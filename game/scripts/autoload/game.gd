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
signal foe_down(pos: Vector3)       # any monster beaten (forge powers listen for it)

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
	"sex": "",              # "male" / "female" ("" = the class's own)
}

## Port Home: once you've flown home after the main adventure, you can whoosh
## back to your cabin from anywhere (the HOME button, or Y).
func can_port_home() -> bool:
	return quest_state("flight_home") == "done" or flags.get("home_won", false) or flags.get("adventure_done", false)

# --- Replay modes: after the first adventure, the family portal starts a new one ---
## Normal, Hard (twice as tough, more monsters) or INSANE (tougher still, and the
## kitchen sink: wild random events and strange monsters, see InsaneChaos). You
## keep your level, gold and gear; "start fresh" puts your gear in the chest.
var mode := "normal"
const MODES := {
	"normal": {"name": "Normal", "hp": 1.0, "boss_hp": 1.0, "dmg": 1.0, "speed": 1.0, "reward": 1.0, "twins": 0.0, "triplets": 0.0},
	# Hard (Jason, Nov 20): "exactly like normal mode with more hit points for the NPCs".
	# No extra monsters (the twins made the forest lag on the iPad), same speed, same
	# hits; about three times the health, grown to your level, better rewards.
	"hard": {"name": "Hard", "hp": 3.0, "boss_hp": 2.5, "dmg": 1.0, "speed": 1.0, "reward": 1.6, "twins": 0.0, "triplets": 0.0},
	"insane": {"name": "INSANE", "hp": 3.4, "boss_hp": 2.6, "dmg": 2.1, "speed": 1.3, "reward": 2.5, "twins": 0.35, "triplets": 0.0},
}

func mode_value(key: String) -> float:
	return float((MODES.get(mode, MODES.normal) as Dictionary).get(key, 1.0))

func mode_name() -> String:
	return String((MODES.get(mode, MODES.normal) as Dictionary).name)

## Did this run start "with my gear"? (INSANE then matches your gear too.)
var mode_geared := true

## Hard and Insane: the monsters grow to match YOU, so a high-level hero still gets
## a real fight in the first dungeon. Both modes match your level. INSANE "with my
## gear" also matches the gear you carry, and adds a bit more on top; start fresh
## and your gear doesn't count against you. Returns (monster health, monster damage)
## multipliers; the mode's own multipliers come on top.
func foe_scale() -> Vector2:
	if mode == "normal":
		return Vector2.ONE
	var z := zone_level()
	var gz := (2.0 + 2.2 * z) * 1.3            # the gear a hero usually has by this level
	var ref_dmg := BASE_DAMAGE + (z - 1) * 3.5 + gz
	var ref_ehp := (BASE_HP + (z - 1) * 18.0) * ((z - 1) + gz + 45.0) / 45.0
	var lv := maxi(level, z)
	var you_dmg := BASE_DAMAGE + (lv - 1) * 3.5 + gz
	var you_ehp := (BASE_HP + (lv - 1) * 18.0) * ((lv - 1) + gz + 45.0) / 45.0
	var extra := 1.0
	if mode == "insane" and mode_geared:
		you_dmg = maxf(you_dmg, BASE_DAMAGE + (level - 1) * 3.5 + gear("damage") + gear("spell") * 0.25)
		you_ehp = maxf(you_ehp, max_hp() * (defense() + 45.0) / 45.0)
		extra = 1.15
	return Vector2(clampf(you_dmg / ref_dmg, 1.0, 12.0) * extra, clampf(you_ehp / ref_ehp, 1.0, 12.0) * extra)

## Fire and lava by mode (Normal uses each hazard's own numbers, unchanged).
## A share of your max health, and armor doesn't help: "in hard mode, the fire
## should burn you more... in insane mode, if the fire touches you, you usually
## pretty much die" (Jason, Nov 20).
##   fire       the hit when a fire vent or geyser catches you
##   fire_burn  then you keep burning, this much per second (3 s for vents, 1.5 s for geysers)
##   lava       every half second you're in lava
const HAZARDS := {
	"hard": {"fire": 0.22, "fire_burn": 0.04, "lava": 0.15},
	"insane": {"fire": 0.6, "fire_burn": 0.1, "lava": 0.45},
}

func hazard(key: String) -> float:
	return float((HAZARDS.get(mode, {}) as Dictionary).get(key, 0.0))

## Loot in Hard and Insane is worth having at your level.
func mode_ilvl(ilvl: int) -> int:
	if mode == "normal":
		return ilvl
	return maxi(ilvl, level) + (1 if mode == "insane" else 0)

## The levels you can play again from the family portal (after the first adventure).
const LEVELS := [
	["vault", "The Deep Vault", "Level 1: rising skeletons, fire vents, the glowing river and the Vault Warden.", Color(0.5, 0.75, 1.0)],
	["forest", "The Goblin Forest", "Level 2: goblin camps, the Warren, the Sinkhole, Chief Gruk and Grimgor.", Color(0.55, 0.95, 0.45)],
	["castle", "Ghost Knight Castle", "Level 3: ghost knights, the Bone Crypt, the Bone Colossus and the Ghost Lord.", Color(0.8, 0.65, 1.0)],
	["cloud", "Cloud Island", "Level 4: storm creatures, the Hail Golem and Mr. Bubbles.", Color(0.6, 0.92, 1.0)],
]
## Which level a saved world flag belongs to (chests, monsters, gates, quest items...),
## so one level can be reset without touching the others. Twins add "+" to the name.
const ZONE_FLAGS := {
	"vault": ["e_", "chest_", "gate_corridor", "lever_corridor", "altar", "warden_dead", "victory"],
	"forest": ["f_", "w_", "s_", "qi_axe", "qi_petal", "qi_strongbox", "sinkhole_", "warren_", "disc_", "gruk", "cyclops", "forest_won"],
	"castle": ["c_", "qi_beacon", "qi_musicbox", "qi_holy", "qi_locket", "crypt_", "bone_colossus", "ghost_pike", "castle_won"],
	"cloud": ["cl_", "qi_feather", "qi_sbub", "qi_updraft", "qi_vent", "cloud_won"],
}

func flag_zone(k: String) -> String:
	var key := k.rstrip("+")
	for z in ZONE_FLAGS:
		for p in ZONE_FLAGS[z]:
			if key.begins_with(String(p)):
				return String(z)
	return ""

## Play one level again, fresh (its monsters, bosses, chests and quests all come
## back), in Normal, Hard or Insane, with your gear or starting fresh. Everything
## else in the world stays as you left it.
func replay_level(z: String, m: String, geared: bool) -> void:
	mode = m if MODES.has(m) else "normal"
	mode_geared = geared
	for k in flags.keys():
		if flag_zone(String(k)) == z:
			flags.erase(k)
	flags.erase("port_from")
	for q in zone_quests(z):
		quests.erase(q)
	if zone_quests(z).has(tracked_quest):
		tracked_quest = ""
		tracked_manual = false
	if z == "vault":
		inventory.erase("heart_vault")
	zone = z
	checkpoint_pos = Vector3.ZERO
	resume_pos = Vector3.ZERO
	objective = ""
	buffs.clear()
	shroom = 0.0
	game_over = false
	if not geared:
		_start_fresh()
	hp = max_hp(); mana = max_mana(); stamina = max_stamina()
	inventory_changed.emit(); stats_changed.emit()

## "Start fresh": everything you've found waits for you in the gear chest at home.
func _start_fresh() -> void:
	for id in inventory.duplicate():
		if id in ["rusty_sword", "traveler_garb"]:
			continue
		inventory.erase(id)
		stash.append(id)
	for base in ["rusty_sword", "traveler_garb"]:
		if not inventory.has(base):
			inventory.append(base)
	equipped = {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": "", "skin": ""}

## Start the whole adventure again from the Vault outpost.
func new_adventure(m: String, geared: bool) -> void:
	mode = m if MODES.has(m) else "normal"
	mode_geared = geared
	var keep := {}
	for k in flags:
		var ks := String(k)
		if ks.begins_with("mount_") or ks in ["special2", "special2_told", "sky_ride_best", "sky_ride_medal", "fish_caught", "climb_top", "climb_red"]:
			keep[k] = flags[k]
	keep["adventure_done"] = true
	keep["adventures"] = int(flags.get("adventures", 0)) + 1
	flags = keep
	quests = {}
	tracked_quest = ""
	tracked_manual = false
	zone = "vault"
	checkpoint_pos = Vector3.ZERO
	resume_pos = Vector3.ZERO
	objective = ""
	day_clock = 150.0
	buffs.clear()
	shroom = 0.0
	game_over = false
	# quest items belong to the last adventure
	for id in inventory.duplicate():
		if item(id).get("slot", "") == "quest":
			inventory.erase(id)
	if not geared:
		_start_fresh()
	hp = max_hp(); mana = max_mana(); stamina = max_stamina()
	inventory_changed.emit(); stats_changed.emit()

const PLACE_NAMES := {"vault": "the Deep Vault", "forest": "the Goblin Forest", "castle": "Ghost Knight Castle", "cloud": "Cloud Island", "home": "home"}

## Is the hero a man or a woman? (The class's own unless chosen in the creator.)
func hero_sex() -> String:
	var sx := String(profile.get("sex", ""))
	if sx == "male" or sx == "female":
		return sx
	return String(CharacterModel.HEROES.get(profile.get("hero", "Knight"), {}).get("sex", "male"))
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
const FACES := ["none", "beard", "mustache", "makeup", "glitter", "eyepatch", "glow_eyes", "mask", "warpaint"]
const FACE_NAMES := {"none": "Plain", "beard": "Beard", "mustache": "Mustache", "makeup": "Makeup", "glitter": "Glitter",
	"eyepatch": "Eyepatch", "glow_eyes": "Glowing eyes", "mask": "Ninja mask", "warpaint": "War paint"}
## Heroes can have beards and moustaches; heroines get makeup and glitter instead.
const MAN_FACES := ["none", "beard", "mustache", "eyepatch", "glow_eyes", "mask", "warpaint"]
const WOMAN_FACES := ["none", "makeup", "glitter", "eyepatch", "glow_eyes", "mask", "warpaint"]

func faces_for(sex: String) -> Array:
	return WOMAN_FACES if sex == "female" else MAN_FACES
const HERO_ORDER := ["Knight", "Rogue", "Barbarian", "Ranger", "Mage", "Priest", "Druid", "Necromancer", "Beastmaster"]
const HERO_BLURB := {
	"Knight": "A sworn blade of the old roads.",
	"Rogue": "Quick hands, sharper eyes. Bobek's favourite.",
	"Barbarian": "Northland strength, few words.",
	"Ranger": "A tracker of deep places, quiver always full.",
	"Mage": "A hedge-wizard who learned the sword.",
	"Priest": "A healer in white and gold who smites the wicked.",
	"Druid": "A friend of root and leaf. The forest fights beside them.",
	"Necromancer": "Wears a crown of bone. The dead rise to serve.",
	"Beastmaster": "Never alone: a loyal wolf runs at their side.",
}
## Each hero's special ability (X key, or the big purple button on a touchscreen).
const ABILITIES := {
	"Rogue": {"name": "Backstab", "short": "STAB", "cd": 6.0, "color": Color(0.75, 0.35, 1.0),
		"desc": "Vanish in a puff of shadow, reappear behind the nearest enemy and strike for a massive 5x critical."},
	"Mage": {"name": "Fireball", "short": "FIRE", "cd": 6.0, "color": Color(1.0, 0.45, 0.15),
		"desc": "Hurl a blazing fireball at the enemy in front of you. It explodes in a huge blast that knocks everything down and leaves the ground burning."},
	"Knight": {"name": "Shield Charge", "short": "CHARGE", "cd": 7.0, "color": Color(0.5, 0.75, 1.0),
		"desc": "Rush forward inside a barrier of light, smashing through enemies, and finish with a stunning shield slam."},
	"Barbarian": {"name": "Whirlwind", "short": "SPIN", "cd": 8.0, "color": Color(1.0, 0.55, 0.25),
		"desc": "Become a burning whirlwind: four spinning hits on everything around you, the last one hurling them away."},
	"Ranger": {"name": "Volley", "short": "VOLLEY", "cd": 7.0, "color": Color(0.55, 1.0, 0.45),
		"desc": "Two waves of nine glowing arrows that burst on impact."},
	"Priest": {"name": "Holy Smite", "short": "SMITE", "cd": 6.0, "color": Color(1.0, 0.88, 0.45),
		"desc": "A pillar of golden light slams down on the enemy in front of you, stunning everything nearby and healing you."},
	"Druid": {"name": "Entangling Roots", "short": "ROOTS", "cd": 8.0, "color": Color(0.45, 0.85, 0.3),
		"desc": "Thorny roots burst from the ground ahead of you: enemies there are stuck fast and torn by thorns."},
	"Necromancer": {"name": "Raise Dead", "short": "RAISE", "cd": 14.0, "color": Color(0.45, 1.0, 0.5),
		"desc": "The ground cracks with green fire and three skeleton warriors claw their way out to fight for you for a while."},
	"Beastmaster": {"name": "Sic 'Em!", "short": "SIC 'EM", "cd": 6.0, "color": Color(1.0, 0.65, 0.3),
		"desc": "Point at an enemy: your wolf pounces on it for a huge stunning bite, and a second wolf joins the hunt."},
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
	"Priest": {"name": "Prayer of Light", "short": "PRAYER", "cd": 18.0, "color": Color(1.0, 0.95, 0.7),
		"desc": "Heals you a lot at once and more over time, and a burst of holy light dazzles every enemy around you."},
	"Druid": {"name": "Wild Growth", "short": "GROW", "cd": 16.0, "color": Color(0.6, 1.0, 0.45),
		"desc": "A ring of flowers blooms around you: you heal while you stand in it, and thorns hurt enemies inside."},
	"Necromancer": {"name": "Soul Drain", "short": "DRAIN", "cd": 12.0, "color": Color(0.5, 1.0, 0.6),
		"desc": "Green beams pull the life out of every enemy near you, and it flows into you."},
	"Beastmaster": {"name": "Bear Friend", "short": "BEAR", "cd": 24.0, "color": Color(0.8, 0.55, 0.3),
		"desc": "A huge brown bear crashes out of nowhere and fights at your side for a while."},
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
var stamina_potions := 2   # energy potions: full stamina and a Second Wind
var hp := 100.0
var mana := 60.0
var stamina := 100.0
var inventory: Array[String] = ["rusty_sword", "traveler_garb"]
var equipped := {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": "", "skin": ""}
var stash: Array[String] = []   # the gear chest in the cabin at home
const STASH_SIZE := 60
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

func _ready() -> void:
	inventory_changed.connect(_refresh_powers)
	# every 3D label (signs, name tags, damage numbers) uses the friendly sign font
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Label3D and (n as Label3D).font == null:
			(n as Label3D).font = SignText.font())

func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_time += delta
		tick_boons(delta)
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
## The Dragonfly, the first flying mount (Mr. Bubbles' reward on Cloud Island).
## You keep it for the rest of the game.
func grant_dragonfly() -> void:
	flags["mount_dragonfly"] = true
	Sfx.play("chirp", 0.0, 0.0)
	say("You got the DRAGONFLY! Press G (or RIDE) to fly.", Color(0.5, 1.0, 0.85))

func wear_costume(id: String, t: Array = []) -> void:
	if not Loot.COSTUMES.has(id):
		return
	if t.is_empty():
		t = Loot.roll_costume_time()      # (the shop's costumes come with a set time)
	var real: bool = t[2]
	costume = {"id": id, "real": real, "until": (Time.get_unix_time_from_system() if real else play_time) + float(t[1])}
	var c: Dictionary = Loot.COSTUMES[id]
	message.emit("%s  (lasts %s)" % [c.line, t[3]], Color(1.0, 0.75, 1.0))
	unlock_look(id)
	inventory_changed.emit()

func clear_costume() -> void:
	costume = {}
	inventory_changed.emit()

# --- the Skin Designer ---------------------------------------------------------
# Every costume you've worn and every armour look you've found unlocks its parts
# (head / body / arms / legs) for the designer. custom_look is the mixed look
# (see CharacterModel._wear_custom); a timed costume still goes on top of it.
var unlocked_looks: Array = []
var custom_look := {}
var custom_look_on := false

func unlock_look(id: String) -> void:
	if id == "" or unlocked_looks.has(id):
		return
	if Loot.COSTUMES.has(id) and not Loot.COSTUMES[id].has("file"):
		return   # goblins, skeletons... can't be taken apart
	unlocked_looks.append(id)

func set_custom_look(look: Dictionary, on := true) -> void:
	custom_look = look.duplicate(true)
	custom_look_on = on
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
	return (BASE_DAMAGE + (level - 1) * 3.5 + gear("damage")) * (1.25 if has_buff("strong") else 1.0) * (1.3 if has_boon("giant_strength") else 1.0)

func spell_damage() -> float:
	return (24.0 + (level - 1) * 6.5) * (1.0 + gear("spell") / 100.0) * (1.25 if has_buff("strong") else 1.0)

## Tobble's Trading Post (see ShopCatalog): elixirs, weapon enchantments and armor
## blessings you bought. id -> seconds of play left. Saved, and kept through new
## adventures and level replays (you paid for them); they fade as you play.
var boons := {}
## Yard decorations you've bought for home (ShopCatalog ids). Saved, kept forever.
var decor: Array = []
## The Forge Journal: recipes you've discovered and riddles the smith has told you.
var forge_book := {"found": [], "hints": []}
## Forge powers on the gear you wear ("power" on forged items: see ForgeRecipes),
## kept up to date whenever your gear changes.
var _powers := {}

func has_boon(id: String) -> bool:
	return boons.has(id)

func has_power(tag: String) -> bool:
	return _powers.has(tag)

func _refresh_powers() -> void:
	_powers.clear()
	for slot in SLOTS:
		var p := String(item(equipped.get(slot, "")).get("power", ""))
		if p != "":
			_powers[p] = true

## Buy (or top up) a boon. A weapon holds one enchantment and armor one blessing,
## so a new one of those replaces the old; elixirs mix freely.
func add_boon(id: String, secs: float) -> void:
	var w: Dictionary = ShopCatalog.ware(id)
	var kind := String(w.get("kind", ""))
	if kind in ["enchant", "bless"]:
		for k in boons.keys():
			if k != id and String(ShopCatalog.ware(k).get("kind", "")) == kind:
				boons.erase(k)
	boons[id] = minf(float(boons.get(id, 0.0)) + secs, 3600.0)
	stats_changed.emit()

func tick_boons(delta: float) -> void:
	if boons.is_empty():
		return
	for k in boons.keys():
		boons[k] = float(boons[k]) - delta
		if float(boons[k]) <= 0.0:
			boons.erase(k)
			message.emit("Your %s wears off." % String(ShopCatalog.ware(k).get("name", k)), Color(1.0, 0.8, 0.55))
			stats_changed.emit()

func boons_text() -> String:
	var out := ""
	var n := 0
	for k in boons:
		var s := int(ceilf(float(boons[k])))
		if n > 0:
			out += "\n" if n % 3 == 0 else "   "      # (three to a line on the HUD)
		out += "%s %d:%02d" % [String(ShopCatalog.ware(k).get("short", k)), s / 60, s % 60]
		n += 1
	return out

## Short buffs from food (see scripts/world/food.gd): name -> seconds left. Not saved.
var buffs := {}
## Rainbow vision from glowing mushrooms: about one point per mushroom (0..5.99),
## wearing off over time. See RainbowShroom and RainbowVision.
var shroom := 0.0
const BUFF_NAMES := {"strong": "Strong", "tough": "Tough", "quick": "Quick", "fed": "Well fed"}

func add_buff(n: String, secs: float) -> void:
	buffs[n] = maxf(float(buffs.get(n, 0.0)), secs)

func has_buff(n: String) -> bool:
	return float(buffs.get(n, 0.0)) > 0.0

func tick_buffs(delta: float) -> void:
	for k in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if float(buffs[k]) <= 0.0:
			buffs.erase(k)

func buffs_text() -> String:
	var parts: Array[String] = []
	for k in buffs:
		parts.append("%s %ds" % [BUFF_NAMES.get(k, k), ceili(float(buffs[k]))])
	if shroom >= 1.0:
		parts.append("Rainbow vision x%d" % mini(int(shroom), 5))
	return "   ".join(parts)

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
	return raw * (1.0 - d / (d + 45.0)) * (0.75 if has_buff("tough") else 1.0) * (0.75 if has_boon("stoneskin") else 1.0)

# ---------------------------------------------------------------------------
func reset_run() -> void:
	buffs.clear()
	shroom = 0.0
	level = 1; xp = 0; gold = 0; potions = 3; mana_potions = 2; stamina_potions = 2; kills = 0; play_time = 0.0
	_reset_items()
	inventory = ["rusty_sword", "traveler_garb"]
	equipped = {"weapon": "rusty_sword", "armor": "traveler_garb", "artifact": "", "skin": ""}
	stash = []
	mode = "normal"
	mode_geared = true
	flags = {}
	quests = {}
	tracked_quest = ""
	tracked_manual = false
	day_clock = 150.0
	costume = {}
	unlocked_looks = []; custom_look = {}; custom_look_on = false
	boons = {}; decor = []; forge_book = {"found": [], "hints": []}
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
	var tag := "" if r == 0 else "[%s] " % Loot.rarity_label(it).to_upper()
	message.emit("Found: %s%s" % [tag, it.name], it.color)
	loot_found.emit(id)
	if it.has("outfit"):
		unlock_look(String(it.outfit))
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

## "Wear my best gear" (Jason, Nov 20): your best weapon, armor and trinket, by
## the same worth the bag uses for "better / weaker" (a forge power counts for a
## bit extra). With include_chest (at the gear chest at home) it looks in the
## chest too, and anything it takes off goes into the chest if your bag is full.
## Skins are a look, so they're left as they are. Returns how many it changed.
func best_score(uid: String) -> float:
	var it := item(uid)
	return score(uid) + (12.0 if String(it.get("power", "")) != "" else 0.0) + (12.0 if String(it.get("power2", "")) != "" else 0.0)

func wear_best(include_chest := false) -> int:
	var changed := 0
	for slot in ["weapon", "armor", "artifact"]:
		var cur: String = equipped.get(slot, "")
		if slot == "artifact" and zone == "vault" and item(cur).get("special", "") == "river":
			continue           # (in the Vault, the river amulet stays on: the river heals you)
		var best := cur
		var bs := best_score(cur) if cur != "" else -INF
		var pool: Array = Array(inventory) + (Array(stash) if include_chest else [])
		for id in pool:
			var it := item(String(id))
			if it.get("slot", "") != slot or id == cur:
				continue
			var sc := best_score(String(id))
			if sc > bs + 0.01:
				bs = sc; best = String(id)
		if best == cur:
			continue
		if stash.has(best):
			stash.erase(best)
			inventory.append(best)
		equip(best)
		changed += 1
		if inventory.size() > BAG_SIZE and cur != "" and include_chest and stash.size() < STASH_SIZE and not ITEMS.has(cur):
			inventory.erase(cur)       # (no room in the bag: what you took off goes in the chest)
			stash.append(cur)
	if changed > 0:
		message.emit("You're wearing your best gear!", Color(1.0, 0.85, 0.4))
	else:
		message.emit("You're already wearing your best gear.", Color(0.8, 0.8, 0.8))
	inventory_changed.emit(); stats_changed.emit()
	return changed

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

## The gear chest at home: put things in, take them out. (What you're wearing
## and quest items stay with you.)
func can_stash(id: String) -> bool:
	var it := item(id)
	return not it.is_empty() and inventory.has(id) and not equipped.values().has(id) and it.get("slot", "") != "quest"

func stash_put(id: String) -> bool:
	if not can_stash(id):
		return false
	if stash.size() >= STASH_SIZE:
		message.emit("The gear chest is full!", Color(1.0, 0.6, 0.4))
		return false
	inventory.erase(id)
	stash.append(id)
	inventory_changed.emit()
	return true

func stash_take(id: String) -> bool:
	if not stash.has(id):
		return false
	if inventory.size() >= BAG_SIZE:
		message.emit("Your bag is full! Put something in the chest first.", Color(1.0, 0.6, 0.4))
		return false
	stash.erase(id)
	inventory.append(id)
	inventory_changed.emit()
	return true

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
	if String(it.get("power", "")) != "":
		out.append("★ " + ForgeRecipes.power_text(String(it.power)))
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
		"pause": [KEY_ESCAPE], "spell": [KEY_Q], "potion": [KEY_R, KEY_1], "mana_potion": [KEY_F, KEY_2], "stamina_potion": [KEY_H, KEY_4],
		"zoom_in_key": [KEY_EQUAL, KEY_KP_ADD], "zoom_out_key": [KEY_MINUS, KEY_KP_SUBTRACT],
		"toggle_view": [KEY_V], "special": [KEY_X], "track_quest": [KEY_T], "mount": [KEY_G], "pose": [KEY_P], "auto_run": [KEY_Z, KEY_NUMLOCK], "special2": [KEY_B, KEY_3],
		"port_home": [KEY_Y, KEY_HOME],
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
		"potion": JOY_BUTTON_DPAD_UP, "mana_potion": JOY_BUTTON_DPAD_DOWN, "stamina_potion": JOY_BUTTON_DPAD_LEFT, "special": JOY_BUTTON_RIGHT_STICK, "special2": JOY_BUTTON_LEFT_STICK}
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
		"potions": potions, "mana_potions": mana_potions, "stamina_potions": stamina_potions,
		"hp": hp, "mana": mana,
		"items": items.duplicate(true),
		"inventory": Array(inventory),
		"equipped": equipped.duplicate(),
		"stash": Array(stash),
		"mode": mode, "mode_geared": mode_geared,
		"kills": kills, "play_time": play_time,
		"flags": flags.duplicate(true),
		"checkpoint_pos": checkpoint_pos, "checkpoint_yaw": checkpoint_yaw, "checkpoint_name": checkpoint_name,
		"objective": objective,
		"resume_pos": resume_pos, "resume_yaw": resume_yaw,
		"zone": zone, "quests": quests.duplicate(true), "tracked_quest": tracked_quest, "tracked_manual": tracked_manual, "day_clock": day_clock, "costume": costume.duplicate(),
		"unlocked_looks": unlocked_looks.duplicate(), "custom_look": custom_look.duplicate(true), "custom_look_on": custom_look_on,
		"boons": boons.duplicate(), "decor": decor.duplicate(), "forge_book": forge_book.duplicate(true),
		"loot_next": Loot._next,
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
	if not p.has("sex"):
		profile.sex = ""      # saves from before you could choose man or woman
	for k in p:
		profile[k] = p[k]
	# retired face options (Nov 17): scar -> glowing eyes, rosy cheeks -> plain
	if profile.get("face", "none") == "scar":
		profile.face = "glow_eyes"
	elif not profile.get("face", "none") in FACES:
		profile.face = "none"
	level = int(d.get("level", 1)); xp = int(d.get("xp", 0)); gold = int(d.get("gold", 0))
	potions = int(d.get("potions", 3)); mana_potions = int(d.get("mana_potions", 2)); stamina_potions = int(d.get("stamina_potions", 2))
	var its: Dictionary = d.get("items", {})
	for k in its:
		items[k] = its[k]
	inventory.assign(d.get("inventory", ["rusty_sword", "traveler_garb"]))
	stash.assign(d.get("stash", []))
	mode = String(d.get("mode", "normal"))
	mode_geared = bool(d.get("mode_geared", true))
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
	unlocked_looks = (d.get("unlocked_looks", []) as Array).duplicate()
	custom_look = (d.get("custom_look", {}) as Dictionary).duplicate(true)
	custom_look_on = bool(d.get("custom_look_on", false))
	boons = (d.get("boons", {}) as Dictionary).duplicate()
	decor = (d.get("decor", []) as Array).duplicate()
	var fb: Dictionary = d.get("forge_book", {})
	forge_book = {"found": (fb.get("found", []) as Array).duplicate(), "hints": (fb.get("hints", []) as Array).duplicate()}
	Loot._next = maxi(Loot._next, int(d.get("loot_next", 1)))
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

const ZONE_NAMES := {"vault": "The Deep Vault", "forest": "The Goblin Forest", "castle": "Ghost Knight Castle", "cloud": "Cloud Island"}
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
		"offer": "Fenn says you're the real thing. Good.\n\nThe goblins answer to Chief Gruk, a brute twice the size of the others. He's holed up at the bottom of the Warren, behind a gate his shamans hold shut with two War Totems. Smash the totems, then end him, and the forest will be safe again.\n\nI've unbarred the door. Go carefully.",
		"busy": "Gruk is at the bottom of the Warren, behind a gate of bones. Two War Totems hold it shut: one past the chasm in the west cave, one in the mines to the east. Smash them both.",
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
		"offer": "Eh? Oh, a living one! Ha. I'm Mott, the gravedigger.\n\nThe ghosts have been digging up my graveyard looking for their old lockets, and they've left mounds of earth everywhere! If you dig the lockets up first, the ghosts might settle down.\n\nThe graveyard's west of here. Wherever a mound glints gold, dig! And if something digs back... well. Run.",
		"busy": "Five lockets, buried in the mounds of loose earth in the graveyard, west. Dig where it glints (USE). Mind the archers in the trees.",
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
		"offer": "Brother Ansel, of the chapel. The Ghost Lord in the castle can't be beaten by steel alone.\n\nThe old monks hid three flasks of holy water in the Bone Crypt under the graveyard: one deep in the catacombs, one past the Bone Bridge, and one in the Ossuary itself, where the Bone Colossus keeps watch. Bring them to me and I'll bless your blade.",
		"busy": "The Bone Crypt is under the graveyard, west. Keep moving on the Bone Bridge, it crumbles! And in the Hall of Bells, watch the wisps: the bells must ring in their order.",
		"thanks": "Three flasks of holy water! Hold out your weapon... there. Now the Ghost Lord will feel your blows.",
		"reward": {"xp": 520, "gold": 120, "mana_potions": 3, "roll": "big"}},
	"wraith_hunt": {"giver": "pip", "zone": "castle", "title": "Spooked Horses",
		"goal": {"type": "collect", "item": "horse", "count": 4}, "track": "Horses brought home",
		"offer": "M-m-mister! The wraiths wailed so loud that all four of our horses ran off, and now they're so scared they've gone see-through!\n\nCould you find them out on the moor and bring them home? Walk up gently and give each one an apple: then it'll follow you anywhere. Lead it back to my paddock, just east of the village.\n\nBut keep them away from the wraiths!",
		"busy": "Four see-through horses, out on the moor. Give each one an apple (USE) and lead it home to my paddock east of the village. If a wraith wails near your horse, it bolts: beat the wraith and calm it again.",
		"thanks": "All four, home and solid again! Look at them munch! Thank you thank you thank you! Here, it's all my savings.",
		"reward": {"xp": 520, "gold": 110, "potions": 2, "roll": "skin"}},
	"fishing": {"giver": "gill", "zone": "castle", "title": "Something Fishy",
		"goal": {"type": "collect", "item": "fish", "count": 5}, "track": "Fish caught",
		"offer": "Ahoy there! Name's Gill. I've fished the Misty Mere for sixty years, but since the ghosts came my old knees won't carry me down the pier.\n\nCatch me five fish, would you? Use the rod at the end of the pier. And if the Ghost Pike bites... don't you let go!",
		"busy": "The pier's just behind me. Wait for the bobber to dip, hook it quick, then reel, reel, REEL!",
		"thanks": "Five fish! And... is that the GHOST PIKE?! Sixty years I've tried to catch that fellow. You're a natural. Here, take this, and come fish any time you like.",
		"reward": {"xp": 620, "gold": 160, "potions": 2, "stamina_potions": 2, "roll": "skin"}},
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
	# --- Level 4: Cloud Island (designed by Jason's son). The angels need help with
	# Mr. Bubbles the flying bear and the flying animals his storms stir up.
	"lost_feathers": {"giver": "ninlil", "zone": "cloud", "title": "Lost Feathers",
		"goal": {"type": "collect", "item": "feather", "count": 6}, "track": "Feathers found",
		"offer": "Oh! A visitor from below! I'm Ninlil, keeper of the winds.\n\nMr. Bubbles' storm tore six feathers out of my wings and blew them all over the islands. Could you find them? They glow gold on the cloud edges.",
		"busy": "Six golden feathers, scattered over the islands. Ride the bubbles up to the higher clouds!",
		"thanks": "My feathers! Now I can fly straight again. Here, a gift from the sky.",
		"reward": {"xp": 900, "gold": 200, "potions": 2, "roll": "skin"}},
	"thunder_birds": {"giver": "ninlil", "zone": "cloud", "title": "Calm the Thunder Birds",
		"goal": {"type": "kill", "types": ["thunder_bird"], "count": 8}, "track": "Thunder birds calmed",
		"offer": "The thunder birds used to be gentle. Mr. Bubbles' lightning has made them wild and they swoop at everyone.\n\nCalm eight of them for me. Watch out: they dive!",
		"busy": "Eight thunder birds. When one pulls up high, it's about to dive: block or roll!",
		"thanks": "The sky is so much quieter. Thank you, brave one.",
		"reward": {"xp": 950, "gold": 220, "potions": 2, "roll": "weapon"}},
	"sky_whale": {"giver": "nanshe", "zone": "cloud", "title": "Rescue the Baby Sky Whale",
		"goal": {"type": "kill", "types": ["storm_sprite"], "count": 6}, "track": "Storm sprites cleared",
		"offer": "I'm Nanshe. I look after the sky creatures.\n\nA baby sky whale is stuck in a storm cloud on the east island, and zappy storm sprites won't let it out. Clear six of them away!",
		"busy": "The baby whale is on the east island. Clear the storm sprites around it.",
		"thanks": "Listen... it's singing! The baby whale is free and swimming home. You have a kind heart.",
		"reward": {"xp": 950, "gold": 220, "potions": 2, "roll": "big"}},
	"storm_bubbles": {"giver": "nanshe", "zone": "cloud", "title": "Pop the Storm Bubbles",
		"goal": {"type": "collect", "item": "stormbubble", "count": 6}, "track": "Storm bubbles popped",
		"offer": "Mr. Bubbles blows lightning bubbles down onto our temple island. If they burst on their own they'll zap the gardens!\n\nPop six of them before they do. Run into them: it tickles a little.",
		"busy": "Crackling yellow bubbles drift around the temple island. Run into them to pop them.",
		"thanks": "Pop pop pop! Not a single zap on the gardens. Well done!",
		"reward": {"xp": 900, "gold": 200, "mana_potions": 3, "roll": "armor"}},
	# Adad the Weather-Keeper's precipitation quests (from the Precipitation Simulator)
	"hail_rings": {"giver": "adad", "zone": "cloud", "title": "Hailstone Rings", "requires": "bubble_lifts",
		"goal": {"type": "collect", "item": "hailstone", "count": 1}, "track": "Hailstone made",
		"locked": "I am Adad, keeper of the weather. Hail, snow, sleet, freezing rain: I make them all!\n\nBut my work is up on the storm layer, and the bubble vents are clogged. Help Utu fix them, then come back.",
		"offer": "Did you know hail is made by riding a storm? Here's how.\n\nA raindrop gets caught in a powerful updraft and carried up above the freezing line, where it freezes. It falls, gets a new coat of water, and the updraft throws it back up again. Every trip adds a new ring of ice.\n\nOn the storm layer stands my Hail Tower. Step in and let it toss you up and down until your hailstone has THREE rings.",
		"busy": "The Hail Tower is on the storm layer. Ride it up past the glittering freezing line, sink back below it, and up again. Three rings!",
		"thanks": "Three rings, just like a tree! Cut a real hailstone in half and you can see them.\n\nThe biggest hailstone ever found in the United States fell in Vivian, South Dakota, in 2010. It was 8 inches across!",
		"reward": {"xp": 1000, "gold": 240, "potions": 2, "roll": "weapon"}},
	"six_sides": {"giver": "adad", "zone": "cloud", "title": "Six Sides of Snow", "requires": "bubble_lifts",
		"goal": {"type": "collect", "item": "snowflake", "count": 6}, "track": "Snowflakes caught",
		"locked": "The bubble vents are still clogged. Help Utu first.",
		"offer": "Up on the Snow Cloud, the air stays below freezing all the way down, so the water freezes straight into ice crystals. Water molecules lock together in a six-sided pattern, so almost every snowflake has SIX arms.\n\nMr. Bubbles is blowing fake snowflakes to fool me. Catch six REAL ones. Count the arms!",
		"busy": "The Snow Cloud is up from the storm layer, on the west side. Catch six snowflakes with six arms. Fakes have four or five!",
		"thanks": "Six perfect snowflakes! They fall gently, at only 1 to 4 miles per hour.\n\nThey grow by deposition: water vapor freezes straight onto a speck of dust and skips being liquid at all.",
		"reward": {"xp": 1000, "gold": 240, "mana_potions": 3, "roll": "skin"}},
	"the_glaze": {"giver": "adad", "zone": "cloud", "title": "The Glaze", "requires": "bubble_lifts",
		"goal": {"type": "collect", "item": "sunlamp", "count": 4}, "track": "Sun lamps relit",
		"locked": "The bubble vents are still clogged. Help Utu first.",
		"offer": "Freezing rain has hit the Ice Cloud! The drops fell through warm air as rain, but the air right at the bottom was below freezing. They stayed liquid until they touched something... and then froze into a coat of clear ice called GLAZE.\n\nNow the whole island is as slippery as glass, and the ice has put out my four sun lamps. Slide over and relight them. Careful near the thin ice!",
		"busy": "The Ice Cloud is up from the storm layer, on the east side. Touch the four frozen sun lamps. It's VERY slippery: walk slowly!",
		"thanks": "The Ice Cloud is glowing again! Freezing rain is one of the most dangerous kinds of weather for airplanes, because ice on the wings changes their shape.\n\nOne more trick: sleet bounces when it lands, but freezing rain doesn't. That's how weather spotters tell them apart!",
		"reward": {"xp": 1050, "gold": 260, "potions": 2, "stamina_potions": 2, "roll": "big"}},
	"why_clouds": {"giver": "enki", "zone": "cloud", "title": "Why Don't Clouds Fall?",
		"goal": {"type": "collect", "item": "updraft", "count": 3}, "track": "Updraft crystals found",
		"offer": "I am Enki, the rainmaker. Tell me, little one: a big cloud weighs as much as a hundred elephants. So why doesn't it fall out of the sky?\n\nFind three updraft crystals and I'll show you the answer. They sit where the warm air rises.",
		"busy": "Three updraft crystals. Look for the shimmering columns of rising warm air.",
		"thanks": "Feel that? Warm air rises and pushes up. A cloud's water is split into trillions of droplets, each too tiny to fall through that rising air, so the whole cloud floats! Remember it.",
		"reward": {"xp": 900, "gold": 200, "potions": 2, "roll": "big"}},
	"make_it_rain": {"giver": "enki", "zone": "cloud", "title": "Make It Rain", "requires": "why_clouds",
		"goal": {"type": "collect", "item": "raingarden", "count": 1}, "track": "Cloud garden watered",
		"locked": "First, learn why clouds float. Then we'll talk about rain.",
		"offer": "Now: rain! When droplets bump together they grow. When they get too heavy for the rising air to hold, they fall. That's rain!\n\nCollect raindrops until you're heavy, then stand still over my dry cloud garden and rain on it.",
		"busy": "Collect raindrops until your weight bar is past the middle, then stand still in the cloud garden.",
		"thanks": "Look at it grow! You made it rain, just like a real cloud. You're a natural rainmaker.",
		"reward": {"xp": 950, "gold": 230, "potions": 2, "roll": "skin"}},
	"bubble_lifts": {"giver": "utu", "zone": "cloud", "title": "The Bubble Lifts",
		"goal": {"type": "collect", "item": "ventstone", "count": 3}, "track": "Bubble vents fixed",
		"offer": "Utu, gate-warden of the sky. Mr. Bubbles clogged the bubble vents that lift us up to the storm layer.\n\nThree vent stones are jammed: one here on the temple island, one on each of the middle islands. Touch them to start them bubbling again.",
		"busy": "Three vent stones: one on the temple island and one on each middle island.",
		"thanks": "Listen to them bubble! The way up to the storm layer is open.",
		"reward": {"xp": 950, "gold": 230, "potions": 2, "roll": "weapon"}},
	"storm_gate": {"giver": "utu", "zone": "cloud", "title": "The Storm Gate", "requires": "bubble_lifts",
		"goal": {"type": "boss", "uid": "hail_golem", "count": 1}, "track": "Hail Golem defeated",
		"locked": "The vents are still clogged. Fix the bubble lifts first.",
		"offer": "A Hail Golem guards the last bubble vent, the one up to Mr. Bubbles' thunderhead. It throws hailstones the size of pumpkins.\n\nBreak it, and the way to the top is open.",
		"busy": "The Hail Golem is on the storm layer, by the last bubble vent. Heavy hits: block!",
		"thanks": "Crunch! The golem is just slush now. The vent to the thunderhead is bubbling.",
		"reward": {"xp": 1100, "gold": 280, "potions": 3, "roll": "big"}},
	"mr_bubbles": {"giver": "anu", "zone": "cloud", "title": "Mr. Bubbles", "requires": "storm_gate",
		"goal": {"type": "boss", "uid": "mr_bubbles", "count": 1}, "track": "Mr. Bubbles defeated",
		"locked": "I am Anu, eldest of the sky. When the storm gate is open, come to me.",
		"offer": "Mr. Bubbles was once a gentle cloud bear who blew rainbow bubbles for the sky children. Then he found the storm's lightning and it went to his head.\n\nHe waits on the thunderhead at the very top. Watch for his strike rings, pop his lightning bubbles, and if he traps you in a bubble, wriggle free! Calm him, and the sky is yours to fly.",
		"busy": "Mr. Bubbles is on the thunderhead at the top. Rings on the ground mean lightning: get out of them!",
		"thanks": "He's... crying? He says he's sorry, and he only wanted friends. The storm is gone.\n\nAnd look who's come to thank you: a dragonfly! It has chosen you. It will carry you anywhere, in every land below.",
		"reward": {"xp": 2000, "gold": 600, "potions": 4, "roll": "boss"}},
	"flight_home": {"giver": "anu", "zone": "home", "title": "The Flight Home", "requires": "mr_bubbles",
		"goal": {"type": "collect", "item": "home", "count": 1}, "track": "Home",
		"locked": "When the storm is calmed, there is one last journey for you.",
		"offer": "You've done everything we asked, little one, and more. Now it's time to go home.\n\nYour cabin is far, far below, past the storm clouds, the floating rocks and the mountains. I'll open the Sky Gate at the south edge of the temple island. Fly through it on your dragonfly and follow the golden rings all the way home.\n\nHold JUMP to climb, let go to glide, and hold BLOCK to dive. Green rings rest its wings. Fly well!",
		"busy": "The Sky Gate is at the south edge of the temple island. Fly through it on your dragonfly!",
		"thanks": "Welcome home.",
		"reward": {"xp": 3000, "gold": 800, "potions": 5, "roll": "boss"}},
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
	stamina_potions += int(r.get("stamina_potions", 0))
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
	"elowen": "Sister Elowen", "mott": "Old Mott", "brannoc": "Captain Brannoc", "holt": "Sergeant Holt", "ansel": "Brother Ansel", "pip": "Pip the Stablehand", "wren": "Lady Wren", "gill": "Old Gill the Fisher", "adad": "Adad the Weather-Keeper",
	"ninlil": "Ninlil of the Winds", "nanshe": "Nanshe the Keeper", "enki": "Enki the Rainmaker", "utu": "Utu the Gate-Warden", "anu": "Anu, Eldest of the Sky",
	# at home (the smith's name is a placeholder: Jason's son gets to name them)
	"tobble_shop": "Tobble the Merchant", "smith": "Ironbeard the Smith"}

## Quests listed in the tracker: active and ready ones.
## Item level of the current zone: the Vault starts low, the castle is tougher.
func zone_level() -> int:
	return {"vault": 4, "forest": 5, "castle": 8, "cloud": 11}.get(zone, 4)

func forest_objective() -> String:
	if zone == "castle":
		return castle_objective()
	if zone == "cloud":
		return cloud_objective()
	if zone == "home":
		if flags.get("ride_again", false) or quest_state("flight_home") != "done":
			return "Follow the golden rings all the way home."
		if flags.get("adventure_done", false):
			return "Home at last! The family portal in the yard leads to any level, or a whole new adventure."
		return "Home at last! The family portal in the yard leads back to the Vault."
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

func cloud_objective() -> String:
	if quest_state("flight_home") == "active":
		return "Fly your dragonfly through the Sky Gate at the south edge of the temple island."
	if quest_state("mr_bubbles") == "done" and quest_state("flight_home") == "available":
		return "Cloud Island is calm! Talk to Anu: it's time for the flight home."
	if quest_state("mr_bubbles") == "done":
		return "Cloud Island is calm! Fly your dragonfly (G) anywhere you like."
	if quest_state("mr_bubbles") == "active":
		return "Ride the bubbles to the thunderhead at the very top and calm Mr. Bubbles."
	if quest_state("mr_bubbles") == "ready":
		return "Tell Anu, Eldest of the Sky, that Mr. Bubbles is calm."
	if quests_in("cloud").is_empty():
		return "Welcome to Cloud Island! The angels at the sky temple need your help."
	return "Help the angels: your quests are on the left. Bubbles lift you higher."

func castle_objective() -> String:
	if quest_state("ghost_lord") == "done":
		return "Castle Morwen is free! Talk to Sister Elowen to ride the cloud up to Cloud Island."
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
