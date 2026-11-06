extends Node3D
class_name AngelWings
## Big feathered wings for the angels of Cloud Island (and the Angel skin).
## Layered feather slats that open and close slowly.

var _l: Node3D
var _r: Node3D
var _t := 0.0
var speed := 1.3

static func make(col: Color, scl := 1.0, tip := Color(1.0, 0.85, 0.4)) -> AngelWings:
	var w := AngelWings.new()
	w._build(col, tip)
	w.scale = Vector3.ONE * scl
	return w

func _build(col: Color, tip: Color) -> void:
	var feather := StandardMaterial3D.new(); feather.albedo_color = col; feather.roughness = 0.7
	feather.emission_enabled = true; feather.emission = col; feather.emission_energy_multiplier = 0.15
	var gold := StandardMaterial3D.new(); gold.albedo_color = tip; gold.metallic = 0.6; gold.roughness = 0.35
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.16, 1.32, 0.2)
		add_child(pivot)
		# three rows of feathers, longest at the bottom, fanning out
		for row in 3:
			for k in 5:
				var f := MeshInstance3D.new(); var bm := BoxMesh.new()
				var length := 0.55 + row * 0.18 - k * 0.04
				bm.size = Vector3(length, 0.035, 0.16)
				f.mesh = bm
				f.material_override = gold if (row == 2 and k == 0) else feather
				var out := 0.12 + k * 0.17
				f.position = Vector3(side * (out + length * 0.35), 0.18 - row * 0.16 - k * 0.04, 0.08 + row * 0.03)
				f.rotation = Vector3(0, 0, side * (-0.35 - row * 0.28 + k * 0.05))
				f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pivot.add_child(f)
		if side < 0:
			_l = pivot
		else:
			_r = pivot

func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * speed) * 0.18
	_l.rotation.y = 0.35 + a
	_r.rotation.y = -0.35 - a
