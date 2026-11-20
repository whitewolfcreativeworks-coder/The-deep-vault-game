extends Node
class_name InsaneChaos
## INSANE MODE's kitchen sink: every 12-20 seconds something wild happens (and
## sometimes two things at once), announced in big rainbow letters, with a little
## countdown at the top of the screen while it lasts. None of them add monsters
## (more monsters = lag on tablets): they change the world, you, or the monsters
## that are already there.
##   RAINBOW STORM   rainbow vision without the mushrooms
##   MOON GRAVITY    huge floaty jumps (and falls)
##   BOING BOING     you bounce every time you land
##   SPEED FREAK     you run super fast
##   METEOR SHOWER   fireballs crash down: watch for the red circles
##   CHICKEN PARTY   a few chickens burst out of nowhere
##   MONSTER RAGE    every monster near you goes into a rage and comes for you
##   DISCO TIME      the lights go disco
##   GOLD RAIN       coins pour out of the sky (a nice one)
##   GIANT FOES      every monster nearby grows huge
##   EARTHQUAKE      the ground shakes and shoves you about
##   BULLET TIME     the monsters slow right down (you don't!)
##   SLIPPERY ICE    the ground turns to ice: you slide everywhere
##   GHOST MONSTERS  the monsters flicker in and out of sight

const EVENTS := ["rainbow", "moon", "boing", "speed", "meteors", "chickens", "rage", "disco", "gold", "giants",
	"quake", "slowmo", "slippery", "ghosts"]
const NAMES := {"rainbow": "RAINBOW STORM!", "moon": "MOON GRAVITY!", "boing": "BOING BOING!",
	"speed": "SPEED FREAK!", "meteors": "METEOR SHOWER!", "chickens": "CHICKEN PARTY!", "rage": "MONSTER RAGE!",
	"disco": "DISCO TIME!", "gold": "GOLD RAIN!", "giants": "GIANT FOES!", "quake": "EARTHQUAKE!", "slowmo": "BULLET TIME!",
	"slippery": "SLIPPERY ICE!", "ghosts": "GHOST MONSTERS!"}
const HINTS := {"rainbow": "Everything's gone wobbly...", "moon": "Jump! Wheee!",
	"boing": "You can't stop bouncing!", "speed": "Zoom zoom!", "meteors": "Get out of the red circles!",
	"chickens": "Bawk bawk BAWK!", "rage": "They're ALL coming for you!", "disco": "Dance while you fight!",
	"gold": "Grab the coins!", "giants": "Everything near you got BIG!", "quake": "Hold on tight!",
	"slowmo": "The monsters are in slow motion. Get 'em!", "slippery": "Whoa! Careful...", "ghosts": "Now you see them, now you don't!"}
## The little countdown names.
const SHORT := {"moon": "MOON GRAVITY", "boing": "BOING", "speed": "SPEED", "disco": "DISCO",
	"quake": "EARTHQUAKE", "slowmo": "BULLET TIME", "slippery": "ICE", "ghosts": "GHOSTS"}

var player: Player
var world: Node3D
var next_t := 6.0
var last := ""
var events_fired := 0
var _ui: CanvasLayer
var _label: Label
var _timers: Label
var _disco: Array = []
var _disco_t := 0.0
var _moon_t := 0.0
var _quake_t := 0.0
var _quake_kick := 0.0
var _slow_t := 0.0
var _slip_t := 0.0
var _ghost_t := 0.0
var _ghosted: Array = []
var _birds: Array = []
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
	_timers = Label.new()
	_timers.add_theme_font_size_override("font_size", 28)
	_timers.add_theme_font_override("font", SignText.font())
	_timers.add_theme_color_override("font_color", Color(1.0, 0.85, 1.0))
	_timers.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	_timers.add_theme_constant_override("outline_size", 10)
	_timers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timers.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timers.offset_left = -600; _timers.offset_right = 600; _timers.offset_top = 66
	_timers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_timers)

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.grip = 1.0
		player.chaos_gravity = 1.0

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or get_tree().paused:
		return
	if _label.modulate.a > 0.0:
		_label.add_theme_color_override("font_color", Color.from_hsv(fmod(Time.get_ticks_msec() * 0.0006, 1.0), 0.6, 1.0))
	_tick_effects(delta)
	_show_timers()
	if player.dead or player.vehicle != null or not player.input_enabled:
		return
	next_t -= delta
	if next_t <= 0.0:
		next_t = _rng.randf_range(12.0, 20.0)
		var pick := _pick(last)
		fire(pick)
		if _rng.randf() < 0.3:      # double trouble!
			fire(_pick(pick), true)

## A random event that makes sense right now (no monster events with no
## monsters about...). (Mirror World, which swapped left and right, was taken out
## for good: it made the game stressful.)
func _pick(not_this: String) -> String:
	for tries in 30:
		var ev: String = EVENTS[_rng.randi() % EVENTS.size()]
		if ev != not_this and ev != last and _makes_sense(ev):
			return ev
	return "gold"

func _makes_sense(ev: String) -> bool:
	match ev:
		"slippery":
			return Game.zone != "cloud" and _slip_t <= 0.0      # (Cloud Island has its own ice)
		"rage":
			return _foes_near(45.0).size() >= 2
		"ghosts", "slowmo", "giants":
			return _foes_near(40.0).size() >= 1
		"moon":
			return _moon_t <= 0.0
		"quake":
			return _quake_t <= 0.0
	return true

func _foes_near(r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and not (e as Enemy).dead and not (e as Enemy).asleep and (e as Enemy).state != Enemy.S.DORMANT \
				and (e as Enemy).global_position.distance_to(player.global_position) < r:
			out.append(e)
	return out

func _tick_effects(delta: float) -> void:
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
	if _moon_t > 0.0:
		_moon_t -= delta
		if _moon_t <= 0.0:
			player.chaos_gravity = 1.0
	if _quake_t > 0.0:
		_quake_t -= delta
		_quake_kick -= delta
		if _quake_kick <= 0.0:
			_quake_kick = 0.45
			player.add_trauma(0.35)
			if player.is_on_floor() and not player.mounted:
				var a := _rng.randf() * TAU
				player.velocity += Vector3(cos(a) * 4.5, 2.5, sin(a) * 4.5)
			if _rng.randf() < 0.4:
				FX.burst(player.global_position + Vector3(0, 0.2, 0), Color(0.65, 0.55, 0.4), 10, 3.0, 0.25, 0.6, -4.0)
	if _slow_t > 0.0:
		_slow_t -= delta
	if _slip_t > 0.0:
		_slip_t -= delta
		player.grip = 0.12 if _slip_t > 0.0 else 1.0
	if _ghost_t > 0.0:
		_ghost_t -= delta
		var now := Time.get_ticks_msec() * 0.001
		for i in _ghosted.size():
			var en: Enemy = _ghosted[i] if is_instance_valid(_ghosted[i]) else null
			if en == null or en.dead or en.state == Enemy.S.DORMANT or not is_instance_valid(en.body):
				continue
			en.body.visible = _ghost_t <= 0.0 or fmod(now + i * 0.37, 0.9) < 0.32
		if _ghost_t <= 0.0:
			_ghosted.clear()

func _show_timers() -> void:
	var parts: Array = []
	var vals := {"moon": _moon_t, "boing": player.bouncy_t,
		"speed": player.haste_t, "disco": _disco_t, "quake": _quake_t, "slowmo": _slow_t, "slippery": _slip_t, "ghosts": _ghost_t}
	for k in vals:
		if float(vals[k]) > 0.05:
			parts.append("%s %d" % [SHORT[k], ceili(float(vals[k]))])
	_timers.text = "   ".join(parts)
	_timers.visible = not parts.is_empty()

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
			_moon_t = 16.0
		"boing":
			p.bouncy_t = 12.0
		"speed":
			p.haste_t = maxf(p.haste_t, 14.0)
		"meteors":
			for k in 8:
				get_tree().create_timer(0.35 + k * 0.6).timeout.connect(_meteor)
		"chickens":
			# (the oldest party birds poof away so there are never more than 8)
			_birds = _birds.filter(func(x: Variant) -> bool: return is_instance_valid(x))
			while _birds.size() > 4:
				var old: Node3D = _birds.pop_front()
				FX.burst(old.global_position + Vector3(0, 0.5, 0), Color(1, 1, 1), 10, 2.0, 0.1, 0.5, 0.0)
				old.queue_free()
			for k in 4:
				var a := k * TAU / 4.0
				get_tree().create_timer(k * 0.15).timeout.connect(func() -> void:
					if is_instance_valid(p) and is_instance_valid(world):
						var at := p.global_position + Vector3(cos(a), 0.5, sin(a)) * 4.5
						_birds.append(Fowl.make(world, at, "turkey" if k % 2 == 0 else "chicken", 9.0)))
			Sfx.play("cluck", -2.0, 0.2)
		"rage":
			for e in _foes_near(45.0):
				var en := e as Enemy
				if bool(en.t.get("heavy", false)):
					continue
				if not en._enraged:
					en._rage()
				en._rallied = true
				if en.state in [Enemy.S.IDLE, Enemy.S.RETURN, Enemy.S.CHASE]:
					en._go(Enemy.S.CHASE)
		"disco":
			_disco_t = 14.0
			for k in 2:
				var l := OmniLight3D.new(); l.light_energy = 3.5; l.omni_range = 9.0
				world.add_child(l)
				_disco.append(l)
		"gold":
			for k in 10:
				get_tree().create_timer(k * 0.2).timeout.connect(func() -> void:
					if is_instance_valid(p):
						var at2 := p.global_position + Vector3(_rng.randf_range(-5, 5), 0.6, _rng.randf_range(-5, 5))
						Pickup.spawn(at2, "gold", _rng.randi_range(3, 9), "", true)
						FX.burst(at2 + Vector3(0, 3, 0), Color(1.0, 0.85, 0.3), 8, 3.0, 0.1, 0.5, -6.0))
		"giants":
			for e in _foes_near(30.0):
				var en := e as Enemy
				if en.has_meta("giant_ev"):
					continue
				en.set_meta("giant_ev", true)
				en.body.scale *= 1.45
				en.max_hp *= 1.4
				en.hp *= 1.4
				en.hit_radius *= 1.4
		"quake":
			_quake_t = 8.0
			_quake_kick = 0.0
			Sfx.play("slam", -2.0, 0.1)
		"slowmo":
			_slow_t = 7.0
			for e in _foes_near(50.0):
				var en := e as Enemy
				en.slow_t = 7.0
				en.body.slow = 0.35
		"slippery":
			_slip_t = 12.0
		"ghosts":
			_ghost_t = 10.0
			_ghosted = _foes_near(45.0)

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
		FX.burst(at + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.15), 28, 7.0, 0.25, 0.8, -6.0)
		Sfx.play_at("fire_burst", at, -2.0, 0.2)
		if is_instance_valid(player) and Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < 2.4 and absf(player.global_position.y - at.y) < 2.5:
			player.take_damage(16.0 * Game.foe_scale().y, at, 5.0)
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and (e as Enemy).global_position.distance_to(at) < 2.4:
				(e as Enemy).take_damage(60.0, at, 4.0)
		ring.queue_free()
		rock.queue_free())
