extends NPC
class_name ShopNPC
## Someone at home you talk to for a shop or the forge (no quests, no beams in the
## sky): Tobble at the Trading Post, the smith at the Forge.

var prompt := ""
var on_talk: Callable

static func make(parent: Node, npc_id: String, pos: Vector3, yaw_deg: float, look: Dictionary, prompt_text: String, talk: Callable) -> ShopNPC:
	var n := ShopNPC.new()
	n.id = npc_id
	n.display_name = Game.NPC_NAMES.get(npc_id, npc_id)
	n.prompt = prompt_text
	n.on_talk = talk
	parent.add_child(n)
	n.global_position = pos
	n._home_yaw = deg_to_rad(yaw_deg)
	n._build(look)
	return n

func _refresh() -> void:
	_marker.visible = false
	_set_beam(false, Color.WHITE)

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	if on_talk.is_valid():
		on_talk.call()
