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
var sparkle: CPUParticles3D        # one for the whole garden: it sparkles over every ripe bed
var sparkles_dirty := true
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
	_flush()
	sparkle = CPUParticles3D.new(); sparkle.name = "RipeSparkle"; sparkle.amount = 36; sparkle.lifetime = 1.4
	sparkle.mesh = FX.quad(0.08); sparkle.material_override = FX.glow_material(Color(1.0, 0.95, 0.5), 2.5)
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	sparkle.direction = Vector3.UP; sparkle.spread = 20; sparkle.initial_velocity_min = 0.3; sparkle.initial_velocity_max = 0.7
	sparkle.gravity = Vector3.ZERO; sparkle.color_ramp = FX._fade_ramp(Color(1.0, 0.95, 0.5))
	sparkle.emitting = false; add_child(sparkle)

# --- cheap to draw (Jason: "this game must have no lag") ---------------------------
# Every fixed piece of the garden (gate, sign, seed box, scarecrow, barrel, paths) is
# merged into one mesh per colour, and the little things cast no shadows.
var _merge := {}                   # material -> SurfaceTool
var _mats := {}
static var _unit_box: BoxMesh

func _mat(c: Color, r := 0.8) -> StandardMaterial3D:
	var key := "%s%.2f" % [c.to_html(), r]
	if not _mats.has(key):
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = r
		_mats[key] = m
	return _mats[key]

func piece(mesh: Mesh, xf: Transform3D, m: Material) -> void:
	var st: SurfaceTool = _merge.get(m)
	if st == null:
		st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_merge[m] = st
	st.append_from(mesh, 0, xf)

func _flush() -> void:
	for m in _merge:
		var mi := MeshInstance3D.new(); mi.mesh = (_merge[m] as SurfaceTool).commit(); mi.material_override = m
		# only the fence, the gate and the bed frames cast shadows; the little things don't
		if m != _mats.get("%s%.2f" % [Color(0.95, 0.93, 0.88).to_html(), 0.7]) and m != _wood:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_merge.clear()

## Something solid to bump into (no mesh).
func solid(lo: Vector3, hi: Vector3) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = hi - lo
	cs.shape = bs; cs.position = (lo + hi) * 0.5; sb.add_child(cs); add_child(sb)

## A box from its corners (merged), solid unless collide is false.
func box(a: Vector3, b: Vector3, m: Material, collide := true, rot := Vector3.ZERO) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	piece(_unit_box, Transform3D(Basis.from_euler(rot) * Basis.from_scale(hi - lo), (lo + hi) * 0.5), m)
	if collide:
		solid(lo, hi)

func ball(at: Vector3, r: float, m: Material, scl := Vector3.ONE) -> void:
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 10; sm.rings = 5
	piece(sm, Transform3D(Basis.from_scale(scl), at), m)

func cyl(at: Vector3, r_top: float, r_bot: float, h: float, m: Material, rot := Vector3.ZERO) -> void:
	var cm := CylinderMesh.new(); cm.top_radius = r_top; cm.bottom_radius = r_bot; cm.height = h; cm.radial_segments = 12
	piece(cm, Transform3D(Basis.from_euler(rot), at), m)

# --- a white picket fence with a gate arch and a sign -------------------------------
func _fence() -> void:
	# (every post and rail is merged into one mesh: the whole fence is one thing to draw)
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
		for ry in [0.28, 0.6]:
			box(lo + Vector3(0, ry, 0), hi + Vector3(0, ry + 0.08, 0), white, false)
		solid(lo, hi + Vector3(0, 0.9, 0))
	# the gate: two posts and an arch with a sign
	for gx in GATE:
		var y := gp(gx, Z1).y
		box(Vector3(gx - 0.09, y, Z1 - 0.09), Vector3(gx + 0.09, y + 2.2, Z1 + 0.09), _wood, true)
	var ay := gp(C.x, Z1).y
	box(Vector3(GATE[0] - 0.15, ay + 2.2, Z1 - 0.1), Vector3(GATE[1] + 0.15, ay + 2.35, Z1 + 0.1), _wood, false)
	box(Vector3(C.x - 0.75, ay + 2.38, Z1 - 0.03), Vector3(C.x + 0.75, ay + 2.78, Z1 + 0.03), _mat(Color(0.98, 0.93, 0.75), 0.8), false)
	var lb := Label3D.new(); lb.text = "GARDEN"; lb.modulate = Color(0.25, 0.5, 0.15); lb.outline_size = 0; lb.font_size = 64
	add_child(lb); lb.position = Vector3(C.x, ay + 2.58, Z1 + 0.04)
	SignText.fit(lb, 1.4, 0.3)
	# flowers climbing the arch
	var rng := RandomNumberGenerator.new(); rng.seed = 1125
	var fm := MultiMesh.new(); fm.transform_format = MultiMesh.TRANSFORM_3D; fm.use_colors = true
	var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.12; sm.radial_segments = 8; sm.rings = 4
	fm.mesh = sm; fm.instance_count = 14
	for k in 14:
		var t := float(k) / 13.0
		var side: float = GATE[0] if k % 2 == 0 else GATE[1]
		var p := Vector3(side, ay + 0.4 + t * 1.9, Z1 + 0.1) if t < 0.95 else Vector3(lerpf(GATE[0], GATE[1], rng.randf()), ay + 2.36, Z1 + 0.12)
		fm.set_instance_transform(k, Transform3D(Basis(), p))
		fm.set_instance_color(k, [Color(1.0, 0.5, 0.7), Color(1.0, 0.85, 0.3), Color(0.75, 0.55, 1.0)][k % 3])
	var fmi := MultiMeshInstance3D.new(); fmi.multimesh = fm; fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fmat := StandardMaterial3D.new(); fmat.roughness = 0.6; fmat.vertex_color_use_as_albedo = true
	fmi.material_override = fmat; add_child(fmi)

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
		box(p + Vector3(-0.33 + k * 0.17, 0.62, -0.1), p + Vector3(-0.2 + k * 0.17, 0.8, 0.02),
			_mat([Color(1.0, 0.55, 0.15), Color(0.95, 0.3, 0.5)][k % 2], 0.8), false, Vector3(-0.25, 0, 0))
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
	ball(p + Vector3(0, 1.62, 0), 0.22, _mat(Color(0.9, 0.78, 0.55), 0.9))
	cyl(p + Vector3(0, 1.86, 0), 0.12, 0.38, 0.28, straw)
	for sx in [-1.0, 1.0]:
		ball(p + Vector3(sx * 0.08, 1.66, 0.2), 0.03, _mat(Color(0.06, 0.06, 0.07)))
	ball(p + Vector3(0.6, 1.45, 0), 0.1, _mat(Color(0.06, 0.06, 0.07)), Vector3(1.4, 1.0, 0.9))

func _water_barrel() -> void:
	var p := gp(13.6, 0.2)
	cyl(p + Vector3(0, 0.4, 0), 0.36, 0.33, 0.8, _wood)
	for hy in [0.15, 0.65]:
		cyl(p + Vector3(0, hy, 0), 0.365, 0.365, 0.05, _mat(Color(0.3, 0.3, 0.32), 0.4))
	cyl(p + Vector3(0, 0.76, 0), 0.33, 0.33, 0.02, _mat(Color(0.3, 0.55, 0.75), 0.05))
	solid(p + Vector3(-0.35, 0, -0.35), p + Vector3(0.35, 0.8, 0.35))
	# a watering can beside it
	var cp := p + Vector3(-0.6, 0, 0.1)
	var green := _mat(Color(0.3, 0.6, 0.35), 0.4)
	cyl(cp + Vector3(0, 0.14, 0), 0.13, 0.15, 0.28, green)
	cyl(cp + Vector3(0.2, 0.22, 0), 0.035, 0.02, 0.32, green, Vector3(0, 0, -0.8))

# --- the beds ----------------------------------------------------------------------
func _process(_delta: float) -> void:
	for b in beds:
		b.tick()
	if sparkles_dirty and sparkle:
		sparkles_dirty = false
		var pts := PackedVector3Array()
		for b in beds:
			if b.stage == 4:
				for k in 6:
					pts.append(b.position + Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.1), randf_range(-0.6, 0.6)))
		sparkle.emitting = not pts.is_empty()
		if not pts.is_empty():
			sparkle.emission_points = pts
