extends Node3D
class_name WildChests
## Treasure chests that turn up in random places out in the wilds, each with a
## silly little scene around it: a pumpkin party, a fairy ring, a sleeping
## goblin, a gang of pecking chickens, a skeleton's picnic, a chest on top of a
## wobbly crate tower, or a "DEFINITELY NOT A TRAP" chest that bites.
## New spots are picked every time the area loads, and every few minutes another
## chest pops up somewhere (up to a limit), so there's always more to find.

const SCENES := ["pumpkins", "fairy_ring", "sleepy_goblin", "chickens", "picnic", "crate_tower", "mimic"]

var ground: Callable          # (x, z) -> Vector3 on the terrain
var ok_spot: Callable         # (Vector2) -> bool: is this a good place for a chest?
var area := Rect2()
var ilvl := 4
var max_chests := 8
var respawn_every := 240.0
var forest_props := true      # the forest has pumpkins, mushrooms, tents...
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _spots: Array[Vector2] = []

static func create(parent: Node3D, rect: Rect2, ground_fn: Callable, ok_fn: Callable, count: int, level: int, forest := true) -> WildChests:
	var w := WildChests.new()
	w.area = rect; w.ground = ground_fn; w.ok_spot = ok_fn; w.ilvl = level; w.forest_props = forest
	parent.add_child(w)
	w._rng.randomize()
	for k in count:
		w.spawn_one(false)
	return w

func _process(delta: float) -> void:
	_timer += delta
	if _timer < respawn_every:
		return
	_timer = 0.0
	if _count_closed() < max_chests:
		spawn_one(true)

func _count_closed() -> int:
	var n := 0
	for c in get_children():
		if c is Node3D and c.has_meta("chest") and is_instance_valid(c.get_meta("chest")) and not c.get_meta("chest").spent:
			n += 1
	return n

func _pick_spot() -> Vector2:
	for tries in 60:
		var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		var clear := true
		for s in _spots:
			if s.distance_to(p) < 22.0:
				clear = false
		if clear and ok_spot.call(p):
			return p
	return Vector2.INF

func spawn_one(announce: bool) -> void:
	var p := _pick_spot()
	if p == Vector2.INF:
		return
	_spots.append(p)
	var scene: String = SCENES[_rng.randi() % SCENES.size()]
	if not forest_props and scene in ["pumpkins", "fairy_ring", "sleepy_goblin"]:
		scene = ["chickens", "picnic", "crate_tower", "mimic"][_rng.randi() % 4]
	var root := Node3D.new(); add_child(root)
	root.position = ground.call(p.x, p.y)
	root.rotation.y = _rng.randf() * TAU
	var chest_at := Vector3.ZERO
	var loot: Array = [{"roll": "wild", "ilvl": ilvl}]
	match scene:
		"pumpkins":
			for k in 7:
				var a := k * TAU / 7.0
				_prop("pumpkin_orange" if k % 2 == 0 else "pumpkin_yellow_small", root, Vector3(cos(a), 0, sin(a)) * 2.4, a * 57.0, 1.3)
			_prop("lantern_standing", root, Vector3(2.8, 0, 1.5), 0.0, 1.0)
			_sign(root, Vector3(-2.6, 0, 1.8), "PUMPKIN PARTY\n(no goblins allowed)")
		"fairy_ring":
			for k in 9:
				var a := k * TAU / 9.0
				_mushroom(root, Vector3(cos(a), 0, sin(a)) * 2.6, Color.from_hsv(_rng.randf(), 0.55, 1.0))
			var sp := CPUParticles3D.new(); sp.amount = 30; sp.lifetime = 2.5; sp.preprocess = 2.5
			sp.mesh = FX.quad(0.08); sp.material_override = FX.glow_material(Color(0.9, 0.8, 1.0), 2.5)
			sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 2.4
			sp.direction = Vector3.UP; sp.spread = 40; sp.initial_velocity_min = 0.2; sp.initial_velocity_max = 0.6
			sp.gravity = Vector3.ZERO; sp.position.y = 0.8
			root.add_child(sp)
		"sleepy_goblin":
			var g := Enemy.new()
			g.configure("goblin" if ilvl >= 3 else "minion", "", 3.5)
			root.add_child(g)
			g.position = Vector3(2.0, 0.3, 0.5)
			g.body.visible = true                      # asleep on the grass, not buried
			g.body.hold_clip = "Lie_Idle"
			var z := Label3D.new(); z.text = "Z z z"; z.font_size = 72; z.pixel_size = 0.006; z.outline_size = 12
			z.billboard = BaseMaterial3D.BILLBOARD_ENABLED; z.modulate = Color(0.85, 0.9, 1.0)
			z.position = Vector3(2.0, 1.2, 0.5); root.add_child(z)
			var zt := z.create_tween().set_loops()
			zt.tween_property(z, "position:y", 1.6, 1.2); zt.tween_property(z, "position:y", 1.2, 1.2)
			g.tree_exited.connect(func() -> void:
				if is_instance_valid(z):
					z.queue_free())
			_sign(root, Vector3(-2.4, 0, 1.4), "SHHH!\nGoblin napping")
		"chickens":
			for k in 4:
				var ch := ChickenMount.new()
				root.add_child(ch)
				var a := k * TAU / 4.0 + 0.4
				ch.position = Vector3(cos(a), 0, sin(a)) * 2.3
				ch.rotation.y = -a + PI * 0.5
				ch.scale = Vector3.ONE * 0.33
			_sign(root, Vector3(-2.8, 0, 1.6), "CHICKEN TREASURE\nDO NOT TOUCH\n- the chickens")
		"picnic":
			_prop("skull", root, Vector3(1.6, 0.0, 0.2), 200.0, 1.2)
			_prop("ribcage", root, Vector3(1.8, 0.0, 0.9), 160.0, 1.2)
			_kit("plate", root, Vector3(0.9, 0.02, 1.4), 0.0, 0.3)
			_kit("food_ingredient_bun", root, Vector3(0.9, 0.05, 1.4), 30.0, 0.35)
			_kit("food_ingredient_cheese", root, Vector3(1.05, 0.05, 1.55), 0.0, 0.3)
			var cloth := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(2.4, 0.02, 2.4); cloth.mesh = cb
			var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.85, 0.2, 0.2); cloth.material_override = cm
			cloth.position = Vector3(1.1, 0.01, 0.9); root.add_child(cloth)
			_sign(root, Vector3(-2.4, 0, 1.5), "LUNCH BREAK\nback in 500 years")
		"crate_tower":
			var y := 0.0
			for k in 3:
				var cr := _prop("crate_A_big" if forest_props else "", root, Vector3(0, y, 0), k * 25.0, 6.0)
				if cr == null:
					var bx := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.4, 1.0, 1.4); bx.mesh = bm
					var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.55, 0.38, 0.22); bx.material_override = wm
					bx.position = Vector3(0, y + 0.5, 0); bx.rotation.y = k * 0.4; root.add_child(bx)
				var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.3, 0.95, 1.3)
				cs.shape = bs; sb.add_child(cs); sb.position = Vector3(0, y + 0.47, 0); root.add_child(sb)
				y += 0.95
			chest_at = Vector3(0, y, 0)
			_sign(root, Vector3(-2.2, 0, 1.6), "Can you reach it?\n(try a double jump!)")
		"mimic":
			_sign(root, Vector3(-2.0, 0, 1.4), "DEFINITELY\nNOT A TRAP")
			loot = [{"roll": "wild", "ilvl": ilvl}, {"roll": "wild", "ilvl": ilvl}]
	var chest := Interactable.create(root, "chest", chest_at, 0.0, "", loot)
	root.set_meta("chest", chest)
	root.set_meta("scene", scene)
	if scene == "mimic":
		chest.used.connect(func(by: Node) -> void: _mimic_bite(chest, by))
	if announce:
		Game.say("*jingle* A treasure chest has appeared somewhere out there...", Color(1.0, 0.85, 0.4))
		Sfx.play("coins", -8.0, 0.0)

func _mimic_bite(chest: Node3D, by: Node) -> void:
	Game.say("The chest BITES you! ...then coughs up double treasure.", Color(1.0, 0.6, 0.4))
	Sfx.play_at("skel_attack", chest.global_position, 0.0)
	var tw := chest.create_tween()
	tw.tween_property(chest, "position:y", chest.position.y + 0.8, 0.12)
	tw.tween_property(chest, "position:y", chest.position.y, 0.15)
	tw.tween_property(chest, "position:y", chest.position.y + 0.4, 0.1)
	tw.tween_property(chest, "position:y", chest.position.y, 0.12)
	if by and by.has_method("take_damage"):
		by.take_damage(8.0, chest.global_position, 4.0)

func _prop(name: String, parent: Node3D, at: Vector3, yaw: float, scl: float) -> Node3D:
	var path := "res://assets/kaykit/forest/%s.gltf" % name
	if name == "" or not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(n)
	n.position = at; n.rotation_degrees.y = yaw; n.scale = Vector3.ONE * scl
	return n

func _kit(name: String, parent: Node3D, at: Vector3, yaw: float, scl: float) -> void:
	var path := "res://assets/kaykit/kitchen/%s.gltf" % name
	if not ResourceLoader.exists(path):
		return
	var n: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(n)
	n.position = at; n.rotation_degrees.y = yaw; n.scale = Vector3.ONE * scl

func _mushroom(parent: Node3D, p: Vector3, col: Color) -> void:
	var cap := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.3; sm.height = 0.3; sm.is_hemisphere = true
	cap.mesh = sm; cap.material_override = FX.glow_material(col, 1.5); cap.position = p + Vector3(0, 0.38, 0)
	parent.add_child(cap)
	var stem := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.09; cm.height = 0.4
	var st := StandardMaterial3D.new(); st.albedo_color = Color(0.9, 0.86, 0.75); stem.mesh = cm; stem.material_override = st
	stem.position = p + Vector3(0, 0.2, 0); parent.add_child(stem)

func _sign(parent: Node3D, at: Vector3, text: String) -> void:
	var post := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(0.12, 1.4, 0.12); post.mesh = pm
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.45, 0.3, 0.16); post.material_override = wood
	post.position = at + Vector3(0, 0.7, 0); parent.add_child(post)
	var board := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.5, 0.75, 0.08); board.mesh = bm
	var bw := StandardMaterial3D.new(); bw.albedo_color = Color(0.72, 0.55, 0.32); board.material_override = bw
	board.position = at + Vector3(0, 1.35, 0); parent.add_child(board)
	for side in [1.0, -1.0]:
		var l := Label3D.new(); l.text = text; l.font_size = 40; l.pixel_size = 0.0045; l.outline_size = 0
		l.modulate = Color(0.18, 0.1, 0.04); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = at + Vector3(0, 1.35, 0.05 * side)
		if side < 0:
			l.rotation.y = PI
		parent.add_child(l)
