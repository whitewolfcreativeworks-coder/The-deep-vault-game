extends RefCounted
class_name GardenPlants
## THE GARDEN (Jason and his son, Nov 25): what you can grow in your garden at
## home (HomeGarden), where the seeds come from, and what each one gives you.
##
##   vegetables  go in your harvest basket. Eat them at the cabin's table for a
##               home-grown meal (a long buff), or sell them to Tobble.
##   flowers     bouquets for the basket: Tobble pays well for them.
##   magic       grow your own potions! Their seeds are rare: boss chests, and
##               now and then a lucky chest. (Tobble doesn't sell them.)
##
## A plant grows while you play anywhere (minutes of PLAY, like the shop's elixirs),
## and twice as fast while its soil is wet: water it (USE) whenever you pass.
## Easy to change: add a line here and give it a look in HomeGarden._plant_look.

const PLANTS := {
	"carrot": {"name": "Carrots", "seed": "Carrot Seeds", "kind": "veg", "mins": 3.0, "yield": 3, "price": 15, "sell": 6,
		"color": Color(1.0, 0.5, 0.1), "buff": "quick", "line": "Crunchy carrots. They make you QUICK!"},
	"tomato": {"name": "Tomatoes", "seed": "Tomato Seeds", "kind": "veg", "mins": 5.0, "yield": 3, "price": 25, "sell": 9,
		"color": Color(0.9, 0.15, 0.12), "buff": "strong", "line": "Juicy red tomatoes. They make you STRONG!"},
	"pumpkin": {"name": "Pumpkin", "seed": "Pumpkin Seeds", "kind": "veg", "mins": 8.0, "yield": 1, "price": 50, "sell": 45,
		"color": Color(1.0, 0.55, 0.12), "buff": "tough", "line": "One giant pumpkin. Pumpkin soup makes you TOUGH!"},
	"sunflower": {"name": "Sunflower", "seed": "Sunflower Seeds", "kind": "flower", "mins": 4.0, "yield": 1, "price": 20, "sell": 30,
		"color": Color(1.0, 0.85, 0.15), "line": "A sunflower taller than you!"},
	"rose": {"name": "Roses", "seed": "Rose Seeds", "kind": "flower", "mins": 3.5, "yield": 2, "price": 25, "sell": 18,
		"color": Color(0.95, 0.25, 0.45), "line": "A bunch of pink roses."},
	"moonpetal": {"name": "Moonpetal", "seed": "Moonpetal Seed", "kind": "magic", "mins": 10.0, "yield": 2, "sell": 0,
		"color": Color(0.65, 0.8, 1.0), "gives": "mana", "line": "Glowing silver petals: two MANA POTIONS!"},
	"heartberry": {"name": "Heartberry Bush", "seed": "Heartberry Seed", "kind": "magic", "mins": 10.0, "yield": 2, "sell": 0,
		"color": Color(1.0, 0.2, 0.35), "gives": "potion", "line": "Little red hearts: two HEALING DRAUGHTS!"},
	"fireblossom": {"name": "Fire Blossom", "seed": "Fire Blossom Seed", "kind": "magic", "mins": 12.0, "yield": 2, "sell": 0,
		"color": Color(1.0, 0.45, 0.1), "gives": "stamina", "line": "A flower made of flame: two ENERGY POTIONS!"},
	"glowcap": {"name": "Glowcaps", "seed": "Glowcap Spores", "kind": "magic", "mins": 8.0, "yield": 3, "sell": 0,
		"color": Color(0.4, 1.0, 0.75), "gives": "mana", "line": "Glowing mushrooms: three MANA POTIONS!"},
}
const COMMON := ["carrot", "tomato", "pumpkin", "sunflower", "rose"]
const MAGIC := ["moonpetal", "heartberry", "fireblossom", "glowcap"]
const KIND_NAMES := {"veg": "Vegetables", "flower": "Flowers", "magic": "Magic plants"}
## The seeds waiting in the seed box by the gate, the first time you visit.
const STARTER := {"carrot": 3, "sunflower": 2, "tomato": 2, "pumpkin": 1}
const WET_SECS := 120.0          # watering: the soil stays wet (double speed) this long
const BUFF_SECS := 300.0         # a home-grown meal: five minutes of play

static func plant_name(id: String) -> String:
	return String(PLANTS.get(id, {}).get("name", id))

static func seed_name(id: String) -> String:
	return String(PLANTS.get(id, {}).get("seed", id))

static func grow_secs(id: String) -> float:
	return float(PLANTS.get(id, {}).get("mins", 5.0)) * 60.0

## A seed for a chest: mostly common ones, and now and then a magic one.
static func roll_seed(rng: RandomNumberGenerator, magic_chance := 0.08) -> String:
	if rng.randf() < magic_chance:
		return MAGIC[rng.randi() % MAGIC.size()]
	return COMMON[rng.randi() % COMMON.size()]
