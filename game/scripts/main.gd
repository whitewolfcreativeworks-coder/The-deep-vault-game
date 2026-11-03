extends Node3D
## Game root: builds the world, owns the player, HUD and menus, and runs flow
## (title -> creator -> play -> pause / death / victory).

static var quick_restart := false

var world: VaultWorld
var player: Player
var hud: HUD
var menus: Menus
var menu_cam: Camera3D
var state := "title"
var _orbit := 0.0
var _death_timer := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not quick_restart:
		Game.reset_run()
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
	menus.resume_requested.connect(_resume)
	menus.respawn_requested.connect(_respawn)
	menus.restart_requested.connect(_restart)
	menus.quit_requested.connect(func() -> void: get_tree().quit())
	Game.player_died.connect(func() -> void: _death_timer = 2.2)
	menu_cam = Camera3D.new()
	menu_cam.fov = 60
	add_child(menu_cam)
	menu_cam.current = true
	Sfx.music("music_explore", -16.0)
	menus.fade_to(0.0, 1.6)
	if quick_restart:
		quick_restart = false
		_start_game()
	else:
		menus.show_panel("title")
	if OS.get_cmdline_user_args().size() > 0 or OS.has_environment("DEEPVAULT_AUTOTEST"):
		var at := preload("res://scripts/tests/autotest.gd").new()
		add_child(at)

func _start_game() -> void:
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

func _process(delta: float) -> void:
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
	state = "victory"
	player.input_enabled = false
	player.set_mouse_captured(false)
	player.body.play_role("cheer")
	menus.show_victory()
