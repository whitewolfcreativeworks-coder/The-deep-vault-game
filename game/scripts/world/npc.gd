extends Node3D
class_name NPC
## A friendly character in the Goblin Forest who gives one quest.
## Walk up and press E / USE to talk. A floating marker shows what they have:
##   gold "!"  a quest for you      gold "?"  your quest is ready to hand in
##   grey "…"  quest in progress     (none) all done

var id := ""
var display_name := ""
var quest := ""
var body: CharacterModel
var _marker: Label3D
var _name_tag: Label3D
var _t := 0.0
var _home_yaw := 0.0

static func create(parent: Node, npc_id: String, pos: Vector3, yaw_deg: float, look: Dictionary) -> NPC:
	var n := NPC.new()
	n.id = npc_id
	n.display_name = Game.NPC_NAMES.get(npc_id, npc_id)
	for q in Game.QUESTS:
		if Game.QUESTS[q].giver == npc_id:
			n.quest = q
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
	Game.quests_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var st := Game.quest_state(quest)
	match st:
		"available":
			_marker.text = "!"; _marker.modulate = Color(1.0, 0.82, 0.15); _marker.visible = true
		"ready":
			_marker.text = "?"; _marker.modulate = Color(1.0, 0.82, 0.15); _marker.visible = true
		"active", "locked":
			_marker.text = "..."; _marker.modulate = Color(0.75, 0.75, 0.75, 0.8); _marker.visible = true
		_:
			_marker.visible = false

func _process(delta: float) -> void:
	_t += delta
	_marker.position.y = 2.75 + sin(_t * 2.5) * 0.08
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
