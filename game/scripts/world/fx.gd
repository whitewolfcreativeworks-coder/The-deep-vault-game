extends Object
class_name FX
## One-shot visual effects built from CPUParticles3D (works identically on
## Forward+ and the OpenGL fallback) plus floating combat text.

static var _soft_tex: GradientTexture2D

static func scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null

static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64; _soft_tex.height = 64
	return _soft_tex

## Additive glowing billboard material (used by every particle effect).
static func glow_material(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_texture()
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	return m

static func quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q

static func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 1.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g

static func burst(pos: Vector3, color: Color, amount := 20, speed := 3.0, size := 0.18, life := 0.7, gravity := -2.0) -> void:
	var root := scene_root()
	if root == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.mesh = quad(size)
	p.material_override = glow_material(color)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.5; p.damping_max = 3.0
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.2
	p.color_ramp = _fade_ramp(color)
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

static func sparks(pos: Vector3, color := Color(1, 0.8, 0.4)) -> void:
	burst(pos, color, 18, 6.0, 0.07, 0.4, -9.0)

static func hit(pos: Vector3, color := Color(1, 0.9, 0.7)) -> void:
	sparks(pos, color)
	burst(pos, color, 6, 1.0, 0.45, 0.25, 0.0)

static func flash_light(pos: Vector3, color: Color, energy := 4.0, rng := 5.0, dur := 0.25) -> void:
	var root := scene_root()
	if root == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color; l.light_energy = energy; l.omni_range = rng
	root.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

static func damage_number(pos: Vector3, amount: float, color: Color, crit := false) -> void:
	var root := scene_root()
	if root == null:
		return
	var l := Label3D.new()
	l.text = ("%d!" if crit else "%d") % int(round(amount))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011 if not crit else 0.0016
	l.font_size = 48
	l.outline_size = 12
	l.modulate = color if not crit else Color(1.0, 0.85, 0.2)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	root.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.1, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

## Expanding ground shockwave ring (boss slam).
static func shockwave(pos: Vector3, color: Color, radius := 6.0, dur := 0.5) -> void:
	var root := scene_root()
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.9; t.outer_radius = 1.0; t.rings = 48
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * 2, color.g * 2, color.b * 2, 1)
	mi.material_override = m
	root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.1, 0)
	mi.scale = Vector3(0.3, 0.6, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.2, radius), dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)
	burst(pos + Vector3(0, 0.3, 0), Color(0.6, 0.55, 0.5), 30, 6.0, 0.5, 0.9, -6.0)
