extends Node3D
class_name HomeWorld
## THE FLIGHT HOME: the last quest of the base game. After Mr. Bubbles is calmed,
## Anu opens the Sky Gate and you ride your dragonfly all the way home on the
## SKY RIDE (see SkyRide): an arcade course at sunset, through rings, past
## lightning, round floating rocks, through a waterfall and under a rainbow, and
## down into the valley to the cabin where the adventure began. Then the cabin,
## the yard and the family portal (and Port Home brings you back here later).
## Fall into the sea of clouds and your dragonfly catches you at the last ring.

signal area_changed(area: String)

var player: Player
var spawn_point := Vector3(0, 200, -1120)
var spawn_yaw := PI                   # facing +z: towards home
var env: Environment
var sun: DirectionalLight3D
var area := ""
var rings: Array = []                 # the Sky Ride's rings: [Node3D, centre, normal, kind, passed, radius, missed, s]
var rings_passed := 0
var checkpoint := Vector3(0, 200, -1120)
var landed := false
var _cloud_mat: ShaderMaterial
var _puffs: Array = []
var _scen: IntroMovie
var _hud: CanvasLayer
var _banner: Label
var _rng := RandomNumberGenerator.new()
var _waterfall_x := Vector3.ZERO
var _splashed := false
var cabin: HomeCabin
var shop: TradingPost        # Tobble's Trading Post, across the yard
var forge: HomeForge         # the Forge, through the gap in the fence
var decor: HomeDecor         # things for the yard you bought at the Trading Post
var ride: SkyRide

const CABIN := Vector3(0, 0, 0)
const LAND := Vector3(4, 0, 10)
## The course: a smooth path through these points. y is height above the valley floor.
const PATH := [
	Vector3(0, 200, -1120), Vector3(18, 194, -1040), Vector3(-22, 186, -960), Vector3(8, 178, -880),
	Vector3(36, 168, -800), Vector3(6, 158, -720), Vector3(-30, 148, -640),
	Vector3(-42, 138, -560), Vector3(-8, 128, -480), Vector3(30, 118, -400),
	Vector3(22, 108, -320), Vector3(-4, 98, -240), Vector3(0, 90, -170), Vector3(0, 88, -125),
	Vector3(-34, 76, -75), Vector3(-58, 62, -10), Vector3(-42, 48, 46), Vector3(0, 36, 66),
	Vector3(44, 26, 44), Vector3(52, 16, -2), Vector3(30, 8, -18), Vector3(12, 4, 2),
]
const SEA_Y := 40.0

func build() -> void:
	_rng.seed = 77
	_cloud_mat = ShaderMaterial.new(); _cloud_mat.shader = load("res://shaders/cloud.gdshader")
	_cloud_mat.set_shader_parameter("tint", Color(1.0, 0.9, 0.82)); _cloud_mat.set_shader_parameter("shade", Color(0.42, 0.38, 0.62))
	_cloud_mat.set_shader_parameter("rim_glow", 0.4)
	_environment()
	_valley()
	cabin = HomeCabin.build_in(self)
	shop = TradingPost.build_in(self)
	forge = HomeForge.build_in(self)
	decor = HomeDecor.build_in(self)
	if _scen and _scen.soundscape:
		_scen.soundscape.inside_fn = indoors      # calmer and further off indoors
	_cloud_sea()
	_cloud_island_behind()
	ride = SkyRide.build_in(self)
	_flush_puffs()
	_make_hud()
	if Game.is_compat():
		for l in find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				(l as Light3D).shadow_enabled = false
	# already home (a saved game after the flight, continuing by the cabin or in it):
	# no flying, the portal is awake. (Through the Sky Gate again, you fly again.)
	var rp := Game.resume_pos
	var home_done: bool = Game.quest_state("flight_home") == "done" or Game.flags.get("adventure_done", false)
	if home_done and rp != Vector3.ZERO and Vector2(rp.x, rp.z).length() < 70.0:
		landed = true
		Game.flags.erase("ride_again")
		_portal_awake()
		if ride:
			ride.finished = true
			for rg in rings:
				(rg[0] as Node3D).visible = false

## In the cabin or the Trading Post (no sunshine through the roof, quieter birds).
func indoors(p: Vector3) -> bool:
	return (cabin != null and cabin.is_inside(p)) or (shop != null and shop.is_inside(p))

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, _scen.height(x, z) if _scen else 0.0, z)

# ---------------------------------------------------------------------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.1, 0.2, 0.58)
	psm.sky_horizon_color = Color(1.0, 0.6, 0.36)
	psm.ground_horizon_color = Color(0.9, 0.62, 0.55)
	psm.ground_bottom_color = Color(0.55, 0.5, 0.6)
	psm.sun_angle_max = 25.0
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.95, 0.7, 0.58)
	env.fog_depth_begin = 320.0
	env.fog_depth_end = 1200.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, 180, 0)        # low in the sky, out ahead of you: home is towards the sunset
	sun.light_color = Color(1.0, 0.75, 0.5)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

## Home: the valley from the opening movie, with the cabin, the well and the yard portal.
func _valley() -> void:
	_scen = IntroMovie.new()
	_scen.name = "Valley"
	add_child(_scen)
	_scen.set_process(false)
	_scen._noise.seed = 3; _scen._noise.frequency = 0.02
	# room for the Trading Post and the Forge (no trees there, and a gap in the fence)
	_scen.clear_spots = [Vector2(TradingPost.AT.x, TradingPost.AT.z), Vector2(HomeForge.AT.x, HomeForge.AT.z)]
	_scen._valley()
	_scen._yard_portal()
	# solid ground: the valley floor, the mountains and the cabin
	for c in _scen.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
			var cs := CollisionShape3D.new(); var sh := ConcavePolygonShape3D.new()
			sh.set_faces((c as MeshInstance3D).mesh.get_faces())
			cs.shape = sh; sb.add_child(cs)
			break
	for n in _scen.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var top := m.get_parent()
		while top and top.get_parent() != _scen:
			top = top.get_parent()
		if top is Node3D and (top as Node3D).scale.x > 25.0:      # the mountains (scaled up 30 to 50 times)
			var sb2 := StaticBody3D.new(); sb2.collision_layer = 1; add_child(sb2)
			var cs2 := CollisionShape3D.new(); cs2.shape = m.mesh.create_convex_shape(true, true)
			sb2.add_child(cs2)
			sb2.global_transform = m.global_transform
	var house := StaticBody3D.new(); house.collision_layer = 1; add_child(house)
	var hc := CollisionShape3D.new(); var hb := BoxShape3D.new(); hb.size = Vector3(6.4, 7.0, 6.4)
	hc.shape = hb; hc.position = ground(CABIN.x, CABIN.z) + Vector3(0, 3.5, 0); house.add_child(hc)
	# the yard portal takes you back to where it all began: the Vault outpost
	var pa := Area3D.new(); pa.collision_layer = 0; pa.collision_mask = 2; add_child(pa)
	var pc := CollisionShape3D.new(); var pb := BoxShape3D.new(); pb.size = Vector3(3.4, 4.0, 1.4)
	pc.shape = pb; pa.add_child(pc)
	pa.global_position = ground(IntroMovie.PORTAL.x, IntroMovie.PORTAL.z) + Vector3(0, 2.0, 0)
	pa.rotation_degrees.y = IntroMovie.PORTAL_YAW
	pa.body_entered.connect(func(bd: Node) -> void:
		if bd.is_in_group("player") and landed:
			pa.set_deferred("monitoring", false)
			var sc := get_tree().current_scene
			var done: bool = Game.flags.get("adventure_done", false) or Game.flags.get("home_won", false)
			if (done or not Game.flags.get("port_from", {}).is_empty()) and sc.has_method("family_portal_choice"):
				# you ported home from somewhere: back there, or to the Vault outpost?
				sc.family_portal_choice(func() -> void:
					# stayed home: step back out of the portal; it wakes again in a moment
					var to_door := Vector3(IntroMovie.DOOR.x - IntroMovie.PORTAL.x, 0, IntroMovie.DOOR.z - IntroMovie.PORTAL.z).normalized()
					var at := IntroMovie.PORTAL + to_door * 3.5
					player.global_position = ground(at.x, at.z) + Vector3(0, 0.2, 0)
					player.velocity = Vector3.ZERO
					get_tree().create_timer(1.5).timeout.connect(func() -> void: pa.monitoring = true))
				return
			Sfx.play("portal", 0.0, 0.0)
			FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
			if sc.has_method("go_to_vault"):
				get_tree().create_timer(0.5).timeout.connect(sc.go_to_vault))
	var sg := Label3D.new(); sg.text = "HOME SWEET HOME"; sg.font_size = 72; sg.pixel_size = 0.008; sg.outline_size = 16
	sg.modulate = Color(1.0, 0.9, 0.6); sg.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sg); sg.global_position = ground(LAND.x, LAND.z) + Vector3(-3, 4.5, 3)

func _puff(pos: Vector3, scl: Vector3, col := Color(1, 1, 1)) -> void:
	_puffs.append([Transform3D(Basis().scaled(scl), pos), col])

func _flush_puffs() -> void:
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 10; sm.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = _puffs.size()
	for i in _puffs.size():
		mm.set_instance_transform(i, _puffs[i][0])
		mm.set_instance_color(i, _puffs[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _cloud_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## A sea of sunset clouds under the first part of the flight (it doesn't hold you up).
func _cloud_sea() -> void:
	var x := -280.0
	while x <= 280.0:
		var z := -1320.0
		while z <= -150.0:
			var r := _rng.randf_range(11.0, 16.0)
			var fade := smoothstep(-150.0, -260.0, z)        # thins out towards the mountains
			if _rng.randf() < fade:
				_puff(Vector3(x + _rng.randf_range(-6, 6), SEA_Y - r * 0.3 + _rng.randf_range(-2, 2), z + _rng.randf_range(-6, 6)),
					Vector3(r, r * 0.45, r), Color(1, 1, 1).darkened(_rng.randf_range(0.0, 0.1)))
			z += 24.0
		x += 24.0

func _cloud_island_behind() -> void:
	# Cloud Island, left behind you: a big pile of cloud with the sky temple on top
	var c := Vector3(0, 175, -1230)
	for k in 70:
		var a := _rng.randf() * TAU; var d := sqrt(_rng.randf()) * 34.0
		var r := _rng.randf_range(6.0, 11.0)
		_puff(c + Vector3(cos(a) * d, _rng.randf_range(-6.0, 2.0), sin(a) * d), Vector3(r, r * 0.6, r))
	var sand := StandardMaterial3D.new(); sand.albedo_color = Color(0.93, 0.84, 0.64)
	var lapis := StandardMaterial3D.new(); lapis.albedo_color = Color(0.18, 0.3, 0.75)
	var y := c.y + 2.0
	for st in [[12.0, 3.0], [9.0, 3.0], [6.0, 2.6]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(st[0] * 2.0, st[1], st[0] * 1.6)
		mi.mesh = bm; mi.material_override = sand; add_child(mi); mi.global_position = Vector3(c.x, y + st[1] * 0.5, c.z)
		y += st[1]
	var top := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(6, 3.2, 5)
	top.mesh = tb; top.material_override = lapis; add_child(top); top.global_position = Vector3(c.x, y + 1.6, c.z)

# ---------------------------------------------------------------------------
# The rings
func path_point(t: float) -> Vector3:
	# Catmull-Rom through PATH; t from 0 to 1 over the whole course
	var n := PATH.size() - 1
	var f := clampf(t, 0.0, 0.9999) * n
	var i := int(f)
	var u := f - i
	var p0: Vector3 = PATH[maxi(i - 1, 0)]
	var p1: Vector3 = PATH[i]
	var p2: Vector3 = PATH[mini(i + 1, n)]
	var p3: Vector3 = PATH[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)

# ---------------------------------------------------------------------------
# 3. Thunder Bird Rocks
func _rock(at: Vector3, r: float) -> void:
	var grass := StandardMaterial3D.new(); grass.albedo_color = Color(0.4, 0.6, 0.28)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.5, 0.45, 0.42); stone.roughness = 0.95
	var top := MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = r; tc.bottom_radius = r * 0.92; tc.height = 1.2
	tc.radial_segments = 14
	top.mesh = tc; top.material_override = grass; add_child(top); top.global_position = at - Vector3(0, 0.6, 0)
	var under := MeshInstance3D.new(); var uc := CylinderMesh.new(); uc.top_radius = r * 0.92; uc.bottom_radius = 0.6; uc.height = r * 1.6
	uc.radial_segments = 10
	under.mesh = uc; under.material_override = stone; add_child(under); under.global_position = at - Vector3(0, 1.2 + r * 0.8, 0)
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = r; cy.height = 1.2
	cs.shape = cy; sb.add_child(cs); sb.global_position = at - Vector3(0, 0.6, 0)

# ---------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new(); _hud.layer = 5; add_child(_hud)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 54)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	_banner.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.0))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_hud.add_child(_banner)

func _show_banner(txt: String) -> void:
	_banner.text = txt
	await get_tree().process_frame
	_banner.position.x = (_banner.get_viewport_rect().size.x - _banner.size.x) * 0.5
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.5)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)

# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if player == null:
		return
	player.free_flight = true
	player.kill_y = -60.0
	# (the Sky Ride shows the score, rings and the names of the parts of the course)

func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		return
	var pp := player.global_position
	# always on your dragonfly while you're up in the sky
	if not landed and not player.mounted and not player.is_on_floor() and player.input_enabled and pp.z < -10.0:
		player.mount_up("dragonfly")
	# the Sky Ride starts as soon as you're up and away on your dragonfly
	if ride and not ride.riding and not ride.finished and not landed and player.mounted and player.mount_kind == "dragonfly" and player.input_enabled:
		ride.start()
	# through the waterfall
	if not _splashed and Vector2(pp.x - _waterfall_x.x, pp.z - _waterfall_x.z).length() < 4.0 and pp.y < _waterfall_x.y and pp.y > _waterfall_x.y - 40.0:
		_splashed = true
		Sfx.play("splash", 0.0, 0.1)
		FX.burst(pp + Vector3(0, 1, 0), Color(0.75, 0.9, 1.0), 60, 6.0, 0.2, 0.6, -4.0)
		Game.say("SPLASH! Right through the waterfall!", Color(0.7, 0.9, 1.0))
	# fell into the sea of clouds: your dragonfly swoops you back to the last ring
	if pp.y < SEA_Y - 6.0 and pp.z < -150.0 and pp.y > -20.0:
		player.global_position = checkpoint + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		player.wing_stamina = maxf(player.wing_stamina, 0.6)
		player.wings_tired = false
		FX.burst(player.global_position, Color(1.0, 0.95, 0.85), 40, 4.0, 0.2, 0.6, 0.0)
		Game.say("Whoosh! Your dragonfly swoops back up to the last ring.", Color(0.6, 1.0, 0.85))
	# landing at home
	if not landed and player.is_on_floor() and Vector2(pp.x - LAND.x, pp.z - LAND.z).length() < 26.0 and pp.y < 12.0:
		_land()

func _land() -> void:
	landed = true
	if ride and ride.riding:
		ride._finish()
	player.free_flight = false
	if player.mounted:
		player.dismount()
	Sfx.music("music_morning", -12.0)
	Sfx.play("victory", -2.0, 0.0)
	FX.screen_flash(Color(1.0, 0.92, 0.75), 0.6, 1.0)
	for k in 8:
		get_tree().create_timer(0.4 * k).timeout.connect(func() -> void:
			var at := ground(LAND.x, LAND.z) + Vector3(randf_range(-14, 14), randf_range(14, 24), randf_range(-10, 14))
			FX.burst(at, Color.from_hsv(randf(), 0.7, 1.0), 70, 9.0, 0.25, 1.2, -2.0)
			Sfx.play_at("pop", at, -2.0, 0.3))
	Game.say("You're HOME! %d of %d rings. What an adventure!" % [rings_passed, rings.size()], Color(1.0, 0.88, 0.5))
	if ride and ride.missed <= 2:
		Game.say("A perfect flight! The sky leaves a gift by the door.", Color(1.0, 0.9, 0.6))
		Interactable.create(self, "chest", ground(2.5, 6.5), 180.0, "home_chest", [{"roll": "boss", "ilvl": 14}])
	Game.on_quest_item("home")
	if Game.flags.has("ride_again"):
		Game.flags.erase("ride_again")
		Game.set_objective(Game.forest_objective())
	var first := Game.quest_state("flight_home") == "ready"
	if first:
		Game.quest_turn_in("flight_home")
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			Game.say("NEW! Port Home: tap HOME (or press Y) to whoosh back to your cabin from anywhere.", Color(0.5, 1.0, 0.8)))
	_portal_awake()

func _portal_awake() -> void:
	if _scen and _scen._portal_mat:
		_scen._portal_mat.set_shader_parameter("intensity", 2.0)
	var lbl := Label3D.new(); lbl.text = "The family portal\n(back to the Vault outpost)"; lbl.font_size = 48; lbl.pixel_size = 0.006
	var pf: Dictionary = Game.flags.get("port_from", {})
	if Game.flags.get("adventure_done", false):
		lbl.text = "The family portal\n(any level, or a new adventure)"
	elif not pf.is_empty():
		lbl.text = "The family portal\n(back to %s, or the Vault outpost)" % Game.PLACE_NAMES.get(String(pf.get("zone", "")), "where you were")
	lbl.outline_size = 12; lbl.modulate = Color(0.6, 1.0, 0.85); lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(lbl); lbl.global_position = ground(IntroMovie.PORTAL.x, IntroMovie.PORTAL.z) + Vector3(0, 6.2, 0)

func reset_boss() -> void:
	pass
