extends Node
## Hair contact sheet: one image per hair style, 6 hero/colour combos, front + 3/4.
const OUT := "/tmp/claude-0/-home-claude/406ea1ff-e3d6-5d4a-8ff4-d7f51a22cb2c/scratchpad/hair/"
var styles := ["natural", "short", "long", "swept", "shoulder", "wild", "bald", "buns", "spiky", "hat"]
var combos := [
	{"hero": "Knight", "hc": 0, "sk": 0},
	{"hero": "Rogue", "hc": 4, "sk": 3},
	{"hero": "Barbarian", "hc": 7, "sk": 5},
	{"hero": "Mage", "hc": 1, "sk": 1},
	{"hero": "Knight", "hc": 5, "sk": 6},
	{"hero": "Rogue", "hc": 8, "sk": 2},
]
var row := 0
var frame := 0
var holder: Node3D
var tag := ""

func _ready() -> void:
	tag = OS.get_environment("TAG")
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.32, 0.36, 0.42)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.55, 0.6); e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e; add_child(env)
	var cam := Camera3D.new(); add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.4
	cam.position = Vector3(0, 1.85, 10); cam.current = true
	var li := DirectionalLight3D.new(); add_child(li); li.rotation_degrees = Vector3(-35, 30, 0); li.light_energy = 1.1
	_build()

func _build() -> void:
	if holder:
		holder.free()
	holder = Node3D.new(); add_child(holder)
	var st: String = styles[row]
	for i in combos.size():
		for v in 2:
			var c: Dictionary = combos[i]
			var cfg := {"kind": "hero", "hero": c.hero, "scale": 1.0, "show_hat": st == "hat",
				"hair_style": "natural" if st == "hat" else st, "hair_color": Game.HAIR_COLORS2[c.hc]}
			if c.hc > 0:
				cfg["hair_tint"] = Game.HAIR_COLORS2[c.hc]
			if c.sk > 0:
				cfg["skin_color"] = Game.SKIN_COLORS[c.sk]
			var m := CharacterModel.new()
			holder.add_child(m)
			m.setup(cfg)
			m.position = Vector3((i * 2 + v - 5.5) * 1.05, 0, 0)
			m.rotation.y = PI + (0.0 if v == 0 else 0.8)

func _process(_d: float) -> void:
	frame += 1
	if frame == 12:
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT + "row_%s_%02d_%s.png" % [tag, row, styles[row]])
		row += 1
		frame = 0
		if row >= styles.size():
			get_tree().quit()
			return
		_build()

