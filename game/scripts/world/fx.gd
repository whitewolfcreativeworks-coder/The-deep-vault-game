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

# ---------------------------------------------------------------------------
# Big-moment effects used by the hero specials.
static func _add_mat(color: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	return m

static func _spawn(mi: Node3D, pos: Vector3) -> bool:
	var root := scene_root()
	if root == null:
		return false
	root.add_child(mi)
	mi.global_position = pos
	return true

## A glowing streak from a to b that thins out and fades (blink and backstab trails).
static func beam(a: Vector3, b: Vector3, color: Color, width := 0.35, dur := 0.5) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 1.0; cm.radial_segments = 12
	mi.mesh = cm
	var m := _add_mat(color, 3.0)
	mi.material_override = m
	if not _spawn(mi, (a + b) * 0.5):
		return
	var up := (b - a).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, up, side.cross(up)).scaled(Vector3(width, len, width))
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.05, len, 0.05), dur).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)
	var n := int(clampf(len * 2.0, 2.0, 24.0))
	for i in n:
		burst(a.lerp(b, (i + 0.5) / n), color, 4, 1.2, 0.25, 0.6, 0.5)

## A column of light that shoots up and fades.
static func pillar(pos: Vector3, color: Color, radius := 1.2, height := 9.0, dur := 0.7) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = radius * 0.6; cm.bottom_radius = radius; cm.height = 1.0; cm.radial_segments = 24
	cm.cap_top = false; cm.cap_bottom = false
	mi.mesh = cm
	var m := _add_mat(color, 1.5)
	m.albedo_color.a = 0.7
	mi.material_override = m
	if not _spawn(mi, pos + Vector3(0, 0.5, 0)):
		return
	mi.scale = Vector3(0.4, 0.2, 0.4)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.0, height, 1.0), dur * 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", pos.y + height * 0.5, dur * 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_delay(dur * 0.2)
	tw.chain().tween_callback(mi.queue_free)
	flash_light(pos + Vector3(0, 2, 0), color, 8.0, 10.0, dur)

## A sphere that grows (or, with implode, collapses) and fades.
static func dome(pos: Vector3, color: Color, radius := 4.0, dur := 0.45, implode := false) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 32; sm.rings = 16
	mi.mesh = sm
	var m := _add_mat(color, 1.4)
	m.albedo_color.a = 0.55
	mi.material_override = m
	if not _spawn(mi, pos + Vector3(0, 0.6, 0)):
		return
	var r0 := radius if implode else 0.3
	var r1 := 0.1 if implode else radius
	mi.scale = Vector3.ONE * r0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1, dur).set_ease(Tween.EASE_OUT if not implode else Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

## A bright blade arc (flattened ring) that sweeps and fades.
static func slash(pos: Vector3, color: Color, radius := 1.6, tilt := 0.0, yaw := 0.0, dur := 0.3) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.82; t.outer_radius = 1.0; t.rings = 40; t.ring_segments = 6
	mi.mesh = t
	var m := _add_mat(color, 3.0)
	mi.material_override = m
	if not _spawn(mi, pos):
		return
	mi.rotation = Vector3(0, yaw, tilt)
	mi.scale = Vector3(radius * 0.5, 0.25, radius * 0.5)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.08, radius), dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:y", yaw + 2.5, dur)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

## Brief full-screen colour flash.
static func screen_flash(color: Color, strength := 0.45, dur := 0.35) -> void:
	var root := scene_root()
	if root == null:
		return
	var cl := CanvasLayer.new(); cl.layer = 5
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(color.r, color.g, color.b, strength)
	cl.add_child(r)
	root.add_child(cl)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, dur)
	tw.tween_callback(cl.queue_free)

## A spinning funnel of light attached to a node (whirlwind).
static func vortex(parent: Node3D, color: Color, radius := 2.6, dur := 1.2) -> void:
	for k in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = radius * (1.0 + 0.15 * k); cm.bottom_radius = radius * (0.45 + 0.1 * k)
		cm.height = 1.8 + 0.5 * k; cm.radial_segments = 7 + k * 2; cm.cap_top = false; cm.cap_bottom = false
		mi.mesh = cm
		var m := _add_mat(color.lerp(Color(1, 0.9, 0.5), 0.2 * k), 0.75)
		m.albedo_color.a = 0.0
		mi.material_override = m
		parent.add_child(mi)
		mi.position = Vector3(0, 0.9 + 0.2 * k, 0)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(m, "albedo_color:a", 0.38 - 0.08 * k, 0.15)
		tw.tween_property(mi, "rotation:y", TAU * (5.0 - k) * (1 if k % 2 == 0 else -1), dur)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.3).set_delay(dur - 0.3)
		tw.chain().tween_callback(mi.queue_free)
	var p := CPUParticles3D.new()
	p.amount = 90; p.lifetime = 0.7; p.local_coords = false
	p.mesh = quad(0.22); p.material_override = glow_material(color, 2.5)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP; p.emission_ring_radius = radius; p.emission_ring_inner_radius = radius * 0.6; p.emission_ring_height = 1.5
	p.direction = Vector3.UP; p.spread = 30; p.initial_velocity_min = 2.0; p.initial_velocity_max = 5.0
	p.orbit_velocity_min = 1.2; p.orbit_velocity_max = 2.0
	p.gravity = Vector3(0, 1.0, 0)
	p.color_ramp = _fade_ramp(color)
	parent.add_child(p)
	p.position = Vector3(0, 0.3, 0)
	p.emitting = true
	parent.get_tree().create_timer(dur).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(0.8).timeout.connect(p.queue_free))

## A lingering pool on the floor that hurts enemies standing in it.
static func shadow_pool(pos: Vector3, color: Color, radius: float, dur: float, tick_dmg: float) -> void:
	var root := scene_root()
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.04; cm.radial_segments = 32
	mi.mesh = cm
	var m := _add_mat(color, 1.0)
	m.albedo_color.a = 0.0
	mi.material_override = m
	root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	var smoke := CPUParticles3D.new()
	smoke.amount = 40; smoke.lifetime = 1.2
	smoke.mesh = quad(0.45); smoke.material_override = glow_material(color, 1.2)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; smoke.emission_sphere_radius = radius * 0.8
	smoke.direction = Vector3.UP; smoke.spread = 15; smoke.initial_velocity_min = 0.4; smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3.ZERO; smoke.scale_amount_min = 0.6; smoke.scale_amount_max = 1.4
	smoke.color_ramp = _fade_ramp(color)
	mi.add_child(smoke)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, 0.2)
	tw.tween_interval(dur)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)
	var ticks := int(dur / 0.5)
	for i in ticks:
		root.get_tree().create_timer(0.5 * (i + 1)).timeout.connect(func() -> void:
			if not is_instance_valid(mi):
				return
			for e in mi.get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.get("dead") != true and e is Node3D and (e as Node3D).global_position.distance_to(pos) < radius + 0.4:
					e.take_damage(tick_dmg, pos, 0.0, false))
