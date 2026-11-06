extends Area3D
class_name Raindrop
## A raindrop floating over Cloud Island. Walk into it and you get a little
## heavier (the weight meter). It comes back after a while.

var _vis: Node3D
var _t := 0.0
var _gone := 0.0

static func make(parent: Node, pos: Vector3) -> Raindrop:
	var r := Raindrop.new()
	parent.add_child(r)
	r.global_position = pos
	return r

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 0.9
	cs.shape = sp; add_child(cs)
	_vis = Node3D.new(); add_child(_vis)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.7, 1.0, 0.75); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color(0.4, 0.65, 1.0); m.emission_energy_multiplier = 1.2; m.roughness = 0.05
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.22; sm.height = 0.44
	ball.mesh = sm; ball.material_override = m; _vis.add_child(ball)
	var tipm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.2; cm.height = 0.3
	tipm.mesh = cm; tipm.material_override = m; tipm.position.y = 0.2; _vis.add_child(tipm)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			_vis.visible = true
			set_deferred("monitoring", true)
		return
	_vis.position.y = sin(_t * 2.4) * 0.12
	_vis.rotation.y += delta * 1.5

func _on_body(b: Node) -> void:
	if not b.is_in_group("player") or _gone > 0.0:
		return
	var w = get_tree().current_scene.get("world")
	if w and w.has_method("add_rain"):
		w.add_rain(0.18)
	Sfx.play("splash", -10.0, 0.3)
	FX.burst(global_position, Color(0.5, 0.75, 1.0), 16, 2.0, 0.1, 0.4, -3.0)
	_vis.visible = false
	set_deferred("monitoring", false)
	_gone = 25.0
