extends Area3D
class_name QuestItem
## A glowing quest object (stolen axe, moonpetal, strongbox). It only shows up
## while its quest is active, and stays collected (saved in Game.flags).

var item := ""
var uid := ""
var _vis: Node3D
var _light: OmniLight3D
var _t := 0.0
var _taken := false

static func create(parent: Node, item_key: String, id: String, pos: Vector3) -> QuestItem:
	var q := QuestItem.new()
	q.item = item_key
	q.uid = id
	parent.add_child(q)
	q.global_position = pos
	q._build()
	return q

func _build() -> void:
	add_to_group("quest_item")
	collision_layer = 0
	collision_mask = 2          # the player
	var cs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 1.1
	cs.shape = sp; cs.position.y = 0.8
	add_child(cs)
	var col := Color(0.55, 0.8, 1.0)
	match item:
		"axe":
			_vis = Node3D.new(); add_child(_vis)
			var w: Node3D = (load(CharacterModel.WEAPON_SCENES["skel_axe"]) as PackedScene).instantiate()
			_vis.add_child(w)
			w.rotation = Vector3(0, 0, 0.5)
			w.scale = Vector3.ONE * 1.3
			col = Color(1.0, 0.8, 0.35)
		"moonpetal":
			_vis = Node3D.new(); add_child(_vis)
			for i in 5:
				var petal := MeshInstance3D.new()
				var pm := SphereMesh.new(); pm.radius = 0.16; pm.height = 0.1
				petal.mesh = pm
				petal.material_override = FX.glow_material(Color(0.45, 0.75, 1.0), 2.6)
				var a := TAU * i / 5.0
				petal.position = Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17)
				_vis.add_child(petal)
			var core := MeshInstance3D.new(); var cm := SphereMesh.new(); cm.radius = 0.08; cm.height = 0.16
			core.mesh = cm; core.material_override = FX.glow_material(Color(1.0, 0.95, 0.6), 3.0)
			_vis.add_child(core)
			var stem := MeshInstance3D.new(); var st := CylinderMesh.new(); st.top_radius = 0.02; st.bottom_radius = 0.03; st.height = 0.45
			stem.mesh = st; var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.25, 0.5, 0.2); stem.material_override = sm
			stem.position.y = -0.25
			_vis.add_child(stem)
			col = Color(0.45, 0.75, 1.0)
		"strongbox":
			_vis = Props.make("chest_gold")
			add_child(_vis)
			_vis.scale = Vector3.ONE * 0.8
			col = Color(1.0, 0.85, 0.4)
	_vis.position.y = 0.6
	_light = OmniLight3D.new(); _light.light_color = col; _light.light_energy = 1.4; _light.omni_range = 4.0
	_light.position.y = 1.0
	add_child(_light)
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 14; sparkle.lifetime = 1.4
	sparkle.mesh = FX.quad(0.1); sparkle.material_override = FX.glow_material(col, 2.0)
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sparkle.emission_sphere_radius = 0.5
	sparkle.direction = Vector3.UP; sparkle.spread = 30; sparkle.initial_velocity_min = 0.2; sparkle.initial_velocity_max = 0.6
	sparkle.gravity = Vector3.ZERO; sparkle.color_ramp = FX._fade_ramp(col)
	sparkle.position.y = 0.6
	add_child(sparkle)
	body_entered.connect(_on_body)
	Game.quests_changed.connect(_refresh)
	_refresh()

func _active() -> bool:
	for id in Game.quests:
		var g: Dictionary = Game.QUESTS[id].goal
		if g.type == "collect" and g.item == item and Game.quests[id].state == "active":
			return true
	return false

func _refresh() -> void:
	var show: bool = not _taken and not Game.flags.get(uid, false) and _active()
	visible = show
	set_deferred("monitoring", show)

func _process(delta: float) -> void:
	if not visible or _vis == null:
		return
	_t += delta
	_vis.rotation.y += delta * 1.2
	_vis.position.y = 0.6 + sin(_t * 2.0) * 0.12

func _on_body(b: Node) -> void:
	if _taken or not visible or not b.is_in_group("player"):
		return
	_taken = true
	Game.flags[uid] = true
	Sfx.play("pickup", -2.0)
	FX.burst(global_position + Vector3(0, 0.8, 0), _light.light_color, 30, 3.0, 0.15, 0.8, 0.5)
	Game.on_quest_item(item)
	queue_free()
