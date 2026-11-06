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
		"locket":
			_vis = Node3D.new(); add_child(_vis)
			var gold := StandardMaterial3D.new(); gold.albedo_color = Color(1.0, 0.8, 0.35); gold.metallic = 0.9; gold.roughness = 0.25
			gold.emission_enabled = true; gold.emission = Color(0.5, 0.35, 0.1)
			for sx in [-0.06, 0.06]:
				var lobe := MeshInstance3D.new(); var lm := SphereMesh.new(); lm.radius = 0.1; lm.height = 0.12
				lobe.mesh = lm; lobe.material_override = gold; lobe.position = Vector3(sx, 0.04, 0); _vis.add_child(lobe)
			var tip := MeshInstance3D.new(); var tm := PrismMesh.new(); tm.size = Vector3(0.24, 0.16, 0.1)
			tip.mesh = tm; tip.material_override = gold; tip.rotation.z = PI; tip.position.y = -0.07; _vis.add_child(tip)
			var chain := MeshInstance3D.new(); var cm2 := TorusMesh.new(); cm2.inner_radius = 0.17; cm2.outer_radius = 0.19
			chain.mesh = cm2; chain.material_override = gold; chain.rotation.x = PI * 0.5; chain.position.y = 0.22; _vis.add_child(chain)
			col = Color(1.0, 0.85, 0.5)
		"beacon":
			# an unlit beacon pole with a cold wisp waiting to be lit
			_vis = Node3D.new(); add_child(_vis)
			var wisp := MeshInstance3D.new(); var wm := SphereMesh.new(); wm.radius = 0.22; wm.height = 0.44
			wisp.mesh = wm; wisp.material_override = FX.glow_material(Color(1.0, 0.85, 0.5), 3.0); _vis.add_child(wisp)
			col = Color(1.0, 0.8, 0.45)
		"holywater":
			_vis = Props.make("bottle_A_labeled_brown"); add_child(_vis)
			for mi in _vis.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = FX.glow_material(Color(0.6, 0.85, 1.0), 1.8)
			col = Color(0.6, 0.85, 1.0)
		"musicbox":
			_vis = Props.make("chest_gold"); add_child(_vis)
			_vis.scale = Vector3.ONE * 0.5
			col = Color(1.0, 0.7, 0.9)
		"feather":
			_vis = Node3D.new(); add_child(_vis)
			var fm := FX.glow_material(Color(1.0, 0.85, 0.4), 1.6)
			var quill := MeshInstance3D.new(); var qm := BoxMesh.new(); qm.size = Vector3(0.18, 0.7, 0.03)
			quill.mesh = qm; quill.material_override = fm; quill.rotation.z = 0.3; _vis.add_child(quill)
			for k in 5:
				var vane := MeshInstance3D.new(); var vm := BoxMesh.new(); vm.size = Vector3(0.28 - k * 0.03, 0.09, 0.02)
				vane.mesh = vm; vane.material_override = fm; vane.position = Vector3(0.1 - k * 0.03, 0.25 - k * 0.12, 0); vane.rotation.z = 0.5
				_vis.add_child(vane)
			col = Color(1.0, 0.85, 0.4)
		"updraft":
			_vis = Node3D.new(); add_child(_vis)
			var cr := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.35, 0.6, 0.35)
			cr.mesh = pm; cr.material_override = FX.glow_material(Color(1.0, 0.7, 0.4), 2.5); _vis.add_child(cr)
			var cr2 := MeshInstance3D.new(); cr2.mesh = pm; cr2.material_override = cr.material_override
			cr2.rotation.z = PI; cr2.position.y = -0.55; _vis.add_child(cr2)
			col = Color(1.0, 0.7, 0.4)
		"ventstone":
			_vis = Node3D.new(); add_child(_vis)
			var st := MeshInstance3D.new(); var cm2 := CylinderMesh.new(); cm2.top_radius = 0.35; cm2.bottom_radius = 0.45; cm2.height = 0.5
			st.mesh = cm2; var sm2 := StandardMaterial3D.new(); sm2.albedo_color = Color(0.85, 0.75, 0.5); sm2.metallic = 0.5
			st.material_override = sm2; _vis.add_child(st)
			var gem := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.18; gs.height = 0.36
			gem.mesh = gs; gem.material_override = FX.glow_material(Color(0.5, 0.85, 1.0), 2.5); gem.position.y = 0.35
			_vis.add_child(gem)
			col = Color(0.5, 0.85, 1.0)
		"stormbubble":
			_vis = Node3D.new(); add_child(_vis)
			var bb := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.55; bs.height = 1.1
			bb.mesh = bs
			var bmat := StandardMaterial3D.new(); bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bmat.albedo_color = Color(1.0, 0.92, 0.4, 0.3); bmat.emission_enabled = true; bmat.emission = Color(1.0, 0.9, 0.3)
			bmat.emission_energy_multiplier = 1.0; bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			bb.material_override = bmat; _vis.add_child(bb)
			col = Color(1.0, 0.9, 0.35)
		_:
			_vis = Node3D.new(); add_child(_vis)
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
	if item == "stormbubble":
		Sfx.play("pop", -2.0, 0.1)
		if b.has_method("add_trauma"):
			b.add_trauma(0.15)
	Sfx.play("pickup", -2.0)
	FX.burst(global_position + Vector3(0, 0.8, 0), _light.light_color, 30, 3.0, 0.15, 0.8, 0.5)
	Game.on_quest_item(item)
	queue_free()
