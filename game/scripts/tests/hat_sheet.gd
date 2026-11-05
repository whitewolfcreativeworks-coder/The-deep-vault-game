extends Node
## Dev tool: the Mage's hat at the old size vs the new smaller size, front and from
## the usual over-the-shoulder camera. Run: godot --path . res://scripts/tests/hat_sheet.tscn
const OUT := "/tmp/claude-0/-home-claude/406ea1ff-e3d6-5d4a-8ff4-d7f51a22cb2c/scratchpad/hair/"
var frame := 0
var cam: Camera3D
var shot := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.32, 0.36, 0.42)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.55, 0.6); e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e; add_child(env)
	var li := DirectionalLight3D.new(); add_child(li); li.rotation_degrees = Vector3(-35, 30, 0)
	for i in 2:
		var m := CharacterModel.new()
		add_child(m)
		m.setup({"kind": "hero", "hero": "Mage", "scale": 0.84, "show_hat": true})
		m.position = Vector3(-0.9 + i * 1.8, 0, 0)
		if i == 0:   # old size for comparison
			var hat := m.find_child("Mage_Hat", true, false) as MeshInstance3D
			var orig: Node = (load("res://assets/kaykit/adventurers/Mage.glb") as PackedScene).instantiate()
			hat.mesh = (orig.find_child("Mage_Hat", true, false) as MeshInstance3D).mesh
			orig.free()
	cam = Camera3D.new(); add_child(cam); cam.current = true
	cam.position = Vector3(0, 1.5, -4.2); cam.look_at(Vector3(0, 1.3, 0))

func _process(_d: float) -> void:
	frame += 1
	if frame == 10:
		get_viewport().get_texture().get_image().save_png(OUT + "hat_%s_%d.png" % [OS.get_environment("TAG"), shot])
		shot += 1
		frame = 0
		if shot == 1:
			# third person from behind, zoomed in close
			cam.position = Vector3(-0.9, 2.0, 2.0); cam.look_at(Vector3(-0.9, 1.4, -4.0))
		elif shot == 2:
			cam.position = Vector3(0.9, 2.0, 2.0); cam.look_at(Vector3(0.9, 1.4, -4.0))
		else:
			get_tree().quit()
