extends Object
class_name Loot
## Random loot: rarities, generated weapons / armor / trinkets / skins with
## random bonuses ("affixes"), and the drop tables for chests and monsters.
## Items are plain dictionaries registered in Game.items under a unique id.

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.86, 0.86, 0.86), Color(0.35, 0.92, 0.4), Color(0.3, 0.62, 1.0), Color(0.78, 0.42, 1.0), Color(1.0, 0.62, 0.15)]
const RARITY_MULT := [1.0, 1.3, 1.65, 2.05, 2.5]
const RARITY_AFFIXES := [0, 1, 2, 3, 4]

const WEAPON_BASES := [
	{"base": "Shortsword", "model": "skel_blade", "dmg": 1.0, "spell": 0},
	{"base": "Longsword", "model": "sword_1handed", "dmg": 1.15, "spell": 0},
	{"base": "Greatblade", "model": "sword_2handed_color", "dmg": 1.35, "spell": 0},
	{"base": "Battle Axe", "model": "skel_axe", "dmg": 1.25, "spell": 0},
	{"base": "Battlestaff", "model": "skel_staff", "dmg": 0.75, "spell": 25},
]
const ARMOR_BASES := [
	{"base": "Leather Jerkin", "shield": "shield_round", "def": 0.8, "tint": Color(0.75, 0.6, 0.45)},
	{"base": "Chain Hauberk", "shield": "shield_badge_color", "def": 1.0, "tint": Color(0.75, 0.78, 0.85)},
	{"base": "Bone Mail", "shield": "Skeleton_Shield_Small_A", "def": 1.05, "tint": Color(0.9, 0.85, 0.7)},
	{"base": "Plate Cuirass", "shield": "shield_square_color", "def": 1.25, "tint": Color(0.6, 0.7, 0.9)},
	{"base": "Warden Plate", "shield": "Skeleton_Shield_Large_A", "def": 1.4, "tint": Color(0.5, 0.65, 0.75)},
]
const TRINKET_BASES := ["Ring", "Charm", "Talisman", "Band", "Pendant"]
const SKINS := {
	"lizard": {"name": "Lizardfolk Hide", "desc": "Your skin turns to green scales. You feel... cold-blooded.", "min": 2, "affix": "hp"},
	"bone": {"name": "Bone Ward", "desc": "You become a walking skeleton. The dead nod at you politely.", "min": 2, "affix": "lifesteal"},
	"frost": {"name": "Frostbound Mantle", "desc": "Ice creeps over you. Your breath steams.", "min": 2, "affix": "mana"},
	"gold": {"name": "Gilded Visage", "desc": "You shine like a king's statue.", "min": 3, "affix": "crit"},
	"spectral": {"name": "Spectral Shroud", "desc": "You fade into a glowing ghost.", "min": 3, "affix": "regen"},
	"ember": {"name": "Ember Soul", "desc": "Fire lives under your skin. Sparks trail behind you.", "min": 3, "affix": "spell"},
}
## affix: [label, low, high, is_percent]
const AFFIXES := {
	"crit": ["crit chance", 3.0, 9.0, true],
	"lifesteal": ["life steal", 2.0, 6.0, true],
	"mana": ["max mana", 10.0, 35.0, false],
	"spell": ["spell power", 10.0, 35.0, true],
	"regen": ["mana regen /s", 1.0, 3.5, false],
	"hp": ["max health", 12.0, 45.0, false],
	"defense": ["defense", 2.0, 7.0, false],
	"damage": ["attack", 2.0, 6.0, false],
}
const SUFFIX := {"crit": "of Precision", "lifesteal": "of the Leech", "mana": "of the Owl", "spell": "of Embers",
	"regen": "of Tides", "hp": "of the Bear", "defense": "of the Turtle", "damage": "of Fury"}
const PREFIX := [["Worn", "Plain", "Iron"], ["Fine", "Sturdy", "Keen"], ["Runed", "Gleaming", "Tempered"],
	["Ancestral", "Stormforged", "Shadowsteel"], []]
const LEGEND_NAMES := {
	"weapon": ["Bobek's Fury", "Dawnbreaker", "Kingslayer", "Wyrmfang", "The Last Light", "Oathkeeper"],
	"armor": ["Bobek's Bulwark", "Aegis of Ashkar", "The Unbroken", "Starplate"],
	"artifact": ["Eye of the Deep", "Bobek's Lucky Sock", "Heart of Embers", "The Wanderer's Star"],
}

static var rng := RandomNumberGenerator.new()
static var _next := 1

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 4)]

## Item level from how deep in the dungeon (z) the loot appears.
static func area_level(z: float) -> int:
	if Game.zone == "forest":
		return 5 if z < -120.0 else 4    # the Goblin Forest, deeper in the Warren
	if z > -12.0: return 1
	if z > -60.0: return 2
	if z > -92.0: return 3
	if z > -134.0: return 4
	return 5

static func roll_rarity(luck := 0.0, floor_r := 0) -> int:
	var w := [55.0 / (1.0 + luck), 27.0, 12.0 * (1.0 + 0.6 * luck), 5.0 * (1.0 + luck), 1.2 * (1.0 + 1.5 * luck)]
	for i in floor_r:
		w[i] = 0.0
	var total := 0.0
	for x in w:
		total += x
	var r := rng.randf() * total
	for i in 5:
		r -= w[i]
		if r <= 0.0:
			return i
	return 4

static func _affix_value(key: String, ilvl: int, rarity: int) -> float:
	var a: Array = AFFIXES[key]
	var v: float = lerpf(a[1], a[2], rng.randf()) * (0.6 + 0.12 * ilvl) * (1.0 + 0.12 * rarity)
	return snappedf(v, 0.5 if a[3] else 1.0)

static func _add_affixes(it: Dictionary, pool: Array, n: int, ilvl: int) -> String:
	var keys := pool.duplicate()
	keys.shuffle()
	var first := ""
	for i in mini(n, keys.size()):
		var k: String = keys[i]
		it[k] = float(it.get(k, 0.0)) + _affix_value(k, ilvl, it.rarity)
		if first == "":
			first = k
	return first

static func _register(it: Dictionary) -> String:
	var uid := "g%d" % _next
	_next += 1
	it["uid"] = uid
	it["color"] = rarity_color(it.rarity)
	Game.items[uid] = it
	return uid

static func make_weapon(ilvl: int, rarity: int) -> String:
	var b: Dictionary = WEAPON_BASES[rng.randi() % WEAPON_BASES.size()]
	var it := {"slot": "weapon", "rarity": rarity, "model": b.model, "base": b.base}
	it["damage"] = roundf((2.0 + ilvl * 2.2) * RARITY_MULT[rarity] * b.dmg * rng.randf_range(0.85, 1.15))
	if b.spell > 0:
		it["spell"] = float(b.spell) * (0.8 + 0.2 * rarity)
	var first := _add_affixes(it, ["crit", "lifesteal", "mana", "spell", "regen", "hp"], RARITY_AFFIXES[rarity], ilvl)
	it["name"] = _name(it, b.base, first, "weapon")
	it["desc"] = "A %s %s." % [RARITY_NAMES[rarity].to_lower(), b.base.to_lower()]
	return _register(it)

static func make_armor(ilvl: int, rarity: int) -> String:
	var b: Dictionary = ARMOR_BASES[clampi(int(rng.randf_range(0.0, 2.2)) + int(ilvl / 2.0), 0, ARMOR_BASES.size() - 1)]
	var it := {"slot": "armor", "rarity": rarity, "shield": b.shield, "tint": b.tint, "base": b.base}
	it["defense"] = roundf((2.0 + ilvl * 2.2) * RARITY_MULT[rarity] * b.def * rng.randf_range(0.85, 1.15))
	var first := _add_affixes(it, ["hp", "mana", "regen", "crit", "lifesteal", "defense"], RARITY_AFFIXES[rarity], ilvl)
	it["name"] = _name(it, b.base, first, "armor")
	it["desc"] = "A %s set of %s." % [RARITY_NAMES[rarity].to_lower(), b.base.to_lower()]
	return _register(it)

static func make_trinket(ilvl: int, rarity: int) -> String:
	var base: String = TRINKET_BASES[rng.randi() % TRINKET_BASES.size()]
	var it := {"slot": "artifact", "rarity": rarity, "base": base}
	var first := _add_affixes(it, ["crit", "lifesteal", "mana", "spell", "regen", "hp", "damage", "defense"], RARITY_AFFIXES[rarity] + 1, ilvl)
	it["name"] = _name(it, base, first, "artifact")
	it["desc"] = "A %s %s, humming faintly." % [RARITY_NAMES[rarity].to_lower(), base.to_lower()]
	return _register(it)

static func make_skin(ilvl: int, rarity: int, which := "") -> String:
	var keys: Array = []
	for k in SKINS:
		if SKINS[k].min <= rarity:
			keys.append(k)
	if which == "" or not SKINS.has(which):
		which = keys[rng.randi() % keys.size()]
	var s: Dictionary = SKINS[which]
	rarity = maxi(rarity, s.min)
	var it := {"slot": "skin", "rarity": rarity, "skin": which, "base": "Skin", "name": s.name, "desc": s.desc}
	it[s.affix] = _affix_value(s.affix, ilvl, rarity)
	_add_affixes(it, ["hp", "mana", "regen", "crit"], rarity - 2, ilvl)
	return _register(it)

static func _name(it: Dictionary, base: String, first_affix: String, slot: String) -> String:
	var r: int = it.rarity
	if r == 4:
		var names: Array = LEGEND_NAMES[slot]
		return names[rng.randi() % names.size()]
	var pre: Array = PREFIX[r]
	var n: String = pre[rng.randi() % pre.size()] + " " + base
	if first_affix != "" and r >= 1:
		n += " " + SUFFIX[first_affix]
	return n

## One random item of any kind.
static func make_random(ilvl: int, luck := 0.0, floor_r := 0, kind := "") -> String:
	var r := roll_rarity(luck, floor_r)
	if kind == "":
		var x := rng.randf()
		kind = "weapon" if x < 0.36 else ("armor" if x < 0.68 else ("artifact" if x < 0.9 else "skin"))
	match kind:
		"weapon": return make_weapon(ilvl, r)
		"armor": return make_armor(ilvl, r)
		"skin": return make_skin(ilvl, maxi(r, 2))
	return make_trinket(ilvl, r)

# ---------------------------------------------------------------------------
# Drop tables. Each entry: {kind: "gold"|"potion"|"mana"|"item", amount, id}

static func _potions(out: Array, n: int, mana_bias := 0.4) -> void:
	for i in n:
		out.append({"kind": "mana" if rng.randf() < mana_bias else "potion", "amount": 1})

## Chest tiers: small, big, supply (before the boss), boss (after it), skin, weapon, armor.
static func roll_chest(tier: String, ilvl: int) -> Array:
	var out: Array = []
	match tier:
		"small":
			out.append({"kind": "gold", "amount": rng.randi_range(8, 25) * ilvl})
			_potions(out, rng.randi_range(1, 2))
			if rng.randf() < 0.7:
				out.append({"kind": "item", "id": make_random(ilvl, 0.3)})
		"big":
			out.append({"kind": "gold", "amount": rng.randi_range(20, 45) * ilvl})
			_potions(out, rng.randi_range(2, 3))
			out.append({"kind": "item", "id": make_random(ilvl, 0.8, 1)})
			if rng.randf() < 0.5:
				out.append({"kind": "item", "id": make_random(ilvl, 0.5)})
		"weapon", "armor":
			out.append({"kind": "gold", "amount": rng.randi_range(15, 35) * ilvl})
			_potions(out, 2)
			out.append({"kind": "item", "id": make_random(ilvl, 0.8, 1, tier)})
		"skin":
			out.append({"kind": "gold", "amount": rng.randi_range(10, 30) * ilvl})
			_potions(out, 1)
			out.append({"kind": "item", "id": make_random(ilvl, 1.0, 2, "skin")})
		"supply":
			out.append({"kind": "potion", "amount": 1}); out.append({"kind": "potion", "amount": 1})
			out.append({"kind": "mana", "amount": 1}); out.append({"kind": "mana", "amount": 1})
			_potions(out, rng.randi_range(0, 2), 0.5)
			if rng.randf() < 0.5:
				out.append({"kind": "item", "id": make_random(ilvl, 0.6, 1)})
		"boss":
			out.append({"kind": "gold", "amount": rng.randi_range(150, 300)})
			out.append({"kind": "item", "id": make_random(5, 2.0, 3)})
			out.append({"kind": "item", "id": make_random(5, 2.0, 2)})
	return out

## What a slain monster drops.
static func roll_enemy(type_name: String, ilvl: int) -> Array:
	var out: Array = []
	var t: Array = {"minion": [0.32, 0.1, 0.0], "warrior": [0.4, 0.18, 0.2], "mage": [0.45, 0.18, 0.2],
		"revenant": [1.0, 1.0, 1.0], "summon": [0.7, 0.04, 0.0]}.get(type_name, [0.3, 0.1, 0.0])
	if rng.randf() < t[0]:
		_potions(out, 2 if type_name == "revenant" else 1, 0.65 if type_name == "mage" else 0.4)
	if rng.randf() < t[1]:
		var floor_r := 1 if type_name == "revenant" else 0
		out.append({"kind": "item", "id": make_random(ilvl, t[2], floor_r)})
	return out

## Gold value when you salvage an item you don't want.
static func salvage_value(it: Dictionary) -> int:
	var r: int = it.get("rarity", 0)
	return (r + 1) * (r + 1) * 6
