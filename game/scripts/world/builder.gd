extends RefCounted
class_name Builder
## Geometry helpers for box-built architecture with collision.

var root: Node3D
var mats := {}
var boxes: Array = []    # [{mi, shape, lo, hi}] for the z-fighting pass
var zfight_fixed := 0

func _init(r: Node3D) -> void:
	root = r
	var stone := ShaderMaterial.new(); stone.shader = load("res://shaders/stone.gdshader")
	stone.set_shader_parameter("mode", 0)
	mats.wall = stone
	var flo := ShaderMaterial.new(); flo.shader = stone.shader
	flo.set_shader_parameter("mode", 1)
	flo.set_shader_parameter("base_color", Color(0.30, 0.28, 0.26))
	flo.set_shader_parameter("moss", 0.15)
	mats.floor = flo
	var rock := ShaderMaterial.new(); rock.shader = stone.shader
	rock.set_shader_parameter("mode", 2)
	rock.set_shader_parameter("base_color", Color(0.27, 0.26, 0.25))
	rock.set_shader_parameter("moss", 0.05)
	mats.rock = rock
	var dark := ShaderMaterial.new(); dark.shader = stone.shader
	dark.set_shader_parameter("mode", 0)
	dark.set_shader_parameter("base_color", Color(0.2, 0.2, 0.22))
	dark.set_shader_parameter("block_w", 2.0); dark.set_shader_parameter("block_h", 0.8)
	mats.dark = dark
	mats.cobble = pbr("cobblestone_floor_08", 0.35)
	mats.cliff = pbr("rock_wall_08", 0.12)
	mats.brick = pbr("castle_brick_07", 0.4)

func pbr(name: String, uv_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s_diff_1k.jpg" % name)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s_nor_gl_1k.jpg" % name)
	m.roughness_texture = load("res://assets/textures/%s_rough_1k.jpg" % name)
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	m.uv1_triplanar_sharpness = 4.0
	return m

func wall_mat(base: Color, moss := 0.25, floor_y := 0.0, bw := 1.3, bh := 0.55) -> ShaderMaterial:
	var m := (mats.wall as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("moss", moss)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("block_w", bw)
	m.set_shader_parameter("block_h", bh)
	return m

## Axis-aligned box from min/max corners.
func box(a: Vector3, b: Vector3, mat: Material, collide := true, shadows := true) -> MeshInstance3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size := hi - lo
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (lo + hi) * 0.5
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var bs: BoxShape3D = null
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		bs = BoxShape3D.new(); bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	boxes.append({"mi": mi, "shape": bs, "lo": lo, "hi": hi})
	return mi

## Overlapping boxes that share a face plane (same facing) make the GPU flicker
## between the two surfaces ("z-fighting"), worst on the 24-bit depth buffers of
## browsers. Nudge every such face but the biggest one inward by a centimetre
## or two so exactly one surface wins.
func fix_coplanar() -> int:
	var n := _fix_coplanar_boxes()
	_flush_trims()
	return n

func _fix_coplanar_boxes() -> int:
	var buckets := {}
	for i in boxes.size():
		var bx: Dictionary = boxes[i]
		for ax in 3:
			for side in 2:
				var c: float = (bx.lo as Vector3)[ax] if side == 0 else (bx.hi as Vector3)[ax]
				var key := "%d|%d|%d" % [ax, side, int(round(c * 500.0))]
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(i)
	var nudges := {}   # "i|ax|side" -> amount
	var fixed := 0
	for key in buckets:
		var lst: Array = buckets[key]
		if lst.size() < 2:
			continue
		var ax := int(String(key).get_slice("|", 0))
		var side := int(String(key).get_slice("|", 1))
		var u := (ax + 1) % 3; var v := (ax + 2) % 3
		var involved := {}
		for a_i in lst.size():
			for b_i in range(a_i + 1, lst.size()):
				var A: Dictionary = boxes[lst[a_i]]; var B: Dictionary = boxes[lst[b_i]]
				var ou := minf(A.hi[u], B.hi[u]) - maxf(A.lo[u], B.lo[u])
				var ov := minf(A.hi[v], B.hi[v]) - maxf(A.lo[v], B.lo[v])
				if ou > 0.02 and ov > 0.02:
					involved[lst[a_i]] = true; involved[lst[b_i]] = true
					fixed += 1
		if involved.is_empty():
			continue
		var ids: Array = involved.keys()
		ids.sort_custom(func(a, b) -> bool:
			var A: Dictionary = boxes[a]; var B: Dictionary = boxes[b]
			return (A.hi[u] - A.lo[u]) * (A.hi[v] - A.lo[v]) > (B.hi[u] - B.lo[u]) * (B.hi[v] - B.lo[v]))
		for k in range(1, ids.size()):
			nudges["%d|%d|%d" % [ids[k], ax, side]] = 0.012 * k
	for nk in nudges:
		var i := int(String(nk).get_slice("|", 0))
		var ax2 := int(String(nk).get_slice("|", 1))
		var side2 := int(String(nk).get_slice("|", 2))
		var bx: Dictionary = boxes[i]
		var lo: Vector3 = bx.lo; var hi: Vector3 = bx.hi
		if side2 == 0:
			lo[ax2] += nudges[nk]
		else:
			hi[ax2] -= nudges[nk]
		if hi[ax2] - lo[ax2] < 0.005:
			continue
		bx.lo = lo; bx.hi = hi
		var mi: MeshInstance3D = bx.mi
		(mi.mesh as BoxMesh).size = hi - lo
		mi.position = (lo + hi) * 0.5
		if bx.shape:
			(bx.shape as BoxShape3D).size = hi - lo
	zfight_fixed = fixed
	return fixed

## Invisible collider (ramps, blockers).
func collider(center: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = center
	sb.rotation = rot
	return sb

## Floor slab with rectangular holes (x0,z0,x1,z1 as Rect2 in xz).
func slab(x0: float, x1: float, z0: float, z1: float, top: float, thick: float, mat: Material, holes: Array = []) -> void:
	var xs: Array[float] = [x0, x1]
	for h in holes:
		var r: Rect2 = h
		xs.append(clampf(r.position.x, x0, x1)); xs.append(clampf(r.end.x, x0, x1))
	xs.sort()
	for i in xs.size() - 1:
		var ax: float = xs[i]; var bx: float = xs[i + 1]
		if bx - ax < 0.01:
			continue
		var mid := (ax + bx) * 0.5
		var cuts: Array = []
		for h in holes:
			var r: Rect2 = h
			if mid > r.position.x and mid < r.end.x:
				cuts.append([r.position.y, r.end.y])
		cuts.sort_custom(func(p, q): return p[0] < q[0])
		var zc := z0
		for c in cuts:
			if c[0] > zc:
				box(Vector3(ax, top - thick, zc), Vector3(bx, top, minf(c[0], z1)), mat)
			zc = maxf(zc, c[1])
		if zc < z1:
			box(Vector3(ax, top - thick, zc), Vector3(bx, top, z1), mat)

## Wall along X (fixed z) from x0..x1 with door gaps [[a,b,door_h],...].
func wall_x(z: float, x0: float, x1: float, y0: float, h: float, t: float, mat: Material, gaps: Array = []) -> void:
	var cur := x0
	gaps.sort_custom(func(p, q): return p[0] < q[0])
	var segs: Array = []      # [a, b, door height (0 = full wall), a is a gap edge, b is a gap edge]
	for g in gaps:
		if g[0] > cur:
			box(Vector3(cur, y0, z - t * 0.5), Vector3(g[0], y0 + h, z + t * 0.5), mat)
			segs.append([cur, g[0], 0.0, cur != x0, true])
		var dh: float = g[2] if g.size() > 2 else 3.6
		box(Vector3(g[0], y0 + dh, z - t * 0.5), Vector3(g[1], y0 + h, z + t * 0.5), mat)
		segs.append([g[0], g[1], dh, true, true])
		cur = g[1]
	if cur < x1:
		box(Vector3(cur, y0, z - t * 0.5), Vector3(x1, y0 + h, z + t * 0.5), mat)
		segs.append([cur, x1, 0.0, cur != x0, false])
	_wall_trims(true, z, segs, y0, h, t, mat, 0.01)

## Wall along Z (fixed x).
func wall_z(x: float, z0: float, z1: float, y0: float, h: float, t: float, mat: Material, gaps: Array = []) -> void:
	var cur := z0
	gaps.sort_custom(func(p, q): return p[0] < q[0])
	var segs: Array = []
	for g in gaps:
		if g[0] > cur:
			box(Vector3(x - t * 0.5, y0, cur), Vector3(x + t * 0.5, y0 + h, g[0]), mat)
			segs.append([cur, g[0], 0.0, cur != z0, true])
		var dh: float = g[2] if g.size() > 2 else 3.6
		box(Vector3(x - t * 0.5, y0 + dh, g[0]), Vector3(x + t * 0.5, y0 + h, g[1]), mat)
		segs.append([g[0], g[1], dh, true, true])
		cur = g[1]
	if cur < z1:
		box(Vector3(x - t * 0.5, y0, cur), Vector3(x + t * 0.5, y0 + h, z1), mat)
		segs.append([cur, z1, 0.0, cur != z0, false])
	# (the walls along X run through the corners, so these stop short of them)
	_wall_trims(false, x, segs, y0, h, t, mat, 0.09)

# --- carved trims ------------------------------------------------------------
## Dungeon walls get a carved frieze band (rosettes between raised lips) and a
## stone base course along the floor. Both wrap round door edges and stand out
## a few centimetres from the wall, so the stone looks hand-worked.
const TRIM_OUT := 0.07
const FRIEZE_H := 0.55
const PLINTH_H := 0.42
var _trim_mats := {}
var _trim_lines := {}     # "axis|coord|y" -> [[a, b], ...] already trimmed (no doubled-up faces)
var _unit_box: BoxMesh

func _trim_mats_for(mat: Material) -> Array:
	if not (mat is ShaderMaterial) or (mat as ShaderMaterial).shader != (mats.wall as ShaderMaterial).shader:
		return []
	var sm := mat as ShaderMaterial
	var md = sm.get_shader_parameter("mode")
	if md != null and int(md) != 0:
		return []
	var key := sm.get_instance_id()
	if not _trim_mats.has(key):
		var bc = sm.get_shader_parameter("base_color")
		var base: Color = bc if bc is Color else Color(0.34, 0.31, 0.28)
		var fr := sm.duplicate() as ShaderMaterial
		fr.set_shader_parameter("mode", 3)
		fr.set_shader_parameter("band_h", FRIEZE_H)
		fr.set_shader_parameter("base_color", base.lightened(0.16))
		fr.set_shader_parameter("moss", 0.0)
		var pl := sm.duplicate() as ShaderMaterial
		pl.set_shader_parameter("local_v", true)
		pl.set_shader_parameter("block_w", 1.7)
		pl.set_shader_parameter("block_h", PLINTH_H)
		pl.set_shader_parameter("base_color", base.darkened(0.12))
		pl.set_shader_parameter("bevel_w", 0.06)
		_trim_mats[key] = [fr, pl]
	return _trim_mats[key]

func _wall_trims(along_x: bool, fixed: float, segs: Array, y0: float, h: float, t: float, mat: Material, _end_pull: float) -> void:
	var tm := _trim_mats_for(mat)
	if tm.is_empty() or h < 3.0:
		return
	var fb := y0 + clampf(h - 1.2, 2.3, 3.0)
	var do_frieze := fb + FRIEZE_H <= y0 + h - 0.05
	for sg in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		var dh: float = sg[2]
		# wrap round a doorway's edge
		a -= TRIM_OUT if sg[3] else 0.0
		b += TRIM_OUT if sg[4] else 0.0
		if dh == 0.0:
			_trim_reqs.append([along_x, fixed, t, a, b, y0 + 0.005, y0 + PLINTH_H, tm[1]])
		if do_frieze and (dh == 0.0 or dh <= fb - 0.02):
			_trim_reqs.append([along_x, fixed, t, a, b, fb, fb + FRIEZE_H, tm[0]])

var _trim_reqs: Array = []

## Lay the trims once the level's boxes are all in place: each wall face gets its
## own strip, and any stretch of face that's up against another box (a wall built
## back to back, a pillar, the rock) is left bare, so no two surfaces ever overlap.
func _flush_trims() -> void:
	if _trim_reqs.is_empty():
		return
	# index the boxes by 1 m cells across x and across z, for quick lookups
	var by_x := {}
	var by_z := {}
	for i in boxes.size():
		var bx: Dictionary = boxes[i]
		var lo: Vector3 = bx.lo; var hi: Vector3 = bx.hi
		for cx in range(int(floor(lo.x)), int(floor(hi.x)) + 1):
			if not by_x.has(cx): by_x[cx] = []
			by_x[cx].append(i)
		for cz in range(int(floor(lo.z)), int(floor(hi.z)) + 1):
			if not by_z.has(cz): by_z[cz] = []
			by_z[cz].append(i)
	for rq in _trim_reqs:
		var along_x: bool = rq[0]
		var fixed: float = rq[1]
		var t: float = rq[2]
		var y_lo: float = rq[5]
		var y_hi: float = rq[6]
		var ym := (y_lo + y_hi) * 0.5
		for sdv in [-1.0, 1.0]:
			var sd: float = sdv
			var face: float = fixed + sd * t * 0.5
			var probe: float = face + sd * 0.035
			var pieces: Array = [[float(rq[3]), float(rq[4])]]
			var cands: Array = (by_z if along_x else by_x).get(int(floor(probe)), [])
			for i in cands:
				var bx: Dictionary = boxes[i]
				var lo: Vector3 = bx.lo; var hi: Vector3 = bx.hi
				var plo := lo.z if along_x else lo.x
				var phi := hi.z if along_x else hi.x
				if probe <= plo or probe >= phi or ym <= lo.y or ym >= hi.y:
					continue
				var alo := lo.x if along_x else lo.z
				var ahi := hi.x if along_x else hi.z
				pieces = _cut(pieces, alo, ahi)
			# and never twice on the same face line
			var key := "%s|%d|%d" % ["x" if along_x else "z", int(round(face * 50.0)), int(round(y_lo * 50.0))]
			var done: Array = _trim_lines.get(key, [])
			for dn in done:
				pieces = _cut(pieces, dn[0], dn[1])
			for pc0 in pieces:
				# a hair short at each end, so a trim's end is never flush with a wall's end
				var pc: Array = [float(pc0[0]) + 0.012, float(pc0[1]) - 0.012]
				if pc[1] - pc[0] < 0.25:
					continue
				done.append(pc)
				var p0: float = face - sd * 0.02
				var p1: float = face + sd * TRIM_OUT
				var lo2 := Vector3(pc[0], y_lo, minf(p0, p1)) if along_x else Vector3(minf(p0, p1), y_lo, pc[0])
				var hi2 := Vector3(pc[1], y_hi, maxf(p0, p1)) if along_x else Vector3(maxf(p0, p1), y_hi, pc[1])
				trim(lo2, hi2, rq[7])
			_trim_lines[key] = done
	_trim_reqs.clear()

func _cut(pieces: Array, c0: float, c1: float) -> Array:
	var out: Array = []
	for pc in pieces:
		if c1 <= pc[0] or c0 >= pc[1]:
			out.append(pc)
			continue
		if c0 > pc[0]:
			out.append([pc[0], c0])
		if c1 < pc[1]:
			out.append([c1, pc[1]])
	return out

## A decorative box (no collision): a unit cube scaled into place, so the shader
## knows where its bottom and top are.
func trim(lo: Vector3, hi: Vector3, mat: Material) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_box
	mi.material_override = mat
	mi.position = (lo + hi) * 0.5
	mi.scale = hi - lo
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

## Rectangular room: floor, four walls, ceiling. gaps per side: n (min z), s (max z), w (min x), e (max x).
func room(x0: float, x1: float, z0: float, z1: float, y: float, h: float, wall_m: Material, floor_m: Material, gaps := {}, ceiling := true, floor_holes: Array = []) -> void:
	var t := 1.0
	slab(x0 - t, x1 + t, z0 - t, z1 + t, y, 1.0, floor_m, floor_holes)
	wall_x(z0 - t * 0.5, x0 - t, x1 + t, y, h, t, wall_m, gaps.get("n", []).duplicate(true))
	wall_x(z1 + t * 0.5, x0 - t, x1 + t, y, h, t, wall_m, gaps.get("s", []).duplicate(true))
	wall_z(x0 - t * 0.5, z0, z1, y, h, t, wall_m, gaps.get("w", []).duplicate(true))
	wall_z(x1 + t * 0.5, z0, z1, y, h, t, wall_m, gaps.get("e", []).duplicate(true))
	if ceiling:
		box(Vector3(x0 - t, y + h, z0 - t), Vector3(x1 + t, y + h + 1.0, z1 + t), wall_m, true, true)

## Stone pillar with base and capital.
func pillar(pos: Vector3, h: float, r := 0.45, mat: Material = null) -> void:
	var m: Material = mat if mat else mats.wall
	box(pos + Vector3(-r - 0.12, 0, -r - 0.12), pos + Vector3(r + 0.12, 0.45, r + 0.12), m)
	box(pos + Vector3(-r, 0.45, -r), pos + Vector3(r, h - 0.45, r), m)
	box(pos + Vector3(-r - 0.15, h - 0.45, -r - 0.15), pos + Vector3(r + 0.15, h, r + 0.15), m)

## Visual steps + an invisible ramp collider so the character glides up/down.
func stairs(x0: float, x1: float, z_top: float, z_bottom: float, y_top: float, y_bottom: float, mat: Material) -> void:
	var n := int(absf(y_top - y_bottom) / 0.25)
	var dz := (z_bottom - z_top) / n
	for i in n:
		var y := y_top - (i + 1) * (y_top - y_bottom) / n
		box(Vector3(x0, y - 0.6, z_top + dz * i), Vector3(x1, y + 0.25, z_top + dz * (i + 1)), mat, false)
	var len := Vector2(z_bottom - z_top, y_bottom - y_top).length()
	var ang := atan2(y_top - y_bottom, absf(z_bottom - z_top))
	var center := Vector3((x0 + x1) * 0.5, (y_top + y_bottom) * 0.5 - 0.2, (z_top + z_bottom) * 0.5)
	var sgn := 1.0 if z_bottom < z_top else -1.0
	collider(center, Vector3(x1 - x0, 0.4, len), Vector3(-ang * sgn, 0, 0))
