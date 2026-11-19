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
# Cloud Island physics (set by the world every frame; 1 / 0 / none elsewhere)
var gravity_mult := 1.0      # floaty < 1 < heavy
var jump_mult := 1.0
var fall_cap := 60.0         # fastest you can fall (floaty skins drift down)
var lift := -999.0           # a bubble carrying you: target vertical speed (none below -100)
var wind := Vector3.ZERO     # a push from the wind (m/s), already scaled by your weight
var grip := 1.0              # 1 = normal footing; lower = slippery (wet cloud, ice): you slide
var float_hold: Node = null  # a bubble that's floating you (it owns `lift` until it pops)
var free_flight := false     # the flight home: no ceiling, no turning back at the map edge
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
const BOSS_ZOOM := 7.5
var _boss_lift := 0.0
var _boss_near := false
var _boss_scan := 0.0
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
var _attack_buffer := 0.0
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
var whiffs := 0             # swings that missed because of too many mushrooms
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
	Game.leveled_up.connect(_on_level_up)
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

# --- the Dragonfly: the first flying mount ------------------------------------------
## Hold jump to climb, let go to glide gently down, steer with the stick.
## Its wings tire: wing_stamina (0..1) drains while climbing (about a minute)
## and barely at all while gliding; it refills on the ground. When it's empty
## the wings droop and you can only glide down until you land and rest.
const FLY_CLIMB_V := 6.5
const FLY_GLIDE_V := -1.8
const FLY_TIRED_V := -3.2
const FLY_CEILING := 60.0       # metres above the last ground you flew over
var wing_stamina := 1.0
var wings_tired := false
var flying := false
var _fly_ground_y := 0.0
var _fly_safe := Vector3.ZERO     # the last spot with ground underneath
var _fly_warned := false

func _dragonfly_move(delta: float, target_v: Vector3) -> void:
	# snappy steering in the air (the normal air control is for jumps)
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-ACCEL * 0.7 * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-ACCEL * 0.7 * delta))
	var below := _blocked(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -80.0, 0))
	if not below.is_empty():
		_fly_ground_y = (below.position as Vector3).y
		_fly_safe = global_position
		_fly_warned = false
	elif flying and not free_flight and Game.zone != "home":
		# nothing underneath (off the edge of the map): the dragonfly turns back
		var back := _fly_safe - global_position
		back.y = 0.0
		if back.length() > 0.1:
			var push := back.normalized() * WALK * DRAGONFLY_SPEED * 0.8
			velocity.x = push.x; velocity.z = push.z
		if not _fly_warned:
			_fly_warned = true
			Game.say("Whoa, there's nothing down there! Your dragonfly turns back.", Color(0.5, 1.0, 0.85))
	var climb := input_enabled and Input.is_action_pressed("jump") and not wings_tired
	var under_ceiling := free_flight or Game.zone == "home" or global_position.y < _fly_ground_y + FLY_CEILING
	var dive := input_enabled and Input.is_action_pressed("block") and not climb
	if mount:
		mount.climbing = climb
		mount.tired = wings_tired
	if is_on_floor() and not climb:
		flying = false
		_fly_safe = global_position
		wing_stamina = minf(1.0, wing_stamina + delta / 8.0)
		if wings_tired and wing_stamina >= 0.35:
			wings_tired = false
			Game.say("Your dragonfly has rested. Ready to fly!", Color(0.5, 1.0, 0.85))
		velocity.y = -1.0
		return
	flying = true
	if climb:
		velocity.y = lerpf(velocity.y, FLY_CLIMB_V if under_ceiling else 0.0, 1.0 - exp(-6.0 * delta))
		wing_stamina = maxf(0.0, wing_stamina - delta / 60.0)
	elif dive:
		velocity.y = lerpf(velocity.y, -9.0, 1.0 - exp(-4.0 * delta))     # hold BLOCK to dive
	else:
		velocity.y = lerpf(velocity.y, FLY_TIRED_V if wings_tired else FLY_GLIDE_V, 1.0 - exp(-3.0 * delta))
		wing_stamina = maxf(0.0, wing_stamina - delta / 600.0)
	if wing_stamina <= 0.0 and not wings_tired:
		wings_tired = true
		Game.say("Your dragonfly is tired! Glide down and land so it can rest.", Color(1.0, 0.8, 0.4))

# --- the Giant Chicken mount --------------------------------------------------------
const MOUNT_SPEED := 1.75       # riding is this much faster than running on foot
const MOPED_SPEED := 2.1        # the moped is even faster
const DRAGONFLY_SPEED := 2.4    # and the dragonfly flies faster still
const MOUNT_ORDER := ["chicken", "moped", "dragonfly"]
var mounted := false
var mount = null                 # ChickenMount, MopedMount or DragonflyMount
var mount_kind := ""

func owns_mount(kind: String) -> bool:
	return bool(Game.flags.get("mount_" + kind, false))

func has_mount() -> bool:
	for k in MOUNT_ORDER:
		if owns_mount(k):
			return true
	return false

func has_moped() -> bool:
	return owns_mount("moped")

## G: get on the first mount you own; press again for the next one
## (chicken -> moped -> dragonfly), and after the last one you get off.
func toggle_mount() -> void:
	if dead:
		return
	if free_flight and flying and mounted:
		Game.say("Not up here! Land first.", Color(0.6, 1.0, 0.85))
		return
	var start := 0
	if mounted:
		start = MOUNT_ORDER.find(mount_kind) + 1
		dismount()
	for i in range(start, MOUNT_ORDER.size()):
		if owns_mount(MOUNT_ORDER[i]):
			mount_up(MOUNT_ORDER[i])
			return

## True when G (RIDE) would switch to another mount instead of getting off.
func has_next_mount() -> bool:
	if not mounted:
		return false
	for i in range(MOUNT_ORDER.find(mount_kind) + 1, MOUNT_ORDER.size()):
		if owns_mount(MOUNT_ORDER[i]):
			return true
	return false

func _seat_h() -> float:
	match mount_kind:
		"moped": return MopedMount.SEAT_H
		"dragonfly": return DragonflyMount.SEAT_H
	return ChickenMount.SEAT_H

func _mount_speed() -> float:
	match mount_kind:
		"moped": return MOPED_SPEED
		"dragonfly": return DRAGONFLY_SPEED
	return MOUNT_SPEED

func mount_up(kind := "chicken") -> void:
	if mounted or dead:
		return
	if not owns_mount(kind) and kind != "chicken":
		kind = "chicken"
	mounted = true
	mount_kind = kind
	match kind:
		"moped": mount = MopedMount.new()
		"dragonfly": mount = DragonflyMount.new()
		_: mount = ChickenMount.new()
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
		Sfx.play({"chicken": "cluck", "moped": "beep"}.get(mount_kind, "chirp"), -6.0, 0.1)
		mount.queue_free()
	mount = null
	mount_kind = ""
	flying = false
	_ride_pose(false)

func _ride_pose(on: bool) -> void:
	if body == null:
		return
	body.hold_clip = "Sit_Chair_Idle" if on else ""
	body.position.y = (_seat_h() - 0.46) if on else 0.0

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
	cfg["sex"] = Game.hero_sex()

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
	if vehicle != null:
		if is_instance_valid(vehicle):
			_vehicle_look(delta)
			return
		leave_vehicle()
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
			if Input.is_action_just_pressed("auto_run"):
				set_auto_run(not auto_run)
			if auto_run:
				# keep running forward (the way the camera looks); left/right still steer,
				# pulling back stops it
				if iv.y > 0.5:
					set_auto_run(false)
				else:
					iv = Vector2(iv.x * 0.6, -1.0).limit_length(1.0)
			_move_input = iv
			dir = Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, view_yaw)
			dir = _shroom_wobble(dir)
			if Input.is_action_just_pressed("jump"):
				_jump_buffer = 0.18
		if Input.is_action_just_pressed("pose") and not dead:
			toggle_pose()
	else:
		_move_input = Vector2.ZERO
	if mounted and mount_kind == "dragonfly":
		_jump_buffer = 0.0      # on the dragonfly, jump means climb (see _dragonfly_move)
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
				velocity.y = JUMP_V * (1.25 if mounted else 1.0) * jump_mult   # jumping never needs stamina: it must always get you out of trouble
				Game.stamina = maxf(0.0, Game.stamina - 6.0)
				_coyote = 0.0
				_jump_buffer = 0.0
				_air_jumps = 1
			elif _air_jumps == 1:
				_double_jump()
	var sprinting := input_enabled and Input.is_action_pressed("sprint") and dir.length() > 0.1 and Game.stamina > 1 and not blocking
	var speed := (SPRINT if sprinting else WALK) * (1.15 if Game.has_buff("quick") else 1.0)
	if mounted:
		speed *= _mount_speed()
	if haste_t > 0.0:
		speed *= 1.45      # Smoke Bomb dash
	if blocking and not (mounted and flying):      # (on a flying dragonfly, BLOCK is a dive)
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
	var a := ACCEL * grip if is_on_floor() else AIR_ACCEL
	velocity.x = lerpf(velocity.x, target_v.x + wind.x, 1.0 - exp(-a * delta))
	velocity.z = lerpf(velocity.z, target_v.z + wind.z, 1.0 - exp(-a * delta))
	if mounted and mount_kind == "dragonfly":
		_dragonfly_move(delta, target_v)
	elif lift > -100.0:
		velocity.y = lerpf(velocity.y, lift, 1.0 - exp(-4.0 * delta))    # riding a bubble
	elif not is_on_floor():
		velocity.y -= GRAVITY * gravity_mult * delta
		velocity.y = maxf(velocity.y, -fall_cap)
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
	if blocking:
		# raise the shield toward whoever is about to hit you, wherever the camera points
		var gt := _guard_target()
		if gt:
			var tg := gt.global_position - global_position
			want = atan2(-tg.x, -tg.z)
	if dodging and not strafe:
		want = atan2(-dodge_dir.x, -dodge_dir.z)
	if posing:
		want = facing          # stand still and let the camera go round
	var turn := 22.0 if strafe else (18.0 if attacking else 12.0)
	if blocking:
		turn = 30.0
	if special_kind == "charge":
		want = atan2(-_charge_dir.x, -_charge_dir.z)
	facing = lerp_angle(facing, want, 1.0 - exp(-turn * delta))
	body.rotation.y = facing
	_update_guard_fx(delta)
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

var _pet_check := 0.5
func _update_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	_pet_check -= delta
	if _pet_check <= 0.0:
		_pet_check = 1.0
		_ensure_pet()
	_burn_step(delta)
	if second_wind_t > 0.0:
		second_wind_t -= delta
		Game.stamina = Game.max_stamina()
		if second_wind_t <= 0.0 and _wind_fx and is_instance_valid(_wind_fx):
			_wind_fx.emitting = false
	potion_cd = maxf(0.0, potion_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	special2_cd = maxf(0.0, special2_cd - delta)
	if ward_t > 0.0:
		ward_t -= delta
		if ward_t <= 0.0 and _ward_fx and is_instance_valid(_ward_fx):
			_ward_fx.queue_free()
	if haste_t > 0.0:
		haste_t -= delta
	if blocking:
		block_time += delta
	if special_kind != "":
		_special_step(delta)
	if hurt_time >= 0.0:
		hurt_time += delta
		if hurt_time > 0.3:
			hurt_time = -1.0
	_attack_buffer -= delta
	stamina_delay -= delta
	if stamina_delay <= 0.0 and not blocking:
		Game.stamina = minf(Game.max_stamina(), Game.stamina + 30.0 * delta * (1.7 if Game.has_buff("fed") else 1.0))
	Game.tick_buffs(delta)
	if Game.shroom > 0.0:
		Game.shroom = maxf(0.0, Game.shroom - delta / 10.0)     # one mushroom wears off in about 13 s
		_shroom_t += delta
		if Game.shroom >= 5.0 and is_on_floor() and not mounted and vehicle == null:
			# far too many mushrooms: you wobble about on your own
			velocity.x += sin(_shroom_t * 1.9) * 9.0 * delta
			velocity.z += cos(_shroom_t * 1.3) * 9.0 * delta
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
	# any fighting move hops you off the chicken first (but not off a flying dragonfly!)
	if mounted and not (mount_kind == "dragonfly" and flying) and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("block") or Input.is_action_just_pressed("dodge")
			or Input.is_action_just_pressed("spell") or Input.is_action_just_pressed("special") or Input.is_action_just_pressed("special2")):
		dismount()
	# Attack never ignores you: a press is remembered for a moment (so pressing
	# during a dodge, a spell or early in a swing still counts), holding the
	# button keeps swinging, and a tired hero still swings (just slower to recover).
	if Input.is_action_just_pressed("attack"):
		_attack_buffer = 0.4
	var holding := Input.is_action_pressed("attack")
	var free_to_swing := not dodging and special_kind == "" and not (mounted and not flying) and not Input.is_action_pressed("block")
	if casting and cast_time > 0.2 and (_attack_buffer > 0.0 or holding):
		casting = false          # the bolt has already flown: cut the cast short
	if free_to_swing and not casting:
		if not attacking:
			if _attack_buffer > 0.0 or holding:
				_attack_buffer = 0.0
				_start_attack(0)
		elif _attack_buffer > 0.0 or (holding and attack_time / attack_dur > 0.5):
			_attack_buffer = 0.0
			combo_queued = true
	# Block raises instantly, even mid-swing (the swing is cancelled), so it can
	# be used on reaction. The first PARRY_WINDOW seconds count as a parry.
	var want_block := Input.is_action_pressed("block") and not dodging and special_kind == "" and Game.stamina > 2.0
	if Input.is_action_just_pressed("block") and Game.stamina <= 2.0:
		Game.say("Too tired to block! Wait for your yellow bar.", Color(1.0, 0.8, 0.4))
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
	if Input.is_action_just_pressed("special2"):
		use_special2()
	if Input.is_action_just_pressed("mana_potion"):
		drink_mana_potion()
	if Input.is_action_just_pressed("stamina_potion"):
		drink_stamina_potion()
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

# --- rainbow vision (glowing mushrooms, see RainbowShroom) -------------------------
var _shroom_t := 0.0
var _dizzy_msg_t := 0.0

## From three mushrooms on, your steering drifts; at five it barely does what you ask.
func _shroom_wobble(dir: Vector3) -> Vector3:
	if Game.shroom <= 2.0 or dir.length() < 0.1:
		return dir
	var wob := (minf(Game.shroom, 5.0) - 2.0) * 0.3
	var d := dir.rotated(Vector3.UP, sin(_shroom_t * 1.7) * wob)
	if Game.shroom >= 5.0:
		d = d.rotated(Vector3.UP, sin(_shroom_t * 0.6) * 1.6) * 0.6
	return d

func _dizzy_say(text: String) -> void:
	if Time.get_ticks_msec() / 1000.0 - _dizzy_msg_t > 2.5:
		_dizzy_msg_t = Time.get_ticks_msec() / 1000.0
		Game.say(text, Color.from_hsv(randf(), 0.5, 1.0))

func _start_attack(kind: int) -> void:
	swings += 1
	combo = kind
	attacking = true
	attack_time = 0.0
	attack_dur = 0.72 if kind == 2 else 0.52
	hit_done = false
	# far too many mushrooms: most swings go wide (decided once per swing, so
	# holding the button doesn't just try again every frame)
	if Game.shroom >= 5.0 and randf() < 0.7:
		hit_done = true
		whiffs += 1
		_dizzy_say("You swing at a rainbow... and miss!")
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
	bolts_fired += 1
	# the bolt grows up with you: bigger and brighter, then two, then three
	# crackling bolts, then lightning that leaps on to a second enemy
	var tier := bolt_tier()
	var t: Dictionary = BOLT_TIERS[tier]
	var sp := Game.spell_power()
	var count: int = t.count
	var side := fwd.cross(Vector3.UP).normalized()
	for i in count:
		var bb: Area3D = b if i == 0 else Area3D.new()
		if i > 0:
			bb.set_script(bolt_scene_script)
		var spread := (i - (count - 1) * 0.5)
		bb.position = b.position + side * spread * 0.45
		get_tree().current_scene.add_child(bb)
		bb.size = float(t.size) + clampf(sp / 60.0, 0.0, 1.0)
		bb.splash = float(t.splash)
		bb.chain = bool(t.get("chain", false))
		bb.sparkle = tier >= 3
		var d := fwd.rotated(Vector3.UP, -spread * 0.06)
		bb.launch(d, "player", Game.spell_damage() * float(t.dmg) / count, t.color, 24.0 + tier * 2.0)
	if tier >= 3:
		Sfx.play("spell", -4.0, 0.15)

## The bolt levels up with you (name, level it arrives, bolts, size, damage, blast).
const BOLT_TIERS := [
	{"name": "Arcane Bolt", "level": 1, "count": 1, "size": 1.0, "dmg": 1.0, "splash": 0.0, "color": Color(0.45, 0.7, 1.0)},
	{"name": "Greater Bolt", "level": 4, "count": 1, "size": 1.5, "dmg": 1.15, "splash": 2.0, "color": Color(0.6, 0.55, 1.0)},
	{"name": "Twin Bolts", "level": 8, "count": 2, "size": 1.4, "dmg": 1.35, "splash": 2.5, "color": Color(0.8, 0.45, 1.0)},
	{"name": "Storm Bolts", "level": 12, "count": 3, "size": 1.5, "dmg": 1.6, "splash": 3.0, "color": Color(1.0, 0.85, 0.4)},
	{"name": "Star Bolts", "level": 16, "count": 3, "size": 1.8, "dmg": 1.9, "splash": 3.5, "color": Color(0.95, 0.95, 1.0), "chain": true},
]

func bolt_tier() -> int:
	var t := 0
	for i in BOLT_TIERS.size():
		if Game.level >= int(BOLT_TIERS[i].level):
			t = i
	return t

func _on_level_up(lv: int) -> void:
	for i in BOLT_TIERS.size():
		if int(BOLT_TIERS[i].level) == lv and i > 0:
			Game.say("Your bolt grew stronger: %s! (Q / BOLT)" % BOLT_TIERS[i].name, BOLT_TIERS[i].color)
			FX.burst(global_position + Vector3(0, 1.4, 0), BOLT_TIERS[i].color, 50, 4.0, 0.2, 0.9, 0.5)

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

## Energy potion: stamina back to full, then a Second Wind: for a while running,
## rolling, blocking and swinging cost nothing (and tired dragonfly wings recover).
var second_wind_t := 0.0
var _wind_fx: CPUParticles3D
func drink_stamina_potion() -> void:
	if potion_cd > 0.0:
		return
	if Game.stamina_potions <= 0:
		Game.say("No energy potions left.", Color(0.9, 1.0, 0.5))
		return
	Game.stamina_potions -= 1
	potion_cd = 1.0
	Game.stamina = Game.max_stamina()
	second_wind_t = 12.0
	wing_stamina = 1.0
	wings_tired = false
	Sfx.play("sip", -4.0)
	Sfx.play("levelup", -14.0, 0.2)
	FX.burst(global_position + Vector3(0, 1.0, 0), Color(0.75, 1.0, 0.3), 36, 3.0)
	Game.say("Second Wind! Endless energy for a few seconds.", Color(0.8, 1.0, 0.45))
	if _wind_fx == null or not is_instance_valid(_wind_fx):
		_wind_fx = CPUParticles3D.new(); _wind_fx.amount = 24; _wind_fx.lifetime = 0.8
		_wind_fx.mesh = FX.quad(0.1); _wind_fx.material_override = FX.glow_material(Color(0.75, 1.0, 0.35), 2.5)
		_wind_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _wind_fx.emission_sphere_radius = 0.6
		_wind_fx.direction = Vector3.UP; _wind_fx.spread = 30; _wind_fx.initial_velocity_min = 0.8; _wind_fx.initial_velocity_max = 1.6
		_wind_fx.gravity = Vector3.ZERO; _wind_fx.color_ramp = FX._fade_ramp(Color(0.75, 1.0, 0.35))
		_wind_fx.position.y = 0.9
		add_child(_wind_fx)
	_wind_fx.emitting = true
	Game.stats_changed.emit()

# ---------------------------------------------------------------------------
func take_damage(amount: float, from_pos: Vector3, knock := 3.0, _crit := false) -> void:
	if dead or invuln > 0.0:
		return
	var to_src := from_pos - global_position
	to_src.y = 0
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	# the shield covers everything but your back (about 240 degrees)
	var blocked := blocking and (to_src.length() < 0.01 or fwd.dot(to_src.normalized()) > -0.5)
	var dmg := Game.mitigate(amount)
	if ward_t > 0.0:
		dmg *= 0.3        # Holy Ward
		FX.sparks(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.9, 0.45))
	if blocked:
		if block_time < PARRY_WINDOW:
			_parry(from_pos)
			return
		var cost := maxf(3.0, dmg * 0.5)
		if Game.stamina >= cost:
			Game.stamina -= cost
			dmg = 0.0 if amount < 40.0 else dmg * 0.15   # only the Warden's biggest blows get through a little
			blocks += 1
			Sfx.play("clang", -3.0)
			_guard_hit = 1.0
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
			FX.burst(global_position + Vector3(0, 1.2, 0) + fwd * 0.7, Color(0.55, 0.8, 1.0), 40, 5.0, 0.12, 0.5, -6.0)
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

## Riding something (a swing, the hot air balloon): the vehicle moves you each
## physics frame and reads the controls it cares about; you can still look
## around and zoom. `pose` is the body clip to hold (e.g. sitting).
var vehicle: Node = null
func ride_vehicle(v: Node, pose := "") -> void:
	if mounted:
		dismount()
	set_auto_run(false)
	attacking = false; blocking = false; casting = false; dodging = false
	vehicle = v
	velocity = Vector3.ZERO
	body.hold_clip = pose
	body.grounded = true
	body.move_speed = 0.0

func leave_vehicle(launch := Vector3.ZERO) -> void:
	vehicle = null
	body.hold_clip = ""
	velocity = launch

func _vehicle_look(delta: float) -> void:
	var lk := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if lk.length() > 0.05:
		yaw -= lk.x * 2.2 * delta
		pitch = clampf(pitch - lk.y * 1.3 * delta, PITCH_MIN, PITCH_MAX)
	velocity = Vector3.ZERO
	body.rotation.y = facing
	body.grounded = true
	body.move_speed = 0.0

## Fire (vents, lava): a shield can't stop it, and you keep burning a moment.
var _burn_t := 0.0
var _burn_dps := 0.0
var _burn_fx: CPUParticles3D
func burn(amount: float, secs: float, dps: float) -> void:
	if dead or invuln > 0.0:
		return
	var was := blocking
	blocking = false
	take_damage(amount, global_position, 0.0)
	blocking = was
	# it should feel like fire: an orange flash, a jolt, a yelp
	FX.screen_flash(Color(1.0, 0.45, 0.1), 0.45, 0.45)
	add_trauma(0.3)
	Sfx.play("fire_burst", -8.0, 0.15)
	_burn_t = maxf(_burn_t, secs)
	_burn_dps = dps
	if _burn_fx == null or not is_instance_valid(_burn_fx):
		_burn_fx = CPUParticles3D.new(); _burn_fx.amount = 36; _burn_fx.lifetime = 0.5
		_burn_fx.mesh = FX.quad(0.3); _burn_fx.material_override = FX.glow_material(Color(1.0, 0.5, 0.15), 2.5)
		_burn_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _burn_fx.emission_box_extents = Vector3(0.3, 0.7, 0.3)
		_burn_fx.direction = Vector3.UP; _burn_fx.spread = 15; _burn_fx.initial_velocity_min = 1.5; _burn_fx.initial_velocity_max = 2.5
		_burn_fx.gravity = Vector3(0, 2, 0); _burn_fx.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.15))
		_burn_fx.position.y = 1.0
		add_child(_burn_fx)
	_burn_fx.emitting = true

func _burn_step(delta: float) -> void:
	if _burn_t <= 0.0:
		return
	_burn_t -= delta
	if not dead:
		Game.hp -= _burn_dps * delta
		damage_taken += _burn_dps * delta
		if Game.hp <= 0.0:
			die()
	if _burn_t <= 0.0 or dead:
		_burn_t = 0.0
		if _burn_fx and is_instance_valid(_burn_fx):
			_burn_fx.emitting = false

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
	auto_run = false
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
		if absf(to.y) > 3.5:
			continue      # on another floor (e.g. the graveyard door right above the crypt)
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
	# on the ground, feel for a ledge at knee height. In the air (pressing JUMP again
	# as you reach a ledge) feel from just below your feet up to chest height, and
	# grab any ledge from a little below your feet to 2 m above them.
	var airborne := not is_on_floor()
	var wall := {}
	for hr in ([-0.25, 0.15, 0.35, 0.9] if airborne else [0.35]):
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, hr, 0), feet + Vector3(0, hr, 0) + fwd * 0.95, 1)
		q.exclude = [get_rid()]
		wall = space.intersect_ray(q)
		if not wall.is_empty():
			break
	if wall.is_empty():
		return false
	var probe_xz: Vector3 = wall.position + fwd * 0.5
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(probe_xz.x, feet.y + 2.2, probe_xz.z), Vector3(probe_xz.x, feet.y - 0.35, probe_xz.z), 1)
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var h: float = top.position.y - feet.y
	if h < (-0.3 if airborne else 0.45) or h > 2.0:
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

# --- auto-run -----------------------------------------------------------------------
var auto_run := false

func set_auto_run(on: bool) -> void:
	if on == auto_run:
		return
	auto_run = on
	Game.say("Auto-run ON (pull back or tap AUTO to stop)" if on else "Auto-run off", Color(0.8, 0.9, 1.0))

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
	auto_run = false
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
	# a giant boss close by: pull back (third person only) so the whole boss fits
	_boss_scan -= delta
	if _boss_scan <= 0.0:
		_boss_scan = 0.25
		_boss_near = false
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and not e.dead and e.t.has("look_size") and e.global_position.distance_to(global_position) < 18.0:
				_boss_near = true
				break
	var zt := zoom_target
	if _boss_near and zoom_target >= FP_THRESHOLD:
		zt = maxf(zoom_target, BOSS_ZOOM)
	zoom = lerpf(zoom, zt, 1.0 - exp(-(9.0 if zt == zoom_target else 3.0) * delta))
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
		pitch = lerpf(pitch, -0.04 if _boss_near else -0.18, 1.0 - exp(-0.9 * delta))
	# --- follow the interpolated body position
	var base := get_global_transform_interpolated().origin
	# near a giant boss, look from a bit higher so the boss's head stays on screen
	_boss_lift = lerpf(_boss_lift, 1.2 if _boss_near and not fp else 0.0, 1.0 - exp(-2.0 * delta))
	var head_pos := base + Vector3(0, EYE_H * float(Game.profile.get("height", 1.0)) + ((_seat_h() - 0.46) if mounted else 0.0) + _boss_lift, 0)
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
	# --- shoulder offset shrinks when the camera is squeezed by walls. The room
	# is measured straight back from the head (not from where the camera ended
	# up), so moving the camera can't change it and set off a back-and-forth.
	var room := zoom
	if zoom > 0.05 and not fp:
		var q0 := PhysicsShapeQueryParameters3D.new()
		q0.shape = _probe
		q0.transform = Transform3D(Basis.IDENTITY, cam_pitch.global_position)
		q0.motion = cam_pitch.global_transform.basis.z * zoom
		q0.collision_mask = 1
		q0.exclude = [get_rid()]
		var r0 := get_world_3d().direct_space_state.cast_motion(q0)
		if r0.size() == 2 and r0[0] < 1.0:
			room = zoom * r0[0]
	_squeeze = lerpf(_squeeze, clampf(room / maxf(zoom, 0.01), 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	if absf(_squeeze - room / maxf(zoom, 0.01)) < 0.002:
		_squeeze = clampf(room / maxf(zoom, 0.01), 0.0, 1.0)
	var squeeze := _squeeze
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
		# Judge every option from the camera's direction *without* the current
		# crane, so the choice doesn't feed back on itself (that made the view
		# tremble when standing still next to a wall or the portal arch), and
		# only switch when another option is clearly better.
		var side := arm.global_transform.basis.x.normalized()
		var base_dir: Vector3 = arm.global_transform.basis.z.rotated(side, _crane)
		var options := [0.0, 0.3, 0.6, 0.9] if high_t() < 0.5 else [0.0, 0.3, 0.5]
		var scores := {}
		if want > 1.5:
			for extra in options:
				q.motion = base_dir.rotated(side, -extra) * want
				var r2 := space.cast_motion(q)
				var s2: float = want if r2.size() < 2 or r2[0] >= 1.0 else maxf(0.0, want * r2[0] - 0.05)
				scores[extra] = s2 - extra * 0.9
		var best_extra := _crane_pick
		if scores.is_empty():
			best_extra = 0.0
		else:
			var top: float = options[0]
			for extra in options:
				if scores[extra] > scores[top]:
					top = extra
			if not scores.has(_crane_pick) or scores[top] > scores[_crane_pick] + 0.6:
				best_extra = top
		_crane_pick = best_extra
		_crane = lerpf(_crane, best_extra, 1.0 - exp(-4.0 * delta))
		if absf(_crane - best_extra) < 0.002:
			_crane = best_extra
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
	# rainbow vision (glowing mushrooms): the view breathes in and out and sways
	var trip := clampf(Game.shroom, 0.0, 5.0) / 5.0
	var trip_on := smoothstep(0.0, 0.6, Game.shroom)
	camera.rotation.z = sin(tt * 23.0) * 0.04 * sh + sin(tt * 0.8) * deg_to_rad(1.5 + 4.5 * trip) * trip_on
	var trip_fov := sin(tt * 1.3) * (3.0 + 8.0 * trip) * trip_on
	var sprint_kick := 5.0 if hspeed > WALK + 0.8 else 0.0
	fov_kick = maxf(0.0, fov_kick - delta * 30.0)
	camera.fov = lerpf(camera.fov, (80.0 if fp else 74.0) + sprint_kick + fov_kick + trip_fov, 1.0 - exp(-(5.0 if fov_kick < 0.5 else 14.0) * delta))

var _head_hidden := false
var kill_y := -40.0      # falling below this is death (the forest Warren sits deeper)
var _crane := 0.0
var _crane_pick := 0.0
var _squeeze := 1.0
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
		if is_instance_valid(e) and e != self and e.has_method("take_damage") and e.get("dead") != true and e is Node3D \
				and not e.is_in_group("critter"):     # specials never aim at the chickens
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
	if Game.shroom >= 5.0:
		_dizzy_say("You're far too dizzy to concentrate!")
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
		"Mage": ok = _fireball()
		"Knight": ok = _start_charge()
		"Barbarian": ok = _start_whirl()
		"Ranger": ok = _volley()
		"Priest": ok = _holy_smite()
		"Druid": ok = _entangling_roots()
		"Necromancer": ok = _raise_dead()
		"Beastmaster": ok = _sic_em()
	if ok:
		special_cd = ab.cd
		specials_used += 1

# ---------------------------------------------------------------------------
# Second special abilities (Game.ABILITIES2): every class learns one on
# arriving at Ghost Knight Castle. B / 3 on a keyboard, its own touch button.
var special2_cd := 0.0
var specials2_used := 0
var ward_t := 0.0
var haste_t := 0.0
var _ward_fx: MeshInstance3D

func special2_ready() -> bool:
	return Game.has_special2() and special2_cd <= 0.0

func use_special2() -> void:
	if dead or mantling or not input_enabled or not Game.has_special2() or special_kind != "":
		return
	var ab := Game.ability2()
	if special2_cd > 0.0:
		Game.say("%s ready in %ds." % [ab.name, ceili(special2_cd)], Color(0.75, 0.9, 1.0))
		return
	attacking = false; casting = false; dodging = false; combo_queued = false; blocking = false
	match Game.profile.hero:
		"Knight": _holy_ward()
		"Barbarian": _earthshatter()
		"Rogue": _smoke_bomb()
		"Ranger": _rain_of_arrows()
		"Priest": _prayer_of_light()
		"Druid": _wild_growth()
		"Necromancer": _soul_drain()
		"Beastmaster": _bear_friend()
		_: _frost_nova()
	special2_cd = ab.cd
	specials2_used += 1

## Knight: a golden dome; 70% less damage for 5 s, heals, knocks foes away.
func _holy_ward() -> void:
	var gold := Color(1.0, 0.88, 0.4)
	ward_t = 5.0
	heal(Game.max_hp() * 0.25)
	_aoe(global_position, 4.5, Game.attack_damage() * 1.2, 14.0, true)
	if _ward_fx and is_instance_valid(_ward_fx):
		_ward_fx.queue_free()
	_ward_fx = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.25; sm.height = 2.5; sm.radial_segments = 24; sm.rings = 12
	_ward_fx.mesh = sm
	_ward_fx.material_override = FX._add_mat(gold, 0.7)
	(_ward_fx.material_override as StandardMaterial3D).albedo_color.a = 0.35
	_ward_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ward_fx)
	_ward_fx.position = Vector3(0, 1.0, 0)
	FX.dome(global_position, gold, 4.5, 0.5)
	FX.pillar(global_position, gold, 1.6, 10.0, 0.8)
	FX.burst(global_position + Vector3(0, 1.2, 0), gold, 70, 5.0, 0.25, 1.0, 1.0)
	FX.screen_flash(gold, 0.3, 0.4)
	Sfx.play("levelup", -4.0, 0.05)
	add_trauma(0.3)

## Barbarian: hop up and smash down; a shockwave stuns everything nearby.
func _earthshatter() -> void:
	velocity.y = JUMP_V * 0.9
	var col := Color(0.95, 0.6, 0.25)
	invuln = maxf(invuln, 0.7)
	await get_tree().create_timer(0.42, false).timeout
	if dead:
		return
	var at := global_position
	var n := _aoe(at, 6.5, Game.attack_damage() * 2.4, 13.0, true)
	FX.shockwave(at, col, 7.5, 0.55)
	FX.shockwave(at, Color(0.6, 0.45, 0.3), 5.0, 0.4)
	FX.burst(at + Vector3(0, 0.4, 0), Color(0.55, 0.45, 0.35), 90, 8.0, 0.4, 1.0, -9.0)
	for k in 8:
		var a := k * TAU / 8.0
		FX.burst(at + Vector3(cos(a) * 3.5, 0.3, sin(a) * 3.5), col, 12, 4.0, 0.3, 0.6, -6.0)
	FX.flash_light(at + Vector3(0, 1, 0), col, 9.0, 12.0, 0.4)
	FX.screen_flash(col, 0.25, 0.3)
	Sfx.play("slam", 0.0, 0.05)
	add_trauma(0.75 if n > 0 else 0.5)
	_hitstop(0.1)

## Rogue: a cloud of poison smoke; you vanish for a moment and dash off fast.
func _smoke_bomb() -> void:
	var green := Color(0.45, 0.9, 0.4)
	var at := global_position
	_aoe(at, 4.0, Game.attack_damage() * 1.0, 3.0, true)
	FX.shadow_pool(at, Color(0.35, 0.75, 0.3), 4.0, 4.0, Game.attack_damage() * 0.6)
	FX.burst(at + Vector3(0, 1.0, 0), Color(0.55, 0.7, 0.5), 110, 3.5, 0.6, 1.6, 0.8)
	FX.dome(at, green, 4.0, 0.5)
	invuln = maxf(invuln, 2.0)
	haste_t = 4.0
	# enemies lose track of you
	for e in _live_enemies():
		if e.global_position.distance_to(at) < 14.0 and e.get("state") != null and e.has_method("lose_target"):
			e.lose_target()
	Sfx.play("fire_burst", -4.0, 0.1)
	fov_kick = 10.0

## Ranger: arrows rain down over a wide spot ahead of you for 1.5 s.
func _rain_of_arrows() -> void:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var at := global_position + fwd * 9.0
	var best: Node3D = null
	var bd := 14.0
	for e in _live_enemies():
		var d: float = e.global_position.distance_to(global_position)
		if d < bd and fwd.dot((e.global_position - global_position).normalized()) > 0.2:
			bd = d; best = e
	if best:
		at = best.global_position
	var fl = _floor_at(at)
	if fl != null:
		at = fl
	var col := Color(0.75, 1.0, 0.6)
	FX.shockwave(at, col, 5.0, 0.4)
	casting = true; cast_time = 0.15
	Sfx.play("swing", -2.0, 0.1)
	for wave in 6:
		await get_tree().create_timer(0.25, false).timeout
		if dead:
			return
		for k in 7:
			var p := at + Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
			FX.beam(p + Vector3(randf_range(-1.0, 1.0), 9.0, randf_range(-1.0, 1.0)), p, col, 0.08, 0.18)
			FX.burst(p + Vector3(0, 0.1, 0), Color(0.75, 0.65, 0.45), 4, 2.0, 0.12, 0.4, -4.0)
		_aoe(at, 5.0, Game.attack_damage() * 0.75, 1.5, wave == 5)
		Sfx.play("hit", -10.0, 0.25)

# ---------------------------------------------------------------------------
# The four newer classes (Priest, Druid, Necromancer, Beastmaster)

## The foe you're facing (or the closest one roughly in front), if any.
func _aim_target(max_d := 20.0, min_dot := 0.25) -> Node3D:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var head := global_position + Vector3(0, 1.3, 0)
	var best: Node3D = null
	var bs := INF
	for e in _live_enemies():
		var to: Vector3 = e.global_position - global_position
		var d := to.length()
		if d > max_d or absf(to.y) > 4.0:
			continue
		var fd := fwd.dot(Vector3(to.x, 0, to.z).normalized()) if d > 0.1 else 1.0
		if fd < min_dot or not _blocked(head, e.global_position + Vector3(0, 1.0, 0)).is_empty():
			continue
		var sc := d - fd * 6.0
		if sc < bs:
			bs = sc; best = e
	return best

func _ahead_floor(dist: float) -> Vector3:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var at := global_position + fwd * dist
	var hit := _blocked(global_position + Vector3(0, 1.2, 0), at + Vector3(0, 1.2, 0))
	if not hit.is_empty():
		at = (hit.position as Vector3) - fwd * 0.6
	var fl = _floor_at(at)
	return fl if fl != null else at

## Priest: a pillar of golden light crashes down on the foe in front.
func _holy_smite() -> bool:
	var tgt := _aim_target(20.0)
	var at: Vector3 = tgt.global_position if tgt else _ahead_floor(8.0)
	var gold := Color(1.0, 0.88, 0.45)
	casting = true; cast_time = 0.2
	FX.pillar(at, gold, 1.6, 14.0, 0.9)
	FX.flash_light(at + Vector3(0, 2, 0), gold, 10.0, 12.0, 0.5)
	Sfx.play("spell", -3.0, 0.05)
	get_tree().create_timer(0.22, false).timeout.connect(func() -> void:
		if dead:
			return
		_aoe(at, 3.4, Game.attack_damage() * 2.2 + Game.spell_damage() * 1.4, 6.0, true)
		FX.shockwave(at + Vector3(0, 0.15, 0), gold, 4.0, 0.4)
		FX.burst(at + Vector3(0, 0.8, 0), Color(1.0, 0.95, 0.7), 70, 7.0, 0.2, 0.9, -1.0)
		Sfx.play("spell_hit", 0.0, 0.05)
		add_trauma(0.3)
		heal(Game.max_hp() * 0.1))
	return true

## Priest: heal a lot now and more over a few seconds; dazzle foes around you.
func _prayer_of_light() -> void:
	var gold := Color(1.0, 0.95, 0.7)
	heal(Game.max_hp() * 0.4)
	casting = true; cast_time = 0.25
	FX.dome(global_position, gold, 6.0, 0.6)
	FX.pillar(global_position, gold, 1.0, 10.0, 1.2)
	FX.screen_flash(gold, 0.35, 0.5)
	Sfx.play("levelup", -4.0, 0.0)
	for e in _live_enemies():
		var to: Vector3 = e.global_position - global_position
		if absf(to.y) < 3.0 and Vector2(to.x, to.z).length() < 6.5:
			_special_hit_enemy(e, Game.spell_damage() * 0.8, 6.0, false, true)
			if e.has_method("lose_target"):
				e.lose_target(2.5)
	for k in 10:
		await get_tree().create_timer(0.5, false).timeout
		if dead:
			return
		heal(Game.max_hp() * 0.035)
		FX.burst(global_position + Vector3(0, 1.0, 0), gold, 8, 1.5, 0.12, 0.8, 1.0)

## Druid: thorny roots burst up ahead and hold every foe there.
func _entangling_roots() -> bool:
	var tgt := _aim_target(16.0)
	var at: Vector3 = tgt.global_position if tgt else _ahead_floor(6.0)
	var green := Color(0.45, 0.85, 0.3)
	casting = true; cast_time = 0.2
	Sfx.play("collapse", -6.0, 0.1)
	FX.shockwave(at + Vector3(0, 0.1, 0), green, 5.0, 0.5)
	FX.burst(at + Vector3(0, 0.3, 0), Color(0.45, 0.32, 0.18), 50, 5.0, 0.25, 0.8, -6.0)
	var vine := StandardMaterial3D.new(); vine.albedo_color = Color(0.25, 0.45, 0.15); vine.roughness = 0.8
	var thorns := Node3D.new(); get_tree().current_scene.add_child(thorns); thorns.global_position = at
	for k in 16:
		var a := randf() * TAU
		var r := sqrt(randf()) * 4.0
		var v := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = randf_range(0.08, 0.16)
		cm.height = randf_range(1.0, 2.2); cm.radial_segments = 6
		v.mesh = cm; v.material_override = vine
		v.position = Vector3(cos(a) * r, 0.0, sin(a) * r); v.rotation = Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		v.scale = Vector3(1, 0.01, 1)
		thorns.add_child(v)
		var tw := v.create_tween()
		tw.tween_property(v, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(3.6)
		tw.tween_property(v, "scale", Vector3(1, 0.01, 1), 0.4)
	get_tree().create_timer(4.5, false).timeout.connect(thorns.queue_free)
	for e in _live_enemies():
		var to: Vector3 = e.global_position - at
		if absf(to.y) < 3.0 and Vector2(to.x, to.z).length() < 4.5 + _hit_radius(e):
			_special_hit_enemy(e, Game.attack_damage() * 1.5 + Game.spell_damage() * 0.9, 0.0, false, false)
			if e.has_method("freeze"):
				e.freeze(3.5, "roots")
	return true

## Druid: a ring of flowers that heals you inside it and pricks foes.
func _wild_growth() -> void:
	var at := global_position
	var ring := Node3D.new(); get_tree().current_scene.add_child(ring); ring.global_position = at
	var cols := [Color(1.0, 0.5, 0.7), Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 1.0), Color(1.0, 1.0, 1.0)]
	var stem := StandardMaterial3D.new(); stem.albedo_color = Color(0.3, 0.65, 0.25)
	for k in 22:
		var a := k * TAU / 22.0
		var f := Node3D.new(); f.position = Vector3(cos(a) * 4.0, 0, sin(a) * 4.0); f.scale = Vector3.ONE * 0.01; ring.add_child(f)
		var st := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.03; cm.height = 0.5
		st.mesh = cm; st.material_override = stem; st.position.y = 0.25; f.add_child(st)
		var bl := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.18
		var pm := StandardMaterial3D.new(); pm.albedo_color = cols[k % cols.size()]; pm.emission_enabled = true
		pm.emission = cols[k % cols.size()]; pm.emission_energy_multiplier = 0.6
		bl.mesh = sm; bl.material_override = pm; bl.position.y = 0.55; f.add_child(bl)
		f.create_tween().tween_property(f, "scale", Vector3.ONE * randf_range(0.9, 1.4), 0.4).set_delay(k * 0.02).set_trans(Tween.TRANS_BACK)
	var glow := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 3.85; tm.outer_radius = 4.15
	glow.mesh = tm; glow.material_override = FX.beam_material(Color(0.6, 1.0, 0.45), 1.5, 0.7); glow.scale = Vector3(1, 0.08, 1)
	glow.position.y = 0.1; ring.add_child(glow)
	var l := OmniLight3D.new(); l.light_color = Color(0.6, 1.0, 0.5); l.light_energy = 1.5; l.omni_range = 7.0
	l.position.y = 1.5; ring.add_child(l)
	casting = true; cast_time = 0.25
	Sfx.play("levelup", -8.0, 0.2)
	for tick in 16:
		await get_tree().create_timer(0.5, false).timeout
		if not is_instance_valid(ring):
			return
		if not dead and global_position.distance_to(at) < 4.3:
			heal(Game.max_hp() * 0.035)
			FX.burst(global_position + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.5), 6, 1.5, 0.1, 0.7, 1.0)
		for e in _live_enemies():
			var to: Vector3 = e.global_position - at
			if absf(to.y) < 3.0 and Vector2(to.x, to.z).length() < 4.2:
				_special_hit_enemy(e, Game.attack_damage() * 0.35 + Game.spell_damage() * 0.2, 0.5)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(1, 0.01, 1), 0.5)
	tw.tween_callback(ring.queue_free)

## Necromancer: the ground cracks with green fire and three skeleton warriors
## claw their way up out of it to fight for you.
var _raises := 0
func _raise_dead() -> bool:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var side := fwd.cross(Vector3.UP)
	var green := Color(0.45, 1.0, 0.5)
	casting = true; cast_time = 0.45
	body._last_cast_t = 1.0           # (so the usual quick cast pose doesn't replace this one)
	body.play_role("Spellcast_Raise", 0.9)
	Sfx.play("spell", -4.0, 0.1)
	Sfx.play("rumble", -6.0, 0.1)
	add_trauma(0.25)
	FX.shockwave(global_position + Vector3(0, 0.1, 0), green, 5.0, 0.6)
	FX.flash_light(global_position + Vector3(0, 1.5, 0), green, 6.0, 10.0, 0.6)
	_raises += 1
	if _raises <= 3:
		Game.say("Rise, my servants!", green)
	for k in 3:
		var at: Vector3 = global_position + fwd * (1.9 if k != 1 else 2.6) + side * float(k - 1) * 1.6
		var fl = _floor_at(at)
		if fl != null:
			at = fl
		_grave_crack(at, green)
		var a := Ally.spawn(self, "skeleton", at + Vector3(0, 0.1, 0), 24.0)
		a.rise_t = Ally.RISE_TIME + k * 0.18
		a._facing = facing
		get_tree().create_timer(0.15 + k * 0.18, false).timeout.connect(func() -> void:
			Sfx.play_at("bone_break", at, -4.0, 0.2)
			FX.burst(at + Vector3(0, 0.3, 0), Color(0.35, 0.3, 0.25), 30, 3.5, 0.3, 0.8, -6.0))
	return true

## A glowing green crack in the ground that fades away.
func _grave_crack(at: Vector3, col: Color) -> void:
	var root := Node3D.new(); get_tree().current_scene.add_child(root); root.global_position = at + Vector3(0, 0.03, 0)
	var m := FX.beam_material(col, 2.5, 0.9)
	for k in 5:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.6, 1.3), 0.02, 0.07)
		mi.mesh = bm; mi.material_override = m
		mi.rotation.y = k * TAU / 5.0 + randf_range(-0.3, 0.3)
		mi.position = Vector3(cos(-mi.rotation.y), 0, sin(-mi.rotation.y)) * bm.size.x * 0.4
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.55; cm.height = 0.02
	disc.mesh = cm; disc.material_override = FX.beam_material(Color(0.1, 0.35, 0.12), 1.0, 0.7); root.add_child(disc)
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 2.0; l.omni_range = 3.5; l.position.y = 0.4; root.add_child(l)
	FX.burst(at + Vector3(0, 0.2, 0), col, 16, 1.5, 0.1, 1.2, 1.5)
	var tw := root.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(root, "scale", Vector3(0.01, 1, 0.01), 0.8)
	tw.parallel().tween_property(l, "light_energy", 0.0, 0.8)
	tw.tween_callback(root.queue_free)

## Necromancer: green beams drain the life from every foe around you.
func _soul_drain() -> void:
	var green := Color(0.45, 1.0, 0.55)
	casting = true; cast_time = 0.3
	Sfx.play("spell", -3.0, 0.1)
	for tick in 5:
		var near: Array = []
		for e in _live_enemies():
			var to: Vector3 = e.global_position - global_position
			if absf(to.y) < 3.5 and to.length() < 9.5:
				near.append(e)
		near = near.slice(0, 7)
		var drained := 0.0
		for e in near:
			var dmg := Game.spell_damage() * 0.45 + Game.attack_damage() * 0.35
			_special_hit_enemy(e, dmg, 0.0)
			drained += dmg
			FX.beam((e as Node3D).global_position + Vector3(0, 1.1, 0), global_position + Vector3(0, 1.2, 0), green, 0.12, 0.35)
		if drained > 0.0:
			heal(drained * 0.5)
			FX.burst(global_position + Vector3(0, 1.1, 0), green, 10, 1.5, 0.12, 0.6, 0.0)
		await get_tree().create_timer(0.45, false).timeout
		if dead:
			return

## Beastmaster: your wolf pounces on the foe you're facing; a second wolf joins.
var pet: Ally
func _sic_em() -> bool:
	var tgt := _aim_target(22.0, 0.0)
	if tgt == null:
		Game.say("No enemy in sight to sic 'em on!", Color(1.0, 0.75, 0.5))
		return false
	_ensure_pet()
	if pet:
		pet.pounce(tgt)
	var side := -Vector3(sin(view_yaw), 0, cos(view_yaw)).cross(Vector3.UP)
	var extra := Ally.spawn(self, "wolf", global_position + side * 1.5 + Vector3(0, 0.1, 0), 15.0)
	extra.pounce(tgt)
	Sfx.play("whistle", -2.0, 0.1)
	Game.say("Sic 'em!", Color(1.0, 0.7, 0.35))
	casting = true; cast_time = 0.2
	return true

## Beastmaster: a big bear fights with you for a while.
func _bear_friend() -> void:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var at := global_position + fwd * 2.5
	var fl = _floor_at(at)
	if fl != null:
		at = fl
	Ally.spawn(self, "bear", at + Vector3(0, 0.1, 0), 22.0)
	Sfx.play("roar_big", -4.0, 0.05)
	add_trauma(0.35)
	FX.shockwave(at, Color(0.8, 0.55, 0.3), 4.0, 0.4)
	Game.say("A bear friend joins the fight!", Color(0.9, 0.65, 0.4))
	casting = true; cast_time = 0.2

## The Beastmaster's own wolf is always with them.
func _ensure_pet() -> void:
	if Game.profile.get("hero", "") != "Beastmaster" or dead:
		return
	if pet == null or not is_instance_valid(pet):
		var behind := Vector3(sin(facing), 0, cos(facing)) * 1.6
		pet = Ally.spawn(self, "wolf", global_position + behind + Vector3(0, 0.2, 0), -1.0)

## Mage: a ring of ice bursts out; every foe nearby is frozen solid.
func _frost_nova() -> void:
	var ice := Color(0.6, 0.9, 1.0)
	var at := global_position
	var dmg := Game.attack_damage() * 1.4 + Game.spell_damage() * 1.0
	for e in _live_enemies():
		var to: Vector3 = e.global_position - at
		if absf(to.y) < 2.8 and Vector2(to.x, to.z).length() < 7.0 + _hit_radius(e):
			_special_hit_enemy(e, dmg * randf_range(0.92, 1.08), 2.0, false, true)
			if e.has_method("freeze"):
				e.freeze(3.0)
	FX.shockwave(at, ice, 8.0, 0.5)
	FX.dome(at, ice, 7.0, 0.5)
	for k in 14:
		var a := k * TAU / 14.0
		FX.pillar(at + Vector3(cos(a) * 4.5, 0, sin(a) * 4.5), ice, 0.35, 2.4, 0.9)
	FX.burst(at + Vector3(0, 0.8, 0), Color(0.85, 0.95, 1.0), 100, 9.0, 0.2, 1.0, -2.0)
	FX.screen_flash(ice, 0.3, 0.4)
	Sfx.play("spell_hit", 0.0, 0.05)
	casting = true; cast_time = 0.2
	add_trauma(0.4)
	_slowmo(0.35, 0.15)

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

## Mage: a blazing fireball that seeks the enemy in front of you (or flies
## 14 m straight ahead), then explodes: big damage, everything knocked down,
## and a patch of burning ground left behind.
func _fireball() -> bool:
	var fwd := -Vector3(sin(view_yaw), 0, cos(view_yaw))
	var head := global_position + Vector3(0, 1.3, 0)
	var target: Node3D = null
	var best := INF
	for e in _live_enemies():
		var to: Vector3 = e.global_position - global_position
		var d := to.length()
		if d > 22.0 or absf(to.y) > 5.0:
			continue
		var facing_dot := fwd.dot(Vector3(to.x, 0, to.z).normalized()) if d > 0.1 else 1.0
		if facing_dot < 0.25:
			continue
		if not _blocked(head, e.global_position + Vector3(0, 1.0, 0)).is_empty():
			continue
		var sc := d - facing_dot * 6.0
		if sc < best:
			best = sc; target = e
	var dest := global_position + fwd * 14.0
	if target:
		dest = target.global_position
	else:
		var hit := _blocked(head, head + fwd * 14.0)
		if not hit.is_empty():
			dest = hit.position - fwd * 0.5
		var fl = _floor_at(dest)
		if fl != null:
			dest = fl
	var orange := Color(1.0, 0.45, 0.12)
	var ball := Node3D.new()
	get_tree().current_scene.add_child(ball)
	var start := head + fwd * 0.7 + Vector3(0, 0.1, 0)
	ball.global_position = start
	var core := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.42; sm.height = 0.84
	core.mesh = sm; core.material_override = FX.glow_material(Color(1.0, 0.75, 0.3), 4.0); ball.add_child(core)
	var shell := MeshInstance3D.new(); var sm2 := SphereMesh.new(); sm2.radius = 0.65; sm2.height = 1.3
	shell.mesh = sm2; var shm := FX._add_mat(orange, 1.5); shm.albedo_color.a = 0.5; shell.material_override = shm; ball.add_child(shell)
	var trail := CPUParticles3D.new(); trail.amount = 60; trail.lifetime = 0.5; trail.local_coords = false
	trail.mesh = FX.quad(0.35); trail.material_override = FX.glow_material(orange, 3.0)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; trail.emission_sphere_radius = 0.35
	trail.spread = 180; trail.initial_velocity_min = 0.5; trail.initial_velocity_max = 1.5; trail.gravity = Vector3(0, 1.5, 0)
	trail.color_ramp = FX._fade_ramp(orange)
	ball.add_child(trail)
	var l := OmniLight3D.new(); l.light_color = orange; l.light_energy = 4.0; l.omni_range = 7.0; ball.add_child(l)
	var aim := dest + Vector3(0, 1.0, 0)
	var flight := clampf(start.distance_to(aim) / 26.0, 0.12, 0.7)
	var dmg := Game.attack_damage() * 2.4 + Game.spell_damage() * 1.6
	var tw := ball.create_tween()
	tw.tween_property(ball, "global_position", aim, flight).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var at := ball.global_position - Vector3(0, 1.0, 0)
		ball.queue_free()
		var n := _aoe(at, 5.0, dmg, 10.0, true)
		FX.shockwave(at + Vector3(0, 0.2, 0), orange, 6.5, 0.5)
		FX.dome(at, Color(1.0, 0.6, 0.2), 5.0, 0.45)
		FX.pillar(at, Color(1.0, 0.5, 0.15), 2.2, 7.0, 0.5)
		FX.burst(at + Vector3(0, 1.0, 0), Color(1.0, 0.65, 0.2), 110, 10.0, 0.35, 0.9, -3.0)
		FX.burst(at + Vector3(0, 0.5, 0), Color(0.4, 0.3, 0.25), 40, 4.0, 0.6, 1.4, 1.0)
		FX.flash_light(at + Vector3(0, 2, 0), Color(1.0, 0.6, 0.25), 12.0, 16.0, 0.5)
		FX.shadow_pool(at, Color(1.0, 0.4, 0.1), 3.5, 3.0, Game.attack_damage() * 0.6)
		FX.screen_flash(Color(1.0, 0.5, 0.15), 0.3, 0.35)
		Sfx.play_at("fire_burst", at, 0.0, 0.05)
		Sfx.play_at("spell_hit", at, -2.0, 0.05)
		add_trauma(0.55 if n > 0 else 0.35)
		_hitstop(0.08))
	casting = true
	cast_time = 0.15
	fov_kick = 10.0
	Sfx.play("spell", 0.0, 0.05)
	FX.burst(start, orange, 30, 3.0, 0.2, 0.4, 0.0)
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
	velocity.y = DOUBLE_JUMP_V * jump_mult
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
const PARRY_WINDOW := 0.4
var block_time := 0.0
var blocks := 0
var parries := 0

## The enemy the shield turns toward: whoever is winding up a blow, else the nearest.
func _guard_target() -> Node3D:
	var best: Node3D = null
	var bs := INF
	for e in _live_enemies():
		var to: Vector3 = e.global_position - global_position
		if absf(to.y) > 3.0:
			continue
		var d := Vector2(to.x, to.z).length()
		var reach := 22.0 if e.get("t") is Dictionary and (e.get("t") as Dictionary).get("ranged", false) else 9.0
		if d > reach:
			continue
		var sc := d
		if e.get("state") == Enemy.S.WINDUP:
			sc -= 6.0
		if sc < bs:
			bs = sc; best = e
	return best

## A see-through glowing shield in front of you while you block: blue when up,
## gold during the parry moment, flashing white when it stops a blow.
var _guard_fx: Node3D
var _guard_mat: StandardMaterial3D
var _guard_a := 0.0
var _guard_hit := 0.0

func _update_guard_fx(delta: float) -> void:
	if _guard_fx == null:
		_guard_fx = Node3D.new()
		add_child(_guard_fx)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.75; sm.height = 0.75; sm.is_hemisphere = true
		sm.radial_segments = 24; sm.rings = 8
		mi.mesh = sm
		_guard_mat = StandardMaterial3D.new()
		_guard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_guard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_guard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_guard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = _guard_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.x = -PI * 0.5            # the dome bulges forward (-Z)
		mi.scale = Vector3(1.0, 0.45, 1.25)
		_guard_fx.add_child(mi)
		var rim := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.72; tm.outer_radius = 0.78
		rim.mesh = tm; rim.material_override = _guard_mat; rim.rotation.x = PI * 0.5; rim.scale = Vector3(1.0, 1.0, 1.25)
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_guard_fx.add_child(rim)
	var up := blocking and not dead
	_guard_a = move_toward(_guard_a, 1.0 if up else 0.0, delta * (12.0 if up else 6.0))
	_guard_hit = maxf(0.0, _guard_hit - delta * 4.0)
	_guard_fx.visible = _guard_a > 0.01
	if not _guard_fx.visible:
		return
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	_guard_fx.position = Vector3(0, 1.05 + ((_seat_h() - 0.46) if mounted else 0.0), 0) + fwd * 0.62
	_guard_fx.rotation = Vector3(0, facing, 0)
	var parry_now := blocking and block_time < PARRY_WINDOW
	var c := Color(1.0, 0.85, 0.35) if parry_now else Color(0.45, 0.75, 1.0)
	c = c.lerp(Color(1, 1, 1), _guard_hit)
	var shimmer := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	_guard_mat.albedo_color = Color(c.r, c.g, c.b, (0.32 + 0.5 * _guard_hit) * _guard_a * shimmer)
	_guard_fx.scale = Vector3.ONE * (0.85 + 0.15 * _guard_a + 0.12 * _guard_hit)

func _parry(from_pos: Vector3) -> void:
	parries += 1
	_guard_hit = 1.0
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
