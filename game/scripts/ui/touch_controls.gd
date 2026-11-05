extends CanvasLayer
class_name TouchControls
## On-screen controls for touchscreens (iPad / phones / touch laptops).
## Appears on the first touch and hides again when a physical key is used.
##  - left side: floating joystick (push fully to sprint)
##  - left edge: ZOOM slider (top = first person, bottom = high overhead view)
##  - right side: drag anywhere free to look, pinch with two fingers to zoom
##  - buttons: the combat cluster sits tight in the bottom-right corner so the
##    middle of the right side stays free for steering the camera
##  - hold a button still for LONG_PRESS seconds: it turns yellow and can be slid
##    anywhere; let go and it stays there (saved). The pause menu also has
##    "Arrange buttons" (move any button, incl. ATTACK and BLOCK) and "Reset".

var player: Player
var main: Node
var pad: Control
var active := false

const LOOK_SENS := 1.35
const LOOK_VERTICAL := 0.6   # vertical swipes move the view less than horizontal ones
const LONG_PRESS := 1.2      # seconds holding a button still to pick it up
const SAVE_PATH := "user://touch_layout.cfg"
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_home := Vector2.ZERO      # where the base appeared for this touch
const STICK_R := 95.0                # knob travel
const STICK_DRIFT := 55.0            # how far (about an inch) the base may follow the thumb
var _stick_vec := Vector2.ZERO
var _look := {}            # touch index -> last position
var _pinch_dist := -1.0
var _btn_touch := {}       # touch index -> button name
var _held := {}            # button name -> true
var _buttons: Array = []   # [{name, action, label, center, radius, hold}]
var _font: Font
# hold-to-move
var _press_info := {}      # touch index -> {name, t, pos}
var _moving := {}          # touch index -> button name being dragged
var _custom := {}          # button name -> Vector2 (fraction of the screen)
var arrange := false       # "Arrange buttons" mode (from the pause menu)
var moves := 0
# zoom slider
var _zoom_id := -1

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	add_child(pad)
	_font = UIKit.title_font()
	visible = false
	_load_layout()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## Default layout. The combat cluster wraps around ATTACK in the bottom-right
## corner; the rest of the right side is left open for the look thumb.
func _defaults() -> Array:
	var r := _screen()
	var w := r.x; var h := r.y
	return [
		{"name": "attack", "action": "attack", "label": "ATTACK", "center": Vector2(w - 170, h - 170), "radius": 92.0, "hold": true},
		{"name": "jump", "action": "jump", "label": "JUMP", "center": Vector2(w - 385, h - 110), "radius": 58.0, "hold": false},
		{"name": "block", "action": "block", "label": "BLOCK", "center": Vector2(w - 395, h - 262), "radius": 58.0, "hold": true},
		{"name": "special", "action": "special", "label": "SPECIAL", "center": Vector2(w - 318, h - 400), "radius": 58.0, "hold": false},
		{"name": "spell", "action": "spell", "label": "BOLT", "center": Vector2(w - 178, h - 412), "radius": 54.0, "hold": false},
		{"name": "dodge", "action": "dodge", "label": "DODGE", "center": Vector2(w - 62, h - 330), "radius": 50.0, "hold": false},
		{"name": "interact", "action": "interact", "label": "USE", "center": Vector2(w - 572, h - 105), "radius": 52.0, "hold": false},
		{"name": "mount", "action": "mount", "label": "RIDE", "center": Vector2(w - 560, h - 250), "radius": 46.0, "hold": false},
		{"name": "potion", "action": "potion", "label": "HEAL", "center": Vector2(w - 372, 62), "radius": 44.0, "hold": false},
		{"name": "mana", "action": "mana_potion", "label": "MANA", "center": Vector2(w - 474, 62), "radius": 44.0, "hold": false},
		{"name": "view", "action": "toggle_view", "label": "VIEW", "center": Vector2(w - 270, 62), "radius": 44.0, "hold": false},
		{"name": "inventory", "action": "inventory", "label": "BAG", "center": Vector2(w - 166, 62), "radius": 44.0, "hold": false},
		{"name": "pause", "action": "pause", "label": "II", "center": Vector2(w - 62, 62), "radius": 44.0, "hold": false},
	]

func _layout() -> void:
	var r := _screen()
	_buttons = _defaults()
	for b in _buttons:
		if _custom.has(b.name):
			var f: Vector2 = _custom[b.name]
			b.center = _clamp_center(Vector2(f.x * r.x, f.y * r.y), b.radius)

func button(n: String) -> Dictionary:
	for b in _buttons:
		if b.name == n:
			return b
	return {}

func _clamp_center(c: Vector2, rad: float) -> Vector2:
	var r := _screen()
	return Vector2(clampf(c.x, rad + 4.0, r.x - rad - 4.0), clampf(c.y, rad + 4.0, r.y - rad - 4.0))

# --- saving the player's own layout -------------------------------------------------
func _load_layout() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in cf.get_section_keys("buttons") if cf.has_section("buttons") else []:
		var v = cf.get_value("buttons", k)
		if v is Vector2:
			_custom[k] = v

func _save_layout() -> void:
	var cf := ConfigFile.new()
	for k in _custom:
		cf.set_value("buttons", k, _custom[k])
	cf.save(SAVE_PATH)

func reset_layout() -> void:
	_custom.clear()
	_save_layout()
	_layout()
	if pad:
		pad.queue_redraw()

func set_arrange(on: bool) -> void:
	arrange = on
	if on:
		_set_active(true)
		_release_all()
	if pad:
		pad.queue_redraw()

# --- zoom slider (left edge) -------------------------------------------------------
func _zoom_rect() -> Rect2:
	var r := _screen()
	var top := maxf(190.0, r.y * 0.24)
	var bottom := minf(r.y - 470.0, r.y * 0.62)
	return Rect2(14.0, top, 76.0, maxf(bottom - top, 160.0))

func _zoom_from_y(y: float) -> void:
	if player == null:
		return
	var zr := _zoom_rect()
	var t := clampf((y - zr.position.y - 20.0) / (zr.size.y - 40.0), 0.0, 1.0)
	var z := t * t * Player.MAX_ZOOM * 0.92 if t > 0.06 else 0.0   # top end snaps to first person
	player.zoom_target = z

# --- input ---------------------------------------------------------------------------
func bind(p: Player, m: Node) -> void:
	player = p
	main = m

func _playing() -> bool:
	return main != null and main.get("state") == "play" and main.menus.current == "" and not get_tree().paused

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		Game.last_touch_ms = Time.get_ticks_msec()
		if not active:
			_set_active(true)
		if arrange:
			_arrange_input(event)
			get_viewport().set_input_as_handled()
			return
		if not _playing():
			_release_all()
			return
		if event is InputEventScreenTouch:
			_on_touch(event)
		else:
			_on_drag(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and active and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_active(false)

func _set_active(on: bool) -> void:
	active = on
	visible = on
	Game.touch_active = on
	if on and player and main and main.get("state") == "play" and not arrange:
		player.set_mouse_captured(true)   # gameplay focus without pointer lock
	if not on:
		_release_all()

## Arrange mode: drag any button straight away; DONE and RESET are drawn at the top.
func _arrange_input(event: InputEvent) -> void:
	var r := _screen()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _done_rect().has_point(e.position):
				set_arrange(false)
				if main and main.has_method("_resume"):
					main._resume()
				return
			if _reset_rect().has_point(e.position):
				reset_layout()
				return
			var b := _button_at(e.position)
			if not b.is_empty():
				_moving[e.index] = b.name
		else:
			if _moving.has(e.index):
				_drop(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _moving.has(d.index):
			_move_to(_moving[d.index], d.position)
	pad.queue_redraw()
	if r == Vector2.ZERO:
		pass

func _done_rect() -> Rect2:
	var r := _screen()
	return Rect2(r.x * 0.5 + 10, r.y * 0.5 - 40, 220, 80)

func _reset_rect() -> Rect2:
	var r := _screen()
	return Rect2(r.x * 0.5 - 230, r.y * 0.5 - 40, 220, 80)

func _move_to(n: String, p: Vector2) -> void:
	var b := button(n)
	if b.is_empty():
		return
	b.center = _clamp_center(p, b.radius)
	pad.queue_redraw()

func _drop(idx: int) -> void:
	var n: String = _moving[idx]
	_moving.erase(idx)
	var b := button(n)
	if b.is_empty():
		return
	var r := _screen()
	_custom[n] = Vector2(b.center.x / r.x, b.center.y / r.y)
	_save_layout()
	moves += 1
	Sfx.play("footstep", -8.0, 0.0)

func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		var b := _button_at(e.position)
		var hud := get_tree().get_first_node_in_group("hud")
		if b.is_empty() and hud and hud.has_method("tap_at") and hud.tap_at(e.position):
			return          # tapped a quest in the list, or the compass
		if not b.is_empty():
			_btn_touch[e.index] = b.name
			_press_info[e.index] = {"name": b.name, "t": 0.0, "pos": e.position}
			_press_button(b)
		elif _zoom_rect().grow(16.0).has_point(e.position) and _zoom_id == -1:
			_zoom_id = e.index
			_zoom_from_y(e.position.y)
		elif _look.size() == 1 and (_look.values()[0] as Vector2).distance_to(e.position) < 520.0:
			# a second finger near the first one is a pinch, wherever it lands
			_look[e.index] = e.position
			_pinch_dist = -1.0
		elif e.position.x < _screen().x * 0.42 and _stick_id == -1:
			_stick_id = e.index
			# the base appears under the thumb, but only inside the bottom-left home zone
			var r := _screen()
			_stick_home = Vector2(clampf(e.position.x, 120.0, 430.0), clampf(e.position.y, r.y - 430.0, r.y - 120.0))
			_stick_origin = _stick_home
			_stick_pos = e.position
			_update_stick()
		else:
			_look[e.index] = e.position
			_pinch_dist = -1.0
	else:
		_press_info.erase(e.index)
		if _moving.has(e.index):
			_drop(e.index)
		elif _btn_touch.has(e.index):
			_release_button(_btn_touch[e.index])
		_btn_touch.erase(e.index)
		if e.index == _zoom_id:
			_zoom_id = -1
		elif e.index == _stick_id:
			_stick_id = -1
			_stick_vec = Vector2.ZERO
			_apply_stick()
		_look.erase(e.index)
		if _look.size() < 2:
			_pinch_dist = -1.0
	pad.queue_redraw()

func _on_drag(e: InputEventScreenDrag) -> void:
	if _moving.has(e.index):
		_move_to(_moving[e.index], e.position)
		return
	if _press_info.has(e.index) and (_press_info[e.index].pos as Vector2).distance_to(e.position) > 22.0:
		_press_info.erase(e.index)   # the thumb moved: it's a press, not a pick-up
	if e.index == _zoom_id:
		_zoom_from_y(e.position.y)
	elif e.index == _stick_id:
		_stick_pos = e.position
		_update_stick()
	elif _look.has(e.index):
		if _look.size() >= 2:
			_look[e.index] = e.position
			var pts: Array = _look.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0 and player:
				var f := _pinch_dist / maxf(d, 1.0)
				player.zoom_target = clampf(player.zoom_target * f + (f - 1.0) * 1.6, 0.0, Player.MAX_ZOOM)
				if player.zoom_target < Player.FP_THRESHOLD and f < 1.0:
					player.zoom_target = 0.0
				elif player.zoom_target < 1.0 and f > 1.0:
					player.zoom_target = 1.6   # pinching out of first person jumps straight back behind the hero
			_pinch_dist = d
		else:
			if player:
				# per-finger delta from our own record (independent of other fingers)
				var rel: Vector2 = e.position - (_look[e.index] as Vector2)
				var spd := rel.length()
				var accel := lerpf(0.65, 1.35, clampf(spd / 28.0, 0.0, 1.0))
				player._look(rel * Vector2(1.0, LOOK_VERTICAL), LOOK_SENS * accel)
			_look[e.index] = e.position
	pad.queue_redraw()

func _update_stick() -> void:
	var v := (_stick_pos - _stick_origin) / STICK_R
	if v.length() > 1.0:
		# let the base follow a little, then stay put: the thumb can slide anywhere
		# and the stick keeps pushing at full strength toward it
		var want := _stick_pos - v.normalized() * STICK_R
		var drift := want - _stick_home
		if drift.length() > STICK_DRIFT:
			drift = drift.normalized() * STICK_DRIFT
		_stick_origin = _stick_home + drift
		v = (_stick_pos - _stick_origin) / STICK_R
		if v.length() > 1.0:
			v = v.normalized()
	_stick_vec = v
	_apply_stick()

func _apply_stick() -> void:
	var v := _stick_vec
	_set_axis("move_right", maxf(v.x, 0.0)); _set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_back", maxf(v.y, 0.0)); _set_axis("move_forward", maxf(-v.y, 0.0))
	if v.length() > 0.93:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")

func _set_axis(action: String, s: float) -> void:
	if s > 0.12:
		Input.action_press(action, s)
	else:
		Input.action_release(action)

## USE swells and pulses gold whenever there's something you can use, talk to or pick up.
## The RIDE button only appears once you've earned the Giant Chicken.
func _available(b: Dictionary) -> bool:
	if b.name == "mount":
		return bool(Game.flags.get("mount_chicken", false)) or arrange
	return true

func _use_ready() -> bool:
	return player != null and player.get("interact_target") != null and not arrange

func _radius(b: Dictionary) -> float:
	if b.name == "interact" and _use_ready():
		return b.radius * 1.4
	return b.radius

func _button_at(p: Vector2) -> Dictionary:
	# exact circles (no extra margin) so near misses go to looking, not to a button
	var best := {}
	var bd := INF
	for b in _buttons:
		if not _available(b):
			continue
		var d: float = p.distance_to(b.center)
		if d <= _radius(b) * 1.04 and d < bd:
			bd = d
			best = b
	return best

func _press_button(b: Dictionary) -> void:
	_held[b.name] = true
	match b.name:
		"pause", "inventory":
			var ev := InputEventAction.new()
			ev.action = b.action; ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventAction.new()
			up.action = b.action; up.pressed = false
			get_tree().create_timer(0.05, true, true).timeout.connect(func() -> void: Input.parse_input_event(up))
		"view":
			if player:
				player.toggle_view()
		_:
			Input.action_press(b.action)
			if not b.hold:
				get_tree().create_timer(0.08, true, true).timeout.connect(func() -> void: Input.action_release(b.action))

func _release_button(n: String) -> void:
	_held.erase(n)
	for b in _buttons:
		if b.name == n and b.hold:
			Input.action_release(b.action)

func _release_all() -> void:
	for b in _buttons:
		if b.hold:
			Input.action_release(b.action)
	_held.clear(); _btn_touch.clear(); _look.clear(); _press_info.clear(); _moving.clear()
	_stick_id = -1; _stick_vec = Vector2.ZERO; _zoom_id = -1
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		Input.action_release(a)
	if pad:
		pad.queue_redraw()

func _process(d: float) -> void:
	if not active:
		return
	pad.visible = _playing() or arrange
	# hold a (non-combat) button still to pick it up and move it; ATTACK and BLOCK are
	# held down in normal play, so they move only in Arrange mode
	for idx in _press_info.keys():
		var info: Dictionary = _press_info[idx]
		info.t += d
		if info.t >= LONG_PRESS and not (info.name in ["attack", "block"]):
			_press_info.erase(idx)
			_btn_touch.erase(idx)
			_held.erase(info.name)
			var b := button(info.name)
			if not b.is_empty() and b.hold:
				Input.action_release(b.action)
			_moving[idx] = info.name
			Sfx.play("levelup", -14.0, 0.0)
	pad.queue_redraw()

func _draw_pad() -> void:
	var gold := Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.55)
	var yellow := Color(1.0, 0.85, 0.1)
	var r := _screen()
	if arrange:
		pad.draw_rect(Rect2(Vector2.ZERO, r), Color(0, 0, 0, 0.35))
		pad.draw_string(_font, Vector2(0, r.y * 0.5 - 90), "Drag the buttons where you like them", HORIZONTAL_ALIGNMENT_CENTER, r.x, 30, Color(1, 0.95, 0.8))
		for rr in [[_reset_rect(), "RESET"], [_done_rect(), "DONE"]]:
			var rc: Rect2 = rr[0]
			pad.draw_rect(rc, Color(0.12, 0.1, 0.08, 0.92))
			pad.draw_rect(rc, UIKit.GOLD, false, 3.0)
			pad.draw_string(_font, rc.position + Vector2(0, rc.size.y * 0.5 + 10), rr[1], HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, 28, Color(1, 0.95, 0.8))
	# zoom slider
	if player:
		var zr := _zoom_rect()
		var cx := zr.position.x + zr.size.x * 0.5
		var top := zr.position.y + 20.0
		var bot := zr.end.y - 20.0
		pad.draw_line(Vector2(cx, top), Vector2(cx, bot), Color(0, 0, 0, 0.4), 16.0)
		pad.draw_line(Vector2(cx, top), Vector2(cx, bot), Color(1, 1, 1, 0.22 if _zoom_id == -1 else 0.45), 6.0)
		var zt := 0.0 if player.zoom_target <= 0.01 else sqrt(clampf(player.zoom_target / (Player.MAX_ZOOM * 0.92), 0.0, 1.0))
		var ky := lerpf(top, bot, zt)
		pad.draw_circle(Vector2(cx, ky), 24.0, Color(0.9, 0.8, 0.6, 0.55 if _zoom_id == -1 else 0.85))
		pad.draw_string(_font, Vector2(zr.position.x - 6, top - 14), "EYES", HORIZONTAL_ALIGNMENT_CENTER, zr.size.x + 12, 14, Color(1, 1, 1, 0.5))
		pad.draw_string(_font, Vector2(zr.position.x - 6, bot + 30), "HIGH", HORIZONTAL_ALIGNMENT_CENTER, zr.size.x + 12, 14, Color(1, 1, 1, 0.5))
	# joystick
	if _stick_id != -1:
		pad.draw_circle(_stick_origin, 95.0, Color(0, 0, 0, 0.25))
		pad.draw_arc(_stick_origin, 95.0, 0, TAU, 48, gold, 3.0)
		pad.draw_circle(_stick_origin + _stick_vec * 95.0, 40.0, Color(0.9, 0.8, 0.6, 0.45))
	elif not arrange:
		var hint := Vector2(240, r.y - 190)
		pad.draw_arc(hint, 95.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		pad.draw_string(_font, hint + Vector2(-48, 6), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 96, 18, Color(1, 1, 1, 0.25))
	var moving_names: Array = _moving.values()
	for b in _buttons:
		if not _available(b):
			continue
		var held: bool = _held.has(b.name)
		var picked: bool = b.name in moving_names
		var interact_ready: bool = b.name == "interact" and player != null and player.interact_target != null
		var fill := Color(0.08, 0.07, 0.07, 0.45 if not held else 0.75)
		if b.name == "potion":
			fill = Color(0.35, 0.05, 0.07, 0.5 if Game.potions > 0 else 0.2)
		elif b.name == "mana":
			fill = Color(0.06, 0.12, 0.38, 0.5 if Game.mana_potions > 0 else 0.2)
		elif b.name == "special":
			var abc: Color = Game.ability().color
			fill = Color(abc.r * 0.45, abc.g * 0.3, abc.b * 0.55, 0.6 if player == null or player.special_cd <= 0.0 else 0.25)
		var rad: float = b.radius
		if interact_ready and not arrange:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			fill = Color(0.85, 0.62, 0.12, 0.75 + 0.15 * pulse)
			rad = b.radius * (1.32 + 0.08 * pulse)
			pad.draw_circle(b.center, rad + 14.0 * pulse + 6.0, Color(1.0, 0.8, 0.25, 0.18 * (1.0 - pulse) + 0.08))
			pad.draw_arc(b.center, rad + 10.0 + 10.0 * pulse, 0, TAU, 48, Color(1.0, 0.9, 0.4, 0.7 * (1.0 - pulse)), 4.0)
		var ring := gold if not held else UIKit.GOLD
		var ring_w := 3.0 if not held else 4.0
		if picked:
			fill = Color(yellow.r, yellow.g, yellow.b, 0.75)
			ring = Color(1, 1, 0.6); ring_w = 6.0
		elif arrange:
			ring = yellow; ring_w = 4.0
		# a filling ring while a button is being held down to pick it up
		for info in _press_info.values():
			if info.name == b.name and info.t > 0.3 and not (b.name in ["attack", "block"]):
				var k: float = clampf((info.t - 0.3) / (LONG_PRESS - 0.3), 0.0, 1.0)
				pad.draw_arc(b.center, b.radius + 8.0, -PI / 2, -PI / 2 + TAU * k, 40, yellow, 6.0)
		pad.draw_circle(b.center, rad, fill)
		pad.draw_arc(b.center, rad, 0, TAU, 40, ring if not interact_ready else Color(1.0, 0.95, 0.6), ring_w if not interact_ready else 5.0)
		var fs := 20 if rad > 60 else (17 if rad > 45 else 15)
		var label: String = b.label
		if b.name == "potion":
			label = "HEAL %d" % Game.potions
		elif b.name == "mana":
			label = "MANA %d" % Game.mana_potions
		elif b.name == "view" and player:
			label = player.view_name()
		elif b.name == "mount" and player:
			label = "WALK" if player.get("mounted") else "RIDE"
		elif b.name == "special":
			label = Game.ability().short
			if player and player.special_cd > 0.0 and not picked:
				var frac: float = player.special_cd / float(Game.ability().cd)
				pad.draw_arc(b.center, b.radius - 6.0, -PI / 2, -PI / 2 + TAU * frac, 40, Color(1, 1, 1, 0.5), 7.0)
				label = "%d" % ceili(player.special_cd)
		if interact_ready and not arrange:
			label = "USE!"
			fs = 24
		pad.draw_string(_font, b.center + Vector2(-rad, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, fs, Color(0.1, 0.08, 0.02) if picked else Color(1, 0.95, 0.85, 0.9))
