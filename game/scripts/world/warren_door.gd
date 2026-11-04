extends Node3D
class_name WarrenDoor
## The barred door of the Goblin Warren. Captain Aldric unbars it when he gives
## you his quest; then E / USE takes you down into the dungeon.

var dest := Vector3.ZERO
var _bars: Node3D

static func make(parent: Node, pos: Vector3, to: Vector3) -> WarrenDoor:
	var d := WarrenDoor.new()
	d.dest = to
	parent.add_child(d)
	d.global_position = pos
	d._build()
	return d

func is_open() -> bool:
	return Game.quest_state("warren") in ["active", "ready", "done"]

func _build() -> void:
	add_to_group("interactable")
	_bars = Node3D.new(); add_child(_bars)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.36, 0.24, 0.14); wood.roughness = 0.9
	for k in 3:
		var plank := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(4.6, 0.35, 0.25)
		plank.mesh = bm; plank.material_override = wood
		plank.position = Vector3(0, 0.9 + k * 1.1, 0); plank.rotation.z = 0.12 * (k - 1)
		_bars.add_child(plank)
	var sb := StaticBody3D.new(); sb.name = "Bars"
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(4.6, 3.6, 0.6)
	cs.shape = bs; cs.position.y = 1.8; sb.add_child(cs); _bars.add_child(sb)
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.6, 0.3); glow.light_energy = 1.0; glow.omni_range = 5.0
	glow.position = Vector3(0, 2.0, -1.5); add_child(glow)
	Game.quests_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_bars.visible = not is_open()
	var sb := _bars.get_node("Bars") as StaticBody3D
	sb.collision_layer = 0 if is_open() else 1

func get_prompt() -> String:
	return "Enter the Goblin Warren" if is_open() else "Barred door (talk to Captain Aldric)"

func interact(_by: Node) -> void:
	if not is_open():
		Game.say("The door is barred from outside. Captain Aldric holds the key.", Color(1.0, 0.75, 0.5))
		return
	var sc := get_tree().current_scene
	if sc.has_method("teleport_player"):
		Sfx.play("door", -4.0)
		sc.teleport_player(dest, 0.0, "The Goblin Warren")
