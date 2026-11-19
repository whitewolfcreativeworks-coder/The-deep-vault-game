extends Node3D
class_name CreatureLook
## Cloud Island creatures built from simple shapes: thunder birds, storm
## sprites, storm bats, bubble mimics, the Hail Golem and Mr. Bubbles himself.
## The enemy keeps an (invisible) skeleton CharacterModel for its animation
## timing; this node is the picture you see, with its own little flap / bob.

var kind := ""
var meshes: Array[MeshInstance3D] = []
var _t := 0.0
var _wings: Array[Node3D] = []
var _bob: Node3D
var flap_speed := 9.0
var _orbit: Node3D
var wing_amp := 0.6
var _roll: Node3D             # the Hail Golem's body, which rolls as he moves
var _fists: Array[Node3D] = []
var _last_pos := Vector3.ZERO

static func make(k: String, flash: Material) -> CreatureLook:
	var c := CreatureLook.new()
	c.kind = k
	c._build(flash)
	return c

func _mat(col: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = emit
	return m

func _see(col: Color, a := 0.4, emit := 0.6) -> StandardMaterial3D:
	var m := _mat(Color(col.r, col.g, col.b, a), 0.1, emit)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _ball(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 16; sm.rings = 8
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	parent.add_child(mi); meshes.append(mi)
	return mi

func _cone(parent: Node3D, r: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = r; cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi); meshes.append(mi)
	return mi

func _slab(parent: Node3D, size: Vector3, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi); meshes.append(mi)
	return mi

## A wing that flaps about its root (at `root`), pointing out to `side` (-1/1).
func _wing(parent: Node3D, root: Vector3, side: float, size: Vector3, m: Material) -> Node3D:
	var pivot := Node3D.new(); pivot.position = root
	parent.add_child(pivot)
	_slab(pivot, size, m, Vector3(side * size.x * 0.5, 0, 0))
	pivot.set_meta("side", side)
	_wings.append(pivot)
	return pivot

func _eyes(parent: Node3D, at: Vector3, spread: float, r: float, iris := Color(0.05, 0.05, 0.08)) -> void:
	var white := _mat(Color(1, 1, 1), 0.3)
	var dark := _mat(iris, 0.2)
	for sx in [-1.0, 1.0]:
		_ball(parent, r, white, at + Vector3(sx * spread, 0, 0))
		_ball(parent, r * 0.55, dark, at + Vector3(sx * spread, 0, -r * 0.6))

func _build(flash: Material) -> void:
	_bob = Node3D.new(); add_child(_bob)
	match kind:
		"bird":
			# a round yellow-and-blue thunder bird with a lightning crest
			var gold := _mat(Color(1.0, 0.82, 0.25), 0.5)
			var blue := _mat(Color(0.25, 0.45, 0.95), 0.5)
			_ball(_bob, 0.55, gold, Vector3(0, 1.0, 0), Vector3(1.0, 0.9, 1.25))
			_ball(_bob, 0.38, gold, Vector3(0, 1.45, -0.45))
			_cone(_bob, 0.13, 0.4, _mat(Color(1.0, 0.55, 0.1)), Vector3(0, 1.4, -0.9), Vector3(-PI * 0.5, 0, 0))
			_eyes(_bob, Vector3(0, 1.55, -0.72), 0.16, 0.1)
			for k in 3:
				_cone(_bob, 0.08, 0.4, _mat(Color(1.0, 0.95, 0.3), 0.3, 1.5), Vector3((k - 1) * 0.12, 1.9, -0.35 + k * 0.08), Vector3(0.3, 0, (k - 1) * 0.3))
			for k in 3:
				_slab(_bob, Vector3(0.12, 0.04, 0.6), blue, Vector3((k - 1) * 0.14, 1.05, 0.85), Vector3(0.3, (k - 1) * 0.3, 0))
			for sd in [-1.0, 1.0]:
				_wing(_bob, Vector3(sd * 0.45, 1.15, 0), sd, Vector3(1.3, 0.06, 0.7), blue)
			flap_speed = 10.0
		"sprite":
			# a grumpy little storm cloud with sparks
			var cloud := _mat(Color(0.35, 0.38, 0.5), 0.9)
			for p in [Vector3(0, 1.2, 0), Vector3(-0.45, 1.05, 0.05), Vector3(0.45, 1.05, 0.05), Vector3(0, 1.45, 0.1), Vector3(0.25, 1.35, -0.2), Vector3(-0.25, 1.3, -0.2)]:
				_ball(_bob, 0.42, cloud, p)
			_eyes(_bob, Vector3(0, 1.25, -0.48), 0.17, 0.11, Color(0.9, 0.85, 0.1))
			_slab(_bob, Vector3(0.36, 0.05, 0.05), _mat(Color(0.05, 0.05, 0.05)), Vector3(0, 1.05, -0.5), Vector3(0, 0, 0.1))
			for k in 3:
				_cone(_bob, 0.05, 0.45, _mat(Color(1.0, 0.95, 0.3), 0.3, 3.0), Vector3(-0.3 + k * 0.3, 0.55, 0), Vector3(PI, 0, 0.25 * (k - 1)))
			wing_amp = 0.0
		"bat":
			var fur := _mat(Color(0.28, 0.22, 0.35), 0.8)
			var mem := _see(Color(0.45, 0.3, 0.55), 0.85, 0.2)
			_ball(_bob, 0.4, fur, Vector3(0, 1.1, 0), Vector3(1, 1.1, 1))
			for sx in [-1.0, 1.0]:
				_cone(_bob, 0.12, 0.35, fur, Vector3(sx * 0.2, 1.6, 0), Vector3(0, 0, -sx * 0.3))
			_eyes(_bob, Vector3(0, 1.2, -0.33), 0.13, 0.08, Color(0.9, 0.2, 0.2))
			for sd in [-1.0, 1.0]:
				_wing(_bob, Vector3(sd * 0.3, 1.15, 0), sd, Vector3(1.2, 0.04, 0.8), mem)
			flap_speed = 14.0
		"mimic":
			# looks just like a bubble... until it opens its mouth
			_ball(_bob, 0.9, _see(Color(0.75, 0.9, 1.0), 0.35, 0.4), Vector3(0, 1.0, 0))
			var tooth := _mat(Color(1, 1, 1), 0.3)
			for k in 7:
				var a := -0.9 + k * 0.3
				_cone(_bob, 0.08, 0.22, tooth, Vector3(sin(a) * 0.75, 1.1, -cos(a) * 0.75), Vector3(PI, 0, 0))
				_cone(_bob, 0.08, 0.22, tooth, Vector3(sin(a) * 0.75, 0.82, -cos(a) * 0.75))
			_eyes(_bob, Vector3(0, 1.45, -0.7), 0.25, 0.14, Color(0.6, 0.1, 0.6))
			wing_amp = 0.0
		"golem":
			# THE HAIL GOLEM: a giant living hailstone. A frosty white core inside
			# a clear icy shell (real hail grows in layers like an onion), knobbly
			# lumps and ice crystals sticking out all over, an angry frozen face,
			# two floating hailstone fists and a swirl of little hailstones. He
			# rolls when he moves.
			var core := _mat(Color(0.86, 0.94, 1.0), 0.35, 0.2)
			var shell := _see(Color(0.4, 0.72, 1.0), 0.38, 0.5)
			var crystal := _mat(Color(0.35, 0.8, 1.0), 0.15, 1.3)
			crystal.metallic = 0.3
			var frost := _mat(Color(0.8, 0.9, 1.0), 0.6, 0.2)
			_roll = Node3D.new(); _roll.position = Vector3(0, 1.1, 0); _bob.add_child(_roll)
			_ball(_roll, 1.0, core, Vector3.ZERO)
			# rings of growth showing through the clear outer layer
			_ball(_roll, 1.16, shell, Vector3.ZERO)
			for k in 3:
				var band := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 1.03; tm.outer_radius = 1.09
				band.mesh = tm; band.material_override = frost; band.rotation = Vector3(k * 1.1, k * 0.7, k * 0.4)
				_roll.add_child(band); meshes.append(band)
			# knobbly lumps all over (seeded, so he looks the same every time)
			var rng := RandomNumberGenerator.new(); rng.seed = 41
			for k in 16:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
				if dir.z < -0.55 and absf(dir.y) < 0.6:
					continue          # (keep his face clear)
				_ball(_roll, rng.randf_range(0.2, 0.36), core, dir * 1.02)
			# ice crystals poking out
			for k in 12:
				var dir2 := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
				if dir2.z < -0.5 and absf(dir2.y) < 0.6:
					continue
				var cr := _cone(_roll, 0.13, rng.randf_range(0.5, 0.9), crystal, dir2 * 1.15)
				cr.basis = Basis(Quaternion(Vector3.UP, dir2)) * Basis.from_scale(Vector3.ONE)
				cr.position = dir2 * (1.15 + 0.2)
			# the face stays at the front while the body rolls
			var face := Node3D.new(); face.position = Vector3(0, 1.2, -1.0); _bob.add_child(face)
			var glow := _mat(Color(0.35, 0.75, 1.0), 0.2, 4.0)
			for sx in [-1.0, 1.0]:
				var eye := _ball(face, 0.17, glow, Vector3(sx * 0.33, 0.12, 0.0))
				eye.scale = Vector3(1.0, 0.7, 0.5)
				_ball(face, 0.07, _mat(Color(1, 1, 1), 0.2, 2.0), Vector3(sx * 0.3, 0.16, -0.06))
				# frozen angry brows
				_slab(face, Vector3(0.42, 0.11, 0.12), crystal, Vector3(sx * 0.32, 0.36, 0.0), Vector3(0, 0, sx * 0.45))
			# a jagged frown full of icicle teeth
			_slab(face, Vector3(0.8, 0.2, 0.08), _mat(Color(0.08, 0.15, 0.3), 0.3), Vector3(0, -0.32, 0.02))
			for k in 5:
				_cone(face, 0.06, 0.18, _mat(Color(0.95, 0.98, 1.0), 0.2, 0.6), Vector3(-0.3 + k * 0.15, -0.26, -0.02), Vector3(PI, 0, 0))
			# floating hailstone fists
			for sx in [-1.0, 1.0]:
				var fist := Node3D.new(); fist.position = Vector3(sx * 1.55, 1.05, -0.3); _bob.add_child(fist)
				fist.set_meta("side", sx)
				_fists.append(fist)
				_ball(fist, 0.42, core, Vector3.ZERO)
				_ball(fist, 0.48, shell, Vector3.ZERO)
				for k in 4:
					var d3 := Vector3(cos(k * 1.6), sin(k * 2.3), sin(k * 1.6)).normalized()
					var fc := _cone(fist, 0.07, 0.35, crystal, d3 * 0.55)
					fc.basis = Basis(Quaternion(Vector3.UP, d3))
			# a swirl of little hailstones
			_orbit = Node3D.new(); _bob.add_child(_orbit); _orbit.position.y = 1.1
			for k in 9:
				var a := k * TAU / 9.0
				var hs := _ball(_orbit, rng.randf_range(0.1, 0.18), core, Vector3(cos(a) * 1.9, sin(a * 3.0) * 0.4, sin(a) * 1.9))
				hs.set_meta("base", hs.position)
			# frosty snow drifting off him
			var snow := CPUParticles3D.new(); snow.amount = 40; snow.lifetime = 2.2
			snow.mesh = FX.quad(0.1); snow.material_override = FX.glow_material(Color(0.9, 0.97, 1.0), 1.0)
			snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; snow.emission_sphere_radius = 1.4
			snow.direction = Vector3.DOWN; snow.spread = 60; snow.gravity = Vector3(0, -1.0, 0)
			snow.initial_velocity_min = 0.2; snow.initial_velocity_max = 0.6
			snow.position.y = 1.3
			_bob.add_child(snow)
			var l := OmniLight3D.new(); l.light_color = Color(0.6, 0.85, 1.0); l.light_energy = 1.2; l.omni_range = 7.0
			l.position.y = 1.4; _bob.add_child(l)
			wing_amp = 0.0
		"bear":
			# MR. BUBBLES: a big fluffy bear made of storm cloud, with glowing eyes, a
			# lightning bolt on his tummy, storm-cloud wings, a crackling crown, a
			# bubble wand in his paw and rainbow bubbles circling him.
			var fur := ShaderMaterial.new(); fur.shader = load("res://shaders/cloud.gdshader")
			fur.set_shader_parameter("tint", Color(0.78, 0.84, 1.0)); fur.set_shader_parameter("shade", Color(0.38, 0.42, 0.62))
			fur.set_shader_parameter("rim_glow", 0.35); fur.set_shader_parameter("wobble", 0.04)
			var mane := fur.duplicate() as ShaderMaterial
			mane.set_shader_parameter("tint", Color(0.5, 0.54, 0.7)); mane.set_shader_parameter("shade", Color(0.22, 0.24, 0.36))
			var cream := _mat(Color(0.95, 0.9, 0.8), 0.9)
			var dark := _mat(Color(0.08, 0.07, 0.1), 0.3)
			var bolt := _mat(Color(1.0, 0.9, 0.25), 0.2, 3.5)
			var gold := _mat(Color(1.0, 0.8, 0.3), 0.25); gold.metallic = 0.8
			var film := ShaderMaterial.new(); film.shader = load("res://shaders/bubble.gdshader")
			# body: a round core wrapped in fluffy puffs
			_ball(_bob, 0.95, fur, Vector3(0, 1.25, 0), Vector3(1.0, 1.0, 0.95))
			for k in 12:
				var a := k * TAU / 12.0
				_ball(_bob, randf_range(0.36, 0.48), fur, Vector3(cos(a) * 0.82, 1.25 + sin(k * 1.7) * 0.45, sin(a) * 0.7 + 0.08))
			_ball(_bob, 0.62, cream, Vector3(0, 1.15, -0.5), Vector3(1.0, 1.05, 0.5))
			# the lightning bolt on his tummy
			_slab(_bob, Vector3(0.12, 0.42, 0.05), bolt, Vector3(0.06, 1.38, -0.8), Vector3(0, 0, 0.45))
			_slab(_bob, Vector3(0.26, 0.09, 0.05), bolt, Vector3(0.0, 1.17, -0.81))
			_slab(_bob, Vector3(0.12, 0.42, 0.05), bolt, Vector3(-0.06, 0.96, -0.8), Vector3(0, 0, 0.45))
			# head with a stormy mane
			var head := Node3D.new(); head.position = Vector3(0, 2.3, -0.12); _bob.add_child(head)
			_ball(head, 0.62, fur, Vector3.ZERO)
			for k in 9:
				var a := -PI * 0.15 + k * PI * 1.3 / 8.0
				_ball(head, randf_range(0.26, 0.34), mane, Vector3(cos(a) * 0.62, 0.15 + sin(a) * 0.5, 0.18))
			for sx in [-1.0, 1.0]:
				_ball(head, 0.24, mane, Vector3(sx * 0.48, 0.55, 0.02))
				_ball(head, 0.12, cream, Vector3(sx * 0.48, 0.55, -0.12))
				# angry eyebrows
				_slab(head, Vector3(0.26, 0.06, 0.06), dark, Vector3(sx * 0.2, 0.3, -0.55), Vector3(0, 0, sx * 0.4))
			_ball(head, 0.28, cream, Vector3(0, -0.13, -0.5), Vector3(1.15, 0.8, 0.8))
			_ball(head, 0.1, dark, Vector3(0, -0.04, -0.74))
			_slab(head, Vector3(0.26, 0.04, 0.04), dark, Vector3(0, -0.24, -0.72))
			for sx in [-1.0, 1.0]:
				_cone(head, 0.04, 0.12, _mat(Color(1, 1, 1), 0.3), Vector3(sx * 0.08, -0.29, -0.72), Vector3(PI, 0, 0))
				# glowing yellow eyes
				var eye := _ball(head, 0.1, _mat(Color(1.0, 0.92, 0.3), 0.2, 4.0), Vector3(sx * 0.2, 0.14, -0.53))
				eye.scale = Vector3(1.0, 0.8, 0.6)
			# a crown of crackling sparks
			for k in 6:
				var a := k * TAU / 6.0
				_cone(head, 0.06, 0.32, bolt, Vector3(cos(a) * 0.32, 0.68, sin(a) * 0.32))
			# arms and legs
			for sx in [-1.0, 1.0]:
				_ball(_bob, 0.32, fur, Vector3(sx * 0.98, 1.35, -0.25), Vector3(1.0, 1.25, 1.0))
				_ball(_bob, 0.26, mane, Vector3(sx * 1.05, 0.95, -0.4))
				_ball(_bob, 0.34, fur, Vector3(sx * 0.48, 0.35, -0.05))
				_ball(_bob, 0.2, cream, Vector3(sx * 0.48, 0.22, -0.32), Vector3(1.0, 0.6, 0.6))
			# the bubble wand in his right paw
			var wand := Node3D.new(); wand.position = Vector3(1.1, 1.0, -0.6); wand.rotation = Vector3(0.3, 0, -0.35); _bob.add_child(wand)
			var stick := MeshInstance3D.new(); var scm := CylinderMesh.new(); scm.top_radius = 0.04; scm.bottom_radius = 0.04; scm.height = 0.9
			stick.mesh = scm; stick.material_override = gold; stick.position.y = 0.35; wand.add_child(stick); meshes.append(stick)
			var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.26; tm.outer_radius = 0.34
			ring.mesh = tm; ring.material_override = gold; ring.position.y = 1.02; ring.rotation.x = PI * 0.5; wand.add_child(ring); meshes.append(ring)
			var disc := MeshInstance3D.new(); var dm := SphereMesh.new(); dm.radius = 0.27; dm.height = 0.06
			disc.mesh = dm; disc.material_override = film; disc.position.y = 1.02; disc.rotation.x = PI * 0.5; wand.add_child(disc)
			# storm-cloud wings with lightning edges
			for sd in [-1.0, 1.0]:
				var w := _wing(_bob, Vector3(sd * 0.65, 1.8, 0.45), sd, Vector3(1.9, 0.1, 1.0), mane)
				for k in 4:
					_ball(w, 0.36 - k * 0.04, mane, Vector3(sd * (0.35 + k * 0.45), 0.08, 0.1))
				_slab(w, Vector3(1.7, 0.05, 0.08), bolt, Vector3(sd * 0.95, -0.05, -0.5))
			# a fluffy tail
			_ball(_bob, 0.3, fur, Vector3(0, 0.75, 0.85))
			# rainbow bubbles circling him
			_orbit = Node3D.new(); _bob.add_child(_orbit); _orbit.position.y = 1.4
			for k in 7:
				var bb := MeshInstance3D.new(); var bsm := SphereMesh.new(); bsm.radius = randf_range(0.16, 0.3); bsm.height = bsm.radius * 2.0
				bsm.radial_segments = 16; bsm.rings = 8
				bb.mesh = bsm; bb.material_override = film
				var a := k * TAU / 7.0
				bb.position = Vector3(cos(a) * 1.75, sin(a * 2.0) * 0.5, sin(a) * 1.75)
				_orbit.add_child(bb)
			flap_speed = 4.0
			wing_amp = 0.45
		"whale":
			# the baby sky whale (a friend, not a foe)
			var blue := _mat(Color(0.45, 0.65, 0.95), 0.5)
			var pale := _mat(Color(0.85, 0.92, 1.0), 0.5)
			_ball(_bob, 1.2, blue, Vector3(0, 1.5, 0), Vector3(1.0, 0.85, 1.7))
			_ball(_bob, 0.9, pale, Vector3(0, 1.1, -0.3), Vector3(1.0, 0.6, 1.5))
			_eyes(_bob, Vector3(0, 1.75, -1.55), 0.55, 0.13)
			for sd in [-1.0, 1.0]:
				_wing(_bob, Vector3(sd * 1.0, 1.2, -0.3), sd, Vector3(0.9, 0.08, 0.45), blue)
			_slab(_bob, Vector3(1.4, 0.1, 0.5), blue, Vector3(0, 1.6, 2.1), Vector3(0.2, 0, 0))
			flap_speed = 2.5
			wing_amp = 0.35
	for m in meshes:
		m.material_overlay = flash

func _process(delta: float) -> void:
	_t += delta
	_bob.position.y = sin(_t * 2.2) * 0.08
	for w in _wings:
		var sd: float = w.get_meta("side")
		w.rotation.z = sd * sin(_t * flap_speed) * wing_amp
	if kind == "mimic":
		_bob.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.04)
	if _roll:
		# roll along the ground the way he's going (in his own frame)
		var gp := global_position
		var mv := gp - _last_pos
		_last_pos = gp
		if mv.length() < 2.0:
			var local := global_transform.basis.inverse() * mv
			_roll.rotate_x(-local.z / maxf(1.2 * global_transform.basis.get_scale().x, 0.1))
			_roll.rotate_z(local.x / maxf(1.2 * global_transform.basis.get_scale().x, 0.1))
		_roll.rotate_y(delta * 0.3)
		for f in _fists:
			var sd: float = f.get_meta("side")
			f.position.y = 1.05 + sin(_t * 2.6 + sd) * 0.18
			f.rotation.y += delta * 1.5
	if _orbit:
		_orbit.rotation.y = _t * 0.9
		for i in _orbit.get_child_count():
			var bb := _orbit.get_child(i) as Node3D
			bb.position.y = sin(_t * 1.6 + i * 1.3) * 0.5
