extends Node3D
class_name BoneCrypt
## THE BONE CRYPT under the graveyard of Ghost Knight Castle (y = CY).
## A ghost-and-skeleton dungeon with its own green ghost-fire look:
##   1. Stair Hall      down from the graveyard
##   2. The Catacombs   a winding maze of skull-lined walls; skeletons claw
##                      their way out of the floor as you pass
##   3. The Bone Bridge a bottomless pit of ghost fog crossed on a bridge of
##                      bone slabs that crumble after you step on them
##   4. Hall of Bells   three ghost bells: watch the wisps ring them, then
##                      ring them in the same order to open the Ossuary
##   5. The Ossuary     a hall of skulls under a bone chandelier, guarded by
##                      the Bone Colossus
## Brother Ansel's holy water is hidden in the Catacombs' far row, past the
## Bone Bridge, and in the Ossuary.

const GHOST := Color(0.45, 1.0, 0.7)
var w: CastleWorld
var b
var Y := 0.0
var _bell_order: Array = []
var _bell_input: Array = []
var _bells: Array = []
var _bells_busy := false
var _gate: Node3D
var _gate_open := false
var colossus: Enemy
var _bone_m: Material
var _wall_m: Material

static func build_in(world: CastleWorld) -> BoneCrypt:
	var c := BoneCrypt.new()
	c.name = "BoneCrypt"
	c.w = world
	c.b = world.b
	c.Y = CastleWorld.CY
	world.add_child(c)
	c._build()
	return c

func _build() -> void:
	_wall_m = b.wall_mat(Color(0.5, 0.47, 0.4), 0.05, Y, 1.0, 0.45)
	var fm := (b.mats.floor as ShaderMaterial).duplicate() as ShaderMaterial
	fm.set_shader_parameter("base_color", Color(0.24, 0.24, 0.22)); fm.set_shader_parameter("moss", 0.0)
	var bone := StandardMaterial3D.new(); bone.albedo_color = Color(0.86, 0.82, 0.7); bone.roughness = 0.8
	_bone_m = bone
	var wm: Material = _wall_m
	# 1. Stair Hall and the passage north
	b.room(-70, -54, 8, 24, Y, 6.0, wm, fm, {"n": [[-64.5, -59.5, 4.5]]})
	b.room(-64.5, -59.5, -8, 8, Y, 4.5, wm, fm, {"s": [[-64.5, -59.5, 4.5]], "n": [[-64.5, -59.5, 4.5]]})
	Interactable.create(w, "shrine", Vector3(-66, Y, 21), 0.0, "", [], "the Crypt Stairs")
	Passage.make(w, Vector3(-62, Y, 22.5), w.ground(CastleWorld.CRYPT_DOOR.x, CastleWorld.CRYPT_DOOR.y + 7.5) + Vector3(0, 0.3, 0), PI,
		"Climb the stairs back to the graveyard", "The Graveyard")
	Interactable.create(w, "inscription", Vector3(-57, Y, 20), -90.0, "", [], "Carved over the arch",
		"HERE LIE THE KNIGHTS OF MORWEN\n\nWho rang the three bells of mourning\nand were never let go.\n\nRing them as the dead ring them,\nand the Ossuary will open.")
	# 2. The Catacombs: a serpentine maze between skull walls
	b.room(-90, -34, -44, -8, Y, 7.0, wm, fm, {"s": [[-64.5, -59.5, 4.5]], "w": [[-30.0, -26.0, 4.5]]})
	for row in [[-16.0, "east"], [-24.0, "west"], [-32.0, "east"]]:
		var z: float = row[0]
		if row[1] == "east":
			_skull_wall(Vector3(-90, Y, z), Vector3(-40, Y, z))
		else:
			_skull_wall(Vector3(-84, Y, z), Vector3(-34, Y, z))
	# 3. The Bone Bridge: a pit of ghost fog with a crumbling bridge
	b.room(-96, -90, -30, -26, Y, 4.5, wm, fm, {"w": [[-30.0, -26.0, 4.5]], "e": [[-30.0, -26.0, 4.5]]})
	b.room(-114, -96, -70, -20, Y, 14.0, wm, fm, {"e": [[-30.0, -26.0, 4.5]], "n": [[-107.0, -103.0, 4.5]]}, true, [PIT])
	b.box(Vector3(PIT.position.x, Y - 40, PIT.position.y), Vector3(PIT.end.x, Y - 38, PIT.end.y), fm)
	var fog := CPUParticles3D.new(); fog.amount = 70; fog.lifetime = 6.0; fog.preprocess = 6.0
	fog.mesh = FX.quad(4.0); fog.material_override = FX.glow_material(Color(0.35, 0.8, 0.6), 0.35)
	fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; fog.emission_box_extents = Vector3(PIT.size.x * 0.5, 1.5, PIT.size.y * 0.5)
	fog.direction = Vector3.UP; fog.spread = 30; fog.initial_velocity_min = 0.3; fog.initial_velocity_max = 0.8
	fog.gravity = Vector3.ZERO; fog.color_ramp = FX._fade_ramp(Color(0.4, 0.85, 0.65))
	add_child(fog); fog.position = Vector3(PIT.get_center().x, Y - 6.0, PIT.get_center().y)
	var pitlight := OmniLight3D.new(); pitlight.light_color = GHOST; pitlight.light_energy = 3.0; pitlight.omni_range = 22.0
	add_child(pitlight); pitlight.position = Vector3(PIT.get_center().x, Y - 4.0, PIT.get_center().y)
	var z0: float = PIT.end.y
	var k := 0
	while z0 > PIT.position.y + 0.01:
		var seg := BridgeSlab.new(); seg.mat = bone
		seg.position = Vector3(-105.0, Y, z0 - 1.0)
		add_child(seg); seg.build()
		z0 -= 2.0
		k += 1
	# 4. Hall of Bells
	b.room(-107, -103, -74, -70, Y, 4.5, wm, fm, {"s": [[-107.0, -103.0, 4.5]], "n": [[-107.0, -103.0, 4.5]]})
	b.room(-114, -90, -98, -74, Y, 10.0, wm, fm, {"s": [[-107.0, -103.0, 4.5]], "e": [[-89.0, -83.0, 4.5]]})
	for i in 3:
		var bell := GhostBell.new(); bell.idx = i; bell.crypt = self
		bell.position = Vector3(-110.0 + i * 8.0, Y, -90.0)
		add_child(bell); bell.build()
		_bells.append(bell)
	# the Ossuary gate (a portcullis of bones) in the passage east
	b.room(-90, -84, -89, -83, Y, 4.5, wm, fm, {"w": [[-89.0, -83.0, 4.5]], "e": [[-89.0, -83.0, 4.5]]})
	_gate = Node3D.new(); add_child(_gate); _gate.position = Vector3(-87.0, Y, -86.0)
	for i in 7:
		var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.18, 4.6, 0.18)
		bar.mesh = bm; bar.material_override = bone; bar.position = Vector3(0, 2.3, -2.7 + i * 0.9); _gate.add_child(bar)
	for y2 in [1.2, 3.4]:
		var rail := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(0.22, 0.25, 6.0)
		rail.mesh = rm; rail.material_override = bone; rail.position = Vector3(0, y2, 0); _gate.add_child(rail)
	var gsb := StaticBody3D.new(); var gcs := CollisionShape3D.new(); var gbs := BoxShape3D.new(); gbs.size = Vector3(0.5, 4.6, 6.0)
	gcs.shape = gbs; gcs.position.y = 2.3; gsb.add_child(gcs); _gate.add_child(gsb)
	# 5. The Ossuary
	b.room(-84, -44, -104, -70, Y, 12.0, wm, fm, {"w": [[-89.0, -83.0, 4.5]]})
	for z in [-100.0, -92.0, -84.0, -76.0]:
		_skull_wall(Vector3(-83.6, Y, z - 2.0), Vector3(-83.6, Y, z + 2.0), true)
		_skull_wall(Vector3(-44.4, Y, z - 2.0), Vector3(-44.4, Y, z + 2.0), true)
	_chandelier(Vector3(-64, Y + 9.5, -87))
	# a throne of bones at the far end
	b.box(Vector3(-68, Y, -103.5), Vector3(-60, Y + 1.0, -99.0), wm)
	b.box(Vector3(-66.2, Y + 1.0, -103.5), Vector3(-61.8, Y + 6.5, -102.4), bone)
	for sx in [-1.0, 1.0]:
		w._model("skull", Vector3(-64 + sx * 1.6, Y + 6.5, -103.0), 0.0, 2.4)
	Passage.make(w, Vector3(-48.0, Y, -72.0), w.ground(CastleWorld.CRYPT_DOOR.x + 4.0, CastleWorld.CRYPT_DOOR.y + 7.5) + Vector3(0, 0.3, 0), PI,
		"Climb the bone stair up to the graveyard", "The Graveyard")
	# lighting: cold green ghost-fire everywhere
	for p in [Vector3(-69.4, Y + 2.6, 12), Vector3(-54.6, Y + 2.6, 20), Vector3(-89.4, Y + 3.0, -12), Vector3(-34.6, Y + 3.0, -20),
			Vector3(-89.4, Y + 3.0, -38), Vector3(-34.6, Y + 3.0, -40), Vector3(-113.4, Y + 3.5, -24), Vector3(-96.6, Y + 3.5, -66),
			Vector3(-113.4, Y + 3.5, -80), Vector3(-90.6, Y + 3.5, -94), Vector3(-83.4, Y + 4.0, -96), Vector3(-44.6, Y + 4.0, -80)]:
		Props.torch(self, p, 90.0 if p.x < -62.0 or p.x == -89.4 or p.x == -113.4 or p.x == -83.4 else -90.0, true, false, GHOST)
	for c in [[-62.0, -26.0, 30.0], [-64.0, -87.0, 22.0]]:
		var gl := OmniLight3D.new(); gl.light_color = Color(0.5, 0.95, 0.75); gl.light_energy = 1.6; gl.omni_range = c[2]
		gl.position = Vector3(c[0], Y + 5.5, c[1]); add_child(gl)
	for c2 in [Vector3(-62, Y + 1.5, -26), Vector3(-105, Y + 2.0, -86), Vector3(-64, Y + 2.0, -87)]:
		_wisps(c2, 18.0)
	# candles and bones on the floor
	var rng := RandomNumberGenerator.new(); rng.seed = 909
	for k2 in 26:
		var area: Array = [[-88, -36, -42, -10], [-112, -92, -96, -76], [-82, -46, -102, -72]][k2 % 3]
		var p2 := Vector3(rng.randf_range(area[0], area[1]), Y, rng.randf_range(area[2], area[3]))
		if k2 % 3 == 0 and (fmod(absf(p2.z + 16.0), 8.0) < 1.2):
			continue
		w._hw(["candle_melted", "skull_candle", "candle_triple"][k2 % 3], p2, rng.randf() * 360.0, 1.4)
		if k2 % 2 == 0:
			w._model(["bone_A", "ribcage", "skull"][k2 % 3], p2 + Vector3(0.7, 0, 0.4), rng.randf() * 360.0, 1.0)
	# holy water: the catacombs' far row, past the bridge, and the Ossuary
	QuestItem.create(w, "holywater", "qi_holy_0", Vector3(-38, Y, -40))
	QuestItem.create(w, "holywater", "qi_holy_1", Vector3(-110, Y, -66))
	QuestItem.create(w, "holywater", "qi_holy_2", Vector3(-64, Y + 1.0, -100.5))
	Interactable.create(w, "chest", Vector3(-87.5, Y, -41.5), 45.0, "c_chest_crypt", [{"roll": "big", "ilvl": 8}])
	Interactable.create(w, "chest", Vector3(-99.5, Y, -67.5), -45.0, "c_chest_bridge", [{"roll": "weapon", "ilvl": 8}])
	# the dead
	var n := 0
	for e in [[Vector3(-80, Y, -12), "crypt_skeleton", 4.5], [Vector3(-50, Y, -13), "crypt_skeleton", 4.5],
			[Vector3(-42, Y, -20), "bone_knight", 0.0], [Vector3(-70, Y, -20), "crypt_skeleton", 4.5], [Vector3(-86, Y, -21), "crypt_hexer", 0.0],
			[Vector3(-60, Y, -28), "crypt_skeleton", 4.5], [Vector3(-45, Y, -29), "bone_knight", 0.0],
			[Vector3(-70, Y, -38), "crypt_skeleton", 4.0], [Vector3(-55, Y, -40), "crypt_skeleton", 4.0], [Vector3(-80, Y, -38), "crypt_hexer", 0.0],
			[Vector3(-105, Y, -24), "bone_knight", 0.0], [Vector3(-100, Y, -66), "crypt_skeleton", 4.0], [Vector3(-110, Y, -64), "crypt_skeleton", 4.0],
			[Vector3(-96, Y, -80), "crypt_hexer", 0.0], [Vector3(-112, Y, -94), "bone_knight", 0.0]]:
		var en := Enemy.new()
		en.configure(e[1], "c_crypt_%d" % n, e[2])
		en.position = e[0] + Vector3(0, 0.3, 0)
		if not Game.flags.get(en.uid, false):
			w.add_child(en)
		n += 1
	if not Game.flags.get("bone_colossus", false):
		colossus = Enemy.new()
		colossus.configure("bone_colossus", "bone_colossus", 0.0)
		colossus.position = Vector3(-64, Y + 0.3, -90)
		w.add_child(colossus)
	if Game.flags.get("crypt_bells", false):
		_open_gate(true)

## The bottomless pit under the Bone Bridge (and where a fall puts you back).
const PIT := Rect2(-114, -62, 18, 26)
const BRIDGE_START := Vector3(-105.0, -59.7, -34.0)

## A wall of stacked skulls (the catacomb partitions and the Ossuary niches).
func _skull_wall(a: Vector3, c: Vector3, niche_only := false) -> void:
	var along_x := absf(c.x - a.x) > absf(c.z - a.z)
	if not niche_only:
		if along_x:
			b.box(Vector3(minf(a.x, c.x), Y, a.z - 0.5), Vector3(maxf(a.x, c.x), Y + 7.0, a.z + 0.5), _wall_m)
		else:
			b.box(Vector3(a.x - 0.5, Y, minf(a.z, c.z)), Vector3(a.x + 0.5, Y + 7.0, maxf(a.z, c.z)), _wall_m)
	var length := a.distance_to(c)
	var dir := (c - a).normalized()
	var face := Vector3(dir.z, 0, -dir.x)
	var count := int(length / 1.0)
	for row in 3:
		for i in count:
			var p := a + dir * (0.5 + i * 1.0) + Vector3(0, 1.0 + row * 1.6, 0)
			for sd in ([1.0, -1.0] if not niche_only else [1.0 if a.x < -60.0 else -1.0]):
				w._instance("skull", p + face * (0.55 * sd), atan2(face.x * sd, face.z * sd), 1.25)

func _chandelier(at: Vector3) -> void:
	var n := Node3D.new(); add_child(n); n.position = at
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 2.6; tm.outer_radius = 3.0
	ring.mesh = tm; ring.material_override = _bone_m; n.add_child(ring)
	for k in 12:
		var a := k * TAU / 12.0
		w._instance("skull", at + Vector3(cos(a) * 2.8, 0.2, sin(a) * 2.8), -a, 1.0)
		var fl := CPUParticles3D.new(); fl.amount = 8; fl.lifetime = 0.6
		fl.mesh = FX.quad(0.2); fl.material_override = FX.glow_material(GHOST, 3.0)
		fl.direction = Vector3.UP; fl.spread = 10; fl.initial_velocity_min = 0.6; fl.initial_velocity_max = 1.0
		fl.gravity = Vector3.ZERO; fl.color_ramp = FX._fade_ramp(GHOST)
		fl.position = Vector3(cos(a) * 2.8, 0.5, sin(a) * 2.8); n.add_child(fl)
	for k in 4:
		var a2 := k * TAU / 4.0
		var ch := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.04; cm.height = 2.6
		ch.mesh = cm; ch.material_override = _bone_m
		ch.position = Vector3(cos(a2) * 1.4, 1.2, sin(a2) * 1.4); ch.rotation = Vector3(sin(a2) * 0.5, 0, -cos(a2) * 0.5)
		n.add_child(ch)
	var l := OmniLight3D.new(); l.light_color = GHOST; l.light_energy = 3.0; l.omni_range = 18.0; l.position.y = -0.5; n.add_child(l)

## Drifting ghost lights.
func _wisps(at: Vector3, spread: float) -> void:
	var p := CPUParticles3D.new(); p.amount = 14; p.lifetime = 9.0; p.preprocess = 9.0
	p.mesh = FX.quad(0.35); p.material_override = FX.glow_material(GHOST, 2.5)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(spread * 0.5, 1.5, spread * 0.5)
	p.direction = Vector3(1, 0.2, 0); p.spread = 180; p.initial_velocity_min = 0.2; p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO; p.color_ramp = FX._fade_ramp(GHOST)
	add_child(p); p.position = at

var _hall_seen := false
func _physics_process(_delta: float) -> void:
	var pl := w.player
	if pl == null or pl.dead:
		return
	if not _hall_seen and not _gate_open and absf(pl.global_position.y - Y) < 3.0 and Rect2(-114, -98, 24, 22).has_point(Vector2(pl.global_position.x, pl.global_position.z)):
		_hall_seen = true
		start_bells()
	# a fall into the ghost fog: back to the start of the bridge, with a scare
	if pl.global_position.y < Y - 9.0 and PIT.grow(2.0).has_point(Vector2(pl.global_position.x, pl.global_position.z)):
		pl.global_position = BRIDGE_START + Vector3(0, 0.3, 0)
		pl.velocity = Vector3.ZERO
		pl.take_damage(Game.max_hp() * 0.15, pl.global_position, 0.0)
		Game.say("The ghosts toss you back up onto the ledge! Try again, and keep moving.", Color(0.55, 1.0, 0.75))
		FX.burst(pl.global_position + Vector3(0, 1, 0), GHOST, 40, 4.0, 0.25, 0.8, 0.5)
		for s in get_children():
			if s is BridgeSlab:
				(s as BridgeSlab).reset()

# --- the bell puzzle ---------------------------------------------------------
func start_bells() -> void:
	if _gate_open or _bells_busy:
		return
	_bells_busy = true
	_bell_input.clear()
	if _bell_order.is_empty():
		_bell_order = [0, 1, 2]
		_bell_order.shuffle()
		_bell_order.append(randi() % 3)
	Game.say("Ghostly wisps drift to the bells... watch the order!", GHOST)
	await get_tree().create_timer(1.0, false).timeout
	for i in _bell_order:
		_bells[i].ring(true)
		await get_tree().create_timer(1.1, false).timeout
	Game.say("Now ring the bells in the same order!", GHOST)
	_bells_busy = false

func bell_rung(i: int) -> void:
	if _gate_open or _bells_busy:
		return
	if _bell_order.is_empty():
		start_bells()
		return
	_bell_input.append(i)
	var k := _bell_input.size() - 1
	if _bell_order[k] != i:
		_bell_input.clear()
		Game.say("A wrong note! The dead stir...", Color(1.0, 0.5, 0.4))
		Sfx.play("bone_break", -2.0, 0.1)
		for sd in [-1.0, 1.0]:
			var en := Enemy.new(); en.configure("crypt_skeleton", "", 3.0)
			en.position = Vector3(-102.0 + sd * 5.0, Y + 0.3, -82.0)
			w.add_child(en)
		get_tree().create_timer(2.5, false).timeout.connect(start_bells)
		return
	if _bell_input.size() == _bell_order.size():
		Game.flags["crypt_bells"] = true
		Game.say("The bells answer in harmony... and the bone gate rises!", GHOST)
		_open_gate(false)

func _open_gate(instant: bool) -> void:
	_gate_open = true
	if instant:
		_gate.position.y += 4.8
		return
	Sfx.play("rumble", -2.0, 0.0)
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", _gate.position.y + 4.8, 2.5).set_trans(Tween.TRANS_SINE)


## A slab of the Bone Bridge: it cracks a moment after you step on it, drops
## into the fog, and comes back a few seconds later.
class BridgeSlab extends Node3D:
	var mat: Material
	var _mesh: MeshInstance3D
	var _body: StaticBody3D
	var _t := -1.0
	var _home := Vector3.ZERO
	func build() -> void:
		_home = position
		_mesh = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.4, 0.35, 1.9)
		_mesh.mesh = bm; _mesh.material_override = mat; _mesh.position.y = -0.17; add_child(_mesh)
		for sx in [-1.0, 1.0]:
			var rib := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.06; cm.height = 1.0
			rib.mesh = cm; rib.material_override = mat; rib.position = Vector3(sx * 1.1, 0.45, 0); _mesh.add_child(rib)
		_body = StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = bm.size
		cs.shape = bs; cs.position.y = -0.17; _body.add_child(cs); add_child(_body)
	func _physics_process(delta: float) -> void:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if _t < 0.0 and p and _body.process_mode != Node.PROCESS_MODE_DISABLED:
			var d := p.global_position - global_position
			if absf(d.x) < 1.5 and absf(d.z) < 1.3 and d.y > -0.2 and d.y < 0.6:     # the seam between two slabs counts for both
				_t = 0.0
				Sfx.play_at("bone_break", global_position, -10.0, 0.3)
		if _t >= 0.0:
			_t += delta
			_mesh.position.x = sin(_t * 60.0) * 0.04 if _t < 0.7 else 0.0
			if _t >= 0.7 and _body.process_mode != Node.PROCESS_MODE_DISABLED:
				_body.process_mode = Node.PROCESS_MODE_DISABLED
				var tw := create_tween()
				tw.tween_property(_mesh, "position:y", -12.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				FX.burst(global_position, Color(0.86, 0.82, 0.7), 14, 2.0, 0.15, 0.6, -6.0)
			if _t >= 6.0:
				reset()
	func reset() -> void:
		_t = -1.0
		_mesh.position = Vector3(0, -0.17, 0)
		_body.process_mode = Node.PROCESS_MODE_INHERIT


## A great ghost bell on a bone frame. Ring it with USE.
class GhostBell extends Node3D:
	var idx := 0
	var crypt: BoneCrypt
	var _bell: Node3D
	var _glow: OmniLight3D
	const PITCH := [0.8, 1.0, 1.25]
	const COLS := [Color(0.45, 1.0, 0.7), Color(0.55, 0.8, 1.0), Color(0.85, 0.65, 1.0)]
	func build() -> void:
		add_to_group("interactable")
		var bone: Material = crypt._bone_m
		for sx in [-1.2, 1.2]:
			var post := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.16; cm.height = 4.0
			post.mesh = cm; post.material_override = bone; post.position = Vector3(sx, 2.0, 0); add_child(post)
		var beam := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.8, 0.25, 0.25)
		beam.mesh = bm; beam.material_override = bone; beam.position.y = 4.0; add_child(beam)
		_bell = Node3D.new(); _bell.position.y = 3.9; add_child(_bell)
		var metal := StandardMaterial3D.new(); metal.albedo_color = COLS[idx].darkened(0.55); metal.metallic = 0.85; metal.roughness = 0.3
		metal.emission_enabled = true; metal.emission = COLS[idx]; metal.emission_energy_multiplier = 0.3
		var shell := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.35; sc.bottom_radius = 0.75; sc.height = 1.1
		shell.mesh = sc; shell.material_override = metal; shell.position.y = -0.6; _bell.add_child(shell)
		var lip := MeshInstance3D.new(); var lt := TorusMesh.new(); lt.inner_radius = 0.66; lt.outer_radius = 0.82
		lip.mesh = lt; lip.material_override = metal; lip.position.y = -1.15; lip.scale = Vector3(1, 0.5, 1); _bell.add_child(lip)
		_glow = OmniLight3D.new(); _glow.light_color = COLS[idx]; _glow.light_energy = 0.4; _glow.omni_range = 6.0
		_glow.position.y = 2.6; add_child(_glow)
	func get_prompt() -> String:
		return "[E] Ring the bell"
	func interact(_by: Node) -> void:
		ring(false)
		crypt.bell_rung(idx)
	func ring(shown: bool) -> void:
		var p := AudioStreamPlayer3D.new()
		p.stream = Sfx.get_stream("clang")
		p.pitch_scale = PITCH[idx]
		p.volume_db = 2.0
		add_child(p); p.position.y = 3.5
		p.play()
		p.finished.connect(p.queue_free)
		var tw := create_tween()
		tw.tween_property(_bell, "rotation:x", 0.5, 0.15)
		tw.tween_property(_bell, "rotation:x", -0.35, 0.3)
		tw.tween_property(_bell, "rotation:x", 0.0, 0.4)
		_glow.light_energy = 4.0
		create_tween().tween_property(_glow, "light_energy", 0.4, 0.9)
		FX.burst(global_position + Vector3(0, 3.2, 0), COLS[idx], 30 if shown else 20, 3.0, 0.2, 0.9, 0.5)
		if shown:
			FX.pillar(global_position, COLS[idx], 0.9, 6.0, 0.8)
