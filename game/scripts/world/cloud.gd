extends Node3D
class_name CloudWorld
## Level 4: CLOUD ISLAND (designed by Orion). Islands of cloud in a sunny sky,
## reached by a cloud lift from Ghost Knight Castle.
##
##   The sea of clouds (y = 0): soft and safe. Fall off an island and you land
##       here, then ride a bubble back up.
##   A  the temple island (y = 20): the angels' ziggurat, the cloud garden.
##   B, C  the middle islands (y = 40), joined by a thin wispy bridge that only
##       holds you when you're light.
##   D  the storm layer (y = 62): rain clouds, lightning, the Hail Golem.
##   E  the thunderhead (y = 86): Mr. Bubbles.
##
## Bubbles carry you between islands. A simple weight meter (FLOATY..HEAVY)
## changes how you jump, fall and get pushed by wind: raindrops make you
## heavier; stand still and they rain back out of you.

signal area_changed(area: String)

const PLAY := 125.0
const ISLANDS := {
	"A": {"c": Vector3(0, 20, 0), "r": 32.0, "storm": false},
	"B": {"c": Vector3(-58, 40, -45), "r": 18.0, "storm": false},
	"C": {"c": Vector3(58, 40, -45), "r": 18.0, "storm": false},
	"D": {"c": Vector3(0, 62, -95), "r": 22.0, "storm": true},
	"E": {"c": Vector3(0, 86, -145), "r": 24.0, "storm": true},
}
## [base position, destination island, quest that must be done first ("" = always)]
const VENTS := [
	[Vector3(0, 0, 42), "A", ""], [Vector3(-42, 0, 6), "A", ""], [Vector3(42, 0, -6), "A", ""],
	[Vector3(-20, 20, -22), "B", ""], [Vector3(20, 20, -22), "C", ""],
	[Vector3(-56, 40, -60), "D", "bubble_lifts"], [Vector3(56, 40, -60), "D", "bubble_lifts"],
	[Vector3(0, 62, -114), "E", "storm_gate"],
]
const GARDEN := Vector3(19, 20, 11)
const UPDRAFTS := [Vector3(-18, 20, 8), Vector3(-62, 40, -36), Vector3(64, 40, -54)]

var player: Player
var spawn_point := Vector3.ZERO
var spawn_yaw := 0.0
var area := ""
var b: Builder
var env: Environment
var sun: DirectionalLight3D
var _rng := RandomNumberGenerator.new()
var _cloud_mat: ShaderMaterial
var _storm_mat: ShaderMaterial
var _wisp_mat: ShaderMaterial
var _puffs: Array = []          # [Transform3D, Color]
var _wisps: Array[StaticBody3D] = []
var _vent_nodes: Array = []     # [Node3D, index]
var _beacon_lights := {}
var warden: Enemy               # (the Hail Golem; named for the shared boss code)
var lord: Enemy                 # Mr. Bubbles
var _boss_started := false
var _whale: Node3D
var _whale_cloud: Node3D
var _flowers: Node3D

# --- weight -------------------------------------------------------------------
var weight := 0.5               # 0 = floaty ... 1 = heavy
var base_weight := 0.5          # set by your skin
var _still_t := 0.0
var _raining := false
var _rain_fx: CPUParticles3D
var _weight_ui: Control
var _weight_bar: ProgressBar
var _weight_label: Label
var _was_floor := true
var _fall_v := 0.0
var _gust_t := 0.0

# --- bubbles ------------------------------------------------------------------
var _ride := {}                 # the bubble you're riding: {to, phase, t, vis}
var _ride_cd := 0.0
var _arrival_done := false

func build() -> void:
	_rng.seed = 41
	b = Builder.new(self)
	_cloud_mat = ShaderMaterial.new(); _cloud_mat.shader = load("res://shaders/cloud.gdshader")
	_cloud_mat.set_shader_parameter("tint", Color(0.97, 0.96, 0.94))
	_cloud_mat.set_shader_parameter("shade", Color(0.58, 0.65, 0.84))
	_cloud_mat.set_shader_parameter("rim_glow", 0.28)
	_storm_mat = _cloud_mat.duplicate()
	_storm_mat.set_shader_parameter("tint", Color(0.62, 0.64, 0.75))
	_storm_mat.set_shader_parameter("shade", Color(0.28, 0.3, 0.4))
	_storm_mat.set_shader_parameter("rim_glow", 0.25)
	_wisp_mat = _cloud_mat.duplicate()
	_wisp_mat.set_shader_parameter("tint", Color(0.95, 0.97, 1.0))
	_environment()
	_sea()
	for k in ISLANDS:
		_island(k)
	_temple()
	_garden()
	_updrafts()
	_wisp_bridge()
	_vents()
	_storm_layer()
	_thunderhead()
	_sky_whale()
	_quest_items()
	_raindrops()
	_enemies()
	_flush_puffs()
	_bounds()
	_motes()
	b.fix_coplanar()
	_weight_hud()
	spawn_point = ISLANDS.A.c + Vector3(0, 14.0, 24.0)
	spawn_yaw = 0.0
	Game.quests_changed.connect(_on_quests)
	_on_quests()
	if Game.is_compat():
		for l in find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				(l as Light3D).shadow_enabled = false

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, _top_at(x, z), z)

func _top_at(x: float, z: float) -> float:
	for k in ISLANDS:
		var c: Vector3 = ISLANDS[k].c
		if Vector2(x - c.x, z - c.z).length() < ISLANDS[k].r:
			return c.y
	return 0.0

func island_of(p: Vector3) -> String:
	for k in ISLANDS:
		var c: Vector3 = ISLANDS[k].c
		if Vector2(p.x - c.x, p.z - c.z).length() < ISLANDS[k].r + 2.0 and absf(p.y - c.y) < 12.0:
			return k
	return "sea" if p.y < 10.0 else "air"

# ---------------------------------------------------------------------------
# Sky and sea of clouds
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.16, 0.38, 0.9)
	psm.sky_horizon_color = Color(0.58, 0.74, 0.98)
	psm.ground_horizon_color = Color(0.85, 0.9, 1.0)
	psm.ground_bottom_color = Color(0.9, 0.93, 1.0)
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.7, 0.8, 1.0)
	env.fog_depth_begin = 120.0
	env.fog_depth_end = 420.0
	env.fog_density = 0.3
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

func _puff(pos: Vector3, scl: Vector3, col := Color(1, 1, 1)) -> void:
	_puffs.append([Transform3D(Basis().scaled(scl), pos), col])

func _flush_puffs() -> void:
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 14; sm.rings = 7
	for storm in [false, true]:
		var list := _puffs.filter(func(p) -> bool: return ((p[1] as Color).v < 0.8) == storm)
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = sm
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _storm_mat if storm else _cloud_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not storm else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)

func _sea() -> void:
	# a soft floor of clouds as far as you can see (and it catches you)
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(PLAY * 2.0 + 40, 2.0, PLAY * 2.0 + 40)
	cs.shape = bs; cs.position = Vector3(0, -1.0, 0); sb.add_child(cs)
	var x := -180.0
	while x <= 180.0:
		var z := -200.0
		while z <= 180.0:
			var r := _rng.randf_range(7.0, 12.0)
			_puff(Vector3(x + _rng.randf_range(-4, 4), -r * 0.55 + _rng.randf_range(-0.6, 0.4), z + _rng.randf_range(-4, 4)),
				Vector3(r, r * 0.6, r), Color(1, 1, 1).darkened(_rng.randf_range(0.0, 0.08)))
			z += 14.0
		x += 14.0

## An island: a flat-topped cylinder you stand on, dressed in puffs.
func _island(k: String) -> void:
	var c: Vector3 = ISLANDS[k].c
	var r: float = ISLANDS[k].r
	var storm: bool = ISLANDS[k].storm
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = r; cy.height = 6.0
	cs.shape = cy; cs.position = c - Vector3(0, 3.0, 0); sb.add_child(cs)
	var col := Color(0.62, 0.64, 0.74) if storm else Color(1, 1, 1)
	# flattened puffs make the walking surface (their tops sit a hair above it)
	var n := int(r * r / 22.0) + 6
	for i in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * (r - 3.0)
		var pr := _rng.randf_range(3.5, 6.0)
		_puff(c + Vector3(cos(a) * d, -pr * 0.32 + 0.15, sin(a) * d), Vector3(pr, pr * 0.35, pr), col.darkened(_rng.randf_range(0.0, 0.06)))
	# a fat puffy rim
	var rim := int(r * 0.9)
	for i in rim:
		var a := TAU * i / rim + _rng.randf_range(-0.1, 0.1)
		var pr := _rng.randf_range(3.0, 4.6)
		_puff(c + Vector3(cos(a) * (r - 1.2), -pr * 0.45, sin(a) * (r - 1.2)), Vector3(pr, pr * 0.8, pr), col.darkened(_rng.randf_range(0.0, 0.1)))
	# and a soft underside
	for i in int(r * 0.6):
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r * 0.75
		var pr := _rng.randf_range(4.0, 7.0)
		_puff(c + Vector3(cos(a) * d, -3.5 - _rng.randf_range(0, 3.0), sin(a) * d), Vector3(pr, pr * 0.7, pr), col.darkened(0.12))

# ---------------------------------------------------------------------------
# The angels' temple island (A)
func _temple() -> void:
	var c: Vector3 = ISLANDS.A.c
	var sand := StandardMaterial3D.new(); sand.albedo_color = Color(0.93, 0.84, 0.64); sand.roughness = 0.85
	var lapis := StandardMaterial3D.new(); lapis.albedo_color = Color(0.18, 0.3, 0.75); lapis.roughness = 0.5
	var gold := StandardMaterial3D.new(); gold.albedo_color = Color(1.0, 0.8, 0.35); gold.metallic = 0.8; gold.roughness = 0.3
	var tc := c + Vector3(0, 0, -14)
	# a three-step ziggurat with a stair up the front and a shrine on top
	var steps := [[12.0, 3.0], [9.0, 3.0], [6.0, 2.6]]
	var y := c.y - 0.5
	for i in steps.size():
		var hw: float = steps[i][0]; var hh: float = steps[i][1]
		b.box(Vector3(tc.x - hw, y, tc.z - hw * 0.8), Vector3(tc.x + hw, y + hh, tc.z + hw * 0.8), sand)
		b.box(Vector3(tc.x - hw - 0.05, y + hh - 0.35, tc.z - hw * 0.8 - 0.05), Vector3(tc.x + hw + 0.05, y + hh, tc.z + hw * 0.8 + 0.05), lapis, false)
		y += hh
	b.stairs(tc.x - 2.0, tc.x + 2.0, tc.z + 4.8 - 0.1, tc.z + 9.6 + 4.0, y, c.y - 0.5, sand)
	b.box(Vector3(tc.x - 3.0, y, tc.z - 2.5), Vector3(tc.x + 3.0, y + 3.2, tc.z + 2.5), lapis)
	b.box(Vector3(tc.x - 3.4, y + 3.2, tc.z - 2.9), Vector3(tc.x + 3.4, y + 3.6, tc.z + 2.9), gold)
	var sl := OmniLight3D.new(); sl.light_color = Color(1.0, 0.85, 0.5); sl.light_energy = 3.0; sl.omni_range = 16.0
	sl.position = Vector3(tc.x, y + 5.0, tc.z); add_child(sl)
	# winged-bull guardians (lamassu) at the foot of the stair
	for sx in [-1.0, 1.0]:
		_lamassu(Vector3(tc.x + sx * 5.5, c.y, tc.z + 14.5), sand, gold)
	# the angels
	_angel("anu", c + Vector3(0, 0, 2.0), 180.0, Color(1.0, 0.85, 0.4), Color(0.2, 0.3, 0.75), "Mage", Color(0.95, 0.95, 0.95))
	_angel("ninlil", c + Vector3(-11, 0, 8), 140.0, Color(0.6, 0.85, 1.0), Color(0.95, 0.95, 1.0), "Rogue", Color(1.0, 0.85, 0.45))
	_angel("nanshe", c + Vector3(11, 0, 8), -140.0, Color(0.3, 0.75, 0.6), Color(0.9, 0.95, 0.9), "Ranger", Color(0.25, 0.2, 0.15))
	_angel("enki", c + Vector3(15, 0, 14), -120.0, Color(0.35, 0.55, 1.0), Color(0.85, 0.9, 1.0), "Mage", Color(0.85, 0.85, 0.9))
	_angel("utu", c + Vector3(-15, 0, -6), 100.0, Color(1.0, 0.65, 0.25), Color(0.95, 0.85, 0.6), "Knight", Color(0.3, 0.2, 0.1))
	Interactable.create(self, "shrine", c + Vector3(-5, 0, 18), 0.0, "", [], "the Sky Temple")
	Interactable.create(self, "inscription", c + Vector3(6, 0, 22), 180.0, "", [], "Sky stone",
		"CLOUD ISLAND\\n\\nA cloud can weigh as much as a hundred elephants, yet it floats.\\nAsk Enki the Rainmaker why.\\n\\nBubbles rise from the vents: step in to float up.\\nFall off? The sea of clouds will catch you.")
	SkyLift.make(self, c + Vector3(-22, 0, 16), "Ride the rain cloud down to Castle Morwen", "go_back_to_castle", Color(0.8, 0.85, 0.95))
	Interactable.create(self, "chest", c + Vector3(tc.x + 4, y, tc.z), 0.0, "cl_chest_temple", [{"roll": "big", "ilvl": 11}])
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		Props.torch(self, c + Vector3(cos(a) * 26.0, 0, sin(a) * 26.0), 0.0, false, false, Color(1.0, 0.8, 0.45))

func _lamassu(at: Vector3, stone: Material, gold: Material) -> void:
	b.box(at + Vector3(-0.8, 0, -1.6), at + Vector3(0.8, 1.8, 1.6), stone)
	b.box(at + Vector3(-0.6, 1.8, -1.8), at + Vector3(0.6, 3.0, -0.6), stone)
	b.box(at + Vector3(-0.65, 3.0, -1.85), at + Vector3(0.65, 3.4, -0.55), gold, false)
	b.box(at + Vector3(-0.4, 1.5, -1.95), at + Vector3(0.4, 2.1, -1.8), stone, false)     # beard
	for sx in [-1.0, 1.0]:
		var w := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.15, 1.4, 2.6)
		w.mesh = bm; w.material_override = gold
		w.position = at + Vector3(sx * 0.95, 2.4, 0.3); w.rotation = Vector3(0.35, 0, sx * 0.2)
		add_child(w)

## An angel: one of the game's characters in robes, with big feathered wings and a glow.
func _angel(id: String, pos: Vector3, yaw: float, robe: Color, wing: Color, hero: String, hair: Color) -> void:
	var npc := NPC.create(self, id, pos, yaw, {"hero": hero, "hat": false, "hair_style": "long",
		"hair_color": hair, "hair_tint": hair, "face": "none",
		"outfit_color": robe, "cape_color": robe.lightened(0.2), "skin_color": Color(0.88, 0.7, 0.55), "height": 1.12})
	var wings := AngelWings.make(wing, 1.15)
	npc.body.add_child(wings)
	var l := OmniLight3D.new(); l.light_color = wing.lerp(Color(1, 1, 1), 0.5); l.light_energy = 1.0; l.omni_range = 5.0
	l.position = Vector3(0, 2.2, 0); npc.add_child(l)

# ---------------------------------------------------------------------------
func _garden() -> void:
	# Enki's dry cloud garden: rain on it and flowers spring up
	var soil := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 4.0; cm.bottom_radius = 4.2; cm.height = 0.3
	soil.mesh = cm
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.55, 0.42, 0.3); sm.roughness = 1.0
	soil.material_override = sm
	soil.position = GARDEN + Vector3(0, 0.1, 0)
	add_child(soil)
	_flowers = Node3D.new(); add_child(_flowers); _flowers.position = GARDEN + Vector3(0, 0.25, 0)
	for k in 26:
		var a := _rng.randf() * TAU; var d := sqrt(_rng.randf()) * 3.6
		var f := Node3D.new(); _flowers.add_child(f); f.position = Vector3(cos(a) * d, 0, sin(a) * d)
		var st := MeshInstance3D.new(); var stc := CylinderMesh.new(); stc.top_radius = 0.03; stc.bottom_radius = 0.04; stc.height = 0.6
		st.mesh = stc; var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.7, 0.3); st.material_override = gm
		st.position.y = 0.3; f.add_child(st)
		var bl := MeshInstance3D.new(); var bsm := SphereMesh.new(); bsm.radius = 0.15; bsm.height = 0.2
		bl.mesh = bsm; bl.material_override = FX.glow_material(Color.from_hsv(_rng.randf(), 0.6, 1.0), 0.8)
		bl.position.y = 0.65; f.add_child(bl)
	Interactable.create(self, "inscription", GARDEN + Vector3(4.6, 0, 3.0), 200.0, "", [], "Enki's cloud garden",
		"A DRY CLOUD GARDEN\\n\\nIt needs rain. Get heavy with raindrops,\\nthen stand still right here.")

func _updrafts() -> void:
	# shimmering columns of rising warm air: stand in one and float up
	for p in UPDRAFTS:
		var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.2; cm.bottom_radius = 2.4; cm.height = 16.0
		cm.cap_top = false; cm.cap_bottom = false
		col.mesh = cm
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.albedo_color = Color(1.0, 0.8, 0.5, 0.12)
		col.material_override = m; col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		col.position = p + Vector3(0, 8.0, 0)
		add_child(col)
		var sp := CPUParticles3D.new(); sp.amount = 40; sp.lifetime = 2.5
		sp.mesh = FX.quad(0.12); sp.material_override = FX.glow_material(Color(1.0, 0.85, 0.55), 1.6)
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sp.emission_box_extents = Vector3(1.8, 0.2, 1.8)
		sp.direction = Vector3.UP; sp.spread = 5; sp.initial_velocity_min = 4.0; sp.initial_velocity_max = 7.0
		sp.gravity = Vector3.ZERO; sp.color_ramp = FX._fade_ramp(Color(1.0, 0.85, 0.55))
		sp.position = p + Vector3(0, 0.3, 0)
		add_child(sp)

## A thin, wispy bridge between the middle islands: it only holds you when you're light.
func _wisp_bridge() -> void:
	var y: float = ISLANDS.B.c.y
	var x := -40.0
	while x < 40.0:
		var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(8.2, 1.0, 5.0)
		cs.shape = bs; cs.position = Vector3(x + 4.0, y - 0.5, -45.0 + sin(x * 0.08) * 3.0); sb.add_child(cs)
		_wisps.append(sb)
		for k in 3:
			var p := Vector3(x + 1.5 + k * 2.6, y - 0.4, cs.position.z + _rng.randf_range(-1.2, 1.2))
			var mi := MeshInstance3D.new(); var smh := SphereMesh.new(); smh.radius = 1.6; smh.height = 1.4
			mi.mesh = smh; mi.material_override = _wisp_mat; mi.position = p
			mi.set_meta("wisp", true)
			add_child(mi)
		x += 8.0

func _vents() -> void:
	for i in VENTS.size():
		var base: Vector3 = VENTS[i][0]
		var v := Node3D.new(); add_child(v); v.position = base
		var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 1.1; tm.outer_radius = 1.5
		ring.mesh = tm
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.85, 0.75, 0.5); rm.metallic = 0.6; rm.roughness = 0.3
		ring.material_override = rm; ring.position.y = 0.15; v.add_child(ring)
		var bub := CPUParticles3D.new(); bub.amount = 14; bub.lifetime = 2.6
		var bm := SphereMesh.new(); bm.radius = 0.25; bm.height = 0.5; bub.mesh = bm
		var bmat := StandardMaterial3D.new(); bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.albedo_color = Color(0.8, 0.95, 1.0, 0.35); bmat.emission_enabled = true; bmat.emission = Color(0.6, 0.85, 1.0)
		bmat.emission_energy_multiplier = 0.5; bmat.roughness = 0.05
		bub.material_override = bmat
		bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; bub.emission_sphere_radius = 0.8
		bub.direction = Vector3.UP; bub.spread = 8; bub.initial_velocity_min = 2.0; bub.initial_velocity_max = 3.5
		bub.gravity = Vector3.ZERO; bub.scale_amount_min = 0.6; bub.scale_amount_max = 1.8
		bub.position.y = 0.4
		v.add_child(bub)
		var l := OmniLight3D.new(); l.light_color = Color(0.6, 0.85, 1.0); l.light_energy = 1.4; l.omni_range = 6.0
		l.position.y = 1.5; v.add_child(l)
		v.add_to_group("bubble_vent")
		_vent_nodes.append([v, i])

func vent_active(i: int) -> bool:
	var need: String = VENTS[i][2]
	return need == "" or Game.quest_state(need) in ["ready", "done"]

func _storm_layer() -> void:
	var c: Vector3 = ISLANDS.D.c
	# heavy rain clouds hanging overhead, dripping
	for p in [Vector3(-8, 9, -4), Vector3(9, 10, 5), Vector3(2, 11, -12)]:
		var at: Vector3 = c + p
		for k in 6:
			_puff(at + Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-0.5, 1.0), _rng.randf_range(-3, 3)), Vector3.ONE * _rng.randf_range(2.2, 3.4), Color(0.5, 0.52, 0.62))
		var rain := CPUParticles3D.new(); rain.amount = 120; rain.lifetime = 1.1
		rain.mesh = FX.quad(0.05); rain.material_override = FX.glow_material(Color(0.7, 0.8, 1.0), 0.6)
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(3.5, 0.3, 3.5)
		rain.direction = Vector3.DOWN; rain.spread = 2; rain.initial_velocity_min = 9.0; rain.initial_velocity_max = 11.0
		rain.gravity = Vector3(0, -6, 0); rain.scale_amount_min = 1.0; rain.scale_amount_max = 3.0
		rain.position = at - Vector3(0, 1.0, 0)
		add_child(rain)
	Interactable.create(self, "shrine", c + Vector3(-12, 0, 12), 0.0, "", [], "the Storm Layer")

func _thunderhead() -> void:
	var c: Vector3 = ISLANDS.E.c
	# a ring of towering storm clouds around Mr. Bubbles' arena
	for k in 18:
		var a := k * TAU / 18.0
		_puff(c + Vector3(cos(a) * 27.0, 4.0, sin(a) * 27.0), Vector3(6, 9, 6), Color(0.5, 0.52, 0.62))
	Interactable.create(self, "shrine", c + Vector3(0, 0, 20), 0.0, "", [], "the Thunderhead")

func _sky_whale() -> void:
	var c: Vector3 = ISLANDS.C.c
	_whale = CreatureLook.make("whale", null)
	add_child(_whale)
	_whale.position = c + Vector3(6, 0.0, 6)
	_whale.rotation.y = -0.8
	_whale_cloud = Node3D.new(); add_child(_whale_cloud); _whale_cloud.position = c + Vector3(6, 0, 6)
	for k in 9:
		var mi := MeshInstance3D.new(); var smh := SphereMesh.new(); smh.radius = 2.2; smh.height = 3.6
		mi.mesh = smh; mi.material_override = _storm_mat
		var a := k * TAU / 9.0
		mi.position = Vector3(cos(a) * 3.0, 1.5 + (k % 3) * 0.8, sin(a) * 3.0)
		_whale_cloud.add_child(mi)
	var z := CPUParticles3D.new(); z.amount = 20; z.lifetime = 0.3
	z.mesh = FX.quad(0.12); z.material_override = FX.glow_material(Color(1.0, 0.95, 0.4), 3.0)
	z.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; z.emission_sphere_radius = 3.0
	z.gravity = Vector3.ZERO; z.spread = 180; z.initial_velocity_min = 1.0; z.initial_velocity_max = 3.0
	z.position.y = 2.0; _whale_cloud.add_child(z)

func _quest_items() -> void:
	var a: Vector3 = ISLANDS.A.c
	var feathers := [a + Vector3(-28, 0, -6), a + Vector3(27, 0, 10), ISLANDS.B.c + Vector3(-12, 0, 8),
		ISLANDS.C.c + Vector3(12, 0, -10), ISLANDS.D.c + Vector3(16, 0, 6), Vector3(0, 40, -45)]
	for i in feathers.size():
		QuestItem.create(self, "feather", "qi_feather_%d" % i, feathers[i])
	for i in UPDRAFTS.size():
		QuestItem.create(self, "updraft", "qi_updraft_%d" % i, UPDRAFTS[i] + Vector3(0, 7.0, 0))
	var stones := [a + Vector3(-26, 0, -10), ISLANDS.B.c + Vector3(8, 0, -6), ISLANDS.C.c + Vector3(-8, 0, -6)]
	for i in stones.size():
		QuestItem.create(self, "ventstone", "qi_vent_%d" % i, stones[i])
	for i in 8:
		var ang := i * TAU / 8.0 + 0.2
		QuestItem.create(self, "stormbubble", "qi_sbub_%d" % i, a + Vector3(cos(ang) * 20.0, 1.0, sin(ang) * 20.0 + 4.0))

## Raindrops: each one makes you heavier. They come back after a while.
func _raindrops() -> void:
	var spots := []
	for k in 8:
		var ang := k * TAU / 8.0
		spots.append(GARDEN + Vector3(cos(ang) * 7.0, 0, sin(ang) * 7.0))
	for k in 6:
		var ang := k * TAU / 6.0
		spots.append(ISLANDS.D.c + Vector3(cos(ang) * 9.0, 0, sin(ang) * 9.0))
	for p in [ISLANDS.B.c + Vector3(4, 0, 10), ISLANDS.B.c + Vector3(-6, 0, 4), ISLANDS.C.c + Vector3(-4, 0, 10), ISLANDS.C.c + Vector3(5, 0, 2),
			ISLANDS.A.c + Vector3(-8, 0, 22), ISLANDS.A.c + Vector3(8, 0, 25)]:
		spots.append(p)
	for p in spots:
		Raindrop.make(self, p + Vector3(0, 0.7, 0))

func _enemies() -> void:
	var n := 0
	var list := [
		[ISLANDS.A.c + Vector3(-24, 3, 18), "thunder_bird"], [ISLANDS.A.c + Vector3(24, 3, -20), "thunder_bird"],
		[ISLANDS.B.c + Vector3(6, 3, 4), "thunder_bird"], [ISLANDS.B.c + Vector3(-6, 2, -8), "storm_bat"], [ISLANDS.B.c + Vector3(0, 0, 12), "bubble_mimic"],
		[ISLANDS.C.c + Vector3(2, 2, 10), "storm_sprite"], [ISLANDS.C.c + Vector3(10, 2, 0), "storm_sprite"], [ISLANDS.C.c + Vector3(-6, 2, 6), "storm_sprite"],
		[ISLANDS.C.c + Vector3(-10, 3, -8), "thunder_bird"], [ISLANDS.C.c + Vector3(0, 0, -14), "bubble_mimic"],
		[ISLANDS.D.c + Vector3(-10, 2, 4), "storm_bat"], [ISLANDS.D.c + Vector3(10, 2, -4), "storm_bat"], [ISLANDS.D.c + Vector3(6, 2, 10), "storm_sprite"],
		[ISLANDS.D.c + Vector3(-6, 3, -10), "thunder_bird"],
	]
	for e in list:
		_enemy(e[1], e[0], "cl_%d" % n)
		n += 1

func _enemy(type_name: String, pos: Vector3, uid: String) -> Enemy:
	if uid != "" and Game.flags.get(uid, false):
		return null
	var e := Enemy.new()
	e.configure(type_name, uid, 0.0)
	e.position = pos + Vector3(0, 0.3, 0)
	add_child(e)
	return e

func _bounds() -> void:
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	for w in [[Vector3(0, 60, -PLAY - 1), Vector3(PLAY * 2 + 4, 200, 2)], [Vector3(0, 60, PLAY + 1), Vector3(PLAY * 2 + 4, 200, 2)],
			[Vector3(-PLAY - 1, 60, 0), Vector3(2, 200, PLAY * 2 + 4)], [Vector3(PLAY + 1, 60, 0), Vector3(2, 200, PLAY * 2 + 4)]]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = w[1]
		cs.shape = bs; cs.position = w[0]; sb.add_child(cs)

func _motes() -> void:
	for c in [ISLANDS.A.c, ISLANDS.B.c, ISLANDS.C.c]:
		var p := CPUParticles3D.new()
		p.amount = 40; p.lifetime = 8.0; p.preprocess = 8.0
		p.mesh = FX.quad(0.08); p.material_override = FX.glow_material(Color(1.0, 0.97, 0.8), 1.4)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(24, 4, 24)
		p.direction = Vector3(1, 0.2, 0); p.spread = 180; p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.4
		p.gravity = Vector3.ZERO; p.color_ramp = FX._fade_ramp(Color(1.0, 0.97, 0.8))
		p.position = c + Vector3(0, 3, 0)
		add_child(p)

# ---------------------------------------------------------------------------
# The weight meter
func _weight_hud() -> void:
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	_weight_ui = Control.new(); _weight_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_ui.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cl.add_child(_weight_ui)
	var box := VBoxContainer.new(); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(-160, -132); box.custom_minimum_size = Vector2(320, 0)
	_weight_ui.add_child(box)
	_weight_label = UIKit.label("FLOATY   ·   WEIGHT   ·   HEAVY", 15, Color(0.9, 0.95, 1.0), true)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_weight_label)
	_weight_bar = UIKit.bar(Color(0.55, 0.75, 1.0), 320, 14)
	_weight_bar.max_value = 1.0
	box.add_child(_weight_bar)

func _skin_float() -> float:
	var cid := Game.costume_id()
	if cid != "" and Loot.COSTUMES.has(cid):
		return float(Loot.COSTUMES[cid].get("float", 0.5))
	return 0.5

func is_floaty() -> bool:
	return weight < 0.55 or not _ride.is_empty()

func add_rain(amount: float) -> void:
	weight = minf(1.0, weight + amount)

func _weight_step(delta: float) -> void:
	var new_base := _skin_float()
	if absf(new_base - base_weight) > 0.001:
		weight = clampf(weight + (new_base - base_weight), 0.0, 1.0)
		base_weight = new_base
	weight = maxf(weight, base_weight)
	# stand still and the raindrops rain back out of you
	var hs := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and hs < 0.4 and weight > base_weight + 0.01:
		_still_t += delta
	else:
		_still_t = 0.0
	var was := _raining
	_raining = _still_t > 0.8
	if _raining:
		weight = maxf(base_weight, weight - 0.18 * delta)
		if player.global_position.distance_to(GARDEN) < 4.5 and weight > 0.0 and Game.quest_state("make_it_rain") == "active" \
				and not Game.flags.get("cl_garden", false):
			Game.flags["cl_garden"] = true
			Game.on_quest_item("raingarden")
			Game.say("Rain falls on the garden... and it blooms!", Color(0.6, 0.9, 1.0))
			_grow_flowers()
	if _rain_fx == null:
		_rain_fx = CPUParticles3D.new(); _rain_fx.amount = 60; _rain_fx.lifetime = 0.8
		_rain_fx.mesh = FX.quad(0.05); _rain_fx.material_override = FX.glow_material(Color(0.6, 0.8, 1.0), 0.8)
		_rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _rain_fx.emission_sphere_radius = 0.6
		_rain_fx.direction = Vector3.DOWN; _rain_fx.spread = 8; _rain_fx.initial_velocity_min = 4.0; _rain_fx.initial_velocity_max = 6.0
		_rain_fx.gravity = Vector3(0, -6, 0); _rain_fx.scale_amount_min = 1.0; _rain_fx.scale_amount_max = 3.0
		_rain_fx.position.y = 2.6
		player.add_child(_rain_fx)
	_rain_fx.emitting = _raining
	if _raining and not was:
		Sfx.play("splash", -12.0, 0.2)
	# physics: floaty jumps higher and falls slower; heavy is the opposite
	var w := 0.0 if not _ride.is_empty() else weight
	player.gravity_mult = lerpf(0.45, 1.35, w)
	player.jump_mult = lerpf(1.35, 0.95, w)
	player.fall_cap = lerpf(5.0, 40.0, w * w)
	# gusts of wind over the wispy bridge and up on the storm layer
	_gust_t += delta
	var pp := player.global_position
	var windy := (absf(pp.z + 45.0) < 8.0 and absf(pp.x) < 42.0 and absf(pp.y - 40.0) < 8.0) or island_of(pp) == "D"
	var gust := Vector3(sin(_gust_t * 0.7) * 7.0, 0, cos(_gust_t * 0.45) * 2.0) if windy else Vector3.ZERO
	if _ride.is_empty():
		player.wind = gust * (1.0 - weight)
	# thin wisps only hold you when you're light
	var solid := is_floaty()
	for wb in _wisps:
		wb.collision_layer = 1 if solid else 0
	# heavy landing = ground-pound
	var on := player.is_on_floor()
	if not on:
		_fall_v = minf(_fall_v, player.velocity.y)
	elif not _was_floor:
		if weight > 0.7 and _fall_v < -9.0:
			_ground_pound()
		_fall_v = 0.0
	_was_floor = on
	_weight_bar.value = weight
	var hc := Color(0.55, 0.75, 1.0).lerp(Color(0.25, 0.35, 0.7), weight)
	(_weight_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = hc
	_weight_label.text = "%s   ·   %s" % ["FLOATY" if weight < 0.35 else ("HEAVY" if weight > 0.7 else "WEIGHT"), "raining..." if _raining else "stand still to rain"]

func _ground_pound() -> void:
	var at: Vector3 = player.global_position
	FX.shockwave(at + Vector3(0, 0.2, 0), Color(0.75, 0.85, 1.0), 4.5, 0.4)
	FX.burst(at + Vector3(0, 0.3, 0), Color(1, 1, 1), 50, 6.0, 0.3, 0.7, -3.0)
	Sfx.play("slam", -2.0, 0.1)
	player.add_trauma(0.4)
	player._aoe(at, 4.0, Game.attack_damage() * 1.6, 8.0, true)

func _grow_flowers() -> void:
	for f in _flowers.get_children():
		var n := f as Node3D
		n.scale = Vector3(0.05, 0.05, 0.05)
		n.create_tween().tween_property(n, "scale", Vector3.ONE * randf_range(0.9, 1.5), randf_range(0.6, 1.4)).set_trans(Tween.TRANS_BACK)
	_flowers.visible = true

# ---------------------------------------------------------------------------
# Bubbles: ride a vent's bubble up to the next island.
func _bubble_step(delta: float) -> void:
	_ride_cd -= delta
	if _ride.is_empty():
		if _ride_cd > 0.0 or player.dead:
			return
		for vn in _vent_nodes:
			var v: Node3D = vn[0]
			var i: int = vn[1]
			var d := Vector2(player.global_position.x - v.position.x, player.global_position.z - v.position.z).length()
			if d < 1.7 and absf(player.global_position.y - v.position.y) < 2.5:
				if vent_active(i):
					_start_ride(VENTS[i][1], v.position)
				elif _ride_cd < -2.0:
					_ride_cd = 0.0
					Game.say("This vent is clogged. Utu the Gate-Warden knows how to fix it.", Color(0.8, 0.9, 1.0))
				break
		# warm updrafts lift you too (heavier = slower)
		for u in UPDRAFTS:
			var du := Vector2(player.global_position.x - u.x, player.global_position.z - u.z).length()
			var dy: float = player.global_position.y - u.y
			if du < 2.2 and dy > -1.0 and dy < 11.0:
				player.lift = lerpf(8.0, 1.5, weight) if dy < 9.0 else 0.0
				return
		if player.lift > -100.0 and player.lift < 9.0 and _arrival_done:
			player.lift = -999.0
		return
	var r: Dictionary = _ride
	r.t += delta
	var dest: Dictionary = ISLANDS[r.to]
	var dc: Vector3 = dest.c
	var pp := player.global_position
	var vis: Node3D = r.vis
	vis.global_position = pp + Vector3(0, 1.0, 0)
	vis.scale = Vector3.ONE * (1.0 + sin(r.t * 5.0) * 0.04)
	var to_c := Vector2(dc.x - pp.x, dc.z - pp.z)
	match r.phase:
		"up":
			player.lift = lerpf(9.0, 5.0, weight) if r.to != "arrive" else -2.5
			player.wind = Vector3.ZERO
			if pp.y > dc.y + 5.0:
				r.phase = "drift"
		"drift":
			player.lift = 0.6 if pp.y < dc.y + 4.0 else 0.0
			player.wind = Vector3(to_c.x, 0, to_c.y).normalized() * 7.0 if to_c.length() > 1.0 else Vector3.ZERO
			if to_c.length() < dest.r * 0.55:
				_pop_ride()
				return
	if r.t > 14.0 or (r.t > 0.5 and Input.is_action_just_pressed("attack")) or player.dead:
		_pop_ride()

func _start_ride(to: String, from: Vector3) -> void:
	var vis := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.3; sm.height = 2.6
	vis.mesh = sm
	var m := StandardMaterial3D.new(); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.8, 0.95, 1.0, 0.22); m.emission_enabled = true; m.emission = Color(0.65, 0.85, 1.0)
	m.emission_energy_multiplier = 0.5; m.roughness = 0.0; m.metallic_specular = 1.0; m.rim_enabled = true; m.rim = 1.0
	vis.material_override = m; vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vis)
	_ride = {"to": to, "phase": "up", "t": 0.0, "vis": vis}
	if player.mounted:
		player.dismount()
	Sfx.play("pop", -6.0, 0.3)
	FX.burst(from + Vector3(0, 1, 0), Color(0.8, 0.95, 1.0), 20, 3.0, 0.15, 0.6, 1.0)

func _pop_ride() -> void:
	if _ride.is_empty():
		return
	var vis: Node3D = _ride.vis
	FX.burst(vis.global_position, Color(0.85, 0.95, 1.0), 40, 4.0, 0.15, 0.6, 0.0)
	Sfx.play("pop", -2.0, 0.1)
	vis.queue_free()
	_ride = {}
	_ride_cd = 1.5
	player.lift = -999.0
	player.wind = Vector3.ZERO
	_arrival_done = true

## Arriving from the castle: you float down onto the temple island in a bubble.
func _arrive() -> void:
	_arrival_done = false
	_start_ride("A", player.global_position)
	_ride.phase = "drift"
	Game.say("A giant bubble carries you onto Cloud Island!", Color(0.8, 0.95, 1.0))

# ---------------------------------------------------------------------------
var _strike_t := 2.0
var _bubble_t := 4.0
var _haunt_t := 0.0
const HAUNTS := [
	["thunder_birds", "thunder_bird", [Vector3(-24, 23, 18), Vector3(24, 23, -20), Vector3(-58, 43, -45), Vector3(58, 43, -45)], 4],
	["sky_whale", "storm_sprite", [Vector3(58, 42, -38), Vector3(66, 42, -46), Vector3(52, 42, -52)], 3],
]

func _process(delta: float) -> void:
	if player == null:
		return
	player.kill_y = -40.0
	if not _arrival_done and _ride.is_empty() and player.input_enabled:
		if Game.resume_pos == Vector3.ZERO:
			_arrive()
		else:
			_arrival_done = true
	var pp := player.global_position
	var isl := island_of(pp)
	_set_area("storm" if isl in ["D", "E"] else "sky")
	_haunt(delta)
	_storm_hazards(delta, isl)
	if _boss_started and lord and is_instance_valid(lord) and not lord.dead:
		_boss_hazards(delta)
	elif not _boss_started and lord and is_instance_valid(lord) and not lord.dead and isl == "E":
		_boss_started = true
		Sfx.music("music_boss", -10.0)
		Game.say("Mr. Bubbles: \"Who's that? Do you want to play? ...BUBBLE TIME!\"", Color(1.0, 0.9, 0.4))
	# the rescued whale swims lazy circles over the east island
	if _whale and not _whale_cloud.visible:
		var c: Vector3 = ISLANDS.C.c
		var t := Time.get_ticks_msec() * 0.0003
		_whale.position = c + Vector3(cos(t) * 14.0, 9.0 + sin(t * 2.0), sin(t) * 14.0)
		_whale.rotation.y = -t + PI

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_weight_step(delta)
	_bubble_step(delta)

func _set_area(a: String) -> void:
	if a == area:
		return
	area = a
	area_changed.emit(a)
	var storm := a == "storm"
	env.ambient_light_energy = 0.6 if storm else 0.8
	sun.light_energy = 0.7 if storm else 1.3
	env.fog_light_color = Color(0.45, 0.48, 0.6) if storm else Color(0.7, 0.8, 1.0)
	env.fog_depth_begin = 30.0 if storm else 120.0
	if not _boss_started:
		Sfx.music("music_explore", -15.0)

func _haunt(delta: float) -> void:
	_haunt_t -= delta
	if _haunt_t > 0.0:
		return
	_haunt_t = 7.0
	for h in HAUNTS:
		if Game.quest_state(h[0]) != "active":
			continue
		var alive := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and not e.dead and e.type_id == h[1]:
				alive += 1
		if alive >= int(h[3]):
			continue
		var spots: Array = (h[2] as Array).filter(func(p: Vector3) -> bool: return player.global_position.distance_to(p) > 12.0)
		if spots.is_empty():
			continue
		var at: Vector3 = spots[randi() % spots.size()]
		var g := _enemy(h[1], at, "")
		FX.burst(at + Vector3(0, 1, 0), Color(1.0, 0.95, 0.5), 30, 3.0, 0.3, 0.9, 0.5)

## Lightning on the storm layer: a ring glows, then a bolt hits it.
func _storm_hazards(delta: float, isl: String) -> void:
	if isl != "D":
		return
	_strike_t -= delta
	if _strike_t <= 0.0:
		_strike_t = randf_range(3.0, 5.0)
		var at: Vector3 = player.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		at.y = ISLANDS.D.c.y
		_lightning(at, 3.0, 30.0)

func _boss_hazards(delta: float) -> void:
	_strike_t -= delta
	_bubble_t -= delta
	var c: Vector3 = ISLANDS.E.c
	var angry := lord.hp < lord.max_hp * 0.5
	if _strike_t <= 0.0:
		_strike_t = randf_range(2.2, 3.4) if angry else randf_range(3.2, 4.4)
		for k in (2 if angry else 1):
			var at: Vector3 = player.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			at.y = c.y
			_lightning(at, 3.2, lord.t.dmg * 0.6)
	if _bubble_t <= 0.0:
		_bubble_t = randf_range(4.0, 6.0) if angry else randf_range(6.0, 8.0)
		var from := lord.global_position + Vector3(0, 2.6, 0)
		Sfx.play_at("pop", from, -4.0, 0.3)
		for k in (2 if angry else 1):
			LightningBubble.blow(self, from + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), lord.t.dmg * 0.5)

func _lightning(at: Vector3, radius: float, dmg: float) -> void:
	var mark := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.03
	mark.mesh = cm; var mm := FX.glow_material(Color(1.0, 0.92, 0.3), 0.9); mm.albedo_color.a = 0.35
	mark.material_override = mm
	add_child(mark); mark.global_position = at + Vector3(0, 0.08, 0)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = radius - 0.15; tm.outer_radius = radius
	ring.mesh = tm; ring.material_override = FX.glow_material(Color(1.0, 0.95, 0.4), 3.0)
	add_child(ring); ring.global_position = at + Vector3(0, 0.1, 0); ring.scale = Vector3(1, 0.05, 1)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void:
		mark.queue_free(); ring.queue_free()
		FX.beam(at + Vector3(randf_range(-2, 2), 30.0, randf_range(-2, 2)), at, Color(1.0, 0.97, 0.6), 0.35, 0.35)
		FX.flash_light(at + Vector3(0, 2, 0), Color(1.0, 0.95, 0.6), 10.0, 16.0, 0.3)
		FX.burst(at + Vector3(0, 0.3, 0), Color(1.0, 0.95, 0.5), 50, 6.0, 0.15, 0.5, -4.0)
		Sfx.play_at("thunder", at, -2.0, 0.1)
		if player and not player.dead:
			var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
			if d < radius and absf(player.global_position.y - at.y) < 3.0:
				player.take_damage(dmg, at + Vector3(0, 0.1, 0), 4.0))

# ---------------------------------------------------------------------------
# Quest-driven changes
func _on_quests() -> void:
	for vn in _vent_nodes:
		_vent_look(vn[0], vent_active(vn[1]))
	# the baby sky whale: stuck in a storm cloud until the sprites are cleared
	var freed: bool = Game.quest_state("sky_whale") in ["ready", "done"]
	if _whale_cloud:
		_whale_cloud.visible = not freed
	if _flowers:
		_flowers.visible = Game.flags.get("cl_garden", false)
	# the Hail Golem guards the storm gate once Utu sends you
	if Game.quest_state("storm_gate") == "active" and (warden == null or not is_instance_valid(warden)) and not Game.flags.get("hail_golem", false):
		warden = _enemy("hail_golem", ISLANDS.D.c + Vector3(0, 0, -12), "hail_golem")
		if warden:
			FX.pillar(warden.global_position, Color(0.7, 0.85, 1.0), 2.0, 14.0, 1.4)
			Game.say("The Hail Golem rumbles awake on the storm layer!", Color(0.7, 0.85, 1.0))
	# Mr. Bubbles takes the thunderhead once Anu sends you
	if Game.quest_state("mr_bubbles") == "active" and (lord == null or not is_instance_valid(lord)) and not Game.flags.get("mr_bubbles", false):
		lord = _enemy("mr_bubbles", ISLANDS.E.c + Vector3(0, 2, -6), "mr_bubbles")
		if lord:
			lord.died.connect(func(_e: Enemy) -> void:
				_boss_started = false
				Sfx.music("music_explore", -15.0)
				for lb in get_tree().get_nodes_in_group("damageable"):
					if lb is LightningBubble:
						lb.queue_free()
				_boss_chest()
				Game.say("Mr. Bubbles tumbles onto the cloud... and starts to cry. The storm is over!", Color(1.0, 0.9, 0.5)))
	if Game.flags.get("mr_bubbles", false):
		_boss_chest()
	# Anu's reward: the dragonfly!
	if Game.quest_state("mr_bubbles") == "done" and not Game.flags.get("mount_dragonfly", false):
		if Game.has_method("grant_dragonfly"):
			Game.call("grant_dragonfly")
		else:
			Game.flags["mount_dragonfly"] = true
			Game.say("You got the DRAGONFLY! Press G (or RIDE) to fly.", Color(0.5, 1.0, 0.85))

func _vent_look(v: Node3D, on: bool) -> void:
	for c in v.get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = on
		elif c is OmniLight3D:
			(c as OmniLight3D).light_energy = 1.4 if on else 0.2

func _boss_chest() -> void:
	if Game.flags.get("cl_chest_bubbles", false) or get_node_or_null("BubblesChest") != null:
		return
	var ch := Interactable.create(self, "chest", ISLANDS.E.c + Vector3(4, 0, -10), -20.0, "cl_chest_bubbles", [{"roll": "boss", "ilvl": 12}])
	ch.name = "BubblesChest"

func summon_for(e: Enemy) -> void:
	var foes := ["thunder_bird", "storm_bat", "thunder_bird"] if e.type_id == "mr_bubbles" else ["storm_sprite", "storm_sprite"]
	Game.say("Mr. Bubbles: \"Birdies! Come and play!\"" if e.type_id == "mr_bubbles" else "The Hail Golem roars!", Color(1.0, 0.9, 0.4))
	for k in foes.size():
		var sp := e.global_position + Vector3(-6.0 + k * 6.0, 1.0, 6.0)
		_enemy(foes[k], sp, "")
		FX.burst(sp + Vector3(0, 1, 0), Color(1.0, 0.95, 0.5), 30, 3.0, 0.3, 0.8, 0.5)

func reset_boss() -> void:
	if _boss_started and lord and is_instance_valid(lord) and not lord.dead:
		_boss_started = false
		lord.hp = lord.max_hp
		Sfx.music("music_explore", -15.0)
