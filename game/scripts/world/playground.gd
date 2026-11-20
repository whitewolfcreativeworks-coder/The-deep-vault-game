extends Node3D
class_name Playground
## A little playground on the dark east side of the Outpost, lit by street
## lamps: a merry-go-round you can spin and ride, a swing set you can sit on and
## jump off at the top, a trampoline, a sandbox, a bench and a sign. Plus a
## stone statue of the hooded Rogue at the back of the clearing.

const RUBBER := Color(0.78, 0.36, 0.26)
const RED := Color(0.85, 0.18, 0.15)
const YELLOW := Color(1.0, 0.8, 0.15)
const BLUE := Color(0.2, 0.45, 0.9)
const GREEN := Color(0.25, 0.7, 0.35)

static func m(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new(); mt.albedo_color = c; mt.roughness = rough; mt.metallic = metal
	return mt

static var _jit := 0

static func box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, collide := false) -> MeshInstance3D:
	# every box is a few millimetres different in size and height, so no two faces
	# ever sit exactly on top of each other (that makes them flicker)
	# (steps of whole millimetres chosen so every bottom, top and side lands on its own value)
	_jit += 1
	var j := 0.012 * float(_jit % 4)
	var grow := Vector3(j if size.x >= 0.25 else j * 0.25, j if size.y >= 0.25 else j * 0.25, j if size.z >= 0.25 else j * 0.25)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	bm.size = size + grow
	mi.mesh = bm; mi.material_override = mat; mi.position = pos + Vector3(0, 0.004 + 0.008 * float(_jit % 5) + (grow.y - j) * 0.5, 0); mi.rotation = rot
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
		cs.shape = bs; sb.add_child(cs); mi.add_child(sb)
	return mi

static func cyl(parent: Node3D, r0: float, r1: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r0; cm.bottom_radius = r1; cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm; mi.material_override = mat; mi.position = pos; mi.rotation = rot
	parent.add_child(mi)
	return mi

## A tall iron street lamp with a warm glowing lantern on top.
static func street_lamp(parent: Node3D, pos: Vector3, color := Color(1.0, 0.78, 0.45), height := 3.6) -> Node3D:
	var n := Node3D.new(); parent.add_child(n); n.position = pos
	var iron := m(Color(0.08, 0.08, 0.09), 0.5, 0.6)
	cyl(n, 0.2, 0.26, 0.5, iron, Vector3(0, 0.25, 0))
	cyl(n, 0.06, 0.08, height, iron, Vector3(0, height * 0.5, 0))
	cyl(n, 0.12, 0.12, 0.12, iron, Vector3(0, height * 0.75, 0))
	var glass := StandardMaterial3D.new(); glass.albedo_color = color; glass.emission_enabled = true
	glass.emission = color; glass.emission_energy_multiplier = 3.0; glass.roughness = 0.2
	cyl(n, 0.16, 0.1, 0.42, glass, Vector3(0, height + 0.22, 0), Vector3.ZERO, 6)
	cyl(n, 0.02, 0.26, 0.22, iron, Vector3(0, height + 0.54, 0), Vector3.ZERO, 6)
	cyl(n, 0.1, 0.12, 0.06, iron, Vector3(0, height, 0), Vector3.ZERO, 6)
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 2.4; l.omni_range = 11.0
	l.omni_attenuation = 1.2
	l.position = Vector3(0, height + 0.1, 0); n.add_child(l)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.18; cy.height = height
	cs.shape = cy; cs.position.y = height * 0.5; sb.add_child(cs); n.add_child(sb)
	return n

static func build(parent: Node3D) -> Playground:
	var p := Playground.new()
	p.name = "Playground"
	parent.add_child(p)
	p._build()
	return p

func _build() -> void:
	# soft red rubber ground with a yellow border
	box(self, Vector3(15.4, 0.06, 34.0), m(RUBBER, 0.95), Vector3(24.7, 0.03, 22.0))
	for z in [4.9, 39.1]:
		box(self, Vector3(15.6, 0.16, 0.3), m(YELLOW), Vector3(24.7, 0.08, z))
	for x in [16.9, 32.5]:
		box(self, Vector3(0.3, 0.16, 34.5), m(YELLOW), Vector3(x, 0.08, 22.0))
	# street lamps: around the playground and in the dark corners of the clearing
	for lp in [Vector3(17.5, 0, 6.0), Vector3(17.5, 0, 22.0), Vector3(17.5, 0, 38.0),
			Vector3(31.8, 0, 6.0), Vector3(31.8, 0, 22.0), Vector3(31.8, 0, 38.0),
			Vector3(-31.0, 0, 39.0)]:
		street_lamp(self, lp)
	var mgr := MerryGoRound.new(); mgr.position = Vector3(24.5, 0, 12.5); add_child(mgr); mgr.build()
	var sw := SwingSet.new(); add_child(sw); sw.position = Vector3(24.5, 0, 24.0); sw.build()
	var tr := Trampoline.new(); add_child(tr); tr.position = Vector3(21.0, 0, 33.5); tr.build()
	_sandbox(Vector3(28.5, 0, 33.5))
	_bench(Vector3(31.2, 0, 17.0), -90.0)
	_sign(Vector3(18.0, 0, 9.0), -60.0, "BOBEK'S\nPLAYGROUND\nno goblins!")
	_statue(Vector3(0, 0, 37.6), 0.0)      # facing straight down the clearing to the dungeon entrance

func _sandbox(at: Vector3) -> void:
	var n := Node3D.new(); add_child(n); n.position = at + Vector3(0, 0.08, 0)     # sits on top of the rubber mat
	var wood := m(Color(0.6, 0.4, 0.22), 0.9)
	for s in [[Vector3(3.2, 0.35, 0.2), Vector3(0, 0.17, -1.5)], [Vector3(3.2, 0.35, 0.2), Vector3(0, 0.17, 1.5)],
			[Vector3(0.2, 0.35, 3.2), Vector3(-1.5, 0.17, 0)], [Vector3(0.2, 0.35, 3.2), Vector3(1.5, 0.17, 0)]]:
		box(n, s[0], wood, s[1], Vector3.ZERO, true)
	box(n, Vector3(2.8, 0.2, 2.8), m(Color(0.93, 0.82, 0.55), 1.0), Vector3(0, 0.1, 0))
	# a sandcastle, a bucket and a spade
	var sand := m(Color(0.88, 0.74, 0.46), 1.0)
	box(n, Vector3(0.8, 0.35, 0.8), sand, Vector3(-0.3, 0.37, -0.2))
	for c in [Vector3(-0.65, 0.5, -0.55), Vector3(0.05, 0.5, -0.55), Vector3(-0.65, 0.5, 0.15), Vector3(0.05, 0.5, 0.15)]:
		cyl(n, 0.13, 0.15, 0.55, sand, c)
		cyl(n, 0.0, 0.16, 0.2, m(RED), c + Vector3(0, 0.37, 0))
	cyl(n, 0.2, 0.15, 0.3, m(BLUE, 0.5), Vector3(0.75, 0.35, 0.6))
	box(n, Vector3(0.12, 0.04, 0.6), m(YELLOW, 0.5), Vector3(0.6, 0.23, -0.6), Vector3(0, 0.6, 0.3))

func _bench(at: Vector3, yaw_deg: float) -> void:
	var n := Node3D.new(); add_child(n); n.position = at; n.rotation_degrees.y = yaw_deg
	var wood := m(Color(0.55, 0.33, 0.18), 0.85)
	var iron := m(Color(0.1, 0.1, 0.1), 0.5, 0.5)
	box(n, Vector3(2.0, 0.08, 0.5), wood, Vector3(0, 0.48, 0), Vector3.ZERO, true)
	box(n, Vector3(2.0, 0.4, 0.06), wood, Vector3(0, 0.82, 0.24))
	for x in [-0.85, 0.85]:
		box(n, Vector3(0.08, 0.48, 0.45), iron, Vector3(x, 0.24, 0))

## A cheerful painted sign: a sunny board in a blue frame on two posts, the words
## sized to fit the board.
func _sign(at: Vector3, yaw_deg: float, text: String) -> void:
	var n := Node3D.new(); add_child(n); n.position = at; n.rotation_degrees.y = yaw_deg
	var wood := m(Color(0.6, 0.4, 0.22), 0.9)
	var frame := m(BLUE, 0.5)
	for sx in [-0.85, 0.85]:
		box(n, Vector3(0.12, 1.9, 0.12), wood, Vector3(sx, 0.95, -0.02))
	var face := m(Color(1.0, 0.93, 0.6), 0.8)
	face.emission_enabled = true; face.emission = Color(1.0, 0.9, 0.6); face.emission_energy_multiplier = 0.25   # readable at night
	box(n, Vector3(1.9, 1.15, 0.08), face, Vector3(0, 1.62, 0.05))
	box(n, Vector3(2.02, 0.1, 0.12), frame, Vector3(0, 2.22, 0.05))
	box(n, Vector3(2.02, 0.1, 0.12), frame, Vector3(0, 1.02, 0.05))
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.1, 1.08, 0.12), frame, Vector3(sx * 0.95, 1.62, 0.05))      # ends tucked inside the top and bottom bars
	var lb := Label3D.new(); lb.text = text; lb.font_size = 64
	lb.modulate = Color(0.85, 0.15, 0.12); lb.outline_size = 10; lb.outline_modulate = Color(1, 1, 1)
	lb.position = Vector3(0, 1.62, 0.1)
	SignText.fit(lb, 1.75, 1.0)
	n.add_child(lb)

## The hooded Rogue (Bobek's hero), carved in pale stone on a tall plinth. It
## faces into the clearing, so you see it from the front as you come through the
## portal, flanked by two fire bowls and lit from below like a monument.
func _statue(at: Vector3, yaw: float) -> void:
	var n := Node3D.new(); n.name = "RogueStatue"; add_child(n); n.position = at; n.rotation.y = yaw
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.8, 0.78, 0.74); stone.roughness = 0.6
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.4, 0.38, 0.36); dark.roughness = 0.85
	var gold := StandardMaterial3D.new(); gold.albedo_color = Color(0.85, 0.66, 0.28); gold.metallic = 0.8; gold.roughness = 0.35
	box(n, Vector3(5.6, 0.45, 5.6), dark, Vector3(0, 0.22, 0), Vector3.ZERO, true)
	box(n, Vector3(4.6, 0.4, 4.6), stone, Vector3(0, 0.62, 0), Vector3.ZERO, true)
	box(n, Vector3(3.6, 2.2, 3.6), stone, Vector3(0, 1.92, 0), Vector3.ZERO, true)
	box(n, Vector3(4.1, 0.38, 4.1), dark, Vector3(0, 3.2, 0), Vector3.ZERO, true)
	box(n, Vector3(3.7, 0.12, 3.7), gold, Vector3(0, 3.44, 0))
	# the name plate on the front (the figure faces -Z)
	box(n, Vector3(2.7, 0.95, 0.08), gold, Vector3(0, 1.95, -1.83))
	var plate := Label3D.new(); plate.text = "THE HOODED ROGUE\nwho first braved the Deep Vault"
	plate.font_size = 64; plate.modulate = Color(0.25, 0.15, 0.05); plate.outline_size = 0
	plate.position = Vector3(0, 1.95, -1.9); plate.rotation.y = PI
	SignText.fit(plate, 2.6, 0.88)
	n.add_child(plate)
	var fig := CharacterModel.new()
	n.add_child(fig)
	fig.setup({"kind": "hero", "hero": "HoodedRogue", "show_hat": true, "weapon": "rusty_sword", "shield": "", "scale": 4.6})
	fig.position = Vector3(0, 3.5, 0)
	fig.set_process(false)
	if fig.anim and fig.anim.has_animation("Cheer"):
		fig.anim.play("Cheer")
		fig.anim.seek(0.55, true)
		fig.anim.pause()
	for mi in fig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = stone
		(mi as MeshInstance3D).material_overlay = null
	# lit from below like a monument
	for sx in [-1.0, 1.0]:
		var sl := SpotLight3D.new(); sl.light_color = Color(1.0, 0.9, 0.75); sl.light_energy = 9.0
		sl.spot_range = 16.0; sl.spot_angle = 28.0
		n.add_child(sl)
		sl.position = Vector3(sx * 3.2, 0.5, -5.5)
		sl.look_at(n.global_position + Vector3(0, 6.5, 0))
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(2.8, 8.0, 2.8)
	cs.shape = bs; cs.position = Vector3(0, 7.5, 0); sb.add_child(cs); n.add_child(sb)

## A huge fire bowl on a stone cap, for the tops of the walls either side of the
## statue: a wide bowl of coals with roaring flames, embers and a warm light
## that reaches across the clearing.
static func giant_brazier(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new(); n.name = "GiantBrazier"; n.add_to_group("giant_brazier"); parent.add_child(n); n.position = at
	var dark := m(Color(0.28, 0.26, 0.25), 0.85)
	var iron := m(Color(0.16, 0.14, 0.13), 0.45, 0.7)
	var gold := m(Color(0.85, 0.62, 0.25), 0.35, 0.8)
	box(n, Vector3(2.0, 0.5, 1.6), dark, Vector3(0, 0.25, 0))
	cyl(n, 0.55, 0.75, 0.5, iron, Vector3(0, 0.75, 0), Vector3.ZERO, 20)
	cyl(n, 1.45, 0.75, 0.95, iron, Vector3(0, 1.45, 0), Vector3.ZERO, 24)
	var rim := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 1.38; tm.outer_radius = 1.56; tm.rings = 32
	rim.mesh = tm; rim.material_override = gold; rim.position = Vector3(0, 1.92, 0); n.add_child(rim)
	var coals := StandardMaterial3D.new(); coals.albedo_color = Color(0.25, 0.05, 0.0); coals.emission_enabled = true
	coals.emission = Color(1.0, 0.35, 0.05); coals.emission_energy_multiplier = 2.5
	cyl(n, 1.3, 1.3, 0.1, coals, Vector3(0, 1.82, 0), Vector3.ZERO, 24)
	# the flames: a wide body of big soft flames and a hot bright core
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1)); ramp.set_color(1, Color(0.7, 0.1, 0.02, 0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.15, 0.95))
	var curve := Curve.new(); curve.add_point(Vector2(0, 0.5)); curve.add_point(Vector2(0.25, 1.0)); curve.add_point(Vector2(1, 0.0))
	for layer in 2:
		var f := CPUParticles3D.new()
		f.amount = 70 if layer == 0 else 40
		f.lifetime = 1.1 if layer == 0 else 0.7
		f.mesh = FX.quad(1.1 if layer == 0 else 0.6)
		f.material_override = FX.glow_material(Color(1.0, 0.55, 0.2) if layer == 0 else Color(1.0, 0.85, 0.45), 2.4)
		f.direction = Vector3.UP; f.spread = 10.0
		f.initial_velocity_min = 2.0; f.initial_velocity_max = 3.8 if layer == 0 else 3.0
		f.gravity = Vector3(0, 1.5, 0)
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		f.emission_sphere_radius = 0.95 if layer == 0 else 0.5
		f.scale_amount_min = 0.6; f.scale_amount_max = 1.1
		f.scale_amount_curve = curve
		f.color_ramp = ramp
		f.position = Vector3(0, 1.95, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(f)
	var e := CPUParticles3D.new(); e.amount = 40; e.lifetime = 3.0
	e.mesh = FX.quad(0.06); e.material_override = FX.glow_material(Color(1.0, 0.6, 0.2), 3.0)
	e.direction = Vector3.UP; e.spread = 30.0; e.initial_velocity_min = 1.5; e.initial_velocity_max = 3.5
	e.gravity = Vector3(0, 0.3, 0); e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; e.emission_sphere_radius = 1.0
	e.color_ramp = FX._fade_ramp(Color(1.0, 0.6, 0.2)); e.position = Vector3(0, 2.2, 0); n.add_child(e)
	var smoke := CPUParticles3D.new(); smoke.amount = 16; smoke.lifetime = 4.0
	smoke.mesh = FX.quad(1.6); smoke.material_override = FX.beam_material(Color(0.12, 0.1, 0.1), 1.0, 0.25, false)
	smoke.direction = Vector3.UP; smoke.spread = 15.0; smoke.initial_velocity_min = 1.0; smoke.initial_velocity_max = 1.8
	smoke.gravity = Vector3(0.2, 0.2, 0); smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; smoke.emission_sphere_radius = 0.6
	smoke.color_ramp = FX._fade_ramp(Color(0.2, 0.18, 0.18)); smoke.position = Vector3(0, 4.2, 0); n.add_child(smoke)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.6, 0.28); l.light_energy = 4.5; l.omni_range = 22.0
	l.omni_attenuation = 1.1; l.position = Vector3(0, 3.0, 0)
	l.set_script(load("res://scripts/world/flicker.gd"))
	n.add_child(l)
	FireHurt.attach(n, 1.3, 1.2, Vector3(0, 2.2, 0))      # (Insane only: any fire hurts)
	# a gentle crackle, not a roar (Jason, Nov 20: "like a crackling fire"); the two
	# bowls start at different points so they don't double up
	var snd := Sfx.loop_on(n, "loop_campfire", -9.0, 3.5, 20.0)
	if snd:
		snd.autoplay = false
		snd.play.call_deferred(randf_range(0.0, 8.0))
	return n


## Spin it with USE; stand on it and it carries you round.
class MerryGoRound extends AnimatableBody3D:
	var spin := 0.35
	var _top: Node3D
	func build() -> void:
		add_to_group("interactable")
		sync_to_physics = true
		var base := Playground.cyl(get_parent(), 0.5, 0.6, 0.28, Playground.m(Color(0.3, 0.3, 0.32), 0.6, 0.4), position + Vector3(0, 0.14, 0))
		base.name = "MerryBase"
		var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 2.3; cy.height = 0.2
		cs.shape = cy; cs.position.y = 0.32; add_child(cs)
		_top = Node3D.new(); add_child(_top)
		var cols := [Playground.RED, Playground.YELLOW, Playground.BLUE, Playground.GREEN, Playground.RED, Playground.YELLOW]
		Playground.cyl(_top, 2.3, 2.3, 0.18, Playground.m(Color(0.85, 0.85, 0.88), 0.4, 0.5), Vector3(0, 0.32, 0), Vector3.ZERO, 32)
		for k in 6:
			var a := k * TAU / 6.0
			# coloured wedges painted on the deck
			var wedge := Playground.box(_top, Vector3(0.9, 0.02, 2.0), Playground.m(cols[k], 0.5), Vector3(sin(a) * 1.15, 0.42 + k * 0.006, cos(a) * 1.15), Vector3(0, a, 0))
			wedge.name = "Wedge%d" % k
			# a bent handlebar
			var hb := Node3D.new(); _top.add_child(hb); hb.rotation.y = a + TAU / 12.0
			var bar_m := Playground.m(Color(0.9, 0.9, 0.92), 0.3, 0.7)
			Playground.cyl(hb, 0.04, 0.04, 0.9, bar_m, Vector3(0, 0.85, 1.7))
			Playground.cyl(hb, 0.04, 0.04, 1.4, bar_m, Vector3(0, 1.3, 1.0), Vector3(PI / 2, 0, 0))
		Playground.cyl(_top, 0.14, 0.14, 1.4, Playground.m(Playground.YELLOW, 0.4, 0.4), Vector3(0, 1.1, 0))
		Playground.cyl(_top, 0.0, 0.4, 0.4, Playground.m(Playground.RED, 0.5), Vector3(0, 2.0, 0))
	func get_prompt() -> String:
		return "[E] Spin the merry-go-round!"
	func interact(_by: Node) -> void:
		spin = minf(spin + 2.2, 4.5)
		Sfx.play_at("whistle", global_position, -10.0, 0.2)
		FX.burst(global_position + Vector3(0, 0.8, 0), Color(1.0, 0.9, 0.5), 20, 3.0, 0.1, 0.6, 0.0)
	func _physics_process(delta: float) -> void:
		rotation.y = fposmod(rotation.y + spin * delta, TAU)
		spin = lerpf(spin, 0.35, 1.0 - exp(-0.25 * delta))


## Two swings. Sit with USE, swing higher and higher, and JUMP to leap off.
class SwingSet extends Node3D:
	func build() -> void:
		var frame := Playground.m(Playground.BLUE, 0.4, 0.5)
		for x in [-2.6, 2.6]:
			for z in [-1.1, 1.1]:
				Playground.cyl(self, 0.07, 0.07, 3.6, frame, Vector3(x, 1.65, z * 0.55), Vector3(z * 0.3, 0, 0))
		Playground.cyl(self, 0.08, 0.08, 5.6, frame, Vector3(0, 3.3, 0), Vector3(0, 0, PI / 2))
		for sx in [-1.25, 1.25]:
			var s := Swing.new(); add_child(s); s.position = Vector3(sx, 3.3, 0); s.build()

class Swing extends Node3D:
	const LEN := 2.55
	var angle := 0.0
	var amp := 0.0
	var _t := 0.0
	var _rider: Player
	var _pivot: Node3D
	var _seat: MeshInstance3D
	var _cool := 0.0
	func build() -> void:
		add_to_group("interactable")
		_pivot = Node3D.new(); add_child(_pivot)
		var chain := Playground.m(Color(0.7, 0.7, 0.72), 0.3, 0.8)
		for sx in [-0.3, 0.3]:
			Playground.cyl(_pivot, 0.02, 0.02, LEN, chain, Vector3(sx, -LEN * 0.5, 0))
		_seat = Playground.box(_pivot, Vector3(0.75, 0.07, 0.4), Playground.m(Playground.RED, 0.6), Vector3(0, -LEN, 0))
		process_physics_priority = 100
	func can_interact() -> bool:
		return _rider == null and _cool <= 0.0
	func get_prompt() -> String:
		return "[E] Sit on the swing"
	func interact(by: Node) -> void:
		if not (by is Player) or _rider != null:
			return
		_rider = by as Player
		_rider.ride_vehicle(self, "Sit_Chair_Idle")
		_rider.facing = global_rotation.y + PI
		_t = 0.0
		amp = 0.15
		Game.say("Wheee! Swing higher... press JUMP to leap off at the top!", Color(1.0, 0.85, 0.5))
	func _physics_process(delta: float) -> void:
		_cool -= delta
		if _rider == null:
			angle = lerpf(angle, 0.0, 1.0 - exp(-1.5 * delta))
			_pivot.rotation.x = angle
			return
		if not is_instance_valid(_rider) or _rider.dead or _rider.vehicle != self:
			_rider = null
			return
		_t += delta
		amp = minf(amp + delta * 0.12, 1.05)       # pump higher and higher
		var w := sqrt(9.8 / LEN)
		angle = amp * sin(_t * w)
		_pivot.rotation.x = angle
		var seat := _seat.global_position
		var fwd := global_transform.basis.z
		_rider.global_position = seat - Vector3(0, 0.46, 0) - fwd * 0.05
		_rider.facing = atan2(fwd.x, fwd.z)
		_rider.body.rotation.y = _rider.facing
		if _t > 0.4 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact")):
			# leap off with the swing's speed (huge at the bottom, a lob at the top)
			var vel := amp * w * LEN * cos(_t * w)
			var dir := global_transform.basis.z * (-1.0 if vel < 0 else 1.0)
			var launch := Vector3(-dir.x, 0, -dir.z) * absf(vel) * 0.9 + Vector3(0, 4.0 + absf(vel) * 0.4, 0)
			var r := _rider
			_rider = null
			_cool = 1.0
			r.leave_vehicle(launch)
			Sfx.play("whistle", -8.0, 0.2)


## Bounce! Hold JUMP as you land to go higher.
class Trampoline extends Node3D:
	const R := 1.9
	const TOP := 0.7
	var _mat_mi: MeshInstance3D
	var _boing := 0.0
	func build() -> void:
		process_physics_priority = 100
		var pad := Playground.m(Playground.BLUE, 0.5)
		var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = R - 0.15; tm.outer_radius = R + 0.2
		ring.mesh = tm; ring.material_override = pad; ring.position.y = TOP; ring.scale = Vector3(1, 0.6, 1); add_child(ring)
		_mat_mi = Playground.cyl(self, R - 0.1, R - 0.1, 0.04, Playground.m(Color(0.08, 0.08, 0.1), 0.6), Vector3(0, TOP - 0.02, 0), Vector3.ZERO, 32)
		for k in 6:
			var a := k * TAU / 6.0
			Playground.cyl(self, 0.05, 0.05, TOP, Playground.m(Color(0.75, 0.75, 0.78), 0.3, 0.7), Vector3(cos(a) * R, TOP * 0.5, sin(a) * R))
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = R + 0.1; cy.height = TOP
		cs.shape = cy; cs.position.y = TOP * 0.5; sb.add_child(cs); add_child(sb)
	func _physics_process(delta: float) -> void:
		_boing = maxf(0.0, _boing - delta * 4.0)
		_mat_mi.position.y = TOP - 0.02 - sin(_boing * PI) * 0.18
		var p := get_tree().get_first_node_in_group("player") as Player
		if p == null or p.dead or p.vehicle != null:
			return
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < R and p.is_on_floor() and absf(p.global_position.y - (global_position.y + TOP)) < 0.25 and p.velocity.y <= 0.5:
			p.velocity.y = 17.0 if Input.is_action_pressed("jump") else 12.0
			_boing = 1.0
			Sfx.play_at("pop", global_position + Vector3(0, TOP, 0), -6.0, 0.3)
			FX.burst(global_position + Vector3(0, TOP + 0.1, 0), Color(0.7, 0.85, 1.0), 12, 2.5, 0.08, 0.4, 0.0)
