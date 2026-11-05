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
	smoke.mesh = FX.quad(0.9); var smm := StandardMaterial3D.new(); smm.albedo_color = Color(0.92, 0.92, 0.94, 0.35)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; smm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; smoke.material_override = smm
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
	_teapot.rotation.y = PI / 2
	_kettle_steam = _steam(Vector3.ZERO)
	_teapot.add_child(_kettle_steam)
	_kettle_steam.position = Vector3(0, 0.12, 0.33)
	_kettle_steam.emitting = false
	# table, stool, cup, tea bag and spoon
	_box(_table + Vector3(-0.8, 0.74, -0.5), _table + Vector3(0.8, 0.8, 0.5), dark)
	for p in [Vector3(-0.7, 0, -0.4), Vector3(0.7, 0, -0.4), Vector3(-0.7, 0, 0.4), Vector3(0.7, 0, 0.4)]:
		_box(_table + p - Vector3(0.05, 0, 0.05), _table + p + Vector3(0.05, 0.74, 0.05), dark)
	Props.place(self, "stool", ROOM + _stool, 0.0, 1.0)
	Props.place(self, "candle_triple", ROOM + _table + Vector3(-0.55, 0.8, -0.3), 0.0, 0.5)
	_cup = Node3D.new(); add_child(_cup); _cup.position = ROOM + _table + Vector3(0.05, 0.8, 0.12)
	var cup_m := _mat(Color(0.95, 0.93, 0.88), 0.35)
	cup_m.cull_mode = BaseMaterial3D.CULL_DISABLED          # open cup: you can see the tea inside
	var cupm := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.085; cc.bottom_radius = 0.065; cc.height = 0.14
	cc.cap_top = false
	cupm.mesh = cc; cupm.material_override = cup_m; cupm.position.y = 0.07; _cup.add_child(cupm)
	var ch := MeshInstance3D.new(); var tor := TorusMesh.new(); tor.inner_radius = 0.025; tor.outer_radius = 0.045
	ch.mesh = tor; ch.material_override = cup_m; ch.position = Vector3(0.095, 0.075, 0); ch.rotation.x = PI / 2; _cup.add_child(ch)
	_tea = MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.079; tc.bottom_radius = 0.07; tc.height = 0.01
	_tea.mesh = tc; _tea_mat = _mat(Color(0.75, 0.82, 0.85), 0.1); _tea.material_override = _tea_mat
	_tea.position.y = 0.02; _tea.visible = false; _cup.add_child(_tea)
	_cup_steam = _steam(Vector3.ZERO); _cup.add_child(_cup_steam); _cup_steam.position.y = 0.15; _cup_steam.emitting = false
	_teabag = Node3D.new(); add_child(_teabag)
	var tb := MeshInstance3D.new(); var tbm := BoxMesh.new(); tbm.size = Vector3(0.06, 0.07, 0.015)
	tb.mesh = tbm; tb.material_override = _mat(Color(0.95, 0.92, 0.82)); _teabag.add_child(tb)
	var tag := MeshInstance3D.new(); var tgm := BoxMesh.new(); tgm.size = Vector3(0.035, 0.035, 0.005)
	tag.mesh = tgm; tag.material_override = _mat(Color(0.85, 0.2, 0.2)); tag.position = Vector3(0.07, 0.12, 0); _teabag.add_child(tag)
	var string := MeshInstance3D.new(); var sgm := BoxMesh.new(); sgm.size = Vector3(0.003, 0.11, 0.003)
	string.mesh = sgm; string.material_override = _mat(Color(0.95, 0.95, 0.95)); string.position = Vector3(0.035, 0.08, 0); string.rotation.z = -0.6
	_teabag.add_child(string)
	_teabag.position = ROOM + _table + Vector3(0.35, 0.82, 0.25)
	_teabag.rotation.x = -PI / 2
	_spoon = MeshInstance3D.new(); var spm := BoxMesh.new(); spm.size = Vector3(0.015, 0.2, 0.01)
	_spoon.mesh = spm; _spoon.material_override = _mat(Color(0.82, 0.82, 0.85), 0.2, 1.0)
	add_child(_spoon); _spoon.position = ROOM + _table + Vector3(-0.2, 0.81, 0.25); _spoon.rotation = Vector3(PI / 2, 0, 0.4)
	# the pouring water
	_stream = MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.012; sc.bottom_radius = 0.016; sc.height = 1.0
	_stream.mesh = sc
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.8, 0.9, 1.0, 0.65); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	_stream.material_override = wm; _stream.visible = false; add_child(_stream)
	Props.place(self, "shelf_small_candles", ROOM + Vector3(1.8, 1.6, -3.9), 0.0, 1.0)
	Props.place(self, "barrel_small", ROOM + Vector3(-4.3, 0, -0.1), 0.0, 1.0)
	Props.place(self, "shelves", ROOM + Vector3(1.6, 0, 3.8), 180.0, 1.0)

## A proper teapot: round body, lid with a knob, spout and a loop handle.
func _make_teapot() -> Node3D:
	var tp := Node3D.new(); add_child(tp)
	var ceramic := _mat(Color(0.92, 0.94, 0.98), 0.3)
	var blue := _mat(Color(0.25, 0.42, 0.78), 0.35)
	var body := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.2; bs.height = 0.3
	body.mesh = bs; body.material_override = ceramic; body.position.y = 0.15; tp.add_child(body)
	var band := MeshInstance3D.new(); var bt := TorusMesh.new(); bt.inner_radius = 0.19; bt.outer_radius = 0.205
	band.mesh = bt; band.material_override = blue; band.position.y = 0.15; tp.add_child(band)
	var lid := MeshInstance3D.new(); var ls := SphereMesh.new(); ls.radius = 0.11; ls.height = 0.08; ls.is_hemisphere = true
	lid.mesh = ls; lid.material_override = blue; lid.position.y = 0.285; tp.add_child(lid)
	var knob := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.03; ks.height = 0.06
	knob.mesh = ks; knob.material_override = ceramic; knob.position.y = 0.335; tp.add_child(knob)
	var spout := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.022; sc.bottom_radius = 0.05; sc.height = 0.26
	spout.mesh = sc; spout.material_override = ceramic; spout.position = Vector3(0, 0.2, 0.24); spout.rotation.x = 0.85
	tp.add_child(spout)
	var handle := MeshInstance3D.new(); var ht := TorusMesh.new(); ht.inner_radius = 0.06; ht.outer_radius = 0.085
	handle.mesh = ht; handle.material_override = blue; handle.position = Vector3(0, 0.17, -0.2); handle.rotation.z = PI / 2
	tp.add_child(handle)
	return tp

func _steam(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new(); p.amount = 30; p.lifetime = 1.8
	p.mesh = FX.quad(0.16); var m := StandardMaterial3D.new(); m.albedo_color = Color(1, 1, 1, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
	p.direction = Vector3.UP; p.spread = 12; p.initial_velocity_min = 0.25; p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.15, 0); p.scale_amount_min = 0.6; p.scale_amount_max = 2.2
	add_child(p); p.position = at
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

# ---------------------------------------------------------------------------
func play() -> void:
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
	var brush := Node3D.new()
	var handle := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.025, 0.2, 0.025); handle.mesh = hb
	handle.material_override = _mat(Color(0.3, 0.6, 1.0)); brush.add_child(handle)
	var bristle := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.03, 0.05, 0.04); bristle.mesh = bb
	bristle.material_override = _mat(Color(1, 1, 1)); bristle.position = Vector3(0, 0.11, 0.015); brush.add_child(bristle)
	var hand := actor._attach("handslot.r")
	if hand:
		hand.add_child(brush)
	var bubbles := CPUParticles3D.new(); bubbles.amount = 20; bubbles.lifetime = 0.8
	bubbles.mesh = FX.quad(0.06); bubbles.material_override = FX.glow_material(Color(1, 1, 1), 1.0)
	bubbles.direction = Vector3(-1, 0.6, 0); bubbles.spread = 50; bubbles.initial_velocity_min = 0.2; bubbles.initial_velocity_max = 0.6
	bubbles.gravity = Vector3(0, -0.6, 0)
	add_child(bubbles); bubbles.position = actor.position + Vector3(-0.3, 1.15, 0)
	_say("Brush, brush, brush...")
	Sfx.play("brush", -4.0)
	for k in 3:
		actor.oneshot("Use_Item", 0.7)
		await _wait(0.7)
		if skipped: return
	bubbles.emitting = false
	brush.queue_free()
	actor.oneshot("Cheer", 0.9)
	_say("Sparkling!")
	await _wait(0.9)
	if skipped: return

	# 5. the teapot whistles on the stove
	shot = "kettle"
	await _cut()
	actor.visible = false
	_cam(R + _stove + Vector3(-1.4, 1.5, 0.9), R + _stove + Vector3(-1.1, 1.4, 0.7), _teapot.position + Vector3(0, 0.2, 0), _teapot.position + Vector3(0, 0.2, 0), 2.2, 35.0)
	_open()
	_kettle_steam.emitting = true
	_kettle_steam.amount = 40
	Sfx.play("kettle", -6.0)
	_say("Tweeeee! The water's ready.")
	await _wait(2.2)
	if skipped: return

	# 6. tea at the table: pour, tea bag, steep 3 seconds, stir, sip
	shot = "tea"
	await _cut()
	_kettle_steam.emitting = false
	actor.visible = true
	actor.position = R + _stool
	actor.rotation.y = 0.0                        # facing the table (-z)
	actor.hold_clip = "Sit_Chair_Idle"
	_teapot.scale = Vector3.ONE * 0.7
	_teapot.position = R + _table + Vector3(-0.45, 0.8, -0.1)
	_teapot.rotation = Vector3(0, PI / 2 + 0.3, 0)
	var front := R + _table + Vector3(0.25, 1.3, -1.7)
	_cam(front, front + Vector3(0.1, -0.05, 0.1), R + _table + Vector3(0.0, 1.05, 0.4), R + _table + Vector3(0.0, 1.05, 0.45), 1.6, 45.0)
	_open()
	_say("Time for a nice cup of tea.")
	await _wait(1.4)
	if skipped: return
	# close-up: the pour
	var cup_top := _cup.position + Vector3(0, 0.15, 0)
	_cam(cup_top + Vector3(0.12, 0.5, -0.7), cup_top + Vector3(0.08, 0.45, -0.6), cup_top + Vector3(-0.1, 0.06, 0), cup_top + Vector3(-0.04, 0.0, 0), 4.0, 40.0)
	var pour := create_tween().set_parallel(true)
	pour.tween_property(_teapot, "position", _cup.position + Vector3(-0.31, 0.33, 0.0), 0.6)
	pour.tween_property(_teapot, "rotation", Vector3(0.75, PI / 2, 0), 0.6)
	await _wait(0.65)
	_stream.visible = true
	var tip: Vector3 = _teapot.global_transform * Vector3(0, 0.286, 0.338)
	var down := cup_top - Vector3(0, 0.05, 0) - tip
	var yax := down.normalized()
	var xax := yax.cross(Vector3.FORWARD).normalized()
	_stream.global_transform = Transform3D(Basis(xax, yax * down.length(), xax.cross(yax)), tip + down * 0.5)
	_tea.visible = true
	Sfx.play("splash", -8.0, 0.0)
	create_tween().tween_property(_tea, "position:y", 0.115, 1.1)
	_say("Pour...")
	await _wait(1.1)
	_stream.visible = false
	var back := create_tween().set_parallel(true)
	back.tween_property(_teapot, "position", R + _table + Vector3(-0.45, 0.8, -0.1), 0.5)
	back.tween_property(_teapot, "rotation", Vector3(0, PI / 2 + 0.3, 0), 0.5)
	_cup_steam.emitting = true
	# the tea bag goes in and the water turns brown
	var drop := create_tween()
	drop.tween_property(_teabag, "position", cup_top + Vector3(0, 0.12, 0), 0.4)
	drop.tween_property(_teabag, "position", cup_top + Vector3(0, -0.03, 0), 0.25)
	await _wait(0.7)
	if skipped: return
	_say("1...")
	create_tween().tween_property(_tea_mat, "albedo_color", Color(0.45, 0.24, 0.1), 3.0)
	await _wait(1.0)
	_say("2...")
	await _wait(1.0)
	_say("3...")
	await _wait(1.0)
	if skipped: return
	# stir
	_say("Stir, stir...")
	_spoon.position = cup_top + Vector3(0.02, 0.06, 0)
	_spoon.rotation = Vector3(0, 0, 0.25)
	var stir := create_tween().set_loops(3)
	stir.tween_property(_spoon, "position", cup_top + Vector3(-0.02, 0.06, 0.02), 0.15)
	stir.tween_property(_spoon, "position", cup_top + Vector3(0.02, 0.06, 0.02), 0.15)
	await _wait(0.9)
	if skipped: return
	# sip, seen from across the table
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

func _end() -> void:
	shot = "end"
	if _music:
		_music.stop()
	finished.emit()
