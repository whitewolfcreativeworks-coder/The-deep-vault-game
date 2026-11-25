extends PanelContainer
class_name WardrobePanel
## The Wardrobe in your cabin (see Outfits.gd): your outfits and your shoes and
## slippers. Tap one and you're wearing it (the preview shows it straight away);
## "Done" when you're happy. Each hero has their own wardrobe.

signal closed(changed: bool)

var _preview: CharacterModel
var _cam: Camera3D
var _vp: SubViewport
var _spin_hold := 0.0
var _title: Label
var _line: Label
var _outfit_box: VBoxContainer
var _foot_box: GridContainer
var _outfit_btns := {}
var _foot_btns := {}
var _start := []                 # [outfit, footwear, costume] when the wardrobe was opened
var _magic_btn: Button           # a magic costume you're wearing, or one put away here

func _ready() -> void:
	custom_minimum_size = Vector2(1560, 860)
	anchor_left = 0.5; anchor_right = 0.5; anchor_top = 0.5; anchor_bottom = 0.5
	offset_left = -780; offset_right = 780; offset_top = -430; offset_bottom = 430
	grow_horizontal = Control.GROW_DIRECTION_BOTH; grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 22); add_child(h)
	# your hero, turning slowly (drag to spin)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(440, 820)
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
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.size = Vector2i(440, 820); _vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_vp)
	var w := Node3D.new(); _vp.add_child(w)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.12, 0.08, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.47, 0.42); e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if compat:
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 0.75; e.ambient_light_energy = 0.45
	we.environment = e; w.add_child(we)
	var key := SpotLight3D.new(); key.light_color = Color(1.0, 0.9, 0.78); key.light_energy = 13.0 * (0.45 if compat else 1.0)
	key.spot_range = 12.0; key.spot_angle = 34.0; key.shadow_enabled = true
	key.position = Vector3(1.6, 3.4, 3.4); key.look_at_from_position(key.position, Vector3(0, 1.1, 0)); w.add_child(key)
	var fill := OmniLight3D.new(); fill.light_energy = 1.4 * (0.45 if compat else 1.0); fill.omni_range = 7.0; fill.position = Vector3(-1.8, 1.8, 2.6); w.add_child(fill)
	# a rug to stand on, and the open wardrobe behind you
	var rug := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 1.0; rm.bottom_radius = 1.0; rm.height = 0.04
	rug.mesh = rm; var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color(0.55, 0.18, 0.15); rmat.roughness = 1.0
	rug.material_override = rmat; rug.position.y = -0.02; w.add_child(rug)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.42, 0.27, 0.15); wood.roughness = 0.8
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.16, 0.1, 0.06); dark.roughness = 0.9
	_box(w, Vector3(0, 1.4, -1.6), Vector3(2.4, 2.8, 0.5), wood)
	_box(w, Vector3(0, 1.4, -1.33), Vector3(2.1, 2.5, 0.05), dark)
	for sx in [-1.0, 1.0]:
		var door := _box(w, Vector3(sx * 1.55, 1.4, -1.0), Vector3(0.05, 2.5, 1.0), wood)
		door.rotation.y = sx * 0.15
	_box(w, Vector3(0, 2.4, -1.4), Vector3(2.0, 0.04, 0.04), _metal())
	var hang := [Color(0.45, 0.6, 0.95), Color(0.95, 0.55, 0.1), Color(0.26, 0.42, 0.72), Color(0.82, 0.15, 0.12), Color(0.35, 0.72, 0.25)]
	for k in hang.size():
		var cm := StandardMaterial3D.new(); cm.albedo_color = hang[k]; cm.roughness = 0.9
		_box(w, Vector3(-0.8 + k * 0.4, 1.85, -1.42), Vector3(0.32, 1.0, 0.14), cm)
	_cam = Camera3D.new(); _cam.fov = 30; w.add_child(_cam)
	_preview = CharacterModel.new(); _preview.rotation.y = PI; w.add_child(_preview)
	# the choices
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var head := HBoxContainer.new(); col.add_child(head)
	_title = UIKit.label("Wardrobe", 34, UIKit.GOLD, true); head.add_child(_title)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var done := _btn("✔  Done", func() -> void: close(), 190)
	done.add_theme_font_size_override("font_size", 22)
	head.add_child(done)
	_line = UIKit.label("", 17, UIKit.PARCH); _line.autowrap_mode = TextServer.AUTOWRAP_WORD; _line.custom_minimum_size = Vector2(980, 48)
	col.add_child(_line)
	col.add_child(UIKit.label("OUTFITS", 22, UIKit.GOLD, true))
	_outfit_box = VBoxContainer.new(); _outfit_box.add_theme_constant_override("separation", 4); col.add_child(_outfit_box)
	col.add_child(UIKit.label("SHOES & SLIPPERS", 22, UIKit.GOLD, true))
	_foot_box = GridContainer.new(); _foot_box.columns = 5
	_foot_box.add_theme_constant_override("h_separation", 6); _foot_box.add_theme_constant_override("v_separation", 6)
	col.add_child(_foot_box)

func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = m; mi.position = at; parent.add_child(mi)
	return mi

func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.7, 0.62, 0.45); m.metallic = 0.8; m.roughness = 0.35
	return m

func _btn(text: String, cb: Callable, wdt := 200.0) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(wdt, 54)
	b.pressed.connect(func() -> void:
		Sfx.play("footstep", -8.0, 0.0)
		cb.call())
	return b

## A choice: a swatch of its colours, its name, lit gold when you're wearing it.
func _choice(text: String, c: Color, c2: Color, cb: Callable, wdt: float, is_new: bool) -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(wdt, 52); b.toggle_mode = true
	b.text = ("  " + text + ("  NEW!" if is_new else "")); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 16)
	b.clip_text = true
	var sw := ColorRect.new(); sw.color = c; sw.custom_minimum_size = Vector2(16, 40)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.position = Vector2(6, 6); sw.size = Vector2(16, 40)
	b.add_child(sw)
	var sw2 := ColorRect.new(); sw2.color = c2; sw2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw2.position = Vector2(10, 18); sw2.size = Vector2(8, 16)
	b.add_child(sw2)
	b.text = "     " + b.text.strip_edges()
	var on := StyleBoxFlat.new(); on.bg_color = Color(0.42, 0.32, 0.14); on.border_color = Color(1.0, 0.85, 0.4)
	on.set_border_width_all(3); on.set_corner_radius_all(6)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.pressed.connect(func() -> void:
		Sfx.play("pickup", -10.0, 0.0)
		cb.call())
	return b

# --- state ---------------------------------------------------------------------------
func open() -> void:
	Game.mend_wardrobe()
	_start = [Game.outfit, Game.footwear, Game.costume_id()]
	_title.text = "%s's Wardrobe" % String(Game.profile.get("name", "Your"))
	_fill()
	_refresh()

func _fill() -> void:
	for c in _outfit_box.get_children():
		c.queue_free()
	for c in _foot_box.get_children():
		c.queue_free()
	_outfit_btns.clear(); _foot_btns.clear()
	_magic_btn = null
	var magic := Game.costume_id() if Game.costume_id() != "" else Game.costume_away_id()
	if magic != "":
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); _outfit_box.add_child(row)
		var gl := UIKit.label("Magic", 14, Color(1.0, 0.7, 1.0), true); gl.custom_minimum_size.x = 132
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(gl)
		_magic_btn = _choice("", Color(0.75, 0.4, 0.95), Color(1.0, 0.85, 1.0), func() -> void: _pick_magic(), 580, false)
		row.add_child(_magic_btn)
	for g in Outfits.GROUPS:
		var ids: Array = []
		for id in Game.outfits_owned:
			if Outfits.OUTFITS.has(id) and String(Outfits.OUTFITS[id].group) == g:
				ids.append(id)
		if ids.is_empty():
			continue
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); _outfit_box.add_child(row)
		var gl := UIKit.label(Outfits.GROUP_NAMES[g], 14, UIKit.DIM, true); gl.custom_minimum_size.x = 132
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(gl)
		var grid := GridContainer.new(); grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
		row.add_child(grid)
		for id in ids:
			var o: Dictionary = Outfits.OUTFITS[id]
			var c1: Color = o.get("color", Color(0.55, 0.42, 0.3))
			var c2: Color = o.get("pattern_color", o.get("hat_color", c1.lightened(0.3)))
			var b := _choice(String(o.name), c1, c2, func() -> void: _pick_outfit(id), 284, Game.wardrobe_new.has(id))
			grid.add_child(b)
			_outfit_btns[id] = b
	for id in Game.footwear_owned:
		if not Outfits.FOOTWEAR.has(id):
			continue
		var f: Dictionary = Outfits.FOOTWEAR[id]
		var b := _choice(String(f.name), f.color, (f.color as Color).lightened(0.4), func() -> void: _pick_footwear(id), 196, Game.wardrobe_new.has(id))
		_foot_box.add_child(b)
		_foot_btns[id] = b

func _pick_outfit(id: String) -> void:
	_put_magic_away()
	Game.wear_outfit(id)
	_refresh(true)

func _pick_footwear(id: String) -> void:
	_put_magic_away()
	Game.wear_footwear(id)
	_refresh(true)

## Picking clothes takes a magic costume off (it stays here, its time paused), so what
## you pick is what you wear. Picking the costume puts it back on.
func _put_magic_away() -> void:
	if Game.costume_id() != "":
		Game.put_away_costume()

func _pick_magic() -> void:
	if Game.costume_id() == "":
		Game.wear_costume_again()
	_refresh(true)

func _refresh(cheer := false) -> void:
	var magic_on := Game.costume_id() != ""
	for id in _outfit_btns:
		(_outfit_btns[id] as Button).set_pressed_no_signal(id == Game.outfit and not magic_on)
	for id in _foot_btns:
		(_foot_btns[id] as Button).set_pressed_no_signal(id == Game.footwear and not magic_on)
	var o: Dictionary = Outfits.OUTFITS.get(Game.outfit, {})
	var f: Dictionary = Outfits.FOOTWEAR.get(Game.footwear, {})
	_line.text = "%s: %s   %s: %s" % [String(o.get("name", "")), String(o.get("line", "")), String(f.get("name", "")), String(f.get("line", ""))]
	if _magic_btn:
		var id := Game.costume_id() if magic_on else Game.costume_away_id()
		var nm := String(Loot.COSTUMES.get(id, {}).get("name", "Magic"))
		if magic_on:
			_magic_btn.text = "     ★ %s costume  (on: %s left)" % [nm, Game.costume_time_text()]
			_line.text = "You're wearing your magic %s costume. Pick any clothes and it goes on this hook, ready for later." % nm
		else:
			var s := maxf(Game.costume_away_left(), 0.0)
			var left := ("%dh %dm" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0)]) if s >= 3600.0 else ("%d:%02d" % [int(s / 60.0), int(fmod(s, 60.0))])
			_magic_btn.text = "     ★ %s costume  (put away: %s left)" % [nm, left]
		_magic_btn.set_pressed_no_signal(magic_on)
	_update_preview(cheer)

func preview_cfg() -> Dictionary:
	var p := Game.profile
	var armor := Game.item(Game.equipped.armor)
	var skin := Game.item(Game.equipped.skin)
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": p.show_hat, "weapon": Game.equipped.weapon,
		"shield": armor.get("shield", "shield_round"), "scale": 1.0, "skin": skin.get("skin", "")}
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
	if Game.costume_id() != "":
		cfg["costume"] = Game.costume_id()       # (what you'll really look like)
		return cfg
	if Game.outfit == "adventure" and Game.custom_look_on and not Game.custom_look.is_empty():
		cfg["custom_look"] = Game.custom_look
	Outfits.dress(cfg, Game.outfit, Game.footwear)
	return cfg

func _update_preview(cheer := false) -> void:
	if _preview == null or not is_inside_tree():
		return
	var ry := _preview.rotation.y
	_cam.current = true
	_cam.position = Vector3(0, 1.35, 7.0); _cam.look_at(Vector3(0, 0.95, 0))
	_preview.setup(preview_cfg())
	_preview.rotation.y = ry
	if cheer:
		_preview.play_role("cheer")

func close() -> void:
	closed.emit(_start != [Game.outfit, Game.footwear, Game.costume_id()])

func _process(delta: float) -> void:
	if not visible or _preview == null:
		return
	_spin_hold -= delta
	if _spin_hold <= 0.0:
		_preview.rotation.y += delta * 0.5
