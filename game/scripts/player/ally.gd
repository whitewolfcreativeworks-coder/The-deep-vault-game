extends CharacterBody3D
class_name Ally
## A friendly creature that fights at your side:
##   wolf      the Beastmaster's loyal companion (always with you)
##   bear      the Beastmaster's Bear Friend (a big hitter, for a while)
##   skeleton  the Necromancer's risen dead (for a while)
## Allies follow you, run at whatever you're fighting (or the nearest foe close
## to you), and bite or swing at it. Enemies don't fight back at them, and
## they don't block you or anyone else.

var kind := "wolf"
var life := -1.0               # seconds left (-1 = stays)
var owner_p: Player
var target: Node3D
var pounce_t := 0.0            # >0: dashing at a target for a big hit
var _cd := 0.0
var _t := 0.0
var _facing := 0.0
var _vis: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _skel: CharacterModel
var _offset := Vector3(1.4, 0, 1.6)
var _dying := false

const STATS := {
	"wolf": {"speed": 6.8, "range": 1.6, "cd": 0.85, "dmg": 0.55, "knock": 2.0},
	"bear": {"speed": 5.6, "range": 2.4, "cd": 1.3, "dmg": 1.3, "knock": 6.0},
	"skeleton": {"speed": 5.2, "range": 1.9, "cd": 1.0, "dmg": 0.6, "knock": 2.5},
}

static func spawn(p: Player, k: String, at: Vector3, secs := -1.0) -> Ally:
	var a := Ally.new()
	a.kind = k
	a.life = secs
	a.owner_p = p
	a.position = at
	p.get_parent().add_child(a)
	FX.burst(at + Vector3(0, 0.8, 0), {"wolf": Color(0.8, 0.8, 0.85), "bear": Color(0.75, 0.5, 0.3), "skeleton": Color(0.45, 1.0, 0.5)}[k], 40, 3.0, 0.2, 0.8, 0.5)
	return a

func _ready() -> void:
	add_to_group("ally")
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new()
	sh.radius = 0.3 if kind == "wolf" else (0.6 if kind == "bear" else 0.35)
	sh.height = 1.0 if kind == "wolf" else (1.8 if kind == "bear" else 1.7)
	cs.shape = sh; cs.position.y = sh.height * 0.5
	add_child(cs)
	_offset = Vector3(randf_range(-2.0, 2.0), 0, randf_range(1.2, 2.4))
	match kind:
		"wolf": _build_wolf(Color(0.55, 0.56, 0.6), Color(0.85, 0.85, 0.88))
		"bear": _build_bear()
		"skeleton": _build_skeleton()

func _m(c: Color, rough := 0.85) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new(); mt.albedo_color = c; mt.roughness = rough
	return mt

func _ball(parent: Node3D, r: float, mat: Material, at: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = mat; mi.position = at; mi.scale = scl
	parent.add_child(mi)
	return mi

func _limb(parent: Node3D, at: Vector3, ln: float, r: float, mat: Material) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n)
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r * 0.85; cm.height = ln
	cm.radial_segments = 8
	mi.mesh = cm; mi.material_override = mat; mi.position.y = -ln * 0.5; n.add_child(mi)
	_legs.append(n)
	return n

func _build_wolf(fur_c: Color, belly_c: Color) -> void:
	_vis = Node3D.new(); add_child(_vis)
	var fur := _m(fur_c); var belly := _m(belly_c)
	var dark := _m(Color(0.05, 0.05, 0.06), 0.3)
	_ball(_vis, 0.3, fur, Vector3(0, 0.62, 0.05), Vector3(0.9, 0.85, 1.6))
	_ball(_vis, 0.22, belly, Vector3(0, 0.52, -0.25), Vector3(0.9, 0.9, 1.0))
	_head = Node3D.new(); _head.position = Vector3(0, 0.82, -0.48); _vis.add_child(_head)
	_ball(_head, 0.2, fur, Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	_ball(_head, 0.11, belly, Vector3(0, -0.05, -0.2), Vector3(0.9, 0.8, 1.4))
	_ball(_head, 0.04, dark, Vector3(0, -0.01, -0.36))
	for sx in [-1.0, 1.0]:
		var ear := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.07; cm.height = 0.18
		ear.mesh = cm; ear.material_override = fur; ear.position = Vector3(sx * 0.1, 0.2, 0.02); ear.rotation.z = -sx * 0.25
		_head.add_child(ear)
		_ball(_head, 0.035, _m(Color(1.0, 0.8, 0.2), 0.2), Vector3(sx * 0.09, 0.06, -0.16))
	_tail = Node3D.new(); _tail.position = Vector3(0, 0.72, 0.5); _vis.add_child(_tail)
	_ball(_tail, 0.08, fur, Vector3(0, 0.05, 0.2), Vector3(0.9, 0.9, 2.6)).rotation.x = 0.5
	for p in [Vector3(-0.14, 0.5, -0.3), Vector3(0.14, 0.5, -0.3), Vector3(-0.14, 0.5, 0.35), Vector3(0.14, 0.5, 0.35)]:
		_limb(_vis, p, 0.5, 0.06, fur)

func _build_bear() -> void:
	_vis = Node3D.new(); add_child(_vis)
	var fur := _m(Color(0.42, 0.27, 0.15)); var muzzle := _m(Color(0.75, 0.6, 0.42))
	var dark := _m(Color(0.05, 0.04, 0.03), 0.3)
	_ball(_vis, 0.6, fur, Vector3(0, 1.0, 0.1), Vector3(1.0, 0.85, 1.35))
	_head = Node3D.new(); _head.position = Vector3(0, 1.35, -0.8); _vis.add_child(_head)
	_ball(_head, 0.36, fur, Vector3.ZERO)
	_ball(_head, 0.17, muzzle, Vector3(0, -0.07, -0.3), Vector3(1.0, 0.8, 1.0))
	_ball(_head, 0.06, dark, Vector3(0, 0.0, -0.45))
	for sx in [-1.0, 1.0]:
		_ball(_head, 0.11, fur, Vector3(sx * 0.25, 0.28, 0.0))
		_ball(_head, 0.045, dark, Vector3(sx * 0.13, 0.08, -0.3))
	for p in [Vector3(-0.32, 0.7, -0.45), Vector3(0.32, 0.7, -0.45), Vector3(-0.32, 0.7, 0.6), Vector3(0.32, 0.7, 0.6)]:
		_limb(_vis, p, 0.7, 0.16, fur)
	_vis.scale = Vector3.ONE * 1.15

func _build_skeleton() -> void:
	_skel = CharacterModel.new()
	add_child(_skel)
	_skel.setup({"kind": "skeleton", "variant": "warrior" if randf() < 0.5 else "minion", "weapon": "skel_blade",
		"shield": "Skeleton_Shield_Small_A", "eye": Color(0.4, 1.0, 0.45), "scale": 0.82})
	_vis = _skel
	# a ghostly green glow so you can tell it's on your side
	var l := OmniLight3D.new(); l.light_color = Color(0.4, 1.0, 0.45); l.light_energy = 0.8; l.omni_range = 3.0
	l.position.y = 1.4; add_child(l)

func _foes() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.dead and absf(e.global_position.y - global_position.y) < 3.0:
			out.append(e)
	return out

func _pick_target() -> void:
	if target and is_instance_valid(target) and not target.get("dead"):
		if target.global_position.distance_to(owner_p.global_position) < 18.0:
			return
	target = null
	var best := 11.0
	for e in _foes():
		var d: float = (e as Node3D).global_position.distance_to(owner_p.global_position)
		if d < best:
			best = d; target = e

## Beastmaster's "Sic 'em!": dash at this foe and land a big pounce.
func pounce(at: Node3D) -> void:
	target = at
	pounce_t = 1.2

func _physics_process(delta: float) -> void:
	_t += delta
	if owner_p == null or not is_instance_valid(owner_p):
		queue_free()
		return
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			_vanish()
			return
	if _dying:
		return
	var st: Dictionary = STATS[kind]
	_cd -= delta
	pounce_t -= delta
	# stay with your hero: catch up across floors / big gaps
	if global_position.distance_to(owner_p.global_position) > 26.0 or absf(global_position.y - owner_p.global_position.y) > 6.0:
		global_position = owner_p.global_position + _offset.rotated(Vector3.UP, owner_p.facing)
		velocity = Vector3.ZERO
		target = null
	if pounce_t <= 0.0:
		_pick_target()
	var goal: Vector3
	var spd: float = st.speed
	var engaged := target != null and is_instance_valid(target)
	if engaged:
		goal = target.global_position
		if pounce_t > 0.0:
			spd *= 1.8
	else:
		goal = owner_p.global_position + _offset.rotated(Vector3.UP, owner_p.facing)
	var to := goal - global_position; to.y = 0
	var reach: float = st.range + (float(target.get("hit_radius")) if engaged and target.get("hit_radius") != null else 0.3)
	var dir := Vector3.ZERO
	if engaged:
		if to.length() > reach * 0.85:
			dir = to.normalized()
	elif to.length() > 1.0:
		dir = to.normalized()
		spd *= clampf(to.length() / 3.0, 0.4, 1.4)
	velocity.x = lerpf(velocity.x, dir.x * spd, 1.0 - exp(-10.0 * delta))
	velocity.z = lerpf(velocity.z, dir.z * spd, 1.0 - exp(-10.0 * delta))
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	if engaged and to.length() <= reach and _cd <= 0.0:
		_strike(st)
	# look and animation
	var face_dir := to if engaged else Vector3(velocity.x, 0, velocity.z)
	if face_dir.length() > 0.2:
		_facing = lerp_angle(_facing, atan2(-face_dir.x, -face_dir.z), 1.0 - exp(-10.0 * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	if _skel:
		_skel.rotation.y = _facing
		_skel.move_speed = hs
		_skel.grounded = true
	else:
		_vis.rotation.y = _facing
		for i in _legs.size():
			_legs[i].rotation.x = sin(_t * (7.0 + hs * 2.0) + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)) * clampf(hs * 0.12, 0.0, 0.7)
		if _tail:
			_tail.rotation.y = sin(_t * 6.0) * 0.4
		if _head:
			_head.position.y = (0.82 if kind == "wolf" else 1.35) + sin(_t * 9.0) * 0.02 * clampf(hs, 0.0, 1.0)

func _strike(st: Dictionary) -> void:
	_cd = float(st.cd)
	var big := pounce_t > 0.0
	var dmg: float = Game.attack_damage() * float(st.dmg) * (3.2 if big else 1.0)
	if big:
		pounce_t = 0.0
		if target.get("_stagger_acc") != null:
			target.set("_stagger_acc", 1.0e9)
		FX.shockwave(target.global_position + Vector3(0, 0.2, 0), Color(1.0, 0.7, 0.3), 2.5, 0.3)
		Sfx.play_at("roar", global_position, -6.0, 0.2)
	target.take_damage(dmg, global_position, float(st.knock) * (2.0 if big else 1.0), big)
	FX.hit(target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.7))
	Sfx.play_at("hit" if kind != "skeleton" else "swing", global_position, -8.0, 0.2)
	if _skel:
		_skel.attack_kind = randi() % 2
		_skel.attack_dur = 0.5
		_skel.attack_t = 0.0
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(_skel):
				_skel.attack_t = -1.0)
	elif _head:
		var tw := create_tween()
		tw.tween_property(_head, "position:z", _head.position.z - 0.25, 0.08)
		tw.tween_property(_head, "position:z", _head.position.z, 0.15)

func _vanish() -> void:
	_dying = true
	FX.burst(global_position + Vector3(0, 0.8, 0), Color(0.45, 1.0, 0.5) if kind == "skeleton" else Color(0.9, 0.85, 0.7), 40, 3.0, 0.2, 0.8, 0.5)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.05, 0.35)
	tw.tween_callback(queue_free)
