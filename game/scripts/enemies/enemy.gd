extends CharacterBody3D
class_name Enemy
## State-machine dungeon enemy (KayKit skeleton rigs).
## Types: minion, warrior, mage (ranged), revenant (heavy, intermediate).

signal died(enemy: Enemy)

const TYPES := {
	"minion": {"name": "Risen Bones", "variant": "minion", "hp": 48.0, "dmg": 11.0, "speed": 3.4, "range": 1.8,
		"windup": 0.42, "cooldown": 1.0, "xp": 30, "weapon": "skel_blade", "shield": "", "eye": Color(0.3, 0.85, 1.0),
		"scale": 0.84, "aggro": 11.0, "poise": 0.0, "gold": [2, 8]},
	"warrior": {"name": "Vault Sentinel", "variant": "warrior", "hp": 80.0, "dmg": 13.0, "speed": 2.9, "range": 1.9,
		"windup": 0.5, "cooldown": 1.35, "xp": 55, "weapon": "skel_axe", "shield": "Skeleton_Shield_Small_A", "eye": Color(1.0, 0.7, 0.2),
		"scale": 0.88, "aggro": 11.0, "poise": 10.0, "gold": [5, 14]},
	"mage": {"name": "Bone Hexer", "variant": "mage", "hp": 46.0, "dmg": 11.0, "speed": 2.6, "range": 11.0,
		"windup": 0.7, "cooldown": 2.4, "xp": 50, "weapon": "skel_staff", "shield": "", "eye": Color(0.4, 1.0, 0.5),
		"scale": 0.84, "aggro": 15.0, "poise": 0.0, "gold": [6, 16], "ranged": true},
	"revenant": {"name": "Hollow Revenant", "variant": "warrior", "hp": 190.0, "dmg": 24.0, "speed": 2.5, "range": 2.6,
		"windup": 0.85, "cooldown": 1.9, "xp": 120, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(1.0, 0.25, 0.15),
		"scale": 1.25, "aggro": 13.0, "poise": 30.0, "gold": [20, 35], "heavy": true},
	# --- Goblin Forest: goblins are built on the hero rigs (green skin, ears, small)
	"goblin": {"name": "Goblin Cutter", "hp": 72.0, "dmg": 13.0, "speed": 4.3, "range": 1.7,
		"windup": 0.38, "cooldown": 0.9, "xp": 40, "weapon": "skel_blade", "shield": "", "eye": Color(1.0, 0.85, 0.2),
		"scale": 0.62, "aggro": 14.0, "poise": 0.0, "gold": [3, 9], "leash": 30.0,
		"look": {"hero": "Rogue", "hair_style": "mohawk", "hair_color": Color(0.12, 0.08, 0.06), "face": "warpaint", "outfit": Color(0.42, 0.3, 0.16)}},
	"goblin_archer": {"name": "Goblin Archer", "hp": 56.0, "dmg": 13.0, "speed": 3.8, "range": 15.0,
		"windup": 0.6, "cooldown": 1.7, "xp": 46, "weapon": "", "shield": "", "eye": Color(0.75, 1.0, 0.3),
		"scale": 0.6, "aggro": 18.0, "poise": 0.0, "gold": [4, 10], "ranged": true, "leash": 32.0,
		"look": {"hero": "Ranger", "hair_style": "natural", "hair_color": Color(0.1, 0.1, 0.1), "face": "none", "outfit": Color(0.3, 0.36, 0.15)}},
	"goblin_brute": {"name": "Goblin Brute", "hp": 280.0, "dmg": 27.0, "speed": 3.0, "range": 2.4,
		"windup": 0.75, "cooldown": 1.55, "xp": 120, "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.45, 0.15),
		"scale": 0.95, "aggro": 14.0, "poise": 25.0, "gold": [12, 24], "heavy": true, "leash": 26.0,
		"look": {"hero": "Barbarian", "hair_style": "bald", "hair_color": Color(0.1, 0.1, 0.1), "face": "warpaint", "outfit": Color(0.35, 0.22, 0.14), "build": 1.25}},
	# (Nov 18: much tougher, bigger, and with two signature moves: the Spore Bomb
	# and the War Horn)
	"goblin_chief": {"name": "Chief Gruk", "hp": 5600.0, "dmg": 56.0, "speed": 4.3, "range": 3.1,
		"windup": 0.62, "cooldown": 1.0, "xp": 900, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(1.0, 0.3, 0.1),
		"scale": 1.6, "aggro": 18.0, "poise": 170.0, "gold": [110, 160], "heavy": true, "leash": 40.0, "summon": true, "nova": true, "enrage": true,
		"moves": ["spore_bomb", "war_horn", "leap_slam", "spore_bomb", "whirl"],
		"look": {"hero": "Barbarian", "hair_style": "mohawk", "hair_color": Color(0.85, 0.12, 0.08), "face": "warpaint", "outfit": Color(0.5, 0.12, 0.1), "build": 1.3, "hat": true}},
	# --- the Sinkhole of Death: fire goblins and the Cyclops Goblin
	"fire_goblin": {"name": "Ember Goblin", "hp": 110.0, "dmg": 17.0, "speed": 4.5, "range": 1.8,
		"windup": 0.36, "cooldown": 0.85, "xp": 70, "weapon": "skel_blade", "shield": "", "eye": Color(1.0, 0.45, 0.1),
		"scale": 0.66, "aggro": 15.0, "poise": 5.0, "gold": [6, 14], "leash": 30.0, "skin": Color(0.78, 0.32, 0.18),
		"look": {"hero": "Rogue", "hair_style": "spiky", "hair_color": Color(1.0, 0.45, 0.05), "face": "warpaint", "outfit": Color(0.25, 0.08, 0.06)}},
	"fire_archer": {"name": "Cinder Slinger", "hp": 85.0, "dmg": 16.0, "speed": 3.9, "range": 16.0,
		"windup": 0.55, "cooldown": 1.6, "xp": 70, "weapon": "", "shield": "", "eye": Color(1.0, 0.5, 0.1),
		"scale": 0.62, "aggro": 19.0, "poise": 0.0, "gold": [6, 14], "ranged": true, "leash": 32.0, "skin": Color(0.78, 0.32, 0.18),
		"look": {"hero": "Ranger", "hair_style": "natural", "hair_color": Color(0.1, 0.1, 0.1), "face": "none", "outfit": Color(0.35, 0.1, 0.05)}},
	"magma_brute": {"name": "Magma Brute", "hp": 420.0, "dmg": 34.0, "speed": 3.0, "range": 2.6,
		"windup": 0.75, "cooldown": 1.5, "xp": 200, "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.35, 0.05),
		"scale": 1.05, "aggro": 15.0, "poise": 35.0, "gold": [18, 32], "heavy": true, "leash": 28.0, "skin": Color(0.62, 0.2, 0.12),
		"look": {"hero": "Barbarian", "hair_style": "spiky", "hair_color": Color(1.0, 0.5, 0.05), "face": "warpaint", "outfit": Color(0.2, 0.06, 0.04), "build": 1.3}},
	"cyclops": {"name": "Grimgor the Cyclops Goblin", "hp": 5200.0, "dmg": 52.0, "speed": 3.5, "range": 3.6,
		"windup": 0.75, "cooldown": 1.2, "xp": 1100, "enrage": true, "moves": ["eye_beam", "boulders", "leap_slam"], "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.25, 0.05),
		"scale": 2.3, "aggro": 20.0, "poise": 180.0, "gold": [140, 220], "heavy": true, "leash": 50.0, "summon": true, "nova": true,
		"skin": Color(0.45, 0.6, 0.22),
		"look": {"hero": "Barbarian", "hair_style": "natural", "hair_color": Color(0.15, 0.1, 0.05), "face": "none", "outfit": Color(0.4, 0.1, 0.08), "build": 1.4, "cyclops": true}},
	# --- the Bone Crypt under Ghost Knight Castle: the risen dead, ghost-fire eyes
	"crypt_skeleton": {"name": "Restless Bones", "variant": "minion", "hp": 210.0, "dmg": 27.0, "speed": 3.9, "range": 1.9,
		"windup": 0.4, "cooldown": 0.95, "xp": 95, "weapon": "skel_blade", "shield": "", "eye": Color(0.4, 1.0, 0.65),
		"scale": 0.86, "aggro": 13.0, "poise": 5.0, "gold": [8, 18], "leash": 26.0},
	"bone_knight": {"name": "Bone Knight", "variant": "warrior", "hp": 360.0, "dmg": 33.0, "speed": 3.2, "range": 2.1,
		"windup": 0.5, "cooldown": 1.15, "xp": 160, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(0.4, 1.0, 0.65),
		"scale": 0.98, "aggro": 13.0, "poise": 30.0, "gold": [12, 26], "leash": 26.0},
	"crypt_hexer": {"name": "Crypt Hexer", "variant": "mage", "hp": 200.0, "dmg": 29.0, "speed": 2.8, "range": 14.0,
		"windup": 0.65, "cooldown": 2.0, "xp": 130, "weapon": "skel_staff", "shield": "", "eye": Color(0.5, 1.0, 0.75),
		"scale": 0.86, "aggro": 16.0, "poise": 0.0, "gold": [10, 22], "ranged": true, "leash": 26.0},
	"bone_colossus": {"name": "The Bone Colossus", "variant": "warrior", "hp": 4600.0, "dmg": 48.0, "speed": 3.1, "range": 3.6,
		"windup": 0.75, "cooldown": 1.25, "xp": 1300, "weapon": "skel_axe", "shield": "", "eye": Color(0.4, 1.0, 0.65),
		"scale": 2.4, "aggro": 18.0, "poise": 160.0, "gold": [140, 220], "heavy": true, "leash": 30.0, "nova": true, "summon": true,
		"enrage": true, "moves": ["leap_slam", "whirl"]},
	# --- Level 3: Ghost Knight Castle (spectral: see-through and glowing)
	"ghost_knight": {"name": "Ghost Knight", "hp": 210.0, "dmg": 27.0, "speed": 3.6, "range": 2.0,
		"windup": 0.45, "cooldown": 1.1, "xp": 120, "weapon": "sword_1handed", "shield": "shield_round", "eye": Color(0.5, 0.9, 1.0),
		"scale": 0.9, "aggro": 16.0, "poise": 18.0, "gold": [12, 26], "leash": 34.0, "skin": Color(0.8, 0.9, 1.0), "armor_drop": 0.35,
		"look": {"hero": "Knight", "hat": true, "hair_style": "natural", "hair_color": Color(0.7, 0.8, 0.9), "face": "none", "outfit": Color(0.55, 0.65, 0.8), "skin_look": "spectral"}},
	"ghost_archer": {"name": "Ghost Archer", "hp": 140.0, "dmg": 25.0, "speed": 3.8, "range": 19.0,
		"windup": 0.55, "cooldown": 1.5, "xp": 110, "weapon": "", "shield": "", "eye": Color(0.45, 1.0, 0.85),
		"scale": 0.86, "aggro": 21.0, "poise": 0.0, "gold": [10, 22], "ranged": true, "leash": 34.0, "skin": Color(0.8, 0.95, 1.0),
		"look": {"hero": "Ranger", "hair_style": "natural", "hair_color": Color(0.7, 0.8, 0.9), "face": "none", "outfit": Color(0.4, 0.6, 0.7), "skin_look": "spectral"}},
	"wraith": {"name": "Wailing Wraith", "variant": "mage", "hp": 150.0, "dmg": 26.0, "speed": 3.0, "range": 14.0,
		"windup": 0.6, "cooldown": 1.8, "xp": 115, "weapon": "skel_staff", "shield": "", "eye": Color(0.6, 0.8, 1.0),
		"scale": 0.9, "aggro": 18.0, "poise": 0.0, "gold": [10, 24], "ranged": true, "leash": 30.0, "skin_look": "spectral"},
	"gatekeeper": {"name": "The Gatehouse Warden", "hp": 3200.0, "dmg": 44.0, "speed": 3.3, "range": 3.2,
		"windup": 0.7, "cooldown": 1.2, "xp": 800, "enrage": true, "moves": ["charge", "leap_slam"], "weapon": "sword_2handed_color", "shield": "", "eye": Color(0.45, 0.85, 1.0),
		"scale": 1.7, "aggro": 18.0, "poise": 90.0, "gold": [80, 140], "heavy": true, "leash": 30.0, "nova": true, "armor_drop": 1.0,
		"skin": Color(0.8, 0.9, 1.0),
		"look": {"hero": "Knight", "hat": true, "hair_style": "natural", "hair_color": Color(0.7, 0.8, 0.9), "face": "none", "outfit": Color(0.4, 0.5, 0.75), "build": 1.25, "skin_look": "spectral"}},
	"ghost_lord": {"name": "Morwen, the Ghost Lord", "hp": 7000.0, "dmg": 54.0, "speed": 3.6, "range": 3.6,
		"windup": 0.7, "cooldown": 1.1, "xp": 1700, "enrage": true, "moves": ["fan", "blink", "whirl", "leap_slam"], "weapon": "sword_2handed_color", "shield": "", "eye": Color(0.55, 0.75, 1.0),
		"scale": 2.2, "aggro": 22.0, "poise": 140.0, "gold": [200, 320], "heavy": true, "leash": 40.0, "nova": true, "summon": true, "armor_drop": 1.0,
		"skin": Color(0.75, 0.85, 1.0),
		"look": {"hero": "Knight", "hat": true, "hair_style": "natural", "hair_color": Color(0.6, 0.7, 0.9), "face": "none", "outfit": Color(0.25, 0.25, 0.45), "build": 1.35, "skin_look": "spectral"}},
	# --- Level 4: Cloud Island. "creature" = a shape-built look (CreatureLook);
	# "fly" = hovers this high above the ground / the player.
	"thunder_bird": {"name": "Thunder Bird", "variant": "minion", "creature": "bird", "hp": 470.0, "dmg": 48.0, "speed": 6.6, "range": 2.4,
		"windup": 0.42, "cooldown": 1.0, "xp": 260, "weapon": "", "shield": "", "eye": Color(1.0, 0.9, 0.3),
		"scale": 0.9, "aggro": 24.0, "poise": 25.0, "gold": [20, 38], "leash": 40.0, "fly": 2.6, "enrage": true},
	"storm_sprite": {"name": "Storm Sprite", "variant": "minion", "creature": "sprite", "hp": 260.0, "dmg": 36.0, "speed": 3.6, "range": 16.0,
		"windup": 0.55, "cooldown": 1.6, "xp": 210, "weapon": "", "shield": "", "eye": Color(1.0, 0.95, 0.35),
		"scale": 0.85, "aggro": 19.0, "poise": 0.0, "gold": [16, 30], "ranged": true, "leash": 30.0, "fly": 1.8},
	"storm_bat": {"name": "Storm Bat", "variant": "minion", "creature": "bat", "hp": 290.0, "dmg": 38.0, "speed": 6.2, "range": 2.2,
		"windup": 0.4, "cooldown": 1.1, "xp": 220, "weapon": "", "shield": "", "eye": Color(0.9, 0.3, 0.9),
		"scale": 0.85, "aggro": 18.0, "poise": 10.0, "gold": [16, 30], "leash": 32.0, "fly": 1.6},
	"bubble_mimic": {"name": "Bubble Mimic", "variant": "minion", "creature": "mimic", "hp": 430.0, "dmg": 46.0, "speed": 3.2, "range": 2.2,
		"windup": 0.6, "cooldown": 1.4, "xp": 240, "weapon": "", "shield": "", "eye": Color(0.8, 0.5, 1.0),
		"scale": 0.9, "aggro": 9.0, "poise": 30.0, "gold": [20, 40], "leash": 20.0},
	"hail_golem": {"name": "The Hail Golem", "variant": "warrior", "creature": "golem", "hp": 5200.0, "dmg": 58.0, "speed": 2.8, "range": 3.6,
		"windup": 0.85, "cooldown": 1.5, "xp": 1600, "weapon": "", "shield": "", "eye": Color(0.6, 0.85, 1.0),
		"scale": 2.0, "aggro": 20.0, "poise": 160.0, "gold": [200, 300], "heavy": true, "leash": 30.0, "nova": true,
		"look_size": 2.0, "radius": 1.2, "enrage": true, "moves": ["boulders", "charge"]},
	"mr_bubbles": {"name": "Mr. Bubbles", "variant": "warrior", "creature": "bear", "hp": 16000.0, "dmg": 78.0, "speed": 4.6, "range": 4.2,
		"windup": 0.75, "cooldown": 1.1, "xp": 3000, "weapon": "", "shield": "", "eye": Color(1.0, 0.92, 0.3),
		"scale": 2.0, "aggro": 26.0, "poise": 220.0, "gold": [400, 600], "heavy": true, "leash": 40.0, "nova": true, "summon": true,
		"fly": 0.4, "dive": true, "look_size": 1.6, "radius": 1.2, "enrage": true, "moves": ["charge", "leap_slam"]},
}
const GOBLIN_SKIN := Color(0.42, 0.62, 0.24)

enum S { DORMANT, AWAKEN, IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, RETURN, DEAD }

var type_id := "minion"
var t: Dictionary
var uid := ""
var hp := 40.0
var max_hp := 40.0
var dead := false
var state := S.IDLE
var state_time := 0.0
var cooldown := 0.0
var home := Vector3.ZERO
var leash := 18.0
var dormant_wake := 0.0     # >0 : lies in the floor until the player comes within this range
var body: CharacterModel
var hit_radius := 0.45
var facing := 0.0
var player: Node3D
var display_name := ""
var bounds := AABB()        # optional room bounds the enemy will not leave
var _strafe := 1.0
var _hurt_t := -1.0
var _stagger_acc := 0.0
var _summoned := false
var _summoned2 := false
var hp_mult := 1.0          # set before add_child: tougher versions (e.g. underground goblins)
var dmg_mult := 1.0
## Insane mode: some monsters are odd. "giant" (big and tough), "speedy" (fast),
## "splitter" (bursts into two little ones). mini = one of those little ones.
var oddity := ""
var mini := false
var _base_hp_mult := 1.0
var _base_dmg_mult := 1.0
var _enraged := false
var _los_t := 0.0
var _los_ok := true
## Skills that grow with the zone: quick foes sidestep your swings, shield
## bearers sometimes catch a blow on their shield.
const AGILE := ["goblin", "fire_goblin", "ghost_knight", "minion", "wraith", "storm_sprite", "thunder_bird"]
var _side_t := 0.0
var _side_dir := Vector3.ZERO
var _dodge_cd := 0.0
func _skill() -> float:
	return clampf(0.04 * float(Game.zone_level()) - 0.06, 0.08, 0.38)

func configure(type_name: String, id: String, wake_range := 0.0) -> void:
	type_id = type_name
	uid = id
	dormant_wake = wake_range

func _ready() -> void:
	t = TYPES[type_id]
	_base_hp_mult = hp_mult
	var boss := bool(t.get("heavy", false)) or int(t.xp) >= 900
	hp_mult *= Game.mode_value("boss_hp" if boss else "hp")
	if Game.mode == "insane" and not boss and not mini and oddity == "" and randf() < 0.3:
		oddity = ["giant", "speedy", "splitter"].pick_random()
	if oddity == "giant":
		hp_mult *= 1.6
	if mini:
		hp_mult *= 0.3
	# The deeper into the game, the tougher: foes grow when you out-level their
	# zone, and again as you finish more of that zone's quests. In Hard and Insane
	# they grow to match you instead (your level; in Insane with gear, your gear too).
	_base_dmg_mult = dmg_mult
	var done := 0
	for q in Game.zone_quests(Game.zone):
		if Game.quest_state(q) == "done":
			done += 1
	var fs := Vector2.ONE
	if Game.mode == "normal":
		var over := maxi(0, Game.level - Game.zone_level())
		hp_mult *= 1.0 + 0.1 * minf(over, 10.0)
		dmg_mult *= 1.0 + 0.07 * minf(over, 10.0)
	else:
		fs = Game.foe_scale()
		hp_mult *= fs.x
		dmg_mult *= fs.y
	hp_mult *= 1.0 + 0.05 * done
	dmg_mult *= 1.0 + 0.03 * done
	if hp_mult != 1.0 or dmg_mult != 1.0 or Game.mode != "normal" or oddity != "" or mini:
		t = t.duplicate()
		t.hp = float(t.hp) * hp_mult
		t.dmg = float(t.dmg) * dmg_mult * (1.3 if oddity == "giant" else 1.0)
		t.speed = float(t.speed) * Game.mode_value("speed") * (1.6 if oddity == "speedy" else (1.15 if mini else 1.0))
		var rw := Game.mode_value("reward") * (0.3 if mini else 1.0) * fs.x
		t.xp = int(float(t.xp) * rw)
		var g0: Array = t.gold
		t.gold = [int(float(g0[0]) * rw), maxi(1, int(float(g0[1]) * rw))]
		if oddity == "giant":
			t.scale = float(t.scale) * 1.4
		elif mini:
			t.scale = float(t.scale) * 0.6
	display_name = {"giant": "Giant ", "speedy": "Speedy ", "splitter": "Splitting "}.get(oddity, "Little " if mini else "") + String(t.name)
	add_to_group("enemy")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	max_hp = t.hp
	hp = max_hp
	hit_radius = 0.45 * t.scale / 0.84
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.38 * t.scale / 0.84; cap.height = 1.7 * t.scale / 0.84
	if t.has("radius"):        # big round creatures: a body as wide as they look
		cap.radius = float(t.radius)
		hit_radius = float(t.radius) + 0.1
	cs.shape = cap; cs.position.y = cap.height * 0.5
	add_child(cs)
	body = CharacterModel.new()
	add_child(body)
	if t.has("look"):
		var lk: Dictionary = t.look
		var skin_c: Color = t.get("skin", GOBLIN_SKIN)
		body.setup({"kind": "hero", "hero": lk.hero, "show_hat": lk.get("hat", false), "weapon": t.weapon, "shield": t.shield,
			"scale": t.scale, "skin_color": skin_c, "hair_style": lk.hair_style, "hair_color": lk.hair_color,
			"hair_tint": skin_c.darkened(0.1) if lk.hair_style in ["bald", "mohawk"] else lk.hair_color,
			"face": lk.face, "ears": not lk.has("skin_look"), "outfit_color": lk.outfit, "cape_color": lk.outfit.darkened(0.2),
			"skin": lk.get("skin_look", ""),
			"build": lk.get("build", 1.05), "height": 0.95})
	else:
		body.setup({"kind": "skeleton", "variant": t.variant, "weapon": t.weapon, "shield": t.shield, "eye": t.eye, "scale": t.scale,
			"skin": t.get("skin_look", "")})
	if t.has("look") and t.look.get("cyclops", false):
		_cyclops_eye.call_deferred()
	if t.has("creature"):
		_creature.call_deferred()
	if t.get("skin_look", t.get("look", {}).get("skin_look", "")) == "spectral":
		_spectral.call_deferred()
	leash = t.get("leash", leash)
	home = global_position
	if oddity != "":
		_oddity_look.call_deferred()
	# far away, ordinary monsters aren't drawn at all (saves a lot on tablets in a
	# forest full of them); big bosses can still be seen from afar
	if not boss and not t.has("look_size"):
		_far_cull.call_deferred()
	# Hard and Insane: more monsters (a twin turns up beside many of them; in
	# Insane most come in a pack of three)
	if Game.mode != "normal" and not boss and not mini and uid != "" and not uid.ends_with("+"):
		var roll := float(absi(hash(uid)) % 100)
		if roll < Game.mode_value("twins") * 100.0 and not Game.flags.get(uid + "+", false):
			_spawn_twin.call_deferred()
		if float(absi(hash(uid + "#")) % 100) < Game.mode_value("triplets") * 100.0 and not Game.flags.get(uid + "++", false):
			_spawn_twin.call_deferred("++")
	facing = rotation.y
	rotation.y = 0
	body.rotation.y = facing
	_strafe = 1.0 if randf() > 0.5 else -1.0
	if dormant_wake > 0.0:
		state = S.DORMANT
		body.visible = false
		cs.disabled = true
		set_physics_process(true)

## Flyers hover above the ground (or the player, when chasing) and swoop down
## to strike. Mr. Bubbles also does a storm dive: up into the clouds, a shadow
## marks the spot, then CRASH.
var _dive_t := 0.0
var _dive_phase := 0
var _dive_at := Vector3.ZERO
var _dive_mark: Node3D
func _fly(delta: float, pdead: bool) -> void:
	var h: float = t.fly
	var base_y := home.y
	var engaged := state in [S.CHASE, S.WINDUP, S.STRIKE, S.RECOVER] and not pdead
	if engaged:
		base_y = player.global_position.y
	var want_y := base_y + h
	if state == S.STRIKE or (state == S.WINDUP and state_time > t.windup * 0.5):
		want_y = base_y + 0.6           # swoop
	if t.get("dive", false) and engaged:
		_dive_t += delta
		match _dive_phase:
			0:
				if _dive_t > 11.0:
					_dive_phase = 1; _dive_t = 0.0
					Game.say("Mr. Bubbles flies up into the storm...", Color(1.0, 0.9, 0.4))
			1:
				want_y = base_y + 15.0
				velocity.x *= 0.9; velocity.z *= 0.9
				if _dive_t > 1.8:
					_dive_phase = 2; _dive_t = 0.0
					_dive_at = player.global_position
					_dive_mark = MeshInstance3D.new()
					var cm := CylinderMesh.new(); cm.top_radius = 5.0; cm.bottom_radius = 5.0; cm.height = 0.03
					(_dive_mark as MeshInstance3D).mesh = cm
					var dm := FX.glow_material(Color(1.0, 0.85, 0.2), 0.8); dm.albedo_color.a = 0.4
					(_dive_mark as MeshInstance3D).material_override = dm
					get_tree().current_scene.add_child(_dive_mark)
					_dive_mark.global_position = _dive_at + Vector3(0, 0.08, 0)
			2:
				want_y = base_y + 15.0
				global_position.x = lerpf(global_position.x, _dive_at.x, 1.0 - exp(-3.0 * delta))
				global_position.z = lerpf(global_position.z, _dive_at.z, 1.0 - exp(-3.0 * delta))
				velocity.x = 0; velocity.z = 0
				if _dive_t > 1.3:
					_dive_phase = 3; _dive_t = 0.0
			3:
				velocity = Vector3(0, -34.0, 0)
				if is_on_floor() or global_position.y < _dive_at.y + 0.6 or _dive_t > 1.5:
					_dive_phase = 0; _dive_t = 0.0
					if _dive_mark and is_instance_valid(_dive_mark):
						_dive_mark.queue_free()
					FX.shockwave(global_position + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.35), 6.0, 0.5)
					FX.burst(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.5), 80, 8.0, 0.3, 0.8, -4.0)
					Sfx.play_at("slam", global_position, 0.0, 0.05)
					if player.has_method("add_trauma"):
						player.add_trauma(0.6)
					var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
					if d < 5.0 and absf(player.global_position.y - global_position.y) < 3.0:
						player.take_damage(t.dmg * 1.2, global_position, 9.0)
				return
	var ground := _ground_below()
	want_y = maxf(want_y, ground + 0.4)
	velocity.y = clampf((want_y - global_position.y) * 3.0, -9.0, 9.0)

func _ground_below() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -30, 0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else global_position.y - 30.0

var _frozen_t := 0.0
var _blind_t := 0.0
var _ice: MeshInstance3D

## Frost Nova: frozen solid in a block of ice for a few seconds.
func freeze(sec: float, style := "ice") -> void:
	if dead or t.get("heavy", false) and sec > 1.5:
		sec = 1.5 if not dead else 0.0     # bosses only shiver for a moment
	if sec <= 0.0:
		return
	_frozen_t = maxf(_frozen_t, sec)
	velocity = Vector3.ZERO
	if body and body.anim:
		body.anim.speed_scale = 0.0
	if style == "roots":
		# held fast by thorny roots instead of a block of ice
		if _ice == null or not is_instance_valid(_ice):
			_ice = MeshInstance3D.new(); add_child(_ice)
			var vine := StandardMaterial3D.new(); vine.albedo_color = Color(0.28, 0.5, 0.16); vine.roughness = 0.8
			for k in 6:
				var v := MeshInstance3D.new(); var tm := TorusMesh.new()
				var r: float = 0.42 * t.scale / 0.84
				tm.inner_radius = r; tm.outer_radius = r + 0.09; tm.rings = 16; tm.ring_segments = 6
				v.mesh = tm; v.material_override = vine
				v.position.y = 0.2 + k * 0.28 * t.scale / 0.84; v.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
				_ice.add_child(v)
		return
	if _ice == null or not is_instance_valid(_ice):
		_ice = MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(1.1, 2.0, 1.1) * t.scale / 0.84
		_ice.mesh = bm
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.emission_enabled = true; m.emission = Color(0.3, 0.6, 0.9)
		m.roughness = 0.05; m.metallic_specular = 1.0
		_ice.material_override = m
		_ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ice.position.y = bm.size.y * 0.5
		add_child(_ice)

func _thaw() -> void:
	if body and body.anim:
		body.anim.speed_scale = 1.0
	if _ice and is_instance_valid(_ice):
		FX.burst(_ice.global_position, Color(0.75, 0.92, 1.0), 25, 3.0, 0.12, 0.6, -6.0)
		_ice.queue_free()
	_ice = null

## Smoke Bomb: lose sight of the player for a few seconds.
func lose_target(sec := 3.0) -> void:
	_blind_t = sec

func _go(s: S) -> void:
	state = s
	state_time = 0.0

## Far away and not doing anything: a monster sleeps. No thinking, no physics, no
## animation, just a quick look every half second to see if you've come close.
## (A forest full of Insane packs is ~180 monsters; only the ones near you need to
## be awake.)
var asleep := false
var _sleep_check := 0.0

func _sleep_dist() -> float:
	return maxf(48.0, maxf(float(t.aggro), dormant_wake) + 14.0)

func _set_asleep(on: bool) -> void:
	asleep = on
	if on:
		velocity = Vector3.ZERO
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT

## The monsters that are awake this physics frame (shared, built once per frame).
static var _awake_frame := -1
static var _awake_list: Array = []
func _awake_enemies() -> Array:
	var f := Engine.get_physics_frames()
	if f != _awake_frame:
		_awake_frame = f
		_awake_list.clear()
		for o in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(o) and not o.dead and not (o is Enemy and (o as Enemy).asleep):
				_awake_list.append(o)
	return _awake_list

func _physics_process(delta: float) -> void:
	if dead:
		if t.has("fly") and not is_on_floor():
			velocity.y -= 22.0 * delta      # flyers tumble down when beaten
			velocity.x *= 0.95; velocity.z *= 0.95
			move_and_slide()
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if asleep:
		if state != S.IDLE and state != S.DORMANT:
			_set_asleep(false)          # something woke it (a hit, a world event...)
		else:
			_sleep_check -= delta
			if _sleep_check > 0.0:
				return
			_sleep_check = 0.4 + randf() * 0.2
			var sd := _sleep_dist()
			if global_position.distance_squared_to(player.global_position) > sd * sd:
				return
			_set_asleep(false)
	elif state == S.IDLE or state == S.DORMANT:
		_sleep_check -= delta
		if _sleep_check <= 0.0:
			_sleep_check = 0.5 + randf() * 0.3
			var sd2 := _sleep_dist() + 6.0
			if global_position.distance_squared_to(player.global_position) > sd2 * sd2 \
					and (state == S.DORMANT or t.has("fly") or is_on_floor()) and _frozen_t <= 0.0 and not _move_busy:
				_set_asleep(true)
				return
	state_time += delta
	cooldown -= delta
	_blind_t -= delta
	if _frozen_t > 0.0:
		_frozen_t -= delta
		if _frozen_t <= 0.0:
			_thaw()
		return
	if _hurt_t >= 0.0:
		_hurt_t += delta
		if _hurt_t > 0.35:
			_hurt_t = -1.0
	if _move_busy:
		body.move_speed = 0.0
		return
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var pdead: bool = player.get("dead") == true or _blind_t > 0.0
	var move := Vector3.ZERO
	var spd: float = t.speed

	_dodge_cd -= delta
	if _side_t > 0.0:
		_side_t -= delta
		velocity.x = _side_dir.x * 7.5
		velocity.z = _side_dir.z * 7.5
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		move_and_slide()
		return
	if type_id in AGILE and state in [S.CHASE, S.WINDUP] and _dodge_cd <= 0.0 and dist < 3.4 and not pdead \
			and player.get("attacking") == true and float(player.get("attack_time")) < 0.12:
		_dodge_cd = 2.2
		if randf() < _skill():
			_side_dir = to_p.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
			_side_t = 0.3
			_go(S.CHASE)
			body.dodge_t = 0.0
			body.dodge_dir = Vector2(_side_dir.dot(Vector3.RIGHT), 0)
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				if is_instance_valid(body):
					body.dodge_t = -1.0)
			return
	match state:
		S.DORMANT:
			if dist < dormant_wake and not pdead:
				_awaken()
			return
		S.AWAKEN:
			if state_time > 1.6:
				_go(S.CHASE)
		S.IDLE:
			if not pdead and dist < t.aggro and _in_bounds(player.global_position) and _can_engage(delta):
				_go(S.CHASE)
				Sfx.play_at("skel_attack", global_position, -10.0)
		S.CHASE:
			# Mr. Bubbles' signature move: float you away in a big bubble (often!)
			if type_id == "mr_bubbles" and not pdead and dist < 24.0:
				_float_cd -= delta
				if _float_cd <= 0.0 and get_tree().get_nodes_in_group("bubble_trap").is_empty():
					_float_cd = randf_range(5.0, 6.5) if _enraged else randf_range(7.0, 9.0)
					_boss_move("bubble_float")
					return
			if t.has("moves") and not pdead and dist < 22.0 and _can_engage(delta):
				_move_cd -= delta
				if _move_cd <= 0.0:
					_move_cd = randf_range(3.5, 5.5) if _enraged else randf_range(5.5, 8.0)
					var mv: Array = t.moves
					_boss_move(String(mv[randi() % mv.size()]))
					return
			if t.get("nova", false):
				_nova_cd -= delta
				if _nova_cd <= 0.0 and dist < 9.0 and not pdead:
					_nova_cd = randf_range(6.5, 9.0) if hp > max_hp * 0.5 else randf_range(4.5, 6.5)
					_fire_nova()
			if pdead or dist > t.aggro * 2.2 or global_position.distance_to(home) > leash or not _in_bounds(player.global_position, 3.0) \
					or absf(player.global_position.y - global_position.y) > 6.0 + float(t.get("fly", 0.0)) + (16.0 if _dive_phase > 0 else 0.0):
				_go(S.RETURN)
			elif t.get("ranged", false):
				# keep a comfortable distance and circle
				var want := 8.0
				var side := to_p.normalized().cross(Vector3.UP) * _strafe
				if dist < want - 2.0:
					move = -to_p.normalized() + side * 0.5
				elif dist > want + 2.5:
					move = to_p.normalized()
				else:
					move = side * 0.7
				if state_time > 2.5:
					_strafe *= -1.0; state_time = 0.0
				if cooldown <= 0.0 and dist < t.range and _has_los():
					_go(S.WINDUP)
			else:
				move = to_p.normalized()
				if dist < t.range * 0.9 and cooldown <= 0.0:
					_go(S.WINDUP)
				elif dist < t.range * 0.9:
					move = to_p.normalized().cross(Vector3.UP) * _strafe * 0.4  # circle while waiting
		S.WINDUP:
			if state_time == delta or state_time < delta * 1.5:
				var kind := 2 if t.get("heavy", false) else randi() % 2
				body.attack_kind = kind
				body.attack_dur = t.windup + 0.45
				body.attack_t = 0.0
				body.flash(t.eye, 0.35)
				if t.get("ranged", false):
					body.cast_t = 0.0
					body.attack_t = -1.0
			if state_time >= t.windup:
				_go(S.STRIKE)
				_strike(dist, to_p)
		S.STRIKE:
			if state_time > 0.15:
				_go(S.RECOVER)
		S.RECOVER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.35:
				cooldown = t.cooldown * randf_range(0.8, 1.2)
				_go(S.CHASE)
		S.STAGGER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.4:
				_go(S.CHASE)
		S.RETURN:
			var th := home - global_position; th.y = 0
			if th.length() < 0.6:
				_go(S.IDLE)
				hp = minf(max_hp, hp + max_hp * 0.5)
			else:
				move = th.normalized()
			if not pdead and dist < t.aggro * 0.7 and global_position.distance_to(home) < leash * 0.6 and _can_engage(delta):
				_go(S.CHASE)

	# separation from other enemies (only the awake ones, and only while moving)
	if state == S.CHASE or state == S.RETURN or (state == S.IDLE and dist < 30.0):
		for o in _awake_enemies():
			if o == self or not is_instance_valid(o) or o.dead:
				continue
			var d: Vector3 = global_position - o.global_position
			d.y = 0
			var l := d.length()
			if l < 1.3 and l > 0.01:
				move += d / l * (1.3 - l) * 1.5
	if move.length() > 1.0:
		move = move.normalized()
	if state in [S.WINDUP, S.STRIKE, S.RECOVER, S.STAGGER, S.AWAKEN]:
		move = Vector3.ZERO
	var target_v := move * spd
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-8.0 * delta))
	if t.has("fly"):
		_fly(delta, pdead)
	elif not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	# face the player while engaged; face movement otherwise
	var want_face := facing
	if state in [S.CHASE, S.WINDUP] and dist > 0.1:
		want_face = atan2(-to_p.x, -to_p.z)
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		want_face = atan2(-velocity.x, -velocity.z)
	var turn := 5.0 if state == S.WINDUP and t.get("heavy", false) else 9.0
	facing = lerp_angle(facing, want_face, 1.0 - exp(-turn * delta))
	body.rotation.y = facing
	body.move_speed = Vector2(velocity.x, velocity.z).length()
	body.grounded = true
	body.hurt_t = _hurt_t / 0.35 if _hurt_t >= 0.0 else -1.0
	if state == S.WINDUP and not t.get("ranged", false):
		body.attack_t = state_time / (t.windup + 0.45)

## The Cyclops stamps the ground: a glowing ring warns you, then a wave of fire
## bursts out around it. Get clear (or dodge through it) in time!
var _nova_cd := 5.0
func _fire_nova() -> void:
	var at := global_position
	var radius := 6.5
	Sfx.play_at("roar_big", at, -2.0, 0.05)
	body.flash(Color(1.0, 0.4, 0.1), 0.9)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = radius - 0.25; tm.outer_radius = radius
	var nc: Color = t.eye
	ring.mesh = tm; ring.material_override = FX.glow_material(nc, 3.0)
	get_tree().current_scene.add_child(ring)
	ring.global_position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(1, 0.05, 1)
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.02
	disc.mesh = cm; var dm := FX.glow_material(nc, 0.7); dm.albedo_color.a = 0.35
	disc.material_override = dm
	get_tree().current_scene.add_child(disc)
	disc.global_position = at + Vector3(0, 0.06, 0)
	disc.scale = Vector3(0.05, 1, 0.05)
	var tw := disc.create_tween()
	tw.tween_property(disc, "scale", Vector3.ONE, 1.15)
	await get_tree().create_timer(1.2).timeout
	ring.queue_free(); disc.queue_free()
	if dead or not is_inside_tree():
		return
	Sfx.play_at("fire_burst", at, 0.0)
	Sfx.play_at("slam", at, 0.0)
	FX.shockwave(at + Vector3(0, 0.2, 0), nc, radius, 0.5)
	FX.burst(at + Vector3(0, 0.6, 0), nc.lightened(0.2), 90, 9.0, 0.35, 0.9, -2.0)
	FX.flash_light(at + Vector3(0, 2, 0), nc, 8.0, 14.0, 0.5)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.5)
	if player and player.get("dead") != true:
		var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if d < radius and absf(player.global_position.y - at.y) < 3.0:
			player.take_damage(t.dmg * 0.8, at, 7.0)

## One huge eye in the middle of the face (covers the two little ones).
func _cyclops_eye() -> void:
	var head: MeshInstance3D = null
	for m in body.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with("_Head") and (m as MeshInstance3D).visible:
			head = m
	var att := body._attach("head")
	if head == null or att == null:
		return
	var ab: AABB = head.global_transform * head.get_aabb()
	var root := Node3D.new(); att.add_child(root)
	# local "forward" of the face: the character faces -Z in body space
	var fwd := (-body.global_transform.basis.z).normalized()
	var c := ab.get_center()
	var r := ab.size.x * 0.24
	var face_pt := c + fwd * (ab.size.z * 0.38) + Vector3(0, ab.size.y * 0.02, 0)
	root.global_transform = Transform3D(body.global_transform.basis.orthonormalized(), face_pt)
	var white := StandardMaterial3D.new(); white.albedo_color = Color(1.0, 0.97, 0.9); white.roughness = 0.2
	var iris := StandardMaterial3D.new(); iris.albedo_color = Color(1.0, 0.35, 0.05); iris.emission_enabled = true
	iris.emission = Color(1.0, 0.3, 0.0); iris.emission_energy_multiplier = 2.5
	var pupil := StandardMaterial3D.new(); pupil.albedo_color = Color(0.02, 0.01, 0.01)
	var skin := StandardMaterial3D.new(); skin.albedo_color = t.get("skin", GOBLIN_SKIN); skin.roughness = 0.7
	var mk := func(rad: float, m: Material, at: Vector3, scl := Vector3.ONE) -> void:
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = rad; sm.height = rad * 2.0
		mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
		root.add_child(mi)
	mk.call(r * 1.25, skin, Vector3(0, 0, r * 0.35), Vector3(1.35, 1.0, 0.55))     # a fleshy socket over the old eyes
	mk.call(r, white, Vector3(0, 0, -r * 0.15))
	mk.call(r * 0.55, iris, Vector3(0, 0, -r * 0.62), Vector3(1, 1, 0.6))
	mk.call(r * 0.28, pupil, Vector3(0, 0, -r * 0.8), Vector3(1, 1, 0.5))
	var brow := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(r * 2.4, r * 0.35, r * 0.5)
	brow.mesh = bm; brow.material_override = skin; brow.position = Vector3(0, r * 1.05, -r * 0.2); brow.rotation.x = 0.25
	root.add_child(brow)
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.35, 0.05); glow.light_energy = 1.5; glow.omni_range = 4.0
	glow.position = Vector3(0, 0, -r * 1.2); root.add_child(glow)
	if type_id == "cyclops":
		_grimgor_regalia(root, r, ab)

## Grimgor dresses to impress: two great curling horns, a crown of iron
## spikes, glowing lava cracks over his shoulders and a cloak of embers.
func _grimgor_regalia(root: Node3D, r: float, ab: AABB) -> void:
	var horn := StandardMaterial3D.new(); horn.albedo_color = Color(0.2, 0.12, 0.08); horn.roughness = 0.5
	var tip := StandardMaterial3D.new(); tip.albedo_color = Color(1.0, 0.45, 0.1); tip.emission_enabled = true
	tip.emission = Color(1.0, 0.35, 0.05); tip.emission_energy_multiplier = 2.5
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.15, 0.13, 0.13); iron.metallic = 0.8; iron.roughness = 0.35
	var top := Vector3(0, ab.size.y * 0.45, r * 1.2)
	for sd in [-1.0, 1.0]:
		# each horn: three cones bending up and out
		var prev := top + Vector3(sd * ab.size.x * 0.32, -ab.size.y * 0.05, 0)
		var dirs := [Vector3(sd * 0.9, 0.5, 0.1), Vector3(sd * 0.5, 0.9, -0.1), Vector3(sd * 0.1, 1.0, -0.4)]
		var rad := r * 0.55
		for i in 3:
			var d: Vector3 = (dirs[i] as Vector3).normalized()
			var ln := r * (1.3 - i * 0.25)
			var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = rad * 0.6; cm.bottom_radius = rad; cm.height = ln
			cm.radial_segments = 8; c.mesh = cm; c.material_override = tip if i == 2 else horn
			c.position = prev + d * ln * 0.5; c.basis = Basis(Quaternion(Vector3.UP, d))
			root.add_child(c)
			prev += d * ln
			rad *= 0.6
	for k in 7:
		var a := (k - 3) * 0.32
		var sp := MeshInstance3D.new(); var scm := CylinderMesh.new(); scm.top_radius = 0.0; scm.bottom_radius = r * 0.16; scm.height = r * (0.9 if k == 3 else 0.6)
		scm.radial_segments = 6; sp.mesh = scm; sp.material_override = iron
		sp.position = top + Vector3(sin(a) * ab.size.x * 0.28, scm.height * 0.4, cos(a) * ab.size.z * 0.1)
		root.add_child(sp)
	# embers drifting off him all the time, and a hot glow at his feet
	var em := CPUParticles3D.new(); em.amount = 50; em.lifetime = 1.4
	em.mesh = FX.quad(0.14); em.material_override = FX.glow_material(Color(1.0, 0.4, 0.1), 3.0)
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; em.emission_box_extents = Vector3(0.8, 1.6, 0.6) * t.scale / 0.84
	em.direction = Vector3.UP; em.spread = 25; em.initial_velocity_min = 0.6; em.initial_velocity_max = 1.6
	em.gravity = Vector3(0, 1.0, 0); em.color_ramp = FX._fade_ramp(Color(1.0, 0.45, 0.1))
	em.position.y = 1.6 * t.scale / 0.84; add_child(em)
	var feet := OmniLight3D.new(); feet.light_color = Color(1.0, 0.35, 0.08); feet.light_energy = 2.5; feet.omni_range = 7.0
	feet.position.y = 0.8; add_child(feet)
	# a molten rim glow over his whole body (chained after the hit-flash pass,
	# so taking a hit still flashes him white)
	var lava := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_add, unshaded, depth_draw_never;\nuniform vec3 col = vec3(1.0, 0.3, 0.05);\nvoid fragment() {\n\tfloat f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);\n\tALBEDO = col * f * 1.6;\n}\n"
	lava.shader = sh
	if body.flash_mat:
		body.flash_mat.next_pass = lava

func _in_bounds(p: Vector3, margin := 0.0) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var b := bounds.grow(margin)
	return p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z

func _has_los() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------------------------------------------------------------------------
# Boss special moves. Every boss has a few (TYPES[..].moves); each one is shown
# first (a glowing ring or line on the ground) so you can get out of the way.
var _move_cd := 4.0
var _float_cd := 3.0
var _move_busy := false

func _warn_ring(at: Vector3, radius: float, secs: float, col := Color(1.0, 0.35, 0.1)) -> void:
	var root := get_tree().current_scene
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = radius - 0.2; tm.outer_radius = radius
	ring.mesh = tm; ring.material_override = FX.beam_material(col, 2.0, 0.9); ring.scale = Vector3(1, 0.06, 1)
	root.add_child(ring); ring.global_position = at + Vector3(0, 0.08, 0)
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.02
	disc.mesh = cm; disc.material_override = FX.beam_material(col, 0.8, 0.3)
	root.add_child(disc); disc.global_position = at + Vector3(0, 0.06, 0); disc.scale = Vector3(0.05, 1, 0.05)
	disc.create_tween().tween_property(disc, "scale", Vector3.ONE, secs)
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		ring.queue_free(); disc.queue_free())

func _player_hit(at: Vector3, radius: float, dmg: float, knock: float, fire := false) -> void:
	if player == null or player.get("dead") == true:
		return
	var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
	if d < radius and absf(player.global_position.y - at.y) < 3.0:
		if fire and player.has_method("burn"):
			player.burn(dmg, 1.5, dmg * 0.08)
		else:
			player.take_damage(dmg, at, knock)

func _face_player() -> void:
	var to: Vector3 = player.global_position - global_position
	facing = atan2(-to.x, -to.z)
	body.rotation.y = facing

var moves_done: Array[String] = []
func _boss_move(mv: String) -> void:
	_move_busy = true
	moves_done.append(mv)
	velocity = Vector3.ZERO
	_face_player()
	match mv:
		"leap_slam": await _mv_leap_slam()
		"charge": await _mv_charge()
		"whirl": await _mv_whirl()
		"fan": await _mv_fan()
		"eye_beam": await _mv_eye_beam()
		"boulders": await _mv_boulders()
		"blink": await _mv_blink()
		"bubble_float": await _mv_bubble_float()
		"spore_bomb": await _mv_spore_bomb()
		"war_horn": await _mv_war_horn()
	if is_inside_tree() and not dead and state != S.WINDUP:
		_go(S.CHASE)
	_move_busy = false

## Chief Gruk hurls a giant glowing mushroom at you. Where it lands it bursts into
## a big cloud of rainbow spores: it stings while you stand in it, and breathing
## it in gives you rainbow vision (like eating a glowing mushroom).
func _mv_spore_bomb() -> void:
	Game.say("Gruk: \"EAT MUSHROOM, TINY HERO!\"", Color(0.75, 1.0, 0.45))
	Sfx.play_at("roar", global_position, -4.0, 0.2)
	body.play_role("cast", 0.7)
	await get_tree().create_timer(0.45, false).timeout
	if dead or not is_inside_tree() or player == null:
		return
	for k in (2 if _enraged else 1):
		var land: Vector3 = player.global_position + (Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if k > 0 else Vector3.ZERO)
		_warn_ring(land, 3.4, 1.1, Color(0.7, 1.0, 0.4))
		var shroom := Node3D.new()
		get_tree().current_scene.add_child(shroom)
		var cap := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.7; sm.height = 0.7; sm.is_hemisphere = true
		cap.mesh = sm; cap.material_override = FX.glow_material(Color(0.8, 0.4, 1.0), 2.0); cap.position.y = 0.3; shroom.add_child(cap)
		var stem := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.18; cm.bottom_radius = 0.24; cm.height = 0.6
		stem.mesh = cm; var stm := StandardMaterial3D.new(); stm.albedo_color = Color(0.9, 0.86, 0.75); stem.material_override = stm
		shroom.add_child(stem)
		var from := global_position + Vector3(0, 3.2, 0)
		shroom.global_position = from
		var tw := shroom.create_tween()
		tw.tween_method(func(f: float) -> void:
			if is_instance_valid(shroom):
				shroom.global_position = from.lerp(land, f) + Vector3(0, sin(f * PI) * 6.0, 0)
				shroom.rotation += Vector3(0.15, 0.25, 0.1), 0.0, 1.0, 1.1)
		tw.tween_callback(func() -> void:
			if is_instance_valid(shroom):
				shroom.queue_free()
			_spore_cloud(land))
		await get_tree().create_timer(0.5, false).timeout
	await get_tree().create_timer(1.2, false).timeout

func _spore_cloud(at: Vector3) -> void:
	Sfx.play_at("pop", at, 0.0, 0.2)
	Sfx.play_at("collapse", at, -10.0, 0.3)
	FX.shockwave(at + Vector3(0, 0.2, 0), Color(0.8, 0.5, 1.0), 3.6, 0.4)
	_player_hit(at, 3.4, float(t.dmg) * 0.7, 5.0, false)
	var cloud := CPUParticles3D.new(); cloud.amount = 70; cloud.lifetime = 2.2
	cloud.mesh = FX.quad(1.2); cloud.material_override = FX.glow_material(Color(1, 1, 1), 1.2)
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; cloud.emission_sphere_radius = 3.0
	cloud.direction = Vector3.UP; cloud.spread = 60; cloud.initial_velocity_min = 0.2; cloud.initial_velocity_max = 0.8
	cloud.gravity = Vector3(0, 0.15, 0); cloud.hue_variation_min = -1.0; cloud.hue_variation_max = 1.0
	cloud.color = Color(1.0, 0.5, 0.5, 0.55)
	cloud.color_ramp = FX._fade_ramp(Color(1, 1, 1))
	get_tree().current_scene.add_child(cloud); cloud.global_position = at + Vector3(0, 1.0, 0)
	var dmg_tick := float(t.dmg) * 0.12
	for k in 10:
		await get_tree().create_timer(0.5, false).timeout
		if not is_instance_valid(cloud):
			return
		if player and player.get("dead") != true:
			var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
			if d < 3.4 and absf(player.global_position.y - at.y) < 3.0:
				player.take_damage(dmg_tick, at, 0.0)
				if k % 3 == 0:
					Game.shroom = minf(4.6, maxf(Game.shroom, floor(Game.shroom) + 1.0))   # spores: rainbow vision (never the full five)
	cloud.emitting = false
	get_tree().create_timer(2.5).timeout.connect(cloud.queue_free)

## Chief Gruk blows his war horn: a blast that throws you back, and goblins come
## running from the dark to help him.
func _mv_war_horn() -> void:
	Game.say("Gruk blows his WAR HORN! \"BOYS! BOYS! GET IN HERE!\"", Color(1.0, 0.6, 0.3))
	body.play_role("cheer", 1.0)
	Sfx.play_at("roar_big", global_position, 0.0, 0.3)
	await get_tree().create_timer(0.5, false).timeout
	if dead or not is_inside_tree():
		return
	FX.shockwave(global_position + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.25), 8.0, 0.6)
	FX.shockwave(global_position + Vector3(0, 1.5, 0), Color(1.0, 0.8, 0.4), 6.0, 0.45)
	_player_hit(global_position, 6.5, float(t.dmg) * 0.5, 12.0, false)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.5)
	var allies := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and is_instance_valid(e) and not e.dead and (e as Node3D).global_position.distance_to(global_position) < 22.0:
			allies += 1
	if allies < 4:
		for k in 3:
			var a := randf() * TAU
			var p := global_position + Vector3(cos(a) * 7.0, 0.3, sin(a) * 7.0)
			FX.burst(p + Vector3(0, 1, 0), Color(0.6, 0.9, 0.3), 30, 3.0, 0.3, 0.8, 0.5)
			var g := Enemy.new()
			g.configure(["goblin", "goblin_archer", "goblin"][k], "", 0.0)
			g.position = p
			get_parent().add_child(g)
	await get_tree().create_timer(0.8, false).timeout

## Mr. Bubbles raises his wand and blows a big rainbow bubble at you. If it
## catches you, it floats you up high: pop it and drop back into the fight. While
## you're up there he sends lightning bubbles after you.
func _mv_bubble_float() -> void:
	Game.say("Mr. Bubbles: \"BUBBLE TIME! Up, up and away!\"", Color(1.0, 0.9, 0.5))
	body.play_role("cast", 0.9)
	Sfx.play_at("pop", global_position, -2.0, 0.3)
	await get_tree().create_timer(0.55, false).timeout
	if dead or not is_inside_tree() or player == null:
		return
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var trap := BubbleTrap.blow(get_parent(), global_position + fwd * 2.4 + Vector3(0, 2.2, 0), player, 5 if _enraged else 4)
	await get_tree().create_timer(1.6, false).timeout
	if dead or not is_inside_tree() or not is_instance_valid(trap) or not trap.caught():
		return
	# you're floating: lightning bubbles drift up after you
	for k in (2 if _enraged else 1):
		LightningBubble.blow(get_parent(), global_position + Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(-1.5, 1.5)), float(t.dmg) * 0.4)
	await get_tree().create_timer(0.8, false).timeout

## Leap high and crash down where you were standing.
func _mv_leap_slam() -> void:
	var to: Vector3 = player.global_position
	var from := global_position
	_warn_ring(to, 4.2, 1.15)
	Game.say("%s leaps!" % display_name, Color(1.0, 0.6, 0.35))
	body.play_role("jump", 1.1)
	Sfx.play_at("roar", global_position, -4.0, 0.1)
	await get_tree().create_timer(0.35, false).timeout
	if dead or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 6.0, 0), 0.0, 1.0, 0.8)
	await tw.finished
	if dead or not is_inside_tree():
		return
	FX.shockwave(to + Vector3(0, 0.2, 0), t.eye, 5.0, 0.4)
	FX.burst(to + Vector3(0, 0.4, 0), Color(0.6, 0.5, 0.4), 60, 7.0, 0.35, 0.9, -6.0)
	Sfx.play_at("slam", to, 0.0, 0.05)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.6)
	_player_hit(to, 4.2, float(t.dmg) * 1.3, 9.0)
	await get_tree().create_timer(0.5, false).timeout

## Lower the head, then thunder forward in a straight line.
func _mv_charge() -> void:
	var dir: Vector3 = player.global_position - global_position; dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else -Vector3(sin(facing), 0, cos(facing))
	var length := 16.0
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.0, 0) + dir * length, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		length = maxf(2.0, global_position.distance_to(hit.position) - 1.5)
	var line := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.2, 0.03, length)
	line.mesh = bm; line.material_override = FX.beam_material(Color(1.0, 0.35, 0.15), 1.4, 0.55)
	get_tree().current_scene.add_child(line)
	line.global_position = global_position + dir * length * 0.5 + Vector3(0, 0.08, 0)
	line.rotation.y = atan2(dir.x, dir.z)
	body.flash(Color(1.0, 0.3, 0.1), 0.8)
	Sfx.play_at("roar_big", global_position, -4.0, 0.1)
	await get_tree().create_timer(0.85, false).timeout
	line.queue_free()
	if dead or not is_inside_tree():
		return
	var from := global_position
	var hit_once := false
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		global_position = from + dir * length * k
		if not hit_once and player and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < 2.0 + hit_radius:
			hit_once = true
			_player_hit(player.global_position, 1.0, float(t.dmg) * 1.4, 12.0)
		if Engine.get_physics_frames() % 3 == 0:
			FX.burst(global_position + Vector3(0, 0.3, 0), Color(0.6, 0.5, 0.4), 6, 2.5, 0.3, 0.5, -3.0), 0.0, 1.0, 0.65)
	await tw.finished
	Sfx.play_at("slam", global_position, -2.0, 0.1)
	await get_tree().create_timer(0.6, false).timeout

## Spin like a top, weapon out, drifting toward you.
func _mv_whirl() -> void:
	Game.say("%s spins into a whirlwind!" % display_name, Color(1.0, 0.6, 0.35))
	for k in 7:
		if dead or not is_inside_tree():
			return
		var to: Vector3 = player.global_position - global_position; to.y = 0
		if to.length() > 1.5:
			global_position += to.normalized() * minf(1.2, to.length() - 1.0)
		body.rotation.y += 2.4
		FX.shockwave(global_position + Vector3(0, 1.0, 0), t.eye, 3.4, 0.25)
		Sfx.play_at("swing", global_position, -2.0, 0.2)
		_player_hit(global_position, 3.4 + hit_radius * 0.5, float(t.dmg) * 0.5, 4.0)
		await get_tree().create_timer(0.32, false).timeout

## A fan of seven ghostly bolts.
func _mv_fan() -> void:
	body.cast_t = 0.0
	await get_tree().create_timer(0.5, false).timeout
	if dead or not is_inside_tree():
		return
	var base_dir: Vector3 = player.global_position - global_position; base_dir.y = 0
	base_dir = base_dir.normalized()
	for k in 7:
		var d := base_dir.rotated(Vector3.UP, (k - 3) * 0.17)
		var bolt := Area3D.new()
		bolt.set_script(load("res://scripts/player/projectile.gd"))
		get_tree().current_scene.add_child(bolt)
		bolt.global_position = global_position + Vector3(0, 1.6 * t.scale / 0.84 * 0.6, 0) + d * 1.2
		bolt.launch(d + Vector3(0, -0.04, 0), "enemy", float(t.dmg) * 0.55, t.eye, 12.0)
	Sfx.play_at("spell", global_position, -2.0, 0.1)
	body.cast_t = -1.0
	await get_tree().create_timer(0.6, false).timeout

## Grimgor's eye beam: a red line, then a sweeping beam of fire.
func _mv_eye_beam() -> void:
	var eye := global_position + Vector3(0, 2.0 * t.scale / 0.84 * 0.95, 0)
	var dir0: Vector3 = player.global_position - global_position; dir0.y = 0
	dir0 = dir0.normalized()
	Game.say("Grimgor's eye glows red hot...", Color(1.0, 0.35, 0.15))
	Sfx.play_at("spell", global_position, 0.0, 0.0)
	for k in 6:
		FX.beam(eye, global_position + dir0 * 18.0 + Vector3(0, 0.1, 0), Color(1.0, 0.2, 0.05), 0.05, 0.2)
		await get_tree().create_timer(0.16, false).timeout
	if dead or not is_inside_tree():
		return
	var sweep := -0.6 if randf() < 0.5 else 0.6
	for k in 12:
		if dead or not is_inside_tree():
			return
		var d := dir0.rotated(Vector3.UP, sweep * (-1.0 + 2.0 * k / 11.0))
		var end := global_position + d * 18.0
		var q := PhysicsRayQueryParameters3D.create(eye, end + Vector3(0, 0.3, 0), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			end = hit.position
		FX.beam(eye, end, Color(1.0, 0.3, 0.05), 0.4, 0.16)
		FX.burst(end, Color(1.0, 0.5, 0.1), 8, 3.0, 0.2, 0.4, -2.0)
		body.rotation.y = atan2(-d.x, -d.z)
		if player and player.get("dead") != true:
			var pp: Vector3 = player.global_position
			var seg := end - global_position; seg.y = 0
			var rel := pp - global_position; rel.y = 0
			var u := clampf(rel.dot(seg) / maxf(seg.length_squared(), 0.01), 0.0, 1.0)
			if (rel - seg * u).length() < 1.1 and absf(pp.y - global_position.y) < 3.0:
				_player_hit(pp, 1.0, float(t.dmg) * 0.35, 3.0, true)
		await get_tree().create_timer(0.1, false).timeout
	await get_tree().create_timer(0.4, false).timeout

## Hurl flaming (or icy) boulders where you're standing.
func _mv_boulders() -> void:
	var col := Color(0.6, 0.85, 1.0) if type_id == "hail_golem" else Color(1.0, 0.45, 0.1)
	Sfx.play_at("roar", global_position, -4.0, 0.1)
	for k in 3:
		if dead or not is_inside_tree() or player == null:
			return
		var land: Vector3 = player.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0)) * (0.0 if k == 0 else 1.0)
		_warn_ring(land, 2.6, 1.0, col)
		var rock := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2; rock.mesh = sm
		var rm := StandardMaterial3D.new(); rm.albedo_color = col.darkened(0.6); rm.emission_enabled = true; rm.emission = col
		rm.emission_energy_multiplier = 1.5; rock.material_override = rm
		get_tree().current_scene.add_child(rock)
		var from := global_position + Vector3(0, 3.0 * t.scale / 0.84 * 0.7, 0)
		rock.global_position = from
		var tw := rock.create_tween()
		tw.tween_method(func(f: float) -> void:
			if is_instance_valid(rock):
				rock.global_position = from.lerp(land, f) + Vector3(0, sin(f * PI) * 7.0, 0)
				rock.rotation += Vector3(0.2, 0.3, 0.1), 0.0, 1.0, 1.0)
		tw.tween_callback(func() -> void:
			if is_instance_valid(rock):
				rock.queue_free()
			FX.shockwave(land + Vector3(0, 0.2, 0), col, 3.0, 0.35)
			FX.burst(land + Vector3(0, 0.5, 0), col, 50, 6.0, 0.25, 0.9, -5.0)
			Sfx.play_at("slam", land, -2.0, 0.1)
			_player_hit(land, 2.6, float(t.dmg) * 0.9, 7.0, type_id != "hail_golem"))
		await get_tree().create_timer(0.45, false).timeout
	await get_tree().create_timer(1.0, false).timeout

## Vanish in mist and appear right behind you, blade already swinging.
func _mv_blink() -> void:
	FX.burst(global_position + Vector3(0, 1.5, 0), t.eye, 50, 4.0, 0.3, 0.8, 0.5)
	Sfx.play_at("portal", global_position, -4.0, 0.1)
	body.visible = false
	await get_tree().create_timer(0.6, false).timeout
	if dead or not is_inside_tree() or player == null:
		body.visible = true
		return
	var behind: Vector3 = player.global_position + Vector3(sin(player.get("facing")), 0, cos(player.get("facing"))) * 3.0
	global_position = behind + Vector3(0, 0.3, 0)
	body.visible = true
	FX.burst(global_position + Vector3(0, 1.5, 0), t.eye, 50, 4.0, 0.3, 0.8, 0.5)
	_face_player()
	_go(S.WINDUP)
	_move_busy = false

## Bosses fight harder when nearly beaten: faster, quicker swings, a red glow.
func _enrage() -> void:
	_enraged = true
	t = t.duplicate()
	t.speed = float(t.speed) * 1.25
	t.cooldown = float(t.cooldown) * 0.65
	t.windup = float(t.windup) * 0.8
	t.dmg = float(t.dmg) * 1.15
	Game.say("%s is ENRAGED!" % display_name, Color(1.0, 0.35, 0.2))
	Sfx.play_at("roar_big", global_position, 0.0, 0.05)
	FX.burst(global_position + Vector3(0, 1.5, 0), Color(1.0, 0.25, 0.1), 60, 5.0, 0.3, 0.8, 0.0)
	body.flash(Color(1.0, 0.2, 0.1), 1.0)
	var aura := OmniLight3D.new(); aura.light_color = Color(1.0, 0.25, 0.1); aura.light_energy = 2.5; aura.omni_range = 5.0
	aura.position.y = 1.5 * t.scale; add_child(aura)
	var embers := CPUParticles3D.new(); embers.amount = 40; embers.lifetime = 0.9
	embers.mesh = FX.quad(0.12); embers.material_override = FX.glow_material(Color(1.0, 0.35, 0.1), 3.0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; embers.emission_sphere_radius = 0.6 * t.scale
	embers.direction = Vector3.UP; embers.spread = 30; embers.initial_velocity_min = 1.0; embers.initial_velocity_max = 2.5
	embers.gravity = Vector3(0, 1, 0); embers.color_ramp = FX._fade_ramp(Color(1.0, 0.4, 0.1))
	embers.position.y = 1.0 * t.scale; add_child(embers)

## Only notice the player on (about) the same floor and with nothing solid in
## between, so foes behind walls or on the level above/below leave you alone.
## The sight check is cached for a moment to keep it cheap.
func _can_engage(delta: float) -> bool:
	if absf(player.global_position.y - global_position.y) > 4.0 + float(t.get("fly", 0.0)):
		return false
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.3
		_los_ok = _has_los()
	return _los_ok

func _awaken() -> void:
	_go(S.AWAKEN)
	body.visible = true
	body.hold_clip = ""
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	body.play_role("spawn", 1.5)
	FX.burst(global_position + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 30, 3.0, 0.4, 1.0, -4.0)
	FX.burst(global_position + Vector3(0, 0.5, 0), t.eye, 14, 1.5, 0.2, 0.9, 1.0)
	Sfx.play_at("bone_break", global_position, -2.0)
	var to_p: Vector3 = player.global_position - global_position
	facing = atan2(-to_p.x, -to_p.z)
	body.rotation.y = facing

func _strike(dist: float, to_p: Vector3) -> void:
	if t.get("ranged", false):
		var b := Area3D.new()
		b.set_script(load("res://scripts/player/projectile.gd"))
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector3(0, 1.5, 0) + (-Vector3(sin(facing), 0, cos(facing))) * 0.6
		var aim: Vector3 = (player.global_position + Vector3(0, 1.1, 0)) - b.global_position
		b.launch(aim, "enemy", t.dmg, t.eye, 13.0)
		b.homing = 1.2
		Sfx.play_at("spell", global_position, -6.0)
		return
	Sfx.play_at("swing", global_position, -4.0, 0.15)
	if t.get("heavy", false):
		Sfx.play_at("slam", global_position, -6.0)
		FX.shockwave(global_position + (-Vector3(sin(facing), 0, cos(facing))) * 1.6, Color(1.0, 0.4, 0.2), 2.6, 0.35)
		if player.has_method("add_trauma"):
			player.add_trauma(0.3)
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var reach: float = t.range + 0.35
	var dy := absf(player.global_position.y - global_position.y)
	if dy > 2.6 + float(t.get("fly", 0.0)) or not _has_los():
		return       # a wall or floor in the way: the blow can't land
	if dist < reach and (dist < 0.6 or fwd.dot(to_p.normalized()) > 0.35) and player.get("dead") != true:
		player.take_damage(t.dmg * randf_range(0.9, 1.1), global_position, 5.0 if t.get("heavy", false) else 3.0)

func take_damage(amount: float, from_pos: Vector3, knock := 2.5, crit := false) -> void:
	if dead:
		return
	if state == S.DORMANT:
		_awaken()
	# a shield bearer facing the blow sometimes takes it on the shield
	if String(t.get("shield", "")) != "" and not t.get("heavy", false) and state in [S.CHASE, S.RECOVER] and randf() < _skill() * 0.8:
		var fwd := -Vector3(sin(facing), 0, cos(facing))
		var from_dir := from_pos - global_position; from_dir.y = 0
		if from_dir.length() > 0.01 and fwd.dot(from_dir.normalized()) > 0.3:
			amount *= 0.25
			Sfx.play_at("clang", global_position, -4.0, 0.15)
			FX.sparks(global_position + Vector3(0, 1.1, 0) + fwd * 0.5, Color(1.0, 0.85, 0.5))
			body.blocking = true
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if is_instance_valid(body):
					body.blocking = false)
	hp -= amount
	if t.get("summon", false) and not _summoned and hp < max_hp * 0.5 and hp > 0.0:
		_summoned = true
		if get_parent().has_method("summon_for"):
			get_parent().summon_for(self)
	# Mr. Bubbles calls his friends twice: at half health and again near the end
	elif type_id == "mr_bubbles" and _summoned and not _summoned2 and hp < max_hp * 0.2 and hp > 0.0:
		_summoned2 = true
		if get_parent().has_method("summon_for"):
			get_parent().summon_for(self)
	if t.get("enrage", false) and not _enraged and hp < max_hp * 0.35 and hp > 0.0:
		_enrage()
	body.flash(Color(1, 1, 1), 0.85)
	Sfx.play_at("hit", global_position + Vector3(0, 1, 0), -3.0, 0.15)
	FX.hit(global_position + Vector3(0, 1.1, 0), Color(1.0, 0.9, 0.7))
	FX.damage_number(global_position + Vector3(0, 2.0 * t.scale / 0.84, 0), amount, Color(1, 1, 1), crit)
	Game.emit_signal("stats_changed")
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("on_enemy_hit"):
		tree.current_scene.on_enemy_hit(self)
	var away := global_position - from_pos
	away.y = 0
	if hp <= 0.0:
		_die(away)
		return
	if state in [S.IDLE, S.RETURN]:
		_go(S.CHASE)
	_stagger_acc += amount
	if _stagger_acc > t.poise:
		_stagger_acc = 0.0
		if away.length() > 0.01:
			var k := away.normalized() * knock
			velocity.x += k.x; velocity.z += k.z
		if state != S.STRIKE:
			_go(S.STAGGER)
			_hurt_t = 0.0

func _die(away: Vector3) -> void:
	_frozen_t = 0.0
	_thaw()
	if _dive_mark and is_instance_valid(_dive_mark):
		_dive_mark.queue_free()
	if look:
		look.create_tween().tween_property(look, "rotation:z", PI * 0.5, 0.5).set_trans(Tween.TRANS_BOUNCE)
	dead = true
	_go(S.DEAD)
	remove_from_group("enemy")
	remove_from_group("damageable")
	collision_layer = 0
	collision_mask = 1
	body.collapse()
	Sfx.play_at("bone_break", global_position, 0.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), t.eye, 24, 2.5, 0.25, 1.0, 1.0)
	Game.kills += 1
	Game.add_xp(t.xp)
	if uid != "":
		Game.flags[uid] = true
	Game.on_enemy_killed(type_id, uid)
	_drop_loot()
	if oddity == "splitter":
		for k in 2:
			var e := Enemy.new()
			e.configure(type_id, "", 0.0)
			e.mini = true
			e.hp_mult = _base_hp_mult
			e.dmg_mult = _base_dmg_mult
			get_parent().add_child.call_deferred(e)
			var at := global_position + Vector3(cos(k * PI) * 1.2, 0.3, sin(k * PI + 0.5) * 1.2)
			e.set_deferred("global_position", at)
		FX.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.9), 40, 4.0, 0.2, 0.7, 0.0)
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(body, "position:y", -1.2, 1.5)
	tw.tween_callback(queue_free)

## A twin for Hard and Insane mode, right beside the original.
func _spawn_twin(tag := "+") -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var e := Enemy.new()
	e.configure(type_id, uid + tag, dormant_wake)
	e.hp_mult = _base_hp_mult
	e.dmg_mult = _base_dmg_mult
	var a := float(absi(hash(uid + tag)) % 628) / 100.0
	var off := Vector3(cos(a), 0, sin(a)) * 2.2
	get_parent().add_child(e)
	e.global_position = home + off + Vector3(0, 0.2, 0)
	e.rotation.y = facing

func _far_cull() -> void:
	if not is_instance_valid(body):
		return
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 80.0
		(g as GeometryInstance3D).visibility_range_end_margin = 4.0

## Insane oddities show: sparkles in yellow (speedy) or pink (splitter).
func _oddity_look() -> void:
	if oddity == "giant":
		return
	var col := Color(1.0, 0.9, 0.2) if oddity == "speedy" else Color(1.0, 0.3, 0.9)
	var p := CPUParticles3D.new(); p.amount = 8; p.lifetime = 0.8
	p.mesh = FX.quad(0.14); p.material_override = FX.glow_material(col, 2.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.6 * float(t.scale)
	p.direction = Vector3.UP; p.spread = 40; p.gravity = Vector3(0, 0.5, 0)
	p.initial_velocity_min = 0.3; p.initial_velocity_max = 0.8
	p.position.y = 1.0 * float(t.scale)
	body.add_child(p)      # (on the body: it rests while the monster sleeps)

## Cloud Island creatures: hide the stand-in skeleton and show the shape-built look.
var look: CreatureLook
func _creature() -> void:
	for m in body.all_meshes:
		if is_instance_valid(m):
			m.visible = false
	for n in body.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = false
	look = CreatureLook.make(String(t.creature), body.flash_mat)
	body.add_child(look)
	# the look sits inside the (already scaled) body; "look_size" sets the final
	# size directly so a boss's scale isn't applied twice
	look.scale = Vector3.ONE * (float(t.look_size) / t.scale if t.has("look_size") else t.scale / 0.9)

## Ghosts: see-through, glowing a cold blue, with a misty trail.
func _spectral() -> void:
	var glow: Color = t.eye
	for m in body.all_meshes:
		if not is_instance_valid(m) or m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as BaseMaterial3D
			var g: StandardMaterial3D = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.albedo_color = Color(0.75, 0.88, 1.0, 0.55)
			g.emission_enabled = true; g.emission = glow * 0.55; g.emission_energy_multiplier = 1.2
			g.cull_mode = BaseMaterial3D.CULL_BACK
			m.set_surface_override_material(i, g)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mist := CPUParticles3D.new()
	mist.amount = 14; mist.lifetime = 1.6
	mist.mesh = FX.quad(0.35 * t.scale); mist.material_override = FX.glow_material(glow, 0.6)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; mist.emission_sphere_radius = 0.4 * t.scale
	mist.direction = Vector3.UP; mist.spread = 30; mist.initial_velocity_min = 0.2; mist.initial_velocity_max = 0.6
	mist.gravity = Vector3.ZERO; mist.color_ramp = FX._fade_ramp(Color(glow.r, glow.g, glow.b, 0.4))
	mist.position.y = 0.5 * t.scale
	add_child(mist)
	var l := OmniLight3D.new(); l.light_color = glow; l.light_energy = 0.7; l.omni_range = 3.5 * t.scale
	l.position.y = 1.2 * t.scale
	add_child(l)

## Ghost knights' armour falls to the ground when they're beaten: helmet and
## plates clatter down, and often a set of ghostly armour you can wear.
func _armor_clatter() -> void:
	var at := global_position
	var metal := StandardMaterial3D.new(); metal.albedo_color = Color(0.62, 0.68, 0.78); metal.metallic = 0.8; metal.roughness = 0.35
	metal.emission_enabled = true; metal.emission = Color(0.1, 0.25, 0.4)
	for k in 4:
		var piece := MeshInstance3D.new()
		var m: Mesh
		if k == 0:
			var sm := SphereMesh.new(); sm.radius = 0.22 * t.scale; sm.height = 0.36 * t.scale; sm.is_hemisphere = true; m = sm
		else:
			var bm := BoxMesh.new(); bm.size = Vector3(0.35, 0.08, 0.28) * t.scale; m = bm
		piece.mesh = m; piece.material_override = metal
		get_tree().current_scene.add_child(piece)
		piece.global_position = at + Vector3(randf_range(-0.3, 0.3), 1.2 * t.scale, randf_range(-0.3, 0.3))
		var land := at + Vector3(randf_range(-1.0, 1.0), 0.05, randf_range(-1.0, 1.0))
		var tw := piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "global_position", land, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_property(piece, "rotation", Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)), 0.55)
		tw.chain().tween_interval(6.0)
		tw.chain().tween_callback(piece.queue_free)
	Sfx.play_at("clang", at, -4.0, 0.2)
	if randf() < float(t.armor_drop):
		Pickup.spawn(at + Vector3(0, 0.9, 0), "item", 1, Loot.make_ghost_armor(Game.zone_level(), Loot.roll_rarity(0.8, 1)))

func _drop_loot() -> void:
	var g: Array = t.gold
	Pickup.spawn(global_position + Vector3(0, 0.6, 0), "gold", randi_range(g[0], g[1]))
	var table := "summon" if uid == "" else type_id
	if t.has("armor_drop"):
		_armor_clatter()
	# now and then a monster drops a costume of itself
	var ms: Array = Loot.MONSTER_SKINS.get(type_id, [])
	if not ms.is_empty() and randf() < float(ms[1]) and Loot.COSTUMES.has(ms[0]):
		Pickup.spawn(global_position + Vector3(0, 0.9, 0), "costume", 1, String(ms[0]))
	var k := 0
	for d in Loot.roll_enemy(table, Loot.area_level(global_position.z)):
		k += 1
		var off := Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.5
		Pickup.spawn(global_position + Vector3(0, 0.7, 0) + off, d.kind, int(d.get("amount", 1)), String(d.get("id", "")))
