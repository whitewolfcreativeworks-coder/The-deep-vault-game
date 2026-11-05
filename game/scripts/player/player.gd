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
const JUMP_V := 7.0          # a tap: a modest hop
const DOUBLE_JUMP_V := 11.0  # tap again in the air: a big boosted jump
const EYE_H := 1.62
const FP_THRESHOLD := 0.45
const MAX_ZOOM := 11.0
const VIEW_STEPS := [0.0, 4.2, 9.5]   # first person, behind, high and back
const HIGH_FROM := 4.5                # past this distance the camera rises and looks down
const MOUSE_SENS := 0.0024

var body: CharacterModel
var cam_yaw: Node3D
var cam_pitch: Node3D
var arm: Node3D
var _probe: SphereShape3D
var view_yaw := 0.0     # smoothed yaw/pitch actually rendered
var view_pitch := -0.25
var cam_len := 3.6      # current camera distance after collision
var _look_idle := 0.0
var _bob := 0.0
const PITCH_MIN := -1.05
const PITCH_MAX := 0.85
var camera: Camera3D
var zoom := 4.2
var zoom_target := 4.2
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
var melee_mana_gained := 0.0
var potions_used := 0
var mana_potions_used := 0
var swings := 0
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
	cam_yaw.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam_pitch = Node3D.new(); cam_yaw.add_child(cam_pitch)
	arm = Node3D.new(); arm.name = "Arm"; cam_pitch.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 74.0
	camera.near = 0.08
	camera.far = 300.0
	arm.add_child(camera)
	_probe = SphereShape3D.new(); _probe.radius = 0.3
	# the body moves in physics ticks; interpolate it so it glides at any refresh rate
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	Game.inventory_changed.connect(_on_inventory_changed)
	cam_yaw.global_position = global_position + Vector3(0, EYE_H, 0)

func rebuild_body() -> void:
	_headgear_hidden.clear()
	var p := Game.profile
	var weapon := Game.item(Game.equipped.weapon)
	var armor := Game.item(Game.equipped.armor)
	var skin := Game.item(Game.equipped.skin)
	var cfg := {
		"kind": "hero", "hero": p.hero, "show_hat": p.show_hat,
		"weapon": Game.equipped.weapon, "shield": armor.get("shield", "shield_round"), "scale": 0.84,
		"skin": skin.get("skin", ""),
	}
	_apply_profile_looks(cfg)
	if armor.has("tint") and int(armor.get("rarity", 0)) >= 1:
		cfg["tint"] = armor.tint
	if p.cape > 0:
		cfg["cape_color"] = Game.CAPE_COLORS[p.cape]
		cfg["outfit_color"] = Game.CAPE_COLORS[p.cape]
	# epic / legendary gear gives a glowing aura in its rarity colour
	var best := maxi(int(weapon.get("rarity", 0)), int(armor.get("rarity", 0)))
	if best >= 3:
		cfg["aura"] = Loot.rarity_color(best)
		cfg["aura_level"] = best
	# armour you can see, and magic costumes on top of everything
	if armor.has("outfit"):
		cfg["outfit_model"] = armor.outfit
	if skin.has("outfit"):
		cfg["outfit_model"] = skin.outfit      # an armour skin changes the look of your armour
		if skin.has("fx"):
			cfg["outfit_fx"] = skin.fx
	if Game.costume_id() != "":
		cfg["costume"] = Game.costume_id()
	elif Game.custom_look_on and not Game.custom_look.is_empty():
		cfg["custom_look"] = Game.custom_look      # your own design from the Skin Designer
	body.setup(cfg)
	body.set_head_visible(not _head_hidden)
	_equipped_sig = _equip_signature()
	if mounted:
		_ride_pose(true)

# --- the Giant Chicken mount --------------------------------------------------------
const MOUNT_SPEED := 1.75       # riding is this much faster than running on foot
var mounted := false
var mount: ChickenMount

func has_mount() -> bool:
	return bool(Game.flags.get("mount_chicken", false))

func toggle_mount() -> void:
	if mounted:
		dismount()
	elif has_mount() and not dead:
		mount_up()

func mount_up() -> void:
	if mounted or dead:
		return
	mounted = true
	mount = ChickenMount.new()
	mount.riding = true
	add_child(mount)
	mount.rotation.y = facing
	mount.bawk()
	FX.burst(global_position + Vector3(0, 0.8, 0), Color(1.0, 0.95, 0.85), 40, 4.0, 0.2, 0.9, -2.0)
	attacking = false; blocking = false; casting = false
	_ride_pose(true)

func dismount() -> void:
	if not mounted:
		return
	mounted = false
	if mount and is_instance_valid(mount):
		FX.burst(mount.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.95, 0.85), 30, 3.0, 0.16, 0.8, -3.0)
		Sfx.play("cluck", -6.0, 0.1)
		mount.queue_free()
	mount = null
	_ride_pose(false)

func _ride_pose(on: bool) -> void:
	if body == null:
		return
	body.hold_clip = "Sit_Chair_Idle" if on else ""
	body.position.y = (ChickenMount.SEAT_H - 0.46) if on else 0.0

## Looks chosen in the character creator (shared with the creator preview).
static func _apply_profile_looks(cfg: Dictionary) -> void:
	var p := Game.profile
	if int(p.get("skin", 0)) > 0:
		cfg["skin_color"] = Game.SKIN_COLORS[p.skin]
	cfg["hair_style"] = p.get("hair_style", "natural")
	var hc := int(p.get("hair_color", 0))
	cfg["hair_color"] = Game.HAIR_COLORS2[hc]
	if hc > 0:
		cfg["hair_tint"] = Game.HAIR_COLORS2[hc]
	if cfg.hair_style in ["bald", "mohawk"]:
		cfg["hair_tint"] = cfg.get("skin_color", Game.SKIN_COLORS[0]).darkened(0.08)   # shaved
	cfg["face"] = p.get("face", "none")
	cfg["build"] = float(p.get("build", 1.0))
	cfg["height"] = float(p.get("height", 1.0))

var _equipped_sig := ""
func _equip_signature() -> String:
	return "%s|%s|%s|%s|%s" % [Game.equipped.weapon, Game.equipped.armor, Game.equipped.skin, Game.costume_id(),
		str(Game.custom_look).hash() if Game.custom_look_on else 0]

func _on_inventory_changed() -> void:
	if _equip_signature() == _equipped_sig:
		return
	var first := _equipped_sig == ""
	var was_costume := _equipped_sig.get_slice("|", 3) if _equipped_sig.count("|") >= 3 else ""
	rebuild_body()
	if not first and is_inside_tree() and was_costume != Game.costume_id():
		# a magic transformation: a swirl of rainbow sparkles
		for k in 3:
			FX.burst(global_position + Vector3(0, 0.4 + k * 0.6, 0), Color.from_hsv(k / 3.0, 0.55, 1.0), 40, 3.5, 0.16, 1.0, 0.5)
		FX.pillar(global_position, Color(1.0, 0.75, 1.0), 1.0, 5.0, 0.6)
		body.flash(Color(1, 0.8, 1), 0.9)
		Sfx.play("portal", -6.0, 0.0)
		return
	if not first and is_inside_tree():
		# a little celebration when your look changes
		FX.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.6), 30, 2.5, 0.14, 0.8, 1.0)
		body.flash(Color(1, 1, 0.8), 0.6)
		Sfx.play("pickup", -6.0, 0.0)

# ---------------------------------------------------------------------------
signal focus_lost   # pointer lock was dropped by the OS / browser (e.g. Esc in Safari)

var _had_lock := false
var _lock_wait := -1.0
var _press_down := false
var _press_pos := Vector2.ZERO
var _dragged := false

## "Captured" means the player has gameplay focus. The OS pointer is only
## locked when using mouse/trackpad and the platform allows it; touch play
## and browsers without pointer lock keep a free cursor.
func set_mouse_captured(c: bool) -> void:
	mouse_captured = c
	if c and not Game.touch_active and not Game.free_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_lock_wait = 0.6
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_had_lock = false
		_lock_wait = -1.0

func _process(delta: float) -> void:
	_update_camera(delta)
	# detect a pointer lock that never took (browser) or was dropped
	if _lock_wait >= 0.0:
		_lock_wait -= delta
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_had_lock = true
			_lock_wait = -1.0
		elif _lock_wait < 0.0 and mouse_captured and not Game.touch_active:
			Game.free_cursor = true
			Game.say("Pointer lock unavailable: drag to look, tap/click to attack.", Color(0.7, 0.8, 1.0))
	elif _had_lock and mouse_captured and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_had_lock = false
		focus_lost.emit()

func _look(rel: Vector2, mult := 1.0) -> void:
	yaw -= rel.x * Game.mouse_sens * mult
	pitch = clampf(pitch - rel.y * Game.mouse_sens * mult, PITCH_MIN, PITCH_MAX)
	_look_idle = 0.0

func _tap_action(action: String) -> void:
	Input.action_press(action)
	get_tree().create_timer(0.06, true, true).timeout.connect(func() -> void: Input.action_release(action))

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	# touchscreens also send emulated mouse events; the touch overlay handles touch
	if (event is InputEventMouse) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if (event is InputEventMouse) and Game.touch_active and Time.get_ticks_msec() - Game.last_touch_ms < 900:
		return   # Safari/iPad can fire "compatibility" mouse events after a touch
	if event is InputEventMouseMotion:
		if mouse_captured and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_look(event.relative)
		elif mouse_captured and Game.free_cursor and _press_down:
			_look(event.relative, 1.6)
			if event.position.distance_to(_press_pos) > 10.0:
				_dragged = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step(-1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var locked := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				if not mouse_captured or (not Game.free_cursor and not Game.touch_active and not locked):
					set_mouse_captured(true)
					get_viewport().set_input_as_handled()
					return
				if Game.free_cursor:
					_press_down = true; _dragged = false; _press_pos = mb.position
				else:
					Input.action_press("attack")
			else:
				if Game.free_cursor:
					if _press_down and not _dragged:
						_tap_action("attack")
					_press_down = false
				else:
					Input.action_release("attack")
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				Input.action_press("block")
			else:
				Input.action_release("block")
	elif event is InputEventPanGesture:
		# trackpad two-finger scroll on macOS / iPadOS
		var pg := event as InputEventPanGesture
		_pan_acc += pg.delta.y
		while absf(_pan_acc) > 1.5:
			zoom_step(1 if _pan_acc > 0 else -1)
			_pan_acc -= signf(_pan_acc) * 1.5
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_target = clampf(zoom_target / maxf(mg.factor, 0.01), 0.0, MAX_ZOOM)
		if zoom_target < FP_THRESHOLD:
			zoom_target = 0.0

var _pan_acc := 0.0

## Mouse wheel: each notch moves the camera; zoom continues smoothly into the head.
func zoom_step(dir: int) -> void:
	var step := 0.35 + zoom_target * 0.18
	zoom_target = clampf(zoom_target + step * dir, 0.0, MAX_ZOOM)
	if zoom_target < FP_THRESHOLD and dir < 0:
		zoom_target = 0.0

func toggle_view() -> void:
	# cycle first person -> behind -> high -> first person
	var i := 0
	for k in VIEW_STEPS.size():
		if absf(zoom_target - VIEW_STEPS[k]) < absf(zoom_target - VIEW_STEPS[i]):
			i = k
	zoom_target = VIEW_STEPS[(i + 1) % VIEW_STEPS.size()]

func view_name() -> String:
	if zoom_target < FP_THRESHOLD:
		return "1ST"
	return "HIGH" if zoom_target > (VIEW_STEPS[1] + VIEW_STEPS[2]) * 0.5 else "BEHIND"

## Extra downward tilt of the camera when zoomed far out (overhead view).
func high_t() -> float:
	return clampf((zoom - HIGH_FROM) / (VIEW_STEPS[2] - HIGH_FROM), 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = 0; velocity.z = 0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	_update_timers(delta)
	if mantling:
		_mantle_step(delta)
		return
	in_river = false
	for r in get_tree().get_nodes_in_group("river"):
		if r.contains(global_position):
			in_river = true
			break
	var dir := Vector3.ZERO
	if input_enabled:
		var lk := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if lk.length() > 0.05:
			yaw -= lk.x * 2.2 * delta
			pitch = clampf(pitch - lk.y * 1.3 * delta, PITCH_MIN, PITCH_MAX)
			_look_idle = 0.0
		if posing:
			_pose_actions(get_physics_process_delta_time())
		else:
			_handle_actions()
			var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			_move_input = iv
			dir = Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, view_yaw)
			if Input.is_action_just_pressed("jump"):
				_jump_buffer = 0.18
		if Input.is_action_just_pressed("pose") and not dead:
			toggle_pose()
	else:
		_move_input = Vector2.ZERO
	if is_on_floor():
		_coyote = 0.14
		if velocity.y <= 0.0:
			_air_jumps = 0
	else:
		_coyote -= delta
	if _jump_buffer > 0.0:
		_jump_buffer -= delta
		if not dodging:
			var fwd := dir if dir.length() > 0.1 else -Vector3(sin(facing), 0, cos(facing))
			if _try_mantle(fwd):
				_jump_buffer = 0.0
				return
			if _coyote > 0.0:
				velocity.y = JUMP_V * (1.25 if mounted else 1.0)   # jumping never needs stamina: it must always get you out of trouble
				Game.stamina = maxf(0.0, Game.stamina - 6.0)
				_coyote = 0.0
				_jump_buffer = 0.0
				_air_jumps = 1
			elif _air_jumps == 1:
				_double_jump()
	var sprinting := input_enabled and Input.is_action_pressed("sprint") and dir.length() > 0.1 and Game.stamina > 1 and not blocking
	var speed := SPRINT if sprinting else WALK
	if mounted:
		speed *= MOUNT_SPEED
	if blocking:
		speed *= 0.45
	if attacking:
		speed *= 0.35
	if casting:
		speed *= 0.5
	if sprinting:
		Game.stamina = maxf(0.0, Game.stamina - 16.0 * delta)
		stamina_delay = 0.5
	# strafing: backpedal and sidestep a bit slower than running forward
	var strafe := Game.strafe_mode or first_person
	if strafe and dir.length() > 0.1:
		var local_in := dir.rotated(Vector3.UP, -yaw)
		var back := clampf(local_in.z, 0.0, 1.0)
		var side := absf(local_in.x)
		speed *= 1.0 - back * 0.28 - side * 0.1 * (1.0 - back)
	var target_v := dir * speed
	if special_kind == "charge":
		target_v = _charge_dir * 15.0
	elif special_kind == "whirl":
		target_v *= 0.6
	if dodging:
		target_v = dodge_dir * 10.5 * (1.0 - dodge_time / 0.42 * 0.5)
	var a := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-a * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-a * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < kill_y:
		take_damage(9999.0, global_position, 0.0)

	# facing
	var want := facing
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if strafe or attacking or blocking or casting:
		want = view_yaw    # face where the camera looks; movement is independent
	elif dir.length() > 0.1:
		want = atan2(-dir.x, -dir.z)
	if dodging and not strafe:
		want = atan2(-dodge_dir.x, -dodge_dir.z)
	if posing:
		want = facing          # stand still and let the camera go round
	var turn := 22.0 if strafe else (18.0 if attacking else 12.0)
	if special_kind == "charge":
		want = atan2(-_charge_dir.x, -_charge_dir.z)
	facing = lerp_angle(facing, want, 1.0 - exp(-turn * delta))
	body.rotation.y = facing
	if special_kind == "whirl":
		body.rotation.y = facing + _special_t / 0.75 * TAU * 2.0
	if mounted and mount:
		mount.rotation.y = facing
		mount.speed = hspeed
		mount.airborne = not is_on_floor()

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
	if strafe and _move_input.length() > 0.15:
		body.local_move = _move_input.normalized() * hspeed
	else:
		body.local_move = Vector2(local_v.x, local_v.z)
	body.backwards = body.local_move.y > 0.5 and body.local_move.y > absf(body.local_move.x)
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

func _update_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	if blocking:
		block_time += delta
	if special_kind != "":
		_special_step(delta)
	if hurt_time >= 0.0:
		hurt_time += delta
		if hurt_time > 0.3:
			hurt_time = -1.0
	stamina_delay -= delta
	if stamina_delay <= 0.0 and not blocking:
		Game.stamina = minf(Game.max_stamina(), Game.stamina + 30.0 * delta)
	Game.mana = minf(Game.max_mana(), Game.mana + Game.mana_regen() * delta)
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
	if Input.is_action_just_pressed("mount"):
		toggle_mount()
	# any fighting move hops you off the chicken first
	if mounted and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("block") or Input.is_action_just_pressed("dodge")
			or Input.is_action_just_pressed("spell") or Input.is_action_just_pressed("special")):
		dismount()
	if Input.is_action_just_pressed("attack") and not dodging and not casting:
		if not attacking:
			if Game.stamina >= 6:
				_start_attack(0)
		elif attack_time / attack_dur > 0.45:
			combo_queued = true
	# Block raises instantly, even mid-swing (the swing is cancelled), so it can
	# be used on reaction. The first PARRY_WINDOW seconds count as a parry.
	var want_block := Input.is_action_pressed("block") and not dodging and special_kind == "" and Game.stamina > 2.0
	if want_block and attacking:
		attacking = false; combo = 0; combo_queued = false
	if want_block and not blocking:
		block_time = 0.0
		Sfx.play("swing", -16.0, 0.1)
	blocking = want_block
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
	if Input.is_action_just_pressed("special"):
		use_special()
	if Input.is_action_just_pressed("mana_potion"):
		drink_mana_potion()
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
	swings += 1
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
	var reach := 3.0 + (0.3 if Game.equipped.weapon != "rusty_sword" else 0.0) + (0.25 if Game.item(Game.equipped.weapon).get("model", "") in ["sword_2handed_color", "skel_staff", "vault_blade"] else 0.0)
	var hit_any := false
	var dealt := 0.0
	var trail_c := Color(0.9, 0.92, 1.0)
	var wit := Game.item(Game.equipped.weapon)
	if int(wit.get("rarity", 0)) >= 2:
		trail_c = Loot.rarity_color(int(wit.rarity)).lightened(0.3)
	if Game.equipped.weapon == "vault_blade":
		trail_c = Color(0.4, 0.85, 1.0)
	var tilt: float = [0.95, -0.95, 1.45][combo % 3]   # diagonal slashes, then an overhead chop
	FX.swipe(origin + Vector3(0, 0.15, 0), facing, tilt, reach * 0.95, trail_c, 160.0 if combo < 2 else 200.0, 0.22, combo == 1)
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
		var crit := randf() < Game.crit_chance()
		if crit:
			dmg *= 1.75
		e.take_damage(dmg, global_position, 5.0 if combo == 2 else 2.5, crit)
		hit_any = true
		dealt += dmg
	if hit_any:
		# sword hits charge your mana: cast, melee to recharge, cast again
		var gain := 7.0 if combo < 2 else 11.0
		Game.mana = minf(Game.max_mana(), Game.mana + gain)
		melee_mana_gained += gain
		if Game.lifesteal() > 0.0:
			heal(dealt * Game.lifesteal())
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
		if high_t() > 0.0:
			fwd.y = clampf(fwd.y, -0.15, 0.3)   # from the high view, aim across the room, not at the floor
			fwd = fwd.normalized()
		b.position = start
	else:
		b.position = camera.global_position + fwd * 0.8 + Vector3(0, -0.15, 0)
	get_tree().current_scene.add_child(b)
	bolts_fired += 1
	# spell power makes bolts bigger and hotter
	var sp := Game.spell_power()
	b.size = 1.0 + clampf(sp / 60.0, 0.0, 1.2)
	var bolt_c := Color(0.45, 0.7, 1.0).lerp(Color(0.85, 0.4, 1.0), clampf(sp / 80.0, 0.0, 1.0))
	b.launch(fwd, "player", Game.spell_damage(), bolt_c, 24.0)

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
	potions_used += 1
	potion_cd = 1.0
	Game.hp = minf(Game.max_hp(), Game.hp + 30.0 + Game.max_hp() * 0.4)
	Sfx.play("pickup", -4.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.35), 24, 2.0)
	Game.stats_changed.emit()

func drink_mana_potion() -> void:
	if potion_cd > 0.0:
		return
	if Game.mana_potions <= 0:
		Game.say("No mana potions left.", Color(0.6, 0.7, 1.0))
		return
	if Game.mana >= Game.max_mana() - 0.5:
		Game.say("Already at full mana.", Color(0.8, 0.8, 0.8))
		return
	Game.mana_potions -= 1
	mana_potions_used += 1
	potion_cd = 1.0
	Game.mana = minf(Game.max_mana(), Game.mana + 25.0 + Game.max_mana() * 0.6)
	Sfx.play("spell", -8.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), Color(0.35, 0.55, 1.0), 24, 2.0)
	Game.stats_changed.emit()

# ---------------------------------------------------------------------------
func take_damage(amount: float, from_pos: Vector3, knock := 3.0, _crit := false) -> void:
	if dead or invuln > 0.0:
		return
	var to_src := from_pos - global_position
	to_src.y = 0
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var blocked := blocking and to_src.length() > 0.01 and fwd.dot(to_src.normalized()) > -0.15
	var dmg := Game.mitigate(amount)
	if blocked:
		if block_time < PARRY_WINDOW:
			_parry(from_pos)
			return
		var cost := maxf(4.0, dmg * 0.8)
		if Game.stamina >= cost:
			Game.stamina -= cost
			dmg = 0.0 if amount < 40.0 else dmg * 0.15   # only the Warden's biggest blows get through a little
			blocks += 1
			Sfx.play("clang", -3.0)
			FX.sparks(global_position + Vector3(0, 1.2, 0) + fwd * 0.6, Color(1.0, 0.85, 0.5))
			FX.flash_light(global_position + Vector3(0, 1.2, 0) + fwd * 0.6, Color(1.0, 0.8, 0.4), 3.0, 4.0, 0.15)
			knock *= 0.3
			add_trauma(0.12)
			if dmg <= 0.0:
				stamina_delay = 0.4
				return
		else:
			Game.stamina = 0.0
			dmg *= 0.5
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
	end_pose()
	dismount()
	dead = false
	global_position = pos
	velocity = Vector3.ZERO
	yaw = yaw_r; facing = yaw_r; pitch = -0.2
	body.revive()
	body.rotation.y = facing
	Game.hp = Game.max_hp(); Game.stamina = Game.max_stamina(); Game.mana = Game.max_mana()
	invuln = 2.0
	snap_view()
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

## Climb onto a ledge in front (river banks, the island, low walls).
func _try_mantle(fwd: Vector3) -> bool:
	if fwd.length() < 0.1:
		return false
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.35, 0), feet + Vector3(0, 0.35, 0) + fwd * 0.95, 1)
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if wall.is_empty():
		return false
	var probe_xz: Vector3 = wall.position + fwd * 0.5
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(probe_xz.x, feet.y + 2.2, probe_xz.z), Vector3(probe_xz.x, feet.y + 0.2, probe_xz.z), 1)
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var h: float = top.position.y - feet.y
	if h < 0.45 or h > 2.0:
		return false
	var target: Vector3 = top.position + Vector3(0, 0.03, 0)
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	sq.shape = cap
	sq.transform = Transform3D(Basis.IDENTITY, target + Vector3(0, 0.9, 0))
	sq.collision_mask = 1
	sq.exclude = [get_rid()]
	if not space.intersect_shape(sq, 1).is_empty():
		return false
	mantling = true
	mantles += 1
	_mantle_t = 0.0
	_mantle_from = feet
	_mantle_to = target
	velocity = Vector3.ZERO
	attacking = false; casting = false; blocking = false
	body.play_role("interact", MANTLE_TIME)
	Sfx.play("footstep", -10.0, 0.1)
	return true

func _mantle_step(delta: float) -> void:
	_mantle_t += delta
	var k := clampf(_mantle_t / MANTLE_TIME, 0.0, 1.0)
	var up := smoothstep(0.0, 0.6, k)
	var over := smoothstep(0.35, 1.0, k)
	var p := _mantle_from.lerp(_mantle_to, over)
	p.y = lerpf(_mantle_from.y, _mantle_to.y + 0.08, up)
	global_position = p
	body.move_speed = 0.0
	if k >= 1.0:
		mantling = false
		velocity = Vector3.ZERO

## Jump the camera to where it should be (after teleports / respawn).
## Hats and helmets vanish while the camera is right behind the head, so they
## never block the view (they come back as soon as you zoom out).
var _headgear_hidden: Array = []
func _fade_headgear(hide: bool) -> void:
	if hide == (not _headgear_hidden.is_empty()):
		return
	if hide:
		for m in body.find_children("*", "MeshInstance3D", true, false):
			var nm := String(m.name)
			if (nm.contains("Hat") or nm.contains("Helmet")) and (m as MeshInstance3D).visible:
				(m as MeshInstance3D).visible = false
				_headgear_hidden.append(m)
	else:
		for m in _headgear_hidden:
			if is_instance_valid(m):
				(m as MeshInstance3D).visible = true
		_headgear_hidden.clear()

# --- "Check yourself out": a turntable camera around your hero ---------------------
signal pose_changed(on: bool)
var posing := false
var _pose_saved := {}
var _pose_i := 0
const POSE_CLIPS := ["Cheer", "2H_Melee_Attack_Spin", "Interact", "1H_Melee_Attack_Chop", "Spellcast_Raise", "Unarmed_Pose", "Block", "Throw", "PickUp", "Jump_Full_Short"]

func toggle_pose() -> void:
	if posing:
		end_pose()
	else:
		start_pose()

func start_pose() -> void:
	if posing or dead:
		return
	posing = true
	_pose_saved = {"zoom": zoom_target, "pitch": pitch, "first": first_person}
	if first_person and has_method("toggle_view"):
		zoom = maxf(zoom, 1.0)
	attacking = false; blocking = false; casting = false; dodging = false
	velocity.x = 0.0; velocity.z = 0.0
	zoom_target = 4.6 if mounted else 3.2
	yaw = facing + PI            # swing round to the front
	pitch = -0.12
	_look_idle = 0.0
	if not mounted:
		body.oneshot("Cheer", 1.3)
	Sfx.play("pickup", -8.0, 0.0)
	pose_changed.emit(true)

func end_pose() -> void:
	if not posing:
		return
	posing = false
	zoom_target = float(_pose_saved.get("zoom", 4.2))
	pitch = float(_pose_saved.get("pitch", -0.2))
	yaw = facing                 # back behind you
	pose_changed.emit(false)

func _pose_actions(delta: float) -> void:
	_move_input = Vector2.ZERO
	# strike a pose (attack / the POSE! button); jump does a happy hop
	if Input.is_action_just_pressed("attack") and not mounted:
		var clip: String = POSE_CLIPS[_pose_i % POSE_CLIPS.size()]
		_pose_i += 1
		body.oneshot(clip, -1.0)
		if clip == "Cheer":
			FX.burst(global_position + Vector3(0, 1.6, 0), Color(1.0, 0.9, 0.5), 20, 2.0, 0.12, 0.8, 0.5)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_V
	if mounted and Input.is_action_just_pressed("attack") and mount:
		mount.bawk()
	# the camera slowly circles you until you drag it yourself
	if _look_idle > 1.5:
		yaw += 0.45 * delta
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("inventory"):
		end_pose()

func snap_view() -> void:
	reset_physics_interpolation()
	view_yaw = yaw; view_pitch = pitch
	cam_len = zoom
	cam_yaw.global_position = global_position + Vector3(0, EYE_H, 0)

## Runs every rendered frame (not per physics tick) so motion stays smooth on
## 60/120 Hz displays. Techniques: smoothed look, interpolated follow target,
## collision that pulls in fast but eases back out slowly, pitch auto-levelling
## while moving, a slightly wider field of view, gentle first-person head bob.
func _update_camera(delta: float) -> void:
	if camera == null:
		return
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-9.0 * delta))
	var fp := zoom < FP_THRESHOLD
	# --- look smoothing (touch input is noisier, so it gets more)
	var tc := 0.05 if Game.touch_active else 0.03
	var k := 1.0 - exp(-delta / tc)
	view_yaw = lerp_angle(view_yaw, yaw, k)
	view_pitch = lerpf(view_pitch, pitch, k)
	# --- ease the view back toward the horizon while travelling in third person
	_look_idle += delta
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if _look_idle > 1.2 and hspeed > 1.0 and (not fp or Game.touch_active) and not dead:
		pitch = lerpf(pitch, -0.18, 1.0 - exp(-0.9 * delta))
	# --- follow the interpolated body position
	var base := get_global_transform_interpolated().origin
	var head_pos := base + Vector3(0, EYE_H * float(Game.profile.get("height", 1.0)) + ((ChickenMount.SEAT_H - 0.46) if mounted else 0.0), 0)
	if body.dead:
		head_pos = base + Vector3(0, 0.6, 0)
	if fp:
		# true first person: no lag, small head bob while walking
		if is_on_floor() and hspeed > 0.5:
			_bob += delta * hspeed * 1.9
		else:
			_bob = lerpf(_bob, round(_bob / PI) * PI, 1.0 - exp(-6.0 * delta))
		var bob := sin(_bob) * 0.028 * clampf(hspeed / WALK, 0.0, 1.4)
		cam_yaw.global_position = head_pos + Vector3(0, bob, 0) + (-Vector3(sin(view_yaw), 0, cos(view_yaw))) * 0.12
	else:
		var fh := 1.0 - exp(-45.0 * delta)
		var fv := 1.0 - exp(-(30.0 if zoom < 1.5 else 12.0) * delta)
		var cp := cam_yaw.global_position
		cp.x = lerpf(cp.x, head_pos.x, fh)
		cp.z = lerpf(cp.z, head_pos.z, fh)
		cp.y = lerpf(cp.y, head_pos.y, fv)
		cam_yaw.global_position = cp
	cam_yaw.rotation = Vector3(0, view_yaw, 0)
	cam_pitch.rotation = Vector3(clampf(view_pitch - high_t() * 0.55 - (_crane if zoom > FP_THRESHOLD else 0.0), -1.3, PITCH_MAX), 0, 0)
	# --- shoulder offset shrinks when the camera is squeezed by walls
	var squeeze := clampf(cam_len / maxf(zoom, 0.01), 0.0, 1.0)
	# close in, the camera moves further over the right shoulder (and a little up)
	# so the head, hair and hats don't fill the middle of the screen
	var ramp := clampf((zoom - 0.6) / 0.8, 0.0, 1.0)
	var near := 1.0 - clampf((zoom - 1.0) / 2.5, 0.0, 1.0)
	var shoulder := ramp * lerpf(0.38 * clampf(1.0 - (zoom - 4.0) / 5.0, 0.3, 1.0), 0.62, near) * squeeze * (0.0 if posing else 1.0)
	var lift := clampf((zoom - 0.5) * 0.12, 0.0, 0.55) + 0.2 * near * ramp
	_fade_headgear(not fp and cam_len < 1.9 and not posing)
	# when a wall behind squeezes the camera in, rise up over the shoulder so you
	# look down at your hero instead of into the back of their helmet
	if not fp:
		lift += (1.0 - squeeze) * 0.75 * clampf(zoom / 2.0, 0.0, 1.0)
	var space := get_world_3d().direct_space_state
	# sweep from the head to the shoulder/raised point first: hugging a wall or a
	# low ceiling must never start the camera inside it
	arm.position = Vector3.ZERO
	var off := Vector3(shoulder, lift, 0)
	if off.length() > 0.01:
		var qs := PhysicsShapeQueryParameters3D.new()
		qs.shape = _probe
		qs.transform = Transform3D(Basis.IDENTITY, arm.global_position)
		qs.motion = arm.global_transform.basis * off
		qs.collision_mask = 1
		qs.exclude = [get_rid()]
		var rs := space.cast_motion(qs)
		if rs.size() == 2:
			off *= rs[0]
	_off_now = _off_now.lerp(off, 1.0 - exp(-10.0 * delta)) if off.length() >= _off_now.length() else off
	arm.position = _off_now
	# --- collision: sphere-cast from there to the wanted camera spot
	var want := zoom if zoom > 0.05 else 0.0
	var safe := want
	if want > 0.05:
		var from := arm.global_position
		var back := arm.global_transform.basis.z * want
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _probe
		q.transform = Transform3D(Basis.IDENTITY, from)
		q.motion = back
		q.collision_mask = 1
		q.exclude = [get_rid()]
		var res := space.cast_motion(q)
		if res.size() == 2 and res[0] < 1.0:
			safe = maxf(0.0, want * res[0] - 0.05)
		# crane: if a wall behind would push the camera into the back of the head,
		# swing it up and over (looking down) instead, if that gives more room
		var best_extra := 0.0
		if want > 1.5:
			var best_score := safe
			for extra in [0.3, 0.6, 0.9] if high_t() < 0.5 else [0.3, 0.5]:
				var dir: Vector3 = arm.global_transform.basis.z.rotated(arm.global_transform.basis.x.normalized(), -extra)
				q.motion = dir * want
				var r2 := space.cast_motion(q)
				var s2: float = want if r2.size() < 2 or r2[0] >= 1.0 else maxf(0.0, want * r2[0] - 0.05)
				var score: float = s2 - extra * 0.9
				if s2 > safe + 0.8 and score > best_score:
					best_score = score
					best_extra = extra
		_crane = lerpf(_crane, best_extra, 1.0 - exp(-4.0 * delta))
	if safe < cam_len - 0.01:
		cam_len = lerpf(cam_len, safe, 1.0 - exp(-delta / 0.03))   # pull in almost instantly
		_hold = 0.55                                                # then wait before easing out
	elif _hold > 0.0:
		_hold -= delta
	else:
		cam_len = move_toward(cam_len, safe, delta * (0.9 + cam_len * 0.2))  # ease back out slowly
	camera.position = Vector3(0, 0, cam_len)
	# hide the head whenever the camera is inside or right behind it
	var head_hidden := fp or cam_len < 1.15
	if head_hidden != _head_hidden:
		_head_hidden = head_hidden
		body.set_head_visible(not head_hidden)
	first_person = fp
	# --- shake
	trauma = maxf(0.0, trauma - delta * 1.6)
	var sh := trauma * trauma
	var tt := Time.get_ticks_msec() * 0.001
	camera.h_offset = sin(tt * 37.0) * 0.12 * sh
	camera.v_offset = cos(tt * 41.0) * 0.12 * sh
	camera.rotation.z = sin(tt * 23.0) * 0.04 * sh
	var sprint_kick := 5.0 if hspeed > WALK + 0.8 else 0.0
	fov_kick = maxf(0.0, fov_kick - delta * 30.0)
	camera.fov = lerpf(camera.fov, (80.0 if fp else 74.0) + sprint_kick + fov_kick, 1.0 - exp(-(5.0 if fov_kick < 0.5 else 14.0) * delta))

var _head_hidden := false
var kill_y := -40.0      # falling below this is death (the forest Warren sits deeper)
var _crane := 0.0
var _move_input := Vector2.ZERO
var _coyote := 0.0
var _jump_buffer := 0.0
var mantling := false
var _mantle_t := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var mantles := 0
const MANTLE_TIME := 0.42
var _hold := 0.0
var _off_now := Vector3.ZERO

# ---------------------------------------------------------------------------
# Special abilities: one per hero (Game.ABILITIES), on a cooldown. Each one is
# meant to be a "wow" moment: big damage, slow motion, light and a camera punch.
var special_cd := 0.0
var special_kind := ""
var specials_used := 0
var special_damage := 0.0
var fov_kick := 0.0
var _special_t := 0.0
var _charge_dir := Vector3.ZERO
var _special_hit := {}
var _whirl_hits := 0
var _whirl_marks := [0.12, 0.42, 0.72, 1.02]
var _shield_fx: MeshInstance3D

func special_ready() -> bool:
	return special_cd <= 0.0 and special_kind == ""

func _live_enemies() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("damageable"):
		if is_instance_valid(e) and e != self and e.has_method("take_damage") and e.get("dead") != true and e is Node3D:
			out.append(e)
	return out

func _hit_radius(e: Node) -> float:
	return e.get("hit_radius") if e.get("hit_radius") != null else 0.5

func _blocked(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _floor_at(p: Vector3) -> Variant:
	var hit := _blocked(p + Vector3(0, 1.6, 0), p + Vector3(0, -4.0, 0))
	return hit.position if hit else null

func _special_hit_enemy(e: Node, dmg: float, knock: float, crit := false, stun := false) -> void:
	if stun and e.get("_stagger_acc") != null:
		e.set("_stagger_acc", 1.0e9)   # guarantees a stagger
	e.take_damage(dmg, global_position, knock, crit)
	special_damage += dmg
	if Game.lifesteal() > 0.0:
		heal(dmg * Game.lifesteal())

func _aoe(at: Vector3, radius: float, dmg: float, knock: float, stun := false, crit_bonus := false) -> int:
	var n := 0
	for e in _live_enemies():
		var to: Vector3 = e.global_position - at
		if absf(to.y) > 2.8:
			continue
		to.y = 0
		if to.length() < radius + _hit_radius(e):
			var c := crit_bonus or randf() < Game.crit_chance()
			_special_hit_enemy(e, dmg * randf_range(0.92, 1.08) * (1.5 if c and not crit_bonus else 1.0), knock, c, stun)
			n += 1
	return n

func _teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	body.reset_physics_interpolation()

func _slowmo(scale: float, real_t: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(real_t, true, false, true).timeout
	Engine.time_scale = 1.0

func use_special() -> void:
	if dead or mantling or not input_enabled:
		return
	var ab := Game.ability()
	if special_kind != "":
		return
	if special_cd > 0.0:
		Game.say("%s ready in %ds." % [ab.name, ceili(special_cd)], Color(0.75, 0.7, 1.0))
		return
	attacking = false; casting = false; dodging = false; combo_queued = false; blocking = false
	var ok := false
	match Game.profile.hero:
		"Rogue": ok = _backstab()
		"Mage": ok = _shadow_step()
		"Knight": ok = _start_charge()
		"Barbarian": ok = _start_whirl()
		"Ranger": ok = _volley()
	if ok:
		special_cd = ab.cd
		specials_used += 1

func _special_step(delta: float) -> void:
	_special_t += delta
	match special_kind:
		"charge":
			invuln = maxf(invuln, 0.05)
			fov_kick = maxf(fov_kick, 16.0)
			if int(_special_t * 40.0) % 2 == 0:
				FX.burst(global_position + Vector3(0, 0.25, 0), Color(0.6, 0.55, 0.5), 4, 2.0, 0.35, 0.5, -2.0)
				FX.burst(global_position + Vector3(0, 1.0, 0) + _charge_dir * 0.9, Color(0.45, 0.7, 1.0), 3, 2.5, 0.2, 0.3, 0.0)
			for e in _live_enemies():
				if _special_hit.has(e):
					continue
				var to: Vector3 = e.global_position - global_position
				to.y = 0
				if to.length() < 1.9 + _hit_radius(e) and to.normalized().dot(_charge_dir) > -0.3:
					_special_hit[e] = true
					_special_hit_enemy(e, Game.attack_damage() * 2.6, 13.0, false, true)
					FX.sparks(e.global_position + Vector3(0, 1.1, 0), Color(0.6, 0.85, 1.0))
					FX.flash_light(e.global_position + Vector3(0, 1, 0), Color(0.6, 0.8, 1.0), 7.0, 7.0, 0.3)
					add_trauma(0.45)
					_hitstop(0.07)
			if _special_t > 0.6 or (_special_t > 0.15 and get_real_velocity().length() < 3.0):
				_end_charge()
		"whirl":
			fov_kick = maxf(fov_kick, 8.0)
			for i in _whirl_marks.size():
				var m: float = _whirl_marks[i]
				if _special_t >= m and _special_t - delta < m:
					var last := i == _whirl_marks.size() - 1
					var n := _aoe(global_position, 4.6 if last else 4.0, Game.attack_damage() * (2.0 if last else 1.25), 12.0 if last else 4.0, last)
					_whirl_hits += n
					FX.slash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.2), 4.2, randf_range(-0.25, 0.25), facing, 0.28)
					FX.shockwave(global_position, Color(1.0, 0.5, 0.15), 4.8 if last else 3.8, 0.4)
					Sfx.play("swing", -2.0, 0.15)
					if n > 0:
						add_trauma(0.25)
					if last:
						FX.pillar(global_position, Color(1.0, 0.45, 0.12), 3.2, 6.0, 0.5)
						FX.burst(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.2), 70, 9.0, 0.3, 0.9, -6.0)
						FX.screen_flash(Color(1.0, 0.5, 0.15), 0.25, 0.35)
						add_trauma(0.55)
						_hitstop(0.1)
			if _special_t > 1.15:
				special_kind = ""

func _end_charge() -> void:
	special_kind = ""
	if _shield_fx and is_instance_valid(_shield_fx):
		_shield_fx.queue_free()
	# finishing shield slam
	var at := global_position + _charge_dir * 0.8
	_aoe(at, 3.6, Game.attack_damage() * 1.6, 9.0, true)
	FX.shockwave(at, Color(0.5, 0.75, 1.0), 5.0, 0.45)
	FX.dome(at, Color(0.45, 0.7, 1.0), 3.6, 0.4)
	FX.slash(at + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1.0), 3.2, 0.0, facing, 0.35)
	FX.burst(at + Vector3(0, 0.4, 0), Color(0.7, 0.85, 1.0), 50, 7.0, 0.25, 0.7, -8.0)
	FX.screen_flash(Color(0.6, 0.8, 1.0), 0.25, 0.3)
	Sfx.play("hit", -1.0, 0.05)
	add_trauma(0.6)
	_hitstop(0.08)

## Rogue: appear behind the nearest enemy in reach and strike for a huge crit.
func _backstab() -> bool:
	var head := global_position + Vector3(0, 1.3, 0)
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var best: Node3D = null
	var best_s := INF
	for e in _live_enemies():
		var to: Vector3 = e.global_position - global_position
		var d := to.length()
		if d > 13.0 or absf(to.y) > 3.0:
			continue
		if not _blocked(head, e.global_position + Vector3(0, 1.0, 0)).is_empty():
			continue
		var sc := d - 3.5 * fwd.dot(Vector3(to.x, 0, to.z).normalized())
		if sc < best_s:
			best_s = sc
			best = e
	if best == null:
		Game.say("No enemy close enough to backstab.", Color(0.75, 0.7, 1.0))
		return false
	var ep := best.global_position
	var away := ep - global_position
	away.y = 0
	away = away.normalized() if away.length() > 0.05 else fwd
	var back_d := _hit_radius(best) + 0.9
	var mid := ep + Vector3(0, 1.0, 0)
	var hit := _blocked(mid, mid + away * (back_d + 0.4))
	if not hit.is_empty():
		back_d = maxf(0.3, mid.distance_to(hit.position) - 0.45)
	var dest := ep + away * back_d
	var fl = _floor_at(dest)
	if fl == null:
		dest = ep - away * (_hit_radius(best) + 0.9)   # no floor behind it: strike from the front
		fl = _floor_at(dest)
	if fl != null:
		dest.y = (fl as Vector3).y + 0.05
	var purple := Color(0.7, 0.3, 1.0)
	var from := global_position
	FX.burst(from + Vector3(0, 1, 0), purple, 60, 4.0, 0.4, 0.9, 1.0)
	FX.dome(from, purple, 2.2, 0.35, true)
	FX.beam(from + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), purple, 0.3, 0.45)
	_teleport(dest)
	var look := ep - dest
	facing = atan2(-look.x, -look.z)
	yaw = facing
	body.rotation.y = facing
	snap_view()
	invuln = maxf(invuln, 0.8)
	var crit_hit := Game.attack_damage() * 5.0 * randf_range(0.95, 1.05)
	_special_hit_enemy(best, crit_hit, 7.0, true, true)
	var chest := ep + Vector3(0, 1.1, 0)
	FX.slash(chest, Color(1.0, 0.35, 0.9), 1.8, 0.8, facing, 0.35)
	FX.slash(chest, Color(0.7, 0.4, 1.0), 1.8, -0.8, facing, 0.35)
	FX.burst(chest, Color(1.0, 0.25, 0.35), 45, 5.0, 0.2, 0.7, -6.0)
	FX.burst(dest + Vector3(0, 1, 0), purple, 50, 3.5, 0.35, 0.8, 1.0)
	FX.flash_light(chest, Color(0.9, 0.4, 1.0), 10.0, 8.0, 0.45)
	FX.screen_flash(Color(0.6, 0.2, 0.9), 0.35, 0.4)
	Sfx.play("swing", 0.0, 0.05)
	Sfx.play("hit", 0.0, 0.05)
	combo = 2
	attacking = true
	attack_dur = 0.72
	attack_time = 0.25
	hit_done = true
	fov_kick = 14.0
	add_trauma(0.55)
	_slowmo(0.2, 0.28)
	return true

## Mage: blink up to 13 m, imploding where you leave (and leaving a damaging
## shadow pool) and exploding in a shadow nova where you land.
func _shadow_step() -> bool:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mv.length() > 0.3:
		fwd = Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, view_yaw).normalized()
	var start := global_position
	var chest := start + Vector3(0, 1.0, 0)
	var dist := 13.0
	var hit := _blocked(chest, chest + fwd * dist)
	if not hit.is_empty():
		dist = chest.distance_to(hit.position) - 0.7
	var dest := Vector3.ZERO
	var found := false
	while dist >= 2.0:
		var p := start + fwd * dist
		var fl = _floor_at(p)
		if fl != null and absf((fl as Vector3).y - start.y) < 2.5:
			dest = Vector3(p.x, (fl as Vector3).y + 0.05, p.z)
			found = true
			break
		dist -= 1.0
	if not found:
		Game.say("No room to shadow step.", Color(0.75, 0.7, 1.0))
		return false
	var violet := Color(0.6, 0.3, 1.0)
	var dmg := Game.attack_damage() * 1.8 + Game.spell_damage() * 0.8
	# leaving: implosion and a lingering shadow pool
	FX.dome(start, violet, 3.5, 0.4, true)
	FX.burst(start + Vector3(0, 1.0, 0), violet, 70, 5.0, 0.4, 0.9, 1.5)
	_aoe(start, 3.5, dmg * 0.6, 6.0, true)
	FX.shadow_pool(start, Color(0.45, 0.2, 0.9), 3.0, 2.5, Game.attack_damage() * 0.5)
	FX.beam(start + Vector3(0, 1.1, 0), dest + Vector3(0, 1.1, 0), violet, 0.45, 0.6)
	_teleport(dest)
	snap_view()
	invuln = maxf(invuln, 0.8)
	# landing: shadow nova
	var n := _aoe(dest, 5.0, dmg, 11.0, true)
	FX.dome(dest, violet, 5.0, 0.45)
	FX.shockwave(dest, violet, 6.0, 0.5)
	FX.pillar(dest, violet, 1.0, 8.0, 0.55)
	FX.burst(dest + Vector3(0, 1.0, 0), violet, 80, 7.0, 0.35, 0.9, 1.5)
	FX.screen_flash(Color(0.45, 0.15, 0.85), 0.4, 0.4)
	Sfx.play("spell", 0.0, 0.05)
	Sfx.play("spell_hit", -2.0, 0.05)
	casting = true
	cast_time = 0.2
	fov_kick = 18.0
	add_trauma(0.5 if n > 0 else 0.3)
	_slowmo(0.3, 0.18)
	return true

## Knight: a shield rush behind a barrier of light that ends in a shield slam.
func _start_charge() -> bool:
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_charge_dir = -Vector3(sin(view_yaw), 0, cos(view_yaw))
	if mv.length() > 0.3:
		_charge_dir = Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, view_yaw).normalized()
	special_kind = "charge"
	_special_t = 0.0
	_special_hit.clear()
	_shield_fx = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.is_hemisphere = false; sm.radial_segments = 24; sm.rings = 12
	_shield_fx.mesh = sm
	_shield_fx.material_override = FX._add_mat(Color(0.35, 0.6, 1.0), 0.8)
	(_shield_fx.material_override as StandardMaterial3D).albedo_color.a = 0.45
	add_child(_shield_fx)
	_shield_fx.position = Vector3(0, 1.0, 0) + _charge_dir.rotated(Vector3.UP, 0.0) * 0.0
	_shield_fx.scale = Vector3(1.3, 1.3, 1.3)
	FX.shockwave(global_position, Color(0.5, 0.75, 1.0), 2.5, 0.3)
	FX.flash_light(global_position + Vector3(0, 1, 0), Color(0.5, 0.75, 1.0), 6.0, 7.0, 0.6)
	Sfx.play("swing", 0.0, 0.05)
	add_trauma(0.25)
	return true

## Barbarian: a burning whirlwind that hits everything around four times,
## the last spin hurling enemies away.
func _start_whirl() -> bool:
	special_kind = "whirl"
	_special_t = 0.0
	combo = 2
	attacking = true
	attack_dur = 1.15
	attack_time = 0.0
	hit_done = true
	FX.vortex(self, Color(1.0, 0.45, 0.12), 2.8, 1.15)
	FX.flash_light(global_position + Vector3(0, 1, 0), Color(1.0, 0.55, 0.2), 3.5, 8.0, 1.1)
	return true

## Ranger: two waves of exploding arrows across a wide arc.
func _volley() -> bool:
	_volley_wave(0.0)
	get_tree().create_timer(0.22).timeout.connect(func() -> void:
		if not dead:
			_volley_wave(5.0))
	var green := Color(0.5, 1.0, 0.4)
	FX.shockwave(global_position, green, 3.0, 0.35)
	FX.burst(global_position + Vector3(0, 1.3, 0) - Vector3(sin(facing), 0, cos(facing)) * 0.8, green, 50, 6.0, 0.25, 0.6, 0.0)
	FX.screen_flash(Color(0.4, 1.0, 0.35), 0.18, 0.3)
	Sfx.play("spell", -1.0, 0.1)
	casting = true
	cast_time = 0.15
	fov_kick = 10.0
	add_trauma(0.3)
	return true

func _volley_wave(offset_deg: float) -> void:
	var fwd := -camera.global_transform.basis.z
	fwd.y = clampf(fwd.y, -0.15 if high_t() > 0.0 else -0.25, 0.25)
	var start := global_position + Vector3(0, 1.35, 0) + (-Vector3(sin(facing), 0, cos(facing))) * 0.6
	for i in 9:
		var d := fwd.rotated(Vector3.UP, deg_to_rad(-36.0 + 9.0 * i + offset_deg * (1 if i % 2 == 0 else -1) * 0.5)).normalized()
		var b := Area3D.new()
		b.set_script(bolt_scene_script)
		b.position = start
		get_tree().current_scene.add_child(b)
		b.size = 1.15
		b.homing = 1.2
		b.splash = 1.6
		b.launch(d, "player", Game.attack_damage() * 1.3, Color(0.5, 1.0, 0.4), 34.0)
	Sfx.play("swing", -4.0, 0.2)

# ---------------------------------------------------------------------------
# Double jump: a second tap while in the air launches a much bigger jump.
var _air_jumps := 0      # 0 on the ground, 1 after the first jump, 2 after the double
var double_jumps := 0

func _double_jump() -> void:
	_air_jumps = 2
	_jump_buffer = 0.0
	velocity.y = DOUBLE_JUMP_V
	var hv := Vector2(velocity.x, velocity.z)
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if iv.length() > 0.2:
		var d := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, view_yaw)
		hv = Vector2(d.x, d.z) * maxf(hv.length(), WALK) * 1.15
		velocity.x = hv.x; velocity.z = hv.y
	double_jumps += 1
	var c := Color(0.75, 0.9, 1.0)
	FX.shockwave(global_position - Vector3(0, 0.1, 0), c, 2.2, 0.35)
	FX.burst(global_position + Vector3(0, 0.2, 0), c, 30, 4.0, 0.2, 0.5, -4.0)
	FX.flash_light(global_position, c, 3.0, 4.0, 0.25)
	Sfx.play("swing", -6.0, 0.1)
	fov_kick = maxf(fov_kick, 6.0)

# ---------------------------------------------------------------------------
# Parry: raising the shield just as a blow lands stops it completely, staggers
# the attacker and gives back some mana.
const PARRY_WINDOW := 0.35
var block_time := 0.0
var blocks := 0
var parries := 0

func _parry(from_pos: Vector3) -> void:
	parries += 1
	invuln = maxf(invuln, 0.2)
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var at := global_position + Vector3(0, 1.2, 0) + fwd * 0.7
	Game.mana = minf(Game.max_mana(), Game.mana + 12.0)
	Sfx.play("clang", 0.0, 0.05)
	FX.slash(at, Color(1.0, 0.85, 0.35), 1.4, PI / 2, facing, 0.25)
	FX.burst(at, Color(1.0, 0.85, 0.4), 30, 5.0, 0.15, 0.4, -4.0)
	FX.flash_light(at, Color(1.0, 0.85, 0.4), 7.0, 6.0, 0.3)
	FX.screen_flash(Color(1.0, 0.85, 0.4), 0.15, 0.25)
	Game.say("Parry!", Color(1.0, 0.85, 0.4))
	add_trauma(0.2)
	_slowmo(0.3, 0.12)
	# stagger whoever struck (the nearest enemy to where the blow came from)
	var best: Node = null
	var bd := 3.5
	for e in _live_enemies():
		var d: float = (e as Node3D).global_position.distance_to(from_pos)
		if d < bd:
			bd = d; best = e
	if best:
		_special_hit_enemy(best, Game.attack_damage() * 0.6, 6.0, false, true)
