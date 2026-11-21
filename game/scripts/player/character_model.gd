extends Node3D
class_name CharacterModel
## Wraps an animated KayKit glTF character (CC0, Kay Lousberg) behind the same
## animation-input interface as the procedural Humanoid: the controller writes
## move_speed / grounded / attack_t / blocking / ... and this node chooses and
## blends the right clips. Weapons attach to the rig's handslot bones.

var move_speed := 0.0
var grounded := true
var attack_t := -1.0
var attack_kind := 0
var attack_dur := 0.55
var blocking := false
var cast_t := -1.0
var dodge_t := -1.0
var dodge_dir := Vector2(0, -1)   # local x/z of the roll direction
var hurt_t := -1.0
var dead := false
var backwards := false
var local_move := Vector2.ZERO
var _loco := ""          # locomotion clip currently shown
var _pend := ""          # clip the input is asking for
var _pend_t := 0.0
var loco_switches := 0   # velocity in the body frame: x = right, y = back (m/s)

var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var flash_mat: StandardMaterial3D
var weapon_root: BoneAttachment3D
var offhand_root: BoneAttachment3D
## Weapons away: the weapon and shield ride on the back (on the chest bone)
## instead of in the hands. The player draws them to fight (Player.draw_weapon).
var sheathed := false
var _wpivot: Node3D          # the weapon (and its tip) under weapon_root
var _spivot: Node3D          # the shield under offhand_root
var _back_weapon := Transform3D.IDENTITY
var _back_shield := Transform3D.IDENTITY
var _shield_depth := 0.0     # a sheathed weapon rides on top of the shield
var weapon_tip: Node3D
var head_meshes: Array[MeshInstance3D] = []
var hold_clip := ""
var _stripes := Color.BLACK   # cfg "outfit_stripes": striped pajamas in the opening movie      # cutscenes: keep playing this clip instead of walking/idling
var all_meshes: Array[MeshInstance3D] = []
var kind := "hero"            # "hero" | "skeleton"
var anims := {}               # role -> clip name
var _last_attack_t := -1.0
var _last_cast_t := -1.0
var _last_dodge_t := -1.0
var _last_hurt_t := -1.0
var _oneshot := ""
var _oneshot_until := 0.0
var _clock := 0.0
var _base_scale := 1.0

const HEROES := {
	"Knight": {"path": "res://assets/kaykit/adventurers/Knight.glb", "sex": "male", "head": ["Knight_Head", "Knight_Helmet"], "hat": "Knight_Helmet", "cape": "Knight_Cape"},
	"Barbarian": {"path": "res://assets/kaykit/adventurers/Barbarian.glb", "body": "res://assets/kaykit/adv2/Barbarian.glb",
		"sex": "male", "head": ["Barbarian_Head", "Barbarian_BearHat"], "hat": "Barbarian_BearHat", "cape": ""},
	"Rogue": {"path": "res://assets/kaykit/adventurers/Rogue.glb", "sex": "female", "head": ["Rogue_Head"], "hat": "", "cape": "Rogue_Cape"},
	"Ranger": {"path": "res://assets/kaykit/adventurers/Rogue.glb", "body": "res://assets/kaykit/adv2/Ranger.glb",
		"sex": "male", "head": ["Ranger_Head"], "hat": "", "cape": "Ranger_Cape"},
	"Mage": {"path": "res://assets/kaykit/adventurers/Mage.glb", "sex": "male", "head": ["Mage_Head", "Mage_Hat"], "hat": "Mage_Hat", "cape": "Mage_Cape"},
	# Classes with their own body: the rig and animations come from "path", the
	# whole body (head, clothes, gear) is swapped for the "body" model's pieces.
	"Priest": {"path": "res://assets/kaykit/adventurers/Mage.glb", "body": "res://assets/kaykit/costumes/Cleric.glb",
		"sex": "female", "head": ["Cleric_Head"], "hat": "", "cape": ""},
	"Druid": {"path": "res://assets/kaykit/adventurers/Mage.glb", "body": "res://assets/kaykit/adv2/Druid.glb",
		"sex": "male", "head": ["Druid_Head"], "hat": "", "cape": ""},
	"Necromancer": {"path": "res://assets/kaykit/adventurers/Mage.glb", "body": "res://assets/kaykit/costumes/Necromancer.glb",
		"sex": "male", "head": ["Necromancer_Head", "Necromancer_Crown"], "hat": "Necromancer_Crown", "cape": ""},
	"Beastmaster": {"path": "res://assets/kaykit/adventurers/Barbarian.glb", "body": "res://assets/kaykit/costumes/Survivalist.glb",
		"sex": "male", "head": ["Survivalist_Head"], "hat": "", "cape": ""},
	# the green-hooded Rogue of the cover art (the statue at the Outpost)
	"HoodedRogue": {"path": "res://assets/kaykit/adventurers/Rogue_Hooded.glb", "sex": "female", "head": ["Rogue_Head_Hooded"], "hat": "", "cape": "Rogue_Cape"},
}
const SKELETONS := {
	"minion": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
	"warrior": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"rogue": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
	"mage": "res://assets/kaykit/skeletons/Skeleton_Mage.glb",
}
const HERO_WEAPON_LENGTH := 1.45
## Hair styles that swap in a modelled head from KayKit Adventurers 2.0 (same
## rig, same head bone, so it sits exactly where the hero's own head was).
const HAIR_HEADS := {
	"short": ["res://assets/kaykit/adv2/Knight.glb", "Knight_Head"],
	"long": ["res://assets/kaykit/adv2/Mage.glb", "Mage_Head"],
	"swept": ["res://assets/kaykit/adv2/Ranger.glb", "Ranger_Head"],
	"shoulder": ["res://assets/kaykit/adv2/Rogue.glb", "Rogue_Head"],
	"wild": ["res://assets/kaykit/adv2/Engineer.glb", "Engineer_Head"],
	"bald": ["res://assets/kaykit/adv2/Barbarian.glb", "Barbarian_Head"],
}
const HAIR_HEAD_BEARDED := ["wild", "bald"]       # these heads already have a beard
## Man or woman: the other version's hair (when you haven't picked a style), and
## each class's own hair colour so they still look like that class.
const FEMALE_HAIR := {"Mage": "shoulder"}         # (the Mage man already has long hair)
const MALE_HAIR := {}
const FEMALE_KEEPS_HEAD := ["Druid"]
const CLASS_HAIR := {"Knight": Color(0.86, 0.68, 0.38), "Rogue": Color(0.78, 0.4, 0.2), "Ranger": Color(0.72, 0.36, 0.16),
	"Necromancer": Color(0.9, 0.9, 0.93), "Priest": Color(0.78, 0.8, 0.86), "Mage": Color(0.24, 0.14, 0.09)}
## The head that buns and spikes are built on, per hero.
const BUN_SPIKE_BASE := {"Knight": "short", "Barbarian": "short", "Mage": "long", "Rogue": "shoulder"}
## Old saved styles -> the closest current one.
const HAIR_ALIASES := {"curly": "wild", "ponytail": "shoulder", "mohawk": "spiky"}
const MAGE_HAT_CROWN_R := 0.62     # hat-local radius where the brim starts
const MAGE_HAT_BRIM := 0.32        # brim width kept (0..1)
const MAGE_HAT_TIP_Y := 0.25       # above this the point is shortened...
const MAGE_HAT_TIP := 0.7          # ...to this fraction
static var _small_hat_cache := {}

## The Mage's hat with a much narrower brim and a shorter point; the crown still
## fits the head (shrinking the whole hat made the head poke through it).
static func _small_mage_hat(src: Mesh) -> Mesh:
	if _small_hat_cache.has(src):
		return _small_hat_cache[src]
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			var p := v[i]
			var r := Vector2(p.x, p.z).length()
			if r > MAGE_HAT_CROWN_R:
				var k := (MAGE_HAT_CROWN_R + (r - MAGE_HAT_CROWN_R) * MAGE_HAT_BRIM) / r
				p.x *= k; p.z *= k
			if p.y > MAGE_HAT_TIP_Y:
				p.y = MAGE_HAT_TIP_Y + (p.y - MAGE_HAT_TIP_Y) * MAGE_HAT_TIP
			v[i] = p
		arr[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, src.surface_get_material(s))
	_small_hat_cache[src] = out
	return out
## The modelled heads' own hair colours (buns/spikes on "hero's own" match them).
const HEAD_OWN_HAIR := {"short": Color(0.86, 0.72, 0.46), "long": Color(0.13, 0.11, 0.11), "shoulder": Color(0.55, 0.32, 0.2)}
## Each hero's own hair colour (for face details on "hero's own").
const HERO_OWN_HAIR := {"Knight": Color(0.86, 0.74, 0.5), "Rogue": Color(0.8, 0.62, 0.36),
	"Barbarian": Color(0.62, 0.62, 0.66), "Mage": Color(0.13, 0.11, 0.11), "Ranger": Color(0.42, 0.26, 0.15),
	"Priest": Color(0.85, 0.7, 0.4), "Druid": Color(0.55, 0.4, 0.25), "Necromancer": Color(0.9, 0.9, 0.92), "Beastmaster": Color(0.4, 0.26, 0.15)}

static func hair_style_of(st: String) -> String:
	return HAIR_ALIASES.get(st, st)
const KEEP_MESHES := ["Body", "Head", "Arm", "Leg", "Cape", "Cloak", "Eyes", "Jaw", "Helmet", "Hat", "Hood", "Skull"]

const WEAPON_SCENES := {
	"rusty_sword": "res://assets/kaykit/items/Skeleton_Blade.gltf",
	"knight_sword": "res://assets/kaykit/items/sword_1handed.gltf",
	"vault_blade": "res://assets/kaykit/items/sword_2handed_color.gltf",
	"skel_blade": "res://assets/kaykit/items/Skeleton_Blade.gltf",
	"skel_axe": "res://assets/kaykit/items/Skeleton_Axe.gltf",
	"skel_staff": "res://assets/kaykit/items/Skeleton_Staff.gltf",
	"sword_1handed": "res://assets/kaykit/items/sword_1handed.gltf",
	"sword_2handed_color": "res://assets/kaykit/items/sword_2handed_color.gltf",
	"necro_staff": "res://assets/kaykit/items/Skeleton_Staff.gltf",
}
## Classes that always carry their own kind of weapon, whatever blade you equip
## (its stats and rarity glow still count): the Necromancer's long bone staff.
const CLASS_WEAPON := {"Necromancer": "necro_staff"}
const TWO_HANDED := ["necro_staff"]
var hero_name := ""
## How each skin changes the body: albedo multiply, metal/rough, emission, alpha.
const SKIN_LOOKS := {
	"lizard": {"albedo": Color(0.55, 1.0, 0.45), "rough": 0.45, "emit": Color(0.03, 0.14, 0.02)},
	"frost": {"albedo": Color(0.72, 0.9, 1.0), "rough": 0.25, "metal": 0.2, "emit": Color(0.1, 0.25, 0.45)},
	"gold": {"albedo": Color(1.0, 0.85, 0.4), "rough": 0.3, "metal": 0.55, "emit": Color(0.42, 0.3, 0.06)},
	"spectral": {"albedo": Color(0.55, 0.88, 1.0, 0.42), "rough": 0.3, "emit": Color(0.25, 0.6, 0.9), "alpha": true},
	"ember": {"albedo": Color(1.0, 0.55, 0.4), "rough": 0.6, "emit": Color(0.9, 0.28, 0.05)},
}
var _aura: Node3D
## Dark costume finishes: a colour wash, an eerie glow, and a dark aura at the feet.
const DARK_LOOKS := {
	"shadow": {"albedo": Color(0.5, 0.45, 0.6), "rough": 0.45, "emit": Color(0.08, 0.0, 0.14), "aura": Color(0.6, 0.2, 1.0)},
	"rot": {"albedo": Color(0.6, 0.85, 0.5), "rough": 0.8, "emit": Color(0.03, 0.12, 0.0), "aura": Color(0.45, 1.0, 0.3)},
	"deathly": {"albedo": Color(0.55, 0.7, 0.85), "rough": 0.4, "metal": 0.2, "emit": Color(0.05, 0.22, 0.45), "aura": Color(0.3, 0.75, 1.0)},
	"infernal": {"albedo": Color(0.85, 0.38, 0.32), "rough": 0.5, "emit": Color(0.55, 0.08, 0.02), "aura": Color(1.0, 0.3, 0.1)},
	# the shop-only finishes (Tobble's Trading Post)
	"golden": {"albedo": Color(1.0, 0.8, 0.38), "rough": 0.28, "metal": 0.85, "emit": Color(0.22, 0.13, 0.0), "aura": Color(1.0, 0.82, 0.3)},
	"starlight": {"albedo": Color(0.72, 0.78, 1.0), "rough": 0.3, "metal": 0.35, "emit": Color(0.16, 0.2, 0.5), "aura": Color(0.75, 0.82, 1.0)},
	"frost": {"albedo": Color(0.78, 0.95, 1.0), "rough": 0.18, "metal": 0.15, "emit": Color(0.08, 0.28, 0.38), "aura": Color(0.55, 0.92, 1.0)},
	"candy": {"albedo": Color(1.0, 0.66, 0.88), "rough": 0.35, "emit": Color(0.3, 0.05, 0.2), "aura": Color(1.0, 0.55, 0.9)},
}

## cfg: {kind:"hero", hero:"Knight", cape_color:Color, outfit_color:Color, show_hat:bool, weapon:id, shield:id|""}
##      {kind:"skeleton", variant:"minion", weapon:"skel_blade", shield:"Skeleton_Shield_Small_A", eye:Color}
func setup(cfg: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	hero_name = String(cfg.get("hero", "")) if String(cfg.get("kind", "hero")) == "hero" else ""
	_aura = null
	_cloud_kind = ""
	head_meshes.clear(); all_meshes.clear(); _never_show.clear(); _own_colors.clear()
	# a costume made from one of the game's own characters is just a different look
	var costume_file := ""
	var costume_fx := ""
	if cfg.has("costume") and Loot.COSTUMES.has(cfg.costume):
		var c: Dictionary = Loot.COSTUMES[cfg.costume]
		if c.has("cloud"):
			_cloud_kind = String(c.cloud)
			cfg = cloud_skin_cfg(_cloud_kind, cfg)
		elif c.has("look"):
			cfg = costume_look_cfg(String(c.look), cfg)
		else:
			var f := String(c.file)
			costume_file = "res://assets/kaykit/%s.glb" % (f if f.contains("/") else "costumes/" + f)
			costume_fx = String(c.get("fx", ""))
	kind = cfg.get("kind", "hero")
	_stripes = cfg.get("outfit_stripes", Color.BLACK)
	var skin: String = cfg.get("skin", "")
	if skin == "bone":
		kind = "skeleton"
		cfg = cfg.duplicate()
		cfg["variant"] = "warrior"
		cfg["eye"] = Color(0.4, 1.0, 0.8)
	var path: String
	var hero: Dictionary = {}
	if kind == "hero":
		hero = HEROES.get(cfg.get("hero", "Knight"), HEROES.Knight)
		path = hero.path
		if cfg.has("hair_style"):
			cfg = cfg.duplicate()
			cfg["hair_style"] = hair_style_of(String(cfg.hair_style))
	else:
		path = SKELETONS.get(cfg.get("variant", "minion"), SKELETONS.minion)
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	model.rotation.y = PI   # KayKit faces +Z; our characters face -Z
	anim = model.find_child("AnimationPlayer", true, false)
	for n in model.find_children("*", "Skeleton3D", true, false):
		skel = n
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var keep := false
		for k in KEEP_MESHES:
			if String(m.name).contains(k):
				keep = true
		m.visible = keep
		if not keep:
			continue
		m.material_overlay = flash_mat
		all_meshes.append(m)
		if kind == "hero":
			if m.name in hero.head:
				head_meshes.append(m)
			if hero.hat != "" and m.name == hero.hat and not cfg.get("show_hat", true):
				m.visible = false
				_never_show.append(m)
			if m.name == "Mage_Hat":
				# a slimmer hat (narrow brim, shorter point) so you can see past it
				m.mesh = _small_mage_hat(m.mesh)
			if m.name == hero.cape and cfg.has("cape_color"):
				_recolor(m, cfg.cape_color, 1.0, 0.0, null)
		else:
			if String(m.name).contains("Head") or String(m.name).contains("Jaw") or String(m.name).contains("Skull") or String(m.name).contains("Eyes") or String(m.name).contains("Helmet") or String(m.name).contains("Hat") or String(m.name).contains("Hood"):
				head_meshes.append(m)
			if String(m.name).contains("Eyes") and cfg.has("eye"):
				var em := StandardMaterial3D.new()
				em.albedo_color = cfg.eye
				em.emission_enabled = true; em.emission = cfg.eye; em.emission_energy_multiplier = 6.0
				m.material_override = em
	_setup_anims()
	if kind == "hero" and hero.has("body") and costume_file == "":
		_wear_class_body(hero, cfg)
	if costume_file != "":
		_wear_costume(costume_file, cfg)
		if DARK_LOOKS.has(costume_fx):
			var dl: Dictionary = DARK_LOOKS[costume_fx]
			for m in all_meshes:
				var mn := String(m.name)
				_skin_mat(m, dl, mn.contains("Cape") or mn.contains("Cloak"))
			_add_aura(dl.aura, 2, costume_fx == "infernal")
		return
	if cfg.has("outfit_model") and kind == "hero":
		_wear_outfit(String(cfg.outfit_model), cfg)
	_custom_head = false
	_part_styles.clear()
	if cfg.has("custom_look") and kind == "hero" and cfg.custom_look is Dictionary:
		_wear_custom(cfg.custom_look)
	if SKIN_LOOKS.get(skin, {}).is_empty() and skin != "bone":
		# outfit colour chosen at the start tints body, arms, legs and headgear;
		# armour found later adds its own lighter tint on top
		var outfit: Color = cfg.get("outfit_color", Color.WHITE)
		var has_outfit := outfit != Color.WHITE
		var armor_t: Color = Color.WHITE.lerp(cfg.tint, 0.45 if not has_outfit else 0.25) if cfg.has("tint") else Color.WHITE
		var skin_c = cfg.get("skin_color", null)
		var hair_t = cfg.get("hair_tint", null)
		if kind != "hero":
			skin_c = null
			hair_t = null
		for m in all_meshes:
			var nm := String(m.name)
			if nm.contains("Cape") or nm.contains("Eyes"):
				continue
			if m in _own_colors:
				# outfit pieces keep their own colours; only the skin tone changes
				if skin_c != null and String(cfg.get("outfit_fx", "")) == "" and not _has_finish(m):
					_recolor(m, Color.WHITE, 0.0, 1.0, skin_c, null)
				continue
			var is_head := nm.contains("_Head")
			if skin_c != null or has_outfit or (is_head and hair_t != null):
				var st := 0.0 if is_head else (0.72 if has_outfit else (0.3 if armor_t != Color.WHITE else 0.0))
				_recolor(m, (outfit if has_outfit else Color.WHITE) * armor_t, st, 1.0, skin_c, hair_t if is_head else null)
			elif armor_t != Color.WHITE and not is_head:
				_mul(m, armor_t)
	# dark armour skins: shadowy / ghostly / fiery finish on the outfit pieces
	var ofx := String(cfg.get("outfit_fx", ""))
	if DARK_LOOKS.has(ofx) and not _own_colors.is_empty():
		for m in _own_colors:
			_skin_mat(m, DARK_LOOKS[ofx], false)
		if not cfg.has("aura"):
			_add_aura(DARK_LOOKS[ofx].aura, 2, ofx == "infernal")
	if SKIN_LOOKS.has(skin):
		for m in all_meshes:
			if String(m.name).contains("Eyes"):
				continue
			_skin_mat(m, SKIN_LOOKS[skin], String(m.name).contains("Cape"))
	_style_custom_parts()
	var weapon = cfg.get("weapon", "")
	set_weapon(weapon)
	set_offhand(_offhand_for(cfg))
	if cfg.has("aura"):
		_add_aura(cfg.aura, int(cfg.get("aura_level", 3)), skin == "ember")
	elif skin == "ember":
		_add_aura(Color(1.0, 0.45, 0.15), 2, true)
	_base_scale = float(cfg.get("scale", 0.84))
	scale = Vector3.ONE * _base_scale
	if kind == "hero":
		var hat_on: bool = hero.hat != "" and cfg.get("show_hat", true)
		var hooded: bool = String(hero.get("path", "")).contains("Hooded")
		# Male or female: every class can be either. The other version gets a head
		# that's clearly a man's or a woman's (short hair / long hair), and the body
		# is broader or slimmer, so the two look very different.
		var base_sex := String(hero.get("sex", "male"))
		var want_sex := String(cfg.get("sex", base_sex))
		# (a full knight's helm stays on: the hair would poke through it, so a
		# heroine in a helm shows a long braid hanging out the back instead)
		var full_helm: bool = hat_on and String(hero.hat) == "Knight_Helmet"
		var swap_sex := cfg.has("sex") and want_sex != base_sex and not hooded and not full_helm
		var hs := String(cfg.get("hair_style", ""))
		# the Druid's antlered hood is the Druid: a heroine keeps it (and gets a braid)
		# unless she picks a hair style
		var keep_hood := swap_sex and hs in ["", "natural"] and FEMALE_KEEPS_HEAD.has(hero_name) and want_sex == "female"
		if keep_hood:
			swap_sex = false
		if swap_sex or (cfg.has("sex") and want_sex == "female" and hs in HAIR_HEAD_BEARDED):
			cfg = cfg.duplicate()
			if swap_sex and hs in ["", "natural"]:
				hs = String((FEMALE_HAIR if want_sex == "female" else MALE_HAIR).get(hero_name, "long" if want_sex == "female" else "short"))
			if want_sex == "female" and hs in HAIR_HEAD_BEARDED:
				hs = "long" if hs == "wild" else "shoulder"   # those heads come with beards
			cfg["hair_style"] = hs
			# the class's own hair colour, unless you picked one
			if Color(cfg.get("hair_color", Game.HAIR_COLORS2[0])) == Game.HAIR_COLORS2[0] and CLASS_HAIR.has(hero_name):
				cfg["hair_color"] = CLASS_HAIR[hero_name]
		var bw := float(cfg.get("build", 1.0))
		var bh := float(cfg.get("height", 1.0))
		if cfg.has("sex"):
			bw *= 0.9 if want_sex == "female" else 1.07
			bh *= 0.97 if want_sex == "female" else 1.02
		model.scale = Vector3(bw, bh, lerpf(1.0, bw, 0.85))
		if _custom_head:
			pass   # a designer head replaces the hero's own head, hair and face
		elif swap_sex or not (hat_on or hooded):
			if HAIR_HEADS.has(hs):
				_swap_head(hero, cfg, skin, hs)
			elif hs in ["buns", "spiky"]:
				# buns and spikes sit on a modelled head too, so the colour always takes
				var base_head: String = BUN_SPIKE_BASE.get(String(cfg.get("hero", "Knight")), "short")
				if swap_sex:
					base_head = "long" if want_sex == "female" else "short"
				_swap_head(hero, cfg, skin, base_head)
		if not _custom_head:
			_add_head_looks(hero, cfg, hat_on or hooded or keep_hood)
		if cfg.has("sex") and want_sex == "female" and hero_name == "Barbarian" and costume_file == "":
			_fur_top()
		if _cloud_kind != "":
			_cloud_extras(_cloud_kind, hero)
	_play(anims.idle, 0.0)

# --- Cloud Island skins (designed by Jason's son): the hero, recoloured, plus pieces
# made from shapes (wings, snouts, balloons, a bubble...). Each one also sets
# how floaty you are on Cloud Island (Loot.COSTUMES[...].float).
var _cloud_kind := ""

static func cloud_skin_cfg(kind: String, base: Dictionary) -> Dictionary:
	var cfg := base.duplicate()
	cfg.erase("costume"); cfg.erase("outfit_model"); cfg.erase("outfit_fx"); cfg.erase("tint")
	var looks := {
		"angel": [Color(0.95, 0.78, 0.62), Color(0.97, 0.95, 0.88), "long", Color(1.0, 0.85, 0.45)],
		"flying_pig": [Color(1.0, 0.72, 0.76), Color(1.0, 0.62, 0.7), "bald", Color(1.0, 0.7, 0.75)],
		"balloon_man": [Color(0.97, 0.82, 0.7), Color(0.95, 0.25, 0.3), "curly", Color(0.2, 0.55, 1.0)],
		"bubble_kid": [Color(0.97, 0.82, 0.7), Color(0.6, 0.85, 1.0), "natural", Color(0.5, 0.75, 1.0)],
		"dandelion": [Color(0.7, 0.88, 0.5), Color(0.35, 0.65, 0.3), "bald", Color(1, 1, 1)],
		"jellyfish": [Color(0.95, 0.7, 0.95), Color(0.75, 0.5, 0.95), "bald", Color(0.9, 0.6, 1.0)],
		"bubbles_cub": [Color(0.62, 0.44, 0.3), Color(0.6, 0.42, 0.28), "bald", Color(0.55, 0.38, 0.25)],
		"thunder_bird": [Color(1.0, 0.85, 0.35), Color(0.25, 0.45, 0.95), "spiky", Color(1.0, 0.85, 0.3)],
		"sky_whale": [Color(0.6, 0.75, 1.0), Color(0.35, 0.55, 0.92), "bald", Color(0.5, 0.65, 1.0)],
		"snowman": [Color(0.97, 0.98, 1.0), Color(0.95, 0.97, 1.0), "bald", Color(1, 1, 1)],
		"penguin": [Color(0.12, 0.12, 0.15), Color(0.1, 0.1, 0.14), "bald", Color(0.1, 0.1, 0.12)],
		"rubber_duck": [Color(1.0, 0.86, 0.2), Color(1.0, 0.86, 0.2), "bald", Color(1.0, 0.85, 0.2)],
	}
	var l: Array = looks.get(kind, looks.angel)
	cfg["skin_color"] = l[0]
	cfg["outfit_color"] = l[1]
	cfg["cape_color"] = (l[1] as Color).darkened(0.15)
	cfg["hair_style"] = l[2]
	cfg["hair_color"] = l[3]; cfg["hair_tint"] = l[3]
	cfg["show_hat"] = false
	cfg["face"] = "blush" if kind in ["angel", "bubble_kid", "flying_pig", "balloon_man"] else "none"
	return cfg

## A node on a bone, authored in skeleton space (positions below are in metres
## on the hero rig: front is +Z, back is -Z, the head's centre is about y 1.6).
func _on_bone(bone: String) -> Node3D:
	var ba := _attach(bone)
	if ba == null:
		return null
	var n := Node3D.new()
	n.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()
	ba.add_child(n)
	return n

func _cp(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO, head := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.material_overlay = flash_mat
	mi.position = pos; mi.scale = scl; mi.rotation = rot
	parent.add_child(mi)
	if head:
		head_meshes.append(mi)
	return mi

func _cone_m(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = r; c.height = h; c.radial_segments = 12
	return c

func _cyl_m(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 14
	return c

func _glassy(c: Color, a := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 0.4; m.roughness = 0.05
	return m

func _cloud_extras(kind: String, hero: Dictionary) -> void:
	var head := _on_bone("head")
	var chest := _on_bone("chest")
	if head == null or chest == null:
		return
	var hb := _head_bounds(hero)
	var hc := hb.get_center()
	var hr := hb.size.x * 0.5
	var front := hc + Vector3(0, -0.05, hb.size.z * 0.5)
	var top := hc + Vector3(0, hb.size.y * 0.5, 0)
	var back := Vector3(0, 1.05, -0.18)
	match kind:
		"angel":
			var w := AngelWings.make(Color(1, 1, 1), 1.0)
			w.position = Vector3(0, -0.3, -0.05); w.rotation.y = PI
			chest.add_child(w)
			var halo := _cp(head, TorusMesh.new(), FX.glow_material(Color(1.0, 0.88, 0.4), 2.0), top + Vector3(0, 0.18, 0), Vector3(0.55, 0.3, 0.55) * hr * 2.0, Vector3.ZERO, true)
			(halo.mesh as TorusMesh).inner_radius = 0.8; (halo.mesh as TorusMesh).outer_radius = 1.0
		"flying_pig":
			var pink := _look_mat(Color(1.0, 0.65, 0.72), 0.6)
			var dark := _look_mat(Color(0.6, 0.25, 0.3), 0.5)
			var sn := _cp(head, _cyl_m(hr * 0.32, hr * 0.3), pink, front + Vector3(0, -0.05, 0.02), Vector3.ONE, Vector3(PI * 0.5, 0, 0), true)
			for sx in [-1.0, 1.0]:
				_cp(head, _sphere(), dark, front + Vector3(sx * hr * 0.12, -0.05, hr * 0.16), Vector3.ONE * hr * 0.06, Vector3.ZERO, true)
				_cp(head, _cone_m(hr * 0.22, hr * 0.4), pink, top + Vector3(sx * hr * 0.62, -0.05, 0), Vector3.ONE, Vector3(0, 0, -sx * 0.5), true)
				var wg := _cp(chest, _boxm(0.38, 0.03, 0.22), _look_mat(Color(1, 1, 1), 0.6), back + Vector3(sx * 0.24, 0.05, -0.04), Vector3.ONE, Vector3(0, sx * 0.3, sx * 0.4))
			var tail := _cp(chest, TorusMesh.new(), pink, Vector3(0, 0.55, -0.24), Vector3.ONE * 0.09, Vector3(PI * 0.5, 0, 0))
		"balloon_man":
			var cols := [Color(0.95, 0.2, 0.25), Color(0.2, 0.55, 1.0), Color(1.0, 0.85, 0.2), Color(0.3, 0.85, 0.4), Color(0.85, 0.4, 0.95)]
			for k in 5:
				var a := k * TAU / 5.0
				var bp := Vector3(cos(a) * 0.32, 2.35 + (k % 2) * 0.2, sin(a) * 0.32 - 0.25)
				var bm := _look_mat(cols[k], 0.15); bm.metallic_specular = 1.0
				_cp(chest, _sphere(), bm, bp, Vector3(0.24, 0.3, 0.24))
				var string_len := bp.distance_to(back)
				var st := _cp(chest, _cyl_m(0.006, string_len), _look_mat(Color(0.95, 0.95, 0.95)), (bp + back) * 0.5)
				st.basis = Basis(Quaternion(Vector3.UP, (bp - back).normalized()))
			_cp(head, _sphere(), _look_mat(Color(0.95, 0.15, 0.2), 0.2), front + Vector3(0, -0.02, 0.03), Vector3.ONE * hr * 0.16, Vector3.ZERO, true)
		"bubble_kid":
			_cp(chest, _sphere(), _glassy(Color(0.7, 0.9, 1.0), 0.18), Vector3(0, 0.95, 0), Vector3(0.75, 1.0, 0.75))
		"dandelion":
			var seedm := _look_mat(Color(1, 1, 1), 0.9)
			for k in 34:
				var u := randf() * TAU; var v := acos(randf_range(-0.6, 1.0))
				var dirv := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
				var sp := _cp(head, _cyl_m(0.006, hr * 0.9), seedm, top + Vector3(0, 0.05, 0) + dirv * hr * 0.45, Vector3.ONE, Vector3.ZERO, true)
				sp.basis = Basis(Quaternion(Vector3.UP, dirv))
				_cp(head, _sphere(), seedm, top + Vector3(0, 0.05, 0) + dirv * hr * 0.9, Vector3.ONE * hr * 0.07, Vector3.ZERO, true)
		"jellyfish":
			var bell := _glassy(Color(0.95, 0.55, 0.95), 0.45)
			_cp(head, _sphere(true), bell, top + Vector3(0, -0.12, 0), Vector3(hr * 1.25, hr * 1.1, hr * 1.25), Vector3.ZERO, true)
			for k in 8:
				var a := k * TAU / 8.0
				var tt := _cp(chest, _cyl_m(0.015, 0.7), bell, Vector3(cos(a) * 0.28, 0.95, sin(a) * 0.22), Vector3.ONE, Vector3(sin(a) * 0.15, 0, cos(a) * 0.15))
		"bubbles_cub":
			var fur := _look_mat(Color(0.6, 0.42, 0.28), 0.9)
			var lite := _look_mat(Color(0.9, 0.75, 0.6), 0.9)
			for sx in [-1.0, 1.0]:
				_cp(head, _sphere(), fur, top + Vector3(sx * hr * 0.7, -0.05, 0), Vector3.ONE * hr * 0.28, Vector3.ZERO, true)
				_cp(head, _sphere(), lite, top + Vector3(sx * hr * 0.7, -0.05, hr * 0.12), Vector3.ONE * hr * 0.15, Vector3.ZERO, true)
				_cp(chest, _sphere(), _look_mat(Color(0.75, 0.78, 0.88), 0.9), back + Vector3(sx * 0.25, 0.08, -0.05), Vector3(0.22, 0.12, 0.15))
			_cp(head, _sphere(), lite, front + Vector3(0, -0.12, 0), Vector3(hr * 0.35, hr * 0.25, hr * 0.2), Vector3.ZERO, true)
			_cp(head, _sphere(), _look_mat(Color(0.1, 0.07, 0.05), 0.3), front + Vector3(0, -0.08, hr * 0.15), Vector3.ONE * hr * 0.08, Vector3.ZERO, true)
		"thunder_bird":
			_cp(head, _cone_m(hr * 0.2, hr * 0.55), _look_mat(Color(1.0, 0.55, 0.1)), front + Vector3(0, -0.06, hr * 0.2), Vector3.ONE, Vector3(PI * 0.5, 0, 0), true)
			for k in 3:
				_cp(head, _cone_m(hr * 0.08, hr * 0.6), FX.glow_material(Color(1.0, 0.95, 0.3), 2.0), top + Vector3((k - 1) * hr * 0.25, 0.08, -0.03 * k), Vector3.ONE, Vector3(0, 0, (k - 1) * 0.35), true)
			for sx in [-1.0, 1.0]:
				_cp(chest, _boxm(0.6, 0.04, 0.35), _look_mat(Color(0.25, 0.45, 0.95), 0.6), back + Vector3(sx * 0.38, 0.0, -0.05), Vector3.ONE, Vector3(0, 0, sx * 0.35))
		"sky_whale":
			var blue := _look_mat(Color(0.4, 0.6, 0.95), 0.5)
			_cp(chest, _boxm(0.55, 0.06, 0.25), blue, Vector3(0, 0.6, -0.4), Vector3.ONE, Vector3(0.3, 0, 0))
			for sx in [-1.0, 1.0]:
				_cp(chest, _boxm(0.3, 0.05, 0.16), blue, Vector3(sx * 0.32, 0.95, 0), Vector3.ONE, Vector3(0, 0, sx * 0.5))
			var spout := CPUParticles3D.new(); spout.amount = 24; spout.lifetime = 0.9
			spout.mesh = FX.quad(0.06); spout.material_override = FX.glow_material(Color(0.7, 0.85, 1.0), 1.0)
			spout.direction = Vector3.UP; spout.spread = 12; spout.initial_velocity_min = 2.0; spout.initial_velocity_max = 3.0
			spout.gravity = Vector3(0, -6, 0); spout.position = top + Vector3(0, 0.05, 0)
			head.add_child(spout)
		"snowman":
			var coal := _look_mat(Color(0.08, 0.08, 0.08), 0.8)
			_cp(head, _cone_m(hr * 0.1, hr * 0.6), _look_mat(Color(1.0, 0.5, 0.1)), front + Vector3(0, -0.02, hr * 0.25), Vector3.ONE, Vector3(PI * 0.5, 0, 0), true)
			_cp(head, _cyl_m(hr * 0.55, hr * 0.15), coal, top + Vector3(0, 0.02, 0), Vector3.ONE, Vector3.ZERO, true)
			_cp(head, _cyl_m(hr * 0.38, hr * 0.7), coal, top + Vector3(0, 0.38 * hr, 0), Vector3.ONE, Vector3.ZERO, true)
			_cp(chest, _cyl_m(0.25, 0.1), _look_mat(Color(0.85, 0.15, 0.2), 0.8), Vector3(0, 1.18, 0))
			for k in 3:
				_cp(chest, _sphere(), coal, Vector3(0, 0.95 - k * 0.15, 0.22), Vector3.ONE * 0.035)
		"penguin":
			_cp(chest, _sphere(), _look_mat(Color(0.97, 0.97, 0.97), 0.7), Vector3(0, 0.8, 0.14), Vector3(0.24, 0.38, 0.12))
			_cp(head, _cone_m(hr * 0.18, hr * 0.4), _look_mat(Color(1.0, 0.6, 0.1)), front + Vector3(0, -0.06, hr * 0.15), Vector3.ONE, Vector3(PI * 0.5, 0, 0), true)
			_cp(head, _sphere(), _look_mat(Color(0.97, 0.97, 0.97), 0.7), front + Vector3(0, 0.02, -hr * 0.05), Vector3(hr * 0.55, hr * 0.4, hr * 0.15), Vector3.ZERO, true)
		"rubber_duck":
			var orange := _look_mat(Color(1.0, 0.55, 0.1), 0.3)
			_cp(head, _sphere(), orange, front + Vector3(0, -0.1, hr * 0.12), Vector3(hr * 0.42, hr * 0.12, hr * 0.32), Vector3.ZERO, true)
			_cp(chest, _cone_m(0.12, 0.25), _look_mat(Color(1.0, 0.86, 0.2), 0.2), Vector3(0, 0.6, -0.25), Vector3.ONE, Vector3(-1.0, 0, 0))

# --- the Skin Designer: a look mixed from parts of collected skins -------------
## custom_look = {"head"|"body"|"arms"|"legs": {"src": "own" | costume id | "adv2/Ranger"...,
##                "tint": Color or null, "finish": "" | "shadow" | "deathly" | "infernal" | "rot"}}
const DESIGN_PARTS := ["head", "body", "arms", "legs"]
const _PART_HEAD := ["Head", "Hat", "Helmet", "Mask", "Glasses", "Headband", "Sunglasses", "Hood", "Visor", "Crown", "Cigar", "Skull", "Jaw", "Eyes"]
var _custom_head := false
var _part_styles := []          # [[meshes, tint, finish], ...] applied after recolouring

## Which designer part a mesh belongs to, from its name.
static func part_of(mesh_name: String) -> String:
	for k in ["ArmLeft", "ArmRight"]:
		if mesh_name.contains(k):
			return "arms"
	for k in ["LegLeft", "LegRight", "LegArmor"]:
		if mesh_name.contains(k):
			return "legs"
	for k in _PART_HEAD:
		if mesh_name.contains(k):
			return "head"
	return "body"

## The model file (and its built-in finish) for a designer source id; "" means own.
static func design_source(src: String) -> Array:
	if src == "" or src == "own":
		return ["", ""]
	if Loot.COSTUMES.has(src):
		var c: Dictionary = Loot.COSTUMES[src]
		if not c.has("file"):
			return ["", ""]
		var f := String(c.file)
		return ["res://assets/kaykit/%s.glb" % (f if f.contains("/") else "costumes/" + f), String(c.get("fx", ""))]
	if src.contains("/"):
		var path := "res://assets/kaykit/%s.glb" % src
		if ResourceLoader.exists(path):
			return [path, ""]
	return ["", ""]

func _has_finish(m: MeshInstance3D) -> bool:
	for st in _part_styles:
		if m in st[0] and DARK_LOOKS.has(String(st[2])):
			return true
	return false

func _wear_custom(look: Dictionary) -> void:
	for part in DESIGN_PARTS:
		var d: Dictionary = look.get(part, {}) if look.get(part, {}) is Dictionary else {}
		var srcinfo := design_source(String(d.get("src", "own")))
		var path: String = srcinfo[0]
		var finish := String(d.get("finish", ""))   # only the finish shown in the designer
		var tint = d.get("tint", null)
		var meshes: Array[MeshInstance3D] = []
		if path != "" and ResourceLoader.exists(path):
			# hide whatever covers this part now (own pieces or an armour outfit)
			for m in all_meshes.duplicate():
				if part_of(String(m.name)) == part or (part == "head" and String(m.name) == "Hair_Head"):
					m.visible = false
					m.name = String(m.name) + "_off"   # free the name for the borrowed piece
					_never_show.append(m)
					all_meshes.erase(m)
					head_meshes.erase(m)
					_own_colors.erase(m)
			meshes = _borrow_meshes(path, func(n: String) -> bool: return part_of(n) == part)
			for m in meshes:
				_own_colors.append(m)
				if part == "head":
					head_meshes.append(m)
			if part == "head":
				_custom_head = true
		else:
			for m in all_meshes:
				if part_of(String(m.name)) == part:
					meshes.append(m)
		if tint is Color or DARK_LOOKS.has(finish):
			_part_styles.append([meshes, tint, finish])

## Tints and finishes chosen in the designer, on top of everything else.
func _style_custom_parts() -> void:
	var auras := {}
	for st in _part_styles:
		var tint = st[1]
		var finish := String(st[2])
		for m in st[0]:
			if not is_instance_valid(m):
				continue
			if DARK_LOOKS.has(finish):
				_skin_mat(m, DARK_LOOKS[finish], false)
				auras[finish] = true
			if tint is Color:
				_tint_mesh(m, tint)
	for f in auras:
		if _aura == null:
			_add_aura(DARK_LOOKS[f].aura, 2, f == "infernal")

## Recolour a mesh to `c`, keeping its shading (skin stays skin).
func _tint_mesh(m: MeshInstance3D, c: Color) -> void:
	for s in m.mesh.get_surface_count():
		var base := m.get_active_material(s)
		if base is ShaderMaterial and (base as ShaderMaterial).shader == _recolor_shader:
			var r := (base as ShaderMaterial).duplicate() as ShaderMaterial
			r.set_shader_parameter("tint", c)
			r.set_shader_parameter("strength", 0.7)
			m.set_surface_override_material(s, r)
		elif base is StandardMaterial3D:
			var sm := base as StandardMaterial3D
			if sm.albedo_texture:
				var r2 := ShaderMaterial.new()
				r2.shader = _recolor_shader
				r2.set_shader_parameter("tex", sm.albedo_texture)
				r2.set_shader_parameter("tint", c * sm.albedo_color)
				r2.set_shader_parameter("strength", 0.7)
				r2.set_shader_parameter("skin_protect", 1.0)
				r2.set_shader_parameter("tex_is_srgb", RenderingServer.get_current_rendering_method() == "gl_compatibility")
				r2.set_shader_parameter("roughness_v", sm.roughness)
				r2.set_shader_parameter("metallic_v", sm.metallic)
				m.set_surface_override_material(s, r2)
			else:
				var d := sm.duplicate() as StandardMaterial3D
				d.albedo_color = d.albedo_color.lerp(c, 0.7)
				m.set_surface_override_material(s, d)

# --- costumes and outfits (KayKit characters on the same rig) -----------------
var _own_colors: Array[MeshInstance3D] = []
static var _costume_scenes := {}

## Skinned meshes from another KayKit character, bound to this rig's skeleton
## (the bones share names and rest poses, so our animations drive them).
func _borrow_meshes(path: String, accept: Callable) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if skel == null or not ResourceLoader.exists(path):
		return out
	if not _costume_scenes.has(path):
		_costume_scenes[path] = load(path)
	var src: Node = (_costume_scenes[path] as PackedScene).instantiate()
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var o := mi as MeshInstance3D
		if not accept.call(String(o.name)):
			continue
		var m := MeshInstance3D.new()
		m.name = o.name; m.mesh = o.mesh; m.skin = o.skin; m.transform = o.transform
		for i in o.get_surface_override_material_count():
			if o.get_surface_override_material(i):
				m.set_surface_override_material(i, o.get_surface_override_material(i))
		# Capes, wings, hats and sunglasses aren't skinned: in the model they hang off a
		# bone (a BoneAttachment3D on "chest" or "head"). Borrowed straight onto the
		# skeleton they'd lose that bone and drop to the feet (the "blue square under
		# your feet" on the Ghost Knight's cape), so hang them off the same bone here.
		var bone := ""
		var rel := o.transform
		var par := o.get_parent()
		while par and par != src:
			if par is BoneAttachment3D:
				bone = String((par as BoneAttachment3D).bone_name)
				break
			if par is Node3D:
				rel = (par as Node3D).transform * rel
			par = par.get_parent()
		if o.skin == null and bone != "" and skel.find_bone(bone) >= 0:
			var att := skel.get_node_or_null("Att_" + bone) as BoneAttachment3D
			if att == null:
				att = BoneAttachment3D.new(); att.name = "Att_" + bone
				skel.add_child(att)
				att.bone_name = bone
			m.transform = rel
			att.add_child(m)
		else:
			skel.add_child(m)
			m.skeleton = NodePath("..")
		m.material_overlay = flash_mat
		all_meshes.append(m)
		out.append(m)
	src.free()
	return out

const _HEADGEAR := ["Head", "Hat", "Helmet", "Mask", "Glasses", "Headband", "Sunglasses", "Cigar", "Hood", "Visor"]

## Become someone else entirely (the whole body is swapped; weapons stay).
func _wear_costume(path: String, cfg: Dictionary) -> void:
	for m in all_meshes:
		m.visible = false
		_never_show.append(m)
		m.name = String(m.name) + "_base"
	all_meshes.clear(); head_meshes.clear()
	for m in _borrow_meshes(path, func(_n: String) -> bool: return true):
		for k in _HEADGEAR:
			if String(m.name).contains(k):
				head_meshes.append(m)
				break
	set_weapon(cfg.get("weapon", ""))
	set_offhand(_offhand_for(cfg))
	if cfg.has("aura"):
		_add_aura(cfg.aura, int(cfg.get("aura_level", 3)))
	_base_scale = float(cfg.get("scale", 0.84))
	scale = Vector3.ONE * _base_scale
	_play(anims.idle, 0.0)

## A class with its own model: hide the base rig's pieces and wear the class
## body (head and all) on the same skeleton, so the animations still fit.
func _wear_class_body(hero: Dictionary, cfg: Dictionary) -> void:
	for m in all_meshes:
		m.visible = false
		_never_show.append(m)
		m.name = String(m.name) + "_base"     # so the class body's pieces keep their own names
	all_meshes.clear(); head_meshes.clear()
	for m in _borrow_meshes(String(hero.body), func(n: String) -> bool: return not n.contains("Weapon")):
		if String(m.name) in hero.head:
			head_meshes.append(m)
		if hero.hat != "" and String(m.name) == hero.hat and not cfg.get("show_hat", true):
			m.visible = false
			_never_show.append(m)
		if hero.cape != "" and String(m.name) == hero.cape and cfg.has("cape_color"):
			_recolor(m, cfg.cape_color, 1.0, 0.0, null)

## Visible armour: swap the body, arms and legs (and cape) for an outfit,
## keeping your own head and hair.
func _wear_outfit(rel: String, _cfg: Dictionary) -> void:
	var path := "res://assets/kaykit/%s.glb" % rel
	if not ResourceLoader.exists(path):
		return
	var body_part := func(n: String) -> bool:
		for k in ["Body", "ArmLeft", "ArmRight", "LegLeft", "LegRight", "Cape", "Cloak", "Chest", "Shoulder", "LegArmor"]:
			if n.contains(k) and not n.contains("Head"):
				return true
		return false
	for m in all_meshes.duplicate():
		if body_part.call(String(m.name)):
			m.visible = false
			_never_show.append(m)
			all_meshes.erase(m)
	for m in _borrow_meshes(path, body_part):
		_own_colors.append(m)


## The cfg for a costume that is one of the game's own characters.
static func costume_look_cfg(look: String, base: Dictionary) -> Dictionary:
	var cfg := base.duplicate()
	cfg.erase("costume")
	if look == "bone":
		cfg["skin"] = "bone"
		return cfg
	var t: Dictionary = Enemy.TYPES.get({"goblin": "goblin", "ember_goblin": "fire_goblin", "gruk": "goblin_chief"}.get(look, "goblin"), {})
	var lk: Dictionary = t.get("look", {})
	var skin_c: Color = t.get("skin", Enemy.GOBLIN_SKIN)
	cfg["hero"] = lk.get("hero", "Rogue")
	cfg["show_hat"] = lk.get("hat", false)
	cfg["skin_color"] = skin_c
	cfg["hair_style"] = lk.get("hair_style", "spiky")
	cfg["hair_color"] = lk.get("hair_color", Color(0.1, 0.1, 0.1))
	cfg["hair_tint"] = lk.get("hair_color", Color(0.1, 0.1, 0.1))
	cfg["face"] = lk.get("face", "none")
	cfg["ears"] = true
	cfg["outfit_color"] = lk.get("outfit", Color(0.4, 0.3, 0.2))
	cfg["cape_color"] = (lk.get("outfit", Color(0.4, 0.3, 0.2)) as Color).darkened(0.2)
	cfg["build"] = lk.get("build", 1.05)
	cfg["height"] = 0.95
	cfg.erase("outfit_model"); cfg.erase("tint"); cfg.erase("skin")
	return cfg

## Multiply a mesh's colours (keeps its texture).
func _mul(m: MeshInstance3D, c: Color) -> void:
	for s in m.mesh.get_surface_count():
		var base := m.get_active_material(s)
		if base is StandardMaterial3D:
			var d := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.albedo_color = d.albedo_color * c
			m.set_surface_override_material(s, d)

func _skin_mat(m: MeshInstance3D, look: Dictionary, is_cape: bool) -> void:
	for s in m.mesh.get_surface_count():
		var base := m.get_active_material(s)
		if not base is StandardMaterial3D:
			continue
		var d := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		var c: Color = look.albedo
		d.albedo_color = Color(d.albedo_color.r * c.r, d.albedo_color.g * c.g, d.albedo_color.b * c.b, c.a)
		if is_cape:
			# capes stay cloth-like: darker and only faintly glowing, or the
			# trailing hem reads as a bright slab on the ground behind your feet
			d.albedo_color = d.albedo_color.darkened(0.35)
		d.roughness = look.get("rough", d.roughness)
		d.metallic = look.get("metal", d.metallic)
		var e: Color = look.get("emit", Color.BLACK)
		if e.get_luminance() > 0.0:
			d.emission_enabled = true
			d.emission = e * (0.2 if is_cape else 1.0)
			d.emission_energy_multiplier = 1.2
		if look.get("alpha", false):
			d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			d.cull_mode = BaseMaterial3D.CULL_BACK
		m.set_surface_override_material(s, d)

## Glowing ring and motes around the feet for epic / legendary gear (and embers).
func _add_aura(c: Color, level: int, embers := false) -> void:
	_aura = Node3D.new()
	add_child(_aura)
	var p := CPUParticles3D.new()
	p.amount = 22 if level < 4 else 40
	p.lifetime = 1.6
	p.mesh = FX.quad(0.08 if not embers else 0.06)
	p.material_override = FX.glow_material(c, 2.2)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.55
	p.emission_ring_inner_radius = 0.35
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4; p.initial_velocity_max = 1.2 if not embers else 2.0
	p.gravity = Vector3(0, 0.4, 0)
	p.color_ramp = FX._fade_ramp(c)
	p.position.y = 0.05
	_aura.add_child(p)
	if level >= 4 or embers:
		var l := OmniLight3D.new()
		l.light_color = c; l.light_energy = 0.7; l.omni_range = 3.0
		l.position.y = 1.0
		_aura.add_child(l)

## Swap a mesh's colour for `c`, keeping the texture's shading (see recolor.gdshader).
func _recolor(m: MeshInstance3D, c: Color, strength: float, skin_protect: float, skin = null, hair = null) -> void:
	for s in m.mesh.get_surface_count():
		var base := m.get_active_material(s)
		if not base is StandardMaterial3D:
			continue
		var sm := base as StandardMaterial3D
		if sm.albedo_texture == null:
			var d := sm.duplicate() as StandardMaterial3D
			d.albedo_color = sm.albedo_color.lerp(c, strength)
			m.set_surface_override_material(s, d)
			continue
		var r := ShaderMaterial.new()
		r.shader = _recolor_shader
		r.set_shader_parameter("tex", sm.albedo_texture)
		r.set_shader_parameter("tint", c)
		if _stripes != Color.BLACK:
			r.set_shader_parameter("stripes", 1.0)
			r.set_shader_parameter("stripe_color", _stripes)
		r.set_shader_parameter("strength", strength)
		r.set_shader_parameter("skin_protect", skin_protect)
		r.set_shader_parameter("tex_is_srgb", RenderingServer.get_current_rendering_method() == "gl_compatibility")
		if skin != null:
			r.set_shader_parameter("skin_tone", skin)
			r.set_shader_parameter("skin_on", 1.0)
		if hair != null:
			r.set_shader_parameter("hair_tone", hair)
			r.set_shader_parameter("hair_on", 1.0)
		r.set_shader_parameter("roughness_v", sm.roughness)
		r.set_shader_parameter("metallic_v", sm.metallic)
		m.set_surface_override_material(s, r)

static var _recolor_shader: Shader = preload("res://shaders/recolor.gdshader")

func _tint(m: MeshInstance3D, c: Color) -> void:
	for s in m.get_surface_override_material_count():
		var base := m.get_active_material(s)
		if base is StandardMaterial3D:
			var d := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.albedo_color = c
			m.set_surface_override_material(s, d)

func _setup_anims() -> void:
	var sk := kind == "skeleton"
	anims = {
		"idle": "Idle_Combat" if sk and anim.has_animation("Idle_Combat") else "Idle",
		"walk": "Walking_D_Skeletons" if sk and anim.has_animation("Walking_D_Skeletons") else "Walking_A",
		"back": "Walking_Backwards",
		"strafe_l": "Running_Strafe_Left",
		"strafe_r": "Running_Strafe_Right",
		"run": "Running_A",
		"jump": "Jump_Idle",
		"block": "Blocking",
		"a0": "1H_Melee_Attack_Slice_Diagonal",
		"a1": "1H_Melee_Attack_Slice_Horizontal",
		"a2": "1H_Melee_Attack_Chop",
		"cast": "Spellcast_Shoot",
		"hurt": "Hit_A",
		"death": "Death_C_Skeletons" if sk and anim.has_animation("Death_C_Skeletons") else "Death_A",
		"dodge_f": "Dodge_Forward", "dodge_b": "Dodge_Backward", "dodge_l": "Dodge_Left", "dodge_r": "Dodge_Right",
		"cheer": "Cheer", "interact": "Interact", "potion": "Use_Item",
		"spawn": "Skeletons_Awaken_Floor" if anim.has_animation("Skeletons_Awaken_Floor") else "Lie_StandUp",
		"taunt": "Taunt" if anim.has_animation("Taunt") else "Cheer",
	}
	# skeleton rigs lack a few clips; fall back gracefully
	for role in ["strafe_l", "strafe_r"]:
		if not anim.has_animation(anims[role]):
			anims[role] = anims.walk
	for role in ["idle", "walk", "back", "run", "jump", "block", "strafe_l", "strafe_r"]:
		var a := anim.get_animation(anims[role])
		if a:
			a.loop_mode = Animation.LOOP_LINEAR

## Slow motion (Insane's Bullet Time): every animation plays at this rate.
var slow := 1.0
## Insane's Speed Freak: the legs run this much faster (so they keep up with you).
var loco_boost := 1.0

func _play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if anim.current_animation == clip and anim.is_playing():
		anim.speed_scale = speed * slow
		return
	anim.play(clip, blend)
	anim.speed_scale = speed * slow

## Play a non-looping clip, compressed/stretched to `duration` seconds.
func oneshot(role: String, duration := -1.0, blend := 0.08) -> void:
	var clip: String = anims.get(role, role)
	if anim == null or not anim.has_animation(clip):
		return
	var length := anim.get_animation(clip).length
	var spd := 1.0 if duration <= 0.0 else length / duration
	anim.play(clip, blend)
	anim.seek(0.0, true)
	anim.speed_scale = spd * slow
	_oneshot = clip
	_oneshot_until = _clock + (length / spd) - 0.05

func clip_length(role: String) -> float:
	var clip: String = anims.get(role, role)
	return anim.get_animation(clip).length if anim and anim.has_animation(clip) else 1.0

func _process(delta: float) -> void:
	_clock += delta * slow
	if anim == null or dead:
		return
	# edge-triggered actions written by the controller
	if attack_t >= 0.0 and (_last_attack_t < 0.0 or attack_t < _last_attack_t):
		oneshot("a%d" % clampi(attack_kind, 0, 2), attack_dur, 0.06)
	if cast_t >= 0.0 and _last_cast_t < 0.0:
		oneshot("cast", 0.5)
	if dodge_t >= 0.0 and _last_dodge_t < 0.0:
		var r := "dodge_f"
		if absf(dodge_dir.x) > absf(dodge_dir.y):
			r = "dodge_r" if dodge_dir.x > 0 else "dodge_l"
		elif dodge_dir.y > 0:
			r = "dodge_b"
		oneshot(r, 0.45)
	if hurt_t >= 0.0 and _last_hurt_t < 0.0 and attack_t < 0.0 and dodge_t < 0.0:
		oneshot("hurt", 0.35)
	_last_attack_t = attack_t; _last_cast_t = cast_t; _last_dodge_t = dodge_t; _last_hurt_t = hurt_t
	if _clock < _oneshot_until:
		return
	_oneshot = ""
	if hold_clip != "":
		_play(hold_clip, 0.25)   # scripted pose for cutscenes (lying in bed, sitting...)
		return
	# locomotion
	if blocking:
		_play(anims.block, 0.12)
	elif not grounded:
		_play(anims.jump, 0.2)
	else:
		_locomotion(get_process_delta_time())

# ---------------------------------------------------------------------------
func _attach(bone: String) -> BoneAttachment3D:
	if skel == null:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba

## `id` is a model key ("skel_axe") or an item id from Game.items; items glow by rarity.
func set_weapon(id: String) -> void:
	if weapon_root:
		weapon_root.queue_free()
		weapon_root = null
	var glow := Color.BLACK
	var it: Dictionary = Game.item(id) if not WEAPON_SCENES.has(id) or Game.items.has(id) else {}
	if not it.is_empty():
		var r: int = it.get("rarity", 0)
		if r >= 2 and id != "vault_blade":
			glow = Loot.rarity_color(r)
		id = it.get("model", id) if id != "vault_blade" else id
	if kind == "hero" and id != "" and CLASS_WEAPON.has(hero_name):
		id = CLASS_WEAPON[hero_name]
	if id == "" or not WEAPON_SCENES.has(id):
		return
	weapon_root = _attach("handslot.r")
	_wpivot = Node3D.new(); _wpivot.name = "Grip"
	weapon_root.add_child(_wpivot)
	var w: Node3D = (load(WEAPON_SCENES[id]) as PackedScene).instantiate()
	_wpivot.add_child(w)
	var tip := Vector3(0, 0.9 * (HERO_WEAPON_LENGTH if kind == "hero" else 1.0), 0)
	if id == "necro_staff":
		# tilted 45 degrees in the hand: it stands up as you walk and run, and leans
		# forward like a wizard's staff when you stand still (a sword's angle would
		# point it straight ahead like a lance)
		w.scale = Vector3.ONE * 1.05
		w.rotation.z = PI / 4.0
		_staff_glow(w, Vector3(0, 1.3, 0))
		tip = w.transform * Vector3(0, 1.3, 0)
	elif kind == "hero":
		w.scale = Vector3(1.12, HERO_WEAPON_LENGTH, 1.12)   # longer blades: easier to see what you hit
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = flash_mat
		if glow != Color.BLACK:
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var bm := (mi as MeshInstance3D).get_active_material(si)
				if bm is StandardMaterial3D:
					var gm := (bm as StandardMaterial3D).duplicate() as StandardMaterial3D
					gm.emission_enabled = true
					gm.emission = glow
					gm.emission_energy_multiplier = 0.9 + 0.5 * float(it.rarity - 2)
					(mi as MeshInstance3D).set_surface_override_material(si, gm)
		if id == "vault_blade":
			var g := StandardMaterial3D.new()
			g.albedo_color = Color(0.45, 0.85, 1.0, 1)
			g.metallic = 0.6; g.roughness = 0.2
			g.emission_enabled = true; g.emission = Color(0.25, 0.8, 1.0); g.emission_energy_multiplier = 2.2
			(mi as MeshInstance3D).material_override = g
		elif id == "rusty_sword":
			pass
	weapon_tip = Node3D.new()
	_wpivot.add_child(weapon_tip)
	weapon_tip.position = tip
	# on the back: a staff stands up over the right shoulder; a blade or an axe
	# hangs hilt-up behind the right shoulder, slanting down to the left hip
	var staff := id.contains("staff")
	var d := Vector3(-0.42, 1.0, 0.0).normalized() if staff else Vector3(0.5, -1.0, 0.0).normalized()
	var back := Basis(d.cross(Vector3.BACK), d, Vector3.BACK)
	var grip := Vector3(0.16, -0.3, _back_z() - 0.07) if staff else Vector3(-0.24, 0.44, _back_z() - 0.08)
	_back_weapon = Transform3D(back * w.basis.orthonormalized().inverse(), grip)
	if sheathed:
		set_sheathed(true)

## How far back the body (and cape) reach, at the chest bone (skeleton space).
func _back_z() -> float:
	var z := -0.32
	for m in all_meshes:
		if is_instance_valid(m) and m.visible and m.mesh and (String(m.name).contains("Body") or String(m.name).contains("Cape") or String(m.name).contains("Cloak")):
			var a: AABB = m.get_aabb()
			if m.get_parent() != skel:
				a = (skel.global_transform.affine_inverse() * m.global_transform) * a if m.is_inside_tree() and skel.is_inside_tree() else a
			z = minf(z, a.position.z)
	return maxf(z, -0.6)

## Put the weapon and shield away on the back, or take them in hand.
func set_sheathed(on: bool) -> void:
	sheathed = on
	if weapon_root and is_instance_valid(weapon_root) and _wpivot:
		weapon_root.bone_name = "chest" if on else "handslot.r"
		var over := _shield_depth if offhand_root and is_instance_valid(offhand_root) else 0.0
		_wpivot.transform = _back_weapon.translated(Vector3(0, 0, -over)) if on else Transform3D.IDENTITY
	if offhand_root and is_instance_valid(offhand_root) and _spivot:
		offhand_root.bone_name = "chest" if on else "handslot.l"
		_spivot.transform = _back_shield if on else Transform3D.IDENTITY

func _offhand_for(cfg: Dictionary) -> String:
	if kind == "hero" and CLASS_WEAPON.has(hero_name) and CLASS_WEAPON[hero_name] in TWO_HANDED:
		return ""          # a staff takes both hands
	return String(cfg.get("shield", ""))

## A ghostly green flame on top of the Necromancer's staff.
func _staff_glow(parent: Node3D, at: Vector3) -> void:
	var g := Color(0.45, 1.0, 0.5)
	var orb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 10; sm.rings = 5
	orb.mesh = sm
	var om := StandardMaterial3D.new(); om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = g; om.emission_enabled = true; om.emission = g; om.emission_energy_multiplier = 4.0
	orb.material_override = om; orb.position = at; orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(orb)
	var halo := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.55, 0.55); halo.mesh = q
	var hm := StandardMaterial3D.new(); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = FX.soft_texture(); hm.albedo_color = Color(g.r, g.g, g.b, 0.7)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = hm; halo.position = at; halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(halo)
	var wisps := CPUParticles3D.new()
	wisps.amount = 10; wisps.lifetime = 0.9; wisps.local_coords = false
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; wisps.emission_sphere_radius = 0.08
	wisps.direction = Vector3.UP; wisps.spread = 25.0; wisps.gravity = Vector3(0, 0.6, 0)
	wisps.initial_velocity_min = 0.1; wisps.initial_velocity_max = 0.35
	wisps.scale_amount_min = 0.5; wisps.scale_amount_max = 1.0
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0)); wisps.scale_amount_curve = curve
	var wm := QuadMesh.new(); wm.size = Vector2(0.09, 0.09); wisps.mesh = wm
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.albedo_texture = FX.soft_texture(); pm.albedo_color = g; pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.vertex_color_use_as_albedo = true
	wisps.material_override = pm
	wisps.position = at
	parent.add_child(wisps)
	var l := OmniLight3D.new(); l.light_color = g; l.light_energy = 0.7; l.omni_range = 2.5; l.position = at
	parent.add_child(l)

func set_offhand(id: String) -> void:
	_shield_depth = 0.0
	if offhand_root:
		offhand_root.queue_free()
		offhand_root = null
	if id == "":
		return
	var p := "res://assets/kaykit/items/%s.gltf" % id
	if not ResourceLoader.exists(p):
		return
	offhand_root = _attach("handslot.l")
	_spivot = Node3D.new(); _spivot.name = "Grip"
	offhand_root.add_child(_spivot)
	var s: Node3D = (load(p) as PackedScene).instantiate()
	_spivot.add_child(s)
	for mi in s.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = flash_mat
	# on the back: flat against it, its thinnest side facing out, under the weapon
	var a := Props.mesh_aabb(s)
	if a.size != Vector3.ZERO:
		a = s.transform * a
		var sz := a.size
		var thin := 0 if sz.x <= sz.y and sz.x <= sz.z else (1 if sz.y <= sz.z else 2)
		var rest := [0, 1, 2]
		rest.erase(thin)
		var up: int = rest[0] if sz[rest[0]] >= sz[rest[1]] else rest[1]
		var side: int = rest[1] if up == rest[0] else rest[0]
		var cols := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		cols[thin] = Vector3.BACK * -1.0
		cols[up] = Vector3.UP
		cols[side] = Vector3.RIGHT
		var b := Basis(cols[0], cols[1], cols[2])
		if b.determinant() < 0.0:
			cols[side] = Vector3.LEFT
			b = Basis(cols[0], cols[1], cols[2])
		var at := Vector3(0.0, 0.08, _back_z() - sz[thin] * 0.5 - 0.01)
		_shield_depth = sz[thin] + 0.02
		_back_shield = Transform3D(b, at - b * a.get_center())
	if sheathed:
		set_sheathed(true)

var _never_show: Array[MeshInstance3D] = []   # hidden hats and swapped-out heads

func set_head_visible(v: bool) -> void:
	for m in head_meshes:
		if is_instance_valid(m):
			m.visible = v and not _never_show.has(m)

static var _hair_head_cache := {}

## Load (once) a modelled head: its mesh, texture and the UV rect of its hair swatch.
static func _hair_head(style: String) -> Dictionary:
	if _hair_head_cache.has(style):
		return _hair_head_cache[style]
	var info := {}
	var spec: Array = HAIR_HEADS.get(style, [])
	if spec.size() == 2 and ResourceLoader.exists(spec[0]):
		var inst: Node = (load(spec[0]) as PackedScene).instantiate()
		var src := inst.find_child(spec[1], true, false) as MeshInstance3D
		if src and src.mesh:
			info.mesh = src.mesh
			var mat := src.get_active_material(0) as StandardMaterial3D
			info.mat = mat
			info.tex = mat.albedo_texture if mat else null
			# the hair swatch: the atlas cell under the top of the head (for the
			# bald head: under the bottom of the beard)
			var arr := src.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var best := 0
			for i in verts.size():
				if (style == "bald" and verts[i].y < verts[best].y) or (style != "bald" and verts[i].y > verts[best].y):
					best = i
			var uv: Vector2 = uvs[best]
			var cw := 1.0 / 8.0
			var chh := 1.0 / 4.0
			var cx := floorf(uv.x / cw) * cw
			var cy := floorf(uv.y / chh) * chh
			info.rect = Vector4(cx + 0.002, cy + 0.002, cx + cw - 0.002, cy + chh - 0.002)
		inst.free()
	_hair_head_cache[style] = info
	return info

## Swap the hero's head for a modelled one with real hair (see HAIR_HEADS).
func _swap_head(hero: Dictionary, cfg: Dictionary, skin_look: String, style: String) -> void:
	var info := _hair_head(style)
	if info.is_empty() or skel == null or skel.find_bone("head") < 0:
		return
	for m in all_meshes:
		if m.name == hero.head[0]:
			m.visible = false
			_never_show.append(m)
	var ba := _attach("head")
	var mi := MeshInstance3D.new()
	mi.name = "Hair_Head"
	mi.mesh = info.mesh
	mi.transform = skel.get_bone_global_rest(skel.find_bone("head")).affine_inverse()
	ba.add_child(mi)
	mi.material_overlay = flash_mat
	all_meshes.append(mi)
	head_meshes.append(mi)
	if SKIN_LOOKS.has(skin_look):
		_skin_mat(mi, SKIN_LOOKS[skin_look], false)
		return
	if info.tex == null:
		return
	var r := ShaderMaterial.new()
	r.shader = _recolor_shader
	r.set_shader_parameter("tex", info.tex)
	r.set_shader_parameter("strength", 0.0)
	r.set_shader_parameter("tex_is_srgb", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var skin_c = cfg.get("skin_color", null)
	if skin_c != null:
		r.set_shader_parameter("skin_tone", skin_c)
		r.set_shader_parameter("skin_on", 1.0)
	var hc: Color = cfg.get("hair_color", Game.HAIR_COLORS2[0])
	if hc != Game.HAIR_COLORS2[0]:
		r.set_shader_parameter("hair_tone", hc)
		r.set_shader_parameter("hair_rect", info.rect)
		r.set_shader_parameter("hair_rect_on", 1.0)
	var sm: StandardMaterial3D = info.mat
	r.set_shader_parameter("roughness_v", sm.roughness if sm else 0.8)
	r.set_shader_parameter("metallic_v", sm.metallic if sm else 0.0)
	mi.material_override = r

func flash(color := Color(1, 1, 1), strength := 0.8) -> void:
	flash_mat.albedo_color = Color(color.r, color.g, color.b, strength)
	var tw := create_tween()
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.22)

func collapse() -> void:
	dead = true
	if anim:
		anim.speed_scale = 1.0
		anim.play(anims.death, 0.1)

func revive() -> void:
	dead = false
	_oneshot_until = 0.0
	rotation.x = 0
	_play(anims.idle, 0.0)

func play_role(role: String, duration := -1.0) -> void:
	oneshot(role, duration)

func head_height() -> float:
	if skel:
		var i := skel.find_bone("head")
		if i >= 0:
			return (skel.global_transform * skel.get_bone_global_pose(i)).origin.y - global_position.y
	return 1.6

## Choose walk / run / backpedal / sidestep from the body-relative movement,
## with hysteresis so diagonals and turning do not flicker between clips.
func _want_loco() -> Array:
	if move_speed <= 0.4:
		return [anims.idle, 1.0]
	var ax := absf(local_move.x)
	var ay := absf(local_move.y)
	var is_side: bool = _loco == anims.strafe_l or _loco == anims.strafe_r
	var side_wins := ax > ay * (0.7 if is_side else 1.35)
	if side_wins:
		var right := local_move.x > 0.0
		if is_side and absf(local_move.x) < 0.3:
			right = _loco == anims.strafe_r
		return [anims.strafe_r if right else anims.strafe_l, clampf(move_speed / 5.0, 0.55, 1.3)]
	var was_back: bool = _loco == anims.back
	if local_move.y > (0.0 if was_back else 0.35):
		return [anims.back, clampf(move_speed / 2.6, 0.6, 1.6)]
	if move_speed > 5.0:
		return [anims.run, clampf(move_speed / 6.5, 0.8, 1.3)]
	return [anims.walk, clampf(move_speed / 3.2, 0.6, 1.5)]

func _locomotion(delta: float) -> void:
	var w := _want_loco()
	var clip: String = w[0]
	if clip != _loco:
		var immediate: bool = _loco == "" or _loco == anims.idle or clip == anims.idle \
			or (clip == anims.run and _loco == anims.walk) or (clip == anims.walk and _loco == anims.run)
		if clip == _pend:
			_pend_t += delta
		else:
			_pend = clip
			_pend_t = 0.0
		if immediate or _pend_t >= 0.16:
			if _loco != "" and _loco != anims.idle and clip != anims.idle:
				loco_switches += 1
			_loco = clip
	else:
		_pend = ""
	_play(_loco, 0.24, w[1] * loco_boost if clip == _loco else anim.speed_scale / maxf(slow, 0.01))

# ---------------------------------------------------------------------------
# Character-creator looks: hair styles and face details are small meshes on the
# head bone, laid out from the head mesh's own bounds so they fit every hero.
var looks_root: Node3D

func _head_bounds(hero: Dictionary) -> AABB:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == hero.head[0]:
			return (mi as MeshInstance3D).get_aabb()
	return AABB(Vector3(-0.54, 1.2, -0.5), Vector3(1.08, 1.1, 1.02))

static var _face_tm_cache := {}

## The head you actually see: a swapped-in modelled head, or the hero's own.
func _visible_head(hero: Dictionary) -> MeshInstance3D:
	for m in all_meshes:
		if is_instance_valid(m) and m.name == "Hair_Head":
			return m
	for m in all_meshes:
		if is_instance_valid(m) and m.name == hero.head[0]:
			return m
	return null

## Face details (moustaches, eyepatches, glowing eyes...) were laid on an ellipsoid
## fitted round the head's bounding box, and on most heads that box pokes out well
## past the real face, so they floated in front of it. Now each detail finds the
## real face by shooting a ray at the visible head mesh. Returns a callable
## (x, y) -> z of the face surface in skeleton space, or NAN if the ray misses.
func _face_ray(hero: Dictionary) -> Callable:
	var fm := _visible_head(hero)
	if fm == null or fm.mesh == null:
		return func(_x: float, _y: float) -> float: return NAN
	if not _face_tm_cache.has(fm.mesh):
		_face_tm_cache[fm.mesh] = fm.mesh.generate_triangle_mesh()
	var tm: TriangleMesh = _face_tm_cache[fm.mesh]
	# a hair head hangs off the head bone with the inverse rest, so it is already in
	# skeleton space; the hero's own (skinned) head sits on the skeleton itself
	var xf: Transform3D = fm.transform if fm.get_parent() == skel else Transform3D.IDENTITY
	var inv := xf.affine_inverse()
	_head_tm = tm; _head_xf = xf
	return func(x: float, y: float) -> float:
		if tm == null:
			return NAN
		var hit: Dictionary = tm.intersect_ray(inv * Vector3(x, y, 6.0), (inv.basis * Vector3(0, 0, -1)).normalized())
		if hit.is_empty():
			return NAN
		return (xf * (hit.position as Vector3)).z

var _head_tm: TriangleMesh
var _head_xf := Transform3D.IDENTITY

## Where a ray from `from` toward `dir` (skeleton space) first meets the visible head.
func _head_hit(from: Vector3, dir: Vector3) -> Variant:
	if _head_tm == null:
		return null
	var inv := _head_xf.affine_inverse()
	var hit: Dictionary = _head_tm.intersect_ray(inv * from, (inv.basis * dir).normalized())
	if hit.is_empty():
		return null
	return _head_xf * (hit.position as Vector3)

## A woman's face: lashes, rosy lips and cheeks; under a helm, a long braid.
func _female_face(c: Vector3, rx: float, ry: float, rz: float, nose_y: float, fz: Callable, covered: bool, cfg: Dictionary, mouth := true) -> void:
	var eye_c := nose_y + 0.105
	var eye_x := 0.24
	# lashes: three little flicks round the top outer edge of each eye
	var lash := _look_mat(Color(0.05, 0.035, 0.03), 0.6)
	for sd in [-1.0, 1.0]:
		for k in 3:
			var a: float = deg_to_rad(20.0 + k * 28.0)
			var d := Vector2(sd * cos(a), sin(a))
			var p2 := Vector2(sd * eye_x, eye_c) + Vector2(sd * cos(a) * 0.088, sin(a) * 0.064) + d * 0.022
			var lz: float = fz.call(p2.x, p2.y) + 0.006
			_piece(_boxm(0.014, 0.05, 0.012), lash, Vector3(p2.x, p2.y, lz), Vector3.ONE, Vector3(0, 0, -atan2(d.x, d.y)))
	# rosy lips (not under a ninja mask)
	var lip_y := nose_y - 0.165
	if mouth:
		_piece(_sphere(), _look_mat(Color(0.88, 0.3, 0.42), 0.35), Vector3(0, lip_y, float(fz.call(0.0, lip_y)) - 0.004), Vector3(0.075, 0.026, 0.03))
	# and pink cheeks
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(1.0, 0.45, 0.5, 0.45)
	pink.albedo_texture = FX.soft_texture()
	pink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sd in ([-1.0, 1.0] if mouth else []):
		var cy := nose_y - 0.01
		var cx: float = sd * 0.31
		var qd := QuadMesh.new(); qd.size = Vector2(0.16, 0.09)
		_piece(qd, pink, Vector3(cx, cy, float(fz.call(cx, cy)) + 0.006), Vector3.ONE, Vector3(0, sd * 0.5, 0))
	var own_hair := false
	for m in all_meshes:
		if m.name == "Hair_Head":
			own_hair = true
	if covered and not own_hair:
		# a long braid hanging down from under the helm
		var hair_c: Color = cfg.get("hair_color", Color(0.32, 0.19, 0.1))
		if hair_c == Game.HAIR_COLORS2[0]:
			hair_c = CLASS_HAIR.get(hero_name, Color(0.55, 0.32, 0.15))
		var hm := _look_mat(hair_c, 0.7)
		for k in 6:
			var r := rx * (0.2 - k * 0.018)
			_piece(_sphere(), hm, Vector3(0, c.y - ry * (0.15 + k * 0.28), c.z - rz * (1.02 + k * 0.08)), Vector3(r, r * 1.3, r))
		_piece(_sphere(), _look_mat(Color(0.9, 0.2, 0.35), 0.5), Vector3(0, c.y - ry * 1.75, c.z - rz * 1.45), Vector3(rx * 0.16, rx * 0.09, rx * 0.06))
		# and long locks falling down either side of her face, so you can tell from the front too
		for sd in [-1.0, 1.0]:
			for k in 5:
				var r2 := rx * (0.15 - k * 0.012)
				_piece(_sphere(), hm, Vector3(sd * rx * (0.9 - k * 0.02), c.y - ry * (0.42 + k * 0.2), c.z + rz * (0.12 - k * 0.03)), Vector3(r2, r2 * 1.35, r2 * 0.9))

## A ninja mask: dark cloth that follows the face itself (a copy of the head's own
## surface below the bridge of the nose, puffed out a little), tied with a strap
## and a knot at the back with two tails.
func _ninja_mask(hero: Dictionary, c: Vector3, rx: float, ry: float, rz: float, nose_y: float, long_hair := false) -> void:
	var cloth := _look_mat(Color(0.09, 0.1, 0.16), 0.85)
	var top := nose_y + 0.03
	# (on long hair, just the face: not the locks hanging down beside it)
	var shell := _face_shell(hero, top, c.z - rz * 0.25, 0.03, 0.43 if long_hair else INF)
	if shell:
		_piece(shell, cloth, Vector3.ZERO)
	else:
		_piece(_sphere(), cloth, Vector3(c.x, nose_y - 0.1, c.z + rz * 0.3), Vector3(rx * 0.9, 0.16, rz * 0.75))
	# tied in a knot at the back of the head, with two tails
	var by := top - 0.04
	var back_z := c.z - rz
	var h_b = _head_hit(Vector3(0, by, c.z - 6.0), Vector3(0, 0, 1))
	if h_b != null:
		back_z = (h_b as Vector3).z
	var knot := _piece(_sphere(), cloth, Vector3(0, by, back_z - 0.03), Vector3(0.07, 0.06, 0.05))
	for sd in [-1.0, 1.0]:
		var tail := _piece(_boxm(0.06, 0.24, 0.015), cloth, knot.position + Vector3(sd * 0.05, -0.12, -0.02))
		tail.rotation = Vector3(0.25, 0, sd * 0.4)

## The visible head's own surface below `top_y` and in front of `back_z`, pushed out
## along its normals by `out` (in skeleton space, like every face detail).
func _face_shell(hero: Dictionary, top_y: float, back_z: float, out: float, half_w := INF) -> ArrayMesh:
	var fm := _visible_head(hero)
	if fm == null or fm.mesh == null:
		return null
	var xf: Transform3D = fm.transform if fm.get_parent() == skel else Transform3D.IDENTITY
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	# The low-poly heads are flat shaded (every corner has its own copy per face),
	# so pushing each face out along its own normal would crack the shell open
	# along every edge. Average the normals of corners that share a position.
	var avg := {}
	var surfs: Array = []
	for si in fm.mesh.get_surface_count():
		var arr := fm.mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		surfs.append([vs, ns, ix])
		for vi in vs.size():
			var key := (xf * vs[vi]).snapped(Vector3.ONE * 0.0005)
			var n: Vector3 = (xf.basis * ns[vi]).normalized() if vi < ns.size() else Vector3.BACK
			avg[key] = avg.get(key, Vector3.ZERO) + n
	for sf in surfs:
		var vs: PackedVector3Array = sf[0]
		var ix: PackedInt32Array = sf[2]
		var tris := ix.size() / 3 if ix.size() > 0 else vs.size() / 3
		for t in tris:
			var poly: Array = []
			for j in 3:
				var vi: int = ix[t * 3 + j] if ix.size() > 0 else t * 3 + j
				var p: Vector3 = xf * vs[vi]
				var n: Vector3 = (avg.get(p.snapped(Vector3.ONE * 0.0005), Vector3.BACK) as Vector3).normalized()
				poly.append([p + n * out, n])
			poly = _clip_poly(poly, func(p: Vector3) -> float: return top_y - p.y)
			poly = _clip_poly(poly, func(p: Vector3) -> float: return p.z - back_z)
			if half_w < INF:
				poly = _clip_poly(poly, func(p: Vector3) -> float: return half_w - absf(p.x))
			for k in range(1, poly.size() - 1):
				for q in [poly[0], poly[k], poly[k + 1]]:
					verts.append(q[0]); norms.append(q[1])
	if verts.size() < 3:
		return null
	var am := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return am

## Keep the part of a polygon ([position, normal] pairs) where side(p) >= 0.
func _clip_poly(poly: Array, side: Callable) -> Array:
	var out: Array = []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da: float = side.call(a[0]); var db: float = side.call(b[0])
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var t := da / (da - db)
			out.append([(a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t).normalized()])
	return out

## Makeup: shimmering eyeshadow, bold lips and rosy cheeks.
func _makeup(nose_y: float, fz: Callable) -> void:
	var eye_c := nose_y + 0.105
	var shadow := StandardMaterial3D.new()
	shadow.albedo_color = Color(0.72, 0.28, 0.95, 0.95)
	shadow.albedo_texture = FX.soft_texture()
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sd in [-1.0, 1.0]:
		var x: float = sd * 0.245
		var y := eye_c + 0.05
		var q := QuadMesh.new(); q.size = Vector2(0.25, 0.11)
		_piece(q, shadow, Vector3(x, y, float(fz.call(x, y)) + 0.014), Vector3.ONE, Vector3(0, sd * 0.3, sd * -0.12))
	var lip_y := nose_y - 0.165
	_piece(_sphere(), _look_mat(Color(0.85, 0.08, 0.22), 0.2), Vector3(0, lip_y, float(fz.call(0.0, lip_y)) + 0.002), Vector3(0.09, 0.034, 0.034))
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(1.0, 0.35, 0.45, 0.5)
	pink.albedo_texture = FX.soft_texture()
	pink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sd in [-1.0, 1.0]:
		var cx: float = sd * 0.3
		var q2 := QuadMesh.new(); q2.size = Vector2(0.18, 0.1)
		_piece(q2, pink, Vector3(cx, nose_y - 0.01, float(fz.call(cx, nose_y - 0.01)) + 0.009), Vector3.ONE, Vector3(0, sd * 0.5, 0))

## Glitter: little rainbow gems on the cheeks, a star by one eye, and sparkles
## that twinkle on and off.
func _glitter(nose_y: float, fz: Callable) -> void:
	var eye_c := nose_y + 0.105
	var cols := [Color(1.0, 0.45, 0.8), Color(0.55, 0.8, 1.0), Color(1.0, 0.9, 0.4), Color(0.75, 0.55, 1.0), Color(0.5, 1.0, 0.8)]
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for sd in [-1.0, 1.0]:
		for k in 7:
			var x: float = sd * (0.22 + rng.randf_range(0.0, 0.16))
			var y: float = nose_y + rng.randf_range(-0.06, 0.05)
			var col: Color = cols[k % cols.size()]
			var m := StandardMaterial3D.new(); m.albedo_color = col; m.emission_enabled = true; m.emission = col
			m.emission_energy_multiplier = 1.6; m.metallic = 0.8; m.roughness = 0.15
			_piece(_sphere(), m, Vector3(x, y, float(fz.call(x, y)) + 0.004), Vector3.ONE * rng.randf_range(0.009, 0.016))
	# a little four-pointed star beside the right eye
	var gold := StandardMaterial3D.new(); gold.albedo_color = Color(1.0, 0.85, 0.35); gold.emission_enabled = true
	gold.emission = Color(1.0, 0.8, 0.3); gold.emission_energy_multiplier = 2.0; gold.metallic = 0.9; gold.roughness = 0.2
	var sx := 0.4; var sy := eye_c - 0.02
	var sz: float = float(fz.call(sx, sy)) + 0.006
	for r in [0.0, PI / 2]:
		_piece(_boxm(0.014, 0.075, 0.008), gold, Vector3(sx, sy, sz), Vector3.ONE, Vector3(0, 0.6, r + PI / 4))
		_piece(_boxm(0.01, 0.045, 0.008), gold, Vector3(sx, sy, sz), Vector3.ONE, Vector3(0, 0.6, r))
	# twinkles
	var tw := CPUParticles3D.new(); tw.amount = 14; tw.lifetime = 0.9; tw.local_coords = true
	tw.mesh = FX.quad(0.035); tw.material_override = FX.glow_material(Color(1, 1, 1), 3.0)
	tw.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; tw.emission_box_extents = Vector3(0.36, 0.08, 0.03)
	tw.gravity = Vector3.ZERO; tw.initial_velocity_min = 0.0; tw.initial_velocity_max = 0.01
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.8, 1, 0), Color(1, 1, 1, 1), Color(0.8, 0.9, 1, 0)])
	tw.color_ramp = ramp
	tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	looks_root.add_child(tw)
	tw.position = Vector3(0, nose_y + 0.01, float(fz.call(0.0, nose_y)) + 0.01)

## A heroine Barbarian wears a fur wrap across her chest.
func _fur_top() -> void:
	var body: MeshInstance3D = null
	for m in all_meshes:
		if String(m.name) == "Barbarian_Body" and m.visible:
			body = m
	if body == null or body.mesh == null or skel == null or skel.find_bone("chest") < 0:
		return
	var tm := body.mesh.generate_triangle_mesh()
	var y := 1.1
	var lo := Vector3(-0.3, y, -0.25); var hi := Vector3(0.3, y, 0.25)
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var hit: Dictionary = tm.intersect_ray(Vector3(0, y, 0) + dir * 2.0, -dir)
		if not hit.is_empty():
			var hp: Vector3 = hit.position
			lo = Vector3(minf(lo.x, hp.x), y, minf(lo.z, hp.z)); hi = Vector3(maxf(hi.x, hp.x), y, maxf(hi.z, hp.z))
	var ba := _attach("chest")
	var root := Node3D.new()
	root.transform = skel.get_bone_global_rest(skel.find_bone("chest")).affine_inverse()
	ba.add_child(root)
	var fur := _look_mat(Color(0.5, 0.33, 0.2), 0.95)
	var trim := _look_mat(Color(0.82, 0.72, 0.55), 0.95)
	var mid := (lo + hi) * 0.5
	var r := (hi - lo) * 0.5 + Vector3(0.025, 0, 0.025)
	for band in [[0.0, 0.2, fur, 1.0], [0.1, 0.035, trim, 1.03], [-0.1, 0.035, trim, 1.03]]:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = band[1]; cm.radial_segments = 20
		mi.mesh = cm; mi.material_override = band[2]
		mi.position = Vector3(mid.x, y + float(band[0]), mid.z)
		mi.scale = Vector3(r.x * float(band[3]), 1.0, r.z * float(band[3]))
		mi.material_overlay = flash_mat
		root.add_child(mi)
		all_meshes.append(mi)

func _look_mat(c: Color, rough := 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _piece(mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.material_overlay = flash_mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	looks_root.add_child(mi)
	head_meshes.append(mi)
	return mi

func _sphere(hemi := false) -> SphereMesh:
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0 if not hemi else 1.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 20; sm.rings = 10
	return sm

func _boxm(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z)
	return b

func _add_head_looks(hero: Dictionary, cfg: Dictionary, covered: bool) -> void:
	var style: String = cfg.get("hair_style", "natural")
	var face: String = cfg.get("face", "none")
	var ears: bool = cfg.get("ears", false)
	# (only heroes made in the creator say male or female; NPCs built on hero rigs don't)
	var fem := String(cfg.get("sex", "")) == "female"
	if (style == "natural" or covered) and face == "none" and not ears and not fem:
		return
	if skel == null or skel.find_bone("head") < 0:
		return
	var hb := skel.find_bone("head")
	var ba := _attach("head")
	looks_root = Node3D.new()
	looks_root.transform = skel.get_bone_global_rest(hb).affine_inverse()   # author in skeleton space
	ba.add_child(looks_root)
	var box := _head_bounds(hero)
	# some heads' bounds take in antlers (Druid), a jaw piece (Necromancer) or a long
	# beard; lay the details out on the head itself, which is the same size on them all
	var core := box.intersection(AABB(Vector3(-0.58, 1.0, -0.6), Vector3(1.16, 1.32, 1.18)))
	if core.has_volume():
		box = core
	var c := box.get_center()
	var sz := box.size
	var rx := sz.x * 0.5; var ry := sz.y * 0.5; var rz := sz.z * 0.5
	var hair_c: Color = cfg.get("hair_color", Color(0.32, 0.19, 0.1))
	if hair_c == Game.HAIR_COLORS2[0]:   # "hero's own" colour
		var hn := String(cfg.get("hero", "Knight"))
		if style in ["buns", "spiky"] and not covered:
			hair_c = HEAD_OWN_HAIR.get(BUN_SPIKE_BASE.get(hn, "short"), hair_c)
		else:
			hair_c = HERO_OWN_HAIR.get(hn, hair_c)
	var skin_c: Color = cfg.get("skin_color", Color(0.97, 0.8, 0.67))
	var hair := _look_mat(hair_c, 0.7)
	# Hair styles are added on top of the hero's own (recoloured) hair rather
	# than covering it with a cap, so they read as hair and not as a helmet.
	# Points on the head surface: an ellipsoid fitted to the head bounds.
	var surf := func(yaw_a: float, pitch_a: float, out := 1.0) -> Vector3:
		return c + Vector3(sin(yaw_a) * cos(pitch_a) * rx, sin(pitch_a) * ry, cos(yaw_a) * cos(pitch_a) * rz) * out
	if not covered:
		match style:
			"buns":
				for sd in [-1.0, 1.0]:
					var bp: Vector3 = surf.call(sd * 0.95, 0.85, 1.0)
					_piece(_sphere(), hair, bp, Vector3.ONE * rx * 0.36)
					_piece(_sphere(), _look_mat(Color(0.8, 0.15, 0.2), 0.5), bp.lerp(c, 0.25), Vector3(rx * 0.3, rx * 0.1, rx * 0.3))
			"spiky":
				for row in [[1.4, 1], [1.0, 6], [0.6, 8]]:
					var pa2: float = row[0]
					var cnt2: int = row[1]
					for i in cnt2:
						var ya3 := TAU * float(i) / cnt2 + pa2
						if cos(ya3) > 0.6 and pa2 < 0.8:
							continue
						var n: Vector3 = (surf.call(ya3, pa2, 1.0) - c).normalized()
						var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = rx * 0.2; cone.height = ry * 0.75
						var pc := _piece(cone, hair, surf.call(ya3, pa2, 0.95) + n * ry * 0.3)
						pc.basis = Basis(Quaternion(Vector3.UP, n))
	if ears:
		# long pointy goblin ears sticking out sideways
		var ear_m := _look_mat(cfg.get("skin_color", Color(0.42, 0.62, 0.24)), 0.6)
		for sd in [-1.0, 1.0]:
			var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = rx * 0.2; cone.height = rx * 1.15
			cone.radial_segments = 8
			var pe := _piece(cone, ear_m, c + Vector3(sd * rx * 1.25, ry * 0.12, -rz * 0.05), Vector3(1.0, 1.0, 0.45))
			pe.rotation = Vector3(0, 0, -sd * 1.2)
	# face details sit on the front of the head (+Z in skeleton space): on the real
	# face where the ray finds it, else on the fitted ellipsoid
	var ray := _face_ray(hero)
	var fz := func(x: float, y: float) -> float:
		var z: float = ray.call(x, y)
		if not is_nan(z):
			return z
		var k := 1.0 - pow(x / rx, 2.0) - pow((y - c.y) / ry, 2.0)
		return c.z + rz * sqrt(maxf(k, 0.05))
	var eye_y := c.y - ry * 0.08
	var eye_x := rx * 0.36
	# Every KayKit head shares one face: find the nose (the frontmost point down the
	# middle) and lay the face out from it. (Swapped hair heads have differently
	# sized bounds, so the box-based guess above lands on the eyebrows there.)
	var nose_y := c.y - ry * 0.3
	var nose_z := -INF
	var sy := c.y - ry * 0.1
	while sy > c.y - ry * 0.7:
		var zr: float = ray.call(0.0, sy)
		if not is_nan(zr) and zr > nose_z and zr < c.z + rz * 1.15:     # (not the Necromancer's jaw piece)
			nose_z = zr; nose_y = sy
		sy -= 0.01
	var swapped := _visible_head(hero) != null and _visible_head(hero).name == "Hair_Head"
	if nose_z > -INF and (swapped or fem):
		eye_y = nose_y + 0.105
	# heroines don't get beards; heroes don't get makeup
	if fem and face in ["beard", "mustache"]:
		face = "none"
	elif not fem and face in ["makeup", "glitter"]:
		face = "none"
	if style in HAIR_HEAD_BEARDED and not covered and face in ["beard", "mustache"]:
		face = "none"          # this head already has a fine beard
	if fem:
		_female_face(c, rx, ry, rz, nose_y, fz, covered, cfg, face != "mask")
	# pale facial hair (a blond Knight) would vanish against the skin
	if face in ["beard", "mustache"] and hair_c.get_luminance() > 0.55:
		hair = _look_mat(hair_c.darkened(0.35), 0.7)
	match face:
		"beard":
			_piece(_sphere(), hair, Vector3(0, c.y - ry * 0.62, fz.call(0.0, c.y - ry * 0.62) - rz * 0.25), Vector3(rx * 0.62, ry * 0.4, rz * 0.32))
			_piece(_boxm(rx * 0.7, ry * 0.09, rz * 0.12), hair, Vector3(0, c.y - ry * 0.38, fz.call(0.0, c.y - ry * 0.38)))
		"mustache":
			for sd in [-1.0, 1.0]:
				_piece(_boxm(rx * 0.34, ry * 0.08, rz * 0.08), hair, Vector3(sd * rx * 0.16, c.y - ry * 0.4, fz.call(sd * rx * 0.16, c.y - ry * 0.4)), Vector3.ONE, Vector3(0, 0, sd * -0.35))
		"eyepatch":
			var d := CylinderMesh.new(); d.top_radius = rx * 0.17; d.bottom_radius = rx * 0.17; d.height = 0.03
			_piece(d, _look_mat(Color(0.05, 0.05, 0.05), 0.5), Vector3(eye_x, eye_y, fz.call(eye_x, eye_y) + 0.01), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var band := TorusMesh.new(); band.inner_radius = 0.97; band.outer_radius = 1.03; band.rings = 32; band.ring_segments = 6
			if not covered:
				# the strap hugs the real head (or hair) all the way round
				var by := eye_y + ry * 0.18
				var bc := Vector3(0, by, c.z)
				var brad := Vector3(rx, 1.0, rz)
				var h_f = _head_hit(Vector3(0, by, c.z + 6.0), Vector3(0, 0, -1))
				var h_b = _head_hit(Vector3(0, by, c.z - 6.0), Vector3(0, 0, 1))
				var h_l = _head_hit(Vector3(-6.0, by, c.z), Vector3(1, 0, 0))
				var h_r = _head_hit(Vector3(6.0, by, c.z), Vector3(-1, 0, 0))
				if h_f != null and h_b != null and h_l != null and h_r != null:
					bc = Vector3(((h_l as Vector3).x + (h_r as Vector3).x) * 0.5, by, ((h_f as Vector3).z + (h_b as Vector3).z) * 0.5)
					brad = Vector3(((h_r as Vector3).x - (h_l as Vector3).x) * 0.5 + 0.012, 1.0, ((h_f as Vector3).z - (h_b as Vector3).z) * 0.5 + 0.012)
				_piece(band, _look_mat(Color(0.08, 0.06, 0.05)), bc, Vector3(brad.x, ry * 0.5, brad.z), Vector3(0, 0, -0.3))
		"scar":
			# a jagged slash from the brow, across the eye, down the cheek, with stitches
			var red := _look_mat(Color(0.55, 0.1, 0.12), 0.55)
			var stitch := _look_mat(Color(0.12, 0.07, 0.05), 0.8)
			var pts := [Vector2(-eye_x - rx * 0.12, eye_y + ry * 0.38), Vector2(-eye_x + rx * 0.02, eye_y + ry * 0.05),
				Vector2(-eye_x - rx * 0.08, eye_y - ry * 0.2), Vector2(-eye_x + rx * 0.06, eye_y - ry * 0.48)]
			for i in pts.size() - 1:
				var p0: Vector2 = pts[i]; var p1: Vector2 = pts[i + 1]
				var mid := (p0 + p1) * 0.5
				var seg := p1 - p0
				var zc: float = fz.call(mid.x, mid.y) + 0.012
				var bx := _boxm(rx * 0.085, seg.length() + rx * 0.06, 0.035)
				_piece(bx, red, Vector3(mid.x, mid.y, zc), Vector3.ONE, Vector3(0, mid.x / rx * 0.9, atan2(-seg.x, seg.y)))
				for k in 2:
					var sp := p0.lerp(p1, 0.33 + 0.34 * k)
					var st := _boxm(rx * 0.24, rx * 0.035, 0.03)
					_piece(st, stitch, Vector3(sp.x, sp.y, fz.call(sp.x, sp.y) + 0.022), Vector3.ONE, Vector3(0, sp.x / rx * 0.9, atan2(-seg.x, seg.y)))
		"warpaint":
			var paint := _look_mat(Color(0.15, 0.35, 0.95), 0.5)
			for sd in [-1.0, 1.0]:
				for k in 2:
					var yy := nose_y + 0.02 - 0.06 * k
					_piece(_boxm(rx * 0.32, ry * 0.05, 0.02), paint, Vector3(sd * rx * 0.48, yy, fz.call(sd * rx * 0.48, yy) + 0.005), Vector3.ONE, Vector3(0, sd * 0.45, 0))
		"blush":
			# soft rosy cheeks: a gentle pink glow that fades out at the edges
			var pink := StandardMaterial3D.new()
			pink.albedo_color = Color(1.0, 0.45, 0.5, 0.55)
			pink.albedo_texture = FX.soft_texture()
			pink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pink.cull_mode = BaseMaterial3D.CULL_DISABLED
			for sd in [-1.0, 1.0]:
				var yy2 := c.y - ry * 0.28
				var xx2: float = sd * rx * 0.52
				var qd := QuadMesh.new(); qd.size = Vector2(rx * 0.5, ry * 0.32)
				_piece(qd, pink, Vector3(xx2, yy2, fz.call(xx2, yy2) + 0.006), Vector3.ONE, Vector3(0, sd * 0.55, 0))
		"makeup":
			_makeup(nose_y, fz)
		"glitter":
			_glitter(nose_y, fz)
		"glow_eyes":
			# magic glowing eyes with a soft halo
			var gc := Color(0.35, 0.95, 1.0)
			var glow := StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = gc; glow.emission_enabled = true; glow.emission = gc; glow.emission_energy_multiplier = 6.0
			var halo := StandardMaterial3D.new(); halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			halo.albedo_texture = FX.soft_texture(); halo.albedo_color = Color(gc.r, gc.g, gc.b, 0.8)
			halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			for sd in [-1.0, 1.0]:
				var ex: float = sd * eye_x
				var ez: float = fz.call(ex, eye_y)
				_piece(_sphere(), glow, Vector3(ex, eye_y, ez + 0.004), Vector3(rx * 0.11, ry * 0.1, rx * 0.05))
				var hq := QuadMesh.new(); hq.size = Vector2(rx * 0.45, rx * 0.45)
				_piece(hq, halo, Vector3(ex, eye_y, ez + 0.006))
		"mask":
			_ninja_mask(hero, c, rx, ry, rz, nose_y, fem)
