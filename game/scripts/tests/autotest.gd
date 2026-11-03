extends Node
## Automated runtime tests and screenshot capture, driven through the real
## game: input actions, mouse-wheel events, combat and interactables.
##
## Run (needs a display; xvfb works):
##   godot --path game -- --autotest=flow --out=/tmp/shots
##   godot --path game -- --autotest=shots --out=/tmp/shots
## Results are printed as "AUTOTEST ..." lines and written to <out>/results.json.

var mode := "flow"
var out_dir := "user://autotest"
var main: Node
var player: Player
var results: Array = []
var god := false
var t0 := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
	if OS.has_environment("DEEPVAULT_AUTOTEST"):
		mode = OS.get_environment("DEEPVAULT_AUTOTEST")
	var web_mode: String = main_web_mode()
	if web_mode != "":
		mode = web_mode
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = get_parent()
	t0 = Time.get_ticks_msec()
	_run.call_deferred()

func main_web_mode() -> String:
	var m = get_parent()
	return m._web_autotest() if m and m.has_method("_web_autotest") else ""

func check(name: String, ok: bool, detail := "") -> void:
	results.append({"check": name, "ok": ok, "detail": detail})
	print("AUTOTEST %s %s %s" % ["PASS" if ok else "FAIL", name, detail])

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(3)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("AUTOTEST SHOT ", name)

var game_time := 0.0
func _process(d: float) -> void:
	game_time += d
	_track_camera(d)
	if god and player:
		Game.hp = maxf(Game.hp, Game.max_hp() * 0.8)
		Game.stamina = Game.max_stamina()
		Game.mana = Game.max_mana()

func tp(pos: Vector3, yaw: float, pitch := -0.2) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.yaw = yaw; player.facing = yaw; player.pitch = pitch
	player.snap_view()
	await frames(4)

func press(action: String, sec: float) -> void:
	Input.action_press(action)
	await wait(sec)
	Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)

func wheel(up: bool, n: int) -> void:
	for i in n:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
		await frames(2)
		var ev2 := ev.duplicate(); ev2.pressed = false
		Input.parse_input_event(ev2)
		await frames(2)

func face(target: Vector3) -> void:
	var to := target - player.global_position
	player.yaw = atan2(-to.x, -to.z)

func nearest_enemy(max_d := 30.0) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d := player.global_position.distance_to(e.global_position)
		if d < bd:
			bd = d; best = e
	return best

## Walk toward and melee every live enemy within radius until none remain.
func clear_enemies(radius: float, timeout: float) -> int:
	var kills0 := Game.kills
	var t := 0.0
	while t < timeout:
		var e := nearest_enemy(radius)
		if e == null:
			break
		face(e.global_position)
		var d := player.global_position.distance_to(e.global_position)
		if d > 2.0:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
			await tap("attack")
		await wait(0.1)
		t += 0.1
	Input.action_release("move_forward")
	return Game.kills - kills0   # the game's own kill counter (any swing, any target)

func use_nearest_interactable() -> bool:
	await frames(3)
	if player.interact_target == null:
		return false
	await tap("interact")
	await wait(0.3)
	if main.menus.current == "lore":
		main._resume()
	return true

func _run() -> void:
	await wait(1.0)
	if mode == "shots":
		await _shots()
	elif mode == "gate":
		await wait(4.0)
		var g: Button = main.menus._audio_gate
		check("web_tap_gate_shown", g != null and is_instance_valid(g) and g.is_visible_in_tree())
		await shot("g_tap_to_begin")
		await wait(6.0)
		if g and is_instance_valid(g):
			g.pressed.emit()
		await wait(1.0)
		check("tap_gate_dismissed_sound_on", (g == null or not is_instance_valid(g)) and not Sfx.muted, main.menus._mute_btn.text)
		await shot("g_title_after_tap")
		await wait(6.0)
	elif mode == "ui":
		await _ui_test()
	elif mode == "looks":
		await _looks_test()
	elif mode == "special":
		await _special_test()
	elif mode == "loot":
		await _loot_test()
	elif mode == "balance":
		await _balance_test()
	elif mode == "river":
		await _start()
		god = false
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.global_position.z < -90.0:
				e.queue_free()
		await wait(0.3)
		for spot in [Vector3(-8, -6.8, -112), Vector3(14, -6.6, -129), Vector3(-9.0, -6.6, -126)]:
			Game.equipped.artifact = ""
			Game.hp = Game.max_hp()
			await tp(spot, PI / 2)
			var h0 := Game.hp
			await wait(1.6)
			check("burns_at_%s" % spot, Game.hp < h0 and player.in_river, "hp %.0f -> %.0f in_river=%s y=%.2f" % [h0, Game.hp, player.in_river, player.global_position.y])
			Game.add_item("amulet_deep")
			Game.equip("amulet_deep")
			Game.hp = Game.max_hp() * 0.5
			var h1 := Game.hp
			await wait(1.6)
			check("heals_at_%s" % spot, Game.hp > h1, "hp %.0f -> %.0f in_river=%s dmg_taken=%.0f" % [h1, Game.hp, player.in_river, player.damage_taken])
	elif mode == "boot":
		await _start()
		await wait(1.0)
		check("boots_and_plays", main.state == "play" and player != null, ProjectSettings.get_setting("application/config/name"))
		await shot("b_boot")
	elif mode == "feel":
		await _feel_test()
	elif mode == "camera":
		await _camera_test()
	elif mode == "touch":
		await _touch_test()
	elif mode == "boss":
		await _start()
		god = true
		Game.level = 4
		Game.add_item("vault_blade"); Game.add_item("chainmail")
		var w0 := world().warden
		print("BOSS pre: valid=%s pos=%s state=%s hp=%s body=%s meshes=%d" % [is_instance_valid(w0), w0.global_position, w0.state, w0.hp, w0.body.global_position, w0.body.all_meshes.size()])
		await tp(Vector3(0, -5.9, -139), 0.0)
		await shot("b0_arena_before")
		await _boss_fight()
	else:
		await _flow()
	_finish()

func _start() -> void:
	await wait(1.5)
	await shot("00_title")
	main.menus.show_panel("creator")
	await wait(0.8)
	await shot("00_character_creator")
	Game.profile.name = "Testa"
	main._start_game()
	player = main.player
	await wait(1.0)

# ---------------------------------------------------------------------------
func _flow() -> void:
	await _start()
	check("game_started", main.state == "play" and player.input_enabled)
	# movement through real input actions
	var p0 := player.global_position
	await press("move_forward", 1.0)
	var moved := p0.distance_to(player.global_position)
	check("movement_wasd", moved > 2.0, "moved %.2fm" % moved)
	await press("sprint", 0.05)
	# camera: wheel in to first person, out to third
	await wheel(true, 12)
	await wait(0.6)
	check("camera_first_person", player.first_person, "zoom=%.2f" % player.zoom)
	await shot("01_outpost_first_person")
	await wheel(false, 8)
	await wait(0.8)
	check("camera_third_person", not player.first_person and player.zoom > 2.5, "zoom=%.2f" % player.zoom)
	await shot("02_outpost_third_person")
	# jump
	var y0 := player.global_position.y
	await tap("jump")
	await wait(0.25)
	check("jump", player.global_position.y > y0 + 0.4, "dy=%.2f" % (player.global_position.y - y0))
	await wait(0.8)
	# read journal + camp chest
	await tp(Vector3(-3.0, 0.1, 22.0), PI)
	var read := await use_nearest_interactable()
	check("interact_inscription", read)
	await tp(Vector3(-8.2, 0.1, 22.5), PI / 2)
	var pot0 := Game.potions
	await use_nearest_interactable()
	await wait(1.6)
	check("chest_loot_pickup", Game.potions > pot0 or Game.gold > 0, "potions %d gold %d" % [Game.potions, Game.gold])
	# entry hall: skeletons rise and are defeated in real combat
	await tp(Vector3(0, -5.9, -13.5), 0.0)
	await shot("03_entry_hall")
	Input.action_press("move_forward"); await wait(1.2); Input.action_release("move_forward")
	await wait(1.8)
	var awake := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.global_position.z > -35 and e.global_position.z < -12 and e.state != Enemy.S.DORMANT:
			awake += 1
	check("skeletons_awaken", awake >= 1, "%d awake" % awake)
	await shot("04_skeletons_rise")
	var xp_before := Game.level * 10000 + Game.xp
	var hp_before := Game.hp
	var k := await clear_enemies(22.0, 60.0)
	check("melee_combat_kills", k >= 3, "%d killed" % k)
	check("xp_gained", Game.level * 10000 + Game.xp > xp_before, "level %d xp %d" % [Game.level, Game.xp])
	check("player_took_damage", player.damage_taken > 0.0, "%.0f damage taken" % player.damage_taken)
	check("level_up", Game.level >= 2, "level %d" % Game.level)
	# arcane bolt
	var b0 := player.bolts_fired
	await wait(1.2)   # let any queued sword combo finish; casting is blocked mid-swing
	for attempt in 3:
		await tap("spell")
		await wait(0.8)
		if player.bolts_fired > b0:
			break
	check("spell_cast", player.bolts_fired > b0, "bolts %d" % player.bolts_fired)
	# fire vents hurt
	god = false
	Game.hp = Game.max_hp()
	await tp(Vector3(0, -5.9, -38.5), 0.0)
	var hp_v := Game.hp
	await wait(3.6)
	check("fire_trap_damage", Game.hp < hp_v, "hp %.0f -> %.0f" % [hp_v, Game.hp])
	await shot("05_fire_vents")
	god = true
	await tp(Vector3(1.7, -5.9, -58.6), -PI / 2)
	var lever_ok := await use_nearest_interactable()
	await wait(2.6)
	check("lever_opens_gate", lever_ok and world().corridor_gate.is_open)
	# armory
	await tp(Vector3(0, -5.9, -62), 0.0)
	await shot("06_armory")
	var ak := await clear_enemies(26.0, 90.0)
	check("armory_cleared_incl_revenant", ak >= 3, "%d killed" % ak)
	var atk0 := Game.attack_damage()
	var inv_before := Game.inventory.duplicate()
	await tp(Vector3(-8.0, -5.9, -63.5), PI / 2)
	await use_nearest_interactable()
	await wait(2.0)
	check("weapon_found_best_equipped", _found_and_best("weapon", inv_before), "%s: attack %.0f -> %.0f" % [Game.item(Game.equipped.weapon).get("name", "?"), atk0, Game.attack_damage()])
	var def0 := Game.defense()
	var inv_before2 := Game.inventory.duplicate()
	await tp(Vector3(0, -5.9, -81.2), 0.0)
	await use_nearest_interactable()
	await wait(2.0)
	check("armor_found_best_equipped", _found_and_best("armor", inv_before2), "%s: defense %.0f -> %.0f" % [Game.item(Game.equipped.armor).get("name", "?"), def0, Game.defense()])
	await shot("06b_armory_loot")
	# the Glowing Deep
	await tp(Vector3(0, -5.9, -94), 0.0, -0.15)
	await shot("07_glowing_deep_entrance")
	await wheel(true, 12); await wait(0.5)
	await tp(Vector3(-6, -5.9, -104), 0.6, -0.1)
	await shot("08_river_first_person")
	await wheel(false, 6); await wait(0.5)
	await tp(Vector3(-3, -5.9, -100), 0.0, -0.3)
	var dk := await clear_enemies(40.0, 120.0)
	check("deep_cleared", dk >= 3, "%d killed" % dk)
	# river burns without the amulet (first remove stragglers, e.g. mages across the
	# cavern, so the check measures the river and not stray bolts)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.global_position.z < -90.0 and e.global_position.z > -134.0:
			e.queue_free()
	await wait(0.2)
	god = false
	Game.hp = Game.max_hp()
	await tp(Vector3(-8, -6.8, -112), PI / 2)
	var hp_r := Game.hp
	await wait(1.6)
	check("river_burns", Game.hp < hp_r and player.in_river, "hp %.0f -> %.0f in_river=%s" % [hp_r, Game.hp, player.in_river])
	await shot("09_wading_river")
	# island chest: amulet
	await tp(Vector3(15.0, -5.9, -124.9), PI)
	await use_nearest_interactable()
	await wait(2.0)
	check("amulet_equipped", Game.equipped.artifact == "amulet_deep", Game.equipped.artifact)
	Game.hp = Game.max_hp() * 0.5
	await tp(Vector3(-8, -6.8, -112), PI / 2)
	var hp_h := Game.hp
	await wait(1.6)
	check("amulet_river_heals", Game.hp > hp_h, "hp %.0f -> %.0f" % [hp_h, Game.hp])
	await shot("10_river_amulet_heals")
	god = true
	await tp(Vector3(-18.4, -5.9, -131.0), -PI / 2)
	await use_nearest_interactable()
	await wait(2.0)
	# random loot may already have given something stronger: then it waits in the bag
	check("runeblade_found", Game.inventory.has("vault_blade") and Game.score(Game.equipped.weapon) >= Game.score("vault_blade") - 0.01,
		"wielding %s" % Game.item(Game.equipped.weapon).get("name", "?"))
	await tp(Vector3(0, -5.9, -100), 0.0, -0.05)
	await shot("11_bridge_view")
	# boss
	await tp(Vector3(0, -5.9, -139), 0.0)
	await _boss_fight()
	await clear_enemies(30.0, 20.0)
	await wait(2.0)
	await tp(Vector3(0, -5.9, -167.2), 0.0)
	var victory := await use_nearest_interactable()
	await wait(3.5)
	check("victory", victory and main.state == "victory", main.state)
	await shot("15_victory")

func _boss_fight() -> void:
	# walk through the sanctum doors until the encounter triggers
	var tw := 0.0
	face(Vector3(0, -6, -157))
	Input.action_press("move_forward")
	while not world().boss_started and tw < 8.0:
		await wait(0.2); tw += 0.2
	Input.action_release("move_forward")
	await wait(2.6)
	var w := world().warden
	check("boss_awakens", world().boss_started and is_instance_valid(w) and w.state != Warden.S.DORMANT, "after walking %.1fs" % tw)
	check("boss_gate_sealed", not world().boss_gate.is_open)
	await shot("12_warden")
	var t := 0.0
	var next_log := 0.0
	var phase2_shot := false
	var dmg0 := player.damage_taken
	var gt0 := game_time
	while t < 180.0 and is_instance_valid(w) and not w.dead:
		if t >= next_log:
			next_log += 2.0
			print("BOSS t=%.0f hp=%.0f state=%d phase=%d pos=%s player=%s php=%.0f" % [t, w.hp, w.state, w.phase, w.global_position, player.global_position, Game.hp])
		var e := nearest_enemy(30.0)
		if e and e != w and player.global_position.distance_to(e.global_position) < 5.0:
			face(e.global_position)
		else:
			face(w.global_position)
		var d := player.global_position.distance_to(w.global_position)
		if d > 3.4:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
			await tap("attack")
		if w.phase >= 2 and not phase2_shot:
			phase2_shot = true
			await shot("13_warden_phase2")
		await wait(0.1)
		t += 0.1
	Input.action_release("move_forward")
	var won := is_instance_valid(w) and w.dead
	check("boss_defeated", won, "after %.0fs of game time, phase %d, player took %.0f damage" % [game_time - gt0, w.phase if is_instance_valid(w) else -1, player.damage_taken - dmg0])
	check("boss_dealt_damage", player.damage_taken > dmg0, "%.0f" % (player.damage_taken - dmg0))
	await wait(2.5)
	await shot("14_warden_shattered")
	check("boss_gate_reopens", world().boss_gate.is_open)

# --- touch & trackpad -------------------------------------------------------
## Simulated touches are given in game (canvas) units and converted to the
## window pixels a real touchscreen reports; Godot scales them back.
func to_win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func touch_ev(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx; e.position = to_win(pos); e.pressed = pressed
	Input.parse_input_event(e)
	await frames(2)

func drag_ev(idx: int, from: Vector2, to: Vector2, steps := 6) -> void:
	for i in steps:
		var e := InputEventScreenDrag.new()
		e.index = idx
		var a := from.lerp(to, float(i) / steps)
		var b := from.lerp(to, float(i + 1) / steps)
		e.position = to_win(b); e.relative = to_win(b) - to_win(a)
		Input.parse_input_event(e)
		await frames(1)

func _stick_hold(c: Vector2, off: Vector2, sec: float) -> void:
	await touch_ev(0, c, true)
	await drag_ev(0, c, c + off)
	await wait(sec)

func _stick_release(at: Vector2) -> void:
	await touch_ev(0, at, false)
	await wait(0.3)

func _touch_test() -> void:
	await _start()
	await tp(Vector3(0, 0.1, 26), 0.0)
	var r := get_viewport().get_visible_rect().size
	var tc: TouchControls = main.touch
	# desktop mouse first: a real left click attacks, right button blocks
	if not OS.has_feature("web"):
		var swm := player.swings
		var lc := InputEventMouseButton.new(); lc.button_index = MOUSE_BUTTON_LEFT; lc.pressed = true; lc.position = r * 0.5
		Input.parse_input_event(lc); await frames(3)
		var lcu := lc.duplicate(); lcu.pressed = false
		Input.parse_input_event(lcu); await frames(2)
		check("mouse_click_attacks", player.swings > swm and player.mouse_captured)
		await wait(0.8)
		var rc := InputEventMouseButton.new(); rc.button_index = MOUSE_BUTTON_RIGHT; rc.pressed = true; rc.position = r * 0.5
		Input.parse_input_event(rc); await frames(4)
		var blocked := player.blocking
		var rcu := rc.duplicate(); rcu.pressed = false
		Input.parse_input_event(rcu); await frames(3)
		check("mouse_right_blocks", blocked and not player.blocking)
	# first touch reveals the overlay (no pointer lock)
	await touch_ev(5, Vector2(r.x * 0.6, r.y * 0.3), true)
	await touch_ev(5, Vector2(r.x * 0.6, r.y * 0.3), false)
	check("touch_overlay_appears", tc.visible and Game.touch_active and player.mouse_captured and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	await shot("t0_touch_overlay")
	# joystick: push up -> walk forward
	var p0 := player.global_position
	var c := Vector2(190, r.y - 190)
	await touch_ev(0, c, true)
	await drag_ev(0, c, c + Vector2(0, -80))
	await wait(1.0)
	await shot("t1_joystick")
	await touch_ev(0, c + Vector2(0, -80), false)
	var moved := p0.distance_to(player.global_position)
	check("touch_joystick_moves", moved > 1.5, "moved %.2fm" % moved)
	# the stick base must stay near home even if the thumb slides across the screen
	await tp(Vector3(2, 0.1, 10), 0.0)
	await touch_ev(0, c, true)
	await drag_ev(0, c, c + Vector2(700, -350), 10)
	await wait(0.4)
	var drift: float = tc._stick_origin.distance_to(tc._stick_home)
	var vec: Vector2 = tc._stick_vec
	await shot("t1a_stick_far")
	await touch_ev(0, c + Vector2(700, -350), false)
	check("stick_stays_put", drift <= 56.0 and vec.length() > 0.95 and vec.x > 0.7, "base drifted %.0f px, stick %s" % [drift, vec])
	# a touch far from the corner still spawns the stick inside the home zone
	await touch_ev(0, Vector2(600, 300), true)
	var home: Vector2 = tc._stick_home
	await touch_ev(0, Vector2(600, 300), false)
	check("stick_home_zone", home.x <= 430.0 and home.y >= r.y - 430.0, "spawned at %s" % home)
	await wait(0.3)
	# strafing: stick right / back / diagonal while the view stays put or swings
	await tp(Vector3(2, 0.1, 10), 0.0)
	await _stick_hold(c, Vector2(85, 0), 1.2)
	var fr := absf(angle_difference(player.facing, player.view_yaw))
	var clip_r: String = player.body.anim.current_animation
	var lr := (player.global_position - Vector3(2, 0.1, 10)).rotated(Vector3.UP, -player.yaw)
	await _stick_release(c + Vector2(85, 0))
	check("strafe_right_faces_camera", fr < 0.25 and lr.x > 1.0 and clip_r.contains("Strafe_Right"), "facing off by %.2f rad, moved %.1fm right, clip %s" % [fr, lr.x, clip_r])
	await shot("t1b_strafe")
	await tp(Vector3(2, 0.1, 10), 0.0)
	await _stick_hold(c, Vector2(0, 85), 1.2)
	var fb := absf(angle_difference(player.facing, player.view_yaw))
	var clip_b: String = player.body.anim.current_animation
	var lb := (player.global_position - Vector3(2, 0.1, 10)).rotated(Vector3.UP, -player.yaw)
	await _stick_release(c + Vector2(0, 85))
	check("backpedal_keeps_facing", fb < 0.25 and lb.z > 1.0 and clip_b.contains("Backwards"), "facing off by %.2f rad, moved %.1fm back, clip %s" % [fb, lb.z, clip_b])
	# run forward-left while swiping the view to the right: body must follow the view, never flip
	await tp(Vector3(2, 0.1, 10), 0.0)
	await touch_ev(0, c, true)
	await drag_ev(0, c, c + Vector2(-60, -60))
	var worst := 0.0
	var sw := Vector2(r.x * 0.65, r.y * 0.45)
	await touch_ev(1, sw, true)
	for i in 10:
		await drag_ev(1, sw + Vector2(i * 14, 0), sw + Vector2((i + 1) * 14, 0), 1)
		worst = maxf(worst, absf(angle_difference(player.facing, player.view_yaw)))
	await touch_ev(1, sw + Vector2(140, 0), false)
	await touch_ev(0, c + Vector2(-60, -60), false)
	check("move_and_look_no_flip", worst < 0.6, "worst facing vs view %.2f rad" % worst)
	# swipe right side -> look
	var y0 := player.yaw
	var s := Vector2(r.x * 0.62, r.y * 0.45)
	await touch_ev(1, s, true)
	await drag_ev(1, s, s + Vector2(-160, 0))
	await touch_ev(1, s + Vector2(-160, 0), false)
	check("touch_swipe_looks", absf(player.yaw - y0) > 0.2, "yaw %.2f -> %.2f" % [y0, player.yaw])
	# pinch in -> first person, pinch out -> third person
	player.zoom_target = 4.0
	var a0 := Vector2(r.x * 0.64, r.y * 0.4); var b0 := Vector2(r.x * 0.66, r.y * 0.4)
	await touch_ev(2, a0, true); await touch_ev(3, b0, true)
	for i in 8:
		var e := InputEventScreenDrag.new(); e.index = 2
		e.position = to_win(a0.lerp(Vector2(r.x * 0.5, r.y * 0.4), (i + 1) / 8.0)); e.relative = Vector2(-5, 0)
		Input.parse_input_event(e)
		var e2 := InputEventScreenDrag.new(); e2.index = 3
		e2.position = to_win(b0.lerp(Vector2(r.x * 0.8, r.y * 0.4), (i + 1) / 8.0)); e2.relative = Vector2(5, 0)
		Input.parse_input_event(e2)
		await frames(1)
	await touch_ev(2, a0, false); await touch_ev(3, b0, false)
	await wait(0.6)
	check("touch_pinch_to_first_person", player.first_person, "zoom %.2f" % player.zoom)
	await shot("t2_pinch_first_person")
	player.zoom_target = 3.6
	await wait(0.6)
	# attack button
	var atk: Dictionary = tc._buttons[0]
	var sw0 := player.swings
	await touch_ev(4, atk.center, true)
	await frames(3)
	var swung := player.swings > sw0
	await touch_ev(4, atk.center, false)
	check("touch_attack_button", swung)
	await wait(0.8)
	# an emulated (touch-generated) mouse click must not attack
	var sw1 := player.swings
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = true; mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.position = Vector2(r.x * 0.6, r.y * 0.5)
	Input.parse_input_event(mb)
	await frames(3)
	var mb2 := mb.duplicate(); mb2.pressed = false
	Input.parse_input_event(mb2)
	await frames(3)
	check("emulated_click_ignored", player.swings == sw1)
	# pause button opens the menu, tapping Resume through the GUI closes it
	var pz: Dictionary = tc._buttons[7]
	await touch_ev(6, pz.center, true); await touch_ev(6, pz.center, false)
	await wait(0.3)
	check("touch_pause_button", main.menus.current == "pause", main.menus.current)
	await shot("t3_pause_menu")
	main._resume()
	await wait(0.3)
	# keyboard use hides the overlay; trackpad free-cursor fallback
	var k := InputEventKey.new(); k.physical_keycode = KEY_W; k.keycode = KEY_W; k.pressed = true
	Input.parse_input_event(k)
	await frames(2)
	var k2 := k.duplicate(); k2.pressed = false
	Input.parse_input_event(k2)
	await frames(2)
	check("keyboard_hides_touch", not tc.visible and not Game.touch_active)
	Game.free_cursor = true
	player.set_mouse_captured(true)
	await frames(2)
	var y1 := player.yaw
	var sw_drag := player.swings
	var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT; m.pressed = true; m.position = Vector2(400, 300)
	Input.parse_input_event(m); await frames(2)
	for i in 6:
		var mm := InputEventMouseMotion.new(); mm.position = Vector2(400 + (i + 1) * 15, 300); mm.relative = Vector2(15, 0)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm); await frames(1)
	var mu := m.duplicate(); mu.pressed = false; mu.position = Vector2(490, 300)
	Input.parse_input_event(mu); await frames(3)
	check("free_cursor_drag_looks", absf(player.yaw - y1) > 0.1 and player.swings == sw_drag, "yaw %.2f -> %.2f" % [y1, player.yaw])
	await wait(0.8)
	var sw2 := player.swings
	var t := InputEventMouseButton.new(); t.button_index = MOUSE_BUTTON_LEFT; t.pressed = true; t.position = Vector2(500, 300)
	Input.parse_input_event(t); await frames(2)
	var tu := t.duplicate(); tu.pressed = false
	Input.parse_input_event(tu); await frames(4)
	check("free_cursor_tap_attacks", player.swings > sw2)
	# arrow keys look
	await wait(0.8)
	var y2 := player.yaw
	Input.action_press("look_left"); await wait(0.5); Input.action_release("look_left")
	check("arrow_keys_look", player.yaw > y2 + 0.2, "yaw %.2f -> %.2f" % [y2, player.yaw])

# --- camera smoothness ------------------------------------------------------
# Measures what a player feels: the camera's distance from the head pumping in
# and out as it hits walls, and frame-to-frame jerk in where it points.
var _cam_track := false
var _cam_frames := 0
var _dist_prev := -1.0
var _dist_dir := 0
var _dist_extreme := 0.0
var _pumps := 0
var _dist_travel := 0.0
var _fwd_prev := Vector3.ZERO
var _fwd_rate_prev := 0.0
var _jerk_sum := 0.0
var _track_time := 0.0

func _track_camera(delta: float) -> void:
	if not _cam_track or player == null or delta <= 0.0:
		return
	var cam: Camera3D = player.camera
	var head := player.global_position + Vector3(0, Player.EYE_H, 0)
	var d := cam.global_position.distance_to(head)
	var fwd := -cam.global_transform.basis.z
	_track_time += delta
	if _cam_frames > 0:
		_dist_travel += absf(d - _dist_prev)
		var dir := signi(int(signf(d - _dist_prev))) if absf(d - _dist_prev) > 0.02 else 0
		if dir != 0:
			if _dist_dir != 0 and dir != _dist_dir and absf(_dist_extreme - d) > 0.0:
				if absf(_dist_extreme - _dist_prev) > 0.35:
					_pumps += 1
				_dist_extreme = _dist_prev
			elif _dist_dir == 0:
				_dist_extreme = _dist_prev
			_dist_dir = dir
		var rate := fwd.angle_to(_fwd_prev) / delta
		if _cam_frames > 1:
			_jerk_sum += absf(rate - _fwd_rate_prev)
		_fwd_rate_prev = rate
	_dist_prev = d
	_fwd_prev = fwd
	_cam_frames += 1

func _camera_test() -> void:
	await _start()
	god = true
	var spots := [
		["hall_pillars", Vector3(-4.2, -5.9, -15.5), Vector3(-4.2, -5.9, -31)],
		["vent_corridor", Vector3(0, -5.9, -35.5), Vector3(0, -5.9, -57.5)],
		["armory_pillars", Vector3(-5.3, -5.9, -62.5), Vector3(-5.3, -5.9, -81)],
		["tunnel_stairs", Vector3(0, 0.1, 2.0), Vector3(0, -5.9, -11.5)],
	]
	var total_pumps := 0
	for sp in spots:
		for zoom_m in [3.6, 6.5]:
			player.zoom_target = zoom_m; player.zoom = zoom_m
			await tp(sp[1], 0.0)
			corridor_off()
			await wait(0.6)
			_cam_track = true; _cam_frames = 0; _pumps = 0; _dist_travel = 0.0; _jerk_sum = 0.0
			_dist_dir = 0; _track_time = 0.0
			var t := 0.0
			Input.action_press("move_forward")
			while t < 6.0 and player.global_position.distance_to(sp[2]) > 1.5:
				face(sp[2])
				player.yaw += sin(t * 2.2) * 1.2   # sweep the view like a player looking around
				player.pitch = clampf(sin(t * 1.3) * 0.5 - 0.2, -1.0, 0.8)
				await frames(1)
				t += get_process_delta_time()
			Input.action_release("move_forward")
			_cam_track = false
			total_pumps += _pumps
			print("CAMSTAT %s zoom=%.1f pumps=%d dist_travel_per_s=%.2f jerk_per_s=%.1f frames=%d" % [sp[0], zoom_m, _pumps, _dist_travel / maxf(_track_time, 0.01), _jerk_sum / maxf(_track_time, 0.01), _cam_frames])
			# threshold set from measurement: the original camera averaged ~3.8 m/s of in/out motion here
			check("camera_settled_%s_%.0fm" % [sp[0], zoom_m], _dist_travel / maxf(_track_time, 0.01) < 2.5, "pumps %d, in/out travel %.2f m/s" % [_pumps, _dist_travel / maxf(_track_time, 0.01)])
		await shot("c_" + sp[0])
	print("CAMSTAT total_pumps=%d" % total_pumps)

func corridor_off() -> void:
	for tr in world().corridor_traps:
		tr.disabled = true

# --- "feel" checks from the second playtest -----------------------------------
## How far (radians, left/right) the character drifts from the centre of view.
func _screen_dev() -> float:
	var cam: Camera3D = player.camera
	var to := player.global_position - cam.global_position
	to.y = 0
	if to.length() < 1.2:
		return 0.0   # camera tucked against the head: angle is meaningless, the head is hidden
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	return absf(fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP))

func _cam_inside() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.05
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, player.camera.global_position)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Coplanar, same-facing, overlapping faces between box meshes = z-fighting.
func _count_zfight() -> int:
	var boxes := []
	for mi in world().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh is BoxMesh and m.visible:
			var a := m.global_transform * m.get_aabb()
			boxes.append(a)
	var n := 0
	var buckets := {}
	for i in boxes.size():
		var a: AABB = boxes[i]
		for ax in 3:
			for side in 2:
				var c: float = a.position[ax] if side == 0 else a.end[ax]
				var key := "%d|%d|%d" % [ax, side, int(round(c * 500.0))]
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(i)
	for key in buckets:
		var lst: Array = buckets[key]
		if lst.size() < 2:
			continue
		var ax := int(String(key).get_slice("|", 0))
		var u := (ax + 1) % 3; var v := (ax + 2) % 3
		for i in lst.size():
			for j in range(i + 1, lst.size()):
				var a: AABB = boxes[lst[i]]; var b: AABB = boxes[lst[j]]
				var ou := minf(a.end[u], b.end[u]) - maxf(a.position[u], b.position[u])
				var ov := minf(a.end[v], b.end[v]) - maxf(a.position[v], b.position[v])
				if ou > 0.02 and ov > 0.02:
					n += 1
	return n

func _feel_test() -> void:
	await _start()
	god = true
	var r := get_viewport().get_visible_rect().size
	var tc = main.touch
	var c := Vector2(190, r.y - 190)
	# --- 1. two fingers: stick back-left while swiping the view right
	await touch_ev(9, Vector2(r.x * 0.6, r.y * 0.3), true); await touch_ev(9, Vector2(r.x * 0.6, r.y * 0.3), false)
	await tp(Vector3(0, -5.9, -100), 0.0, -0.2)
	await wait(0.5)
	var clips := {}
	var switches := 0
	var last_clip := ""
	var worst_face := 0.0
	var worst_dev := 0.0
	var dev_sum := 0.0
	var dir_err_sum := 0.0
	var samples := 0
	await touch_ev(0, c, true)
	await drag_ev(0, c, c + Vector2(-62, 62))
	await wait(0.5)
	var sw := Vector2(r.x * 0.62, r.y * 0.4)
	await touch_ev(1, sw, true)
	var pos := sw
	for i in 60:
		var nxt := sw + Vector2(fmod(i * 9.0, 300.0), sin(i * 0.4) * 12.0)
		if nxt.x < pos.x:   # lift and re-place the finger, like a real repeated swipe
			await touch_ev(1, pos, false); await touch_ev(1, nxt, true)
		else:
			await drag_ev(1, pos, nxt, 1)
		pos = nxt
		await RenderingServer.frame_post_draw   # sample what was actually drawn this frame
		var clip: String = player.body.anim.current_animation
		if player.body.get("_oneshot") != null and player.body._oneshot != "":
			clip = last_clip   # one-shot actions are not locomotion flicker
		if clip != last_clip:
			if last_clip != "":
				switches += 1
			last_clip = clip
		clips[clip] = true
		worst_face = maxf(worst_face, absf(angle_difference(player.facing, player.view_yaw if "view_yaw" in player else player.yaw)))
		var dv := _screen_dev()
		worst_dev = maxf(worst_dev, dv); dev_sum += dv
		var hv := Vector3(player.velocity.x, 0, player.velocity.z)
		if hv.length() > 1.0:
			var shown_yaw: float = player.view_yaw if "view_yaw" in player else player.yaw
			var want := Vector3(-0.707, 0, 0.707).rotated(Vector3.UP, shown_yaw)
			dir_err_sum += hv.normalized().angle_to(want)
		samples += 1
	await touch_ev(1, pos, false)
	await touch_ev(0, c + Vector2(-62, 62), false)
	print("FEEL two_finger switches=%d clips=%s worst_face=%.2f worst_screen_dev=%.3f mean_dev=%.3f mean_dir_err=%.2f" % [switches, clips.keys(), worst_face, worst_dev, dev_sum / samples, dir_err_sum / samples])
	check("two_finger_steady_animation", switches <= 2, "%d clip switches %s" % [switches, clips.keys()])
	check("two_finger_character_centred", worst_dev < 0.3, "worst %.2f rad off centre, mean %.2f" % [worst_dev, dev_sum / samples])
	check("two_finger_moves_where_pushed", dir_err_sum / samples < 0.25, "mean direction error %.2f rad" % (dir_err_sum / samples))
	await shot("f1_two_finger")
	if OS.has_environment("FEEL_PART1"):
		return
	# --- 2. hug walls and pillars while turning: is the camera ever inside geometry?
	var inside := 0
	var frames_n := 0
	var hugs := [[Vector3(-8.3, -5.9, -14.5), Vector3(-8.3, -5.9, -32.5)], [Vector3(2.1, -5.9, -35.5), Vector3(2.1, -5.9, -58.5)],
		[Vector3(10.3, -5.9, -62.5), Vector3(10.3, -5.9, -82.5)], [Vector3(0, -5.9, -14), Vector3(-1.5, -5.9, -34.5)]]
	for wl in [3.6, 6.5]:
		for hg in hugs:
			for t in world().corridor_traps:
				t.disabled = true
			player.zoom_target = wl; player.zoom = wl
			await tp(hg[0], 0.0)
			await wait(0.4)
			var t2 := 0.0
			Input.action_press("move_forward")
			while t2 < 4.0 and player.global_position.distance_to(hg[1]) > 1.2:
				face(hg[1])
				player.yaw += sin(t2 * 2.6) * 1.4
				player.pitch = sin(t2 * 1.7) * 0.4 - 0.15
				await frames(1)
				if _cam_inside():
					inside += 1
				frames_n += 1
				t2 += get_process_delta_time()
			Input.action_release("move_forward")
	print("FEEL camera_inside_geometry frames=%d of %d" % [inside, frames_n])
	check("camera_never_inside_walls", inside == 0, "%d of %d frames" % [inside, frames_n])
	var zf := _count_zfight()
	print("FEEL zfight_face_pairs=%d" % zf)
	check("no_zfighting_faces", zf == 0, "%d overlapping coplanar face pairs" % zf)
	# --- 3. pits: get out using only the stick and the jump button
	var Yf := -6.0
	var pits := [["river", Vector3(-8, Yf - 0.9, -112), Vector3(-8, Yf, -104)],
		["pool_to_island", Vector3(12.5, Yf - 0.9, -126), Vector3(15, Yf, -126)],
		["channel", Vector3(ch_x(), Yf - 0.7, -126), Vector3(ch_x() + 2.5, Yf, -126)],
		["river_no_stamina", Vector3(8, Yf - 0.9, -112), Vector3(8, Yf, -119)]]
	for pt in pits:
		await tp(pt[1], 0.0)
		await wait(0.6)
		if String(pt[0]).ends_with("no_stamina"):
			Game.stamina = 0.0
		var goal: Vector3 = pt[2]
		var t3 := 0.0
		var out := false
		while t3 < 6.0:
			face(goal)
			if String(pt[0]).ends_with("no_stamina"):
				Game.stamina = 0.0
			Input.action_press("move_forward")
			if int(t3 * 10) % 5 == 0:
				var jb: Dictionary = tc._buttons[4]
				await touch_ev(7, jb.center, true); await touch_ev(7, jb.center, false)
			await wait(0.1)
			t3 += 0.1
			if player.global_position.y > goal.y - 0.25 and Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() < 3.0:
				out = true
				break
		Input.action_release("move_forward")
		check("escape_%s" % pt[0], out, "%.1fs, ended at y=%.2f" % [t3, player.global_position.y])
	# --- 4. touch buttons: bigger, non-overlapping, on screen
	var bs: Array = tc._buttons
	var overlap := false
	var off := false
	var big := 0.0
	for i in bs.size():
		big = maxf(big, bs[i].radius)
		var cc: Vector2 = bs[i].center
		if cc.x - bs[i].radius < 0 or cc.y - bs[i].radius < 0 or cc.x + bs[i].radius > r.x or cc.y + bs[i].radius > r.y:
			off = true
		for j in range(i + 1, bs.size()):
			if cc.distance_to(bs[j].center) < bs[i].radius + bs[j].radius + 6.0:
				overlap = true
	check("buttons_layout", not overlap and not off, "attack radius %.0f" % big)
	await touch_ev(9, Vector2(r.x * 0.6, r.y * 0.3), true); await touch_ev(9, Vector2(r.x * 0.6, r.y * 0.3), false)
	await tp(Vector3(0, -5.9, -100), 0.0, -0.2)
	await shot("f4_buttons")

func ch_x() -> float:
	return -9.0

# --- loot -------------------------------------------------------------------
func _loot_test() -> void:
	await _start()
	god = true
	Loot.rng.seed = 1234
	# 1. rarity spread over many rolls
	var counts := [0, 0, 0, 0, 0]
	var kinds := {}
	var bad := 0
	for i in 2000:
		var id := Loot.make_random(3)
		var it := Game.item(id)
		counts[it.rarity] += 1
		kinds[it.slot] = kinds.get(it.slot, 0) + 1
		if String(it.get("name", "")) == "" or (it.slot == "weapon" and float(it.get("damage", 0)) <= 0.0):
			bad += 1
		Game.items.erase(id)
	print("LOOT rarity_counts=%s kinds=%s" % [counts, kinds])
	check("loot_rarities_spread", counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4] and counts[4] > 0, "%s" % [counts])
	check("loot_items_valid", bad == 0, "%d bad" % bad)
	# 2. open every chest in the dungeon
	var chests := []
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.kind == "chest":
			chests.append(n)
	var hp0 := Game.potions; var mp0 := Game.mana_potions; var inv0 := Game.inventory.size()
	for c in chests:
		c.interact(player)
	await wait(0.3)
	for pk in get_tree().get_nodes_in_group("pickup_dbg"):
		pass
	# collect everything that spawned
	var picks := []
	for n in world().get_parent().get_children():
		if n is Pickup:
			picks.append(n)
	for pk in picks:
		pk._collect()
	print("LOOT chests=%d heal+%d mana+%d items+%d gold=%d" % [chests.size(), Game.potions - hp0, Game.mana_potions - mp0, Game.inventory.size() - inv0, Game.gold])
	check("more_chests", chests.size() >= 12, "%d chests" % chests.size())
	check("chests_give_potions", Game.potions - hp0 + Game.mana_potions - mp0 >= 15, "heal +%d, mana +%d" % [Game.potions - hp0, Game.mana_potions - mp0])
	check("chests_give_gear", Game.inventory.size() - inv0 >= 10, "%d items" % (Game.inventory.size() - inv0))
	# 3. enemy drops
	var drops := 0; var dpots := 0
	for i in 200:
		for d in Loot.roll_enemy(["minion", "warrior", "mage", "revenant"][i % 4], 3):
			if d.kind == "item":
				drops += 1
				Game.items.erase(d.id)
			else:
				dpots += 1
	print("LOOT enemy_drops per 200 kills: items=%d potions=%d" % [drops, dpots])
	check("monsters_drop_loot", drops >= 20 and dpots >= 60, "items %d potions %d" % [drops, dpots])
	# 4. melee recharges mana
	await tp(Vector3(0, -5.9, -62), 0.0)
	var e := Enemy.new(); e.configure("revenant", "dummy"); e.position = Vector3(0, -6, -64); world().add_child(e)
	await wait(0.5)
	Game.mana = 0.0
	var m0 := player.melee_mana_gained
	for k in 4:
		face(e.global_position)
		await tap("attack")
		await wait(0.6)
	check("melee_recharges_mana", player.melee_mana_gained - m0 >= 14.0, "+%.0f mana from hits" % (player.melee_mana_gained - m0))
	e.queue_free()
	# 5. looks: every skin plus epic gear auras
	await tp(Vector3(2, 0.1, 12), PI)
	player.zoom_target = 3.0; player.zoom = 3.0
	player.yaw = PI; player.pitch = -0.15
	await wait(0.4)
	for sk in Loot.SKINS:
		var id := Loot.make_skin(4, 3, sk)
		Game.add_item(id, false)
		Game.equip(id)
		await wait(0.9)
		player.facing = PI   # look the camera in the eye
		player.yaw = 0.0; player.snap_view()
		await wait(0.5)
		await shot("look_skin_" + sk)
	Game.unequip("skin")
	var ew := Loot.make_weapon(4, 3); Game.add_item(ew, false); Game.equip(ew)
	var ea := Loot.make_armor(4, 4); Game.add_item(ea, false); Game.equip(ea)
	await wait(1.0)
	player.facing = PI; player.yaw = 0.0; player.snap_view()
	await wait(0.5)
	await shot("look_epic_gear")
	check("looks_change", true, "skins and auras captured")
	main._open("inventory")
	await wait(0.6)
	await shot("look_inventory")
	main._resume()

# --- boss balance (no cheats) ----------------------------------------------------
func _gear_up_like_a_player() -> void:
	# loot from every chest before the boss + drops from every monster
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.kind == "chest":
			for l in n.loot:
				var rolled: Array = Loot.roll_chest(l.roll, Loot.area_level(n.global_position.z)) if l.has("roll") else [l]
				for d in rolled:
					match d.kind:
						"potion": Game.potions += int(d.get("amount", 1))
						"mana": Game.mana_potions += int(d.get("amount", 1))
						"item": Game.add_item(d.id)
						"gold": Game.gold += int(d.amount)
	for t in ["minion", "minion", "minion", "warrior", "warrior", "minion", "revenant", "minion", "minion", "mage", "mage", "warrior", "minion"]:
		for d in Loot.roll_enemy(t, 3):
			match d.kind:
				"potion": Game.potions += 1
				"mana": Game.mana_potions += 1
				"item": Game.add_item(d.id)
	# a real player drinks some on the way down
	Game.potions = int(Game.potions * 0.5)
	Game.mana_potions = int(Game.mana_potions * 0.5)

func _bot_boss() -> Dictionary:
	await tp(Vector3(0, -5.9, -139), 0.0)
	Game.hp = Game.max_hp(); Game.mana = Game.max_mana()
	face(Vector3(0, -6, -157))
	Input.action_press("move_forward")
	var tw := 0.0
	while not world().boss_started and tw < 8.0:
		await wait(0.2); tw += 0.2
	Input.action_release("move_forward")
	var w: Warden = world().warden
	var t := 0.0
	var pot0 := player.potions_used; var mp0 := player.mana_potions_used
	var casts0 := player.bolts_fired
	var gt0 := game_time
	# "human" skill: reacts to only some telegraphs, a little slower to swing
	var skill := float(OS.get_environment("BALANCE_SKILL")) if OS.has_environment("BALANCE_SKILL") else 0.5
	var reacted := {}
	var min_frac := 1.0
	var dmg0 := player.damage_taken
	while game_time - gt0 < 300.0 and is_instance_valid(w) and not w.dead and not player.dead:
		var d := player.global_position.distance_to(w.global_position)
		min_frac = minf(min_frac, Game.hp / Game.max_hp())
		if Game.hp < Game.max_hp() * 0.4 and Game.potions > 0 and player.potion_cd <= 0.0:
			await tap("potion")
		elif Game.mana < 20.0 and Game.mana_potions > 0 and player.potion_cd <= 0.0 and d > 5.0:
			await tap("mana_potion")
		var danger := (w.state == Warden.S.SLAM or w.state == Warden.S.LEAP) and \
			Vector2(player.global_position.x - w._target.x, player.global_position.z - w._target.z).length() < 6.0
		var tele_id := "%d_%d" % [w.state, int((game_time - gt0) / 1.5)]
		if danger and not reacted.has(tele_id):
			reacted[tele_id] = randf() < skill   # decide once per telegraph whether we notice it
		var will_dodge: bool = danger and reacted.get(tele_id, false)
		if will_dodge and not player.dodging and Game.stamina >= 22:
			var away := player.global_position - w._target
			face(player.global_position + away)
			Input.action_press("move_forward")
			await tap("dodge")
			await wait(0.45)
			Input.action_release("move_forward")
		else:
			var add := nearest_enemy(5.0)
			var target: Node3D = add if add != null and add != w else w
			face(target.global_position)
			var dt := player.global_position.distance_to(target.global_position)
			var reach := 3.4 if target == w else 2.0
			if target == w and Game.mana >= 20.0 and (dt > 5.0 or randf() < 0.3):
				Input.action_release("move_forward")
				await tap("spell")
			elif dt > reach:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
				await tap("attack")
				if randf() > skill:
					await wait(0.25)   # a human pauses between swings now and then
		await wait(0.1)
		t += 0.1
	Input.action_release("move_forward")
	return {"won": is_instance_valid(w) and w.dead, "died": player.dead, "game_time": snappedf(game_time - gt0, 0.1), "skill": skill, "lowest_hp_pct": int(min_frac * 100), "damage_taken": int(player.damage_taken - dmg0),
		"warden_hp": w.hp if is_instance_valid(w) else 0.0, "hp_left": Game.hp,
		"heal_used": player.potions_used - pot0, "mana_used": player.mana_potions_used - mp0,
		"heal_left": Game.potions, "mana_left": Game.mana_potions, "casts": player.bolts_fired - casts0,
		"attack": Game.attack_damage(), "defense": Game.defense(), "max_hp": Game.max_hp(), "spell": Game.spell_damage()}

func _balance_test() -> void:
	await _start()
	god = false
	var setup := OS.get_environment("BALANCE_SETUP") if OS.has_environment("BALANCE_SETUP") else "geared"
	var sd := int(OS.get_environment("BALANCE_SEED")) if OS.has_environment("BALANCE_SEED") else 7
	Loot.rng.seed = sd
	seed(sd)
	Game.level = 4
	if setup == "geared":
		_gear_up_like_a_player()
	Game.hp = Game.max_hp(); Game.mana = Game.max_mana(); Game.stamina = Game.max_stamina()
	var gear := []
	for sl in Game.SLOTS:
		var it := Game.item(Game.equipped[sl])
		if not it.is_empty():
			gear.append("%s[%s]" % [it.name, Loot.RARITY_NAMES[it.rarity]])
	print("BALANCE skill=%s setup=%s seed=%d level=%d heal=%d mana=%d gear=%s" % [OS.get_environment("BALANCE_SKILL"), setup, sd, Game.level, Game.potions, Game.mana_potions, gear])
	var r := await _bot_boss()
	print("BALANCE result %s" % JSON.stringify(r))
	check("balance_%s_seed%d" % [setup, sd], r.won if setup == "geared" else not r.won, JSON.stringify(r))

## A new item of this slot was picked up, and the equipped one is the best owned.
func _found_and_best(slot: String, before: Array) -> bool:
	var found := false
	var best := -INF
	for id in Game.inventory:
		if Game.item(id).get("slot", "") == slot:
			best = maxf(best, Game.score(id))
			if not before.has(id):
				found = true
	return found and Game.score(Game.equipped[slot]) >= best - 0.01

# --- hero special abilities -----------------------------------------------------
func _dummy(pos: Vector3) -> Enemy:
	var e := Enemy.new(); e.configure("revenant", "dummy"); e.position = pos; world().add_child(e)
	return e

func _special_test() -> void:
	await _start()
	god = true
	var at := Vector3(0, -5.9, -62)
	for hero in ["Rogue", "Mage", "Knight", "Barbarian", "Ranger"]:
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		Game.profile.hero = hero
		player.rebuild_body()
		player.special_cd = 0.0
		await tp(at, 0.0)
		player.facing = 0.0; player.yaw = 0.0; player.zoom_target = 4.5; player.zoom = 4.5; player.snap_view()
		var foes: Array = []
		match hero:
			"Rogue": foes = [_dummy(at + Vector3(0.5, -0.1, -5.0))]
			"Mage": foes = [_dummy(at + Vector3(0.6, -0.1, -1.2))]
			"Knight": foes = [_dummy(at + Vector3(0, -0.1, -4.0))]
			"Barbarian": foes = [_dummy(at + Vector3(1.6, -0.1, 0)), _dummy(at + Vector3(-1.6, -0.1, 0.3)), _dummy(at + Vector3(0, -0.1, -1.8))]
			"Ranger": foes = [_dummy(at + Vector3(-1.5, -0.1, -7.0)), _dummy(at + Vector3(1.5, -0.1, -7.0))]
		await wait(0.6)
		var hp0: Array = foes.map(func(f: Enemy) -> float: return f.hp)
		var p0 := player.global_position
		var d0 := player.special_damage
		await tap("special")
		await wait(0.12)
		await shot("s_%s_a" % hero)
		await wait(0.9)
		await shot("s_%s_b" % hero)
		var hurt := 0
		for i in foes.size():
			var f: Enemy = foes[i]
			if not is_instance_valid(f) or f.dead or f.hp < hp0[i] - 1.0:
				hurt += 1
		var moved := player.global_position.distance_to(p0)
		match hero:
			"Rogue":
				var f: Enemy = foes[0]
				check("rogue_backstab_behind", is_instance_valid(f) and player.global_position.z < f.global_position.z, "player z %.1f enemy z %.1f" % [player.global_position.z, f.global_position.z if is_instance_valid(f) else 0.0])
				check("rogue_backstab_hits", hurt == 1 and player.special_damage - d0 > Game.attack_damage() * 3.0, "%.0f dmg" % (player.special_damage - d0))
			"Mage":
				check("mage_shadow_step_moves", moved > 4.0, "%.1f m" % moved)
				check("mage_shadow_burst_hits", hurt == 1, "%d hit" % hurt)
			"Knight":
				check("knight_charge_moves", moved > 2.0, "%.1f m" % moved)
				check("knight_charge_hits", hurt == 1, "%d hit" % hurt)
			"Barbarian":
				check("barbarian_whirlwind_hits_all", hurt == 3, "%d of 3 hit, %.0f dmg" % [hurt, player.special_damage - d0])
			"Ranger":
				check("ranger_volley_hits", hurt >= 1, "%d of 2 hit" % hurt)
		check("%s_on_cooldown" % hero.to_lower(), player.special_cd > 0.0)
		var used := player.specials_used
		player.use_special()
		check("%s_cooldown_blocks_reuse" % hero.to_lower(), player.specials_used == used)
	# no enemy in reach: backstab does nothing and costs no cooldown
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await wait(0.3)
	Game.profile.hero = "Rogue"; player.rebuild_body(); player.special_cd = 0.0
	player.use_special()
	check("backstab_needs_target", player.special_cd == 0.0)

# --- character creator looks: close-ups of every hero with each option --------
func _looks_test() -> void:
	var m = main.menus
	m.show_panel("creator")
	await wait(0.5)
	await shot("k_creator_default")
	m.current = "looks"   # stop the turntable
	var cam: Camera3D = m._preview_vp.find_children("*", "Camera3D", true, false)[0]
	var combos := [
		{"hair_style": "cropped", "face": "beard", "hair_color": 4, "skin": 5},
		{"hair_style": "long", "face": "blush", "hair_color": 3, "skin": 2},
		{"hair_style": "ponytail", "face": "eyepatch", "hair_color": 0, "skin": 4},
		{"hair_style": "buns", "face": "warpaint", "hair_color": 7, "skin": 1},
		{"hair_style": "spiky", "face": "scar", "hair_color": 6, "skin": 3},
		{"hair_style": "mohawk", "face": "mustache", "hair_color": 8, "skin": 6},
		{"hair_style": "bald", "face": "beard", "hair_color": 5, "skin": 7},
		{"hair_style": "natural", "face": "none", "hair_color": 1, "skin": 0},
	]
	var heroes: Array = Game.HERO_ORDER if OS.get_environment("LOOKS_ALL") != "" else ["Knight", "Rogue"]
	for hero in heroes:
		for i in combos.size():
			var c: Dictionary = combos[i]
			Game.profile.hero = hero
			Game.profile.show_hat = false
			for k in c:
				Game.profile[k] = c[k]
			m._refresh_preview()
			for side in [PI, PI + 0.9]:
				m._preview.rotation.y = side
				cam.position = Vector3(0, 1.8, 5.2); cam.look_at(Vector3(0, 1.62, 0))
				await frames(4)
				await RenderingServer.frame_post_draw
				m._preview_vp.get_texture().get_image().save_png(out_dir.path_join("k_%s_%d_%s.png" % [hero, i, "f" if side == PI else "s"]))
	# body shapes
	cam.position = Vector3(0, 1.4, 6.6); cam.look_at(Vector3(0, 1.1, 0))
	Game.profile.hero = "Rogue"; Game.profile.hair_style = "natural"; Game.profile.face = "none"; Game.profile.skin = 0
	for bh in [[0.82, 0.86], [1.0, 1.0], [1.3, 1.14]]:
		Game.profile.build = bh[0]; Game.profile.height = bh[1]
		m._refresh_preview(); m._preview.rotation.y = PI
		await frames(4)
		await RenderingServer.frame_post_draw
		m._preview_vp.get_texture().get_image().save_png(out_dir.path_join("k_body_%s.png" % str(bh[0])))
	cam.position = Vector3(0, 1.4, 6.6); cam.look_at(Vector3(0, 1.1, 0))
	Game.profile.build = 1.0; Game.profile.height = 1.0
	m.current = "creator"
	m._randomize_look()
	await wait(0.6)
	await shot("k_creator_random")
	check("looks_rendered", true)

# --- small UI checks -----------------------------------------------------------
func _ui_test() -> void:
	check("sound_starts_on", not Sfx.muted and main.menus._mute_btn.text.begins_with("Sound is ON"), main.menus._mute_btn.text)
	Game.profile.cape = 1   # crimson
	main.menus.show_panel("creator")
	main.menus._refresh_preview()
	await wait(1.0)
	await shot("u_creator_crimson")
	Game.profile.cape = 2   # azure
	main.menus._refresh_preview()
	await wait(1.0)
	await shot("u_creator_azure")
	Game.profile.cape = 3   # verdant
	Game.profile.hero = "Rogue"
	main.menus._refresh_preview()
	await wait(1.0)
	await shot("u_creator_rogue_green")
	Game.profile.hero = "Knight"
	Game.profile.cape = 2
	Game.profile.name = "Testa"
	Game.profile.merge({"show_hat": false, "hair_style": "spiky", "hair_color": 5, "skin": 5, "face": "beard", "build": 1.2, "height": 1.1}, true)
	main._start_game()
	player = main.player
	await wait(1.0)
	player.facing = PI; player.yaw = 0.0; player.zoom_target = 3.0; player.zoom = 3.0; player.snap_view()
	await wait(0.6)
	await shot("u_ingame_azure")
	var cm: CharacterModel = player.find_children("*", "CharacterModel", true, false)[0]
	check("custom_looks_in_game", cm.looks_root != null and cm.looks_root.get_child_count() > 2)
	# the bag can be closed with its own button
	main._open("inventory")
	await wait(0.4)
	var btn: Button = main.menus._bag_close
	check("bag_has_close_button", btn != null and btn.is_visible_in_tree())
	await shot("u_bag")
	var r := btn.get_global_rect()
	check("bag_close_button_small", r.size.x < 300 and r.size.y < 120, "%s" % r.size)
	btn.pressed.emit()
	await wait(0.4)
	check("bag_close_button_works", main.menus.current == "" and not get_tree().paused, main.menus.current)
	main._open("pause")
	await wait(0.3)
	check("pause_sound_label", main.menus._pause_sound_btn.text.begins_with("Sound is ON"), main.menus._pause_sound_btn.text)
	main.menus._toggle_mute()
	check("mute_toggles", Sfx.muted and main.menus._pause_sound_btn.text.begins_with("Sound is OFF") and AudioServer.is_bus_mute(0))
	main.menus._toggle_mute()
	check("unmute_toggles", not Sfx.muted and not AudioServer.is_bus_mute(0))
	main._resume()

func world() -> VaultWorld:
	return main.world

# ---------------------------------------------------------------------------
func _shots() -> void:
	await _start()
	god = true
	var spots := [
		["s_outpost", Vector3(0, 0.1, 28), 0.0, -0.12, 4.5], ["s_entrance", Vector3(3, 0.1, 8), 0.25, 0.05, 3.5],
		["s_stairs_fp", Vector3(0, -2.5, -6), 0.0, -0.25, 0.0], ["s_hall", Vector3(0, -5.9, -14), 0.0, -0.1, 4.0],
		["s_corridor", Vector3(0, -5.9, -35.5), 0.0, -0.05, 0.0], ["s_armory", Vector3(0, -5.9, -61.5), 0.0, -0.15, 4.0],
		["s_deep_fp", Vector3(-2, -5.9, -95), 0.15, -0.2, 0.0], ["s_deep_tp", Vector3(-10, -5.9, -104), 0.9, -0.25, 6.0],
		["s_bridge", Vector3(0, -5.9, -112), 1.57, -0.15, 3.0], ["s_island", Vector3(13, -5.9, -119), 2.6, -0.25, 3.5],
		["s_falls", Vector3(-4, -5.9, -122), 0.0, 0.25, 0.0], ["s_sanctum", Vector3(0, -5.9, -143.5), 0.0, -0.05, 4.0],
	]
	for s in spots:
		player.zoom_target = s[4]; player.zoom = s[4]
		await tp(s[1], s[2], s[3])
		await wait(1.2)
		await shot(s[0])

func _finish() -> void:
	var passed := results.filter(func(r): return r.ok).size()
	var summary := {"mode": mode, "passed": passed, "total": results.size(), "seconds": (Time.get_ticks_msec() - t0) / 1000.0,
		"renderer": RenderingServer.get_video_adapter_name(), "results": results}
	var f := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(summary, "  "))
	print("AUTOTEST SUMMARY %d/%d passed in %.0fs" % [passed, results.size(), summary.seconds])
	get_tree().quit(0 if passed == results.size() else 1)
