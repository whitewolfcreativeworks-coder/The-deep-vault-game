extends Area3D
## Magic bolt shared by the player (arcane bolt) and enemy casters.
## Lightly homes toward the nearest valid target in front of it.

var team := "player"
var damage := 20.0
var speed := 22.0
var color := Color(0.45, 0.7, 1.0)
var dir := Vector3.FORWARD
var life := 3.0
var homing := 2.5
var size := 1.0
var splash := 0.0       # >0: the explosion also hurts enemies within this radius
var _done := false
var _light: OmniLight3D

func launch(d: Vector3, t: String, dmg: float, c: Color, spd: float) -> void:
	dir = d.normalized(); team = t; damage = dmg; color = c; speed = spd
	collision_layer = 0
	collision_mask = 1 | (4 if team == "player" else 2)
	monitoring = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new(); s.radius = 0.25
	cs.shape = s
	add_child(cs)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.13 * size; sm.height = 0.26 * size
	core.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.6)
	m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = 6.0
	core.material_override = m
	add_child(core)
	var trail := CPUParticles3D.new()
	trail.amount = 40; trail.lifetime = 0.45; trail.local_coords = false
	trail.mesh = FX.quad(0.28 * size)
	trail.material_override = FX.glow_material(color, 1.6)
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.1; trail.initial_velocity_max = 0.6
	trail.spread = 180
	trail.scale_amount_min = 0.4; trail.scale_amount_max = 1.0
	trail.color_ramp = FX._fade_ramp(color)
	add_child(trail)
	_light = OmniLight3D.new()
	_light.light_color = color; _light.light_energy = 2.5; _light.omni_range = 4.0
	add_child(_light)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	if life <= 0.0:
		_explode()
		return
	var tgt := _find_target()
	if tgt:
		var want: Vector3 = ((tgt.global_position + Vector3(0, 1.0, 0)) - global_position).normalized()
		dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	global_position += dir * speed * delta

func _find_target() -> Node3D:
	var group := "enemy" if team == "player" else "player"
	var best: Node3D = null
	var best_d := 14.0
	for n in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(n) or n.get("dead") == true:
			continue
		var to: Vector3 = (n.global_position + Vector3(0, 1.0, 0)) - global_position
		var d := to.length()
		if d < best_d and dir.dot(to / maxf(d, 0.01)) > 0.75:
			best_d = d
			best = n
	return best

func _on_body(b: Node) -> void:
	if _done:
		return
	if b.has_method("take_damage"):
		if (team == "player" and b.is_in_group("enemy")) or (team == "enemy" and b.is_in_group("player")):
			b.take_damage(damage, global_position - dir * 2.0, 3.0, false)
	_explode()

func _explode() -> void:
	_done = true
	if splash > 0.0 and team == "player":
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.get("dead") != true and e is Node3D and (e as Node3D).global_position.distance_to(global_position) < splash + 0.8:
				e.take_damage(damage * 0.5, global_position, 3.0, false)
		FX.dome(global_position - Vector3(0, 0.6, 0), color, splash, 0.3)
	FX.burst(global_position, color, int(26 * size), 4.0 * size, 0.22 * size, 0.5, 0.0)
	FX.flash_light(global_position, color, 5.0, 6.0, 0.3)
	Sfx.play_at("spell_hit", global_position, -4.0)
	queue_free()
