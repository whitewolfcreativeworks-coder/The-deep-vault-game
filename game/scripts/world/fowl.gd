extends CharacterBody3D
class_name Fowl
## A wandering chicken or turkey. It pecks about, clucks, runs off flapping when
## hit, and when beaten drops food: a roast drumstick (chicken) or a big turkey
## leg (turkey) that restores health and energy when you pick it up.
## It is "damageable" (swords and spells hit it) but not an enemy, so it never
## counts toward quests and never fights back.

var kind := "chicken"         # "chicken" | "turkey"
var hp := 30.0
var dead := false
var hit_radius := 0.35
var home := Vector3.ZERO
var wander_r := 7.0
var _target := Vector3.ZERO
var _wait := 0.0
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _t := 0.0
var _cluck_t := 4.0
var _facing := 0.0
var _vis: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _flash: StandardMaterial3D

static func make(parent: Node, pos: Vector3, k: String, radius := 7.0) -> Fowl:
	var f := Fowl.new()
	f.kind = k
	f.wander_r = radius
	parent.add_child(f)
	f.global_position = pos
	f.home = pos
	return f

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("critter")
	collision_layer = 4
	collision_mask = 1
	hp = 22.0 if kind == "chicken" else 44.0
	hit_radius = 0.35 if kind == "chicken" else 0.5
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new()
	sh.radius = 0.25 if kind == "chicken" else 0.36; sh.height = 0.7 if kind == "chicken" else 0.95
	cs.shape = sh; cs.position.y = sh.height * 0.5
	add_child(cs)
	_flash = StandardMaterial3D.new(); _flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _flash.albedo_color = Color(1, 1, 1, 0)
	_build()
	_facing = randf() * TAU
	_wait = randf_range(0.5, 2.5)
	_cluck_t = randf_range(2.0, 7.0)

func _m(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough
	return m

func _ball(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	mi.material_overlay = _flash
	parent.add_child(mi)
	return mi

func _cone(parent: Node3D, r: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = r; cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

func _build() -> void:
	_vis = Node3D.new(); add_child(_vis)
	var leg_m := _m(Color(1.0, 0.7, 0.2), 0.6)
	var beak := _m(Color(1.0, 0.6, 0.12), 0.5)
	var red := _m(Color(0.88, 0.12, 0.1), 0.6)
	var eye := _m(Color(0.02, 0.02, 0.02), 0.2)
	if kind == "chicken":
		var white := _m(Color(0.97, 0.95, 0.9))
		_ball(_vis, 0.24, white, Vector3(0, 0.42, 0.02), Vector3(0.9, 0.85, 1.15))
		for k in 3:
			var a := (k - 1) * 0.4
			_ball(_vis, 0.1, white, Vector3(sin(a) * 0.1, 0.56, 0.24), Vector3(0.5, 1.2, 0.5)).rotation = Vector3(-0.5, 0, -a)
		_head = Node3D.new(); _head.position = Vector3(0, 0.62, -0.2); _vis.add_child(_head)
		_ball(_head, 0.12, white, Vector3.ZERO)
		_cone(_head, 0.04, 0.1, beak, Vector3(0, -0.01, -0.13), Vector3(-PI / 2, 0, 0))
		for k in 3:
			_ball(_head, 0.035, red, Vector3(0, 0.11, -0.04 + k * 0.04))
		_ball(_head, 0.03, red, Vector3(0, -0.08, -0.08), Vector3(1, 1.5, 1))
		for sx in [-1.0, 1.0]:
			_ball(_head, 0.022, eye, Vector3(sx * 0.09, 0.02, -0.06))
			var w := Node3D.new(); w.position = Vector3(sx * 0.2, 0.46, 0.02); _vis.add_child(w); _wings.append(w)
			_ball(w, 0.12, white, Vector3(sx * 0.03, 0, 0.02), Vector3(0.35, 0.8, 1.1))
	else:
		# a turkey: plump and brown with a big striped fan of a tail
		var brown := _m(Color(0.36, 0.22, 0.12))
		var bronze := _m(Color(0.5, 0.33, 0.16), 0.5)
		var cream := _m(Color(0.9, 0.82, 0.62))
		var rust := _m(Color(0.62, 0.28, 0.12))
		var blue := _m(Color(0.55, 0.7, 0.85))
		_ball(_vis, 0.34, brown, Vector3(0, 0.6, 0.04), Vector3(0.95, 0.9, 1.15))
		_ball(_vis, 0.22, bronze, Vector3(0, 0.62, -0.24), Vector3(1.0, 1.0, 0.8))
		for k in 7:
			var a := (k - 3) * 0.32
			var fan_c: Material = [brown, rust, cream][k % 3]
			var fe := _ball(_vis, 0.2, fan_c, Vector3(sin(a) * 0.36, 0.78 + cos(a) * 0.3, 0.36), Vector3(0.38, 1.25, 0.12))
			fe.rotation = Vector3(-0.25, 0, -a)
			var tip := _ball(_vis, 0.06, cream, Vector3(sin(a) * 0.55, 0.78 + cos(a) * 0.52, 0.37), Vector3(1.2, 1.0, 0.4))
			tip.rotation.z = -a
		_head = Node3D.new(); _head.position = Vector3(0, 0.9, -0.36); _vis.add_child(_head)
		_ball(_head, 0.1, blue, Vector3.ZERO, Vector3(1, 1.1, 1))
		_cone(_head, 0.035, 0.09, beak, Vector3(0, -0.01, -0.11), Vector3(-PI / 2, 0, 0))
		_ball(_head, 0.04, red, Vector3(0, -0.1, -0.06), Vector3(1, 2.0, 1))     # wattle
		_ball(_head, 0.025, red, Vector3(0.0, 0.02, -0.12), Vector3(1, 2.4, 1)).rotation.x = 0.4   # snood
		for sx in [-1.0, 1.0]:
			_ball(_head, 0.02, eye, Vector3(sx * 0.08, 0.03, -0.05))
			var w := Node3D.new(); w.position = Vector3(sx * 0.3, 0.6, 0.04); _vis.add_child(w); _wings.append(w)
			_ball(w, 0.17, bronze, Vector3(sx * 0.03, 0, 0.02), Vector3(0.3, 0.8, 1.15))
	var leg_h := 0.24 if kind == "chicken" else 0.32
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new(); leg.position = Vector3(sx * 0.09 * (1.0 if kind == "chicken" else 1.4), leg_h, 0.02); _vis.add_child(leg); _legs.append(leg)
		var shin := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.02; cm.bottom_radius = 0.02; cm.height = leg_h
		shin.mesh = cm; shin.material_override = leg_m; shin.position.y = -leg_h * 0.5; leg.add_child(shin)
		_ball(leg, 0.04, leg_m, Vector3(0, -leg_h, -0.04), Vector3(1.0, 0.4, 1.6))

func _physics_process(delta: float) -> void:
	_t += delta
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5
	var spd := 0.0
	var dir := Vector3.ZERO
	if _flee_t > 0.0:
		_flee_t -= delta
		dir = global_position - _flee_from; dir.y = 0
		if dir.length() < 0.01:
			dir = Vector3(randf() - 0.5, 0, randf() - 0.5)
		dir = dir.normalized()
		# don't run too far from home
		var back := home - global_position; back.y = 0
		if back.length() > wander_r * 1.6:
			dir = (dir + back.normalized() * 1.2).normalized()
		spd = 3.4 if kind == "chicken" else 3.0
	else:
		_wait -= delta
		var to := _target - global_position; to.y = 0
		if _wait > 0.0 or to.length() < 0.4:
			if _wait <= 0.0:
				_wait = randf_range(1.0, 4.0)
				var a := randf() * TAU
				var r := sqrt(randf()) * wander_r
				_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
		else:
			dir = to.normalized()
			spd = 1.1 if kind == "chicken" else 0.9
	velocity.x = lerpf(velocity.x, dir.x * spd, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, dir.z * spd, 1.0 - exp(-8.0 * delta))
	var was := global_position
	move_and_slide()
	# stuck against something? pick somewhere else
	if spd > 0.0 and _flee_t <= 0.0 and was.distance_to(global_position) < spd * delta * 0.2:
		_wait = 0.3
	if global_position.y < home.y - 30.0:
		queue_free()
	# look and animation
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.2:
		_facing = lerp_angle(_facing, atan2(-velocity.x, -velocity.z), 1.0 - exp(-8.0 * delta))
	_vis.rotation.y = _facing
	var step := hv.length()
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * (6.0 + step * 5.0) + i * PI) * clampf(step * 0.5, 0.0, 0.7)
	if _flee_t > 0.0:
		for i in _wings.size():
			_wings[i].rotation.z = (sin(_t * 30.0) * 0.7 + 0.5) * (1.0 if i == 0 else -1.0)
		_head.rotation.x = -0.2
	else:
		for w in _wings:
			w.rotation.z = lerpf(w.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
		if step < 0.2:
			_head.rotation.x = maxf(0.0, sin(_t * 3.0 + home.x)) * 1.1      # pecking at the ground
		else:
			_head.rotation.x = sin(_t * 9.0) * 0.15
	_cluck_t -= delta
	if _cluck_t <= 0.0:
		_cluck_t = randf_range(5.0, 11.0)
		Sfx.play_at("cluck", global_position, -14.0 if kind == "chicken" else -11.0, 0.25, 5.0)

func take_damage(amount: float, from_pos: Vector3, _knock := 2.5, _crit := false) -> void:
	if dead:
		return
	hp -= amount
	_flash.albedo_color = Color(1, 1, 1, 0.75)
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.18)
	FX.burst(global_position + Vector3(0, 0.5, 0), Color(0.98, 0.96, 0.9) if kind == "chicken" else Color(0.55, 0.38, 0.22), 10, 2.5, 0.08, 0.7, -3.0)
	Sfx.play_at("bawk", global_position, -6.0, 0.25)
	_flee_t = 2.2
	_flee_from = from_pos
	velocity.y = 3.5
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	remove_from_group("damageable")
	FX.burst(global_position + Vector3(0, 0.5, 0), Color(0.98, 0.96, 0.9) if kind == "chicken" else Color(0.6, 0.4, 0.22), 40, 4.0, 0.12, 1.2, -2.0)
	Pickup.spawn(global_position + Vector3(0, 0.6, 0), "food", 1 if kind == "chicken" else 2)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3(1.2, 0.05, 1.2), 0.2)
	tw.tween_callback(queue_free)
