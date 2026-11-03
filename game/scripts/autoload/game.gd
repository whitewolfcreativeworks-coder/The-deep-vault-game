extends Node
## Global game state: input map, character profile, RPG stats, inventory,
## equipment, checkpoints and flow signals. Everything gameplay-relevant that
## must survive a death/respawn lives here.

signal stats_changed
signal inventory_changed
signal leveled_up(new_level: int)
signal message(text: String, color: Color)
signal objective_changed(text: String)
signal player_died
signal victory

# --- Character profile (set by the character creator) ----------------------
var profile := {
	"name": "Aldric",
	"hero": "Knight",       # key of CharacterModel.HEROES
	"cape": 0,              # index into CAPE_COLORS
	"show_hat": true,
}
const HERO_ORDER := ["Knight", "Rogue", "Barbarian", "Ranger", "Mage"]
const HERO_BLURB := {
	"Knight": "A sworn blade of the old roads. (Male)",
	"Rogue": "Quick hands, sharper eyes. (Female)",
	"Barbarian": "Northland strength, few words. (Male)",
	"Ranger": "A hooded tracker of deep places. (Female)",
	"Mage": "A hedge-wizard who learned the sword. (Male)",
}
const CAPE_COLORS := [
	Color(1, 1, 1), Color(0.75, 0.15, 0.12), Color(0.2, 0.45, 0.85), Color(0.25, 0.6, 0.3),
	Color(0.55, 0.3, 0.75), Color(0.2, 0.2, 0.22), Color(0.95, 0.75, 0.3),
]
const CAPE_NAMES := ["Original", "Crimson", "Azure", "Verdant", "Violet", "Shadow", "Gold"]

const SKIN_TONES := [
	Color(0.96, 0.80, 0.69), Color(0.87, 0.67, 0.53), Color(0.72, 0.52, 0.38),
	Color(0.55, 0.38, 0.26), Color(0.38, 0.26, 0.18),
]
const HAIR_STYLES := ["Short", "Long", "Ponytail", "Shaved"]
const HAIR_COLORS := [
	Color(0.18, 0.12, 0.08), Color(0.45, 0.28, 0.14), Color(0.78, 0.62, 0.35),
	Color(0.55, 0.16, 0.08), Color(0.08, 0.08, 0.09), Color(0.70, 0.70, 0.72),
]
const OUTFITS := [
	{"name": "Wayfarer", "tunic": Color(0.30, 0.22, 0.14), "pants": Color(0.20, 0.17, 0.14), "trim": Color(0.62, 0.50, 0.30)},
	{"name": "Crimson Guard", "tunic": Color(0.45, 0.08, 0.08), "pants": Color(0.16, 0.13, 0.12), "trim": Color(0.80, 0.66, 0.30)},
	{"name": "Forest Ranger", "tunic": Color(0.16, 0.28, 0.15), "pants": Color(0.22, 0.18, 0.12), "trim": Color(0.55, 0.45, 0.25)},
	{"name": "Midnight Scholar", "tunic": Color(0.13, 0.15, 0.32), "pants": Color(0.12, 0.12, 0.16), "trim": Color(0.70, 0.72, 0.85)},
]

# --- Items ------------------------------------------------------------------
const ITEMS := {
	"rusty_sword": {"name": "Rusted Shortsword", "slot": "weapon", "damage": 0, "desc": "Pitted, but it still holds an edge.", "color": Color(0.55, 0.45, 0.38)},
	"knight_sword": {"name": "Knight's Longsword", "slot": "weapon", "damage": 9, "desc": "Balanced steel bearing a forgotten order's crest.", "color": Color(0.82, 0.84, 0.88)},
	"vault_blade": {"name": "Runeblade of Ashkar", "slot": "weapon", "damage": 18, "desc": "Blue runes crawl along the fuller. It hums near the river.", "color": Color(0.45, 0.85, 1.0)},
	"traveler_garb": {"name": "Traveler's Garb", "slot": "armor", "defense": 2, "desc": "Wool and leather. Better than nothing.", "color": Color(0.45, 0.35, 0.25)},
	"chainmail": {"name": "Vault Guard Hauberk", "slot": "armor", "defense": 10, "desc": "Riveted rings, cold and heavy.", "color": Color(0.60, 0.62, 0.66)},
	"warden_plate": {"name": "Wardenforged Plate", "slot": "armor", "defense": 20, "desc": "Plate cut from the Warden's own stone-steel.", "color": Color(0.35, 0.55, 0.65)},
	"amulet_deep": {"name": "Amulet of the Deep", "slot": "artifact", "desc": "While worn, the Vault's river mends rather than burns. +30 max mana.", "color": Color(0.3, 0.9, 1.0)},
	"heart_vault": {"name": "Heart of the Vault", "slot": "quest", "desc": "The sealed heart of Ashkar. Warm, and beating.", "color": Color(1.0, 0.75, 0.35)},
}

# --- Stats ------------------------------------------------------------------
var level := 1
var xp := 0
var gold := 0
var potions := 2
var hp := 100.0
var mana := 60.0
var stamina := 100.0
var inventory: Array[String] = ["rusty_sword", "traveler_garb"]
var equipped := {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": ""}
var kills := 0
var play_time := 0.0
var flags := {}  # world state that survives respawn: "chest_x_opened", "enemy_x_dead", "gate_x_open"...

var checkpoint_pos := Vector3.ZERO
var checkpoint_yaw := 0.0
var checkpoint_name := "the outpost"
var objective := ""
var in_game := false
var mouse_sens := 0.0024
var game_over := false

const BASE_HP := 100.0
const BASE_DAMAGE := 12.0
const BASE_MANA := 60.0

func _init() -> void:
	_register_inputs()

func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_time += delta

# ---------------------------------------------------------------------------
func max_hp() -> float:
	return BASE_HP + (level - 1) * 18.0

func max_mana() -> float:
	return BASE_MANA + (level - 1) * 8.0 + (30.0 if equipped.artifact == "amulet_deep" else 0.0)

func max_stamina() -> float:
	return 100.0 + (level - 1) * 5.0

func attack_damage() -> float:
	var w: Dictionary = ITEMS.get(equipped.weapon, {})
	return BASE_DAMAGE + (level - 1) * 3.5 + float(w.get("damage", 0))

func spell_damage() -> float:
	return 22.0 + (level - 1) * 6.0

func defense() -> float:
	var a: Dictionary = ITEMS.get(equipped.armor, {})
	return float(a.get("defense", 0)) + (level - 1) * 1.0

func xp_to_next() -> int:
	return int(round(80.0 * pow(level, 1.45)))

func mitigate(raw: float) -> float:
	var d := defense()
	return raw * (1.0 - d / (d + 45.0))

# ---------------------------------------------------------------------------
func reset_run() -> void:
	level = 1; xp = 0; gold = 0; potions = 2; kills = 0; play_time = 0.0
	inventory = ["rusty_sword", "traveler_garb"]
	equipped = {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": ""}
	flags = {}
	hp = max_hp(); mana = max_mana(); stamina = max_stamina()
	game_over = false
	stats_changed.emit(); inventory_changed.emit()

func add_xp(amount: int) -> void:
	xp += amount
	message.emit("+%d XP" % amount, Color(0.75, 0.6, 1.0))
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		hp = max_hp(); mana = max_mana(); stamina = max_stamina()
		leveled_up.emit(level)
		message.emit("LEVEL %d!  Health, damage and mana increased." % level, Color(1.0, 0.85, 0.3))
	stats_changed.emit()

func add_gold(amount: int) -> void:
	gold += amount
	message.emit("+%d gold" % amount, Color(1.0, 0.82, 0.3))
	stats_changed.emit()

func add_item(id: String, auto_equip := true) -> void:
	if not inventory.has(id):
		inventory.append(id)
	var it: Dictionary = ITEMS[id]
	message.emit("Found: %s" % it.name, it.color)
	if auto_equip and it.slot in ["weapon", "armor", "artifact"]:
		var cur: String = equipped[it.slot]
		if cur == "" or _item_score(id) > _item_score(cur):
			equip(id)
	inventory_changed.emit()

func _item_score(id: String) -> float:
	var it: Dictionary = ITEMS.get(id, {})
	return float(it.get("damage", 0)) + float(it.get("defense", 0)) + (1.0 if it.slot == "artifact" else 0.0)

func equip(id: String) -> void:
	var it: Dictionary = ITEMS[id]
	if not it.slot in ["weapon", "armor", "artifact"]:
		return
	equipped[it.slot] = id
	mana = minf(mana, max_mana())
	message.emit("Equipped %s" % it.name, it.color)
	inventory_changed.emit(); stats_changed.emit()

func unequip_artifact() -> void:
	equipped.artifact = ""
	mana = minf(mana, max_mana())
	inventory_changed.emit(); stats_changed.emit()

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)

func set_checkpoint(pos: Vector3, yaw: float, label: String) -> void:
	if checkpoint_name == label:
		return
	checkpoint_pos = pos; checkpoint_yaw = yaw; checkpoint_name = label
	message.emit("Checkpoint: %s" % label, Color(0.6, 0.9, 1.0))

func say(text: String, color := Color(0.92, 0.88, 0.80)) -> void:
	message.emit(text, color)

# ---------------------------------------------------------------------------
func _register_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "dodge": [KEY_C, KEY_ALT],
		"interact": [KEY_E], "inventory": [KEY_I], "character": [KEY_TAB],
		"pause": [KEY_ESCAPE], "spell": [KEY_Q], "potion": [KEY_R, KEY_1],
		"zoom_in_key": [KEY_EQUAL, KEY_KP_ADD], "zoom_out_key": [KEY_MINUS, KEY_KP_SUBTRACT],
		"toggle_view": [KEY_V],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "block": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)
	# Gamepad (basic): left stick move, A jump, X attack, LB block, RB spell, Y interact.
	var pad_buttons := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "interact": JOY_BUTTON_Y,
		"block": JOY_BUTTON_LEFT_SHOULDER, "spell": JOY_BUTTON_RIGHT_SHOULDER,
		"dodge": JOY_BUTTON_B, "pause": JOY_BUTTON_START, "inventory": JOY_BUTTON_BACK,
		"potion": JOY_BUTTON_DPAD_UP}
	for action in pad_buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad_buttons[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]; jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)
		InputMap.action_set_deadzone(action, 0.2)
