extends Node3D
class_name Humanoid
## Procedurally built and procedurally animated humanoid.
## Used for the player (human), skeletons, the revenant and the Warden.
## Character faces -Z. Right side is +X.
##
## The controlling script writes the animation inputs below each frame
## (move_speed, grounded, attack_t, ...) and the body animates itself.

# --- animation inputs -------------------------------------------------------
var move_speed := 0.0        # metres per second along the ground
var grounded := true
var attack_t := -1.0         # 0..1 progress of the current swing, -1 = none
var attack_kind := 0         # 0 overhead diagonal, 1 horizontal, 2 thrust / slam
var blocking := false
var cast_t := -1.0
var dodge_t := -1.0
var hurt_t := -1.0
var dead := false
var alive_time := 0.0

var style := "human"
var cfg := {}

# --- pivots -----------------------------------------------------------------
var hips: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var sh_l: Node3D; var sh_r: Node3D
var el_l: Node3D; var el_r: Node3D
var hand_l: Node3D; var hand_r: Node3D
var hip_l: Node3D; var hip_r: Node3D
var kn_l: Node3D; var kn_r: Node3D
var weapon_root: Node3D
var shield_root: Node3D
var head_parts: Array[Node3D] = []   # hidden in first person
var all_meshes: Array[MeshInstance3D] = []
var flash_mat: StandardMaterial3D
var weapon_tip: Node3D

var _phase := 0.0
var _hip_h := 0.95
var _mats := {}

func setup(c: Dictionary) -> void:
	cfg = c
	style = c.get("style", "human")
	for ch in get_children():
		ch.queue_free()
	head_parts.clear(); all_meshes.clear()
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	flash_mat.render_priority = 1
	_build()
	scale = Vector3.ONE * float(c.get("scale", 1.0))

# ---------------------------------------------------------------------------
func mat(color: Color, metal := 0.0, rough := 0.8, emission := Color.BLACK, e_energy := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), metal, rough, emission.to_html(), e_energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if e_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = e_energy
	_mats[key] = m
	return m

func mk(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.material_overlay = flash_mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	all_meshes.append(mi)
	return mi

func pivot(parent: Node3D, pos: Vector3, n := "") -> Node3D:
	var p := Node3D.new()
	p.position = pos
	if n != "":
		p.name = n
	parent.add_child(p)
	return p

func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 12; c.rings = 4
	return c
func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0
	s.radial_segments = 16; s.rings = 8
	return s
func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z)
	return b
func cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r if r2 < 0 else r2; c.height = h
	c.radial_segments = 12
	return c

# ---------------------------------------------------------------------------
func _build() -> void:
	match style:
		"skeleton": _build_skeleton()
		"warden": _build_warden()
		_: _build_human()

func _limbs(shoulder_w: float, upper: float, fore: float, thigh: float, shin: float,
		arm_r: float, leg_r: float, m_upper: Material, m_fore: Material, m_hand: Material,
		m_thigh: Material, m_shin: Material, m_foot: Material) -> void:
	# arms
	for side in [-1, 1]:
		var sh := pivot(spine, Vector3(shoulder_w * side, 0.50, 0.0))
		mk(sh, capsule(arm_r, upper + arm_r), m_upper, Vector3(0, -upper * 0.5, 0))
		var el := pivot(sh, Vector3(0, -upper, 0))
		mk(el, capsule(arm_r * 0.85, fore + arm_r), m_fore, Vector3(0, -fore * 0.5, 0))
		var hd := pivot(el, Vector3(0, -fore, 0))
		mk(hd, sphere(arm_r * 1.05), m_hand, Vector3(0, -0.03, 0))
		if side < 0:
			sh_l = sh; el_l = el; hand_l = hd
		else:
			sh_r = sh; el_r = el; hand_r = hd
	# legs
	for side in [-1, 1]:
		var hp := pivot(hips, Vector3(0.105 * side, 0.0, 0.0))
		mk(hp, capsule(leg_r, thigh + leg_r), m_thigh, Vector3(0, -thigh * 0.5, 0))
		var kn := pivot(hp, Vector3(0, -thigh, 0))
		mk(kn, capsule(leg_r * 0.8, shin + leg_r), m_shin, Vector3(0, -shin * 0.5, 0))
		mk(kn, box(leg_r * 1.7, 0.08, 0.26), m_foot, Vector3(0, -shin - 0.01, -0.05))
		if side < 0:
			hip_l = hp; kn_l = kn
		else:
			hip_r = hp; kn_r = kn

func _build_human() -> void:
	var female: bool = cfg.get("sex", "male") == "female"
	var skin := mat(cfg.get("skin_color", Color(0.87, 0.67, 0.53)), 0.0, 0.65)
	var tunic := mat(cfg.get("tunic", Color(0.3, 0.22, 0.14)), 0.0, 0.9)
	var pants := mat(cfg.get("pants", Color(0.2, 0.17, 0.14)), 0.0, 0.9)
	var trim := mat(cfg.get("trim", Color(0.6, 0.5, 0.3)), 0.4, 0.5)
	var boots := mat(Color(0.16, 0.10, 0.07), 0.0, 0.7)
	var hair := mat(cfg.get("hair_color", Color(0.2, 0.12, 0.08)), 0.0, 0.75)
	var armor_id: String = cfg.get("armor", "traveler_garb")
	var armored: bool = cfg.get("armored_enemy", false)
	var metal_col: Color = Game.ITEMS.get(armor_id, {}).get("color", Color(0.6, 0.6, 0.65))
	if armored:
		metal_col = cfg.get("metal", Color(0.22, 0.22, 0.25))
	var metal := mat(metal_col, 0.85, 0.35)
	var chain := mat(metal_col.darkened(0.1), 0.75, 0.55)

	_hip_h = 0.95 if not female else 0.92
	hips = pivot(self, Vector3(0, _hip_h, 0), "Hips")
	spine = pivot(hips, Vector3.ZERO, "Spine")
	var hip_w := 0.17 if female else 0.15
	var chest_w := 0.155 if female else 0.185
	mk(spine, capsule(hip_w, 0.36), pants, Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.72))
	var body_m := tunic
	if armor_id == "chainmail" or armored:
		body_m = chain
	mk(spine, capsule(chest_w * 0.92, 0.42), body_m, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1, 0.68))
	mk(spine, capsule(chest_w, 0.40), body_m, Vector3(0, 0.40, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.7))
	mk(spine, box(chest_w * 2.0, 0.06, 0.25), trim, Vector3(0, 0.08, 0))  # belt
	mk(spine, box(0.07, 0.05, 0.02), mat(Color(0.85, 0.7, 0.3), 0.9, 0.3), Vector3(0, 0.08, -0.13))
	if armor_id == "warden_plate" or armored:
		mk(spine, box(chest_w * 2.1, 0.32, 0.26), metal, Vector3(0, 0.40, -0.02))
		for s in [-1, 1]:
			mk(spine, sphere(0.1), metal, Vector3((chest_w + 0.06) * s, 0.52, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.1))
	if female and armor_id == "traveler_garb":
		mk(spine, capsule(0.19, 0.2), tunic, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1.1, 1, 0.85))  # skirt panel
	neck = pivot(spine, Vector3(0, 0.56, 0), "Neck")
	var nk := mk(neck, cyl(0.05, 0.1), skin, Vector3(0, 0.03, 0))
	head = pivot(neck, Vector3(0, 0.08, 0), "Head")
	var hd := mk(head, sphere(0.115), skin, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(0.88, 1.05, 1.0))
	var eye_m := mat(Color(0.05, 0.05, 0.06))
	var e1 := mk(head, sphere(0.014), eye_m, Vector3(-0.038, 0.115, -0.098))
	var e2 := mk(head, sphere(0.014), eye_m, Vector3(0.038, 0.115, -0.098))
	var nose := mk(head, box(0.025, 0.04, 0.03), skin, Vector3(0, 0.085, -0.11))
	head_parts.append_array([nk, hd, e1, e2, nose])
	if armored:
		var helm := mk(head, sphere(0.135), metal, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 1.1, 1.05))
		var slit := mk(head, box(0.12, 0.02, 0.02), mat(Color(1, 0.3, 0.1), 0, 1, Color(1, 0.35, 0.1), 6.0), Vector3(0, 0.12, -0.13))
		head_parts.append_array([helm, slit])
	else:
		_build_hair(hair, int(cfg.get("hair_style", 0)))

	var arm_m := tunic if armor_id == "traveler_garb" and not armored else chain
	var fore_m := skin if (not female and armor_id == "traveler_garb" and not armored) else arm_m
	_limbs(chest_w + 0.04, 0.29, 0.26, 0.45, 0.45, 0.052 if female else 0.058, 0.07 if female else 0.072,
		arm_m, fore_m, skin if not armored else metal, pants, pants, boots)
	if armor_id != "traveler_garb" or armored:
		for kn in [kn_l, kn_r]:
			mk(kn, capsule(0.065, 0.3), metal, Vector3(0, -0.2, -0.01))  # greaves
	_attach_weapon(cfg.get("weapon", "rusty_sword"))
	if cfg.get("shield", true):
		_attach_shield(armored)

func _build_hair(hair: Material, s: int) -> void:
	var parts: Array[Node3D] = []
	match s:
		0:  # short
			parts.append(mk(head, sphere(0.125), hair, Vector3(0, 0.14, 0.012), Vector3.ZERO, Vector3(0.93, 0.78, 1.02)))
		1:  # long
			parts.append(mk(head, sphere(0.127), hair, Vector3(0, 0.14, 0.01), Vector3.ZERO, Vector3(0.95, 0.8, 1.04)))
			parts.append(mk(head, box(0.23, 0.30, 0.09), hair, Vector3(0, 0.0, 0.075)))
			for sd in [-1, 1]:
				parts.append(mk(head, box(0.05, 0.22, 0.09), hair, Vector3(0.095 * sd, 0.04, 0.02)))
		2:  # ponytail
			parts.append(mk(head, sphere(0.125), hair, Vector3(0, 0.14, 0.012), Vector3.ZERO, Vector3(0.93, 0.8, 1.02)))
			parts.append(mk(head, capsule(0.04, 0.26), hair, Vector3(0, 0.05, 0.15), Vector3(-0.5, 0, 0)))
		_:  # shaved: a thin stubble cap
			parts.append(mk(head, sphere(0.117), mat((hair as StandardMaterial3D).albedo_color.lerp(Color(0.6, 0.45, 0.35), 0.5)), Vector3(0, 0.12, 0.008), Vector3.ZERO, Vector3(0.9, 0.82, 1.0)))
	head_parts.append_array(parts)

func _build_skeleton() -> void:
	var bone := mat(Color(0.82, 0.78, 0.66), 0.0, 0.7)
	var dark := mat(Color(0.32, 0.28, 0.22), 0.2, 0.8)
	var eye_c: Color = cfg.get("eye", Color(0.3, 0.8, 1.0))
	var eye := mat(eye_c, 0, 1, eye_c, 8.0)
	_hip_h = 0.95
	hips = pivot(self, Vector3(0, _hip_h, 0), "Hips")
	spine = pivot(hips, Vector3.ZERO, "Spine")
	mk(spine, box(0.28, 0.1, 0.14), bone, Vector3(0, 0.0, 0))              # pelvis
	mk(spine, cyl(0.025, 0.4), bone, Vector3(0, 0.22, 0.03))               # spine
	for i in 4:
		var y := 0.28 + i * 0.07
		mk(spine, box(0.30 - i * 0.012, 0.025, 0.17), bone, Vector3(0, y, 0.0))  # ribs
	mk(spine, box(0.40, 0.04, 0.08), bone, Vector3(0, 0.50, 0.02))         # collar
	mk(spine, box(0.22, 0.18, 0.02), dark, Vector3(0, 0.15, -0.09), Vector3(0.1, 0, 0))  # rag
	neck = pivot(spine, Vector3(0, 0.55, 0), "Neck")
	mk(neck, cyl(0.025, 0.1), bone, Vector3(0, 0.04, 0))
	head = pivot(neck, Vector3(0, 0.08, 0), "Head")
	mk(head, sphere(0.11), bone, Vector3(0, 0.11, 0), Vector3.ZERO, Vector3(0.9, 1.0, 1.05))
	mk(head, box(0.12, 0.05, 0.1), bone, Vector3(0, 0.02, -0.04))           # jaw
	mk(head, sphere(0.022), eye, Vector3(-0.04, 0.11, -0.095))
	mk(head, sphere(0.022), eye, Vector3(0.04, 0.11, -0.095))
	if cfg.get("helmet", false):
		mk(head, sphere(0.125), mat(Color(0.35, 0.3, 0.25), 0.7, 0.5), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1, 0.7, 1.05))
	_limbs(0.2, 0.28, 0.26, 0.44, 0.44, 0.025, 0.03, bone, bone, bone, bone, bone, bone)
	_attach_weapon(cfg.get("weapon", "rusty_sword"))
	if cfg.get("shield", false):
		_attach_shield(true)

func _build_warden() -> void:
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	stone.set_shader_parameter("mode", 2)
	stone.set_shader_parameter("base_color", Color(0.30, 0.31, 0.34))
	stone.set_shader_parameter("moss", 0.1)
	var rune_c := Color(0.25, 0.75, 1.0)
	var rune := mat(rune_c, 0, 1, rune_c, 5.0)
	var core := mat(Color(1, 0.7, 0.3), 0, 1, Color(1.0, 0.6, 0.25), 9.0)
	var iron := mat(Color(0.2, 0.21, 0.24), 0.8, 0.45)
	_hip_h = 1.0
	hips = pivot(self, Vector3(0, _hip_h, 0), "Hips")
	spine = pivot(hips, Vector3.ZERO, "Spine")
	mk(spine, box(0.55, 0.3, 0.38), stone, Vector3(0, 0.05, 0))
	mk(spine, box(0.75, 0.48, 0.5), stone, Vector3(0, 0.45, 0))
	mk(spine, box(0.8, 0.08, 0.52), iron, Vector3(0, 0.25, 0))
	mk(spine, sphere(0.11), core, Vector3(0, 0.45, -0.24))
	for i in 3:
		mk(spine, box(0.03, 0.4 - i * 0.1, 0.02), rune, Vector3(-0.22 + i * 0.22, 0.47, -0.262))
	var cl := OmniLight3D.new(); cl.light_color = Color(1, 0.6, 0.3); cl.light_energy = 2.0; cl.omni_range = 4.0
	cl.position = Vector3(0, 0.45, -0.5); spine.add_child(cl)
	neck = pivot(spine, Vector3(0, 0.72, 0), "Neck")
	head = pivot(neck, Vector3(0, 0.02, 0), "Head")
	mk(head, box(0.3, 0.26, 0.3), stone, Vector3(0, 0.12, -0.02))
	mk(head, box(0.22, 0.035, 0.02), rune, Vector3(0, 0.15, -0.175))
	mk(head, box(0.36, 0.06, 0.34), iron, Vector3(0, 0.26, -0.02))
	# arms: boulder shoulders, heavy forearms, huge fists
	for side in [-1, 1]:
		var sh := pivot(spine, Vector3(0.5 * side, 0.6, 0))
		mk(sh, sphere(0.2), stone, Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.1, 1, 1))
		mk(sh, box(0.22, 0.42, 0.22), stone, Vector3(0, -0.26, 0))
		var el := pivot(sh, Vector3(0, -0.48, 0))
		mk(el, box(0.26, 0.42, 0.26), stone, Vector3(0, -0.2, 0))
		mk(el, box(0.03, 0.3, 0.02), rune, Vector3(0, -0.2, -0.135))
		var hd := pivot(el, Vector3(0, -0.44, 0))
		mk(hd, box(0.32, 0.26, 0.32), stone, Vector3(0, -0.05, 0))
		mk(hd, box(0.34, 0.08, 0.34), iron, Vector3(0, 0.06, 0))
		if side < 0:
			sh_l = sh; el_l = el; hand_l = hd
		else:
			sh_r = sh; el_r = el; hand_r = hd
	for side in [-1, 1]:
		var hp := pivot(hips, Vector3(0.18 * side, -0.05, 0))
		mk(hp, box(0.24, 0.48, 0.26), stone, Vector3(0, -0.22, 0))
		var kn := pivot(hp, Vector3(0, -0.46, 0))
		mk(kn, box(0.22, 0.46, 0.24), stone, Vector3(0, -0.22, 0))
		mk(kn, box(0.28, 0.1, 0.4), iron, Vector3(0, -0.46, -0.05))
		if side < 0:
			hip_l = hp; kn_l = kn
		else:
			hip_r = hp; kn_r = kn
	weapon_tip = pivot(hand_r, Vector3(0, -0.2, 0))

func _attach_weapon(id: String) -> void:
	if weapon_root:
		weapon_root.queue_free()
	weapon_root = pivot(hand_r, Vector3(0, -0.03, 0), "Weapon")
	var it: Dictionary = Game.ITEMS.get(id, {})
	var col: Color = it.get("color", Color(0.7, 0.7, 0.75))
	var grip := mat(Color(0.25, 0.15, 0.08), 0.0, 0.8)
	var guard := mat(Color(0.65, 0.55, 0.3), 0.85, 0.35)
	if id == "maul":
		mk(weapon_root, cyl(0.03, 1.1), grip, Vector3(0, 0, -0.35), Vector3(PI / 2, 0, 0))
		mk(weapon_root, box(0.22, 0.22, 0.38), mat(Color(0.25, 0.25, 0.28), 0.8, 0.5), Vector3(0, 0, -0.9))
		weapon_tip = pivot(weapon_root, Vector3(0, 0, -0.9))
		return
	var length := 0.75
	var blade_m: Material = mat(col, 0.9, 0.25)
	if id == "knight_sword":
		length = 0.95
	elif id == "vault_blade":
		length = 1.0
		blade_m = mat(col, 0.6, 0.2, Color(0.3, 0.85, 1.0), 2.5)
	elif id == "rusty_sword":
		blade_m = mat(col, 0.5, 0.75)
	mk(weapon_root, cyl(0.02, 0.18), grip, Vector3(0, 0, 0.0), Vector3(PI / 2, 0, 0))
	mk(weapon_root, box(0.24 if length > 0.8 else 0.18, 0.03, 0.04), guard, Vector3(0, 0, -0.1))
	mk(weapon_root, box(0.055, 0.012, length), blade_m, Vector3(0, 0, -0.1 - length * 0.5))
	mk(weapon_root, sphere(0.03), guard, Vector3(0, 0, 0.1))
	weapon_tip = pivot(weapon_root, Vector3(0, 0, -0.1 - length))

func _attach_shield(dark: bool) -> void:
	shield_root = pivot(el_l, Vector3(-0.05, -0.16, 0), "Shield")
	var wood := mat(Color(0.35, 0.22, 0.12) if not dark else Color(0.2, 0.18, 0.16), 0.0, 0.85)
	var rim := mat(Color(0.55, 0.55, 0.58), 0.85, 0.4)
	mk(shield_root, cyl(0.25, 0.04), wood, Vector3.ZERO, Vector3(0, 0, PI / 2))
	mk(shield_root, cyl(0.06, 0.07), rim, Vector3(-0.01, 0, 0), Vector3(0, 0, PI / 2))
	var ring := TorusMesh.new(); ring.inner_radius = 0.23; ring.outer_radius = 0.265
	mk(shield_root, ring, rim, Vector3.ZERO, Vector3(0, 0, PI / 2))

func set_weapon(id: String) -> void:
	_attach_weapon(id)

func set_head_visible(v: bool) -> void:
	for p in head_parts:
		if is_instance_valid(p):
			p.visible = v

func flash(color := Color(1, 1, 1), strength := 0.8) -> void:
	flash_mat.albedo_color = Color(color.r, color.g, color.b, strength)
	var tw := create_tween()
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.22)

# ---------------------------------------------------------------------------
# Animation. Rotation sign conventions (character facing -Z):
#  arm/leg pivots hang down: +X swings the limb forward
#  spine / neck stand up:    -X leans forward
#  +Y yaws toward the character's left
func _process(delta: float) -> void:
	if hips == null:
		return
	alive_time += delta
	if dead:
		return
	var w := 1.0 - exp(-14.0 * delta)
	var ws := 1.0 - exp(-30.0 * delta)
	var spd := clampf(move_speed, 0.0, 9.0)
	var run := clampf((spd - 3.5) / 3.0, 0.0, 1.0)
	var amt := clampf(spd / 3.0, 0.0, 1.0)
	_phase += delta * (spd * 2.4 + 0.0) / maxf(scale.x, 0.4)
	var s := sin(_phase)
	var c := cos(_phase)
	var breath := sin(alive_time * 2.0) * 0.02

	# targets
	var t_hips_y := _hip_h + absf(c) * 0.04 * amt - 0.02 * amt
	var t_spine := Vector3(-0.06 * amt - 0.18 * run + breath, 0.0, 0.0)
	var t_neck := Vector3(0.05 * amt + 0.12 * run, 0.0, 0.0)
	var t_hip_l := Vector3(s * (0.55 + 0.35 * run) * amt, 0, 0)
	var t_hip_r := Vector3(-s * (0.55 + 0.35 * run) * amt, 0, 0)
	var t_kn_l := Vector3(-maxf(0.0, -c) * (0.8 + 0.6 * run) * amt - 0.05, 0, 0)
	var t_kn_r := Vector3(-maxf(0.0, c) * (0.8 + 0.6 * run) * amt - 0.05, 0, 0)
	var t_sh_l := Vector3(-s * (0.45 + 0.3 * run) * amt + 0.05, 0, -0.12)
	var t_sh_r := Vector3(s * (0.45 + 0.3 * run) * amt + 0.25, 0, 0.12)
	var t_el_l := Vector3(0.25 + 0.6 * run, 0, 0)
	var t_el_r := Vector3(0.45 + 0.6 * run, 0, 0)
	var t_wrist := Vector3(0.0, 0.0, 0.0)
	if style == "warden":
		t_sh_l.z = -0.25; t_sh_r.z = 0.25
		t_spine.x -= 0.12

	if not grounded:
		t_hip_l = Vector3(0.5, 0, 0); t_hip_r = Vector3(-0.1, 0, 0)
		t_kn_l = Vector3(-0.9, 0, 0); t_kn_r = Vector3(-0.4, 0, 0)
		t_sh_l = Vector3(0.6, 0, -0.5); t_sh_r = Vector3(0.6, 0, 0.5)

	if blocking:
		t_sh_l = Vector3(1.25, -0.5, -0.1)
		t_el_l = Vector3(1.3, 0, 0)
		t_spine.y = -0.15

	if cast_t >= 0.0:
		var k := sin(clampf(cast_t, 0.0, 1.0) * PI)
		t_sh_l = t_sh_l.lerp(Vector3(1.5, 0.35, 0), k)
		t_el_l = t_el_l.lerp(Vector3(0.1, 0, 0), k)
		t_spine.y = lerpf(t_spine.y, -0.3, k)

	if attack_t >= 0.0:
		var p := _attack_pose(attack_t, attack_kind)
		t_sh_r = p[0]; t_el_r = p[1]; t_spine.y = p[2]; t_wrist = p[3]
		t_spine.x += p[4]
		w = ws

	if dodge_t >= 0.0:
		var k2 := sin(clampf(dodge_t, 0.0, 1.0) * PI)
		t_spine.x -= 0.9 * k2
		t_hips_y -= 0.4 * k2
		t_hip_l.x += 1.3 * k2; t_hip_r.x += 1.0 * k2
		t_kn_l.x -= 1.8 * k2; t_kn_r.x -= 1.8 * k2

	if hurt_t >= 0.0:
		var k3 := sin(clampf(hurt_t, 0.0, 1.0) * PI)
		t_spine.x += 0.35 * k3
		t_neck.x += 0.3 * k3

	hips.position.y = lerpf(hips.position.y, t_hips_y, w)
	spine.rotation = spine.rotation.lerp(t_spine, w)
	neck.rotation = neck.rotation.lerp(t_neck, w)
	hip_l.rotation = hip_l.rotation.lerp(t_hip_l, w)
	hip_r.rotation = hip_r.rotation.lerp(t_hip_r, w)
	kn_l.rotation = kn_l.rotation.lerp(t_kn_l, w)
	kn_r.rotation = kn_r.rotation.lerp(t_kn_r, w)
	sh_l.rotation = sh_l.rotation.lerp(t_sh_l, w)
	sh_r.rotation = sh_r.rotation.lerp(t_sh_r, w)
	el_l.rotation = el_l.rotation.lerp(t_el_l, w)
	el_r.rotation = el_r.rotation.lerp(t_el_r, w)
	hand_r.rotation = hand_r.rotation.lerp(t_wrist, w)

## Returns [shoulder_r, elbow_r, spine_yaw, wrist, spine_pitch] for swing progress t.
func _attack_pose(t: float, kind: int) -> Array:
	var wind := 0.32
	var strike := 0.55
	var a: Array
	var b: Array
	if kind == 0:  # overhead diagonal
		a = [Vector3(2.7, -0.2, 0.5), Vector3(1.3, 0, 0), -0.45, Vector3(0.3, 0, 0), 0.08]
		b = [Vector3(0.35, 0.6, -0.3), Vector3(0.15, 0, 0), 0.4, Vector3(-0.4, 0, 0), -0.25]
	elif kind == 1:  # horizontal sweep right -> left
		a = [Vector3(1.45, -1.3, 0.2), Vector3(0.5, 0, 0), -0.6, Vector3(-1.3, 0, 0), 0.0]
		b = [Vector3(1.35, 1.05, 0.0), Vector3(0.15, 0, 0), 0.55, Vector3(-1.3, 0, 0), -0.1]
	else:  # thrust / two-handed slam
		a = [Vector3(2.9, 0.0, 0.15), Vector3(0.9, 0, 0), -0.1, Vector3(0.0, 0, 0), 0.15]
		b = [Vector3(0.9, 0.1, 0.0), Vector3(0.0, 0, 0), 0.05, Vector3(-0.9, 0, 0), -0.45]
	var rest := [Vector3(0.3, 0, 0.12), Vector3(0.45, 0, 0), 0.0, Vector3.ZERO, 0.0]
	var from: Array; var to: Array; var k: float
	if t < wind:
		from = rest; to = a; k = _ease_out(t / wind)
	elif t < strike:
		from = a; to = b; k = _ease_in((t - wind) / (strike - wind))
	else:
		from = b; to = rest; k = smoothstep(0.0, 1.0, (t - strike) / (1.0 - strike))
	return [
		(from[0] as Vector3).lerp(to[0], k), (from[1] as Vector3).lerp(to[1], k),
		lerpf(from[2], to[2], k), (from[3] as Vector3).lerp(to[3], k), lerpf(from[4], to[4], k),
	]

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0, 1), 3.0)
func _ease_in(x: float) -> float:
	return pow(clampf(x, 0, 1), 1.6)

# ---------------------------------------------------------------------------
## Detach every visible part into a tumbling rigid body (skeletons, the Warden).
func shatter(impulse_dir: Vector3, power := 3.0, lifetime := 7.0) -> void:
	dead = true
	var world := get_tree().current_scene
	for mi in all_meshes:
		if not is_instance_valid(mi) or not mi.visible:
			continue
		var gt := mi.global_transform
		var rb := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		var aabb := mi.get_aabb()
		var bs := BoxShape3D.new()
		var sc := gt.basis.get_scale()
		bs.size = (aabb.size * sc).clamp(Vector3.ONE * 0.04, Vector3.ONE * 2.0)
		cs.shape = bs
		cs.position = aabb.get_center() * sc
		rb.add_child(cs)
		rb.collision_layer = 8
		rb.collision_mask = 1 | 8
		rb.mass = maxf(0.2, bs.size.x * bs.size.y * bs.size.z * 300.0)
		world.add_child(rb)
		rb.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin)
		mi.get_parent().remove_child(mi)
		rb.add_child(mi)
		mi.transform = Transform3D(Basis.from_scale(sc), Vector3.ZERO)
		mi.material_overlay = null
		var dir := (impulse_dir + Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 1.0), randf_range(-0.6, 0.6))).normalized()
		rb.apply_impulse(dir * power * rb.mass * randf_range(0.5, 1.2))
		rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		var tw := rb.create_tween()
		tw.tween_interval(lifetime)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(rb.queue_free)
	all_meshes.clear()

## Simple fall-over for humans (player death, revenant).
func collapse() -> void:
	dead = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:x", PI / 2.1, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + 0.12, 0.7)
	tw.tween_property(sh_l, "rotation", Vector3(2.2, 0, -0.6), 0.5)
	tw.tween_property(sh_r, "rotation", Vector3(2.4, 0, 0.6), 0.5)

func revive() -> void:
	dead = false
	rotation = Vector3.ZERO
	position = Vector3.ZERO
