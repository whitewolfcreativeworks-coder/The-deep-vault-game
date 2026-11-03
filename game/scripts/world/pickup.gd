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
		"potion", "mana":
			col = Color(1.0, 0.25, 0.3) if kind == "potion" else Color(0.3, 0.5, 1.0)
			var b: Node3D = Props.make("bottle_A_labeled_brown")
			_vis.add_child(b)
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				var m := StandardMaterial3D.new()
				m.albedo_color = col.darkened(0.1); m.emission_enabled = true
				m.emission = col; m.emission_energy_multiplier = 1.6
				m.roughness = 0.2
				(mi as MeshInstance3D).material_override = m
		_:
			var it := Game.item(item_id)
			var r: int = it.get("rarity", 0)
			col = Loot.rarity_color(r)
			_vis.add_child(_item_model(it, col))
			if r >= 2:
				_add_beam(col, r)
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
		"mana":
			Game.mana_potions += amount
			Game.say("+1 Mana Potion", Color(0.45, 0.6, 1.0))
			Sfx.play("pickup", -6.0, 0.0)
			Game.stats_changed.emit()
		_:
			var r: int = Game.item(item_id).get("rarity", 0)
			Game.add_item(item_id)
			Sfx.play("levelup" if r >= 3 else "pickup", -4.0 if r >= 3 else -3.0, 0.0)
	FX.burst(global_position, Color(1, 0.85, 0.4), 12, 2.0, 0.12, 0.5, 0.0)
	queue_free()

## The thing lying on the floor: the real weapon / shield, a gem or a mask.
func _item_model(it: Dictionary, col: Color) -> Node3D:
	var n := Node3D.new()
	var path := ""
	var slot: String = it.get("slot", "")
	if slot == "weapon":
		var key: String = it.get("model", "skel_blade")
		path = CharacterModel.WEAPON_SCENES.get(key, "")
	elif slot == "armor":
		path = "res://assets/kaykit/items/%s.gltf" % it.get("shield", "shield_round")
	if path != "" and ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		m.rotation_degrees = Vector3(0, 0, 25) if slot == "weapon" else Vector3(0, 0, 0)
		m.position.y = -0.35 if slot == "weapon" else -0.1
		m.scale = Vector3.ONE * (0.9 if slot == "weapon" else 1.0)
		n.add_child(m)
		return n
	var mi := MeshInstance3D.new()
	if slot == "skin":
		var sm := SphereMesh.new(); sm.radius = 0.2; sm.height = 0.4
		mi.mesh = sm
	else:
		var pm := PrismMesh.new(); pm.size = Vector3(0.24, 0.36, 0.24)
		mi.mesh = pm
	var m2 := StandardMaterial3D.new(); m2.albedo_color = col; m2.emission_enabled = true
	m2.emission = col; m2.emission_energy_multiplier = 2.5; m2.metallic = 0.5; m2.roughness = 0.2
	mi.material_override = m2
	n.add_child(mi)
	return n

## A column of light so good loot can be spotted across the room.
func _add_beam(col: Color, r: int) -> void:
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02; cm.bottom_radius = 0.16 + 0.04 * r; cm.height = 4.0 + r
	cm.radial_segments = 12
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(col.r, col.g, col.b, 0.35)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = cm.height * 0.5 - 0.3
	add_child(beam)
	var sp := CPUParticles3D.new()
	sp.amount = 10 + r * 4; sp.lifetime = 1.2
	sp.mesh = FX.quad(0.08)
	sp.material_override = FX.glow_material(col, 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.3
	sp.direction = Vector3.UP; sp.spread = 20
	sp.initial_velocity_min = 0.5; sp.initial_velocity_max = 1.5
	sp.gravity = Vector3.ZERO
	sp.color_ramp = FX._fade_ramp(col)
	add_child(sp)
