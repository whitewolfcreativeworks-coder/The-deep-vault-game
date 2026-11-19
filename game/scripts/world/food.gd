extends Node3D
class_name Food
## Food you can eat (USE) wherever it's laid out: on the tables in every dungeon,
## and on top of some barrels and crates. Each kind gives a little something:
## health, energy, mana, or a short buff (strong, tough, quick, well fed).
## Eaten food comes back after a few minutes.

const KINDS := {
	"bread": {"name": "a loaf of bread", "tag": "Well fed: your energy comes back faster", "buff": "fed", "secs": 60.0, "stamina": 1.0},
	"cheese": {"name": "a wedge of cheese", "tag": "+25% health", "heal": 0.25},
	"apple": {"name": "a crunchy apple", "tag": "Quick: you run faster", "heal": 0.1, "buff": "quick", "secs": 40.0},
	"drumstick": {"name": "a roast chicken leg", "tag": "Strong: you hit 25% harder", "heal": 0.1, "buff": "strong", "secs": 45.0},
	"pie": {"name": "a berry pie", "tag": "Tough: you take less damage", "heal": 0.1, "buff": "tough", "secs": 45.0},
	"cider": {"name": "a mug of apple cider", "tag": "Mana refilled", "mana": 1.0, "drink": true},
	"bun": {"name": "a sticky bun", "tag": "Energy refilled", "stamina": 1.0, "heal": 0.05},
}
const RESPAWN := 300.0

var kind := "bread"
var eaten := false
var _vis: Node3D
var _t := 0.0
var _back := 0.0
var _spark: CPUParticles3D

static func make(parent: Node, at: Vector3, k: String, yaw := 0.0) -> Food:
	var f := Food.new()
	f.kind = k
	parent.add_child(f)
	f.global_position = at
	f.rotation.y = yaw
	return f

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("food")
	_vis = Node3D.new(); add_child(_vis)
	match kind:
		"bread": _bread()
		"cheese": _cheese()
		"apple": _apple()
		"drumstick": _drumstick()
		"pie": _pie()
		"cider": _cider()
		_: _bun()
	# a faint twinkle so you notice there's something to eat
	_spark = CPUParticles3D.new(); _spark.amount = 3; _spark.lifetime = 1.4
	_spark.mesh = FX.quad(0.05); _spark.material_override = FX.glow_material(Color(1.0, 0.92, 0.6), 1.6)
	_spark.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _spark.emission_sphere_radius = 0.15
	_spark.direction = Vector3.UP; _spark.spread = 20; _spark.gravity = Vector3(0, 0.25, 0)
	_spark.initial_velocity_min = 0.05; _spark.initial_velocity_max = 0.15
	_spark.color_ramp = FX._fade_ramp(Color(1.0, 0.92, 0.6))
	_spark.position.y = 0.15; add_child(_spark)

func can_interact() -> bool:
	return not eaten

func get_prompt() -> String:
	var k: Dictionary = KINDS.get(kind, KINDS.bread)
	return "[E] %s %s (%s)" % ["Drink" if k.get("drink", false) else "Eat", k.name, k.tag]

func interact(by: Node) -> void:
	if eaten:
		return
	var k: Dictionary = KINDS.get(kind, KINDS.bread)
	eaten = true
	_back = RESPAWN
	_vis.visible = false
	_spark.emitting = false
	if k.has("heal") and by and by.has_method("heal"):
		by.heal(Game.max_hp() * float(k.heal))
	if k.has("stamina"):
		Game.stamina = minf(Game.max_stamina(), Game.stamina + Game.max_stamina() * float(k.stamina))
	if k.has("mana"):
		Game.mana = minf(Game.max_mana(), Game.mana + Game.max_mana() * float(k.mana))
	if k.has("buff"):
		Game.add_buff(String(k.buff), float(k.secs))
	if k.get("drink", false):
		Sfx.play("sip", -3.0, 0.1)
	else:
		Sfx.play("pickup", -6.0, 0.25)
		Sfx.play("brush", -14.0, 0.3)      # a crunchy munch
	FX.burst(global_position + Vector3(0, 0.15, 0), Color(0.95, 0.8, 0.5), 16, 1.5, 0.05, 0.5, -3.0)
	if by is Node3D:
		FX.burst((by as Node3D).global_position + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 18, 2.0, 0.1, 0.8, 1.0)
	Game.say("Yum! %s. %s!" % [String(k.name).capitalize(), k.tag], Color(1.0, 0.85, 0.5))

func _process(delta: float) -> void:
	_t += delta
	if eaten:
		_back -= delta
		if _back <= 0.0:
			eaten = false
			_vis.visible = true
			_spark.emitting = true
		return

# --- the food itself (small cartoon models made from shapes) --------------------
func _m(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough
	return m

func _ball(r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 14; sm.rings = 7
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	_vis.add_child(mi)
	return mi

func _cyl(r0: float, r1: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r0; cm.bottom_radius = r1; cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	_vis.add_child(mi)
	return mi

func _plate() -> void:
	_cyl(0.2, 0.17, 0.025, _m(Color(0.92, 0.9, 0.85), 0.3), Vector3(0, 0.0125, 0))

func _bread() -> void:
	_plate()
	var crust := _m(Color(0.78, 0.5, 0.22), 0.7)
	_ball(0.13, crust, Vector3(0, 0.1, 0), Vector3(1.25, 0.62, 0.8))
	var cut := _m(Color(0.95, 0.85, 0.6), 0.8)
	for k in 3:
		var sl := _ball(0.025, cut, Vector3(-0.08 + k * 0.08, 0.17, 0), Vector3(0.6, 0.25, 2.2))
		sl.rotation.y = 0.5

func _cheese() -> void:
	_plate()
	var mi := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.22, 0.12, 0.16); pm.left_to_right = 0.0
	mi.mesh = pm; mi.material_override = _m(Color(1.0, 0.82, 0.25), 0.5); mi.position = Vector3(0, 0.085, 0)
	mi.rotation = Vector3(PI / 2, 0, 0)
	_vis.add_child(mi)
	var hole := _m(Color(0.85, 0.65, 0.15), 0.6)
	for p in [Vector3(-0.04, 0.07, 0.081), Vector3(0.03, 0.11, 0.081), Vector3(-0.07, 0.12, 0.081)]:
		_ball(0.014, hole, p, Vector3(1, 1, 0.3))

func _apple() -> void:
	var red := _m(Color(0.85, 0.12, 0.1), 0.35)
	_ball(0.075, red, Vector3(0, 0.07, 0), Vector3(1, 0.92, 1))
	_cyl(0.006, 0.008, 0.05, _m(Color(0.35, 0.22, 0.1)), Vector3(0, 0.155, 0), Vector3(0, 0, 0.2))
	var leaf := _ball(0.025, _m(Color(0.3, 0.7, 0.25)), Vector3(0.025, 0.16, 0), Vector3(1.4, 0.3, 0.7))
	leaf.rotation.z = -0.4
	_ball(0.06, _m(Color(0.95, 0.75, 0.15), 0.35), Vector3(0.13, 0.06, 0.05), Vector3(1, 0.95, 1))   # and a golden one

func _drumstick() -> void:
	_plate()
	var meat := _m(Color(0.62, 0.32, 0.12), 0.55)
	var bone := _m(Color(0.96, 0.93, 0.85), 0.5)
	for side in [-1.0, 1.0]:
		var root := Node3D.new(); _vis.add_child(root); root.position = Vector3(side * 0.06, 0.06, side * 0.02); root.rotation.y = side * 0.5
		var m1 := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12
		m1.mesh = sm; m1.material_override = meat; m1.scale = Vector3(1.6, 0.85, 1.0); root.add_child(m1)
		var b1 := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = 0.09
		b1.mesh = cm; b1.material_override = bone; b1.position = Vector3(0.12, 0.0, 0); b1.rotation.z = PI / 2; root.add_child(b1)
		for dz in [-0.012, 0.012]:
			var k1 := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.016; ks.height = 0.032
			k1.mesh = ks; k1.material_override = bone; k1.position = Vector3(0.165, 0.0, dz); root.add_child(k1)

func _pie() -> void:
	var crust := _m(Color(0.86, 0.6, 0.3), 0.7)
	_cyl(0.16, 0.13, 0.07, crust, Vector3(0, 0.035, 0))
	_cyl(0.145, 0.145, 0.012, _m(Color(0.55, 0.1, 0.35), 0.3), Vector3(0, 0.068, 0))
	for k in 4:
		var strip := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.28, 0.012, 0.025)
		strip.mesh = bm; strip.material_override = crust; strip.position = Vector3(0, 0.074 + k * 0.003, 0); strip.rotation.y = k * PI / 4
		_vis.add_child(strip)
	var slice := _ball(0.02, _m(Color(0.95, 0.95, 1.0), 0.4), Vector3(0, 0.085, 0), Vector3(1.2, 0.5, 1.2))   # a dollop of cream
	slice.name = "Cream"

func _cider() -> void:
	var wood := _m(Color(0.55, 0.36, 0.18), 0.7)
	_cyl(0.06, 0.055, 0.15, wood, Vector3(0, 0.075, 0))
	for y in [0.03, 0.12]:
		_cyl(0.063, 0.063, 0.012, _m(Color(0.35, 0.35, 0.38), 0.4), Vector3(0, y, 0))
	_cyl(0.056, 0.056, 0.01, _m(Color(0.95, 0.75, 0.3), 0.2), Vector3(0, 0.148, 0))
	_ball(0.04, _m(Color(1.0, 0.98, 0.9), 0.8), Vector3(0, 0.155, 0), Vector3(1.4, 0.45, 1.4))
	var handle := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.025; tm.outer_radius = 0.04
	handle.mesh = tm; handle.material_override = wood; handle.position = Vector3(0.07, 0.08, 0); handle.rotation.x = PI / 2
	_vis.add_child(handle)

func _bun() -> void:
	_plate()
	var dough := _m(Color(0.86, 0.6, 0.3), 0.6)
	_ball(0.075, dough, Vector3(0, 0.06, 0), Vector3(1, 0.65, 1))
	_ball(0.06, _m(Color(0.98, 0.95, 0.9), 0.5), Vector3(0, 0.09, 0), Vector3(1.0, 0.25, 1.0))   # icing
	_ball(0.012, _m(Color(0.9, 0.15, 0.2), 0.3), Vector3(0, 0.11, 0))                          # a cherry


# --- laying food out ------------------------------------------------------------
static var _tm_cache := {}

## The highest point of `prop`'s meshes straight below `at` (world), or NAN.
static func _top_at(prop: Node3D, at: Vector3) -> float:
	var best := NAN
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		if not _tm_cache.has(m.mesh):
			_tm_cache[m.mesh] = m.mesh.generate_triangle_mesh()
		var tm: TriangleMesh = _tm_cache[m.mesh]
		if tm == null:
			continue
		var inv := m.global_transform.affine_inverse()
		var hit: Dictionary = tm.intersect_ray(inv * (at + Vector3(0, 20, 0)), (inv.basis * Vector3.DOWN).normalized())
		if not hit.is_empty():
			var y: float = (m.global_transform * (hit.position as Vector3)).y
			if is_nan(best) or y > best:
				best = y
	return best

## Put up to `count` foods on the flat top of a table (or barrel, crate...).
static func spread_on(prop: Node3D, count: int, rng: RandomNumberGenerator, parent: Node) -> int:
	var ab := Props.mesh_aabb(prop)
	if ab.size == Vector3.ZERO:
		return 0
	var xf := prop.global_transform
	# sample the top: the table top is the most common height under the sample points
	var spots: Array = []
	for ix in 6:
		for iz in 6:
			var lp := Vector3(lerpf(ab.position.x, ab.end.x, 0.18 + 0.64 * ix / 5.0), 0, lerpf(ab.position.z, ab.end.z, 0.18 + 0.64 * iz / 5.0))
			var wp := xf * lp
			var y := _top_at(prop, wp)
			if not is_nan(y):
				spots.append(Vector3(wp.x, y, wp.z))
	if spots.is_empty():
		return 0
	var ys: Array = []
	for sp in spots:
		ys.append(snappedf((sp as Vector3).y, 0.03))
	var counts := {}
	for y in ys:
		counts[y] = int(counts.get(y, 0)) + 1
	var top_y: float = ys[0]
	for y in counts:
		if int(counts[y]) > int(counts[top_y]) or (int(counts[y]) == int(counts[top_y]) and float(y) > top_y):
			top_y = y
	# only tops you can reach and see: table or barrel height, not a giant prop
	var h := top_y - prop.global_position.y
	if h < 0.4 or h > 1.7:
		return 0
	var flat: Array = spots.filter(func(sp) -> bool: return absf((sp as Vector3).y - top_y) < 0.035)
	flat.shuffle()
	var placed: Array = []
	var kinds := KINDS.keys()
	for sp in flat:
		if placed.size() >= count:
			break
		var ok := true
		for q in placed:
			if Vector2((sp as Vector3).x - (q as Vector3).x, (sp as Vector3).z - (q as Vector3).z).length() < 0.42:
				ok = false
				break
		if not ok:
			continue
		placed.append(sp)
		Food.make(parent, (sp as Vector3) + Vector3(0, 0.005, 0), kinds[rng.randi() % kinds.size()], rng.randf() * TAU)
	return placed.size()

## Stock a whole world: food on every table, and a snack on some barrels and crates.
static func stock_world(world: Node3D) -> int:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(String(world.get_script().resource_path)) + 7
	var tables: Array = []
	var tops: Array = []
	for n in world.find_children("*", "Node3D", true, false):
		var path := String((n as Node).scene_file_path)
		if path == "":
			continue
		var f := path.get_file().to_lower()
		if f.begins_with("table"):
			tables.append(n)
		elif f.begins_with("barrel") or f.begins_with("crate") or f.begins_with("keg"):
			tops.append(n)
	var total := 0
	for t in tables:
		total += spread_on(t, 3, rng, world)
	# (the same barrels every time, not a different set each visit)
	for i in range(tops.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = tops[i]; tops[i] = tops[j]; tops[j] = tmp
	# nothing to eat right next to a lever, door or chest: it would steal your USE
	var busy: Array = []
	for it in world.get_tree().get_nodes_in_group("interactable"):
		if it is Node3D and not (it is Food):
			busy.append((it as Node3D).global_position)
	var used: Array = []
	for b in tops:
		if used.size() >= 8:
			break
		var bp := (b as Node3D).global_position
		var near := false
		for u in used:
			if (u as Vector3).distance_to(bp) < 12.0:
				near = true
				break
		for q in busy:
			if (q as Vector3).distance_to(bp) < 3.5:
				near = true
				break
		if near or rng.randf() > 0.5:
			continue
		var got := spread_on(b, 1, rng, world)
		if got > 0:
			used.append(bp)
			total += got
	return total
