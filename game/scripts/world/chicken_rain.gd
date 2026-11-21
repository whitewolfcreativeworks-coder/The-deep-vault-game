extends Node3D
class_name ChickenRain
## CHICKEN PARTY (Insane): chickens rain out of the sky all around you, flapping
## like mad. Each one lands with a BAWK, scurries off in a panic and vanishes in a
## puff of feathers. (Jason, Nov 21: "a lot more chickens should fall out of the sky".)
##
## They're only for show (the few real chickens that fall with them are the ones
## you can catch for a drumstick), so they're cheap: every falling chicken in the
## sky is drawn together in one go, and their wings in another, however many there are.

const MAX_AT_ONCE := 26
const FALL_FROM := Vector2(12.0, 18.0)     # metres above you they start
const SPREAD := Vector2(2.0, 12.0)         # how far around you they land

var player: Node3D
var to_drop := 40                          # how many still to come
var landed := 0                            # (for the tests)
var _birds: Array = []                     # [pos, vel, land_y, state (0 falling, 1 running), t, yaw, run dir, life]
var _next := 0.0
var _bawk_t := 0.0
var _mm: MultiMesh
var _wings: MultiMesh
var _rng := RandomNumberGenerator.new()

static var _body_mesh: ArrayMesh
static var _wing_mesh: ArrayMesh

static func start(parent: Node, p: Node3D, count := 40) -> ChickenRain:
	for c in parent.get_children():
		if c is ChickenRain:
			(c as ChickenRain).to_drop += count       # (already raining: more!)
			return c
	var r := ChickenRain.new()
	r.player = p
	r.to_drop = count
	parent.add_child(r)
	return r

func _ready() -> void:
	_rng.randomize()
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	_mm = MultiMesh.new(); _mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = body_mesh(); _mm.instance_count = MAX_AT_ONCE; _mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = _mm; mi.material_override = mat
	mi.extra_cull_margin = 60.0
	add_child(mi)
	_wings = MultiMesh.new(); _wings.transform_format = MultiMesh.TRANSFORM_3D
	_wings.mesh = wing_mesh(); _wings.instance_count = MAX_AT_ONCE * 2; _wings.visible_instance_count = 0
	var wi := MultiMeshInstance3D.new(); wi.multimesh = _wings; wi.material_override = mat
	wi.extra_cull_margin = 60.0
	add_child(wi)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_bawk_t -= delta
	_next -= delta
	while _next <= 0.0 and to_drop > 0 and _birds.size() < MAX_AT_ONCE:
		_next += 0.1
		_drop_one()
	if _next < -0.2:
		_next = 0.0
	var i := 0
	while i < _birds.size():
		var b: Array = _birds[i]
		b[4] = float(b[4]) + delta
		var pos: Vector3 = b[0]
		if int(b[3]) == 0:
			var vel: Vector3 = b[1]
			vel.y = maxf(vel.y - 9.0 * delta, -7.5)          # (flapping like mad slows them down a bit)
			pos += vel * delta
			if pos.y <= float(b[2]):
				pos.y = float(b[2])
				b[3] = 1
				b[4] = 0.0
				var a := _rng.randf() * TAU
				b[6] = Vector3(cos(a), 0, sin(a))
				b[5] = atan2(-cos(a), -sin(a))
				b[7] = _rng.randf_range(1.2, 2.6)
				landed += 1
				if landed % 3 == 0:
					FX.burst(pos + Vector3(0, 0.3, 0), Color(1, 1, 1), 10, 2.5, 0.08, 0.6, -3.0)
				if _bawk_t <= 0.0:
					_bawk_t = 0.22
					Sfx.play_at("bawk" if _rng.randf() < 0.6 else "cluck", pos, -8.0, 0.3, 6.0)
			b[1] = vel
		else:
			var d: Vector3 = b[6]
			pos += d * 2.6 * delta
			b[7] = float(b[7]) - delta
			if float(b[7]) <= 0.0:
				FX.burst(pos + Vector3(0, 0.35, 0), Color(1, 1, 1), 8, 1.8, 0.07, 0.5, -2.0)
				_birds.remove_at(i)
				continue
		b[0] = pos
		i += 1
	_draw_all()
	if to_drop <= 0 and _birds.is_empty():
		queue_free()

func _drop_one() -> void:
	to_drop -= 1
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(SPREAD.x, SPREAD.y)
	var base := player.global_position
	var x := base.x + cos(a) * r
	var z := base.z + sin(a) * r
	var top := base.y + _rng.randf_range(FALL_FROM.x, FALL_FROM.y)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top + 2.0, z), Vector3(x, base.y - 25.0, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return               # (nowhere to land: over a cliff or a cloud gap)
	var land: Vector3 = hit.position
	_birds.append([Vector3(x, top, z), Vector3(_rng.randf_range(-1, 1), -_rng.randf_range(1.0, 3.0), _rng.randf_range(-1, 1)),
		land.y, 0, 0.0, _rng.randf() * TAU, Vector3.ZERO, 0.0])

func _draw_all() -> void:
	var n := _birds.size()
	_mm.visible_instance_count = n
	_wings.visible_instance_count = n * 2
	for k in n:
		var b: Array = _birds[k]
		var falling := int(b[3]) == 0
		var t := float(b[4])
		var yaw := float(b[5]) + (t * 2.5 if falling else 0.0)     # (they spin a little as they fall)
		var bb := Basis(Vector3.UP, yaw)
		if falling:
			bb = bb * Basis(Vector3.RIGHT, sin(t * 7.0 + k) * 0.35)
		var pos: Vector3 = b[0]
		if not falling:
			pos.y += absf(sin(t * 14.0)) * 0.12                        # a panicky hop
		var xf := Transform3D(bb, pos)
		_mm.set_instance_transform(k, xf)
		var flap := (0.4 + sin(t * (32.0 if falling else 20.0) + k) * 0.75)
		for side: int in [0, 1]:
			var wb := Basis(Vector3.UP, PI * side) * Basis(Vector3.FORWARD, -flap)
			_wings.set_instance_transform(k * 2 + side, xf * Transform3D(wb, Vector3(0.16 if side == 0 else -0.16, 0.42, 0.02)))

# --- the chicken itself: a few simple shapes baked into one mesh -----------------------
static func _add(st: SurfaceTool, m: PrimitiveMesh, xf: Transform3D, c: Color) -> void:
	var arr := m.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	var col := HomeDecor._vc(c)
	for i in idx:
		st.set_color(col)
		st.set_normal((nb * norms[i]).normalized())
		st.add_vertex(xf * verts[i])

static func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 10; s.rings = 5
	return s

static func body_mesh() -> ArrayMesh:
	if _body_mesh:
		return _body_mesh
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.97, 0.95, 0.9)
	var red := Color(0.9, 0.12, 0.1)
	var orange := Color(1.0, 0.6, 0.12)
	var black := Color(0.05, 0.05, 0.05)
	_add(st, _ball(0.22), Transform3D(Basis().scaled(Vector3(1.0, 0.9, 1.25)), Vector3(0, 0.38, 0.02)), white)       # body
	_add(st, _ball(0.11), Transform3D(Basis().scaled(Vector3(0.8, 1.3, 1.0)), Vector3(0, 0.55, 0.24)), white)        # tail
	_add(st, _ball(0.12), Transform3D(Basis(), Vector3(0, 0.68, -0.2)), white)                                       # head
	_add(st, _ball(0.05), Transform3D(Basis().scaled(Vector3(0.6, 1.3, 1.6)), Vector3(0, 0.81, -0.21)), red)         # comb
	_add(st, _ball(0.035), Transform3D(Basis().scaled(Vector3(0.8, 1.5, 0.8)), Vector3(0, 0.59, -0.3)), red)         # wattle
	for sx in [-1.0, 1.0]:
		_add(st, _ball(0.022), Transform3D(Basis(), Vector3(sx * 0.085, 0.71, -0.29)), black)                         # eyes
		var leg := CylinderMesh.new(); leg.top_radius = 0.022; leg.bottom_radius = 0.022; leg.height = 0.2; leg.radial_segments = 6
		_add(st, leg, Transform3D(Basis(), Vector3(sx * 0.08, 0.1, 0.0)), orange)                                     # legs
		_add(st, _ball(0.04), Transform3D(Basis().scaled(Vector3(1.0, 0.4, 1.6)), Vector3(sx * 0.08, 0.01, -0.03)), orange)
	var beak := CylinderMesh.new(); beak.top_radius = 0.0; beak.bottom_radius = 0.045; beak.height = 0.1; beak.radial_segments = 6
	_add(st, beak, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.67, -0.34)), orange)
	_body_mesh = st.commit()
	return _body_mesh

static func wing_mesh() -> ArrayMesh:
	if _wing_mesh:
		return _wing_mesh
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add(st, _ball(0.13), Transform3D(Basis().scaled(Vector3(1.1, 0.3, 1.2)), Vector3(0.12, 0, 0)), Color(0.94, 0.92, 0.86))
	_wing_mesh = st.commit()
	return _wing_mesh
