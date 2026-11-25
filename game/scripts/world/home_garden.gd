extends Node3D
class_name HomeGarden
## THE GARDEN (Jason and his son, Nov 25): a fenced vegetable and flower garden
## beside the cabin, with six raised beds. (What grows, and what it gives you:
## GardenPlants.)
##   a bed        empty: plant a seed. Growing: water it (it grows twice as fast
##                while the soil is wet). Ripe (it sparkles): pick it!
##   seed box     by the gate: a gift of seeds the first time, then Tobble's seed
##                stand (buy more)
##   the cabin's breakfast table: eat what you've grown (HomeCabin)
## Plants grow while you play anywhere, even far away on an adventure.

const C := Vector3(10.5, 0, -3.8)                 # the garden's middle
const X0 := 6.6
const X1 := 14.4
const Z0 := -8.6
const Z1 := 1.0
const GATE := [9.5, 11.5]                          # the gap in the front fence (x)
const BEDS := [Vector2(8.4, -5.9), Vector2(10.5, -5.9), Vector2(12.6, -5.9),
	Vector2(8.4, -2.4), Vector2(10.5, -2.4), Vector2(12.6, -2.4)]
const BED_HALF := 0.8
const SEED_BOX := Vector2(7.4, 0.1)

var home: HomeWorld
var beds: Array[GardenBed] = []
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D

static func build_in(h: HomeWorld) -> HomeGarden:
	var g := HomeGarden.new()
	g.name = "Garden"
	g.home = h
	h.add_child(g)
	g._build()
	return g

func gp(x: float, z: float) -> Vector3:
	return home.ground(x, z)

func _build() -> void:
	Game._mend_garden()
	_wood = _mat(Color(0.55, 0.38, 0.22), 0.85)
	_dark = _mat(Color(0.36, 0.24, 0.14), 0.9)
	_fence()
	_paths()
	for i in BEDS.size():
		var b := GardenBed.make(self, i, gp(BEDS[i].x, BEDS[i].y))
		beds.append(b)
	_seed_box()
	_scarecrow()
	_water_barrel()

func _mat(c: Color, r := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = r
	return m

func box(a: Vector3, b: Vector3, m: Material, collide := true) -> MeshInstance3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = hi - lo; mi.mesh = bm
	mi.material_override = m; mi.position = (lo + hi) * 0.5; add_child(mi)
	if collide:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = hi - lo
		cs.shape = bs; sb.add_child(cs); mi.add_child(sb)
	return mi

# --- a white picket fence with a gate arch and a sign -------------------------------
func _fence() -> void:
	var white := _mat(Color(0.95, 0.93, 0.88), 0.7)
	var sides := [[Vector2(X0, Z0), Vector2(X1, Z0)], [Vector2(X0, Z0), Vector2(X0, Z1)], [Vector2(X1, Z0), Vector2(X1, Z1)],
		[Vector2(X0, Z1), Vector2(GATE[0], Z1)], [Vector2(GATE[1], Z1), Vector2(X1, Z1)]]
	for s in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ln := a.distance_to(b)
		var n := maxi(1, int(ln / 0.42))
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(n))
			var y := gp(p.x, p.y).y
			box(Vector3(p.x - 0.05, y, p.y - 0.05), Vector3(p.x + 0.05, y + 0.85, p.y + 0.05), white, false)
		# two rails, and one long solid strip to bump into
		var y0 := gp((a.x + b.x) * 0.5, (a.y + b.y) * 0.5).y
		var lo := Vector3(minf(a.x, b.x) - 0.03, y0, minf(a.y, b.y) - 0.03)
		var hi := Vector3(maxf(a.x, b.x) + 0.03, y0, maxf(a.y, b.y) + 0.03)
		box(lo + Vector3(0, 0.28, 0), hi + Vector3(0, 0.36, 0), white, false)
		box(lo + Vector3(0, 0.6, 0), hi + Vector3(0, 0.68, 0), white, false)
		var wall := box(lo, hi + Vector3(0, 0.9, 0), white, true)
		wall.visible = false
	# the gate: two posts and an arch with a sign
	for gx in GATE:
		var y := gp(gx, Z1).y
		box(Vector3(gx - 0.09, y, Z1 - 0.09), Vector3(gx + 0.09, y + 2.2, Z1 + 0.09), _wood, true)
	var ay := gp(C.x, Z1).y
	box(Vector3(GATE[0] - 0.15, ay + 2.2, Z1 - 0.1), Vector3(GATE[1] + 0.15, ay + 2.35, Z1 + 0.1), _wood, false)
	var board := box(Vector3(C.x - 0.75, ay + 2.38, Z1 - 0.03), Vector3(C.x + 0.75, ay + 2.78, Z1 + 0.03), _mat(Color(0.98, 0.93, 0.75), 0.8), false)
	board.name = "GardenSign"
	var lb := Label3D.new(); lb.text = "GARDEN"; lb.modulate = Color(0.25, 0.5, 0.15); lb.outline_size = 0; lb.font_size = 64
	add_child(lb); lb.position = Vector3(C.x, ay + 2.58, Z1 + 0.04)
	SignText.fit(lb, 1.4, 0.3)
	# flowers climbing the arch
	var rng := RandomNumberGenerator.new(); rng.seed = 1125
	for k in 14:
		var t := float(k) / 13.0
		var side: float = GATE[0] if k % 2 == 0 else GATE[1]
		var p := Vector3(side, ay + 0.4 + t * 1.9, Z1 + 0.1) if t < 0.95 else Vector3(lerpf(GATE[0], GATE[1], rng.randf()), ay + 2.36, Z1 + 0.12)
		var fl := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.12; sm.radial_segments = 8; sm.rings = 4
		fl.mesh = sm; fl.material_override = _mat([Color(1.0, 0.5, 0.7), Color(1.0, 0.85, 0.3), Color(0.75, 0.55, 1.0)][k % 3], 0.6)
		fl.position = p; add_child(fl)

## Trodden paths between the beds.
func _paths() -> void:
	var path := _mat(Color(0.58, 0.46, 0.32), 1.0)
	var y := gp(C.x, C.z).y
	box(Vector3(GATE[0] + 0.1, y - 0.06, -4.15 - 0.6), Vector3(GATE[1] - 0.1, y + 0.025, Z1), path, false)
	box(Vector3(X0 + 0.4, y - 0.06, -4.15 - 0.6), Vector3(X1 - 0.4, y + 0.025, -4.15 + 0.6), path, false)

# --- the seed box by the gate -----------------------------------------------------
func _seed_box() -> void:
	var p := gp(SEED_BOX.x, SEED_BOX.y)
	box(p + Vector3(-0.4, 0, -0.3), p + Vector3(0.4, 0.55, 0.3), _wood, true)
	box(p + Vector3(-0.43, 0.55, -0.33), p + Vector3(0.43, 0.62, 0.33), _dark, false)
	for k in 4:
		var pk := box(p + Vector3(-0.33 + k * 0.17, 0.62, -0.1), p + Vector3(-0.2 + k * 0.17, 0.8, 0.02),
			_mat([Color(1.0, 0.55, 0.15), Color(0.9, 0.2, 0.15), Color(1.0, 0.85, 0.2), Color(0.95, 0.3, 0.5)][k], 0.8), false)
		pk.rotation.x = -0.25
	var lb := Label3D.new(); lb.text = "SEEDS"; lb.modulate = Color(1.0, 0.9, 0.55); lb.outline_size = 10
	lb.outline_modulate = Color(0.2, 0.12, 0.05); lb.font_size = 64; lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(lb); lb.position = p + Vector3(0, 1.15, 0)
	SignText.fit(lb, 0.7, 0.2)
	var u := Usable.make(self, p + Vector3(0, 0.7, 0.45), "[E] Open the seed box", _use_seed_box)
	u.name = "SeedBox"
	_seed_prompt(u)

func _seed_prompt(u: Usable) -> void:
	u.prompt = "[E] Open the seed box (a present for your garden!)" if not Game.garden_starter else "[E] Seed stand (buy seeds from Tobble)"

func _use_seed_box() -> void:
	if not Game.garden_starter:
		Game.garden_starter = true
		var parts: Array = []
		for id in GardenPlants.STARTER:
			Game.add_seeds(id, int(GardenPlants.STARTER[id]))
			parts.append("%d %s" % [int(GardenPlants.STARTER[id]), GardenPlants.seed_name(id)])
		Sfx.play("chest", -6.0, 0.1)
		FX.burst(gp(SEED_BOX.x, SEED_BOX.y) + Vector3(0, 0.9, 0), Color(0.6, 1.0, 0.5), 30, 2.5, 0.12, 0.8, 0.5)
		Game.say("Seeds for your garden: %s. Plant them in the beds!" % ", ".join(parts), Color(0.7, 1.0, 0.6))
		var u := get_node_or_null("SeedBox") as Usable
		if u:
			_seed_prompt(u)
		Game.save_slot()
		return
	var sc := get_tree().current_scene
	if sc.has_method("open_shop"):
		sc.open_shop("seed")

# --- a scarecrow, and a rain barrel ------------------------------------------------
func _scarecrow() -> void:
	var p := gp(13.6, -7.8)
	var straw := _mat(Color(0.92, 0.8, 0.42), 0.95)
	box(p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 1.7, 0.05), _dark, true)
	box(p + Vector3(-0.7, 1.25, -0.04), p + Vector3(0.7, 1.33, 0.04), _dark, false)
	box(p + Vector3(-0.28, 0.75, -0.16), p + Vector3(0.28, 1.4, 0.16), _mat(Color(0.3, 0.45, 0.75), 0.9), false)
	box(p + Vector3(-0.72, 1.2, -0.08), p + Vector3(-0.5, 1.38, 0.08), straw, false)
	box(p + Vector3(0.5, 1.2, -0.08), p + Vector3(0.72, 1.38, 0.08), straw, false)
	var head := MeshInstance3D.new(); var hs := SphereMesh.new(); hs.radius = 0.22; hs.height = 0.44; head.mesh = hs
	head.material_override = _mat(Color(0.9, 0.78, 0.55), 0.9); head.position = p + Vector3(0, 1.62, 0); add_child(head)
	var hat := MeshInstance3D.new(); var hc := CylinderMesh.new(); hc.top_radius = 0.12; hc.bottom_radius = 0.38; hc.height = 0.28
	hat.mesh = hc; hat.material_override = straw; hat.position = p + Vector3(0, 1.86, 0); add_child(hat)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new(); var es := SphereMesh.new(); es.radius = 0.03; es.height = 0.06; eye.mesh = es
		eye.material_override = _mat(Color(0.05, 0.05, 0.05)); eye.position = p + Vector3(sx * 0.08, 1.66, 0.2); add_child(eye)
	var crow := MeshInstance3D.new(); var cs := SphereMesh.new(); cs.radius = 0.11; cs.height = 0.2; crow.mesh = cs
	crow.material_override = _mat(Color(0.08, 0.08, 0.1)); crow.position = p + Vector3(0.6, 1.45, 0); crow.scale = Vector3(1.4, 1.0, 0.9)
	add_child(crow)

func _water_barrel() -> void:
	var p := gp(13.6, 0.2)
	var bar := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.36; bc.bottom_radius = 0.33; bc.height = 0.8
	bar.mesh = bc; bar.material_override = _wood; bar.position = p + Vector3(0, 0.4, 0); add_child(bar)
	for hy in [0.15, 0.65]:
		var ring := MeshInstance3D.new(); var rc := CylinderMesh.new(); rc.top_radius = 0.365; rc.bottom_radius = 0.365; rc.height = 0.05
		ring.mesh = rc; ring.material_override = _mat(Color(0.3, 0.3, 0.32), 0.4); ring.position = p + Vector3(0, hy, 0); add_child(ring)
	var water := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = 0.33; wc.bottom_radius = 0.33; wc.height = 0.02
	water.mesh = wc; var wm := _mat(Color(0.3, 0.55, 0.75), 0.05); wm.metallic = 0.3; water.material_override = wm
	water.position = p + Vector3(0, 0.76, 0); add_child(water)
	# a watering can beside it
	var can := Node3D.new(); add_child(can); can.position = p + Vector3(-0.6, 0, 0.1)
	var green := _mat(Color(0.3, 0.6, 0.35), 0.4); green.metallic = 0.5
	var body := MeshInstance3D.new(); var cb := CylinderMesh.new(); cb.top_radius = 0.13; cb.bottom_radius = 0.15; cb.height = 0.28
	body.mesh = cb; body.material_override = green; body.position.y = 0.14; can.add_child(body)
	var spout := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.035; sc.bottom_radius = 0.02; sc.height = 0.32
	spout.mesh = sc; spout.material_override = green; spout.position = Vector3(0.2, 0.22, 0); spout.rotation.z = -0.8; can.add_child(spout)

# --- the beds ----------------------------------------------------------------------
func _process(_delta: float) -> void:
	for b in beds:
		b.tick()
