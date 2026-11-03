extends Area3D
class_name Pickup
## Floating loot: gold, healing draughts, items. Drifts to the player when near.

var kind := "gold"
var amount := 1
var item_id := ""
var _t := 0.0
var _vis: Node3D
var _base_y := 0.0
var _vel := Vector3.ZERO
var _settled := false
var _collected := false

static func spawn(pos: Vector3, k: String, amt := 1, id := "") -> Pickup:
	var p := Pickup.new()
	p.kind = k; p.amount = amt; p.item_id = id
	var root := FX.scene_root()
	root.add_child(p)
	p.global_position = pos
	p._vel = Vector3(randf_range(-1.5, 1.5), 4.0, randf_range(-1.5, 1.5))
	return p

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new(); s.radius = 0.6
	cs.shape = s
	add_child(cs)
	_vis = Node3D.new()
	add_child(_vis)
	var col := Color(1.0, 0.8, 0.3)
	match kind:
		"gold":
			var c: Node3D = Props.make("coin_stack_small")
			_vis.add_child(c)
			c.scale = Vector3.ONE * 0.9
		"potion":
			col = Color(1.0, 0.25, 0.3)
			var b: Node3D = Props.make("bottle_A_labeled_brown")
			_vis.add_child(b)
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.9, 0.15, 0.2); m.emission_enabled = true
				m.emission = Color(1, 0.1, 0.15); m.emission_energy_multiplier = 1.5
				m.roughness = 0.2
				(mi as MeshInstance3D).material_override = m
		_:
			col = Game.ITEMS.get(item_id, {}).get("color", Color(0.6, 0.9, 1.0))
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new(); pm.size = Vector3(0.3, 0.45, 0.3)
			mi.mesh = pm
			var m2 := StandardMaterial3D.new(); m2.albedo_color = col; m2.emission_enabled = true; m2.emission = col; m2.emission_energy_multiplier = 3.0
			mi.material_override = m2
			_vis.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = col; l.light_energy = 0.8; l.omni_range = 2.2
	_vis.add_child(l)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	_t += delta
	if not _settled:
		_vel.y -= 14.0 * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -0.45, 0) + _vel * delta, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and _vel.y < 0:
			global_position = hit.position + Vector3(0, 0.45, 0)
			_settled = true
			_base_y = global_position.y
		else:
			global_position += _vel * delta
		if _t > 3.0:
			_settled = true; _base_y = global_position.y
	else:
		_vis.position.y = sin(_t * 2.5) * 0.08
	_vis.rotation.y += delta * 1.8
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and _t > 0.5 and p.get("dead") != true:
		var to := (p.global_position + Vector3(0, 0.9, 0)) - global_position
		if to.length() < 2.6:
			global_position += to.normalized() * minf(to.length(), (9.0 / maxf(to.length(), 0.4)) * delta)
			_settled = true
		if to.length() < 0.7:
			_collect()

func _on_body(b: Node) -> void:
	if b.is_in_group("player") and _t > 0.5:
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	match kind:
		"gold":
			Game.add_gold(amount)
			Sfx.play("coins", -6.0)
		"potion":
			Game.potions += amount
			Game.say("+1 Healing Draught", Color(1, 0.45, 0.45))
			Sfx.play("pickup", -6.0)
			Game.stats_changed.emit()
		_:
			Game.add_item(item_id)
			Sfx.play("pickup", -3.0)
	FX.burst(global_position, Color(1, 0.85, 0.4), 12, 2.0, 0.12, 0.5, 0.0)
	queue_free()
