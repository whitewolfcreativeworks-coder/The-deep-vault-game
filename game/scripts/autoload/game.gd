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
const HAIR_STYLES2 := ["natural", "curly", "long", "ponytail", "buns", "spiky", "mohawk", "bald"]
const HAIR_STYLE_NAMES := {"natural": "Natural", "curly": "Curly", "long": "Long", "ponytail": "Ponytail",
	"buns": "Buns", "spiky": "Spiky", "mohawk": "Mohawk", "bald": "Bald"}
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
		if it.slot == "skin":
			better = cur == ""   # your first skin goes on straight away; later ones wait in the bag
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
		"toggle_view": [KEY_V], "special": [KEY_X],
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
		"potion": JOY_BUTTON_DPAD_UP, "mana_potion": JOY_BUTTON_DPAD_DOWN, "special": JOY_BUTTON_RIGHT_STICK}
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
		"gold": int(d.get("gold", 0)),
	}
