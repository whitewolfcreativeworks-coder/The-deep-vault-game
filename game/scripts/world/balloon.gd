extends Node3D
class_name BalloonRide
## A striped hot air balloon on a wooden launch deck in the Goblin Forest.
## Climb in (USE), then:
##   JUMP (hold)   fire the burner and rise
##   DODGE (hold)  let air out and sink faster (otherwise it sinks slowly)
##   move          drift where the camera points
##   USE           step out once the basket is on the ground
## It lands anywhere and waits there until you ride it again.

const MAX_Y := 85.0
var bound := 112.0
var _rider: Player
var _vel := Vector3.ZERO
var _landed := true
var _burn := false
var _vis: Node3D
var _flame: CPUParticles3D
var _flame_light: OmniLight3D
var _roar: AudioStreamPlayer3D
var _hint_t := 0.0
var _cool := 0.0
var _sway := 0.0

static func make(parent: Node3D, pos: Vector3, yaw := 0.0) -> BalloonRide:
	var b := BalloonRide.new()
	b.name = "HotAirBalloon"
	parent.add_child(b)
	b.global_position = pos
	b.rotation.y = yaw
	b._build()
	return b

func _build() -> void:
	add_to_group("interactable")
	process_physics_priority = 100
	_vis = Node3D.new(); add_child(_vis)
	# wicker basket
	var wicker := StandardMaterial3D.new(); wicker.albedo_color = Color(0.62, 0.43, 0.22); wicker.roughness = 0.95
	var rim := StandardMaterial3D.new(); rim.albedo_color = Color(0.42, 0.26, 0.12); rim.roughness = 0.8
	for s in [[Vector3(1.5, 1.0, 0.1), Vector3(0, 0.5, -0.7)], [Vector3(1.5, 1.0, 0.1), Vector3(0, 0.5, 0.7)],
			[Vector3(0.1, 1.0, 1.5), Vector3(-0.7, 0.5, 0)], [Vector3(0.1, 1.0, 1.5), Vector3(0.7, 0.5, 0)],
			[Vector3(1.5, 0.08, 1.5), Vector3(0, 0.04, 0)]]:
		Playground.box(_vis, s[0], wicker, s[1])
	for s in [[Vector3(1.62, 0.12, 0.16), Vector3(0, 1.04, -0.72)], [Vector3(1.62, 0.12, 0.16), Vector3(0, 1.04, 0.72)],
			[Vector3(0.16, 0.12, 1.62), Vector3(-0.72, 1.04, 0)], [Vector3(0.16, 0.12, 1.62), Vector3(0.72, 1.04, 0)]]:
		Playground.box(_vis, s[0], rim, s[1])
	# ropes up to the envelope, the burner, and the envelope with its stripes
	var rope := StandardMaterial3D.new(); rope.albedo_color = Color(0.85, 0.8, 0.65)
	for c in [Vector3(-0.68, 0, -0.68), Vector3(0.68, 0, -0.68), Vector3(-0.68, 0, 0.68), Vector3(0.68, 0, 0.68)]:
		var top: Vector3 = c * 1.9 + Vector3(0, 4.0, 0)
		var bot: Vector3 = c + Vector3(0, 1.1, 0)
		var mid := (top + bot) * 0.5
		var r := Playground.cyl(_vis, 0.025, 0.025, top.distance_to(bot), rope, mid)
		r.basis = Basis(Quaternion(Vector3.UP, (top - bot).normalized()))
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.15, 0.15, 0.17); iron.metallic = 0.7; iron.roughness = 0.4
	Playground.cyl(_vis, 0.18, 0.22, 0.35, iron, Vector3(0, 2.6, 0))
	var env := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 3.6; sm.height = 8.4
	sm.radial_segments = 32; sm.rings = 16
	env.mesh = sm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 col_a : source_color = vec4(0.9, 0.18, 0.15, 1.0);
uniform vec4 col_b : source_color = vec4(1.0, 0.82, 0.2, 1.0);
uniform vec4 band : source_color = vec4(0.2, 0.4, 0.9, 1.0);
void fragment() {
	float s = step(0.5, fract(UV.x * 12.0));
	vec3 c = mix(col_a.rgb, col_b.rgb, s);
	float b = smoothstep(0.43, 0.45, UV.y) * (1.0 - smoothstep(0.5, 0.52, UV.y));
	ALBEDO = mix(c, band.rgb, b);
	ROUGHNESS = 0.7;
}
"""
	var em := ShaderMaterial.new(); em.shader = sh
	env.material_override = em
	env.position = Vector3(0, 7.7, 0)
	_vis.add_child(env)
	var skirt := Playground.cyl(_vis, 1.05, 0.55, 1.0, em, Vector3(0, 4.0, 0))
	skirt.name = "Skirt"
	_flame = CPUParticles3D.new(); _flame.amount = 40; _flame.lifetime = 0.45; _flame.emitting = false
	_flame.mesh = FX.quad(0.35); _flame.material_override = FX.glow_material(Color(1.0, 0.55, 0.15), 3.0)
	_flame.direction = Vector3.UP; _flame.spread = 8; _flame.initial_velocity_min = 4.0; _flame.initial_velocity_max = 6.0
	_flame.gravity = Vector3.ZERO; _flame.color_ramp = FX._fade_ramp(Color(1.0, 0.6, 0.2))
	_flame.position = Vector3(0, 2.8, 0); _vis.add_child(_flame)
	_flame_light = OmniLight3D.new(); _flame_light.light_color = Color(1.0, 0.6, 0.25); _flame_light.light_energy = 0.0
	_flame_light.omni_range = 9.0; _flame_light.position = Vector3(0, 4.5, 0); _vis.add_child(_flame_light)
	_roar = Sfx.loop_on(self, "loop_fire", -60.0, 4.0, 30.0)
	if _roar:
		_roar.position = Vector3(0, 3.0, 0)

func can_interact() -> bool:
	return _rider == null and _cool <= 0.0

func get_prompt() -> String:
	return "[E] Ride the hot air balloon!"

func interact(by: Node) -> void:
	if not (by is Player) or _rider != null:
		return
	_rider = by as Player
	_rider.ride_vehicle(self, "")
	_vel = Vector3.ZERO
	_hint_t = 0.0
	Game.say("Up, up and away! Hold JUMP to fire the burner, DODGE to sink, move to steer. Land and press USE to step out.", Color(1.0, 0.85, 0.5))

func riding() -> bool:
	return _rider != null

func _floor_y() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 3.0, 0), global_position - Vector3(0, 60.0, 0), 1)
	if _rider:
		q.exclude = [_rider.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else global_position.y - 60.0

func _physics_process(delta: float) -> void:
	_cool -= delta
	_sway += delta
	if _rider == null:
		_set_burner(false)
		_vis.rotation = _vis.rotation.lerp(Vector3.ZERO, 1.0 - exp(-2.0 * delta))
		# an empty balloon left in the air drifts back down
		if not _landed:
			_descend_only(delta)
		return
	if not is_instance_valid(_rider) or _rider.dead or _rider.vehicle != self:
		_rider = null
		return
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, _rider.view_yaw)
	var burn := Input.is_action_pressed("jump")
	var vent := Input.is_action_pressed("dodge") or Input.is_action_pressed("block")
	_set_burner(burn)
	var want_vy := 3.6 if burn else (-4.5 if vent else -0.9)
	var want_h := dir * 6.5
	if _landed and not burn:
		want_h = Vector3.ZERO     # a basket on the ground doesn't skid around
	_vel.x = lerpf(_vel.x, want_h.x, 1.0 - exp(-1.2 * delta))
	_vel.z = lerpf(_vel.z, want_h.z, 1.0 - exp(-1.2 * delta))
	_vel.y = lerpf(_vel.y, want_vy, 1.0 - exp(-1.5 * delta))
	var p := global_position + _vel * delta
	p.x = clampf(p.x, -bound, bound)
	p.z = clampf(p.z, -bound, bound)
	p.y = minf(p.y, MAX_Y)
	global_position = p
	var fy := _floor_y()
	_landed = false
	if global_position.y <= fy + 0.02:
		global_position.y = fy
		_vel.y = maxf(_vel.y, 0.0)
		_landed = true
	# a gentle sway while flying
	var fly := 0.0 if _landed else 1.0
	_vis.rotation.x = lerpf(_vis.rotation.x, (sin(_sway * 0.9) * 0.03 - _vel.z * 0.01) * fly, 1.0 - exp(-2.0 * delta))
	_vis.rotation.z = lerpf(_vis.rotation.z, (cos(_sway * 0.7) * 0.03 + _vel.x * 0.01) * fly, 1.0 - exp(-2.0 * delta))
	# the rider stands in the basket, facing where they look
	_rider.global_position = global_position + Vector3(0, 0.1, 0)
	_rider.facing = _rider.view_yaw
	_rider.body.rotation.y = _rider.facing
	_hint_t += delta
	if Input.is_action_just_pressed("interact") and _hint_t > 0.4:
		if _landed:
			_step_out()
		else:
			Game.say("Land first! Hold DODGE (C) to come down.", Color(1.0, 0.8, 0.5))

func _descend_only(delta: float) -> void:
	global_position.y -= 2.0 * delta
	var fy := _floor_y()
	if global_position.y <= fy:
		global_position.y = fy
		_landed = true

func _set_burner(on: bool) -> void:
	if on == _burn:
		return
	_burn = on
	_flame.emitting = on
	_flame_light.light_energy = 3.5 if on else 0.0
	if _roar:
		_roar.volume_db = -6.0 if on else -60.0

func _step_out() -> void:
	var r := _rider
	_rider = null
	_cool = 1.0
	_set_burner(false)
	var side := Vector3(cos(r.view_yaw), 0, -sin(r.view_yaw))
	var out := global_position + side * 1.8 + Vector3(0, 1.0, 0)
	r.leave_vehicle()
	r.global_position = out
	Game.say("You step out of the basket.", Color(0.9, 0.85, 0.7))
