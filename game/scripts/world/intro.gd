extends Node3D
class_name IntroMovie
## The opening movie, played after you create your hero:
## sunrise over the mountains into a quiet valley -> your hero wakes up in
## pajamas in their little cabin, changes into their outfit, brushes their
## teeth, boils water and drinks a cup of tea -> walks out whistling down the
## forest trail -> finds a forgotten portal, which flickers to life -> steps in.
## Everything is real-time 3D with the player's own character. Skippable.

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
var _portal_mat: ShaderMaterial
var _portal_light: OmniLight3D
var _scenes := {}
var _noise := FastNoiseLite.new()
var _music: AudioStreamPlayer
var shot := ""                         # current shot name (tests take pictures)

# --- valley layout
const CABIN := Vector3(0, 0, 0)
const DOOR := Vector3(0, 0, 5.5)
const PORTAL := Vector3(-18, 0, -78)
var trail: PackedVector2Array = [Vector2(0, 7), Vector2(3, -8), Vector2(-4, -25), Vector2(2, -42), Vector2(-8, -58), Vector2(-16, -72)]

func height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 4.0
	var r := Vector2(x, z + 30.0).length()
	h += pow(maxf(r - 70.0, 0.0), 1.5) * 0.12
	var near := minf(Vector2(x, z).length(), Vector2(x - PORTAL.x, z - PORTAL.z).length())
	h *= smoothstep(4.0, 22.0, near)
	return h

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

# ---------------------------------------------------------------------------
func build() -> void:
	_noise.seed = 3; _noise.frequency = 0.02
	_environment()
	_valley()
	_cabin_interior()
	_old_portal()
	_actor()
	cam = Camera3D.new(); cam.fov = 55; cam.near = 0.05
	add_child(cam)
	cam.current = true
	_overlay()

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.25, 0.5)
	sky_mat.sky_horizon_color = Color(1.0, 0.55, 0.35)
	sky_mat.ground_horizon_color = Color(0.45, 0.35, 0.3)
	sky_mat.ground_bottom_color = Color(0.12, 0.12, 0.1)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.75, 0.6)
	env.fog_density = 0.0012
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(2, -20, 0)     # below the mountains: it rises in shot 1
	sun.light_color = Color(1.0, 0.7, 0.45)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

func _valley() -> void:
	# ground
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 61; var step := 4.0; var o := -120.0
	var cols := []
	for j in n:
		for i in n:
			var x := o + i * step; var z := o + j * step - 30.0
			var c := Color(0.36, 0.55, 0.22).lerp(Color(0.5, 0.6, 0.25), _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)
			var td := INF
			for k in trail.size() - 1:
				td = minf(td, _seg(Vector2(x, z), trail[k], trail[k + 1]))
			c = c.lerp(Color(0.52, 0.42, 0.28), smoothstep(5.0, 2.0, td))
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
	# mountains: the sun rises over the eastern peak
	for k in 14:
		var a := k * TAU / 14.0
		_model(["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees"][k % 3],
			Vector3(cos(a) * 140.0, -8.0, sin(a) * 140.0 - 30.0), k * 47.0, 34.0 + (k % 3) * 4.0)
	_model("mountain_B_grass_trees", Vector3(95, -8.0, -110), 20.0, 52.0)
	# the cabin, with chimney smoke and a little garden
	_model("building_home_A_green", g(CABIN.x, CABIN.z) - Vector3(0, 0.2, 0), 0.0, 7.0)
	var smoke := CPUParticles3D.new(); smoke.amount = 30; smoke.lifetime = 5.0; smoke.preprocess = 5.0
	smoke.mesh = FX.quad(0.9); var smm := StandardMaterial3D.new(); smm.albedo_color = Color(0.9, 0.9, 0.92, 0.35)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; smm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; smoke.material_override = smm
	smoke.direction = Vector3(0.3, 1, 0); smoke.spread = 10; smoke.initial_velocity_min = 0.6; smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.2, 0.15, 0); smoke.scale_amount_min = 0.8; smoke.scale_amount_max = 2.2
	add_child(smoke); smoke.position = g(CABIN.x, CABIN.z) + Vector3(1.6, 7.6, -1.0)
	_model("building_well_green", g(-7, 6), 30.0, 4.5)
	for p in [Vector2(5, 7), Vector2(6.5, 8), Vector2(-4, 9)]:
		_model("pumpkin_orange" if p.x > 0 else "pumpkin_yellow_small", g(p.x, p.y), p.x * 40.0, 1.0)
	_model("fence_wood_straight", g(9, 4), 0.0, 6.0)
	_model("fence_wood_straight", g(-10, 3), 0.0, 6.0)
	# trees lining the trail
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	for k in 140:
		var p := Vector2(rng.randf_range(-70, 60), rng.randf_range(-110, 30))
		var td := INF
		for s in trail.size() - 1:
			td = minf(td, _seg(p, trail[s], trail[s + 1]))
		if td < 6.0 or p.length() < 14.0 or p.distance_to(Vector2(PORTAL.x, PORTAL.z)) < 10.0:
			continue
		var nm: String = ["tree_single_A", "tree_single_B", "tree_pine_yellow_large", "tree_pine_orange_medium"][rng.randi() % 4]
		_model(nm, g(p.x, p.y) - Vector3(0, 0.2, 0), rng.randf() * 360.0, 6.5 if nm.begins_with("tree_single") else 1.1)
	var birds := Node3D.new(); add_child(birds); birds.position = g(0, -20)
	Sfx.loop_on(birds, "loop_birds", -8.0, 30.0, 200.0)

func _seg(p: Vector2, a: Vector2, c: Vector2) -> float:
	var ab := c - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# --- the cabin interior (a set filmed away from the valley) ---------------------
var _bed_pos: Vector3
var _wardrobe_pos: Vector3
var _basin_pos: Vector3
var _stove_pos: Vector3
var _chair_pos: Vector3
var _kettle_steam: CPUParticles3D
var _mug_steam: CPUParticles3D

func _wood(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.85
	return m

func _box(a: Vector3, b2: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = (b2 - a).abs()
	mi.mesh = bm; mi.material_override = m; mi.position = ROOM + (a + b2) * 0.5
	add_child(mi)
	return mi

func _cabin_interior() -> void:
	var floor_m := _wood(Color(0.45, 0.3, 0.18)); var wall_m := _wood(Color(0.55, 0.38, 0.22))
	var dark := _wood(Color(0.3, 0.2, 0.12))
	_box(Vector3(-5, -0.2, -4), Vector3(5, 0, 4), floor_m)
	_box(Vector3(-5, 0, -4.2), Vector3(5, 4, -4), wall_m)
	_box(Vector3(-5.2, 0, -4), Vector3(-5, 4, 4), wall_m)
	_box(Vector3(5, 0, -4), Vector3(5.2, 4, 4), wall_m)
	_box(Vector3(-5, 4, -4), Vector3(5, 4.2, 4), dark)
	for x in [-3.0, 0.0, 3.0]:
		_box(Vector3(x - 0.15, 3.6, -4), Vector3(x + 0.15, 3.9, 4), dark)   # beams
	# window with morning light
	var win := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.6, 1.2); win.mesh = q
	win.material_override = FX.glow_material(Color(1.0, 0.85, 0.6), 1.8)
	win.position = ROOM + Vector3(-1.5, 2.3, -3.98); add_child(win)
	var beam := SpotLight3D.new(); beam.light_color = Color(1.0, 0.8, 0.55); beam.light_energy = 9.0
	beam.spot_range = 9.0; beam.spot_angle = 30.0; beam.shadow_enabled = true
	add_child(beam); beam.position = ROOM + Vector3(-1.5, 2.6, -3.6); beam.look_at(ROOM + Vector3(-3.0, 0.2, -1.0))
	var fill := OmniLight3D.new(); fill.light_color = Color(1.0, 0.8, 0.6); fill.light_energy = 1.2; fill.omni_range = 10.0
	add_child(fill); fill.position = ROOM + Vector3(1, 3.0, 1)
	# bed (left back corner)
	_bed_pos = Vector3(-3.6, 0, -2.2)
	_box(_bed_pos + Vector3(-0.9, 0, -1.4), _bed_pos + Vector3(0.9, 0.45, 1.4), dark)
	_box(_bed_pos + Vector3(-0.85, 0.45, -1.35), _bed_pos + Vector3(0.85, 0.62, 1.35), _wood(Color(0.92, 0.9, 0.85)))
	_box(_bed_pos + Vector3(-0.86, 0.6, -0.4), _bed_pos + Vector3(0.86, 0.68, 1.36), _wood(Color(0.35, 0.5, 0.8)))   # blanket
	_box(_bed_pos + Vector3(-0.6, 0.62, -1.3), _bed_pos + Vector3(0.6, 0.8, -0.85), _wood(Color(0.98, 0.97, 0.95)))  # pillow
	_box(_bed_pos + Vector3(-0.9, 0, -1.5), _bed_pos + Vector3(0.9, 1.2, -1.35), dark)
	# wardrobe (right back)
	_wardrobe_pos = Vector3(3.8, 0, -3.2)
	_box(_wardrobe_pos + Vector3(-0.9, 0, -0.6), _wardrobe_pos + Vector3(0.9, 2.6, 0.5), dark)
	_box(_wardrobe_pos + Vector3(-0.02, 0.2, 0.5), _wardrobe_pos + Vector3(0.02, 2.4, 0.53), _wood(Color(0.2, 0.13, 0.08)))
	# wash basin (left wall)
	_basin_pos = Vector3(-4.3, 0, 1.5)
	_box(_basin_pos + Vector3(-0.4, 0, -0.5), _basin_pos + Vector3(0.4, 0.9, 0.5), dark)
	var basin := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.35; cy.bottom_radius = 0.25; cy.height = 0.2
	basin.mesh = cy; basin.material_override = _wood(Color(0.75, 0.78, 0.82)); basin.position = ROOM + _basin_pos + Vector3(0, 1.0, 0)
	add_child(basin)
	var mirror := MeshInstance3D.new(); var mq := QuadMesh.new(); mq.size = Vector2(0.6, 0.8); mirror.mesh = mq
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.75, 0.85, 0.9); mm.metallic = 1.0; mm.roughness = 0.05
	mirror.material_override = mm; mirror.position = ROOM + _basin_pos + Vector3(-0.38, 1.8, 0); mirror.rotation.y = PI / 2
	add_child(mirror)
	# stove with a kettle (right wall)
	_stove_pos = Vector3(4.2, 0, 1.0)
	_box(_stove_pos + Vector3(-0.6, 0, -0.6), _stove_pos + Vector3(0.6, 1.0, 0.6), _wood(Color(0.18, 0.17, 0.17)))
	_box(_stove_pos + Vector3(0.1, 1.0, -0.15), _stove_pos + Vector3(0.4, 4.0, 0.15), _wood(Color(0.18, 0.17, 0.17)))
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.5, 0.2); glow.light_energy = 1.5; glow.omni_range = 4.0
	glow.set_script(load("res://scripts/world/flicker.gd")); add_child(glow); glow.position = ROOM + _stove_pos + Vector3(-0.7, 0.5, 0)
	var kettle := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.22; ks.height = 0.34
	kettle.mesh = ks; var km := StandardMaterial3D.new(); km.albedo_color = Color(0.7, 0.3, 0.15); km.metallic = 0.7; km.roughness = 0.3
	kettle.material_override = km; kettle.position = ROOM + _stove_pos + Vector3(-0.15, 1.17, 0); add_child(kettle)
	_kettle_steam = _steam(ROOM + _stove_pos + Vector3(-0.3, 1.45, 0))
	# table and chair (middle)
	_chair_pos = Vector3(0.6, 0, 1.6)
	_box(Vector3(-0.8, 0.75, 0.0), Vector3(0.8, 0.82, 1.0), dark)
	for p in [Vector3(-0.7, 0, 0.1), Vector3(0.7, 0, 0.1), Vector3(-0.7, 0, 0.9), Vector3(0.7, 0, 0.9)]:
		_box(p - Vector3(0.05, 0, 0.05), p + Vector3(0.05, 0.75, 0.05), dark)
	Props.place(self, "stool", ROOM + _chair_pos, 0.0, 1.0)
	var mug := MeshInstance3D.new(); var mc := CylinderMesh.new(); mc.top_radius = 0.07; mc.bottom_radius = 0.06; mc.height = 0.14
	mug.mesh = mc; mug.material_override = _wood(Color(0.9, 0.85, 0.75)); mug.position = ROOM + Vector3(0.4, 0.9, 0.75); add_child(mug)
	_mug_steam = _steam(ROOM + Vector3(0.4, 1.0, 0.75))
	_mug_steam.emitting = false
	Props.place(self, "candle_triple", ROOM + Vector3(-0.4, 0.82, 0.4), 0.0, 0.6)
	Props.place(self, "shelf_small_candles", ROOM + Vector3(0.0, 1.6, -3.9), 0.0, 1.0)
	Props.place(self, "barrel_small", ROOM + Vector3(-4.3, 0, -0.2), 0.0, 1.0)
	Props.place(self, "shelves", ROOM + Vector3(2.0, 0, -3.8), 0.0, 1.0)

func _steam(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new(); p.amount = 24; p.lifetime = 2.0
	p.mesh = FX.quad(0.18); var m := StandardMaterial3D.new(); m.albedo_color = Color(1, 1, 1, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
	p.direction = Vector3.UP; p.spread = 12; p.initial_velocity_min = 0.3; p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.2, 0); p.scale_amount_min = 0.6; p.scale_amount_max = 2.0
	add_child(p); p.position = at
	return p

func _old_portal() -> void:
	var c := g(PORTAL.x, PORTAL.z)
	_model("arch_gate", c - Vector3(0, 0.15, 0), -40.0, 1.5)
	_model("tree_dead_large", c + Vector3(-5, 0, -3), 70.0, 1.3)
	_model("tree_dead_medium", c + Vector3(4.5, 0, -2), -20.0, 1.2)
	for k in 5:
		_model("rock_single_" + ["A", "C", "E", "B", "D"][k], c + Vector3(-6 + k * 3.0, -0.2, 2.5 + (k % 2) * 1.5), k * 50.0, 6.0)
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2)
	disc.mesh = q
	_portal_mat = ShaderMaterial.new(); _portal_mat.shader = load("res://shaders/portal.gdshader")
	_portal_mat.set_shader_parameter("intensity", 0.0)
	disc.material_override = _portal_mat
	add_child(disc)
	disc.position = c + Vector3(0, 3.0, 0); disc.rotation_degrees.y = -40.0
	_portal_light = OmniLight3D.new(); _portal_light.light_color = Color(0.4, 1.0, 0.8); _portal_light.light_energy = 0.0
	_portal_light.omni_range = 14.0; add_child(_portal_light); _portal_light.position = c + Vector3(0, 3, 1.0)

func _actor() -> void:
	actor = CharacterModel.new()
	add_child(actor)
	_dress(true)
	actor.grounded = true

## Pajamas first (pale blue, no gear), then the real adventuring outfit.
func _dress(pajamas: bool) -> void:
	var p := Game.profile
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": false if pajamas else p.show_hat, "scale": 1.0}
	if pajamas:
		cfg["outfit_color"] = Color(0.6, 0.75, 1.0)
		cfg["cape_color"] = Color(0.6, 0.75, 1.0)
	else:
		if p.cape > 0:
			cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
			cfg["outfit_color"] = Game.CAPE_COLORS[p.cape]
	Player._apply_profile_looks(cfg)
	var hold := actor.hold_clip
	actor.setup(cfg)
	actor.hold_clip = hold

# --- overlay: letterbox, captions, title, skip button ---------------------------
func _overlay() -> void:
	_ui = CanvasLayer.new(); _ui.layer = 20; add_child(_ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	_ui.add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new(); bar.color = Color.BLACK; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size.y = 90
		if top:
			bar.offset_bottom = 90
		else:
			bar.offset_top = -90
		root.add_child(bar)
	_caption = UIKit.label("", 30, Color(1.0, 0.95, 0.85), true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -78; _caption.offset_bottom = -20
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(_caption)
	_title = UIKit.label("BOBEK'S ADVENTURE", 84, UIKit.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.offset_left = -700; _title.offset_right = 700; _title.offset_top = -170; _title.offset_bottom = -60
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0, 0.9))
	_title.modulate.a = 0.0
	root.add_child(_title)
	var skip := Button.new(); skip.text = "Skip intro  >>"
	skip.custom_minimum_size = Vector2(230, 56)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -260; skip.offset_right = -24; skip.offset_top = 18; skip.offset_bottom = 74
	skip.pressed.connect(func() -> void: skip_now())
	root.add_child(skip)
	_fade = ColorRect.new(); _fade.color = Color(0, 0, 0, 1); _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(_fade)
	root.move_child(skip, -1)

func skip_now() -> void:
	if skipped:
		return
	skipped = true
	_end()

func _say(t: String) -> void:
	_caption.text = t
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.4)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## A film cut: quick fade, move the hero to `at`, fade back in.
func _cut(at: Vector3) -> void:
	await _fade_to(1.0, 0.25)
	actor.position = at
	_fade_to(0.0, 0.3)

func _fade_to(a: float, t: float) -> void:
	var tw := create_tween(); tw.tween_property(_fade, "color:a", a, t)
	await tw.finished

func _cam_move(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, dur: float) -> void:
	cam.position = from; _look_at = look_from
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", to, dur)
	tw.tween_property(self, "_look_at", look_to, dur)

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

func _face(dir_yaw: float) -> void:
	create_tween().tween_property(actor, "rotation:y", dir_yaw, 0.35)

## Walk along the valley trail (each point snapped to the ground).
func _walk_trail(points: Array, speed: float) -> void:
	for p in points:
		if skipped:
			return
		await _walk(g(p.x, p.y), speed)

func _notes() -> void:
	# little music notes floating up while whistling
	for k in 6:
		if skipped or not is_inside_tree():
			return
		var n := Label3D.new(); n.text = "~ ♪" if k % 2 == 0 else "♫"
		n.font_size = 64; n.pixel_size = 0.006; n.modulate = Color(1.0, 0.95, 0.6)
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED; n.outline_size = 8
		add_child(n); n.position = actor.position + Vector3(0.3, 2.0, 0)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "position", n.position + Vector3(randf_range(-0.6, 0.6), 1.6, 0), 1.8)
		tw.tween_property(n, "modulate:a", 0.0, 1.8)
		tw.chain().tween_callback(n.queue_free)
		await _wait(0.9)

# ---------------------------------------------------------------------------
func play() -> void:
	_music = AudioStreamPlayer.new(); _music.stream = Sfx.get_stream("music_morning"); _music.volume_db = -14.0
	add_child(_music); _music.play()
	var nm: String = Game.profile.name
	# 1. sunrise over the mountains into the valley
	shot = "sunrise"
	actor.visible = false
	_cam_move(Vector3(30, 18, 70), Vector3(18, 12, 40), Vector3(80, 30, -100), Vector3(0, 4, -5), 9.0)
	create_tween().tween_property(sun, "rotation_degrees:x", -24.0, 9.0)
	var stw := create_tween().set_parallel(true)
	stw.tween_property(sky_mat, "sky_horizon_color", Color(1.0, 0.82, 0.62), 9.0)
	stw.tween_property(sky_mat, "sky_top_color", Color(0.32, 0.55, 0.88), 9.0)
	await _fade_to(0.0, 1.5)
	create_tween().tween_property(_title, "modulate:a", 1.0, 1.5)
	await _wait(5.0)
	if skipped: return
	create_tween().tween_property(_title, "modulate:a", 0.0, 1.2)
	_say("Far from any dungeon, in a quiet valley, the sun comes up over a little cabin...")
	await _wait(3.5)
	if skipped: return
	# 2. inside: asleep in bed, in pajamas
	shot = "bed"
	await _fade_to(1.0, 0.4)
	actor.visible = true
	actor.position = ROOM + _bed_pos + Vector3(0, 0.62, 0.3)
	actor.rotation.y = 0.0
	actor.hold_clip = "Lie_Idle"
	_cam_move(ROOM + Vector3(-0.6, 2.7, 2.8), ROOM + Vector3(-1.4, 2.3, 1.6), ROOM + _bed_pos + Vector3(0, 0.6, 0.2), ROOM + _bed_pos + Vector3(0, 0.8, 0), 6.0)
	_fade_to(0.0, 0.6)
	_say("Zzz...")
	await _wait(2.5)
	if skipped: return
	_say("Rise and shine, %s!" % nm)
	actor.hold_clip = ""
	actor.oneshot("Lie_StandUp", 2.0)
	await _wait(2.0)
	if skipped: return
	actor.position = ROOM + _bed_pos + Vector3(1.3, 0, 0.6)
	actor.rotation.y = -PI / 2
	actor.oneshot("Cheer", 1.6)
	await _wait(1.6)
	if skipped: return
	# 3. change out of pajamas
	shot = "dress"
	_cam_move(ROOM + Vector3(0.2, 2.3, 2.6), ROOM + Vector3(1.2, 2.1, 1.9), ROOM + Vector3(0.5, 1.1, -1.5), ROOM + _wardrobe_pos + Vector3(-0.4, 1.1, 1.2), 3.5)
	await _walk(ROOM + _wardrobe_pos + Vector3(-0.4, 0, 1.4), 2.0)
	if skipped: return
	_face(PI * 0.0)
	actor.oneshot("Interact", 1.0)
	await _wait(0.8)
	FX.burst(actor.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.95, 0.7), 50, 3.0, 0.2, 0.8, 0.0)
	Sfx.play("pickup", -6.0)
	_dress(false)
	_say("Time to get dressed!")
	actor.oneshot("Cheer", 1.4)
	await _wait(1.6)
	if skipped: return
	# 4. brush teeth
	shot = "teeth"
	await _cut(ROOM + _basin_pos + Vector3(2.2, 0, 0.9))
	_cam_move(ROOM + Vector3(-1.6, 2.1, 3.7), ROOM + Vector3(-2.2, 1.9, 3.6), ROOM + _basin_pos + Vector3(0.9, 1.3, 0.3), ROOM + _basin_pos + Vector3(0.6, 1.4, 0), 3.0)
	await _walk(ROOM + _basin_pos + Vector3(0.75, 0, 0), 1.6)
	if skipped: return
	_face(PI / 2)
	_say("Brush, brush, brush...")
	Sfx.play("brush", -4.0)
	var brush := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.22, 0.03); brush.mesh = bm
	brush.material_override = FX.glow_material(Color(0.4, 0.8, 1.0), 0.6)
	var hand := actor._attach("handslot.r")
	if hand:
		hand.add_child(brush)
	var bubbles := CPUParticles3D.new(); bubbles.amount = 16; bubbles.lifetime = 0.8
	bubbles.mesh = FX.quad(0.07); bubbles.material_override = FX.glow_material(Color(1, 1, 1), 1.2)
	bubbles.direction = Vector3(-1, 1, 0); bubbles.spread = 40; bubbles.initial_velocity_min = 0.3; bubbles.initial_velocity_max = 0.7
	bubbles.gravity = Vector3(0, -0.5, 0)
	add_child(bubbles); bubbles.position = actor.position + Vector3(-0.35, 1.55, 0)
	for k in 3:
		actor.oneshot("Use_Item", 0.8)
		await _wait(0.8)
		if skipped: return
	bubbles.emitting = false
	brush.queue_free()
	_say("Sparkling!")
	await _wait(0.8)
	if skipped: return
	# 5. kettle on
	shot = "kettle"
	await _cut(ROOM + _stove_pos + Vector3(-2.4, 0, 1.0))
	_cam_move(ROOM + Vector3(1.0, 2.1, 3.6), ROOM + Vector3(1.4, 2.0, 3.4), ROOM + _stove_pos + Vector3(-1.4, 1.2, 0.4), ROOM + _stove_pos + Vector3(-0.6, 1.2, 0), 4.0)
	await _walk(ROOM + _stove_pos + Vector3(-1.2, 0, 0), 1.6)
	if skipped: return
	_face(-PI / 2)
	actor.oneshot("Interact", 1.0)
	_say("Time for a nice cup of tea.")
	await _wait(1.2)
	Sfx.play("kettle", -6.0)
	_kettle_steam.amount = 50
	await _wait(2.4)
	if skipped: return
	# 6. sit and drink it
	shot = "tea"
	await _cut(ROOM + _chair_pos + Vector3(1.4, 0, 1.2))
	_cam_move(ROOM + Vector3(1.6, 1.8, -1.4), ROOM + Vector3(0.9, 1.6, -1.7), ROOM + _chair_pos + Vector3(0.6, 1.0, 0.4), ROOM + _chair_pos + Vector3(0, 1.0, 0), 5.0)
	await _walk(ROOM + _chair_pos + Vector3(0, 0, 0.1), 1.6)
	if skipped: return
	actor.rotation.y = 0.0
	actor.oneshot("Sit_Chair_Down", 0.9)
	await _wait(0.9)
	actor.hold_clip = "Sit_Chair_Idle"
	_mug_steam.emitting = true
	await _wait(0.6)
	Sfx.play("sip", -4.0)
	_say("Ahh... perfect.")
	await _wait(1.4)
	Sfx.play("sip", -4.0)
	await _wait(1.2)
	if skipped: return
	actor.hold_clip = ""
	actor.oneshot("Sit_Chair_StandUp", 0.9)
	await _wait(0.9)
	if skipped: return
	# 7. out the door and down the trail, whistling
	shot = "trail"
	await _fade_to(1.0, 0.4)
	actor.position = g(DOOR.x, DOOR.z)
	actor.rotation.y = PI
	actor.set_weapon("rusty_sword")
	if actor.has_method("set_offhand"):
		actor.set_offhand("shield_round")
	_cam_move(g(6, 16) + Vector3(0, 3.0, 0), g(4, 6) + Vector3(0, 2.6, 0), g(0, 6) + Vector3(0, 1.2, 0), g(1, -6) + Vector3(0, 1.2, 0), 7.0)
	_fade_to(0.0, 0.6)
	_say("Ready for the day!")
	Sfx.play("whistle", -6.0, 0.0)
	_notes()
	await _walk_trail([Vector2(0, 7), Vector2(3, -8)], 2.2)
	if skipped: return
	_cam_move(g(-10, -10) + Vector3(0, 3.0, 0), g(-12, -40) + Vector3(0, 3.2, 0), g(0, -15) + Vector3(0, 1.2, 0), g(-6, -50) + Vector3(0, 1.2, 0), 10.0)
	_say("Whistling down the forest trail...")
	Sfx.play("whistle", -6.0, 0.0)
	_notes()
	await _walk_trail([Vector2(-4, -25), Vector2(2, -42), Vector2(-8, -58)], 2.6)
	if skipped: return
	# 8. the forgotten portal
	shot = "portal"
	actor.position = g(-11, -64)
	var to_p := Vector3(PORTAL.x, 0, PORTAL.z) - Vector3(actor.position.x, 0, actor.position.z)
	_cam_move(g(-4, -66) + Vector3(0, 2.6, 0), g(-6, -68) + Vector3(0, 2.4, 0), g(-14, -72) + Vector3(0, 2.0, 0), g(PORTAL.x, PORTAL.z) + Vector3(0, 2.6, 0), 6.0)
	await _walk(g(-14, -69), 1.6)
	if skipped: return
	actor.rotation.y = atan2(-to_p.x, -to_p.z)
	_say("Huh? A portal... I've never seen that here before!")
	actor.oneshot("Interact", 1.0)
	await _wait(1.4)
	for k in 3:
		_portal_mat.set_shader_parameter("intensity", 0.8)
		_portal_light.light_energy = 2.0
		await _wait(0.12)
		_portal_mat.set_shader_parameter("intensity", 0.0)
		_portal_light.light_energy = 0.0
		await _wait(0.25)
	if skipped: return
	Sfx.play("portal", -2.0, 0.0)
	var ptw := create_tween().set_parallel(true)
	ptw.tween_method(func(v: float) -> void: _portal_mat.set_shader_parameter("intensity", v), 0.0, 2.2, 1.5)
	ptw.tween_property(_portal_light, "light_energy", 5.0, 1.5)
	FX.burst(g(PORTAL.x, PORTAL.z) + Vector3(0, 3, 0), Color(0.4, 1.0, 0.8), 80, 5.0, 0.3, 1.4, 0.0)
	actor.oneshot("Cheer", 1.6)
	_say("It's waking up! Where does it go...?")
	await _wait(2.0)
	if skipped: return
	_say("Only one way to find out!")
	await _walk(g(PORTAL.x, PORTAL.z), 2.4)
	if skipped: return
	FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.5)
	_end()

func _end() -> void:
	shot = "end"
	if _music:
		_music.stop()
	finished.emit()
