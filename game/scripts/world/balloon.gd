extends Node3D
class_name BalloonRide
## A striped hot air balloon on a wooden launch deck in the Goblin Forest.
## Climb in (USE), then:
##   JUMP (hold)   fire the burner and rise (on the iPad the button says LIFT and
##                 glows yellow while you're in the basket)
##   DODGE (hold)  let air out and sink faster (otherwise it sinks slowly)
##   move          drift where the camera points
##   USE / ATTACK  on the ground: step out. Up in the air: hop out! A little striped
##                 parachute floats you gently down, and the empty balloon sinks
##                 slowly and comes to rest wherever it lands (Jason, Nov 22).
## The basket is solid: it bumps against walls, rocks and trees, climbs gentle rises
## and lands on anything, even the mountain tops in the corners of the forest. In
## the basket your weapon and shield are put away, so nothing pokes through it.

const MAX_Y := 85.0
const BOX := Vector3(1.4, 0.9, 1.4)      # the basket, for bumping into things
const BOX_UP := 0.55                     # its centre above the basket floor
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
var _q: PhysicsShapeQueryParameters3D
var _stripes: ShaderMaterial

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
	_stripes = em
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
	var box := BoxShape3D.new(); box.size = BOX
	_q = PhysicsShapeQueryParameters3D.new()
	_q.shape = box
	_q.collision_mask = 1

func can_interact() -> bool:
	return _rider == null and _cool <= 0.0

func get_prompt() -> String:
	return "[E] Ride the hot air balloon!"

func interact(by: Node) -> void:
	if not (by is Player) or _rider != null:
		return
	_rider = by as Player
	_rider.ride_vehicle(self, "")
	_rider.show_gear(false)
	_vel = Vector3.ZERO
	_hint_t = 0.0
	Game.say("Up, up and away! Hold %s to fire the burner, DODGE to sink, move to steer. USE or ATTACK to get out (up high you hop out with a parachute)." % ("LIFT" if Game.touch_active else "JUMP"), Color(1.0, 0.85, 0.5))

func riding() -> bool:
	return _rider != null

func _cast(at: Vector3, motion: Vector3) -> float:
	_q.transform = Transform3D(Basis(Vector3.UP, rotation.y), at + Vector3(0, BOX_UP, 0))
	_q.motion = motion
	return get_world_3d().direct_space_state.cast_motion(_q)[0]

func _inside(at: Vector3) -> bool:
	_q.transform = Transform3D(Basis(Vector3.UP, rotation.y), at + Vector3(0, BOX_UP, 0))
	_q.motion = Vector3.ZERO
	return not get_world_3d().direct_space_state.intersect_shape(_q, 1).is_empty()

## Move the basket by `motion`, bumping into whatever is in the way: it climbs a
## gentle rise, slides along a wall or a cliff, and comes to rest on whatever is
## below it. Returns true when it's resting on something.
func _move(motion: Vector3) -> bool:
	var at := global_position
	var k := 0
	while k < 16 and _inside(at):         # (never stuck inside anything: pop up out of it)
		at.y += 0.25
		k += 1
	var h := Vector3(motion.x, 0, motion.z)
	var t := at + h
	t.x = clampf(t.x, -bound, bound)
	t.z = clampf(t.z, -bound, bound)
	h = Vector3(t.x - at.x, 0, t.z - at.z)
	if h.length_squared() > 1e-8:
		if _cast(at, h) >= 1.0:
			at += h
		else:
			# a rise no steeper than 45 degrees: up and over it
			var up := Vector3(0, h.length() + 0.05, 0)
			var fu := _cast(at, up)
			if fu >= 1.0 and _cast(at + up, h) >= 1.0:
				at += up + h
			else:
				# a wall: slide along it
				for part in [Vector3(h.x, 0, 0), Vector3(0, 0, h.z)]:
					var f := _cast(at, part)
					at += part * f
	var v := Vector3(0, motion.y, 0)
	if at.y + v.y > MAX_Y:
		v.y = minf(MAX_Y - at.y, 0.0)
	var rest := false
	if v.y != 0.0:
		var fv := _cast(at, v)
		at += v * fv
		rest = v.y < 0.0 and fv < 1.0
	if not rest:
		rest = _cast(at, Vector3(0, -0.08, 0)) < 1.0
	global_position = at
	return rest

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
		if is_instance_valid(_rider):
			_rider.show_gear(true)
		_rider = null
		_landed = false
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
	var before := global_position
	_landed = _move(_vel * delta)
	if _landed:
		_vel.y = maxf(_vel.y, 0.0)
	if delta > 0.0:
		var moved := (global_position - before) / delta
		_vel.x = moved.x if absf(moved.x) < absf(_vel.x) else _vel.x     # (bumped: lose that speed)
		_vel.z = moved.z if absf(moved.z) < absf(_vel.z) else _vel.z
	# a gentle sway while flying
	var fly := 0.0 if _landed else 1.0
	_vis.rotation.x = lerpf(_vis.rotation.x, (sin(_sway * 0.9) * 0.03 - _vel.z * 0.01) * fly, 1.0 - exp(-2.0 * delta))
	_vis.rotation.z = lerpf(_vis.rotation.z, (cos(_sway * 0.7) * 0.03 + _vel.x * 0.01) * fly, 1.0 - exp(-2.0 * delta))
	# the rider stands in the basket, facing where they look
	_rider.global_position = global_position + Vector3(0, 0.1, 0)
	_rider.facing = _rider.view_yaw
	_rider.body.rotation.y = _rider.facing
	_hint_t += delta
	if (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")) and _hint_t > 0.4:
		hop_out()

## Empty: it sinks slowly, drifting to a stop, and rests wherever it comes down.
func _descend_only(delta: float) -> void:
	_vel.x = lerpf(_vel.x, 0.0, 1.0 - exp(-0.6 * delta))
	_vel.z = lerpf(_vel.z, 0.0, 1.0 - exp(-0.6 * delta))
	_landed = _move(Vector3(_vel.x, -2.0, _vel.z) * delta)
	if _landed:
		_vel = Vector3.ZERO

func _set_burner(on: bool) -> void:
	if on == _burn:
		return
	_burn = on
	_flame.emitting = on
	_flame_light.light_energy = 3.5 if on else 0.0
	if _roar:
		_roar.volume_db = -6.0 if on else -60.0

## Out of the basket: on the ground you step out; up in the air you hop over the
## side and a little parachute floats you down.
func hop_out() -> void:
	if _rider == null:
		return
	if _landed:
		_step_out()
		return
	var r := _rider
	_rider = null
	_cool = 1.5
	_set_burner(false)
	r.show_gear(true)
	var side := Vector3(cos(r.view_yaw), 0, -sin(r.view_yaw))
	r.leave_vehicle(side * 2.5 + Vector3(0, 3.0, 0))
	r.global_position = global_position + side * 1.3 + Vector3(0, 1.2, 0)
	r.parachute = _parachute(r)
	Sfx.play("whistle", -10.0, 0.15)
	Game.say("Wheee! Your little parachute floats you down. The balloon will come down by itself.", Color(1.0, 0.85, 0.5))

## A small striped parachute (the balloon's own colours) over the hero's head.
func _parachute(r: Player) -> Node3D:
	var c := Node3D.new(); c.name = "Parachute"
	r.add_child(c)
	c.position = Vector3(0, 2.7, 0)
	var dome := MeshInstance3D.new(); var sm := SphereMesh.new()
	sm.radius = 1.15; sm.height = 1.15; sm.is_hemisphere = true; sm.radial_segments = 24; sm.rings = 8
	dome.mesh = sm; dome.material_override = _stripes
	dome.scale = Vector3(1.0, 0.7, 1.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(dome)
	var rope := StandardMaterial3D.new(); rope.albedo_color = Color(0.9, 0.85, 0.7)
	for a in [0.785, 2.356, 3.927, 5.498]:
		var top := Vector3(cos(a) * 1.0, 0.0, sin(a) * 1.0)
		var bot := Vector3(cos(a) * 0.25, -1.45, sin(a) * 0.25)
		var line := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = top.distance_to(bot); cm.radial_segments = 4
		line.mesh = cm; line.material_override = rope
		line.position = (top + bot) * 0.5
		line.basis = Basis(Quaternion(Vector3.UP, (top - bot).normalized()))
		c.add_child(line)
	c.scale = Vector3.ONE * 0.2
	c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	return c

func _step_out() -> void:
	var r := _rider
	_rider = null
	_cool = 1.0
	_set_burner(false)
	r.show_gear(true)
	var side := Vector3(cos(r.view_yaw), 0, -sin(r.view_yaw))
	var out := global_position + side * 1.8 + Vector3(0, 1.0, 0)
	r.leave_vehicle()
	r.global_position = out
	Game.say("You step out of the basket.", Color(0.9, 0.85, 0.7))
