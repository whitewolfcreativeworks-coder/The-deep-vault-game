extends PanelContainer
class_name KitchenPanel
## The stove in your cabin (Cooking): pick a recipe, press COOK, and watch: your
## vegetables plop into the pot one by one, the soup changes colour and bubbles,
## the spoon stirs, a puff of steam and sparkles, and the dish pops out onto the
## counter. It goes in your lunchbox, to eat whenever you like (the Bag).

signal closed

var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _soup: MeshInstance3D
var _soup_mat: StandardMaterial3D
var _bubbles: CPUParticles3D
var _steam: CPUParticles3D
var _spoon: Node3D
var _dish_spot: Node3D
var _dish: Node3D
var _cards := {}
var _sel := ""
var _cook_btn: Button
var _status: Label
var _basket: Label
var _lunch: Label
var _note: Label
var busy := false
var cooked := 0                    # (for the tests)
const POT := Vector3(-0.35, 1.0, 0.0)      # the soup's surface, in the little kitchen

func _ready() -> void:
	custom_minimum_size = Vector2(1560, 860)
	anchor_left = 0.5; anchor_right = 0.5; anchor_top = 0.5; anchor_bottom = 0.5
	offset_left = -780; offset_right = 780; offset_top = -430; offset_bottom = 430
	grow_horizontal = Control.GROW_DIRECTION_BOTH; grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# the pot only bubbles while you're looking at it
	visibility_changed.connect(func() -> void:
		_bubbles.emitting = visible
		_steam.emitting = visible)
	_bubbles.emitting = false; _steam.emitting = false

# --- the little kitchen in the picture ---------------------------------------------
func _m(c: Color, r := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = r; m.metallic = metal
	return m

func _mesh(mesh: Mesh, m: Material, pos: Vector3, parent: Node3D = null, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m
	mi.position = pos; mi.rotation = rot; mi.scale = scl
	(parent if parent else _world).add_child(mi)
	return mi

func _boxm(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z)
	return b

func _cylm(rt: float, rb: float, h: float, segs := 20) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = segs
	return c

func _sphm(r: float, hemi := false) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * (1.0 if hemi else 2.0); s.is_hemisphere = hemi
	s.radial_segments = 16; s.rings = 8
	return s

func _build() -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 22); add_child(h)
	var svc := SubViewportContainer.new(); svc.custom_minimum_size = Vector2(620, 820); svc.stretch = true
	h.add_child(svc)
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.size = Vector2i(620, 820); _vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_vp)
	_world = Node3D.new(); _vp.add_child(_world)
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2, 0.12, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.55, 0.42)
	e.ambient_light_energy = 0.5 if compat else 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC if compat else Environment.TONE_MAPPER_AGX
	if compat:
		e.tonemap_exposure = 0.8
	we.environment = e; _world.add_child(we)
	var key := OmniLight3D.new(); key.light_color = Color(1.0, 0.85, 0.65); key.light_energy = 2.4 * (0.6 if compat else 1.0)
	key.omni_range = 6.0; key.position = Vector3(0.6, 2.4, 1.6); _world.add_child(key)
	var fire := OmniLight3D.new(); fire.light_color = Color(1.0, 0.5, 0.2); fire.light_energy = 1.0; fire.omni_range = 2.0
	fire.position = POT + Vector3(0, -0.6, 0.75); _world.add_child(fire)
	fire.set_script(load("res://scripts/world/flicker.gd"))
	var wood := _m(Color(0.5, 0.33, 0.2), 0.85)
	var dark_wood := _m(Color(0.32, 0.2, 0.12), 0.9)
	var iron := _m(Color(0.16, 0.15, 0.15), 0.5, 0.4)
	# the back wall, a shelf of jars and bunches of herbs
	_mesh(_boxm(3.6, 2.8, 0.1), _m(Color(0.62, 0.45, 0.3), 0.95), Vector3(0, 1.4, -0.75))
	_mesh(_boxm(1.9, 0.05, 0.25), dark_wood, Vector3(0.06, 1.97, -0.6))
	var jar_cols := [Color(1.0, 0.55, 0.15), Color(0.5, 0.75, 0.3), Color(0.9, 0.2, 0.2), Color(1.0, 0.85, 0.3), Color(0.6, 0.4, 0.8)]
	for k in 5:
		var jx := -0.66 + k * 0.33
		_mesh(_cylm(0.09, 0.09, 0.24), _m(jar_cols[k], 0.3), Vector3(jx, 2.12, -0.6))
		_mesh(_cylm(0.07, 0.07, 0.05), _m(Color(0.95, 0.92, 0.85)), Vector3(jx, 2.26, -0.6))
	for k in 3:
		var hx := 0.4 + k * 0.24                 # bunches of herbs hanging under the shelf
		_mesh(_cylm(0.006, 0.006, 0.16), dark_wood, Vector3(hx, 1.87, -0.55))
		_mesh(_sphm(0.075), _m(Color(0.35, 0.6, 0.28)), Vector3(hx, 1.73, -0.55), null, Vector3.ZERO, Vector3(1.0, 1.5, 1.0))
	# the stove, its fire glowing through the little window
	_mesh(_boxm(1.0, 0.9, 0.8), iron, POT + Vector3(0, -0.55, 0.0))
	var glow := _m(Color(0.9, 0.3, 0.06)); glow.emission_enabled = true; glow.emission = Color(1.0, 0.38, 0.08); glow.emission_energy_multiplier = 1.1
	_mesh(_boxm(0.42, 0.24, 0.02), glow, POT + Vector3(0, -0.72, 0.405))
	for k in 4:
		_mesh(_boxm(0.025, 0.26, 0.03), iron, POT + Vector3(-0.15 + k * 0.1, -0.72, 0.415))
	_mesh(_boxm(0.5, 0.04, 0.05), iron, POT + Vector3(0, -0.58, 0.42))
	_mesh(_boxm(1.04, 0.05, 0.84), _m(Color(0.25, 0.24, 0.24), 0.4, 0.5), POT + Vector3(0, -0.08, 0.0))
	# the pot: a fat copper pot with handles, and the soup in it
	var copper := _m(Color(0.75, 0.42, 0.25), 0.35, 0.7)
	_mesh(_cylm(0.36, 0.3, 0.42, 24), copper, POT + Vector3(0, -0.06, 0))
	var rim := _mesh(TorusMesh.new(), copper, POT + Vector3(0, 0.15, 0), null, Vector3.ZERO, Vector3(0.38, 0.4, 0.38))
	(rim.mesh as TorusMesh).inner_radius = 0.9; (rim.mesh as TorusMesh).outer_radius = 1.0
	for sx in [-1.0, 1.0]:
		var hd := _mesh(TorusMesh.new(), iron, POT + Vector3(sx * 0.41, 0.06, 0), null, Vector3(0, 0, PI * 0.5), Vector3(0.08, 0.08, 0.08))
		(hd.mesh as TorusMesh).inner_radius = 0.6
	_soup_mat = _m(Color(0.55, 0.45, 0.35), 0.25)
	_soup_mat.emission_enabled = true; _soup_mat.emission_energy_multiplier = 0.25
	_soup = _mesh(_cylm(0.33, 0.33, 0.02, 24), _soup_mat, POT + Vector3(0, 0.1, 0))
	_bubbles = CPUParticles3D.new(); _bubbles.amount = 14; _bubbles.lifetime = 0.8
	_bubbles.mesh = _sphm(0.025); var bm := _m(Color(1, 1, 1, 0.8), 0.1); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubbles.material_override = bm
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _bubbles.emission_sphere_radius = 0.22
	_bubbles.direction = Vector3.UP; _bubbles.spread = 10; _bubbles.initial_velocity_min = 0.05; _bubbles.initial_velocity_max = 0.15
	_bubbles.gravity = Vector3.ZERO; _bubbles.scale_amount_min = 0.5; _bubbles.scale_amount_max = 1.2
	_bubbles.position = POT + Vector3(0, 0.1, 0); _world.add_child(_bubbles)
	_steam = CPUParticles3D.new(); _steam.amount = 18; _steam.lifetime = 1.8
	_steam.mesh = FX.quad(0.18)
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; sm.albedo_texture = FX.soft_texture(); sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.6, 0.6, 0.62, 0.6); sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD   # steam only lightens
	sm.disable_receive_shadows = true
	_steam.material_override = sm
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 1.8)); _steam.scale_amount_curve = sc
	_steam.direction = Vector3.UP; _steam.spread = 12; _steam.initial_velocity_min = 0.25; _steam.initial_velocity_max = 0.45
	_steam.gravity = Vector3(0.03, 0.12, 0); _steam.scale_amount_min = 0.6; _steam.scale_amount_max = 1.6
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _steam.emission_sphere_radius = 0.15
	var g := Gradient.new(); g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	_steam.color_ramp = g
	_steam.position = POT + Vector3(0, 0.2, 0); _world.add_child(_steam)
	# a wooden spoon leaning in the pot (it stirs while you cook)
	_spoon = Node3D.new(); _world.add_child(_spoon); _spoon.position = POT + Vector3(0, 0.1, 0)
	_mesh(_cylm(0.018, 0.022, 0.7), wood, Vector3(0.16, 0.28, 0), _spoon, Vector3(0, 0, 0.35))
	_mesh(_sphm(0.05), wood, Vector3(0.05, -0.04, 0), _spoon, Vector3.ZERO, Vector3(1.0, 0.45, 1.3))
	# the counter, where the finished dish goes, with a checked cloth
	_mesh(_boxm(0.8, 0.9, 0.8), wood, Vector3(0.58, 0.45 - 0.08, 0.0))
	_mesh(_boxm(0.84, 0.06, 0.84), dark_wood, Vector3(0.58, 0.85, 0.0))
	var cloth := _m(Color(0.9, 0.3, 0.3), 0.9)
	_mesh(_boxm(0.56, 0.01, 0.5), cloth, Vector3(0.58, 0.885, 0.05))
	var cream := _m(Color(0.98, 0.95, 0.9), 0.9)
	for k in 3:
		_mesh(_boxm(0.56, 0.012, 0.06), cream, Vector3(0.58, 0.887, -0.12 + k * 0.17))
	_dish_spot = Node3D.new(); _world.add_child(_dish_spot); _dish_spot.position = Vector3(0.58, 0.9, 0.05)
	# a little sign on the wall
	var lb := Label3D.new(); lb.text = "KITCHEN"; lb.font_size = 72; lb.pixel_size = 0.004; lb.outline_size = 12
	lb.modulate = Color(1.0, 0.85, 0.5); lb.outline_modulate = Color(0.25, 0.12, 0.05); lb.position = Vector3(0.06, 2.44, -0.68)
	_world.add_child(lb)
	_cam = Camera3D.new(); _cam.fov = 44.0; _world.add_child(_cam)
	_cam.position = Vector3(0.06, 2.15, 3.6); _cam.look_at(Vector3(0.06, 1.15, 0.0))
	# the floor
	_mesh(_boxm(3.6, 0.05, 1.8), _m(Color(0.42, 0.28, 0.17), 0.9), Vector3(0, -0.07, 0.1))
	# --- the recipes
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var head := HBoxContainer.new(); col.add_child(head)
	head.add_child(UIKit.label("Kitchen", 34, UIKit.GOLD, true))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var done := Button.new(); done.text = "✔  Done"; done.custom_minimum_size = Vector2(170, 54)
	done.add_theme_font_size_override("font_size", 22)
	done.pressed.connect(func() -> void:
		if not busy:
			Sfx.play("footstep", -8.0, 0.0)
			closed.emit())
	head.add_child(done)
	_note = UIKit.label("", 16, UIKit.DIM)
	var note := _note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD; note.custom_minimum_size.x = 860
	col.add_child(note)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for id in Cooking.ORDER:
		var b := Button.new(); b.toggle_mode = true; b.custom_minimum_size = Vector2(440, 74)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.clip_text = true
		b.add_theme_font_size_override("font_size", 16)
		var on := StyleBoxFlat.new(); on.bg_color = Color(0.42, 0.3, 0.14); on.border_color = Color(1.0, 0.85, 0.4)
		on.set_border_width_all(3); on.set_corner_radius_all(8)
		b.add_theme_stylebox_override("pressed", on); b.add_theme_stylebox_override("hover_pressed", on)
		b.pressed.connect(func() -> void:
			if busy:
				return
			Sfx.play("footstep", -8.0, 0.0)
			select(id))
		grid.add_child(b)
		_cards[id] = b
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 16); col.add_child(row)
	_cook_btn = Button.new(); _cook_btn.custom_minimum_size = Vector2(300, 70); _cook_btn.add_theme_font_size_override("font_size", 26)
	_cook_btn.pressed.connect(func() -> void: cook())
	row.add_child(_cook_btn)
	_status = UIKit.label("", 18, Color(1.0, 0.9, 0.6), true); _status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size.x = 540; _status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	_basket = UIKit.label("", 16, UIKit.PARCH); _basket.autowrap_mode = TextServer.AUTOWRAP_WORD; _basket.custom_minimum_size.x = 860
	col.add_child(_basket)
	_lunch = UIKit.label("", 16, Color(0.8, 1.0, 0.7)); _lunch.autowrap_mode = TextServer.AUTOWRAP_WORD; _lunch.custom_minimum_size.x = 860
	col.add_child(_lunch)

# --- state -----------------------------------------------------------------------
func open() -> void:
	busy = false
	_status.text = ""
	_cam.current = true
	var pick := ""
	for id in Cooking.ORDER:
		if pick == "" and Cooking.can_cook(id):
			pick = id
	select(pick if pick != "" else (_sel if _sel != "" else String(Cooking.ORDER[0])))
	if pick == "":
		_status.text = "Pick vegetables and flowers in your garden, then come and cook them here!"

const NOTE := "Cook what you grow in your garden. Dishes go in your lunchbox: eat them any time from your Bag, even out on an adventure!"

func select(id: String) -> void:
	_sel = id
	_refresh()
	_soup_mat.albedo_color = Color(0.55, 0.45, 0.35).lerp(Cooking.RECIPES[id].color, 0.35)
	_soup_mat.emission = _soup_mat.albedo_color
	_show_dish(id, false)

func _refresh() -> void:
	for id in _cards:
		var r: Dictionary = Cooking.RECIPES[id]
		var parts: Array = []
		var miss := Cooking.missing(id)
		for ing in r.needs:
			parts.append("%s%s" % [Cooking.ing_text(String(ing), int(r.needs[ing])), " ✓" if not miss.has(ing) else ""])
		var b: Button = _cards[id]
		b.text = "  %s%s\n  %s" % [String(r.name), ("  ×%d" % Cooking.makes(id)) if Cooking.makes(id) > 1 else "", ", ".join(parts)]
		b.set_pressed_no_signal(id == _sel)
		b.add_theme_color_override("font_color", (r.color as Color).lightened(0.3) if miss.is_empty() else UIKit.DIM)
	_note.text = NOTE + ("  Chef's Whites: one extra helping of everything!" if Outfits.perk("chefs_touch") else "")
	var r2: Dictionary = Cooking.RECIPES[_sel]
	var m2 := Cooking.missing(_sel)
	_cook_btn.disabled = not m2.is_empty() or busy
	_cook_btn.text = "COOK IT!" if m2.is_empty() else "Need more"
	if not busy:
		if m2.is_empty():
			_status.text = String(r2.line)
		else:
			var need: Array = []
			for ing in m2:
				need.append(Cooking.ing_text(String(ing), int(m2[ing]), "more "))
			_status.text = "%s  (You need %s.)" % [String(r2.line), " and ".join(need)]
	var bk: Array = []
	for ing in Game.basket:
		bk.append("%s ×%d" % [GardenPlants.plant_name(String(ing)), int(Game.basket[ing])])
	_basket.text = ("Your basket: " + ", ".join(bk)) if not bk.is_empty() else "Your basket is empty: pick something in your garden!"
	var lb: Array = []
	for d in Game.lunchbox:
		lb.append("%s ×%d" % [Cooking.dish_name(String(d)), int(Game.lunchbox[d])])
	_lunch.text = ("Your lunchbox: " + ", ".join(lb)) if not lb.is_empty() else "Your lunchbox is empty."

## Cook the selected dish: the little show, then into the lunchbox.
func cook() -> void:
	if busy or not Cooking.can_cook(_sel):
		return
	busy = true
	var id := _sel
	var r: Dictionary = Cooking.RECIPES[id]
	_refresh()
	_status.text = "Cooking..."
	_show_dish(id, false)
	# the ingredients plop in, one by one
	var target: Color = r.color
	var start := _soup_mat.albedo_color
	var n := 0
	var total := 0
	for ing in r.needs:
		total += int(r.needs[ing])
	for ing in r.needs:
		for k in int(r.needs[ing]):
			var piece := _ingredient(String(ing))
			piece.position = POT + Vector3(randf_range(-0.12, 0.12), 0.95, randf_range(-0.08, 0.08))
			var tw := create_tween()
			tw.tween_property(piece, "position:y", POT.y + 0.08, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(piece, "rotation", Vector3(randf() * 3.0, randf() * 3.0, 0), 0.38)
			await tw.finished
			_splash(target)
			Sfx.play("pop", -4.0, 0.15)
			n += 1
			_soup_mat.albedo_color = start.lerp(target, float(n) / float(total))
			_soup_mat.emission = _soup_mat.albedo_color
			var sink := create_tween()
			sink.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.25)
			sink.tween_callback(piece.queue_free)
			await get_tree().create_timer(0.12).timeout
	# stir, stir
	Sfx.play("stir", -4.0, 0.1)
	_bubbles.amount = 40
	var st := create_tween()
	st.tween_property(_spoon, "rotation:y", _spoon.rotation.y + TAU * 2.0, 1.2).set_trans(Tween.TRANS_SINE)
	await st.finished
	_bubbles.amount = 14
	# poof! and the dish pops out onto the counter
	_puff(target)
	Cooking.cook(id)
	cooked += 1
	_show_dish(id, true)
	Sfx.play("levelup", -8.0, 0.0)
	_status.text = "%s%s! Into your lunchbox it goes." % [String(r.name), (" ×%d" % Cooking.makes(id)) if Cooking.makes(id) > 1 else ""]
	busy = false
	_refresh()
	_status.text = "%s%s! Into your lunchbox it goes." % [String(r.name), (" ×%d" % Cooking.makes(id)) if Cooking.makes(id) > 1 else ""]

func _ingredient(ing: String) -> Node3D:
	var n := Node3D.new(); _world.add_child(n)
	var c: Color = GardenPlants.PLANTS.get(ing, {}).get("color", Color.WHITE)
	match ing:
		"carrot":
			_mesh(_cylm(0.05, 0.005, 0.22), _m(c, 0.6), Vector3.ZERO, n, Vector3(0, 0, PI))
			_mesh(_cylm(0.0, 0.03, 0.12), _m(Color(0.3, 0.65, 0.25)), Vector3(0, 0.15, 0), n)
		"tomato":
			_mesh(_sphm(0.08), _m(c, 0.3), Vector3.ZERO, n)
			_mesh(_cylm(0.03, 0.03, 0.02), _m(Color(0.3, 0.6, 0.2)), Vector3(0, 0.08, 0), n)
		"pumpkin":
			_mesh(_sphm(0.14), _m(c, 0.5), Vector3.ZERO, n, Vector3.ZERO, Vector3(1.2, 0.85, 1.2))
			_mesh(_cylm(0.02, 0.025, 0.07), _m(Color(0.35, 0.4, 0.15)), Vector3(0, 0.14, 0), n)
		"sunflower":
			_mesh(_cylm(0.1, 0.1, 0.02), _m(Color(1.0, 0.85, 0.15)), Vector3.ZERO, n)
			_mesh(_cylm(0.05, 0.05, 0.025), _m(Color(0.35, 0.2, 0.08)), Vector3(0, 0.005, 0), n)
		_:
			_mesh(_sphm(0.06), _m(c, 0.5), Vector3.ZERO, n)
	return n

func _splash(c: Color) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.amount = 14; p.lifetime = 0.5; p.explosiveness = 1.0
	p.mesh = _sphm(0.02); p.material_override = _m(c, 0.3)
	p.direction = Vector3.UP; p.spread = 50; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.1; p.gravity = Vector3(0, -4.0, 0)
	p.position = POT + Vector3(0, 0.12, 0); _world.add_child(p); p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _puff(c: Color) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.amount = 24; p.lifetime = 0.9; p.explosiveness = 0.9
	p.mesh = FX.quad(0.08); p.material_override = FX.glow_material(Color(1.0, 0.95, 0.6), 2.0)
	p.direction = Vector3.UP; p.spread = 70; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.4; p.gravity = Vector3(0, -0.5, 0)
	p.position = _dish_spot.position + Vector3(0, 0.15, 0); _world.add_child(p); p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	_steam.amount = 30
	get_tree().create_timer(1.0).timeout.connect(func() -> void: _steam.amount = 18)

## The finished dish on the counter (pop = it bounces in).
func _show_dish(id: String, pop: bool) -> void:
	if _dish and is_instance_valid(_dish):
		_dish.queue_free()
	_dish = Node3D.new(); _dish_spot.add_child(_dish)
	if not pop:
		_dish.visible = false
		return
	_dish_look(id, _dish)
	_dish.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(_dish, "scale", Vector3.ONE * 1.5, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if visible and _dish and is_instance_valid(_dish) and _dish.visible:
		_dish.rotation.y += delta * 0.6
	if visible and _soup and not busy:
		_spoon.rotation.y += delta * 0.15

func _dish_look(id: String, n: Node3D) -> void:
	var c: Color = Cooking.RECIPES[id].color
	var white := _m(Color(0.97, 0.95, 0.9), 0.4)
	var bowl := func(col: Color) -> void:
		_mesh(_sphm(0.16, true), white, Vector3(0, 0.16, 0), n, Vector3(PI, 0, 0), Vector3(1.0, 0.8, 1.0))
		_mesh(_cylm(0.15, 0.15, 0.015), _m(col, 0.3), Vector3(0, 0.15, 0), n)
	match id:
		"carrot_soup", "pumpkin_stew":
			bowl.call(c)
			for k in 4:
				var a := k * TAU / 4.0
				_mesh(_sphm(0.02), _m(Color(0.3, 0.65, 0.25)), Vector3(cos(a) * 0.07, 0.16, sin(a) * 0.07), n)
			if id == "pumpkin_stew":
				for k in 3:
					var a2 := k * TAU / 3.0 + 0.5
					_mesh(_boxm(0.04, 0.03, 0.04), _m(Color(1.0, 0.6, 0.2)), Vector3(cos(a2) * 0.05, 0.165, sin(a2) * 0.05), n)
		"tomato_pie":
			_mesh(_cylm(0.2, 0.18, 0.08), _m(Color(0.9, 0.68, 0.35), 0.7), Vector3(0, 0.04, 0), n)
			_mesh(_cylm(0.17, 0.17, 0.012), _m(c, 0.4), Vector3(0, 0.085, 0), n)
			for k in 3:
				_mesh(_boxm(0.34, 0.015, 0.025), _m(Color(0.95, 0.75, 0.42), 0.7), Vector3(0, 0.095, -0.1 + k * 0.1), n)
				_mesh(_boxm(0.025, 0.016, 0.34), _m(Color(0.95, 0.75, 0.42), 0.7), Vector3(-0.1 + k * 0.1, 0.096, 0), n)
		"garden_salad":
			_mesh(_sphm(0.17, true), _m(Color(0.6, 0.4, 0.25), 0.8), Vector3(0, 0.17, 0), n, Vector3(PI, 0, 0), Vector3(1.0, 0.75, 1.0))
			for k in 9:
				var a := k * TAU / 9.0
				_mesh(_sphm(0.045), _m(Color(0.4, 0.75, 0.3)), Vector3(cos(a) * 0.08, 0.17, sin(a) * 0.08), n, Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
			for k in 3:
				_mesh(_sphm(0.025), _m(Color(0.9, 0.2, 0.15), 0.3), Vector3(-0.05 + k * 0.05, 0.19, 0.03), n)
				_mesh(_boxm(0.05, 0.015, 0.015), _m(Color(1.0, 0.55, 0.15)), Vector3(-0.04 + k * 0.04, 0.19, -0.04), n)
		"heros_feast":
			_mesh(_cylm(0.3, 0.28, 0.02), white, Vector3(0, 0.01, 0), n)
			_mesh(_cylm(0.1, 0.09, 0.05), _m(Color(0.9, 0.68, 0.35)), Vector3(-0.12, 0.045, 0.05), n)
			_mesh(_cylm(0.085, 0.085, 0.01), _m(Color(0.9, 0.2, 0.15)), Vector3(-0.12, 0.072, 0.05), n)
			_mesh(_sphm(0.08, true), white, Vector3(0.11, 0.09, 0.06), n, Vector3(PI, 0, 0))
			_mesh(_cylm(0.075, 0.075, 0.01), _m(Color(1.0, 0.55, 0.15)), Vector3(0.11, 0.088, 0.06), n)
			_mesh(_sphm(0.08), _m(Color(1.0, 0.55, 0.12), 0.5), Vector3(0.0, 0.08, -0.13), n, Vector3.ZERO, Vector3(1.2, 0.85, 1.2))
			_mesh(_cylm(0.015, 0.02, 0.05), _m(Color(0.35, 0.4, 0.15)), Vector3(0.0, 0.16, -0.13), n)
		"sunflower_cookies":
			_mesh(_cylm(0.22, 0.2, 0.015), white, Vector3(0, 0.008, 0), n)
			for k in 3:
				var a := k * TAU / 3.0
				var cp := Vector3(cos(a) * 0.09, 0.03 + k * 0.004, sin(a) * 0.09)
				_mesh(_cylm(0.07, 0.07, 0.025), _m(c, 0.8), cp, n)
				for d in 4:
					var a3 := d * TAU / 4.0 + k
					_mesh(_sphm(0.008), _m(Color(0.25, 0.18, 0.1)), cp + Vector3(cos(a3) * 0.035, 0.014, sin(a3) * 0.035), n)
		"rose_tea":
			_mesh(_cylm(0.13, 0.12, 0.012), white, Vector3(0, 0.006, 0), n)
			_mesh(_cylm(0.075, 0.055, 0.11), white, Vector3(0, 0.065, 0), n)
			_mesh(_cylm(0.07, 0.07, 0.01), _m(c, 0.2), Vector3(0, 0.115, 0), n)
			var hd := _mesh(TorusMesh.new(), white, Vector3(0.085, 0.07, 0), n, Vector3(PI * 0.5, 0, 0), Vector3(0.035, 0.035, 0.035))
			(hd.mesh as TorusMesh).inner_radius = 0.6
			_mesh(_sphm(0.02), _m(Color(1.0, 0.45, 0.6)), Vector3(-0.02, 0.122, 0.02), n)
