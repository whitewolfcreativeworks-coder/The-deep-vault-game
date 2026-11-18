extends ForestWorld
class_name CastleWorld
## Level 3: GHOST KNIGHT CASTLE. A misty, moonlit moor reached through the
## Moonlit Portal once every Goblin Forest quest is done.
##
## South: the arrival portal (and the way back to the forest).
## Middle: the village of Ashenford and its seven quest givers.
## West: the graveyard, with the crypt stairs down to the crypt (y = CY).
## East: the ruined chapel where the wraiths wail.
## Hills: three old beacons to light.
## North: Castle Morwen. The gate stays shut until the Gatehouse Warden falls;
## inside are the courtyard, the great hall, the library and, at the back, the
## Ghost Lord's throne. Beating him earns the second mount: the moped.
##
## Shares the forest's terrain and model helpers (it extends ForestWorld) but
## builds its own land, sky and places.

const CY := -60.0                 # crypt floor
const KY := 3.0                   # castle plateau height
const GATE_Z := -50.0             # curtain wall (south face)
const BACK_Z := -108.0
const WALL_X := 40.0
const HW_DIR := "res://assets/kaykit/halloween/%s.gltf"
const PORTAL := Vector2(0.0, 100.0)
const VILLAGE := Vector2(0.0, 52.0)
const GRAVES := Vector2(-62.0, 22.0)
const CHAPEL := Vector2(62.0, 18.0)
const BEACONS := [Vector2(-92.0, -22.0), Vector2(92.0, -26.0), Vector2(-70.0, 80.0)]
const CRYPT_DOOR := Vector2(-62.0, 6.0)
const MERE := Vector2(48.0, 74.0)        # the Misty Mere: fishing (Old Gill)
const MERE_R := 11.0
var mere_y := 0.0
const PADDOCK := Vector2(29.0, 54.0)     # Pip's paddock, where the spooked horses come home
const HORSE_SPOTS := [Vector2(44.0, 30.0), Vector2(-34.0, 38.0), Vector2(26.0, 90.0), Vector2(-44.0, 86.0)]
var horses: Array[GhostHorse] = []

var spawn_yaw := 0.0
var warden: Enemy
var lord: Enemy
var portcullis: Node3D
var _gate_open := false
var _lord_started := false
var _beacon_fires := {}          # quest item uid -> Node3D (the fire, hidden until lit)
var _back_area: Area3D

func _wild_spot_ok(p: Vector2) -> bool:
	if road_dist(p) < 8.0 or _in_castle(p, 8.0):
		return false
	for c in clearings:
		if p.distance_to(c[0]) < c[1] + 4.0:
			return false
	var h := height(p.x, p.y)
	for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(height(p.x + d.x, p.y + d.y) - h) > 1.2:
			return false
	return true

func _in_castle(p: Vector2, pad := 0.0) -> bool:
	return absf(p.x) < WALL_X + 6.0 + pad and p.y < GATE_Z + 6.0 + pad

func build() -> void:
	_rng.seed = 31
	noise.seed = 23; noise.frequency = 0.013; noise.fractal_octaves = 3
	detail_noise.seed = 9; detail_noise.frequency = 0.07
	pal = {"grass_a": Color(0.22, 0.3, 0.2), "grass_b": Color(0.3, 0.34, 0.24), "dirt": Color(0.34, 0.3, 0.26),
		"rock": Color(0.36, 0.37, 0.4), "bed": Color(0.25, 0.27, 0.25)}
	road = PackedVector2Array([Vector2(0, 104), Vector2(-3, 80), Vector2(2, 62), Vector2(0, 40), Vector2(-4, 14),
		Vector2(3, -14), Vector2(0, -36), Vector2(0, -52)])
	b = Builder.new(self)
	clearings = [[PORTAL, 12.0], [VILLAGE, 22.0], [GRAVES, 20.0], [CHAPEL, 15.0], [Vector2(0, -40), 12.0], [MERE, MERE_R + 6.0], [PADDOCK, 8.0]]
	for bp in BEACONS:
		clearings.append([bp, 6.0])
	_environment()
	_terrain()
	_trunks = StaticBody3D.new(); _trunks.collision_layer = 1; add_child(_trunks)
	_arrival()
	_village()
	_graveyard()
	_chapel()
	_beacons()
	_castle()
	_crypt()
	_mere()
	_paddock()
	b.fix_coplanar()      # stone boxes that share a face would flicker: nudge them apart
	_moors()
	_scatter()
	_horizon()
	_bounds()
	_flush_multimeshes()
	_mist()
	Game.quests_changed.connect(_on_quests)
	_on_quests()
	wild_chests = WildChests.create(self, Rect2(-PLAY + 8, -40, (PLAY - 8) * 2, 40 + PLAY - 8), ground, _wild_spot_ok, 5, 8)
	if Game.is_compat():
		for l in find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				(l as Light3D).shadow_enabled = false
		env.tonemap_exposure = 1.15

# ---------------------------------------------------------------------------
# Land
func stream_dist(_p: Vector2) -> float:
	return 999.0

func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := noise.get_noise_2d(x, z) * 6.0 + 1.5
	var rd := road_dist(p)
	h = lerpf(h, h * 0.3, smoothstep(14.0, 5.0, rd))
	for c in clearings:
		var cd: float = p.distance_to(c[0])
		var ch := noise.get_noise_2d(c[0].x, c[0].y) * 6.0 * 0.3 + 0.45
		h = lerpf(h, ch, smoothstep(c[1] + 8.0, c[1] * 0.6, cd))
	# the Misty Mere: a bowl in the moor that holds the water
	var md := p.distance_to(MERE)
	if md < MERE_R + 5.0:
		var rim := noise.get_noise_2d(MERE.x, MERE.y) * 6.0 * 0.3 + 0.45
		h = lerpf(h, rim - 2.4, smoothstep(MERE_R + 4.0, MERE_R - 3.0, md))
	# the beacon hills
	for bp in BEACONS:
		h += smoothstep(18.0, 3.0, p.distance_to(bp)) * 9.0
	var edge := maxf(absf(x), absf(z))
	if edge > 100.0:
		h += pow(edge - 100.0, 1.6) * 0.18
	# the castle's flat hilltop
	var k := smoothstep(WALL_X + 14.0, WALL_X + 6.0, absf(x)) * smoothstep(GATE_Z + 16.0, GATE_Z + 6.0, z)
	# a hair below the castle's stone floors, so ground and floor never flicker against each other
	return lerpf(h, KY - 0.12, k)

func _hw(name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0, collide := false) -> Node3D:
	var path := HW_DIR % name
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

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.03, 0.05, 0.12)
	psm.sky_horizon_color = Color(0.16, 0.2, 0.3)
	psm.ground_horizon_color = Color(0.1, 0.12, 0.16)
	psm.ground_bottom_color = Color(0.02, 0.03, 0.05)
	psm.sun_angle_max = 6.0
	psm.sun_curve = 0.3
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.6)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.2, 0.25, 0.36)
	env.fog_depth_begin = 25.0
	env.fog_depth_end = 220.0
	env.fog_density = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.7, 0.78, 0.95)
	env.volumetric_fog_length = 50.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	we.environment = env
	add_child(we)
	# the moon
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_color = Color(0.62, 0.72, 1.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.light_volumetric_fog_energy = 2.0
	add_child(sun)
	var moon := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 9.0; sm.height = 18.0
	moon.mesh = sm; moon.material_override = FX.glow_material(Color(0.85, 0.9, 1.0), 2.5)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	moon.position = sun.global_transform.basis.z * 320.0 + Vector3(0, 20, 0)
	day_night = null

func _set_area(a: String) -> void:
	if a == area:
		return
	area = a
	area_changed.emit(a)
	var under := a == "crypt"
	sun.visible = not under
	env.background_mode = Environment.BG_COLOR if under else Environment.BG_SKY
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_color = Color(0.26, 0.3, 0.42) if under else Color(0.36, 0.42, 0.6)
	env.ambient_light_energy = 0.8 if under else 0.75
	env.fog_light_color = Color(0.04, 0.05, 0.08) if under else Color(0.2, 0.25, 0.36)
	env.fog_depth_begin = 8.0 if under else 25.0
	env.fog_depth_end = 70.0 if under else 220.0
	env.volumetric_fog_density = 0.03 if under else (0.008 if _beacons_lit() else 0.014)
	if a == "castle" and not _lord_started:
		Sfx.music("music_explore", -15.0)

## Ghosts keep coming back while a quest needs them: wraiths at the chapel and
## in the crypt, ghost knights on the moors, archers on the hills. [quest, type,
## spots, how many to keep around at once].
const HAUNTS := [
	["wraith_hunt", "wraith", [Vector2(62, 12), Vector2(56, 22), Vector2(68, 24), Vector2(62, 32), Vector2(74, 10), Vector2(30, 34), Vector2(-20, 80)], 3],
	["restless_dead", "ghost_knight", [Vector2(-6, 20), Vector2(28, -12), Vector2(-30, -8), Vector2(42, 48), Vector2(-40, 70)], 4],
	["archers_on_walls", "ghost_archer", [Vector2(-86, -18), Vector2(86, -22), Vector2(-66, 30), Vector2(-74, 76), Vector2(60, -40)], 4],
]
var _haunt_t := 0.0
var _haunted: Array = []

func _haunt(delta: float) -> void:
	_haunt_t -= delta
	if _haunt_t > 0.0:
		return
	_haunt_t = 6.0
	_haunted = _haunted.filter(func(e) -> bool: return is_instance_valid(e) and not e.dead)
	for h in HAUNTS:
		if Game.quest_state(h[0]) != "active":
			continue
		var alive := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and not e.dead and e.type_id == h[1] and e.global_position.y > CY + 20.0:
				alive += 1
		if alive >= int(h[3]):
			continue
		# rise at a spot out of the player's sight-line (not right on top of them)
		var spots: Array = (h[2] as Array).filter(func(p: Vector2) -> bool:
			return Vector2(player.global_position.x, player.global_position.z).distance_to(p) > 14.0)
		if spots.is_empty():
			continue
		var at: Vector2 = spots[randi() % spots.size()]
		var g := Enemy.new()
		g.configure(h[1], "", 0.0)
		g.position = ground(at.x + randf_range(-3, 3), at.y + randf_range(-3, 3)) + Vector3(0, 0.3, 0)
		add_child(g)
		_haunted.append(g)
		FX.burst(g.position + Vector3(0, 1, 0), Color(0.55, 0.8, 1.0), 30, 3.0, 0.3, 0.9, 0.5)

func _process(delta: float) -> void:
	if player == null:
		return
	_haunt(delta)
	player.kill_y = CY - 30.0
	var pp := player.global_position
	_set_area("crypt" if pp.y < CY + 20.0 else "castle")
	if not _lord_started and lord and is_instance_valid(lord) and not lord.dead and pp.y > KY - 2.0 and pp.z < -86.0 and absf(pp.x) < 15.0:
		_lord_started = true
		Sfx.music("music_boss", -10.0)
		Game.say("Morwen, the Ghost Lord: \"Another hero for my army of the dead...\"", Color(0.6, 0.8, 1.0))

func reset_boss() -> void:
	if _lord_started and lord and is_instance_valid(lord) and not lord.dead:
		_lord_started = false
		lord.hp = lord.max_hp
		Sfx.music("music_explore", -15.0)

## The Ghost Lord and the Warden call up more ghosts when badly hurt.
func summon_for(e: Enemy) -> void:
	if e.type_id == "bone_colossus":
		Game.say("The Bone Colossus roars, and the floor cracks open...", Color(0.55, 1.0, 0.75))
		for k in 3:
			var sp := e.global_position + Vector3(-6.0 + k * 6.0, 0.3, 6.0)
			var s2 := Enemy.new(); s2.configure("crypt_skeleton", "", 2.0)
			s2.position = sp
			add_child(s2)
		return
	Game.say("%s: \"Rise, my knights!\"" % ("Morwen" if e.type_id == "ghost_lord" else "The Warden"), Color(0.6, 0.8, 1.0))
	var foes := ["ghost_knight", "wraith", "ghost_knight"] if e.type_id == "ghost_lord" else ["ghost_knight", "ghost_archer"]
	for k in foes.size():
		var sp := e.global_position + Vector3(-6.0 + k * 6.0, 0.2, 5.0)
		FX.burst(sp + Vector3(0, 1, 0), Color(0.55, 0.8, 1.0), 30, 3.0, 0.3, 0.8, 0.5)
		var g := Enemy.new()
		g.configure(foes[k], "", 0.0)
		g.position = sp
		add_child(g)

# ---------------------------------------------------------------------------
# Places
func _portal_disc(c: Vector3, yaw: float, col: Color) -> void:
	var disc := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.4, 5.2)
	disc.mesh = q
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/portal.gdshader")
	pm.set_shader_parameter("intensity", 2.0)
	disc.material_override = pm
	disc.position = c + Vector3(0, 3.0, 0); disc.rotation.y = yaw
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	var pl := OmniLight3D.new(); pl.light_color = col; pl.light_energy = 3.0; pl.omni_range = 12.0
	pl.position = c + Vector3(0, 3.0, 0); add_child(pl)

func _arrival() -> void:
	var c := ground(PORTAL.x, PORTAL.y)
	_model("arch_gate", c + Vector3(0, -0.2, 0), 0.0, 1.5, false).name = "Portal"
	_portal_disc(c, 0.0, Color(0.6, 0.7, 1.0))
	var sb := StaticBody3D.new(); add_child(sb)
	for sx in [-3.0, 3.0]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.2, 6.5, 1.2)
		cs.shape = bs; cs.position = c + Vector3(sx * 1.05, 3.2, 0); sb.add_child(cs)
	spawn_point = ground(PORTAL.x, PORTAL.y - 8.0) + Vector3(0, 0.15, 0)
	# walk back into the portal to return to the Goblin Forest
	_back_area = Area3D.new(); _back_area.collision_layer = 0; _back_area.collision_mask = 2
	var ac := CollisionShape3D.new(); var ab := BoxShape3D.new(); ab.size = Vector3(3.6, 4.0, 1.2)
	ac.shape = ab; _back_area.add_child(ac); add_child(_back_area)
	_back_area.position = c + Vector3(0, 2.0, 0.4)
	_back_area.body_entered.connect(func(bd: Node) -> void:
		if bd.is_in_group("player") and Game.play_time > 3.0:
			_back_area.set_deferred("monitoring", false)
			Sfx.play("portal", 0.0, 0.0)
			FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
			var sc := get_tree().current_scene
			if sc.has_method("go_to_forest"):
				get_tree().create_timer(0.5).timeout.connect(sc.go_to_forest))
	for k in 6:
		var a := PI * 0.25 + k * PI * 0.3
		_hw("gravemarker_" + ["A", "B"][k % 2], ground(PORTAL.x + sin(a) * 11.0, PORTAL.y + cos(a) * 11.0), rad_to_deg(a), 1.4)
	Interactable.create(self, "inscription", ground(PORTAL.x - 4.0, PORTAL.y - 4.0), 180.0, "", [], "Signpost",
		"ASHENFORD  →  north\\nCASTLE MORWEN  →  beyond the village\\n\\n(Someone has scrawled: \\\"GO BACK! THE GHOSTS!\\\")\\n\\nStep back into the portal to return to the Goblin Forest.")

func _lamp(p: Vector3, col := Color(1.0, 0.7, 0.4)) -> void:
	_model("lantern_standing", p, 0.0, 1.4)
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 1.8; l.omni_range = 9.0
	l.position = p + Vector3(0, 1.1, 0); add_child(l)

func _village() -> void:
	var c := VILLAGE
	var houses := [["building_home_A_green", Vector2(-16, 40), 70.0], ["building_home_B_red", Vector2(17, 38), -70.0],
		["building_home_A_green", Vector2(-19, 60), 110.0], ["building_home_B_red", Vector2(18, 64), -110.0],
		["building_tower_A_green", Vector2(-6, 72), 180.0]]
	for hz in houses:
		var hp: Vector2 = hz[1]
		_model(hz[0], ground(hp.x, hp.y) - Vector3(0, 0.2, 0), hz[2], 5.0, true)
	_model("building_well_green", ground(c.x + 5, c.y - 2), 0.0, 5.0, true)
	for p in [Vector2(-5, 44), Vector2(5, 44), Vector2(-6, 62), Vector2(7, 60), Vector2(0, 30)]:
		_lamp(ground(p.x, p.y))
	_hw("pumpkin_orange_jackolantern", ground(-9, 46), 20.0, 1.6)
	_hw("pumpkin_orange_jackolantern", ground(10, 56), -40.0, 1.6)
	_hw("bench", ground(-3, 50), 90.0, 1.4, true)
	_campfire(ground(2, 48))
	for k in 5:
		_model(["crate_A_big", "barrel", "sack", "barrel", "crate_B_small"][k], ground(12 + k * 1.3, 44 + (k % 2) * 1.5), k * 50.0, 6.0, k < 2)
	Interactable.create(self, "shrine", ground(-7, 54), 90.0, "", [], "Ashenford")
	# the villagers (each with a beam of light over their head while they need you)
	NPC.create(self, "elowen", ground(-4, 57), 160.0, {"hero": "Mage", "hat": false, "hair_style": "long",
		"hair_color": Color(0.85, 0.82, 0.7), "hair_tint": Color(0.85, 0.82, 0.7), "face": "blush",
		"outfit_color": Color(0.85, 0.85, 0.9), "cape_color": Color(0.5, 0.55, 0.75), "skin_color": Color(0.9, 0.72, 0.6)})
	NPC.create(self, "mott", ground(-12, 49), 120.0, {"hero": "Barbarian", "hair_style": "bald",
		"hair_color": Color(0.6, 0.6, 0.6), "face": "beard", "outfit_color": Color(0.35, 0.3, 0.25), "cape_color": Color(0.25, 0.2, 0.18),
		"skin_color": Color(0.8, 0.62, 0.5), "build": 1.1, "height": 0.9, "weapon": "skel_axe"})
	NPC.create(self, "brannoc", ground(9, 47), -120.0, {"hero": "Knight", "hat": true, "hair_style": "natural",
		"hair_color": Color(0.3, 0.2, 0.12), "face": "eyepatch", "outfit_color": Color(0.55, 0.15, 0.15), "cape_color": Color(0.5, 0.1, 0.1),
		"skin_color": Color(0.75, 0.55, 0.4), "build": 1.15})
	NPC.create(self, "holt", ground(13, 40), -150.0, {"hero": "Ranger", "hair_style": "natural",
		"hair_color": Color(0.15, 0.12, 0.1), "face": "mustache", "outfit_color": Color(0.5, 0.15, 0.15), "cape_color": Color(0.4, 0.12, 0.12),
		"skin_color": Color(0.6, 0.42, 0.3)})
	NPC.create(self, "ansel", ground(-9, 64), 150.0, {"hero": "Mage", "hat": false, "hair_style": "bald",
		"hair_color": Color(0.4, 0.3, 0.2), "face": "none", "outfit_color": Color(0.45, 0.32, 0.2), "cape_color": Color(0.4, 0.3, 0.2),
		"skin_color": Color(0.88, 0.68, 0.52), "build": 1.15})
	NPC.create(self, "pip", ground(11, 61), -160.0, {"hero": "Rogue", "hair_style": "curly",
		"hair_color": Color(0.9, 0.55, 0.2), "hair_tint": Color(0.9, 0.55, 0.2), "face": "blush",
		"outfit_color": Color(0.3, 0.45, 0.25), "cape_color": Color(0.25, 0.35, 0.2), "skin_color": Color(0.95, 0.75, 0.6), "height": 0.8})
	# Lady Wren waits by the castle gate (she's a friendly ghost)
	NPC.create(self, "wren", ground(15, -37), -150.0, {"hero": "Mage", "hat": false, "hair_style": "long",
		"hair_color": Color(0.75, 0.85, 1.0), "hair_tint": Color(0.75, 0.85, 1.0), "face": "blush",
		"outfit_color": Color(0.6, 0.7, 0.95), "cape_color": Color(0.5, 0.6, 0.9), "skin_color": Color(0.82, 0.88, 1.0)})
	var wl := OmniLight3D.new(); wl.light_color = Color(0.6, 0.8, 1.0); wl.light_energy = 1.5; wl.omni_range = 6.0
	wl.position = ground(15, -37) + Vector3(0, 2.2, 0); add_child(wl)

func _graveyard() -> void:
	var c := GRAVES
	# fence ring with a gate facing the village
	for k in 20:
		var a := k * TAU / 20.0
		if absf(wrapf(a, -PI, PI)) < 0.35:
			continue                         # the gap on the east side
		var p := ground(c.x + cos(a) * 18.0, c.y + sin(a) * 18.0)
		_hw("fence" if k % 4 != 0 else "fence_broken", p, rad_to_deg(-a) + 90.0, 1.8, true)
	_hw("fence_gate", ground(c.x + 18.0, c.y), 90.0, 1.8)
	var names := ["grave_A", "grave_B", "gravestone", "grave_A_destroyed", "gravemarker_A", "gravemarker_B"]
	for row in 4:
		for col in 5:
			var gp := Vector2(c.x - 12.0 + col * 5.5 + _rng.randf_range(-0.8, 0.8), c.y + 4.0 + row * 3.6)
			_hw(names[(row * 5 + col) % names.size()], ground(gp.x, gp.y), 180.0 + _rng.randf_range(-12, 12), 1.5)
	_hw("tree_dead_large_decorated", ground(c.x - 12, c.y - 10), 30.0, 1.8)
	_hw("tree_dead_small", ground(c.x + 10, c.y - 12), 80.0, 1.8)
	_hw("tree_dead_large_decorated", ground(c.x + 6, c.y + 16), 200.0, 1.6)
	_hw("shrine_candles", ground(c.x - 14, c.y + 2), 90.0, 1.5)
	_hw("skull_candle", ground(c.x + 4, c.y - 4), 0.0, 1.5)
	for p in [Vector2(c.x + 15, c.y - 4), Vector2(c.x + 15, c.y + 4)]:
		_lamp(ground(p.x, p.y), Color(0.55, 0.85, 0.7))
	# the crypt: stairs down below the graveyard
	var cd := ground(CRYPT_DOOR.x, CRYPT_DOOR.y)
	_hw("crypt", cd, 0.0, 1.0, true)          # 6 x 8 m, its door faces the village side (+z)
	for sx in [-2.2, 2.2]:
		_hw("candle_triple", cd + Vector3(sx, 0, 5.0), 0.0, 1.5)
	var cl := OmniLight3D.new(); cl.light_color = Color(0.5, 0.75, 1.0); cl.light_energy = 2.0; cl.omni_range = 8.0
	cl.position = cd + Vector3(0, 2.0, 5.0); add_child(cl)
	Passage.make(self, cd + Vector3(0, 0, 4.9), Vector3(-62, CY + 0.1, 18), 0.0, "Go down into the Bone Crypt", "The Bone Crypt")
	# mounds of dug-up earth between the graves, each hiding a locket (dig with USE);
	# two of them have a skeleton in them too
	var k2 := 0
	for p in [Vector2(-70, 12), Vector2(-54, 18), Vector2(-66, 30), Vector2(-50, 32), Vector2(-74, 24)]:
		if not Game.flags.get("qi_locket_%d" % k2, false):
			DigMound.make(self, ground(p.x, p.y), "qi_locket_%d" % k2, k2 == 1 or k2 == 3)
		k2 += 1
	var n := 0
	for e in [[Vector2(-70, 8), "ghost_archer"], [Vector2(-52, 10), "ghost_knight"], [Vector2(-60, 34), "ghost_archer"],
			[Vector2(-76, 30), "ghost_knight"], [Vector2(-56, 26), "ghost_knight"]]:
		_enemy(e[1], ground(e[0].x, e[0].y), "c_grave_%d" % n, _rng.randf() * TAU)
		n += 1

func _chapel() -> void:
	var c := CHAPEL
	var y := height(c.x, c.y)
	var wm: Material = b.wall_mat(Color(0.42, 0.42, 0.46), 0.3, y, 1.4, 0.6)
	# broken walls: high at the back, crumbling toward the front
	b.box(Vector3(c.x - 7, y - 1, c.y - 11), Vector3(c.x + 7, y + 8, c.y - 10), wm)
	b.box(Vector3(c.x - 8, y - 1, c.y - 11), Vector3(c.x - 7, y + 6.5, c.y + 1), wm)
	b.box(Vector3(c.x - 8, y - 1, c.y + 4), Vector3(c.x - 7, y + 2.5, c.y + 10), wm)
	b.box(Vector3(c.x + 7, y - 1, c.y - 11), Vector3(c.x + 8, y + 5.0, c.y - 2), wm)
	b.box(Vector3(c.x + 7, y - 1, c.y + 2), Vector3(c.x + 8, y + 1.8, c.y + 7), wm)
	b.box(Vector3(c.x - 8, y - 1, c.y + 9), Vector3(c.x - 3, y + 3.0, c.y + 10), wm)
	b.box(Vector3(c.x + 4, y - 1, c.y + 9), Vector3(c.x + 8, y + 1.2, c.y + 10), wm)
	b.box(Vector3(c.x - 2, y + 7.5, c.y - 11.5), Vector3(c.x + 2, y + 11.0, c.y - 10.0), wm)   # bell gable
	b.box(Vector3(c.x - 2.0, y - 0.5, c.y - 9.0), Vector3(c.x + 2.0, y + 1.0, c.y - 7.5), wm)   # altar
	_hw("plaque_candles", Vector3(c.x, y + 1.0, c.y - 8.2), 0.0, 1.4)
	for k in 6:
		_hw("bench", Vector3(c.x + (-3.0 if k % 2 == 0 else 3.0), y, c.y - 4.0 + int(k / 2) * 3.2), 0.0, 1.4)
	for p in [Vector3(c.x - 6, y, c.y - 8), Vector3(c.x + 6, y, c.y - 8)]:
		_hw("candle_melted", p, 0.0, 1.6)
		var l := OmniLight3D.new(); l.light_color = Color(0.5, 0.65, 1.0); l.light_energy = 1.6; l.omni_range = 8.0
		l.position = p + Vector3(0, 1.2, 0); add_child(l)
	var n := 0
	for e in [Vector2(c.x - 3, c.y - 6), Vector2(c.x + 3, c.y - 2), Vector2(c.x, c.y + 4), Vector2(c.x + 10, c.y + 12), Vector2(c.x - 11, c.y - 4)]:
		_enemy("wraith", ground(e.x, e.y), "c_chapel_%d" % n, PI * 0.5)
		n += 1
	_enemy("ghost_knight", ground(c.x - 2, c.y + 14), "c_chapel_k", 0.0)
	Interactable.create(self, "chest", Vector3(c.x + 4.5, y, c.y - 8.5), -20.0, "c_chest_chapel", [{"roll": "big", "ilvl": 8}])

func _beacons() -> void:
	var n := 0
	for bp in BEACONS:
		var g := ground(bp.x, bp.y)
		Props.place(self, "pillar", g - Vector3(0, 0.2, 0), 0.0, 0.9, true)
		var fire := Node3D.new(); add_child(fire); fire.position = g + Vector3(0, 3.6, 0)
		var fl := CPUParticles3D.new(); fl.amount = 70; fl.lifetime = 1.0
		fl.mesh = FX.quad(0.9); fl.material_override = FX.glow_material(Color(1.0, 0.6, 0.2), 3.5)
		fl.direction = Vector3.UP; fl.spread = 14; fl.initial_velocity_min = 2.0; fl.initial_velocity_max = 4.0
		fl.gravity = Vector3(0, 1.5, 0); fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fl.emission_sphere_radius = 0.5
		fl.color_ramp = FX._fade_ramp(Color(1.0, 0.6, 0.2))
		fire.add_child(fl)
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.6, 0.25); l.light_energy = 6.0; l.omni_range = 26.0
		l.set_script(load("res://scripts/world/flicker.gd")); fire.add_child(l)
		var uid := "qi_beacon_%d" % n
		_beacon_fires[uid] = fire
		QuestItem.create(self, "beacon", uid, g + Vector3(0, 0, 2.2))
		for k in 2:
			var a := k * PI + 0.7
			_enemy("ghost_archer", ground(bp.x + cos(a) * 7.0, bp.y + sin(a) * 7.0), "c_beacon_%d_%d" % [n, k], a)
		n += 1

func _beacons_lit() -> bool:
	for uid in _beacon_fires:
		if not Game.flags.get(uid, false):
			return false
	return true

func _castle() -> void:
	var wm: Material = b.wall_mat(Color(0.38, 0.4, 0.46), 0.25, KY, 1.8, 0.7)
	var Y := KY - 1.0
	var H := 13.0
	# curtain walls (the gate in the middle of the south wall)
	b.wall_x(GATE_Z, -WALL_X, WALL_X, Y, H, 2.0, wm, [[-4.0, 4.0, 8.5]])
	b.wall_x(BACK_Z, -WALL_X, WALL_X, Y, H, 2.0, wm)
	b.wall_z(-WALL_X, BACK_Z, GATE_Z, Y, H, 2.0, wm)
	b.wall_z(WALL_X, BACK_Z, GATE_Z, Y, H, 2.0, wm)
	# battlements along the front
	var x := -WALL_X
	while x < WALL_X:
		b.box(Vector3(x, Y + H, GATE_Z - 1.0), Vector3(x + 1.4, Y + H + 1.4, GATE_Z + 1.0), wm, false)
		x += 2.8
	# towers
	for tp in [Vector2(-WALL_X, GATE_Z), Vector2(WALL_X, GATE_Z), Vector2(-WALL_X, BACK_Z), Vector2(WALL_X, BACK_Z),
			Vector2(-7.5, GATE_Z), Vector2(7.5, GATE_Z)]:
		var r := 3.5 if absf(tp.x) > 10.0 else 3.0
		b.box(Vector3(tp.x - r, Y, tp.y - r), Vector3(tp.x + r, Y + H + 6.0, tp.y + r), wm)
		b.box(Vector3(tp.x - r - 0.5, Y + H + 6.0, tp.y - r - 0.5), Vector3(tp.x + r + 0.5, Y + H + 7.0, tp.y + r + 0.5), wm, false)
		var tl := OmniLight3D.new(); tl.light_color = Color(0.5, 0.75, 1.0); tl.light_energy = 3.0; tl.omni_range = 14.0
		tl.position = Vector3(tp.x, Y + H + 8.0, tp.y); add_child(tl)
	# banners and torches by the gate
	for sx in [-5.0, 5.0]:
		Props.torch(self, Vector3(sx, KY + 3.0, GATE_Z + 1.1), 0.0, true, false, Color(0.5, 0.75, 1.0))
	# the portcullis
	portcullis = Node3D.new(); add_child(portcullis)
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.22, 0.22, 0.25); iron.metallic = 0.85; iron.roughness = 0.4
	for k in 9:
		var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.18, 8.5, 0.18)
		bar.mesh = bm; bar.material_override = iron; bar.position = Vector3(-3.6 + k * 0.9, 4.25, 0); portcullis.add_child(bar)
	for k in 4:
		var bar2 := MeshInstance3D.new(); var bm2 := BoxMesh.new(); bm2.size = Vector3(7.7, 0.16, 0.24)
		bar2.mesh = bm2; bar2.material_override = iron; bar2.position = Vector3(0, 1.0 + k * 2.2, 0); portcullis.add_child(bar2)
	var psb := StaticBody3D.new(); psb.collision_layer = 1
	var pcs := CollisionShape3D.new(); var pbs := BoxShape3D.new(); pbs.size = Vector3(8.0, 8.5, 1.0)
	pcs.shape = pbs; pcs.position.y = 4.25; psb.add_child(pcs); portcullis.add_child(psb)
	portcullis.position = Vector3(0, Y, GATE_Z)
	Interactable.create(self, "inscription", Vector3(-6.5, KY, GATE_Z + 3.5), 0.0, "", [], "Castle Morwen",
		"CASTLE MORWEN\\n\\nThe gate is shut fast, and something huge keeps watch.\\nWhile the Gatehouse Warden stands, it will not open.")
	# courtyard
	var court := [[Vector3(-14, KY, -60), "ghost_knight"], [Vector3(14, KY, -60), "ghost_knight"], [Vector3(-28, KY, -68), "ghost_archer"],
		[Vector3(28, KY, -66), "ghost_archer"], [Vector3(0, KY, -66), "ghost_knight"], [Vector3(-30, KY, -95), "ghost_knight"],
		[Vector3(30, KY, -100), "ghost_archer"]]
	var n := 0
	for e in court:
		_enemy(e[1], e[0], "c_court_%d" % n, 0.0)
		n += 1
	Interactable.create(self, "shrine", Vector3(-6, KY, -56), 0.0, "", [], "the Castle Gate")
	for k in 6:
		_model(["crate_A_big", "barrel", "sack"][k % 3], Vector3(-34 + _rng.randf_range(-3, 3), KY, -56 - k * 2.5), k * 40.0, 6.0, true)
	_model("weaponrack", Vector3(34, KY, -58), -90.0, 1.6, true)
	_hw("coffin", Vector3(30, KY, -78), 30.0, 1.6, true)
	_hw("coffin_decorated", Vector3(-30, KY, -80), -20.0, 1.6, true)
	# the great hall (south door), the library to its east, the throne at the back
	var hm: Material = b.wall_mat(Color(0.32, 0.33, 0.4), 0.15, KY, 1.4, 0.55)
	b.room(-14, 14, -104, -76, KY, 11.0, hm, b.mats.cobble, {"s": [[-3.0, 3.0, 6.0]], "e": [[-92.0, -86.0, 5.0]]})
	b.room(16, 30, -98, -80, KY, 8.0, hm, b.mats.cobble, {"w": [[-92.0, -86.0, 5.0]]})
	for z in [-82.0, -90.0, -98.0]:
		b.pillar(Vector3(-8, KY, z), 11.0, 0.7, hm)
		b.pillar(Vector3(8, KY, z), 11.0, 0.7, hm)
	for p in [Vector3(-13.4, KY + 3.5, -80), Vector3(13.4, KY + 3.5, -80), Vector3(-13.4, KY + 3.5, -94), Vector3(13.4, KY + 3.5, -96),
			Vector3(29.4, KY + 3.2, -84), Vector3(29.4, KY + 3.2, -94)]:
		Props.torch(self, p, 90.0 if p.x < 0 else -90.0, true, false, Color(0.5, 0.75, 1.0))
	for hz in [-82.0, -92.0, -100.0]:
		var hl := OmniLight3D.new(); hl.light_color = Color(0.55, 0.65, 1.0); hl.light_energy = 1.8; hl.omni_range = 16.0
		hl.position = Vector3(0, KY + 8.0, hz); add_child(hl)
	# throne dais
	var dark: Material = b.mats.dark
	b.box(Vector3(-6, KY - 0.5, -104), Vector3(6, KY + 0.6, -99), dark)
	b.box(Vector3(-1.6, KY + 0.6, -103.6), Vector3(1.6, KY + 1.4, -102.0), dark)
	b.box(Vector3(-1.6, KY + 1.4, -103.9), Vector3(1.6, KY + 5.5, -103.3), dark)
	for sx in [-1.6, 1.4]:
		b.box(Vector3(sx, KY + 1.4, -103.6), Vector3(sx + 0.2, KY + 2.6, -102.0), dark)
	var thr := OmniLight3D.new(); thr.light_color = Color(0.4, 0.6, 1.0); thr.light_energy = 3.0; thr.omni_range = 10.0
	thr.position = Vector3(0, KY + 4.0, -101.0); add_child(thr)
	for sx in [-4.5, 4.5]:
		_hw("candle_triple", Vector3(sx, KY + 0.6, -100.5), 0.0, 1.6)
	n = 0
	for e in [[Vector3(-5, KY, -84), "ghost_knight"], [Vector3(5, KY, -86), "ghost_knight"], [Vector3(0, KY, -90), "wraith"]]:
		_enemy(e[1], e[0], "c_hall_%d" % n, 0.0)
		n += 1
	# the library: shelves (dark boxes), a reading table and Lady Wren's music box
	for k in 4:
		b.box(Vector3(17.5 + k * 3.2, KY, -97.6), Vector3(19.5 + k * 3.2, KY + 4.0, -96.4), dark)
		b.box(Vector3(17.5 + k * 3.2, KY, -81.6), Vector3(19.5 + k * 3.2, KY + 4.0, -80.4), dark)
	b.box(Vector3(24, KY, -90.5), Vector3(27, KY + 1.0, -87.5), dark)
	QuestItem.create(self, "musicbox", "qi_musicbox", Vector3(25.5, KY + 1.0, -89.0))
	_enemy("wraith", Vector3(22, KY, -84), "c_lib_0", 0.0)
	_enemy("wraith", Vector3(22, KY, -94), "c_lib_1", 0.0)
	var ll := OmniLight3D.new(); ll.light_color = Color(1.0, 0.8, 0.55); ll.light_energy = 1.6; ll.omni_range = 9.0
	ll.position = Vector3(25, KY + 3.0, -89); add_child(ll)

var crypt: BoneCrypt
func _crypt() -> void:
	crypt = BoneCrypt.build_in(self)

## The Misty Mere: glowing ghost-water, reeds, a pier and Old Gill the Fisher.
func _mere() -> void:
	var rim := noise.get_noise_2d(MERE.x, MERE.y) * 6.0 * 0.3 + 0.45
	mere_y = rim - 0.6
	var side := (MERE_R - 0.5) * 2.0
	GlowRiver.create(self, Rect2(MERE.x - side * 0.5, MERE.y - side * 0.5, side, side), mere_y, Vector2(0.2, 1.0), Color(0.35, 0.75, 0.95), true, false)
	# the pier, from the west shore out over the water
	var plank := StandardMaterial3D.new(); plank.albedo_color = Color(0.42, 0.32, 0.22); plank.roughness = 0.9
	var px0 := MERE.x - MERE_R - 3.5
	var px1 := MERE.x - 3.5
	var top := rim + 0.3
	b.box(Vector3(px0, top - 0.2, MERE.y - 1.3), Vector3(px1, top, MERE.y + 1.3), plank)
	var x := px0 + 1.0
	while x < px1:
		for sd in [-1.2, 1.2]:
			b.box(Vector3(x - 0.15, rim - 3.0, MERE.y + sd - 0.15), Vector3(x + 0.15, top + (0.9 if x > px1 - 1.2 else 0.0), MERE.y + sd + 0.15), plank, x > px1 - 4.0)
		x += 3.0
	FishingSpot.make(self, Vector3(px1 - 0.9, top, MERE.y), Vector3(1, 0, 0), mere_y)
	_lamp(Vector3(px1 - 0.4, top, MERE.y + 1.1), Color(0.6, 0.85, 1.0))
	# reeds, lily pads, a little rowboat, and mist on the water
	var reed := StandardMaterial3D.new(); reed.albedo_color = Color(0.35, 0.45, 0.28)
	var pad := StandardMaterial3D.new(); pad.albedo_color = Color(0.25, 0.45, 0.25)
	for k in 40:
		var a := _rng.randf() * TAU
		var r := MERE_R + _rng.randf_range(-2.0, 1.5)
		var rp := Vector2(MERE.x + cos(a) * r, MERE.y + sin(a) * r)
		if absf(rp.y - MERE.y) < 2.5 and rp.x < MERE.x:
			continue
		var rm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.04; cm.height = _rng.randf_range(0.9, 1.8)
		cm.radial_segments = 4; rm.mesh = cm; rm.material_override = reed
		add_child(rm); rm.position = Vector3(rp.x, maxf(mere_y, height(rp.x, rp.y)) + cm.height * 0.5, rp.y)
		rm.rotation = Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
	for k in 14:
		var a2 := _rng.randf() * TAU
		var r2 := _rng.randf_range(2.0, MERE_R - 2.0)
		var lp := MeshInstance3D.new(); var lc := CylinderMesh.new(); lc.top_radius = _rng.randf_range(0.3, 0.55); lc.bottom_radius = lc.top_radius; lc.height = 0.02
		lp.mesh = lc; lp.material_override = pad; add_child(lp)
		lp.position = Vector3(MERE.x + cos(a2) * r2, mere_y + 0.03, MERE.y + sin(a2) * r2)
	var boat := Node3D.new(); add_child(boat); boat.position = Vector3(MERE.x + 4.0, mere_y + 0.1, MERE.y - 5.0); boat.rotation.y = 0.6
	var bw := StandardMaterial3D.new(); bw.albedo_color = Color(0.5, 0.36, 0.22)
	for sd in [-1.0, 1.0]:
		var bs := MeshInstance3D.new(); var bbm := BoxMesh.new(); bbm.size = Vector3(0.1, 0.45, 2.6)
		bs.mesh = bbm; bs.material_override = bw; bs.position = Vector3(sd * 0.55, 0.15, 0); bs.rotation.z = sd * 0.25; boat.add_child(bs)
	var bb := MeshInstance3D.new(); var bbb := BoxMesh.new(); bbb.size = Vector3(1.0, 0.08, 2.4); bb.mesh = bbb; bb.material_override = bw
	boat.add_child(bb)
	var mist := CPUParticles3D.new(); mist.amount = 40; mist.lifetime = 7.0; mist.preprocess = 7.0
	mist.mesh = FX.quad(3.0); mist.material_override = FX.glow_material(Color(0.6, 0.75, 0.85), 0.25)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; mist.emission_box_extents = Vector3(MERE_R, 0.2, MERE_R)
	mist.direction = Vector3(1, 0.05, 0); mist.spread = 180; mist.initial_velocity_min = 0.1; mist.initial_velocity_max = 0.3
	mist.gravity = Vector3.ZERO; mist.color_ramp = FX._fade_ramp(Color(0.6, 0.75, 0.85))
	add_child(mist); mist.position = Vector3(MERE.x, mere_y + 0.6, MERE.y)
	var wl := OmniLight3D.new(); wl.light_color = Color(0.45, 0.75, 1.0); wl.light_energy = 1.5; wl.omni_range = 16.0
	add_child(wl); wl.position = Vector3(MERE.x, mere_y + 3.0, MERE.y)
	NPC.create(self, "gill", ground(px0 - 2.5, MERE.y + 3.0), -60.0, {"hero": "Barbarian", "hat": false, "hair_style": "bald",
		"hair_color": Color(0.85, 0.85, 0.85), "hair_tint": Color(0.85, 0.85, 0.85), "face": "beard",
		"outfit_color": Color(0.3, 0.4, 0.5), "cape_color": Color(0.25, 0.3, 0.35), "build": 1.1, "height": 0.9,
		"skin_color": Color(0.88, 0.68, 0.52), "weapon": ""})

## Pip's paddock east of the village: a rail fence with the gate facing the
## village, a water trough and hay. The four spooked horses come home here.
func _paddock() -> void:
	var c := PADDOCK
	var y0 := height(c.x, c.y)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.45, 0.33, 0.22); wood.roughness = 0.9
	var hw := 6.0
	# posts every 2 m round a 12 x 12 m square, with a 4 m gap (the gate) on the west side
	var sides := [[Vector2(-hw, -hw), Vector2(hw, -hw)], [Vector2(hw, -hw), Vector2(hw, hw)], [Vector2(hw, hw), Vector2(-hw, hw)], [Vector2(-hw, hw), Vector2(-hw, -hw)]]
	for sd in sides:
		var a: Vector2 = sd[0]
		var bb: Vector2 = sd[1]
		var n := 6
		for i in n:
			var p0 := a.lerp(bb, float(i) / n)
			var p1 := a.lerp(bb, float(i + 1) / n)
			var west := absf(p0.x + hw) < 0.1 and absf(p1.x + hw) < 0.1
			if west and absf((p0.y + p1.y) * 0.5) < 2.0:
				continue                                   # the gate gap
			var gy := height(c.x + p0.x, c.y + p0.y)
			b.box(Vector3(c.x + p0.x - 0.12, gy - 0.3, c.y + p0.y - 0.12), Vector3(c.x + p0.x + 0.12, gy + 1.35, c.y + p0.y + 0.12), wood, true)
			for ry in [0.55, 1.1]:
				var lo := Vector3(c.x + minf(p0.x, p1.x) - 0.05, gy + ry - 0.07, c.y + minf(p0.y, p1.y) - 0.05)
				var hi := Vector3(c.x + maxf(p0.x, p1.x) + 0.05, gy + ry + 0.07, c.y + maxf(p0.y, p1.y) + 0.05)
				b.box(lo, hi, wood, true)
	# gate posts with a little arch and sign
	for gz in [-2.0, 2.0]:
		b.box(Vector3(c.x - hw - 0.15, y0 - 0.3, c.y + gz - 0.15), Vector3(c.x - hw + 0.15, y0 + 2.6, c.y + gz + 0.15), wood, true)
	b.box(Vector3(c.x - hw - 0.15, y0 + 2.45, c.y - 2.3), Vector3(c.x - hw + 0.15, y0 + 2.7, c.y + 2.3), wood, false)
	var sg := Label3D.new(); sg.text = "PIP'S PADDOCK"; sg.font_size = 56; sg.pixel_size = 0.006; sg.outline_size = 12
	sg.modulate = Color(1.0, 0.9, 0.7); sg.position = Vector3(c.x - hw - 0.2, y0 + 3.0, c.y); sg.rotation.y = -PI * 0.5
	add_child(sg)
	_lamp(ground(c.x - hw - 1.0, c.y + 3.2))
	var mk := Marker3D.new(); mk.name = "Paddock"; mk.add_to_group("paddock"); add_child(mk); mk.position = Vector3(c.x, y0, c.y)
	# water trough and hay bales
	var trough := StandardMaterial3D.new(); trough.albedo_color = Color(0.38, 0.3, 0.22)
	b.box(Vector3(c.x + 3.2, y0, c.y - 4.6), Vector3(c.x + 5.0, y0 + 0.6, c.y - 3.6), trough, true)
	var water := StandardMaterial3D.new(); water.albedo_color = Color(0.25, 0.45, 0.6); water.metallic = 0.4; water.roughness = 0.1
	b.box(Vector3(c.x + 3.3, y0 + 0.5, c.y - 4.5), Vector3(c.x + 4.9, y0 + 0.56, c.y - 3.7), water, false)
	var hay := StandardMaterial3D.new(); hay.albedo_color = Color(0.85, 0.72, 0.35); hay.roughness = 1.0
	for hp in [Vector3(4.0, 0, 3.6), Vector3(4.2, 0, 2.2), Vector3(4.1, 0.75, 2.9)]:
		b.box(Vector3(c.x + hp.x - 0.6, y0 + hp.y, c.y + hp.z - 0.6),
			Vector3(c.x + hp.x + 0.6, y0 + hp.y + 0.75, c.y + hp.z + 0.6), hay, true)
	# the horses: home already, or out on the moor waiting to be found
	var pad := Rect2(c.x - hw - 1.5, c.y - hw - 1.5, hw * 2.0 + 3.0, hw * 2.0 + 3.0)
	var done := Game.quest_state("wraith_hunt") == "done"
	for k in HORSE_SPOTS.size():
		var id := "c_horse_%d" % k
		var hs: Vector2 = HORSE_SPOTS[k]
		var h := GhostHorse.make(self, ground(hs.x, hs.y) + Vector3(0, 0.3, 0), id, pad)
		horses.append(h)
		if done or Game.flags.get(id, false):
			h.settle(false, y0)

func _moors() -> void:
	# ghost knights patrol the road and moors; archers keep to the high ground
	var n := 0
	for e in [[Vector2(-6, 20), "ghost_knight"], [Vector2(8, 4), "ghost_knight"], [Vector2(-28, -8), "ghost_knight"],
			[Vector2(30, -14), "ghost_knight"], [Vector2(-40, 50), "ghost_archer"], [Vector2(42, 48), "ghost_knight"],
			[Vector2(-30, 82), "ghost_knight"], [Vector2(36, 86), "ghost_archer"], [Vector2(0, -24), "ghost_knight"],
			[Vector2(60, -40), "ghost_archer"], [Vector2(-60, -40), "ghost_knight"], [Vector2(84, 40), "ghost_knight"]]:
		_enemy(e[1], ground(e[0].x, e[0].y), "c_moor_%d" % n, _rng.randf() * TAU)
		n += 1

func _scatter() -> void:
	var tree_types := [["tree_dead_large", 1.4, 0.4], ["tree_dead_medium", 1.4, 0.3], ["tree_pine_orange_large", 1.1, 0.5],
		["tree_pine_yellow_medium", 1.2, 0.4], ["trees_B_medium", 1.1, 0.5]]
	var z := -HALF + 6.0
	while z < HALF - 6.0:
		var x := -HALF + 6.0
		while x < HALF - 6.0:
			var p := Vector2(x + _rng.randf_range(-3.0, 3.0), z + _rng.randf_range(-3.0, 3.0))
			x += 8.0
			var dens := noise.get_noise_2d(p.x * 2.1, p.y * 2.1) * 0.5 + 0.4
			if _rng.randf() > dens or road_dist(p) < 9.0 or _in_castle(p, 4.0):
				continue
			if absf(p.x) < 14.0 and p.y > -40.0 and p.y < 96.0:
				continue
			var blocked := false
			for c in clearings:
				if p.distance_to(c[0]) < c[1] + 3.0:
					blocked = true
			if blocked:
				continue
			var tt: Array = tree_types[_rng.randi() % tree_types.size()]
			var s: float = tt[1] * _rng.randf_range(0.8, 1.3)
			var inside := absf(p.x) < PLAY and absf(p.y) < PLAY
			_instance(tt[0], ground(p.x, p.y) - Vector3(0, 0.2, 0), _rng.randf() * TAU, s, tt[2] * s / tt[1] if inside else 0.0)
		z += 8.0
	for k in 60:
		var p2 := Vector2(_rng.randf_range(-PLAY, PLAY), _rng.randf_range(-PLAY, PLAY))
		if road_dist(p2) < 7.0 or _in_castle(p2, 2.0):
			continue
		var s2 := _rng.randf_range(5.0, 11.0)
		_instance(["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"][k % 5],
			ground(p2.x, p2.y) - Vector3(0, 0.25, 0), _rng.randf() * TAU, s2, 0.12 * s2)
	for k in 26:
		var p3 := Vector2(_rng.randf_range(-PLAY, PLAY), _rng.randf_range(-40, PLAY))
		if road_dist(p3) < 6.0 or p3.distance_to(VILLAGE) < 24.0:
			continue
		_hw(["gravemarker_A", "gravestone", "grave_A_destroyed", "tree_dead_small"][k % 4], ground(p3.x, p3.y), _rng.randf() * 360.0, 1.5)

## Ghostly mist rolling over the moor and pale wisps drifting about.
func _mist() -> void:
	for c in [Vector3(0, 0, 70), Vector3(-55, 0, 25), Vector3(55, 0, 15), Vector3(0, 0, -20), Vector3(-60, 0, -40), Vector3(60, 0, -40), Vector3(0, 0, -70)]:
		var m := CPUParticles3D.new()
		m.amount = 26 if Game.is_compat() else 40; m.lifetime = 10.0; m.preprocess = 10.0
		m.mesh = FX.quad(6.0)
		var mm := FX.glow_material(Color(0.55, 0.62, 0.8), 0.35)
		m.material_override = mm
		m.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; m.emission_box_extents = Vector3(30, 0.4, 30)
		m.direction = Vector3(1, 0, 0.3); m.spread = 30; m.initial_velocity_min = 0.3; m.initial_velocity_max = 0.8
		m.gravity = Vector3.ZERO
		m.color_ramp = FX._fade_ramp(Color(0.6, 0.68, 0.85, 0.25))
		add_child(m)
		m.position = c + Vector3(0, height(c.x, c.z) + 0.6, 0)
		var w := CPUParticles3D.new()
		w.amount = 24; w.lifetime = 7.0; w.preprocess = 7.0
		w.mesh = FX.quad(0.12); w.material_override = FX.glow_material(Color(0.6, 0.85, 1.0), 2.2)
		w.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; w.emission_box_extents = Vector3(28, 3, 28)
		w.direction = Vector3(0, 1, 0); w.spread = 180; w.initial_velocity_min = 0.1; w.initial_velocity_max = 0.4
		w.gravity = Vector3.ZERO; w.color_ramp = FX._fade_ramp(Color(0.6, 0.85, 1.0))
		add_child(w)
		w.position = c + Vector3(0, height(c.x, c.z) + 2.5, 0)

func _horizon() -> void:
	var names := ["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees"]
	for k in 22:
		var a := k * TAU / 22.0
		var r := 168.0 + _rng.randf_range(-8, 12)
		_model(names[k % 3], Vector3(cos(a) * r, -6.0, sin(a) * r), _rng.randf() * 360.0, _rng.randf_range(28.0, 38.0))

# ---------------------------------------------------------------------------
# Quest-driven changes
func _on_quests() -> void:
	# lit beacons (and the mist thins once all three are burning)
	for uid in _beacon_fires:
		(_beacon_fires[uid] as Node3D).visible = Game.flags.get(uid, false)
	if env and area == "castle":
		env.volumetric_fog_density = 0.008 if _beacons_lit() else 0.014
	# the Gatehouse Warden appears once Brannoc asks you to face him
	var gs := Game.quest_state("the_gatehouse")
	if gs == "active" and (warden == null or not is_instance_valid(warden)) and not Game.flags.get("gatekeeper", false):
		warden = _enemy("gatekeeper", Vector3(0, KY, GATE_Z + 9.0), "gatekeeper", 0.0)
		if warden:
			FX.pillar(warden.global_position, Color(0.5, 0.8, 1.0), 1.5, 12.0, 1.4)
			Game.say("The Gatehouse Warden rises before the castle gate!", Color(0.6, 0.8, 1.0))
	if gs in ["ready", "done"] and not _gate_open:
		_open_gate(area == "")       # already open when the level loads
	# the Ghost Lord takes his throne once Elowen sends you after him
	if Game.quest_state("ghost_lord") == "active" and (lord == null or not is_instance_valid(lord)) and not Game.flags.get("ghost_lord", false):
		lord = _enemy("ghost_lord", Vector3(0, KY + 0.6, -100.5), "ghost_lord", 0.0)
		if lord:
			lord.died.connect(func(_e: Enemy) -> void:
				_lord_started = false
				Sfx.music("music_explore", -15.0)
				_lord_chest()
				Game.say("Morwen fades with a long, sad sigh. Castle Morwen is free!", Color(0.7, 0.9, 1.0)))
	if Game.flags.get("ghost_lord", false):
		_lord_chest()
	if Game.quest_state("ghost_lord") == "done":
		_cloud_lift()
	# Elowen's reward for beating the Ghost Lord: the moped!
	if Game.quest_state("ghost_lord") == "done" and not Game.flags.get("mount_moped", false):
		Game.flags["mount_moped"] = true
		Game.say("You got a MOPED! Meep meep! Press G (or RIDE) to hop on.", Color(1.0, 0.5, 0.45))
		Sfx.play("beep", 0.0, 0.0)
		if player and not player.dead:
			FX.pillar(player.global_position, Color(1.0, 0.45, 0.4), 1.4, 9.0, 1.0)
			if player.mounted:
				player.dismount()
			player.mount_up("moped")

## After the Ghost Lord: a cloud gathers by Sister Elowen to lift you to Cloud Island.
func _cloud_lift() -> void:
	if get_node_or_null("CloudLift") != null:
		return
	var sl := SkyLift.make(self, ground(-1, 61) + Vector3(0, 0.1, 0), "Step onto the cloud: up to Cloud Island!", "go_to_cloud")
	sl.name = "CloudLift"
	# a golden beam of light up into the sky marks the cloud from anywhere on the moor
	FX.sky_beacon(sl, sl.global_position, Color(1.0, 0.85, 0.45))

func _lord_chest() -> void:
	if Game.flags.get("c_chest_lord", false) or get_node_or_null("LordChest") != null:
		return
	var ch := Interactable.create(self, "chest", Vector3(4, KY + 0.6, -101), -20.0, "c_chest_lord", [{"roll": "boss", "ilvl": 9}])
	ch.name = "LordChest"

func _open_gate(instant: bool) -> void:
	_gate_open = true
	if instant:
		portcullis.position.y += 8.0
		return
	Sfx.play("rumble", 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(portcullis, "position:y", portcullis.position.y + 8.0, 4.0).set_trans(Tween.TRANS_SINE)
	Game.say("With a great groan, the castle gate rises!", Color(0.7, 0.9, 1.0))
