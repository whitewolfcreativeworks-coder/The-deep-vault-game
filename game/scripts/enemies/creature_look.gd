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
var wing_amp := 0.6

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
			# a hulking golem of hailstones
			var ice := _mat(Color(0.8, 0.9, 1.0), 0.25, 0.15)
			var dark_ice := _mat(Color(0.55, 0.7, 0.9), 0.3)
			_ball(_bob, 0.8, ice, Vector3(0, 1.4, 0), Vector3(1.2, 1.0, 0.9))
			_ball(_bob, 0.5, ice, Vector3(0, 2.3, -0.1))
			for sx in [-1.0, 1.0]:
				_ball(_bob, 0.45, dark_ice, Vector3(sx * 1.05, 1.6, 0))
				_ball(_bob, 0.42, ice, Vector3(sx * 1.2, 0.9, -0.1))
				_ball(_bob, 0.4, dark_ice, Vector3(sx * 0.45, 0.4, 0))
			_eyes(_bob, Vector3(0, 2.35, -0.42), 0.18, 0.1, Color(0.2, 0.5, 1.0))
			for k in 6:
				_ball(_bob, 0.18, ice, Vector3(randf_range(-0.8, 0.8), randf_range(1.0, 2.0), randf_range(-0.5, 0.5)))
			wing_amp = 0.0
		"bear":
			# MR. BUBBLES: a big round fluffy bear with storm-cloud wings
			var fur := _mat(Color(0.6, 0.42, 0.28), 0.9)
			var belly := _mat(Color(0.88, 0.75, 0.6), 0.9)
			var nose := _mat(Color(0.12, 0.08, 0.06), 0.3)
			var cloud := _mat(Color(0.55, 0.58, 0.7), 0.9)
			_ball(_bob, 0.9, fur, Vector3(0, 1.2, 0), Vector3(1.0, 1.0, 0.95))
			_ball(_bob, 0.62, belly, Vector3(0, 1.1, -0.48), Vector3(1.0, 1.0, 0.5))
			_ball(_bob, 0.6, fur, Vector3(0, 2.25, -0.1))
			for sx in [-1.0, 1.0]:
				_ball(_bob, 0.22, fur, Vector3(sx * 0.45, 2.75, -0.05))
				_ball(_bob, 0.12, belly, Vector3(sx * 0.45, 2.75, -0.15))
				_ball(_bob, 0.28, fur, Vector3(sx * 0.85, 1.2, -0.3))
				_ball(_bob, 0.3, fur, Vector3(sx * 0.45, 0.35, -0.1))
			_ball(_bob, 0.25, belly, Vector3(0, 2.12, -0.6), Vector3(1.1, 0.8, 0.8))
			_ball(_bob, 0.09, nose, Vector3(0, 2.2, -0.82))
			_eyes(_bob, Vector3(0, 2.4, -0.5), 0.2, 0.1, Color(0.95, 0.85, 0.15))
			# storm-cloud wings with lightning edges
			for sd in [-1.0, 1.0]:
				var w := _wing(_bob, Vector3(sd * 0.6, 1.7, 0.4), sd, Vector3(1.8, 0.1, 1.0), cloud)
				for k in 3:
					_ball(w, 0.35, cloud, Vector3(sd * (0.4 + k * 0.5), 0.1, 0.1))
				_slab(w, Vector3(1.6, 0.05, 0.08), _mat(Color(1.0, 0.95, 0.3), 0.2, 3.0), Vector3(sd * 0.9, -0.05, -0.5))
			# a crown of crackling sparks
			for k in 5:
				var a := k * TAU / 5.0
				_cone(_bob, 0.06, 0.3, _mat(Color(1.0, 0.95, 0.3), 0.2, 3.0), Vector3(cos(a) * 0.3, 2.9, sin(a) * 0.3 - 0.1))
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
