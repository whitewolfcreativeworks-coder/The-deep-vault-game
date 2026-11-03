extends CharacterBody3D
class_name Warden
## The Vault Warden: a rune-bound stone golem guarding the Heart.
## Phase 1: sweeping strikes and a telegraphed ground slam.
## Phase 2 (<55%): summons Risen Bones, adds a leaping slam.
## Phase 3 (<25%): enraged, faster, core burns red.
## Shatters into physics debris on death.

signal defeated
signal health_changed(hp: float, max_hp: float)

enum S { DORMANT, AWAKEN, CHASE, SWIPE, SLAM, LEAP, SUMMON, RECOVER, DEAD }

var max_hp := 1450.0
var hp := 1450.0
const ARMOR := 0.8   # stone hide: takes 80% of incoming damage
var dead := false
var state := S.DORMANT
var st := 0.0
var cooldown := 1.0
var phase := 1
var facing := 0.0
var body: Humanoid
var player: Node3D
var hit_radius := 1.1
var display_name := "The Vault Warden"
var arena_center := Vector3.ZERO
var arena_radius := 13.0
var _telegraph: MeshInstance3D
var _tele_mat: ShaderMaterial
var _target := Vector3.ZERO
var _leap_from := Vector3.ZERO
var _summoned := false
var _hit_done := false
var _combo := 0
var _step_acc := 0.0
var summon_callback: Callable

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.95; cap.height = 4.2
	cs.shape = cap; cs.position.y = 2.1
	add_child(cs)
	body = Humanoid.new()
	add_child(body)
	body.setup({"style": "warden", "scale": 2.15})
	# kneel while dormant
	body.position.y = -0.9
	body.rotation.x = 0.35
	_telegraph = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2, 2)
	_telegraph.mesh = pm
	_tele_mat = ShaderMaterial.new(); _tele_mat.shader = load("res://shaders/rune.gdshader")
	_tele_mat.set_shader_parameter("color", Color(1.0, 0.35, 0.15))
	_tele_mat.set_shader_parameter("rings", 0.0)
	_telegraph.material_override = _tele_mat
	_telegraph.top_level = true
	_telegraph.visible = false
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_telegraph)
	facing = rotation.y
	rotation.y = 0
	body.rotation.y = facing

func awaken() -> void:
	if state != S.DORMANT:
		return
	_go(S.AWAKEN)
	Sfx.play_at("roar", global_position + Vector3(0, 3, 0), 4.0, 0.0, 20.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(body, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:x", 0.0, 1.6)
	FX.burst(global_position + Vector3(0, 1, 0), Color(0.6, 0.55, 0.5), 60, 7.0, 0.6, 1.6, -5.0)
	FX.burst(global_position + Vector3(0, 3, 0), Color(0.3, 0.75, 1.0), 40, 3.0, 0.25, 1.5, 1.0)
	health_changed.emit(hp, max_hp)

func _go(s: S) -> void:
	state = s
	st = 0.0
	_hit_done = false

func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	st += delta
	cooldown -= delta
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var pdead: bool = player.get("dead") == true
	var spd := 2.3 if phase < 3 else 3.2
	var tempo := 1.0 if phase < 3 else 0.72
	var move := Vector3.ZERO
	var want_face := facing
	body.attack_t = -1.0

	match state:
		S.DORMANT:
			return
		S.AWAKEN:
			if st > 2.0:
				_go(S.CHASE)
		S.CHASE:
			want_face = atan2(-to_p.x, -to_p.z)
			if pdead:
				move = Vector3.ZERO
			elif phase >= 2 and not _summoned:
				_go(S.SUMMON)
			elif cooldown <= 0.0:
				if phase >= 2 and dist > 7.0 and randf() < 0.65:
					_begin_leap()
				elif dist < 4.2:
					if randf() < 0.45 or _combo >= 2:
						_begin_slam()
					else:
						_go(S.SWIPE)
				elif dist > 9.0 and randf() < 0.35:
					_begin_slam()
				else:
					move = to_p.normalized()
			else:
				if dist > 3.2:
					move = to_p.normalized()
		S.SWIPE:
			want_face = atan2(-to_p.x, -to_p.z) if st < 0.45 * tempo else facing
			var dur := 1.15 * tempo
			body.attack_kind = 1
			body.attack_t = st / dur
			if not _hit_done and st >= dur * 0.48:
				_hit_done = true
				Sfx.play_at("swing", global_position + Vector3(0, 2, 0), 4.0, 0.0, 12.0)
				var fwd := -Vector3(sin(facing), 0, cos(facing))
				if dist < 5.2 and fwd.dot(to_p.normalized()) > 0.1 and not pdead:
					player.take_damage(26.0, global_position, 7.0)
			if st >= dur:
				_combo += 1
				cooldown = 0.6 * tempo
				_go(S.RECOVER)
		S.SLAM:
			var wind := 1.2 * tempo
			body.attack_kind = 2
			body.attack_t = clampf(st / (wind + 0.6), 0.0, 1.0)
			_tele_mat.set_shader_parameter("fill", clampf(st / wind, 0.0, 1.0) * 0.98)
			if not _hit_done and st >= wind:
				_hit_done = true
				_impact(_target, 4.8, 36.0)
			if st >= wind + 0.6:
				_combo = 0
				cooldown = 1.4 * tempo
				_go(S.RECOVER)
		S.LEAP:
			var air := 1.15 * tempo
			_tele_mat.set_shader_parameter("fill", clampf(st / air, 0.0, 1.0) * 0.98)
			var k := clampf(st / air, 0.0, 1.0)
			var pos := _leap_from.lerp(_target, smoothstep(0.15, 1.0, k))
			pos.y = _leap_from.y + sin(k * PI) * 6.0
			global_position = pos
			body.attack_kind = 2
			body.attack_t = 0.25 + k * 0.3
			if k >= 1.0 and not _hit_done:
				_hit_done = true
				global_position = _target
				_impact(_target, 5.5, 40.0)
			if st >= air + 0.8:
				cooldown = 1.2 * tempo
				_go(S.RECOVER)
		S.SUMMON:
			body.cast_t = clampf(st / 1.6, 0.0, 1.0)
			if st > 0.3 and not _hit_done:
				_hit_done = true
				_summoned = true
				Sfx.play_at("roar", global_position + Vector3(0, 3, 0), 2.0, 0.1, 20.0)
				Game.say("The Warden calls the dead to its side!", Color(1.0, 0.55, 0.4))
				if summon_callback.is_valid():
					summon_callback.call()
			if st > 1.6:
				body.cast_t = -1.0
				cooldown = 0.8
				_go(S.CHASE)
		S.RECOVER:
			if st > 0.55 * tempo:
				_go(S.CHASE)

	if state != S.LEAP:
		if move.length() > 0.0:
			var tv := move * spd
			velocity.x = lerpf(velocity.x, tv.x, 1.0 - exp(-5.0 * delta))
			velocity.z = lerpf(velocity.z, tv.z, 1.0 - exp(-5.0 * delta))
		else:
			velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * delta))
		velocity.y = -1.0 if is_on_floor() else velocity.y - 22.0 * delta
		move_and_slide()
		# never leave the arena
		var off := global_position - arena_center
		off.y = 0
		if off.length() > arena_radius:
			global_position = arena_center + off.normalized() * arena_radius + Vector3(0, global_position.y - arena_center.y, 0)
	facing = lerp_angle(facing, want_face, 1.0 - exp(-4.0 * delta))
	body.rotation.y = facing
	var hs := Vector2(velocity.x, velocity.z).length()
	body.move_speed = hs * 0.9
	_step_acc += hs * delta
	if _step_acc > 2.2:
		_step_acc = 0.0
		Sfx.play_at("slam", global_position, -14.0, 0.2, 10.0)
		if player.has_method("add_trauma") and dist < 12.0:
			player.add_trauma(0.08)

func _begin_slam() -> void:
	_go(S.SLAM)
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	_target = global_position + fwd * 2.8
	_show_telegraph(_target, 4.8)
	Sfx.play_at("skel_attack", global_position + Vector3(0, 2, 0), 2.0, 0.0, 12.0)

func _begin_leap() -> void:
	_go(S.LEAP)
	_leap_from = global_position
	_target = player.global_position
	_target.y = global_position.y
	_show_telegraph(_target, 5.5)
	Sfx.play_at("roar", global_position, -2.0, 0.2, 20.0)

func _show_telegraph(p: Vector3, radius: float) -> void:
	_telegraph.visible = true
	_telegraph.global_position = Vector3(p.x, arena_center.y + 0.06, p.z)
	_telegraph.scale = Vector3(radius, 1, radius)
	_tele_mat.set_shader_parameter("fill", 0.0)

func _impact(p: Vector3, radius: float, dmg: float) -> void:
	_telegraph.visible = false
	Sfx.play_at("slam", p, 6.0, 0.0, 20.0)
	FX.shockwave(p, Color(1.0, 0.45, 0.2), radius, 0.5)
	FX.flash_light(p + Vector3(0, 1, 0), Color(1.0, 0.5, 0.25), 8.0, 10.0, 0.4)
	if player.has_method("add_trauma"):
		player.add_trauma(0.55)
	var d := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length()
	if d < radius and player.get("dead") != true and player.global_position.y < p.y + 1.5:
		player.take_damage(dmg, p, 9.0)

func take_damage(amount: float, from_pos: Vector3, _knock := 0.0, crit := false) -> void:
	if dead or state == S.DORMANT:
		return
	amount *= ARMOR
	hp -= amount
	body.flash(Color(1, 1, 1), 0.6)
	Sfx.play_at("hit", global_position + Vector3(0, 2, 0), 0.0, 0.1)
	Sfx.play_at("clang", global_position + Vector3(0, 2, 0), -12.0, 0.2)
	var hit_p := global_position + Vector3(0, 2.0, 0) + (from_pos - global_position).normalized() * 0.9
	FX.hit(hit_p, Color(0.7, 0.85, 1.0))
	FX.damage_number(global_position + Vector3(0, 4.6, 0), amount, Color(1, 1, 1), crit)
	health_changed.emit(maxf(hp, 0.0), max_hp)
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("on_enemy_hit"):
		tree.current_scene.on_enemy_hit(self)
	if hp <= 0.0:
		_die(from_pos)
		return
	if phase == 1 and hp < max_hp * 0.55:
		phase = 2
	if phase == 2 and hp < max_hp * 0.25:
		phase = 3
		Game.say("The Warden's core blazes with fury!", Color(1.0, 0.4, 0.2))
		Sfx.play_at("roar", global_position + Vector3(0, 3, 0), 6.0, 0.0, 25.0)
		for mi in body.all_meshes:
			var m := mi.material_override
			if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
				var m2 := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				m2.emission = Color(1.0, 0.3, 0.1)
				m2.albedo_color = Color(1.0, 0.35, 0.15)
				mi.material_override = m2

func _die(from_pos: Vector3) -> void:
	dead = true
	_go(S.DEAD)
	_telegraph.visible = false
	remove_from_group("enemy")
	remove_from_group("damageable")
	collision_layer = 0
	Sfx.play_at("roar", global_position + Vector3(0, 3, 0), 6.0, 0.0, 30.0)
	Sfx.play_at("slam", global_position, 6.0, 0.0, 30.0)
	FX.burst(global_position + Vector3(0, 2.5, 0), Color(1.0, 0.65, 0.3), 90, 8.0, 0.35, 2.0, -2.0)
	FX.flash_light(global_position + Vector3(0, 2, 0), Color(1.0, 0.6, 0.3), 12.0, 18.0, 1.5)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.8)
	var away := global_position - from_pos
	away.y = 0
	body.shatter(away.normalized() * 0.6, 4.0, 14.0)
	Game.kills += 1
	Game.add_xp(600)
	Game.flags["warden_dead"] = true
	Pickup.spawn(global_position + Vector3(0, 1.5, 0), "item", 1, "warden_plate")
	for i in 6:
		Pickup.spawn(global_position + Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)), "gold", randi_range(15, 30))
	Pickup.spawn(global_position + Vector3(0.5, 1.2, 0.5), "potion", 1)
	defeated.emit()
