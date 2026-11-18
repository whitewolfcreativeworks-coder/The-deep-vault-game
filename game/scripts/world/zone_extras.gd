extends Node
class_name ZoneExtras
## Little extras sprinkled over every zone once it's built:
##  - a few Energy Potions lying about in random spots (near chests, shrines,
##    signs and people, so they're always somewhere you can walk to), and
##  - wandering chickens and turkeys in the open-air areas, topped back up
##    every so often.
## It waits a few physics frames first so the level's collision is in place.

var world: Node3D
var potions := 4
var fowl_areas: Array = []      # [[centre: Vector3, radius: float, count: int], ...]
var _frames := 0
var _done := false
var _respawn_t := 60.0
var _fowl: Array[Fowl] = []
var _rng := RandomNumberGenerator.new()

static func attach(w: Node3D, n_potions: int, areas: Array) -> ZoneExtras:
	var z := ZoneExtras.new()
	z.name = "ZoneExtras"
	z.world = w
	z.potions = n_potions
	z.fowl_areas = areas
	w.add_child(z)
	return z

func _ready() -> void:
	_rng.randomize()

func _physics_process(delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return
	if not _done:
		_done = true
		_scatter_potions()
		_top_up_fowl()
		return
	_respawn_t -= delta
	if _respawn_t <= 0.0:
		_respawn_t = 60.0
		_top_up_fowl()

func _floor_at(p: Vector3, up := 2.5, down := 6.0) -> Variant:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, up, 0), p - Vector3(0, down, 0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var at: Vector3 = hit.position
	if (hit.normal as Vector3).y < 0.7:
		return null          # too steep
	# room to stand (nothing solid right there)
	var sq := PhysicsShapeQueryParameters3D.new()
	var sp := SphereShape3D.new(); sp.radius = 0.35
	sq.shape = sp; sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0)); sq.collision_mask = 1
	if not space.intersect_shape(sq, 1).is_empty():
		return null
	return at

func _scatter_potions() -> void:
	var anchors: Array = []
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Node3D and world.is_ancestor_of(n):
			anchors.append(n)
	if anchors.is_empty() or potions <= 0:
		return
	# shuffle, then place one potion near each of the first few anchors
	for i in range(anchors.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = anchors[i]; anchors[i] = anchors[j]; anchors[j] = tmp
	var placed := 0
	var used: Array[Vector3] = []
	for a in anchors:
		if placed >= potions:
			break
		var base: Vector3 = (a as Node3D).global_position
		if used.any(func(u: Vector3) -> bool: return u.distance_to(base) < 12.0):
			continue
		for attempt in 8:
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(1.6, 3.4)
			var at = _floor_at(base + Vector3(cos(ang) * r, 0, sin(ang) * r))
			if at == null or absf((at as Vector3).y - base.y) > 1.5:
				continue
			Pickup.place(world, (at as Vector3) + Vector3(0, 0.45, 0), "stamina")
			used.append(base)
			placed += 1
			break

func _top_up_fowl() -> void:
	_fowl = _fowl.filter(func(f: Fowl) -> bool: return is_instance_valid(f) and not f.dead)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for area in fowl_areas:
		var c: Vector3 = area[0]
		var r: float = area[1]
		var want: int = area[2]
		var have := _fowl.filter(func(f: Fowl) -> bool: return f.home.distance_to(c) < r + 1.0).size()
		for k in want - have:
			for attempt in 8:
				var ang := _rng.randf() * TAU
				var d := sqrt(_rng.randf()) * r
				var p := c + Vector3(cos(ang) * d, 0, sin(ang) * d)
				if player and _done and _frames > 10 and player.global_position.distance_to(p) < 10.0:
					continue      # don't pop into existence right in front of you
				var at = _floor_at(p, 6.0, 14.0)
				if at == null:
					continue
				var f := Fowl.make(world, (at as Vector3) + Vector3(0, 0.2, 0), "turkey" if _rng.randf() < 0.35 else "chicken", minf(r, 7.0))
				_fowl.append(f)
				break
