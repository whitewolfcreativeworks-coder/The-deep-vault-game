extends Node3D
class_name Gate
## Iron portcullis that slides into the ceiling. Blocks passage while closed.

var width := 3.0
var height := 3.6
var is_open := false
var uid := ""
var _bars: Node3D
var _body: StaticBody3D

static func create(parent: Node, pos: Vector3, w: float, h: float, yaw_deg := 0.0, id := "") -> Gate:
	var g := Gate.new()
	g.width = w; g.height = h; g.uid = id
	parent.add_child(g)
	g.position = pos
	g.rotation_degrees.y = yaw_deg
	g._build()
	if id != "" and Game.flags.get(id, false):
		g.open(true)
	return g

func _build() -> void:
	_bars = Node3D.new()
	add_child(_bars)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.15); iron.metallic = 0.85; iron.roughness = 0.5
	var n := int(width / 0.28)
	for i in n + 1:
		var bar := MeshInstance3D.new()
		var c := CylinderMesh.new(); c.top_radius = 0.035; c.bottom_radius = 0.035; c.height = height
		bar.mesh = c; bar.material_override = iron
		bar.position = Vector3(-width * 0.5 + i * (width / n), height * 0.5, 0)
		_bars.add_child(bar)
		var tip := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.1, 0.16, 0.1)
		tip.mesh = pm; tip.material_override = iron; tip.rotation.z = PI
		tip.position = Vector3(bar.position.x, -0.05, 0)
		_bars.add_child(tip)
	for y in [0.4, height * 0.5, height - 0.3]:
		var cross := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(width - 0.06, 0.08, 0.08)
		cross.mesh = b; cross.material_override = iron; cross.position = Vector3(0, y, 0.02)
		_bars.add_child(cross)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(width, height, 0.3)
	cs.shape = bs; cs.position = Vector3(0, height * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)

func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	if uid != "":
		Game.flags[uid] = true
	_body.collision_layer = 0
	if instant:
		_bars.position.y = height - 0.2
		return
	Sfx.play_at("door", global_position + Vector3(0, 2, 0), 2.0, 0.0, 10.0)
	var tw := create_tween()
	tw.tween_property(_bars, "position:y", height - 0.2, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_trauma"):
		p.add_trauma(0.2)

func close(instant := false) -> void:
	if not is_open:
		return
	is_open = false
	if uid != "":
		Game.flags.erase(uid)
	_body.collision_layer = 1
	if instant:
		_bars.position.y = 0.0
		return
	Sfx.play_at("slam", global_position + Vector3(0, 2, 0), 0.0, 0.0, 10.0)
	var tw := create_tween()
	tw.tween_property(_bars, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
