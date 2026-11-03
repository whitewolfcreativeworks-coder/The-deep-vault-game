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
	if god and player:
		Game.hp = maxf(Game.hp, Game.max_hp() * 0.8)
		Game.stamina = Game.max_stamina()
		Game.mana = Game.max_mana()

func tp(pos: Vector3, yaw: float, pitch := -0.2) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.yaw = yaw; player.facing = yaw; player.pitch = pitch
	player.cam_yaw.global_position = pos + Vector3(0, Player.EYE_H, 0)
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
	var killed := 0
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
		if not is_instance_valid(e) or e.dead:
			killed += 1
	Input.action_release("move_forward")
	return killed

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
	await tp(Vector3(1.0, -5.9, -58.4), -PI / 2)
	var lever_ok := await use_nearest_interactable()
	await wait(2.6)
	check("lever_opens_gate", lever_ok and world().corridor_gate.is_open)
	# armory
	await tp(Vector3(0, -5.9, -62), 0.0)
	await shot("06_armory")
	var ak := await clear_enemies(26.0, 90.0)
	check("armory_cleared_incl_revenant", ak >= 3, "%d killed" % ak)
	await tp(Vector3(-8.0, -5.9, -63.5), PI / 2)
	await use_nearest_interactable()
	await wait(2.0)
	check("weapon_upgrade_equipped", Game.equipped.weapon == "knight_sword", Game.equipped.weapon)
	await tp(Vector3(0, -5.9, -81.2), 0.0)
	await use_nearest_interactable()
	await wait(2.0)
	check("armor_upgrade_equipped", Game.equipped.armor == "chainmail", Game.equipped.armor)
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
	# river burns without the amulet
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
	check("runeblade_equipped", Game.equipped.weapon == "vault_blade", Game.equipped.weapon)
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

func _touch_test() -> void:
	await _start()
	await tp(Vector3(0, 0.1, 26), 0.0)
	var r := get_viewport().get_visible_rect().size
	var tc: TouchControls = main.touch
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
