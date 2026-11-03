extends SceneTree
## Dev tool: renders every KayKit character side by side mid-animation.
## xvfb-run godot --path game -s res://scripts/tests/lineup.gd

const CHARS := [
	"res://assets/kaykit/adventurers/Knight.glb", "res://assets/kaykit/adventurers/Barbarian.glb",
	"res://assets/kaykit/adventurers/Mage.glb", "res://assets/kaykit/adventurers/Rogue.glb",
	"res://assets/kaykit/adventurers/Rogue_Hooded.glb",
	"res://assets/kaykit/skeletons/Skeleton_Minion.glb", "res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"res://assets/kaykit/skeletons/Skeleton_Rogue.glb", "res://assets/kaykit/skeletons/Skeleton_Mage.glb",
]

func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65); env.environment.ambient_light_energy = 0.6
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 20, 0); root.add_child(l)
	var i := 0
	for p in CHARS:
		var inst: Node3D = load(p).instantiate()
		root.add_child(inst)
		inst.position = Vector3((i - 4) * 1.6, 0, 0)
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		var sk: Skeleton3D = inst.find_child("*", true, false) as Skeleton3D
		for n in inst.find_children("*", "Skeleton3D", true, false):
			sk = n
		var aabb := AABB()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge((mi as MeshInstance3D).get_aabb())
		print(p.get_file(), " anims=", ap.get_animation_list().size() if ap else 0,
			" skel_bones=", sk.get_bone_count() if sk else 0, " aabb_y=", aabb.size.y,
			" meshes=", inst.find_children("*", "MeshInstance3D", true, false).map(func(m): return m.name))
		if ap:
			var a := "1H_Melee_Attack_Chop" if i % 2 == 0 else "Idle"
			if ap.has_animation(a):
				ap.play(a)
				ap.seek(0.35, true)
				ap.pause()
		i += 1
	if i > 0:
		var ap0: AnimationPlayer = root.get_child(2).find_child("AnimationPlayer", true, false)
		print("ANIMS: ", ap0.get_animation_list())
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.6, 9.5); cam.rotation_degrees.x = -5; cam.fov = 60
	root.add_child(cam)
	for k in 8:
		await process_frame
	get_root().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/406ea1ff-e3d6-5d4a-8ff4-d7f51a22cb2c/scratchpad/lineup.png")
	quit()
