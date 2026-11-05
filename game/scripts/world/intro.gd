extends Node3D
class_name IntroMovie
## The opening movie (about 40 seconds), played after you create your hero:
##  1. sunrise over the mountains; Bobek's cabin in the valley; title
##  2. asleep in bed in striped pajamas -> wakes, gets up, big stretch
##  3. opens the wardrobe -> poof! dressed for adventure
##  4. brushes teeth (seen from the mirror)
##  5. the teapot whistles on the stove
##  6. at the table: pours from the teapot into the cup, drops in the tea bag,
##     waits three seconds while it turns brown, stirs, sips
##  7. out the door and a few steps across the yard to the old family portal;
##     stands in it and a beam of light carries him away
## The cameras face the hero so you can see what they're doing. Skippable.

signal finished

const FOREST := "res://assets/kaykit/forest/%s.gltf"
const ROOM := Vector3(400, 0, 0)       # the cabin interior set (filmed separately)

var cam: Camera3D
var actor: CharacterModel
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var skipped := false
var _look_at := Vector3.ZERO
var _ui: CanvasLayer
var _caption: Label
var _title: Label
var _fade: ColorRect
var _scenes := {}
var _noise := FastNoiseLite.new()
var _music: AudioStreamPlayer
var shot := ""                         # current shot name (tests take pictures)

# --- yard layout: the portal is just across the yard from the front door
const CABIN := Vector3(0, 0, 0)
const DOOR := Vector3(1.0, 0, 4.6)
const PORTAL := Vector3(9.0, 0, 15.0)
const PORTAL_YAW := -150.0             # the arch faces the cabin door
const PORTAL_CAM := Vector2(15.7, 12.3)   # where the camera watches the walk from
const INDOOR := 0.72                   # the hero is a little smaller inside so the furniture fits him

func height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 3.0
	var r := Vector2(x, z).length()
	h += pow(maxf(r - 45.0, 0.0), 1.5) * 0.18
	return h * smoothstep(14.0, 30.0, r)

func g(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)

func _model(name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0) -> Node3D:
	var path := FOREST % name
	if not ResourceLoader.exists(path):
		return Props.place(self, name, pos, yaw_deg, scl)
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var n: Node3D = (_scenes[path] as PackedScene).instantiate()
	add_child(n)
	n.position = pos; n.rotation_degrees.y = yaw_deg; n.scale = Vector3.ONE * scl
	return n

func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

# ---------------------------------------------------------------------------
func build() -> void:
	_noise.seed = 3; _noise.frequency = 0.02
	_environment()
	_valley()
	_cabin_interior()
	_yard_portal()
	_actor()
	cam = Camera3D.new(); cam.fov = 50; cam.near = 0.03
	add_child(cam)
	cam.current = true
	_overlay()

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.28, 0.55)
	sky_mat.sky_horizon_color = Color(1.0, 0.58, 0.35)
	sky_mat.ground_horizon_color = Color(0.45, 0.38, 0.3)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.1)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.8, 0.65)
	env.fog_density = 0.0015
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(3, 160, 0)     # behind the eastern peak: rises in shot 1
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

func _valley() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 51; var step := 4.0; var o := -100.0
	var cols := []
	for j in n:
		for i in n:
			var x := o + i * step; var z := o + j * step
			var c := Color(0.36, 0.56, 0.22).lerp(Color(0.5, 0.62, 0.25), _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)
			# the little path from the door to the portal
			var t := clampf(Vector2(x - DOOR.x, z - DOOR.z).dot(Vector2(PORTAL.x - DOOR.x, PORTAL.z - DOOR.z).normalized()), 0.0, 13.0)
			var on := Vector2(DOOR.x, DOOR.z) + Vector2(PORTAL.x - DOOR.x, PORTAL.z - DOOR.z).normalized() * t
			c = c.lerp(Color(0.55, 0.45, 0.3), smoothstep(3.0, 1.2, Vector2(x, z).distance_to(on)))
			cols.append([Vector3(x, height(x, z), z), c if Game.is_compat() else c.srgb_to_linear()])
	for j in n - 1:
		for i in n - 1:
			for v in [cols[j * n + i], cols[j * n + i + 1], cols[(j + 1) * n + i], cols[j * n + i + 1], cols[(j + 1) * n + i + 1], cols[(j + 1) * n + i]]:
				st.set_color(v[1]); st.add_vertex(v[0])
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/terrain.gdshader")
	var nt := NoiseTexture2D.new(); nt.seamless = true; var fn := FastNoiseLite.new(); fn.frequency = 0.02; nt.noise = fn
	sm.set_shader_parameter("detail", nt)
	mi.material_override = sm
	add_child(mi)
	# mountains ring the valley; the sun comes up over the big eastern one
	for k in 12:
		var a := k * TAU / 12.0
		_model(["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees"][k % 3],
			Vector3(cos(a) * 110.0, -8.0, sin(a) * 110.0), k * 47.0, 30.0 + (k % 3) * 4.0)
	_model("mountain_B_grass_trees", Vector3(-70, -8.0, -75), 20.0, 50.0)
	# the cabin, smoke from the chimney, a well, a little garden
	_model("building_home_A_green", g(CABIN.x, CABIN.z) - Vector3(0, 0.2, 0), 0.0, 7.0)
	var smoke := CPUParticles3D.new(); smoke.amount = 30; smoke.lifetime = 5.0; smoke.preprocess = 5.0
	smoke.mesh = FX.quad(1.4); smoke.material_override = _puff_mat(Color(0.92, 0.92, 0.94, 0.4))
	smoke.direction = Vector3(0.3, 1, 0); smoke.spread = 10; smoke.initial_velocity_min = 0.6; smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.2, 0.15, 0); smoke.scale_amount_min = 0.8; smoke.scale_amount_max = 2.2
	add_child(smoke); smoke.position = g(CABIN.x, CABIN.z) + Vector3(1.6, 7.6, -1.0)
	_model("building_well_green", g(-7, 6), 30.0, 4.5)
	for p in [Vector2(-3, 8), Vector2(-4.5, 9.5), Vector2(-2, 10)]:
		_model("pumpkin_orange" if p.x > -4 else "pumpkin_yellow_small", g(p.x, p.y), p.x * 40.0, 1.0)
	_model("fence_wood_straight", g(-9, 2), 0.0, 6.0)
	_model("fence_wood_straight", g(-9, 9), 0.0, 6.0)
	_model("lantern_standing", g(3.5, 6.0), 0.0, 1.0)
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	for k in 110:
		var p := Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
		if p.length() < 13.0 or p.distance_to(Vector2(PORTAL.x, PORTAL.z)) < 9.0 or p.distance_to(Vector2(5, 10)) < 9.0 or p.distance_to(PORTAL_CAM) < 6.0:
			continue
		var nm: String = ["tree_single_A", "tree_single_B", "tree_pine_yellow_large", "tree_pine_orange_medium"][rng.randi() % 4]
		_model(nm, g(p.x, p.y) - Vector3(0, 0.2, 0), rng.randf() * 360.0, 6.5 if nm.begins_with("tree_single") else 1.1)
	var birds := Node3D.new(); add_child(birds); birds.position = g(0, 8)
	Sfx.loop_on(birds, "loop_birds", -8.0, 30.0, 200.0)

# --- the yard portal ------------------------------------------------------------
var _portal_mat: ShaderMaterial
var _portal_light: OmniLight3D

func _yard_portal() -> void:
	var c := g(PORTAL.x, PORTAL.z)
	var arch := _model("arch_gate", c - Vector3(0, 0.1, 0), PORTAL_YAW, 1.5)
	for side in ["arch_gate_left", "arch_gate_right"]:     # no iron gates: an open archway
		var gate := arch.find_child(side, true, false)
		if gate:
			gate.visible = false
	for k in 5:
		var a := deg_to_rad(PORTAL_YAW) + PI * 0.5 + (k - 2) * 0.45
		_model("rock_single_" + ["A", "C", "E", "B", "D"][k], c + Vector3(sin(a), 0, cos(a)) * 4.0 - Vector3(0, 0.2, 0), k * 50.0, 4.5)
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2); disc.mesh = q
	_portal_mat = ShaderMaterial.new(); _portal_mat.shader = load("res://shaders/portal.gdshader")
	_portal_mat.set_shader_parameter("intensity", 1.0)
	disc.material_override = _portal_mat
	add_child(disc)
	disc.position = c + Vector3(0, 3.0, 0); disc.rotation_degrees.y = PORTAL_YAW
	_portal_light = OmniLight3D.new(); _portal_light.light_color = Color(0.4, 1.0, 0.8); _portal_light.light_energy = 1.5
	_portal_light.omni_range = 10.0; add_child(_portal_light); _portal_light.position = c + Vector3(0, 2.5, 0)

# --- the cabin interior set ------------------------------------------------------
var _bed: Vector3 = Vector3(-3.4, 0, -2.0)        # bed centre (head end towards -z)
var _wardrobe: Vector3 = Vector3(3.6, 0, -3.3)
var _basin: Vector3 = Vector3(-4.4, 0, 1.6)
var _stove: Vector3 = Vector3(4.2, 0, 1.6)
var _table: Vector3 = Vector3(0.6, 0, -0.2)
var _stool: Vector3 = Vector3(0.6, 0, 0.75)
var _kettle_steam: CPUParticles3D
var _teapot: Node3D
var _teapot_home: Transform3D
var _cup: Node3D
var _tea: MeshInstance3D
var _tea_mat: StandardMaterial3D
var _cup_steam: CPUParticles3D
var _stream: MeshInstance3D
var _teabag: Node3D
var _spoon: MeshInstance3D

func _box(a: Vector3, b2: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = (b2 - a).abs()
	mi.mesh = bm; mi.material_override = m; mi.position = (a + b2) * 0.5
	if parent:
		parent.add_child(mi)
	else:
		mi.position += ROOM
		add_child(mi)
	return mi

func _cabin_interior() -> void:
	var floor_m := _mat(Color(0.48, 0.32, 0.19)); var wall_m := _mat(Color(0.6, 0.42, 0.25))
	var dark := _mat(Color(0.32, 0.21, 0.12))
	_box(Vector3(-5, -0.2, -4), Vector3(5, 0, 4), floor_m)
	for k in 9:
		_box(Vector3(-5, 0.001, -4 + k * 1.0 - 0.02), Vector3(5, 0.004, -4 + k * 1.0 + 0.02), dark)   # floorboards
	_box(Vector3(-5, 0, -4.2), Vector3(5, 4, -4), wall_m)
	_box(Vector3(-5.2, 0, -4), Vector3(-5, 4, 4), wall_m)
	_box(Vector3(5, 0, -4), Vector3(5.2, 4, 4), wall_m)
	_box(Vector3(-5, 0, 4), Vector3(5, 4, 4.2), wall_m)
	_box(Vector3(-5, 4, -4), Vector3(5, 4.2, 4), dark)
	for x in [-3.0, 0.0, 3.0]:
		_box(Vector3(x - 0.15, 3.6, -4), Vector3(x + 0.15, 3.9, 4), dark)
	# window and morning sunbeam
	var win := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.6, 1.2); win.mesh = q
	win.material_override = FX.glow_material(Color(1.0, 0.86, 0.62), 1.8)
	win.position = ROOM + Vector3(-1.0, 2.3, -3.98); add_child(win)
	_box(Vector3(-1.85, 1.65, -3.98), Vector3(-0.15, 1.73, -3.9), dark)
	_box(Vector3(-1.05, 1.7, -3.98), Vector3(-0.95, 2.9, -3.9), dark)
	var beam := SpotLight3D.new(); beam.light_color = Color(1.0, 0.82, 0.58); beam.light_energy = 8.0
	beam.spot_range = 9.0; beam.spot_angle = 32.0; beam.shadow_enabled = true
	add_child(beam); beam.position = ROOM + Vector3(-1.0, 2.6, -3.6); beam.look_at(ROOM + Vector3(-3.0, 0.3, -1.0))
	var fill := OmniLight3D.new(); fill.light_color = Color(1.0, 0.85, 0.65); fill.light_energy = 1.6; fill.omni_range = 11.0
	add_child(fill); fill.position = ROOM + Vector3(0.5, 3.2, 1.5)
	# bed: frame, mattress, pillow, patchwork blanket
	_box(_bed + Vector3(-0.9, 0, -1.4), _bed + Vector3(0.9, 0.42, 1.4), dark)
	_box(_bed + Vector3(-0.85, 0.42, -1.35), _bed + Vector3(0.85, 0.58, 1.35), _mat(Color(0.94, 0.92, 0.86)))
	_box(_bed + Vector3(-0.87, 0.56, -0.25), _bed + Vector3(0.87, 0.64, 1.37), _mat(Color(0.75, 0.3, 0.25)))
	_box(_bed + Vector3(-0.55, 0.58, -1.3), _bed + Vector3(0.55, 0.76, -0.85), _mat(Color(0.98, 0.97, 0.95)))
	_box(_bed + Vector3(-0.9, 0, -1.5), _bed + Vector3(0.9, 1.25, -1.36), dark)
	# wardrobe
	_box(_wardrobe + Vector3(-0.9, 0, -0.6), _wardrobe + Vector3(0.9, 2.6, 0.5), dark)
	_box(_wardrobe + Vector3(-0.85, 0.15, 0.5), _wardrobe + Vector3(-0.03, 2.45, 0.54), _mat(Color(0.42, 0.27, 0.15)))
	_box(_wardrobe + Vector3(0.03, 0.15, 0.5), _wardrobe + Vector3(0.85, 2.45, 0.54), _mat(Color(0.42, 0.27, 0.15)))
	# wash stand with basin and a mirror on the wall
	_box(_basin + Vector3(-0.4, 0, -0.5), _basin + Vector3(0.4, 0.9, 0.5), dark)
	var bowl := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.34; cy.bottom_radius = 0.24; cy.height = 0.18
	bowl.mesh = cy; bowl.material_override = _mat(Color(0.85, 0.88, 0.92), 0.3); bowl.position = ROOM + _basin + Vector3(0, 0.99, 0)
	add_child(bowl)
	_box(_basin + Vector3(-0.58, 1.15, -0.42), _basin + Vector3(-0.55, 2.05, 0.42), dark)
	var mirror := MeshInstance3D.new(); var mq := QuadMesh.new(); mq.size = Vector2(0.72, 0.8); mirror.mesh = mq
	mirror.material_override = _mat(Color(0.75, 0.86, 0.92), 0.05, 1.0)
	mirror.position = ROOM + _basin + Vector3(-0.54, 1.6, 0); mirror.rotation.y = PI / 2
	add_child(mirror)
	# stove with the teapot
	_box(_stove + Vector3(-0.6, 0, -0.6), _stove + Vector3(0.6, 1.0, 0.6), _mat(Color(0.18, 0.17, 0.17), 0.6, 0.4))
	_box(_stove + Vector3(0.15, 1.0, -0.15), _stove + Vector3(0.45, 4.0, 0.15), _mat(Color(0.18, 0.17, 0.17), 0.6, 0.4))
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.5, 0.2); glow.light_energy = 1.5; glow.omni_range = 4.0
	glow.set_script(load("res://scripts/world/flicker.gd")); add_child(glow); glow.position = ROOM + _stove + Vector3(-0.7, 0.5, 0)
	_teapot = _make_teapot()
	_teapot.position = ROOM + _stove + Vector3(-0.2, 1.0, 0)
	_teapot.rotation.y = 0.35                      # spout side-on to the camera
	_kettle_steam = _steam(Vector3.ZERO, 0.14, 40, _teapot)
	_kettle_steam.position = SPOUT_TIP + Vector3(0, 0.02, 0.01)
	_kettle_steam.direction = Vector3(0, 1, 0.5)
	_kettle_steam.initial_velocity_min = 0.6; _kettle_steam.initial_velocity_max = 1.0
	_kettle_steam.emitting = false
	_kit("pan_A", ROOM + _stove + Vector3(0.0, 1.0, -0.38), 90.0, 0.32)
	# kitchen shelf by the stove: jars, plates and a cutting board (KayKit Restaurant Bits)
	_box(Vector3(2.3, 1.35, -3.98), Vector3(4.4, 1.41, -3.6), dark)
	_kit("jar_A_medium", ROOM + Vector3(2.55, 1.41, -3.78), 0.0, 0.42)
	_kit("jar_C_large", ROOM + Vector3(2.9, 1.41, -3.78), 0.0, 0.38)
	_kit("jar_B_small", ROOM + Vector3(3.2, 1.41, -3.78), 0.0, 0.45)
	_kit("jar_D_medium", ROOM + Vector3(3.5, 1.41, -3.78), 0.0, 0.4)
	_kit("dishrack_plates", ROOM + Vector3(4.0, 1.41, -3.78), 0.0, 0.35)
	_box(Vector3(4.2, 0, -1.2), Vector3(4.95, 0.9, 0.4), dark)               # counter beside the stove
	_kit("cuttingboard", ROOM + Vector3(4.55, 0.9, -0.5), 90.0, 0.4)
	_kit("food_ingredient_bun", ROOM + Vector3(4.55, 0.93, -0.55), 0.0, 0.35)
	_kit("crate_carrots", ROOM + Vector3(4.4, 0.0, 2.9), 20.0, 0.45)
	_kit("crate_potatoes", ROOM + Vector3(3.6, 0.0, 3.3), -10.0, 0.45)
	# a round table set for breakfast
	_kit("table_round_A_small", ROOM + _table, 0.0, 0.8)
	Props.place(self, "stool", ROOM + _stool, 0.0, 1.0)
	Props.place(self, "candle_triple", ROOM + _table + Vector3(-0.32, 0.8, -0.32), 0.0, 0.45)
	_kit("plate", ROOM + _table + Vector3(0.3, 0.8, -0.05), 0.0, 0.28)
	_kit("food_ingredient_bun", ROOM + _table + Vector3(0.27, 0.83, -0.08), 30.0, 0.3)
	_kit("food_ingredient_cheese", ROOM + _table + Vector3(0.36, 0.83, 0.0), 0.0, 0.25)
	# the cup on its saucer
	_kit("plate_small", ROOM + _table + Vector3(-0.02, 0.8, 0.14), 0.0, 0.3)
	_cup = Node3D.new(); add_child(_cup); _cup.position = ROOM + _table + Vector3(-0.02, 0.815, 0.14)
	var china := _mat(Color(0.97, 0.96, 0.93), 0.15)
	china.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blue := _mat(Color(0.2, 0.36, 0.72), 0.25)
	_cup.add_child(_lathe([Vector2(0, 0.012), Vector2(0.038, 0.012), Vector2(0.042, 0), Vector2(0.05, 0.004), Vector2(0.058, 0.03),
		Vector2(0.068, 0.07), Vector2(0.075, 0.1), Vector2(0.078, 0.112), Vector2(0.074, 0.114), Vector2(0.068, 0.104),
		Vector2(0.062, 0.07), Vector2(0.052, 0.03), Vector2(0.0, 0.02)], china))
	_cup.add_child(_lathe([Vector2(0.0768, 0.093), Vector2(0.0775, 0.1), Vector2(0.0768, 0.106)], blue))
	_cup.add_child(_tube(Vector3(0.062, 0.088, 0), Vector3(0.125, 0.085, 0), Vector3(0.06, 0.035, 0), 0.009, 0.008, china))
	_tea = MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.066; tc.bottom_radius = 0.066; tc.height = 0.004
	_tea.mesh = tc; _tea_mat = _mat(Color(0.72, 0.8, 0.84), 0.05); _tea.material_override = _tea_mat
	_tea.position.y = 0.03; _tea.scale = Vector3(0.8, 1, 0.8); _tea.visible = false; _cup.add_child(_tea)
	_cup_steam = _steam(Vector3.ZERO, 0.05, 14, _cup); _cup_steam.position.y = 0.12; _cup_steam.emitting = false
	_cup_steam.initial_velocity_min = 0.08; _cup_steam.initial_velocity_max = 0.18
	_teabag = Node3D.new(); add_child(_teabag)
	var tb := MeshInstance3D.new(); var tbm := BoxMesh.new(); tbm.size = Vector3(0.05, 0.06, 0.012)
	tb.mesh = tbm; tb.material_override = _mat(Color(0.93, 0.88, 0.75)); _teabag.add_child(tb)
	var tag := MeshInstance3D.new(); var tgm := BoxMesh.new(); tgm.size = Vector3(0.03, 0.03, 0.004)
	tag.mesh = tgm; tag.material_override = _mat(Color(0.85, 0.2, 0.2)); tag.position = Vector3(0.09, 0.1, 0); _teabag.add_child(tag)
	var string := MeshInstance3D.new(); var sgm := BoxMesh.new(); sgm.size = Vector3(0.0025, 0.11, 0.0025)
	string.mesh = sgm; string.material_override = _mat(Color(0.95, 0.95, 0.95)); string.position = Vector3(0.045, 0.065, 0); string.rotation.z = -0.95
	_teabag.add_child(string)
	_teabag.position = ROOM + _table + Vector3(0.14, 0.81, 0.3)
	_teabag.rotation = Vector3(-PI / 2, 0, 0.3)
	_spoon = MeshInstance3D.new()
	var sp := Node3D.new()
	var shaft := MeshInstance3D.new(); var shm := CylinderMesh.new(); shm.top_radius = 0.004; shm.bottom_radius = 0.006; shm.height = 0.13
	shaft.mesh = shm; shaft.material_override = _mat(Color(0.85, 0.85, 0.88), 0.15, 1.0); shaft.position.y = 0.065; sp.add_child(shaft)
	var bowl2 := MeshInstance3D.new(); var bsm := SphereMesh.new(); bsm.radius = 0.014; bsm.height = 0.012
	bowl2.mesh = bsm; bowl2.material_override = shaft.material_override; bowl2.scale = Vector3(1, 1, 1.5); sp.add_child(bowl2)
	_spoon.add_child(sp)
	add_child(_spoon); _spoon.position = ROOM + _table + Vector3(-0.17, 0.805, 0.22); _spoon.rotation = Vector3(PI / 2, 0, 0.5)
	# the pouring water
	_stream = MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.013; sc.bottom_radius = 0.017; sc.height = 1.0
	_stream.mesh = sc
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.62, 0.78, 0.95, 0.85); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	_stream.material_override = wm; _stream.visible = false; add_child(_stream)
	Props.place(self, "shelf_small_candles", ROOM + Vector3(1.8, 1.6, -3.9), 0.0, 1.0)
	Props.place(self, "barrel_small", ROOM + Vector3(-4.3, 0, -0.1), 0.0, 1.0)
	Props.place(self, "shelves", ROOM + Vector3(1.6, 0, 3.8), 180.0, 1.0)

const SPOUT_TIP := Vector3(0, 0.27, 0.33)      # teapot-local, the spout points along +Z

## A smooth shape turned on a lathe: `profile` is (radius, height) pairs.
func _lathe(profile: Array, mat: Material, segs := 28) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]; var p1: Vector2 = profile[i + 1]
		for k in segs:
			var a0 := TAU * k / segs; var a1 := TAU * (k + 1) / segs
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x); var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x); var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			for v in [v00, v10, v11, v00, v11, v01]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	return mi

## A tube along a quadratic curve (spouts, handles), radius r0 -> r1.
func _tube(p0: Vector3, p1: Vector3, p2: Vector3, r0: float, r1: float, mat: Material, steps := 12, segs := 14) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in steps + 1:
		var t := float(i) / steps
		var c := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var tan := (p1 - p0).lerp(p2 - p1, t).normalized()
		var side := tan.cross(Vector3.RIGHT if absf(tan.x) < 0.9 else Vector3.UP).normalized()
		var up := side.cross(tan).normalized()
		var r := lerpf(r0, r1, t)
		var ring := []
		for k in segs:
			var a := TAU * k / segs
			ring.append(c + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)
	for i in steps:
		for k in segs:
			var a: Vector3 = rings[i][k]; var b2: Vector3 = rings[i][(k + 1) % segs]
			var c2: Vector3 = rings[i + 1][k]; var d2: Vector3 = rings[i + 1][(k + 1) % segs]
			for v in [a, c2, d2, a, d2, b2]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	(mi.material_override as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return mi

var _lid: Node3D

## A china teapot: round turned body, lid with a knob, curved spout, loop handle.
func _make_teapot() -> Node3D:
	var tp := Node3D.new(); add_child(tp)
	var china := _mat(Color(0.95, 0.95, 0.97), 0.18)
	var blue := _mat(Color(0.2, 0.36, 0.72), 0.25)
	tp.add_child(_lathe([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.11, 0.012), Vector2(0.15, 0.04), Vector2(0.178, 0.1),
		Vector2(0.176, 0.16), Vector2(0.15, 0.215), Vector2(0.105, 0.248), Vector2(0.09, 0.25), Vector2(0.0, 0.25)], china))
	var band := _lathe([Vector2(0.179, 0.115), Vector2(0.18, 0.13), Vector2(0.179, 0.145)], blue)
	tp.add_child(band)
	_lid = Node3D.new(); tp.add_child(_lid); _lid.position.y = 0.245
	_lid.add_child(_lathe([Vector2(0.098, 0), Vector2(0.096, 0.012), Vector2(0.075, 0.035), Vector2(0.03, 0.048),
		Vector2(0.018, 0.05), Vector2(0.026, 0.065), Vector2(0.022, 0.08), Vector2(0, 0.084)], blue))
	tp.add_child(_tube(Vector3(0, 0.085, 0.15), Vector3(0, 0.1, 0.29), SPOUT_TIP, 0.042, 0.017, china))
	tp.add_child(_tube(Vector3(0, 0.2, -0.13), Vector3(0, 0.22, -0.3), Vector3(0, 0.05, -0.16), 0.02, 0.018, blue))
	return tp

## Soft round puff texture for steam and smoke (instead of hard squares).
var _puff_tex: GradientTexture2D
func _puff_mat(c: Color) -> StandardMaterial3D:
	if _puff_tex == null:
		_puff_tex = GradientTexture2D.new(); _puff_tex.width = 64; _puff_tex.height = 64
		_puff_tex.fill = GradientTexture2D.FILL_RADIAL
		_puff_tex.fill_from = Vector2(0.5, 0.5); _puff_tex.fill_to = Vector2(0.5, 0.0)
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_puff_tex.gradient = gr
	var m := StandardMaterial3D.new(); m.albedo_texture = _puff_tex; m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD      # steam only ever lightens (no dark fringes)
	return m

func _kit(name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0) -> Node3D:
	var path := "res://assets/kaykit/kitchen/%s.gltf" % name
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var n: Node3D = (_scenes[path] as PackedScene).instantiate()
	add_child(n)
	n.position = pos; n.rotation_degrees.y = yaw_deg; n.scale = Vector3.ONE * scl
	return n

func _steam(at: Vector3, size := 0.16, amount := 30, parent: Node = null) -> CPUParticles3D:
	var p := CPUParticles3D.new(); p.amount = amount; p.lifetime = 1.8
	p.mesh = FX.quad(size); p.material_override = _puff_mat(Color(0.75, 0.75, 0.78, 0.6))
	p.direction = Vector3.UP; p.spread = 10; p.initial_velocity_min = 0.25; p.initial_velocity_max = 0.5
	p.gravity = Vector3(0.03, 0.12, 0); p.scale_amount_min = 0.6; p.scale_amount_max = 1.2
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 1.8)); p.scale_amount_curve = sc
	var cr := Gradient.new()
	cr.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	cr.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	p.color_ramp = cr
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(p); p.position = at
	return p

func _actor() -> void:
	actor = CharacterModel.new()
	add_child(actor)
	_dress(true)
	actor.grounded = true

## Striped pajamas first, then the real adventuring outfit.
func _dress(pajamas: bool) -> void:
	var p := Game.profile
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": false if pajamas else p.show_hat, "scale": 1.0}
	if pajamas:
		cfg["outfit_color"] = Color(0.45, 0.6, 0.95)
		cfg["outfit_stripes"] = Color(0.95, 0.95, 1.0)
		cfg["cape_color"] = Color(0.45, 0.6, 0.95)
	elif p.cape > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
		cfg["outfit_color"] = Game.CAPE_COLORS[p.cape]
	Player._apply_profile_looks(cfg)
	var hold := actor.hold_clip
	actor.setup(cfg)
	actor.hold_clip = hold

# --- overlay: letterbox, captions, title, skip -------------------------------------
func _overlay() -> void:
	_ui = CanvasLayer.new(); _ui.layer = 20; add_child(_ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	_ui.add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new(); bar.color = Color.BLACK; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0; bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0; bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -88.0; bar.offset_bottom = 88.0 if top else 0.0
		root.add_child(bar)
	_caption = UIKit.label("", 30, Color(1.0, 0.95, 0.85), true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.anchor_left = 0.0; _caption.anchor_right = 1.0; _caption.anchor_top = 1.0; _caption.anchor_bottom = 1.0
	_caption.offset_top = -76; _caption.offset_bottom = -16
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(_caption)
	_title = UIKit.label("BOBEK'S ADVENTURE", 84, UIKit.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.offset_left = -700; _title.offset_right = 700; _title.offset_top = -190; _title.offset_bottom = -80
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0, 0.9))
	_title.modulate.a = 0.0
	root.add_child(_title)
	_fade = ColorRect.new(); _fade.color = Color(0, 0, 0, 1); _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(_fade)
	var skip := Button.new(); skip.text = "Skip intro  >>"
	skip.custom_minimum_size = Vector2(230, 56)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -260; skip.offset_right = -24; skip.offset_top = 16; skip.offset_bottom = 72
	skip.pressed.connect(func() -> void: skip_now())
	root.add_child(skip)

func skip_now() -> void:
	if skipped:
		return
	skipped = true
	_end()

func _say(t: String) -> void:
	_caption.text = t
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _fade_to(a: float, t: float) -> void:
	var tw := create_tween(); tw.tween_property(_fade, "color:a", a, t)
	await tw.finished

## A film cut: quick dip to black while things are moved into place.
func _cut() -> void:
	await _fade_to(1.0, 0.2)

func _open() -> void:
	_fade_to(0.0, 0.25)

var _cam_tw: Tween
func _cam(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, dur: float, fov := 50.0) -> void:
	if _cam_tw and _cam_tw.is_valid():
		_cam_tw.kill()           # a new shot replaces the old camera move
	cam.position = from; _look_at = look_from; cam.fov = fov
	var tw := create_tween()
	_cam_tw = tw.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", to, dur)
	tw.tween_property(self, "_look_at", look_to, dur)
	cam.look_at(_look_at)

func _process(_d: float) -> void:
	if cam:
		cam.look_at(_look_at)

func _walk(to: Vector3, speed := 1.6) -> void:
	var from := actor.position
	var d := Vector3(to.x - from.x, 0, to.z - from.z)
	if d.length() < 0.05:
		return
	actor.rotation.y = atan2(-d.x, -d.z)
	actor.move_speed = speed
	var tw := create_tween(); tw.tween_property(actor, "position", to, d.length() / speed)
	await tw.finished
	actor.move_speed = 0.0

func _turn(yaw: float, t := 0.3) -> void:
	create_tween().tween_property(actor, "rotation:y", yaw, t)

func _yaw_to(p: Vector3) -> float:
	var d := p - actor.position
	return atan2(-d.x, -d.z)

## A toothbrush held at the mouth (it follows the head as he brushes), with foam.
func _toothbrush(foam: Array) -> Node3D:
	var head: MeshInstance3D = null
	for m in actor.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with("_Head") and (m as MeshInstance3D).visible:
			head = m
	var mouth := actor.position + Vector3(-0.32, 1.12, 0)
	if head:
		var ab: AABB = head.global_transform * head.get_aabb()
		mouth = Vector3(ab.position.x + 0.03, ab.position.y + ab.size.y * 0.2, ab.get_center().z)
	var att := actor._attach("head")
	var root := Node3D.new()
	if att:
		att.add_child(root)
	else:
		add_child(root)
	# handle runs out to his right hand (world -Z while he faces the mirror) and down
	var along := Vector3(-0.45, -0.7, -0.55).normalized()
	var up := Vector3(0, 1, 0)
	var side := along.cross(up).normalized()
	root.global_transform = Transform3D(Basis(along, side.cross(along), side), mouth)
	var scrub := Node3D.new(); root.add_child(scrub)
	var handle := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.26, 0.028, 0.03)
	handle.mesh = hb; handle.material_override = _mat(Color(0.2, 0.55, 1.0), 0.3); handle.position.x = 0.15; scrub.add_child(handle)
	var neck := MeshInstance3D.new(); var nb := BoxMesh.new(); nb.size = Vector3(0.05, 0.02, 0.022)
	neck.mesh = nb; neck.material_override = handle.material_override; neck.position.x = 0.01; scrub.add_child(neck)
	var bristle := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.05, 0.03, 0.03)
	bristle.mesh = bb; bristle.material_override = _mat(Color(1, 1, 1), 0.6); bristle.position = Vector3(-0.005, 0.0, 0.0); scrub.add_child(bristle)
	var tipm := MeshInstance3D.new(); var tb2 := BoxMesh.new(); tb2.size = Vector3(0.05, 0.012, 0.032)
	tipm.mesh = tb2; tipm.material_override = _mat(Color(0.3, 0.85, 0.9), 0.6); tipm.position = Vector3(-0.005, 0.018, 0.0); scrub.add_child(tipm)
	# toothpaste foam round the mouth
	var fm := _mat(Color(1, 1, 1), 0.5)
	for k in 7:
		var f := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.016 + (k % 3) * 0.006; sm.height = sm.radius * 2.0
		f.mesh = sm; f.material_override = fm
		root.add_child(f)
		f.global_position = mouth + Vector3(-0.01, -0.015 + (k % 2) * 0.03, -0.07 + k * 0.022)
		f.scale = Vector3.ONE * 0.01
		foam.append(f)
	return root

# ---------------------------------------------------------------------------
func play() -> void:
	_t0 = Time.get_ticks_msec()
	_music = AudioStreamPlayer.new(); _music.stream = Sfx.get_stream("music_morning"); _music.volume_db = -14.0
	add_child(_music); _music.play()
	var nm: String = Game.profile.name
	var R := ROOM

	# 1. sunrise over the eastern mountain, down onto the cabin
	shot = "sunrise"
	actor.visible = false
	_cam(g(-14, 34) + Vector3(0, 9, 0), g(-9, 22) + Vector3(0, 5, 0), Vector3(-60, 30, -80), g(0, 0) + Vector3(0, 3, 0), 6.0)
	create_tween().tween_property(sun, "rotation_degrees:x", -28.0, 6.0)
	var stw := create_tween().set_parallel(true)
	stw.tween_property(sky_mat, "sky_horizon_color", Color(1.0, 0.84, 0.64), 6.0)
	stw.tween_property(sky_mat, "sky_top_color", Color(0.32, 0.56, 0.9), 6.0)
	await _fade_to(0.0, 1.0)
	create_tween().tween_property(_title, "modulate:a", 1.0, 1.0)
	await _wait(2.8)
	if skipped: return
	create_tween().tween_property(_title, "modulate:a", 0.0, 0.8)
	_say("The sun comes up over a little cabin in a quiet valley...")
	await _wait(2.2)
	if skipped: return

	# 2. asleep in bed, striped pajamas -> wakes, gets up, stretches
	shot = "bed"
	await _cut()
	actor.visible = true
	actor.scale = Vector3.ONE * INDOOR
	actor.position = R + _bed + Vector3(0, 0.58, -0.45)
	actor.rotation.y = PI
	actor.hold_clip = "Lie_Idle"
	_cam(R + _bed + Vector3(1.9, 1.5, 2.3), R + _bed + Vector3(1.6, 1.3, 1.9), R + _bed + Vector3(0, 0.7, -0.4), R + _bed + Vector3(0, 0.8, -0.3), 4.5, 45.0)
	_open()
	_say("Zzz...")
	await _wait(1.6)
	if skipped: return
	_say("Rise and shine, %s!" % nm)
	actor.hold_clip = ""
	actor.oneshot("Lie_StandUp", 1.6)
	await _wait(1.5)
	if skipped: return
	actor.position = R + _bed + Vector3(1.35, 0, 0.5)
	actor.rotation.y = _yaw_to(R + _bed + Vector3(3.5, 0, 3.0))
	_cam(R + _bed + Vector3(3.2, 1.4, 3.0), R + _bed + Vector3(3.0, 1.3, 2.7), R + _bed + Vector3(1.35, 0.85, 0.5), R + _bed + Vector3(1.35, 0.95, 0.5), 2.0, 45.0)
	actor.oneshot("Cheer", 1.5)                 # a big morning stretch
	_say("Stretch!")
	await _wait(1.5)
	if skipped: return

	# 3. wardrobe -> poof, dressed for adventure
	shot = "dress"
	await _cut()
	actor.position = R + _wardrobe + Vector3(-0.3, 0, 1.25)
	actor.rotation.y = 0.0
	_cam(R + _wardrobe + Vector3(-1.7, 1.45, 4.3), R + _wardrobe + Vector3(-1.4, 1.4, 4.0), R + _wardrobe + Vector3(-0.2, 1.0, 1.0), R + _wardrobe + Vector3(-0.3, 1.0, 1.25), 2.6, 48.0)
	_open()
	actor.oneshot("Interact", 0.8)
	_say("What to wear today...?")
	await _wait(0.9)
	_turn(_yaw_to(cam.position))
	await _wait(0.3)
	FX.burst(R + _wardrobe + Vector3(-0.3, 1.0, 1.25), Color(1.0, 0.95, 0.7), 50, 2.5, 0.1, 0.7, 0.0)
	Sfx.play("pickup", -6.0)
	_dress(false)
	actor.oneshot("Cheer", 1.2)
	_say("Ready for adventure!")
	await _wait(1.3)
	if skipped: return

	# 4. brush teeth, seen from the mirror
	shot = "teeth"
	await _cut()
	actor.position = R + _basin + Vector3(1.45, 0, 0)
	actor.rotation.y = PI / 2                    # facing the mirror (-x)
	var mirror_eye := R + _basin + Vector3(-0.4, 1.6, 0.12)
	_cam(mirror_eye, mirror_eye + Vector3(0.04, -0.03, -0.08), R + _basin + Vector3(1.45, 1.3, 0), R + _basin + Vector3(1.45, 1.28, 0), 3.0, 52.0)
	_open()
	await _wait(0.05)
	var foam: Array = []
	var brush := _toothbrush(foam)
	var scrub: Node3D = brush.get_child(0) if brush else null
	var bubbles := CPUParticles3D.new(); bubbles.amount = 14; bubbles.lifetime = 0.7
	bubbles.mesh = FX.quad(0.035); bubbles.material_override = _puff_mat(Color(1, 1, 1, 0.95))
	bubbles.direction = Vector3(-1, 0.4, 0); bubbles.spread = 60; bubbles.initial_velocity_min = 0.15; bubbles.initial_velocity_max = 0.4
	bubbles.gravity = Vector3(0, -0.8, 0)
	add_child(bubbles); bubbles.global_position = brush.global_position if brush else actor.position + Vector3(-0.3, 1.1, 0)
	_say("Brush, brush, brush...")
	Sfx.play("brush", -4.0)
	actor.oneshot("Use_Item", 2.4)
	if scrub:
		var sw := create_tween().set_loops(12)
		sw.tween_property(scrub, "position:x", 0.03, 0.1)
		sw.tween_property(scrub, "position:x", -0.03, 0.1)
	for f in foam:
		create_tween().tween_property(f, "scale", Vector3.ONE, 1.4).set_delay(randf() * 0.6)
	await _wait(2.4)
	if skipped: return
	bubbles.emitting = false
	if brush:
		brush.queue_free()
	FX.burst(actor.position + Vector3(-0.35, 1.18, 0), Color(1, 1, 1), 12, 1.2, 0.04, 0.5, 0.0)
	actor.oneshot("Cheer", 0.9)
	_say("Sparkling clean!")
	await _wait(0.9)
	if skipped: return

	# 5. the teapot boils and whistles on the stove
	shot = "kettle"
	await _cut()
	actor.visible = false
	_cam(R + _stove + Vector3(-1.25, 1.45, 0.75), R + _stove + Vector3(-1.0, 1.35, 0.6), _teapot.position + Vector3(0, 0.2, 0.05), _teapot.position + Vector3(0, 0.22, 0.05), 2.8, 34.0)
	_open()
	Sfx.play("kettle", -3.0, 0.0)
	_say("Bubble, bubble...")
	_kettle_steam.emitting = true
	_kettle_steam.amount = 16
	var rattle := create_tween().set_loops(10)
	rattle.tween_property(_lid, "position:y", 0.258, 0.07)
	rattle.tween_property(_lid, "position:y", 0.245, 0.07)
	await _wait(1.0)
	_kettle_steam.amount = 60
	_kettle_steam.initial_velocity_max = 1.6
	_say("Tweeeeee! The water's ready.")
	await _wait(1.8)
	if skipped: return

	# 6. tea at the table: pour, tea bag, steep three seconds, stir, sip
	shot = "tea"
	await _cut()
	_kettle_steam.emitting = false
	_kettle_steam.visible = false
	actor.visible = true
	actor.position = R + _stool
	actor.rotation.y = 0.0                        # facing the table (-z)
	actor.hold_clip = "Sit_Chair_Idle"
	_teapot.scale = Vector3.ONE * 0.7
	_teapot.position = R + _table + Vector3(-0.32, 0.8, 0.05)
	_teapot.rotation = Vector3(0, PI / 2 + 0.3, 0)
	var cup_top := _cup.position + Vector3(0, 0.11, 0)
	# close on the cup: teapot tips, water runs from the spout
	_cam(cup_top + Vector3(0.12, 0.42, -0.62), cup_top + Vector3(0.08, 0.38, -0.55), cup_top + Vector3(-0.08, 0.04, 0), cup_top + Vector3(-0.03, 0.0, 0), 4.5, 42.0)
	_open()
	_say("Time for a nice cup of tea.")
	var pour := create_tween().set_parallel(true)
	pour.tween_property(_teapot, "position", _cup.position + Vector3(-0.3, 0.3, 0.0), 0.6)
	pour.tween_property(_teapot, "rotation", Vector3(0.78, PI / 2, 0), 0.6)
	await _wait(0.65)
	if skipped: return
	_stream.visible = true
	var tip: Vector3 = _teapot.global_transform * SPOUT_TIP
	var down := cup_top - Vector3(0, 0.06, 0) - tip
	var yax := down.normalized()
	var xax := yax.cross(Vector3.FORWARD).normalized()
	_stream.global_transform = Transform3D(Basis(xax, yax * down.length(), xax.cross(yax)), tip + down * 0.5)
	_tea.visible = true
	Sfx.play("pour", -4.0, 0.0)
	var fill := create_tween().set_parallel(true)
	fill.tween_property(_tea, "position:y", 0.098, 1.2)
	fill.tween_property(_tea, "scale", Vector3(1.0, 1, 1.0), 1.2)
	_say("Pour...")
	await _wait(1.2)
	_stream.visible = false
	var back := create_tween().set_parallel(true)
	back.tween_property(_teapot, "position", R + _table + Vector3(-0.32, 0.8, 0.05), 0.5)
	back.tween_property(_teapot, "rotation", Vector3(0, PI / 2 + 0.3, 0), 0.5)
	_cup_steam.emitting = true
	# in goes the tea bag: count to three while it turns brown
	var drop := create_tween()
	drop.tween_property(_teabag, "position", cup_top + Vector3(0, 0.1, 0), 0.35)
	drop.parallel().tween_property(_teabag, "rotation", Vector3(0, 0.4, 0), 0.35)
	drop.tween_property(_teabag, "position", cup_top + Vector3(0, -0.035, 0), 0.25)
	await _wait(0.6)
	if skipped: return
	Sfx.play("splash", -16.0, 0.0)
	create_tween().tween_property(_tea_mat, "albedo_color", Color(0.48, 0.24, 0.08), 3.0)
	var bob := create_tween().set_loops(3)
	bob.tween_property(_teabag, "position:y", cup_top.y - 0.02, 0.5)
	bob.tween_property(_teabag, "position:y", cup_top.y - 0.035, 0.5)
	for n in ["1...", "2...", "3..."]:
		_say(n)
		await _wait(1.0)
		if skipped: return
	# out with the bag, then stir
	create_tween().tween_property(_teabag, "position", _cup.position + Vector3(0.16, 0.0, 0.08), 0.4)
	_say("Stir, stir...")
	_spoon.position = cup_top + Vector3(0.0, 0.0, 0)
	_spoon.rotation = Vector3(0, 0, 0.3)
	Sfx.play("stir", -6.0, 0.0)
	var stir := create_tween().set_loops(4)
	for k in 4:
		var ang := TAU * k / 4.0
		stir.tween_property(_spoon, "position", cup_top + Vector3(cos(ang) * 0.03, -0.01, sin(ang) * 0.03), 0.07)
	await _wait(1.15)
	if skipped: return
	_spoon.position = _cup.position + Vector3(0.0, 0.0, 0.115)
	_spoon.rotation = Vector3(PI / 2, PI / 2, 0)
	# sip, seen from across the table
	var front := R + _table + Vector3(0.25, 1.3, -1.7)
	_cam(front + Vector3(0.2, 0, 0), front + Vector3(0.1, -0.05, 0.2), R + _stool + Vector3(0, 1.15, 0), R + _stool + Vector3(0, 1.2, 0), 2.4, 40.0)
	actor.hold_clip = ""
	actor.oneshot("Use_Item", 0.9)
	Sfx.play("sip", -3.0)
	await _wait(0.9)
	actor.hold_clip = "Sit_Chair_Idle"
	_say("Ahh... perfect.")
	await _wait(1.3)
	if skipped: return

	# 7. out the door, across the yard, into the portal; a beam of light
	shot = "portal"
	await _cut()
	actor.hold_clip = ""
	actor.set_weapon("rusty_sword")
	if actor.has_method("set_offhand"):
		actor.set_offhand("shield_round")
	actor.scale = Vector3.ONE
	actor.position = g(DOOR.x, DOOR.z)
	var pc := g(PORTAL.x, PORTAL.z)
	_cam(g(PORTAL_CAM.x, PORTAL_CAM.y) + Vector3(0, 2.4, 0), g(PORTAL_CAM.x - 0.8, PORTAL_CAM.y - 0.6) + Vector3(0, 2.0, 0),
		g(DOOR.x, DOOR.z) + Vector3(0, 1.4, 0), pc + Vector3(0, 1.5, 0), 5.0, 48.0)
	_open()
	_say("Off to the old portal, like always...")
	Sfx.play("whistle", -7.0, 0.0)
	await _walk(pc, 2.4)
	if skipped: return
	var front_of := g(7.4, 11.2)
	_cam(front_of + Vector3(0, 1.6, 0), front_of + Vector3(0.3, 1.5, 0.4), pc + Vector3(0, 1.4, 0), pc + Vector3(0, 1.6, 0), 3.0, 48.0)
	actor.rotation.y = _yaw_to(cam.position)
	_say("Here we go!")
	actor.oneshot("Cheer", 1.0)
	await _wait(1.0)
	if skipped: return
	_beam(pc)
	await _wait(1.8)
	if skipped: return
	FX.screen_flash(Color(0.9, 1.0, 0.95), 1.0, 1.2)
	_end()

## A column of light pours down, the hero glows and lifts away.
func _beam(at: Vector3) -> void:
	Sfx.play("portal", -2.0, 0.0)
	FX.pillar(at, Color(0.55, 1.0, 0.85), 1.2, 14.0, 2.2)
	FX.burst(at + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.9), 90, 3.0, 0.25, 1.6, 2.5)
	var rise := CPUParticles3D.new(); rise.amount = 80; rise.lifetime = 1.4
	rise.mesh = FX.quad(0.12); rise.material_override = FX.glow_material(Color(0.7, 1.0, 0.9), 2.5)
	rise.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; rise.emission_sphere_radius = 0.8
	rise.direction = Vector3.UP; rise.spread = 8; rise.initial_velocity_min = 2.0; rise.initial_velocity_max = 4.0
	rise.gravity = Vector3.ZERO
	add_child(rise); rise.position = at + Vector3(0, 0.5, 0)
	_portal_mat.set_shader_parameter("intensity", 2.8)
	_portal_light.light_energy = 6.0
	actor.flash(Color(0.7, 1.0, 0.9), 0.9)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor, "position:y", actor.position.y + 1.2, 1.6).set_ease(Tween.EASE_IN)
	tw.tween_property(actor, "scale", Vector3(0.3, 1.6, 0.3), 1.6).set_ease(Tween.EASE_IN)

var _t0 := 0
func _end() -> void:
	shot = "end"
	print("INTRO_MOVIE_SECONDS %.1f" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	if _music:
		_music.stop()
	finished.emit()
