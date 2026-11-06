extends Node3D
class_name SkyLift
## A puffy cloud you step onto and press USE: it carries you between Ghost
## Knight Castle and Cloud Island (main.gd does the travelling).

var prompt := ""
var action := ""        # the main-scene method to call, e.g. "go_to_cloud"

static func make(parent: Node, pos: Vector3, prompt_text: String, main_method: String, tint := Color(1, 1, 1)) -> SkyLift:
	var s := SkyLift.new()
	s.prompt = prompt_text; s.action = main_method
	parent.add_child(s)
	s.global_position = pos
	s.add_to_group("interactable")
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/cloud.gdshader")
	mat.set_shader_parameter("tint", tint)
	for k in 7:
		var a := k * TAU / 7.0
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.7; sm.height = 1.4
		mi.mesh = sm; mi.material_override = mat
		mi.position = Vector3(cos(a) * 1.1, 0.35 + (k % 2) * 0.15, sin(a) * 1.1)
		mi.scale = Vector3(1.0, 0.6, 1.0)
		s.add_child(mi)
	var top := MeshInstance3D.new(); var tm := SphereMesh.new(); tm.radius = 1.2; tm.height = 1.0
	top.mesh = tm; top.material_override = mat; top.position.y = 0.4; s.add_child(top)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.95, 0.8); l.light_energy = 1.5; l.omni_range = 6.0
	l.position.y = 1.5; s.add_child(l)
	var sp := CPUParticles3D.new(); sp.amount = 16; sp.lifetime = 2.0
	sp.mesh = FX.quad(0.1); sp.material_override = FX.glow_material(Color(1.0, 0.95, 0.7), 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 1.4
	sp.direction = Vector3.UP; sp.spread = 20; sp.initial_velocity_min = 0.3; sp.initial_velocity_max = 0.9
	sp.gravity = Vector3.ZERO; sp.color_ramp = FX._fade_ramp(Color(1.0, 0.95, 0.7))
	sp.position.y = 0.6; s.add_child(sp)
	return s

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	var sc := get_tree().current_scene
	if sc.has_method(action):
		sc.call(action)
