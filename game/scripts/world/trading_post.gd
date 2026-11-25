extends HomeBuilding
class_name TradingPost
## TOBBLE'S TRADING POST, across the yard from the cabin. Tobble (the merchant you
## helped in the Goblin Forest, whose strongbox was stolen) has set up shop near
## your home. Inside, everything is on display: walk up to it and press E.
##   the elixir shelf          elixirs (Triple Jump, Swift Feet, Giant Strength...)
##   the enchanting table      weapon enchantments (Flame, Frost, Lightning Edge)
##   the blessing altar        armor blessings (Stoneskin, Thorns, Fireproof)
##   the costume mannequins    costumes you can only get here
##   the yard catalog          things for your yard at home
##   the special pedestal      Today's Special (half price!)
##   Tobble at the counter     sell your gear
## Like the cabin, the room is built out of sight under the valley (and only drawn
## while you're in it).

const AT := Vector3(-9, 0, 24)              # the building in the yard (further out from Nov 25: more room)
const YAW := 158.0                          # its door faces the cabin
const SCALE := 6.0
const IN := Vector3(30, -30, 30)            # the room
const W := 12.0                             # room width (x) and depth (z)
const D := 10.0
const H := 4.2

var room: Node3D
var tobble: ShopNPC
var _inside := false
var _special: Node3D

static func build_in(h: HomeWorld) -> TradingPost:
	var t := TradingPost.new()
	t.name = "TradingPost"
	t.home = h
	h.add_child(t)
	t._exterior()
	t._interior()
	return t

func _fwd() -> Vector3:
	return Vector3(sin(deg_to_rad(YAW)), 0, cos(deg_to_rad(YAW)))

## Outside, in front of the door.
func door_out() -> Vector3:
	var f := _fwd()
	var d := Vector3(AT.x, 0, AT.z) + f * 5.4 - f.cross(Vector3.UP) * 0.9      # (the door is a little off-centre)
	return home.ground(d.x, d.z)

func is_inside(p: Vector3) -> bool:
	return absf(p.y - IN.y - 2.0) < 6.0 and absf(p.x - IN.x) < W * 0.5 + 1.0 and absf(p.z - IN.z) < D * 0.5 + 1.0

func arrival() -> Vector3:
	return IN + Vector3(0, 0.05, D * 0.5 - 1.3)

# --- outside -------------------------------------------------------------------------
func _exterior() -> void:
	var g := home.ground(AT.x, AT.z)
	var hs: Node3D = home._scen._model("building_home_B_red", g - Vector3(0, 0.35, 0), YAW, SCALE)
	hs.name = "ShopHouse"
	# solid walls (a box the size of the house)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.84, 1.0, 1.02) * SCALE * Vector3(1, 1.2, 1)
	cs.shape = bs
	_solid().add_child(cs)
	cs.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(YAW)), g + Vector3(0, bs.size.y * 0.5, 0))
	# the sign over the door, crates and a barrel of apples, a lantern
	var f := _fwd()
	var side := f.cross(Vector3.UP)
	var front := g + f * (0.58 * SCALE)
	var sg := label_sign(self, Vector3.ZERO, "TOBBLE'S\nTRADING POST", Color(1.0, 0.85, 0.4), 3.4, 1.0)
	sg.global_position = front + Vector3(0, 4.3, 0) + f * 0.3
	sg.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sg.rotation.y = deg_to_rad(YAW)
	var gold := label_sign(self, Vector3.ZERO, "Elixirs · Enchantments · Costumes · We buy gear!", Color(1.0, 0.95, 0.8), 4.2, 0.28)
	gold.global_position = front + Vector3(0, 3.6, 0) + f * 0.3
	gold.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	gold.rotation.y = deg_to_rad(YAW)
	for k in 3:
		var c: Node3D = home._scen._model("crate_A_big" if k < 2 else "barrel", Vector3.ZERO, YAW + k * 25.0, 1.0)
		var at := front + f * 1.0 + side * (2.2 + k * 0.9)
		c.global_position = home.ground(at.x, at.z)
		var a := Props.mesh_aabb(c)
		if a.size.y > 0.0:
			c.scale = Vector3.ONE * clampf(0.75 / a.size.y, 0.2, 3.0)
	var lamp: Node3D = home._scen._model("lantern_standing", Vector3.ZERO, YAW, 1.0)
	var la := front + f * 1.2 - side * 2.0
	lamp.global_position = home.ground(la.x, la.z)
	Usable.make(self, door_out() - f * 1.6 + Vector3(0, 1.0, 0), "[E] Go into Tobble's Trading Post", go_in)

# --- inside --------------------------------------------------------------------------
func _interior() -> void:
	room = Node3D.new(); room.name = "ShopRoom"
	add_child(room)
	room.position = IN
	var floor_m := mat(Color(0.52, 0.34, 0.2), 0.75)
	var wall_m := mat(Color(0.72, 0.56, 0.38), 0.85)
	var dark := mat(Color(0.32, 0.2, 0.11), 0.8)
	var hw := W * 0.5; var hd := D * 0.5
	box(room, Vector3(-hw, -0.3, -hd), Vector3(hw, 0, hd), floor_m)
	for k in 9:          # floorboards
		var x := -hw + 0.67 + k * 1.33
		box(room, Vector3(x - 0.02, 0, -hd), Vector3(x + 0.02, 0.005, hd), dark, false)
	box(room, Vector3(-hw, H, -hd), Vector3(hw, H + 0.3, hd), wall_m)                    # ceiling
	box(room, Vector3(-hw - 0.3, 0, -hd), Vector3(-hw, H, hd), wall_m)                   # left
	box(room, Vector3(hw, 0, -hd), Vector3(hw + 0.3, H, hd), wall_m)                     # right
	box(room, Vector3(-hw, 0, -hd - 0.3), Vector3(hw, H, -hd), wall_m)                   # back
	box(room, Vector3(-hw, 0, hd), Vector3(-0.7, H, hd + 0.3), wall_m)                   # front, with the door
	box(room, Vector3(0.7, 0, hd), Vector3(hw, H, hd + 0.3), wall_m)
	box(room, Vector3(-0.7, 2.4, hd), Vector3(0.7, H, hd + 0.3), wall_m)
	box(room, Vector3(-0.6, 0, hd - 0.05), Vector3(0.6, 2.35, hd), mat(Color(0.45, 0.28, 0.15), 0.75), false)   # the door
	for z in [-3.0, 0.0, 3.0]:                                                             # beams
		box(room, Vector3(-hw, H - 0.3, z - 0.15), Vector3(hw, H, z + 0.15), dark, false)
	for x in [-hw + 0.1, hw - 0.1]:                                                       # corner posts
		for z in [-hd + 0.1, hd - 0.1]:
			box(room, Vector3(x - 0.12, 0, z - 0.12), Vector3(x + 0.12, H, z + 0.12), dark, false)
	# windows: warm daylight
	var win := glow(Color(1.0, 0.85, 0.6), 0.45)
	for z in [-2.0, 2.0]:
		box(room, Vector3(-hw + 0.01, 1.4, z - 0.6), Vector3(-hw + 0.03, 2.6, z + 0.6), win, false)
		box(room, Vector3(hw - 0.03, 1.4, z - 0.6), Vector3(hw - 0.01, 2.6, z + 0.6), win, false)
	box(room, Vector3(-1.8, 0.0, 1.0), Vector3(1.8, 0.01, 3.4), mat(Color(0.55, 0.16, 0.18), 0.9), false)    # rug
	for x in [-2.6, 2.6]:
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.8, 0.55); l.light_energy = 1.4; l.omni_range = 9.0
		room.add_child(l); l.position = Vector3(x, H - 0.7, 0.5)
		sphere(room, Vector3(x, H - 0.6, 0.5), 0.16, glow(Color(1.0, 0.8, 0.45), 3.0))
		box(room, Vector3(x - 0.01, H - 0.45, 0.49), Vector3(x + 0.01, H, 0.51), dark, false)
	_counter()
	_elixir_shelf()
	_enchant_table()
	_blessing_altar()
	_costume_rack()
	_yard_catalog()
	_special_pedestal()
	Usable.make(self, IN + Vector3(0, 0.8, hd - 0.6), "[E] Go back out to the yard", go_out)
	room.visible = false

func _counter() -> void:
	var wood := mat(Color(0.48, 0.3, 0.16), 0.7)
	var top := mat(Color(0.62, 0.42, 0.24), 0.55)
	box(room, Vector3(-2.2, 0, -3.1), Vector3(2.2, 1.0, -2.5), wood)
	box(room, Vector3(-2.3, 1.0, -3.15), Vector3(2.3, 1.08, -2.45), top, false)
	box(room, Vector3(-4.0, 0, -4.8), Vector3(4.0, 2.6, -4.6), mat(Color(0.4, 0.25, 0.13), 0.8))       # shelves behind
	for y in [0.9, 1.6, 2.3]:
		box(room, Vector3(-3.8, y, -4.6), Vector3(3.8, y + 0.05, -4.25), top, false)
	var r := RandomNumberGenerator.new(); r.seed = 5
	for y in [0.95, 1.65]:
		for k in 9:
			var x := -3.5 + k * 0.85 + r.randf_range(-0.1, 0.1)
			var jar := cylinder(room, Vector3(x, y, -4.43), 0.09, 0.11, r.randf_range(0.22, 0.38), mat(Color.from_hsv(r.randf(), 0.4, 0.8), 0.3))
			jar.position.y = y + jar.mesh.height * 0.5 + 0.05
	Props.place(room, "coin_stack_small", Vector3(1.5, 1.08, -2.8), 20.0, 1.0)
	Props.place(room, "candle_triple", Vector3(-1.6, 1.08, -2.8), 0.0, 0.5)
	var scale_m := mat(Color(0.85, 0.65, 0.3), 0.3, 0.8)
	cylinder(room, Vector3(0.6, 1.08, -2.8), 0.03, 0.03, 0.4, scale_m)
	box(room, Vector3(0.3, 1.47, -2.82), Vector3(0.9, 1.5, -2.78), scale_m, false)
	box(room, Vector3(-2.2, 0, -4.55), Vector3(2.2, 0.3, -3.15), mat(Color(0.4, 0.25, 0.13), 0.8))      # (a step to stand on)
	tobble = ShopNPC.make(room, "tobble_shop", IN + Vector3(0, 0.3, -3.7), 180.0,
		{"hero": "Rogue", "hair_style": "curly", "hair_color": Color(0.85, 0.66, 0.35), "hair_tint": Color(0.85, 0.66, 0.35),
		"face": "mustache", "outfit_color": Color(0.7, 0.55, 0.15), "cape_color": Color(0.55, 0.15, 0.4), "build": 1.2, "height": 0.92},
		"[E] Talk to Tobble (sell your gear)", func() -> void: open("sell"))
	label_sign(room, Vector3(0, 2.95, -2.8), "SELL YOUR GEAR HERE", Color(1.0, 0.85, 0.4), 2.2, 0.26)

func _elixir_shelf() -> void:
	var x := -W * 0.5 + 0.35
	var wood := mat(Color(0.45, 0.28, 0.15), 0.75)
	box(room, Vector3(x, 0, -1.6), Vector3(x + 0.6, 2.2, 1.0), wood)
	var cols := [Color(0.55, 0.85, 1.0), Color(0.5, 1.0, 0.6), Color(1.0, 0.45, 0.3), Color(1.0, 0.85, 0.3)]
	for y in [0.75, 1.35, 1.95]:
		box(room, Vector3(x + 0.6, y - 0.05, -1.6), Vector3(x + 0.95, y, 1.0), wood, false)
		for k in 6:
			var c: Color = cols[(k + int(y * 3.0)) % cols.size()]
			var z := -1.4 + k * 0.42
			var bm := mat(c.darkened(0.15), 0.25, 0.1)
			bm.emission_enabled = true; bm.emission = c; bm.emission_energy_multiplier = 0.35
			cylinder(room, Vector3(x + 0.78, y, z), 0.07, 0.1, 0.24, bm)
			cylinder(room, Vector3(x + 0.78, y + 0.24, z), 0.03, 0.03, 0.08, mat(Color(0.55, 0.35, 0.2)))
	label_sign(room, Vector3(x + 1.0, 2.6, -0.3), "ELIXIRS", Color(0.6, 1.0, 0.8))
	Usable.make(self, IN + Vector3(x + 1.6, 1.0, -0.3), "[E] Look at the elixirs", func() -> void: open("elixir"))

func _enchant_table() -> void:
	var at := Vector3(-3.7, 0, -3.3)
	var wood := mat(Color(0.35, 0.2, 0.12), 0.7)
	box(room, at + Vector3(-0.8, 0, -0.45), at + Vector3(0.8, 0.85, 0.45), wood)
	box(room, at + Vector3(-0.7, 0.85, -0.38), at + Vector3(0.7, 0.88, 0.38), mat(Color(0.3, 0.1, 0.35), 0.9), false)     # velvet
	var blade := Props.place(room, "sword_shield", at + Vector3(0, 0.9, 0), 90.0, 0.6)
	blade.rotation_degrees.x = 0.0
	var runes := CPUParticles3D.new(); runes.amount = 14; runes.lifetime = 1.6
	runes.mesh = FX.quad(0.08); runes.material_override = FX.glow_material(Color(1.0, 0.55, 0.2), 2.2)
	runes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; runes.emission_box_extents = Vector3(0.6, 0.05, 0.3)
	runes.direction = Vector3.UP; runes.spread = 10; runes.initial_velocity_min = 0.2; runes.initial_velocity_max = 0.5
	runes.gravity = Vector3.ZERO; runes.color_ramp = FX._fade_ramp(Color(1.0, 0.6, 0.25))
	room.add_child(runes); runes.position = at + Vector3(0, 0.95, 0)
	label_sign(room, at + Vector3(0, 1.75, 0), "WEAPON ENCHANTING", Color(1.0, 0.65, 0.35))
	Usable.make(self, IN + at + Vector3(0, 1.0, 0.9), "[E] Enchant your weapon", func() -> void: open("enchant"))

func _blessing_altar() -> void:
	var at := Vector3(3.7, 0, -3.3)
	var stone := mat(Color(0.62, 0.6, 0.58), 0.9)
	box(room, at + Vector3(-0.55, 0, -0.55), at + Vector3(0.55, 0.25, 0.55), stone)
	box(room, at + Vector3(-0.35, 0.25, -0.35), at + Vector3(0.35, 0.9, 0.35), stone)
	box(room, at + Vector3(-0.5, 0.9, -0.5), at + Vector3(0.5, 1.0, 0.5), stone)
	var sh := Props.place(room, "sword_shield_gold", at + Vector3(0, 1.25, 0), 180.0, 0.55)
	var spin := create_tween().set_loops()
	spin.tween_property(sh, "rotation:y", sh.rotation.y + TAU, 6.0).as_relative()
	var halo := CPUParticles3D.new(); halo.amount = 18; halo.lifetime = 2.0
	halo.mesh = FX.quad(0.07); halo.material_override = FX.glow_material(Color(1.0, 0.95, 0.6), 2.0)
	halo.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; halo.emission_ring_axis = Vector3.UP
	halo.emission_ring_radius = 0.6; halo.emission_ring_inner_radius = 0.5; halo.emission_ring_height = 0.05
	halo.direction = Vector3.UP; halo.spread = 5; halo.initial_velocity_min = 0.2; halo.initial_velocity_max = 0.4; halo.gravity = Vector3.ZERO
	room.add_child(halo); halo.position = at + Vector3(0, 1.05, 0)
	label_sign(room, at + Vector3(0, 2.1, 0), "ARMOR BLESSINGS", Color(1.0, 0.95, 0.65))
	Usable.make(self, IN + at + Vector3(-0.2, 1.0, 0.9), "[E] Bless your armor", func() -> void: open("bless"))

func _costume_rack() -> void:
	var x := W * 0.5 - 1.2
	for k in 2:
		var id: String = ["golden_knight", "star_mage"][k]
		var z := -1.4 + k * 1.6
		var stand := mat(Color(0.4, 0.26, 0.14), 0.8)
		cylinder(room, Vector3(x, 0, z), 0.4, 0.45, 0.12, stand)
		var m := CharacterModel.new()
		room.add_child(m)
		m.position = Vector3(x, 0.12, z)
		m.rotation.y = deg_to_rad(90.0)
		m.setup({"kind": "hero", "hero": "Knight", "costume": id, "scale": 0.84})
		m.set_process(false)
		if m.anim:
			m.anim.play("Idle" if m.anim.has_animation("Idle") else m.anim.current_animation)
			m.anim.seek(0.3, true)
			m.anim.speed_scale = 0.0
	label_sign(room, Vector3(x - 0.4, 2.55, -0.6), "COSTUMES", Color(1.0, 0.7, 1.0))
	Usable.make(self, IN + Vector3(x - 1.5, 1.0, -0.6), "[E] Look at the costumes", func() -> void: open("costume"))

func _yard_catalog() -> void:
	var at := Vector3(-3.8, 0, 2.6)
	var wood := mat(Color(0.42, 0.26, 0.14), 0.75)
	box(room, at + Vector3(-0.15, 0, -0.15), at + Vector3(0.15, 1.0, 0.15), wood)
	var top := box(room, at + Vector3(-0.4, 1.0, -0.3), at + Vector3(0.4, 1.06, 0.3), wood, false)
	top.rotation.x = 0.35
	var book := box(room, at + Vector3(-0.32, 1.08, -0.22), at + Vector3(0.32, 1.12, 0.22), mat(Color(0.95, 0.92, 0.82)), false)
	book.rotation.x = 0.35
	# a little gnome and a flower pot to show what's on offer
	var g := Node3D.new(); room.add_child(g); g.position = at + Vector3(0.9, 0, -0.2)
	HomeDecor.gnome_model(self, g, 0.6)
	cylinder(room, at + Vector3(-0.9, 0, -0.1), 0.22, 0.16, 0.35, mat(Color(0.7, 0.35, 0.2)))
	for k in 6:
		var a := k * TAU / 6.0
		sphere(room, at + Vector3(-0.9 + cos(a) * 0.12, 0.45, -0.1 + sin(a) * 0.12), 0.08, mat(Color.from_hsv(k / 6.0, 0.6, 1.0), 0.6))
	label_sign(room, at + Vector3(0, 1.75, 0), "FOR YOUR YARD", Color(0.6, 1.0, 0.6))
	Usable.make(self, IN + at + Vector3(0.3, 1.0, -0.8), "[E] Things for your yard", func() -> void: open("deco"))

func _special_pedestal() -> void:
	var at := Vector3(3.8, 0, 2.6)
	var stone := mat(Color(0.75, 0.68, 0.55), 0.6)
	cylinder(room, at, 0.45, 0.5, 0.9, stone)
	var dome := sphere(room, at + Vector3(0, 0.9, 0), 0.4, null, 1.0)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.8, 0.95, 1.0, 0.18); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05; gm.metallic_specular = 1.0
	dome.material_override = gm
	_special = Node3D.new(); room.add_child(_special); _special.position = at + Vector3(0, 1.1, 0)
	var star := sphere(_special, Vector3.ZERO, 0.12, glow(Color(1.0, 0.9, 0.4), 3.0))
	star.scale = Vector3(1, 1, 1)
	var sp := CPUParticles3D.new(); sp.amount = 16; sp.lifetime = 1.2
	sp.mesh = FX.quad(0.06); sp.material_override = FX.glow_material(Color(1.0, 0.9, 0.5), 2.5)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.3
	sp.direction = Vector3.UP; sp.spread = 180; sp.initial_velocity_min = 0.1; sp.initial_velocity_max = 0.3; sp.gravity = Vector3.ZERO
	_special.add_child(sp)
	var bob := create_tween().set_loops()
	bob.tween_property(_special, "position:y", 0.12, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(_special, "position:y", -0.12, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	var w := ShopCatalog.ware(ShopCatalog.special_id())
	label_sign(room, at + Vector3(0, 2.05, 0), "TODAY'S SPECIAL", Color(1.0, 0.9, 0.4))
	label_sign(room, at + Vector3(0, 1.78, 0), "%s: HALF PRICE!" % String(w.get("name", "?")), Color(1.0, 0.97, 0.85), 1.9, 0.18)
	Usable.make(self, IN + at + Vector3(-0.3, 1.0, -0.9), "[E] Today's Special (half price!)", func() -> void: open("special"))

# --- using it ------------------------------------------------------------------------
func _process(_delta: float) -> void:
	var p := home.player
	if p == null:
		return
	var inside := is_inside(p.global_position)
	if inside != _inside:
		_inside = inside
		room.visible = inside      # (no point drawing a room nobody's in)

func go_in() -> void:
	var sc := scene_main()
	if sc and sc.has_method("teleport_player"):
		Sfx.play("door", -4.0, 0.1)
		room.visible = true
		sc.teleport_player(arrival(), 0.0, "Tobble's Trading Post")
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			Game.say(_greeting(), Color(1.0, 0.88, 0.6)))

func go_out() -> void:
	var sc := scene_main()
	if sc and sc.has_method("teleport_player"):
		Sfx.play("door", -4.0, 0.1)
		sc.teleport_player(door_out() + Vector3(0, 0.1, 0), deg_to_rad(YAW) + PI, "Out into the yard.")

func open(tab: String) -> void:
	var sc := scene_main()
	if sc and sc.has_method("open_shop"):
		sc.open_shop(tab)

const GREETINGS := [
	"Tobble: \"Welcome, welcome! Mind the jars. Everything's for sale!\"",
	"Tobble: \"My hero! Thanks to you I've got my strongbox back. Have a look around!\"",
	"Tobble: \"Fresh elixirs today! Well... fresh-ish.\"",
	"Tobble: \"Got any gear you're not using? I pay a fair price. Ask at the counter!\"",
	"Tobble: \"Have you seen Today's Special? Half price, today only!\"",
]

func _greeting() -> String:
	return GREETINGS[randi() % GREETINGS.size()]
