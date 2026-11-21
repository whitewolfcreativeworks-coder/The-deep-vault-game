extends Node3D
class_name HomeBuilding
## Shared bits for the outbuildings at home (Tobble's Trading Post and the Forge):
## boxes with collision, materials, signs.

var home: HomeWorld
var _body: StaticBody3D

func _solid() -> StaticBody3D:
	if _body == null:
		_body = StaticBody3D.new(); _body.collision_layer = 1
		add_child(_body)
	return _body

static func mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = energy
	return m

## A box between two corners (in `parent`'s space); solid unless told otherwise.
func box(parent: Node3D, a: Vector3, b: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = (b - a).abs()
	mi.mesh = bm; mi.material_override = m
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if solid:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = bm.size
		cs.shape = bs
		_solid().add_child(cs)
		cs.global_transform = mi.global_transform
	return mi

func cylinder(parent: Node3D, at: Vector3, r_top: float, r_bot: float, h: float, m: Material, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = r_top; cm.bottom_radius = r_bot; cm.height = h; cm.radial_segments = segs; cm.rings = 1
	mi.mesh = cm; mi.material_override = m
	parent.add_child(mi)
	mi.position = at + Vector3(0, h * 0.5, 0)
	return mi

func sphere(parent: Node3D, at: Vector3, r: float, m: Material, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2.0 * squash; sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	return mi

## A floating sign over something (faces you as you walk round).
static func label_sign(parent: Node3D, at: Vector3, text: String, col := Color(1.0, 0.86, 0.45), w := 1.6, h := 0.3) -> Label3D:
	var l := Label3D.new(); l.text = text; l.modulate = col
	l.outline_size = 10; l.outline_modulate = Color(0.18, 0.09, 0.03); l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(l)
	l.position = at
	SignText.fit(l, w, h)
	return l

static func scene_main() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null
