extends CharacterBody3D
class_name Enemy
## State-machine dungeon enemy (KayKit skeleton rigs).
## Types: minion, warrior, mage (ranged), revenant (heavy, intermediate).

signal died(enemy: Enemy)

const TYPES := {
	"minion": {"name": "Risen Bones", "variant": "minion", "hp": 48.0, "dmg": 11.0, "speed": 3.4, "range": 1.8,
		"windup": 0.42, "cooldown": 1.0, "xp": 30, "weapon": "skel_blade", "shield": "", "eye": Color(0.3, 0.85, 1.0),
		"scale": 0.84, "aggro": 11.0, "poise": 0.0, "gold": [2, 8]},
	"warrior": {"name": "Vault Sentinel", "variant": "warrior", "hp": 80.0, "dmg": 13.0, "speed": 2.9, "range": 1.9,
		"windup": 0.5, "cooldown": 1.35, "xp": 55, "weapon": "skel_axe", "shield": "Skeleton_Shield_Small_A", "eye": Color(1.0, 0.7, 0.2),
		"scale": 0.88, "aggro": 11.0, "poise": 10.0, "gold": [5, 14]},
	"mage": {"name": "Bone Hexer", "variant": "mage", "hp": 46.0, "dmg": 11.0, "speed": 2.6, "range": 11.0,
		"windup": 0.7, "cooldown": 2.4, "xp": 50, "weapon": "skel_staff", "shield": "", "eye": Color(0.4, 1.0, 0.5),
		"scale": 0.84, "aggro": 15.0, "poise": 0.0, "gold": [6, 16], "ranged": true},
	"revenant": {"name": "Hollow Revenant", "variant": "warrior", "hp": 190.0, "dmg": 24.0, "speed": 2.5, "range": 2.6,
		"windup": 0.85, "cooldown": 1.9, "xp": 120, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(1.0, 0.25, 0.15),
		"scale": 1.25, "aggro": 13.0, "poise": 30.0, "gold": [20, 35], "heavy": true},
	# --- Goblin Forest: goblins are built on the hero rigs (green skin, ears, small)
	"goblin": {"name": "Goblin Cutter", "hp": 72.0, "dmg": 13.0, "speed": 4.3, "range": 1.7,
		"windup": 0.38, "cooldown": 0.9, "xp": 40, "weapon": "skel_blade", "shield": "", "eye": Color(1.0, 0.85, 0.2),
		"scale": 0.62, "aggro": 14.0, "poise": 0.0, "gold": [3, 9], "leash": 30.0,
		"look": {"hero": "Rogue", "hair_style": "mohawk", "hair_color": Color(0.12, 0.08, 0.06), "face": "warpaint", "outfit": Color(0.42, 0.3, 0.16)}},
	"goblin_archer": {"name": "Goblin Archer", "hp": 56.0, "dmg": 13.0, "speed": 3.8, "range": 15.0,
		"windup": 0.6, "cooldown": 1.7, "xp": 46, "weapon": "", "shield": "", "eye": Color(0.75, 1.0, 0.3),
		"scale": 0.6, "aggro": 18.0, "poise": 0.0, "gold": [4, 10], "ranged": true, "leash": 32.0,
		"look": {"hero": "Ranger", "hair_style": "natural", "hair_color": Color(0.1, 0.1, 0.1), "face": "none", "outfit": Color(0.3, 0.36, 0.15)}},
	"goblin_brute": {"name": "Goblin Brute", "hp": 280.0, "dmg": 27.0, "speed": 3.0, "range": 2.4,
		"windup": 0.75, "cooldown": 1.55, "xp": 120, "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.45, 0.15),
		"scale": 0.95, "aggro": 14.0, "poise": 25.0, "gold": [12, 24], "heavy": true, "leash": 26.0,
		"look": {"hero": "Barbarian", "hair_style": "bald", "hair_color": Color(0.1, 0.1, 0.1), "face": "scar", "outfit": Color(0.35, 0.22, 0.14), "build": 1.25}},
	"goblin_chief": {"name": "Chief Gruk", "hp": 1150.0, "dmg": 33.0, "speed": 3.3, "range": 2.9,
		"windup": 0.8, "cooldown": 1.45, "xp": 450, "weapon": "skel_axe", "shield": "Skeleton_Shield_Large_A", "eye": Color(1.0, 0.3, 0.1),
		"scale": 1.35, "aggro": 16.0, "poise": 70.0, "gold": [60, 90], "heavy": true, "leash": 40.0, "summon": true,
		"look": {"hero": "Barbarian", "hair_style": "mohawk", "hair_color": Color(0.85, 0.12, 0.08), "face": "warpaint", "outfit": Color(0.5, 0.12, 0.1), "build": 1.3, "hat": true}},
	# --- the Sinkhole of Death: fire goblins and the Cyclops Goblin
	"fire_goblin": {"name": "Ember Goblin", "hp": 110.0, "dmg": 17.0, "speed": 4.5, "range": 1.8,
		"windup": 0.36, "cooldown": 0.85, "xp": 70, "weapon": "skel_blade", "shield": "", "eye": Color(1.0, 0.45, 0.1),
		"scale": 0.66, "aggro": 15.0, "poise": 5.0, "gold": [6, 14], "leash": 30.0, "skin": Color(0.78, 0.32, 0.18),
		"look": {"hero": "Rogue", "hair_style": "spiky", "hair_color": Color(1.0, 0.45, 0.05), "face": "warpaint", "outfit": Color(0.25, 0.08, 0.06)}},
	"fire_archer": {"name": "Cinder Slinger", "hp": 85.0, "dmg": 16.0, "speed": 3.9, "range": 16.0,
		"windup": 0.55, "cooldown": 1.6, "xp": 70, "weapon": "", "shield": "", "eye": Color(1.0, 0.5, 0.1),
		"scale": 0.62, "aggro": 19.0, "poise": 0.0, "gold": [6, 14], "ranged": true, "leash": 32.0, "skin": Color(0.78, 0.32, 0.18),
		"look": {"hero": "Ranger", "hair_style": "natural", "hair_color": Color(0.1, 0.1, 0.1), "face": "none", "outfit": Color(0.35, 0.1, 0.05)}},
	"magma_brute": {"name": "Magma Brute", "hp": 420.0, "dmg": 34.0, "speed": 3.0, "range": 2.6,
		"windup": 0.75, "cooldown": 1.5, "xp": 200, "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.35, 0.05),
		"scale": 1.05, "aggro": 15.0, "poise": 35.0, "gold": [18, 32], "heavy": true, "leash": 28.0, "skin": Color(0.62, 0.2, 0.12),
		"look": {"hero": "Barbarian", "hair_style": "spiky", "hair_color": Color(1.0, 0.5, 0.05), "face": "scar", "outfit": Color(0.2, 0.06, 0.04), "build": 1.3}},
	"cyclops": {"name": "Grimgor the Cyclops Goblin", "hp": 2200.0, "dmg": 40.0, "speed": 3.2, "range": 3.6,
		"windup": 0.85, "cooldown": 1.5, "xp": 900, "weapon": "skel_axe", "shield": "", "eye": Color(1.0, 0.25, 0.05),
		"scale": 2.3, "aggro": 20.0, "poise": 120.0, "gold": [120, 180], "heavy": true, "leash": 50.0, "summon": true, "nova": true,
		"skin": Color(0.45, 0.6, 0.22),
		"look": {"hero": "Barbarian", "hair_style": "natural", "hair_color": Color(0.15, 0.1, 0.05), "face": "none", "outfit": Color(0.4, 0.1, 0.08), "build": 1.4, "cyclops": true}},
}
const GOBLIN_SKIN := Color(0.42, 0.62, 0.24)

enum S { DORMANT, AWAKEN, IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, RETURN, DEAD }

var type_id := "minion"
var t: Dictionary
var uid := ""
var hp := 40.0
var max_hp := 40.0
var dead := false
var state := S.IDLE
var state_time := 0.0
var cooldown := 0.0
var home := Vector3.ZERO
var leash := 18.0
var dormant_wake := 0.0     # >0 : lies in the floor until the player comes within this range
var body: CharacterModel
var hit_radius := 0.45
var facing := 0.0
var player: Node3D
var display_name := ""
var bounds := AABB()        # optional room bounds the enemy will not leave
var _strafe := 1.0
var _hurt_t := -1.0
var _stagger_acc := 0.0
var _summoned := false

func configure(type_name: String, id: String, wake_range := 0.0) -> void:
	type_id = type_name
	uid = id
	dormant_wake = wake_range

func _ready() -> void:
	t = TYPES[type_id]
	display_name = t.name
	add_to_group("enemy")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	max_hp = t.hp
	hp = max_hp
	hit_radius = 0.45 * t.scale / 0.84
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.38 * t.scale / 0.84; cap.height = 1.7 * t.scale / 0.84
	cs.shape = cap; cs.position.y = cap.height * 0.5
	add_child(cs)
	body = CharacterModel.new()
	add_child(body)
	if t.has("look"):
		var lk: Dictionary = t.look
		var skin_c: Color = t.get("skin", GOBLIN_SKIN)
		body.setup({"kind": "hero", "hero": lk.hero, "show_hat": lk.get("hat", false), "weapon": t.weapon, "shield": t.shield,
			"scale": t.scale, "skin_color": skin_c, "hair_style": lk.hair_style, "hair_color": lk.hair_color,
			"hair_tint": skin_c.darkened(0.1) if lk.hair_style in ["bald", "mohawk"] else lk.hair_color,
			"face": lk.face, "ears": true, "outfit_color": lk.outfit, "cape_color": lk.outfit.darkened(0.2),
			"build": lk.get("build", 1.05), "height": 0.95})
	else:
		body.setup({"kind": "skeleton", "variant": t.variant, "weapon": t.weapon, "shield": t.shield, "eye": t.eye, "scale": t.scale})
	if t.has("look") and t.look.get("cyclops", false):
		_cyclops_eye.call_deferred()
	leash = t.get("leash", leash)
	home = global_position
	facing = rotation.y
	rotation.y = 0
	body.rotation.y = facing
	_strafe = 1.0 if randf() > 0.5 else -1.0
	if dormant_wake > 0.0:
		state = S.DORMANT
		body.visible = false
		cs.disabled = true
		set_physics_process(true)

func _go(s: S) -> void:
	state = s
	state_time = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	state_time += delta
	cooldown -= delta
	if _hurt_t >= 0.0:
		_hurt_t += delta
		if _hurt_t > 0.35:
			_hurt_t = -1.0
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	var pdead: bool = player.get("dead") == true
	var move := Vector3.ZERO
	var spd: float = t.speed

	match state:
		S.DORMANT:
			if dist < dormant_wake and not pdead:
				_awaken()
			return
		S.AWAKEN:
			if state_time > 1.6:
				_go(S.CHASE)
		S.IDLE:
			if not pdead and dist < t.aggro and _in_bounds(player.global_position):
				_go(S.CHASE)
				Sfx.play_at("skel_attack", global_position, -10.0)
		S.CHASE:
			if t.get("nova", false):
				_nova_cd -= delta
				if _nova_cd <= 0.0 and dist < 9.0 and not pdead:
					_nova_cd = randf_range(6.5, 9.0) if hp > max_hp * 0.5 else randf_range(4.5, 6.5)
					_fire_nova()
			if pdead or dist > t.aggro * 2.2 or global_position.distance_to(home) > leash or not _in_bounds(player.global_position, 3.0):
				_go(S.RETURN)
			elif t.get("ranged", false):
				# keep a comfortable distance and circle
				var want := 8.0
				var side := to_p.normalized().cross(Vector3.UP) * _strafe
				if dist < want - 2.0:
					move = -to_p.normalized() + side * 0.5
				elif dist > want + 2.5:
					move = to_p.normalized()
				else:
					move = side * 0.7
				if state_time > 2.5:
					_strafe *= -1.0; state_time = 0.0
				if cooldown <= 0.0 and dist < t.range and _has_los():
					_go(S.WINDUP)
			else:
				move = to_p.normalized()
				if dist < t.range * 0.9 and cooldown <= 0.0:
					_go(S.WINDUP)
				elif dist < t.range * 0.9:
					move = to_p.normalized().cross(Vector3.UP) * _strafe * 0.4  # circle while waiting
		S.WINDUP:
			if state_time == delta or state_time < delta * 1.5:
				var kind := 2 if t.get("heavy", false) else randi() % 2
				body.attack_kind = kind
				body.attack_dur = t.windup + 0.45
				body.attack_t = 0.0
				body.flash(t.eye, 0.35)
				if t.get("ranged", false):
					body.cast_t = 0.0
					body.attack_t = -1.0
			if state_time >= t.windup:
				_go(S.STRIKE)
				_strike(dist, to_p)
		S.STRIKE:
			if state_time > 0.15:
				_go(S.RECOVER)
		S.RECOVER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.35:
				cooldown = t.cooldown * randf_range(0.8, 1.2)
				_go(S.CHASE)
		S.STAGGER:
			body.attack_t = -1.0
			body.cast_t = -1.0
			if state_time > 0.4:
				_go(S.CHASE)
		S.RETURN:
			var th := home - global_position; th.y = 0
			if th.length() < 0.6:
				_go(S.IDLE)
				hp = minf(max_hp, hp + max_hp * 0.5)
			else:
				move = th.normalized()
			if not pdead and dist < t.aggro * 0.7 and global_position.distance_to(home) < leash * 0.6:
				_go(S.CHASE)

	# separation from other enemies
	for o in get_tree().get_nodes_in_group("enemy"):
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var l := d.length()
		if l < 1.3 and l > 0.01:
			move += d / l * (1.3 - l) * 1.5
	if move.length() > 1.0:
		move = move.normalized()
	if state in [S.WINDUP, S.STRIKE, S.RECOVER, S.STAGGER, S.AWAKEN]:
		move = Vector3.ZERO
	var target_v := move * spd
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-8.0 * delta))
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	# face the player while engaged; face movement otherwise
	var want_face := facing
	if state in [S.CHASE, S.WINDUP] and dist > 0.1:
		want_face = atan2(-to_p.x, -to_p.z)
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		want_face = atan2(-velocity.x, -velocity.z)
	var turn := 5.0 if state == S.WINDUP and t.get("heavy", false) else 9.0
	facing = lerp_angle(facing, want_face, 1.0 - exp(-turn * delta))
	body.rotation.y = facing
	body.move_speed = Vector2(velocity.x, velocity.z).length()
	body.grounded = true
	body.hurt_t = _hurt_t / 0.35 if _hurt_t >= 0.0 else -1.0
	if state == S.WINDUP and not t.get("ranged", false):
		body.attack_t = state_time / (t.windup + 0.45)

## The Cyclops stamps the ground: a glowing ring warns you, then a wave of fire
## bursts out around it. Get clear (or dodge through it) in time!
var _nova_cd := 5.0
func _fire_nova() -> void:
	var at := global_position
	var radius := 6.5
	Sfx.play_at("roar_big", at, -2.0, 0.05)
	body.flash(Color(1.0, 0.4, 0.1), 0.9)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = radius - 0.25; tm.outer_radius = radius
	ring.mesh = tm; ring.material_override = FX.glow_material(Color(1.0, 0.25, 0.05), 3.0)
	get_tree().current_scene.add_child(ring)
	ring.global_position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(1, 0.05, 1)
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = 0.02
	disc.mesh = cm; var dm := FX.glow_material(Color(1.0, 0.2, 0.0), 0.7); dm.albedo_color.a = 0.35
	disc.material_override = dm
	get_tree().current_scene.add_child(disc)
	disc.global_position = at + Vector3(0, 0.06, 0)
	disc.scale = Vector3(0.05, 1, 0.05)
	var tw := disc.create_tween()
	tw.tween_property(disc, "scale", Vector3.ONE, 1.15)
	await get_tree().create_timer(1.2).timeout
	ring.queue_free(); disc.queue_free()
	if dead or not is_inside_tree():
		return
	Sfx.play_at("fire_burst", at, 0.0)
	Sfx.play_at("slam", at, 0.0)
	FX.shockwave(at + Vector3(0, 0.2, 0), Color(1.0, 0.35, 0.05), radius, 0.5)
	FX.burst(at + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.1), 90, 9.0, 0.35, 0.9, -2.0)
	FX.flash_light(at + Vector3(0, 2, 0), Color(1.0, 0.45, 0.1), 8.0, 14.0, 0.5)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.5)
	if player and player.get("dead") != true:
		var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if d < radius and absf(player.global_position.y - at.y) < 3.0:
			player.take_damage(t.dmg * 0.8, at, 7.0)

## One huge eye in the middle of the face (covers the two little ones).
func _cyclops_eye() -> void:
	var head: MeshInstance3D = null
	for m in body.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with("_Head") and (m as MeshInstance3D).visible:
			head = m
	var att := body._attach("head")
	if head == null or att == null:
		return
	var ab: AABB = head.global_transform * head.get_aabb()
	var root := Node3D.new(); att.add_child(root)
	# local "forward" of the face: the character faces -Z in body space
	var fwd := (-body.global_transform.basis.z).normalized()
	var c := ab.get_center()
	var r := ab.size.x * 0.24
	var face_pt := c + fwd * (ab.size.z * 0.38) + Vector3(0, ab.size.y * 0.02, 0)
	root.global_transform = Transform3D(body.global_transform.basis.orthonormalized(), face_pt)
	var white := StandardMaterial3D.new(); white.albedo_color = Color(1.0, 0.97, 0.9); white.roughness = 0.2
	var iris := StandardMaterial3D.new(); iris.albedo_color = Color(1.0, 0.35, 0.05); iris.emission_enabled = true
	iris.emission = Color(1.0, 0.3, 0.0); iris.emission_energy_multiplier = 2.5
	var pupil := StandardMaterial3D.new(); pupil.albedo_color = Color(0.02, 0.01, 0.01)
	var skin := StandardMaterial3D.new(); skin.albedo_color = t.get("skin", GOBLIN_SKIN); skin.roughness = 0.7
	var mk := func(rad: float, m: Material, at: Vector3, scl := Vector3.ONE) -> void:
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = rad; sm.height = rad * 2.0
		mi.mesh = sm; mi.material_override = m; mi.position = at; mi.scale = scl
		root.add_child(mi)
	mk.call(r * 1.25, skin, Vector3(0, 0, r * 0.35), Vector3(1.35, 1.0, 0.55))     # a fleshy socket over the old eyes
	mk.call(r, white, Vector3(0, 0, -r * 0.15))
	mk.call(r * 0.55, iris, Vector3(0, 0, -r * 0.62), Vector3(1, 1, 0.6))
	mk.call(r * 0.28, pupil, Vector3(0, 0, -r * 0.8), Vector3(1, 1, 0.5))
	var brow := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(r * 2.4, r * 0.35, r * 0.5)
	brow.mesh = bm; brow.material_override = skin; brow.position = Vector3(0, r * 1.05, -r * 0.2); brow.rotation.x = 0.25
	root.add_child(brow)
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.35, 0.05); glow.light_energy = 1.5; glow.omni_range = 4.0
	glow.position = Vector3(0, 0, -r * 1.2); root.add_child(glow)

func _in_bounds(p: Vector3, margin := 0.0) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var b := bounds.grow(margin)
	return p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z

func _has_los() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.2, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _awaken() -> void:
	_go(S.AWAKEN)
	body.visible = true
	body.hold_clip = ""
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = false
	body.play_role("spawn", 1.5)
	FX.burst(global_position + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 30, 3.0, 0.4, 1.0, -4.0)
	FX.burst(global_position + Vector3(0, 0.5, 0), t.eye, 14, 1.5, 0.2, 0.9, 1.0)
	Sfx.play_at("bone_break", global_position, -2.0)
	var to_p: Vector3 = player.global_position - global_position
	facing = atan2(-to_p.x, -to_p.z)
	body.rotation.y = facing

func _strike(dist: float, to_p: Vector3) -> void:
	if t.get("ranged", false):
		var b := Area3D.new()
		b.set_script(load("res://scripts/player/projectile.gd"))
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + Vector3(0, 1.5, 0) + (-Vector3(sin(facing), 0, cos(facing))) * 0.6
		var aim: Vector3 = (player.global_position + Vector3(0, 1.1, 0)) - b.global_position
		b.launch(aim, "enemy", t.dmg, t.eye, 13.0)
		b.homing = 1.2
		Sfx.play_at("spell", global_position, -6.0)
		return
	Sfx.play_at("swing", global_position, -4.0, 0.15)
	if t.get("heavy", false):
		Sfx.play_at("slam", global_position, -6.0)
		FX.shockwave(global_position + (-Vector3(sin(facing), 0, cos(facing))) * 1.6, Color(1.0, 0.4, 0.2), 2.6, 0.35)
		if player.has_method("add_trauma"):
			player.add_trauma(0.3)
	var fwd := -Vector3(sin(facing), 0, cos(facing))
	var reach: float = t.range + 0.35
	if dist < reach and (dist < 0.6 or fwd.dot(to_p.normalized()) > 0.35) and player.get("dead") != true:
		player.take_damage(t.dmg * randf_range(0.9, 1.1), global_position, 5.0 if t.get("heavy", false) else 3.0)

func take_damage(amount: float, from_pos: Vector3, knock := 2.5, crit := false) -> void:
	if dead:
		return
	if state == S.DORMANT:
		_awaken()
	hp -= amount
	if t.get("summon", false) and not _summoned and hp < max_hp * 0.5 and hp > 0.0:
		_summoned = true
		if get_parent().has_method("summon_for"):
			get_parent().summon_for(self)
	body.flash(Color(1, 1, 1), 0.85)
	Sfx.play_at("hit", global_position + Vector3(0, 1, 0), -3.0, 0.15)
	FX.hit(global_position + Vector3(0, 1.1, 0), Color(1.0, 0.9, 0.7))
	FX.damage_number(global_position + Vector3(0, 2.0 * t.scale / 0.84, 0), amount, Color(1, 1, 1), crit)
	Game.emit_signal("stats_changed")
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("on_enemy_hit"):
		tree.current_scene.on_enemy_hit(self)
	var away := global_position - from_pos
	away.y = 0
	if hp <= 0.0:
		_die(away)
		return
	if state in [S.IDLE, S.RETURN]:
		_go(S.CHASE)
	_stagger_acc += amount
	if _stagger_acc > t.poise:
		_stagger_acc = 0.0
		if away.length() > 0.01:
			var k := away.normalized() * knock
			velocity.x += k.x; velocity.z += k.z
		if state != S.STRIKE:
			_go(S.STAGGER)
			_hurt_t = 0.0

func _die(away: Vector3) -> void:
	dead = true
	_go(S.DEAD)
	remove_from_group("enemy")
	remove_from_group("damageable")
	collision_layer = 0
	collision_mask = 1
	body.collapse()
	Sfx.play_at("bone_break", global_position, 0.0)
	FX.burst(global_position + Vector3(0, 1.0, 0), t.eye, 24, 2.5, 0.25, 1.0, 1.0)
	Game.kills += 1
	Game.add_xp(t.xp)
	if uid != "":
		Game.flags[uid] = true
	Game.on_enemy_killed(type_id, uid)
	_drop_loot()
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(body, "position:y", -1.2, 1.5)
	tw.tween_callback(queue_free)

func _drop_loot() -> void:
	var g: Array = t.gold
	Pickup.spawn(global_position + Vector3(0, 0.6, 0), "gold", randi_range(g[0], g[1]))
	var table := "summon" if uid == "" else type_id
	var k := 0
	for d in Loot.roll_enemy(table, Loot.area_level(global_position.z)):
		k += 1
		var off := Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.5
		Pickup.spawn(global_position + Vector3(0, 0.7, 0) + off, d.kind, int(d.get("amount", 1)), String(d.get("id", "")))
