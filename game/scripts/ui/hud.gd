extends CanvasLayer
class_name HUD

var player: Player
var root: Control
var name_label: Label
var hp_bar: ProgressBar; var hp_text: Label
var mp_bar: ProgressBar
var st_bar: ProgressBar
var xp_bar: ProgressBar
var gold_label: Label
var potion_label: Label
var special_label: Label
var costume_label: Label
var objective_label: Label
var prompt_label: Label
var msg_box: VBoxContainer
var quest_box: VBoxContainer
var compass: QuestCompass
var _quest_rows := {}            # quest id -> the row Control (for taps)

## The quest list: the one the compass follows is marked with a gold arrow.
## Tap a quest (or press T) to follow it.
func _refresh_quests() -> void:
	if quest_box == null:
		return
	for c in quest_box.get_children():
		c.queue_free()
	_quest_rows.clear()
	var ids := Game.tracked_quests()
	if ids.is_empty():
		return
	quest_box.add_child(UIKit.label("QUESTS  (tap to follow)" if Game.touch_active else "QUESTS  ([T] next)", 15, UIKit.GOLD, true))
	var cur := Game.current_quest()
	for id in ids:
		var q: Dictionary = Game.QUESTS[id]
		var ready: bool = Game.quest_state(id) == "ready"
		var on: bool = id == cur
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				Game.track_quest(id))
		var l := UIKit.label(("➤ " if on else "   ") + q.title, 17, Color(1.0, 0.82, 0.25) if on else Color(1.0, 0.92, 0.7, 0.75), true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		var t := ("     Done! Return to %s" % Game.NPC_NAMES.get(q.giver, "")) if ready else ("     %s: %d / %d" % [q.track, Game.quest_progress(id), q.goal.count])
		var l2 := UIKit.label(t, 15, Color(0.6, 1.0, 0.5) if ready else (UIKit.PARCH if on else Color(0.85, 0.8, 0.7, 0.7)))
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l2)
		quest_box.add_child(row)
		_quest_rows[id] = row

## Touch: a tap on a quest row follows it; a tap on the compass steps to the next.
func tap_at(pos: Vector2) -> bool:
	for id in _quest_rows:
		var r: Control = _quest_rows[id]
		if is_instance_valid(r) and r.get_global_rect().grow(6.0).has_point(pos):
			Game.track_quest(id)
			return true
	if compass and compass.visible and compass.tap(pos):
		return true
	return false
var crosshair: Control
var vignette: ColorRect
var target_box: VBoxContainer; var target_name: Label; var target_bar: ProgressBar
var boss_box: VBoxContainer; var boss_bar: ProgressBar; var boss_name: Label
var hint: Label
var view_label: Label
var _target: Node = null
var _target_time := 0.0
var _last_hp := -1.0
var _hint_time := 0.0
var _vig := 0.0
var _prompt := ""

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = "shader_type canvas_item; uniform float amount = 0.0; uniform vec4 tint : source_color = vec4(0.6,0.0,0.0,1.0);\nvoid fragment(){ vec2 d = UV - 0.5; float v = smoothstep(0.25, 0.75, length(d * vec2(1.4, 1.0))); COLOR = vec4(tint.rgb, v * amount); }"
	var vm := ShaderMaterial.new(); vm.shader = vs
	vignette.material = vm
	root.add_child(vignette)

	# --- status block (top-left)
	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", UIKit.panel_style(0.62))
	status.position = Vector2(20, 18)
	root.add_child(status)
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 5)
	status.add_child(sv)
	name_label = UIKit.label("", 21, UIKit.GOLD, true)
	sv.add_child(name_label)
	var hp_row := HBoxContainer.new(); sv.add_child(hp_row)
	hp_bar = UIKit.bar(Color(0.72, 0.12, 0.12), 280, 20); hp_row.add_child(hp_bar)
	hp_text = UIKit.label("", 15); hp_text.custom_minimum_size.x = 90; hp_row.add_child(hp_text)
	mp_bar = UIKit.bar(Color(0.2, 0.42, 0.9), 280, 12); sv.add_child(mp_bar)
	st_bar = UIKit.bar(Color(0.78, 0.66, 0.22), 280, 9); sv.add_child(st_bar)
	xp_bar = UIKit.bar(Color(0.55, 0.35, 0.85), 280, 6); sv.add_child(xp_bar)
	var res_row := HBoxContainer.new(); res_row.add_theme_constant_override("separation", 22); sv.add_child(res_row)
	potion_label = UIKit.label("", 16, Color(1, 0.55, 0.55)); res_row.add_child(potion_label)
	special_label = UIKit.label("", 16, Color(0.8, 0.65, 1.0))
	sv.add_child(special_label)
	costume_label = UIKit.label("", 16, Color(1.0, 0.7, 1.0))
	sv.add_child(costume_label)
	gold_label = UIKit.label("", 16, Color(1, 0.82, 0.35)); res_row.add_child(gold_label)

	# --- objective (top-centre)
	objective_label = UIKit.label("", 20, UIKit.PARCH, true)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-450, 22)
	objective_label.size = Vector2(900, 30)
	root.add_child(objective_label)

	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-350, 62); boss_box.size = Vector2(700, 50)
	boss_name = UIKit.label("THE VAULT WARDEN", 22, Color(1, 0.75, 0.5), true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = UIKit.bar(Color(0.8, 0.3, 0.12), 700, 18)
	boss_box.add_child(boss_bar)
	boss_box.visible = false
	root.add_child(boss_box)

	target_box = VBoxContainer.new()
	target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_box.position = Vector2(-140, 64); target_box.size = Vector2(280, 40)
	target_name = UIKit.label("", 16); target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_box.add_child(target_name)
	target_bar = UIKit.bar(Color(0.75, 0.2, 0.15), 280, 10)
	target_box.add_child(target_bar)
	target_box.visible = false
	root.add_child(target_box)

	# --- interaction prompt
	prompt_label = UIKit.label("", 22, Color(1, 0.92, 0.7), true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-400, -190); prompt_label.size = Vector2(800, 30)
	root.add_child(prompt_label)

	# --- quest tracker (left, under the status box)
	quest_box = VBoxContainer.new()
	quest_box.position = Vector2(22, 198)
	quest_box.add_theme_constant_override("separation", 4)
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quest_box)
	# --- compass with the quest arrow (top right)
	compass = QuestCompass.new()
	root.add_child(compass)
	add_to_group("hud")
	Game.quests_changed.connect(_refresh_quests)
	_refresh_quests()
	# --- messages (right)
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	msg_box.position = Vector2(-520, 120); msg_box.size = Vector2(500, 400)
	msg_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)

	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func() -> void:
		crosshair.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.75))
		crosshair.draw_arc(Vector2.ZERO, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.5))
	root.add_child(crosshair)

	hint = UIKit.label("WASD move · Mouse look · Wheel zoom (1st/3rd person) · LMB attack (hits recharge mana) · RMB block · Q arcane bolt · X special\nSpace jump/climb · Shift sprint · C dodge · E interact · R heal · F mana · I inventory · T follow next quest · Esc menu", 15, UIKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-600, -70); hint.size = Vector2(1200, 50)
	root.add_child(hint)
	view_label = UIKit.label("", 14, UIKit.DIM)
	view_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	view_label.position = Vector2(-260, -36); view_label.size = Vector2(240, 24)
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(view_label)

	Game.message.connect(push_message)
	Game.objective_changed.connect(func(t: String) -> void:
		objective_label.text = t
		objective_label.modulate.a = 0.0
		create_tween().tween_property(objective_label, "modulate:a", 1.0, 0.8))
	Game.leveled_up.connect(func(_l: int) -> void:
		Sfx.play("levelup", -2.0, 0.0)
		if player:
			FX.burst(player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 60, 4.0, 0.2, 1.4, 1.5)
			FX.flash_light(player.global_position + Vector3(0, 1.5, 0), Color(1, 0.85, 0.4), 5.0, 8.0, 1.0))

func bind_player(p: Player) -> void:
	player = p
	if compass:
		compass.player = p
	p.interact_target_changed.connect(func(t: String) -> void: _prompt = t)

func set_target(n: Node) -> void:
	if n == null or n.is_in_group("boss"):
		return
	_target = n
	_target_time = 4.0

func push_message(text: String, color: Color) -> void:
	var l := UIKit.label(text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 500
	msg_box.add_child(l)
	while msg_box.get_child_count() > 7:
		msg_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

func show_boss(w: Warden) -> void:
	boss_box.visible = true
	boss_bar.max_value = w.max_hp; boss_bar.value = w.hp
	if not w.health_changed.is_connected(_on_boss_hp):
		w.health_changed.connect(_on_boss_hp)

func _on_boss_hp(hp: float, mx: float) -> void:
	boss_bar.max_value = mx
	create_tween().tween_property(boss_bar, "value", hp, 0.2)

func hide_boss() -> void:
	boss_box.visible = false

func _process(delta: float) -> void:
	if player == null:
		return
	name_label.text = "%s  ·  Level %d" % [Game.profile.name, Game.level]
	hp_bar.max_value = Game.max_hp(); hp_bar.value = lerpf(hp_bar.value, Game.hp, 1.0 - exp(-12.0 * delta))
	hp_text.text = " %d / %d" % [int(ceil(maxf(Game.hp, 0.0))), int(Game.max_hp())]
	mp_bar.max_value = Game.max_mana(); mp_bar.value = Game.mana
	st_bar.max_value = Game.max_stamina(); st_bar.value = Game.stamina
	xp_bar.max_value = Game.xp_to_next(); xp_bar.value = Game.xp
	if quest_box:
		quest_box.position.x = 104.0 if Game.touch_active else 22.0
	if compass:
		var vw := root.size.x
		compass.position = Vector2(vw - compass.size.x - (6.0 if Game.touch_active else 14.0), 104.0 if Game.touch_active else 8.0)
		msg_box.position.y = compass.position.y + compass.size.y + 24.0
	if Input.is_action_just_pressed("track_quest") and get_tree().current_scene.get("state") == "play":
		Game.track_next()
	potion_label.text = ("Heal %d   Mana %d" if Game.touch_active else "Heal %d [R]   Mana %d [F]") % [Game.potions, Game.mana_potions]
	var ab := Game.ability()
	var ab_state := "ready" if player.special_cd <= 0.0 else "%ds" % ceili(player.special_cd)
	special_label.text = ("%s: %s" if Game.touch_active else "%s [X]: %s") % [ab.name, ab_state]
	special_label.modulate = Color(1, 1, 1) if player.special_cd <= 0.0 else Color(0.6, 0.6, 0.6)
	var cid := Game.costume_id()
	costume_label.visible = cid != ""
	if cid != "":
		costume_label.text = "%s: %s" % [Loot.COSTUMES.get(cid, {}).get("name", "Costume"), Game.costume_time_text()]
	gold_label.text = "Gold: %d" % Game.gold
	# damage / low-health vignette
	var vm := vignette.material as ShaderMaterial
	if _last_hp >= 0.0 and Game.hp < _last_hp - 0.5:
		_vig = 0.9
	_last_hp = Game.hp
	var low := clampf(1.0 - Game.hp / (Game.max_hp() * 0.3), 0.0, 1.0) * (0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	_vig = maxf(low, _vig - delta * 2.5)
	vm.set_shader_parameter("amount", _vig)
	if player.in_river and not Game.has_special("river"):
		vm.set_shader_parameter("tint", Color(0.1, 0.5, 0.8, 1))
	else:
		vm.set_shader_parameter("tint", Color(0.6, 0.0, 0.0, 1))
	# target bar
	_target_time -= delta
	if _target and is_instance_valid(_target) and _target_time > 0.0 and _target.get("dead") != true and not boss_box.visible:
		target_box.visible = true
		target_name.text = String(_target.get("display_name"))
		target_bar.max_value = _target.get("max_hp"); target_bar.value = _target.get("hp")
	else:
		target_box.visible = false
	crosshair.visible = player.mouse_captured and (player.first_person or player.zoom < 2.5)
	crosshair.queue_redraw()
	prompt_label.text = _prompt.replace("[E]", "USE ▸") if Game.touch_active else _prompt
	if Game.touch_active:
		hint.text = "Left thumb: move · Right side: swipe to look · Left-edge slider or pinch: zoom\nHold any button still to move it (turns yellow) · Pause menu: Arrange / Reset buttons"
	_hint_time += delta
	hint.modulate.a = clampf(1.0 - (_hint_time - 40.0) / 3.0, 0.0, 1.0)
	view_label.text = "First person" if player.first_person else "Third person  ·  zoom %.1fm" % player.zoom

func show_hint_again() -> void:
	_hint_time = 0.0
