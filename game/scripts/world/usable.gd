extends Node3D
class_name Usable
## A spot you can USE: it shows a prompt and runs a function (doors, the desk,
## the gear chest, the bed).

var prompt := ""
var action: Callable

static func make(parent: Node, at: Vector3, prompt_text: String, fn: Callable) -> Usable:
	var u := Usable.new()
	u.prompt = prompt_text
	u.action = fn
	parent.add_child(u)
	u.global_position = at
	u.add_to_group("interactable")
	return u

func can_interact() -> bool:
	return action.is_valid()

func get_prompt() -> String:
	return prompt

func interact(_by: Node) -> void:
	if action.is_valid():
		action.call()
