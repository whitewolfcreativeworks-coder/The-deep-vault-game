extends Node3D
class_name DragonflyMount
## The Dragonfly: the first flying mount, Mr. Bubbles' reward on Cloud Island,
## and yours for the rest of the game. Built from simple shapes: a long,
## segmented, shimmery teal body, big round compound eyes, four see-through
## rainbow wings that buzz fast while climbing, slowly while gliding and droop
## when tired, little legs and a saddle. Faces -Z like every character.
## The player script drives `speed`, `airborne`, `riding`, `climbing`, `tired`.

const SEAT_H := 1.3              # saddle top above the ground

var speed := 0.0
var airborne := false
var riding := false
var climbing := false
var tired := false
var _t := 0.0
var _body: Node3D
var _wings: Array[Node3D] = []       # pivots: [front-left, front-right, back-left, back-right]
var _wing_mat: StandardMaterial3D
var _tail: Node3D
var _buzz: AudioStreamPlayer3D
var _flap := 0.0

static func _mat(c: Color, rough := 0.35, metal := 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

func _sphere(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 16; sm.rings = 8
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r0: float, r1: float, h: float, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r0; cm.bottom_radius = r1; cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm; mi.material_override = m; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ready() -> void:
	var teal := _mat(Color(0.1, 0.62, 0.7), 0.25, 0.6)
	teal.emission_enabled = true; teal.emission = Color(0.02, 0.18, 0.22)
	var blue := _mat(Color(0.12, 0.3, 0.75), 0.25, 0.6)
	var eye := _mat(Color(0.25, 0.85, 0.45), 0.15, 0.3)
	eye.emission_enabled = true; eye.emission = Color(0.05, 0.25, 0.1)
	var dark := _mat(Color(0.05, 0.06, 0.08), 0.5, 0.2)
	var leather := _mat(Color(0.5, 0.28, 0.12), 0.75, 0.0)
	_body = Node3D.new(); add_child(_body)
	# thorax (under the saddle) and head with two huge eyes at the front (-Z)
	_sphere(_body, 0.42, teal, Vector3(0, 0.95, 0.0), Vector3(0.95, 0.9, 1.25))
	_sphere(_body, 0.3, blue, Vector3(0, 1.0, -0.55), Vector3(1.0, 0.9, 0.9))
	for sx in [-0.2, 0.2]:
		_sphere(_body, 0.24, eye, Vector3(sx, 1.12, -0.72))
		_sphere(_body, 0.06, dark, Vector3(sx * 1.25, 1.18, -0.92))     # a shiny pupil spot
	# little mouth parts
	_sphere(_body, 0.08, dark, Vector3(0, 0.88, -0.82), Vector3(1.4, 0.6, 1.0))
	# the long segmented tail, gently curving, alternating teal and blue
	_tail = Node3D.new(); _body.add_child(_tail); _tail.position = Vector3(0, 0.95, 0.45)
	for k in 9:
		var r := 0.19 - k * 0.012
		_sphere(_tail, r, teal if k % 2 == 0 else blue, Vector3(0, -k * 0.015, 0.2 + k * 0.27), Vector3(1.0, 1.0, 1.35))
	_sphere(_tail, 0.07, blue, Vector3(0, -0.15, 2.7))
	# six little legs
	for k in 3:
		for sx in [-1.0, 1.0]:
			var leg := _cyl(_body, 0.025, 0.02, 0.55, dark, Vector3(sx * 0.3, 0.55, -0.25 + k * 0.25), Vector3(0, 0, sx * 0.5))
			leg.rotation.x = 0.2 - k * 0.2
	# saddle with a little backrest
	var saddle := _cyl(_body, 0.32, 0.34, 0.1, leather, Vector3(0, SEAT_H - 0.05, 0.05))
	saddle.scale = Vector3(1.0, 1.0, 1.3)
	var rest := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.45, 0.28, 0.06)
	rest.mesh = bm; rest.material_override = leather; rest.position = Vector3(0, SEAT_H + 0.1, 0.42); _body.add_child(rest)
	# four see-through, rainbow-tinted wings on pivots at the shoulders
	_wing_mat = StandardMaterial3D.new()
	_wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wing_mat.albedo_color = Color(0.75, 0.95, 1.0, 0.32)
	_wing_mat.metallic = 0.8; _wing_mat.roughness = 0.1
	_wing_mat.emission_enabled = true; _wing_mat.emission = Color(0.25, 0.45, 0.6)
	_wing_mat.rim_enabled = true; _wing_mat.rim = 0.8
	var vein := _mat(Color(0.15, 0.3, 0.35), 0.5, 0.2)
	for i in 4:
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var piv := Node3D.new(); _body.add_child(piv)
		piv.position = Vector3(side * 0.25, 1.2, -0.12 if front else 0.18)
		var w := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 0.04
		w.mesh = sm; w.material_override = _wing_mat
		var length := 1.45 if front else 1.3
		w.scale = Vector3(length / 0.5 * 0.5, 1.0, 0.36 if front else 0.4)
		w.position = Vector3(side * length * 0.5, 0, 0)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(w)
		var spar := _cyl(piv, 0.012, 0.012, length, vein, Vector3(side * length * 0.5, 0.01, -0.05), Vector3(0, 0, PI * 0.5))
		spar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.rotation.y = side * (-0.12 if front else 0.12)
		_wings.append(piv)
	_buzz = Sfx.loop_on(self, "loop_wings", -18.0, 4.0, 25.0)

func _process(delta: float) -> void:
	_t += delta
	# how hard the wings beat: a blur while climbing, a slow shimmer while
	# gliding or resting, and limp (drooping) when tired
	var rate := 0.0
	var amp := 0.0
	var lift := 0.0
	if tired:
		rate = 2.0; amp = 0.08; lift = -0.55
	elif airborne and climbing:
		rate = 38.0; amp = 0.55; lift = 0.1
	elif airborne:
		rate = 9.0; amp = 0.2; lift = 0.0
	elif riding and speed > 0.5:
		rate = 6.0; amp = 0.15; lift = 0.15
	else:
		rate = 1.2; amp = 0.05; lift = 0.25        # folded up a little, at rest
	_flap += delta * rate
	for i in _wings.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var phase := 0.0 if i < 2 else PI * 0.5   # front and back pairs beat out of step
		var a := lift + sin(_flap * TAU * 0.15 + phase) * amp
		_wings[i].rotation.z = side * a
	# hover bob, a lean into fast flight, and the tail sways
	_body.position.y = sin(_t * 3.0) * (0.06 if airborne else 0.015)
	var lean := clampf(speed / 12.0, 0.0, 1.0) * 0.18 * (1.0 if airborne else 0.4)
	_body.rotation.x = lerpf(_body.rotation.x, lean, 1.0 - exp(-4.0 * delta))
	_tail.rotation.x = sin(_t * 2.0) * 0.05 - (0.12 if tired else 0.0)
	_wing_mat.albedo_color = Color.from_hsv(fmod(0.5 + sin(_t * 0.7) * 0.08, 1.0), 0.25, 1.0, 0.3 if not tired else 0.22)
	if _buzz:
		_buzz.volume_db = -12.0 if (airborne and climbing) else (-18.0 if airborne else -40.0)
		_buzz.pitch_scale = 1.15 if climbing else 0.9

## Matches the other mounts' hello noise.
func bawk() -> void:
	Sfx.play("chirp", -4.0, 0.08)
