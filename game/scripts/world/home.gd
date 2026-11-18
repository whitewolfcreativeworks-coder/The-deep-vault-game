extends Node3D
class_name HomeWorld
## THE FLIGHT HOME: the last quest of the base game. After Mr. Bubbles is calmed,
## Anu opens the Sky Gate and you ride your dragonfly all the way home, through
## a flying course at sunset, to the cabin where the adventure began.
##
##   1. Sky School: golden rings teach you to fly (JUMP climbs, let go to glide,
##      BLOCK dives). Green rings rest your dragonfly's wings.
##   2. The Storm Gate: lightning strikes the rings; watch for the glowing columns.
##   3. Thunder Bird Rocks: floating rocks where thunder birds nest. They chase
##      you into the sky: fight them from your dragonfly, or outfly them.
##   4. The Floating Lake: fly straight through its waterfall.
##   5. Home Valley: over the mountains and spiral down to the cabin.
## Fall into the sea of clouds and your dragonfly catches you at the last ring.

signal area_changed(area: String)

var player: Player
var spawn_point := Vector3(0, 200, -1120)
var spawn_yaw := PI                   # facing +z: towards home
var env: Environment
var sun: DirectionalLight3D
var area := ""
var rings: Array = []                 # [Node3D, centre, normal, kind ("gold"/"rest"/"home"), passed]
var rings_passed := 0
var checkpoint := Vector3(0, 200, -1120)
var landed := false
var _cloud_mat: ShaderMaterial
var _puffs: Array = []
var _scen: IntroMovie
var _bolts: Array = []                # [centre, timer, column node]
var _hud: CanvasLayer
var _ring_label: Label
var _banner: Label
var _rng := RandomNumberGenerator.new()
var _waterfall_x := Vector3.ZERO
var _splashed := false

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
const SECTIONS := [[-1200.0, "SKY SCHOOL"], [-850.0, "THE STORM GATE"], [-640.0, "THUNDER BIRD ROCKS"], [-470.0, "THE FLOATING LAKE"], [-200.0, "HOME VALLEY"]]
const SEA_Y := 40.0

func build() -> void:
	_rng.seed = 77
	_cloud_mat = ShaderMaterial.new(); _cloud_mat.shader = load("res://shaders/cloud.gdshader")
	_cloud_mat.set_shader_parameter("tint", Color(1.0, 0.94, 0.88)); _cloud_mat.set_shader_parameter("shade", Color(0.62, 0.55, 0.72))
	_cloud_mat.set_shader_parameter("rim_glow", 0.4)
	_environment()
	_valley()
	_cloud_sea()
	_cloud_island_behind()
	_course()
	_storm_gate()
	_bird_rocks()
	_floating_lake()
	_flush_puffs()
	_make_hud()
	if Game.is_compat():
		for l in find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				(l as Light3D).shadow_enabled = false

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, _scen.height(x, z) if _scen else 0.0, z)

# ---------------------------------------------------------------------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.2, 0.32, 0.72)
	psm.sky_horizon_color = Color(1.0, 0.68, 0.45)
	psm.ground_horizon_color = Color(0.95, 0.72, 0.6)
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
	env.fog_light_color = Color(1.0, 0.78, 0.62)
	env.fog_depth_begin = 160.0
	env.fog_depth_end = 700.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, 180, 0)        # low in the sky, out ahead of you: home is towards the sunset
	sun.light_color = Color(1.0, 0.75, 0.5)
	sun.light_energy = 1.25
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
			Sfx.play("portal", 0.0, 0.0)
			FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
			var sc := get_tree().current_scene
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

func _course() -> void:
	# rings roughly every 30 m along the path; every fifth one is a green rest ring
	var samples := 900
	var acc := 0.0
	var prev := path_point(0.0)
	var k := 0
	for i in range(1, samples):
		var t := float(i) / samples
		var p := path_point(t)
		acc += p.distance_to(prev)
		prev = p
		if acc >= 30.0 and t < 0.985:
			acc = 0.0
			var ahead := path_point(minf(t + 0.004, 1.0))
			var nrm := (ahead - p).normalized()
			var kind := "rest" if k % 5 == 4 else "gold"
			_ring(p, nrm, kind)
			k += 1
	# the last ring: a big welcome-home arch over the yard
	var home := ground(LAND.x, LAND.z) + Vector3(0, 4.0, 0)
	_ring(home, (home - path_point(0.97)).normalized() * Vector3(1, 0, 1), "home")

func _ring(at: Vector3, nrm: Vector3, kind: String) -> void:
	var n := Node3D.new(); add_child(n); n.global_position = at
	var r := 4.6 if kind != "home" else 6.0
	var tor := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = r - 0.35; tm.outer_radius = r
	tm.rings = 32; tm.ring_segments = 10
	tor.mesh = tm
	var col := {"gold": Color(1.0, 0.82, 0.35), "rest": Color(0.45, 1.0, 0.6), "home": Color(1.0, 0.6, 0.8)}[kind] as Color
	tor.material_override = FX.beam_material(col, 2.2, 0.9, false)
	tor.rotation.x = PI * 0.5                  # the torus lies flat; stand it up to face along +z
	n.add_child(tor)
	var nn := nrm.normalized() if nrm.length() > 0.01 else Vector3.BACK
	n.look_at(at + nn, Vector3.UP if absf(nn.y) < 0.95 else Vector3.RIGHT)
	var sp := CPUParticles3D.new(); sp.amount = 16; sp.lifetime = 1.4
	sp.mesh = FX.quad(0.14); sp.material_override = FX.glow_material(col, 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; sp.emission_ring_axis = Vector3(0, 0, 1)
	sp.emission_ring_radius = r; sp.emission_ring_inner_radius = r - 0.4; sp.emission_ring_height = 0.1
	sp.gravity = Vector3.ZERO; sp.spread = 180; sp.initial_velocity_max = 0.4; sp.color_ramp = FX._fade_ramp(col)
	n.add_child(sp)
	if kind == "home":
		var lbl := Label3D.new(); lbl.text = "WELCOME HOME"; lbl.font_size = 96; lbl.pixel_size = 0.01; lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.85, 0.9); lbl.position.y = r + 1.2; lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		n.add_child(lbl)
	rings.append([n, at, nn, kind, false, r])

func _ring_step() -> void:
	var pp := player.global_position + Vector3(0, 1.0, 0)
	for rg in rings:
		if rg[4]:
			continue
		var c: Vector3 = rg[1]
		var rel := pp - c
		var along: float = rel.dot(rg[2])
		var side := (rel - (rg[2] as Vector3) * along).length()
		if absf(along) < 1.6 and side < float(rg[5]):
			rg[4] = true
			rings_passed += 1
			var n: Node3D = rg[0]
			if rg[3] != "home":
				checkpoint = c
			match String(rg[3]):
				"rest":
					player.wing_stamina = minf(1.0, player.wing_stamina + 0.6)
					player.wings_tired = false
					Game.say("A rest ring! Your dragonfly's wings feel fresh again.", Color(0.5, 1.0, 0.65))
				"home":
					Game.say("WELCOME HOME! Now land in the yard.", Color(1.0, 0.85, 0.9))
			Sfx.play("pickup", -4.0, 0.0)
			FX.burst(c, (Color(1.0, 0.9, 0.5) if rg[3] == "gold" else Color(0.5, 1.0, 0.65)), 40, 6.0, 0.15, 0.6, 0.0)
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 1.6, 0.35)
			tw.tween_property(n, "scale", Vector3.ONE * 0.05, 0.25)
			tw.tween_callback(n.queue_free)
			Game.add_gold(3)
			if rings_passed in [1, 3, 6, 9]:
				_tutorial(rings_passed)

func _tutorial(n: int) -> void:
	match n:
		1: Game.say("Fly through the golden rings! Hold JUMP to climb, let go to glide.", Color(1.0, 0.92, 0.6))
		3: Game.say("Too high? Hold BLOCK to dive down faster.", Color(1.0, 0.92, 0.6))
		6: Game.say("Green rings rest your dragonfly's wings. Don't climb too much, or it gets tired!", Color(0.6, 1.0, 0.7))
		9: Game.say("You're a natural! Follow the rings home.", Color(1.0, 0.92, 0.6))

# ---------------------------------------------------------------------------
# 2. The Storm Gate: storm clouds and lightning
func _storm_gate() -> void:
	for k in 40:
		var t := _rng.randf_range(0.27, 0.42)
		var p := path_point(t) + Vector3(_rng.randf_range(-45, 45), _rng.randf_range(8, 24), _rng.randf_range(-10, 10))
		var r := _rng.randf_range(5.0, 9.0)
		_puff(p, Vector3(r, r * 0.6, r), Color(0.45, 0.42, 0.55))
	for k in 6:
		var t := 0.28 + k * 0.024
		var c := path_point(t) + Vector3(_rng.randf_range(-6, 6), 0, 0)
		var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.6; cm.bottom_radius = 2.6; cm.height = 40.0
		cm.cap_top = false; cm.cap_bottom = false
		col.mesh = cm; col.material_override = FX.beam_material(Color(1.0, 0.95, 0.4), 1.5, 0.5, true)
		col.visible = false; col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(col); col.global_position = c
		_bolts.append([c, _rng.randf_range(0.5, 3.0), col])

func _bolt_step(delta: float) -> void:
	for b in _bolts:
		b[1] -= delta
		var col: MeshInstance3D = b[2]
		if b[1] <= 0.0:
			if not col.visible:
				col.visible = true                 # warning: the column glows
				b[1] = 1.0
			else:
				col.visible = false
				b[1] = _rng.randf_range(2.0, 3.5)
				var c: Vector3 = b[0]
				FX.beam(c + Vector3(0, 22, 0), c - Vector3(0, 18, 0), Color(1.0, 0.97, 0.6), 0.5, 0.35)
				FX.flash_light(c, Color(1.0, 0.95, 0.6), 10.0, 30.0, 0.3)
				Sfx.play_at("thunder", c, -2.0, 0.1)
				var pp := player.global_position
				if Vector2(pp.x - c.x, pp.z - c.z).length() < 3.2 and absf(pp.y - c.y) < 20.0:
					player.take_damage(Game.max_hp() * 0.12, c, 3.0)
					Game.say("ZAP! Watch for the glowing columns: lightning strikes there next!", Color(1.0, 0.9, 0.4))

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

func _bird_rocks() -> void:
	for k in 5:
		var t := 0.46 + k * 0.03
		var side := -1.0 if k % 2 == 0 else 1.0
		var at := path_point(t) + Vector3(side * _rng.randf_range(14.0, 20.0), -_rng.randf_range(6.0, 10.0), 0)
		_rock(at, _rng.randf_range(5.0, 7.0))
		# a straw nest, and a thunder bird that lives there
		var nest := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 1.2
		var straw := StandardMaterial3D.new(); straw.albedo_color = Color(0.8, 0.65, 0.35)
		nest.mesh = tm; nest.material_override = straw; add_child(nest); nest.global_position = at + Vector3(0, 0.15, 0)
		var e := Enemy.new()
		e.configure("thunder_bird", "", 0.0)
		e.position = at + Vector3(0, 0.4, 0)
		add_child(e)

# ---------------------------------------------------------------------------
# 4. The Floating Lake and its waterfall
func _floating_lake() -> void:
	var t := 0.62
	var p := path_point(t)
	var at := p + Vector3(-26.0, 10.0, 0)
	_rock(at, 16.0)
	var water := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = 12.0; wc.bottom_radius = 12.0; wc.height = 0.1
	wc.radial_segments = 32
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.3, 0.6, 0.9, 0.8); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05; wm.metallic = 0.3; wm.emission_enabled = true; wm.emission = Color(0.1, 0.3, 0.5); wm.emission_energy_multiplier = 0.4
	water.mesh = wc; water.material_override = wm; add_child(water); water.global_position = at + Vector3(0, 0.05, 0)
	# the waterfall pours off the east edge, right across the flight path
	_waterfall_x = Vector3(p.x, at.y, p.z)
	var fall := CPUParticles3D.new(); fall.amount = 260; fall.lifetime = 2.2
	fall.mesh = FX.quad(0.3); fall.material_override = FX.glow_material(Color(0.75, 0.88, 1.0), 0.7)
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; fall.emission_box_extents = Vector3(0.6, 0.2, 3.0)
	fall.direction = Vector3(0.6, -1, 0); fall.spread = 6; fall.initial_velocity_min = 3.0; fall.initial_velocity_max = 5.0
	fall.gravity = Vector3(0, -14, 0); fall.scale_amount_min = 1.0; fall.scale_amount_max = 2.5
	add_child(fall); fall.global_position = Vector3(at.x + 16.0, at.y, p.z)
	var sheet := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(6.0, 40.0)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.7, 0.85, 1.0, 0.35); sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.emission_enabled = true; sm.emission = Color(0.5, 0.7, 0.9); sm.emission_energy_multiplier = 0.4
	sheet.mesh = qm; sheet.material_override = sm; add_child(sheet)
	sheet.global_position = Vector3(p.x, at.y - 20.0, p.z); sheet.rotation.y = PI * 0.5
	var mist := CPUParticles3D.new(); mist.amount = 30; mist.lifetime = 3.0
	mist.mesh = FX.quad(3.0); mist.material_override = FX.glow_material(Color(0.9, 0.95, 1.0), 0.3)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; mist.emission_sphere_radius = 4.0
	mist.gravity = Vector3(0, 0.5, 0); mist.spread = 180; mist.initial_velocity_max = 1.0
	add_child(mist); mist.global_position = Vector3(p.x, at.y - 30.0, p.z)

# ---------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new(); _hud.layer = 5; add_child(_hud)
	_ring_label = Label.new()
	_ring_label.add_theme_font_size_override("font_size", 26)
	_ring_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_ring_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_ring_label.add_theme_constant_override("outline_size", 8)
	_ring_label.position = Vector2(24, 300)
	_hud.add_child(_ring_label)
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
	var pp := player.global_position
	var here := ""
	for sec in SECTIONS:
		if pp.z > float(sec[0]):
			here = String(sec[1])
	if here != area and player.input_enabled and not landed:
		area = here
		area_changed.emit(area)
		_show_banner(area)
	_ring_label.text = "" if landed else "RINGS  %d / %d" % [rings_passed, rings.size()]

func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		return
	var pp := player.global_position
	# always on your dragonfly while you're up in the sky
	if not landed and not player.mounted and not player.is_on_floor() and player.input_enabled and pp.z < -10.0:
		player.mount_up("dragonfly")
	_ring_step()
	_bolt_step(delta)
	# through the waterfall
	if not _splashed and Vector2(pp.x - _waterfall_x.x, pp.z - _waterfall_x.z).length() < 4.0 and pp.y < _waterfall_x.y and pp.y > _waterfall_x.y - 40.0:
		_splashed = true
		Sfx.play("splash", 0.0, 0.1)
		FX.burst(pp + Vector3(0, 1, 0), Color(0.75, 0.9, 1.0), 60, 6.0, 0.2, 0.6, -4.0)
		Game.say("SPLASH! Right through the waterfall!", Color(0.7, 0.9, 1.0))
	# fell into the sea of clouds: your dragonfly swoops you back to the last ring
	if pp.y < SEA_Y - 6.0 and pp.z < -150.0:
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
	if rings_passed >= rings.size() - 2:
		Game.say("A perfect flight! The sky leaves a gift by the door.", Color(1.0, 0.9, 0.6))
		Interactable.create(self, "chest", ground(2.5, 6.5), 180.0, "home_chest", [{"roll": "boss", "ilvl": 14}])
	Game.on_quest_item("home")
	if Game.quest_state("flight_home") == "ready":
		Game.quest_turn_in("flight_home")
	_portal_awake()

func _portal_awake() -> void:
	if _scen and _scen._portal_mat:
		_scen._portal_mat.set_shader_parameter("intensity", 2.0)
	var lbl := Label3D.new(); lbl.text = "The family portal\n(back to the Vault outpost)"; lbl.font_size = 48; lbl.pixel_size = 0.006
	lbl.outline_size = 12; lbl.modulate = Color(0.6, 1.0, 0.85); lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(lbl); lbl.global_position = ground(IntroMovie.PORTAL.x, IntroMovie.PORTAL.z) + Vector3(0, 6.2, 0)

func reset_boss() -> void:
	pass
