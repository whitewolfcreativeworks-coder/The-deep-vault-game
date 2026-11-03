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
var weapon_tip: Node3D
var head_meshes: Array[MeshInstance3D] = []
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
	"Barbarian": {"path": "res://assets/kaykit/adventurers/Barbarian.glb", "sex": "male", "head": ["Barbarian_Head", "Barbarian_Hat"], "hat": "Barbarian_Hat", "cape": "Barbarian_Cape"},
	"Rogue": {"path": "res://assets/kaykit/adventurers/Rogue.glb", "sex": "female", "head": ["Rogue_Head"], "hat": "", "cape": "Rogue_Cape"},
	"Ranger": {"path": "res://assets/kaykit/adventurers/Rogue_Hooded.glb", "sex": "female", "head": ["Rogue_Head_Hooded"], "hat": "", "cape": "Rogue_Cape"},
	"Mage": {"path": "res://assets/kaykit/adventurers/Mage.glb", "sex": "male", "head": ["Mage_Head", "Mage_Hat"], "hat": "Mage_Hat", "cape": "Mage_Cape"},
}
const SKELETONS := {
	"minion": "res://assets/kaykit/skeletons/Skeleton_Minion.glb",
	"warrior": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"rogue": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb",
	"mage": "res://assets/kaykit/skeletons/Skeleton_Mage.glb",
}
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
}
## How each skin changes the body: albedo multiply, metal/rough, emission, alpha.
const SKIN_LOOKS := {
	"lizard": {"albedo": Color(0.55, 1.0, 0.45), "rough": 0.45, "emit": Color(0.03, 0.14, 0.02)},
	"frost": {"albedo": Color(0.72, 0.9, 1.0), "rough": 0.25, "metal": 0.2, "emit": Color(0.1, 0.25, 0.45)},
	"gold": {"albedo": Color(1.0, 0.85, 0.4), "rough": 0.3, "metal": 0.55, "emit": Color(0.42, 0.3, 0.06)},
	"spectral": {"albedo": Color(0.55, 0.88, 1.0, 0.42), "rough": 0.3, "emit": Color(0.25, 0.6, 0.9), "alpha": true},
	"ember": {"albedo": Color(1.0, 0.55, 0.4), "rough": 0.6, "emit": Color(0.9, 0.28, 0.05)},
}
var _aura: Node3D

## cfg: {kind:"hero", hero:"Knight", cape_color:Color, outfit_color:Color, show_hat:bool, weapon:id, shield:id|""}
##      {kind:"skeleton", variant:"minion", weapon:"skel_blade", shield:"Skeleton_Shield_Small_A", eye:Color}
func setup(cfg: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	head_meshes.clear(); all_meshes.clear()
	kind = cfg.get("kind", "hero")
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
			var is_head := nm.contains("_Head")
			if skin_c != null or has_outfit or (is_head and hair_t != null):
				var st := 0.0 if is_head else (0.72 if has_outfit else (0.3 if armor_t != Color.WHITE else 0.0))
				_recolor(m, (outfit if has_outfit else Color.WHITE) * armor_t, st, 1.0, skin_c, hair_t if is_head else null)
			elif armor_t != Color.WHITE and not is_head:
				_mul(m, armor_t)
	if SKIN_LOOKS.has(skin):
		for m in all_meshes:
			if String(m.name).contains("Eyes"):
				continue
			_skin_mat(m, SKIN_LOOKS[skin], String(m.name).contains("Cape"))
	var weapon = cfg.get("weapon", "")
	set_weapon(weapon)
	set_offhand(cfg.get("shield", ""))
	if cfg.has("aura"):
		_add_aura(cfg.aura, int(cfg.get("aura_level", 3)), skin == "ember")
	elif skin == "ember":
		_add_aura(Color(1.0, 0.45, 0.15), 2, true)
	_base_scale = float(cfg.get("scale", 0.84))
	scale = Vector3.ONE * _base_scale
	if kind == "hero":
		var bw := float(cfg.get("build", 1.0))
		var bh := float(cfg.get("height", 1.0))
		model.scale = Vector3(bw, bh, lerpf(1.0, bw, 0.85))
		var hat_on: bool = hero.hat != "" and cfg.get("show_hat", true)
		var hooded: bool = String(hero.get("path", "")).contains("Hooded")
		_add_head_looks(hero, cfg, hat_on or hooded)
	_play(anims.idle, 0.0)

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
		d.roughness = look.get("rough", d.roughness)
		d.metallic = look.get("metal", d.metallic)
		var e: Color = look.get("emit", Color.BLACK)
		if e.get_luminance() > 0.0:
			d.emission_enabled = true
			d.emission = e * (0.6 if is_cape else 1.0)
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
		r.set_shader_parameter("strength", strength)
		r.set_shader_parameter("skin_protect", skin_protect)
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

func _play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if anim.current_animation == clip and anim.is_playing():
		anim.speed_scale = speed
		return
	anim.play(clip, blend)
	anim.speed_scale = speed

## Play a non-looping clip, compressed/stretched to `duration` seconds.
func oneshot(role: String, duration := -1.0, blend := 0.08) -> void:
	var clip: String = anims.get(role, role)
	if anim == null or not anim.has_animation(clip):
		return
	var length := anim.get_animation(clip).length
	var spd := 1.0 if duration <= 0.0 else length / duration
	anim.play(clip, blend)
	anim.seek(0.0, true)
	anim.speed_scale = spd
	_oneshot = clip
	_oneshot_until = _clock + (length / spd) - 0.05

func clip_length(role: String) -> float:
	var clip: String = anims.get(role, role)
	return anim.get_animation(clip).length if anim and anim.has_animation(clip) else 1.0

func _process(delta: float) -> void:
	_clock += delta
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
	if id == "" or not WEAPON_SCENES.has(id):
		return
	weapon_root = _attach("handslot.r")
	var w: Node3D = (load(WEAPON_SCENES[id]) as PackedScene).instantiate()
	weapon_root.add_child(w)
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
	weapon_root.add_child(weapon_tip)
	weapon_tip.position = Vector3(0, 0.9, 0)

func set_offhand(id: String) -> void:
	if offhand_root:
		offhand_root.queue_free()
		offhand_root = null
	if id == "":
		return
	var p := "res://assets/kaykit/items/%s.gltf" % id
	if not ResourceLoader.exists(p):
		return
	offhand_root = _attach("handslot.l")
	var s: Node3D = (load(p) as PackedScene).instantiate()
	offhand_root.add_child(s)
	for mi in s.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = flash_mat

func set_head_visible(v: bool) -> void:
	for m in head_meshes:
		if is_instance_valid(m):
			m.visible = v

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
	_play(_loco, 0.24, w[1] if clip == _loco else anim.speed_scale)

# ---------------------------------------------------------------------------
# Character-creator looks: hair styles and face details are small meshes on the
# head bone, laid out from the head mesh's own bounds so they fit every hero.
var looks_root: Node3D

func _head_bounds(hero: Dictionary) -> AABB:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == hero.head[0]:
			return (mi as MeshInstance3D).get_aabb()
	return AABB(Vector3(-0.54, 1.2, -0.5), Vector3(1.08, 1.1, 1.02))

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
	if (style == "natural" or covered) and face == "none":
		return
	if skel == null or skel.find_bone("head") < 0:
		return
	var hb := skel.find_bone("head")
	var ba := _attach("head")
	looks_root = Node3D.new()
	looks_root.transform = skel.get_bone_global_rest(hb).affine_inverse()   # author in skeleton space
	ba.add_child(looks_root)
	var box := _head_bounds(hero)
	var c := box.get_center()
	var sz := box.size
	var rx := sz.x * 0.5; var ry := sz.y * 0.5; var rz := sz.z * 0.5
	var hair_c: Color = cfg.get("hair_color", Color(0.32, 0.19, 0.1))
	var skin_c: Color = cfg.get("skin_color", Color(0.97, 0.8, 0.67))
	var hair := _look_mat(hair_c, 0.7)
	# Hair styles are added on top of the hero's own (recoloured) hair rather
	# than covering it with a cap, so they read as hair and not as a helmet.
	# Points on the head surface: an ellipsoid fitted to the head bounds.
	var surf := func(yaw_a: float, pitch_a: float, out := 1.0) -> Vector3:
		return c + Vector3(sin(yaw_a) * cos(pitch_a) * rx, sin(pitch_a) * ry, cos(yaw_a) * cos(pitch_a) * rz) * out
	if not covered:
		match style:
			"curly":
				# a mop of bumpy curls over the top, back and sides
				var k := 0
				for row in [[1.35, 1], [0.95, 7], [0.55, 10], [0.15, 9]]:
					var pa: float = row[0]
					var cnt: int = row[1]
					for i in cnt:
						var ya := TAU * (float(i) + 0.5 * (k % 2)) / cnt
						if cos(ya) > 0.55 and pa < 0.8:
							continue   # keep the face clear
						var pr: Vector3 = surf.call(ya, pa, 0.98)
						_piece(_sphere(), hair, pr, Vector3.ONE * rx * (0.3 + 0.04 * sin(i * 2.7 + pa * 5.0)))
					k += 1
			"long":
				# strands falling from the crown down the back and past the ears
				for i in 7:
					var ya := PI + (float(i) - 3.0) * 0.32
					var top: Vector3 = surf.call(ya, 0.55, 0.92)
					var cap := CapsuleMesh.new(); cap.radius = rx * 0.15; cap.height = sz.y * 1.05
					_piece(cap, hair, top + Vector3(0, -sz.y * 0.42, 0) + Vector3(sin(ya), 0, cos(ya)) * rz * 0.12, Vector3.ONE, Vector3(-cos(ya) * 0.12, 0, sin(ya) * 0.12))
				for sd in [-1.0, 1.0]:
					for j in 2:
						var ya2: float = sd * (PI * 0.5 - 0.05 + 0.32 * j)
						var top2: Vector3 = surf.call(ya2, 0.35, 1.0)
						var cap2 := CapsuleMesh.new(); cap2.radius = rx * 0.14; cap2.height = sz.y * 0.9
						_piece(cap2, hair, top2 + Vector3(0, -sz.y * 0.38, 0), Vector3.ONE, Vector3(0, 0, sd * 0.1))
			"ponytail":
				var tie: Vector3 = surf.call(PI, 0.55, 1.0)
				_piece(_sphere(), _look_mat(Color(0.8, 0.15, 0.2), 0.5), tie, Vector3.ONE * rx * 0.17)
				var cap3 := CapsuleMesh.new(); cap3.radius = rx * 0.2; cap3.height = sz.y * 0.95
				_piece(cap3, hair, tie + Vector3(0, -sz.y * 0.36, -rz * 0.28), Vector3.ONE, Vector3(-0.5, 0, 0))
				_piece(_sphere(), hair, tie + Vector3(0, -sz.y * 0.78, -rz * 0.52), Vector3(rx * 0.17, ry * 0.2, rz * 0.17))
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
			"mohawk":
				# shaved head (hair recoloured to skin) with a tall crest front to back
				for i in 8:
					var ang := 1.0 + float(i) * 0.27    # from the hairline over the crown to the back
					var pt := c + Vector3(0, sin(ang) * ry, cos(ang) * rz) * 0.96
					var n2 := (pt - c).normalized()
					var cone2 := CylinderMesh.new(); cone2.top_radius = 0.0; cone2.bottom_radius = rx * 0.17
					cone2.height = ry * (0.5 + 0.45 * sin(float(i) / 7.0 * PI))
					var pc2 := _piece(cone2, hair, pt + n2 * cone2.height * 0.45, Vector3(0.45, 1.0, 1.0))
					pc2.basis = Basis(Quaternion(Vector3.UP, n2)) * Basis.from_scale(Vector3(0.45, 1.0, 1.0))
	# face details sit on the front of the head (+Z in skeleton space)
	var fz := func(x: float, y: float) -> float:
		var k := 1.0 - pow(x / rx, 2.0) - pow((y - c.y) / ry, 2.0)
		return c.z + rz * sqrt(maxf(k, 0.05))
	var eye_y := c.y - ry * 0.08
	var eye_x := rx * 0.36
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
				_piece(band, _look_mat(Color(0.08, 0.06, 0.05)), Vector3(0, eye_y + ry * 0.18, c.z), Vector3(rx * 1.0, ry * 0.5, rz * 1.0), Vector3(0, 0, -0.3))
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
					var yy := c.y - ry * (0.26 + 0.12 * k)
					_piece(_boxm(rx * 0.32, ry * 0.05, 0.02), paint, Vector3(sd * rx * 0.48, yy, fz.call(sd * rx * 0.48, yy) + 0.005), Vector3.ONE, Vector3(0, sd * 0.45, 0))
		"blush":
			var pink := _look_mat(Color(1.0, 0.5, 0.55), 0.6)
			for sd in [-1.0, 1.0]:
				var yy2 := c.y - ry * 0.3
				var d2 := CylinderMesh.new(); d2.top_radius = rx * 0.13; d2.bottom_radius = rx * 0.13; d2.height = 0.02
				_piece(d2, pink, Vector3(sd * rx * 0.5, yy2, fz.call(sd * rx * 0.5, yy2) - 0.005), Vector3.ONE, Vector3(PI / 2, sd * 0.5, 0))
