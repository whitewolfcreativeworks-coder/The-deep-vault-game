extends CharacterBody3D
class_name Player
## The adventurer. Movement, the continuous 1st/3rd-person zoom camera,
## melee combo, shield block, dodge roll, arcane bolt, potions, interaction.

signal interact_target_changed(text: String)

const WALK := 4.4
const SPRINT := 7.2
const ACCEL := 14.0
const AIR_ACCEL := 4.0
const GRAVITY := 22.0
const JUMP_V := 7.6
const EYE_H := 1.62
const FP_THRESHOLD := 0.45
const MAX_ZOOM := 9.0
const MOUSE_SENS := 0.0024

var body: CharacterModel
var cam_yaw: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var zoom := 3.6
var zoom_target := 3.6
var first_person := false
var trauma := 0.0
var input_enabled := true
var mouse_captured := false

var yaw := 0.0          # camera yaw (radians)
var pitch := -0.25
var facing := 0.0       # body yaw

var attacking := false
var attack_time := 0.0
var attack_dur := 0.55
var combo := 0
var combo_queued := false
var hit_done := false
var casting := false
var cast_time := 0.0
var dodging := false
var dodge_time := 0.0
var dodge_dir := Vector3.ZERO
var invuln := 0.0
var blocking := false
var stamina_delay := 0.0
var potion_cd := 0.0
var hurt_time := -1.0
var dead := false
var step_accum := 0.0
var in_river := false
var river_tick := 0.0
var interact_target: Node = null
var damage_taken := 0.0
var bolts_fired := 0
var _last_prompt := ""
var bolt_scene_script := preload("res://scripts/player/projectile.gd")

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.34; cap.height = 1.8
	cs.shape = cap; cs.position.y = 0.9
	add_child(cs)
	body = CharacterModel.new()
	body.name = "Body"
	add_child(body)
	rebuild_body()
	# camera rig is top-level so body rotation never drags it
	cam_yaw = Node3D.new(); cam_yaw.name = "CamYaw"; cam_yaw.top_level = true
	add_child(cam_yaw)
	cam_pitch = Node3D.new(); cam_yaw.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.collision_mask = 1
	spring.margin = 0.25
	var probe := SphereShape3D.new(); probe.radius = 0.22
	spring.shape = probe
	cam_pitch.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 300.0
	spring.add_child(camera)
	Game.inventory_changed.connect(_on_inventory_changed)
	cam_yaw.global_position = global_position + Vector3(0, EYE_H, 0)

func rebuild_body() -> void:
	var p := Game.profile
	var cfg := {
		"kind": "hero", "hero": p.hero, "show_hat": p.show_hat,
		"weapon": Game.equipped.weapon, "shield": _shield_for_armor(), "scale": 0.84,
	}
	if p.cape > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
	body.setup(cfg)
	body.set_head_visible(not first_person)
	_equipped_sig = _equip_signature()

func _shield_for_armor() -> String:
	match Game.equipped.armor:
		"chainmail": return "shield_badge_color"
		"warden_plate": return "shield_square_color"
	return "shield_round"

var _equipped_sig := ""
func _equip_signature() -> String:
	return "%s|%s" % [Game.equipped.weapon, Game.equipped.armor]

func _on_inventory_changed() -> void:
	if _equip_signature() == _equipped_sig:
		return
	body.set_weapon(Game.equipped.weapon)
	body.set_offhand(_shield_for_armor())
	_equipped_sig = _equip_signature()

# ---------------------------------------------------------------------------
func set_mouse_captured(c: bool) -> void:
	mouse_captured = c
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if c else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and mouse_captured:
		yaw -= event.relative.x * Game.mouse_sens
		pitch = clampf(pitch - event.relative.y * Game.mouse_sens, -1.35, 1.25)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step(1)
		elif not mouse_captured and event.button_index == MOUSE_BUTTON_LEFT:
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()

## Mouse wheel: each notch moves the camera; zoom continues smoothly into the head.
func zoom_step(dir: int) -> void:
	var step := 0.35 + zoom_target * 0.18
	zoom_target = clampf(zoom_target + step * dir, 0.0, MAX_ZOOM)
	if zoom_target < FP_THRESHOLD and dir < 0:
		zoom_target = 0.0

func toggle_view() -> void:
	zoom_target = 3.6 if zoom_target < FP_THRESHOLD else 0.0

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = 0; velocity.z = 0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		_update_camera(delta)
		return
	_update_timers(delta)
	in_river = false
	for r in get_tree().get_nodes_in_group("river"):
		if r.contains(global_position):
			in_river = true
			break
	var dir := Vector3.ZERO
	if input_enabled:
		_handle_actions()
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
		if Input.is_action_just_pressed("jump") and is_on_floor() and not dodging and Game.stamina >= 8:
			velocity.y = JUMP_V
			_use_stamina(8)
	var sprinting := input_enabled and Input.is_action_pressed("sprint") and dir.length() > 0.1 and Game.stamina > 1 and not blocking
	var speed := SPRINT if sprinting else WALK
	if blocking:
		speed *= 0.45
	if attacking:
		speed *= 0.35
	if casting:
		speed *= 0.5
	if sprinting:
		Game.stamina = maxf(0.0, Game.stamina - 16.0 * delta)
		stamina_delay = 0.5
	var target_v := dir * speed
	if dodging:
		target_v = dodge_dir * 10.5 * (1.0 - dodge_time / 0.42 * 0.5)
	var a := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-a * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-a * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -40.0:
		take_damage(9999.0, global_position, 0.0)

	# facing
	var want := facing
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if first_person or attacking or blocking or casting:
		want = yaw
	elif dir.length() > 0.1:
		want = atan2(-dir.x, -dir.z)
	if dodging and not first_person:
		want = atan2(-dodge_dir.x, -dodge_dir.z)
	facing = lerp_angle(facing, want, 1.0 - exp(-(18.0 if attacking else 12.0) * delta))
	body.rotation.y = facing

	# animation inputs
	body.move_speed = hspeed
	body.grounded = is_on_floor()
	body.attack_t = attack_time / attack_dur if attacking else -1.0
	body.attack_kind = combo
	body.attack_dur = attack_dur
	body.blocking = blocking
	var local_dodge := dodge_dir.rotated(Vector3.UP, -facing)
	body.dodge_dir = Vector2(local_dodge.x, local_dodge.z)
	var local_v := Vector3(velocity.x, 0, velocity.z).rotated(Vector3.UP, -facing)
	body.backwards = first_person and local_v.z > 0.5
	body.cast_t = cast_time / 0.45 if casting else -1.0
	body.dodge_t = dodge_time / 0.42 if dodging else -1.0
	body.hurt_t = hurt_time / 0.3 if hurt_time >= 0.0 else -1.0

	if is_on_floor() and hspeed > 1.0:
		step_accum += hspeed * delta
		if step_accum > (1.1 if hspeed < 5 else 1.5):
			step_accum = 0.0
			Sfx.play("footstep", -18.0 if not in_river else -10.0, 0.15)
			if in_river:
				Sfx.play("splash", -22.0, 0.2)
	_update_interact()
	_update_camera(delta)

func _update_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	if hurt_time >= 0.0:
		hurt_time += delta
		if hurt_time > 0.3:
			hurt_time = -1.0
	stamina_delay -= delta
	if stamina_delay <= 0.0 and not blocking:
		Game.stamina = minf(Game.max_stamina(), Game.stamina + 30.0 * delta)
	Game.mana = minf(Game.max_mana(), Game.mana + 3.0 * delta)
	if attacking:
		attack_time += delta
		if not hit_done and attack_time / attack_dur >= 0.42:
			hit_done = true
			_melee_hit()
		if attack_time >= attack_dur:
			attacking = false
			if combo_queued:
				combo_queued = false
				_start_attack((combo + 1) % 3)
			else:
				combo = 0
	if casting:
		cast_time += delta
		if cast_time >= 0.18 and cast_time - delta < 0.18:
			_fire_bolt()
		if cast_time >= 0.45:
			casting = false
	if dodging:
		dodge_time += delta
		if dodge_time >= 0.42:
			dodging = false

func _handle_actions() -> void:
	if not mouse_captured:
		blocking = false
		return
	if Input.is_action_just_pressed("attack") and not dodging and not casting:
		if not attacking:
			if Game.stamina >= 6:
				_start_attack(0)
		elif attack_time / attack_dur > 0.45:
			combo_queued = true
	blocking = Input.is_action_pressed("block") and not attacking and not dodging and Game.stamina > 2.0
	if blocking:
		stamina_delay = 0.4
	if Input.is_action_just_pressed("dodge") and is_on_floor() and not dodging and Game.stamina >= 22:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var d := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
		if d.length() < 0.1:
			d = Vector3(0, 0, 1).rotated(Vector3.UP, facing)  # roll backward
		dodge_dir = d.normalized()
		dodging = true; dodge_time = 0.0; invuln = 0.36
		attacking = false; casting = false; combo = 0; combo_queued = false
		_use_stamina(22)
		Sfx.play("swing", -12.0, 0.2)
	if Input.is_action_just_pressed("spell") and not casting and not attacking and not dodging:
		if Game.mana >= 20:
			Game.mana -= 20
			casting = true; cast_time = 0.0
			Sfx.play("spell", -6.0)
		else:
			Game.say("Not enough mana.", Color(0.6, 0.7, 1.0))
	if Input.is_action_just_pressed("potion"):
		drink_potion()
	if Input.is_action_just_pressed("interact") and interact_target and is_instance_valid(interact_target):
		interact_target.interact(self)
	if Input.is_action_just_pressed("toggle_view"):
		toggle_view()
	if Input.is_action_just_pressed("zoom_in_key"):
		zoom_step(-1)
	if Input.is_action_just_pressed("zoom_out_key"):
		zoom_step(1)

func _use_stamina(v: float) -> void:
	Game.stamina = maxf(0.0, Game.stamina - v)
	stamina_delay = 0.7

func _start_attack(kind: int) -> void:
	combo = kind
	attacking = true
	attack_time = 0.0
	attack_dur = 0.72 if kind == 2 else 0.52
	hit_done = false
	_use_stamina(6 if kind < 2 else 10)
	Sfx.play("swing", -7.0, 0.12)

func _melee_hit() -> void:
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var origin := global_position + Vector3(0, 1.0, 0)
	var reach := 2.5 + (0.3 if Game.equipped.weapon != "rusty_sword" else 0.0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(e) or e == self or not e.has_method("take_damage"):
			continue
		if e.get("dead") == true:
			continue
		var r: float = e.get("hit_radius") if e.get("hit_radius") != null else 0.5
		var to: Vector3 = (e.global_position + Vector3(0, 1.0, 0)) - origin
		to.y *= 0.5
		var dist := to.length() - r
		if dist > reach:
			continue
		var ang := fwd.dot(Vector3(to.x, 0, to.z).normalized())
		if ang < 0.25 and dist > 0.6:
			continue
		var dmg := Game.attack_damage() * (1.6 if combo == 2 else 1.0) * randf_range(0.9, 1.1)
		var crit := randf() < 0.12
		if crit:
			dmg *= 1.75
		e.take_damage(dmg, global_position, 5.0 if combo == 2 else 2.5, crit)
		hit_any = true
	if hit_any:
		add_trauma(0.18 if combo < 2 else 0.32)
		_hitstop(0.05 if combo < 2 else 0.08)

func _hitstop(t: float) -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0

func _fire_bolt() -> void:
	var b := Area3D.new()
	b.set_script(bolt_scene_script)
	var fwd := -camera.global_transform.basis.z
	if not first_person:
		# aim from the hand, toward what the camera centre is looking at
		var from := camera.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 60.0, 1 | 4)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var aim_point: Vector3 = hit.position if hit else from + fwd * 60.0
		var start := global_position + Vector3(0, 1.35, 0) + (-Vector3(sin(facing), 0, cos(facing))) * 0.6
		fwd = (aim_point - start).normalized()
		b.position = start
	else:
		b.position = camera.global_position + fwd * 0.8 + Vector3(0, -0.15, 0)
	get_tree().current_scene.add_child(b)
	bolts_fired += 1
	b.launch(fwd, "player", Game.spell_damage(), Color(0.45, 0.7, 1.0), 24.0)

func drink_potion() -> void:
	if potion_cd > 0.0:
		return
	if Game.potions <= 0:
		Game.say("No healing draughts left.", Color(1, 0.6, 0.5))
		return
	if Game.hp >= Game.max_hp() - 0.5:
		Game.say("Already at full health.", Color(0.8, 0.8, 0.8))
		return
	Game.potions -= 1
	potion_cd = 1.0
	Game.hp = minf(Game.max_hp(), Game.hp + 30.0 + Game.max_hp() * 0.4)
	Sfx.play("pickup", -4.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.35), 24, 2.0)
	Game.stats_changed.emit()

# ---------------------------------------------------------------------------
func take_damage(amount: float, from_pos: Vector3, knock := 3.0, _crit := false) -> void:
	if dead or invuln > 0.0:
		return
	var to_src := from_pos - global_position
	to_src.y = 0
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var blocked := blocking and to_src.length() > 0.01 and fwd.dot(to_src.normalized()) > 0.2
	var dmg := Game.mitigate(amount)
	if blocked:
		var cost := dmg * 1.1
		if Game.stamina >= cost:
			Game.stamina -= cost
			dmg *= 0.2
			Sfx.play("clang", -4.0)
			FX.sparks(global_position + Vector3(0, 1.2, 0) + fwd * 0.5, Color(1.0, 0.85, 0.5))
			knock *= 0.4
		else:
			Game.stamina = 0.0
			dmg *= 0.6
			blocking = false
			Game.say("Guard broken!", Color(1, 0.5, 0.3))
	if not blocked or dmg > 3.0:
		hurt_time = 0.0
		body.flash(Color(1, 0.2, 0.2), 0.6)
		Sfx.play("hurt", -6.0)
	Game.hp -= dmg
	damage_taken += dmg
	stamina_delay = 0.5
	add_trauma(0.25 + dmg / 60.0)
	if to_src.length() > 0.01:
		var k := -to_src.normalized() * knock
		velocity.x += k.x; velocity.z += k.z
	FX.damage_number(global_position + Vector3(0, 2.0, 0), dmg, Color(1.0, 0.35, 0.3), false)
	Game.stats_changed.emit()
	if Game.hp <= 0.0:
		die()

func heal(v: float) -> void:
	Game.hp = minf(Game.max_hp(), Game.hp + v)
	Game.stats_changed.emit()

func die() -> void:
	if dead:
		return
	dead = true
	Game.hp = 0
	attacking = false; blocking = false; casting = false; dodging = false
	body.collapse()
	zoom_target = maxf(zoom_target, 4.5)
	Sfx.play("death", -2.0, 0.0)
	Game.player_died.emit()

func respawn_at(pos: Vector3, yaw_r: float) -> void:
	dead = false
	global_position = pos
	velocity = Vector3.ZERO
	yaw = yaw_r; facing = yaw_r; pitch = -0.2
	body.revive()
	body.rotation.y = facing
	Game.hp = Game.max_hp(); Game.stamina = Game.max_stamina(); Game.mana = Game.max_mana()
	invuln = 2.0
	cam_yaw.global_position = global_position + Vector3(0, EYE_H, 0)
	Game.stats_changed.emit()

func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)

# ---------------------------------------------------------------------------
func _update_interact() -> void:
	var best: Node = null
	var best_d := 2.6
	var fwd := -Vector3(sin(yaw), 0, cos(yaw))
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or not n.has_method("interact"):
			continue
		if n.has_method("can_interact") and not n.can_interact():
			continue
		var to: Vector3 = n.global_position - global_position
		to.y = 0
		var d := to.length()
		var bonus := 0.0 if d < 0.01 else fwd.dot(to / d) * 0.6
		if d - bonus < best_d:
			best_d = d - bonus
			best = n
	interact_target = best
	var txt := ""
	if best:
		txt = best.get_prompt() if best.has_method("get_prompt") else "Interact"
	if txt != _last_prompt:
		_last_prompt = txt
		interact_target_changed.emit(txt)

func _update_camera(delta: float) -> void:
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-10.0 * delta))
	var fp := zoom < FP_THRESHOLD
	if fp != first_person:
		first_person = fp
		body.set_head_visible(not fp)
	var head_pos := global_position + Vector3(0, EYE_H * (body.scale.y), 0)
	if body.dead:
		head_pos = global_position + Vector3(0, 0.6, 0)
	# follow: snappy vertically when close (first person must not lag)
	var follow := 1.0 - exp(-(40.0 if zoom < 1.5 else 16.0) * delta)
	cam_yaw.global_position = cam_yaw.global_position.lerp(head_pos, follow)
	if fp:
		cam_yaw.global_position = head_pos + (-Vector3(sin(yaw), 0, cos(yaw))) * 0.12
	cam_yaw.rotation = Vector3(0, yaw, 0)
	cam_pitch.rotation = Vector3(pitch, 0, 0)
	var shoulder := clampf((zoom - 0.6) / 3.0, 0.0, 1.0) * 0.5 * clampf(1.0 - (zoom - 4.0) / 5.0, 0.3, 1.0)
	spring.position = Vector3(shoulder, clampf((zoom - 0.5) * 0.08, 0.0, 0.35), 0)
	spring.spring_length = zoom if zoom > 0.05 else 0.0
	# shake
	trauma = maxf(0.0, trauma - delta * 1.6)
	var sh := trauma * trauma
	var tt := Time.get_ticks_msec() * 0.001
	camera.h_offset = sin(tt * 37.0) * 0.12 * sh
	camera.v_offset = cos(tt * 41.0) * 0.12 * sh
	camera.rotation.z = sin(tt * 23.0) * 0.04 * sh
	camera.fov = lerpf(camera.fov, 78.0 if (fp) else 70.0, 1.0 - exp(-6.0 * delta))
