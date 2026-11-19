extends CanvasLayer
class_name RainbowVision
## The full-screen rainbow-vision effect from eating glowing mushrooms (Game.shroom),
## drawn under the HUD, plus rainbow sparkles drifting round the hero.

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0
var _sparkles: CPUParticles3D
var player: Node3D

func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new(); _mat.shader = load("res://shaders/rainbow_vision.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

func _process(delta: float) -> void:
	_t += delta
	var amt := clampf(Game.shroom, 0.0, 5.0)
	_rect.visible = amt > 0.02
	if _rect.visible:
		_mat.set_shader_parameter("amount", amt)
		_mat.set_shader_parameter("t", _t)
	# rainbow sparkles round the hero
	if player and is_instance_valid(player):
		if _sparkles == null or not is_instance_valid(_sparkles):
			_sparkles = CPUParticles3D.new(); _sparkles.amount = 40; _sparkles.lifetime = 2.0
			_sparkles.mesh = FX.quad(0.14); _sparkles.material_override = FX.glow_material(Color(1, 1, 1), 2.5)
			_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _sparkles.emission_sphere_radius = 2.2
			_sparkles.direction = Vector3.UP; _sparkles.spread = 180; _sparkles.gravity = Vector3(0, 0.2, 0)
			_sparkles.initial_velocity_min = 0.2; _sparkles.initial_velocity_max = 0.6
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0])
			g.colors = PackedColorArray([Color(1, 0.2, 0.2), Color(1, 0.6, 0.1), Color(1, 1, 0.2), Color(0.3, 1, 0.3), Color(0.3, 0.6, 1), Color(0.7, 0.3, 1), Color(1, 0.3, 0.8, 0)])
			_sparkles.color_ramp = g
			_sparkles.position.y = 1.2
			player.add_child(_sparkles)
		_sparkles.emitting = amt > 0.5
		_sparkles.scale = Vector3.ONE * clampf(0.5 + amt * 0.15, 0.5, 1.25)
