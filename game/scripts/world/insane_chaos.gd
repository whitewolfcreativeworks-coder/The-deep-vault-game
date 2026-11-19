extends Node
class_name InsaneChaos
## INSANE MODE's kitchen sink: every 15-25 seconds something wild happens (and
## sometimes two things at once), announced in big rainbow letters. Most last a few seconds; you can still play
## through all of them, but they make an already hard mode crazy.
##   RAINBOW STORM   rainbow vision without the mushrooms
##   MOON GRAVITY    huge floaty jumps (and falls)
##   MIRROR WORLD    left is right and right is left!
##   BOING BOING     you bounce every time you land
##   SPEED FREAK     you run super fast
##   METEOR SHOWER   fireballs crash down: watch for the red circles
##   CHICKEN PARTY   a flock of chickens bursts out of nowhere
##   MONSTER PARTY   more monsters climb out of the ground
##   DISCO TIME      the lights go disco
##   GOLD RAIN       coins pour out of the sky (a nice one)
##   GIANT FOES      every monster nearby grows huge

const EVENTS := ["rainbow", "moon", "mirror", "boing", "speed", "meteors", "chickens", "monsters", "disco", "gold", "giants"]
const NAMES := {"rainbow": "RAINBOW STORM!", "moon": "MOON GRAVITY!", "mirror": "MIRROR WORLD!", "boing": "BOING BOING!",
	"speed": "SPEED FREAK!", "meteors": "METEOR SHOWER!", "chickens": "CHICKEN PARTY!", "monsters": "MONSTER PARTY!",
	"disco": "DISCO TIME!", "gold": "GOLD RAIN!", "giants": "GIANT FOES!"}
const HINTS := {"rainbow": "Everything's gone wobbly...", "moon": "Jump! Wheee!", "mirror": "Left is right and right is left!",
	"boing": "You can't stop bouncing!", "speed": "Zoom zoom!", "meteors": "Get out of the red circles!",
	"chickens": "Bawk bawk BAWK!", "monsters": "They're climbing out of the ground!", "disco": "Dance while you fight!",
	"gold": "Grab the coins!", "giants": "Everything near you got BIG!"}

var player: Player
var world: Node3D
var next_t := 8.0
var last := ""
var events_fired := 0
var _ui: CanvasLayer
var _label: Label
var _disco: Array = []
var _disco_t := 0.0
var _undo: Array = []            # [time left, Callable]
var _rng := RandomNumberGenerator.new()
var _tw: Tween

func _ready() -> void:
	_rng.randomize()
	_ui = CanvasLayer.new(); _ui.layer = 6; add_child(_ui)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_font_override("font", SignText.font())
	_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	_label.add_theme_constant_override("outline_size", 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -600; _label.offset_right = 600; _label.offset_top = 150
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.modulate.a = 0.0
	_ui.add_child(_label)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or get_tree().paused:
		return
	for u in _undo.duplicate():
		u[0] -= delta
		if u[0] <= 0.0:
			(u[1] as Callable).call()
			_undo.erase(u)
	if _label.modulate.a > 0.0:
		_label.add_theme_color_override("font_color", Color.from_hsv(fmod(Time.get_ticks_msec() * 0.0006, 1.0), 0.6, 1.0))
	if _disco_t > 0.0:
		_disco_t -= delta
		for i in _disco.size():
			var l: OmniLight3D = _disco[i]
			if is_instance_valid(l):
				var a := Time.get_ticks_msec() * 0.003 + i * TAU / _disco.size()
				l.global_position = player.global_position + Vector3(cos(a) * 4.0, 2.5, sin(a) * 4.0)
				l.light_color = Color.from_hsv(fmod(a * 0.3, 1.0), 0.9, 1.0)
		if _disco_t <= 0.0:
			for l in _disco:
				if is_instance_valid(l):
					l.queue_free()
			_disco.clear()
	if player.dead or player.vehicle != null or not player.input_enabled:
		return
	next_t -= delta
	if next_t <= 0.0:
		next_t = _rng.randf_range(14.0, 24.0)
		var pick := last
		while pick == last:
			pick = EVENTS[_rng.randi() % EVENTS.size()]
		fire(pick)
		if _rng.randf() < 0.3:       # double trouble!
			var two := pick
			while two == pick:
				two = EVENTS[_rng.randi() % EVENTS.size()]
			fire(two, true)

## Set something off now (the tests use this too).
func fire(ev: String, also := false) -> void:
	if not also:
		last = ev
	events_fired += 1
	if also:
		_label.text = _label.text.get_slice("\n", 0) + " + " + String(NAMES[ev]) + "\nDOUBLE TROUBLE!"
		_label.add_theme_font_size_override("font_size", 46)
	else:
		_label.text = "INSANE: %s\n%s" % [NAMES[ev], HINTS[ev]]
		_label.add_theme_font_size_override("font_size", 64)
	if _tw and _tw.is_valid():
		_tw.kill()
	var tw := _label.create_tween()
	_tw = tw
	tw.tween_property(_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.8)
	tw.tween_property(_label, "modulate:a", 0.0, 0.6)
	Sfx.play("portal", -4.0, 0.2)
	FX.screen_flash(Color.from_hsv(_rng.randf(), 0.5, 1.0), 0.4, 0.5)
	var p := player
	match ev:
		"rainbow":
			Game.shroom = maxf(Game.shroom, 3.4)
		"moon":
			p.chaos_gravity = 0.3
			_later(16.0, func() -> void: p.chaos_gravity = 1.0)
		"mirror":
			p.mirror_t = 10.0
		"boing":
			p.bouncy_t = 12.0
		"speed":
			p.haste_t = maxf(p.haste_t, 14.0)
		"meteors":
			for k in 14:
				get_tree().create_timer(0.35 + k * 0.55).timeout.connect(_meteor)
		"chickens":
			for k in 9:
				var a := k * TAU / 9.0
				var at := p.global_position + Vector3(cos(a), 0.5, sin(a)) * 3.0
				Fowl.make(world, at, "turkey" if k % 3 == 0 else "chicken", 9.0)
			Sfx.play("cluck", -2.0, 0.2)
		"monsters":
			_monster_party()
		"disco":
			_disco_t = 14.0
			for k in 4:
				var l := OmniLight3D.new(); l.light_energy = 3.0; l.omni_range = 9.0
				world.add_child(l)
				_disco.append(l)
		"gold":
			for k in 16:
				get_tree().create_timer(k * 0.18).timeout.connect(func() -> void:
					if is_instance_valid(p):
						var at2 := p.global_position + Vector3(_rng.randf_range(-5, 5), 0.6, _rng.randf_range(-5, 5))
						Pickup.spawn(at2, "gold", _rng.randi_range(3, 9))
						FX.burst(at2 + Vector3(0, 3, 0), Color(1.0, 0.85, 0.3), 8, 3.0, 0.1, 0.5, -6.0))
		"giants":
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and (e as Enemy).global_position.distance_to(p.global_position) < 30.0 and not (e as Enemy).dead:
					var en := e as Enemy
					en.body.scale *= 1.45
					en.max_hp *= 1.4
					en.hp *= 1.4
					en.hit_radius *= 1.4

func _later(sec: float, fn: Callable) -> void:
	_undo.append([sec, fn])

## A fireball crashes down: a red circle shows where, a moment before.
func _meteor() -> void:
	if player == null or not is_instance_valid(player):
		return
	var at := player.global_position + Vector3(_rng.randf_range(-7, 7), 0.05, _rng.randf_range(-7, 7))
	var ring := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.4; cm.bottom_radius = 2.4; cm.height = 0.04
	ring.mesh = cm; ring.material_override = FX.beam_material(Color(1.0, 0.2, 0.1), 1.0, 0.45, false)
	world.add_child(ring); ring.global_position = at
	var rock := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2
	rock.mesh = sm; rock.material_override = FX.beam_material(Color(1.0, 0.45, 0.1), 2.0, 1.0, false)
	world.add_child(rock); rock.global_position = at + Vector3(4, 26, 3)
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", at, 1.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		FX.burst(at + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.15), 50, 7.0, 0.25, 0.8, -6.0)
		Sfx.play_at("fire_burst", at, -2.0, 0.2)
		if is_instance_valid(player) and Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < 2.4 and absf(player.global_position.y - at.y) < 2.5:
			player.take_damage(16.0 * Game.foe_scale().y, at, 5.0)
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and (e as Enemy).global_position.distance_to(at) < 2.4:
				(e as Enemy).take_damage(60.0, at, 4.0)
		ring.queue_free()
		rock.queue_free())

## Four more of whatever monster lives nearest climb out of the ground.
func _monster_party() -> void:
	var best: Enemy = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and not (e as Enemy).dead and not bool((e as Enemy).t.get("heavy", false)):
			var d := (e as Enemy).global_position.distance_to(player.global_position)
			if d < bd:
				bd = d; best = e
	var kind := best.type_id if best and bd < 80.0 else "minion"
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var e2 := Enemy.new()
		e2.configure(kind, "", 6.0)
		world.add_child(e2)
		e2.global_position = player.global_position + Vector3(cos(a) * 4.5, 0.2, sin(a) * 4.5)
