extends Node3D
## Game root: builds the world, owns the player, HUD and menus, and runs flow
## (title -> creator -> play -> pause / death / victory).

static var quick_restart := false
static var continue_pending := false   # a save slot was loaded: rebuild the world from it
const AUTOSAVE_EVERY := 15.0
var _autosave_t := 0.0

var world: VaultWorld
var player: Player
var hud: HUD
var menus: Menus
var menu_cam: Camera3D
var touch: TouchControls
var state := "title"
var _orbit := 0.0
var _death_timer := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Only the player opts in to physics interpolation (see Player._ready);
	# everything else keeps its exact per-tick transforms.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not quick_restart and not continue_pending:
		Game.reset_run()
	if not continue_pending:
		Game.hp = Game.max_hp(); Game.mana = Game.max_mana(); Game.stamina = Game.max_stamina()
	world = VaultWorld.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build()
	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = world.spawn_point
	player.input_enabled = false
	world.player = player
	if not continue_pending:
		Game.checkpoint_pos = world.spawn_point
		Game.checkpoint_yaw = 0.0
		Game.checkpoint_name = "the Outpost"
	hud = HUD.new()
	add_child(hud)
	hud.bind_player(player)
	hud.visible = false
	menus = Menus.new()
	add_child(menus)
	menus.start_requested.connect(_start_game)
	menus.continue_requested.connect(_continue_slot)
	menus.exit_to_title_requested.connect(_save_and_exit)
	Game.leveled_up.connect(func(_l: int) -> void: autosave())
	menus.resume_requested.connect(_resume)
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
	player.respawn_at(world.spawn_point, 0.0)
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
	hud.visible = true
	Game.in_game = true
	Game.set_objective(Game.objective if Game.objective != "" else "Enter the Deep Vault beneath the cliffs.")
	Game.say("Welcome back, %s. Level %d." % [Game.profile.name, Game.level], UIKit.GOLD)
	menus.fade.color.a = 1.0
	menus.fade_to(0.0, 1.2)

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
		if menus.current in ["pause", "inventory", "lore"]:
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
