extends CanvasLayer
class_name TouchControls
## On-screen controls for touchscreens (iPad / phones / touch laptops).
## Appears on the first touch and hides again when a physical key is used.
##  - left side: floating joystick (push fully to sprint)
##  - right side: drag to look, pinch with two fingers to zoom 1st <-> 3rd person
##  - buttons: attack, block (hold), spell, dodge, jump, interact, potion,
##    view toggle, inventory, pause

var player: Player
var main: Node
var pad: Control
var active := false

const LOOK_SENS := 1.35
const LOOK_VERTICAL := 0.6   # vertical swipes move the view less than horizontal ones
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
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var r := get_viewport().get_visible_rect().size
	var w := r.x; var h := r.y
	_buttons = [
		{"name": "attack", "action": "attack", "label": "ATTACK", "center": Vector2(w - 178, h - 188), "radius": 94.0, "hold": true},
		{"name": "block", "action": "block", "label": "BLOCK", "center": Vector2(w - 392, h - 112), "radius": 68.0, "hold": true},
		{"name": "spell", "action": "spell", "label": "BOLT", "center": Vector2(w - 378, h - 300), "radius": 63.0, "hold": false},
		{"name": "dodge", "action": "dodge", "label": "DODGE", "center": Vector2(w - 178, h - 398), "radius": 63.0, "hold": false},
		{"name": "special", "action": "special", "label": "SPECIAL", "center": Vector2(w - 372, h - 462), "radius": 66.0, "hold": false},
		{"name": "jump", "action": "jump", "label": "JUMP", "center": Vector2(w - 70, h - 318), "radius": 56.0, "hold": false},
		{"name": "interact", "action": "interact", "label": "USE", "center": Vector2(w - 572, h - 100), "radius": 57.0, "hold": false},
		{"name": "potion", "action": "potion", "label": "HEAL", "center": Vector2(w - 560, h - 250), "radius": 49.0, "hold": false},
		{"name": "mana", "action": "mana_potion", "label": "MANA", "center": Vector2(w - 700, h - 175), "radius": 49.0, "hold": false},
		{"name": "pause", "action": "pause", "label": "II", "center": Vector2(w - 62, 66), "radius": 42.0, "hold": false},
		{"name": "inventory", "action": "inventory", "label": "BAG", "center": Vector2(w - 164, 66), "radius": 42.0, "hold": false},
		{"name": "view", "action": "toggle_view", "label": "VIEW", "center": Vector2(w - 266, 66), "radius": 42.0, "hold": false},
	]

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
	if on and player and main and main.get("state") == "play":
		player.set_mouse_captured(true)   # gameplay focus without pointer lock
	if not on:
		_release_all()

func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		var b := _button_at(e.position)
		if not b.is_empty():
			_btn_touch[e.index] = b.name
			_press_button(b)
		elif e.position.x < get_viewport().get_visible_rect().size.x * 0.42 and _stick_id == -1:
			_stick_id = e.index
			# the base appears under the thumb, but only inside the bottom-left home zone
			var r := get_viewport().get_visible_rect().size
			_stick_home = Vector2(clampf(e.position.x, 120.0, 430.0), clampf(e.position.y, r.y - 430.0, r.y - 120.0))
			_stick_origin = _stick_home
			_stick_pos = e.position
			_update_stick()
		else:
			_look[e.index] = e.position
			_pinch_dist = -1.0
	else:
		if _btn_touch.has(e.index):
			_release_button(_btn_touch[e.index])
			_btn_touch.erase(e.index)
		elif e.index == _stick_id:
			_stick_id = -1
			_stick_vec = Vector2.ZERO
			_apply_stick()
		_look.erase(e.index)
		if _look.size() < 2:
			_pinch_dist = -1.0
	pad.queue_redraw()

func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _stick_id:
		_stick_pos = e.position
		_update_stick()
	elif _look.has(e.index):
		if _look.size() >= 2:
			var pts: Array = _look.values()
			_look[e.index] = e.position
			pts = _look.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0 and player:
				var f := _pinch_dist / maxf(d, 1.0)
				player.zoom_target = clampf(player.zoom_target * f + (f - 1.0) * 1.2, 0.0, Player.MAX_ZOOM)
				if player.zoom_target < Player.FP_THRESHOLD:
					player.zoom_target = 0.0
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

func _button_at(p: Vector2) -> Dictionary:
	for b in _buttons:
		if p.distance_to(b.center) <= b.radius * 1.15:
			return b
	return {}

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
	_held.clear(); _btn_touch.clear(); _look.clear()
	_stick_id = -1; _stick_vec = Vector2.ZERO
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		Input.action_release(a)
	if pad:
		pad.queue_redraw()

func _process(_d: float) -> void:
	if active:
		pad.visible = _playing()
		pad.queue_redraw()

func _draw_pad() -> void:
	var gold := Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, 0.55)
	# joystick
	if _stick_id != -1:
		pad.draw_circle(_stick_origin, 95.0, Color(0, 0, 0, 0.25))
		pad.draw_arc(_stick_origin, 95.0, 0, TAU, 48, gold, 3.0)
		pad.draw_circle(_stick_origin + _stick_vec * 95.0, 40.0, Color(0.9, 0.8, 0.6, 0.45))
	else:
		var r := get_viewport().get_visible_rect().size
		var hint := Vector2(190, r.y - 190)
		pad.draw_arc(hint, 95.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		pad.draw_string(_font, hint + Vector2(-48, 6), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 96, 18, Color(1, 1, 1, 0.25))
	for b in _buttons:
		var held: bool = _held.has(b.name)
		var interact_ready: bool = b.name == "interact" and player != null and player.interact_target != null
		var fill := Color(0.08, 0.07, 0.07, 0.45 if not held else 0.75)
		if b.name == "potion":
			fill = Color(0.35, 0.05, 0.07, 0.5 if Game.potions > 0 else 0.2)
		elif b.name == "mana":
			fill = Color(0.06, 0.12, 0.38, 0.5 if Game.mana_potions > 0 else 0.2)
		elif b.name == "special":
			var abc: Color = Game.ability().color
			fill = Color(abc.r * 0.45, abc.g * 0.3, abc.b * 0.55, 0.6 if player == null or player.special_cd <= 0.0 else 0.25)
		if interact_ready:
			fill = Color(0.45, 0.33, 0.12, 0.7)
		pad.draw_circle(b.center, b.radius, fill)
		pad.draw_arc(b.center, b.radius, 0, TAU, 40, gold if not held else UIKit.GOLD, 3.0 if not held else 4.0)
		var fs := 20 if b.radius > 60 else (17 if b.radius > 45 else 15)
		var label: String = b.label
		if b.name == "potion":
			label = "HEAL %d" % Game.potions
		elif b.name == "mana":
			label = "MANA %d" % Game.mana_potions
		elif b.name == "view" and player:
			label = player.view_name()
		elif b.name == "special":
			label = Game.ability().short
			if player and player.special_cd > 0.0:
				var frac: float = player.special_cd / float(Game.ability().cd)
				pad.draw_arc(b.center, b.radius - 6.0, -PI / 2, -PI / 2 + TAU * frac, 40, Color(1, 1, 1, 0.5), 7.0)
				label = "%d" % ceili(player.special_cd)
		pad.draw_string(_font, b.center + Vector2(-b.radius, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, b.radius * 2.0, fs, Color(1, 0.95, 0.85, 0.9))
