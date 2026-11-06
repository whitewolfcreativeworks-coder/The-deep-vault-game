extends Node3D
class_name LightningBubble
## Mr. Bubbles blows these: crackling bubbles that drift after you. Hit one to
## pop it. If it reaches you it either zaps you or traps you in a bubble that
## floats you up: tap ATTACK three times to break out.

var hp := 1.0
var dead := false
var hit_radius := 0.9
var trap := false
var _t := 0.0
var _caught := false
var _taps := 0
var _player: Node3D
var _shell: MeshInstance3D
var _mat: StandardMaterial3D
var dmg := 30.0

static func blow(parent: Node, at: Vector3, damage: float) -> LightningBubble:
	var b := LightningBubble.new()
	b.dmg = damage
	b.trap = randf() < 0.45
	parent.add_child(b)
	b.global_position = at
	return b

func _ready() -> void:
	add_to_group("damageable")
	_shell = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.8; sm.height = 1.6
	_shell.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := Color(0.75, 0.9, 1.0) if trap else Color(1.0, 0.92, 0.35)
	_mat.albedo_color = Color(c.r, c.g, c.b, 0.3); _mat.emission_enabled = true; _mat.emission = c; _mat.emission_energy_multiplier = 1.2
	_mat.roughness = 0.05
	_shell.material_override = _mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	var sp := CPUParticles3D.new(); sp.amount = 16; sp.lifetime = 0.4
	sp.mesh = FX.quad(0.08); sp.material_override = FX.glow_material(Color(1.0, 0.95, 0.4), 3.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.7
	sp.gravity = Vector3.ZERO; sp.initial_velocity_min = 0.5; sp.initial_velocity_max = 1.5; sp.spread = 180
	add_child(sp)
	_player = get_tree().get_first_node_in_group("player")

func take_damage(_amount: float, _from: Vector3, _knock := 0.0, _crit := false) -> void:
	_pop(false)

func _pop(zap: bool) -> void:
	if dead:
		return
	dead = true
	remove_from_group("damageable")
	if _caught and _player:
		_player.lift = -999.0
	Sfx.play_at("pop", global_position, -2.0, 0.15)
	FX.burst(global_position, Color(1.0, 0.95, 0.5) if not trap else Color(0.8, 0.95, 1.0), 30, 4.0, 0.12, 0.5, 0.0)
	if zap and _player and _player.has_method("take_damage"):
		FX.beam(global_position, _player.global_position + Vector3(0, 1, 0), Color(1.0, 0.95, 0.4), 0.15, 0.25)
		_player.take_damage(dmg, global_position, 3.0)
	queue_free()

func _process(delta: float) -> void:
	if dead or _player == null or not is_instance_valid(_player):
		return
	_t += delta
	var target: Vector3 = _player.global_position + Vector3(0, 1.0, 0)
	if _caught:
		global_position = target
		_shell.scale = Vector3.ONE * 1.5
		if Input.is_action_just_pressed("attack"):
			_taps += 1
			_shell.scale = Vector3.ONE * (1.5 + 0.1 * _taps)
		if _taps >= 3 or _t > 3.5 or _player.get("dead") == true:
			_pop(false)
		return
	var to := target - global_position
	global_position += to.normalized() * minf(to.length(), 2.4 * delta)
	_shell.scale = Vector3.ONE * (1.0 + sin(_t * 6.0) * 0.05)
	if to.length() < 1.1:
		if trap and _player.get("dead") != true:
			_caught = true; _t = 0.0
			_player.lift = 2.2
			Game.say("Trapped in a bubble! Tap ATTACK to pop it!", Color(0.8, 0.95, 1.0))
			Sfx.play("pop", -8.0, 0.2)
		else:
			_pop(true)
	elif _t > 10.0:
		_pop(false)
