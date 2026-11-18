extends CharacterBody3D
class_name GhostHorse
## One of Pip's spooked horses, gone see-through with fright. It wanders the
## moor; walk up and give it an apple (USE) and it calms down and follows you.
## Lead it into the stable paddock in the village to bring it home.

var uid := ""
var home := Vector3.ZERO           # where it wanders
var paddock := Rect2()             # village stable paddock (x/z)
var calm := false
var player: Player
var _t := 0.0
var _target := Vector3.ZERO
var _wait := 0.0
var _facing := 0.0
var _vis: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _mat: StandardMaterial3D
var _done := false
var _spook_t := 0.0
var _bolt := 0.0
var _picked := 0.0
var _stuck_t := 0.0

static func make(parent: Node3D, pos: Vector3, id: String, pad: Rect2) -> GhostHorse:
	var h := GhostHorse.new()
	h.uid = id
	h.paddock = pad
	h.position = pos
	parent.add_child(h)
	h.home = pos
	return h

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ghost_horse")
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); sh.radius = 0.5; sh.height = 1.6
	cs.shape = sh; cs.position.y = 0.9; add_child(cs)
	_build()
	_facing = randf() * TAU

func _build() -> void:
	_vis = Node3D.new(); add_child(_vis)
	_mat = StandardMaterial3D.new(); _mat.albedo_color = Color(0.7, 0.85, 1.0, 0.55)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.55, 0.9); _mat.emission_energy_multiplier = 0.8; _mat.roughness = 0.3
	var mane := StandardMaterial3D.new(); mane.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	mane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mane.emission_enabled = true; mane.emission = Color(0.6, 0.85, 1.0)
	mane.emission_energy_multiplier = 1.5
	_ball(_vis, 0.45, _mat, Vector3(0, 1.25, 0.1), Vector3(0.85, 0.85, 1.9))
	var neck := Node3D.new(); neck.position = Vector3(0, 1.5, -0.7); _vis.add_child(neck)
	_ball(neck, 0.22, _mat, Vector3(0, 0.3, -0.1), Vector3(1, 2.0, 1)).rotation.x = 0.5
	_head = Node3D.new(); _head.position = Vector3(0, 0.75, -0.35); neck.add_child(_head)
	_ball(_head, 0.2, _mat, Vector3(0, 0, -0.15), Vector3(0.85, 0.9, 1.8))
	for sx in [-1.0, 1.0]:
		var ear := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.05; cm.height = 0.2
		ear.mesh = cm; ear.material_override = _mat; ear.position = Vector3(sx * 0.1, 0.2, 0.05); _head.add_child(ear)
		_ball(_head, 0.035, mane, Vector3(sx * 0.13, 0.05, -0.2))
	for k in 5:
		_ball(neck, 0.09, mane, Vector3(0, 0.15 + k * 0.17, 0.08 + k * 0.03), Vector3(0.6, 1.4, 1.0))
	_tail = Node3D.new(); _tail.position = Vector3(0, 1.4, 0.9); _vis.add_child(_tail)
	_ball(_tail, 0.12, mane, Vector3(0, -0.3, 0.15), Vector3(0.7, 2.6, 0.7)).rotation.x = -0.4
	for p in [Vector3(-0.22, 1.0, -0.6), Vector3(0.22, 1.0, -0.6), Vector3(-0.22, 1.0, 0.7), Vector3(0.22, 1.0, 0.7)]:
		var leg := Node3D.new(); leg.position = p; _vis.add_child(leg); _legs.append(leg)
		var lm := MeshInstance3D.new(); var lc := CylinderMesh.new(); lc.top_radius = 0.09; lc.bottom_radius = 0.07; lc.height = 1.0
		lm.mesh = lc; lm.material_override = _mat; lm.position.y = -0.5; leg.add_child(lm)
	var l := OmniLight3D.new(); l.light_color = Color(0.55, 0.8, 1.0); l.light_energy = 0.8; l.omni_range = 4.0; l.position.y = 1.4
	add_child(l)

func _ball(parent: Node3D, r: float, m: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
	parent.add_child(mi)
	return mi

func can_interact() -> bool:
	return not calm and not _done and Game.quest_state("wraith_hunt") == "active"

func get_prompt() -> String:
	return "[E] Offer an apple to the frightened horse"

func interact(by: Node) -> void:
	if not (by is Player) or calm:
		return
	player = by as Player
	calm = true
	Sfx.play_at("whistle", global_position, -6.0, 0.2)
	FX.burst(global_position + Vector3(0, 1.8, 0), Color(1.0, 0.6, 0.7), 20, 2.0, 0.15, 0.9, 1.0)
	Game.say("The horse munches the apple and calms down. It will follow you: lead it to Pip's paddock in the village!", Color(0.75, 0.9, 1.0))

func _physics_process(delta: float) -> void:
	_t += delta
	if _done:
		_head.rotation.x = maxf(0.0, sin(_t * 0.7 + float(uid.hash() % 7))) * 0.7     # grazing
		_tail.rotation.x = sin(_t * 2.0) * 0.15
		return
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5
	var dir := Vector3.ZERO
	var spd := 0.0
	if calm and player and is_instance_valid(player) and not player.dead:
		var to := player.global_position - global_position; to.y = 0
		if to.length() > 30.0:
			global_position = player.global_position + Vector3(2, 0.5, 2)       # never lose your horse
		elif to.length() > 3.0:
			dir = to.normalized(); spd = clampf(to.length() * 1.2, 2.0, 7.5)
			# stuck behind a cart or a tree? it's a ghost: it fades and pops up beside you
			if Vector2(get_real_velocity().x, get_real_velocity().z).length() < 0.6:
				_stuck_t += delta
			else:
				_stuck_t = maxf(0.0, _stuck_t - delta)
			if _stuck_t > 1.6:
				_stuck_t = 0.0
				FX.burst(global_position + Vector3(0, 1.2, 0), Color(0.75, 0.9, 1.0), 24, 3.0, 0.15, 0.6, 0.0)
				var behind := -Vector3(sin(player.facing), 0, cos(player.facing)) * -2.5
				global_position = player.global_position + behind + Vector3(0, 0.5, 0)
				velocity = Vector3.ZERO
				FX.burst(global_position + Vector3(0, 1.2, 0), Color(0.75, 0.9, 1.0), 24, 3.0, 0.15, 0.6, 0.0)
		else:
			_stuck_t = 0.0
		# a wraith close by spooks it again: it bolts away and you have to calm it again
		_spook_t -= delta
		if _spook_t <= 0.0:
			_spook_t = 0.25
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and not e.dead and e.type_id == "wraith" and e.global_position.distance_to(global_position) < 4.0:
					calm = false
					var away: Vector3 = global_position - e.global_position; away.y = 0
					away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
					home = global_position + away * 10.0
					_target = home
					_wait = 0.0
					_bolt = 1.6
					Game.say("A wraith wails and the horse bolts! Beat the wraith, then calm the horse again.", Color(1.0, 0.6, 0.5))
					Sfx.play_at("hurt", global_position, -6.0, 0.3)
					break
		if paddock.has_point(Vector2(global_position.x, global_position.z)):
			_arrive()
			return
	else:
		# wander about near where it ran to, stopping now and then to graze
		var to2 := _target - global_position; to2.y = 0
		if _bolt > 0.0:
			_bolt -= delta
			dir = to2.normalized() if to2.length() > 0.5 else Vector3.ZERO
			spd = 8.0
		elif _wait > 0.0:
			_wait -= delta
		elif to2.length() < 0.6 or get_slide_collision_count() > 0 and _t - _picked > 2.0:
			_wait = randf_range(1.5, 4.0)
			var a := randf() * TAU
			_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0)
			_picked = _t
		else:
			dir = to2.normalized(); spd = 1.8
	velocity.x = lerpf(velocity.x, dir.x * spd, 1.0 - exp(-6.0 * delta))
	velocity.z = lerpf(velocity.z, dir.z * spd, 1.0 - exp(-6.0 * delta))
	move_and_slide()
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.3:
		_facing = lerp_angle(_facing, atan2(-velocity.x, -velocity.z), 1.0 - exp(-6.0 * delta))
	_vis.rotation.y = _facing
	var s := hv.length()
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * (5.0 + s * 1.5) + (PI if i in [0, 3] else 0.0)) * clampf(s * 0.15, 0.0, 0.6)
	_tail.rotation.x = sin(_t * 3.0) * 0.2
	_head.rotation.x = 0.0 if s > 0.5 else maxf(0.0, sin(_t * 1.3)) * 0.6
	_mat.albedo_color.a = (0.75 if calm else 0.5) + sin(_t * 2.0) * 0.1

func _arrive() -> void:
	Game.flags[uid] = true
	Game.on_quest_item("horse")
	Sfx.play("levelup", -8.0, 0.1)
	FX.burst(global_position + Vector3(0, 1.4, 0), Color(0.75, 0.9, 1.0), 40, 3.0, 0.2, 1.0, 1.0)
	Game.say("Home safe! The fright wears off and the horse is solid again.", Color(0.75, 0.95, 1.0))
	settle(true)

## Home in the paddock: no longer a ghost, it grazes there for good.
func settle(animate := false, y := INF) -> void:
	_done = true
	calm = true
	remove_from_group("interactable")
	var c := paddock.get_center()
	var k := int(uid.right(1)) if uid.right(1).is_valid_int() else 0
	var spot := Vector3(c.x - 3.0 + (k % 2) * 4.0, global_position.y if y == INF else y, c.y - 2.5 + floorf(k / 2.0) * 5.0)
	var solid := Color(0.45, 0.3, 0.18) if k % 2 == 0 else Color(0.9, 0.88, 0.82)
	var glow := Color(0.0, 0.0, 0.0)
	if animate:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "global_position", spot, 2.0)
		tw.tween_property(_mat, "albedo_color", solid, 2.0)
		tw.tween_property(_mat, "emission", glow, 2.0)
		tw.tween_property(_vis, "rotation:y", randf() * TAU, 2.0)
	else:
		global_position = spot
		_mat.albedo_color = solid
		_mat.emission = glow
		_vis.rotation.y = randf() * TAU
	for l in find_children("*", "OmniLight3D", false, false):
		(l as Node).queue_free()
