extends Node3D
class_name Interactable
## E-to-use world objects: chest, lever, inscription, shrine (checkpoint), altar.

signal used(by: Node)

var kind := "chest"
var uid := ""
var title := ""
var text := ""
var loot: Array = []        # [{roll:"big"}, {kind:"gold", amount:30}, {kind:"item", id:"vault_blade"}, {kind:"mana", amount:1}]
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
			var golden := false
			for l in loot:
				if l.get("roll", "") in ["big", "boss", "skin", "supply", "wild"] or l.get("id", "") in ["vault_blade", "amulet_deep"]:
					golden = true
			_vis = Props.place(self, "chest_gold" if golden else "chest", Vector3.ZERO, 0.0, 1.0, true)
			for n in _vis.find_children("*", "Node3D", true, false):
				if String(n.name).to_lower().contains("lid") or String(n.name).to_lower().contains("top"):
					_lid = n
			_light = OmniLight3D.new(); _light.light_color = Color(1.0, 0.8, 0.35); _light.light_energy = 0.6; _light.omni_range = 3.0
			_light.position = Vector3(0, 0.8, 0)
			add_child(_light)
		"lever":
			_build_lever()
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
			# a dim rune ring on top until the Heart appears
			var rune := MeshInstance3D.new(); var rq := QuadMesh.new(); rq.size = Vector2(1.3, 1.3); rune.mesh = rq
			var rmat := ShaderMaterial.new(); rmat.shader = load("res://shaders/rune.gdshader")
			rmat.set_shader_parameter("color", Color(1.0, 0.7, 0.3)); rmat.set_shader_parameter("intensity", 0.6)
			rune.material_override = rmat; rune.rotation.x = -PI / 2; rune.position = Vector3(0, 1.01, 0); add_child(rune)
			_build_heart()
			var sb4 := StaticBody3D.new(); var cs4 := CollisionShape3D.new(); var bs4 := BoxShape3D.new(); bs4.size = bx.size
			cs4.shape = bs4; cs4.position = Vector3(0, 0.5, 0); sb4.add_child(cs4); add_child(sb4)

## The Heart of the Vault: a big faceted amber crystal that floats above the
## altar inside three spinning golden rings, with runes circling it. Hidden
## until the Warden falls; then a pillar of light brings it down (reveal()).
var _crystal: Node3D
var _rings: Array[Node3D] = []
var _orbit: Node3D
func _build_heart() -> void:
	_vis = Node3D.new(); _vis.position = Vector3(0, 2.1, 0); add_child(_vis)
	_crystal = Node3D.new(); _vis.add_child(_crystal)
	var amber := StandardMaterial3D.new(); amber.albedo_color = Color(1.0, 0.62, 0.22, 0.85)
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; amber.metallic = 0.3; amber.roughness = 0.05
	amber.emission_enabled = true; amber.emission = Color(1.0, 0.5, 0.15); amber.emission_energy_multiplier = 2.2
	amber.rim_enabled = true; amber.rim = 0.8
	for up in [1.0, -1.0]:
		var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.42
		cm.height = 0.75 if up > 0 else 0.55; cm.radial_segments = 6; cm.rings = 1
		cone.mesh = cm; cone.material_override = amber
		cone.position.y = cm.height * 0.5 * up; cone.rotation.x = 0.0 if up > 0 else PI
		_crystal.add_child(cone)
	var core := MeshInstance3D.new(); var cs := SphereMesh.new(); cs.radius = 0.16; cs.height = 0.32; core.mesh = cs
	core.material_override = FX.beam_material(Color(1.0, 0.85, 0.5), 3.0, 1.0)
	_crystal.add_child(core)
	var gold := _metal(Color(1.0, 0.78, 0.3))
	gold.emission_enabled = true; gold.emission = Color(1.0, 0.6, 0.2); gold.emission_energy_multiplier = 0.6
	for i in 3:
		var r := Node3D.new(); _vis.add_child(r)
		r.rotation = [Vector3(0.0, 0.0, 0.0), Vector3(PI / 2, 0.0, 0.0), Vector3(0.0, 0.0, PI / 2)][i]
		r.rotate_object_local(Vector3.RIGHT, 0.35 * (i + 1))
		var ring := MeshInstance3D.new(); var tm := TorusMesh.new()
		var rr := 0.75 + i * 0.16
		tm.inner_radius = rr - 0.035; tm.outer_radius = rr + 0.035; tm.rings = 48; tm.ring_segments = 8
		ring.mesh = tm; ring.material_override = gold; r.add_child(ring)
		_rings.append(r)
	_orbit = Node3D.new(); _vis.add_child(_orbit)
	for k in 6:
		var a := k * TAU / 6.0
		var g := MeshInstance3D.new(); var gq := QuadMesh.new(); gq.size = Vector2(0.32, 0.32); g.mesh = gq
		var gm := ShaderMaterial.new(); gm.shader = load("res://shaders/rune.gdshader")
		gm.set_shader_parameter("color", Color(1.0, 0.8, 0.4)); gm.set_shader_parameter("intensity", 1.6)
		g.material_override = gm; g.position = Vector3(cos(a) * 1.35, sin(a * 2.0) * 0.2, sin(a) * 1.35)
		g.rotation.y = -a + PI / 2
		_orbit.add_child(g)
	_light = OmniLight3D.new(); _light.light_color = Color(1.0, 0.65, 0.3); _light.light_energy = 4.0; _light.omni_range = 12.0
	_light.shadow_enabled = true
	_vis.add_child(_light)
	Props.fire_particles(_crystal, 0.5, Color(1.0, 0.7, 0.35), true, false)      # (the Heart's glow: not a fire)
	_vis.visible = Game.flags.get("warden_dead", false) and not Game.flags.get(uid, false)

## The Warden has fallen: a pillar of light, and the Heart descends onto the altar.
func reveal() -> void:
	if _vis == null:
		return
	_vis.visible = true
	_vis.position.y = 7.0
	_vis.scale = Vector3.ONE * 0.1
	var beam := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.9; bm.bottom_radius = 0.9; bm.height = 14.0
	bm.cap_top = false; bm.cap_bottom = false
	beam.mesh = bm; beam.material_override = FX.beam_material(Color(1.0, 0.8, 0.45), 1.4, 0.0)
	beam.position.y = 7.0; add_child(beam)
	var bmat := beam.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_property(bmat, "albedo_color:a", 0.45, 0.6)
	tw.parallel().tween_property(_vis, "position:y", 2.1, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_vis, "scale", Vector3.ONE, 2.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Sfx.play_at("victory", global_position, -4.0, 0.0)
		FX.burst(global_position + Vector3(0, 2.1, 0), Color(1.0, 0.75, 0.35), 90, 6.0, 0.25, 1.4, 0.0)
		FX.flash_light(global_position + Vector3(0, 2.2, 0), Color(1.0, 0.7, 0.35), 10.0, 14.0, 0.8))
	tw.tween_property(bmat, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(beam.queue_free)
	Sfx.play_at("portal", global_position, -2.0, 0.0)

## An ornate golden lever on a carved golden wall plate (Jason, Nov 24: "it could
## be all gold with a little glow to it... re-craft those levers so they look more
## ornate... and they glow a bit"). A framed plate with rivets, a glowing rune in a
## ring at the top, a slotted track, a golden arm with a collar and a glowing gem
## knob that pulses gently. Pulled, the gem, the rune and the light turn green.
var _gem_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _rune_mat: ShaderMaterial
const LEVER_AMBER := Color(1.0, 0.68, 0.22)
const LEVER_GREEN := Color(0.4, 1.0, 0.45)
const LEVER_UP := -0.9                  # the arm's tilt: up and out of the plate...
const LEVER_DOWN := -2.25               # ...pulled: down and out
func _build_lever() -> void:
	var gold := _metal(Color(1.0, 0.78, 0.3))
	gold.metallic = 0.95; gold.roughness = 0.28
	gold.emission_enabled = true; gold.emission = Color(1.0, 0.72, 0.3); gold.emission_energy_multiplier = 0.25
	var dark := _metal(Color(0.8, 0.56, 0.2))          # (still gold, a shade deeper, so the frame and post read)
	dark.metallic = 0.85; dark.roughness = 0.35
	dark.emission_enabled = true; dark.emission = Color(0.75, 0.48, 0.14); dark.emission_energy_multiplier = 0.15
	var groove := StandardMaterial3D.new(); groove.albedo_color = Color(0.08, 0.06, 0.04); groove.roughness = 0.9
	var c := Vector3(0, 1.15, 0)
	# (built facing -z, then turned round: every lever in the game faces the way
	# it's placed, +z, where you stand to pull it. The old one faced the wall and
	# you saw its back: "that weird handle with a gold backpiece".)
	var base := Node3D.new(); base.rotation.y = PI; add_child(base)
	# it stands on its own: a gold-capped post on a stone foot
	var foot := MeshInstance3D.new(); var ftm := BoxMesh.new(); ftm.size = Vector3(0.56, 0.14, 0.42); foot.mesh = ftm
	foot.material_override = dark; foot.position = Vector3(0, 0.07, -0.06); add_child(foot)
	var post := MeshInstance3D.new(); var ptm := BoxMesh.new(); ptm.size = Vector3(0.24, 0.6, 0.18); post.mesh = ptm
	post.material_override = dark; post.position = Vector3(0, 0.44, -0.1); add_child(post)
	# the plate: a dark gold frame round a bright gold face, with a rivet in each corner
	var frame := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = Vector3(0.78, 1.06, 0.07); frame.mesh = fb
	frame.material_override = dark; frame.position = c + Vector3(0, 0.05, 0.1); base.add_child(frame)
	var face := MeshInstance3D.new(); var fcb := BoxMesh.new(); fcb.size = Vector3(0.64, 0.92, 0.06); face.mesh = fcb
	face.material_override = gold; face.position = c + Vector3(0, 0.05, 0.065); base.add_child(face)
	for corner in [Vector2(-0.32, 0.48), Vector2(0.32, 0.48), Vector2(-0.32, -0.38), Vector2(0.32, -0.38)]:
		var rv := MeshInstance3D.new(); var rs := SphereMesh.new(); rs.radius = 0.035; rs.height = 0.07; rs.radial_segments = 8; rs.rings = 4
		rv.mesh = rs; rv.material_override = gold; rv.position = c + Vector3(corner.x, corner.y, 0.03); base.add_child(rv)
	# a crest on top
	var crest := MeshInstance3D.new(); var cp := PrismMesh.new(); cp.size = Vector3(0.42, 0.16, 0.07); crest.mesh = cp
	crest.material_override = dark; crest.position = c + Vector3(0, 0.66, 0.1); base.add_child(crest)
	# the glowing rune in a golden ring, above the lever
	var ring := MeshInstance3D.new(); var rt := TorusMesh.new(); rt.inner_radius = 0.13; rt.outer_radius = 0.16; rt.rings = 24; rt.ring_segments = 6
	ring.mesh = rt; ring.material_override = gold; ring.rotation.x = PI * 0.5; ring.position = c + Vector3(0, 0.3, 0.02); base.add_child(ring)
	var rune := MeshInstance3D.new(); var rq := QuadMesh.new(); rq.size = Vector2(0.26, 0.26); rune.mesh = rq
	_rune_mat = ShaderMaterial.new(); _rune_mat.shader = load("res://shaders/rune.gdshader")
	_rune_mat.set_shader_parameter("color", LEVER_AMBER); _rune_mat.set_shader_parameter("intensity", 1.4)
	rune.material_override = _rune_mat; rune.rotation.y = PI; rune.position = c + Vector3(0, 0.3, 0.025); base.add_child(rune)
	# the slot the lever swings along
	var slot := MeshInstance3D.new(); var sbm := BoxMesh.new(); sbm.size = Vector3(0.08, 0.58, 0.02); slot.mesh = sbm
	slot.material_override = groove; slot.position = c + Vector3(0, -0.06, 0.03); base.add_child(slot)
	# the pivot: a gold hub with a ring
	var hub := MeshInstance3D.new(); var hc := CylinderMesh.new(); hc.top_radius = 0.09; hc.bottom_radius = 0.09; hc.height = 0.1
	hub.mesh = hc; hub.material_override = gold; hub.rotation.x = PI * 0.5; hub.position = c + Vector3(0, -0.1, -0.02); base.add_child(hub)
	var hr := MeshInstance3D.new(); var hrt := TorusMesh.new(); hrt.inner_radius = 0.1; hrt.outer_radius = 0.13; hrt.rings = 20; hrt.ring_segments = 6
	hr.mesh = hrt; hr.material_override = dark; hr.rotation.x = PI * 0.5; hr.position = c + Vector3(0, -0.1, 0.0); base.add_child(hr)
	# the arm, with a collar half way and a glowing gem for a knob
	_lid = Node3D.new(); _lid.position = c + Vector3(0, -0.1, -0.08); base.add_child(_lid)
	var arm := MeshInstance3D.new(); var am := CylinderMesh.new(); am.top_radius = 0.035; am.bottom_radius = 0.05; am.height = 0.6
	arm.mesh = am; arm.material_override = gold; arm.position = Vector3(0, 0.3, 0); _lid.add_child(arm)
	var collar := MeshInstance3D.new(); var ct := TorusMesh.new(); ct.inner_radius = 0.04; ct.outer_radius = 0.07; ct.rings = 16; ct.ring_segments = 6
	collar.mesh = ct; collar.material_override = dark; collar.position = Vector3(0, 0.32, 0); _lid.add_child(collar)
	var cup := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.075; cc.bottom_radius = 0.04; cc.height = 0.07
	cup.mesh = cc; cup.material_override = gold; cup.position = Vector3(0, 0.6, 0); _lid.add_child(cup)
	var gem := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.075; gs.height = 0.15; gs.radial_segments = 12; gs.rings = 6
	gem.mesh = gs
	_gem_mat = StandardMaterial3D.new(); _gem_mat.albedo_color = LEVER_AMBER; _gem_mat.metallic = 0.2; _gem_mat.roughness = 0.1
	_gem_mat.emission_enabled = true; _gem_mat.emission = LEVER_AMBER; _gem_mat.emission_energy_multiplier = 2.5
	gem.material_override = _gem_mat; gem.position = Vector3(0, 0.67, 0); _lid.add_child(gem)
	var halo := MeshInstance3D.new(); var hq := QuadMesh.new(); hq.size = Vector2(0.4, 0.4); halo.mesh = hq
	_halo_mat = StandardMaterial3D.new(); _halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_texture = FX.soft_texture(); _halo_mat.albedo_color = Color(LEVER_AMBER.r, LEVER_AMBER.g, LEVER_AMBER.b, 0.55)
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = _halo_mat; halo.position = Vector3(0, 0.67, 0); halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lid.add_child(halo)
	_lid.rotation.x = LEVER_UP          # sticking out of the plate, up and towards you
	_light = OmniLight3D.new(); _light.light_color = LEVER_AMBER; _light.light_energy = 0.85; _light.omni_range = 3.4
	_light.position = c + Vector3(0, 0.3, -0.85); base.add_child(_light)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.78, 1.06, 0.3)
	cs.shape = bs; cs.position = c + Vector3(0, 0.05, 0.0); sb.add_child(cs); base.add_child(sb)

## A pulled lever glows green.
func _lever_done(silent: bool) -> void:
	if _gem_mat == null:
		return
	_gem_mat.albedo_color = LEVER_GREEN; _gem_mat.emission = LEVER_GREEN
	_halo_mat.albedo_color = Color(LEVER_GREEN.r, LEVER_GREEN.g, LEVER_GREEN.b, 0.5)
	_rune_mat.set_shader_parameter("color", LEVER_GREEN)
	if _light:
		_light.light_color = LEVER_GREEN
	if not silent and _lid:
		var at := _lid.global_position + _lid.global_transform.basis.y * 0.67
		FX.burst(at, LEVER_GREEN, 26, 2.6, 0.1, 0.7, -1.0)
		FX.flash_light(at, LEVER_GREEN, 3.0, 4.0, 0.4)

func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.metallic = 0.8; m.roughness = 0.4
	return m

func _process(delta: float) -> void:
	if kind == "lever" and _gem_mat and not spent:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		_gem_mat.emission_energy_multiplier = 1.8 + pulse * 1.6
		_halo_mat.albedo_color.a = 0.25 + pulse * 0.3
		return
	if kind == "shrine" and _vis:
		_vis.rotation.y += delta
		_vis.position.y = 1.25 + sin(Time.get_ticks_msec() * 0.002) * 0.06
	elif kind == "altar" and _vis and _vis.visible and not spent:
		var tt := Time.get_ticks_msec() * 0.001
		_crystal.rotation.y += delta * 0.9
		_crystal.position.y = sin(tt * 1.6) * 0.08
		for i in _rings.size():
			_rings[i].rotate_object_local(Vector3.UP, delta * (1.4 + i * 0.6) * (1.0 if i % 2 == 0 else -1.0))
		_orbit.rotation.y -= delta * 0.6

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
			var rolled: Array = []
			for l in loot:
				if l.has("roll"):
					rolled.append_array(Loot.roll_chest(l.roll, int(l.get("ilvl", Loot.area_level(global_position.z)))))
				else:
					rolled.append(l)
			var best := -1
			for l in rolled:
				if l.get("kind", "") == "item":
					best = maxi(best, int(Game.item(l.id).get("rarity", 0)))
			var burst_c := Loot.rarity_color(best) if best >= 1 else Color(1, 0.85, 0.4)
			var i := 0
			for l in rolled:
				var k: String = l.get("kind", "gold")
				var toward := (by as Node3D).global_position - global_position if by is Node3D else Vector3.BACK
				toward.y = 0
				var pos := global_position + Vector3(0, 1.0, 0) + toward.normalized() * 0.9
				Pickup.spawn(pos + Vector3(i * 0.15, 0, 0), k, int(l.get("amount", 1)), String(l.get("id", "")))
				i += 1
			FX.burst(global_position + Vector3(0, 0.9, 0), burst_c, 30 + 15 * maxi(best, 0), 3.0, 0.18, 0.9, 0.5)
			FX.flash_light(global_position + Vector3(0, 1.2, 0), burst_c, 4.0 + 1.5 * maxi(best, 0), 6.0, 0.8)
			if best >= 3:
				Game.say("%s loot!" % Loot.RARITY_NAMES[best].to_upper(), burst_c)
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
				# the rings whirl, the crystal soars up and bursts into light
				var tw := create_tween()
				tw.tween_method(func(v: float) -> void:
					for r in _rings:
						r.rotate_object_local(Vector3.UP, v * 0.05), 1.0, 12.0, 1.2)
				tw.parallel().tween_property(_vis, "position:y", 3.4, 1.2).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_vis, "scale", Vector3.ONE * 0.05, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_callback(func() -> void:
					_vis.visible = false
					FX.flash_light(global_position + Vector3(0, 3.0, 0), Color(1.0, 0.8, 0.4), 14.0, 18.0, 0.9)
					FX.burst(global_position + Vector3(0, 3.2, 0), Color(1.0, 0.85, 0.5), 140, 8.0, 0.3, 1.6, -1.0)
					FX.screen_flash(Color(1.0, 0.9, 0.7), 0.6, 0.8))
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
				tw2.tween_property(_lid, "rotation:x", LEVER_DOWN, 0.0 if silent else 0.35)
			_lever_done(silent)
		"altar":
			if silent and _vis:
				_vis.visible = false
