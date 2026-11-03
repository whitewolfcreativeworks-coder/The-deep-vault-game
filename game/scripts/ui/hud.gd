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
var objective_label: Label
var prompt_label: Label
var msg_box: VBoxContainer
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

	hint = UIKit.label("WASD move · Mouse look · Wheel zoom (1st/3rd person) · LMB attack · RMB block · Q arcane bolt\nSpace jump · Shift sprint · C dodge · E interact · R potion · I inventory · Tab character · Esc menu", 15, UIKit.DIM)
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
	p.interact_target_changed.connect(func(t: String) -> void: prompt_label.text = t)

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
	potion_label.text = "Draughts: %d  [R]" % Game.potions
	gold_label.text = "Gold: %d" % Game.gold
	# damage / low-health vignette
	var vm := vignette.material as ShaderMaterial
	if _last_hp >= 0.0 and Game.hp < _last_hp - 0.5:
		_vig = 0.9
	_last_hp = Game.hp
	var low := clampf(1.0 - Game.hp / (Game.max_hp() * 0.3), 0.0, 1.0) * (0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	_vig = maxf(low, _vig - delta * 2.5)
	vm.set_shader_parameter("amount", _vig)
	if player.in_river and Game.equipped.artifact != "amulet_deep":
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
	_hint_time += delta
	hint.modulate.a = clampf(1.0 - (_hint_time - 40.0) / 3.0, 0.0, 1.0)
	view_label.text = "First person" if player.first_person else "Third person  ·  zoom %.1fm" % player.zoom

func show_hint_again() -> void:
	_hint_time = 0.0
