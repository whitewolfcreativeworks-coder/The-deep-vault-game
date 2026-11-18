extends Node3D
class_name ForestDiscoveries
## Little surprises tucked away in the Goblin Forest, in different spots every
## visit. Each one does something cute when you use it and gives a small gift
## the first time:
##   gnome_house   knock on a mushroom house: a gnome pops out with a cookie
##   teddy         a lost teddy bear on a stump: hug it (full health)
##   frog          a frog with a crown on a lily pad: kiss it (it's just a frog)
##   snails        a snail race: cheer and the snails race to the finish
##   bunnies       a bunny family by their burrow: share a carrot
##   bottle        a message in a bottle on the stream bank

const KINDS := ["gnome_house", "teddy", "frog", "snails", "bunnies", "bottle"]
var forest: ForestWorld
var _rng := RandomNumberGenerator.new()

static func build_in(f: ForestWorld) -> ForestDiscoveries:
	var d := ForestDiscoveries.new()
	d.name = "Discoveries"
	d.forest = f
	f.add_child(d)
	d._place_all()
	return d

func _place_all() -> void:
	_rng.randomize()
	var used: Array[Vector2] = []
	for k in KINDS:
		var spot := Vector2.INF
		for attempt in 60:
			var p := Vector2(_rng.randf_range(-100, 100), _rng.randf_range(-80, 100))
			if k == "bottle":
				# on the stream bank
				if forest.stream_dist(p) > 5.5 or forest.stream_dist(p) < 3.5:
					continue
			elif not forest._wild_spot_ok(p):
				continue
			if p.distance_to(Vector2(0, 92)) < 18.0 or used.any(func(u: Vector2) -> bool: return u.distance_to(p) < 30.0):
				continue
			spot = p
			break
		if spot == Vector2.INF:
			continue
		used.append(spot)
		var spot_node := Spot.new()
		spot_node.kind = k
		add_child(spot_node)
		spot_node.global_position = forest.ground(spot.x, spot.y)
		spot_node.rotation.y = _rng.randf() * TAU
		spot_node.build()

static func mt(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough
	return m

static func ball(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 14; sm.rings = 7
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	parent.add_child(mi)
	return mi


class Spot extends Node3D:
	var kind := ""
	var _actors: Array[Node3D] = []
	var _busy := 0.0
	var _t := 0.0
	var _bubble: Label3D

	func build() -> void:
		add_to_group("interactable")
		match kind:
			"gnome_house": _gnome_house()
			"teddy": _teddy()
			"frog": _frog()
			"snails": _snails()
			"bunnies": _bunnies()
			"bottle": _bottle()
		# a soft twinkle so you notice it from a little way off
		var sp := CPUParticles3D.new(); sp.amount = 10; sp.lifetime = 2.2; sp.preprocess = 2.0
		sp.mesh = FX.quad(0.09); sp.material_override = FX.glow_material(Color(1.0, 0.95, 0.7), 2.5)
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 1.4
		sp.direction = Vector3.UP; sp.spread = 40; sp.initial_velocity_min = 0.1; sp.initial_velocity_max = 0.4
		sp.gravity = Vector3.ZERO; sp.position.y = 1.0
		add_child(sp)
		_bubble = Label3D.new(); _bubble.font_size = 64; _bubble.pixel_size = 0.005; _bubble.outline_size = 14
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _bubble.modulate = Color(1.0, 0.98, 0.9)
		_bubble.position.y = 2.6; _bubble.visible = false; _bubble.no_depth_test = true
		add_child(_bubble)

	func get_prompt() -> String:
		match kind:
			"gnome_house": return "[E] Knock on the tiny door"
			"teddy": return "[E] Hug the teddy bear"
			"frog": return "[E] Kiss the frog?"
			"snails": return "[E] Cheer for the snails!"
			"bunnies": return "[E] Share a carrot"
			"bottle": return "[E] Read the message in the bottle"
		return "[E] Look"

	func can_interact() -> bool:
		return _busy <= 0.0

	func _say(text: String, secs := 3.5) -> void:
		_bubble.text = text
		_bubble.visible = true
		get_tree().create_timer(secs).timeout.connect(func() -> void:
			if is_instance_valid(_bubble):
				_bubble.visible = false)

	func _first() -> bool:
		var f := "disc_" + kind
		if Game.flags.get(f, false):
			return false
		Game.flags[f] = true
		return true

	func interact(by: Node) -> void:
		_busy = 4.0
		var first := _first()
		var at := global_position + Vector3(0, 1.0, 0)
		match kind:
			"gnome_house":
				var g := _actors[0]
				g.visible = true
				var tw := g.create_tween()
				tw.tween_property(g, "position:z", -1.0, 0.4).set_trans(Tween.TRANS_BACK)
				tw.tween_interval(2.6)
				tw.tween_property(g, "position:z", -0.2, 0.4)
				tw.tween_callback(func() -> void: g.visible = false)
				Sfx.play_at("door", global_position, -6.0, 0.1)
				_say("Oh! A visitor! Have a cookie!" if first else "Back again? Sorry, all out of cookies!")
				if first:
					Pickup.spawn(at + Vector3(0, 0, -1.5), "stamina")
					Game.add_gold(25)
			"teddy":
				FX.burst(at + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.65), 40, 2.5, 0.15, 1.2, 1.5)
				Sfx.play("levelup", -12.0, 0.2)
				Game.hp = Game.max_hp(); Game.stamina = Game.max_stamina()
				Game.stats_changed.emit()
				_say("The teddy feels loved. You feel great!")
				var tb := _actors[0]
				var tw2 := tb.create_tween()
				tw2.tween_property(tb, "scale", Vector3(1.15, 0.9, 1.15), 0.15)
				tw2.tween_property(tb, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
			"frog":
				FX.burst(_actors[0].global_position + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.9), 50, 3.0, 0.2, 0.8, 0.5)
				Sfx.play_at("pop", global_position, -4.0, 0.1)
				_say("POOF! ...Ribbit. (It was just a frog.)" if first else "Ribbit.")
				if first:
					Pickup.spawn(at, "mana")
					Pickup.spawn(at, "potion")
				var fr := _actors[0]
				var tw3 := fr.create_tween()
				tw3.tween_property(fr, "position:y", fr.position.y + 0.8, 0.25).set_trans(Tween.TRANS_SINE)
				tw3.tween_property(fr, "position:y", fr.position.y, 0.25).set_trans(Tween.TRANS_SINE)
			"snails":
				var winner := randi() % 3
				var names := ["Speedy (red)", "Zoom (blue)", "Lightning (green)"]
				for i in 3:
					var sn := _actors[i]
					var tw4 := sn.create_tween()
					var spd := 2.2 if i == winner else randf_range(2.6, 3.4)
					tw4.tween_property(sn, "position:z", -2.4, spd).set_trans(Tween.TRANS_QUAD)
					tw4.tween_interval(1.2)
					tw4.tween_property(sn, "position:z", 2.4, 0.01)
				Sfx.play("whistle", -6.0, 0.1)
				get_tree().create_timer(2.4).timeout.connect(func() -> void:
					_say("%s wins!" % names[winner])
					Sfx.play("coins", -6.0)
					FX.burst(global_position + Vector3(-0.8 + winner * 0.8, 0.6, -2.4), Color(1.0, 0.85, 0.3), 30, 2.0, 0.1, 0.8, 0.5))
				if first:
					Game.add_gold(40)
			"bunnies":
				var p := (by as Node3D).global_position if by is Node3D else global_position
				for bn in _actors:
					var tw5 := bn.create_tween()
					var to := bn.global_position.lerp(p, 0.55)
					tw5.tween_property(bn, "global_position", to + Vector3(0, 0.5, 0), 0.3)
					tw5.tween_property(bn, "global_position", to, 0.3)
				FX.burst(p + Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.7), 24, 2.0, 0.12, 1.0, 1.0)
				_say("Nom nom nom! The bunnies love you." if not first else "Nom nom! They give you a lucky clover!")
				if first:
					Pickup.spawn(at, "stamina")
					Pickup.spawn(at, "stamina")
			"bottle":
				var sc := get_tree().current_scene
				if sc.has_method("show_lore"):
					sc.show_lore("A message in a bottle", "To whoever finds this:\n\nThe goblins took my sandwich. Not my gold, not my sword. My SANDWICH.\nIf you see a goblin with crumbs on its face, it's that one.\n\nAlso, I hid some coins under this bottle. You've earned them.\n\n- Bobek")
				if first:
					Game.add_gold(60)
					Sfx.play("coins", -4.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		_busy -= delta
		match kind:
			"bunnies":
				for i in _actors.size():
					var bn := _actors[i]
					var hop := maxf(0.0, sin(_t * 4.0 + i * 2.1))
					bn.get_child(0).position.y = hop * 0.25
			"frog":
				if _actors.size() > 0:
					_actors[0].scale.y = 1.0 + sin(_t * 3.0) * 0.06

	# --- the little scenes ---------------------------------------------------
	func _gnome_house() -> void:
		var stem := ForestDiscoveries.mt(Color(0.95, 0.9, 0.8))
		var cap := ForestDiscoveries.mt(Color(0.85, 0.12, 0.1), 0.6)
		var white := ForestDiscoveries.mt(Color(1, 1, 1))
		Playground.cyl(self, 0.75, 0.9, 1.8, stem, Vector3(0, 0.9, 0))
		ForestDiscoveries.ball(self, 1.5, cap, Vector3(0, 2.0, 0), Vector3(1.0, 0.55, 1.0))
		for d in [Vector3(0.7, 2.35, 0.6), Vector3(-0.6, 2.4, 0.5), Vector3(0.1, 2.55, -0.7), Vector3(-0.8, 2.25, -0.4), Vector3(0.9, 2.2, -0.5)]:
			ForestDiscoveries.ball(self, 0.18, white, d, Vector3(1, 0.4, 1))
		var door := Playground.box(self, Vector3(0.55, 0.85, 0.08), ForestDiscoveries.mt(Color(0.45, 0.28, 0.14)), Vector3(0, 0.45, -0.85))
		door.name = "Door"
		ForestDiscoveries.ball(self, 0.04, ForestDiscoveries.mt(Color(1.0, 0.8, 0.3), 0.3), Vector3(0.18, 0.45, -0.9))
		var win := StandardMaterial3D.new(); win.albedo_color = Color(1.0, 0.85, 0.4); win.emission_enabled = true
		win.emission = Color(1.0, 0.75, 0.3); win.emission_energy_multiplier = 2.0
		Playground.cyl(self, 0.16, 0.16, 0.05, win, Vector3(0.45, 1.25, -0.72), Vector3(PI / 2 - 0.3, 0.5, 0))
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.75, 0.35); l.light_energy = 0.8; l.omni_range = 3.0
		l.position = Vector3(0.45, 1.25, -1.0); add_child(l)
		Playground.box(self, Vector3(0.12, 0.04, 0.6), ForestDiscoveries.mt(Color(0.55, 0.5, 0.45)), Vector3(0, 0.02, -1.2))
		# the gnome (hidden until you knock)
		var g := Node3D.new(); g.position = Vector3(0, 0, -0.2); add_child(g); g.visible = false
		ForestDiscoveries.ball(g, 0.22, ForestDiscoveries.mt(Color(0.25, 0.4, 0.85)), Vector3(0, 0.3, 0), Vector3(1, 1.2, 1))
		ForestDiscoveries.ball(g, 0.15, ForestDiscoveries.mt(Color(1.0, 0.82, 0.7)), Vector3(0, 0.62, 0))
		ForestDiscoveries.ball(g, 0.13, white, Vector3(0, 0.52, -0.1), Vector3(1, 1.3, 0.7))
		ForestDiscoveries.ball(g, 0.04, ForestDiscoveries.mt(Color(1.0, 0.55, 0.5)), Vector3(0, 0.62, -0.15))
		Playground.cyl(g, 0.0, 0.17, 0.45, cap, Vector3(0, 0.9, 0))
		_actors.append(g)

	func _teddy() -> void:
		var wood := ForestDiscoveries.mt(Color(0.5, 0.33, 0.18), 0.9)
		Playground.cyl(self, 0.5, 0.55, 0.6, wood, Vector3(0, 0.3, 0))
		Playground.cyl(self, 0.48, 0.48, 0.02, ForestDiscoveries.mt(Color(0.8, 0.65, 0.42)), Vector3(0, 0.61, 0))
		var t := Node3D.new(); t.position = Vector3(0, 0.62, 0); add_child(t)
		var fur := ForestDiscoveries.mt(Color(0.72, 0.48, 0.28), 1.0)
		var tan := ForestDiscoveries.mt(Color(0.92, 0.78, 0.58), 1.0)
		var dark := ForestDiscoveries.mt(Color(0.08, 0.05, 0.04), 0.3)
		ForestDiscoveries.ball(t, 0.25, fur, Vector3(0, 0.25, 0), Vector3(1, 1.1, 0.9))
		ForestDiscoveries.ball(t, 0.15, tan, Vector3(0, 0.22, -0.16), Vector3(1, 1.1, 0.6))
		ForestDiscoveries.ball(t, 0.2, fur, Vector3(0, 0.6, 0))
		for sx in [-1.0, 1.0]:
			ForestDiscoveries.ball(t, 0.08, fur, Vector3(sx * 0.15, 0.76, 0))
			ForestDiscoveries.ball(t, 0.045, tan, Vector3(sx * 0.15, 0.76, -0.04))
			ForestDiscoveries.ball(t, 0.03, dark, Vector3(sx * 0.07, 0.64, -0.17))
			ForestDiscoveries.ball(t, 0.09, fur, Vector3(sx * 0.28, 0.32, -0.04), Vector3(0.8, 1.3, 0.8))
			ForestDiscoveries.ball(t, 0.1, fur, Vector3(sx * 0.13, 0.06, -0.18), Vector3(0.9, 0.8, 1.3))
		ForestDiscoveries.ball(t, 0.08, tan, Vector3(0, 0.55, -0.17), Vector3(1, 0.8, 0.7))
		ForestDiscoveries.ball(t, 0.03, dark, Vector3(0, 0.57, -0.23))
		var bow := ForestDiscoveries.mt(Color(0.9, 0.2, 0.3), 0.5)
		for sx in [-1.0, 1.0]:
			ForestDiscoveries.ball(t, 0.06, bow, Vector3(sx * 0.07, 0.43, -0.12), Vector3(1.2, 0.8, 0.5))
		_actors.append(t)
		var note := Label3D.new(); note.text = "If found,\nplease hug."; note.font_size = 40; note.pixel_size = 0.004
		note.modulate = Color(0.25, 0.2, 0.15); note.outline_size = 0
		note.position = Vector3(0.0, 0.35, -0.56); add_child(note)
		Playground.box(self, Vector3(0.5, 0.3, 0.01), ForestDiscoveries.mt(Color(0.98, 0.96, 0.88)), Vector3(0, 0.35, -0.555))

	func _frog() -> void:
		var water := StandardMaterial3D.new(); water.albedo_color = Color(0.2, 0.45, 0.55, 0.85); water.roughness = 0.05
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; water.metallic = 0.3
		Playground.cyl(self, 1.8, 1.8, 0.04, water, Vector3(0, 0.03, 0), Vector3.ZERO, 32)
		for k in 9:
			var a := k * TAU / 9.0
			ForestDiscoveries.ball(self, 0.28, ForestDiscoveries.mt(Color(0.5, 0.5, 0.48)), Vector3(cos(a) * 1.95, 0.06, sin(a) * 1.95), Vector3(1, 0.5, 1))
		var pad := ForestDiscoveries.mt(Color(0.3, 0.65, 0.25), 0.6)
		for pp in [Vector3(0.4, 0.06, 0.3), Vector3(-0.7, 0.06, -0.5), Vector3(0.9, 0.06, -0.8)]:
			Playground.cyl(self, 0.38, 0.38, 0.02, pad, pp)
		ForestDiscoveries.ball(self, 0.08, ForestDiscoveries.mt(Color(1.0, 0.7, 0.85)), Vector3(-0.6, 0.12, -0.4))
		var f := Node3D.new(); f.position = Vector3(0.4, 0.08, 0.3); add_child(f)
		var green := ForestDiscoveries.mt(Color(0.35, 0.75, 0.3), 0.5)
		ForestDiscoveries.ball(f, 0.18, green, Vector3(0, 0.12, 0), Vector3(1.1, 0.75, 1.0))
		for sx in [-1.0, 1.0]:
			ForestDiscoveries.ball(f, 0.07, green, Vector3(sx * 0.09, 0.26, -0.06))
			ForestDiscoveries.ball(f, 0.04, ForestDiscoveries.mt(Color(1, 1, 1)), Vector3(sx * 0.09, 0.28, -0.11))
			ForestDiscoveries.ball(f, 0.02, ForestDiscoveries.mt(Color(0, 0, 0)), Vector3(sx * 0.09, 0.285, -0.145))
		var gold := ForestDiscoveries.mt(Color(1.0, 0.8, 0.25), 0.3)
		gold.metallic = 0.8
		Playground.cyl(f, 0.08, 0.08, 0.06, gold, Vector3(0, 0.34, -0.02))
		for k in 4:
			var a := k * TAU / 4.0
			Playground.cyl(f, 0.0, 0.025, 0.07, gold, Vector3(cos(a) * 0.07, 0.4, sin(a) * 0.07 - 0.02))
		_actors.append(f)

	func _snails() -> void:
		var track := ForestDiscoveries.mt(Color(0.55, 0.42, 0.28), 1.0)
		Playground.box(self, Vector3(2.6, 0.03, 5.4), track, Vector3(0, 0.02, 0))
		for x in [-0.4, 0.4]:
			Playground.box(self, Vector3(0.04, 0.05, 5.2), ForestDiscoveries.mt(Color(1, 1, 1)), Vector3(x, 0.05, 0))
		var flag_c := ForestDiscoveries.mt(Color(1, 1, 1))
		for x in [-1.3, 1.3]:
			Playground.cyl(self, 0.03, 0.03, 1.2, ForestDiscoveries.mt(Color(0.3, 0.3, 0.3)), Vector3(x, 0.6, -2.5))
		Playground.box(self, Vector3(2.6, 0.3, 0.02), flag_c, Vector3(0, 1.1, -2.5))
		var fl := Label3D.new(); fl.text = "FINISH"; fl.font_size = 48; fl.pixel_size = 0.005; fl.modulate = Color(0.1, 0.1, 0.1)
		fl.outline_size = 0; fl.position = Vector3(0, 1.1, -2.52); fl.rotation.y = PI; add_child(fl)
		var sl := Label3D.new(); sl.text = "THE GREAT\nSNAIL RACE"; sl.font_size = 56; sl.pixel_size = 0.005
		sl.modulate = Color(1.0, 0.85, 0.3); sl.outline_size = 10; sl.position = Vector3(1.9, 1.3, 2.4)
		sl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; add_child(sl)
		var shells := [Color(0.9, 0.2, 0.15), Color(0.2, 0.45, 0.95), Color(0.3, 0.8, 0.3)]
		for i in 3:
			var sn := Node3D.new(); sn.position = Vector3(-0.8 + i * 0.8, 0.03, 2.4); add_child(sn)
			var body := ForestDiscoveries.mt(Color(0.85, 0.78, 0.6), 0.5)
			ForestDiscoveries.ball(sn, 0.12, body, Vector3(0, 0.06, 0), Vector3(0.8, 0.5, 2.0))
			ForestDiscoveries.ball(sn, 0.16, ForestDiscoveries.mt(shells[i], 0.4), Vector3(0, 0.2, 0.06))
			for sx in [-0.04, 0.04]:
				Playground.cyl(sn, 0.008, 0.008, 0.14, body, Vector3(sx, 0.16, -0.2), Vector3(-0.4, 0, 0))
			sn.rotation.y = 0.0
			_actors.append(sn)

	func _bunnies() -> void:
		var dirt := ForestDiscoveries.mt(Color(0.45, 0.33, 0.2), 1.0)
		ForestDiscoveries.ball(self, 1.0, dirt, Vector3(0, 0, 0), Vector3(1.2, 0.45, 1.0))
		ForestDiscoveries.ball(self, 0.3, ForestDiscoveries.mt(Color(0.05, 0.04, 0.03)), Vector3(0, 0.15, -0.9), Vector3(1.2, 0.9, 0.4))
		for k in 5:
			var c := Vector3(-1.4 + k * 0.6, 0, 1.4)
			Playground.cyl(self, 0.0, 0.05, 0.25, ForestDiscoveries.mt(Color(1.0, 0.5, 0.1)), c + Vector3(0, 0.05, 0), Vector3(PI, 0, 0))
			for j in 3:
				Playground.box(self, Vector3(0.03, 0.22, 0.08), ForestDiscoveries.mt(Color(0.3, 0.7, 0.25)), c + Vector3(0, 0.2, 0), Vector3(0, j * 1.0, 0.3))
		var cols := [Color(0.95, 0.95, 0.95), Color(0.6, 0.45, 0.32), Color(0.75, 0.72, 0.7)]
		for i in 3:
			var bn := Node3D.new(); bn.position = Vector3(-1.2 + i * 1.2, 0, -1.6 + (i % 2) * 0.5); add_child(bn)
			bn.rotation.y = randf() * TAU
			var inner := Node3D.new(); bn.add_child(inner)
			var fur := ForestDiscoveries.mt(cols[i], 1.0)
			ForestDiscoveries.ball(inner, 0.17, fur, Vector3(0, 0.16, 0.04), Vector3(0.9, 0.85, 1.15))
			ForestDiscoveries.ball(inner, 0.11, fur, Vector3(0, 0.3, -0.12))
			ForestDiscoveries.ball(inner, 0.06, ForestDiscoveries.mt(Color(1, 1, 1)), Vector3(0, 0.18, 0.2))
			for sx in [-0.04, 0.04]:
				ForestDiscoveries.ball(inner, 0.035, fur, Vector3(sx, 0.48, -0.1), Vector3(0.7, 2.6, 0.5))
				ForestDiscoveries.ball(inner, 0.016, ForestDiscoveries.mt(Color(0.05, 0.05, 0.05)), Vector3(sx * 1.2, 0.33, -0.21))
			_actors.append(bn)

	func _bottle() -> void:
		var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.4, 0.75, 0.55, 0.6)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = 0.05; glass.metallic = 0.2
		var b := Node3D.new(); b.position = Vector3(0, 0.12, 0); b.rotation = Vector3(PI / 2, 0, 0.2); add_child(b)
		Playground.cyl(b, 0.11, 0.11, 0.4, glass, Vector3.ZERO)
		Playground.cyl(b, 0.04, 0.1, 0.12, glass, Vector3(0, 0.26, 0))
		Playground.cyl(b, 0.045, 0.045, 0.06, ForestDiscoveries.mt(Color(0.6, 0.45, 0.3)), Vector3(0, 0.34, 0))
		Playground.cyl(b, 0.06, 0.06, 0.26, ForestDiscoveries.mt(Color(0.95, 0.9, 0.75)), Vector3(0, -0.02, 0))
		for k in 3:
			ForestDiscoveries.ball(self, 0.06, ForestDiscoveries.mt(Color(0.9, 0.8, 0.6)), Vector3(0.4 + k * 0.15, 0.03, -0.3 + k * 0.2), Vector3(1, 0.4, 1))
