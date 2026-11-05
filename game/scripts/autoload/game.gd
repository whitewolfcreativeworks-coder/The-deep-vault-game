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
	"name": "Bobek",
	"hero": "Knight",       # key of CharacterModel.HEROES
	"cape": 0,              # index into CAPE_COLORS
	"show_hat": true,
	"skin": 0,              # index into SKIN_COLORS (0 = the hero's own)
	"hair_style": "natural",
	"hair_color": 0,        # index into HAIR_COLORS2 (0 = the hero's own)
	"face": "none",
	"build": 1.0,           # 0.82 skinny .. 1.3 big
	"height": 1.0,          # 0.86 short .. 1.14 tall
}
const SKIN_COLORS := [Color(0.97, 0.8, 0.67), Color(1.0, 0.86, 0.76), Color(0.93, 0.72, 0.55), Color(0.82, 0.6, 0.42),
	Color(0.66, 0.45, 0.3), Color(0.47, 0.31, 0.21), Color(0.33, 0.21, 0.15), Color(0.55, 0.8, 0.5), Color(0.6, 0.7, 0.95)]
const SKIN_NAMES := ["Hero's own", "Pale", "Fair", "Tan", "Olive", "Brown", "Deep", "Goblin green", "Frost blue"]
## "short".."bald" are modelled heads (KayKit Adventurers 2.0); buns and spiky are built on top
## of the hero's own hair. Old saves: curly -> wild, ponytail -> shoulder, mohawk -> spiky.
const HAIR_STYLES2 := ["natural", "short", "long", "swept", "shoulder", "wild", "bald", "buns", "spiky"]
const HAIR_STYLE_NAMES := {"natural": "Natural", "short": "Short", "long": "Long", "swept": "Swept + goatee",
	"shoulder": "Shoulder-length", "wild": "Wild + beard", "bald": "Bald + beard", "buns": "Buns", "spiky": "Spiky"}
const HAIR_COLORS2 := [Color(0.5, 0.3, 0.2), Color(0.12, 0.08, 0.06), Color(0.32, 0.19, 0.1), Color(0.55, 0.3, 0.14), Color(0.85, 0.66, 0.35),
	Color(0.78, 0.33, 0.12), Color(0.9, 0.9, 0.92), Color(0.25, 0.45, 0.95), Color(0.95, 0.4, 0.7), Color(0.3, 0.75, 0.35)]
const HAIR_COLOR_NAMES := ["Hero's own", "Black", "Dark brown", "Chestnut", "Blonde", "Ginger", "White", "Blue", "Pink", "Green"]
const FACES := ["none", "beard", "mustache", "eyepatch", "scar", "warpaint", "blush"]
const FACE_NAMES := {"none": "Plain", "beard": "Beard", "mustache": "Mustache", "eyepatch": "Eyepatch",
	"scar": "Scar", "warpaint": "War paint", "blush": "Rosy cheeks"}
const HERO_ORDER := ["Knight", "Rogue", "Barbarian", "Ranger", "Mage"]
const HERO_BLURB := {
	"Knight": "A sworn blade of the old roads.",
	"Rogue": "Quick hands, sharper eyes. Bobek's favourite.",
	"Barbarian": "Northland strength, few words.",
	"Ranger": "A hooded tracker of deep places.",
	"Mage": "A hedge-wizard who learned the sword.",
}
## Each hero's special ability (X key, or the big purple button on a touchscreen).
const ABILITIES := {
	"Rogue": {"name": "Backstab", "short": "STAB", "cd": 6.0, "color": Color(0.75, 0.35, 1.0),
		"desc": "Vanish in a puff of shadow, reappear behind the nearest enemy and strike for a massive 5x critical."},
	"Mage": {"name": "Shadow Step", "short": "BLINK", "cd": 5.0, "color": Color(0.55, 0.3, 1.0),
		"desc": "Blink 13 m across the room. Shadow implodes where you leave (and lingers, burning enemies) and explodes where you land."},
	"Knight": {"name": "Shield Charge", "short": "CHARGE", "cd": 7.0, "color": Color(0.5, 0.75, 1.0),
		"desc": "Rush forward inside a barrier of light, smashing through enemies, and finish with a stunning shield slam."},
	"Barbarian": {"name": "Whirlwind", "short": "SPIN", "cd": 8.0, "color": Color(1.0, 0.55, 0.25),
		"desc": "Become a burning whirlwind: four spinning hits on everything around you, the last one hurling them away."},
	"Ranger": {"name": "Volley", "short": "VOLLEY", "cd": 7.0, "color": Color(0.55, 1.0, 0.45),
		"desc": "Two waves of nine glowing arrows that burst on impact."},
}
func ability() -> Dictionary:
	return ABILITIES.get(profile.hero, ABILITIES.Knight)

## Second special abilities: every hero gets one on arriving at Ghost Knight Castle.
const ABILITIES2 := {
	"Knight": {"name": "Holy Ward", "short": "WARD", "cd": 16.0, "color": Color(1.0, 0.9, 0.45),
		"desc": "A golden shield of light: you take far less damage for a few seconds, heal, and push foes back."},
	"Barbarian": {"name": "Earthshatter", "short": "SLAM", "cd": 12.0, "color": Color(0.9, 0.6, 0.3),
		"desc": "Leap and smash the ground: a huge shockwave stuns everything around you."},
	"Rogue": {"name": "Smoke Bomb", "short": "SMOKE", "cd": 14.0, "color": Color(0.5, 0.9, 0.5),
		"desc": "Vanish in poison smoke: enemies lose you and choke, and you dash away faster."},
	"Ranger": {"name": "Rain of Arrows", "short": "RAIN", "cd": 13.0, "color": Color(0.7, 1.0, 0.6),
		"desc": "A storm of arrows falls on the ground ahead of you."},
	"Mage": {"name": "Frost Nova", "short": "FROST", "cd": 12.0, "color": Color(0.6, 0.9, 1.0),
		"desc": "A blast of ice freezes every enemy around you solid."},
}

func ability2() -> Dictionary:
	return ABILITIES2.get(profile.hero, ABILITIES2.Knight)

func has_special2() -> bool:
	return bool(flags.get("special2", false))

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
## Hand-made unique items. Random loot (scripts/autoload/loot.gd) is generated at
## runtime; every item, unique or random, lives in `items` under its id.
const ITEMS := {
	"rusty_sword": {"name": "Rusted Shortsword", "slot": "weapon", "rarity": 0, "model": "skel_blade", "damage": 0.0, "desc": "Pitted, but it still holds an edge."},
	"vault_blade": {"name": "Runeblade of Ashkar", "slot": "weapon", "rarity": 4, "model": "vault_blade", "damage": 22.0, "spell": 30.0, "crit": 8.0, "desc": "Blue runes crawl along the fuller. It hums near the river."},
	"traveler_garb": {"name": "Traveler's Garb", "slot": "armor", "rarity": 0, "shield": "shield_round", "defense": 2.0, "desc": "Wool and leather. Better than nothing."},
	"amulet_deep": {"name": "Amulet of the Deep", "slot": "artifact", "rarity": 3, "mana": 30.0, "regen": 1.0, "special": "river", "desc": "While worn, the Vault's river mends rather than burns."},
	"heart_vault": {"name": "Heart of the Vault", "slot": "quest", "rarity": 4, "desc": "The sealed heart of Ashkar. Warm, and beating."},
}
const SLOTS := ["weapon", "armor", "artifact", "skin"]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "artifact": "Trinket", "skin": "Skin", "quest": "Quest"}
const BAG_SIZE := 24
var items := {}

func item(uid: String) -> Dictionary:
	if uid == "":
		return {}
	return items.get(uid, {})

func _reset_items() -> void:
	items.clear()
	for k in ITEMS:
		var it: Dictionary = ITEMS[k].duplicate(true)
		it["uid"] = k
		it["color"] = Loot.rarity_color(it.rarity)
		items[k] = it

# --- Stats ------------------------------------------------------------------
var level := 1
var xp := 0
var gold := 0
var potions := 3          # healing draughts
var mana_potions := 2
var hp := 100.0
var mana := 60.0
var stamina := 100.0
var inventory: Array[String] = ["rusty_sword", "traveler_garb"]
var equipped := {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": "", "skin": ""}
var kills := 0
var play_time := 0.0
var flags := {}  # world state that survives respawn: "chest_x_opened", "enemy_x_dead", "gate_x_open"...

var checkpoint_pos := Vector3.ZERO
var checkpoint_yaw := 0.0
var checkpoint_name := "the outpost"
var objective := ""
var in_game := false
var mouse_sens := 0.0024
var strafe_mode := true      # character faces the camera direction; move any way (sidestep/backpedal)
var touch_active := false
var last_touch_ms := -100000     # set by the touch overlay once the screen is touched
var free_cursor := false      # pointer lock unavailable (e.g. some browsers): drag to look
var game_over := false

const BASE_HP := 100.0
const BASE_DAMAGE := 12.0
const BASE_MANA := 60.0

func _init() -> void:
	_register_inputs()
	_reset_items()

func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_time += delta
		if not costume.is_empty() and costume_left() <= 0.0:
			var nm: String = Loot.COSTUMES.get(costume.get("id", ""), {}).get("name", "costume")
			clear_costume()
			message.emit("POOF! Your %s magic wears off." % nm, Color(1.0, 0.85, 0.5))

# ---------------------------------------------------------------------------
# Costumes (see Loot.COSTUMES): {"id", "until", "real"}. "real" costumes count
# down in real time (they can last for days), the others only while you play.
var costume := {}

func costume_id() -> String:
	return String(costume.get("id", "")) if not costume.is_empty() else ""

func costume_left() -> float:
	if costume.is_empty():
		return 0.0
	if costume.get("real", false):
		return float(costume.until) - Time.get_unix_time_from_system()
	return float(costume.until) - play_time

func costume_time_text() -> String:
	var s := maxf(costume_left(), 0.0)
	if s >= 86400.0:
		return "%dd %dh" % [int(s / 86400.0), int(fmod(s, 86400.0) / 3600.0)]
	if s >= 3600.0:
		return "%dh %dm" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0)]
	return "%d:%02d" % [int(s / 60.0), int(fmod(s, 60.0))]

## Put on a costume straight away (a new one always replaces the old one).
func wear_costume(id: String) -> void:
	if not Loot.COSTUMES.has(id):
		return
	var t: Array = Loot.roll_costume_time()
	var real: bool = t[2]
	costume = {"id": id, "real": real, "until": (Time.get_unix_time_from_system() if real else play_time) + float(t[1])}
	var c: Dictionary = Loot.COSTUMES[id]
	message.emit("%s  (lasts %s)" % [c.line, t[3]], Color(1.0, 0.75, 1.0))
	inventory_changed.emit()

func clear_costume() -> void:
	costume = {}
	inventory_changed.emit()

# ---------------------------------------------------------------------------
## True on the WebGL / OpenGL "Compatibility" renderer (browser builds, old GPUs).
static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

## Sum of one bonus across everything you wear.
func gear(key: String) -> float:
	var t := 0.0
	for slot in SLOTS:
		t += float(item(equipped.get(slot, "")).get(key, 0.0))
	return t

func max_hp() -> float:
	return BASE_HP + (level - 1) * 18.0 + gear("hp")

func max_mana() -> float:
	return BASE_MANA + (level - 1) * 8.0 + gear("mana")

func mana_regen() -> float:
	return 6.0 + gear("regen")

func max_stamina() -> float:
	return 100.0 + (level - 1) * 5.0

func attack_damage() -> float:
	return BASE_DAMAGE + (level - 1) * 3.5 + gear("damage")

func spell_damage() -> float:
	return (24.0 + (level - 1) * 6.5) * (1.0 + gear("spell") / 100.0)

func spell_power() -> float:
	return gear("spell")

func crit_chance() -> float:
	return 0.10 + gear("crit") / 100.0

func lifesteal() -> float:
	return gear("lifesteal") / 100.0

func defense() -> float:
	return gear("defense") + (level - 1) * 1.0

func has_special(tag: String) -> bool:
	for slot in SLOTS:
		if item(equipped.get(slot, "")).get("special", "") == tag:
			return true
	return false

func xp_to_next() -> int:
	return int(round(80.0 * pow(level, 1.45)))

func mitigate(raw: float) -> float:
	var d := defense()
	return raw * (1.0 - d / (d + 45.0))

# ---------------------------------------------------------------------------
func reset_run() -> void:
	level = 1; xp = 0; gold = 0; potions = 3; mana_potions = 2; kills = 0; play_time = 0.0
	_reset_items()
	inventory = ["rusty_sword", "traveler_garb"]
	equipped = {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": "", "skin": ""}
	flags = {}
	quests = {}
	tracked_quest = ""
	tracked_manual = false
	day_clock = 150.0
	costume = {}
	zone = "vault"
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

signal loot_found(uid: String)

func add_item(id: String, auto_equip := true) -> void:
	var it := item(id)
	if it.is_empty():
		return
	if not inventory.has(id):
		inventory.append(id)
	var r: int = it.get("rarity", 0)
	var tag := "" if r == 0 else "[%s] " % Loot.RARITY_NAMES[r].to_upper()
	message.emit("Found: %s%s" % [tag, it.name], it.color)
	loot_found.emit(id)
	if auto_equip and it.slot in SLOTS:
		var cur: String = equipped[it.slot]
		var better := cur == "" or score(id) > score(cur)
		if it.slot == "artifact" and item(cur).get("special", "") == "river" and it.get("special", "") != "river":
			better = false   # never swap away the river amulet automatically
		if it.get("special", "") == "river":
			better = true
		if it.slot == "skin" and not it.has("outfit"):
			better = cur == ""   # your first magic skin goes on straight away; later ones wait in the bag
		elif it.slot == "skin":
			# armour skins swap in whenever they're an upgrade (unless you wear a magic skin)
			better = cur == "" or (item(cur).has("outfit") and score(id) > score(cur))
		if better:
			equip(id)
		elif it.slot != "quest":
			message.emit("  (in your bag: press I to compare)", Color(0.7, 0.7, 0.7))
	_trim_bag()
	inventory_changed.emit()

## Rough worth of an item for automatic upgrades and comparisons.
func score(uid: String) -> float:
	var it := item(uid)
	return float(it.get("damage", 0)) + float(it.get("defense", 0)) * 1.1 + float(it.get("hp", 0)) * 0.15 \
		+ float(it.get("mana", 0)) * 0.12 + float(it.get("regen", 0)) * 1.5 + float(it.get("crit", 0)) * 0.9 \
		+ float(it.get("lifesteal", 0)) * 1.4 + float(it.get("spell", 0)) * 0.18 + float(it.get("rarity", 0)) * 0.5

func equip(id: String) -> void:
	var it := item(id)
	if it.is_empty() or not it.slot in SLOTS:
		return
	equipped[it.slot] = id
	hp = minf(hp, max_hp())
	mana = minf(mana, max_mana())
	message.emit("Equipped %s" % it.name, it.color)
	inventory_changed.emit(); stats_changed.emit()

func unequip(slot: String) -> void:
	if slot in ["artifact", "skin"]:
		equipped[slot] = ""
		hp = minf(hp, max_hp()); mana = minf(mana, max_mana())
		inventory_changed.emit(); stats_changed.emit()

func unequip_artifact() -> void:
	unequip("artifact")

func salvage(id: String) -> void:
	var it := item(id)
	if it.is_empty() or equipped.values().has(id) or it.slot == "quest" or ITEMS.has(id):
		return
	inventory.erase(id)
	var g := Loot.salvage_value(it)
	gold += g
	message.emit("Salvaged %s for %d gold" % [it.name, g], Color(1.0, 0.82, 0.3))
	inventory_changed.emit(); stats_changed.emit()

## Keep the bag tidy: when full, the least valuable unequipped item becomes gold.
func _trim_bag() -> void:
	while inventory.size() > BAG_SIZE:
		var worst := ""
		var ws := INF
		for id in inventory:
			if equipped.values().has(id) or ITEMS.has(id):
				continue
			var sc := score(id)
			if sc < ws:
				ws = sc; worst = id
		if worst == "":
			return
		salvage(worst)

func item_lines(uid: String) -> PackedStringArray:
	var it := item(uid)
	var out := PackedStringArray()
	if it.has("damage") and float(it.damage) > 0: out.append("+%d attack" % int(it.damage))
	if it.has("defense") and float(it.defense) > 0: out.append("+%d defense" % int(it.defense))
	for k in ["hp", "mana", "regen", "crit", "lifesteal", "spell"]:
		if float(it.get(k, 0)) > 0:
			var a: Array = Loot.AFFIXES[k]
			out.append(("+%.1f%% %s" if a[3] else "+%.0f %s") % [float(it[k]), a[0]] if k != "regen" else "+%.1f %s" % [float(it[k]), a[0]])
	if it.get("special", "") == "river":
		out.append("river heals you")
	return out

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)

func set_checkpoint(pos: Vector3, yaw: float, label: String) -> void:
	if checkpoint_name == label:
		return
	checkpoint_pos = pos; checkpoint_yaw = yaw; checkpoint_name = label
	message.emit("Checkpoint: %s  (game saved)" % label if active_slot >= 0 else "Checkpoint: %s" % label, Color(0.6, 0.9, 1.0))
	resume_pos = pos; resume_yaw = yaw
	save_slot()

func say(text: String, color := Color(0.92, 0.88, 0.80)) -> void:
	message.emit(text, color)

# ---------------------------------------------------------------------------
func _register_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"look_left": [KEY_LEFT], "look_right": [KEY_RIGHT], "look_up": [KEY_UP], "look_down": [KEY_DOWN],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "dodge": [KEY_C, KEY_ALT],
		"interact": [KEY_E], "inventory": [KEY_I], "character": [KEY_TAB],
		"pause": [KEY_ESCAPE], "spell": [KEY_Q], "potion": [KEY_R, KEY_1], "mana_potion": [KEY_F, KEY_2],
		"zoom_in_key": [KEY_EQUAL, KEY_KP_ADD], "zoom_out_key": [KEY_MINUS, KEY_KP_SUBTRACT],
		"toggle_view": [KEY_V], "special": [KEY_X], "track_quest": [KEY_T], "mount": [KEY_G], "pose": [KEY_P], "auto_run": [KEY_Z, KEY_NUMLOCK], "special2": [KEY_B, KEY_3],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Mouse buttons are routed by the player script (so touch-emulated clicks
	# can be ignored), which presses these actions itself.
	for action in ["attack", "block"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	# Gamepad (basic): left stick move, A jump, X attack, LB block, RB spell, Y interact.
	var pad_buttons := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "interact": JOY_BUTTON_Y,
		"block": JOY_BUTTON_LEFT_SHOULDER, "spell": JOY_BUTTON_RIGHT_SHOULDER,
		"dodge": JOY_BUTTON_B, "pause": JOY_BUTTON_START, "inventory": JOY_BUTTON_BACK,
		"potion": JOY_BUTTON_DPAD_UP, "mana_potion": JOY_BUTTON_DPAD_DOWN, "special": JOY_BUTTON_RIGHT_STICK, "special2": JOY_BUTTON_LEFT_STICK}
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

# ---------------------------------------------------------------------------
# Save slots: three characters, each saved where you left off.
# Stored as Godot text variants in user:// (IndexedDB in the browser/iPad app).
const SAVE_SLOTS := 3
const SAVE_VERSION := 1
var active_slot := -1                    # the slot this run saves into (-1 = none yet)
var resume_pos := Vector3.ZERO    # last safe spot (on the ground, not in the river)
var resume_yaw := 0.0
var saves_written := 0

func _slot_path(i: int) -> String:
	return "user://save_%d.sav" % i

func has_save(i: int) -> bool:
	return FileAccess.file_exists(_slot_path(i))

func any_save() -> bool:
	for i in SAVE_SLOTS:
		if has_save(i):
			return true
	return false

func first_empty_slot() -> int:
	for i in SAVE_SLOTS:
		if not has_save(i):
			return i
	return -1

func save_slot(i := -1) -> bool:
	if i < 0:
		i = active_slot
	if i < 0 or not in_game:
		return false
	var d := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"profile": profile.duplicate(true),
		"level": level, "xp": xp, "gold": gold,
		"potions": potions, "mana_potions": mana_potions,
		"hp": hp, "mana": mana,
		"items": items.duplicate(true),
		"inventory": Array(inventory),
		"equipped": equipped.duplicate(),
		"kills": kills, "play_time": play_time,
		"flags": flags.duplicate(true),
		"checkpoint_pos": checkpoint_pos, "checkpoint_yaw": checkpoint_yaw, "checkpoint_name": checkpoint_name,
		"objective": objective,
		"resume_pos": resume_pos, "resume_yaw": resume_yaw,
		"zone": zone, "quests": quests.duplicate(true), "tracked_quest": tracked_quest, "tracked_manual": tracked_manual, "day_clock": day_clock, "costume": costume.duplicate(),
	}
	var f := FileAccess.open(_slot_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(var_to_str(d))
	f.close()
	saves_written += 1
	return true

func read_slot(i: int) -> Dictionary:
	if not has_save(i):
		return {}
	var f := FileAccess.open(_slot_path(i), FileAccess.READ)
	if f == null:
		return {}
	var v = str_to_var(f.get_as_text())
	f.close()
	return v if v is Dictionary else {}

## Loads a slot into the live game state. The world is rebuilt afterwards so
## opened chests, pulled levers and defeated enemies stay that way.
func load_slot(i: int) -> bool:
	var d := read_slot(i)
	if d.is_empty():
		return false
	reset_run()
	active_slot = i
	var p: Dictionary = d.get("profile", {})
	for k in p:
		profile[k] = p[k]
	level = int(d.get("level", 1)); xp = int(d.get("xp", 0)); gold = int(d.get("gold", 0))
	potions = int(d.get("potions", 3)); mana_potions = int(d.get("mana_potions", 2))
	var its: Dictionary = d.get("items", {})
	for k in its:
		items[k] = its[k]
	inventory.assign(d.get("inventory", ["rusty_sword", "traveler_garb"]))
	var eq: Dictionary = d.get("equipped", {})
	for k in eq:
		equipped[k] = eq[k]
	kills = int(d.get("kills", 0)); play_time = float(d.get("play_time", 0.0))
	flags = d.get("flags", {}).duplicate(true)
	checkpoint_pos = d.get("checkpoint_pos", Vector3.ZERO)
	checkpoint_yaw = float(d.get("checkpoint_yaw", 0.0))
	checkpoint_name = String(d.get("checkpoint_name", "the Outpost"))
	objective = String(d.get("objective", ""))
	resume_pos = d.get("resume_pos", Vector3.ZERO)
	resume_yaw = float(d.get("resume_yaw", 0.0))
	zone = String(d.get("zone", "vault"))
	quests = d.get("quests", {}).duplicate(true)
	tracked_quest = String(d.get("tracked_quest", ""))
	tracked_manual = bool(d.get("tracked_manual", false))
	day_clock = float(d.get("day_clock", 150.0))
	costume = (d.get("costume", {}) as Dictionary).duplicate()
	hp = clampf(float(d.get("hp", max_hp())), max_hp() * 0.5, max_hp())
	mana = clampf(float(d.get("mana", max_mana())), 0.0, max_mana())
	stamina = max_stamina()
	stats_changed.emit(); inventory_changed.emit()
	return true

func delete_slot(i: int) -> void:
	if has_save(i):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(i)))
	if active_slot == i:
		active_slot = -1

## Short description of a slot for the menu.
func slot_summary(i: int) -> Dictionary:
	var d := read_slot(i)
	if d.is_empty():
		return {}
	var p: Dictionary = d.get("profile", {})
	var secs := int(d.get("play_time", 0.0))
	var ago := int(Time.get_unix_time_from_system() - float(d.get("saved_at", 0.0)))
	var ago_s := "just now"
	if ago >= 86400:
		ago_s = "%d day%s ago" % [ago / 86400, "" if ago < 172800 else "s"]
	elif ago >= 3600:
		ago_s = "%d hour%s ago" % [ago / 3600, "" if ago < 7200 else "s"]
	elif ago >= 60:
		ago_s = "%d min ago" % (ago / 60)
	return {
		"name": String(p.get("name", "Nameless")),
		"hero": String(p.get("hero", "Knight")),
		"level": int(d.get("level", 1)),
		"where": String(d.get("checkpoint_name", "the Outpost")),
		"objective": String(d.get("objective", "")),
		"time": "%dh %02dm" % [secs / 3600, (secs / 60) % 60] if secs >= 3600 else "%d min" % maxi(1, secs / 60),
		"ago": ago_s,
		"won": d.get("flags", {}).get("victory", false),
		"forest_won": d.get("flags", {}).get("forest_won", false),
		"gold": int(d.get("gold", 0)),
		"zone": ZONE_NAMES.get(String(d.get("zone", "vault")), "The Deep Vault"),
	}

# ---------------------------------------------------------------------------
# Levels and quests.
signal quests_changed
signal quest_event(text: String)
var zone := "vault"               # "vault" (Level 1) or "forest" (Level 2: the Goblin Forest)
var quests := {}                  # quest id -> {"state": "active"|"ready"|"done", "n": progress}
var tracked_quest := ""           # the quest the compass arrow points to ("" = pick one automatically)
var tracked_manual := false       # true when the player chose it themselves
var day_clock := 150.0            # seconds into the forest's day/night cycle (see DayNight)

const ZONE_NAMES := {"vault": "The Deep Vault", "forest": "The Goblin Forest", "castle": "Ghost Knight Castle"}
const GOBLINS := ["goblin", "goblin_archer", "goblin_brute", "goblin_chief", "fire_goblin", "fire_archer", "magma_brute", "cyclops"]

## Quest givers and their quests (Level 2). Goals: kill (enemy types), collect (quest items), boss (enemy uid).
const QUESTS := {
	"goblin_trouble": {"giver": "fenn", "title": "Goblin Trouble",
		"goal": {"type": "kill", "count": 10}, "track": "Goblins defeated",
		"offer": "Well met, traveller! You came through the old portal? Then you're just in time.\n\nGoblins have been pouring out of the Warren and raiding the road. Thin their numbers: defeat ten of them and come back to me.",
		"busy": "Ten goblins. They roam the road and the woods. Watch for the archers: they hang back and shoot.",
		"thanks": "Ten! You fight like three rangers. Take this, and go and talk to the others in the forest: they need help too. Captain Aldric guards the Warren to the north.",
		"reward": {"xp": 160, "gold": 40, "potions": 2, "roll": "weapon"}},
	"stolen_axes": {"giver": "bram", "title": "Bram's Stolen Axes",
		"goal": {"type": "collect", "item": "axe", "count": 3}, "track": "Axes found",
		"offer": "Those thieving goblins took my three good axes! Can't cut a single log without them.\n\nThey'll have carried them back to their camps in the woods. Bring them back and I'll make it worth your while.",
		"busy": "Three axes. Look around the goblin camps: you'll see them glinting.",
		"thanks": "My axes! Back where they belong. Here, this armour was my father's. It'll serve you better than it serves my wall.",
		"reward": {"xp": 180, "gold": 50, "roll": "armor"}},
	"moonpetals": {"giver": "maera", "title": "Moonpetals",
		"goal": {"type": "collect", "item": "moonpetal", "count": 7}, "track": "Moonpetals gathered",
		"offer": "Ah, a visitor. Hush now, the forest is listening.\n\nI brew my potions from moonpetals, little glowing flowers that grow in the quiet places of this forest. My knees aren't what they were. Could you gather seven for me? Mind the goblins: they've taken to camping in my favourite spots.",
		"busy": "Moonpetals glow blue in the shade. Look near the stream and under the big trees.",
		"thanks": "Seven perfect moonpetals. Here, take some of my brews, and a little something I've been saving.",
		"reward": {"xp": 160, "gold": 30, "potions": 2, "mana_potions": 3, "roll": "skin"}},
	"strongbox": {"giver": "tobble", "title": "The Stolen Strongbox",
		"goal": {"type": "collect", "item": "strongbox", "count": 1}, "track": "Strongbox recovered",
		"offer": "Oh, thank goodness, a hero! The goblins ambushed my wagon and dragged off my strongbox: everything I own is in it!\n\nThey took it down into the Warren. Please, bring it back!",
		"busy": "My strongbox is somewhere down in the Warren. I'd bet that brute of a chief is sitting on it.",
		"thanks": "My strongbox! Everything's still here! Please, take a fair share. You've earned it ten times over.",
		"reward": {"xp": 260, "gold": 150, "roll": "big"}},
	"warren": {"giver": "aldric", "title": "Into the Warren", "requires": "goblin_trouble",
		"goal": {"type": "boss", "uid": "gruk", "count": 1}, "track": "Chief Gruk defeated",
		"locked": "Halt. The Warren is no place for someone untested.\n\nRanger Fenn by the portal has goblin work that needs doing. Help Fenn first, and then we'll talk.",
		"offer": "Fenn says you're the real thing. Good.\n\nThe goblins answer to Chief Gruk, a brute twice the size of the others. He's holed up at the bottom of the Warren. End him, and the forest will be safe again.\n\nI've unbarred the door. Go carefully.",
		"busy": "Gruk is at the bottom of the Warren. He calls for help when he's hurt, so be ready.",
		"thanks": "Gruk is beaten? The whole forest will sing about this. You have my thanks and the thanks of the realm. Here, from the garrison vault.",
		"reward": {"xp": 450, "gold": 200, "roll": "boss"}},
	"sinkhole": {"giver": "dunstan", "title": "The Sinkhole of Death", "requires": "goblin_trouble",
		"goal": {"type": "boss", "uid": "cyclops", "count": 1}, "track": "Grimgor defeated",
		"locked": "Eh? You want to help? Hah! You look like you'd faint at a goblin.\n\nGo and help Ranger Fenn by the portal first. Then come back and we'll talk about what lives under this ground.",
		"offer": "Shh! Listen... hear that rumbling? There's a hollow under these woods, deep as a mountain is tall. My granddad called it the Sinkhole of Death.\n\nSomething's living down there. A great goblin with ONE BIG EYE: Grimgor. His fire goblins are digging up under the forest.\n\nSomebody has to go down and stop him. Are you brave enough?",
		"busy": "Grimgor's down at the very bottom, past the lava river. Watch for his stomp: when the ground glows red around him, RUN!",
		"thanks": "You beat Grimgor?! And you came back riding a GIANT CHICKEN! Hah! Best thing I've seen in sixty years of digging. Here, you've earned every coin.",
		"reward": {"xp": 700, "gold": 260, "potions": 3, "roll": "boss"}},
	# --- Level 3: Ghost Knight Castle (nine quests)
	"restless_dead": {"giver": "elowen", "zone": "castle", "title": "The Restless Dead",
		"goal": {"type": "kill", "types": ["ghost_knight"], "count": 8}, "track": "Ghost knights laid to rest",
		"offer": "Bless you for coming, traveller. Every night the ghost knights ride out of Castle Morwen and terrify Ashenford.\n\nLay eight of them to rest. When they fall, their armour clatters to the ground: keep whatever fits you.",
		"busy": "The ghost knights patrol the moors and the castle road. Their armour falls when they do.",
		"thanks": "Eight souls at peace. The village sleeps a little easier tonight. Take this, with the chapel's thanks.",
		"reward": {"xp": 520, "gold": 120, "potions": 2, "roll": "armor"}},
	"lost_lockets": {"giver": "mott", "zone": "castle", "title": "Lockets in the Graveyard",
		"goal": {"type": "collect", "item": "locket", "count": 5}, "track": "Lockets found",
		"offer": "Eh? Oh, a living one! Ha. I'm Mott, the gravedigger.\n\nThe ghosts have been digging up the graveyard looking for their old lockets. If you find five of them first, the ghosts might settle down. They glint gold between the graves, west of here.",
		"busy": "Five lockets. West, in the graveyard. Mind the archers in the trees.",
		"thanks": "Five lockets, safe and sound. I'll put them back where they belong. You've a good heart.",
		"reward": {"xp": 480, "gold": 110, "potions": 2, "roll": "skin"}},
	"light_beacons": {"giver": "brannoc", "zone": "castle", "title": "Light the Beacons",
		"goal": {"type": "collect", "item": "beacon", "count": 3}, "track": "Beacons lit",
		"offer": "Captain Brannoc of the King's Guard. We came to take back Castle Morwen, and the ghosts sent us running.\n\nThree old beacons stand on the hills around the castle. Light all three and the ghosts' mist will thin. Then we can talk about that gate.",
		"busy": "Three beacons on the hills around the castle. Walk up to each one to light it.",
		"thanks": "Look at that! You can see the castle walls again. Now, about that gate...",
		"reward": {"xp": 500, "gold": 120, "potions": 2, "roll": "weapon"}},
	"the_gatehouse": {"giver": "brannoc", "zone": "castle", "title": "The Gatehouse Warden", "requires": "light_beacons",
		"goal": {"type": "boss", "uid": "gatekeeper", "count": 1}, "track": "Gatehouse Warden defeated",
		"locked": "Light the beacons first. With the mist this thick we'd never even find the gate.",
		"offer": "The castle gate is guarded by the Gatehouse Warden: a ghost knight twice the size of the others. While he stands, the gate stays shut.\n\nBeat him and the gate is ours. His stomp freezes the ground, so keep moving!",
		"busy": "The Warden stands before the castle gate, to the north. Watch for the blue ring when he stomps.",
		"thanks": "The gate is open! Castle Morwen, here we come. You fight like a whole company of guards.",
		"reward": {"xp": 750, "gold": 180, "potions": 3, "roll": "big"}},
	"archers_on_walls": {"giver": "holt", "zone": "castle", "title": "Archers on the Walls",
		"goal": {"type": "kill", "types": ["ghost_archer"], "count": 8}, "track": "Ghost archers defeated",
		"offer": "Sergeant Holt. Keep your head down! Ghost archers shoot at anything that moves near the castle.\n\nTake out eight of them and my lads can move in. They hide on the hills and in the graveyard trees.",
		"busy": "Eight ghost archers. They keep their distance, so close in fast or shoot back.",
		"thanks": "Eight! My lads can breathe again. Here, you've earned the good stuff.",
		"reward": {"xp": 520, "gold": 130, "potions": 2, "roll": "weapon"}},
	"holy_water": {"giver": "ansel", "zone": "castle", "title": "Holy Water",
		"goal": {"type": "collect", "item": "holywater", "count": 3}, "track": "Holy water found",
		"offer": "Brother Ansel, of the chapel. The Ghost Lord in the castle can't be beaten by steel alone.\n\nThe old monks hid three flasks of holy water in the crypt under the graveyard. Bring them to me and I'll bless your blade.",
		"busy": "The crypt is under the graveyard, west. Look for the stone crypt with the stairs going down.",
		"thanks": "Three flasks of holy water! Hold out your weapon... there. Now the Ghost Lord will feel your blows.",
		"reward": {"xp": 520, "gold": 120, "mana_potions": 3, "roll": "big"}},
	"wraith_hunt": {"giver": "pip", "zone": "castle", "title": "Spooked Horses",
		"goal": {"type": "kill", "types": ["wraith"], "count": 6}, "track": "Wraiths banished",
		"offer": "M-m-mister! The wraiths keep scaring our horses and they've all run off!\n\nCould you chase away six of those floaty, wailing things? They hang about the old ruined chapel to the east.",
		"busy": "Six wraiths. East, at the ruined chapel. They throw cold magic, so dodge!",
		"thanks": "The horses are coming back! Thank you thank you thank you! Here, it's all my savings.",
		"reward": {"xp": 480, "gold": 90, "potions": 2, "roll": "skin"}},
	"music_box": {"giver": "wren", "zone": "castle", "title": "Lady Wren's Music Box", "requires": "the_gatehouse",
		"goal": {"type": "collect", "item": "musicbox", "count": 1}, "track": "Music box found",
		"locked": "Oh... a visitor. I can't leave the castle gate, and the gate is shut. If only someone could open it...",
		"offer": "I'm Lady Wren. I lived in Castle Morwen, long ago, before the Ghost Lord came.\n\nMy music box is still in the castle library. If I could hear its song once more, I think I could finally rest. Would you find it for me?",
		"busy": "The library is on the east side of the great hall. My music box sits on a little table there.",
		"thanks": "My music box... *its little tune plays* Thank you. I feel so light. Please, take my family's treasure. And beat him for me.",
		"reward": {"xp": 560, "gold": 150, "roll": "big"}},
	"ghost_lord": {"giver": "elowen", "zone": "castle", "title": "The Ghost Lord", "requires": "the_gatehouse",
		"goal": {"type": "boss", "uid": "ghost_lord", "count": 1}, "track": "Ghost Lord defeated",
		"locked": "Lay the restless dead to rest, and get the castle gate open. Then come back to me.",
		"offer": "The Ghost Lord sits on Castle Morwen's throne and sends the dead riding every night. It has to end.\n\nHe waits in the throne room at the back of the great hall. Brother Ansel's holy water will help. Go, and may the light go with you.",
		"busy": "The throne room is at the far end of the great hall. When he raises his sword, a ring of frost spreads out: get away from it!",
		"thanks": "It's over! The ghosts are going home at last. The whole of Ashenford owes you everything.\n\nAnd... there's something in the old stable you should see. Pip's been fixing it up for you. It goes VROOM.",
		"reward": {"xp": 1200, "gold": 400, "potions": 3, "roll": "boss"}},
}

## Quests belonging to a zone (the forest's six have no "zone" key).
func zone_quests(z: String) -> Array:
	var out: Array = []
	for id in QUESTS:
		if String(QUESTS[id].get("zone", "forest")) == z:
			out.append(id)
	return out

func zone_complete(z: String) -> bool:
	for id in zone_quests(z):
		if quest_state(id) != "done":
			return false
	return not zone_quests(z).is_empty()

func quest_state(id: String) -> String:
	if quests.has(id):
		return String(quests[id].state)
	var q: Dictionary = QUESTS.get(id, {})
	if q.has("requires") and quest_state(q.requires) != "done":
		return "locked"
	return "available"

func quest_progress(id: String) -> int:
	return int(quests.get(id, {}).get("n", 0))

func quest_accept(id: String) -> void:
	if quests.has(id):
		return
	quests[id] = {"state": "active", "n": 0}
	tracked_quest = id                # a new quest is the one you're on
	tracked_manual = false
	set_objective(forest_objective())
	quest_event.emit("New quest: %s" % QUESTS[id].title)
	message.emit("New quest: %s" % QUESTS[id].title, Color(1.0, 0.85, 0.35))
	quests_changed.emit()
	save_slot()

func _advance(id: String, n := 1) -> void:
	var q: Dictionary = QUESTS[id]
	var st: Dictionary = quests[id]
	if st.state != "active":
		return
	st.n = mini(int(st.n) + n, int(q.goal.count))
	message.emit("%s: %d/%d" % [q.track, st.n, q.goal.count], Color(1.0, 0.85, 0.35))
	if int(st.n) >= int(q.goal.count):
		st.state = "ready"
		message.emit("Quest complete! Return to %s." % NPC_NAMES.get(q.giver, "the quest giver"), Color(0.6, 1.0, 0.5))
		quest_event.emit("ready")
		set_objective(forest_objective())
	quests_changed.emit()

func on_enemy_killed(type_id: String, uid: String) -> void:
	for id in quests:
		if quests[id].state != "active":
			continue
		var g: Dictionary = QUESTS[id].goal
		if g.type == "kill" and type_id in g.get("types", GOBLINS):
			_advance(id)
		elif g.type == "boss" and uid == g.uid:
			_advance(id)

func on_quest_item(item: String) -> void:
	for id in quests:
		var g: Dictionary = QUESTS[id].goal
		if quests[id].state == "active" and g.type == "collect" and g.item == item:
			_advance(id)
			save_slot()
			return

## Turn a finished quest in: rewards, then the quest is done.
func quest_turn_in(id: String) -> Array:
	if quest_state(id) != "ready":
		return []
	quests[id].state = "done"
	var r: Dictionary = QUESTS[id].reward
	add_xp(int(r.get("xp", 0)))
	if r.has("gold"):
		add_gold(int(r.gold))
	potions += int(r.get("potions", 0))
	mana_potions += int(r.get("mana_potions", 0))
	var items_got: Array = []
	if r.has("roll"):
		for d in Loot.roll_chest(String(r.roll), zone_level() + (1 if r.roll == "boss" else 0)):
			if d.kind == "costume":
				wear_costume(String(d.id))
			elif d.kind == "item":
				add_item(d.id)
				items_got.append(d.id)
			elif d.kind == "gold":
				add_gold(int(d.amount))
			elif d.kind == "potion":
				potions += int(d.get("amount", 1))
			elif d.kind == "mana":
				mana_potions += int(d.get("amount", 1))
	message.emit("Quest done: %s" % QUESTS[id].title, Color(0.6, 1.0, 0.5))
	set_objective(forest_objective())
	stats_changed.emit()
	quests_changed.emit()
	save_slot()
	return items_got

const NPC_NAMES := {"fenn": "Ranger Fenn", "bram": "Bram the Woodcutter", "maera": "Old Maera", "tobble": "Tobble the Merchant", "aldric": "Captain Aldric", "dunstan": "Digger Dunstan",
	"elowen": "Sister Elowen", "mott": "Old Mott", "brannoc": "Captain Brannoc", "holt": "Sergeant Holt", "ansel": "Brother Ansel", "pip": "Pip the Stablehand", "wren": "Lady Wren"}

## Quests listed in the tracker: active and ready ones.
## Item level of the current zone: the Vault starts low, the castle is tougher.
func zone_level() -> int:
	return {"vault": 4, "forest": 5, "castle": 8}.get(zone, 4)

func forest_objective() -> String:
	if zone == "castle":
		return castle_objective()
	if zone != "forest":
		return objective
	if zone_complete("forest"):
		return "Every forest quest is done! The Moonlit Portal (south-east) leads to Ghost Knight Castle."
	if quest_state("warren") == "done" and quest_state("sinkhole") != "done":
		return "Gruk is beaten! Finish every forest quest (Digger Dunstan, north-west, still needs help) to open the Moonlit Portal."
	if quest_state("warren") == "done":
		return "Finish every forest quest to open the Moonlit Portal to Level 3."
	if quest_state("warren") in ["active", "ready"]:
		return "Defeat Chief Gruk at the bottom of the Goblin Warren." if quest_state("warren") == "active" else "Tell Captain Aldric that Gruk is beaten."
	if quests.is_empty():
		return "Explore the Goblin Forest. Ranger Fenn waits by the portal."
	if quest_state("goblin_trouble") == "done":
		return "Help the forest folk, then see Captain Aldric at the Warren gate (north)."
	return "Help the forest folk: your quests are listed on the left."

func castle_objective() -> String:
	if quest_state("ghost_lord") == "done":
		return "Castle Morwen is free! Ride your moped (G) and enjoy the moonlight."
	if quest_state("ghost_lord") in ["active", "ready"]:
		return "Defeat the Ghost Lord in the castle's throne room." if quest_state("ghost_lord") == "active" else "Tell Sister Elowen the Ghost Lord is gone."
	if quests_in("castle").is_empty():
		return "Welcome to Ashenford. Talk to the villagers: they need your help against the ghosts of Castle Morwen."
	return "Help Ashenford: your quests are listed on the left. The beams of light show who needs you."

func quests_in(z: String) -> Array:
	return zone_quests(z).filter(func(id: String) -> bool: return quests.has(id))

## Choose the quest the compass follows (the player picked it).
func track_quest(id: String) -> void:
	if not quest_state(id) in ["active", "ready"]:
		return
	tracked_quest = id
	tracked_manual = true
	message.emit("Following: %s" % QUESTS[id].title, Color(1.0, 0.85, 0.35))
	quests_changed.emit()

## Step to the next open quest (T key / gamepad).
func track_next() -> void:
	var ids := tracked_quests()
	if ids.is_empty():
		return
	var i := ids.find(tracked_quest)
	track_quest(ids[(i + 1) % ids.size()])

## The quest the compass follows right now; "" if there are none open.
func current_quest() -> String:
	if quest_state(tracked_quest) in ["active", "ready"]:
		return tracked_quest
	return ""

func tracked_quests() -> Array:
	var out: Array = []
	for id in quests:
		if quests[id].state in ["active", "ready"]:
			out.append(id)
	return out
