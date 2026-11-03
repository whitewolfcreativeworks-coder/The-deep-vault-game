extends CanvasLayer
class_name Menus
## Title screen, character creator (live 3D preview), pause, inventory &
## character sheet, lore reader, death and victory screens.

signal start_requested
signal resume_requested
signal respawn_requested
signal restart_requested
signal quit_requested

var root: Control
var current := ""
var fade: ColorRect
var _panels := {}
var _preview: CharacterModel
var _preview_vp: SubViewport
var _hero_btns := {}
var _cape_btns: Array[Button] = []
var _name_edit: LineEdit
var _hero_desc: Label
var _hat_btn: CheckButton
var _inv_list: VBoxContainer
var _stats_label: Label
var _lore_title: Label
var _lore_text: Label
var _victory_stats: Label
var _death_label: Label
var _mute_btn: Button

const NAMES := ["Aldric", "Brenna", "Corin", "Dagna", "Edric", "Fiora", "Gareth", "Halla", "Ivo", "Jessa", "Kael", "Liora", "Maelis", "Noren", "Orla", "Perrin", "Rhosyn", "Soren", "Tamsin", "Wren"]

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title()
	_build_creator()
	_build_pause()
	_build_inventory()
	_build_lore()
	_build_death()
	_build_victory()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Game.inventory_changed.connect(_refresh_inventory)
	Game.stats_changed.connect(_refresh_stats)

func fade_to(a: float, t := 0.8) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, t)
	return tw

func show_panel(n: String) -> void:
	current = n
	for k in _panels:
		(_panels[k] as Control).visible = k == n
	if n == "creator":
		_refresh_preview()
	if n == "inventory":
		_refresh_inventory(); _refresh_stats()

func is_open() -> bool:
	return current != ""

func close_all() -> void:
	show_panel("")

func _center_panel(n: String, w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, h)
	p.position = Vector2(-w / 2.0, -h / 2.0)
	p.size = Vector2(w, h)
	p.visible = false
	root.add_child(p)
	_panels[n] = p
	return p

func _button(text: String, cb: Callable, w := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 46)
	b.pressed.connect(func() -> void:
		Sfx.play("footstep", -8.0, 0.0)
		cb.call())
	return b

# ---------------------------------------------------------------------------
func _build_title() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	_panels["title"] = c
	var grad := ColorRect.new()
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := Shader.new()
	gs.code = "shader_type canvas_item; void fragment(){ float v = smoothstep(0.0, 0.7, UV.x); COLOR = vec4(0.0, 0.0, 0.02, (1.0 - v) * 0.82); }"
	var gm := ShaderMaterial.new(); gm.shader = gs
	grad.material = gm
	c.add_child(grad)
	var v := VBoxContainer.new()
	v.position = Vector2(110, 180)
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var t1 := UIKit.label("THE DEEP VAULT", 76, UIKit.GOLD, true)
	v.add_child(t1)
	var t2 := UIKit.label("Beneath the cliffs of Ashkar, a light still beats in the dark.", 22, UIKit.PARCH)
	v.add_child(t2)
	var sp := Control.new(); sp.custom_minimum_size.y = 40; v.add_child(sp)
	v.add_child(_button("Begin Adventure", func() -> void: show_panel("creator")))
	_mute_btn = _button("Sound: On", func() -> void: _toggle_mute())
	v.add_child(_mute_btn)
	v.add_child(_button("Quit", func() -> void: quit_requested.emit()))
	var foot := UIKit.label("An open-source experiment · Godot 4.5 · Assets: KayKit (CC0), Poly Haven (CC0), original procedural art & sound", 14, UIKit.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(110, -50)
	c.add_child(foot)

func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)
	_mute_btn.text = "Sound: Off" if Sfx.muted else "Sound: On"

# ---------------------------------------------------------------------------
func _build_creator() -> void:
	var p := _center_panel("creator", 1180, 720)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 24)
	p.add_child(h)
	# preview
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(520, 680)
	svc.stretch = true
	h.add_child(svc)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = false
	_preview_vp.size = Vector2i(520, 680)
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_preview_vp)
	var w := Node3D.new(); _preview_vp.add_child(w)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.35, 0.33, 0.45); e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	we.environment = e; w.add_child(we)
	var key := SpotLight3D.new(); key.light_color = Color(1.0, 0.75, 0.5); key.light_energy = 14.0; key.spot_range = 12.0; key.spot_angle = 30.0
	key.position = Vector3(1.8, 3.4, 2.6); key.look_at_from_position(key.position, Vector3(0, 1.0, 0)); key.shadow_enabled = true
	w.add_child(key)
	var rim := OmniLight3D.new(); rim.light_color = Color(0.3, 0.6, 1.0); rim.light_energy = 3.0; rim.omni_range = 6.0
	rim.position = Vector3(-1.5, 2.2, -1.6); w.add_child(rim)
	var floor_m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.2; cm.height = 0.2
	floor_m.mesh = cm
	var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/stone.gdshader"); fm.set_shader_parameter("mode", 1)
	floor_m.material_override = fm; floor_m.position.y = -0.1
	w.add_child(floor_m)
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.35, 6.2); cam.fov = 30
	w.add_child(cam)
	cam.look_at(Vector3(0, 1.05, 0))
	_preview = CharacterModel.new()
	w.add_child(_preview)
	# options
	var opts := VBoxContainer.new(); opts.add_theme_constant_override("separation", 12)
	opts.custom_minimum_size.x = 580
	h.add_child(opts)
	opts.add_child(UIKit.label("Create Your Adventurer", 34, UIKit.GOLD, true))
	opts.add_child(UIKit.label("Hero", 18, UIKit.DIM, true))
	var hg := GridContainer.new(); hg.columns = 3; hg.add_theme_constant_override("h_separation", 8); hg.add_theme_constant_override("v_separation", 8)
	opts.add_child(hg)
	for hero in Game.HERO_ORDER:
		var hb := Button.new(); hb.text = hero; hb.toggle_mode = true; hb.custom_minimum_size = Vector2(180, 44)
		hb.pressed.connect(func() -> void:
			Game.profile.hero = hero
			_refresh_preview(true))
		hg.add_child(hb)
		_hero_btns[hero] = hb
	_hero_desc = UIKit.label("", 17, UIKit.PARCH)
	_hero_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	opts.add_child(_hero_desc)
	opts.add_child(UIKit.label("Cloak colour", 18, UIKit.DIM, true))
	var cg := HBoxContainer.new(); cg.add_theme_constant_override("separation", 8)
	opts.add_child(cg)
	for i in Game.CAPE_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 40)
		b.tooltip_text = Game.CAPE_NAMES[i]
		b.toggle_mode = true
		var sb := StyleBoxFlat.new(); sb.bg_color = Game.CAPE_COLORS[i] if i > 0 else Color(0.5, 0.45, 0.4)
		sb.set_corner_radius_all(4); sb.border_color = Color(0, 0, 0, 0.6); sb.set_border_width_all(2)
		var sbp := sb.duplicate() as StyleBoxFlat; sbp.border_color = UIKit.GOLD; sbp.set_border_width_all(4)
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sbp)
		b.add_theme_stylebox_override("pressed", sbp); b.add_theme_stylebox_override("focus", sbp)
		if i == 0:
			b.text = "—"
		var idx := i
		b.pressed.connect(func() -> void:
			Game.profile.cape = idx
			_refresh_preview())
		cg.add_child(b)
		_cape_btns.append(b)
	_hat_btn = CheckButton.new(); _hat_btn.text = "Show helm / hat"; _hat_btn.button_pressed = true
	_hat_btn.toggled.connect(func(on: bool) -> void:
		Game.profile.show_hat = on
		_refresh_preview())
	opts.add_child(_hat_btn)
	opts.add_child(UIKit.label("Name", 18, UIKit.DIM, true))
	var nr := HBoxContainer.new(); nr.add_theme_constant_override("separation", 8); opts.add_child(nr)
	_name_edit = LineEdit.new(); _name_edit.custom_minimum_size = Vector2(380, 46); _name_edit.max_length = 18
	_name_edit.text = Game.profile.name
	nr.add_child(_name_edit)
	nr.add_child(_button("Random", func() -> void: _name_edit.text = NAMES.pick_random(), 150))
	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; opts.add_child(sp)
	opts.add_child(UIKit.label("Every hero fights with sword, shield and the arcane bolt.\nYour choice is how you look and who you are.", 15, UIKit.DIM))
	var br := HBoxContainer.new(); br.add_theme_constant_override("separation", 12); opts.add_child(br)
	br.add_child(_button("Back", func() -> void: show_panel("title"), 160))
	br.add_child(_button("Enter the Vault", func() -> void:
		var nm := _name_edit.text.strip_edges()
		Game.profile.name = nm if nm != "" else "Nameless"
		start_requested.emit(), 300))

func _refresh_preview(cheer := false) -> void:
	var p := Game.profile
	for k in _hero_btns:
		(_hero_btns[k] as Button).button_pressed = k == p.hero
	for i in _cape_btns.size():
		_cape_btns[i].button_pressed = i == p.cape
	_hero_desc.text = Game.HERO_BLURB.get(p.hero, "")
	_hat_btn.visible = CharacterModel.HEROES[p.hero].hat != ""
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": p.show_hat, "weapon": "rusty_sword", "shield": "shield_round", "scale": 1.0}
	if p.cape > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
	_preview.setup(cfg)
	if cheer:
		_preview.play_role("cheer")

func _process(delta: float) -> void:
	if current == "creator" and _preview:
		_preview.rotation.y += delta * 0.45

# ---------------------------------------------------------------------------
func _build_pause() -> void:
	var p := _center_panel("pause", 420, 580)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var t := UIKit.label("Paused", 40, UIKit.GOLD, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", func() -> void: resume_requested.emit(), 360))
	v.add_child(_button("Inventory & Character", func() -> void: show_panel("inventory"), 360))
	v.add_child(_button("Toggle sound", func() -> void: _toggle_mute(), 360))
	var mv := _button("", func() -> void: pass, 360)
	mv.text = "Movement: Strafe (face camera)"
	mv.pressed.connect(func() -> void:
		Game.strafe_mode = not Game.strafe_mode
		mv.text = "Movement: Strafe (face camera)" if Game.strafe_mode else "Movement: Free (face where you run)")
	v.add_child(mv)
	var sl_row := HBoxContainer.new(); sl_row.add_theme_constant_override("separation", 10)
	sl_row.add_child(UIKit.label("Mouse", 17, UIKit.DIM))
	var sl := HSlider.new(); sl.min_value = 0.0006; sl.max_value = 0.006; sl.step = 0.0002
	sl.value = Game.mouse_sens; sl.custom_minimum_size = Vector2(280, 30)
	sl.value_changed.connect(func(val: float) -> void: Game.mouse_sens = val)
	sl_row.add_child(sl)
	v.add_child(sl_row)
	v.add_child(_button("Restart adventure", func() -> void: restart_requested.emit(), 360))
	v.add_child(_button("Quit game", func() -> void: quit_requested.emit(), 360))

func _build_inventory() -> void:
	var p := _center_panel("inventory", 1000, 640)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 30); p.add_child(h)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 360; h.add_child(left)
	left.add_child(UIKit.label("Character", 30, UIKit.GOLD, true))
	_stats_label = UIKit.label("", 18)
	left.add_child(_stats_label)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(right)
	right.add_child(UIKit.label("Inventory", 30, UIKit.GOLD, true))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(560, 470); right.add_child(sc)
	_inv_list = VBoxContainer.new(); _inv_list.add_theme_constant_override("separation", 8)
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_inv_list)
	right.add_child(UIKit.label("[I] or [Esc] to close", 14, UIKit.DIM))

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var t := int(Game.play_time)
	_stats_label.text = "%s the %s\n\nLevel %d   (%d / %d XP)\nHealth   %d / %d\nMana     %d / %d\nStamina  %d\n\nAttack   %.0f\nArcane   %.0f\nDefense  %.0f  (-%d%% damage)\n\nGold %d   ·   Draughts %d\nFoes defeated %d\nTime in the Vault %d:%02d" % [
		Game.profile.name, Game.profile.hero, Game.level, Game.xp, Game.xp_to_next(),
		int(maxf(Game.hp, 0)), int(Game.max_hp()), int(Game.mana), int(Game.max_mana()), int(Game.max_stamina()),
		Game.attack_damage(), Game.spell_damage(), Game.defense(), int(round(Game.defense() / (Game.defense() + 45.0) * 100.0)),
		Game.gold, Game.potions, Game.kills, t / 60, t % 60]

func _refresh_inventory() -> void:
	if _inv_list == null:
		return
	for c in _inv_list.get_children():
		c.queue_free()
	for id in Game.inventory:
		var it: Dictionary = Game.ITEMS[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIKit.panel_style(0.6, it.color, 4))
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14); row.add_child(hb)
		var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
		var stat := ""
		if it.has("damage"): stat = "  +%d attack" % it.damage
		if it.has("defense"): stat = "  %d defense" % it.defense
		vb.add_child(UIKit.label("%s%s" % [it.name, stat], 19, it.color, true))
		var d := UIKit.label(it.desc, 15, UIKit.DIM); d.autowrap_mode = TextServer.AUTOWRAP_WORD; d.custom_minimum_size.x = 340
		vb.add_child(d)
		var slot: String = it.slot
		if slot in ["weapon", "armor", "artifact"]:
			var eq: bool = Game.equipped[slot] == id
			if eq and slot != "artifact":
				hb.add_child(UIKit.label("Equipped", 16, UIKit.GOLD))
			else:
				var b := Button.new(); b.text = "Unequip" if eq else "Equip"; b.custom_minimum_size = Vector2(120, 40)
				b.pressed.connect(func() -> void:
					if eq:
						Game.unequip_artifact()
					else:
						Game.equip(id))
				hb.add_child(b)
		_inv_list.add_child(row)

func _build_lore() -> void:
	var p := _center_panel("lore", 760, 460)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16); p.add_child(v)
	_lore_title = UIKit.label("", 32, UIKit.GOLD, true); v.add_child(_lore_title)
	_lore_text = UIKit.label("", 19, UIKit.PARCH)
	_lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lore_text.custom_minimum_size = Vector2(700, 300)
	v.add_child(_lore_text)
	v.add_child(_button("Close  [E]", func() -> void: resume_requested.emit(), 200))

func show_lore(t: String, body: String) -> void:
	_lore_title.text = t
	_lore_text.text = body
	show_panel("lore")

func _build_death() -> void:
	var p := _center_panel("death", 560, 300)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 18); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	var t := UIKit.label("YOU HAVE FALLEN", 44, Color(0.85, 0.2, 0.15), true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_death_label = UIKit.label("", 18, UIKit.PARCH); _death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_death_label)
	v.add_child(_button("Rise again", func() -> void: respawn_requested.emit(), 300))

func show_death() -> void:
	_death_label.text = "You will wake at the shrine of %s.\nYour gear and experience are kept." % Game.checkpoint_name
	show_panel("death")

func _build_victory() -> void:
	var p := _center_panel("victory", 760, 560)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	var t := UIKit.label("THE HEART IS YOURS", 46, UIKit.GOLD, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIKit.label("The Warden has fallen and the Heart of Ashkar beats in your hands.\nAbove, dawn breaks over the old outpost.", 19, UIKit.PARCH)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_victory_stats = UIKit.label("", 18, UIKit.PARCH); _victory_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_victory_stats)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	hb.add_child(_button("Play again", func() -> void: restart_requested.emit(), 240))
	hb.add_child(_button("Quit", func() -> void: quit_requested.emit(), 200))

func show_victory() -> void:
	var t := int(Game.play_time)
	_victory_stats.text = "%s the %s  ·  Level %d\nFoes defeated: %d   ·   Gold: %d\nTime: %d:%02d" % [Game.profile.name, Game.profile.hero, Game.level, Game.kills, Game.gold, t / 60, t % 60]
	show_panel("victory")
