extends Node3D
class_name DecorMover
## Move your yard decorations (Jason's son, Nov 25). Touch one and hold still: a ring
## of lights fills up around it, then it lights up and the thing lifts off the
## ground. Drag it wherever you want it and let go. (Like moving a button on the
## iPad.) It turns to face you while you carry it.
##
## With a keyboard, or the USE button: walk up to it and hold E (USE). It floats
## where you look; walk it where you want it and press E (USE) to set it down.
##
## Things you can move are HomeDecor.movable (the statue, the gnome, the bench, the
## bird bath and the flower beds). Spots are saved in Game.decor_spots.
## It won't go inside a building, the garden, the portal, on a slope, on top of
## something else or out past the yard: the ring turns red, and if you let go
## there it floats back to where it was.

const HOLD := 1.0          # seconds of holding still to pick it up
const START := 0.22        # the ring only shows after a moment (a quick swipe is still a swipe)
const STILL_PX := 24.0     # how far a finger may wander while holding still
const REACH := 32.0        # how far away you can pick something up by touch
const YARD_R := 44.0       # how far from the cabin things can go
const SEGS := 28

var deco: HomeDecor
var ring: MultiMeshInstance3D
var _ring_mat: StandardMaterial3D
var state := ""            # "" | "hold" | "carry"
var how := ""              # "touch" | "use"
var item := ""             # the spot id being moved
var ok := true
var moved := 0             # (for the tests)
var refused := 0
var _t := 0.0
var _touch := -1
var _touch_pos := Vector2.ZERO
var _from := Vector3.ZERO
var _from_yaw := 0.0
var _target := Vector3.ZERO
var _use_let_go := false
var _ring_r := 1.0
var _lit := -1

static func make(d: HomeDecor) -> DecorMover:
	var m := DecorMover.new(); m.name = "Mover"; m.deco = d
	d.add_child(m)
	m._make_ring()
	return m

func _make_ring() -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.06, 0.12)
	mm.mesh = bm; mm.instance_count = SEGS
	ring = MultiMeshInstance3D.new(); ring.multimesh = mm
	_ring_mat = StandardMaterial3D.new(); _ring_mat.vertex_color_use_as_albedo = true
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.no_depth_test = true          # (always visible, even behind the thing itself)
	_ring_mat.render_priority = 2
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)

func _size_ring(r: float) -> void:
	_ring_r = r
	var mm := ring.multimesh
	var seg_len := TAU * r / SEGS * 0.72
	for k in SEGS:
		var a := -PI * 0.5 + k * TAU / SEGS           # (it fills clockwise from the top)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var b := Basis(Vector3.UP, -a + PI * 0.5).scaled(Vector3(seg_len, 1, 1))
		mm.set_instance_transform(k, Transform3D(b, p))
	_lit = -1

## fill 0..1 lights the ring up segment by segment; colour for the lit ones.
func _paint(fill: float, lit: Color, dim := Color(1, 1, 1, 0.28)) -> void:
	var n := int(round(clampf(fill, 0.0, 1.0) * SEGS))
	var key := n * 1000 + int(lit.r * 9) * 100 + int(lit.g * 9) * 10 + int(lit.b * 9)
	if key == _lit:
		return
	_lit = key
	for k in SEGS:
		ring.multimesh.set_instance_color(k, lit if k < n else dim)

func _player() -> Player:
	return deco.home.player if deco and deco.home else null

func _cam() -> Camera3D:
	var p := _player()
	return p.camera if p else get_viewport().get_camera_3d()

func busy() -> bool:
	return state != ""

func touch_index() -> int:
	return _touch if how == "touch" else -1

# --- touch: hold on it, then drag ---------------------------------------------------
## A finger came down at `pos`. If it's on something you can move, start holding it.
func touch_down(index: int, pos: Vector2) -> bool:
	if state != "" or not _can_move_now():
		return false
	var id := pick_at(pos)
	if id == "":
		return false
	_begin(id, "touch")
	_touch = index
	_touch_pos = pos
	return true

## What's under the screen point `pos` (a spot id, or "").
func pick_at(pos: Vector2) -> String:
	var cam := _cam()
	var p := _player()
	if cam == null or p == null:
		return ""
	var o := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := ""
	var best_d := INF
	for id in deco.movable:
		var it: Dictionary = deco.movable[id]
		var n: Node3D = it.node
		if n.global_position.distance_to(p.global_position) > REACH:
			continue
		var inv := n.global_transform.affine_inverse()
		var r: float = it.r
		var box := AABB(Vector3(-r, -0.2, -r), Vector3(r * 2.0, float(it.h) + 0.2, r * 2.0))
		var hit = box.intersects_ray(inv * o, inv.basis * dir)
		if hit != null:
			var d := o.distance_to(n.global_transform * (hit as Vector3))
			if d < best_d:
				best_d = d
				best = id
	return best

## The finger moved. Returns false if this touch isn't ours any more (it was a swipe:
## the caller turns it back into an ordinary look or stick touch).
func touch_drag(index: int, pos: Vector2) -> bool:
	if how != "touch" or index != _touch:
		return false
	if state == "hold":
		if pos.distance_to(_touch_pos) > STILL_PX:
			cancel()
			return false
		return true
	_touch_pos = pos
	var g = _ground_under(pos)
	if g != null:
		_target = g
	return true

func touch_up(index: int) -> void:
	if how != "touch" or index != _touch:
		return
	if state == "carry":
		set_down()
	else:
		cancel()

# --- USE / E: hold it, then it floats where you look --------------------------------
func begin_use(id: String) -> void:
	if state != "" or not _can_move_now():
		return
	_begin(id, "use")
	_use_let_go = false

# --- the holding, carrying and setting down ------------------------------------------
func _can_move_now() -> bool:
	var sc := get_tree().current_scene
	var p := _player()
	return p != null and deco.home.landed and not get_tree().paused and (sc == null or sc.get("state") == null or sc.get("state") == "play") \
		and not deco.home.indoors(p.global_position) and not p.mounted

func _begin(id: String, mode: String) -> void:
	item = id
	how = mode
	state = "hold"
	_t = 0.0
	var it: Dictionary = deco.movable[id]
	var n: Node3D = it.node
	_from = n.global_position
	_from_yaw = n.rotation.y
	_target = _from
	_size_ring(float(it.r) + 0.35)
	ring.global_position = _from + Vector3(0, 0.08, 0)
	_paint(0.0, Color(1.0, 0.85, 0.3))

func _process(delta: float) -> void:
	if state == "":
		return
	if not is_instance_valid(_player()) or get_tree().paused:
		cancel()
		return
	var it: Dictionary = deco.movable.get(item, {})
	if it.is_empty():
		cancel()
		return
	var n: Node3D = it.node
	if state == "hold":
		if how == "use" and not Input.is_action_pressed("interact"):
			if _t > START:
				Game.say("Keep holding to pick it up!", Color(1.0, 0.9, 0.6))
			cancel()
			return
		_t += delta
		var fill := (_t - START) / (HOLD - START)
		ring.visible = _t > START or how == "use"
		_paint(fill, Color(1.0, 0.85, 0.3))
		# a little wobble as it gets ready to lift
		n.position.y = n.get_parent().to_local(_from).y + (sin(_t * 40.0) * 0.015 if fill > 0.5 else 0.0)
		if fill >= 1.0:
			_lift(n)
		return
	# carrying
	if how == "use":
		if not Input.is_action_pressed("interact"):
			_use_let_go = true
		var g = _ground_under(get_viewport().get_visible_rect().size * Vector2(0.5, 0.56))
		if g != null:
			_target = g
		var pp := _player().global_position
		var f := Vector2(_target.x - pp.x, _target.z - pp.z)
		var reach := clampf(f.length(), 2.2 + float(it.r), 9.0 + float(it.r))
		f = (f.normalized() if f.length() > 0.01 else Vector2(-sin(_player().yaw), -cos(_player().yaw))) * reach
		_target = deco.home.ground(pp.x + f.x, pp.z + f.y)
		if _use_let_go and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
			set_down()
			return
	ok = can_place(item, _target)
	var want := _target + Vector3(0, 0.45 + sin(Time.get_ticks_msec() * 0.006) * 0.06, 0)
	n.global_position = n.global_position.lerp(want, 1.0 - exp(-14.0 * delta))
	var to := _player().global_position - n.global_position
	if Vector2(to.x, to.z).length() > 0.5:
		var face := atan2(-to.x, -to.z) + float(it.get("front", 0.0))     # (its front towards you)
		n.rotation.y = lerp_angle(n.rotation.y, face, 1.0 - exp(-8.0 * delta))
	ring.global_position = _target + Vector3(0, 0.08, 0)
	_paint(1.0, Color(0.35, 1.0, 0.45, 0.9) if ok else Color(1.0, 0.3, 0.25, 0.9))

func _lift(_n: Node3D) -> void:
	state = "carry"
	_player().carrying = true
	_body_on(item, false)
	Sfx.play("pop", -2.0, 0.05)
	Sfx.play("levelup", -12.0, 0.0)
	FX.burst(_from + Vector3(0, 0.4, 0), Color(1.0, 0.9, 0.5), 26, 2.4, 0.12, 0.7, 0.5)
	_paint(1.0, Color(1.0, 0.95, 0.55))
	var nm := String(deco.movable[item].get("name", "it"))
	if how == "touch":
		Game.say("You picked up the %s! Drag it where you want it and let go." % nm, Color(1.0, 0.9, 0.6))
	else:
		Game.say("You picked up the %s! Walk and look where you want it, then press USE to set it down." % nm, Color(1.0, 0.9, 0.6))

## Put it down where it is (or back where it came from, if it doesn't fit there).
func set_down() -> void:
	if state != "carry":
		cancel()
		return
	var it: Dictionary = deco.movable[item]
	var n: Node3D = it.node
	ok = can_place(item, _target)
	if not ok:
		refused += 1
		if how == "use":
			Game.say("It won't fit there. Try somewhere else!", Color(1.0, 0.6, 0.5))
			Sfx.play("beep", -8.0, 0.0)
			return
		Game.say("It won't fit there, so it floated back.", Color(1.0, 0.75, 0.55))
		_put(n, _from, _from_yaw, false)
	else:
		_put(n, _target, n.rotation.y, true)
		moved += 1
		var key := item
		Game.decor_spots[key] = [snappedf(_target.x, 0.01), snappedf(_target.z, 0.01), snappedf(n.rotation.y, 0.001)]
		var sc := get_tree().current_scene
		if sc and sc.has_method("autosave"):
			sc.autosave()
	_end()

func _put(n: Node3D, at: Vector3, yaw: float, thump: bool) -> void:
	n.rotation.y = yaw
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", at, 0.18 if thump else 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if thump:
		tw.tween_callback(func() -> void:
			Sfx.play("slam", -10.0, 0.1)
			FX.burst(at + Vector3(0, 0.1, 0), Color(0.75, 0.65, 0.5), 18, 2.0, 0.16, 0.6, -2.0))
	var id := item
	tw.tween_callback(func() -> void: _body_on(id, true))

func cancel() -> void:
	if state == "carry" and deco.movable.has(item):
		_put(deco.movable[item].node, _from, _from_yaw, false)
	elif state == "hold" and deco.movable.has(item):
		var n: Node3D = deco.movable[item].node
		n.global_position = _from
	_end()

func _end() -> void:
	state = ""
	var p := _player()
	if p:
		p.carrying = false
	how = ""
	_touch = -1
	ring.visible = false

func _body_on(id: String, on: bool) -> void:
	var it: Dictionary = deco.movable.get(id, {})
	if it.is_empty():
		return
	for b in (it.node as Node).find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = 1 if on else 0

## The ground under a screen point (the yard's own ground, not roofs or trees).
func _ground_under(pos: Vector2):
	var cam := _cam()
	if cam == null:
		return null
	var o := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	if dir.y > -0.02:
		return null                      # (looking at the sky)
	var y := deco.home.ground(o.x, o.z).y
	var p := o
	for i in 4:                          # walk down onto the bumpy ground
		var t := (y - o.y) / dir.y
		if t < 0.0:
			return null
		p = o + dir * t
		y = deco.home.ground(p.x, p.z).y
	var f := Vector2(p.x, p.z)
	if f.length() > YARD_R + 6.0:
		f = f.normalized() * (YARD_R + 6.0)
	return deco.home.ground(f.x, f.y)

## Can this thing stand here? (In the yard, on fairly level ground, not in a building,
## the garden or the portal, not on top of something else or your hero.)
func can_place(id: String, at: Vector3) -> bool:
	var it: Dictionary = deco.movable.get(id, {})
	if it.is_empty():
		return false
	var r: float = it.r
	var f := Vector2(at.x, at.z)
	if f.length() > YARD_R:
		return false
	for k in deco.home.keep_clear_of():
		var c: Array = k
		if c[0] is Rect2:
			var ext: Vector3 = it.get("ext", Vector3(r, 1, r))
			if (c[0] as Rect2).grow(minf(ext.x, ext.z)).has_point(f):
				return false
		elif f.distance_to(c[0]) < float(c[1]) + r:
			return false
	for other in deco.movable:
		if other == id:
			continue
		var on: Node3D = deco.movable[other].node
		if f.distance_to(Vector2(on.global_position.x, on.global_position.z)) < r + float(deco.movable[other].r) + 0.2:
			return false
	var p := _player()
	if p and f.distance_to(Vector2(p.global_position.x, p.global_position.z)) < r + 0.6:
		return false
	# fairly level
	var lo := at.y
	var hi := at.y
	for k in 8:
		var a := k * TAU / 8.0
		var h := deco.home.ground(at.x + cos(a) * r, at.z + sin(a) * r).y
		lo = minf(lo, h); hi = maxf(hi, h)
	if hi - lo > 0.7:
		return false
	# nothing solid in the way (trees, lamps, fences)
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ext2: Vector3 = it.get("ext", Vector3(r, 1, r))
	var cyl := CylinderShape3D.new(); cyl.radius = maxf(minf(ext2.x, ext2.z) * 0.9, 0.25); cyl.height = 1.4
	q.shape = cyl
	q.transform = Transform3D(Basis(), at + Vector3(0, 0.75 + 0.7, 0))
	q.collision_mask = 1
	var ex: Array[RID] = []
	for b in (it.node as Node).find_children("*", "StaticBody3D", true, false):
		ex.append((b as StaticBody3D).get_rid())
	if deco.home.ground_body:
		ex.append(deco.home.ground_body.get_rid())
	q.exclude = ex
	return space.intersect_shape(q, 1).is_empty()
