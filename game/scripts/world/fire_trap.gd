extends Node3D
class_name FireTrap
## Floor vent that cycles: idle -> warning glow -> roaring flame column.
## Damages the player standing in the column. Can be permanently disabled.

var period := 3.2
var offset := 0.0
var size := Vector2(2.6, 1.4)
var disabled := false
var _t := 0.0
var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _grate_mat: StandardMaterial3D
var _area: Area3D
var _tick := 0.0
var _was_on := false
var _loop: AudioStreamPlayer3D

const WARN := 0.7
const BURN := 1.1

static func create(parent: Node, pos: Vector3, sz: Vector2, per: float, off: float) -> FireTrap:
	var f := FireTrap.new()
	f.size = sz; f.period = per; f.offset = off
	parent.add_child(f)
	f.position = pos
	f._build()
	return f

func _build() -> void:
	var grate := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = Vector3(size.x, 0.06, size.y)
	grate.mesh = b
	_grate_mat = StandardMaterial3D.new()
	_grate_mat.albedo_color = Color(0.1, 0.09, 0.09); _grate_mat.metallic = 0.7; _grate_mat.roughness = 0.6
	_grate_mat.emission_enabled = true; _grate_mat.emission = Color(1.0, 0.35, 0.1); _grate_mat.emission_energy_multiplier = 0.0
	grate.material_override = _grate_mat
	grate.position.y = 0.01
	add_child(grate)
	for i in int(size.x / 0.3):
		var slot := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.06, 0.07, size.y * 0.9)
		slot.mesh = sb
		var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.02, 0.02, 0.02)
		slot.material_override = sm
		slot.position = Vector3(-size.x * 0.5 + 0.15 + i * 0.3, 0.02, 0)
		add_child(slot)
	_flames = CPUParticles3D.new()
	_flames.amount = 90
	_flames.lifetime = 0.7
	_flames.emitting = false
	_flames.mesh = FX.quad(0.6)
	_flames.material_override = FX.glow_material(Color(1.0, 0.5, 0.15), 2.5)
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(size.x * 0.45, 0.05, size.y * 0.4)
	_flames.direction = Vector3.UP; _flames.spread = 8.0
	_flames.initial_velocity_min = 4.0; _flames.initial_velocity_max = 6.5
	_flames.gravity = Vector3(0, 1.0, 0)
	_flames.damping_min = 1.0; _flames.damping_max = 2.0
	var curve := Curve.new(); curve.add_point(Vector2(0, 0.4)); curve.add_point(Vector2(0.25, 1.0)); curve.add_point(Vector2(1, 0.2))
	_flames.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1)); g.set_color(1, Color(0.6, 0.05, 0.0, 0))
	g.add_point(0.35, Color(1.0, 0.45, 0.1, 0.9))
	_flames.color_ramp = g
	add_child(_flames)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 16; _smoke.lifetime = 2.0; _smoke.emitting = false
	_smoke.mesh = FX.quad(1.2)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.albedo_texture = FX.soft_texture()
	smat.vertex_color_use_as_albedo = true
	_smoke.material_override = smat
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(size.x * 0.4, 0.1, size.y * 0.35)
	_smoke.position.y = 2.5
	_smoke.direction = Vector3.UP; _smoke.initial_velocity_min = 0.5; _smoke.initial_velocity_max = 1.0
	_smoke.gravity = Vector3(0, 0.3, 0)
	_smoke.color_ramp = FX._fade_ramp(Color(0.12, 0.1, 0.09, 0.5))
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2); _light.light_energy = 0.0; _light.omni_range = 7.0
	_light.position.y = 1.2
	_light.light_volumetric_fog_energy = 2.0
	add_child(_light)
	_area = Area3D.new()
	_area.collision_layer = 0; _area.collision_mask = 2
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(size.x * 0.95, 3.0, size.y * 0.95)
	cs.shape = bs; cs.position.y = 1.5
	_area.add_child(cs)
	add_child(_area)
	_loop = Sfx.loop_on(self, "loop_fire", -60.0, 4.0, 20.0)

func phase() -> float:
	return fposmod(_t + offset, period)

func is_burning() -> bool:
	return not disabled and phase() > period - BURN

func _process(delta: float) -> void:
	_t += delta
	if disabled:
		_flames.emitting = false
		_grate_mat.emission_energy_multiplier = 0.0
		_light.light_energy = 0.0
		if _loop:
			_loop.volume_db = -60.0
		return
	var p := phase()
	var warn_start := period - BURN - WARN
	var on := is_burning()
	var warn := clampf((p - warn_start) / WARN, 0.0, 1.0) if p < period - BURN else 1.0
	_grate_mat.emission_energy_multiplier = warn * 2.5 + (2.0 if on else 0.0)
	_flames.emitting = on
	_smoke.emitting = on
	_light.light_energy = (5.0 if on else warn * 0.8)
	if _loop:
		_loop.volume_db = -2.0 if on else -60.0
	if on and not _was_on:
		Sfx.play_at("fire_burst", global_position + Vector3(0, 1, 0), 0.0, 0.1, 6.0)
		_tick = 0.0
	_was_on = on
	if on:
		_tick -= delta
		if _tick <= 0.0:
			for b in _area.get_overlapping_bodies():
				if b.is_in_group("player") and b.has_method("take_damage"):
					b.take_damage(16.0, global_position + Vector3(0, 0, 3.0), 2.0)
					_tick = 0.45
