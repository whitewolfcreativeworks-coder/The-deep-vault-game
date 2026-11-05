extends Node3D
class_name ChickenClaim
## Walk up to the Giant Chicken in Grimgor's throne cavern and use it to claim
## your mount. After that, ride any time with G (or the RIDE button).

var chicken: ChickenMount

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "Claim your reward: the Giant Chicken!  [E]"

func interact(by: Node) -> void:
	Game.flags["mount_chicken"] = true
	Game.say("You have a mount! Ride the Giant Chicken any time: press G (or tap RIDE).", Color(1.0, 0.9, 0.4))
	Game.message.emit("New mount: the Giant Chicken!", Color(1.0, 0.95, 0.6))
	Sfx.play("levelup", -2.0, 0.0)
	if chicken and is_instance_valid(chicken):
		FX.burst(chicken.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.95, 0.7), 60, 4.0, 0.2, 1.0, -2.0)
		chicken.queue_free()
	if by and by.has_method("mount_up"):
		by.global_position = global_position
		by.mount_up()
	var main := get_tree().current_scene
	if main and main.has_method("autosave"):
		main.autosave()
