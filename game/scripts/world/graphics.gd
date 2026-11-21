extends RefCounted
class_name Graphics
## GRAPHICS: Auto / High / Medium / Low (Jason, Nov 21: "the low medium high settings
## for graphics... we should definitely do those"). One game on every device: the
## levels, heroes, quests and monsters are the same on every setting; only how much
## the device has to draw changes.
##
##   High    the game exactly as it has always looked.
##   Medium  Insane's smoothness savings everywhere (identical scenery drawn together,
##           tiny far-off details and far monsters not drawn, far monsters asleep);
##           far-off lamps and torches stop lighting things; sun shadows drawn in
##           two layers instead of four and reaching less far; a few fewer sparks
##           and embers; a slightly lower 3D resolution.
##   Low     all that, plus sun shadows in one layer (just around you), half the
##           sparks, lamps stop lighting sooner, and a lower 3D resolution again.
##           (Menus and text stay sharp.) The shadows stay: they make the look.
##   Auto    (the default) starts on whatever last ran smoothly on this device. If the
##           game keeps running slowly it steps down one level and remembers; running
##           smoothly with room to spare for half a minute, it tries one level up
##           (once per session, so it never flip-flops).
##
## Kept on the device (user://settings.cfg), not in the save: the same hero can be
## played on a phone and on an iPad, each drawing what it can.
##
## Resolution, shadows, lamps and sparks change at once; the scenery savings and
## sleeping monsters are decided when you arrive somewhere.

const NAMES := ["Low", "Medium", "High"]
const PATH := "user://settings.cfg"
const RES := [0.7, 0.85, 1.0]              # 3D resolution
const PARTICLES := [0.5, 0.75, 1.0]        # sparks, embers, mist...
const LAMP_REACH := [28.0, 50.0, 0.0]      # lamps further away than this stop lighting (0: always)
const LAMP_RANGE := [1.5, 2.0, 0.0]        # ...unless it's a big one (a brazier): its range times this
const SUN_SHADOW := [0.4, 0.6, 1.0]        # how far sun shadows reach
const SUN_LAYERS := [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, -1]
const SLOW_FPS := 28.0                     # (an iPhone in Low Power Mode runs at 30: not slow)
const FAST_FPS := 55.0
const WINDOW := 4.0                        # seconds per measurement
const SLOW_WINDOWS := 2                    # 8 s running slowly: step down
const FAST_WINDOWS := 8                    # 32 s with room to spare: try one up

static var choice := "auto"                # "auto", "high", "medium", "low"
static var auto_level := 2
static var testing := false                # (the autotests: always High unless a test says so)
static var _loaded := false
static var _win_t := 0.0
static var _win_frames := 0
static var _slow := 0
static var _fast := 0
static var _tried_up := false
static var _grace := 3.0
static var _last_us := 0

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if testing:
		choice = "high"
		return
	# phones start a step down (small screens, lots of pixels); Auto sorts out the rest
	if OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile"):
		auto_level = 1
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		choice = String(cf.get_value("graphics", "choice", "auto"))
		auto_level = clampi(int(cf.get_value("graphics", "auto_level", auto_level)), 0, 2)
	if not choice in ["auto", "high", "medium", "low"]:
		choice = "auto"

static func save() -> void:
	if testing:
		return
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("graphics", "choice", choice)
	cf.set_value("graphics", "auto_level", auto_level)
	cf.save(PATH)

## 0 Low, 1 Medium, 2 High.
static func level() -> int:
	ensure_loaded()
	match choice:
		"low": return 0
		"medium": return 1
		"high": return 2
	return auto_level

static func lean() -> bool:
	return level() < 2

static func particles() -> float:
	return PARTICLES[level()]

static func label() -> String:
	ensure_loaded()
	if choice == "auto":
		return "Graphics: Auto (%s)" % NAMES[auto_level]
	return "Graphics: " + NAMES[level()]

## The pause menu button: Auto -> High -> Medium -> Low -> Auto.
static func cycle(root: Node) -> void:
	ensure_loaded()
	choice = {"auto": "high", "high": "medium", "medium": "low", "low": "auto"}[choice]
	if choice == "auto":
		_tried_up = false
	save()
	apply(root)

static func set_choice(c: String, root: Node) -> void:
	ensure_loaded()
	choice = c
	save()
	apply(root)

## Resolution, shadows, lamps and sparks for everything under root (the level).
static func apply(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var l := level()
	var vp := root.get_viewport()
	if vp:
		vp.scaling_3d_scale = RES[l]
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if l < 2 and not Game.is_compat() else Viewport.SCALING_3D_MODE_BILINEAR
	for n in root.find_children("*", "Light3D", true, false):
		var lt := n as Light3D
		if lt is DirectionalLight3D:
			var d := lt as DirectionalLight3D
			if not d.has_meta("gfx_dist"):
				d.set_meta("gfx_dist", d.directional_shadow_max_distance)
				d.set_meta("gfx_layers", int(d.directional_shadow_mode))
			d.directional_shadow_max_distance = float(d.get_meta("gfx_dist")) * SUN_SHADOW[l]
			d.directional_shadow_mode = (int(d.get_meta("gfx_layers")) if SUN_LAYERS[l] < 0 else SUN_LAYERS[l]) as DirectionalLight3D.ShadowMode
			continue
		if not lt.has_meta("gfx_fade"):
			lt.set_meta("gfx_fade", [lt.distance_fade_enabled, lt.distance_fade_begin, lt.distance_fade_length, lt.shadow_enabled])
		var orig: Array = lt.get_meta("gfx_fade")
		if l == 2:
			lt.distance_fade_enabled = orig[0]; lt.distance_fade_begin = orig[1]; lt.distance_fade_length = orig[2]
			lt.shadow_enabled = orig[3]
		else:
			var rng := 0.0
			if lt is OmniLight3D:
				rng = (lt as OmniLight3D).omni_range
			elif lt is SpotLight3D:
				rng = (lt as SpotLight3D).spot_range
			var reach := maxf(LAMP_REACH[l], rng * LAMP_RANGE[l])
			lt.distance_fade_enabled = true
			lt.distance_fade_begin = minf(float(orig[1]), reach) if orig[0] else reach
			lt.distance_fade_length = 10.0
			lt.shadow_enabled = bool(orig[3]) and l == 1
	for n in root.find_children("*", "CPUParticles3D", true, false):
		_scale_particles(n, l)
	for n in root.find_children("*", "GPUParticles3D", true, false):
		_scale_particles(n, l)

static func _scale_particles(n: Node, l: int) -> void:
	if not n.has_meta("gfx_amount"):
		n.set_meta("gfx_amount", int(n.get("amount")))
	var want := maxi(1, int(round(float(n.get_meta("gfx_amount")) * PARTICLES[l])))
	if int(n.get("amount")) != want:
		n.set("amount", want)

## Not playing (a menu, a movie, the title): don't count this time.
static func idle() -> void:
	_last_us = 0

## Just arrived somewhere: let it settle before measuring.
static func arrived() -> void:
	_grace = 3.0
	_win_t = 0.0; _win_frames = 0
	_slow = 0; _fast = 0
	_last_us = 0

## Auto: main calls this every frame while you're playing (no menu open). Returns
## "down" or "up" when it changed the level.
static func watch(root: Node) -> String:
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _last_us == 0 else float(now - _last_us) / 1000000.0
	_last_us = now
	ensure_loaded()
	if choice != "auto" or testing or dt <= 0.0:
		return ""
	return feed(root, dt)

## One frame's time, in real seconds (the tests feed it made-up frames).
static func feed(root: Node, dt: float) -> String:
	if _grace > 0.0:
		_grace -= dt
		return ""
	_win_t += minf(dt, 0.25)
	_win_frames += 1
	if _win_t < WINDOW:
		return ""
	var fps := float(_win_frames) / _win_t
	_win_t = 0.0; _win_frames = 0
	if fps < SLOW_FPS:
		_slow += 1; _fast = 0
		if _slow >= SLOW_WINDOWS and auto_level > 0:
			_slow = 0
			auto_level -= 1
			_changed(root)
			return "down"
	elif fps >= FAST_FPS:
		_fast += 1; _slow = 0
		if _fast >= FAST_WINDOWS and auto_level < 2 and not _tried_up:
			_tried_up = true
			_fast = 0
			auto_level += 1
			_changed(root)
			return "up"
	else:
		_slow = 0; _fast = 0
	return ""

static func _changed(root: Node) -> void:
	save()
	apply(root)
	_grace = 3.0

## (for the tests)
static func reset_auto(lv := 2) -> void:
	auto_level = lv
	_tried_up = false
	arrived()
	_grace = 0.0
