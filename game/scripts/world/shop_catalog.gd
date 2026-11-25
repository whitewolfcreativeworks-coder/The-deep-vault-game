extends Object
class_name ShopCatalog
## TOBBLE'S TRADING POST: what's for sale, what it costs, and selling your gear.
## (Jason and his son, Nov 20: "a place you can go and spend your gold". Things
## you buy are TEMPORARY: "they fade". No loot boxes, no paying for Port Home or
## for coming back to life.)
##
## Kinds:
##   elixir    a drink with a timed effect; elixirs mix freely
##   enchant   a timed magic edge on your weapon (one at a time)
##   bless     a timed blessing on your armor (one at a time)
##   costume   a shop-only costume for a whole real day (see Loot.COSTUMES "shop")
##   deco      something for your yard at home; yours to keep
##
## Times are minutes of PLAY (they don't run down while the game is closed);
## costumes count real hours, like the costumes you find.
## Easy to change: add a line, and give it a "use" in the game if it's new.

const WARES := [
	# --- elixirs
	{"id": "triple_jump", "kind": "elixir", "name": "Triple Jump Elixir", "short": "Triple Jump", "price": 300, "mins": 10,
		"desc": "Jump a THIRD time in the air: tap jump again at the top of your double jump.", "color": Color(0.55, 0.85, 1.0)},
	{"id": "swift_feet", "kind": "elixir", "name": "Swift Feet Elixir", "short": "Swift Feet", "price": 250, "mins": 10,
		"desc": "Run a quarter faster.", "color": Color(0.5, 1.0, 0.6)},
	{"id": "giant_strength", "kind": "elixir", "name": "Giant Strength Elixir", "short": "Giant Strength", "price": 600, "mins": 10,
		"desc": "Hit 30% harder.", "color": Color(1.0, 0.45, 0.3)},
	{"id": "lucky_coin", "kind": "elixir", "name": "Lucky Coin", "short": "Lucky Coin", "price": 400, "mins": 15,
		"desc": "Gold you pick up is worth half as much again.", "color": Color(1.0, 0.85, 0.3)},
	# --- weapon enchantments
	{"id": "flame_edge", "kind": "enchant", "name": "Flame Edge", "short": "Flame Edge", "price": 500, "mins": 15,
		"desc": "Your weapon sets foes on fire: they keep burning after you hit them.", "color": Color(1.0, 0.5, 0.15)},
	{"id": "frost_edge", "kind": "enchant", "name": "Frost Edge", "short": "Frost Edge", "price": 500, "mins": 15,
		"desc": "Your weapon chills foes to the bone: they slow right down.", "color": Color(0.55, 0.9, 1.0)},
	{"id": "storm_edge", "kind": "enchant", "name": "Lightning Edge", "short": "Lightning Edge", "price": 700, "mins": 15,
		"desc": "Now and then, lightning leaps from your weapon to another foe nearby.", "color": Color(0.75, 0.8, 1.0)},
	# --- armor blessings
	{"id": "stoneskin", "kind": "bless", "name": "Stoneskin Blessing", "short": "Stoneskin", "price": 600, "mins": 15,
		"desc": "Your skin turns tough as stone: you take a quarter less damage.", "color": Color(0.75, 0.7, 0.6)},
	{"id": "thorns", "kind": "bless", "name": "Thorns Blessing", "short": "Thorns", "price": 450, "mins": 15,
		"desc": "Foes that hit you get hurt back.", "color": Color(0.5, 0.85, 0.35)},
	{"id": "fireproof", "kind": "bless", "name": "Fireproof Blessing", "short": "Fireproof", "price": 800, "mins": 15,
		"desc": "Fire and lava burn you only HALF as much. (Very handy in Insane!)", "color": Color(1.0, 0.65, 0.3)},
	# --- costumes you can only get here
	{"id": "golden_knight", "kind": "costume", "name": "Golden Knight", "price": 3000, "hours": 24,
		"desc": "Shining gold armor from head to toe.", "color": Color(1.0, 0.82, 0.35)},
	{"id": "star_mage", "kind": "costume", "name": "Star Mage", "price": 3500, "hours": 24,
		"desc": "Robes woven from starlight.", "color": Color(0.75, 0.82, 1.0)},
	{"id": "frost_ninja", "kind": "costume", "name": "Frost Ninja", "price": 2500, "hours": 24,
		"desc": "An icy ninja, silent as snowfall.", "color": Color(0.6, 0.92, 1.0)},
	{"id": "candy_clown", "kind": "costume", "name": "Candy Clown", "price": 2000, "hours": 24,
		"desc": "Pink, sparkly and very silly.", "color": Color(1.0, 0.6, 0.88)},
	{"id": "golden_dino", "kind": "costume", "name": "Golden Dino", "price": 6000, "hours": 24,
		"desc": "A dinosaur suit made of solid gold. RAWR!", "color": Color(1.0, 0.78, 0.25)},
	# --- for your yard at home (yours to keep)
	{"id": "flower_garden", "kind": "deco", "name": "Flower Beds", "price": 1000,
		"desc": "Bright flower beds in front of your cabin.", "color": Color(1.0, 0.55, 0.7)},
	{"id": "twinkle_lights", "kind": "deco", "name": "Twinkle Lights", "price": 1500,
		"desc": "Strings of little coloured lights along the path to the portal.", "color": Color(1.0, 0.9, 0.5)},
	{"id": "gnome", "kind": "deco", "name": "Garden Gnome", "price": 800,
		"desc": "A cheerful gnome to guard your pumpkins.", "color": Color(0.9, 0.3, 0.25)},
	{"id": "bench", "kind": "deco", "name": "Garden Bench", "price": 600,
		"desc": "A bench by the garden. Sit and watch the clouds.", "color": Color(0.7, 0.5, 0.3)},
	{"id": "bird_bath", "kind": "deco", "name": "Bird Bath", "price": 1200,
		"desc": "A stone bird bath. More birds will come and sing.", "color": Color(0.6, 0.85, 1.0)},
	{"id": "statue", "kind": "deco", "name": "Golden Statue of YOU", "price": 12000,
		"desc": "A giant golden statue of your hero, right in the yard. The ultimate trophy!", "color": Color(1.0, 0.8, 0.3)},
	# --- seeds for your garden (magic seeds can't be bought: find them!)
	{"id": "seed_carrot", "kind": "seed", "plant": "carrot", "name": "Carrot Seeds", "price": 15,
		"desc": "Three crunchy carrots in 3 minutes. Carrots make you QUICK!", "color": Color(1.0, 0.55, 0.15)},
	{"id": "seed_tomato", "kind": "seed", "plant": "tomato", "name": "Tomato Seeds", "price": 25,
		"desc": "Three juicy tomatoes in 5 minutes. Tomatoes make you STRONG!", "color": Color(0.95, 0.25, 0.2)},
	{"id": "seed_pumpkin", "kind": "seed", "plant": "pumpkin", "name": "Pumpkin Seeds", "price": 50,
		"desc": "One giant pumpkin in 8 minutes. Pumpkin soup makes you TOUGH!", "color": Color(1.0, 0.6, 0.2)},
	{"id": "seed_sunflower", "kind": "seed", "plant": "sunflower", "name": "Sunflower Seeds", "price": 20,
		"desc": "A sunflower taller than you, in 4 minutes. I'll buy it for 30 gold!", "color": Color(1.0, 0.85, 0.2)},
	{"id": "seed_rose", "kind": "seed", "plant": "rose", "name": "Rose Seeds", "price": 25,
		"desc": "Two pink roses in 3 and a half minutes. I'll buy them for 18 gold each!", "color": Color(1.0, 0.45, 0.65)},
]

const KIND_NAMES := {"elixir": "Elixirs", "enchant": "Weapon Enchantments", "bless": "Armor Blessings",
	"costume": "Costumes", "deco": "For Your Yard", "seed": "Seeds"}

static func ware(id: String) -> Dictionary:
	for w in WARES:
		if w.id == id:
			return w
	return {}

static func of_kind(kind: String) -> Array:
	return WARES.filter(func(w: Dictionary) -> bool: return w.kind == kind)

## Today's Special: one thing at half price, a different one each day.
static func special_id(day := -1) -> String:
	if day < 0:
		day = int(Time.get_unix_time_from_system() / 86400.0)
	var pool: Array = WARES.filter(func(w: Dictionary) -> bool: return w.kind != "deco" and w.kind != "seed")
	return String(pool[posmod(day * 7 + 3, pool.size())].id)

static func price(id: String) -> int:
	var w := ware(id)
	var p := int(w.get("price", 0))
	return p / 2 if id == special_id() else p

## Can you buy it right now? "" if yes, otherwise why not.
static func why_not(id: String) -> String:
	var w := ware(id)
	if w.is_empty():
		return "?"
	if w.kind == "deco" and Game.decor.has(id):
		return "In your yard"
	if Game.gold < price(id):
		return "Not enough gold"
	return ""

## Buy it: takes the gold and puts the magic on. Returns true if bought.
static func buy(id: String) -> bool:
	if why_not(id) != "":
		return false
	var w := ware(id)
	Game.gold -= price(id)
	match String(w.kind):
		"elixir", "enchant", "bless":
			Game.add_boon(id, float(w.mins) * 60.0)
			Game.say("%s! (%d minutes)" % [w.name, int(w.mins)], w.color)
		"costume":
			Game.wear_costume(id, [0, float(w.hours) * 3600.0, true, "a whole day"])
		"deco":
			Game.decor.append(id)
			Game.say("Tobble will set up the %s in your yard!" % String(w.name).to_lower(), w.color)
		"seed":
			Game.add_seeds(String(w.plant), 1)
			Game.say("%s! Plant them in your garden." % String(w.name), w.color)
	Sfx.play("coins", -4.0, 0.1)
	Game.stats_changed.emit()
	Game.inventory_changed.emit()
	return true

# --- selling ----------------------------------------------------------------------
## Your harvest basket: what Tobble would pay for the lot (vegetables and flowers).
static func harvest_value() -> int:
	var g := 0
	for id in Game.basket:
		g += int(GardenPlants.PLANTS.get(id, {}).get("sell", 0)) * int(Game.basket[id])
	return g

static func sell_harvest() -> int:
	var g := harvest_value()
	Game.basket.clear()
	Game.gold += g
	Game.inventory_changed.emit(); Game.stats_changed.emit()
	return g

## Tobble pays twice what you'd get for salvaging it out in the wild (forged gear more).
static func sell_value(uid: String) -> int:
	var it := Game.item(uid)
	var v := Loot.salvage_value(it) * 2
	if int(it.get("tier", 0)) > 0:
		v = 150 * int(pow(3.0, float(int(it.tier) - 1)))
	return v

static func can_sell(uid: String) -> bool:
	var it := Game.item(uid)
	return not it.is_empty() and Game.inventory.has(uid) and not Game.equipped.values().has(uid) \
		and it.get("slot", "") != "quest" and not Game.ITEMS.has(uid)

static func sell(uid: String) -> int:
	if not can_sell(uid):
		return 0
	var g := sell_value(uid)
	Game.inventory.erase(uid)
	Game.gold += g
	Game.inventory_changed.emit(); Game.stats_changed.emit()
	return g

## "Sell everything I'm not using": what that would sell (it keeps forged and
## legendary gear, just in case).
static func junk() -> Array:
	var out: Array = []
	for uid in Game.inventory:
		var it := Game.item(uid)
		if can_sell(uid) and int(it.get("tier", 0)) == 0 and int(it.get("rarity", 0)) < 4:
			out.append(uid)
	return out
