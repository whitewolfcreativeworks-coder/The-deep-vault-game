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
}

## cfg: {kind:"hero", hero:"Knight", cape_color:Color, show_hat:bool, weapon:id, shield:id|""}
##      {kind:"skeleton", variant:"minion", weapon:"skel_blade", shield:"Skeleton_Shield_Small_A", eye:Color}
func setup(cfg: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	head_meshes.clear(); all_meshes.clear()
	kind = cfg.get("kind", "hero")
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
				_tint(m, cfg.cape_color)
		else:
			if String(m.name).contains("Head") or String(m.name).contains("Jaw") or String(m.name).contains("Skull") or String(m.name).contains("Eyes") or String(m.name).contains("Helmet") or String(m.name).contains("Hat") or String(m.name).contains("Hood"):
				head_meshes.append(m)
			if String(m.name).contains("Eyes") and cfg.has("eye"):
				var em := StandardMaterial3D.new()
				em.albedo_color = cfg.eye
				em.emission_enabled = true; em.emission = cfg.eye; em.emission_energy_multiplier = 6.0
				m.material_override = em
	_setup_anims()
	set_weapon(cfg.get("weapon", ""))
	set_offhand(cfg.get("shield", ""))
	_base_scale = float(cfg.get("scale", 0.84))
	scale = Vector3.ONE * _base_scale
	_play(anims.idle, 0.0)

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

func set_weapon(id: String) -> void:
	if weapon_root:
		weapon_root.queue_free()
		weapon_root = null
	if id == "" or not WEAPON_SCENES.has(id):
		return
	weapon_root = _attach("handslot.r")
	var w: Node3D = (load(WEAPON_SCENES[id]) as PackedScene).instantiate()
	weapon_root.add_child(w)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = flash_mat
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
