extends CharacterBody3D
class_name Enemy
## State-machine dungeon enemy (KayKit skeleton rigs).
## Types: minion, warrior, mage (ranged), revenant (heavy, intermediate).

signal died(enemy: Enemy)

const TYPES := {
	"minion": {"name": "Risen Bones", "variant": "minion", "hp": 48.0, "dmg": 11.0, "speed": 3.4, "range": 1.8,
		"windup": 0.42, "cooldown": 1.0, "xp": 30, "weapon": "skel_blade", "shield": "", "eye": Color(0.3, 0.85, 1.0),
		"scale": 0.84, "aggro": 11.0, "poise": 0.0, "gold": [2, 8]},
	"warrior": {"name": "Vault Sentinel", "variant": "warrior", "hp": 80.0, "dmg": 13.0, "speed": 2.9, "range": 1.9,
		"windup": 0.5, "cooldown": 1.35, "xp": 55, "weapon": "skel_axe", "shield": "Skeleton_Shield_Small_A", "eye": Color(1.0, 0.7, 0.2),
		"scale": 0.88, "aggro": 11.0, "poise": 10.0, "gold": [5, 14]},
	"mage": {"name": "Bone Hexer", "variant": "mage", "hp": 46.0, "dmg": 11.0, "speed": 2.6, "range": 11.0,
		"windup": 0.7, "cooldown": 2.4, "xp": 50, "weapon": "skel_staff", "shield": "", "eye": Color(0.4, 1.0, 0.5),
		"scale": 0.84, "aggro": 15.0, "poise": 0.0, "gold": [6, 16], "ranged": true},
	"revenant": {"name": "Hollow Revenant", "variant": "warrior", "hp": 190.0, "dmg": 24.0, "speed": 2.5, "range": 2.6,
		"windup": 0.85, "cooldown": 1.9, "xp": 120, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(1.0, 0.25, 0.15),
		"scale": 1.25, "aggro": 13.0, "poise": 30.0, "gold": [20, 35], "heavy": true},
}

enum S { DORMANT, AWAKEN, IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, RETURN, DEAD }

var type_id := "minion"
var t: Dictionary
var uid := ""
var hp := 40.0
var max_hp := 40.0
var dead := false
var state := S.IDLE
var state_time := 0.0
var cooldown := 0.0
var home := Vector3.ZERO
var leash := 18.0
var dormant_wake := 0.0     # >0 : lies in the floor until the player comes within this range
var body: CharacterModel
var hit_radius := 0.45
var facing := 0.0
var player: Node3D
var display_name := ""
var bounds := AABB()        # optional room bounds the enemy will not leave
var _strafe := 1.0
var _hurt_t := -1.0
var _stagger_acc := 0.0

func configure(type_name: String, id: String, wake_range := 0.0) -> void:
	type_id = type_name
	uid = id
	dormant_wake = wake_range

func _ready() -> void:
	t = TYPES[type_id]
	display_name = t.name
	add_to_group("enemy")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	max_hp = t.hp
	hp = max_hp
	hit_radius = 0.45 * t.scale / 0.84
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.38 * t.scale / 0.84; cap.height = 1.7 * t.scale / 0.84
	cs.shape = cap; cs.position.y = cap.height * 0.5
	add_child(cs)
	body = CharacterModel.new()
	add_child(body)
	body.setup({"kind": "skeleton", "variant": t.variant, "weapon": t.weapon, "shield": t.shield, "eye": t.eye, "scale": t.scale})
	home = global_position
	facing = rotation.y
	rotation.y = 0
	body.rotation.y = facing
	_strafe = 1.0 if randf() > 0.5 else -1.0
	if dormant_wake > 0.0:
		state = S.DORMANT
		body.visible = false
		cs.disabled = true
		set_physics_process(true)

func _go(s: S) -> void:
	state = s
	state_time = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	state_time += delta
	cooldown -= delta
	if _hurt_t >= 0.0:
		_hurt_t += delta
		if _hurt_t > 0.35:
			_hurt_t = -1.0
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var pdead: bool = player.get("dead") == true
	var move := Vector3.ZERO
	var spd: float = t.speed

	match state:
		S.DORMANT:
			if dist < dormant_wake and not pdead:
				_awaken()
			return
		S.AWAKEN:
			if state_time > 1.6:
				_go(S.CHASE)
		S.IDLE:
			if not pdead and dist < t.aggro and _in_bounds(player.global_position):
				_go(S.CHASE)
				Sfx.play_at("skel_attack", global_position, -10.0)
		S.CHASE:
			if pdead or dist > t.aggro * 2.2 or global_position.distance_to(home) > leash or not _in_bounds(player.global_position, 3.0):
				_go(S.RETURN)
			elif t.get("ranged", false):
				# keep a comfortable distance and circle
				var want := 8.0
				var side := to_p.normalized().cross(Vector3.UP) * _strafe
				if dist < want - 2.0:
					move = -to_p.normalized() + side * 0.5
				elif dist > want + 2.5:
					move = to_p.normalized()
				else:
					move = side * 0.7
				if state_time > 2.5:
					_strafe *= -1.0; state_time = 0.0
				if cooldown <= 0.0 and dist < t.range and _has_los():
					_go(S.WINDUP)
			else:
				move = to_p.normalized()
				if dist < t.range * 0.9 and cooldown <= 0.0:
					_go(S.WINDUP)
				elif dist < t.range * 0.9:
					move = to_p.normalized().cross(Vector3.UP) * _strafe * 0.4  # circle while waiting
		S.WINDUP:
			if state_time == delta or state_time < delta * 1.5:
				var kind := 2 if t.get("heavy", false) else randi() % 2
				body.attack_kind = kind
				body.attack_dur = t.windup + 0.45
				body.attack_t = 0.0
				body.flash(t.eye, 0.35)
				if t.get("ranged", false):
					body.cast_t = 0.0
					body.attack_t = -1.0
			if state_time >= t.windup:
				_go(S.STRIKE)
				_strike(dist, to_p)
		S.STRIKE:
			if state_time > 0.15:
				_go(S.RECOVER)
		S.RECOVER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.35:
				cooldown = t.cooldown * randf_range(0.8, 1.2)
				_go(S.CHASE)
		S.STAGGER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.4:
				_go(S.CHASE)
		S.RETURN:
			var th := home - global_position; th.y = 0
			if th.length() < 0.6:
				_go(S.IDLE)
				hp = minf(max_hp, hp + max_hp * 0.5)
			else:
				move = th.normalized()
			if not pdead and dist < t.aggro * 0.7 and global_position.distance_to(home) < leash * 0.6:
				_go(S.CHASE)

	# separation from other enemies
	for o in get_tree().get_nodes_in_group("enemy"):
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var l := d.length()
		if l < 1.3 and l > 0.01:
			move += d / l * (1.3 - l) * 1.5
	if move.length() > 1.0:
		move = move.normalized()
	if state in [S.WINDUP, S.STRIKE, S.RECOVER, S.STAGGER, S.AWAKEN]:
		move = Vector3.ZERO
	var target_v := move * spd
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-8.0 * delta))
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	# face the player while engaged; face movement otherwise
	var want_face := facing
	if state in [S.CHASE, S.WINDUP] and dist > 0.1:
		want_face = atan2(-to_p.x, -to_p.z)
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		want_face = atan2(-velocity.x, -velocity.z)
	var turn := 5.0 if state == S.WINDUP and t.get("heavy", false) else 9.0
	facing = lerp_angle(facing, want_face, 1.0 - exp(-turn * delta))
	body.rotation.y = facing
	body.move_speed = Vector2(velocity.x, velocity.z).length()
	body.grounded = true
	body.hurt_t = _hurt_t / 0.35 if _hurt_t >= 0.0 else -1.0
	if state == S.WINDUP and not t.get("ranged", false):
		body.attack_t = state_time / (t.windup + 0.45)

func _in_bounds(p: Vector3, margin := 0.0) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var b := bounds.grow(margin)
	return p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z

func _has_los() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _awaken() -> void:
	_go(S.AWAKEN)
	body.visible = true
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	body.play_role("spawn", 1.5)
	FX.burst(global_position + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 30, 3.0, 0.4, 1.0, -4.0)
	FX.burst(global_position + Vector3(0, 0.5, 0), t.eye, 14, 1.5, 0.2, 0.9, 1.0)
	Sfx.play_at("bone_break", global_position, -2.0)
	var to_p: Vector3 = player.global_position - global_position
	facing = atan2(-to_p.x, -to_p.z)
	body.rotation.y = facing

func _strike(dist: float, to_p: Vector3) -> void:
	if t.get("ranged", false):
		var b := Area3D.new()
		b.set_script(load("res://scripts/player/projectile.gd"))
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector3(0, 1.5, 0) + (-Vector3(sin(facing), 0, cos(facing))) * 0.6
		var aim: Vector3 = (player.global_position + Vector3(0, 1.1, 0)) - b.global_position
		b.launch(aim, "enemy", t.dmg, t.eye, 13.0)
		b.homing = 1.2
		Sfx.play_at("spell", global_position, -6.0)
		return
	Sfx.play_at("swing", global_position, -4.0, 0.15)
	if t.get("heavy", false):
		Sfx.play_at("slam", global_position, -6.0)
		FX.shockwave(global_position + (-Vector3(sin(facing), 0, cos(facing))) * 1.6, Color(1.0, 0.4, 0.2), 2.6, 0.35)
		if player.has_method("add_trauma"):
			player.add_trauma(0.3)
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var reach: float = t.range + 0.35
	if dist < reach and (dist < 0.6 or fwd.dot(to_p.normalized()) > 0.35) and player.get("dead") != true:
		player.take_damage(t.dmg * randf_range(0.9, 1.1), global_position, 5.0 if t.get("heavy", false) else 3.0)

func take_damage(amount: float, from_pos: Vector3, knock := 2.5, crit := false) -> void:
	if dead:
		return
	if state == S.DORMANT:
		_awaken()
	hp -= amount
	body.flash(Color(1, 1, 1), 0.85)
	Sfx.play_at("hit", global_position + Vector3(0, 1, 0), -3.0, 0.15)
	FX.hit(global_position + Vector3(0, 1.1, 0), Color(1.0, 0.9, 0.7))
	FX.damage_number(global_position + Vector3(0, 2.0 * t.scale / 0.84, 0), amount, Color(1, 1, 1), crit)
	Game.emit_signal("stats_changed")
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("on_enemy_hit"):
		tree.current_scene.on_enemy_hit(self)
	var away := global_position - from_pos
	away.y = 0
	if hp <= 0.0:
		_die(away)
		return
	if state in [S.IDLE, S.RETURN]:
		_go(S.CHASE)
	_stagger_acc += amount
	if _stagger_acc > t.poise:
		_stagger_acc = 0.0
		if away.length() > 0.01:
			var k := away.normalized() * knock
			velocity.x += k.x; velocity.z += k.z
		if state != S.STRIKE:
			_go(S.STAGGER)
			_hurt_t = 0.0

func _die(away: Vector3) -> void:
	dead = true
	_go(S.DEAD)
	remove_from_group("enemy")
	remove_from_group("damageable")
	collision_layer = 0
	collision_mask = 1
	body.collapse()
	Sfx.play_at("bone_break", global_position, 0.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), t.eye, 24, 2.5, 0.25, 1.0, 1.0)
	Game.kills += 1
	Game.add_xp(t.xp)
	if uid != "":
		Game.flags[uid] = true
	_drop_loot()
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(body, "position:y", -1.2, 1.5)
	tw.tween_callback(queue_free)

func _drop_loot() -> void:
	var g: Array = t.gold
	Pickup.spawn(global_position + Vector3(0, 0.6, 0), "gold", randi_range(g[0], g[1]))
	var table := "summon" if uid == "" else type_id
	var k := 0
	for d in Loot.roll_enemy(table, Loot.area_level(global_position.z)):
		k += 1
		var off := Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.5
		Pickup.spawn(global_position + Vector3(0, 0.7, 0) + off, d.kind, int(d.get("amount", 1)), String(d.get("id", "")))
