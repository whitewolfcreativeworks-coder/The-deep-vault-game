extends Node3D
## Game root: builds the world, owns the player, HUD and menus, and runs flow
## (title -> creator -> play -> pause / death / victory).

static var quick_restart := false
static var continue_pending := false   # a save slot was loaded: rebuild the world from it
const AUTOSAVE_EVERY := 15.0
var _autosave_t := 0.0

var world   # VaultWorld (Level 1) or ForestWorld (Level 2)
var player: Player
var hud: HUD
var menus: Menus
var menu_cam: Camera3D
var touch: TouchControls
var rainbow: RainbowVision
var state := "title"
var _orbit := 0.0
var _death_timer := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (the autotests always draw on High unless a test says otherwise)
	Graphics.testing = OS.get_cmdline_user_args().size() > 0 or OS.has_environment("DEEPVAULT_AUTOTEST") or _web_autotest() != ""
	# Only the player opts in to physics interpolation (see Player._ready);
	# everything else keeps its exact per-tick transforms.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not quick_restart and not continue_pending:
		Game.reset_run()
	if not continue_pending:
		Game.hp = Game.max_hp(); Game.mana = Game.max_mana(); Game.stamina = Game.max_stamina()
	match Game.zone:
		"forest": world = ForestWorld.new()
		"castle": world = CastleWorld.new()
		"cloud": world = CloudWorld.new()
		"home": world = HomeWorld.new()
		_: world = VaultWorld.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build()
	_zone_extras()
	Food.stock_world(world)      # food on the tables (and some barrels and crates) to eat
	# once the physics world knows the walls: put any floating wall torch on a wall
	var w: Node3D = world
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_instance_valid(w) and w.is_inside_tree():
			Props.snap_torches(w)
			# INSANE (and the Medium and Low graphics settings): draw identical scenery
			# props together and skip tiny far-off details (far fewer draw calls).
			# Normal and Hard on High look exactly as always.
			if (Game.mode == "insane" or Graphics.lean()) and not OS.has_environment("DEEPVAULT_NOBATCH"):
				batch_stats = StaticBatcher.batch(w)
				batch_stats["far_culled"] = StaticBatcher.cull_small(w)
			Graphics.apply(w))
	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = world.spawn_point
	player.input_enabled = false
	world.player = player
	if world.has_method("keep_in"):
		player.keep_in = world.keep_in          # (the edge of the level)
	if not continue_pending or Game.checkpoint_pos == Vector3.ZERO:
		Game.checkpoint_pos = world.spawn_point
		Game.checkpoint_yaw = float(world.get("spawn_yaw")) if world.get("spawn_yaw") != null else 0.0
		Game.checkpoint_name = {"forest": "the Portal Glade", "castle": "the Moor Portal", "cloud": "the Sky Temple", "home": "the sky"}.get(Game.zone, "the Outpost")
	hud = HUD.new()
	add_child(hud)
	hud.bind_player(player)
	rainbow = RainbowVision.new()
	add_child(rainbow)
	rainbow.player = player
	# INSANE mode: wild things happen every half a minute or so
	if Game.mode == "insane" and Game.zone != "home":
		chaos = InsaneChaos.new()
		chaos.player = player
		chaos.world = world
		chaos.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(chaos)
	hud.visible = false
	menus = Menus.new()
	add_child(menus)
	menus.start_requested.connect(_play_intro)
	menus.continue_requested.connect(_continue_slot)
	menus.forest_requested.connect(go_to_forest)
	Game.quests_changed.connect(_check_forest_done)
	menus.exit_to_title_requested.connect(_save_and_exit)
	Game.leveled_up.connect(func(_l: int) -> void: autosave())
	menus.resume_requested.connect(_resume)
	menus.desk_closed.connect(_on_desk_closed)
	menus.respawn_requested.connect(_respawn)
	menus.restart_requested.connect(_restart)
	menus.quit_requested.connect(func() -> void: get_tree().quit())
	Game.player_died.connect(func() -> void: _death_timer = 2.2)
	touch = TouchControls.new()
	add_child(touch)
	touch.bind(player, self)
	player.focus_lost.connect(func() -> void:
		if state == "play" and menus.current == "":
			_open("pause"))
	menu_cam = Camera3D.new()
	menu_cam.fov = 60
	add_child(menu_cam)
	menu_cam.current = true
	Sfx.music("music_explore", -16.0)
	menus.fade_to(0.0, 1.6)
	if quick_restart:
		quick_restart = false
		_start_game()
	elif continue_pending:
		continue_pending = false
		_continue_game()
	else:
		menus.show_panel("title")
	if OS.get_cmdline_user_args().size() > 0 or OS.has_environment("DEEPVAULT_AUTOTEST") or _web_autotest() != "":
		var at := preload("res://scripts/tests/autotest.gd").new()
		add_child(at)

## Browser builds can run the test harness via the URL: index.html?autotest=shots
static func _web_autotest() -> String:
	if not OS.has_feature("web"):
		return ""
	var q = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) == TYPE_STRING and String(q).contains("autotest="):
		return String(q).get_slice("autotest=", 1).get_slice("&", 0)
	return ""

func _start_game() -> void:
	if Game.active_slot < 0:
		Game.active_slot = maxi(Game.first_empty_slot(), 0)
	Game.resume_pos = Vector3.ZERO
	menus.close_all()
	state = "play"
	player.rebuild_body()
	player.respawn_at(world.spawn_point, float(world.get("spawn_yaw")) if world.get("spawn_yaw") != null else 0.0)
	player.invuln = 0.0
	player.camera.current = true
	player.input_enabled = true
	player.set_mouse_captured(true)
	hud.visible = true
	Game.in_game = true
	Game.set_objective("Enter the Deep Vault beneath the cliffs.")
	Game.say("Welcome, %s. The Vault waits below." % Game.profile.name, UIKit.GOLD)
	menus.fade.color.a = 1.0
	menus.fade_to(0.0, 1.2)
	autosave()

# --- save slots ---------------------------------------------------------------
## Menu picked a saved character: load it, then rebuild the world from its state.
func _continue_slot(i: int) -> void:
	if not Game.load_slot(i):
		return
	get_tree().paused = false
	continue_pending = true
	get_tree().reload_current_scene()

func _continue_game() -> void:
	menus.close_all()
	state = "play"
	player.rebuild_body()
	var at: Vector3 = Game.resume_pos if Game.resume_pos != Vector3.ZERO else Game.checkpoint_pos
	var yaw: float = Game.resume_yaw if Game.resume_pos != Vector3.ZERO else Game.checkpoint_yaw
	var hp_saved := Game.hp
	player.respawn_at(at + Vector3(0, 0.1, 0), yaw)
	Game.hp = maxf(hp_saved, Game.max_hp() * 0.5)
	player.invuln = 2.0
	player.camera.current = true
	player.input_enabled = true
	player.set_mouse_captured(true)
	Game.in_game = true
	await _get_ready()
	hud.visible = true
	if Game.zone in ["forest", "castle", "cloud", "home"]:
		Game.objective = Game.forest_objective()
	Game.set_objective(Game.objective if Game.objective != "" else "Enter the Deep Vault beneath the cliffs.")
	if Game.has_meta("arrive_say"):
		Game.say(String(Game.get_meta("arrive_say")), UIKit.GOLD)
		Game.remove_meta("arrive_say")
	elif Game.zone == "cloud" and Game.resume_pos == Vector3.ZERO:
		Game.say("Up, up, up through the clouds... Welcome to Cloud Island!", Color(0.85, 0.95, 1.0))
		if not Game.flags.get("special2_told", false):
			Game.flags["special2_told"] = true
			var a2: Dictionary = Game.ability2()
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				Game.say("The sky gives you a NEW POWER! %s: press %s to use it." % [a2.name, "B / 3" if not Game.touch_active else "the new button"], Color(0.6, 1.0, 0.9)))
	elif Game.zone == "home" and Game.resume_pos == Vector3.ZERO:
		Game.say("Through the Sky Gate... it's a long way home! Follow the golden rings.", Color(1.0, 0.9, 0.6))
	elif Game.zone == "castle" and Game.resume_pos == Vector3.ZERO:
		Game.say("You step out under a cold moon. Somewhere a ghost wails... Welcome to Ghost Knight Castle!", Color(0.7, 0.85, 1.0))
	elif Game.zone == "forest" and Game.play_time > 0.0 and Game.resume_pos == Vector3.ZERO:
		Game.say("You step out of the portal into the Goblin Forest.", UIKit.GOLD)
	else:
		Game.say("Welcome back, %s. Level %d." % [Game.profile.name, Game.level], UIKit.GOLD)
	menus.fade.color.a = 1.0
	menus.fade_to(0.0, 1.2)

# --- getting ready -------------------------------------------------------------
## Jason, Nov 20: on a slower iPad a new level stutters for its first few seconds,
## then plays better "once everything's loaded in". So arriving somewhere (through
## a portal, Port Home, a level from the family portal, Continue) now waits behind
## the dark screen for a moment, with the place's name up:
##   - a camera turns once all the way round where you'll appear, so everything
##     around you is drawn once (the graphics are ready before you see them);
##   - the effects of a fight (sparks, bursts, damage numbers, slashes) and the
##     common sounds are made once, out of sight, so the first fight doesn't hitch;
##   - then it waits until the frame rate has settled.
## The world is paused meanwhile (nothing can attack you). At least 2 s; a slow
## device waits longer (up to 5 s), a fast one no longer than it needs.
const READY_MIN := 2.0
const READY_MAX := 5.0
var ready_hold_secs := 0.0         # (for the tests: how long the last one took,
var ready_held_paused := false     #  whether the world was paused, and what it said)
var ready_title := ""
const WARM_SOUNDS := ["hit", "swing", "clang", "hurt", "bone_break", "pickup", "coins", "levelup", "spell", "spell_hit",
	"fire_burst", "skel_attack", "roar", "slam", "footstep", "death", "chest", "door", "portal", "thunder", "rumble", "whistle"]

func _hold_wanted() -> bool:
	if Game.has_meta("test_hold"):
		return true
	# (the automated tests time things from the moment a level starts)
	return not (OS.get_cmdline_user_args().size() > 0 or OS.has_environment("DEEPVAULT_AUTOTEST") or _web_autotest() != "")

func _get_ready() -> void:
	if not _hold_wanted() or player == null:
		return
	var prev_state := state
	state = "arriving"
	get_tree().paused = true
	menus.fade_to(1.0, 0.01)
	menus.fade.color.a = 1.0
	var title: String = Game.ZONE_NAMES.get(Game.zone, "Home" if Game.zone == "home" else "")
	if Game.zone == "home":
		title = "Home"
	if Game.mode != "normal":
		title += "  ·  " + Game.mode_name().to_upper()
	menus.show_getting_ready(title, "Getting ready")
	ready_title = title
	ready_held_paused = get_tree().paused
	var cam := Camera3D.new()
	cam.fov = player.camera.fov; cam.near = player.camera.near; cam.far = player.camera.far
	add_child(cam)
	cam.current = true
	var eye := player.global_position + Vector3(0, 1.9, 0)
	cam.global_position = eye
	for nm in WARM_SOUNDS:
		Sfx.get_stream(nm)
	# a little fight's worth of effects, just in front of the turning camera
	var fx_at := eye + Vector3(-sin(player.yaw), -0.6, -cos(player.yaw)) * 3.0
	FX.hit(fx_at); FX.sparks(fx_at); FX.burst(fx_at, Color(1.0, 0.6, 0.3), 20)
	FX.damage_number(fx_at, 12.0, Color(1, 1, 1), false)
	FX.damage_number(fx_at, 30.0, Color(1, 1, 1), true)
	FX.swipe(fx_at, player.yaw, 0.9, 2.5, Color(0.9, 0.92, 1.0))
	FX.shockwave(fx_at, Color(0.8, 0.9, 1.0), 2.0, 0.3)
	FX.flash_light(fx_at, Color(1.0, 0.8, 0.5), 3.0, 4.0, 0.2)
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var steady := 0
	while true:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		var el := float(Time.get_ticks_msec() - t0) / 1000.0
		var spin := clampf(el / 1.5, 0.0, 1.0)
		if is_instance_valid(cam):
			cam.global_position = eye
			cam.rotation = Vector3(-0.2, player.yaw + spin * TAU, 0.0)
		steady = steady + 1 if dt < 0.05 else 0
		menus.show_getting_ready(title, "Getting ready" + ".".repeat(1 + int(el * 3.0) % 3))
		if (el >= READY_MIN and spin >= 1.0 and steady >= 12) or el >= READY_MAX:
			ready_hold_secs = el
			break
	cam.queue_free()
	player.camera.current = true
	player.snap_view()
	menus.show_getting_ready("")
	Graphics.arrived()
	state = prev_state if prev_state != "arriving" else "play"
	get_tree().paused = false

# --- the opening movie --------------------------------------------------------
var intro: IntroMovie

func _play_intro() -> void:
	menus.close_all()
	state = "intro"
	hud.visible = false
	Sfx.music("", -16.0)
	# the movie has its own sky and valley: take the Vault out while it plays
	remove_child(world)
	remove_child(player)
	intro = IntroMovie.new()
	add_child(intro)
	intro.build()
	intro.finished.connect(_end_intro, CONNECT_ONE_SHOT)
	intro.play()

func _end_intro() -> void:
	if intro == null:
		return
	intro.queue_free()
	intro = null
	add_child(world)
	add_child(player)
	Sfx.music("music_explore", -16.0)
	_start_game()
	# beamed in: a column of light at the arrival portal
	var at: Vector3 = world.spawn_point
	FX.screen_flash(Color(0.85, 1.0, 0.95), 0.9, 1.4)
	FX.pillar(at, Color(0.55, 1.0, 0.85), 1.2, 12.0, 1.6)
	FX.burst(at + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.9), 70, 3.0, 0.22, 1.2, 0.5)
	Sfx.play("portal", -4.0, 0.0)
	Game.say("Whoosh! You step out of the old portal... the Deep Vault awaits!", UIKit.GOLD)

## Level 1 -> Level 2: through the portal that opens when the Vault is won.
func go_to_forest() -> void:
	Game.zone = "forest"
	Game.flags["victory"] = true
	Game.checkpoint_pos = Vector3.ZERO
	Game.resume_pos = Vector3.ZERO
	Game.objective = ""
	Game.game_over = false
	Game.in_game = true
	if Game.active_slot < 0:
		Game.active_slot = maxi(Game.first_empty_slot(), 0)
	Game.save_slot()
	get_tree().paused = false
	continue_pending = true
	get_tree().reload_current_scene()

## Level 2 -> Level 3: through the Moonlit Portal once every forest quest is done.
## Every class learns its second special power on arrival.
func go_to_castle() -> void:
	Game.zone = "castle"
	Game.checkpoint_pos = Vector3.ZERO
	Game.resume_pos = Vector3.ZERO
	Game.objective = ""
	Game.game_over = false
	Game.in_game = true
	if Game.active_slot < 0:
		Game.active_slot = maxi(Game.first_empty_slot(), 0)
	Game.save_slot()
	get_tree().paused = false
	continue_pending = true
	get_tree().reload_current_scene()

## Level 3 -> Level 4: a cloud forms around you and lifts you into the sky.
## Energy potions in random spots, and chickens and turkeys out in the open air.
func _zone_extras() -> void:
	var areas: Array = []
	var n_pot := 4
	match Game.zone:
		"forest", "castle":
			n_pot = 6 if Game.zone == "forest" else 5
			var k := 0
			for n in get_tree().get_nodes_in_group("npc"):
				var np := (n as Node3D).global_position
				if np.y < -20.0 or k >= 5:
					continue
				areas.append([np + Vector3(7.0, 0, 5.0), 6.0, 2 if k % 2 == 0 else 1])
				k += 1
		"cloud":
			n_pot = 4
		"home":
			n_pot = 0
		_:
			areas = [[Vector3(-3.0, 0, 31.0), 6.0, 2], [Vector3(-26.0, 0, 36.0), 5.0, 2]]
	ZoneExtras.attach(world, n_pot, areas)

func go_to_cloud() -> void:
	if state != "play" or player.dead:
		return
	player.input_enabled = false
	if player.mounted:
		player.dismount()
	var puff := CPUParticles3D.new(); puff.amount = 80; puff.lifetime = 2.0
	var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2; puff.mesh = sm
	puff.material_override = FX.glow_material(Color(1, 1, 1), 0.6)
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; puff.emission_ring_radius = 2.0; puff.emission_ring_inner_radius = 1.2
	puff.emission_ring_height = 0.6; puff.emission_ring_axis = Vector3.UP
	puff.direction = Vector3.UP; puff.spread = 30; puff.initial_velocity_min = 0.5; puff.initial_velocity_max = 1.5
	puff.gravity = Vector3.ZERO; puff.scale_amount_min = 0.8; puff.scale_amount_max = 2.0
	player.add_child(puff)
	Sfx.play("portal", -4.0, 0.0)
	Game.say("A cloud swirls around you and lifts you up into the sky!", Color(0.85, 0.95, 1.0))
	player.lift = 6.0
	player.zoom_target = 7.0
	await get_tree().create_timer(3.2).timeout
	FX.screen_flash(Color(1, 1, 1), 1.0, 1.4)
	await menus.fade_to(1.0, 0.6).finished
	player.lift = -999.0
	_travel("cloud")

## The last quest: through the Sky Gate on your dragonfly, on the long flight home.
func go_to_home() -> void:
	if state != "play" or player.dead:
		return
	player.input_enabled = false
	Sfx.play("portal", -2.0, 0.0)
	Game.say("Through the Sky Gate! Hold on tight...", Color(1.0, 0.9, 0.6))
	FX.screen_flash(Color(1.0, 0.95, 0.8), 1.0, 1.2)
	await menus.fade_to(1.0, 0.8).finished
	_travel("home")

## Home again: the family portal in the yard leads back to the Vault outpost.
func go_to_vault() -> void:
	if state != "play":
		return
	player.input_enabled = false
	await menus.fade_to(1.0, 0.8).finished
	_travel("vault")

## Back down from Cloud Island on a rain cloud.
func go_back_to_castle() -> void:
	if state != "play":
		return
	player.input_enabled = false
	Sfx.play("splash", -6.0, 0.0)
	await menus.fade_to(1.0, 0.8).finished
	_travel("castle")

func _travel(z: String, arrive := Vector3.ZERO, arrive_yaw := 0.0) -> void:
	Game.zone = z
	if z == "cloud":
		Game.flags["special2"] = true      # every hero learns a second power in the sky
	Game.checkpoint_pos = Vector3.ZERO
	Game.resume_pos = arrive               # (zero: the level's own starting spot)
	Game.resume_yaw = arrive_yaw
	Game.objective = ""
	Game.game_over = false
	Game.in_game = true
	if Game.active_slot < 0:
		Game.active_slot = maxi(Game.first_empty_slot(), 0)
	Game.save_slot()
	get_tree().paused = false
	continue_pending = true
	get_tree().reload_current_scene()

## Doors and ladders: fade out, move the player, fade back in.
func teleport_player(dest: Vector3, yaw: float, label: String) -> void:
	player.input_enabled = false
	await menus.fade_to(1.0, 0.35).finished
	player.global_position = dest
	player.velocity = Vector3.ZERO
	player.yaw = yaw; player.facing = yaw
	player.reset_physics_interpolation()
	player.snap_view()
	Game.resume_pos = dest
	player.input_enabled = true
	menus.fade_to(0.0, 0.5)
	Game.say(label, UIKit.GOLD)
	autosave()

func open_dialogue(npc: NPC) -> void:
	menus.show_dialogue(npc)
	get_tree().paused = true
	player.set_mouse_captured(false)

func _check_forest_done() -> void:
	var won := ""
	if Game.zone == "forest" and Game.zone_complete("forest") and not Game.flags.get("forest_won", false):
		won = "forest"
	elif Game.zone == "castle" and Game.quest_state("ghost_lord") == "done" and not Game.flags.get("castle_won", false):
		won = "castle"
	elif Game.zone == "cloud" and Game.quest_state("mr_bubbles") == "done" and not Game.flags.get("cloud_won", false):
		won = "cloud"
	elif Game.zone == "home" and Game.quest_state("flight_home") == "done" and not Game.flags.get("home_won", false):
		won = "home"
	if won != "":
		Game.flags[won + "_won"] = true
		if won == "home":
			Game.flags["adventure_done"] = true      # the family portal now offers a new adventure
		Game.set_objective(Game.forest_objective())
		autosave()
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if menus.current == "":
				menus.show_forest_victory(won)
				get_tree().paused = true
				player.set_mouse_captured(false))

func autosave() -> void:
	if state == "play" and Game.active_slot >= 0 and not player.dead:
		Game.save_slot()
		_autosave_t = 0.0

func _save_and_exit() -> void:
	autosave()
	Game.in_game = false
	Game.active_slot = -1
	get_tree().paused = false
	get_tree().reload_current_scene()

func _notification(what: int) -> void:
	# closing the app, switching away from it, or the browser tab hiding: save now
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if state == "play" and player:
			autosave()

## Remember the last safe spot to continue from, and autosave now and then.
func _track_save(delta: float) -> void:
	if state != "play" or player == null or get_tree().paused:
		return
	if player.is_on_floor() and not player.in_river and not player.dead and not player.mantling:
		Game.resume_pos = player.global_position
		Game.resume_yaw = player.facing
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_EVERY:
		autosave()

func _process(delta: float) -> void:
	_track_save(delta)
	# Auto graphics: keep an eye on how smoothly it runs while you play
	if state == "play" and menus.current == "" and not get_tree().paused and is_instance_valid(world):
		if Graphics.watch(world) == "down":
			Game.say("Graphics set to %s so the game runs smoothly on this device (change it in the pause menu)." % Graphics.NAMES[Graphics.level()], Color(0.75, 0.8, 0.9))
	else:
		Graphics.idle()
	if state == "title" or menus.current == "creator":
		_orbit += delta * 0.05
		var c := Vector3(0, 2.0, 12.0)
		menu_cam.global_position = c + Vector3(sin(_orbit) * 16.0, 3.0 + sin(_orbit * 0.7) * 1.0, cos(_orbit) * 16.0 + 6.0)
		menu_cam.look_at(Vector3(0, 3.5, -1.0))
	if _death_timer > 0.0:
		_death_timer -= delta
		if _death_timer <= 0.0:
			state = "dead"
			player.set_mouse_captured(false)
			menus.show_death()

func _unhandled_input(event: InputEvent) -> void:
	if state == "title":
		return
	if event.is_action_pressed("pause"):
		if menus.current == "designer":
			menus.designer.close(false)      # Esc steps back out of the Skin Designer
		elif menus.current in ["ask", "modes", "levels"] and _ask_cancel.is_valid():
			_ask_cancel.call()
		elif menus.current in ["pause", "inventory", "lore", "stash", "ask", "shop", "forge", "journal"]:
			_resume()
		elif menus.current == "" and state == "play":
			_open("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") or event.is_action_pressed("character"):
		if menus.current == "inventory":
			_resume()
		elif menus.current == "" and state == "play":
			_open("inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("port_home"):
		ask_port_home()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and menus.current == "lore":
		_resume()
		get_viewport().set_input_as_handled()

func _open(panel: String) -> void:
	if panel == "pause":
		autosave()
	menus.show_panel(panel)
	get_tree().paused = true
	player.set_mouse_captured(false)

func _resume() -> void:
	menus.close_all()
	get_tree().paused = false
	if state == "play":
		player.set_mouse_captured(true)

func _respawn() -> void:
	menus.close_all()
	world.reset_boss()
	state = "play"
	menus.fade.color.a = 1.0
	player.respawn_at(Game.checkpoint_pos, Game.checkpoint_yaw)
	player.set_mouse_captured(true)
	menus.fade_to(0.0, 1.0)
	Game.say("You rise again at %s." % Game.checkpoint_name, Color(0.6, 0.85, 1.0))

func _restart() -> void:
	get_tree().paused = false
	Game.reset_run()
	quick_restart = true
	get_tree().reload_current_scene()

# --- hooks called by world objects ------------------------------------------
func on_enemy_hit(e: Node) -> void:
	hud.set_target(e)

func show_boss_bar(w: Warden) -> void:
	hud.show_boss(w)

func hide_boss_bar() -> void:
	hud.hide_boss()

# --- Port Home ----------------------------------------------------------------------
var _ask_cancel: Callable      # what Esc does on a question
var chaos: InsaneChaos
var batch_stats := {}
## The HOME button (or Y): once unlocked, back to your cabin from anywhere. The
## family portal in the yard can then take you back to where you were.
func ask_port_home() -> void:
	if state != "play" or player == null or player.dead or menus.current != "" or not Game.can_port_home() or not player.input_enabled:
		return
	if Game.zone == "home" and world is HomeWorld and (world as HomeWorld).cabin and (world as HomeWorld).cabin.is_inside(player.global_position):
		Game.say("You're already home!", Color(1.0, 0.9, 0.6))
		return
	var here: String = Game.PLACE_NAMES.get(Game.zone, "here")
	var back := "" if Game.zone == "home" else "\n\nThe family portal in the yard can bring you right back to %s." % here
	_ask_cancel = _resume
	menus.ask("Port home?", "Whoosh back to your cabin?" + back, [["Port home!", _port_home], ["Stay here", _resume]])
	get_tree().paused = true
	player.set_mouse_captured(false)

func _port_home() -> void:
	menus.close_all()
	get_tree().paused = false
	player.set_mouse_captured(true)
	if player.mounted:
		player.dismount()
	Sfx.play("portal", -2.0, 0.0)
	FX.burst(player.global_position + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.85), 80, 6.0, 0.2, 1.0, 2.0)
	FX.screen_flash(Color(0.75, 1.0, 0.9), 0.9, 1.0)
	if Game.zone == "home":
		teleport_player(HomeCabin.arrival(), 0.0, "Whoosh! Home sweet home.")
		return
	player.input_enabled = false
	Game.flags["port_from"] = {"zone": Game.zone, "pos": Game.resume_pos, "yaw": Game.resume_yaw}
	await menus.fade_to(1.0, 0.8).finished
	Game.set_meta("arrive_say", "Whoosh! Home sweet home.")
	_travel("home", HomeCabin.arrival(), 0.0)

## Walking into the family portal after porting home. Before the first adventure is
## done: back to where you were, the Vault outpost, or stay home. After it: back
## where you left off, choose any level (in Normal, Hard or Insane), a whole new
## adventure, or stay home.
func family_portal_choice(stay: Callable) -> void:
	var pf: Dictionary = Game.flags.get("port_from", {})
	var there: String = Game.PLACE_NAMES.get(String(pf.get("zone", "")), "where you were")
	var done := bool(Game.flags.get("adventure_done", false)) or bool(Game.flags.get("home_won", false))
	_ask_cancel = func() -> void:
		_resume()
		stay.call()
	var opts: Array = []
	if not pf.is_empty():
		opts.append(["Back where I left off" if done else "Back to " + there, func() -> void:
			menus.close_all(); get_tree().paused = false
			_port_back()])
	if done:
		opts.append(["Choose a level", func() -> void:
			_ask_level(stay)])
		opts.append(["A new adventure!", func() -> void:
			_ask_mode(stay)])
	else:
		opts.append(["The Vault outpost", func() -> void:
			Game.flags.erase("port_from")
			menus.close_all(); get_tree().paused = false
			player.set_mouse_captured(true)
			FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
			Sfx.play("portal", 0.0, 0.0)
			go_to_vault()])
	opts.append(["Stay home", func() -> void:
		_resume()
		stay.call()])
	var text := "Where would you like to go?"
	if done:
		text = "Where would you like to go?\n\n"
		if not pf.is_empty():
			text += "Back where I left off: the exact spot you ported home from, in %s.\n" % there
		text += "Choose a level: play any one level again, fresh, in Normal, Hard or INSANE.\nA new adventure: the whole thing again from the very beginning."
	menus.ask("The family portal", text, opts)
	get_tree().paused = true
	player.set_mouse_captured(false)

## Pick Normal, Hard or Insane, with or without your gear.
func _ask_mode(stay: Callable) -> void:
	_ask_cancel = func() -> void:
		_resume()
		stay.call()
	menus.choose_mode(func(m: String, geared: bool) -> void: start_new_adventure(m, geared), _ask_cancel)

## Pick a level, then Normal, Hard or Insane (the Sky Ride just flies).
func _ask_level(stay: Callable) -> void:
	_ask_cancel = func() -> void:
		_resume()
		stay.call()
	menus.choose_level(func(z: String) -> void:
		if z == "skyride":
			start_sky_ride()
			return
		var place := String(Game.PLACE_NAMES.get(z, z))
		var title := place.substr(0, 1).to_upper() + place.substr(1)
		menus.choose_mode(func(m: String, geared: bool) -> void: start_level(z, m, geared), func() -> void: _ask_level(stay),
			title + "!", "Play %s again, fresh: its monsters, bosses, chests and quests all come back. You keep your level and gold. With your gear, you keep everything you carry. Starting fresh, you begin with the old rusty sword, and your gear waits in the gear chest at home." % place),
		_ask_cancel)

## One level again, fresh, in the chosen mode.
func start_level(z: String, m: String, geared: bool) -> void:
	menus.close_all()
	get_tree().paused = false
	player.input_enabled = false
	Sfx.play("portal", 0.0, 0.0)
	FX.screen_flash(Color(1.0, 0.95, 0.85), 1.0, 1.2)
	await menus.fade_to(1.0, 0.9).finished
	Game.replay_level(z, m, geared)
	var nm := String(Game.PLACE_NAMES.get(z, z))
	nm = nm.substr(0, 1).to_upper() + nm.substr(1)
	Game.set_meta("arrive_say", "%s: %s mode%s! Good luck, %s." % [nm.to_upper(), Game.mode_name(), "" if geared else " (your gear waits in the chest at home)", Game.profile.name])
	_travel(z)

## The Sky Ride again: up into the sky on the dragonfly, through the rings home.
func start_sky_ride() -> void:
	menus.close_all()
	get_tree().paused = false
	player.input_enabled = false
	Game.flags.erase("port_from")
	Game.flags["ride_again"] = true
	Game.flags.erase("home_chest")      # a perfect flight earns the gift again
	Sfx.play("portal", 0.0, 0.0)
	FX.screen_flash(Color(1.0, 0.95, 0.8), 1.0, 1.2)
	await menus.fade_to(1.0, 0.9).finished
	Game.set_meta("arrive_say", "THE SKY RIDE! Follow the rings home. Go for the RAINBOW medal!")
	_travel("home")

## A whole new adventure from the Vault outpost (you keep your level and gold).
func start_new_adventure(m: String, geared: bool) -> void:
	menus.close_all()
	get_tree().paused = false
	player.input_enabled = false
	Sfx.play("portal", 0.0, 0.0)
	FX.screen_flash(Color(1.0, 0.95, 0.85), 1.0, 1.2)
	await menus.fade_to(1.0, 0.9).finished
	Game.new_adventure(m, geared)
	Game.set_meta("arrive_say", "A NEW ADVENTURE: %s mode%s! Good luck, %s." % [Game.mode_name(), "" if geared else " (your gear waits in the chest at home)", Game.profile.name])
	_travel("vault")

func _port_back() -> void:
	var pf: Dictionary = Game.flags.get("port_from", {})
	Game.flags.erase("port_from")
	player.set_mouse_captured(true)
	player.input_enabled = false
	Sfx.play("portal", 0.0, 0.0)
	FX.screen_flash(Color(0.85, 1.0, 0.95), 1.0, 1.2)
	await menus.fade_to(1.0, 0.8).finished
	var z := String(pf.get("zone", "vault"))
	Game.set_meta("arrive_say", "Whoosh! Back to %s." % Game.PLACE_NAMES.get(z, "where you were"))
	_travel(z, pf.get("pos", Vector3.ZERO), float(pf.get("yaw", 0.0)))

## The desk in the cabin at home: change your name and looks.
func open_desk() -> void:
	if state != "play" or menus.current != "":
		return
	menus.open_desk()
	get_tree().paused = true
	player.set_mouse_captured(false)

func _on_desk_closed(changed: bool) -> void:
	if changed:
		player.rebuild_body()
		Game.say("Looking good, %s!" % Game.profile.name, Color(1.0, 0.9, 0.6))
		autosave()
	_resume()

## The gear chest in the cabin at home.
func open_stash() -> void:
	if state != "play" or menus.current != "":
		return
	_open("stash")

## Tobble's Trading Post: a display (or Tobble himself) opens the shop at that tab.
func open_shop(tab: String) -> void:
	if state != "play" or menus.current != "":
		return
	_open("shop")
	menus.shop_ui.open_shop(tab)

## The anvil (or, journal = true, the Forge Journal).
func open_forge(journal := false) -> void:
	if state != "play" or menus.current != "":
		return
	if journal:
		_open("journal")
		menus.shop_ui.refresh_journal()
	else:
		_open("forge")
		menus.shop_ui.open_forge()

## FORGE! The panel steps aside so you can watch the smith hammer it out, then
## comes back to show what you made.
func forge_strike(uid: String) -> void:
	_resume()
	var grand := ForgeRecipes.is_grand(uid)
	var f = world.get("forge") if world else null
	if f is HomeForge:
		(f as HomeForge).strike(grand)
	player.input_enabled = false
	get_tree().create_timer(2.1).timeout.connect(func() -> void:
		if not is_instance_valid(player):
			return
		player.input_enabled = true
		var it := Game.item(uid)
		Game.say("You forged: %s!" % String(it.get("name", "?")), it.get("color", Color.WHITE))
		autosave()
		if state == "play" and menus.current == "":
			_open("forge")
			var who: String = String(Game.NPC_NAMES.smith).split(" ")[0]
			menus.shop_ui.open_forge(("%s: \"Now THAT is something special. I haven't made one of those in years!\"" % who) if grand
				else ("%s: \"There. Never a dud from my anvil! Bring me three more and we'll see what else we can make.\"" % who)))

func show_lore(t: String, body: String) -> void:
	menus.show_lore(t, body)
	get_tree().paused = true
	player.set_mouse_captured(false)

func on_victory() -> void:
	Game.flags["victory"] = true
	autosave()
	state = "victory"
	player.input_enabled = false
	player.set_mouse_captured(false)
	player.body.play_role("cheer")
	menus.show_victory()
