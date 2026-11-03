extends Object
class_name Props
## KayKit Dungeon Remastered props (CC0) plus small procedural builders.

const DIR := "res://assets/kaykit/dungeon/%s.gltf.glb"
static var _cache := {}

static func make(name: String) -> Node3D:
	var path := DIR % name
	if not ResourceLoader.exists(path):
		path = "res://assets/kaykit/dungeon/%s.glb" % name
	if not _cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("Missing prop: " + name)
			return Node3D.new()
		_cache[path] = load(path)
	return (_cache[path] as PackedScene).instantiate()

## Place a prop; optional simple box collider sized from its meshes.
static func place(parent: Node, name: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0, collide := false) -> Node3D:
	var n := make(name)
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * scl
	if collide:
		var aabb := mesh_aabb(n)
		if aabb.size != Vector3.ZERO:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new(); bs.size = aabb.size
			cs.shape = bs
			cs.position = aabb.get_center()
			sb.add_child(cs)
			n.add_child(sb)
	return n

static func mesh_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := n.global_transform.affine_inverse() * m.global_transform if n.is_inside_tree() else _rel(n, m)
		var a := xf * m.get_aabb()
		if first:
			out = a; first = false
		else:
			out = out.merge(a)
	return out

static func _rel(root: Node3D, m: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = m
	while n and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

## A wall-mounted or standing torch with a flickering shadow-casting light.
static func torch(parent: Node, pos: Vector3, yaw_deg := 0.0, mounted := true, shadows := false, color := Color(1.0, 0.62, 0.3)) -> Node3D:
	var t := place(parent, "torch_mounted" if mounted else "torch_lit", pos, yaw_deg)
	var flame_pos := Vector3(0, 0.62, 0.32) if mounted else Vector3(0, 1.45, 0)
	if mounted:
		flame_pos = flame_pos.rotated(Vector3.UP, deg_to_rad(yaw_deg))
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos + flame_pos
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 3.4
	l.omni_range = 12.0
	l.omni_attenuation = 1.0
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.5
	holder.add_child(l)
	l.set_script(load("res://scripts/world/flicker.gd"))
	fire_particles(holder, 0.6, color)
	return t

static func fire_particles(parent: Node3D, size := 1.0, color := Color(1.0, 0.6, 0.25), embers := true) -> void:
	var f := CPUParticles3D.new()
	f.amount = int(24 * size) + 8
	f.lifetime = 0.55
	f.mesh = FX.quad(0.22 * size)
	f.material_override = FX.glow_material(color, 2.2)
	f.direction = Vector3.UP
	f.spread = 12.0
	f.initial_velocity_min = 0.5 * size; f.initial_velocity_max = 1.2 * size
	f.gravity = Vector3(0, 1.2, 0)
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.06 * size
	f.scale_amount_min = 0.5; f.scale_amount_max = 1.0
	var curve := Curve.new(); curve.add_point(Vector2(0, 0.6)); curve.add_point(Vector2(0.3, 1.0)); curve.add_point(Vector2(1, 0.0))
	f.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1)); g.set_color(1, Color(0.8, 0.15, 0.02, 0))
	g.add_point(0.4, Color(color.r, color.g * 0.8, color.b * 0.5, 0.9))
	f.color_ramp = g
	parent.add_child(f)
	if embers:
		var e := CPUParticles3D.new()
		e.amount = 10
		e.lifetime = 2.2
		e.mesh = FX.quad(0.03)
		e.material_override = FX.glow_material(Color(1.0, 0.55, 0.2), 3.0)
		e.direction = Vector3.UP
		e.spread = 25.0
		e.initial_velocity_min = 0.6; e.initial_velocity_max = 1.4
		e.gravity = Vector3(0, 0.25, 0)
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.1 * size
		e.color_ramp = FX._fade_ramp(Color(1.0, 0.6, 0.25))
		e.orbit_velocity_min = -0.1; e.orbit_velocity_max = 0.1
		parent.add_child(e)
