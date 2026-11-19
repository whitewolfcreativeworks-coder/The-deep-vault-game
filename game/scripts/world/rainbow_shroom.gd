extends Node3D
class_name RainbowShroom
## A glowing mushroom you can eat (USE). Each one gives a little magic (mana) and
## a dose of "rainbow vision" (Game.shroom). One is pretty. Five and you can hardly
## tell up from down. The lesson: don't eat too many mushrooms! A mushroom grows
## back after a couple of minutes.

const REGROW := 120.0
const LINES := [
	"Mmm... it tastes like rainbows. Ooh, pretty colours!",
	"Whoa... everything's going swirly!",
	"Hee hee! The walls are dancing!",
	"Rainbows EVERYWHERE! (Maybe that's enough mushrooms...)",
	"WOOOAH! Which way is up?! (Lesson learned: don't eat so many mushrooms!)",
]

var col := Color(0.35, 0.9, 0.75)
var lit := true
var _vis: Node3D
var _light: OmniLight3D
var _gone := 0.0

static func make(parent: Node, at: Vector3, c: Color, size := 1.0, with_light := true) -> RainbowShroom:
	var s := RainbowShroom.new()
	s.col = c
	s.lit = with_light
	parent.add_child(s)
	s.position = at
	s.scale = Vector3.ONE * size
	return s

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("rainbow_shroom")
	_vis = Node3D.new(); add_child(_vis)
	var cap := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.35; sm.height = 0.35; sm.is_hemisphere = true
	cap.mesh = sm; cap.material_override = FX.glow_material(col, 1.6)
	cap.position = Vector3(0, 0.4, 0)
	_vis.add_child(cap)
	# little white spots on the cap
	var spot := StandardMaterial3D.new(); spot.albedo_color = Color(1, 1, 1); spot.emission_enabled = true
	spot.emission = Color(1, 1, 1); spot.emission_energy_multiplier = 0.8
	for k in 5:
		var a := k * TAU / 5.0 + 0.4
		var d := MeshInstance3D.new(); var ds := SphereMesh.new(); ds.radius = 0.045; ds.height = 0.05
		d.mesh = ds; d.material_override = spot
		d.position = Vector3(cos(a) * 0.2, 0.62, sin(a) * 0.2)
		_vis.add_child(d)
	var stem := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.1; cm.height = 0.42
	stem.mesh = cm; var st := StandardMaterial3D.new(); st.albedo_color = Color(0.85, 0.82, 0.7); stem.material_override = st
	stem.position = Vector3(0, 0.21, 0)
	_vis.add_child(stem)
	_light = OmniLight3D.new(); _light.light_color = col; _light.light_energy = 0.8; _light.omni_range = 4.0
	_light.position = Vector3(0, 0.8, 0); add_child(_light)
	_light.visible = lit

func can_interact() -> bool:
	return _gone <= 0.0

func get_prompt() -> String:
	return "[E] Eat the glowing mushroom"

func interact(by: Node) -> void:
	if _gone > 0.0:
		return
	_gone = REGROW
	_vis.visible = false
	_light.visible = false
	var lvl := mini(int(floor(Game.shroom)) + 1, 5)
	Game.shroom = minf(5.0, floor(Game.shroom) + 1.0) + 0.6
	Game.mana = minf(Game.max_mana(), Game.mana + Game.max_mana() * 0.15)
	Sfx.play("pickup", -6.0, 0.4)
	Sfx.play_at("pop", global_position, -6.0, 0.4)
	for k in 6:
		FX.burst(global_position + Vector3(0, 0.6, 0), Color.from_hsv(k / 6.0, 0.7, 1.0), 8, 2.0, 0.08, 0.9, 0.5)
	Game.say(LINES[lvl - 1], Color.from_hsv(randf(), 0.5, 1.0))

func _process(delta: float) -> void:
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			_vis.visible = true
			_light.visible = lit
			_vis.scale = Vector3.ONE * 0.1
			create_tween().tween_property(_vis, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK)
