extends RefCounted
class_name Cooking
## THE KITCHEN (Jason and his son, Nov 25): cook what you grow at the stove in your
## cabin (KitchenPanel). Each dish goes in your LUNCHBOX; eat it whenever you like,
## at home or out on an adventure (the Bag: "Lunchbox").
##
## The basics for now. More recipes and ingredients come later (the open world);
## add a line here and give the dish a look in KitchenPanel._dish_look.
##
##   needs   ingredients from your harvest basket (Game.basket: GardenPlants ids)
##   makes   how many come out of the pot
##   eat     what eating one does: "heal" (share of health), "energy", "mana" (refill
##           0..1), and "buffs": [buff, ...] for BUFF_SECS of play

const BUFF_SECS := 600.0           # ten minutes of play
const RECIPES := {
	"carrot_soup": {"name": "Carrot Soup", "needs": {"carrot": 2}, "makes": 1, "color": Color(1.0, 0.55, 0.15),
		"eat": {"heal": 0.3, "buffs": ["quick"]}, "line": "Warm and orange. Makes you QUICK for 10 minutes."},
	"tomato_pie": {"name": "Tomato Pie", "needs": {"tomato": 2}, "makes": 1, "color": Color(0.9, 0.2, 0.15),
		"eat": {"heal": 0.3, "buffs": ["strong"]}, "line": "A golden pie with a tomato top. Makes you STRONG for 10 minutes."},
	"pumpkin_stew": {"name": "Pumpkin Stew", "needs": {"pumpkin": 1}, "makes": 2, "color": Color(0.85, 0.45, 0.12),
		"eat": {"heal": 0.5, "buffs": ["tough"]}, "line": "Thick and filling: two bowls! Makes you TOUGH for 10 minutes."},
	"garden_salad": {"name": "Garden Salad", "needs": {"carrot": 1, "tomato": 1}, "makes": 1, "color": Color(0.45, 0.8, 0.3),
		"eat": {"heal": 1.0, "energy": 1.0, "buffs": ["fed"]}, "line": "Crunchy and fresh. All your health back, and WELL FED for 10 minutes."},
	"heros_feast": {"name": "Hero's Feast", "needs": {"carrot": 1, "tomato": 1, "pumpkin": 1}, "makes": 1, "color": Color(1.0, 0.8, 0.3),
		"eat": {"heal": 1.0, "energy": 1.0, "buffs": ["quick", "strong", "tough", "fed"]},
		"line": "A whole feast! QUICK, STRONG, TOUGH and WELL FED for 10 minutes."},
	"sunflower_cookies": {"name": "Sunflower Cookies", "needs": {"sunflower": 1}, "makes": 3, "color": Color(0.85, 0.62, 0.3),
		"eat": {"energy": 1.0, "heal": 0.15}, "line": "Three crunchy cookies. Each one fills up your energy."},
	"rose_tea": {"name": "Rose Tea", "needs": {"rose": 2}, "makes": 2, "color": Color(1.0, 0.55, 0.7),
		"eat": {"mana": 1.0}, "line": "Two cups of sweet pink tea. Each one fills up your magic."},
}
const ORDER := ["carrot_soup", "tomato_pie", "pumpkin_stew", "garden_salad", "heros_feast", "sunflower_cookies", "rose_tea"]

## "1 carrot", "2 tomatoes", "1 more pumpkin".
static func ing_text(ing: String, n: int, more := "") -> String:
	var word := ing
	if n != 1:
		word += "es" if ing.ends_with("o") else "s"
	return "%d %s%s" % [n, more, word]

static func dish_name(id: String) -> String:
	return String(RECIPES.get(id, {}).get("name", id))

## What you're short of for a recipe ({} if you can cook it).
static func missing(id: String) -> Dictionary:
	var out := {}
	var need: Dictionary = RECIPES.get(id, {}).get("needs", {})
	for ing in need:
		var short := int(need[ing]) - int(Game.basket.get(ing, 0))
		if short > 0:
			out[ing] = short
	return out

## How many come out of the pot (one more in Chef's Whites).
static func makes(id: String) -> int:
	return int(RECIPES.get(id, {}).get("makes", 1)) + (1 if Outfits.perk("chefs_touch") else 0)

static func can_cook(id: String) -> bool:
	return RECIPES.has(id) and missing(id).is_empty()

## Cook it: the ingredients leave the basket, the dish goes in the lunchbox.
static func cook(id: String) -> bool:
	if not can_cook(id):
		return false
	var r: Dictionary = RECIPES[id]
	for ing in r.needs:
		Game.basket[ing] = int(Game.basket[ing]) - int(r.needs[ing])
		if int(Game.basket[ing]) <= 0:
			Game.basket.erase(ing)
	Game.lunchbox[id] = int(Game.lunchbox.get(id, 0)) + makes(id)
	Game.inventory_changed.emit()
	return true

## Eat one from the lunchbox. Returns a line saying what it did ("" if there was none).
static func eat(id: String) -> String:
	if int(Game.lunchbox.get(id, 0)) <= 0:
		return ""
	Game.lunchbox[id] = int(Game.lunchbox[id]) - 1
	if int(Game.lunchbox[id]) <= 0:
		Game.lunchbox.erase(id)
	var e: Dictionary = RECIPES[id].eat
	var parts: Array = []
	if e.has("heal"):
		Game.hp = minf(Game.max_hp(), Game.hp + Game.max_hp() * float(e.heal))
		parts.append("health" if float(e.heal) >= 1.0 else "some health")
	if e.has("energy"):
		Game.stamina = Game.max_stamina()
		parts.append("energy")
	if e.has("mana"):
		Game.mana = Game.max_mana()
		parts.append("magic")
	var bs: Array = []
	for b in e.get("buffs", []):
		Game.add_buff(String(b), BUFF_SECS)
		bs.append(String(Game.BUFF_NAMES.get(b, b)).to_upper())
	Game.stats_changed.emit(); Game.inventory_changed.emit()
	var line := "Yum, %s!" % dish_name(id).to_lower()
	if not parts.is_empty():
		line += " %s back." % " and ".join(parts).capitalize()
	if not bs.is_empty():
		line += " You feel %s." % " and ".join(bs)
	return line
