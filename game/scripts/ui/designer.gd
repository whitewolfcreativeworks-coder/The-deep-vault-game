extends PanelContainer
class_name SkinDesigner
## The Skin Designer: build your own look from the costumes and armour skins
## you've found. Pick a head, body, arms and legs from any of them (or keep your
## own), give each part a colour and a finish (shadow, ghostly, fiery, rotten),
## spin the preview, then "Wear it". A timed costume from a chest still goes on
## top while it lasts; your design comes back afterwards.
## The look is stored in Game.custom_look (see CharacterModel._wear_custom).

signal closed(wore: bool)

const PART_NAMES := {"head": "HEAD", "body": "BODY", "arms": "ARMS", "legs": "LEGS"}
const TINTS := [null, Color(0.85, 0.15, 0.15), Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.2), Color(0.25, 0.75, 0.3),
	Color(0.2, 0.75, 0.85), Color(0.2, 0.35, 0.95), Color(0.55, 0.25, 0.85), Color(1.0, 0.45, 0.75),
	Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14)]
const FINISHES := ["", "shadow", "deathly", "infernal", "rot"]
const FINISH_NAMES := {"": "Plain", "shadow": "Shadow", "deathly": "Ghostly", "infernal": "Hellfire", "rot": "Rotten"}

var look := {}                 # the design being edited
var sources: Array = []        # "own" + unlocked looks
var _preview: CharacterModel
var _cam: Camera3D
var _vp: SubViewport
var _spin_hold := 0.0
var _src_labels := {}
var _fin_labels := {}
var _swatch_btns := {}
var _note: Label
var _status: Label

func _ready() -> void:
	custom_minimum_size = Vector2(1500, 840)
	anchor_left = 0.5; anchor_right = 0.5; anchor_top = 0.5; anchor_bottom = 0.5
	offset_left = -750; offset_right = 750; offset_top = -420; offset_bottom = 420
	grow_horizontal = Control.GROW_DIRECTION_BOTH; grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

# --- layout ------------------------------------------------------------------------
func _build() -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 24); add_child(h)
	# live preview: drag to spin
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(480, 800)
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
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.size = Vector2i(480, 800); _vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_vp)
	var w := Node3D.new(); _vp.add_child(w)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.06, 0.05, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.45, 0.42, 0.52); e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_AGX; e.glow_enabled = true
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if compat:
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 0.7; e.ambient_light_energy = 0.4; e.glow_enabled = false
	we.environment = e; w.add_child(we)
	var key := SpotLight3D.new(); key.light_color = Color(1.0, 0.88, 0.75); key.light_energy = 14.0 * (0.45 if compat else 1.0)
	key.spot_range = 12.0; key.spot_angle = 34.0; key.shadow_enabled = true
	key.position = Vector3(1.6, 3.4, 3.4); key.look_at_from_position(key.position, Vector3(0, 1.1, 0)); w.add_child(key)
	var fill := OmniLight3D.new(); fill.light_energy = 1.3 * (0.45 if compat else 1.0); fill.omni_range = 7.0; fill.position = Vector3(-1.8, 1.8, 2.6); w.add_child(fill)
	var rim := OmniLight3D.new(); rim.light_color = Color(0.6, 0.4, 1.0); rim.light_energy = 3.0 * (0.6 if compat else 1.0); rim.omni_range = 6.0
	rim.position = Vector3(-1.5, 2.2, -1.6); w.add_child(rim)
	var floor_m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.2; cm.height = 0.2
	floor_m.mesh = cm; var fm := ShaderMaterial.new(); fm.shader = load("res://shaders/stone.gdshader"); fm.set_shader_parameter("mode", 1)
	floor_m.material_override = fm; floor_m.position.y = -0.1; w.add_child(floor_m)
	_cam = Camera3D.new(); _cam.fov = 30; w.add_child(_cam)
	_cam.position = Vector3(0, 1.25, 5.3); _cam.look_at(Vector3(0, 0.95, 0))
	_preview = CharacterModel.new(); _preview.rotation.y = PI; w.add_child(_preview)
	# options
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var head := HBoxContainer.new(); col.add_child(head)
	head.add_child(UIKit.label("Skin Designer", 34, UIKit.GOLD, true))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	head.add_child(_btn("✕  Close", func() -> void: close(false), 150))
	_note = UIKit.label("", 16, UIKit.DIM); _note.autowrap_mode = TextServer.AUTOWRAP_WORD; _note.custom_minimum_size.x = 900
	col.add_child(_note)
	for part in CharacterModel.DESIGN_PARTS:
		var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); col.add_child(box)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); box.add_child(row)
		var pl := UIKit.label(PART_NAMES[part], 22, UIKit.GOLD, true); pl.custom_minimum_size.x = 86; row.add_child(pl)
		row.add_child(_btn("◀", func() -> void: _cycle_src(part, -1), 60))
		var sl := UIKit.label("", 19, UIKit.PARCH, true); sl.custom_minimum_size.x = 300; sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.clip_text = true
		row.add_child(sl); _src_labels[part] = sl
		row.add_child(_btn("▶", func() -> void: _cycle_src(part, 1), 60))
		var gap := Control.new(); gap.custom_minimum_size.x = 18; row.add_child(gap)
		row.add_child(_btn("◀", func() -> void: _cycle_finish(part, -1), 60))
		var fl := UIKit.label("", 18, Color(0.8, 0.65, 1.0), true); fl.custom_minimum_size.x = 120; fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(fl); _fin_labels[part] = fl
		row.add_child(_btn("▶", func() -> void: _cycle_finish(part, 1), 60))
		var sw := HBoxContainer.new(); sw.add_theme_constant_override("separation", 6); box.add_child(sw)
		var pad := Control.new(); pad.custom_minimum_size.x = 86; sw.add_child(pad)
		_swatch_btns[part] = []
		for i in TINTS.size():
			var b := Button.new(); b.custom_minimum_size = Vector2(58, 52); b.toggle_mode = true
			var tc = TINTS[i]
			if tc == null:
				b.text = "Own"
			else:
				var st := StyleBoxFlat.new(); st.bg_color = tc; st.set_corner_radius_all(6)
				st.border_color = Color(0, 0, 0, 0.6); st.set_border_width_all(2)
				var stp := st.duplicate() as StyleBoxFlat; stp.border_color = Color(1, 0.95, 0.6); stp.set_border_width_all(5)
				for s in ["normal", "hover", "focus"]:
					b.add_theme_stylebox_override(s, st)
				b.add_theme_stylebox_override("pressed", stp)
				b.add_theme_stylebox_override("hover_pressed", stp)
			b.pressed.connect(func() -> void: _set_tint(part, i))
			sw.add_child(b)
			(_swatch_btns[part] as Array).append(b)
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 14); col.add_child(foot)
	foot.add_child(_btn("🎲  Random!", func() -> void: randomize_look(), 200))
	foot.add_child(_btn("Start over", func() -> void: _reset_look(), 180))
	foot.add_child(_btn("Take it off", func() -> void: take_off(), 180))
	var wear := _btn("✔  Wear it", func() -> void: wear(), 220)
	wear.add_theme_font_size_override("font_size", 22)
	foot.add_child(wear)
	_status = UIKit.label("", 16, UIKit.DIM); col.add_child(_status)

func _btn(text: String, cb: Callable, w := 200.0) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(w, 58)
	b.pressed.connect(func() -> void:
		Sfx.play("footstep", -8.0, 0.0)
		cb.call())
	return b

# --- state -------------------------------------------------------------------------
func open() -> void:
	sources = ["own"]
	for id in Game.unlocked_looks:
		if CharacterModel.design_source(String(id))[0] != "":
			sources.append(id)
	look = Game.custom_look.duplicate(true) if not Game.custom_look.is_empty() else {}
	for part in CharacterModel.DESIGN_PARTS:
		if not look.has(part) or not look[part] is Dictionary:
			look[part] = {"src": "own", "tint": null, "finish": ""}
		if not sources.has(String(look[part].get("src", "own"))):
			look[part]["src"] = "own"
	_note.text = ("Mix parts from the %d costumes and armour skins you've found. Tap ◀ ▶ to change a part, pick a colour, and try a finish!" % (sources.size() - 1)) \
		if sources.size() > 1 else "Find costumes and armour skins in chests to unlock more parts! For now you can recolour your own outfit."
	_status.text = "You're wearing your design." if Game.custom_look_on else ""
	_refresh()

static func source_name(id: String) -> String:
	if id == "own":
		return "Your own"
	if Loot.COSTUMES.has(id):
		return String(Loot.COSTUMES[id].name)
	for a in Loot.ARMOR_SKINS:
		if a.outfit == id and not a.has("fx"):
			return String(a.name)
	return id.get_file().replace("_", " ")

func set_part(part: String, src: String, tint = null, finish := "") -> void:
	look[part] = {"src": src if sources.has(src) else "own", "tint": tint, "finish": finish}
	_refresh()

func _cycle_src(part: String, d: int) -> void:
	var i := sources.find(String(look[part].src))
	look[part].src = sources[(i + d + sources.size()) % sources.size()]
	_refresh()

func _cycle_finish(part: String, d: int) -> void:
	var i := FINISHES.find(String(look[part].get("finish", "")))
	look[part].finish = FINISHES[(i + d + FINISHES.size()) % FINISHES.size()]
	_refresh()

func _set_tint(part: String, i: int) -> void:
	look[part].tint = TINTS[i]
	_refresh()

func randomize_look() -> void:
	for part in CharacterModel.DESIGN_PARTS:
		look[part] = {"src": sources[randi() % sources.size()],
			"tint": TINTS[randi() % TINTS.size()] if randf() < 0.55 else null,
			"finish": FINISHES[randi() % FINISHES.size()] if randf() < 0.25 else ""}
	_refresh(true)

func _reset_look() -> void:
	for part in CharacterModel.DESIGN_PARTS:
		look[part] = {"src": "own", "tint": null, "finish": ""}
	_refresh()

func wear() -> void:
	Game.set_custom_look(look, true)
	Game.say("Looking sharp! Your own design is on.", Color(1.0, 0.8, 1.0))
	close(true)

func take_off() -> void:
	Game.custom_look_on = false
	Game.inventory_changed.emit()
	_status.text = "Back to your normal look."

func close(wore: bool) -> void:
	closed.emit(wore)

func _refresh(cheer := false) -> void:
	for part in CharacterModel.DESIGN_PARTS:
		var d: Dictionary = look[part]
		(_src_labels[part] as Label).text = source_name(String(d.src))
		(_fin_labels[part] as Label).text = FINISH_NAMES.get(String(d.get("finish", "")), "Plain")
		var btns: Array = _swatch_btns[part]
		for i in btns.size():
			var t = TINTS[i]
			var on: bool = (t == null and d.tint == null) or (t is Color and d.tint is Color and (t as Color).is_equal_approx(d.tint))
			(btns[i] as Button).set_pressed_no_signal(on)
	_update_preview(cheer)

func preview_cfg() -> Dictionary:
	var p := Game.profile
	var armor := Game.item(Game.equipped.armor)
	var skin := Game.item(Game.equipped.skin)
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": p.show_hat, "weapon": Game.equipped.weapon,
		"shield": armor.get("shield", "shield_round"), "scale": 1.0}
	Player._apply_profile_looks(cfg)
	if int(p.get("cape", 0)) > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
		cfg["outfit_color"] = Game.CAPE_COLORS[p.cape]
	if armor.has("outfit"):
		cfg["outfit_model"] = armor.outfit
	if skin.has("outfit"):
		cfg["outfit_model"] = skin.outfit
		if skin.has("fx"):
			cfg["outfit_fx"] = skin.fx
	cfg["custom_look"] = look
	return cfg

func _update_preview(cheer := false) -> void:
	if _preview == null or not is_inside_tree():
		return
	var ry := _preview.rotation.y
	_cam.current = true
	_cam.position = Vector3(0, 1.4, 7.4); _cam.look_at(Vector3(0, 1.0, 0))
	_preview.setup(preview_cfg())
	_preview.rotation.y = ry
	if cheer:
		_preview.play_role("cheer")

func _process(delta: float) -> void:
	if not visible or _preview == null:
		return
	_spin_hold -= delta
	if _spin_hold <= 0.0:
		_preview.rotation.y += delta * 0.5
