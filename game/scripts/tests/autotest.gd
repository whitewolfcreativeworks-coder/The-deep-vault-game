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
	elif mode == "combat2":
		await _combat2_test()
	elif mode == "websave1":
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		Game.add_gold(42)
		main.autosave()
		await wait(3.0)   # let the browser flush user:// to IndexedDB
		check("web_save_written", Game.has_save(0))
	elif mode == "websave2":
		await wait(3.0)
		check("web_save_survives_reopen", Game.any_save() and Game.slot_summary(0).get("gold", 0) == 42, str(Game.slot_summary(0)))
		check("web_title_offers_continue", main.menus._continue_btn.visible)
		main.menus._open_slots("continue")
		await wait(0.8)
		await shot("ws_slots_after_reopen")
	elif mode == "forestshots":
		# quick look at forest places (no quests): used while building the level
		Game.zone = "forest"
		if not (main.world is ForestWorld):
			Game.set_meta("fshots", true)
			await _start()
			main.go_to_forest()
			return
		await wait(2.0)
		player = main.player
		god = true
		var w: ForestWorld = main.world
		for v in [["fs_gate", w.ground(0, -76), 0.0, 0.15, 7.0], ["fs_lumber", w.ground(-48, 52), -2.4, -0.1, 7.0],
				["fs_maera", w.ground(46, 14), 2.2, -0.1, 7.0], ["fs_camp", w.ground(-45, -30), -2.3, -0.2, 9.0],
				["fs_merchant", w.ground(-8, -12), -2.4, -0.15, 7.0], ["fs_bridge", w.ground(10, 30), 0.4, -0.15, 8.0],
				["fs_den", Vector3(0, ForestWorld.WY + 0.1, -142), 0.0, -0.1, 6.0], ["fs_hall", Vector3(0, ForestWorld.WY + 0.1, -172), 0.0, -0.05, 7.0]]:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.global_position.distance_to(v[1]) < 25.0:
					e.set_physics_process(false)
			await tp(v[1] + Vector3(0, 0.3, 0), v[2], v[3])
			player.zoom_target = v[4]; player.zoom = v[4]; player.pitch = v[3]; player.snap_view()
			await wait(1.4)
			await shot(v[0])
	elif mode == "intro" or mode == "introskip":
		await wait(1.5)
		main.menus.show_panel("creator")
		await wait(0.5)
		main.menus.start_requested.emit()   # "Enter the Vault"
		await wait(0.5)
		check("intro_starts", main.state == "intro" and main.intro != null, main.state)
		if mode == "introskip":
			await wait(3.0)
			main.intro.skip_now()
			await wait(1.5)
			check("skip_goes_to_vault", main.state == "play" and main.intro == null and main.world.is_inside_tree(), main.state)
		else:
			var seen := {}
			var t := 0.0
			var t_start := Time.get_ticks_msec()
			while main.state == "intro" and t < 150.0:
				var sh: String = main.intro.shot if main.intro else ""
				if sh != "" and not seen.has(sh):
					seen[sh] = true
					await wait(1.6)
					await shot("in_" + sh)
				await wait(0.25)
				t += 0.25
				if OS.get_environment("INTRO_FRAMES") != "" and int(t * 4.0) % (4 if OS.get_environment("INTRO_FRAMES") == "1" else 2) == 0:
					await shot("f_%03d" % int(t))
			var secs := (Time.get_ticks_msec() - t_start) / 1000.0
			print("INTRO_LENGTH ", secs)
			check("intro_short", secs < 60.0, "%.1f s" % secs)
			for sh2 in ["sunrise", "bed", "dress", "teeth", "kettle", "tea", "portal"]:
				check("intro_shot_" + sh2, seen.has(sh2))
			await wait(2.0)
			check("intro_ends_at_vault", main.state == "play" and main.world is VaultWorld and main.player.global_position.distance_to(main.world.spawn_point) < 3.0)
			await shot("in_arrival")
	elif mode == "forest":
		if await _forest_test():
			return
	elif mode == "compass":
		if await _compass_test():
			return
	elif mode == "daynight":
		if await _daynight_test():
			return
	elif mode == "costumes":
		await _costumes_test()
	elif mode == "sinkhole":
		if await _sinkhole_test():
			return
	elif mode == "saves":
		if await _saves_test():
			return   # the scene reloaded: the next phase runs in a fresh test node
	elif mode == "swing":
		await _start()
		god = true
		for z in [[0.0, "fp"], [4.2, "behind"]]:
			player.zoom_target = z[0]; player.zoom = z[0]; player.snap_view()
			await wait(0.8)
			for k in 3:
				Engine.time_scale = 0.08
				Input.action_press("attack")
				while not (player.attacking and player.hit_done):
					await frames(1)
				Input.action_release("attack")
				await frames(2)
				await shot("sw_%s_%d" % [z[1], k])
				Engine.time_scale = 1.0
				combo_hold()
				await wait(0.3)
	elif mode == "djump":
		await _start()
		god = true
		await tp(Vector3(0, -5.9, -62), 0.0)
		await wait(0.8)
		for seq in [[0.0], [0.0, 0.18], [0.0, 0.3]]:
			var y0 := player.global_position.y
			var top := y0
			var dj0 := player.double_jumps
			for k in seq.size():
				if k > 0:
					await wait(seq[k])
				await press("jump", 0.07)
				print("DJ tap %d y=%.2f vy=%.2f floor=%s air=%d buf=%.2f coy=%.2f mant=%s ts=%.2f inp=%s dead=%s dodge=%s" % [k, player.global_position.y - y0, player.velocity.y, player.is_on_floor(), player._air_jumps, player._jump_buffer, player._coyote, player.mantling, Engine.time_scale, player.input_enabled, player.dead, player.dodging])
			for i in 90:
				await frames(1)
				top = maxf(top, player.global_position.y)
			print("DJ seq %s top=%.2f doubles=%d" % [str(seq), top - y0, player.double_jumps - dj0])
			await wait(0.6)
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
		if Game.has_meta("flow_phase"):
			await _flow_after_portal()
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
	var claimed := await use_nearest_interactable()
	await wait(7.5)
	var w = main.world
	check("level1_complete_portal_opens", claimed and w._portal_open and w.secret_door.position.y < -9.0, "door y %.1f" % w.secret_door.position.y)
	player.yaw = 0.0; player.pitch = 0.05; player.zoom_target = 6.0; player.zoom = 6.0; player.snap_view()
	await wait(1.0)
	await shot("15_ancient_portal")
	# walk into the portal: the game travels to Level 2 (the scene reloads)
	Game.set_meta("flow_phase", 2)
	await tp(Vector3(0, -5.9, -175.5), 0.0)
	Input.action_press("move_forward")
	for i in 60:
		await wait(0.1)
		if not w._portal_open:     # stepped in: let go before the world changes
			Input.action_release("move_forward")
			await wait(5.0)
	Input.action_release("move_forward")
	check("portal_reached", false, "still in the Vault at %s" % player.global_position)

func _flow_after_portal() -> void:
	Game.remove_meta("flow_phase")
	Input.action_release("move_forward")
	await wait(2.5)
	player = main.player
	check("portal_leads_to_forest", main.world is ForestWorld and Game.zone == "forest" and main.state == "play", Game.zone)
	check("arrive_at_forest_portal", player.global_position.distance_to(main.world.spawn_point) < 3.0, str(player.global_position))
	await shot("16_forest_arrival")

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
	var atk: Dictionary = tc.button("attack")
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
	var pz: Dictionary = tc.button("pause")
	await touch_ev(6, pz.center, true); await touch_ev(6, pz.center, false)
	await wait(0.3)
	check("touch_pause_button", main.menus.current == "pause", main.menus.current)
	await shot("t3_pause_menu")
	main._resume()
	await wait(0.3)
	# zoom slider on the left edge: top = first person, bottom = high view
	var zr: Rect2 = tc._zoom_rect()
	var ztop := Vector2(zr.get_center().x, zr.position.y + 20.0)
	var zbot := Vector2(zr.get_center().x, zr.end.y - 20.0)
	await touch_ev(8, zbot, true)
	await drag_ev(8, zbot, ztop)
	await wait(0.5)
	var z_fp := player.zoom_target
	await drag_ev(8, ztop, zbot)
	await touch_ev(8, zbot, false)
	await wait(0.5)
	check("zoom_slider", z_fp == 0.0 and player.zoom_target > 8.0, "top %.1f bottom %.1f" % [z_fp, player.zoom_target])
	await shot("t4_zoom_slider_high")
	# pinch (fingers together) back out of first person, even with one finger on the left half
	player.zoom_target = 0.0
	await wait(0.4)
	var pa := Vector2(r.x * 0.30, r.y * 0.35); var pb := Vector2(r.x * 0.58, r.y * 0.35)
	await touch_ev(2, pb, true); await touch_ev(3, pa, true)
	for i in 8:
		var e3 := InputEventScreenDrag.new(); e3.index = 3
		e3.position = to_win(pa.lerp(Vector2(r.x * 0.41, r.y * 0.35), (i + 1) / 8.0)); e3.relative = Vector2(8, 0)
		Input.parse_input_event(e3)
		var e4 := InputEventScreenDrag.new(); e4.index = 2
		e4.position = to_win(pb.lerp(Vector2(r.x * 0.47, r.y * 0.35), (i + 1) / 8.0)); e4.relative = Vector2(-8, 0)
		Input.parse_input_event(e4)
		await frames(1)
	await touch_ev(2, pb, false); await touch_ev(3, pa, false)
	await wait(0.4)
	check("pinch_out_of_first_person", player.zoom_target > 1.0, "zoom %.1f" % player.zoom_target)
	# hold a button still: it turns yellow and can be moved; it stays there
	tc.reset_layout()
	var jb2: Dictionary = tc.button("jump")
	var j0: Vector2 = jb2.center
	await touch_ev(10, j0, true)
	await wait(1.4)
	var picked: bool = tc._moving.values().has("jump")
	await shot("t5_button_picked_up")
	var dest := Vector2(r.x * 0.8, r.y * 0.5)
	await drag_ev(10, j0, dest)
	await touch_ev(10, dest, false)
	await wait(0.2)
	var moved_to: Vector2 = tc.button("jump").center
	check("hold_to_move_button", picked and moved_to.distance_to(dest) < 30.0, "picked=%s now at %s" % [picked, moved_to])
	tc._layout()   # positions survive a relayout (and are saved to disk)
	check("moved_button_saved", tc.button("jump").center.distance_to(dest) < 30.0 and FileAccess.file_exists(TouchControls.SAVE_PATH))
	await shot("t6_button_moved")
	# arrange mode from the pause menu moves ATTACK too; reset restores everything
	tc.set_arrange(true)
	var a1: Vector2 = tc.button("attack").center
	await touch_ev(11, a1, true)
	await drag_ev(11, a1, a1 + Vector2(-150, -120))
	await touch_ev(11, a1 + Vector2(-150, -120), false)
	await shot("t7_arrange_mode")
	check("arrange_moves_attack", tc.button("attack").center.distance_to(a1) > 100.0)
	tc.set_arrange(false)
	tc.reset_layout()
	check("reset_layout", tc.button("jump").center.distance_to(j0) < 2.0 and tc.button("attack").center.distance_to(a1) < 2.0)
	player.zoom_target = 4.2
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
				var jb: Dictionary = tc._buttons.filter(func(b: Dictionary) -> bool: return b.name == "jump")[0]
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

# --- Level 2: the Goblin Forest -------------------------------------------------
func _npc(id: String) -> NPC:
	for n in get_tree().get_nodes_in_group("npc"):
		if (n as NPC).id == id:
			return n
	return null

func _talk(id: String) -> void:
	var n := _npc(id)
	await tp(n.global_position + Vector3(0, 0.2, 2.2), 0.0)
	await wait(0.3)
	main.open_dialogue(n)
	await wait(0.5)

func _kill_near(types: Array, radius: float, at: Vector3) -> int:
	var k := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and not e.dead and (e.type_id in types) and e.global_position.distance_to(at) < radius:
			e.take_damage(99999.0, player.global_position)
			k += 1
	return k

func _forest_test() -> bool:
	var phase: int = Game.get_meta("forest_phase", 1)
	if phase == 1:
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		Game.set_meta("forest_phase", 2)
		main.go_to_forest()       # as if the Vault was won and the portal taken
		return true
	if phase == 2:
		await wait(2.5)
		player = main.player
		god = true
		check("forest_loaded", main.world is ForestWorld and Game.zone == "forest", str(Game.zone))
		check("six_npcs", get_tree().get_nodes_in_group("npc").size() == 6)
		player.zoom_target = 4.2; player.zoom = 4.2; player.pitch = -0.12; player.snap_view()
		await wait(1.5)
		await shot("fo_01_arrival")
		var w: ForestWorld = main.world
		var entrance := w.ground(0, -101)
		var cam_to_warren: Vector3 = entrance - player.camera.global_position
		var q := PhysicsRayQueryParameters3D.create(player.camera.global_position, entrance + Vector3(0, 12.0, -4.0), 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		check("warren_in_view_from_portal", hit.is_empty() or (hit.position as Vector3).distance_to(entrance) < 14.0, "%.0f m away" % cam_to_warren.length())
		player.zoom_target = 9.5; player.zoom = 9.5; player.snap_view()
		await wait(1.2)
		await shot("fo_02_arrival_high")
		player.zoom_target = 5.0; player.zoom = 5.0; player.yaw = PI; player.pitch = -0.05; player.snap_view()
		await wait(1.2)
		await shot("fo_02b_portal")
		player.yaw = 0.0
		player.zoom_target = 4.2; player.zoom = 4.2
		# 1. Ranger Fenn: goblin hunt
		await _talk("fenn")
		await shot("fo_03_dialogue_fenn")
		main.menus._dlg_buttons.get_child(0).pressed.emit()
		await wait(0.3)
		check("quest_accepted", Game.quest_state("goblin_trouble") == "active")
		main._resume()
		await wait(0.3)
		await shot("fo_04_quest_tracker")
		check("warren_locked_before", not w.door.is_open())
		var killed := 0
		for c in [Vector3(0, 0, 40), Vector3(0, 0, -30), Vector3(-58, 0, -42), Vector3(60, 0, -50)]:
			killed += _kill_near(Enemy.TYPES.keys(), 30.0, w.ground(c.x, c.z))
			await wait(0.6)
		check("goblin_hunt_ready", Game.quest_state("goblin_trouble") == "ready", "%d killed, %d/10" % [killed, Game.quest_progress("goblin_trouble")])
		var lvl0 := Game.level; var g0 := Game.gold; var inv0 := Game.inventory.size()
		await _talk("fenn")
		main.menus._dlg_buttons.get_child(0).pressed.emit()
		await wait(0.4)
		await shot("fo_05_reward")
		main._resume()
		check("quest_reward", Game.quest_state("goblin_trouble") == "done" and Game.gold > g0 and Game.inventory.size() > inv0, "gold %d -> %d" % [g0, Game.gold])
		# 2. Bram's axes
		await _talk("bram")
		main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		var axes := get_tree().get_nodes_in_group("quest_item").filter(func(n) -> bool: return n.item == "axe")
		check("axes_visible_after_accept", axes.size() == 3 and axes.all(func(n) -> bool: return n.visible))
		await tp(axes[0].global_position + Vector3(0, 0.3, 2.0), 0.0)
		await wait(0.4)
		await shot("fo_06_axe")
		for a in axes:
			await tp(a.global_position + Vector3(0, 0.3, 0), 0.0)
			await wait(0.5)
		check("axes_collected", Game.quest_state("stolen_axes") == "ready", "%d/3" % Game.quest_progress("stolen_axes"))
		await _talk("bram"); main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		# 3. Maera's moonpetals
		await _talk("maera")
		await shot("fo_07_maera")
		main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		for n in get_tree().get_nodes_in_group("quest_item"):
			if n.item == "moonpetal" and Game.quest_state("moonpetals") == "active":
				await tp(n.global_position + Vector3(0, 0.3, 0), 0.0)
				await wait(0.5)
		check("moonpetals_gathered", Game.quest_state("moonpetals") == "ready")
		await _talk("maera"); main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		# 4. Tobble and 5. Captain Aldric
		await _talk("tobble"); main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		await _talk("aldric")
		await shot("fo_08_aldric")
		main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		check("warren_unbarred", w.door.is_open())
		await tp(w.ground(0, -78) + Vector3(0, 0.2, 0), 0.0)
		player.zoom_target = 6.0; player.zoom = 6.0; player.pitch = 0.12; player.snap_view()
		await wait(1.0)
		await shot("fo_09_warren_entrance")
		w.door.interact(player)
		await wait(1.5)
		check("entered_warren", player.global_position.y < ForestWorld.WY + 5.0, str(player.global_position))
		await shot("fo_10_warren_mouth")
		await tp(Vector3(0, ForestWorld.WY + 0.1, -150), PI * 0.0)
		await wait(0.8)
		await shot("fo_11_goblin_den")
		_kill_near(Enemy.TYPES.keys(), 20.0, Vector3(0, ForestWorld.WY, -150))
		await tp(Vector3(0, ForestWorld.WY + 0.1, -176), 0.0)
		await wait(1.5)
		await shot("fo_12_gruk")
		var gk: Enemy = w.gruk
		gk.take_damage(gk.max_hp * 0.55, player.global_position)
		await wait(1.2)
		check("gruk_summons_help", get_tree().get_nodes_in_group("enemy").filter(func(e) -> bool: return e.uid == "" and not e.dead).size() >= 2)
		gk.take_damage(99999.0, player.global_position)
		_kill_near(Enemy.TYPES.keys(), 30.0, gk.global_position)
		await wait(1.0)
		check("gruk_quest_ready", Game.quest_state("warren") == "ready")
		var box := get_tree().get_nodes_in_group("quest_item").filter(func(n) -> bool: return n.item == "strongbox")
		await tp(box[0].global_position + Vector3(0, 0.3, 0), 0.0)
		await wait(0.6)
		check("strongbox_found", Game.quest_state("strongbox") == "ready")
		await _talk("tobble"); main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		await _talk("aldric"); main.menus._dlg_buttons.get_child(0).pressed.emit(); await wait(0.2); main._resume()
		await wait(3.5)
		check("forest_victory", main.menus.current == "forest_victory", main.menus.current)
		await shot("fo_13_forest_victory")
		main._resume()
		# save and continue in the forest
		Game.set_meta("forest_phase", 3)
		Game.set_meta("forest_lvl", Game.level)
		main.autosave()
		Game.reset_run()
		main._continue_slot(0)
		return true
	await wait(2.5)
	player = main.player
	check("continue_in_forest", main.world is ForestWorld and Game.zone == "forest")
	check("quests_saved", Game.quest_state("warren") == "done" and Game.quest_state("moonpetals") == "done")
	check("slot_says_forest", Game.slot_summary(0).get("zone", "") == "The Goblin Forest")
	Game.remove_meta("forest_phase")
	return false

# --- save slots: save, "close the app", continue where you left off ------------
## Phase 1 plays and saves, then reloads the game like reopening the app.
## Phase 2 (a new test node after the reload) checks everything came back.
func _saves_test() -> bool:
	var phase: int = Game.get_meta("saves_phase", 1)
	if phase == 1:
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		god = true
		check("new_game_gets_slot", Game.active_slot == 0, str(Game.active_slot))
		Game.add_xp(Game.xp_to_next() + Game.xp_to_next() + 5)   # to level 3
		Game.add_gold(77)
		var wid := Loot.make_weapon(3, 3)
		Game.add_item(wid, false)
		# kill one enemy for good
		await tp(Vector3(0, -5.9, -62), 0.0)
		await wait(0.8)
		var e := nearest_enemy(40.0) as Enemy
		var dead_uid := e.uid if e else ""
		if e:
			e.take_damage(99999.0, player.global_position)
		await wait(1.0)
		var at := player.global_position
		Game.set_meta("saves_expect", {"level": Game.level, "gold": Game.gold, "item": wid, "uid": dead_uid, "pos": at,
			"inv": Game.inventory.size(), "flags": Game.flags.size()})
		main.autosave()
		check("save_file_written", Game.has_save(0) and Game.slot_summary(0).get("level", 0) == Game.level, str(Game.slot_summary(0)))
		await shot("sv1_before_close")
		# "close and reopen the app": wipe the live state, then continue from the slot
		Game.reset_run()
		Game.level = 1; Game.gold = 0
		Game.set_meta("saves_phase", 2)
		main._continue_slot(0)
		return true
	if phase == 2:
		await wait(2.0)
		player = main.player
		var ex: Dictionary = Game.get_meta("saves_expect")
		check("continue_starts_playing", main.state == "play" and player.input_enabled, main.state)
		check("level_gold_restored", Game.level == ex.level and Game.gold == ex.gold, "level %d gold %d" % [Game.level, Game.gold])
		check("items_restored", Game.inventory.has(ex.item) and Game.inventory.size() == ex.inv and not Game.item(ex.item).is_empty(), "%d items" % Game.inventory.size())
		check("position_restored", player.global_position.distance_to(ex.pos) < 2.0, "%s vs %s" % [player.global_position, ex.pos])
		var back := false
		for en in get_tree().get_nodes_in_group("enemy"):
			if en is Enemy and (en as Enemy).uid == ex.uid:
				back = true
		check("killed_enemy_stays_dead", ex.uid != "" and not back and Game.flags.get(ex.uid, false), ex.uid)
		check("profile_restored", Game.profile.name == "Testa", Game.profile.name)
		await shot("sv2_after_continue")
		# save & exit to the title: Continue is offered and shows the slot
		Game.set_meta("saves_phase", 3)
		main._save_and_exit()
		return true
	await wait(2.0)
	check("title_offers_continue", main.state == "title" and main.menus._continue_btn.visible)
	main.menus._open_slots("continue")
	await wait(0.6)
	await shot("sv3_slots")
	check("slot_card_shows_hero", Game.slot_summary(0).get("name", "") == "Testa")
	check("next_new_game_uses_slot_2", Game.first_empty_slot() == 1)
	Game.remove_meta("saves_phase")
	return false

# --- block, parry, swing trails, camera views ---------------------------------
func combo_hold() -> void:
	pass

func _combat2_test() -> void:
	await _start()
	# open-air views at the outpost first
	for v in [[0.0, "first"], [4.2, "behind"], [9.5, "high"]]:
		player.zoom_target = v[0]; player.zoom = v[0]
		player.pitch = -0.2; player.snap_view()
		await wait(1.0)
		Input.action_press("attack")
		await wait(0.27)
		Input.action_release("attack")
		await shot("c_out_" + v[1])
		await wait(0.7)
	var at := Vector3(0, -5.9, -62)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await tp(at, 0.0)
	player.facing = 0.0; player.yaw = 0.0; player.snap_view()
	var e := _dummy(at + Vector3(0, -0.1, -2.2))
	await wait(0.3)
	e._awaken()
	await wait(1.5)
	# 1. holding block stops the revenant's blows
	Game.hp = Game.max_hp(); Game.stamina = Game.max_stamina()
	var hp0 := Game.hp
	var b0 := player.blocks + player.parries
	Input.action_press("block")
	var t := 0.0
	while t < 8.0 and player.blocks + player.parries - b0 < 3:
		face(e.global_position)
		Game.stamina = Game.max_stamina()
		await wait(0.1)
		t += 0.1
	await shot("c_blocking")
	Input.action_release("block")
	check("block_stops_damage", player.blocks + player.parries - b0 >= 3 and Game.hp >= hp0 - 0.5, "%d blocked, hp %.0f -> %.0f" % [player.blocks + player.parries - b0, hp0, Game.hp])
	# 2. raising the shield as the blow comes is a parry (and it cancels a swing)
	var p0 := player.parries
	t = 0.0
	var tries := 0
	while t < 20.0 and player.parries == p0:
		face(e.global_position)
		Game.hp = Game.max_hp()
		if e.state == Enemy.S.WINDUP and e.state_time >= e.t.windup - 0.2:
			Input.action_press("block")
			await wait(0.5)
			Input.action_release("block")
			tries += 1
		else:
			await wait(0.02)
		t += 0.05
	await shot("c_parry")
	check("parry_works", player.parries > p0, "%d tries" % tries)
	await wait(0.5)
	player.facing = 0.0; player.yaw = 0.0
	Input.action_press("attack"); await frames(2)
	await wait(0.1)
	Input.action_press("block"); await wait(0.15)
	check("block_cancels_swing", player.blocking and not player.attacking)
	Input.action_release("attack"); Input.action_release("block")
	e.queue_free()
	await wait(0.6)
	# 3. swing trails and the three camera views
	for v in [[0.0, "first"], [4.2, "behind"], [9.5, "high"]]:
		player.zoom_target = v[0]; player.zoom = v[0]
		player.facing = 0.0; player.yaw = 0.0; player.pitch = -0.2; player.snap_view()
		await wait(0.8)
		await tap("attack")
		await wait(0.28)
		await shot("c_view_" + v[1])
		await wait(0.6)
	check("view_cycle", true)
	player.zoom_target = 0.0; player.toggle_view()
	var n1 := player.view_name()
	player.toggle_view()
	var n2 := player.view_name()
	player.toggle_view()
	check("view_button_cycles", n1 == "BEHIND" and n2 == "HIGH" and player.view_name() == "1ST", "%s %s %s" % [n1, n2, player.view_name()])

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
	# double jump: one tap is a hop, a second tap in the air is a big jump
	await tp(at, 0.0)
	await wait(0.6)
	var y0 := player.global_position.y
	var top1 := y0
	await press("jump", 0.07)
	for i in 40:
		await frames(1)
		top1 = maxf(top1, player.global_position.y)
	await wait(0.8)
	var top2 := y0
	var dj0 := player.double_jumps
	await press("jump", 0.07)
	await wait(0.18)
	await press("jump", 0.07)
	await frames(1)
	await shot("s_double_jump")
	for i in 60:
		await frames(1)
		top2 = maxf(top2, player.global_position.y)
	check("double_jump_higher", player.double_jumps == dj0 + 1 and top2 - y0 > (top1 - y0) * 1.8, "single %.2f m, double %.2f m" % [top1 - y0, top2 - y0])

# --- character creator looks: close-ups of every hero with each option --------
func _looks_test() -> void:
	var m = main.menus
	m.show_panel("creator")
	await wait(0.5)
	await shot("k_creator_default")
	Game.profile.merge({"hero": "Rogue", "hair_style": "spiky", "hair_color": 4, "skin": 3, "face": "scar", "cape": 3}, true)
	for t in ["hero", "body", "hair", "face", "colours"]:
		m._set_tab(t)
		await wait(1.6)
		await shot("k_tab_" + t)
	m._set_tab("hero")
	m.current = "looks"   # stop the turntable
	var cam: Camera3D = m._preview_vp.find_children("*", "Camera3D", true, false)[0]
	var combos := [
		{"hair_style": "short", "face": "beard", "hair_color": 4, "skin": 5},
		{"hair_style": "long", "face": "blush", "hair_color": 3, "skin": 2},
		{"hair_style": "shoulder", "face": "eyepatch", "hair_color": 0, "skin": 4},
		{"hair_style": "buns", "face": "warpaint", "hair_color": 7, "skin": 1},
		{"hair_style": "spiky", "face": "scar", "hair_color": 6, "skin": 3},
		{"hair_style": "swept", "face": "mustache", "hair_color": 8, "skin": 6},
		{"hair_style": "bald", "face": "beard", "hair_color": 5, "skin": 7},
		{"hair_style": "wild", "face": "none", "hair_color": 1, "skin": 0},
		{"hair_style": "curly", "face": "none", "hair_color": 0, "skin": 0},   # old save name -> wild
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

# --- compass and quest arrow -------------------------------------------------
func _compass_test() -> bool:
	var phase: int = Game.get_meta("compass_phase", 1)
	if phase == 1:
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		Game.set_meta("compass_phase", 2)
		main.go_to_forest()
		return true
	await wait(2.5)
	player = main.player
	god = true
	var hud: HUD = main.hud
	var cp: QuestCompass = hud.compass
	check("compass_shown", cp != null and cp.visible and cp.is_inside_tree())
	await wait(0.6)
	check("no_arrow_without_quest", not cp._has_target)
	# compass turns with the camera
	player.yaw = 0.0; player.snap_view(); await wait(0.3)
	var h0 := cp.heading()
	player.yaw = PI * 0.5; player.snap_view(); await wait(0.3)
	var h1 := cp.heading()
	check("compass_turns", absf(wrapf(h1 - h0, -PI, PI)) > 1.2, "%.2f -> %.2f" % [h0, h1])
	player.yaw = 0.0; player.snap_view()
	await shot("cp_01_no_quest")
	Game.quest_accept("stolen_axes")
	await wait(0.8)
	check("new_quest_followed", Game.current_quest() == "stolen_axes")
	check("arrow_shown", cp._has_target)
	var axe := cp._first("quest_item", func(n: Node) -> bool: return n.get("item") == "axe" and (n as Node3D).visible)
	check("arrow_to_nearest_axe", axe != null and cp._target.distance_to(axe.global_position) < 0.5)
	await shot("cp_02_axes")
	Game.quest_accept("goblin_trouble")
	Game.quest_accept("strongbox")
	await wait(0.8)
	check("strongbox_points_to_warren_door", Game.current_quest() == "strongbox" and cp._below == -1)
	await shot("cp_03_strongbox")
	# choose a quest by tapping it in the list
	await wait(0.3)
	var row: Control = hud._quest_rows.get("goblin_trouble")
	var tapped := row != null and hud.tap_at(row.get_global_rect().get_center())
	await wait(0.6)
	check("tap_to_follow", tapped and Game.current_quest() == "goblin_trouble" and Game.tracked_manual)
	var gob := cp._first("enemy", func(n: Node) -> bool: return n.get("type_id") in Game.GOBLINS and not n.get("dead"))
	check("arrow_to_nearest_goblin", gob != null and cp._target.distance_to(gob.global_position) < 3.0)
	await shot("cp_04_goblins")
	Game.track_next()
	await wait(0.5)
	check("t_cycles", Game.current_quest() != "goblin_trouble")
	# walk toward the arrow: it says we get closer
	Game.track_quest("stolen_axes")
	await wait(0.6)
	var d0 := cp._dist
	var to: Vector3 = cp._target
	player.global_position = player.global_position.lerp(to, 0.6) + Vector3(0, 1.0, 0)
	await wait(1.0)
	check("distance_drops", cp._dist < d0 - 5.0, "%.0f -> %.0f" % [d0, cp._dist])
	# arrow points the right way: face the target, the arrow is at the top
	var dv := cp._target - player.global_position
	player.yaw = atan2(-dv.x, -dv.z); player.snap_view(); await wait(0.4)
	var rel := wrapf(QuestCompass.bearing(dv) - cp.heading(), -PI, PI)
	check("arrow_up_when_facing", absf(rel) < 0.35, "%.2f" % rel)
	await shot("cp_05_facing_axe")
	# hand-in: arrow goes to the quest giver; done quest -> auto pick another
	Game.quests["stolen_axes"].state = "ready"
	Game.quests_changed.emit()
	await wait(0.6)
	var bram := cp._first("npc", func(n: Node) -> bool: return n.get("id") == "bram")
	check("ready_points_to_giver", bram != null and cp._target.distance_to(bram.global_position) < 0.5)
	Game.quests["stolen_axes"].state = "done"
	Game.quests_changed.emit()
	await wait(0.8)
	check("auto_picks_next", Game.current_quest() in ["goblin_trouble", "strongbox"])
	Game.save_slot()
	check("tracked_saved", String(Game.read_slot(Game.active_slot).get("tracked_quest", "")) == Game.tracked_quest)
	return false

# --- day and night in the forest ----------------------------------------------
func _daynight_test() -> bool:
	var phase: int = Game.get_meta("dn_phase", 1)
	if phase == 1:
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		Game.set_meta("dn_phase", 2)
		main.go_to_forest()
		return true
	await wait(2.5)
	player = main.player
	god = true
	var w: ForestWorld = main.world
	check("daynight_exists", w.day_night != null)
	check("cycle_maths", DayNight.phase_name(30.0) == "sunrise" and DayNight.phase_name(200.0) == "day"
		and DayNight.phase_name(430.0) == "sunset" and DayNight.phase_name(600.0) == "night" and DayNight.phase_name(845.0) == "sunrise")
	check("seven_minute_blocks", is_equal_approx(DayNight.daylight(400.0), 1.0) and is_equal_approx(DayNight.daylight(420.0 + 90.0), 0.0)
		and DayNight.daylight(420.0 + 45.0) > 0.3 and DayNight.daylight(420.0 + 45.0) < 0.7)
	player.zoom_target = 6.0; player.zoom = 6.0; player.pitch = -0.05; player.yaw = 0.0; player.snap_view()
	var energies := {}
	for t in [[200.0, "day"], [420.0 + 50.0, "sunset"], [420.0 + 250.0, "night"], [840.0 + 40.0, "sunrise"]]:
		Game.day_clock = t[0]
		await wait(1.2)
		energies[t[1]] = w.sun.light_energy if w.sun.visible else 0.0
		await shot("dn_" + t[1])
	check("night_is_dark", energies.night < 0.05 and w.day_night.moon.light_energy > 0.2)
	check("day_is_bright", energies.day > 1.0)
	var c0 := Game.day_clock
	await wait(2.0)
	check("clock_runs", Game.day_clock > c0 + 1.0)
	Game.save_slot()
	check("clock_saved", absf(float(Game.read_slot(Game.active_slot).get("day_clock", -1.0)) - Game.day_clock) < 5.0)
	return false

# --- the Sinkhole of Death, Grimgor and the Giant Chicken ------------------------
func _sinkhole_test() -> bool:
	var phase: int = Game.get_meta("sk_phase", 1)
	if phase == 1:
		for i in Game.SAVE_SLOTS:
			Game.delete_slot(i)
		await _start()
		Game.set_meta("sk_phase", 2)
		main.go_to_forest()
		return true
	await wait(2.5)
	player = main.player
	god = true
	var w: ForestWorld = main.world
	var sk: SinkholeOfDeath = w.sinkhole
	check("sinkhole_built", sk != null and _npc("dunstan") != null)
	check("locked_at_first", Game.quest_state("sinkhole") == "locked")
	Game.quests["goblin_trouble"] = {"state": "done", "n": 10}
	Game.quests_changed.emit()
	check("unlocked_after_fenn", Game.quest_state("sinkhole") == "available")
	await _talk("dunstan")
	player.yaw = PI * 0.5; player.zoom_target = 5.0; player.zoom = 5.0; player.pitch = -0.35; player.snap_view()
	await shot("sk_01_dunstan_dialogue")
	main.menus._dlg_buttons.get_child(0).pressed.emit()
	await wait(0.2)
	main._resume()
	check("quest_accepted", Game.quest_state("sinkhole") == "active")
	await wait(1.0)
	await shot("sk_02_ground_shakes")
	var t := 0.0
	while player.global_position.y > SinkholeOfDeath.SY + 5.0 and t < 10.0:
		await wait(0.25); t += 0.25
	await wait(1.6)
	check("fell_into_sinkhole", player.global_position.y < SinkholeOfDeath.SY + 3.0 and Game.flags.get("sinkhole_open", false), str(player.global_position))
	check("red_caverns", w.area == "sinkhole")
	player.yaw = 0.0; player.pitch = -0.1; player.snap_view()
	await wait(1.0)
	await shot("sk_03_landing")
	# the compass now points the way to Grimgor (same level) - not the surface
	var cp: QuestCompass = main.hud.compass
	await wait(0.6)
	check("compass_points_to_grimgor", cp._has_target and cp._below == 0 and cp._target.distance_to(sk.cyclops.global_position) < 2.0)
	# the lava river cavern
	_kill_near(Enemy.TYPES.keys(), 26.0, Vector3(-32, SinkholeOfDeath.SY, -64))
	await tp(Vector3(-32, SinkholeOfDeath.SY + 0.3, -96), 0.0)
	player.zoom_target = 7.0; player.zoom = 7.0; player.pitch = -0.25; player.snap_view()
	await wait(1.5)
	await shot("sk_04_lava_river")
	var hp0 := Game.hp
	god = false
	await tp(Vector3(-46, SinkholeOfDeath.SY - 0.6, -110), 0.0)
	await wait(1.4)
	check("lava_burns", Game.hp < hp0, "%.0f -> %.0f" % [hp0, Game.hp])
	god = true
	Game.hp = Game.max_hp()
	_kill_near(Enemy.TYPES.keys(), 40.0, Vector3(-32, SinkholeOfDeath.SY, -110))
	await tp(Vector3(-32, SinkholeOfDeath.SY + 0.3, -146), 0.0)
	await wait(1.0)
	await shot("sk_05_ember_den")
	_kill_near(Enemy.TYPES.keys(), 30.0, Vector3(-32, SinkholeOfDeath.SY, -155))
	# Grimgor
	await tp(Vector3(-32, SinkholeOfDeath.SY + 0.3, -190), 0.0)
	player.yaw = 0.0; player.zoom_target = 7.0; player.zoom = 7.0; player.pitch = -0.08; player.snap_view()
	await wait(2.5)
	check("boss_awake", sk._boss_started)
	await shot("sk_06_grimgor")
	var cy: Enemy = sk.cyclops
	await tp(cy.global_position + Vector3(0, 0.3, 6.0), 0.0)
	player.yaw = 0.0; player.zoom_target = 5.0; player.zoom = 5.0; player.pitch = -0.15; player.snap_view()
	cy._nova_cd = 0.0
	await wait(0.6)
	await shot("sk_07_stomp_warning")
	await wait(1.0)
	cy.take_damage(cy.max_hp * 0.6, player.global_position)
	await wait(1.0)
	check("grimgor_summons", get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e.get("type_id") in ["fire_goblin", "fire_archer"] and not e.dead).size() >= 2)
	cy.take_damage(99999.0, player.global_position)
	await wait(3.0)
	check("grimgor_defeated", Game.quest_state("sinkhole") == "ready" and Game.flags.get("cyclops", false))
	check("chicken_waiting", sk._chicken != null and is_instance_valid(sk._chicken))
	await tp(sk._chicken.global_position + Vector3(0, 0.3, 2.0), PI)
	player.zoom_target = 4.5; player.zoom = 4.5; player.pitch = -0.2; player.yaw = 0.0; player.snap_view()
	await wait(1.0)
	await shot("sk_08_giant_chicken")
	var claim: Node = sk._chicken.get_child(sk._chicken.get_child_count() - 1)
	claim.interact(player)
	await wait(1.0)
	check("mount_unlocked", Game.flags.get("mount_chicken", false) and player.mounted)
	# riding is faster than running
	await tp(Vector3(-32, SinkholeOfDeath.SY + 0.3, -196), 0.0)
	player.yaw = PI; player.snap_view()
	await wait(0.4)
	var p0 := player.global_position
	await press("move_forward", 1.5)
	var ride_d := player.global_position.distance_to(p0)
	check("riding_is_fast", ride_d > 9.0, "%.1f m in 1.5 s" % ride_d)
	await shot("sk_09_riding")
	# dismount and mount with the key
	await press("mount", 0.07)
	await wait(0.3)
	check("g_dismounts", not player.mounted)
	await press("mount", 0.07)
	await wait(0.3)
	check("g_mounts", player.mounted)
	# up the ladder and hand the quest in
	var lad: Node = null
	for n in get_tree().get_nodes_in_group("sinkhole_exit"):
		lad = n
	check("exit_ladder", lad != null)
	lad.interact(player)
	await wait(1.6)
	check("back_on_surface", player.global_position.y > -20.0 and w.area == "forest", str(player.global_position))
	await tp(sk.pit_center() + Vector3(7, 0.5, 6), PI * 0.75)
	player.zoom_target = 6.0; player.zoom = 6.0; player.pitch = -0.3; player.snap_view()
	await wait(1.2)
	await shot("sk_10_riding_by_the_pit")
	player.dismount()
	await _talk("dunstan")
	main.menus._dlg_buttons.get_child(0).pressed.emit()
	await wait(0.3)
	main._resume()
	check("quest_done", Game.quest_state("sinkhole") == "done")
	Game.save_slot()
	check("mount_saved", bool(Game.read_slot(Game.active_slot).get("flags", {}).get("mount_chicken", false)))
	return false

# --- costumes, outfits and wild chests ---------------------------------------------
func _costumes_test() -> void:
	await _start()
	player = main.player
	god = true
	# a line-up of every costume, far above the world with its own camera and light
	var stage := Node3D.new(); main.add_child(stage); stage.position = Vector3(0, 400, 0)
	var ids: Array = Loot.COSTUMES.keys()
	var cols := 10
	for i in ids.size():
		var cm := CharacterModel.new(); stage.add_child(cm)
		cm.setup({"kind": "hero", "hero": "Knight", "show_hat": false, "costume": ids[i], "scale": 1.0, "weapon": "rusty_sword"})
		cm.position = Vector3((i % cols - (cols - 1) * 0.5) * 1.7, -(i / cols) * 2.9, 0)
		cm.rotation.y = PI + 0.35
		var lb := Label3D.new(); lb.text = ids[i]; lb.pixel_size = 0.0045; lb.font_size = 44; lb.outline_size = 8
		lb.position = cm.position + Vector3(0, -0.3, 0.6); stage.add_child(lb)
	var li := DirectionalLight3D.new(); stage.add_child(li); li.rotation_degrees = Vector3(-30, 20, 0); li.light_energy = 1.2
	var cam := Camera3D.new(); stage.add_child(cam)
	cam.position = Vector3(0, -3.6, 17.0); cam.fov = 55; cam.current = true
	cam.look_at(stage.global_position + Vector3(0, -3.7, 0))
	await wait(1.5)
	await shot("cos_00_lineup")
	check("all_costumes_build", stage.get_child_count() >= ids.size() * 2)
	stage.queue_free()
	player.camera.current = true
	# outfits: armour you can see
	var kinds := {}
	for base in Loot.OUTFITS:
		for rel in Loot.OUTFITS[base]:
			kinds[rel] = true
	var missing := []
	for rel in kinds:
		if not ResourceLoader.exists("res://assets/kaykit/%s.glb" % rel):
			missing.append(rel)
	check("outfit_files_exist", missing.is_empty(), str(missing))
	var aid := Loot.make_armor(4, 3)
	check("armor_has_outfit", Game.item(aid).has("outfit"), str(Game.item(aid)))
	Game.add_item(aid)
	Game.equip(aid)
	await wait(0.6)
	player.zoom_target = 3.2; player.zoom = 3.2; player.yaw = PI; player.pitch = -0.1; player.snap_view()
	await wait(0.6)
	var outfit_meshes := player.body._own_colors.size()
	check("outfit_worn", outfit_meshes >= 3, "%d outfit meshes (%s)" % [outfit_meshes, Game.item(aid).outfit])
	await shot("cos_01_outfit")
	# a costume from a chest: drop one, walk over it, transform
	Pickup.spawn(player.global_position + Vector3(0, 1.0, -2.0), "costume", 1, "dino")
	await wait(1.0)
	await shot("cos_02_costume_pickup")
	await tp(player.global_position + Vector3(0, 0.2, -2.0), PI)
	await wait(1.2)
	check("became_dino", Game.costume_id() == "dino" and player.body._never_show.size() > 0)
	player.yaw = PI; player.snap_view()
	await wait(0.6)
	await shot("cos_03_dino")
	# a new costume replaces the old one
	Game.wear_costume("dark_knight")
	await wait(0.8)
	check("new_costume_replaces", Game.costume_id() == "dark_knight")
	await shot("cos_04_dark_knight")
	# play-time costumes run out
	Game.costume = {"id": "vampire", "real": false, "until": Game.play_time + 1.0}
	Game.inventory_changed.emit()
	await wait(2.2)
	check("costume_expires", Game.costume_id() == "")
	# real-time ones survive a save
	Game.wear_costume("werewolf")
	Game.costume.real = true; Game.costume.until = Time.get_unix_time_from_system() + 86400.0
	Game.save_slot()
	check("costume_saved", String(Game.read_slot(Game.active_slot).get("costume", {}).get("id", "")) == "werewolf")
	# wild chests out by the outpost
	var wc: Array = main.world.find_children("*", "WildChests", true, false)
	var chests := 0
	for w in wc:
		for c in w.get_children():
			if c.has_meta("chest"):
				chests += 1
	check("wild_chests_spawned", chests >= 2, str(chests))
	if chests > 0:
		var c0: Node3D = wc[0].get_child(0)
		await tp(c0.global_position + Vector3(0, 0.5, 3.5), 0.0)
		player.zoom_target = 6.0; player.zoom = 6.0; player.pitch = -0.3; player.snap_view()
		await wait(1.0)
		await shot("cos_05_wild_chest_" + String(c0.get_meta("scene")))
	# lots of chests: costumes do drop
	var got := 0
	for k in 60:
		for d in Loot.roll_chest("wild", 4):
			if d.get("kind", "") == "costume":
				got += 1
	check("costumes_drop_from_chests", got >= 6, "%d in 60 wild chests" % got)
