extends Node3D
class_name ClimbOut
## A rope ladder back up to the forest from the Warren.

var dest := Vector3.ZERO

static func make(parent: Node, pos: Vector3, to: Vector3) -> ClimbOut:
	var c := ClimbOut.new()
	c.dest = to
	parent.add_child(c)
	c.global_position = pos
	c.add_to_group("interactable")
	var rope := StandardMaterial3D.new(); rope.albedo_color = Color(0.55, 0.42, 0.25)
	for sx in [-0.45, 0.45]:
		var r := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 0.05; cm.height = 7.0
		r.mesh = cm; r.material_override = rope; r.position = Vector3(sx, 3.5, 0); c.add_child(r)
	for k in 12:
		var rung := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.08, 0.12)
		rung.mesh = bm; rung.material_override = rope; rung.position = Vector3(0, 0.4 + k * 0.55, 0); c.add_child(rung)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.95, 0.8); l.light_energy = 1.2; l.omni_range = 5.0
	l.position = Vector3(0, 6.5, 0); c.add_child(l)
	return c

func get_prompt() -> String:
	return "Climb back up to the forest"

func interact(_by: Node) -> void:
	var sc := get_tree().current_scene
	if sc.has_method("teleport_player"):
		sc.teleport_player(dest, PI, "the Goblin Forest")
