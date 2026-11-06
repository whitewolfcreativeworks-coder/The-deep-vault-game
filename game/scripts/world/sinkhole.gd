extends Node3D
class_name SinkholeOfDeath
## THE SINKHOLE OF DEATH (designed by Jason's son): the Goblin Forest's second dungeon.
## Digger Dunstan stands by a patch of cracked, smoking ground in the north-west
## woods. Accept his quest and the ground gives way under your feet: you fall
## into red, fiery caverns far below. Fight through the Ember Goblins, cross the
## lava river, and defeat Grimgor the Cyclops Goblin in his throne cavern. Your
## reward is your first mount: the Giant Chicken!
##
## Surface: the crack (before) / the open pit (after; jump in to go back down).
## Underground (y = SY): landing cavern -> lava river cavern -> ember den ->
## Grimgor's throne. Rope ladders lead back up from the landing and the throne.

const SY := -140.0                         # floor of the caverns
const HOLE := Vector2(-32.0, -64.0)        # where the ground caves in (surface x/z)
const HOLE_R := 3.6
const X0 := -32.0                          # the caverns' centre line

var w: ForestWorld
var b                                      # the forest's builder
var cyclops: Enemy
var _pending := false
var _falling := false
var _pit: Node3D
var _crack: Node3D
var _lava_mat: Material
var _boss_started := false
var _chicken: ChickenMount
var _geysers: Array = []
var _geyser_t := 0.0
var _bounce_cd := 0.0

static func build_in(world: ForestWorld) -> SinkholeOfDeath:
	var s := SinkholeOfDeath.new()
	s.w = world
	s.b = world.b
	world.add_child(s)
	s._build()
	return s

func surface(x: float, z: float) -> Vector3:
	return w.ground(x, z)

func _build() -> void:
	_surface()
	_caverns()
	Game.quests_changed.connect(_on_quests)

# --- surface: Dunstan, the crack, the pit ---------------------------------------
func _surface() -> void:
	var c := surface(HOLE.x, HOLE.y)
	NPC.create(w, "dunstan", surface(HOLE.x + 4.6, HOLE.y + 1.0), 100.0, {"hero": "Barbarian", "hat": false,
		"hair_style": "natural", "hair_color": Color(0.5, 0.5, 0.5), "hair_tint": Color(0.55, 0.55, 0.55), "face": "beard",
		"outfit_color": Color(0.45, 0.35, 0.25), "cape_color": Color(0.3, 0.22, 0.15), "build": 1.15, "height": 0.92,
		"skin_color": Color(0.85, 0.62, 0.45), "weapon": "skel_axe"})
	w._model("barrel", surface(HOLE.x + 7.5, HOLE.y - 3.0), 30.0, 6.0, true)
	w._model("crate_A_big", surface(HOLE.x + 6.5, HOLE.y + 4.0), 15.0, 6.0, true)
	w._model("sack", surface(HOLE.x + 8.0, HOLE.y + 3.0), 40.0, 6.0)
	Interactable.create(w, "inscription", surface(HOLE.x - 5.5, HOLE.y + 3.5), 120.0, "", [], "Warning sign",
		"DANGER!\\n\\nGROUND NOT SAFE\\nDO NOT STAND HERE\\n\\n(Scrawled underneath in goblin: \\\"GRIMGOR SEES YOU\\\")")
	# the crack: glowing red lines and a whisper of smoke
	_crack = Node3D.new(); w.add_child(_crack); _crack.position = c + Vector3(0, 0.06, 0)
	var crack_m := FX.glow_material(Color(1.0, 0.25, 0.05), 2.2)
	for k in 9:
		var a := k * TAU / 9.0 + 0.2
		var seg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.03, randf_range(1.2, 2.8))
		seg.mesh = bm; seg.material_override = crack_m
		seg.position = Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 2.2)
		seg.rotation.y = -a + randf_range(-0.5, 0.5)
		_crack.add_child(seg)
	var smoke := CPUParticles3D.new(); smoke.amount = 18; smoke.lifetime = 3.0; smoke.preprocess = 3.0
	smoke.mesh = FX.quad(0.9); smoke.material_override = FX.glow_material(Color(0.45, 0.35, 0.32), 0.45)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; smoke.emission_sphere_radius = 2.0
	smoke.direction = Vector3.UP; smoke.spread = 15; smoke.initial_velocity_min = 0.4; smoke.initial_velocity_max = 0.9
	smoke.gravity = Vector3(0, 0.15, 0); smoke.scale_amount_min = 0.8; smoke.scale_amount_max = 2.0
	smoke.color_ramp = FX._fade_ramp(Color(0.6, 0.45, 0.4))
	_crack.add_child(smoke)
	var cl := OmniLight3D.new(); cl.light_color = Color(1.0, 0.3, 0.08); cl.light_energy = 1.2; cl.omni_range = 5.0
	cl.position.y = 0.5; _crack.add_child(cl)
	_pit = Node3D.new(); w.add_child(_pit); _pit.position = c
	_pit.add_to_group("sinkhole_pit")
	_build_pit_look()
	_set_open(Game.flags.get("sinkhole_open", false))

func _build_pit_look() -> void:
	# a black hole with jagged rocks round the rim and a red glow from far below
	var hole := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = HOLE_R; cm.bottom_radius = HOLE_R * 0.6; cm.height = 3.0
	hole.mesh = cm
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.02, 0.0, 0.0); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole.material_override = hm
	hole.position.y = -1.42
	_pit.add_child(hole)
	var glow := MeshInstance3D.new(); var gm := CylinderMesh.new(); gm.top_radius = HOLE_R * 0.55; gm.bottom_radius = HOLE_R * 0.55; gm.height = 0.02
	glow.mesh = gm; glow.material_override = FX.glow_material(Color(1.0, 0.2, 0.02), 1.4)
	glow.position.y = 0.04
	_pit.add_child(glow)
	for k in 12:
		var a := k * TAU / 12.0
		var r := w._model("rock_single_" + ["A", "B", "C", "D", "E"][k % 5], Vector3.ZERO, k * 37.0, 3.2 + (k % 3) * 0.8)
		r.reparent(_pit, false)
		r.position = Vector3(cos(a), -0.3, sin(a)) * (HOLE_R + 0.4)
	var embers := CPUParticles3D.new(); embers.amount = 40; embers.lifetime = 2.5; embers.preprocess = 2.5
	embers.mesh = FX.quad(0.08); embers.material_override = FX.glow_material(Color(1.0, 0.5, 0.1), 3.0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; embers.emission_sphere_radius = HOLE_R * 0.7
	embers.direction = Vector3.UP; embers.spread = 20; embers.initial_velocity_min = 1.5; embers.initial_velocity_max = 3.5
	embers.gravity = Vector3(0, 0.2, 0); embers.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.1))
	_pit.add_child(embers)
	var pl := OmniLight3D.new(); pl.light_color = Color(1.0, 0.3, 0.05); pl.light_energy = 2.5; pl.omni_range = 9.0
	pl.position.y = 0.6; pl.set_script(load("res://scripts/world/flicker.gd")); _pit.add_child(pl)

func _set_open(open: bool) -> void:
	_pit.visible = open
	_crack.visible = not open

func pit_center() -> Vector3:
	return surface(HOLE.x, HOLE.y)

# --- the cave-in, when you accept Dunstan's quest ---------------------------------
func _on_quests() -> void:
	if Game.quest_state("sinkhole") == "active" and not Game.flags.get("sinkhole_open", false):
		_pending = true

func _process(delta: float) -> void:
	var player := w.player
	if player == null:
		return
	var main := get_tree().current_scene
	if _pending and main.get("state") == "play" and not get_tree().paused:
		_pending = false
		_collapse()
	# jumping into the open pit takes you back down
	if Game.flags.get("sinkhole_open", false) and not _falling and not player.dead:
		var p := player.global_position
		if Vector2(p.x - HOLE.x, p.z - HOLE.y).length() < HOLE_R - 0.4 and absf(p.y - pit_center().y) < 2.5:
			_fall_in(false)
	# the boss wakes when you walk into the throne cavern
	if not _boss_started and cyclops and is_instance_valid(cyclops) and not cyclops.dead \
			and player.global_position.y < SY + 20.0 and player.global_position.z < -186.0:
		_boss_started = true
		Sfx.music("music_boss", -10.0)
		Sfx.play("roar_big", 0.0, 0.0)
		player.add_trauma(0.6)
		Game.say("Grimgor: \"ONE EYE SEES ALL! TINY HERO GO SQUISH!\"", Color(1.0, 0.45, 0.2))
	# lava throws you back out (with a nasty burn) so you can scramble to the bank
	_bounce_cd -= delta
	if player.in_river and player.global_position.y < SY - 0.2 and _bounce_cd <= 0.0 and not player.dead:
		_bounce_cd = 0.9
		player.velocity.y = 9.5
		FX.burst(player.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.45, 0.1), 30, 4.0, 0.2, 0.8, -4.0)
		Sfx.play("fire_burst", -6.0, 0.1)
	# fire geysers in the lava cavern
	_geyser_t -= delta
	if _geyser_t <= 0.0 and player.global_position.y < SY + 20.0:
		_geyser_t = 1.4
		_geyser_tick()

func _collapse() -> void:
	var player := w.player
	_falling = true
	player.input_enabled = false
	Game.say("Dunstan: \"Wait... do you feel that? The ground's... LOOK OUT!\"", Color(1.0, 0.85, 0.5))
	Sfx.play("collapse", 0.0, 0.0)
	var c := pit_center()
	for k in 6:
		player.add_trauma(0.35 + k * 0.08)
		FX.burst(c + Vector3(randf_range(-2.5, 2.5), 0.3, randf_range(-2.5, 2.5)), Color(0.5, 0.4, 0.3), 14, 3.0, 0.3, 0.9, -5.0)
		for s in _crack.get_children():
			if s is MeshInstance3D:
				s.scale = Vector3(1.0 + k * 0.35, 1, 1.0 + k * 0.1)
		await get_tree().create_timer(0.22).timeout
	# you stumble onto the crack as it splits wide open
	var tw := create_tween()
	tw.tween_property(player, "global_position", c + Vector3(0, 0.2, 0), 0.35)
	await tw.finished
	_set_open(true)
	Game.flags["sinkhole_open"] = true
	# chunks of ground tumble into the dark
	for k in 10:
		var a := k * TAU / 10.0
		var chunk := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(randf_range(0.8, 1.6), 0.6, randf_range(0.8, 1.6))
		chunk.mesh = bm
		var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.32, 0.42, 0.18).lerp(Color(0.35, 0.25, 0.15), randf()); chunk.material_override = cm
		w.add_child(chunk)
		chunk.global_position = c + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 2.6)
		var ct := chunk.create_tween().set_parallel(true)
		ct.tween_property(chunk, "global_position:y", c.y - 30.0, 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(randf() * 0.25)
		ct.tween_property(chunk, "rotation", Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), 1.6)
		ct.chain().tween_callback(chunk.queue_free)
	FX.burst(c + Vector3(0, 0.5, 0), Color(0.45, 0.38, 0.3), 70, 5.0, 0.45, 1.3, -4.0)
	_fall_in(true)

## Down you go: a short drop out of sight, black, then you land in the caverns.
func _fall_in(first: bool) -> void:
	var player := w.player
	var main := get_tree().current_scene
	_falling = true
	player.input_enabled = false
	player.set_physics_process(false)
	Sfx.play("portal", -8.0, 0.0)
	var tw := create_tween()
	tw.tween_property(player, "global_position", pit_center() + Vector3(0, -7.0, 0), 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if main.has_method("_fade"):
		pass
	await tw.finished
	await main.menus.fade_to(1.0, 0.25).finished
	var land := Vector3(HOLE.x, SY + 9.0, HOLE.y)
	player.global_position = land
	player.velocity = Vector3(0, -10.0, 0)
	player.reset_physics_interpolation()
	player.snap_view()
	player.set_physics_process(true)
	main.menus.fade_to(0.0, 0.6)
	await get_tree().create_timer(0.75).timeout
	player.add_trauma(0.7)
	Sfx.play("slam", -2.0, 0.0)
	FX.burst(Vector3(HOLE.x, SY + 0.3, HOLE.y), Color(0.5, 0.25, 0.15), 50, 5.0, 0.4, 1.2, -5.0)
	player.input_enabled = true
	_falling = false
	if first:
		player.take_damage(8.0, player.global_position + Vector3(0, 1, 0), 0.0)
		_title("THE SINKHOLE OF DEATH")
		Game.set_objective("Survive the Sinkhole of Death and defeat whatever rules its depths.")
		Game.say("You crash down into a burning cavern far beneath the forest!", Color(1.0, 0.5, 0.25))
	Game.resume_pos = Vector3(HOLE.x, SY + 0.2, HOLE.y)
	Game.set_checkpoint(Vector3(HOLE.x, SY + 0.2, HOLE.y), 0.0, "the bottom of the Sinkhole")
	if main.has_method("autosave"):
		main.autosave()

func _title(text: String) -> void:
	var layer := CanvasLayer.new(); layer.layer = 15; add_child(layer)
	var l := UIKit.label(text, 64, Color(1.0, 0.35, 0.15), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -700; l.offset_right = 700; l.offset_top = -160; l.offset_bottom = -80
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 0.95))
	l.modulate.a = 0.0
	layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(layer.queue_free)

# --- the caverns ---------------------------------------------------------------
func _caverns() -> void:
	var wm: Material = b.wall_mat(Color(0.46, 0.24, 0.17), 0.0, SY, 2.4, 1.1)
	var fm := (b.mats.floor as ShaderMaterial).duplicate() as ShaderMaterial
	fm.set_shader_parameter("base_color", Color(0.3, 0.22, 0.19)); fm.set_shader_parameter("moss", 0.0)
	var Y := SY
	# 1. landing cavern (open to the shaft above)
	b.room(-44, -20, -76, -52, Y, 14.0, wm, fm, {"n": [[X0 - 3.0, X0 + 3.0, 6.0]]}, false)
	for r in [[Vector3(-45, Y + 14, -77), Vector3(-19, Y + 15, -68)], [Vector3(-45, Y + 14, -60), Vector3(-19, Y + 15, -51)],
			[Vector3(-45, Y + 14, -68), Vector3(-36, Y + 15, -60)], [Vector3(-28, Y + 14, -68), Vector3(-19, Y + 15, -60)]]:
		b.box(r[0], r[1], wm)
	for k in 8:   # the shaft rising to the hole
		var a := k * TAU / 8.0
		var p := Vector3(HOLE.x + cos(a) * 5.0, Y + 15, HOLE.y + sin(a) * 5.0)
		b.box(p + Vector3(-1.6, 0, -1.6), p + Vector3(1.6, 40, 1.6), wm, false, false)
	var shaft := SpotLight3D.new(); shaft.light_color = Color(1.0, 0.85, 0.65); shaft.light_energy = 3.0
	shaft.spot_range = 40.0; shaft.spot_angle = 14.0; shaft.light_volumetric_fog_energy = 3.0
	add_child(shaft); shaft.position = Vector3(HOLE.x, Y + 32, HOLE.y); shaft.rotation_degrees = Vector3(-90, 0, 0)
	ClimbOut.make(self, Vector3(-41.5, Y, -60), surface(HOLE.x + 3.0, HOLE.y + 6.0) + Vector3(0, 0.3, 0)).add_to_group("sinkhole_exit")
	# 2. tunnel
	b.room(X0 - 3.0, X0 + 3.0, -92, -76, Y, 6.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]], "n": [[X0 - 3.0, X0 + 3.0, 6.0]]})
	# 3. the lava river cavern: a stone bridge over a river of fire
	b.room(-54, -10, -128, -92, Y, 16.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]], "n": [[X0 - 3.0, X0 + 3.0, 6.0]]}, true,
		[Rect2(-55, -114, 46, 8)])
	var lava := GlowRiver.create(self, Rect2(-54, -114, 44, 8), Y - 1.0, Vector2(1, 0), Color(1.0, 0.35, 0.05), false, true)
	b.box(Vector3(-55, Y - 4, -115), Vector3(-9, Y - 1.2, -105), fm)          # the lava bed
	b.box(Vector3(X0 - 2.2, Y - 1.2, -114.5), Vector3(X0 + 2.2, Y, -105.5), (b.mats.dark as Material))   # bridge
	for sd in [-1.0, 1.0]:
		for z in [-114.0, -110.0, -106.0]:
			b.box(Vector3(X0 + sd * 2.1 - 0.2, Y, z - 0.2), Vector3(X0 + sd * 2.1 + 0.2, Y + 1.0, z + 0.2), wm)
	_geysers = [Vector3(-46, Y - 1.0, -110), Vector3(-20, Y - 1.0, -110), Vector3(-40, Y - 1.0, -108), Vector3(-14, Y - 1.0, -111)]
	# 4. tunnel
	b.room(X0 - 3.0, X0 + 3.0, -142, -128, Y, 6.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]], "n": [[X0 - 3.0, X0 + 3.0, 6.0]]})
	# 5. the ember den
	b.room(-48, -16, -168, -142, Y, 10.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]], "n": [[X0 - 3.0, X0 + 3.0, 6.0]]})
	w._campfire(Vector3(X0, Y, -155))
	Interactable.create(w, "chest", Vector3(-45, Y, -146), 90.0, "s_chest_den", [{"roll": "big", "ilvl": 6}])
	# 6. tunnel
	b.room(X0 - 3.0, X0 + 3.0, -182, -168, Y, 6.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]], "n": [[X0 - 3.0, X0 + 3.0, 6.0]]})
	# 7. Grimgor's throne cavern: lava pools in the corners, pillars, a throne of rock
	b.room(-60, -4, -226, -182, Y, 18.0, wm, fm, {"s": [[X0 - 3.0, X0 + 3.0, 6.0]]}, true,
		[Rect2(-59, -225, 12, 12), Rect2(-17, -225, 12, 12), Rect2(-59, -196, 10, 12), Rect2(-15, -196, 10, 12)])
	for r in [Rect2(-59, -225, 12, 12), Rect2(-17, -225, 12, 12), Rect2(-59, -196, 10, 12), Rect2(-15, -196, 10, 12)]:
		GlowRiver.create(self, r, Y - 0.9, Vector2(0.3, 1), Color(1.0, 0.35, 0.05), true, true)
		b.box(Vector3(r.position.x, Y - 4, r.position.y), Vector3(r.end.x, Y - 1.1, r.end.y), fm)
	for z in [-194.0, -206.0, -218.0]:
		b.pillar(Vector3(-42, Y, z), 18.0, 1.0, wm)
		b.pillar(Vector3(-22, Y, z), 18.0, 1.0, wm)
	b.box(Vector3(X0 - 4, Y, -226), Vector3(X0 + 4, Y + 1.2, -220), wm)                 # dais
	b.box(Vector3(X0 - 2.2, Y + 1.2, -225.5), Vector3(X0 + 2.2, Y + 6.5, -224), wm)     # throne back
	b.box(Vector3(X0 - 2.5, Y + 1.2, -224), Vector3(X0 + 2.5, Y + 2.4, -221.5), wm)     # seat
	for sd in [-1.0, 1.0]:
		w._model("skull", Vector3(X0 + sd * 2.0, Y + 6.5, -224.8), 0.0, 2.2)
		w._campfire(Vector3(X0 + sd * 9.0, Y, -214))
	w._model("ribcage", Vector3(-12, Y, -204), 40.0, 1.6)
	w._model("bone_A", Vector3(-48, Y, -210), 10.0, 1.4)
	# red rock spires, embers and heat everywhere
	var spire_m := (b.mats.rock as ShaderMaterial).duplicate() as ShaderMaterial
	spire_m.set_shader_parameter("base_color", Color(0.45, 0.14, 0.08))
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for room in [[-44, -20, -76, -52], [-54, -10, -128, -92], [-48, -16, -168, -142], [-60, -4, -226, -182]]:
		var area: float = (room[1] - room[0]) * (room[3] - room[2])
		for k in int(area / 70.0):
			var p := Vector3(rng.randf_range(room[0] + 1.5, room[1] - 1.5), Y, rng.randf_range(room[2] + 1.5, room[3] - 1.5))
			if absf(p.x - X0) < 5.0 or (p.z > -116 and p.z < -104) or Vector2(p.x - HOLE.x, p.z - HOLE.y).length() < 6.0:
				continue
			if p.z < -182 and ((p.x < -46 or p.x > -18) and (p.z < -213 or (p.z > -196))):
				continue
			_spire(p, rng.randf_range(1.2, 4.5), rng.randf_range(0.4, 1.0), spire_m)
		# stalactites from the ceiling
		for k in int(area / 110.0):
			var p2 := Vector3(rng.randf_range(room[0] + 1, room[1] - 1), 0, rng.randf_range(room[2] + 1, room[3] - 1))
			var top := Y + (14.0 if room[2] == -76 else (16.0 if room[2] == -128 else (10.0 if room[2] == -168 else 18.0)))
			if room[2] == -76 and Vector2(p2.x - HOLE.x, p2.z - HOLE.y).length() < 8.0:
				continue
			var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = rng.randf_range(0.4, 0.9); cm.bottom_radius = 0.0
			cm.height = rng.randf_range(1.5, 4.0); cone.mesh = cm; cone.material_override = spire_m
			cone.position = Vector3(p2.x, top - cm.height * 0.5, p2.z)
			add_child(cone)
	for room in [[-32.0, -64.0, 18.0], [-32.0, -110.0, 30.0], [-32.0, -155.0, 22.0], [-32.0, -204.0, 34.0]]:
		var em := CPUParticles3D.new(); em.amount = 90; em.lifetime = 5.0; em.preprocess = 5.0
		em.mesh = FX.quad(0.07); em.material_override = FX.glow_material(Color(1.0, 0.45, 0.1), 3.0)
		em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; em.emission_box_extents = Vector3(room[2] * 0.5, 0.5, room[2] * 0.5)
		em.direction = Vector3.UP; em.spread = 25; em.initial_velocity_min = 0.4; em.initial_velocity_max = 1.4
		em.gravity = Vector3(0.1, 0.25, 0); em.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.1))
		add_child(em); em.position = Vector3(room[0], Y + 0.5, room[1])
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.5, 0.25); l.light_energy = 2.0; l.omni_range = room[2]
		l.position = Vector3(room[0], Y + 6.0, room[1]); l.set_script(load("res://scripts/world/flicker.gd")); add_child(l)
	for room in [[-44, -20, -76, -52, 10.0], [-54, -10, -128, -92, 11.0], [-48, -16, -168, -142, 8.0], [-60, -4, -226, -182, 12.0]]:
		var gx: float = room[0] + 6.0
		while gx < room[1] - 2.0:
			var gz: float = room[2] + 6.0
			while gz < room[3] - 2.0:
				var fl := OmniLight3D.new(); fl.light_color = Color(1.0, 0.78, 0.6); fl.light_energy = 1.7; fl.omni_range = 14.0
				fl.omni_attenuation = 1.2; fl.position = Vector3(gx, Y + room[4], gz); add_child(fl)
				gz += 12.0
			gx += 12.0
	for p in [Vector3(-43.5, Y + 3, -64), Vector3(-20.5, Y + 3, -64), Vector3(-53.5, Y + 3.5, -98), Vector3(-10.5, Y + 3.5, -98),
			Vector3(-47.5, Y + 3.2, -150), Vector3(-16.5, Y + 3.2, -160), Vector3(-59.5, Y + 4, -200), Vector3(-4.5, Y + 4, -200)]:
		Props.torch(self, p, 90.0 if p.x < X0 else -90.0, true)
	# --- the goblins of the deep
	var n := 0
	for e in [[Vector3(-36, Y, -70), "fire_goblin"], [Vector3(-26, Y, -58), "fire_goblin"],
			[Vector3(-40, Y, -98), "fire_goblin"], [Vector3(-24, Y, -100), "fire_goblin"], [Vector3(-44, Y, -122), "fire_archer"],
			[Vector3(-20, Y, -124), "fire_archer"], [Vector3(-32, Y, -120), "magma_brute"],
			[Vector3(-40, Y, -150), "fire_goblin"], [Vector3(-24, Y, -150), "fire_goblin"], [Vector3(-36, Y, -162), "fire_archer"],
			[Vector3(-28, Y, -162), "fire_archer"], [Vector3(-32, Y, -158), "magma_brute"]]:
		w._enemy(e[1], e[0], "s_gob_%d" % n, PI * 0.0)
		n += 1
	cyclops = w._enemy("cyclops", Vector3(X0, Y + 1.3, -216), "cyclops", 0.0)
	if cyclops:
		cyclops.died.connect(_on_cyclops_dead)
	elif not Game.flags.get("mount_chicken", false):
		_spawn_chicken.call_deferred()
	if Game.flags.get("cyclops", false):
		_exit_ladder()
		if not Game.flags.get("s_chest_boss", false):
			Interactable.create(w, "chest", Vector3(X0 + 5, Y + 1.2, -223), -30.0, "s_chest_boss", [{"roll": "boss"}])

func _spire(p: Vector3, h: float, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r * 0.15; cm.bottom_radius = r; cm.height = h
	cm.radial_segments = 7
	mi.mesh = cm; mi.material_override = m; mi.position = p + Vector3(0, h * 0.5, 0); mi.rotation.y = randf() * TAU
	add_child(mi)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = r * 0.7; cyl.height = h
	cs.shape = cyl; sb.add_child(cs); add_child(sb); sb.position = mi.position

func _exit_ladder() -> void:
	ClimbOut.make(self, Vector3(X0 + 9.0, SY, -222), surface(HOLE.x + 3.0, HOLE.y + 6.0) + Vector3(0, 0.3, 0)).add_to_group("sinkhole_exit")

## Fire geysers burst out of the lava river now and then: stay on the bridge!
func _geyser_tick() -> void:
	if _geysers.is_empty():
		return
	var g: Vector3 = _geysers[randi() % _geysers.size()]
	FX.pillar(g, Color(1.0, 0.4, 0.05), 1.0, 7.0, 0.8)
	FX.burst(g + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.1), 40, 7.0, 0.25, 1.1, -6.0)
	Sfx.play_at("fire_burst", g, -8.0, 0.2)
	var player := w.player
	if player and Vector2(player.global_position.x - g.x, player.global_position.z - g.z).length() < 2.2 and player.global_position.y < SY + 3.0:
		player.take_damage(18.0, g, 6.0)

func _on_cyclops_dead(_e: Enemy) -> void:
	Sfx.music("music_explore", -15.0)
	Game.say("Grimgor topples like a falling tower. The Sinkhole of Death is beaten!", Color(1.0, 0.85, 0.4))
	Interactable.create(w, "chest", Vector3(X0 + 5, SY + 1.2, -223), -30.0, "s_chest_boss", [{"roll": "boss"}])
	_exit_ladder()
	await get_tree().create_timer(2.0).timeout
	_spawn_chicken()

## The reward: a Giant Chicken pecking about the throne cavern, waiting for you.
func _spawn_chicken() -> void:
	if Game.flags.get("mount_chicken", false) or _chicken:
		return
	_chicken = ChickenMount.new()
	add_child(_chicken)
	_chicken.position = Vector3(X0 - 6.0, SY, -208)
	_chicken.rotation.y = PI * 0.15
	_chicken.bawk()
	FX.pillar(_chicken.position, Color(1.0, 0.9, 0.5), 1.6, 8.0, 0.9)
	Game.say("BAWK! A Giant Chicken waddles out from behind the throne. It seems to like you!", Color(1.0, 0.95, 0.6))
	var claim := ChickenClaim.new()
	claim.chicken = _chicken
	_chicken.add_child(claim)

## Environment for the caverns: red, smoky and hot.
static func apply_env(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.005, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.35)
	env.ambient_light_energy = 1.0
	env.fog_light_color = Color(0.16, 0.05, 0.02)
	env.fog_depth_begin = 25.0
	env.fog_depth_end = 150.0
	env.volumetric_fog_density = 0.007
	env.volumetric_fog_albedo = Color(0.9, 0.72, 0.6)
