extends Node3D
class_name BubbleTrap
## Mr. Bubbles' signature move: he blows a big rainbow bubble at you. Dodge it,
## or hit it to pop it. If it reaches you, you're inside it and it floats you
## up high over the thunderhead. Tap ATTACK (or JUMP) to pop it and drop back
## down to keep fighting... but the longer you wait, the further it drifts
## towards the edge.

signal popped

var hp := 1.0
var dead := false
var hit_radius := 1.2
var _player: Player
var _t := 0.0
var _caught := false
var _taps := 0
var _need := 4
var _rise_to := 0.0
var _drift := Vector3.ZERO
var _shell: MeshInstance3D
var _mat: ShaderMaterial
var _label: Label3D
var _speed := 9.0
var _sure := false          # INSANE Mr. Bubbles: it keeps coming until it gets you
const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")

static func blow(parent: Node, at: Vector3, p: Player, taps := 4) -> BubbleTrap:
	var b := BubbleTrap.new()
	b._player = p
	b._need = taps
	parent.add_child(b)
	b.global_position = at
	return b

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("bubble_trap")
	_shell = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
	sm.radial_segments = 32; sm.rings = 16
	_shell.mesh = sm
	_mat = ShaderMaterial.new(); _mat.shader = BUBBLE_SHADER
	_shell.material_override = _mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	var sp := CPUParticles3D.new(); sp.amount = 18; sp.lifetime = 1.0
	sp.mesh = FX.quad(0.09); sp.material_override = FX.glow_material(Color(0.9, 0.95, 1.0), 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 1.0
	sp.gravity = Vector3.ZERO; sp.initial_velocity_min = 0.2; sp.initial_velocity_max = 0.6; sp.spread = 180
	add_child(sp)
	_label = Label3D.new(); _label.font_size = 72; _label.pixel_size = 0.006; _label.outline_size = 16
	_label.modulate = Color(1.0, 1.0, 0.75); _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _label.no_depth_test = true
	_label.position.y = 2.6; _label.visible = false
	add_child(_label)
	Sfx.play_at("pop", global_position, -6.0, 0.4)

## INSANE Mr. Bubbles' bubble: you can't pop it on the way in, it homes in on
## you all the way (a dodge roll only buys a moment), and once you're inside you
## CHOP it `taps` times to pop it (Jason, Nov 23: "you have to chop the bubble
## three times to pop it to fall to the ground").
func make_sure(taps := 3) -> void:
	_sure = true
	_need = taps
	_speed = 8.0

## Your attacks pop it before it gets you (but not Insane Mr. Bubbles' one).
func take_damage(_amount: float, _from: Vector3, _knock := 0.0, _crit := false) -> void:
	if not _caught and not _sure:
		_pop()

func caught() -> bool:
	return _caught

func _pop() -> void:
	if dead:
		return
	dead = true
	remove_from_group("damageable")
	if _caught and _player and is_instance_valid(_player):
		_player.lift = -999.0
		_player.wind = Vector3.ZERO
		if _player.float_hold == self:
			_player.float_hold = null
	Sfx.play_at("pop", global_position, 0.0, 0.1)
	FX.burst(global_position, Color(0.85, 0.95, 1.0), 50, 5.0, 0.15, 0.7, 0.0)
	for k in 6:
		FX.burst(global_position + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), Color.from_hsv(k / 6.0, 0.5, 1.0), 6, 2.0, 0.1, 0.4, 0.0)
	popped.emit()
	queue_free()

func _physics_process(delta: float) -> void:
	if dead or _player == null or not is_instance_valid(_player):
		if not dead:
			_pop()
		return
	_t += delta
	var chest := _player.global_position + Vector3(0, 1.0, 0)
	if not _caught:
		# fly at you, homing a little (a dodge roll gets you out of the way)
		var to := chest - global_position
		if _t < 1.4 or _sure:
			_drift = to.normalized() * _speed       # it stops steering after a moment: dodge it!
		global_position += _drift * delta
		_shell.scale = Vector3.ONE * (1.0 + sin(_t * 7.0) * 0.05)
		if to.length() < 1.3 and not _player.dead and not _player.dodging:
			_catch()
		elif _t > (8.0 if _sure else 4.0):
			_pop()
		return
	# you're inside: up you go, drifting
	global_position = chest
	_shell.scale = Vector3.ONE * (1.35 + sin(_t * 5.0) * 0.04 + _taps * 0.06)
	var below := _rise_to - _player.global_position.y
	_player.lift = clampf(below * 0.9, 0.2, 5.0)
	var push := Vector3.ZERO
	if get_parent().has_method("arena_push"):
		push = get_parent().arena_push(_player.global_position)
	_player.wind = _drift + push
	_player.velocity.x = lerpf(_player.velocity.x, _drift.x, 0.1)
	_player.velocity.z = lerpf(_player.velocity.z, _drift.z, 0.1)
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
		_taps += 1
		Sfx.play("pop", -14.0, 0.4)
		FX.burst(global_position, Color(0.9, 0.95, 1.0), 8, 2.0, 0.08, 0.3, 0.0)
	_label.text = ("CHOP IT!  %d" if _sure else "TAP ATTACK!  %d") % maxi(0, _need - _taps)
	if _taps >= _need or _t > 7.0 or _player.dead:
		_pop()

func _catch() -> void:
	_caught = true
	_t = 0.0
	remove_from_group("damageable")        # your sword can't pop it from inside: tap!
	_rise_to = _player.global_position.y + 9.0
	var a := randf() * TAU
	_drift = Vector3(cos(a), 0, sin(a)) * 1.4
	_player.float_hold = self
	if _player.mounted:
		_player.dismount()
	_label.visible = true
	Sfx.play("pop", -4.0, 0.0)
	if _sure:
		Game.say("Caught in a bubble! CHOP it %d times (ATTACK) to pop it!" % _need, Color(0.85, 0.95, 1.0))
	else:
		Game.say("Floating away in a bubble! TAP ATTACK (or JUMP) to pop it!", Color(0.85, 0.95, 1.0))
