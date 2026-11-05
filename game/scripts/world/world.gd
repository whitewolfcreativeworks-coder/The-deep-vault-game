extends Node3D
class_name VaultWorld
## Builds the whole adventure: the ruined outpost at dusk and the Deep Vault
## (entry hall, fire-vent corridor, armory, the Glowing Deep river cavern,
## and the Warden's sanctum), then runs area atmosphere and story beats.
##
## Layout (metres). Forward is -Z. Outpost y=0, the Vault floor is y=-6.
##   Outpost       z  +44 .. -2
##   Stair tunnel  z   -2 .. -12
##   Entry Hall    z  -12 .. -34   x -9..9
##   Vent Corridor z  -34 .. -60   x -2..2
##   Armory        z  -60 .. -84   x -11..11
##   Passage       z  -84 .. -92
##   Glowing Deep  z  -92 .. -134  x -22..22   river z -116..-108
##   Sanctum hall  z -134 .. -142
##   Sanctum       z -142 .. -172  x -15..15

signal area_changed(area: String)

const Y := -6.0
var b: Builder
var env: Environment
var sun: DirectionalLight3D
var area := ""
var player: Player
var corridor_traps: Array[FireTrap] = []
var corridor_gate: Gate
var boss_gate: Gate
var warden: Warden
var altar: Interactable
var boss_started := false
var rivers: Array[GlowRiver] = []
var spawn_point := Vector3(-22.5, 0.1, 25.0)   # inside the arrival portal (west side area)
var spawn_yaw := -1.15                          # facing out of the portal toward the vault gate
const ARRIVAL := Vector3(-24.0, 0, 25.0)
var hall_woken := false

func build() -> void:
	b = Builder.new(self)
	_environment()
	_outpost()
	_tunnel()
	_entry_hall()
	_corridor()
	_armory()
	_glowing_deep()
	_sanctum()
	b.fix_coplanar()
	if Game.is_compat():
		_tune_for_compat()

## Browser / OpenGL renderer: no positional shadows (each costs extra passes),
## gentler glow, and brighter ambient since there is no volumetric fog or SSAO.
func _tune_for_compat() -> void:
	for l in find_children("*", "Light3D", true, false):
		if l is OmniLight3D or l is SpotLight3D:
			(l as Light3D).shadow_enabled = false
	env.glow_intensity = 0.55
	env.glow_hdr_threshold = 1.2
	env.tonemap_exposure = 1.25

# ---------------------------------------------------------------------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.05, 0.07, 0.16)
	psm.sky_horizon_color = Color(0.55, 0.32, 0.30)
	psm.sky_curve = 0.12
	psm.ground_bottom_color = Color(0.03, 0.03, 0.04)
	psm.ground_horizon_color = Color(0.3, 0.2, 0.2)
	psm.sun_angle_max = 12.0
	psm.sky_energy_multiplier = 0.9
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.30, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(2, 1.0); env.set_glow_level(3, 0.8); env.set_glow_level(4, 0.6); env.set_glow_level(5, 0.4)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.25, 0.22, 0.32)
	env.fog_density = 0.01
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 140.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.7, 0.7, 0.8)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()   # the rising moon over the outpost
	sun.rotation_degrees = Vector3(-28, -150, 0)
	sun.light_color = Color(0.62, 0.68, 0.95)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_volumetric_fog_energy = 0.4
	add_child(sun)

func _set_area(a: String) -> void:
	if a == area:
		return
	area = a
	area_changed.emit(a)
	var tw := create_tween().set_parallel(true)
	var amb := Color(0.32, 0.30, 0.42); var amb_e := 0.55
	var vf := 0.012; var vf_alb := Color(0.7, 0.7, 0.8); var vf_em := Color.BLACK
	var fog_c := Color(0.25, 0.22, 0.32)
	match a:
		"outpost":
			Sfx.music("music_explore", -16.0)
		"vault":
			amb = Color(0.34, 0.31, 0.36); amb_e = 0.85
			vf = 0.03; vf_alb = Color(0.6, 0.6, 0.65); fog_c = Color(0.05, 0.05, 0.07)
			Sfx.music("music_explore", -14.0)
		"deep":
			amb = Color(0.22, 0.40, 0.48); amb_e = 0.7
			vf = 0.035; vf_alb = Color(0.55, 0.8, 0.9); vf_em = Color(0.0, 0.025, 0.035); fog_c = Color(0.02, 0.06, 0.08)
			Sfx.music("music_explore", -14.0)
		"sanctum":
			amb = Color(0.40, 0.31, 0.27); amb_e = 0.8
			vf = 0.03; vf_alb = Color(0.8, 0.65, 0.55); vf_em = Color(0.02, 0.008, 0.0); fog_c = Color(0.06, 0.04, 0.03)
	sun.visible = a == "outpost"
	tw.tween_property(env, "ambient_light_color", amb, 1.5)
	tw.tween_property(env, "ambient_light_energy", amb_e, 1.5)
	tw.tween_property(env, "volumetric_fog_density", vf, 1.5)
	tw.tween_property(env, "volumetric_fog_albedo", vf_alb, 1.5)
	tw.tween_property(env, "volumetric_fog_emission", vf_em, 1.5)
	tw.tween_property(env, "fog_light_color", fog_c, 1.5)

func _process(_delta: float) -> void:
	if player == null:
		return
	var z := player.global_position.z
	var a := "outpost"
	if z < -6.0:
		a = "vault"
	if z < -90.0:
		a = "deep"
	if z < -134.0:
		a = "sanctum"
	_set_area(a)
	_story(z)

# ---------------------------------------------------------------------------
var _beats := {}
func _beat(id: String) -> bool:
	if _beats.has(id):
		return false
	_beats[id] = true
	return true

func _story(z: float) -> void:
	if Game.game_over:
		return
	if z < -12.0 and _beat("enter"):
		Game.set_objective("Explore the Entry Hall.")
		Game.say("The air is cold and tastes of old stone.", Color(0.8, 0.8, 0.85))
	if z < -34.5 and _beat("corridor"):
		Game.set_objective("Time your run through the fire vents and pull the lever.")
	if z < -61.0 and _beat("armory"):
		Game.set_objective("Defeat the Armory's guardians and claim its gear.")
	if z < -93.0 and _beat("deep"):
		Game.set_objective("Cross the Glowing Deep. Something glints on the island.")
		Game.say("A river of living light winds through the cavern...", Color(0.5, 0.9, 1.0))
	if z < -146.0 and not boss_started and not Game.flags.get("warden_dead", false):
		_start_boss()

# ---------------------------------------------------------------------------
func _outpost() -> void:
	# the ancient portal you arrive through (from the opening movie), in the west side area
	var arch: Node3D = (load("res://assets/kaykit/forest/arch_gate.gltf") as PackedScene).instantiate()
	add_child(arch)
	arch.position = ARRIVAL + Vector3(0, -0.05, 0)
	arch.rotation_degrees.y = 90.0
	arch.scale = Vector3.ONE * 1.5
	for side in ["arch_gate_left", "arch_gate_right"]:
		var gate := arch.find_child(side, true, false)
		if gate:
			gate.visible = false
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2); disc.mesh = q
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/portal.gdshader"); pm.set_shader_parameter("intensity", 1.2)
	disc.material_override = pm; disc.position = ARRIVAL + Vector3(0, 3.0, 0); disc.rotation_degrees.y = 90.0; add_child(disc)
	var pl := OmniLight3D.new(); pl.light_color = Color(0.4, 1.0, 0.8); pl.light_energy = 2.0; pl.omni_range = 9.0
	pl.position = ARRIVAL + Vector3(1.5, 3.0, 0); add_child(pl)
	var ring := MeshInstance3D.new(); var rc := CylinderMesh.new(); rc.top_radius = 2.4; rc.bottom_radius = 2.6; rc.height = 0.12
	ring.mesh = rc; ring.material_override = b.mats.cobble; ring.position = ARRIVAL + Vector3(1.4, 0.03, 0); add_child(ring)
	# a short worn path from the portal through the gap in the ruined wall
	b.box(Vector3(-22, -0.97, 23.5), Vector3(-11, 0.025, 26.5), b.mats.cobble, false)
	# the stone back wall behind the portal so you can't walk round into nothing
	var asb := StaticBody3D.new(); add_child(asb)
	var acs := CollisionShape3D.new(); var abs := BoxShape3D.new(); abs.size = Vector3(1.0, 6.5, 6.5)
	acs.shape = abs; acs.position = ARRIVAL + Vector3(-0.8, 3.2, 0); asb.add_child(acs)
	# ground and boundary
	b.box(Vector3(-40, -1, -2), Vector3(40, 0, 50), b.mats.cliff)
	b.box(Vector3(-11, -0.98, 4), Vector3(11, 0.02, 32), b.mats.cobble, false)
	# cliff face with the vault entrance cut into it
	b.box(Vector3(-40, -8, -18), Vector3(-2.5, 18, -2), b.mats.cliff)
	b.box(Vector3(2.5, -8, -18), Vector3(40, 18, -2), b.mats.cliff)
	b.box(Vector3(-2.5, 5.0, -18), Vector3(2.5, 18, -2), b.mats.cliff)
	# a jagged, layered cliff silhouette
	for i in 9:
		var x := -36.0 + i * 9.0
		var h := 18.0 + fmod(i * 7.3, 9.0)
		b.box(Vector3(x - 5, 0, -26 - fmod(i * 3.1, 6.0)), Vector3(x + 5, h, -12), b.mats.cliff)
	# side and rear hills keep the player in the clearing
	b.box(Vector3(-41, -1, -2), Vector3(-34, 7, 50), b.mats.cliff)
	b.box(Vector3(34, -1, -2), Vector3(41, 7, 50), b.mats.cliff)
	b.box(Vector3(-41, -1, 44), Vector3(41, 6, 51), b.mats.cliff)
	for i in 8:
		var x2 := -30.0 + i * 8.5
		b.box(Vector3(x2 - 4, 0, 42 - fmod(i * 1.7, 3.0)), Vector3(x2 + 3, 4 + fmod(i * 2.3, 4.0), 46), b.mats.rock)
	# carved entrance arch
	var brick: Material = b.wall_mat(Color(0.38, 0.35, 0.32), 0.3, 0.0)
	b.box(Vector3(-3.6, 0, -2.6), Vector3(-2.5, 5.4, -1.2), brick)
	b.box(Vector3(2.5, 0, -2.6), Vector3(3.6, 5.4, -1.2), brick)
	b.box(Vector3(-3.9, 5.0, -2.8), Vector3(3.9, 6.2, -1.0), brick)
	var sigil := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(1.6, 1.6); sigil.mesh = sq
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/rune.gdshader")
	sm.set_shader_parameter("color", Color(0.3, 0.75, 1.0)); sm.set_shader_parameter("intensity", 1.2)
	sigil.material_override = sm; sigil.position = Vector3(0, 7.2, -1.95)
	add_child(sigil)
	Props.torch(self, Vector3(-4.2, 2.6, -1.9), 0.0, true, true)
	Props.torch(self, Vector3(4.2, 2.6, -1.9), 0.0, true, false)
	# ruined walls and an abandoned camp
	for p in [[Vector3(-14, 0, 12), 90.0, "wall_broken"], [Vector3(-14, 0, 16), 90.0, "wall_cracked"], [Vector3(-14, 0, 20), 90.0, "wall_half"],
			[Vector3(14, 0, 10), -90.0, "wall_broken"], [Vector3(14, 0, 14), -90.0, "wall"], [Vector3(14, 0, 22), -90.0, "wall_half"],
			[Vector3(-10, 0, 34), 180.0, "wall_broken"], [Vector3(10, 0, 34), 180.0, "wall_half"], [Vector3(-6, 0, 34), 180.0, "wall_cracked"]]:
		Props.place(self, p[2], p[0], p[1], 1.0, true)
	for p in [Vector3(-12, 0, 4), Vector3(12, 0, 4), Vector3(-12, 0, 28), Vector3(12, 0, 28)]:
		Props.place(self, "pillar", p, 0.0, 1.0, true)
	Props.place(self, "rubble_large", Vector3(-11, 0, 8), 30.0)
	Props.place(self, "rubble_half", Vector3(10, 0, 26), -40.0)
	Props.place(self, "rubble_large", Vector3(8.5, 0, 2.5), 120.0)
	_tent(Vector3(-7, 0, 22), 20.0, Color(0.45, 0.38, 0.28))
	_tent(Vector3(7.5, 0, 25), -30.0, Color(0.35, 0.18, 0.15))
	_campfire(Vector3(1.5, 0, 19))
	Props.place(self, "table_medium_broken", Vector3(-4, 0, 16), 15.0, 1.0, true)
	Props.place(self, "stool", Vector3(-2.6, 0, 17.4), 40.0)
	Props.place(self, "barrel_large", Vector3(-9, 0, 26), 0.0, 1.0, true)
	Props.place(self, "barrel_small_stack", Vector3(-8.5, 0, 28), 50.0, 1.0, true)
	Props.place(self, "crates_stacked", Vector3(9.5, 0, 18), -20.0, 1.0, true)
	Props.place(self, "box_large", Vector3(8.2, 0, 16.5), 10.0, 1.0, true)
	Props.place(self, "keg", Vector3(5.5, 0, 22.5), 0.0, 1.0, true)
	Props.place(self, "banner_patternA_red", Vector3(-12, 0, 4), 90.0)
	Props.place(self, "trunk_medium_A", Vector3(-6, 0, 24.5), 20.0, 1.0, true)
	Props.place(self, "sword_shield_broken", Vector3(3.5, 0, 6), 160.0)
	Interactable.create(self, "inscription", Vector3(-3.0, 0, 20.5), 200.0, "", [], "A torn journal",
		"Day 9. Corwin went down alone. Said the Warden only stirs for those who reach the Heart.\n\nDay 11. Blue light from the stair at night. The river below the vault is alive, I am sure of it. It burns the skin... but Corwin swore an amulet was made to walk it.\n\nDay 12. No sign of Corwin. I am going in after him. If you find this, the fire vents breathe in rhythm. Watch them, and run between their breaths.")
	Interactable.create(self, "chest", Vector3(-9.5, 0, 22.5), 90.0, "chest_camp", [{"kind": "potion", "amount": 1}, {"roll": "small"}])
	Interactable.create(self, "shrine", Vector3(-5.5, 0, 5.5), 0.0, "", [], "the Outpost")
	# moonlit motes over the clearing
	var dust := _motes(Vector3(0, 3, 18), Vector3(18, 3, 16), Color(0.8, 0.85, 1.0), 120, 0.05)
	dust.position = Vector3(0, 3, 18)

func _tent(pos: Vector3, yaw: float, col: Color) -> void:
	var n := Node3D.new(); add_child(n); n.position = pos; n.rotation_degrees.y = yaw
	var mi := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(3.0, 2.0, 3.4)
	mi.mesh = pm
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m; mi.position.y = 1.0
	n.add_child(mi)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(2.6, 1.6, 3.4)
	cs.shape = bs; cs.position.y = 0.8; sb.add_child(cs); n.add_child(sb)

func _campfire(pos: Vector3) -> void:
	var n := Node3D.new(); add_child(n); n.position = pos
	for i in 8:
		var a := i * TAU / 8.0
		var r := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.22; sm.height = 0.3
		r.mesh = sm; r.material_override = b.mats.rock
		r.position = Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75)
		n.add_child(r)
	for i in 4:
		var l := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 1.0
		l.mesh = cm
		var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.22, 0.13, 0.07)
		wm.emission_enabled = true; wm.emission = Color(1.0, 0.3, 0.05); wm.emission_energy_multiplier = 0.6
		l.material_override = wm
		l.rotation = Vector3(PI / 2.4, i * PI / 2.0, 0); l.position.y = 0.25
		n.add_child(l)
	var fire := Node3D.new(); fire.position.y = 0.35; n.add_child(fire)
	Props.fire_particles(fire, 2.2, Color(1.0, 0.55, 0.2), true)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.28); light.light_energy = 3.2; light.omni_range = 14.0
	light.shadow_enabled = true; light.position.y = 1.2
	light.light_volumetric_fog_energy = 1.0
	light.set_script(load("res://scripts/world/flicker.gd"))
	n.add_child(light)
	Sfx.loop_on(n, "loop_fire", -6.0, 4.0, 22.0)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.9; cy.height = 0.5
	cs.shape = cy; cs.position.y = 0.25; sb.add_child(cs); n.add_child(sb)

func _motes(center: Vector3, extents: Vector3, col: Color, count: int, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count; p.lifetime = 8.0; p.preprocess = 8.0
	p.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = extents
	ppm.direction = Vector3(0.2, 1, 0.1); ppm.spread = 60
	ppm.initial_velocity_min = 0.05; ppm.initial_velocity_max = 0.25
	ppm.gravity = Vector3(0, 0.02, 0)
	ppm.turbulence_enabled = true; ppm.turbulence_noise_strength = 0.8
	var ramp := Gradient.new(); ramp.set_color(0, Color(1, 1, 1, 0)); ramp.add_point(0.3, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new(); rt.gradient = ramp
	ppm.color_ramp = rt
	p.process_material = ppm
	p.draw_pass_1 = FX.quad(size)
	p.material_override = FX.glow_material(col, 2.0)
	add_child(p)
	p.position = center
	return p

# ---------------------------------------------------------------------------
func _tunnel() -> void:
	var wm: Material = b.wall_mat(Color(0.33, 0.31, 0.29), 0.3, Y)
	b.stairs(-2.5, 2.5, -2.0, -12.0, 0.0, Y, b.mats.floor)
	b.box(Vector3(-2.5, Y - 1, -12.5), Vector3(2.5, Y, -11.0), b.mats.floor)
	b.box(Vector3(-3.5, Y - 1, -12.5), Vector3(-2.5, 5, -2), wm)
	b.box(Vector3(2.5, Y - 1, -12.5), Vector3(3.5, 5, -2), wm)
	# stepped tunnel ceiling following the stairs
	for i in 5:
		var z0 := -2.0 - i * 2.0
		var y := 4.4 - i * 1.2
		b.box(Vector3(-3.5, y, z0 - 2.0), Vector3(3.5, y + 1.0 + i * 1.2, z0), wm)
	Props.torch(self, Vector3(-2.45, Y + 5.0, -8.5), 90.0, true)

func _entry_hall() -> void:
	var wm: Material = b.wall_mat(Color(0.33, 0.31, 0.29), 0.3, Y)
	b.room(-9, 9, -34, -12, Y, 7.5, wm, b.mats.floor, {"s": [[-2.5, 2.5, 5.0]], "n": [[-2.0, 2.0, 3.6]]})
	for z in [-17.0, -23.0, -29.0]:
		b.pillar(Vector3(-5.5, Y, z), 7.5, 0.45, wm)
		b.pillar(Vector3(5.5, Y, z), 7.5, 0.45, wm)
	Props.torch(self, Vector3(-8.95, Y + 3.0, -20.0), 90.0, true, true)
	Props.torch(self, Vector3(8.95, Y + 3.0, -26.0), -90.0, true)
	Props.torch(self, Vector3(-1.9 - 1.0, Y + 2.6, -33.95), 0.0, true)
	Props.torch(self, Vector3(1.9 + 1.0, Y + 2.6, -33.95), 0.0, true)
	for p in [[Vector3(-7.6, Y, -14.5), 30.0, "rubble_large"], [Vector3(7.5, Y, -31), 0.0, "rubble_half"],
			[Vector3(7.8, Y, -15.5), 0.0, "barrel_large"], [Vector3(6.8, Y, -14.2), 40.0, "barrel_small"],
			[Vector3(-7.4, Y, -30.5), 10.0, "table_long_broken"], [Vector3(-8.0, Y, -27), 90.0, "shelf_small_candles"],
			[Vector3(7.9, Y, -21), -90.0, "banner_patternB_blue"], [Vector3(-7.9, Y, -24.5), 90.0, "banner_patternB_blue"],
			[Vector3(3.5, Y, -32.4), 0.0, "candle_triple"], [Vector3(-3.5, Y, -32.4), 0.0, "candle_triple"]]:
		Props.place(self, p[2], p[0], p[1], 1.0, p[2].begins_with("barrel") or p[2].begins_with("table") or p[2].begins_with("shelf"))
	Interactable.create(self, "inscription", Vector3(-7.5, Y, -18.5), 90.0, "", [], "The Founding Stone",
		"HERE THE KEEPERS OF ASHKAR SEALED THE HEART,\nTHAT ITS LIGHT MIGHT FEED THE DEEP RIVER AND NEVER THE GREED OF KINGS.\n\nLET THE WARDEN STAND UNTIL ONE WORTHY BRINGS THE HEART BACK INTO THE WORLD.\n\n(Beneath, scratched more recently: \"the bones get up when you walk past them\")")
	Interactable.create(self, "chest", Vector3(7.4, Y, -29.0), -90.0, "chest_hall_a", [{"roll": "small"}])
	Interactable.create(self, "chest", Vector3(-7.4, Y, -22.2), 90.0, "chest_hall_b", [{"roll": "small"}])
	var hall_bounds := AABB(Vector3(-9, Y - 1, -34), Vector3(18, 9, 22))
	for e in [[Vector3(-3, Y, -21), "minion", "e_hall_1"], [Vector3(3.5, Y, -24), "minion", "e_hall_2"], [Vector3(0, Y, -29.5), "minion", "e_hall_3"]]:
		_enemy(e[1], e[0], e[2], PI, 6.5, hall_bounds)

func _corridor() -> void:
	var wm: Material = b.wall_mat(Color(0.30, 0.28, 0.27), 0.2, Y, 0.9, 0.45)
	b.room(-2.75, 2.75, -60, -34, Y, 5.0, wm, b.mats.floor, {"s": [[-2.0, 2.0, 3.6]], "n": [[-2.0, 2.0, 3.6]]})
	var offs := [0.0, 0.8, 1.6, 2.4]
	var zs := [-38.5, -43.0, -47.5, -52.0]
	for i in 4:
		corridor_traps.append(FireTrap.create(self, Vector3(0, Y, zs[i]), Vector2(5.4, 1.8), 3.2, offs[i]))
	Props.torch(self, Vector3(-2.7, Y + 2.6, -36), 90.0, true)
	Props.torch(self, Vector3(2.7, Y + 2.6, -56.5), -90.0, true, true)
	Props.place(self, "sword_shield_broken", Vector3(-2.0, Y, -45), 30.0)
	Props.place(self, "rubble_half", Vector3(2.0, Y, -55), 60.0)
	corridor_gate = Gate.create(self, Vector3(0, Y, -60.0), 4.0, 3.6, 0.0, "gate_corridor")
	var lever := Interactable.create(self, "lever", Vector3(2.45, Y, -58.8), -90.0, "lever_corridor")
	Interactable.create(self, "chest", Vector3(-2.1, Y, -58.6), 90.0, "chest_corridor", [{"kind": "mana", "amount": 1}, {"roll": "small"}])
	lever.used.connect(func(_by: Node) -> void:
		corridor_gate.open()
		for t in corridor_traps:
			t.disabled = true
		Game.say("Somewhere, old chains groan. The vents fall silent.", Color(0.9, 0.85, 0.7)))
	if Game.flags.get("lever_corridor", false):
		for t in corridor_traps:
			t.disabled = true

func _armory() -> void:
	var wm: Material = b.wall_mat(Color(0.35, 0.32, 0.30), 0.18, Y)
	b.room(-11, 11, -84, -60, Y, 8.0, wm, b.mats.floor, {"s": [[-2.0, 2.0, 3.6]], "n": [[-2.0, 2.0, 3.6]]})
	for z in [-66.0, -72.0, -78.0]:
		b.pillar(Vector3(-6.5, Y, z), 8.0, 0.5, wm)
		b.pillar(Vector3(6.5, Y, z), 8.0, 0.5, wm)
	Props.torch(self, Vector3(-10.95, Y + 3.0, -63), 90.0, true)
	Props.torch(self, Vector3(10.95, Y + 3.0, -75), -90.0, true, true)
	Props.torch(self, Vector3(-10.95, Y + 3.0, -80), 90.0, true)
	Props.torch(self, Vector3(-3.0, Y + 3.0, -83.95), 0.0, true)
	Props.torch(self, Vector3(3.0, Y + 3.0, -83.95), 0.0, true)
	var deco := [
		[Vector3(-10.4, Y, -68), 90.0, "sword_shield"], [Vector3(-10.4, Y, -70), 90.0, "sword_shield_gold"], [Vector3(-10.4, Y, -72), 90.0, "sword_shield"],
		[Vector3(10.4, Y, -64), -90.0, "shelves"], [Vector3(10.4, Y, -68), -90.0, "sword_shield"], [Vector3(10.4, Y, -80), -90.0, "shelf_large"],
		[Vector3(-9, Y, -76), 0.0, "table_long_decorated_A"], [Vector3(9.4, Y, -82.5), 0.0, "barrel_large_decorated"],
		[Vector3(8.2, Y, -82.8), 0.0, "barrel_small"], [Vector3(-9.5, Y, -82.6), 0.0, "crates_stacked"],
		[Vector3(-10.6, Y, -78.5), 90.0, "banner_shield_red"], [Vector3(10.6, Y, -72), -90.0, "banner_shield_red"],
		[Vector3(-3, Y, -83.4), 0.0, "keyring_hanging"], [Vector3(4, Y, -61.4), 180.0, "box_stacked"],
	]
	for p in deco:
		Props.place(self, p[2], p[0], p[1], 1.0, not p[2].begins_with("banner") and not p[2].begins_with("keyring"))
	Interactable.create(self, "chest", Vector3(-9.4, Y, -63.5), 90.0, "chest_armory_a", [{"roll": "weapon"}])
	Interactable.create(self, "chest", Vector3(0, Y, -82.6), 0.0, "chest_armory_b", [{"roll": "armor"}])
	Interactable.create(self, "chest", Vector3(-9.4, Y, -80.4), 90.0, "chest_armory_c", [{"roll": "big"}])
	Interactable.create(self, "shrine", Vector3(8.4, Y, -62.6), 180.0, "", [], "the Armory")
	Interactable.create(self, "inscription", Vector3(9.8, Y, -76.5), -90.0, "", [], "Sentinel's Oath",
		"We who guard the Vault ask no rest.\nWhen flesh fails, the bone will stand.\nWhen bone fails, the Warden wakes.\n\n(Someone has scrawled beneath: \"the big one is slow. dodge, then strike.\")")
	var bnd := AABB(Vector3(-11, Y - 1, -84), Vector3(22, 10, 24))
	_enemy("warrior", Vector3(-4.5, Y, -69), "e_arm_1", PI, 0.0, bnd)
	_enemy("warrior", Vector3(4.5, Y, -71), "e_arm_2", PI, 0.0, bnd)
	_enemy("minion", Vector3(-2, Y, -75), "e_arm_3", PI, 7.0, bnd)
	_enemy("revenant", Vector3(0, Y, -79.5), "e_arm_rev", PI, 0.0, bnd)
	# passage onward
	var pm: Material = b.wall_mat(Color(0.31, 0.30, 0.30), 0.3, Y)
	b.room(-2, 2, -92, -84, Y, 4.2, pm, b.mats.floor, {"s": [[-2.0, 2.0, 3.6]], "n": [[-2.0, 2.0, 3.6]]})
	# a curious chest in the passage: always holds a skin (a new look)
	Interactable.create(self, "chest", Vector3(1.35, Y, -88.0), -90.0, "chest_curious", [{"roll": "skin"}])

# ---------------------------------------------------------------------------
func _glowing_deep() -> void:
	var x0 := -22.0; var x1 := 22.0; var z0 := -134.0; var z1 := -92.0
	var h := 16.0
	var wm: Material = b.wall_mat(Color(0.26, 0.27, 0.29), 0.35, Y, 1.6, 0.7)
	(wm as ShaderMaterial).set_shader_parameter("glow_origin", Vector3(0, Y, -112))
	(wm as ShaderMaterial).set_shader_parameter("glow_radius", 26.0)
	(wm as ShaderMaterial).set_shader_parameter("glow_color", Color(0.2, 0.8, 1.0))
	var fm := (b.mats.floor as ShaderMaterial).duplicate() as ShaderMaterial
	fm.set_shader_parameter("glow_origin", Vector3(0, Y, -112))
	fm.set_shader_parameter("glow_radius", 18.0)
	fm.set_shader_parameter("wet", 0.5)
	fm.set_shader_parameter("moss", 0.35)
	var river := Rect2(x0 - 1.0, -116.0, (x1 - x0) + 2.0, 8.0)
	var pool := Rect2(11.0, -131.0, 8.0, 10.0)
	var ch_w := Rect2(-9.7, -133.0, 1.4, 17.0)
	var ch_e := Rect2(-0.7 + 6.0, -133.0, 1.4, 17.0)
	var holes := [river, pool, ch_w, ch_e]
	b.room(x0, x1, z0, z1, Y, h, wm, fm, {"s": [[-2.0, 2.0, 3.6]], "n": [[-2.5, 2.5, 4.6]]}, true, holes)
	# channel beds
	var bed := b.wall_mat(Color(0.18, 0.2, 0.22), 0.5, Y - 2.0)
	(bed as ShaderMaterial).set_shader_parameter("wet", 1.0)
	b.box(Vector3(x0 - 2, Y - 2.6, -116), Vector3(x1 + 2, Y - 1.0, -108), bed)
	b.box(Vector3(pool.position.x, Y - 2.6, pool.position.y), Vector3(pool.end.x, Y - 1.0, pool.end.y), bed)
	for c in [ch_w, ch_e]:
		b.box(Vector3(c.position.x, Y - 1.6, c.position.y), Vector3(c.end.x, Y - 0.8, c.end.y), bed)
	# river inlet / outlet tunnels plug the void beyond the walls
	b.box(Vector3(x0 - 6, Y - 2.6, -117), Vector3(x0 - 4, Y + 2, -107), b.mats.rock)
	b.box(Vector3(x1 + 4, Y - 2.6, -117), Vector3(x1 + 6, Y + 2, -107), b.mats.rock)
	b.box(Vector3(x0 - 6, Y - 2.6, -118), Vector3(x0, Y + 2, -116), b.mats.rock)
	b.box(Vector3(x0 - 6, Y - 2.6, -108), Vector3(x0, Y + 2, -106), b.mats.rock)
	b.box(Vector3(x1, Y - 2.6, -118), Vector3(x1 + 6, Y + 2, -116), b.mats.rock)
	b.box(Vector3(x1, Y - 2.6, -108), Vector3(x1 + 6, Y + 2, -106), b.mats.rock)
	# island in the pool
	b.box(Vector3(13.6, Y - 1.6, -127.4), Vector3(16.4, Y - 0.1, -124.6), b.mats.floor)
	# the river itself and its feeders
	rivers.append(GlowRiver.create(self, Rect2(x0 - 4, -116, (x1 - x0) + 8, 8), Y - 0.55, Vector2(1, 0)))
	rivers.append(GlowRiver.create(self, pool, Y - 0.5, Vector2(0.3, 1), Color(0.2, 0.95, 0.85), true))
	rivers.append(GlowRiver.create(self, ch_w, Y - 0.9, Vector2(0, 1)))
	rivers.append(GlowRiver.create(self, ch_e, Y - 0.9, Vector2(0, 1)))
	for r in rivers:
		r.damage_per_sec = 12.0
	# waterfalls: the west inlet cascades down the wall; two feeders pour from the north wall
	_waterfall(Vector3(x0 + 0.05, Y + 3.5, -112), Vector2(7.5, 11.0), PI / 2)
	_waterfall(Vector3(ch_w.get_center().x, Y + 4.5, z0 + 0.05), Vector2(1.6, 11.0), 0.0)
	_waterfall(Vector3(ch_e.get_center().x, Y + 4.5, z0 + 0.05), Vector2(1.6, 11.0), 0.0)
	for wx in [ch_w.get_center().x, ch_e.get_center().x]:
		var spl := Node3D.new(); add_child(spl); spl.position = Vector3(wx, Y - 0.8, z0 + 0.6)
		_splash_emitter(spl, 0.8)
	var wspl := Node3D.new(); add_child(wspl); wspl.position = Vector3(x0 + 0.7, Y - 0.5, -112)
	_splash_emitter(wspl, 3.5)
	# the bridge (railings, deck, supports)
	b.box(Vector3(-2.4, Y - 0.5, -116.6), Vector3(2.4, Y, -107.4), b.wall_mat(Color(0.34, 0.33, 0.33), 0.3, Y))
	for sx in [-2.4, 2.1]:
		b.box(Vector3(sx, Y, -116.6), Vector3(sx + 0.3, Y + 0.8, -107.4), b.wall_mat(Color(0.34, 0.33, 0.33), 0.3, Y))
	for sz in [-114.5, -109.5]:
		b.pillar(Vector3(-1.6, Y - 2.0, sz), 1.6, 0.3)
		b.pillar(Vector3(1.6, Y - 2.0, sz), 1.6, 0.3)
	# little stepping bridges over the feeder channels
	for c in [ch_w, ch_e]:
		b.box(Vector3(c.position.x - 0.3, Y - 0.25, -122.0), Vector3(c.end.x + 0.3, Y, -120.6), b.mats.floor)
	# great pillars reaching into the dark
	for p in [Vector3(-15, Y, -99), Vector3(15, Y, -99), Vector3(-15, Y, -126), Vector3(-3.5 + 0.0, Y, -127.5), Vector3(3.5, Y, -127.5)]:
		b.pillar(p, h, 0.9, wm)
	# glowing crystal clusters
	for c in [[Vector3(-19, Y, -97), 1.2], [Vector3(19.5, Y, -103), 1.0], [Vector3(-20, Y, -124), 1.4], [Vector3(-12, Y, -131.5), 0.9],
			[Vector3(19.5, Y, -132), 1.1], [Vector3(12.5, Y, -96), 0.7], [Vector3(-6, Y, -105.8), 0.6], [Vector3(7, Y, -118.4), 0.6]]:
		_crystals(c[0], c[1])
	# a shaft of pale light from a crack high above the bridge
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(0.75, 0.85, 1.0)
	shaft.light_energy = 6.0
	shaft.spot_range = 26.0
	shaft.spot_angle = 11.0
	shaft.spot_attenuation = 0.6
	shaft.light_volumetric_fog_energy = 6.0
	shaft.shadow_enabled = true
	shaft.position = Vector3(1.5, Y + h - 0.6, -113)
	shaft.rotation_degrees = Vector3(-84, 0, 0)
	add_child(shaft)
	_motes(Vector3(0, Y + 6, -113), Vector3(20, 6, 19), Color(0.45, 0.85, 1.0), 260, 0.045)
	# ruins
	for p in [[Vector3(-19, Y, -94.5), 0.0, "rubble_large"], [Vector3(17, Y, -122), 20.0, "rubble_half"], [Vector3(-6, Y, -132.6), 0.0, "wall_broken"],
			[Vector3(6.0, Y, -97), 0.0, "column"], [Vector3(-6.0, Y, -97), 0.0, "column"], [Vector3(-17, Y, -119.0), 0.0, "barrier_column"],
			[Vector3(-13, Y, -119.0), 0.0, "barrier_half"], [Vector3(20.6, Y, -96), -90.0, "banner_thin_blue"], [Vector3(-20.6, Y, -101), 90.0, "banner_thin_blue"]]:
		Props.place(self, p[2], p[0], p[1], 1.0, not p[2].begins_with("banner"))
	Props.torch(self, Vector3(-2.6 - 0.5, Y + 3.0, -133.95), 0.0, true, true, Color(0.5, 0.8, 1.0))
	Props.torch(self, Vector3(2.6 + 0.5, Y + 3.0, -133.95), 0.0, true, false, Color(0.5, 0.8, 1.0))
	# loot and lore
	Interactable.create(self, "chest", Vector3(15.0, Y - 0.1, -126.0), 0.0, "chest_island",
		[{"kind": "item", "id": "amulet_deep"}, {"roll": "big"}])
	Interactable.create(self, "chest", Vector3(-19.6, Y, -131.0), 90.0, "chest_runeblade",
		[{"kind": "item", "id": "vault_blade"}, {"roll": "small"}])
	Interactable.create(self, "chest", Vector3(19.4, Y, -98.0), -90.0, "chest_deep_a", [{"roll": "small"}])
	Interactable.create(self, "chest", Vector3(-19.4, Y, -104.5), 90.0, "chest_deep_b", [{"roll": "big"}])
	Interactable.create(self, "chest", Vector3(-4.6, Y, -132.6), 0.0, "chest_supply", [{"roll": "supply"}])
	Interactable.create(self, "shrine", Vector3(-6.0, Y, -95.6), 180.0, "", [], "the Glowing Deep")
	Interactable.create(self, "shrine", Vector3(-6.5, Y, -129.8), 0.0, "", [], "the Warden's Door")
	Interactable.create(self, "inscription", Vector3(8.5, Y, -95.0), 180.0, "", [], "Corwin's last words",
		"(carved hastily with a knife)\n\nThe light in the water is the Heart's own blood. It burns the unworthy.\nThe Keepers' amulet lies on the island. With it the river will mend you rather than burn.\n\nThe Warden waits beyond. It leaps when you run from it. Do not run far.\n- C.")
	var bnd := AABB(Vector3(x0, Y - 3, z0), Vector3(x1 - x0, h, z1 - z0))
	_enemy("minion", Vector3(-5, Y, -101), "e_deep_1", PI, 7.0, bnd)
	_enemy("minion", Vector3(5, Y, -103), "e_deep_2", PI, 7.0, bnd)
	_enemy("mage", Vector3(-11, Y, -124), "e_deep_m1", 0.0, 0.0, bnd)
	_enemy("mage", Vector3(8, Y, -127), "e_deep_m2", 0.0, 0.0, bnd)
	_enemy("warrior", Vector3(0, Y, -125), "e_deep_w", 0.0, 0.0, bnd)
	_enemy("minion", Vector3(-17, Y, -128), "e_deep_3", PI / 2, 6.0, bnd)

func _waterfall(pos: Vector3, size: Vector2, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/waterfall.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	mi.rotation.y = yaw
	var l := OmniLight3D.new(); l.light_color = Color(0.2, 0.8, 1.0); l.light_energy = 1.4; l.omni_range = 8.0
	l.position = Vector3(0, -size.y * 0.3, 0.8)
	mi.add_child(l)

func _splash_emitter(parent: Node3D, width: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(30 * width) + 10; p.lifetime = 1.0
	p.mesh = FX.quad(0.18)
	p.material_override = FX.glow_material(Color(0.4, 0.9, 1.0), 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.5, 0.1, width * 0.5)
	p.direction = Vector3.UP; p.spread = 40
	p.initial_velocity_min = 1.0; p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -6, 0)
	p.color_ramp = FX._fade_ramp(Color(0.5, 0.9, 1.0))
	parent.add_child(p)
	var mist := CPUParticles3D.new()
	mist.amount = 14; mist.lifetime = 3.0
	mist.mesh = FX.quad(2.0)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.albedo_texture = FX.soft_texture(); mm.vertex_color_use_as_albedo = true
	mist.material_override = mm
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(width * 0.5, 0.2, width * 0.5)
	mist.direction = Vector3.UP; mist.initial_velocity_min = 0.2; mist.initial_velocity_max = 0.6; mist.gravity = Vector3.ZERO
	mist.color_ramp = FX._fade_ramp(Color(0.55, 0.85, 0.95, 0.25))
	parent.add_child(mist)

func _crystals(pos: Vector3, s: float) -> void:
	var n := Node3D.new(); add_child(n); n.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.85, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color(0.2, 0.75, 1.0); m.emission_energy_multiplier = 2.5
	m.roughness = 0.1; m.metallic = 0.2
	var rng := RandomNumberGenerator.new(); rng.seed = int(pos.x * 31 + pos.z * 17)
	for i in 5:
		var c := MeshInstance3D.new(); var pm := PrismMesh.new()
		var hh := rng.randf_range(0.6, 1.6) * s
		pm.size = Vector3(0.28 * s, hh, 0.28 * s)
		c.mesh = pm; c.material_override = m
		c.position = Vector3(rng.randf_range(-0.4, 0.4) * s, hh * 0.45, rng.randf_range(-0.4, 0.4) * s)
		c.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf(), rng.randf_range(-0.4, 0.4))
		n.add_child(c)
	var l := OmniLight3D.new(); l.light_color = Color(0.3, 0.8, 1.0); l.light_energy = 0.8 * s; l.omni_range = 4.0 * s
	l.position.y = 1.0 * s
	n.add_child(l)

# ---------------------------------------------------------------------------
func _sanctum() -> void:
	var wm: Material = b.wall_mat(Color(0.30, 0.28, 0.30), 0.1, Y, 1.8, 0.8)
	var fm := (b.mats.floor as ShaderMaterial).duplicate() as ShaderMaterial
	fm.set_shader_parameter("base_color", Color(0.27, 0.25, 0.25))
	b.room(-2.5, 2.5, -142, -134, Y, 5.0, wm, fm, {"s": [[-2.5, 2.5, 4.6]], "n": [[-2.5, 2.5, 4.6]]})
	b.room(-15, 15, -172, -142, Y, 14.0, wm, fm, {"s": [[-2.5, 2.5, 4.6]], "n": [[-3.5, 3.5, 6.5]]})
	_portal_chamber(wm, fm)
	boss_gate = Gate.create(self, Vector3(0, Y, -141.6), 5.0, 4.6, 0.0, "")
	boss_gate.open(true)
	# ring of pillars with braziers
	for i in 8:
		var a := i * TAU / 8.0 + TAU / 16.0
		var p := Vector3(cos(a) * 11.0, Y, -157 + sin(a) * 11.0)
		b.pillar(p, 14.0, 0.7, wm)
	for p in [Vector3(-9, Y, -147), Vector3(9, Y, -147), Vector3(-9, Y, -167), Vector3(9, Y, -167)]:
		_brazier(p)
	# great floor seal
	var seal := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(16, 16)
	seal.mesh = pm
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/rune.gdshader")
	sm.set_shader_parameter("color", Color(0.3, 0.7, 1.0)); sm.set_shader_parameter("intensity", 0.7); sm.set_shader_parameter("spin", 0.05)
	seal.material_override = sm
	seal.position = Vector3(0, Y + 0.02, -157)
	add_child(seal)
	for p in [[Vector3(-14.5, Y, -152), 90.0, "banner_triple_red"], [Vector3(14.5, Y, -152), -90.0, "banner_triple_red"],
			[Vector3(-14.5, Y, -162), 90.0, "banner_triple_red"], [Vector3(14.5, Y, -162), -90.0, "banner_triple_red"],
			[Vector3(-13, Y, -170.5), 0.0, "rubble_large"], [Vector3(12.5, Y, -170.8), 0.0, "sword_shield_broken"]]:
		Props.place(self, p[2], p[0], p[1])
	altar = Interactable.create(self, "altar", Vector3(0, Y, -169.0), 0.0, "altar")
	altar.used.connect(_on_altar_used)
	warden = Warden.new()
	warden.position = Vector3(0, Y, -157)
	warden.rotation.y = PI  # face the sanctum doors
	add_child(warden)
	warden.arena_center = Vector3(0, Y, -157)
	warden.arena_radius = 12.0
	warden.summon_callback = _summon_adds
	warden.defeated.connect(_on_warden_defeated)
	if Game.flags.get("warden_dead", false):
		warden.queue_free()
		warden = null

# ---------------------------------------------------------------------------
# End of Level 1: behind the altar a stone door grinds open onto an ancient
# portal. Walking into it carries you to the portal glade of the Goblin Forest.
var secret_door: MeshInstance3D
var _portal_disc: MeshInstance3D
var _portal_light: OmniLight3D
var _portal_area: Area3D
var _portal_open := false

func _portal_chamber(wm: Material, fm: Material) -> void:
	var mossy: Material = b.wall_mat(Color(0.26, 0.3, 0.24), 0.7, Y, 1.4, 0.6)
	b.room(-7, 7, -186, -172.6, Y, 9.0, mossy, fm, {"s": [[-7.0, 7.0, 9.0]]})
	secret_door = b.box(Vector3(-3.6, Y, -172.6), Vector3(3.6, Y + 6.6, -171.4), wm)
	var arch: Node3D = (load("res://assets/kaykit/forest/arch_gate.gltf") as PackedScene).instantiate()
	add_child(arch)
	arch.position = Vector3(0, Y - 0.1, -182.0)
	arch.scale = Vector3.ONE * 1.5
	_portal_disc = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2)
	_portal_disc.mesh = q
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/portal.gdshader")
	pm.set_shader_parameter("intensity", 0.0)
	_portal_disc.material_override = pm
	_portal_disc.position = Vector3(0, Y + 3.0, -182.05)
	add_child(_portal_disc)
	_portal_light = OmniLight3D.new(); _portal_light.light_color = Color(0.4, 1.0, 0.8); _portal_light.light_energy = 0.0
	_portal_light.omni_range = 14.0; _portal_light.position = Vector3(0, Y + 3.0, -180.5); add_child(_portal_light)
	# old roots and rubble: nobody has used this portal in a very long time
	Props.place(self, "rubble_half", Vector3(-5, Y, -184), 30.0)
	Props.place(self, "rubble_large", Vector3(5.2, Y, -178), -20.0)
	for sx in [-5.8, 5.8]:
		Props.torch(self, Vector3(sx, Y + 3.2, -180.0), 90.0 if sx < 0 else -90.0, true)
	_portal_area = Area3D.new(); _portal_area.collision_layer = 0; _portal_area.collision_mask = 2
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.6, 4.0, 1.4)
	cs.shape = bs; _portal_area.add_child(cs)
	_portal_area.position = Vector3(0, Y + 2.0, -182.0)
	_portal_area.monitoring = false
	add_child(_portal_area)
	_portal_area.body_entered.connect(func(bd: Node) -> void:
		if bd.is_in_group("player") and _portal_open:
			_enter_portal())
	if Game.flags.get("altar", false):
		_open_portal(true)

func _open_portal(instant := false) -> void:
	_portal_open = true
	var pm := _portal_disc.material_override as ShaderMaterial
	if instant:
		secret_door.position.y -= 6.8
		secret_door.get_child(0).queue_free()   # its collider
		pm.set_shader_parameter("intensity", 2.2)
		_portal_light.light_energy = 4.0
		_portal_area.set_deferred("monitoring", true)
		return
	Sfx.play("rumble", 0.0, 0.0)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_trauma"):
		p.add_trauma(0.5)
	for k in 6:
		FX.burst(Vector3(-3.0 + k * 1.2, Y + 0.4, -171.0), Color(0.55, 0.5, 0.45), 18, 3.0, 0.5, 1.4, -2.0)
	var tw := create_tween()
	tw.tween_property(secret_door, "position:y", secret_door.position.y - 6.8, 3.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		secret_door.get_child(0).queue_free()
		Sfx.play("portal", -2.0, 0.0)
		FX.burst(_portal_disc.global_position, Color(0.4, 1.0, 0.8), 80, 5.0, 0.3, 1.2, 0.0)
		FX.flash_light(_portal_disc.global_position, Color(0.5, 1.0, 0.85), 10.0, 16.0, 1.0)
		Game.say("An ancient portal flickers to life! Step into it.", Color(0.5, 1.0, 0.85))
		Game.set_objective("Step into the ancient portal behind the altar.")
		_portal_area.set_deferred("monitoring", true))
	tw.tween_method(func(v: float) -> void: pm.set_shader_parameter("intensity", v), 0.0, 2.2, 1.6)
	tw.parallel().tween_property(_portal_light, "light_energy", 4.0, 1.6)

func _enter_portal() -> void:
	_portal_open = false
	Sfx.play("portal", 0.0, 0.0)
	FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
	var sc := get_tree().current_scene
	if sc.has_method("go_to_forest"):
		get_tree().create_timer(0.5).timeout.connect(sc.go_to_forest)

func _brazier(p: Vector3) -> void:
	var n := Node3D.new(); add_child(n); n.position = p
	var base := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.5; cm.bottom_radius = 0.25; cm.height = 1.2
	base.mesh = cm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.2, 0.18, 0.16); m.metallic = 0.8; m.roughness = 0.5
	base.material_override = m; base.position.y = 0.6
	n.add_child(base)
	var fire := Node3D.new(); fire.position.y = 1.25; n.add_child(fire)
	Props.fire_particles(fire, 1.8, Color(1.0, 0.5, 0.2), true)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.55, 0.25); l.light_energy = 2.6; l.omni_range = 12.0
	l.position.y = 1.8; l.light_volumetric_fog_energy = 1.5
	l.set_script(load("res://scripts/world/flicker.gd"))
	n.add_child(l)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.5; cy.height = 1.2
	cs.shape = cy; cs.position.y = 0.6; sb.add_child(cs); n.add_child(sb)

# ---------------------------------------------------------------------------
func _enemy(type_name: String, pos: Vector3, uid: String, yaw: float, wake: float, bounds: AABB) -> Enemy:
	if Game.flags.get(uid, false):
		return null
	var e := Enemy.new()
	e.configure(type_name, uid, wake)
	e.bounds = bounds
	e.position = pos
	e.rotation.y = yaw
	add_child(e)
	return e

func _start_boss() -> void:
	if warden == null:
		return
	boss_started = true
	boss_gate.close()
	Game.set_objective("Defeat the Vault Warden.")
	Game.say("The seal flares. Stone grinds against stone...", Color(1.0, 0.7, 0.5))
	Sfx.music("music_boss", -8.0)
	warden.awaken()
	var sc := get_tree().current_scene
	if sc.has_method("show_boss_bar"):
		sc.show_boss_bar(warden)

func _summon_adds() -> void:
	var bnd := AABB(Vector3(-15, Y - 1, -172), Vector3(30, 14, 30))
	var i := 0
	for p in [Vector3(-7, Y, -152), Vector3(7, Y, -152), Vector3(0, Y, -165)]:
		var e := _enemy("minion", p, "", PI, 40.0, bnd)
		e.leash = 40.0
		i += 1

## Called when the player dies inside the arena: reset the encounter.
func reset_boss() -> void:
	if warden == null or warden.dead or not boss_started:
		return
	boss_started = false
	boss_gate.open(true)
	var w := warden
	warden = null
	w.queue_free()
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.uid == "" and e.global_position.z < -142.0:
			e.queue_free()
	warden = Warden.new()
	warden.position = Vector3(0, Y, -157)
	warden.rotation.y = PI
	add_child(warden)
	warden.arena_center = Vector3(0, Y, -157)
	warden.arena_radius = 12.0
	warden.summon_callback = _summon_adds
	warden.defeated.connect(_on_warden_defeated)
	Sfx.music("music_explore", -14.0)
	var sc := get_tree().current_scene
	if sc.has_method("hide_boss_bar"):
		sc.hide_boss_bar()

func _on_warden_defeated() -> void:
	boss_gate.open()
	var reward := Interactable.create(self, "chest", Vector3(0, Y, -164.0), 0.0, "chest_warden", [{"roll": "boss"}])
	FX.burst(reward.global_position + Vector3(0, 1, 0), Loot.rarity_color(4), 60, 4.0, 0.25, 1.5, 0.5)
	Sfx.music("music_explore", -12.0)
	Game.set_objective("Claim the Heart of the Vault upon the altar.")
	Game.say("The Warden crumbles. The Heart's light pulses from the altar.", Color(1.0, 0.8, 0.5))
	var sc := get_tree().current_scene
	if sc.has_method("hide_boss_bar"):
		get_tree().create_timer(2.0).timeout.connect(sc.hide_boss_bar)

func _on_altar_used(_by: Node) -> void:
	Game.game_over = true
	Game.flags["victory"] = true
	Game.set_objective("The Heart is yours! Something rumbles behind the altar...")
	Game.say("LEVEL 1 COMPLETE!  The Heart of the Vault is yours.", Color(1.0, 0.85, 0.4))
	var sc := get_tree().current_scene
	if sc.has_method("autosave"):
		sc.autosave()
	get_tree().create_timer(2.2).timeout.connect(func() -> void: _open_portal())
