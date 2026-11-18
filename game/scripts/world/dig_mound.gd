extends Node3D
class_name DigMound
## A mound of freshly turned earth in the graveyard, where a ghost was digging
## for its lost locket. While Mott's quest is on, something glints in it: press
## USE to dig, and the locket pops out (and sometimes a skeleton with it).

var uid := ""               # the locket's quest-item uid
var item := "locket"
var grabby := false         # a skeleton climbs out with this one
var _busy := false
var _dug := false
var _glint: CPUParticles3D
var _dirt: MeshInstance3D
var _t := 0.0

static func make(parent: Node3D, pos: Vector3, id: String, skeleton := false) -> DigMound:
	var m := DigMound.new()
	m.uid = id
	m.grabby = skeleton
	parent.add_child(m)
	m.global_position = pos
	return m

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dig_mound")
	var soil := StandardMaterial3D.new(); soil.albedo_color = Color(0.3, 0.22, 0.15); soil.roughness = 1.0
	_dirt = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.9; sm.height = 0.9
	sm.radial_segments = 14; sm.rings = 6
	_dirt.mesh = sm; _dirt.material_override = soil; _dirt.scale = Vector3(1.0, 0.45, 1.3); _dirt.position.y = 0.05
	add_child(_dirt)
	# clods and a little wooden cross
	for k in 5:
		var cl := MeshInstance3D.new(); var cm := BoxMesh.new(); cm.size = Vector3.ONE * randf_range(0.15, 0.28)
		cl.mesh = cm; cl.material_override = soil
		var a := k * TAU / 5.0 + randf() * 0.5
		cl.position = Vector3(cos(a) * 1.1, 0.06, sin(a) * 1.3); cl.rotation = Vector3(randf(), randf(), randf())
		add_child(cl)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.42, 0.32, 0.22)
	var post := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(0.1, 0.9, 0.1)
	post.mesh = pm; post.material_override = wood; post.position = Vector3(0, 0.45, -1.35); post.rotation.z = 0.15; add_child(post)
	var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5, 0.09, 0.09)
	bar.mesh = bm; bar.material_override = wood; bar.position = Vector3(0.05, 0.68, -1.35); bar.rotation.z = 0.15; add_child(bar)
	# the gold glint that tells you something's buried here
	_glint = CPUParticles3D.new(); _glint.amount = 6; _glint.lifetime = 0.9
	_glint.mesh = FX.quad(0.14); _glint.material_override = FX.glow_material(Color(1.0, 0.85, 0.4), 3.0)
	_glint.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _glint.emission_sphere_radius = 0.4
	_glint.gravity = Vector3.ZERO; _glint.initial_velocity_max = 0.0; _glint.scale_amount_min = 0.5
	_glint.color_ramp = FX._fade_ramp(Color(1.0, 0.85, 0.4)); _glint.position.y = 0.4
	add_child(_glint)
	Game.quests_changed.connect(_refresh)
	_refresh()

func _active() -> bool:
	for id in Game.quests:
		var g: Dictionary = Game.QUESTS[id].goal
		if g.type == "collect" and g.item == item and Game.quests[id].state == "active":
			return true
	return false

func _refresh() -> void:
	_glint.emitting = can_interact()

func can_interact() -> bool:
	return not _busy and not _dug and not Game.flags.get(uid, false) and _active()

func get_prompt() -> String:
	return "[E] Dig in the loose earth"

func interact(by: Node) -> void:
	if not can_interact() or not (by is Player):
		return
	_busy = true
	_glint.emitting = false
	var p := by as Player
	var to := global_position - p.global_position; to.y = 0
	if to.length() > 0.1:
		p.facing = atan2(-to.x, -to.z)
		p.body.rotation.y = p.facing
	# three big scoops of dirt
	for k in 3:
		if not p.mounted:
			p.body.oneshot("1H_Melee_Attack_Chop", 0.45)
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree():
			return
		Sfx.play_at("hit", global_position, -6.0, 0.25)
		FX.burst(global_position + Vector3(0, 0.4, 0), Color(0.35, 0.26, 0.17), 18, 3.5, 0.18, 0.7, 0.0)
		_dirt.scale.y = maxf(0.12, _dirt.scale.y - 0.11)
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
	_dug = true
	_busy = false
	remove_from_group("interactable")
	# the locket pops up out of the hole
	var q := QuestItem.create(get_parent(), item, uid, global_position + Vector3(0, 0.1, 0))
	q.position.y += 0.0
	var tw := q.create_tween()
	q.scale = Vector3.ONE * 0.2
	tw.tween_property(q, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup", -6.0, 0.2)
	if grabby:
		# a bony hand bursts out of the earth...
		Sfx.play_at("bone_break", global_position, -2.0, 0.1)
		Game.say("A skeleton claws its way out of the grave! It wants that locket back!", Color(1.0, 0.6, 0.5))
		var sk := Enemy.new()
		sk.configure("crypt_skeleton", "", 0.0)
		sk.position = get_parent().to_local(global_position + Vector3(1.2, 0.3, 1.2))
		get_parent().add_child(sk)
		FX.burst(global_position + Vector3(1.2, 0.6, 1.2), Color(0.35, 0.26, 0.17), 30, 4.0, 0.2, 0.9, 0.0)
	else:
		Game.say("Something glints in the hole: a locket!", Color(1.0, 0.85, 0.5))
