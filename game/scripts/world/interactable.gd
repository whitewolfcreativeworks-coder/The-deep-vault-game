extends Node3D
class_name Interactable
## E-to-use world objects: chest, lever, inscription, shrine (checkpoint), altar.

signal used(by: Node)

var kind := "chest"
var uid := ""
var title := ""
var text := ""
var loot: Array = []        # [{kind:"gold", amount:30}, {kind:"item", id:"knight_sword"}, {kind:"potion", amount:2}]
var once := true
var spent := false
var spawn_yaw := 0.0
var _vis: Node3D
var _lid: Node3D
var _light: OmniLight3D
var _rune: MeshInstance3D

static func create(parent: Node, k: String, pos: Vector3, yaw_deg := 0.0, id := "", loot_items: Array = [], t := "", body := "") -> Interactable:
	var n := Interactable.new()
	n.kind = k
	n.uid = id
	n.loot = loot_items
	n.title = t
	n.text = body
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.spawn_yaw = deg_to_rad(yaw_deg)
	n._build()
	if id != "" and Game.flags.get(id, false):
		n._apply_spent(true)
	n.add_to_group("interactable")
	return n

func _build() -> void:
	match kind:
		"chest":
			_vis = Props.place(self, "chest_gold" if loot.size() > 2 else "chest", Vector3.ZERO, 0.0, 1.0, true)
			for n in _vis.find_children("*", "Node3D", true, false):
				if String(n.name).to_lower().contains("lid") or String(n.name).to_lower().contains("top"):
					_lid = n
			_light = OmniLight3D.new(); _light.light_color = Color(1.0, 0.8, 0.35); _light.light_energy = 0.6; _light.omni_range = 3.0
			_light.position = Vector3(0, 0.8, 0)
			add_child(_light)
		"lever":
			var base := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5, 0.6, 0.2); base.mesh = bm
			base.material_override = _metal(Color(0.25, 0.24, 0.26)); base.position = Vector3(0, 1.1, 0); add_child(base)
			_lid = Node3D.new(); _lid.position = Vector3(0, 1.1, -0.12); add_child(_lid)
			var arm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.03; cm.height = 0.55
			arm.mesh = cm; arm.material_override = _metal(Color(0.45, 0.4, 0.35)); arm.position = Vector3(0, 0.25, 0); _lid.add_child(arm)
			var knob := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12; knob.mesh = sm
			knob.material_override = _metal(Color(0.8, 0.2, 0.15)); knob.position = Vector3(0, 0.52, 0); _lid.add_child(knob)
			_lid.rotation.x = -0.7
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.5, 0.6, 0.3)
			cs.shape = bs; cs.position = Vector3(0, 1.1, 0); sb.add_child(cs); add_child(sb)
		"inscription":
			_vis = MeshInstance3D.new(); var b2 := BoxMesh.new(); b2.size = Vector3(1.0, 1.4, 0.25); (_vis as MeshInstance3D).mesh = b2
			var sm2 := ShaderMaterial.new(); sm2.shader = load("res://shaders/stone.gdshader"); sm2.set_shader_parameter("mode", 2)
			sm2.set_shader_parameter("base_color", Color(0.38, 0.36, 0.33))
			(_vis as MeshInstance3D).material_override = sm2
			_vis.position = Vector3(0, 0.7, 0)
			add_child(_vis)
			var glyphs := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.75, 0.9); glyphs.mesh = q
			var gm := ShaderMaterial.new(); gm.shader = load("res://shaders/rune.gdshader")
			gm.set_shader_parameter("color", Color(0.9, 0.7, 0.35)); gm.set_shader_parameter("intensity", 0.9); gm.set_shader_parameter("spin", 0.0)
			glyphs.material_override = gm
			glyphs.position = Vector3(0, 0.8, -0.13); glyphs.rotation.y = PI
			add_child(glyphs)
			var sb2 := StaticBody3D.new(); var cs2 := CollisionShape3D.new(); var bs2 := BoxShape3D.new(); bs2.size = b2.size
			cs2.shape = bs2; cs2.position = _vis.position; sb2.add_child(cs2); add_child(sb2)
			once = false
		"shrine":
			_rune = MeshInstance3D.new(); var pq := PlaneMesh.new(); pq.size = Vector2(2.6, 2.6); _rune.mesh = pq
			var rm := ShaderMaterial.new(); rm.shader = load("res://shaders/rune.gdshader")
			rm.set_shader_parameter("color", Color(0.35, 0.6, 1.0)); rm.set_shader_parameter("intensity", 0.5)
			_rune.material_override = rm; _rune.position = Vector3(0, 0.03, 0)
			add_child(_rune)
			var ped := MeshInstance3D.new(); var pc := CylinderMesh.new(); pc.top_radius = 0.25; pc.bottom_radius = 0.35; pc.height = 1.0
			ped.mesh = pc; var pmat := ShaderMaterial.new(); pmat.shader = load("res://shaders/stone.gdshader"); pmat.set_shader_parameter("mode", 0)
			ped.material_override = pmat; ped.position = Vector3(0, 0.5, 0); add_child(ped)
			var crystal := MeshInstance3D.new(); var cp := PrismMesh.new(); cp.size = Vector3(0.22, 0.4, 0.22); crystal.mesh = cp
			var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.5, 0.8, 1.0); cmat.emission_enabled = true
			cmat.emission = Color(0.35, 0.65, 1.0); cmat.emission_energy_multiplier = 4.0
			crystal.material_override = cmat; crystal.position = Vector3(0, 1.25, 0); add_child(crystal)
			_vis = crystal
			_light = OmniLight3D.new(); _light.light_color = Color(0.45, 0.7, 1.0); _light.light_energy = 1.2; _light.omni_range = 6.0
			_light.position = Vector3(0, 1.4, 0); add_child(_light)
			var sb3 := StaticBody3D.new(); var cs3 := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.35; cy.height = 1.0
			cs3.shape = cy; cs3.position = Vector3(0, 0.5, 0); sb3.add_child(cs3); add_child(sb3)
			once = false
		"altar":
			var ped2 := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(1.4, 1.0, 1.0); ped2.mesh = bx
			var pm2 := ShaderMaterial.new(); pm2.shader = load("res://shaders/stone.gdshader"); pm2.set_shader_parameter("mode", 0)
			pm2.set_shader_parameter("base_color", Color(0.3, 0.3, 0.34))
			ped2.material_override = pm2; ped2.position = Vector3(0, 0.5, 0); add_child(ped2)
			var heart := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.22; hs.height = 0.5; heart.mesh = hs
			var hm := StandardMaterial3D.new(); hm.albedo_color = Color(1, 0.7, 0.3); hm.emission_enabled = true
			hm.emission = Color(1.0, 0.55, 0.2); hm.emission_energy_multiplier = 6.0
			heart.material_override = hm; heart.position = Vector3(0, 1.45, 0); add_child(heart)
			_vis = heart
			_light = OmniLight3D.new(); _light.light_color = Color(1.0, 0.65, 0.3); _light.light_energy = 3.0; _light.omni_range = 9.0
			_light.shadow_enabled = true
			_light.position = Vector3(0, 1.6, 0); add_child(_light)
			Props.fire_particles(heart, 0.7, Color(1.0, 0.6, 0.3), true)
			var sb4 := StaticBody3D.new(); var cs4 := CollisionShape3D.new(); var bs4 := BoxShape3D.new(); bs4.size = bx.size
			cs4.shape = bs4; cs4.position = Vector3(0, 0.5, 0); sb4.add_child(cs4); add_child(sb4)

func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.metallic = 0.8; m.roughness = 0.4
	return m

func _process(delta: float) -> void:
	if kind == "shrine" and _vis:
		_vis.rotation.y += delta
		_vis.position.y = 1.25 + sin(Time.get_ticks_msec() * 0.002) * 0.06
	elif kind == "altar" and _vis and not spent:
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
		_vis.scale = Vector3(s, s, s)

func get_prompt() -> String:
	match kind:
		"chest": return "[E] Open chest"
		"lever": return "[E] Pull lever"
		"inscription": return "[E] Read: %s" % title
		"shrine": return "[E] Rest at the shrine (save & heal)"
		"altar": return "[E] Claim the Heart of the Vault"
	return "[E] Use"

func can_interact() -> bool:
	if kind == "altar" and not Game.flags.get("warden_dead", false):
		return false
	return not (once and spent)

func interact(by: Node) -> void:
	if not can_interact():
		return
	match kind:
		"chest":
			Sfx.play_at("chest", global_position, 0.0)
			var i := 0
			for l in loot:
				var k: String = l.get("kind", "gold")
				var pos := global_position + Vector3(0, 1.0, 0) + (-global_transform.basis.z) * 0.6
				Pickup.spawn(pos + Vector3(i * 0.15, 0, 0), "item" if k == "item" else k, int(l.get("amount", 1)), String(l.get("id", "")))
				i += 1
			FX.burst(global_position + Vector3(0, 0.9, 0), Color(1, 0.85, 0.4), 30, 3.0, 0.18, 0.9, 0.5)
			FX.flash_light(global_position + Vector3(0, 1.2, 0), Color(1, 0.8, 0.4), 4.0, 6.0, 0.8)
		"lever":
			Sfx.play_at("lever", global_position, 0.0)
		"inscription":
			var sc := get_tree().current_scene
			if sc.has_method("show_lore"):
				sc.show_lore(title, text)
		"shrine":
			Sfx.play("levelup", -8.0, 0.0)
			Game.hp = Game.max_hp(); Game.mana = Game.max_mana(); Game.stamina = Game.max_stamina()
			Game.stats_changed.emit()
			var fwd := spawn_yaw
			Game.checkpoint_name = ""  # force message
			Game.set_checkpoint(global_position + Vector3(0, 0.1, 0) + Vector3(sin(fwd), 0, cos(fwd)) * -1.8, fwd, title)
			Game.say("You feel restored.", Color(0.6, 0.85, 1.0))
			FX.burst(global_position + Vector3(0, 1.2, 0), Color(0.4, 0.7, 1.0), 40, 3.0, 0.2, 1.2, 1.0)
		"altar":
			Sfx.play("victory", -2.0, 0.0)
			if _vis:
				var tw := create_tween()
				tw.tween_property(_vis, "position:y", 3.0, 1.5).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(_vis, "scale", Vector3.ONE * 0.1, 1.5)
			FX.burst(global_position + Vector3(0, 1.6, 0), Color(1.0, 0.7, 0.3), 80, 6.0, 0.3, 2.0, 0.5)
			Game.add_item("heart_vault", false)
	_apply_spent(false)
	used.emit(by)

func _apply_spent(silent: bool) -> void:
	if not once:
		return
	spent = true
	if uid != "":
		Game.flags[uid] = true
	match kind:
		"chest":
			if _lid:
				var tw := create_tween()
				tw.tween_property(_lid, "rotation:x", -1.6, 0.0 if silent else 0.6)
			if _light:
				_light.light_energy = 0.0
		"lever":
			if _lid:
				var tw2 := create_tween()
				tw2.tween_property(_lid, "rotation:x", 0.7, 0.0 if silent else 0.35)
