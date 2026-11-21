extends Object
class_name ForgeRecipes
## THE FORGE: put three pieces of gear on the anvil and forge them into ONE piece
## of gear you can't find anywhere else. Forged gear can be forged again:
##
##   found gear x3      -> FORGED        (tier 1)
##   Forged x3          -> REFORGED      (tier 2:  9 found pieces)
##   Reforged x3        -> MASTERFORGED  (tier 3: 27 found pieces)
##   Masterforged x3    -> STARFORGED    (tier 4: 81 found pieces, the very best)
##
## (The new piece's tier is one more than the LOWEST tier you put in.)
##
## THE SECRET (players aren't told; the blacksmith only drops riddles):
## every piece of gear carries hidden ESSENCES, from its magic bonuses, the words
## in its name, and its look. The anvil adds up the essences of all three pieces.
## The strongest one, and the second strongest (if it's strong enough), decide
## what comes out. Same essences in, same kind of gear out (only the numbers vary).
##
## -------------------------------------------------------------------------------
## FOR JASON'S SON: make up your own secret recipes! Copy a line in RECIPES and change:
##   "id"        a short name with no spaces (must be different from the others)
##   "ess"       the two essences, e.g. ["fire", "light"]; the same one twice means
##               "almost all of that essence", e.g. ["storm", "storm"]
##   "tier"      the lowest tier it can be forged at (1 to 4)
##   "names"     what it's called as a weapon, as armor, and as a trinket
##   "power"     one of the powers in POWERS below
##   "hint"      the blacksmith's riddle for it
## Essences: fire, frost, storm, stone, beast, bone, light, shadow.
## -------------------------------------------------------------------------------
const RECIPES := [
	# the grand ones: Masterforged (tier 3) or better
	{"id": "phoenix", "ess": ["fire", "light"], "tier": 3, "power": "phoenix",
		"names": {"weapon": "Phoenix Blade", "armor": "Phoenix Plate", "artifact": "Phoenix Feather"},
		"hint": "When fire meets the sunrise, even falling down is only a nap."},
	{"id": "thunderking", "ess": ["storm", "light"], "tier": 3, "power": "thunderking",
		"names": {"weapon": "Thunderking's Blade", "armor": "Thunderking's Mail", "artifact": "Thunderking's Crown"},
		"hint": "Sunshine and thunder, crowned together, rule the whole sky."},
	{"id": "steam", "ess": ["fire", "frost"], "tier": 3, "power": "steam",
		"names": {"weapon": "Steamcleaver", "armor": "Steamheart Plate", "artifact": "Kettle of Clouds"},
		"hint": "Fire and ice, hammered as one, make the air too thick to see through."},
	{"id": "bonecaller", "ess": ["bone", "shadow"], "tier": 3, "power": "raise_dead",
		"names": {"weapon": "Bonecaller", "armor": "Gravelord's Mail", "artifact": "Skull of Many Friends"},
		"hint": "Bones and darkness never stay buried for long."},
	{"id": "moonfang", "ess": ["beast", "shadow"], "tier": 3, "power": "summon_wolf",
		"names": {"weapon": "Moonfang", "armor": "Moonfang Furs", "artifact": "Moonfang Collar"},
		"hint": "Fur under a midnight moon howls for a friend."},
	{"id": "stormcaller", "ess": ["storm", "storm"], "tier": 3, "power": "chain_lightning",
		"names": {"weapon": "Stormcaller", "armor": "Stormcaller's Mantle", "artifact": "Bottled Lightning"},
		"hint": "Thunder alone, folded thrice, never strikes just once."},
	{"id": "blazewalker", "ess": ["fire", "fire"], "tier": 3, "power": "fire_trail",
		"names": {"weapon": "Blazewalker", "armor": "Blazewalker Plate", "artifact": "Blazewalker Boots"},
		"hint": "Pure flame, folded thrice, leaves burning footprints."},
	{"id": "winters_heart", "ess": ["frost", "frost"], "tier": 3, "power": "frost_nova",
		"names": {"weapon": "Winter's Bite", "armor": "Winter's Heart", "artifact": "Snow Globe of Winter"},
		"hint": "Pure winter, folded thrice, freezes anyone who dares to hit you."},
	# Jason's idea: star boots for the slippery clouds (Reforged, tier 2)
	{"id": "starstride", "ess": ["light", "stone"], "tier": 2, "power": "sure_feet",
		"names": {"weapon": "Starstride Blade", "armor": "Starstride Greaves", "artifact": "Starstride Boots"},
		"hint": "Rock and starlight make the surest boots in the sky. No more slipping!"},
	# simple ones: almost all one essence, just Forged (tier 1)
	{"id": "emberblade", "ess": ["fire", "fire"], "tier": 1, "power": "burn_hit",
		"names": {"weapon": "Emberblade", "armor": "Ember Mail", "artifact": "Ember Charm"},
		"hint": "Three hot things make a hotter thing."},
	{"id": "rimefang", "ess": ["frost", "frost"], "tier": 1, "power": "frost_hit",
		"names": {"weapon": "Rimefang", "armor": "Rime Mail", "artifact": "Rime Charm"},
		"hint": "Three cold things make a colder thing."},
	{"id": "sparkblade", "ess": ["storm", "storm"], "tier": 1, "power": "spark_hit",
		"names": {"weapon": "Sparkblade", "armor": "Spark Mail", "artifact": "Spark Charm"},
		"hint": "Three crackling things make a crackle that jumps."},
	{"id": "rampart", "ess": ["stone", "stone"], "tier": 1, "power": "shockwave",
		"names": {"weapon": "Rampart Blade", "armor": "Rampart Plate", "artifact": "Rampart Stone"},
		"hint": "Three stony things make a shield that pushes back."},
	{"id": "wildheart", "ess": ["beast", "beast"], "tier": 1, "power": "wild_heart",
		"names": {"weapon": "Wildheart Axe", "armor": "Wildheart Furs", "artifact": "Wildheart Totem"},
		"hint": "Three wild things make a heart that heals itself."},
	{"id": "rattlebones", "ess": ["bone", "bone"], "tier": 1, "power": "thorns",
		"names": {"weapon": "Rattlebone Blade", "armor": "Rattlebone Mail", "artifact": "Rattlebone Charm"},
		"hint": "Three bony things make armor that bites back."},
	{"id": "dawnshard", "ess": ["light", "light"], "tier": 1, "power": "radiance",
		"names": {"weapon": "Dawnshard", "armor": "Dawnshard Mail", "artifact": "Dawnshard Charm"},
		"hint": "Three bright things make a light that heals the brave."},
	{"id": "nightveil", "ess": ["shadow", "shadow"], "tier": 1, "power": "shadow_veil",
		"names": {"weapon": "Nightveil Blade", "armor": "Nightveil Cloak", "artifact": "Nightveil Charm"},
		"hint": "Three dark things make a cloak to vanish in."},
]

## What each power does (the game code for each is in Powers, scripts/player/powers.gd).
const POWERS := {
	"burn_hit": "Your hits set foes on fire",
	"frost_hit": "Your hits chill foes and slow them down",
	"spark_hit": "Sparks sometimes jump from your hits to another foe",
	"shockwave": "Blocking a blow sends out a shockwave",
	"wild_heart": "You slowly heal by yourself",
	"thorns": "Foes that hit you get hurt back",
	"radiance": "Every foe you defeat heals you a little",
	"shadow_veil": "After you dodge, foes lose sight of you",
	"phoenix": "Rise from the ashes ONCE per level when you would fall",
	"thunderking": "Lightning strikes your foes from the sky",
	"steam": "When you're hit, a burst of steam hides you and scalds foes",
	"raise_dead": "Foes you defeat may rise to fight for you",
	"summon_wolf": "Foes you defeat may call a spirit wolf to your side",
	"chain_lightning": "Your hits chain lightning to up to 3 foes",
	"fire_trail": "You leave a trail of fire when you run",
	"frost_nova": "Big hits on you freeze the foes around you",
	"sure_feet": "No slipping on ice or wet clouds, and a third jump in the air",
}

## The small power each essence gives from Reforged (tier 2) up.
const MINOR := {"fire": "burn_hit", "frost": "frost_hit", "storm": "spark_hit", "stone": "shockwave",
	"beast": "wild_heart", "bone": "thorns", "light": "radiance", "shadow": "shadow_veil"}

const TIER_NAMES := ["", "Forged", "Reforged", "Masterforged", "Starforged"]
const TIER_COLORS := [Color(1, 1, 1), Color(0.95, 0.6, 0.32), Color(0.3, 0.95, 0.85), Color(1.0, 0.42, 0.65), Color(1.0, 0.94, 0.55)]
const MAX_TIER := 4
## Gold to forge into each tier.
const FEE := [0, 100, 300, 800, 2000]

const ESSENCES := ["fire", "frost", "storm", "stone", "beast", "bone", "light", "shadow"]
const ESSENCE_NAMES := {"fire": "Fire", "frost": "Frost", "storm": "Storm", "stone": "Stone", "beast": "Beast", "bone": "Bone", "light": "Light", "shadow": "Shadow"}
const ESSENCE_COLORS := {"fire": Color(1.0, 0.45, 0.15), "frost": Color(0.55, 0.9, 1.0), "storm": Color(0.7, 0.72, 1.0),
	"stone": Color(0.7, 0.62, 0.5), "beast": Color(0.55, 0.85, 0.3), "bone": Color(0.92, 0.88, 0.75),
	"light": Color(1.0, 0.92, 0.55), "shadow": Color(0.62, 0.35, 0.95)}
## The only clue the anvil gives you: what the glow smells like.
const WHISPERS := {"fire": "smoke", "frost": "fresh snow", "storm": "thunder", "stone": "deep earth", "beast": "wet fur",
	"bone": "old graves", "light": "sunrise", "shadow": "midnight"}
## Words for forged names.
const ADJ := {"fire": "Ember", "frost": "Frost", "storm": "Storm", "stone": "Stone", "beast": "Wild", "bone": "Bone", "light": "Dawn", "shadow": "Shadow"}

## Where essences come from (secret!).
const FROM_AFFIX := {"spell": "fire", "damage": "fire", "regen": "frost", "crit": "storm", "defense": "stone",
	"hp": "beast", "lifesteal": "shadow", "mana": "light"}
## Words in a gear's name or kind (matching the start or the end of a word).
const FROM_WORDS := {
	"bone": "bone", "skeleton": "bone", "ancestral": "bone", "grave": "bone", "necromancer": "bone",
	"spectral": "shadow", "ghost": "shadow", "phantom": "shadow", "wraith": "shadow", "shadow": "shadow",
	"kingslayer": "shadow", "night": "shadow", "ninja": "shadow",
	"moon": "light", "runed": "light", "gleaming": "light", "dawn": "light", "light": "light", "star": "light",
	"holy": "light", "aegis": "light", "cleric": "light", "paladin": "light",
	"storm": "storm", "thunder": "storm", "sky": "storm", "gale": "storm", "cloud": "storm", "keen": "storm",
	"rain": "frost", "frost": "frost", "tides": "frost", "deep": "frost", "ice": "frost", "rime": "frost",
	"ember": "fire", "fury": "fire", "tempered": "fire", "wyrm": "fire", "flame": "fire", "fire": "fire", "hellfire": "fire",
	"plate": "stone", "warden": "stone", "chain": "stone", "iron": "stone", "sturdy": "stone", "bulwark": "stone",
	"unbroken": "stone", "oath": "stone", "cuirass": "stone", "rampart": "stone",
	"leather": "beast", "furs": "beast", "lizard": "beast", "sock": "beast", "barbarian": "beast", "druid": "beast",
	"axe": "beast", "wild": "beast", "fang": "beast", "ranger": "beast",
}
const FROM_SKIN := {"lizard": "beast", "bone": "bone", "frost": "frost", "gold": "light", "spectral": "shadow", "ember": "fire"}
const FROM_FX := {"shadow": "shadow", "deathly": "frost", "infernal": "fire", "rot": "bone"}
## What a forged piece's bonuses lean towards.
const AFFIX_FOR := {"fire": "damage", "frost": "regen", "storm": "crit", "stone": "defense", "beast": "hp",
	"bone": "lifesteal", "light": "mana", "shadow": "lifesteal"}

## The smith's other riddles (once you've heard all the recipe riddles).
const LORE := [
	"Fury and embers burn just the same.",
	"Precision strikes like lightning.",
	"The Bear is wild at heart, and so is leather.",
	"The Turtle, the Warden and good plate all have hearts of stone.",
	"Tides run cold. So does anything from the deep.",
	"The Owl watches by the light of dawn.",
	"The Leech drinks in the dark.",
	"Old bones remember the grave, and so does anything a skeleton dropped.",
	"Ghosts and phantoms are made of shadow.",
	"Anything from the sky smells of storm.",
	"A forged piece remembers what it was made from.",
	"The strongest essence leads. The second one follows, if it's strong enough to keep up.",
	"Three of the same make a pure thing. Pure things are the strangest of all.",
	"Fold it three times and three times again, and it starts to shine like a star.",
]

static func power_text(tag: String) -> String:
	return String(POWERS.get(tag, tag))

static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}

# --- reading the essences in a piece of gear ---------------------------------------
static func essences(it: Dictionary) -> Dictionary:
	var out := {}
	if it.has("ess"):
		for k in it.ess:
			out[k] = float(it.ess[k])
		return out
	var slot := String(it.get("slot", ""))
	for k in FROM_AFFIX:
		# (a weapon's attack, armor's defense and a staff's spell power are just what
		# they are, not magic bonuses)
		if (k == "damage" and slot == "weapon") or (k == "defense" and slot == "armor") or (k == "spell" and String(it.get("model", "")) == "skel_staff"):
			continue
		if float(it.get(k, 0.0)) > 0.0:
			_add(out, FROM_AFFIX[k], 1.0)
	var text := ("%s %s %s" % [it.get("name", ""), it.get("base", ""), it.get("outfit", "")]).to_lower().replace("'", "").replace("/", " ")
	for w in text.split(" ", false):
		for key in FROM_WORDS:
			if w.begins_with(key) or (w.length() > key.length() + 2 and w.ends_with(key)):
				_add(out, FROM_WORDS[key], 1.0)
	if it.has("skin") and FROM_SKIN.has(it.skin):
		_add(out, FROM_SKIN[it.skin], 2.0)
	if it.has("fx") and FROM_FX.has(it.fx):
		_add(out, FROM_FX[it.fx], 1.0)
	if out.is_empty():
		# plain gear: weapons are hot from the smithy, armor is solid, trinkets shine
		_add(out, {"weapon": "fire", "armor": "stone", "artifact": "light"}.get(it.get("slot", ""), "beast"), 1.0)
	return out

static func _add(d: Dictionary, k: String, v: float) -> void:
	d[k] = float(d.get(k, 0.0)) + v

## The three pieces together: [strongest, second] (the same twice when one essence
## is much stronger than the rest), plus the totals.
static func reading(uids: Array) -> Dictionary:
	var tot := {}
	for u in uids:
		var e := essences(Game.item(String(u)))
		for k in e:
			_add(tot, k, float(e[k]))
	var order: Array = ESSENCES.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var va := float(tot.get(a, 0.0)); var vb := float(tot.get(b, 0.0))
		return va > vb if va != vb else ESSENCES.find(a) < ESSENCES.find(b))
	var a: String = order[0]
	var b: String = order[1]
	if float(tot.get(b, 0.0)) < float(tot.get(a, 0.0)) * 0.45:
		b = a
	return {"a": a, "b": b, "total": tot}

static func tier_of(uids: Array) -> int:
	var lo := MAX_TIER
	for u in uids:
		lo = mini(lo, int(Game.item(String(u)).get("tier", 0)))
	return mini(lo + 1, MAX_TIER)

## Which slot comes out: whatever most of the pieces are (skins just add essence).
static func slot_of(uids: Array) -> String:
	var n := {"weapon": 0, "armor": 0, "artifact": 0}
	var first := ""
	for u in uids:
		var s := String(Game.item(String(u)).get("slot", ""))
		if n.has(s):
			n[s] += 1
			if first == "":
				first = s
	var best := first if first != "" else "artifact"
	for s in ["weapon", "armor", "artifact"]:
		if int(n[s]) > int(n[best]):
			best = s
	return best

## The secret recipe these pieces make at this tier ({} = none: a plain forged piece).
static func match_recipe(a: String, b: String, tier: int) -> Dictionary:
	var best := {}
	for r in RECIPES:
		var e: Array = r.ess
		var hit: bool = (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a)
		if hit and int(r.tier) <= tier and (best.is_empty() or int(r.tier) > int(best.tier)):
			best = r
	return best

## What the anvil "says" about the pieces on it: a glow colour and a smell.
static func whisper(uids: Array) -> Dictionary:
	if uids.is_empty():
		return {"text": "The anvil is cold and quiet.", "color": Color(0.6, 0.6, 0.6)}
	var r := reading(uids)
	var a: String = r.a
	var b: String = r.b
	var col: Color = ESSENCE_COLORS[a].lerp(ESSENCE_COLORS[b], 0.35)
	var text := "The anvil glows... it smells of %s." % WHISPERS[a] if a == b else "The anvil glows... it smells of %s and %s." % [WHISPERS[a], WHISPERS[b]]
	return {"text": text, "color": col}

## Can these pieces be forged? "" if yes, otherwise why not.
static func why_not(uids: Array) -> String:
	if uids.size() < 3:
		return "Put three pieces of gear on the anvil."
	for u in uids:
		if not usable(String(u)):
			return "One of those can't go on the anvil."
	if Game.gold < FEE[tier_of(uids)]:
		return "You need %d gold for the smith." % FEE[tier_of(uids)]
	return ""

## Gear that can go on the anvil: in your bag or the gear chest, not worn, not
## a quest item or one of the special starting pieces.
static func usable(uid: String) -> bool:
	var it := Game.item(uid)
	return not it.is_empty() and (Game.inventory.has(uid) or Game.stash.has(uid)) and not Game.equipped.values().has(uid) \
		and String(it.get("slot", "")) in ["weapon", "armor", "artifact", "skin"] and not Game.ITEMS.has(uid)

## Forge three pieces into one. Returns the new piece's id ("" if it can't).
static func forge(uids: Array) -> String:
	if why_not(uids) != "":
		return ""
	var tier := tier_of(uids)
	var r := reading(uids)
	var a: String = r.a
	var b: String = r.b
	var slot := slot_of(uids)
	var rec := match_recipe(a, b, tier)
	var lv := 1
	var wpn := {}
	var arm := {}
	for u in uids:
		var it := Game.item(String(u))
		lv = maxi(lv, est_ilvl(it))
		if it.get("slot", "") == "weapon" and wpn.is_empty():
			wpn = it
		if it.get("slot", "") == "armor" and arm.is_empty():
			arm = it
	var ilvl := lv + tier
	var k := 1.0 + 0.12 * tier
	var rng := Loot.rng
	var it := {"slot": slot, "rarity": 4, "tier": tier, "ilvl": ilvl, "forged": true}
	var noun := ""
	match slot:
		"weapon":
			it["model"] = String(wpn.get("model", "sword_1handed"))
			noun = String(wpn.get("base", "Longsword"))
			it["base"] = noun
			it["damage"] = roundf((2.0 + ilvl * 2.2) * Loot.RARITY_MULT[4] * 1.3 * rng.randf_range(0.95, 1.1) * k)
			if it.model == "skel_staff":
				it["spell"] = 40.0 + 15.0 * tier
		"armor":
			it["shield"] = String(arm.get("shield", "shield_square_color"))
			noun = String(arm.get("base", "Plate"))
			it["base"] = noun
			it["tint"] = ESSENCE_COLORS[a].lerp(Color(0.8, 0.8, 0.85), 0.3)
			if arm.has("outfit"):
				it["outfit"] = arm.outfit
			it["defense"] = roundf((2.0 + ilvl * 2.2) * Loot.RARITY_MULT[4] * 1.45 * rng.randf_range(0.95, 1.1) * k)
		_:
			noun = ["Charm", "Talisman", "Amulet", "Band"][ESSENCES.find(a) % 4]
			it["base"] = noun
	# bonuses that lean towards the essences (stronger at each tier)
	var keys: Array = [AFFIX_FOR[a], AFFIX_FOR[b]]
	var pool: Array = ["hp", "crit", "lifesteal", "regen", "mana", "defense" if slot != "armor" else "hp", "damage" if slot != "weapon" else "crit"]
	while keys.size() < 2 + tier:
		var x: String = pool[rng.randi() % pool.size()]
		keys.append(x)
	for key0 in keys:
		var key := String(key0)
		it[key] = float(it.get(key, 0.0)) + snappedf(Loot._affix_value(key, ilvl, 4) * k, 0.5)
	# the name and the power
	if not rec.is_empty():
		it["name"] = String((rec.names as Dictionary).get(slot, rec.id))
		it["power"] = String(rec.power)
		it["recipe"] = String(rec.id)
	else:
		it["name"] = ("%s %s" % [ADJ[a], noun]) if a == b else ("%s%s %s" % [ADJ[a], ADJ[b].to_lower(), noun])
		if tier >= 2:
			it["power"] = String(MINOR[a])
	if tier >= 4 and String(MINOR[b]) != String(it.get("power", "")):
		it["power2"] = String(MINOR[b])       # Starforged: a second power
	var ess := {a: 2.0}
	if b != a:
		ess[b] = 1.0
	it["ess"] = ess
	it["desc"] = "%s on the anvil at home, from %s." % [TIER_NAMES[tier], ESSENCE_NAMES[a] if a == b else "%s and %s" % [ESSENCE_NAMES[a], ESSENCE_NAMES[b]]]
	# pay the smith, and the three pieces become one
	Game.gold -= FEE[tier]
	for u in uids:
		Game.inventory.erase(String(u))
		Game.stash.erase(String(u))
	var uid := Loot._register(it)
	it["color"] = TIER_COLORS[tier]
	Game.inventory.append(uid)
	if not rec.is_empty() and not (Game.forge_book.found as Array).has(rec.id):
		(Game.forge_book.found as Array).append(rec.id)
	Game.inventory_changed.emit(); Game.stats_changed.emit()
	return uid

## Is this a big one (a golden flash)?
static func is_grand(uid: String) -> bool:
	var it := Game.item(uid)
	return int(it.get("tier", 0)) >= 3 or (it.has("recipe") and int(recipe(String(it.recipe)).get("tier", 1)) >= 2)

## A rough item level for gear found before items remembered theirs.
static func est_ilvl(it: Dictionary) -> int:
	if it.has("ilvl"):
		return int(it.ilvl)
	var r := clampi(int(it.get("rarity", 0)), 0, 4)
	if float(it.get("damage", 0.0)) > 0.0 and it.get("slot", "") == "weapon":
		return clampi(int(round((float(it.damage) / (Loot.RARITY_MULT[r] * 1.2) - 2.0) / 2.2)), 1, 20)
	if float(it.get("defense", 0.0)) > 0.0 and it.get("slot", "") == "armor":
		return clampi(int(round((float(it.defense) / (Loot.RARITY_MULT[r] * 1.2) - 2.0) / 2.2)), 1, 20)
	return 2 + r * 2

# --- the blacksmith's riddles --------------------------------------------------------
## The next riddle: one for a recipe you haven't found (and haven't heard yet),
## otherwise a bit of forge lore.
static func next_hint() -> String:
	var heard: Array = Game.forge_book.hints
	var found: Array = Game.forge_book.found
	for r in RECIPES:
		if not found.has(r.id) and not heard.has(r.id):
			heard.append(r.id)
			return String(r.hint)
	return String(LORE[randi() % LORE.size()])
