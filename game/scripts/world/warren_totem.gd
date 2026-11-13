extends Node3D
class_name WarrenTotem
## A goblin War Totem: a carved, skull-topped pole with burning eyes. Two of
## them hold Chief Gruk's gate shut. Hit one enough and it cracks apart.

signal broken(t: WarrenTotem)

var uid := ""
var hp := 260.0
var max_hp := 260.0
var dead := false
var hit_radius := 0.8
var _eyes: Array[MeshInstance3D] = []
var _parts: Array[MeshInstance3D] = []
var _flash: StandardMaterial3D

static func make(parent: Node, pos: Vector3, id: String) -> WarrenTotem:
	var t := WarrenTotem.new()
	t.uid = id
	parent.add_child(t)
	t.global_position = pos
	if Game.flags.get(id, false):
		t.queue_free()
		return null
	return t

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("warren_totem")
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1, 1, 1, 0)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.42, 0.28, 0.16); wood.roughness = 0.9
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color(0.75, 0.15, 0.1); paint.roughness = 0.7
	var bone := StandardMaterial3D.new(); bone.albedo_color = Color(0.9, 0.86, 0.72)
	# carved stacked faces
	for k in 3:
		var y := 0.5 + k * 0.9
		_box(Vector3(0.9 - k * 0.08, 0.85, 0.9 - k * 0.08), wood, Vector3(0, y, 0))
		_box(Vector3(0.7, 0.12, 0.95 - k * 0.08), paint, Vector3(0, y + 0.25, 0))
		_box(Vector3(0.5, 0.1, 0.08), Color(0.1, 0.05, 0.03), Vector3(0, y - 0.18, 0.46 - k * 0.04))   # mouth
		for sx in [-0.18, 0.18]:
			var eye := _box(Vector3(0.14, 0.1, 0.06), Color(1, 1, 1), Vector3(sx, y + 0.08, 0.47 - k * 0.04))
			eye.material_override = FX.glow_material(Color(1.0, 0.45, 0.1), 3.0)
			_eyes.append(eye)
	# a big skull on top, with horns
	var sk := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.38; sm.height = 0.7
	sk.mesh = sm; sk.material_override = bone; sk.position.y = 3.25; add_child(sk); _parts.append(sk)
	for sx in [-1.0, 1.0]:
		var h := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.1; cm.height = 0.6
		h.mesh = cm; h.material_override = bone; h.position = Vector3(sx * 0.4, 3.45, 0); h.rotation.z = -sx * 0.9
		add_child(h); _parts.append(h)
	for p in _parts:
		p.material_overlay = _flash
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.45, 0.15); l.light_energy = 2.5; l.omni_range = 7.0
	l.position.y = 2.5; add_child(l)
	var fire := CPUParticles3D.new(); fire.amount = 30; fire.lifetime = 0.8
	fire.mesh = FX.quad(0.3); fire.material_override = FX.glow_material(Color(1.0, 0.5, 0.15), 3.0)
	fire.direction = Vector3.UP; fire.spread = 15; fire.initial_velocity_min = 1.0; fire.initial_velocity_max = 2.0
	fire.gravity = Vector3(0, 1.5, 0); fire.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.15))
	fire.position.y = 3.6; add_child(fire)
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.0, 3.5, 1.0)
	cs.shape = bs; cs.position.y = 1.75; sb.add_child(cs)

func _box(size: Vector3, m, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	if m is Color:
		var sm := StandardMaterial3D.new(); sm.albedo_color = m; mi.material_override = sm
	else:
		mi.material_override = m
	mi.position = pos
	add_child(mi); _parts.append(mi)
	return mi

func take_damage(amount: float, _from: Vector3, _knock := 0.0, _crit := false) -> void:
	if dead:
		return
	hp -= amount
	_flash.albedo_color = Color(1.0, 0.8, 0.5, 0.7)
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.2)
	Sfx.play_at("hit", global_position, -4.0, 0.15)
	FX.burst(global_position + Vector3(0, 1.5, 0), Color(0.6, 0.4, 0.25), 12, 3.0, 0.2, 0.5, -6.0)
	var shake := create_tween()
	shake.tween_property(self, "rotation:z", 0.06, 0.05)
	shake.tween_property(self, "rotation:z", 0.0, 0.08)
	if hp <= 0.0:
		_break()

func _break() -> void:
	dead = true
	remove_from_group("damageable")
	remove_from_group("warren_totem")
	Game.flags[uid] = true
	Sfx.play_at("bone_break", global_position, 0.0)
	Sfx.play_at("fire_burst", global_position, -2.0)
	FX.burst(global_position + Vector3(0, 1.8, 0), Color(0.55, 0.38, 0.22), 60, 6.0, 0.35, 1.0, -9.0)
	FX.burst(global_position + Vector3(0, 3.2, 0), Color(1.0, 0.5, 0.15), 50, 5.0, 0.25, 0.8, 0.0)
	FX.flash_light(global_position + Vector3(0, 2, 0), Color(1.0, 0.5, 0.2), 8.0, 10.0, 0.4)
	broken.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(queue_free)
