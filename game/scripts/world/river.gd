extends Node3D
class_name GlowRiver
## The luminous river: animated shader surface, glow lights, mist sheets,
## drifting motes, a volumetric fog volume, and gameplay: it burns the
## player (arcane damage) unless the Amulet of the Deep is worn, in which
## case it heals and the water shifts to green where they wade.

var rect := Rect2()        # xz extent
var surface_y := -6.5
var flow := Vector2(1, 0)
var mat: ShaderMaterial
var _player: Node3D
var _tick := 0.0
var _warned := false
var _corrupt := 0.0
var _ripple := 0.0
var _splash_cd := 0.0
var glow := Color(0.15, 0.85, 1.0)
var deep := Color(0.0, 0.12, 0.22)
var damage_per_sec := 7.0
var is_pool := false
var _pulse := 0.0

static func create(parent: Node, r: Rect2, y: float, flow_dir: Vector2, glow_c := Color(0.15, 0.85, 1.0), pool := false) -> GlowRiver:
	var g := GlowRiver.new()
	g.rect = r; g.surface_y = y; g.flow = flow_dir; g.glow = glow_c; g.is_pool = pool
	parent.add_child(g)
	g._build()
	return g

func _build() -> void:
	add_to_group("river")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	pm.subdivide_width = int(rect.size.x * 2.5)
	pm.subdivide_depth = int(rect.size.y * 2.5)
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/river.gdshader")
	mat.set_shader_parameter("flow_dir", flow)
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("deep_color", deep)
	if is_pool:
		mat.set_shader_parameter("flow_speed", 0.12)
		mat.set_shader_parameter("wave_height", 0.025)
	mi.material_override = mat
	mi.position = Vector3(rect.get_center().x, surface_y, rect.get_center().y)
	add_child(mi)
	# glow lights just above the surface (emission does not light the scene by itself)
	var step := 7.0
	var n := maxi(1, int(maxf(rect.size.x, rect.size.y) / step))
	for i in n:
		var l := OmniLight3D.new()
		l.light_color = glow
		l.light_energy = 1.6
		l.omni_range = 9.5
		l.omni_attenuation = 1.4
		l.light_volumetric_fog_energy = 0.6
		var along := (i + 0.5) / n
		if rect.size.x >= rect.size.y:
			l.position = Vector3(rect.position.x + rect.size.x * along, surface_y + 0.9, rect.get_center().y)
		else:
			l.position = Vector3(rect.get_center().x, surface_y + 0.9, rect.position.y + rect.size.y * along)
		l.set_script(load("res://scripts/world/flicker.gd"))
		add_child(l)
	# mist sheets drifting over the water
	for k in 2:
		var mist := MeshInstance3D.new()
		var mp := PlaneMesh.new(); mp.size = rect.size + Vector2(6, 6)
		mist.mesh = mp
		var mm := ShaderMaterial.new(); mm.shader = load("res://shaders/mist.gdshader")
		mm.set_shader_parameter("color", glow.lerp(Color(0.7, 0.85, 0.9), 0.55))
		mm.set_shader_parameter("density", 0.32 - k * 0.1)
		mm.set_shader_parameter("glow", 0.6)
		mm.set_shader_parameter("drift", Vector2(flow.x, flow.y) * (0.12 + k * 0.08))
		mm.set_shader_parameter("scale", 0.14 + k * 0.06)
		mist.material_override = mm
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.position = Vector3(rect.get_center().x, surface_y + 0.35 + k * 0.55, rect.get_center().y)
		add_child(mist)
	# drifting glowing motes rising off the river
	var motes := GPUParticles3D.new()
	motes.amount = int(clampf(rect.get_area() * 1.2, 40, 400))
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.visibility_aabb = AABB(Vector3(-rect.size.x, -2, -rect.size.y), Vector3(rect.size.x * 2, 14, rect.size.y * 2))
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(rect.size.x * 0.5, 0.1, rect.size.y * 0.5)
	ppm.direction = Vector3(flow.x, 4.0, flow.y).normalized()
	ppm.spread = 25.0
	ppm.initial_velocity_min = 0.25; ppm.initial_velocity_max = 0.7
	ppm.gravity = Vector3(0, 0.08, 0)
	ppm.turbulence_enabled = true
	ppm.turbulence_noise_strength = 1.2
	ppm.turbulence_noise_scale = 3.0
	ppm.scale_min = 0.4; ppm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0)); ramp.add_point(0.15, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new(); rt.gradient = ramp
	ppm.color_ramp = rt
	motes.process_material = ppm
	motes.draw_pass_1 = FX.quad(0.07)
	motes.material_override = FX.glow_material(glow.lightened(0.3), 3.0)
	motes.position = Vector3(rect.get_center().x, surface_y + 0.1, rect.get_center().y)
	add_child(motes)
	# volumetric glow (Forward+ only; ignored by the OpenGL fallback)
	var fog := FogVolume.new()
	fog.size = Vector3(rect.size.x + 2, 3.0, rect.size.y + 2)
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fm := FogMaterial.new()
	fm.density = 0.045
	fm.albedo = glow.lerp(Color.WHITE, 0.5)
	fm.emission = glow * 0.18
	fm.height_falloff = 0.6
	fm.edge_fade = 0.5
	fog.material = fm
	fog.position = Vector3(rect.get_center().x, surface_y + 1.0, rect.get_center().y)
	add_child(fog)
	if not is_pool:
		Sfx.loop_on(self, "loop_river", -4.0, 8.0, 40.0).position = mi.position

func contains(p: Vector3) -> bool:
	return rect.has_point(Vector2(p.x, p.z)) and p.y < surface_y + 0.4

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	_splash_cd -= delta
	var inside: bool = contains(_player.global_position) and _player.get("dead") != true
	var protected: bool = Game.equipped.artifact == "amulet_deep"
	var hspeed: float = Vector2(_player.velocity.x, _player.velocity.z).length() if "velocity" in _player else 0.0
	_ripple = lerpf(_ripple, (1.0 if inside else 0.0) * clampf(0.35 + hspeed / 5.0, 0.0, 1.2), 1.0 - exp(-4.0 * delta))
	_corrupt = lerpf(_corrupt, 1.0 if (inside and protected) else 0.0, 1.0 - exp(-1.5 * delta))
	mat.set_shader_parameter("ripple_pos", _player.global_position)
	mat.set_shader_parameter("ripple_strength", _ripple)
	mat.set_shader_parameter("corruption", _corrupt)
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	mat.set_shader_parameter("pulse", _pulse)
	if not inside:
		return
	if _splash_cd <= 0.0 and hspeed > 1.0:
		_splash_cd = 0.25
		var c := glow if not protected else Color(0.35, 1.0, 0.55)
		FX.burst(Vector3(_player.global_position.x, surface_y + 0.05, _player.global_position.z), c, 10, 2.5, 0.12, 0.6, -6.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	if protected:
		if Game.hp < Game.max_hp():
			_player.heal(5.0)
			FX.burst(_player.global_position + Vector3(0, 1.0, 0), Color(0.35, 1.0, 0.55), 6, 1.5, 0.12, 0.6, 1.0)
		Game.mana = minf(Game.max_mana(), Game.mana + 4.0)
		if not _warned:
			_warned = true
			Game.say("The amulet sings. The river's light mends you.", Color(0.4, 1.0, 0.6))
	else:
		_player.take_damage(damage_per_sec * 0.5 / maxf(0.2, 1.0 - Game.defense() / (Game.defense() + 45.0)), _player.global_position, 0.0)
		_pulse = 0.8
		if not _warned:
			_warned = true
			Game.say("The glowing water burns with arcane fire!", Color(0.5, 0.85, 1.0))
