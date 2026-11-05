extends Node3D
class_name MopedMount
## The Moped: Bobek's second mount, the reward for beating the Ghost Lord of
## Castle Morwen. A little cherry-red scooter built from simple shapes, with a
## headlight that lights up the moors, spinning wheels, puffs of exhaust and a
## putt-putt engine. Faster than the Giant Chicken. Faces -Z like everything.
## The player script drives `speed`, `airborne` and `riding`, like the chicken.

const SEAT_H := 1.0              # saddle top above the ground

var speed := 0.0
var airborne := false
var riding := false
var _t := 0.0
var _wheels: Array[Node3D] = []
var _frame: Node3D
var _puffs: CPUParticles3D
var _engine: AudioStreamPlayer3D

func _box(parent: Node3D, size: Vector3, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ready() -> void:
	var red := ChickenMount.mat(Color(0.85, 0.1, 0.12), 0.35); red.metallic = 0.3
	var cream := ChickenMount.mat(Color(0.96, 0.92, 0.82), 0.4)
	var black := ChickenMount.mat(Color(0.05, 0.05, 0.06), 0.6)
	var chrome := ChickenMount.mat(Color(0.85, 0.87, 0.9), 0.15); chrome.metallic = 1.0
	var seat := ChickenMount.mat(Color(0.2, 0.12, 0.08), 0.7)
	_frame = Node3D.new(); add_child(_frame)
	# wheels (front at -Z)
	for z in [-0.68, 0.62]:
		var w := Node3D.new(); _frame.add_child(w); w.position = Vector3(0, 0.3, z)
		_cyl(w, 0.3, 0.16, black, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
		_cyl(w, 0.17, 0.18, chrome, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
		for k in 3:
			_box(w, Vector3(0.19, 0.04, 0.3), chrome, Vector3.ZERO, Vector3(k * PI / 3.0, 0, 0))
		_wheels.append(w)
	# body: a rounded rear shell, footboard and front shield
	var shell := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.42; sm.height = 0.84
	shell.mesh = sm; shell.material_override = red; shell.scale = Vector3(0.95, 0.75, 1.35); shell.position = Vector3(0, 0.68, 0.42)
	_frame.add_child(shell)
	_box(_frame, Vector3(0.42, 0.08, 0.7), cream, Vector3(0, 0.36, -0.1))
	_box(_frame, Vector3(0.5, 0.75, 0.12), red, Vector3(0, 0.72, -0.5), Vector3(-0.25, 0, 0))
	_box(_frame, Vector3(0.24, 0.14, 0.36), red, Vector3(0, 0.62, -0.72))           # front mudguard
	# seat
	var st := _box(_frame, Vector3(0.38, 0.12, 0.62), seat, Vector3(0, SEAT_H - 0.06, 0.3))
	st.scale = Vector3(1, 1, 1)
	# steering column, handlebars, mirrors
	_cyl(_frame, 0.04, 0.8, chrome, Vector3(0, 0.95, -0.6), Vector3(-0.3, 0, 0))
	_cyl(_frame, 0.03, 0.75, chrome, Vector3(0, 1.32, -0.7), Vector3(0, 0, PI * 0.5))
	for sx in [-0.38, 0.38]:
		_cyl(_frame, 0.045, 0.14, black, Vector3(sx, 1.32, -0.7), Vector3(0, 0, PI * 0.5))
		_cyl(_frame, 0.012, 0.25, chrome, Vector3(sx * 0.7, 1.45, -0.7))
		_cyl(_frame, 0.06, 0.02, chrome, Vector3(sx * 0.7, 1.58, -0.7), Vector3(PI * 0.5, 0, 0))
	# headlight
	var lamp := _cyl(_frame, 0.11, 0.08, chrome, Vector3(0, 1.22, -0.8), Vector3(PI * 0.5, 0, 0))
	var glass := MeshInstance3D.new(); var gm := SphereMesh.new(); gm.radius = 0.09; gm.height = 0.1; gm.is_hemisphere = true
	glass.mesh = gm; glass.material_override = FX.glow_material(Color(1.0, 0.95, 0.75), 3.0)
	glass.rotation.x = -PI * 0.5; glass.position = Vector3(0, 1.22, -0.84); _frame.add_child(glass)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam := SpotLight3D.new(); beam.light_color = Color(1.0, 0.95, 0.8); beam.light_energy = 4.0
	beam.spot_range = 22.0; beam.spot_angle = 28.0; beam.position = Vector3(0, 1.22, -0.9)
	beam.rotation.x = -0.12
	_frame.add_child(beam)
	# tail light and exhaust pipe
	var tail := _box(_frame, Vector3(0.14, 0.06, 0.04), FX.glow_material(Color(1.0, 0.1, 0.05), 2.0), Vector3(0, 0.78, 0.98))
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cyl(_frame, 0.05, 0.5, chrome, Vector3(0.24, 0.32, 0.6), Vector3(PI * 0.5, 0, 0))
	_puffs = CPUParticles3D.new(); _puffs.amount = 18; _puffs.lifetime = 0.9
	_puffs.mesh = FX.quad(0.22); _puffs.material_override = FX.glow_material(Color(0.7, 0.7, 0.72), 0.4)
	_puffs.direction = Vector3(0, 0.4, 1); _puffs.spread = 20; _puffs.initial_velocity_min = 0.6; _puffs.initial_velocity_max = 1.2
	_puffs.gravity = Vector3(0, 0.6, 0); _puffs.scale_amount_min = 0.6; _puffs.scale_amount_max = 1.6
	_puffs.color_ramp = FX._fade_ramp(Color(0.75, 0.75, 0.78, 0.5))
	_puffs.position = Vector3(0.24, 0.32, 0.88)
	_frame.add_child(_puffs)
	_engine = Sfx.loop_on(self, "loop_moped", -14.0, 4.0, 25.0)

func _process(delta: float) -> void:
	_t += delta
	var sp := speed if riding else 0.0
	for w in _wheels:
		w.rotation.x -= sp * delta / 0.3
	# a bit of bounce and a lean back when going fast
	_frame.position.y = absf(sin(_t * 18.0)) * 0.015 * clampf(sp / 6.0, 0.3, 1.0) + (0.1 if airborne else 0.0)
	_frame.rotation.x = lerpf(_frame.rotation.x, 0.06 * clampf(sp / 12.0, 0.0, 1.0) + (0.12 if airborne else 0.0), 1.0 - exp(-6.0 * delta))
	_puffs.speed_scale = 0.6 + 0.8 * clampf(sp / 10.0, 0.0, 1.0)
	if _engine:
		_engine.pitch_scale = 0.8 + clampf(sp / 14.0, 0.0, 1.0) * 0.7

## Matches ChickenMount.bawk(): the hello noise when you climb on.
func bawk() -> void:
	Sfx.play("beep", -2.0, 0.05)
