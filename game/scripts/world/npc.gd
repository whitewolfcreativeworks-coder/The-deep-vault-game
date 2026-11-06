extends Node3D
class_name NPC
## A friendly character in the Goblin Forest who gives one quest.
## Walk up and press E / USE to talk. A floating marker shows what they have:
##   gold "!"  a quest for you      gold "?"  your quest is ready to hand in
##   grey "…"  quest in progress     (none) all done

var id := ""
var display_name := ""
var quest := ""            # the quest this NPC is on right now (some give several, one after another)
var quests: Array = []

func _pick_quest() -> void:
	if quests.is_empty():
		return
	quest = quests[quests.size() - 1]
	for q in quests:
		if Game.quest_state(q) != "done":
			quest = q
			return
var body: CharacterModel
var _marker: Label3D
var _name_tag: Label3D
var _t := 0.0
var _home_yaw := 0.0
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _beam_core: MeshInstance3D
var _beam_motes: CPUParticles3D
var _beam_col := Color.WHITE

static func create(parent: Node, npc_id: String, pos: Vector3, yaw_deg: float, look: Dictionary) -> NPC:
	var n := NPC.new()
	n.id = npc_id
	n.display_name = Game.NPC_NAMES.get(npc_id, npc_id)
	for q in Game.QUESTS:
		if Game.QUESTS[q].giver == npc_id:
			n.quests.append(q)
	n._pick_quest()
	parent.add_child(n)
	n.global_position = pos
	n._home_yaw = deg_to_rad(yaw_deg)
	n._build(look)
	return n

func _build(look: Dictionary) -> void:
	add_to_group("interactable")
	add_to_group("npc")
	body = CharacterModel.new()
	add_child(body)
	var cfg := {"kind": "hero", "hero": look.get("hero", "Knight"), "show_hat": look.get("hat", true), "scale": 0.9,
		"weapon": look.get("weapon", ""), "shield": look.get("shield", "")}
	for k in ["skin_color", "hair_style", "hair_color", "hair_tint", "face", "outfit_color", "cape_color", "build", "height"]:
		if look.has(k):
			cfg[k] = look[k]
	body.setup(cfg)
	body.rotation.y = _home_yaw
	# a solid body so the player can't walk through
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
	cs.shape = cap; cs.position.y = 0.85
	sb.add_child(cs); add_child(sb)
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 44; _name_tag.pixel_size = 0.006
	_name_tag.outline_size = 10; _name_tag.modulate = Color(1.0, 0.92, 0.7)
	_name_tag.position.y = 2.25
	_name_tag.no_depth_test = false
	add_child(_name_tag)
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 150; _marker.pixel_size = 0.006
	_marker.outline_size = 22; _marker.outline_modulate = Color(0.15, 0.08, 0.0)
	_marker.position.y = 2.75
	add_child(_marker)
	_build_beam()
	Game.quests_changed.connect(_refresh)
	_refresh()

## A beam of light shooting up into the sky over anyone with a quest for you:
## white while they have a quest to give, green once you've taken it (that's
## who you report back to). It glows brightest when the quest is ready to hand in.
func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.1; cm.height = 14.0
	cm.radial_segments = 8; cm.cap_top = false; cm.cap_bottom = false
	_beam.mesh = cm
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.disable_receive_shadows = true
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 3.2 + 7.0
	add_child(_beam)
	_beam_core = MeshInstance3D.new()
	var cc := CylinderMesh.new(); cc.top_radius = 0.025; cc.bottom_radius = 0.035; cc.height = 14.0
	cc.radial_segments = 8; cc.cap_top = false; cc.cap_bottom = false
	_beam_core.mesh = cc; _beam_core.material_override = _beam_mat
	_beam_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_core.position.y = 3.2 + 7.0
	add_child(_beam_core)
	_beam_motes = CPUParticles3D.new(); _beam_motes.amount = 10; _beam_motes.lifetime = 2.0
	_beam_motes.mesh = FX.quad(0.08); _beam_motes.material_override = FX.glow_material(Color(1, 1, 1), 2.0)
	_beam_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _beam_motes.emission_sphere_radius = 0.12
	_beam_motes.direction = Vector3.UP; _beam_motes.spread = 5; _beam_motes.initial_velocity_min = 2.0; _beam_motes.initial_velocity_max = 4.0
	_beam_motes.gravity = Vector3.ZERO; _beam_motes.position.y = 3.2
	add_child(_beam_motes)

func _set_beam(on: bool, c: Color) -> void:
	_beam.visible = on; _beam_core.visible = on; _beam_motes.emitting = on
	_beam_col = c
	_beam_motes.color = c

func _refresh() -> void:
	_pick_quest()
	var st := Game.quest_state(quest)
	match st:
		"available":
			_marker.text = "!"; _marker.modulate = Color(1.0, 0.82, 0.15); _marker.visible = true
			_set_beam(true, Color(1.0, 1.0, 1.0))
		"ready":
			_marker.text = "?"; _marker.modulate = Color(1.0, 0.82, 0.15); _marker.visible = true
			_set_beam(true, Color(0.3, 1.0, 0.35))
		"active":
			_marker.text = "..."; _marker.modulate = Color(0.75, 0.75, 0.75, 0.8); _marker.visible = true
			_set_beam(true, Color(0.25, 0.85, 0.3))
		"locked":
			_marker.text = "..."; _marker.modulate = Color(0.75, 0.75, 0.75, 0.8); _marker.visible = true
			_set_beam(false, Color.WHITE)
		_:
			_marker.visible = false
			_set_beam(false, Color.WHITE)

func _process(delta: float) -> void:
	_t += delta
	_marker.position.y = 2.75 + sin(_t * 2.5) * 0.08
	if _beam and _beam.visible:
		# brighter when the quest is ready; softer when you're standing right next to it
		var ready := Game.quest_state(quest) == "ready"
		var pulse := 0.75 + 0.25 * sin(_t * (4.0 if ready else 1.6))
		var a := (0.75 if ready else 0.6) * pulse
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl:
			# softer right next to them; fades out far away (the compass covers that)
			var d := pl.global_position.distance_to(global_position)
			a *= clampf(d / 6.0, 0.35, 1.0) * clampf((90.0 - d) / 30.0, 0.0, 1.0)
		_beam_mat.albedo_color = Color(_beam_col.r, _beam_col.g, _beam_col.b, a)
	# turn to face the player when they come close, back to the post otherwise
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var want := _home_yaw
	if p and p.global_position.distance_to(global_position) < 7.0:
		var to := p.global_position - global_position
		want = atan2(-to.x, -to.z)   # CharacterModel faces -Z, like the player
	body.rotation.y = lerp_angle(body.rotation.y, want, 1.0 - exp(-4.0 * delta))

func get_prompt() -> String:
	match Game.quest_state(quest):
		"available": return "Talk to %s  (new quest!)" % display_name
		"ready": return "Talk to %s  (hand in quest)" % display_name
	return "Talk to %s" % display_name

func interact(_by: Node) -> void:
	var sc := get_tree().current_scene
	if sc.has_method("open_dialogue"):
		sc.open_dialogue(self)
