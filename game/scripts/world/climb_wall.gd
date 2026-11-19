extends Node3D
class_name ClimbWall
## The climbing corner in the dark north-west of the Outpost, just left of the
## portal you arrive through: two big climbing walls meet at a lookout deck.
##   Green route (north wall): big holds, one step at a time. Walk at the next
##     hold and press JUMP to pull yourself up.
##   Red route (west wall): smaller holds with gaps, set too high to just step up:
##     jump, then press JUMP again as you reach the next one.
## Ring the bell at the top, then ride the zipline back down past the portal.
## Street lamps, coloured uplights and strings of party lights keep it bright.

const WALL_FACE_Z := 1.0          # the north wall's climbing face
const WALL_FACE_X := -32.6        # the west wall's climbing face
const DECK := Rect2(-32.6, 1.0, 5.85, 4.0)   # x/z of the lookout deck
const DECK_TOP := 8.55
const GREEN := Color(0.3, 0.85, 0.35)
const RED := Color(0.95, 0.25, 0.22)
const ZIP_A := Vector3(-27.4, 10.85, 4.5)    # cable ends (the rider hangs 2.25 m below)
const ZIP_B := Vector3(-18.0, 3.7, 16.0)
const HANG := 2.25

var green_holds: Array[Node3D] = []
var red_holds: Array[Node3D] = []
var bell: Node3D
var zipline: ZipLine
var _route := ""                  # the route you were last seen climbing
var _route_t := -100.0
var _clock := 0.0
var _scan := 0.0

static func build(parent: Node3D) -> ClimbWall:
	var c := ClimbWall.new()
	c.name = "ClimbWall"
	parent.add_child(c)
	c._build()
	return c

static func mat(c: Color, rough := 0.7, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = glow
	return m

## A plain box (no jitter: these are things you stand on, so their tops are exact).
func block(size: Vector3, m: Material, center: Vector3, collide := true, shadows := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = m; mi.position = center
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	if collide:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
		cs.shape = bs; sb.add_child(cs); mi.add_child(sb)
	return mi

func _build() -> void:
	var panel := mat(Color(0.3, 0.4, 0.5), 0.8)
	var panel2 := mat(Color(0.36, 0.46, 0.56), 0.8)
	var seam := mat(Color(0.12, 0.14, 0.18), 0.6, 0.3)
	var wood := mat(Color(0.55, 0.36, 0.2), 0.85)
	var iron := mat(Color(0.1, 0.1, 0.12), 0.45, 0.7)
	# --- the two walls (painted plywood panels with dark seams) ---
	# (every face is kept a few millimetres off every other, so nothing flickers)
	block(Vector3(18.4, 10.55, 2.9), panel, Vector3(-24.7, 5.225, WALL_FACE_Z - 1.45))
	block(Vector3(1.4, 10.56, 19.5), panel2, Vector3(WALL_FACE_X - 0.7, 5.22, WALL_FACE_Z + 9.75))
	for k in range(1, 9):
		block(Vector3(0.06, 10.4, 0.04), seam, Vector3(-33.0 + k * 2.0, 5.25, WALL_FACE_Z + 0.025), false, false)
	for k in 5:
		block(Vector3(16.9, 0.06, 0.05), seam, Vector3(-24.05, 2.0 + k * 2.0, WALL_FACE_Z + 0.032), false, false)
	for k in 10:
		block(Vector3(0.04, 10.4, 0.06), seam, Vector3(WALL_FACE_X + 0.025, 5.25, WALL_FACE_Z + 1.0 + k * 2.0), false, false)
	for k in 5:
		block(Vector3(0.05, 0.06, 19.3), seam, Vector3(WALL_FACE_X + 0.032, 2.0 + k * 2.0, WALL_FACE_Z + 9.85), false, false)
	# a chunky cap along the tops
	block(Vector3(18.8, 0.4, 3.3), iron, Vector3(-24.7, 10.68, WALL_FACE_Z - 1.45), false)
	block(Vector3(1.8, 0.42, 19.9), iron, Vector3(WALL_FACE_X - 0.7, 10.66, WALL_FACE_Z + 9.75), false)
	_little_holds()
	# --- green route: 8 big holds, each 0.95 m above the last, ending at the deck ---
	var gm := mat(GREEN, 0.55, 0.0, 0.25)
	for i in 8:
		var top := 0.95 * (i + 1)
		var x := -17.0 - 1.3 * i
		var h := block(Vector3(1.15, 0.75, 0.95), gm, Vector3(x, top - 0.375, WALL_FACE_Z + 0.475))
		block(Vector3(0.7, 0.06, 0.5), mat(GREEN.lightened(0.3), 0.5, 0.0, 0.6), Vector3(x, top + 0.01, WALL_FACE_Z + 0.5), false, false)
		h.set_meta("top", top)
		green_holds.append(h)
	# --- red route: 8 small holds with a gap between each, ending at the deck. They
	# sit too high to step up onto: jump, then press JUMP again by the next one ---
	var rm := mat(RED, 0.55, 0.0, 0.25)
	for i in 8:
		var top := DECK_TOP - (8 - i) * 1.0
		var z := 6.0 + (7 - i) * 1.5
		var h := block(Vector3(1.0, 0.6, 1.0), rm, Vector3(WALL_FACE_X + 0.5, top - 0.3, z))
		block(Vector3(0.55, 0.06, 0.55), mat(RED.lightened(0.3), 0.5, 0.0, 0.6), Vector3(WALL_FACE_X + 0.5, top + 0.01, z), false, false)
		h.set_meta("top", top)
		red_holds.append(h)
	# route badges at the bottom of each route
	_badge(Vector3(-17.0, 1.75, WALL_FACE_Z + 0.06), 0.0, GREEN, "GREEN\nEASY")
	_badge(Vector3(WALL_FACE_X + 0.06, 2.2, 17.8), PI / 2, RED, "RED\nTRICKY")
	# soft crash mats (just padding: you sink into them a little)
	var mat_m := mat(Color(0.2, 0.42, 0.85), 0.9)
	block(Vector3(11.0, 0.12, 2.78), mat_m, Vector3(-21.6, 0.067, WALL_FACE_Z + 1.4), false, false)
	block(Vector3(2.78, 0.12, 13.5), mat_m, Vector3(WALL_FACE_X + 1.4, 0.071, 11.9), false, false)
	# --- the lookout deck ---
	var dc := Vector3(DECK.position.x + DECK.size.x * 0.5, 0, DECK.position.y + DECK.size.y * 0.5)
	block(Vector3(DECK.size.x, 0.7, DECK.size.y), wood, Vector3(dc.x, DECK_TOP - 0.35, dc.z))
	for k in 6:
		block(Vector3(DECK.size.x - 0.03, 0.02, 0.06), mat(Color(0.4, 0.25, 0.13)), Vector3(dc.x, DECK_TOP + 0.005, DECK.position.y + 0.36 + k * 0.67), false, false)
	var dx1 := DECK.position.x + DECK.size.x
	var dz1 := DECK.position.y + DECK.size.y
	for p in [Vector2(dx1 - 0.2, dz1 - 0.2), Vector2(dx1 - 0.2, DECK.position.y + 2.3), Vector2(DECK.position.x + 2.8, dz1 - 0.2)]:
		block(Vector3(0.35, DECK_TOP - 0.6, 0.35), wood, Vector3(p.x, (DECK_TOP - 0.6) * 0.5 - 0.03, p.y))
	# railings, with gaps where the two routes arrive and at the zipline corner
	var rail := mat(Color(1.0, 0.8, 0.15), 0.5, 0.3)
	_rail(Vector3(dx1 - 0.05, DECK_TOP, 2.25), Vector3(dx1 - 0.05, DECK_TOP, 3.5), rail)
	_rail(Vector3(DECK.position.x + 1.2, DECK_TOP, dz1 - 0.05), Vector3(-28.3, DECK_TOP, dz1 - 0.05), rail)
	# a flag on top
	block(Vector3(0.08, 3.2, 0.08), iron, Vector3(DECK.position.x + 0.5, DECK_TOP + 1.58, DECK.position.y + 0.5), false)
	var flag := block(Vector3(1.2, 0.7, 0.03), mat(Color(1.0, 0.85, 0.2), 0.6, 0.0, 0.3), Vector3(DECK.position.x + 1.12, DECK_TOP + 2.8, DECK.position.y + 0.5), false)
	flag.set_meta("flag", true)
	# the bell
	bell = Bell.new(); add_child(bell); bell.position = Vector3(DECK.position.x + 1.0, DECK_TOP, DECK.position.y + 2.2); bell.build(self)
	# the zipline
	zipline = ZipLine.new(); add_child(zipline); zipline.build(ZIP_A, ZIP_B)
	# a warm lamp over the deck
	var dl := OmniLight3D.new(); dl.light_color = Color(1.0, 0.85, 0.6); dl.light_energy = 1.8; dl.omni_range = 8.0
	dl.position = Vector3(dc.x, DECK_TOP + 2.4, dc.z); add_child(dl)
	# --- lights: street lamps, coloured uplights, party lights ---
	var lamps := [[Vector3(-21.0, 0, 6.5), Color(1.0, 0.78, 0.45)], [Vector3(-29.5, 0, 14.0), Color(0.6, 0.85, 1.0)],
		[Vector3(-24.0, 0, 18.0), Color(1.0, 0.6, 0.85)], [Vector3(-15.8, 0, 7.5), Color(0.7, 1.0, 0.6)]]
	for lp in lamps:
		Playground.street_lamp(self, lp[0], lp[1])
	_uplight(Vector3(-21.5, 0.2, 6.0), Vector3(-21.5, 6.0, WALL_FACE_Z), Color(0.55, 1.0, 0.6))
	_uplight(Vector3(-25.5, 0.2, 13.0), Vector3(WALL_FACE_X, 6.0, 13.0), Color(1.0, 0.55, 0.5))
	for lp in [Vector3(dx1 - 0.2, DECK_TOP, 2.3), Vector3(DECK.position.x + 2.8, DECK_TOP, dz1 - 0.2)]:
		block(Vector3(0.1, 1.5, 0.1), iron, lp + Vector3(0, 0.73, 0), false)
	_party_lights(Vector3(dx1 - 0.2, DECK_TOP + 1.45, 2.3), Vector3(-21.0, 4.3, 6.5))
	_party_lights(Vector3(DECK.position.x + 2.8, DECK_TOP + 1.45, dz1 - 0.2), Vector3(-29.5, 4.3, 14.0))
	_party_lights(Vector3(-21.0, 4.3, 6.5), Vector3(-15.8, 4.3, 7.5))
	_sign(Vector3(-19.0, 0, 9.5), -25.0)

## Decorative little holds all over both walls (one draw call per wall).
func _little_holds() -> void:
	var cols := [Color(0.95, 0.8, 0.2), Color(0.95, 0.45, 0.15), Color(0.6, 0.35, 0.85), Color(0.95, 0.95, 0.95),
		Color(0.2, 0.75, 0.9), Color(0.95, 0.45, 0.65), Color(0.25, 0.25, 0.3)]
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	for wall in 2:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
		var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 8; sm.rings = 4; sm.is_hemisphere = true
		mm.mesh = sm
		mm.instance_count = 110
		for k in mm.instance_count:
			var s := Vector3(rng.randf_range(0.09, 0.2), rng.randf_range(0.07, 0.16), rng.randf_range(0.06, 0.12))
			var y := rng.randf_range(0.4, 10.0)
			var bs := Basis()
			var pos: Vector3
			if wall == 0:
				pos = Vector3(rng.randf_range(-33.4, -15.6), y, WALL_FACE_Z)
				bs = Basis(Vector3(1, 0, 0), PI / 2) * Basis(Vector3.UP, rng.randf() * TAU)
			else:
				pos = Vector3(WALL_FACE_X, y, rng.randf_range(1.2, 20.3))
				bs = Basis(Vector3(0, 0, 1), -PI / 2) * Basis(Vector3.UP, rng.randf() * TAU)
				s = Vector3(s.z, s.y, s.x)      # thin in x: it sticks out of a wall facing +x
			mm.set_instance_transform(k, Transform3D(bs.scaled(s), pos))
			mm.set_instance_color(k, cols[rng.randi() % cols.size()])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
		var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.6
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _rail(a: Vector3, b: Vector3, m: Material) -> void:
	var d := b - a
	var len := d.length()
	var n := maxi(1, int(len / 1.2))
	for k in n + 1:
		var p := a + d * (float(k) / n)
		block(Vector3(0.08, 1.05, 0.08), m, p + Vector3(0, 0.52, 0), false)
	var mid := (a + b) * 0.5
	var bar := block(Vector3(0.07, 0.07, len) if absf(d.z) > absf(d.x) else Vector3(len, 0.07, 0.07), m, mid + Vector3(0, 1.05, 0), false)
	bar.set_meta("rail", true)
	block(Vector3(0.05, 0.05, len) if absf(d.z) > absf(d.x) else Vector3(len, 0.05, 0.05), m, mid + Vector3(0, 0.55, 0), false)
	# an invisible fence so you don't tumble off the edge by accident
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
	bs.size = Vector3(0.12, 1.2, len) if absf(d.z) > absf(d.x) else Vector3(len, 1.2, 0.12)
	cs.shape = bs; sb.add_child(cs); add_child(sb); sb.position = mid + Vector3(0, 0.6, 0)

func _badge(at: Vector3, yaw: float, c: Color, text: String) -> void:
	var n := Node3D.new(); add_child(n); n.position = at; n.rotation.y = yaw
	var d := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.55; cm.height = 0.05
	d.mesh = cm; d.material_override = mat(c, 0.5, 0.0, 0.8); d.rotation.x = PI / 2; n.add_child(d)
	var lb := Label3D.new(); lb.text = text; lb.font_size = 54; lb.outline_size = 10
	lb.modulate = Color(1, 1, 1); lb.outline_modulate = Color(0, 0, 0, 0.8); lb.position = Vector3(0, 0, 0.04)
	SignText.fit(lb, 0.85, 0.62)
	n.add_child(lb)

func _uplight(at: Vector3, target: Vector3, c: Color) -> void:
	var sl := SpotLight3D.new(); sl.light_color = c; sl.light_energy = 7.0; sl.spot_range = 16.0; sl.spot_angle = 34.0
	add_child(sl); sl.position = at
	sl.look_at(target)
	var can := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.22; cm.bottom_radius = 0.16; cm.height = 0.35
	can.mesh = cm; can.material_override = mat(Color(0.1, 0.1, 0.12), 0.5, 0.6); can.position = at + Vector3(0, -0.02, 0); add_child(can)

## A sagging string of coloured bulbs between two points (glowing, no extra lights).
func _party_lights(a: Vector3, b: Vector3) -> void:
	var cols := [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.4), Color(0.35, 0.6, 1.0), Color(1.0, 0.45, 0.9)]
	var n := int(a.distance_to(b) / 0.7)
	var wire := mat(Color(0.05, 0.05, 0.05))
	var prev := a
	for k in n + 1:
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.9, 0)
		if k > 0:
			var seg := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012
			cm.height = prev.distance_to(p); cm.radial_segments = 4; seg.mesh = cm; seg.material_override = wire
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(seg); seg.position = (prev + p) * 0.5
			seg.basis = Basis(Quaternion(Vector3.UP, (p - prev).normalized()))
		if k > 0 and k < n:
			var bl := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16; sm.radial_segments = 8; sm.rings = 4
			bl.mesh = sm; bl.material_override = mat(cols[k % cols.size()], 0.3, 0.0, 3.0)
			bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bl); bl.position = p - Vector3(0, 0.1, 0)
		prev = p

func _sign(at: Vector3, yaw_deg: float) -> void:
	var n := Node3D.new(); add_child(n); n.position = at; n.rotation_degrees.y = yaw_deg
	var wood := mat(Color(0.6, 0.4, 0.22), 0.9)
	var frame := mat(Color(0.9, 0.25, 0.2), 0.5)
	block(Vector3(0.12, 2.1, 0.12), wood, Vector3(-0.95, 1.03, -0.07), true, true, n)
	block(Vector3(0.12, 2.1, 0.12), wood, Vector3(0.95, 1.03, -0.07), false, true, n)
	block(Vector3(2.2, 1.4, 0.08), mat(Color(1.0, 0.93, 0.6), 0.8, 0.0, 0.25), Vector3(0, 1.75, 0.05), false, true, n)
	block(Vector3(2.32, 0.1, 0.12), frame, Vector3(0, 2.47, 0.05), false, true, n)
	block(Vector3(2.32, 0.1, 0.12), frame, Vector3(0, 1.03, 0.05), false, true, n)
	for sx in [-1.0, 1.0]:
		block(Vector3(0.1, 1.36, 0.12), frame, Vector3(sx * 1.1, 1.75, 0.05), false, true, n)
	var title := Label3D.new(); title.text = "CLIMBING WALL!"; title.font_size = 64
	title.modulate = Color(0.85, 0.15, 0.12); title.outline_size = 10; title.outline_modulate = Color(1, 1, 1)
	title.position = Vector3(0, 2.18, 0.1)
	SignText.fit(title, 2.0, 0.4)
	n.add_child(title)
	var lb := Label3D.new()
	lb.text = "GREEN = easy     RED = tricky (jump!)\nRing the bell at the top,\nthen ride the zipline down!"
	lb.font_size = 48; lb.modulate = Color(0.15, 0.25, 0.55); lb.outline_size = 0
	lb.position = Vector3(0, 1.58, 0.1)
	SignText.fit(lb, 2.0, 0.78)
	n.add_child(lb)

func _physics_process(delta: float) -> void:
	_clock += delta
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.2
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.is_on_floor():
		return
	for pair in [[green_holds, "green"], [red_holds, "red"]]:
		for h in pair[0]:
			var hp: Vector3 = (h as Node3D).global_position
			if absf(p.global_position.y - float(h.get_meta("top"))) < 0.3 and Vector2(p.global_position.x - hp.x, p.global_position.z - hp.z).length() < 0.9:
				if float(h.get_meta("top")) > 3.0:
					_route = pair[1]
					_route_t = _clock

## Somebody rang the bell at the top.
func rang(by: Player) -> void:
	FX.burst(bell.global_position + Vector3(0, 1.6, 0), Color(1.0, 0.85, 0.3), 50, 5.0, 0.15, 1.0, 1.0)
	for k in 3:
		var c: Color = [GREEN, RED, Color(0.4, 0.7, 1.0)][k]
		FX.burst(bell.global_position + Vector3(randf_range(-2, 2), 4.0 + k, randf_range(-2, 2)), c, 40, 6.0, 0.15, 1.2, 0.5)
	var red := _clock - _route_t < 60.0 and _route == "red"
	if red and not Game.flags.get("climb_red", false):
		Game.flags["climb_red"] = true
		Game.add_gold(80)
		Game.add_xp(100)
		Game.say("You beat the RED route! That's the tricky one. +80 gold!", Color(1.0, 0.5, 0.45))
	elif not Game.flags.get("climb_top", false):
		Game.add_gold(40)
		Game.add_xp(60)
		Game.say("You climbed the wall! +40 gold. Now ride the zipline down!", Color(1.0, 0.9, 0.4))
	else:
		Game.say("DING! Top of the wall!", Color(1.0, 0.9, 0.4))
	Game.flags["climb_top"] = true
	_route = ""
	if by:
		by.add_trauma(0.15)


## Ring it with USE.
class Bell extends Node3D:
	var wall: ClimbWall
	var _swing := 0.0
	var _t := 0.0
	var _cup: Node3D
	var _cool := 0.0
	func build(w: ClimbWall) -> void:
		wall = w
		add_to_group("interactable")
		var iron := ClimbWall.mat(Color(0.1, 0.1, 0.12), 0.45, 0.7)
		var brass := ClimbWall.mat(Color(0.9, 0.7, 0.3), 0.3, 0.85)
		for sx in [-0.55, 0.55]:
			Playground.cyl(self, 0.05, 0.06, 2.3, iron, Vector3(sx, 1.15, 0))
		Playground.cyl(self, 0.05, 0.05, 1.2, iron, Vector3(0, 2.3, 0), Vector3(0, 0, PI / 2))
		_cup = Node3D.new(); _cup.position = Vector3(0, 2.25, 0); add_child(_cup)
		Playground.cyl(_cup, 0.14, 0.36, 0.55, brass, Vector3(0, -0.32, 0))
		Playground.cyl(_cup, 0.0, 0.16, 0.12, brass, Vector3(0, -0.02, 0))
		var clapper := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.14
		clapper.mesh = sm; clapper.material_override = iron; clapper.position = Vector3(0, -0.62, 0); _cup.add_child(clapper)
	func can_interact() -> bool:
		return _cool <= 0.0
	func get_prompt() -> String:
		return "[E] Ring the bell!"
	func interact(by: Node) -> void:
		_cool = 1.0
		_swing = 0.7
		_t = 0.0
		Sfx.play_at("clang", global_position + Vector3(0, 2, 0), 0.0, 0.0)
		get_tree().create_timer(0.35).timeout.connect(func() -> void: Sfx.play_at("clang", global_position + Vector3(0, 2, 0), -4.0, 0.05))
		wall.rang(by as Player)
	func _process(delta: float) -> void:
		_cool -= delta
		_t += delta
		_swing = lerpf(_swing, 0.0, 1.0 - exp(-0.8 * delta))
		_cup.rotation.x = sin(_t * 9.0) * _swing


## Hang on with USE and whizz down the cable; JUMP lets go early.
class ZipLine extends Node3D:
	var a: Vector3
	var b: Vector3
	var _len := 1.0
	var _s := 0.0
	var _v := 0.0
	var _rider: Player
	var _trolley: Node3D
	var _cool := 0.0
	var rides := 0
	func build(from: Vector3, to: Vector3) -> void:
		a = from; b = to
		_len = a.distance_to(b)
		process_physics_priority = 100
		add_to_group("interactable")
		var iron := ClimbWall.mat(Color(0.1, 0.1, 0.12), 0.45, 0.7)
		var steel := ClimbWall.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8)
		# end poles
		Playground.cyl(get_parent(), 0.12, 0.14, 2.6, iron, a + Vector3(0.1, -1.3, 0.1))
		Playground.cyl(get_parent(), 0.16, 0.2, b.y + 0.4, iron, Vector3(b.x + 0.2, (b.y + 0.4) * 0.5, b.z + 0.2))
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.22; cy.height = b.y + 0.4
		cs.shape = cy; sb.add_child(cs); get_parent().add_child(sb); sb.position = Vector3(b.x + 0.2, (b.y + 0.4) * 0.5, b.z + 0.2)
		# the cable
		var cable := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = _len
		cm.radial_segments = 6; cable.mesh = cm; cable.material_override = steel
		cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(cable); cable.position = (a + b) * 0.5
		cable.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		# the trolley and its handle bar
		_trolley = Node3D.new(); add_child(_trolley)
		Playground.box(_trolley, Vector3(0.22, 0.16, 0.3), ClimbWall.mat(Color(1.0, 0.75, 0.1), 0.5, 0.4), Vector3(0, 0, 0))
		Playground.cyl(_trolley, 0.02, 0.02, 1.2, iron, Vector3(0, -0.6, 0))
		Playground.cyl(_trolley, 0.04, 0.04, 0.7, ClimbWall.mat(Color(1.0, 0.3, 0.2), 0.5), Vector3(0, -1.2, 0), Vector3(0, 0, PI / 2))
		_place(0.0)
		var lb := Label3D.new(); lb.text = "ZIPLINE"; lb.font_size = 64; lb.pixel_size = 0.005; lb.outline_size = 10
		lb.modulate = Color(1.0, 0.85, 0.3); lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		get_parent().add_child(lb); lb.position = a + Vector3(0.3, 0.6, 0.3)
	## Interact from where the handle hangs (just above the deck).
	func _place(s: float) -> void:
		var p := a.lerp(b, s / _len)
		_trolley.global_position = p
		global_position = p - Vector3(0, HANG - 0.3, 0)
		_trolley.global_position = p
	func can_interact() -> bool:
		return _rider == null and _cool <= 0.0 and _s < 0.01
	func get_prompt() -> String:
		return "[E] Ride the zipline!"
	func interact(by: Node) -> void:
		if not (by is Player) or _rider != null:
			return
		_rider = by as Player
		_rider.ride_vehicle(self, "Jump_Idle")
		_s = 0.0; _v = 2.0
		rides += 1
		Sfx.play("whistle", -6.0, 0.1)
		Game.say("Wheeee! (JUMP to let go)", Color(1.0, 0.85, 0.5))
	func _physics_process(delta: float) -> void:
		_cool -= delta
		if _rider == null:
			if _s > 0.0:
				_s = maxf(0.0, _s - delta * 6.0)       # the trolley rolls back up for the next ride
				_place(_s)
			return
		if not is_instance_valid(_rider) or _rider.dead or _rider.vehicle != self:
			_rider = null
			return
		_v = minf(_v + 7.0 * delta, 13.0)
		_s += _v * delta
		var dir := (b - a).normalized()
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		var done := _s >= _len - 1.6
		_s = minf(_s, _len - 1.6)
		_place(_s)
		_rider.global_position = a.lerp(b, _s / _len) - Vector3(0, HANG, 0)
		_rider.facing = atan2(-flat.x, -flat.z)
		_rider.body.rotation.y = _rider.facing
		if done or Input.is_action_just_pressed("jump"):
			var r := _rider
			_rider = null
			_cool = 1.5
			r.leave_vehicle(flat * 1.2 + Vector3(0, 2.0, 0))
			Sfx.play("whistle", -10.0, 0.25)
