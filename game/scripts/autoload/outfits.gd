extends RefCounted
class_name Outfits
## THE WARDROBE (designed by Jason's son, Nov 25): the cabinet in your cabin, the
## one you change in at the very start of the opening movie. It keeps your
## OUTFITS and your SHOES & SLIPPERS, and you can change in it whenever you're
## home. Put your pajamas back on, wear bunny slippers to fight a goblin chief, or
## put on your work clothes for building, the forge, the garden, fishing or
## cooking.
##
## Every hero has their own wardrobe (it's saved with the hero), and each class
## starts with different things in it. Outfits are only a look: they never change
## your health, damage or defence, so every class stays fair. A magic costume
## (from a chest or Tobble's shop) still goes on top while it lasts.
##
## More outfits can be given with Game.grant_outfit(id) / grant_footwear(id) (the
## open world will have some to find).
##
## An outfit is your hero's own body recoloured (colour, pattern), with the hat
## or helmet off and maybe something on the head or round the middle (see
## CharacterModel._outfit_extras). Footwear goes on over your boots
## (CharacterModel._footwear).

const GROUPS := ["adventure", "bedtime", "fun", "work"]
const GROUP_NAMES := {"adventure": "ADVENTURING", "bedtime": "BEDTIME", "fun": "JUST FOR FUN", "work": "WORK CLOTHES"}

## pattern: "" | "stripes" | "dots" | "checks" | "stars"
## hat: "" | "nightcap" | "toadstool" | "bear" | "cat" | "bunny" | "lamb" | "frog" | "horns" | "hardhat" | "goggles" | "sunhat" | "rainhat" | "chefhat"
## belt: "" | "toolbelt" | "apron"
const OUTFITS := {
	"adventure": {"group": "adventure", "name": "Adventuring Clothes", "line": "Your trusty adventuring gear. Ready for anything!"},
	"pajamas": {"group": "bedtime", "name": "Striped Pajamas", "color": Color(0.45, 0.6, 0.95), "pattern": "stripes",
		"pattern_color": Color(0.95, 0.95, 1.0), "line": "The very ones you woke up in. So cosy!"},
	# --- each class's own bedtime wear...
	"knight_nightshirt": {"group": "bedtime", "name": "Royal Nightshirt", "color": Color(0.66, 0.1, 0.13), "pattern": "stars",
		"pattern_color": Color(1.0, 0.82, 0.3), "hat": "nightcap", "hat_color": Color(0.66, 0.1, 0.13), "trim": Color(1.0, 0.82, 0.3),
		"line": "Fit for a sleepy king. The nightcap has a golden bobble."},
	"barbarian_lumberjack": {"group": "bedtime", "name": "Lumberjack PJs", "color": Color(0.75, 0.12, 0.1), "pattern": "checks",
		"pattern_color": Color(0.12, 0.1, 0.1), "line": "Red and black checks. Warm enough for the far north."},
	"rogue_midnight": {"group": "bedtime", "name": "Midnight PJs", "color": Color(0.25, 0.15, 0.45), "pattern": "stars",
		"pattern_color": Color(0.85, 0.88, 1.0), "hat": "nightcap", "hat_color": Color(0.25, 0.15, 0.45), "trim": Color(0.85, 0.88, 1.0),
		"line": "Dark as the night sky. Perfect for sneaking to the kitchen."},
	"ranger_leafy": {"group": "bedtime", "name": "Leafy PJs", "color": Color(0.22, 0.5, 0.24), "pattern": "stripes",
		"pattern_color": Color(0.62, 0.84, 0.42), "line": "Green as the forest. You could sleep in a tree."},
	"mage_starry": {"group": "bedtime", "name": "Starry Night Robe", "color": Color(0.12, 0.16, 0.42), "pattern": "stars",
		"pattern_color": Color(1.0, 0.85, 0.35), "hat": "nightcap", "hat_color": Color(0.12, 0.16, 0.42), "trim": Color(1.0, 0.85, 0.35),
		"line": "Every star on it twinkles a little. Probably magic."},
	"priest_cloudy": {"group": "bedtime", "name": "Cloudy PJs", "color": Color(0.55, 0.75, 0.98), "pattern": "dots",
		"pattern_color": Color(0.98, 0.98, 1.0), "line": "Soft as a cloud, blue as a summer sky."},
	"druid_toadstool": {"group": "bedtime", "name": "Toadstool PJs", "color": Color(0.82, 0.15, 0.12), "pattern": "dots",
		"pattern_color": Color(0.98, 0.96, 0.9), "hat": "toadstool", "hat_color": Color(0.82, 0.15, 0.12), "trim": Color(0.98, 0.96, 0.9),
		"line": "Red with white spots, and a mushroom cap to match."},
	"necro_skeleton": {"group": "bedtime", "name": "Skeleton PJs", "color": Color(0.1, 0.1, 0.12), "pattern": "stripes",
		"pattern_color": Color(0.92, 0.9, 0.82), "hat": "nightcap", "hat_color": Color(0.1, 0.1, 0.12), "trim": Color(0.92, 0.9, 0.82),
		"line": "Black with bony white stripes. Spooky, but comfy."},
	"beast_wolf": {"group": "bedtime", "name": "Wolf PJs", "color": Color(0.5, 0.52, 0.56), "pattern": "dots",
		"pattern_color": Color(0.26, 0.26, 0.3), "line": "Grey with paw prints all over. Awoo... yawn."},
	# --- ...and a onesie just for fun
	"knight_dragon": {"group": "fun", "name": "Dragon Onesie", "color": Color(0.3, 0.62, 0.28), "pattern": "dots",
		"pattern_color": Color(0.7, 0.9, 0.45), "hat": "horns", "hat_color": Color(0.98, 0.9, 0.6), "line": "Little horns and green scales. RAWR!"},
	"barbarian_bear": {"group": "fun", "name": "Bear Onesie", "color": Color(0.48, 0.3, 0.18), "hat": "bear", "hat_color": Color(0.48, 0.3, 0.18),
		"trim": Color(0.85, 0.68, 0.5), "line": "A big brown bear, with round ears. Grrr!"},
	"rogue_cat": {"group": "fun", "name": "Black Cat Onesie", "color": Color(0.13, 0.12, 0.15), "hat": "cat", "hat_color": Color(0.13, 0.12, 0.15),
		"trim": Color(1.0, 0.6, 0.7), "line": "Pointy ears and silent paws. Meow."},
	"ranger_fox": {"group": "fun", "name": "Fox Onesie", "color": Color(0.92, 0.45, 0.12), "hat": "cat", "hat_color": Color(0.92, 0.45, 0.12),
		"trim": Color(0.98, 0.95, 0.9), "line": "Clever, quick and very orange."},
	"mage_bunny": {"group": "fun", "name": "Magic Bunny Onesie", "color": Color(0.95, 0.95, 0.97), "pattern": "dots",
		"pattern_color": Color(1.0, 0.75, 0.85), "hat": "bunny", "hat_color": Color(0.97, 0.97, 0.99), "trim": Color(1.0, 0.7, 0.82),
		"line": "Every wizard needs a rabbit. Now you ARE the rabbit."},
	"priest_lamb": {"group": "fun", "name": "Fluffy Lamb Onesie", "color": Color(0.96, 0.94, 0.88), "pattern": "dots",
		"pattern_color": Color(1.0, 1.0, 1.0), "hat": "lamb", "hat_color": Color(0.96, 0.94, 0.88), "trim": Color(0.3, 0.26, 0.24),
		"line": "Woolly, white and very huggable. Baa!"},
	"druid_frog": {"group": "fun", "name": "Frog Onesie", "color": Color(0.35, 0.72, 0.25), "pattern": "dots",
		"pattern_color": Color(0.2, 0.48, 0.16), "hat": "frog", "hat_color": Color(0.35, 0.72, 0.25), "line": "Big froggy eyes on top. Ribbit!"},
	"necro_bat": {"group": "fun", "name": "Bat Onesie", "color": Color(0.22, 0.13, 0.28), "hat": "cat", "hat_color": Color(0.22, 0.13, 0.28),
		"trim": Color(0.62, 0.3, 0.55), "big_ears": true, "line": "Big pointy bat ears. Flap flap!"},
	"beast_tiger": {"group": "fun", "name": "Tiger Onesie", "color": Color(0.95, 0.55, 0.1), "pattern": "stripes",
		"pattern_color": Color(0.1, 0.08, 0.06), "hat": "cat", "hat_color": Color(0.95, 0.55, 0.1), "trim": Color(0.98, 0.95, 0.9),
		"line": "Orange with black stripes. Hear me ROAR!"},
	# --- work clothes for home (everybody has these)
	"work_builder": {"group": "work", "name": "Builder's Overalls", "color": Color(0.26, 0.42, 0.72), "hat": "hardhat", "hat_color": Color(1.0, 0.8, 0.1),
		"belt": "toolbelt", "belt_color": Color(0.45, 0.3, 0.16), "line": "Hard hat on, tools on your belt. Time to build!"},
	"work_smith": {"group": "work", "name": "Smith's Apron", "color": Color(0.32, 0.3, 0.29), "hat": "goggles", "hat_color": Color(0.35, 0.24, 0.14),
		"belt": "apron", "belt_color": Color(0.45, 0.28, 0.15), "line": "A thick leather apron and goggles, for the heat of the forge."},
	"work_gardener": {"group": "work", "name": "Gardener's Dungarees", "color": Color(0.36, 0.56, 0.3), "pattern": "checks",
		"pattern_color": Color(0.3, 0.48, 0.26), "hat": "sunhat", "hat_color": Color(0.92, 0.8, 0.48), "trim": Color(0.75, 0.25, 0.2),
		"line": "Green dungarees and a straw sun hat, for digging and planting."},
	"work_fisher": {"group": "work", "name": "Fishing Gear", "color": Color(0.98, 0.8, 0.12), "hat": "rainhat", "hat_color": Color(0.98, 0.8, 0.12),
		"line": "A big yellow raincoat and rain hat. Let it pour!"},
	"work_chef": {"group": "work", "name": "Chef's Whites", "color": Color(0.96, 0.96, 0.94), "hat": "chefhat", "hat_color": Color(0.99, 0.99, 0.99),
		"belt": "apron", "belt_color": Color(0.98, 0.98, 0.98), "line": "A tall white hat and a clean apron. Something smells good!"},
}

## kind: "" (your own boots) | "fluffy" | "bunny" | "dino" | "bear" | "duck" | "skull" | "workboots" | "wellies"
const FOOTWEAR := {
	"boots": {"name": "Adventuring Boots", "kind": "", "color": Color(0.4, 0.28, 0.18), "line": "Your own sturdy boots."},
	"fluffy": {"name": "Fluffy Slippers", "kind": "fluffy", "color": Color(0.62, 0.76, 1.0), "line": "Soft and fluffy, with a pompom on each."},
	"bunny": {"name": "Bunny Slippers", "kind": "bunny", "color": Color(0.97, 0.95, 0.95), "line": "Two little bunnies, one on each foot."},
	"dino": {"name": "Dino Slippers", "kind": "dino", "color": Color(0.35, 0.68, 0.3), "line": "Stomp stomp! Green, with claws."},
	"bear": {"name": "Bear Paw Slippers", "kind": "bear", "color": Color(0.5, 0.32, 0.2), "line": "Big brown bear paws."},
	"duck": {"name": "Duck Slippers", "kind": "duck", "color": Color(1.0, 0.85, 0.2), "line": "Quack quack, waddle waddle."},
	"skull": {"name": "Skull Slippers", "kind": "skull", "color": Color(0.93, 0.91, 0.84), "line": "A grinning skull on each toe. Brrr!"},
	"workboots": {"name": "Work Boots", "kind": "workboots", "color": Color(0.62, 0.45, 0.22), "line": "Chunky boots for building and digging."},
	"wellies": {"name": "Rain Boots", "kind": "wellies", "color": Color(0.98, 0.8, 0.12), "line": "Tall yellow boots for puddles and gardens."},
}

## What's in each class's wardrobe to begin with.
const CLASS_OUTFITS := {
	"Knight": ["knight_nightshirt", "knight_dragon"], "Barbarian": ["barbarian_lumberjack", "barbarian_bear"],
	"Rogue": ["rogue_midnight", "rogue_cat"], "Ranger": ["ranger_leafy", "ranger_fox"], "Mage": ["mage_starry", "mage_bunny"],
	"Priest": ["priest_cloudy", "priest_lamb"], "Druid": ["druid_toadstool", "druid_frog"],
	"Necromancer": ["necro_skeleton", "necro_bat"], "Beastmaster": ["beast_wolf", "beast_tiger"],
}
const CLASS_SLIPPERS := {"Knight": "dino", "Barbarian": "bear", "Rogue": "bunny", "Ranger": "duck", "Mage": "bunny",
	"Priest": "duck", "Druid": "dino", "Necromancer": "skull", "Beastmaster": "bear"}
const WORK := ["work_builder", "work_smith", "work_gardener", "work_fisher", "work_chef"]

static func starter_outfits(hero: String) -> Array:
	var a: Array = ["adventure", "pajamas"]
	a.append_array(CLASS_OUTFITS.get(hero, CLASS_OUTFITS.Knight))
	a.append_array(WORK)
	return a

static func starter_footwear(hero: String) -> Array:
	return ["boots", "fluffy", String(CLASS_SLIPPERS.get(hero, "bunny")), "workboots", "wellies"]

static func outfit_name(id: String) -> String:
	return String(OUTFITS.get(id, {}).get("name", id))

static func footwear_name(id: String) -> String:
	return String(FOOTWEAR.get(id, {}).get("name", id))

## Dress a CharacterModel cfg in an outfit (anything but "adventure") and footwear.
## The hero's own body, recoloured; armour looks, designs and the hat come off.
static func dress(cfg: Dictionary, outfit_id: String, footwear_id: String) -> void:
	if OUTFITS.has(outfit_id) and outfit_id != "adventure":
		var o: Dictionary = OUTFITS[outfit_id]
		for k in ["outfit_model", "outfit_fx", "custom_look", "tint", "skin"]:
			cfg.erase(k)
		cfg["show_hat"] = false
		cfg["no_cape"] = true
		cfg["outfit_color"] = o.color
		cfg["cape_color"] = (o.color as Color).darkened(0.12)
		if String(o.get("pattern", "")) != "":
			cfg["outfit_pattern"] = String(o.pattern)
			cfg["pattern_color"] = o.get("pattern_color", Color.WHITE)
		cfg["outfit_extras"] = outfit_id
	var fw: Dictionary = FOOTWEAR.get(footwear_id, {})
	if String(fw.get("kind", "")) != "":
		cfg["footwear"] = footwear_id
