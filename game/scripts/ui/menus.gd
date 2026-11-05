extends CanvasLayer
class_name Menus
## Title screen, character creator (live 3D preview), pause, inventory &
## character sheet, lore reader, death and victory screens.

signal start_requested
signal resume_requested
signal respawn_requested
signal restart_requested
signal quit_requested
signal continue_requested(slot: int)
signal exit_to_title_requested
signal forest_requested

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

const PREVIEW_COMPAT_EXPOSURE := 0.68
const PREVIEW_COMPAT_KEY := 0.45
const NAMES := ["Bobek", "Sir Bobek", "Lady Bobeka", "Bobek the Bold", "Bobek the Brave", "Bobekus Maximus", "Little Bobek", "Big Bobek", "Bobek Jr.", "Bobekovich", "Bobekson", "Bobekina", "Bo'Bek", "Bobbek", "Archmage Bobek", "Bobek the Unkillable", "Bobek of the Deep", "Grandmaster Bobek", "Bobekzilla", "Bobek Bobekington", "Bobek the Snack-Sized", "Bobek McBobface", "Bobek the Sneaky", "Captain Bobek", "Bobek the Tea-Drinker", "Bobek Sparklepants", "Baron von Bobek", "Bobek the Unbonked", "Bobek Supreme", "Teeny Tiny Bobek", "Bobek the Magnificent", "Bobekachu", "Bobek of the Forest", "Bob-Ek", "Bobek the Goblin Bonker", "Bobek Prime", "Bobeky Boo", "Bobek the Brushed (Teeth)", "Sir Bobs-a-Lot", "Bobek the Untrippable", "Bobek Danger", "Professor Bobek", "Bobek the Wise-ish", "B. O. Bek", "Bobek the Snorer", "Bobek Thunderpants", "Dr. Bobek", "Bobek the Bouncy", "Kingbobek", "Bobek the Legend", "Bobek Quickfingers", "Bobek the Pancake Lover", "Bobekasaurus Rex", "Bobek 3000", "Bobek the Unstoppable", "Mega Bobek", "Bobek Shadowstep", "Bobek of the Seven Snacks", "Bobek the Kettle Master", "Bobek von Sneakypants"]

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
	_build_slots()
	_build_pause()
	_build_inventory()
	_build_lore()
	_build_death()
	_build_victory()
	_build_dialogue()
	_build_forest_victory()
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
	if n == "title" and _continue_btn:
		_continue_btn.visible = Game.any_save()
	if n == "inventory":
		_refresh_inventory(); _refresh_stats()
	if n == "pause" and _arrange_btn:
		_arrange_btn.visible = Game.touch_active
		_reset_btn.visible = Game.touch_active

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
	var t1 := UIKit.label("BOBEK'S ADVENTURE", 76, UIKit.GOLD, true)
	v.add_child(t1)
	var t2 := UIKit.label("Into the Deep Vault. Beneath the cliffs of Ashkar, a light still beats in the dark.", 22, UIKit.PARCH)
	v.add_child(t2)
	var sp := Control.new(); sp.custom_minimum_size.y = 40; v.add_child(sp)
	_continue_btn = _button("Continue", func() -> void: _open_slots("continue"))
	_continue_btn.custom_minimum_size.y = 58
	_continue_btn.add_theme_font_size_override("font_size", 24)
	v.add_child(_continue_btn)
	v.add_child(_button("New Adventure", func() -> void: _new_adventure()))
	_mute_btn = _button(_sound_label(), func() -> void: _toggle_mute())
	v.add_child(_mute_btn)
	v.add_child(_button("Quit", func() -> void: quit_requested.emit()))
	var cover := TextureRect.new()
	cover.texture = load("res://assets/ui/cover_art.png")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	cover.offset_left = -560; cover.offset_right = -70; cover.offset_top = -245; cover.offset_bottom = 245
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(cover)
	var foot := UIKit.label("An open-source experiment · Godot 4.5 · Assets: KayKit (CC0), Poly Haven (CC0), original procedural art & sound", 14, UIKit.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(110, -50)
	c.add_child(foot)
	# Browsers keep audio locked until the first tap. On the web, the first screen
	# asks for that tap, so the music starts the moment the title appears.
	if OS.has_feature("web"):
		var gate := Button.new()
		gate.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.94)
		for st in ["normal", "hover", "pressed", "focus"]:
			gate.add_theme_stylebox_override(st, sb)
		var art := TextureRect.new()
		art.texture = load("res://assets/ui/cover_art.png")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.anchor_bottom = 0.82
		art.offset_top = 30
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gate.add_child(art)
		var tap := UIKit.label("Tap anywhere to begin  ·  this turns the sound on", 30, UIKit.GOLD, true)
		tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tap.offset_top = -120; tap.offset_bottom = -60
		tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gate.add_child(tap)
		var tw := tap.create_tween().set_loops()
		tw.tween_property(tap, "modulate:a", 0.45, 0.9)
		tw.tween_property(tap, "modulate:a", 1.0, 0.9)
		gate.pressed.connect(func() -> void:
			gate.queue_free()
			Sfx.set_muted(false)
			_mute_btn.text = _sound_label()
			Sfx.restart_music()
			Sfx.play("levelup", -8.0, 0.0))
		c.add_child(gate)
		_audio_gate = gate

func _sound_label() -> String:
	return "Sound is OFF  (tap to turn on)" if Sfx.muted else "Sound is ON  (tap to mute)"

func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)
	_mute_btn.text = _sound_label()
	if _pause_sound_btn:
		_pause_sound_btn.text = _sound_label()

# ---------------------------------------------------------------------------
func _swatch(col: Color, tip: String, cb: Callable, w := 48.0, txt := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 54)
	b.tooltip_text = tip
	b.toggle_mode = true
	b.text = txt
	var sb := StyleBoxFlat.new(); sb.bg_color = col
	sb.set_corner_radius_all(6); sb.border_color = Color(0, 0, 0, 0.6); sb.set_border_width_all(2)
	var sbp := sb.duplicate() as StyleBoxFlat; sbp.border_color = Color(1, 0.92, 0.6); sbp.set_border_width_all(6)
	sbp.expand_margin_left = 3; sbp.expand_margin_right = 3; sbp.expand_margin_top = 3; sbp.expand_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sbp); b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("hover_pressed", sbp)
	b.add_theme_color_override("font_color", Color(1, 1, 1)); b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func() -> void:
		Sfx.play("footstep", -10.0, 0.0)
		cb.call())
	return b

func _choice(text: String, cb: Callable, w := 118.0) -> Button:
	var b := Button.new(); b.text = text; b.toggle_mode = true
	b.custom_minimum_size = Vector2(w, 42)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void:
		Sfx.play("footstep", -10.0, 0.0)
		cb.call())
	return b

func _grid(cols: int, parent: Control) -> GridContainer:
	var g := GridContainer.new(); g.columns = cols
	g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	return g

static var _grab_tex: Texture2D
func _style_slider(sl: HSlider) -> void:
	if _grab_tex == null:
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		for y in 40:
			for x in 40:
				var d := Vector2(x - 19.5, y - 19.5).length()
				var a := clampf(19.0 - d, 0.0, 1.0)
				var c := Color(1.0, 0.86, 0.5) if d < 14.0 else Color(0.35, 0.25, 0.1)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
		_grab_tex = ImageTexture.create_from_image(img)
	for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
		sl.add_theme_icon_override(k, _grab_tex)
	var track := StyleBoxFlat.new(); track.bg_color = Color(0.2, 0.17, 0.14); track.set_corner_radius_all(6)
	track.content_margin_top = 6; track.content_margin_bottom = 6
	var fillsb := StyleBoxFlat.new(); fillsb.bg_color = Color(0.75, 0.58, 0.28); fillsb.set_corner_radius_all(6)
	fillsb.content_margin_top = 6; fillsb.content_margin_bottom = 6
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fillsb)
	sl.add_theme_stylebox_override("grabber_area_highlight", fillsb)

func _heading(t: String, parent: Control) -> void:
	parent.add_child(UIKit.label(t, 20, UIKit.GOLD, true))

func _slider(lo: float, hi: float, key: String, left: String, right: String, parent: Control) -> HSlider:
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 10); parent.add_child(r)
	var l1 := UIKit.label(left, 19, UIKit.PARCH); l1.custom_minimum_size.x = 80; r.add_child(l1)
	var sl := HSlider.new(); sl.min_value = lo; sl.max_value = hi; sl.step = 0.01
	sl.custom_minimum_size = Vector2(520, 56)
	_style_slider(sl); sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value = float(Game.profile.get(key, 1.0))
	sl.value_changed.connect(func(v: float) -> void:
		Game.profile[key] = v
		_refresh_preview())
	r.add_child(sl)
	r.add_child(UIKit.label(right, 19, UIKit.PARCH))
	return sl

var _skin_btns: Array[Button] = []
var _hair_btns := {}
var _hcol_btns: Array[Button] = []
var _face_btns := {}
var _build_sl: HSlider
var _height_sl: HSlider
var _hair_note: Label
var _tab_btns := {}
var _tab_pages := {}
var _tab := "hero"
var _preview_cam: Camera3D
var _spin_hold := 0.0
var _cam_t := 0.0          # 0 = full body, 1 = face close-up

const CREATOR_TABS := [["hero", "Hero"], ["body", "Body"], ["hair", "Hair"], ["face", "Face"], ["colours", "Colours"]]

func _page(id: String, parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	_tab_pages[id] = v
	return v

func _set_tab(id: String) -> void:
	_tab = id
	for k in _tab_pages:
		(_tab_pages[k] as Control).visible = k == id
	for k in _tab_btns:
		(_tab_btns[k] as Button).set_pressed_no_signal(k == id)
	if id in ["hair", "face"]:
		_spin_hold = 0.0
	_refresh_preview()

## Any hair choice takes the helm off, otherwise the change would be invisible.
func _hair_changed() -> void:
	if CharacterModel.HEROES[Game.profile.hero].hat != "":
		Game.profile.show_hat = false
	_refresh_preview()

func _build_creator() -> void:
	var p := _center_panel("creator", 1540, 860)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 26)
	p.add_child(h)
	# ---- live preview: drag to spin; zooms to the face for hair and face
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(560, 820)
	svc.stretch = true
	svc.gui_input.connect(func(ev: InputEvent) -> void:
		var dx := 0.0
		if ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			dx = (ev as InputEventMouseMotion).relative.x
		elif ev is InputEventScreenDrag:
			dx = (ev as InputEventScreenDrag).relative.x
		if dx != 0.0 and _preview:
			_preview.rotation.y += dx * 0.012
			_spin_hold = 3.0)
	h.add_child(svc)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = false
	_preview_vp.size = Vector2i(560, 820)
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_preview_vp)
	var w := Node3D.new(); _preview_vp.add_child(w)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.4, 0.38, 0.48); e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	# The web/iPad renderer has no AgX tone curve, so the same lights come out much
	# brighter and pale colours wash to white. Give it its own, gentler lighting.
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if compat:
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		e.tonemap_exposure = PREVIEW_COMPAT_EXPOSURE
		e.ambient_light_energy = 0.35
		e.glow_enabled = false
	we.environment = e; w.add_child(we)
	var key := SpotLight3D.new(); key.light_color = Color(1.0, 0.85, 0.7); key.light_energy = 14.0 * (PREVIEW_COMPAT_KEY if compat else 1.0); key.spot_range = 12.0; key.spot_angle = 32.0
	key.position = Vector3(1.6, 3.4, 3.4); key.look_at_from_position(key.position, Vector3(0, 1.2, 0)); key.shadow_enabled = true
	w.add_child(key)
	var fill := OmniLight3D.new(); fill.light_color = Color(1.0, 0.95, 0.9); fill.light_energy = 1.2 * (PREVIEW_COMPAT_KEY if compat else 1.0); fill.omni_range = 7.0
	fill.position = Vector3(-1.8, 1.8, 2.6); w.add_child(fill)
	var rim := OmniLight3D.new(); rim.light_color = Color(0.3, 0.6, 1.0); rim.light_energy = 3.0 * (0.6 if compat else 1.0); rim.omni_range = 6.0
	rim.position = Vector3(-1.5, 2.2, -1.6); w.add_child(rim)
	var floor_m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.2; cm.height = 0.2
	floor_m.mesh = cm
	var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/stone.gdshader"); fm.set_shader_parameter("mode", 1)
	floor_m.material_override = fm; floor_m.position.y = -0.1
	w.add_child(floor_m)
	_preview_cam = Camera3D.new(); _preview_cam.fov = 30
	w.add_child(_preview_cam)
	_preview = CharacterModel.new()
	_preview.rotation.y = PI
	w.add_child(_preview)
	_update_preview_cam(1.0)
	# ---- options
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 900
	h.add_child(col)
	col.add_child(UIKit.label("Create Your Adventurer", 34, UIKit.GOLD, true))
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); col.add_child(tabs)
	for t in CREATOR_TABS:
		var id: String = t[0]
		var tb := _choice(t[1], func() -> void: _set_tab(id), 170)
		tb.custom_minimum_size.y = 54
		tb.add_theme_font_size_override("font_size", 21)
		tabs.add_child(tb)
		_tab_btns[id] = tb
	var pages := PanelContainer.new()
	var psb := StyleBoxFlat.new(); psb.bg_color = Color(0, 0, 0, 0.28); psb.set_corner_radius_all(8)
	psb.content_margin_left = 22; psb.content_margin_right = 22; psb.content_margin_top = 18; psb.content_margin_bottom = 18
	pages.add_theme_stylebox_override("panel", psb)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pages)
	var stack := VBoxContainer.new(); pages.add_child(stack)
	# Hero
	var ph := _page("hero", stack)
	var hg := _grid(3, ph)
	for hero in Game.HERO_ORDER:
		var hb := _choice(hero, func() -> void:
			Game.profile.hero = hero
			_refresh_preview(true), 270)
		hb.custom_minimum_size.y = 64
		hb.add_theme_font_size_override("font_size", 22)
		hg.add_child(hb)
		_hero_btns[hero] = hb
	_hero_desc = UIKit.label("", 19, UIKit.PARCH)
	_hero_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hero_desc.custom_minimum_size = Vector2(840, 120)
	ph.add_child(_hero_desc)
	# Body
	var pb := _page("body", stack)
	_heading("Skin", pb)
	var sg := _grid(9, pb)
	for i in Game.SKIN_COLORS.size():
		var idx := i
		var sc: Color = Game.SKIN_COLORS[i] if i > 0 else Color(0.45, 0.42, 0.4)
		var b := _swatch(sc, Game.SKIN_NAMES[i], func() -> void:
			Game.profile.skin = idx
			_refresh_preview(), 84, "Own" if i == 0 else "")
		sg.add_child(b); _skin_btns.append(b)
	_heading("Build", pb)
	_build_sl = _slider(0.82, 1.3, "build", "Skinny", "Big", pb)
	_heading("Height", pb)
	_height_sl = _slider(0.86, 1.14, "height", "Short", "Tall", pb)
	# Hair
	var pr := _page("hair", stack)
	_heading("Style", pr)
	var hsg := _grid(4, pr)
	for i in Game.HAIR_STYLES2.size():
		var st: String = Game.HAIR_STYLES2[i]
		var b := _choice(Game.HAIR_STYLE_NAMES[st], func() -> void:
			Game.profile.hair_style = st
			_hair_changed(), 200)
		b.custom_minimum_size.y = 56
		b.add_theme_font_size_override("font_size", 20)
		hsg.add_child(b); _hair_btns[st] = b
	_heading("Colour", pr)
	var hcg := _grid(10, pr)
	for i in Game.HAIR_COLORS2.size():
		var idx := i
		var b := _swatch(Game.HAIR_COLORS2[i] if i > 0 else Color(0.45, 0.42, 0.4), Game.HAIR_COLOR_NAMES[i], func() -> void:
			Game.profile.hair_color = idx
			_hair_changed(), 76, "Own" if i == 0 else "")
		hcg.add_child(b); _hcol_btns.append(b)
	_hair_note = UIKit.label("", 17, UIKit.DIM)
	pr.add_child(_hair_note)
	# Face
	var pf := _page("face", stack)
	_heading("Face detail", pf)
	var fg := _grid(4, pf)
	for i in Game.FACES.size():
		var f: String = Game.FACES[i]
		var b := _choice(Game.FACE_NAMES[f], func() -> void:
			Game.profile.face = f
			_refresh_preview(), 200)
		b.custom_minimum_size.y = 56
		b.add_theme_font_size_override("font_size", 20)
		fg.add_child(b); _face_btns[f] = b
	pf.add_child(UIKit.label("Beards, mustaches and war paint take your hair colour.", 16, UIKit.DIM))
	# Colours
	var pc := _page("colours", stack)
	_heading("Armor & cloak colour", pc)
	var cg := _grid(7, pc)
	for i in Game.CAPE_COLORS.size():
		var idx := i
		var b := _swatch(Game.CAPE_COLORS[i] if i > 0 else Color(0.5, 0.45, 0.4), Game.CAPE_NAMES[i], func() -> void:
			Game.profile.cape = idx
			_refresh_preview(), 110, "Own" if i == 0 else "")
		cg.add_child(b); _cape_btns.append(b)
	_hat_btn = CheckButton.new(); _hat_btn.text = "Wear helm / hat"; _hat_btn.button_pressed = true
	_hat_btn.add_theme_font_size_override("font_size", 20)
	_hat_btn.toggled.connect(func(on: bool) -> void:
		Game.profile.show_hat = on
		_refresh_preview())
	pc.add_child(_hat_btn)
	# ---- name and buttons
	var nr := HBoxContainer.new(); nr.add_theme_constant_override("separation", 10); col.add_child(nr)
	nr.add_child(UIKit.label("Name", 20, UIKit.DIM, true))
	_name_edit = LineEdit.new(); _name_edit.custom_minimum_size = Vector2(420, 50); _name_edit.max_length = 22
	_name_edit.text = Game.profile.name
	nr.add_child(_name_edit)
	nr.add_child(_button("Random name", func() -> void: _name_edit.text = NAMES.pick_random(), 200))
	var br := HBoxContainer.new(); br.add_theme_constant_override("separation", 12); col.add_child(br)
	br.add_child(_button("Back", func() -> void: show_panel("title"), 150))
	var dice := _button("Surprise me!", func() -> void: _randomize_look(), 300)
	dice.custom_minimum_size.y = 64
	dice.add_theme_font_size_override("font_size", 26)
	var dsb := StyleBoxFlat.new(); dsb.bg_color = Color(0.55, 0.36, 0.08); dsb.set_corner_radius_all(12)
	dsb.border_color = Color(1.0, 0.85, 0.35); dsb.set_border_width_all(3)
	var dsh := dsb.duplicate() as StyleBoxFlat; dsh.bg_color = Color(0.72, 0.48, 0.1)
	dice.add_theme_stylebox_override("normal", dsb); dice.add_theme_stylebox_override("hover", dsh)
	dice.add_theme_stylebox_override("pressed", dsh); dice.add_theme_stylebox_override("focus", dsb)
	dice.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	dice.tooltip_text = "Random look, colours and a silly Bobek name"
	br.add_child(dice)
	var spc := Control.new(); spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; br.add_child(spc)
	br.add_child(_button("Enter the Vault", func() -> void:
		var nm := _name_edit.text.strip_edges()
		Game.profile.name = nm if nm != "" else "Nameless"
		start_requested.emit(), 320))
	_set_tab("hero")

func _randomize_look() -> void:
	var p := Game.profile
	p.skin = randi() % Game.SKIN_COLORS.size()
	p.hair_style = Game.HAIR_STYLES2.pick_random()
	p.hair_color = randi() % Game.HAIR_COLORS2.size()
	p.face = Game.FACES.pick_random()
	p.cape = randi() % Game.CAPE_COLORS.size()
	p.build = snappedf(randf_range(0.85, 1.25), 0.01)
	p.height = snappedf(randf_range(0.88, 1.12), 0.01)
	p.show_hat = false
	_name_edit.text = NAMES.pick_random()
	_build_sl.set_value_no_signal(p.build)
	_height_sl.set_value_no_signal(p.height)
	_refresh_preview(true)

func _refresh_preview(cheer := false) -> void:
	if _preview == null:
		return
	var p := Game.profile
	for k in _hero_btns:
		(_hero_btns[k] as Button).set_pressed_no_signal(k == p.hero)
	for i in _cape_btns.size():
		_cape_btns[i].set_pressed_no_signal(i == p.cape)
	for i in _skin_btns.size():
		_skin_btns[i].set_pressed_no_signal(i == int(p.skin))
	for i in _hcol_btns.size():
		_hcol_btns[i].set_pressed_no_signal(i == int(p.hair_color))
	for k in _hair_btns:
		(_hair_btns[k] as Button).set_pressed_no_signal(k == CharacterModel.hair_style_of(String(p.hair_style)))
	for k in _face_btns:
		(_face_btns[k] as Button).set_pressed_no_signal(k == p.face)
	var ab := Game.ability()
	_hero_desc.text = "%s\n\nSpecial move: %s\n%s" % [Game.HERO_BLURB.get(p.hero, ""), ab.name, ab.desc]
	var hero: Dictionary = CharacterModel.HEROES[p.hero]
	_hat_btn.visible = hero.hat != ""
	_hat_btn.set_pressed_no_signal(p.show_hat)
	if String(hero.path).contains("Hooded"):
		_hair_note.text = "The Ranger always wears the hood, so hair styles don't show (hair colour still tints the brows and beard)."
	else:
		_hair_note.text = "Picking hair takes the helm off so you can see it (put it back on under Colours)."
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": p.show_hat, "weapon": "rusty_sword", "shield": "shield_round", "scale": 1.0}
	if p.cape > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
		cfg["outfit_color"] = Game.CAPE_COLORS[p.cape]
	Player._apply_profile_looks(cfg)
	_preview.setup(cfg)
	if cheer:
		_preview.play_role("cheer")

func _update_preview_cam(k: float) -> void:
	var face := _tab in ["hair", "face"]
	_cam_t = lerpf(_cam_t, 1.0 if face else 0.0, k)
	var hgt := float(Game.profile.get("height", 1.0))
	var body_pos := Vector3(0, 1.45, 6.8); var body_at := Vector3(0, 1.1, 0)
	var face_pos := Vector3(0, 1.85 * hgt, 3.0); var face_at := Vector3(0, 1.62 * hgt, 0)
	_preview_cam.position = body_pos.lerp(face_pos, _cam_t)
	_preview_cam.look_at(body_at.lerp(face_at, _cam_t))

func _process(delta: float) -> void:
	if current == "creator" and _preview:
		_update_preview_cam(1.0 - exp(-6.0 * delta))
		_spin_hold -= delta
		if _spin_hold <= 0.0:
			if _tab in ["hair", "face"]:
				# turn gently from side to side so the hair can be seen from all angles
				var want := PI + sin(Time.get_ticks_msec() * 0.0007) * 0.9
				_preview.rotation.y = lerp_angle(_preview.rotation.y, want, 1.0 - exp(-2.0 * delta))
			else:
				_preview.rotation.y += delta * 0.45

# ---------------------------------------------------------------------------
# Save slots: three characters. "continue" mode picks one to play; "replace"
# mode (all three in use) picks one to overwrite with a new adventure.
var _continue_btn: Button
var _slots_box: HBoxContainer
var _slots_title: Label
var _slots_mode := "continue"
var _delete_armed := -1

func _new_adventure() -> void:
	var i := Game.first_empty_slot()
	if i < 0:
		_open_slots("replace")
		return
	Game.active_slot = i
	show_panel("creator")

func _open_slots(mode: String) -> void:
	_slots_mode = mode
	_delete_armed = -1
	show_panel("slots")
	_refresh_slots()

func _build_slots() -> void:
	var p := _center_panel("slots", 1420, 700)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 18); p.add_child(v)
	_slots_title = UIKit.label("", 36, UIKit.GOLD, true)
	_slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_slots_title)
	_slots_box = HBoxContainer.new(); _slots_box.add_theme_constant_override("separation", 24)
	_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_slots_box)
	var br := HBoxContainer.new(); br.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(br)
	br.add_child(_button("Back", func() -> void: show_panel("title"), 220))

func _refresh_slots() -> void:
	for ch in _slots_box.get_children():
		ch.queue_free()
	_slots_title.text = "Choose a hero to continue" if _slots_mode == "continue" else "All three slots are in use: pick one to replace"
	for i in Game.SAVE_SLOTS:
		var info := Game.slot_summary(i)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(430, 520)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.06, 0.06, 0.92); sb.set_corner_radius_all(10)
		sb.border_color = UIKit.GOLD if not info.is_empty() else Color(0.35, 0.3, 0.25); sb.set_border_width_all(3)
		sb.content_margin_left = 24; sb.content_margin_right = 24; sb.content_margin_top = 20; sb.content_margin_bottom = 20
		card.add_theme_stylebox_override("panel", sb)
		_slots_box.add_child(card)
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 10); card.add_child(cv)
		cv.add_child(UIKit.label("Slot %d" % (i + 1), 18, UIKit.DIM, true))
		var idx := i
		if info.is_empty():
			cv.add_child(UIKit.label("Empty", 34, Color(0.6, 0.55, 0.5), true))
			var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; cv.add_child(sp)
			cv.add_child(_button("New adventure here", func() -> void:
				Game.active_slot = idx
				show_panel("creator"), 380))
			continue
		var nm := UIKit.label(info.name, 32, UIKit.GOLD, true)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		cv.add_child(nm)
		var ab: Dictionary = Game.ABILITIES.get(info.hero, {})
		cv.add_child(UIKit.label("Level %d %s" % [info.level, info.hero], 24, UIKit.PARCH, true))
		cv.add_child(UIKit.label("Special: %s" % ab.get("name", ""), 17, ab.get("color", UIKit.DIM)))
		cv.add_child(UIKit.label(info.zone, 19, Color(0.6, 0.95, 0.6) if info.zone.contains("Forest") else Color(0.75, 0.8, 1.0), true))
		var where := UIKit.label(("Forest saved: Level 2 complete!" if info.forest_won else "Last shrine: " + info.where), 18, UIKit.PARCH)
		where.autowrap_mode = TextServer.AUTOWRAP_WORD
		cv.add_child(where)
		if info.objective != "" and not info.forest_won:
			var ob := UIKit.label(info.objective, 16, UIKit.DIM)
			ob.autowrap_mode = TextServer.AUTOWRAP_WORD
			cv.add_child(ob)
		cv.add_child(UIKit.label("Played %s · %d gold" % [info.time, info.gold], 16, UIKit.DIM))
		cv.add_child(UIKit.label("Saved %s" % info.ago, 16, UIKit.DIM))
		var sp2 := Control.new(); sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL; cv.add_child(sp2)
		if _slots_mode == "continue":
			var go := _button("Continue", func() -> void: continue_requested.emit(idx), 380)
			go.custom_minimum_size.y = 60
			go.add_theme_font_size_override("font_size", 24)
			cv.add_child(go)
			var del := _button("Tap again to delete" if _delete_armed == idx else "Delete", func() -> void:
				if _delete_armed == idx:
					Game.delete_slot(idx)
					_delete_armed = -1
					if not Game.any_save():
						show_panel("title")
						return
				else:
					_delete_armed = idx
				_refresh_slots(), 380)
			del.custom_minimum_size.y = 40
			del.add_theme_font_size_override("font_size", 15)
			cv.add_child(del)
		else:
			cv.add_child(_button("Replace with a new hero", func() -> void:
				Game.delete_slot(idx)
				Game.active_slot = idx
				show_panel("creator"), 380))

var _arrange_btn: Button
var _reset_btn: Button
func _build_pause() -> void:
	var p := _center_panel("pause", 420, 760)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var t := UIKit.label("Paused", 40, UIKit.GOLD, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", func() -> void: resume_requested.emit(), 360))
	v.add_child(_button("Inventory & Character", func() -> void: show_panel("inventory"), 360))
	_pause_sound_btn = _button(_sound_label(), func() -> void: _toggle_mute(), 360)
	v.add_child(_pause_sound_btn)
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
	_arrange_btn = _button("Arrange touch buttons", func() -> void:
		var m := get_parent()
		if m and m.get("touch"):
			close_all()                       # stay paused while arranging
			m.touch.set_arrange(true), 360)
	v.add_child(_arrange_btn)
	_reset_btn = _button("Reset touch buttons", func() -> void:
		var m := get_parent()
		if m and m.get("touch"):
			m.touch.reset_layout()
			Game.say("Touch buttons back to the default layout.", UIKit.PARCH), 360)
	v.add_child(_reset_btn)
	v.add_child(_button("Save & exit to title", func() -> void: exit_to_title_requested.emit(), 360))
	v.add_child(_button("Restart adventure", func() -> void: restart_requested.emit(), 360))
	v.add_child(_button("Quit game", func() -> void: quit_requested.emit(), 360))

func _build_inventory() -> void:
	var p := _center_panel("inventory", 1220, 760)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 26); p.add_child(h)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 380; left.add_theme_constant_override("separation", 8); h.add_child(left)
	left.add_child(UIKit.label("Character", 30, UIKit.GOLD, true))
	_stats_label = UIKit.label("", 17)
	left.add_child(_stats_label)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation", 8); h.add_child(right)
	var head := HBoxContainer.new()
	head.add_child(UIKit.label("Equipped", 26, UIKit.GOLD, true))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(spacer)
	var x := Button.new(); x.text = "✕  Close"; x.custom_minimum_size = Vector2(150, 50)
	x.pressed.connect(func() -> void: resume_requested.emit())
	head.add_child(x)
	_bag_close = x
	right.add_child(head)
	_equipped_box = VBoxContainer.new(); _equipped_box.add_theme_constant_override("separation", 6)
	right.add_child(_equipped_box)
	right.add_child(UIKit.label("Bag", 26, UIKit.GOLD, true))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(760, 370); right.add_child(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inv_list = VBoxContainer.new(); _inv_list.add_theme_constant_override("separation", 8)
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_inv_list)
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 16)
	foot.add_child(_button("Close", func() -> void: resume_requested.emit(), 200))
	foot.add_child(UIKit.label("▲ green = better than what you wear", 14, UIKit.DIM))
	right.add_child(foot)


var _equipped_box: VBoxContainer
var _bag_close: Button
var _pause_sound_btn: Button
var _audio_gate: Button

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var t := int(Game.play_time)
	_stats_label.text = "%s the %s\n\nLevel %d   (%d / %d XP)\nHealth   %d / %d\nMana     %d / %d  (+%.1f/s, +7 per sword hit)\nStamina  %d\n\nAttack   %.0f\nArcane bolt  %.0f  (+%.0f%% spell power)\nDefense  %.0f  (-%d%% damage)\nCritical %.0f%%\nLife steal %.0f%%\n\nGold %d\nHealing draughts %d   Mana potions %d\nFoes defeated %d\nTime in the Vault %d:%02d" % [
		Game.profile.name, Game.profile.hero, Game.level, Game.xp, Game.xp_to_next(),
		int(maxf(Game.hp, 0)), int(Game.max_hp()), int(Game.mana), int(Game.max_mana()), Game.mana_regen(), int(Game.max_stamina()),
		Game.attack_damage(), Game.spell_damage(), Game.spell_power(), Game.defense(), int(round(Game.defense() / (Game.defense() + 45.0) * 100.0)),
		Game.crit_chance() * 100.0, Game.lifesteal() * 100.0,
		Game.gold, Game.potions, Game.mana_potions, Game.kills, t / 60, t % 60]

func _item_row(id: String, equipped_now: bool) -> Control:
	var it: Dictionary = Game.item(id)
	var r: int = it.get("rarity", 0)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.panel_style(0.6, it.get("color", UIKit.GOLD), 4))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12); row.add_child(hb)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
	var slot: String = it.get("slot", "")
	vb.add_child(UIKit.label("%s   [%s %s]" % [it.name, Loot.RARITY_NAMES[r], Game.SLOT_NAMES.get(slot, slot)], 18, it.get("color", UIKit.PARCH), true))
	var lines := Game.item_lines(id)
	var stat := UIKit.label(", ".join(lines) if lines.size() > 0 else String(it.get("desc", "")), 15, UIKit.PARCH)
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD; stat.custom_minimum_size.x = 480
	vb.add_child(stat)
	if slot in Game.SLOTS and not equipped_now:
		var cur: String = Game.equipped.get(slot, "")
		var diff := Game.score(id) - Game.score(cur)
		var cmp := UIKit.label(("▲ better (+%.0f)" if diff > 0.5 else ("▼ weaker (%.0f)" if diff < -0.5 else "about the same")) % diff, 14,
			Color(0.4, 1.0, 0.45) if diff > 0.5 else (Color(1.0, 0.45, 0.4) if diff < -0.5 else UIKit.DIM))
		vb.add_child(cmp)
	if slot == "skin" and it.has("desc"):
		var d := UIKit.label(String(it.desc), 14, UIKit.DIM); d.autowrap_mode = TextServer.AUTOWRAP_WORD; d.custom_minimum_size.x = 480
		vb.add_child(d)
	if slot in Game.SLOTS:
		if equipped_now:
			if slot in ["artifact", "skin"]:
				var ub := Button.new(); ub.text = "Remove"; ub.custom_minimum_size = Vector2(118, 46)
				ub.pressed.connect(func() -> void: Game.unequip(slot))
				hb.add_child(ub)
		else:
			var eb := Button.new(); eb.text = "Wear" if slot == "skin" else "Equip"; eb.custom_minimum_size = Vector2(118, 46)
			eb.pressed.connect(func() -> void: Game.equip(id))
			hb.add_child(eb)
			if not Game.ITEMS.has(id):
				var sb := Button.new(); sb.text = "Salvage %dg" % Loot.salvage_value(it); sb.custom_minimum_size = Vector2(140, 46)
				sb.pressed.connect(func() -> void: Game.salvage(id))
				hb.add_child(sb)
	return row

func _refresh_inventory() -> void:
	if _inv_list == null:
		return
	for c in _equipped_box.get_children():
		c.queue_free()
	for c in _inv_list.get_children():
		c.queue_free()
	for slot in Game.SLOTS:
		var id: String = Game.equipped.get(slot, "")
		if id == "":
			_equipped_box.add_child(UIKit.label("%s: (empty)" % Game.SLOT_NAMES[slot], 16, UIKit.DIM))
		else:
			_equipped_box.add_child(_item_row(id, true))
	# a magic costume you're wearing, with its time left and a way to take it off
	if Game.costume_id() != "":
		var c: Dictionary = Loot.COSTUMES.get(Game.costume_id(), {})
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
		row.add_child(UIKit.label("Costume: %s  (%s left)" % [c.get("name", "?"), Game.costume_time_text()], 17, Color(1.0, 0.7, 1.0), true))
		row.add_child(_button("Take it off", func() -> void:
			Game.clear_costume()
			Game.say("You take off the costume. Back to your old self!", Color(1.0, 0.85, 0.6))
			_refresh_inventory(), 170))
		_equipped_box.add_child(row)
	var bag: Array = []
	for id in Game.inventory:
		if not Game.equipped.values().has(id):
			bag.append(id)
	bag.sort_custom(func(a, b) -> bool:
		var ra: int = Game.item(a).get("rarity", 0); var rb: int = Game.item(b).get("rarity", 0)
		return ra > rb if ra != rb else Game.score(a) > Game.score(b))
	if bag.is_empty():
		_inv_list.add_child(UIKit.label("Nothing else yet. Open chests and defeat monsters to find gear!", 16, UIKit.DIM))
	for id in bag:
		_inv_list.add_child(_item_row(id, false))

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
	var p := _center_panel("victory", 820, 660)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	var t := UIKit.label("THE HEART IS YOURS", 46, UIKit.GOLD, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIKit.label("The Warden has fallen and the Heart of Ashkar beats in your hands.\nAbove, dawn breaks over the old outpost.", 19, UIKit.PARCH)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_victory_stats = UIKit.label("", 18, UIKit.PARCH); _victory_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_victory_stats)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	var go := _button("Step through the portal  →  Level 2: The Goblin Forest", func() -> void: forest_requested.emit(), 640)
	go.custom_minimum_size.y = 62
	go.add_theme_font_size_override("font_size", 22)
	v.add_child(go)
	hb.add_child(_button("Play the Vault again", func() -> void: restart_requested.emit(), 300))
	hb.add_child(_button("Quit", func() -> void: quit_requested.emit(), 200))

func show_victory() -> void:
	var t := int(Game.play_time)
	_victory_stats.text = "Level 1 complete!\nA shimmering portal has opened behind the altar.\n\n%s the %s  ·  Level %d\nFoes defeated: %d   ·   Gold: %d\nTime: %d:%02d" % [Game.profile.name, Game.profile.hero, Game.level, Game.kills, Game.gold, t / 60, t % 60]
	show_panel("victory")

# ---------------------------------------------------------------------------
# NPC dialogue: who they are, what they need, and the quest buttons.
var _dlg_name: Label
var _dlg_title: Label
var _dlg_text: Label
var _dlg_buttons: HBoxContainer
var _dlg_npc: NPC

func _build_dialogue() -> void:
	var p := _center_panel("dialogue", 980, 560)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); p.add_child(v)
	_dlg_name = UIKit.label("", 34, UIKit.GOLD, true)
	v.add_child(_dlg_name)
	_dlg_title = UIKit.label("", 20, Color(1.0, 0.82, 0.3), true)
	v.add_child(_dlg_title)
	_dlg_text = UIKit.label("", 22, UIKit.PARCH)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dlg_text.custom_minimum_size = Vector2(920, 260)
	_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_dlg_text)
	_dlg_buttons = HBoxContainer.new(); _dlg_buttons.add_theme_constant_override("separation", 16)
	_dlg_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_dlg_buttons)

func _dlg_button(text: String, cb: Callable, primary := false) -> void:
	var b := _button(text, cb, 330 if primary else 230)
	b.custom_minimum_size.y = 60 if primary else 52
	b.add_theme_font_size_override("font_size", 23 if primary else 19)
	_dlg_buttons.add_child(b)

func _close_dialogue() -> void:
	var m := get_parent()
	if m and m.has_method("_resume"):
		m._resume()

func show_dialogue(npc: NPC) -> void:
	_dlg_npc = npc
	show_panel("dialogue")
	_refresh_dialogue()

func _refresh_dialogue(extra := "") -> void:
	for c in _dlg_buttons.get_children():
		c.queue_free()
	var q: Dictionary = Game.QUESTS.get(_dlg_npc.quest, {})
	var st := Game.quest_state(_dlg_npc.quest)
	_dlg_name.text = _dlg_npc.display_name
	_dlg_title.text = "Quest: " + String(q.get("title", "")) + {"active": "  (in progress)", "ready": "  (complete!)", "done": "  (done)"}.get(st, "")
	match st:
		"available":
			_dlg_text.text = q.offer
			_dlg_button("Accept quest", func() -> void:
				Game.quest_accept(_dlg_npc.quest)
				_refresh_dialogue(), true)
			_dlg_button("Not now", _close_dialogue)
		"locked":
			_dlg_text.text = q.locked
			_dlg_button("Farewell", _close_dialogue)
		"active":
			_dlg_text.text = "%s\n\n%s: %d / %d" % [q.busy, q.track, Game.quest_progress(_dlg_npc.quest), q.goal.count]
			_dlg_button("On my way", _close_dialogue, true)
		"ready":
			_dlg_text.text = q.thanks
			_dlg_button("Complete quest", func() -> void:
				var got := Game.quest_turn_in(_dlg_npc.quest)
				Sfx.play("levelup", -4.0, 0.0)
				var lines := PackedStringArray()
				var r: Dictionary = q.reward
				lines.append("+%d XP   +%d gold" % [r.get("xp", 0), r.get("gold", 0)])
				if r.get("potions", 0) > 0 or r.get("mana_potions", 0) > 0:
					lines.append("+%d healing   +%d mana potions" % [r.get("potions", 0), r.get("mana_potions", 0)])
				for id in got:
					var it := Game.item(id)
					lines.append("Received: %s (%s)" % [it.get("name", id), Loot.RARITY_NAMES[clampi(int(it.get("rarity", 0)), 0, 4)]])
				_refresh_dialogue("\n".join(lines)), true)
		"done":
			_dlg_text.text = (extra + "\n\n" if extra != "" else "") + "Thank you again, friend. The forest won't forget you."
			_dlg_button("Farewell", _close_dialogue, true)
	if extra != "" and st != "done":
		_dlg_text.text = extra + "\n\n" + _dlg_text.text

# ---------------------------------------------------------------------------
var _forest_stats: Label
func _build_forest_victory() -> void:
	var p := _center_panel("forest_victory", 820, 560)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16); v.alignment = BoxContainer.ALIGNMENT_CENTER; p.add_child(v)
	var t := UIKit.label("THE FOREST IS SAFE", 46, UIKit.GOLD, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s2 := UIKit.label("Chief Gruk is beaten and the goblins are scattered.\nLevel 2 complete! The next adventure is on its way.", 20, UIKit.PARCH)
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s2)
	_forest_stats = UIKit.label("", 18, UIKit.PARCH); _forest_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_forest_stats)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 16); v.add_child(hb)
	hb.add_child(_button("Keep exploring", func() -> void: _close_dialogue(), 280))
	hb.add_child(_button("Save & exit to title", func() -> void: exit_to_title_requested.emit(), 300))

func show_forest_victory() -> void:
	var done := 0
	for q in Game.QUESTS:
		if Game.quest_state(q) == "done":
			done += 1
	var t := int(Game.play_time)
	_forest_stats.text = "%s the %s  ·  Level %d\nQuests done: %d / %d   ·   Foes defeated: %d   ·   Gold: %d\nTime played: %d:%02d" % [
		Game.profile.name, Game.profile.hero, Game.level, done, Game.QUESTS.size(), Game.kills, Game.gold, t / 60, t % 60]
	show_panel("forest_victory")
