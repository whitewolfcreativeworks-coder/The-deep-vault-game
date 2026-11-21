extends HomeBuilding
class_name HomeDecor
## Things for your yard, bought at Tobble's Trading Post (Game.decor). Each one
## appears in the yard the moment you buy it, and stays.
##   flower_garden   flower beds in front of the cabin
##   twinkle_lights  strings of little coloured lights along the path to the portal
##   gnome           a garden gnome by the pumpkins
##   bench           a bench by the garden
##   bird_bath       a stone bird bath (and the birds come and sing more often)
##   statue          a giant golden statue of your hero
## Everything's simple shapes (no extra lights), so it costs next to nothing to draw.

var built := {}

static func build_in(h: HomeWorld) -> HomeDecor:
	var d := HomeDecor.new()
	d.name = "Decor"
	d.home = h
	h.add_child(d)
	d.refresh()
	Game.inventory_changed.connect(d.refresh)
	return d

func refresh() -> void:
	for id in Game.decor:
		if built.has(id):
			continue
		var n := Node3D.new(); n.name = String(id)
		add_child(n)
		built[id] = n
		match String(id):
			"flower_garden": _flowers(n)
			"twinkle_lights": _lights(n)
			"gnome": _gnome(n)
			"bench": _bench(n)
			"bird_bath": _bird_bath(n)
			"statue": _statue(n)
	if home._scen and home._scen.soundscape:
		home._scen.soundscape.more_birds = Game.decor.has("bird_bath")

## Vertex colours: the Forward+ renderer wants them linear (like the valley's own).
static func _vc(c: Color) -> Color:
	return c if Game.is_compat() else c.srgb_to_linear()

func _g(x: float, z: float) -> Vector3:
	return home.ground(x, z)

# --- flower beds -----------------------------------------------------------------------
func _flowers(n: Node3D) -> void:
	var soil := mat(Color(0.3, 0.2, 0.12), 1.0)
	var r := RandomNumberGenerator.new(); r.seed = 41
	for bed in [[Vector2(-2.0, 3.9), 2.4], [Vector2(3.4, 3.9), 1.6]]:
		var c: Vector2 = bed[0]
		var wdt: float = bed[1]
		var at := _g(c.x, c.y)
		box(n, at + Vector3(-wdt * 0.5, -0.1, -0.35), at + Vector3(wdt * 0.5, 0.12, 0.35), soil, false)
		for k in [-1, 1]:
			box(n, at + Vector3(-wdt * 0.5 - 0.06, -0.1, k * 0.38 - 0.04), at + Vector3(wdt * 0.5 + 0.06, 0.18, k * 0.38 + 0.04), mat(Color(0.6, 0.6, 0.58)), false)
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
		var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.1; sm.radial_segments = 8; sm.rings = 4
		mm.mesh = sm
		var cnt := int(wdt * 14)
		mm.instance_count = cnt * 2
		var cols := [Color(1.0, 0.35, 0.45), Color(1.0, 0.85, 0.25), Color(0.75, 0.45, 1.0), Color(1.0, 0.6, 0.85), Color(1.0, 1.0, 0.95), Color(1.0, 0.5, 0.2)]
		for k in cnt:
			var p := at + Vector3(r.randf_range(-wdt * 0.45, wdt * 0.45), 0.0, r.randf_range(-0.28, 0.28))
			var hgt := r.randf_range(0.22, 0.4)
			mm.set_instance_transform(k * 2, Transform3D(Basis().scaled(Vector3(1, 1, 1)), p + Vector3(0, hgt, 0)))
			mm.set_instance_color(k * 2, _vc(cols[r.randi() % cols.size()]))
			mm.set_instance_transform(k * 2 + 1, Transform3D(Basis().scaled(Vector3(0.7, 2.2, 0.7)), p + Vector3(0, hgt * 0.5, 0)))
			mm.set_instance_color(k * 2 + 1, _vc(Color(0.3, 0.62, 0.25)))
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
		var fm := StandardMaterial3D.new(); fm.vertex_color_use_as_albedo = true; fm.roughness = 0.7
		mi.material_override = fm
		n.add_child(mi)

# --- twinkle lights ---------------------------------------------------------------------
func _lights(n: Node3D) -> void:
	var post := mat(Color(0.35, 0.22, 0.12), 0.8)
	var a := Vector2(IntroMovie.DOOR.x, IntroMovie.DOOR.z) + Vector2(0, 1.5)
	var b := Vector2(IntroMovie.PORTAL.x, IntroMovie.PORTAL.z) - Vector2(1.6, 2.2)
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * 1.9
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var sm := SphereMesh.new(); sm.radius = 0.045; sm.height = 0.09; sm.radial_segments = 8; sm.rings = 4
	mm.mesh = sm
	var per := 9
	var posts := 4
	mm.instance_count = 2 * (posts - 1) * per
	var cols := [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3), Color(0.35, 1.0, 0.45), Color(0.35, 0.65, 1.0), Color(1.0, 0.45, 0.9)]
	var i := 0
	for s: float in [-1.0, 1.0]:
		var tops: Array = []
		for k in posts:
			var p2 := a + (b - a) * (float(k) / float(posts - 1)) + side * s
			var g := _g(p2.x, p2.y)
			cylinder(n, g, 0.05, 0.06, 2.3, post)
			tops.append(g + Vector3(0, 2.25, 0))
		for k in posts - 1:
			var p0: Vector3 = tops[k]
			var p1: Vector3 = tops[k + 1]
			for j in per:
				var t := (j + 0.5) / float(per)
				var p := p0.lerp(p1, t) - Vector3(0, sin(t * PI) * 0.45, 0)
				mm.set_instance_transform(i, Transform3D(Basis(), p))
				mm.set_instance_color(i, _vc(cols[(i + int(s)) % cols.size()]) * (1.0 if Game.is_compat() else 1.3))
				i += 1
			# the wire
			var wire := MeshInstance3D.new(); var cm := CylinderMesh.new()
			cm.top_radius = 0.008; cm.bottom_radius = 0.008; cm.height = p0.distance_to(p1); cm.radial_segments = 4
			wire.mesh = cm; wire.material_override = mat(Color(0.15, 0.15, 0.15))
			n.add_child(wire)
			wire.position = (p0 + p1) * 0.5 - Vector3(0, 0.3, 0)
			wire.look_at(p1 - Vector3(0, 0.3, 0), Vector3.UP)
			wire.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	var bm := StandardMaterial3D.new(); bm.vertex_color_use_as_albedo = true
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)

# --- the gnome -------------------------------------------------------------------------
func _gnome(n: Node3D) -> void:
	var g := Node3D.new(); n.add_child(g)
	g.position = _g(-1.2, 9.6)
	g.rotation.y = deg_to_rad(20.0)
	gnome_model(self, g, 1.0)

## A garden gnome (also on show at the Trading Post).
static func gnome_model(b: HomeBuilding, g: Node3D, s: float) -> void:
	b.cylinder(g, Vector3.ZERO, 0.17 * s, 0.22 * s, 0.32 * s, mat(Color(0.2, 0.35, 0.75), 0.7))                     # coat
	b.cylinder(g, Vector3(0, 0.0, 0), 0.23 * s, 0.24 * s, 0.05 * s, mat(Color(0.25, 0.2, 0.15)))                    # boots
	b.sphere(g, Vector3(0, 0.42 * s, 0), 0.12 * s, mat(Color(1.0, 0.82, 0.68), 0.6))                                 # face
	b.sphere(g, Vector3(0, 0.42 * s, -0.11 * s), 0.035 * s, mat(Color(1.0, 0.6, 0.55), 0.5))                         # nose
	var beard := b.sphere(g, Vector3(0, 0.34 * s, -0.06 * s), 0.12 * s, mat(Color(0.97, 0.97, 0.95), 0.9), 1.3)
	beard.scale = Vector3(1.0, 1.0, 0.7)
	b.cylinder(g, Vector3(0, 0.5 * s, 0), 0.0, 0.14 * s, 0.38 * s, mat(Color(0.85, 0.15, 0.15), 0.6))               # hat

# --- the bench -------------------------------------------------------------------------
func _bench(n: Node3D) -> void:
	var path := "res://assets/kaykit/halloween/bench.gltf"
	if not ResourceLoader.exists(path):
		return
	var bn: Node3D = (load(path) as PackedScene).instantiate()
	n.add_child(bn)
	bn.position = _g(12.4, 8.7)
	bn.rotation.y = deg_to_rad(-130.0)
	var a := Props.mesh_aabb(bn)
	if a.size.x > 0.0:
		bn.scale = Vector3.ONE * clampf(1.8 / maxf(a.size.x, a.size.z), 0.3, 6.0)

# --- the bird bath ---------------------------------------------------------------------
func _bird_bath(n: Node3D) -> void:
	var at := _g(10.6, 7.0)
	var stone := mat(Color(0.7, 0.7, 0.68), 0.9)
	cylinder(n, at, 0.22, 0.3, 0.1, stone)
	cylinder(n, at + Vector3(0, 0.1, 0), 0.1, 0.14, 0.62, stone)
	cylinder(n, at + Vector3(0, 0.72, 0), 0.5, 0.2, 0.16, stone)
	var water := cylinder(n, at + Vector3(0, 0.86, 0), 0.43, 0.43, 0.01, null)
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.45, 0.7, 0.9); wm.roughness = 0.05; wm.metallic = 0.2
	wm.emission_enabled = true; wm.emission = Color(0.1, 0.2, 0.3)
	water.material_override = wm
	# a little bird on the rim
	var bird := Node3D.new(); n.add_child(bird); bird.position = at + Vector3(0.42, 0.9, 0)
	var feathers := mat(Color(0.45, 0.6, 0.85), 0.7)
	var bd := sphere(bird, Vector3(0, 0.07, 0), 0.07, feathers, 1.0)
	bd.scale = Vector3(1.0, 0.9, 1.3)
	sphere(bird, Vector3(0, 0.15, -0.06), 0.05, feathers)
	sphere(bird, Vector3(0, 0.1, 0.04), 0.05, mat(Color(1.0, 0.55, 0.35), 0.7))        # a red breast
	var beak := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.018; cm.height = 0.05
	beak.mesh = cm; beak.material_override = mat(Color(1.0, 0.75, 0.2))
	bird.add_child(beak); beak.position = Vector3(0, 0.15, -0.12); beak.rotation.x = -PI * 0.5
	var hop := create_tween().set_loops()
	hop.tween_interval(2.5)
	hop.tween_property(bird, "rotation:y", PI * 0.6, 0.15).as_relative()
	hop.tween_property(bird, "position:y", 0.06, 0.08).as_relative()
	hop.tween_property(bird, "position:y", -0.06, 0.08).as_relative()
	hop.tween_interval(3.0)
	hop.tween_property(bird, "rotation:y", -PI * 0.6, 0.15).as_relative()

# --- the golden statue -----------------------------------------------------------------
func _statue(n: Node3D) -> void:
	var at := _g(7.6, 3.4)
	var grp := Node3D.new(); n.add_child(grp)
	grp.position = at
	grp.rotation.y = deg_to_rad(157.0)       # looking out over the yard (the statue faces local -z)
	var stone := mat(Color(0.75, 0.72, 0.68), 0.85)
	var goldm := mat(Color(1.0, 0.78, 0.3), 0.22, 0.95)
	goldm.emission_enabled = true; goldm.emission = Color(0.25, 0.15, 0.02); goldm.emission_energy_multiplier = 0.6
	box(grp, Vector3(-1.1, -0.3, -1.1), Vector3(1.1, 0.9, 1.1), stone)
	box(grp, Vector3(-1.2, 0.9, -1.2), Vector3(1.2, 1.05, 1.2), goldm, false)
	var m := CharacterModel.new()
	grp.add_child(m)
	m.position = Vector3(0, 1.05, 0)
	var p := Game.profile
	var cfg := {"kind": "hero", "hero": p.hero, "show_hat": p.show_hat, "weapon": Game.equipped.get("weapon", ""),
		"shield": Game.item(Game.equipped.get("armor", "")).get("shield", "shield_round"), "scale": 0.84 * 1.9}
	Player._apply_profile_looks(cfg)
	m.setup(cfg)
	m.set_process(false)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = goldm
		(mi as MeshInstance3D).material_overlay = null
	if m.anim:
		var clip := "Cheer" if m.anim.has_animation("Cheer") else "Idle"
		m.anim.play(clip)
		m.anim.seek(minf(0.9, m.anim.get_animation(clip).length * 0.5), true)
		m.anim.speed_scale = 0.0
	var plaque := label_sign(grp, Vector3(0, 0.35, -1.12), "%s\nthe %s" % [p.name, p.hero], Color(1.0, 0.9, 0.55), 1.7, 0.6)
	plaque.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plaque.rotation.y = PI
	var sp := CPUParticles3D.new(); sp.amount = 16; sp.lifetime = 2.0
	sp.mesh = FX.quad(0.08); sp.material_override = FX.glow_material(Color(1.0, 0.9, 0.5), 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sp.emission_box_extents = Vector3(0.8, 1.6, 0.8)
	sp.direction = Vector3.UP; sp.spread = 30; sp.initial_velocity_min = 0.1; sp.initial_velocity_max = 0.3; sp.gravity = Vector3.ZERO
	grp.add_child(sp); sp.position = Vector3(0, 2.8, 0)
