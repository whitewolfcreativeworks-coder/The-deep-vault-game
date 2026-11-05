extends Node3D
class_name Passage
## A doorway or stair to somewhere else in the same level (the castle crypt and
## back). Walk up and press USE: fade out, arrive, fade in.

var dest := Vector3.ZERO
var dest_yaw := 0.0
var prompt := ""
var label := ""

static func make(parent: Node, pos: Vector3, to: Vector3, to_yaw: float, prompt_text: String, arrive_label: String, glow := Color(0.5, 0.8, 1.0)) -> Passage:
	var p := Passage.new()
	p.dest = to; p.dest_yaw = to_yaw; p.prompt = prompt_text; p.label = arrive_label
	parent.add_child(p)
	p.global_position = pos
	p.add_to_group("interactable")
	var l := OmniLight3D.new(); l.light_color = glow; l.light_energy = 1.6; l.omni_range = 6.0
	l.position = Vector3(0, 2.0, 0); p.add_child(l)
	var sp := CPUParticles3D.new(); sp.amount = 20; sp.lifetime = 1.6
	sp.mesh = FX.quad(0.08); sp.material_override = FX.glow_material(glow, 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sp.emission_box_extents = Vector3(1.0, 0.2, 0.6)
	sp.direction = Vector3.UP; sp.spread = 15; sp.initial_velocity_min = 0.4; sp.initial_velocity_max = 1.0
	sp.gravity = Vector3.ZERO; sp.color_ramp = FX._fade_ramp(glow)
	p.add_child(sp)
	return p

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	var sc := get_tree().current_scene
	if sc.has_method("teleport_player"):
		sc.teleport_player(dest, dest_yaw, label)
