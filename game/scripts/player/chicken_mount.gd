extends Node3D
class_name ChickenMount
## The Giant Chicken: the first mount (the reward for beating the Cyclops
## Goblin in the Sinkhole of Death). Built from simple shapes so it can be as
## silly as it likes: googly eyes, a wobbly red comb, a bobbing head, scurrying
## legs and flapping wings. Faces -Z like every character.
## The player script drives `speed`, `airborne` and `riding`; on its own (in the
## throne room, waiting to be claimed) it idles and pecks at the floor.

const SEAT_H := 1.62            # height of the saddle top above the ground

var speed := 0.0
var airborne := false
var riding := false
var _t := 0.0
var _peck := 0.0
var _cluck_t := 3.0
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _head: Node3D
var _torso: Node3D
var _comb: Array[Node3D] = []

static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough
	return m

func _sphere(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r0: float, r1: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r0; cm.bottom_radius = r1; cm.height = h
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ready() -> void:
	var white := mat(Color(0.97, 0.95, 0.9))
	var cream := mat(Color(0.93, 0.86, 0.72))
	var red := mat(Color(0.88, 0.12, 0.1), 0.6)
	var orange := mat(Color(1.0, 0.62, 0.12), 0.5)
	var leg_m := mat(Color(1.0, 0.75, 0.2), 0.6)
	var black := mat(Color(0.03, 0.03, 0.03), 0.2)
	var brown := mat(Color(0.55, 0.32, 0.15))
	_torso = Node3D.new(); add_child(_torso)
	# plump body, fluffy breast and a saddle
	_sphere(_torso, 0.7, white, Vector3(0, 1.15, 0.05), Vector3(0.95, 0.78, 1.15))
	_sphere(_torso, 0.5, white, Vector3(0, 1.05, -0.55), Vector3(1.0, 1.05, 0.9))
	_sphere(_torso, 0.36, cream, Vector3(0, 0.82, -0.62), Vector3(1.1, 0.9, 0.8))
	var saddle := _cyl(_torso, 0.42, 0.46, 0.12, brown, Vector3(0, 1.62 - 0.06, 0.08))
	saddle.scale = Vector3(1.0, 1.0, 1.25)
	_cyl(_torso, 0.05, 0.05, 0.9, mat(Color(0.4, 0.22, 0.1)), Vector3(0, 1.3, 0.08), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1.6, 1)
	# tail feathers fanning up at the back
	for k in 5:
		var a := (k - 2) * 0.32
		var f := _sphere(_torso, 0.3, white if k % 2 == 0 else cream, Vector3(sin(a) * 0.32, 1.55 + cos(a) * 0.12, 0.85), Vector3(0.35, 1.1, 0.5))
		f.rotation = Vector3(-0.6, 0, -a)
	# wings
	for sd in [-1.0, 1.0]:
		var w := Node3D.new(); _torso.add_child(w)
		w.position = Vector3(sd * 0.62, 1.32, 0.0)
		var wm := _sphere(w, 0.45, white, Vector3(sd * 0.04, -0.15, 0.12), Vector3(0.28, 0.75, 1.0))
		wm.rotation.z = sd * 0.15
		_sphere(w, 0.2, cream, Vector3(sd * 0.06, -0.38, 0.45), Vector3(0.3, 0.6, 1.0))
		_wings.append(w)
	# neck and head
	_head = Node3D.new(); _torso.add_child(_head)
	_head.position = Vector3(0, 1.75, -0.78)
	_cyl(_torso, 0.2, 0.32, 0.6, white, Vector3(0, 1.5, -0.7), Vector3(-0.35, 0, 0))
	_sphere(_head, 0.33, white, Vector3.ZERO, Vector3(0.95, 1.0, 1.05))
	# googly eyes (big whites with little pupils that wobble)
	for sd in [-1.0, 1.0]:
		_sphere(_head, 0.12, mat(Color(1, 1, 1), 0.2), Vector3(sd * 0.22, 0.1, -0.2))
		_sphere(_head, 0.055, black, Vector3(sd * 0.27, 0.08, -0.29))
	# beak, comb and wattle
	var beak := _cyl(_head, 0.0, 0.12, 0.3, orange, Vector3(0, -0.02, -0.4), Vector3(-PI / 2, 0, 0))
	beak.scale = Vector3(1.0, 1.0, 0.75)
	for k in 4:
		_comb.append(_sphere(_head, 0.1 + (k % 2) * 0.03, red, Vector3(0, 0.34 + (k % 2) * 0.05, -0.18 + k * 0.12)))
	_sphere(_head, 0.09, red, Vector3(0, -0.24, -0.3), Vector3(0.8, 1.4, 0.8))
	# legs with three-toed feet (each swings from the hip)
	for sd in [-1.0, 1.0]:
		var hip := Node3D.new(); add_child(hip)
		hip.position = Vector3(sd * 0.28, 0.7, 0.05)
		_cyl(hip, 0.06, 0.08, 0.7, leg_m, Vector3(0, -0.35, 0))
		for k in 3:
			var a := (k - 1) * 0.5
			var toe := _cyl(hip, 0.03, 0.04, 0.32, leg_m, Vector3(sin(a) * 0.12, -0.67, -cos(a) * 0.12), Vector3(-PI / 2 + 0.15, a, 0))
			toe.position.z -= 0.02
		_legs.append(hip)
	for m in find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _process(delta: float) -> void:
	var run := clampf(speed / 7.0, 0.0, 1.6)
	_t += delta * (2.0 + speed * 1.9)
	# scurrying legs
	for i in _legs.size():
		var ph := _t + (PI if i == 1 else 0.0)
		_legs[i].rotation.x = sin(ph) * 0.75 * clampf(run * 1.4, 0.0, 1.0) if not airborne else -0.6
	# bouncy body and the famous chicken head-bob
	_torso.position.y = absf(sin(_t)) * 0.08 * clampf(run * 1.5, 0.0, 1.0)
	var bob := sin(_t * 2.0) * 0.1 * clampf(run, 0.0, 1.0)
	# idle pecking when standing still
	if speed < 0.5 and not airborne and not riding:
		_peck -= delta
		if _peck <= 0.0:
			_peck = randf_range(1.8, 4.0)
			var tw := create_tween()
			tw.tween_property(_head, "position", Vector3(0, 0.9, -1.05), 0.18)
			tw.tween_property(_head, "position", Vector3(0, 1.75, -0.78), 0.25)
	else:
		_head.position = Vector3(0, 1.75 + absf(bob) * 0.3, -0.78 + bob)
	# flapping wings in the air, a little flutter when running
	var flap := sin(Time.get_ticks_msec() * 0.03) * (0.9 if airborne else 0.15 * run)
	for i in _wings.size():
		var sd := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = sd * (0.2 + flap)
	for c in _comb:
		c.position.x = sin(_t * 1.3 + c.position.z * 8.0) * 0.03
	# the odd cluck
	_cluck_t -= delta
	if _cluck_t <= 0.0:
		_cluck_t = randf_range(3.0, 7.0)
		if is_inside_tree():
			Sfx.play_at("cluck", global_position + Vector3(0, 1.6, 0), -8.0, 0.15)

func bawk() -> void:
	Sfx.play_at("bawk", global_position + Vector3(0, 1.6, 0), -2.0, 0.08)
	FX.burst(global_position + Vector3(0, 1.2, 0), Color(1, 1, 1), 26, 3.0, 0.14, 1.0, -3.0)
