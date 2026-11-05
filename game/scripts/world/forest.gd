extends Node3D
class_name ForestWorld
## Level 2: the Goblin Forest. An open, sunlit valley you can roam freely:
## a portal glade in the south with the Goblin Warren's entrance in view on the
## northern ridge, a road and a stream with a bridge, a woodcutter's camp, a
## herbalist's hut, a robbed merchant, two goblin camps, five quest givers, and
## the Warren itself, a goblin dungeon dug beneath the ridge with Chief Gruk.

signal area_changed(area: String)

const HALF := 140.0          # terrain half size (metres)
const STEP := 2.0            # terrain grid spacing
const PLAY := 118.0          # playable half size (invisible walls beyond)
const WY := -60.0            # floor height of the Warren dungeon
const FOREST_DIR := "res://assets/kaykit/forest/%s.gltf"

var player: Player
var spawn_point := Vector3.ZERO
var b: Builder
var env: Environment
var sun: DirectionalLight3D
var area := ""
var noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var road: PackedVector2Array = [Vector2(0, 104), Vector2(3, 82), Vector2(-5, 58), Vector2(2, 34), Vector2(0, 14),
	Vector2(-4, -8), Vector2(5, -36), Vector2(-2, -66), Vector2(0, -88)]
var clearings := []           # [Vector2 centre, radius]
var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _multi := {}              # model name -> Array[Transform3D]
var _trunks: StaticBody3D
var door: Node3D
var gruk: Enemy
var day_night: DayNight
var sinkhole: SinkholeOfDeath
var wild_chests: WildChests

func _wild_spot_ok(p: Vector2) -> bool:
	if road_dist(p) < 8.0 or stream_dist(p) < 7.0 or p.distance_to(SinkholeOfDeath.HOLE) < 12.0:
		return false
	for c in clearings:
		if p.distance_to(c[0]) < c[1] + 4.0:
			return false
	# not on a steep slope
	var h := height(p.x, p.y)
	for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(height(p.x + d.x, p.y + d.y) - h) > 1.2:
			return false
	return true
var boss_started := false
## Ground colours (the castle's moors use their own, gloomier set)
var pal := {"grass_a": Color(0.33, 0.52, 0.2), "grass_b": Color(0.45, 0.58, 0.22), "dirt": Color(0.5, 0.39, 0.25),
	"rock": Color(0.45, 0.43, 0.38), "bed": Color(0.32, 0.34, 0.26)}
const MOON_PORTAL := Vector2(80.0, 78.0)
var _moon_area: Area3D
var _moon_mat: ShaderMaterial
var _moon_light: OmniLight3D
var _moon_disc: MeshInstance3D

func build() -> void:
	_rng.seed = 7
	noise.seed = 11; noise.frequency = 0.011; noise.fractal_octaves = 3
	detail_noise.seed = 5; detail_noise.frequency = 0.08
	b = Builder.new(self)
	clearings = [[Vector2(0, 92), 16.0], [Vector2(-55, 45), 16.0], [Vector2(55, 8), 13.0], [Vector2(-14, -18), 10.0],
		[Vector2(-58, -42), 15.0], [Vector2(60, -50), 15.0], [Vector2(36, 62), 10.0], [Vector2(0, -92), 15.0],
		[SinkholeOfDeath.HOLE, 12.0], [MOON_PORTAL, 12.0]]
	_environment()
	_terrain()
	_stream()
	_trunks = StaticBody3D.new(); _trunks.collision_layer = 1; add_child(_trunks)
	_portal_glade()
	_road_dressing()
	_lumber_camp()
	_herbalist()
	_merchant()
	_goblin_camp(Vector2(-58, -42), "w")
	_goblin_camp(Vector2(60, -50), "e")
	_goblin_outpost(Vector2(36, 62))
	_warren_entrance()
	_moon_portal()
	_scatter_forest()
	_horizon()
	_bounds()
	_flush_multimeshes()
	_motes()
	_warren()
	_quest_items()
	sinkhole = SinkholeOfDeath.build_in(self)
	# treasure chests in random spots out in the woods (new ones keep popping up)
	wild_chests = WildChests.create(self, Rect2(-PLAY + 8, -86, (PLAY - 8) * 2, 86 + PLAY - 8), ground, _wild_spot_ok, 7, 5)
	if Game.is_compat():
		for l in find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				(l as Light3D).shadow_enabled = false
		env.tonemap_exposure = 1.05

# ---------------------------------------------------------------------------
# Height field
func _dist_seg(p: Vector2, a: Vector2, c: Vector2) -> float:
	var ab := c - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func road_dist(p: Vector2) -> float:
	var d := INF
	for i in road.size() - 1:
		d = minf(d, _dist_seg(p, road[i], road[i + 1]))
	return d

func stream_z(x: float) -> float:
	return 16.0 + sin(x * 0.045) * 7.0 + sin(x * 0.11 + 1.3) * 2.0

func stream_dist(p: Vector2) -> float:
	return absf(p.y - stream_z(p.x)) * 0.92

func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := noise.get_noise_2d(x, z) * 7.0 + 2.0
	# roads and clearings are gentler
	var rd := road_dist(p)
	h = lerpf(h, h * 0.35, smoothstep(16.0, 6.0, rd))
	for c in clearings:
		var cd: float = p.distance_to(c[0])
		var ch := noise.get_noise_2d(c[0].x, c[0].y) * 7.0 * 0.35 + 2.0 * 0.35
		h = lerpf(h, ch, smoothstep(c[1] + 8.0, c[1] * 0.6, cd))
	# the northern ridge the Warren is dug into
	h += smoothstep(-90.0, -112.0, z) * 16.0
	# hills rising at the edge of the valley
	var edge := maxf(absf(x), absf(z) * (1.0 if z > 0.0 else 0.0))
	if edge > 100.0:
		h += pow(edge - 100.0, 1.6) * 0.18
	# the stream bed
	var sd := stream_dist(p)
	if z > -40.0 and z < 60.0:
		h -= smoothstep(7.0, 2.0, sd) * 2.4
	return h

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)

func _col(c: Color) -> Color:
	return c if Game.is_compat() else c.srgb_to_linear()

func _terrain() -> void:
	var n := int(HALF * 2.0 / STEP) + 1
	var hs := PackedFloat32Array(); hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-HALF + i * STEP, -HALF + j * STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_a: Color = pal.grass_a; var grass_b: Color = pal.grass_b
	var dirt: Color = pal.dirt; var rock: Color = pal.rock; var bed: Color = pal.bed
	var verts := []
	verts.resize(n * n)
	for j in n:
		for i in n:
			var x := -HALF + i * STEP; var z := -HALF + j * STEP
			var y: float = hs[j * n + i]
			var hx: float = hs[j * n + mini(i + 1, n - 1)] - hs[j * n + maxi(i - 1, 0)]
			var hz: float = hs[mini(j + 1, n - 1) * n + i] - hs[maxi(j - 1, 0) * n + i]
			var nrm := Vector3(-hx, STEP * 2.0, -hz).normalized()
			var p := Vector2(x, z)
			var c := grass_a.lerp(grass_b, clampf(detail_noise.get_noise_2d(x, z) * 0.8 + 0.5, 0.0, 1.0))
			c = c.lerp(dirt, smoothstep(4.5, 2.0, road_dist(p)) * 0.95)
			for cl in clearings:
				c = c.lerp(grass_b.lerp(dirt, 0.25), smoothstep(cl[1], cl[1] * 0.5, p.distance_to(cl[0])) * 0.35)
			if z > -40.0 and z < 60.0:
				c = c.lerp(bed, smoothstep(5.0, 2.5, stream_dist(p)))
			c = c.lerp(rock, smoothstep(0.82, 0.62, nrm.y))
			verts[j * n + i] = [Vector3(x, y, z), nrm, _col(c)]
	for j in n - 1:
		for i in n - 1:
			var a: Array = verts[j * n + i]; var bb: Array = verts[j * n + i + 1]
			var c2: Array = verts[(j + 1) * n + i]; var d: Array = verts[(j + 1) * n + i + 1]
			for v in [a, bb, c2, bb, d, c2]:
				st.set_normal(v[1]); st.set_color(v[2]); st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/terrain.gdshader")
	var nt := NoiseTexture2D.new(); nt.width = 256; nt.height = 256; nt.seamless = true
	var fn := FastNoiseLite.new(); fn.frequency = 0.02; nt.noise = fn
	sm.set_shader_parameter("detail", nt)
	mi.material_override = sm
	add_child(mi)
	# collision: a height map shape at the same spacing
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n; hm.map_depth = n; hm.map_data = hs
	cs.shape = hm
	cs.scale = Vector3(STEP, 1.0, STEP)
	sb.add_child(cs)
	add_child(sb)

func _stream() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var w := 4.2
	var x := -HALF
	var v := 0.0
	var prev := Vector3(x, 0, stream_z(x))
	while x <= HALF:
		var z := stream_z(x)
		var wy := height(x, z) + 1.0
		var cur := Vector3(x, wy, z)
		v += cur.distance_to(prev)
		prev = cur
		var dz := stream_z(x + 0.5) - stream_z(x - 0.5)
		var side := Vector3(-dz, 0, 1.0).normalized()
		st.set_uv(Vector2(0.0, v)); st.add_vertex(cur - side * w)
		st.set_uv(Vector2(1.0, v)); st.add_vertex(cur + side * w)
		x += 2.0
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/water.gdshader")
	var nt := NoiseTexture2D.new(); nt.seamless = true; nt.width = 128; nt.height = 128
	var fn := FastNoiseLite.new(); fn.frequency = 0.05; nt.noise = fn
	sm.set_shader_parameter("noise", nt)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var snd := Node3D.new(); add_child(snd); snd.position = Vector3(0, 0, stream_z(0))
	Sfx.loop_on(snd, "loop_river", -14.0, 6.0, 40.0)
	# the road bridge
	var bz := stream_z(0.0)
	var br := _model("building_bridge_A", Vector3(0, -0.4, bz), 90.0, 6.0)
	var top := height(0, bz - 9.0)
	br.position.y = maxf(top, height(0, bz + 9.0)) - 1.15
	# walkable deck matching the bridge
	b.box(Vector3(-3.0, br.position.y + 1.05, bz - 6.5), Vector3(3.0, br.position.y + 1.25, bz + 6.5), StandardMaterial3D.new(), true).visible = false

# ---------------------------------------------------------------------------
# Models
func _model(name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0, collide := false) -> Node3D:
	var path := FOREST_DIR % name
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var n: Node3D = (_scenes[path] as PackedScene).instantiate()
	add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * scl
	if collide:
		var aabb := Props.mesh_aabb(n)
		var sb := StaticBody3D.new(); sb.collision_layer = 1
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = aabb.size
		cs.shape = bs; cs.position = aabb.get_center()
		sb.add_child(cs); n.add_child(sb)
	return n

## Queue an instance for a shared MultiMesh (trees and rocks: hundreds of them).
func _instance(name: String, pos: Vector3, yaw: float, scl: float, trunk_r := 0.0) -> void:
	if not _multi.has(name):
		_multi[name] = []
	_multi[name].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), pos))
	if trunk_r > 0.0:
		var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = trunk_r; cy.height = 6.0
		cs.shape = cy; cs.position = pos + Vector3(0, 3.0, 0)
		_trunks.add_child(cs)

func _flush_multimeshes() -> void:
	for name in _multi:
		var path := FOREST_DIR % name
		if not _scenes.has(path):
			_scenes[path] = load(path)
		var proto: Node3D = (_scenes[path] as PackedScene).instantiate()
		for m in proto.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var local := Props._rel(proto, mi)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			var xs: Array = _multi[name]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, (xs[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0):
				mmi.material_override = mi.get_surface_override_material(0)
			mmi.visibility_range_end = 150.0
			add_child(mmi)
		proto.free()

# ---------------------------------------------------------------------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.28, 0.5, 0.82)
	psm.sky_horizon_color = Color(0.78, 0.82, 0.78)
	psm.ground_horizon_color = Color(0.5, 0.55, 0.45)
	psm.ground_bottom_color = Color(0.2, 0.25, 0.15)
	psm.sun_angle_max = 25.0
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.62, 0.72, 0.68)
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 420.0
	env.fog_density = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.95, 0.95, 0.85)
	env.volumetric_fog_length = 60.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -30, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_volumetric_fog_energy = 1.2
	add_child(sun)
	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(env, sun, psm, self)

func _set_area(a: String) -> void:
	if a == area:
		return
	area = a
	area_changed.emit(a)
	var under := a != "forest"
	if day_night:
		day_night.active = not under
	sun.visible = not under
	env.background_mode = Environment.BG_COLOR if under else Environment.BG_SKY
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if under else Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.32, 0.3, 0.26)
	env.ambient_light_energy = 1.0 if under else 0.9
	env.fog_light_color = Color(0.05, 0.05, 0.04) if under else Color(0.62, 0.72, 0.68)
	env.fog_depth_begin = 8.0 if under else 70.0
	env.fog_depth_end = 70.0 if under else 420.0
	env.volumetric_fog_density = 0.025 if under else 0.004
	env.volumetric_fog_albedo = Color(0.7, 0.65, 0.5) if under else Color(0.95, 0.95, 0.85)
	if a == "sinkhole":
		SinkholeOfDeath.apply_env(env)
	if a == "forest":
		Sfx.music("music_explore", -15.0)

func _process(_delta: float) -> void:
	if player == null:
		return
	player.kill_y = SinkholeOfDeath.SY - 30.0
	var py := player.global_position.y
	_set_area("sinkhole" if py < SinkholeOfDeath.SY + 30.0 else ("warren" if py < WY + 20.0 else "forest"))
	if not boss_started and gruk and is_instance_valid(gruk) and not gruk.dead and player.global_position.y < WY + 20.0 \
			and player.global_position.z < -168.0:
		boss_started = true
		Sfx.music("music_boss", -10.0)
		Game.say("Chief Gruk: \"WHO DARES?! Gruk smash tiny hero!\"", Color(1.0, 0.5, 0.3))

func reset_boss() -> void:
	if boss_started and gruk and is_instance_valid(gruk) and not gruk.dead:
		boss_started = false
		gruk.hp = gruk.max_hp
		Sfx.music("music_explore", -15.0)

# ---------------------------------------------------------------------------
# Places
func _portal_glade() -> void:
	var c := ground(0, 98)
	var arch := _model("arch_gate", c + Vector3(0, -0.2, 0), 0.0, 1.5, false)
	# the swirling portal you arrived through
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2)
	disc.mesh = q
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/portal.gdshader")
	disc.material_override = pm
	disc.position = c + Vector3(0, 3.0, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	var pl := OmniLight3D.new(); pl.light_color = Color(0.4, 1.0, 0.8); pl.light_energy = 3.0; pl.omni_range = 12.0
	pl.position = c + Vector3(0, 3.0, -1.0); add_child(pl)
	var sb := StaticBody3D.new(); add_child(sb)
	for sx in [-3.0, 3.0]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.2, 6.5, 1.2)
		cs.shape = bs; cs.position = c + Vector3(sx * 1.05, 3.2, 0); sb.add_child(cs)
	arch.name = "Portal"
	FX.burst(disc.position, Color(0.4, 1.0, 0.8), 1, 0.1)
	spawn_point = ground(0, 91) + Vector3(0, 0.15, 0)
	# standing stones, lanterns, and the shrine (checkpoint)
	for i in 7:
		var a := PI * 0.2 + i * PI * 0.27
		var p := ground(sin(a) * 13.0, 92.0 + cos(a) * 13.0)
		_instance("rock_single_" + ["C", "E", "B"][i % 3], p - Vector3(0, 0.3, 0), a, 9.0 + (i % 3) * 2.0)
		var cs2 := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 1.4; cy.height = 4.0
		cs2.shape = cy; cs2.position = p + Vector3(0, 1.5, 0); _trunks.add_child(cs2)
	for p in [Vector3(-4.5, 0, 86.0), Vector3(4.5, 0, 86.0)]:
		var lp := ground(p.x, p.z)
		_model("lantern_standing", lp, 0.0, 1.4)
		var ll := OmniLight3D.new(); ll.light_color = Color(1.0, 0.75, 0.4); ll.light_energy = 1.4; ll.omni_range = 7.0
		ll.position = lp + Vector3(0, 1.1, 0); add_child(ll)
	Interactable.create(self, "shrine", ground(-8, 84), 30.0, "", [], "the Portal Glade")
	NPC.create(self, "fenn", ground(7.5, 85.5), -110.0, {"hero": "Ranger", "outfit_color": Color(0.3, 0.45, 0.22),
		"cape_color": Color(0.25, 0.4, 0.2), "skin_color": Color(0.82, 0.6, 0.42), "face": "scar", "hair_color": Color(0.32, 0.19, 0.1)})
	Interactable.create(self, "inscription", ground(-3.5, 101.0), 180.0, "", [], "Waystone",
		"THE OLD PORTAL\\n\\nRoad north: the Warren of the goblins (keep away!)\\nWest: Bram's lumber camp\\nEast, by the stream: Old Maera's hut\\n\\n(Scratched below: \\\"GOBLINS STOLE MY CART  - T.\\\")")

func _road_dressing() -> void:
	# fences and lantern posts along the road, and a few goblin scouts
	var i := 0
	for z in range(78, -80, -14):
		var x := 0.0
		for k in road.size() - 1:
			if road[k].y >= z and road[k + 1].y <= z:
				var t := (z - road[k].y) / (road[k + 1].y - road[k].y)
				x = lerpf(road[k].x, road[k + 1].x, t)
		if absf(z - stream_z(x)) < 9.0:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		if i % 3 == 0:
			var pp := ground(x + side * 5.5, z)
			_model("post_lantern", pp, 90.0 * side, 0.9)
			var ll := OmniLight3D.new(); ll.light_color = Color(1.0, 0.72, 0.4); ll.light_energy = 1.2; ll.omni_range = 8.0
			ll.position = pp + Vector3(side * -0.4, 2.7, 0); add_child(ll)
		else:
			_model("fence_wood_straight", ground(x + side * 5.0, z), 0.0, 6.0)
		i += 1
	var scouts := [[Vector2(7, 50), "goblin"], [Vector2(-9, 44), "goblin"], [Vector2(9, 24.0 - 30.0), "goblin_archer"],
		[Vector2(-10, -30), "goblin"], [Vector2(12, -28), "goblin"], [Vector2(-8, -60), "goblin_archer"], [Vector2(9, -64), "goblin"]]
	var n := 0
	for s in scouts:
		_enemy(s[1], ground(s[0].x, s[0].y), "f_scout_%d" % n, _rng.randf() * TAU)
		n += 1

func _lumber_camp() -> void:
	var c := ground(-55, 45)
	_model("building_lumbermill_green", ground(-62, 38), 40.0, 6.0, true)
	for k in 6:
		_model("resource_lumber", ground(-48 + k * 0.4, 50 + k * 1.3) + Vector3(0, 0.1, 0), 20.0 + k * 7.0, 5.0)
	for k in 5:
		var p := ground(-46.0 + _rng.randf_range(-8, 8), 34.0 + _rng.randf_range(-6, 6))
		_model("tree_single_A_cut", p, _rng.randf() * 360.0, 6.0)
	_model("wheelbarrow", ground(-50, 41), 120.0, 6.0, true)
	_model("weaponrack", ground(-58, 50), 70.0, 6.0, true)
	_campfire(ground(-53, 46))
	NPC.create(self, "bram", ground(-51, 44), 120.0, {"hero": "Barbarian", "hat": false, "hair_style": "natural",
		"hair_color": Color(0.55, 0.25, 0.1), "hair_tint": Color(0.55, 0.25, 0.1), "face": "beard", "build": 1.25,
		"outfit_color": Color(0.6, 0.18, 0.12), "cape_color": Color(0.5, 0.15, 0.1), "weapon": "skel_axe"})
	Interactable.create(self, "chest", ground(-64, 47), 100.0, "f_chest_lumber", [{"roll": "small", "ilvl": 4}])

func _herbalist() -> void:
	_model("building_home_B_red", ground(60, 2), -120.0, 5.0, true)
	_model("building_well_green", ground(49, 0), 0.0, 5.0, true)
	for p in [Vector2(52, 12), Vector2(55, 14), Vector2(48, 9), Vector2(63, 10)]:
		_model("pumpkin_orange" if _rng.randf() < 0.5 else "pumpkin_yellow_small", ground(p.x, p.y), _rng.randf() * 360.0, 1.0)
	var lp := ground(51, 5)
	_model("lantern_standing", lp, 0.0, 1.3)
	var ll := OmniLight3D.new(); ll.light_color = Color(0.6, 0.85, 1.0); ll.light_energy = 1.5; ll.omni_range = 8.0
	ll.position = lp + Vector3(0, 1.0, 0); add_child(ll)
	NPC.create(self, "maera", ground(53, 4), -60.0, {"hero": "Mage", "hat": true, "hair_style": "long",
		"hair_color": Color(0.9, 0.9, 0.92), "hair_tint": Color(0.9, 0.9, 0.92), "face": "blush",
		"outfit_color": Color(0.35, 0.25, 0.55), "cape_color": Color(0.3, 0.2, 0.5), "skin_color": Color(0.93, 0.72, 0.55)})
	Interactable.create(self, "shrine", ground(44, 8), -60.0, "", [], "Maera's Hut")

func _merchant() -> void:
	var c := Vector2(-14, -18)
	_model("wheelbarrow", ground(c.x - 3, c.y + 2), 200.0, 9.0, true)
	for k in 7:
		var nm: String = ["crate_A_big", "crate_B_small", "barrel", "sack"][k % 4]
		_model(nm, ground(c.x + _rng.randf_range(-6, 4), c.y + _rng.randf_range(-5, 5)), _rng.randf() * 360.0, 6.0, k < 4)
	NPC.create(self, "tobble", ground(c.x + 2.5, c.y - 1), 100.0, {"hero": "Rogue", "hair_style": "curly",
		"hair_color": Color(0.85, 0.66, 0.35), "hair_tint": Color(0.85, 0.66, 0.35), "face": "mustache",
		"outfit_color": Color(0.7, 0.55, 0.15), "cape_color": Color(0.55, 0.15, 0.4), "build": 1.2, "height": 0.92})

func _campfire(p: Vector3) -> void:
	var fire := Node3D.new(); add_child(fire); fire.position = p
	for k in 6:
		_model("rock_single_A", p + Vector3(cos(k * 1.05) * 1.0, 0, sin(k * 1.05) * 1.0), k * 40.0, 4.0)
	var fl := GPUParticles3D.new()
	var ppm := ParticleProcessMaterial.new()
	ppm.direction = Vector3.UP; ppm.spread = 12; ppm.initial_velocity_min = 1.0; ppm.initial_velocity_max = 2.2
	ppm.gravity = Vector3(0, 1.0, 0); ppm.scale_min = 0.6; ppm.scale_max = 1.2
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; ppm.emission_sphere_radius = 0.35
	fl.process_material = ppm
	fl.amount = 40; fl.lifetime = 0.8
	fl.draw_pass_1 = FX.quad(0.45)
	fl.material_override = FX.glow_material(Color(1.0, 0.5, 0.15), 3.0)
	fl.position.y = 0.3
	fire.add_child(fl)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.55, 0.25); l.light_energy = 2.4; l.omni_range = 10.0
	l.position.y = 1.4
	l.set_script(load("res://scripts/world/flicker.gd"))
	fire.add_child(l)
	Sfx.loop_on(fire, "loop_fire", -10.0, 4.0, 22.0)

func _goblin_camp(c: Vector2, tag: String) -> void:
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var p := ground(c.x + cos(a) * 8.0, c.y + sin(a) * 8.0)
		_model("tent", p, rad_to_deg(-a) + 90.0, 7.0, true)
	_campfire(ground(c.x, c.y))
	for k in 3:
		var a2 := k * TAU / 3.0
		_model("post_skull", ground(c.x + cos(a2) * 12.5, c.y + sin(a2) * 12.5), rad_to_deg(-a2), 1.0, true)
	for k in 6:
		var nm: String = ["bone_A", "skull", "ribcage", "crate_A_big", "barrel", "sack"][k]
		_model(nm, ground(c.x + _rng.randf_range(-6, 6), c.y + _rng.randf_range(-6, 6)), _rng.randf() * 360.0,
			0.6 if k < 3 else 6.0)
	_model("tree_dead_large", ground(c.x + 10, c.y - 9), 30.0, 1.4)
	var foes := ["goblin", "goblin", "goblin_archer", "goblin", "goblin_brute" if tag == "w" else "goblin_archer", "goblin", "goblin_archer"]
	for k in foes.size():
		var a3 := k * TAU / foes.size()
		_enemy(foes[k], ground(c.x + cos(a3) * 4.0, c.y + sin(a3) * 4.0), "f_camp%s_%d" % [tag, k], a3)
	Interactable.create(self, "chest", ground(c.x - 2, c.y - 10), 0.0, "f_chest_camp_" + tag, [{"roll": "big", "ilvl": 4}])

func _goblin_outpost(c: Vector2) -> void:
	_model("tent", ground(c.x - 4, c.y), 60.0, 6.0, true)
	_model("tree_dead_medium", ground(c.x + 5, c.y + 3), 10.0, 1.3)
	_model("post_skull", ground(c.x + 2, c.y - 5), 200.0, 1.0, true)
	for k in 3:
		_enemy(["goblin", "goblin", "goblin_archer"][k], ground(c.x + k * 2.5 - 2.5, c.y + 2.0), "f_outpost_%d" % k, PI)

func _warren_entrance() -> void:
	var c := ground(0, -101)
	var mine := _model("building_mine_green", c + Vector3(0, -0.4, 0), 0.0, 7.0, false)
	mine.name = "WarrenEntrance"
	# the mine model sits on a ridge; solid blocks either side of the door
	var sb := StaticBody3D.new(); add_child(sb)
	for sx in [-1.0, 1.0]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.5, 8.0, 12.0)
		cs.shape = bs; cs.position = c + Vector3(sx * 4.4, 4.0, -2.0); sb.add_child(cs)
	var back := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(12.0, 8.0, 4.0)
	back.shape = bb; back.position = c + Vector3(0, 4.0, -6.5); sb.add_child(back)
	# great braziers and banners: visible from the portal far to the south
	for sx in [-6.5, 6.5]:
		var bp := c + Vector3(sx, 0, 5.5)
		Props.place(self, "pillar", bp, 0.0, 1.0, true)
		var fire := Node3D.new(); add_child(fire); fire.position = bp + Vector3(0, 4.1, 0)
		var fl := CPUParticles3D.new(); fl.amount = 50; fl.lifetime = 0.9
		fl.mesh = FX.quad(0.7); fl.material_override = FX.glow_material(Color(1.0, 0.45, 0.12), 3.5)
		fl.direction = Vector3.UP; fl.spread = 15; fl.initial_velocity_min = 1.5; fl.initial_velocity_max = 3.0
		fl.gravity = Vector3(0, 1.5, 0); fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fl.emission_sphere_radius = 0.4
		fl.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.15))
		fire.add_child(fl)
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.5, 0.2); l.light_energy = 4.0; l.omni_range = 16.0
		l.set_script(load("res://scripts/world/flicker.gd")); fire.add_child(l)
		_model("flag_red", c + Vector3(sx * 1.4, 0, 3.0), 180.0, 10.0)
	var beacon := c + Vector3(0, 10.5, -4.0)
	Props.place(self, "pillar", beacon - Vector3(0, 3.0, 0), 0.0, 1.4, false)
	var bf := CPUParticles3D.new(); bf.amount = 90; bf.lifetime = 1.3
	bf.mesh = FX.quad(1.3); bf.material_override = FX.glow_material(Color(1.0, 0.45, 0.1), 4.0)
	bf.direction = Vector3.UP; bf.spread = 12; bf.initial_velocity_min = 3.0; bf.initial_velocity_max = 5.5
	bf.gravity = Vector3(0, 2.0, 0); bf.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; bf.emission_sphere_radius = 0.9
	bf.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.15))
	add_child(bf); bf.position = beacon + Vector3(0, 2.2, 0)
	var bl := OmniLight3D.new(); bl.light_color = Color(1.0, 0.5, 0.2); bl.light_energy = 8.0; bl.omni_range = 30.0
	bl.set_script(load("res://scripts/world/flicker.gd")); add_child(bl); bl.position = beacon + Vector3(0, 4.0, 0)
	door = WarrenDoor.make(self, c + Vector3(0, 0, 3.0), Vector3(0, WY + 0.1, -118.0))
	NPC.create(self, "aldric", ground(8.5, -88), 200.0, {"hero": "Knight", "hat": true,
		"outfit_color": Color(0.35, 0.45, 0.75), "cape_color": Color(0.2, 0.3, 0.7), "skin_color": Color(0.66, 0.45, 0.3),
		"face": "mustache", "hair_color": Color(0.12, 0.08, 0.06), "weapon": "sword_1handed", "shield": "shield_round"})
	Interactable.create(self, "shrine", ground(-9, -86), 160.0, "", [], "the Warren Gate")
	_enemy("goblin_brute", ground(-14, -78), "f_gate_brute", 0.5)
	_enemy("goblin", ground(14, -76), "f_gate_g1", 2.0)

# ---------------------------------------------------------------------------
func _scatter_forest() -> void:
	var tree_types := [["tree_single_A", 6.0, 0.55], ["tree_single_B", 6.0, 0.55], ["tree_single_A", 7.5, 0.6],
		["tree_pine_yellow_large", 1.15, 0.5], ["tree_pine_orange_large", 1.1, 0.5], ["tree_pine_yellow_medium", 1.2, 0.4]]
	var count := 0
	var z := -HALF + 6.0
	while z < HALF - 6.0:
		var x := -HALF + 6.0
		while x < HALF - 6.0:
			var p := Vector2(x + _rng.randf_range(-3.0, 3.0), z + _rng.randf_range(-3.0, 3.0))
			x += 7.0
			var dens := noise.get_noise_2d(p.x * 2.1, p.y * 2.1) * 0.5 + 0.55
			if _rng.randf() > dens:
				continue
			if road_dist(p) < 10.0 or stream_dist(p) < 7.5:
				continue
			# keep the long view from the portal to the Warren open
			if absf(p.x) < 15.0 and p.y > -96.0 and p.y < 96.0:
				continue
			var blocked := false
			for c in clearings:
				if p.distance_to(c[0]) < c[1] + 3.0:
					blocked = true
			if blocked:
				continue
			var tt: Array = tree_types[_rng.randi() % tree_types.size()] if _rng.randf() < 0.82 else tree_types[_rng.randi_range(3, 5)]
			var s: float = tt[1] * _rng.randf_range(0.8, 1.25)
			var gp := ground(p.x, p.y) - Vector3(0, 0.2, 0)
			var inside := absf(p.x) < PLAY and absf(p.y) < PLAY
			_instance(tt[0], gp, _rng.randf() * TAU, s, tt[2] * s / tt[1] if inside else 0.0)
			count += 1
		z += 7.0
	# rocks and bushes
	for k in 70:
		var p2 := Vector2(_rng.randf_range(-PLAY, PLAY), _rng.randf_range(-PLAY, PLAY))
		if road_dist(p2) < 7.0 or stream_dist(p2) < 5.0:
			continue
		var r: String = ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"][k % 5]
		var s2 := _rng.randf_range(5.0, 11.0)
		_instance(r, ground(p2.x, p2.y) - Vector3(0, 0.25, 0), _rng.randf() * TAU, s2, 0.12 * s2)
	print("FOREST trees=%d" % count)

func _horizon() -> void:
	# mountains ringing the valley
	var names := ["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees"]
	for k in 22:
		var a := k * TAU / 22.0
		var r := 168.0 + _rng.randf_range(-8, 12)
		var p := Vector3(cos(a) * r, -6.0, sin(a) * r)
		_model(names[k % 3], p, _rng.randf() * 360.0, _rng.randf_range(28.0, 38.0))

func _bounds() -> void:
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	for w in [[Vector3(0, 20, -PLAY - 1), Vector3(PLAY * 2 + 4, 80, 2)], [Vector3(0, 20, PLAY + 1), Vector3(PLAY * 2 + 4, 80, 2)],
			[Vector3(-PLAY - 1, 20, 0), Vector3(2, 80, PLAY * 2 + 4)], [Vector3(PLAY + 1, 20, 0), Vector3(2, 80, PLAY * 2 + 4)]]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = w[1]
		cs.shape = bs; cs.position = w[0]; sb.add_child(cs)

func _motes() -> void:
	# drifting pollen in the sunlight and fireflies in the shade
	for c in [Vector3(0, 3, 70), Vector3(-50, 3, 30), Vector3(50, 3, 0), Vector3(0, 3, -40), Vector3(-30, 3, -70), Vector3(40, 3, 40)]:
		var p := CPUParticles3D.new()
		p.amount = 60; p.lifetime = 8.0; p.preprocess = 8.0
		p.mesh = FX.quad(0.09); p.material_override = FX.glow_material(Color(1.0, 0.95, 0.6), 1.6)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(30, 3, 30)
		p.direction = Vector3(1, 0.2, 0); p.spread = 180; p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.4
		p.gravity = Vector3(0.05, 0.02, 0)
		p.color_ramp = FX._fade_ramp(Color(1.0, 0.95, 0.6))
		add_child(p)
		p.position = c + Vector3(0, height(c.x, c.z), 0)

## The Moonlit Portal (south-east): it wakes when every forest quest is done
## and leads to Level 3, Ghost Knight Castle.
func _moon_portal() -> void:
	var c := ground(MOON_PORTAL.x, MOON_PORTAL.y)
	var face := atan2(-MOON_PORTAL.x, -MOON_PORTAL.y)     # turned toward the valley
	var arch := _model("arch_gate", c + Vector3(0, -0.2, 0), rad_to_deg(face), 1.5, false)
	arch.name = "MoonPortal"
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2)
	disc.mesh = q
	_moon_mat = ShaderMaterial.new(); _moon_mat.shader = load("res://shaders/portal.gdshader")
	disc.material_override = _moon_mat
	_moon_disc = disc
	disc.position = c + Vector3(0, 3.0, 0); disc.rotation.y = face
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_moon_light = OmniLight3D.new(); _moon_light.light_color = Color(0.6, 0.7, 1.0); _moon_light.omni_range = 14.0
	_moon_light.position = c + Vector3(0, 3.0, 0); add_child(_moon_light)
	for k in 6:
		var a := k * TAU / 6.0
		_instance("rock_single_" + ["C", "E", "B"][k % 3], ground(MOON_PORTAL.x + cos(a) * 9.0, MOON_PORTAL.y + sin(a) * 9.0) - Vector3(0, 0.3, 0), a, 7.0)
	Interactable.create(self, "inscription", ground(MOON_PORTAL.x - 5.0, MOON_PORTAL.y - 5.0), rad_to_deg(face), "", [], "Moonlit Portal",
		"THE MOONLIT PORTAL\n\nIt sleeps until the forest is at peace.\nHelp everyone in the Goblin Forest and it will wake,\nand carry you to Castle Morwen: Ghost Knight Castle.")
	_moon_area = Area3D.new(); _moon_area.collision_layer = 0; _moon_area.collision_mask = 2
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.6, 4.0, 1.6)
	cs.shape = bs; _moon_area.add_child(cs)
	add_child(_moon_area)
	_moon_area.position = c + Vector3(0, 2.0, 0); _moon_area.rotation.y = face
	_moon_area.body_entered.connect(func(bd: Node) -> void:
		if bd.is_in_group("player") and Game.zone_complete("forest"):
			_moon_area.set_deferred("monitoring", false)
			Sfx.play("portal", 0.0, 0.0)
			FX.screen_flash(Color(0.8, 0.85, 1.0), 1.0, 1.2)
			var sc := get_tree().current_scene
			if sc.has_method("go_to_castle"):
				get_tree().create_timer(0.5).timeout.connect(sc.go_to_castle))
	Game.quests_changed.connect(_moon_refresh)
	_moon_refresh()

func _moon_refresh() -> void:
	var open := Game.zone_complete("forest")
	_moon_mat.set_shader_parameter("intensity", 2.2 if open else 0.25)
	_moon_light.light_energy = 4.0 if open else 0.6
	_moon_area.monitoring = open
	_moon_disc.visible = open          # asleep: just an empty stone arch

# ---------------------------------------------------------------------------
# Enemies and quests
func _enemy(type_name: String, pos: Vector3, uid: String, yaw: float) -> Enemy:
	if Game.flags.get(uid, false):
		return null
	var e := Enemy.new()
	e.configure(type_name, uid, 0.0)
	e.position = pos + Vector3(0, 0.3, 0)
	e.rotation.y = yaw
	add_child(e)
	return e

## Chief Gruk calls two goblins to his side when badly hurt.
func summon_for(e: Enemy) -> void:
	if e.type_id == "cyclops":
		Game.say("Grimgor: \"EMBER BOYS! BURN TINY HERO!\"", Color(1.0, 0.45, 0.2))
		for k in 3:
			var sp := e.global_position + Vector3(-7.0 + k * 7.0, 0.2, 5.0)
			FX.burst(sp + Vector3(0, 1, 0), Color(1.0, 0.45, 0.1), 30, 3.0, 0.3, 0.8, 0.5)
			var fg := Enemy.new()
			fg.configure("fire_goblin" if k != 1 else "fire_archer", "", 0.0)
			fg.position = sp
			add_child(fg)
		return
	Game.say("Gruk: \"BOYS! Get 'em!\"", Color(1.0, 0.5, 0.3))
	for k in 2:
		var p := e.global_position + Vector3(-5.0 + k * 10.0, 0.2, 4.0)
		FX.burst(p + Vector3(0, 1, 0), Color(0.6, 0.9, 0.3), 30, 3.0, 0.3, 0.8, 0.5)
		var g := Enemy.new()
		g.configure("goblin" if k == 0 else "goblin_archer", "", 0.0)
		g.position = p
		add_child(g)

func _quest_items() -> void:
	# Bram's stolen axes: one in each goblin camp and one at the outpost
	QuestItem.create(self, "axe", "qi_axe_w", ground(-62, -36))
	QuestItem.create(self, "axe", "qi_axe_e", ground(64, -55))
	QuestItem.create(self, "axe", "qi_axe_o", ground(39, 65))
	# Maera's moonpetals: shady spots near the stream and under big trees
	var k := 0
	for p in [Vector2(30, 22), Vector2(78, 18), Vector2(70, -14), Vector2(-28, 10), Vector2(-80, 26), Vector2(20, -6),
			Vector2(-44, -18), Vector2(86, -30), Vector2(-70, 60)]:
		QuestItem.create(self, "moonpetal", "qi_petal_%d" % k, ground(p.x, p.y))
		k += 1
	# goblins have made camp by some of Maera's favourite spots
	var gk := 0
	for g in [[Vector2(78, 18), ["goblin", "goblin_archer"]], [Vector2(-80, 26), ["goblin", "goblin"]],
			[Vector2(-44, -18), ["goblin_archer", "goblin", "goblin"]], [Vector2(86, -30), ["goblin_brute"]], [Vector2(-70, 60), ["goblin", "goblin_archer"]]]:
		var at: Vector2 = g[0]
		var foes: Array = g[1]
		for i in foes.size():
			var a := TAU * i / foes.size()
			_enemy(foes[i], ground(at.x + cos(a) * 3.5, at.y + sin(a) * 3.5), "f_petalguard_%d" % gk, a)
			gk += 1

# ---------------------------------------------------------------------------
# The Goblin Warren: a dungeon dug beneath the northern ridge.
func _warren() -> void:
	var wm: Material = b.wall_mat(Color(0.32, 0.27, 0.2), 0.45, WY, 1.6, 0.7)
	var fm: Material = b.mats.floor
	var Y := WY
	# entry cavern
	b.room(-8, 8, -126, -110, Y, 7.0, wm, fm, {"n": [[-2.5, 2.5, 4.5]]})
	# tunnel
	b.room(-2.5, 2.5, -140, -126, Y, 4.5, wm, fm, {"s": [[-2.5, 2.5, 4.5]], "n": [[-2.5, 2.5, 4.5]]})
	# goblin den
	b.room(-13, 13, -164, -140, Y, 8.0, wm, fm, {"s": [[-2.5, 2.5, 4.5]], "n": [[-3.0, 3.0, 5.0]]})
	# Gruk's hall
	b.room(-16, 16, -198, -164, Y, 10.0, wm, fm, {"s": [[-3.0, 3.0, 5.0]]})
	for z in [-170.0, -182.0, -192.0]:
		b.pillar(Vector3(-10, Y, z), 10.0, 0.7, wm)
		b.pillar(Vector3(10, Y, z), 10.0, 0.7, wm)
	for p in [Vector3(-7.9, Y + 3, -118), Vector3(7.9, Y + 3, -118), Vector3(-12.9, Y + 3.2, -150), Vector3(12.9, Y + 3.2, -155),
			Vector3(-15.9, Y + 4, -175), Vector3(15.9, Y + 4, -175), Vector3(-15.9, Y + 4, -190), Vector3(15.9, Y + 4, -190)]:
		Props.torch(self, p, 90.0 if p.x < 0 else -90.0, true)
	# glowing mushrooms and goblin junk
	for k in 18:
		var mp := Vector3(_rng.randf_range(-12, 12), Y, _rng.randf_range(-196, -112))
		if absf(mp.x) > 2.0 or mp.z < -140.0 or mp.z > -126.0:
			_mushroom(mp)
	_campfire(Vector3(0, Y, -152))
	for k in 5:
		_model("tent" if k < 2 else ["crate_A_big", "barrel", "sack"][k - 2], Vector3(_rng.randf_range(-10, 10), Y, _rng.randf_range(-160, -144)),
			_rng.randf() * 360.0, 6.0 if k >= 2 else 5.0, true)
	for hz in [-172.0, -184.0, -194.0]:
		var hl := OmniLight3D.new(); hl.light_color = Color(1.0, 0.7, 0.45); hl.light_energy = 1.6; hl.omni_range = 16.0
		hl.position = Vector3(0, Y + 7.5, hz); add_child(hl)
	_campfire(Vector3(-8, Y, -186))
	_campfire(Vector3(8, Y, -186))
	for p2 in [Vector3(-2.9, Y + 3.0, -132), Vector3(2.9, Y + 3.0, -136)]:
		Props.torch(self, p2, 90.0 if p2.x < 0 else -90.0, true)
	_model("skull", Vector3(-12, Y, -194), 30.0, 1.4)
	_model("ribcage", Vector3(11, Y, -195), 10.0, 1.4)
	_model("post_skull", Vector3(-4, Y, -195), 0.0, 1.2, true)
	_model("post_skull", Vector3(4, Y, -195), 0.0, 1.2, true)
	Interactable.create(self, "shrine", Vector3(-5, Y, -114), 0.0, "", [], "the Warren Mouth")
	ClimbOut.make(self, Vector3(5, Y, -113), ground(0, -94) + Vector3(0, 0.2, 0))
	# goblins
	var n := 0
	for e in [[Vector3(-5, Y, -147), "goblin"], [Vector3(5, Y, -149), "goblin"], [Vector3(-8, Y, -158), "goblin_archer"],
			[Vector3(8, Y, -157), "goblin_archer"], [Vector3(0, Y, -160), "goblin_brute"], [Vector3(-3, Y, -133), "goblin"]]:
		_enemy(e[1], e[0], "w_gob_%d" % n, PI * 0.0)
		n += 1
	gruk = _enemy("goblin_chief", Vector3(0, Y, -188), "gruk", 0.0)
	# the merchant's strongbox sits behind the chief's throne
	QuestItem.create(self, "strongbox", "qi_strongbox", Vector3(0, Y, -195))
	if gruk:
		gruk.died.connect(func(_e: Enemy) -> void:
			Sfx.music("music_explore", -15.0)
			Interactable.create(self, "chest", Vector3(6, Y, -193), -30.0, "w_chest_gruk", [{"roll": "boss"}])
			Game.say("Chief Gruk falls with a mighty THUD. The Warren is yours!", Color(1.0, 0.85, 0.4)))
	elif not Game.flags.get("w_chest_gruk", false):
		Interactable.create(self, "chest", Vector3(6, Y, -193), -30.0, "w_chest_gruk", [{"roll": "boss"}])

func _mushroom(p: Vector3) -> void:
	var col := Color(0.35, 0.9, 0.75) if _rng.randf() < 0.6 else Color(0.75, 0.45, 1.0)
	var cap := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.35; sm.height = 0.35; sm.is_hemisphere = true
	cap.mesh = sm; cap.material_override = FX.glow_material(col, 1.6)
	cap.position = p + Vector3(0, 0.4, 0)
	add_child(cap)
	var stem := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.1; cm.height = 0.42
	stem.mesh = cm; var st := StandardMaterial3D.new(); st.albedo_color = Color(0.85, 0.82, 0.7); stem.material_override = st
	stem.position = p + Vector3(0, 0.21, 0)
	add_child(stem)
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 0.8; l.omni_range = 4.0
	l.position = p + Vector3(0, 0.8, 0); add_child(l)
