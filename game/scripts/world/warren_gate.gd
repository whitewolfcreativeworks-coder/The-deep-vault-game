extends RefCounted
class_name WarrenGate
## THE WARREN GATE (Nov 25): the way into the Goblin Warren, at the north end of
## the Goblin Forest's road.
##
## It used to be a little mine-house model set on the slope of the ridge. Its front
## floated over the hillside, you walked up the grass into the inside of the model,
## and USE only lit up once you were right up among its rails (the door sat 3 m
## above the ground in front of it). Jason, Nov 25: "it's not intuitive... the
## graphics look funny, just sitting up there on the hill... there should be a real
## like obvious way to go up to it to enter into it."
##
## Now the road runs straight into a level MINE YARD cut into the foot of the ridge,
## with rock walls either side. At its back, a timber-framed TUNNEL goes into the
## rock face under a sign, "THE GOBLIN WARREN". Rails run from the yard into the
## dark. Two braziers flank the tunnel, and the big beacon burns on the rock above it
## (you see it from the portal).
##   * Barred (until Captain Aldric gives you his quest): planks across the tunnel.
##   * Open: walk into the tunnel and you go down into the Warren, or press USE
##     anywhere in front of it (USE lights up from about 4 m away).
##
## The ground is cut here by ForestWorld.height() using cut() below.

const MOUTH_Z := -100.0          # the rock face: the tunnel goes in here
const YARD_HALF := 8.0           # the yard is level for |x| <= 8 (rock walls from there)
const YARD_FRONT := -86.0        # ...from the rock face back to here, where the road comes in
const SLOT_HALF := 4.0           # the ground is cut away under the tunnel too...
const SLOT_END := -106.0         # ...back to its end
const IN_W := 2.6                # half the tunnel's clear width (between the timbers)
const ROCK_W := 3.1              # half the opening in the rock
const IN_H := 4.4                # clear height under the timbers
const ROOF := 5.0                # the rock above the opening starts here (above the floor)
const TOP := 10.0                # the top of the rock face (above the floor)
const BACK := -104.2             # the rock face is this deep
const END_Z := -106.0            # the tunnel's dark end

## How much the ridge is cut away here: 1 = down to the yard floor, 0 = untouched.
static func cut(p: Vector2) -> float:
	var yard := smoothstep(YARD_HALF + 2.5, YARD_HALF, absf(p.x)) * smoothstep(MOUTH_Z - 2.5, MOUTH_Z, p.y) \
		* smoothstep(YARD_FRONT + 6.0, YARD_FRONT, p.y)
	var slot := smoothstep(SLOT_HALF + 2.0, SLOT_HALF, absf(p.x)) * smoothstep(SLOT_END - 2.0, SLOT_END, p.y) \
		* smoothstep(MOUTH_Z + 4.0, MOUTH_Z, p.y)
	return maxf(yard, slot)

## Trees and scattered rocks keep out of here.
static func keep_clear(p: Vector2) -> bool:
	return absf(p.x) < 14.0 and p.y > -112.0 and p.y < YARD_FRONT + 6.0

var w: ForestWorld
var y0 := 0.0                    # the yard floor
var rng := RandomNumberGenerator.new()
var rock: Material
var dark_rock: Material
var wood: StandardMaterial3D
var iron: StandardMaterial3D

static func build(world: ForestWorld) -> WarrenDoor:
	var g := WarrenGate.new()
	return g._build(world)

func _build(world: ForestWorld) -> WarrenDoor:
	w = world
	rng.seed = 1125                # (its own dice: the rest of the forest stays exactly as it was)
	y0 = w.ground(0, MOUTH_Z + 6.0).y
	rock = w.b.wall_mat(Color(0.5, 0.47, 0.41), 0.35, y0, 2.8, 1.4)
	(rock as ShaderMaterial).set_shader_parameter("mode", 2)          # natural rock, not building stone
	(rock as ShaderMaterial).set_shader_parameter("mortar_color", Color(0.32, 0.3, 0.26))   # (soft cracks)
	dark_rock = w.b.wall_mat(Color(0.27, 0.22, 0.17), 0.05, y0, 1.6, 0.8)
	(dark_rock as ShaderMaterial).set_shader_parameter("mode", 2)
	(dark_rock as ShaderMaterial).set_shader_parameter("mortar_color", Color(0.16, 0.13, 0.1))
	wood = StandardMaterial3D.new(); wood.albedo_color = Color(0.46, 0.3, 0.17); wood.roughness = 0.85
	iron = StandardMaterial3D.new(); iron.albedo_color = Color(0.24, 0.23, 0.24); iron.metallic = 0.7; iron.roughness = 0.45
	_rock_face()
	_tunnel()
	_timbers()
	_sign()
	_rails()
	_cart()
	_fires()
	_yard_dressing()
	_rocks()
	var door := WarrenDoor.make(w, Vector3(0, y0, MOUTH_Z + 0.35), Vector3(0, ForestWorld.WY + 0.1, -118.0))
	door.name = "WarrenGateDoor"
	door.add_walk_in(Vector3(0, 1.5, (MOUTH_Z - 1.6 + END_Z) * 0.5 - door.position.z), Vector3(IN_W * 2.0, 3.0, (MOUTH_Z - 1.6) - END_Z))
	return door

func _box(a: Vector3, b: Vector3, m: Material, collide := true) -> MeshInstance3D:
	return w.b.box(a, b, m, collide)

func ridge_top(z: float) -> float:
	return w.gate_floor + w.ridge_h(z) - y0

# --- the rock: a cliff face across the back of the yard, walls down its sides -------
func _rock_face() -> void:
	var f := MOUTH_Z
	_box(Vector3(-11.0, y0 - 0.8, BACK), Vector3(-ROCK_W, y0 + TOP, f), rock)
	_box(Vector3(ROCK_W, y0 - 0.8, BACK), Vector3(11.0, y0 + TOP, f), rock)
	_box(Vector3(-ROCK_W, y0 + ROOF, BACK), Vector3(ROCK_W, y0 + TOP, f), rock)
	# the sides of the yard: a slab of rock either side, sloping down with the ridge
	# (the hillside under it is too steep to climb, so it needs no collision of its own)
	var za := f + 0.5
	var zb := f + 11.5
	var ha := ridge_top(f) + 1.0
	var hb := 0.25
	var along := Vector3(0, hb - ha, zb - za)
	var ln := along.length()
	var zax := along / ln
	var yax := zax.cross(Vector3.RIGHT) * -1.0
	if yax.y < 0.0:
		yax = -yax
	var bas := Basis(Vector3.RIGHT, yax, zax)
	var thick := 9.0
	var wide := 4.0
	for sx: float in [-1.0, 1.0]:
		var slab := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(wide, thick, ln + 1.0); slab.mesh = sm
		slab.material_override = rock
		var mid_top := Vector3(sx * (YARD_HALF + wide * 0.5 - 0.15), y0 + (ha + hb) * 0.5, (za + zb) * 0.5)
		slab.transform = Transform3D(bas, mid_top - yax * thick * 0.5)
		w.add_child(slab)

# --- the tunnel into the dark ----------------------------------------------------------
func _tunnel() -> void:
	# its walls and roof, then the hill over it, all the way back to its end
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * ROCK_W, y0 - 0.8, END_Z - 2.5)
		var c := Vector3(sx * 7.0, y0 + ROOF, BACK)
		_box(a, c, dark_rock)
	_box(Vector3(-7.0, y0 - 0.8, END_Z - 3.0), Vector3(7.0, y0 + ROOF, END_Z), dark_rock)
	var mid := (BACK + END_Z - 3.0) * 0.5
	_box(Vector3(-7.0, y0 + ROOF, mid), Vector3(7.0, y0 + ridge_top(BACK) + 0.2, BACK), rock)
	_box(Vector3(-7.0, y0 + ROOF, END_Z - 3.0), Vector3(7.0, y0 + ridge_top(mid) + 0.2, mid), rock)
	# a dark floor (the ground under it is cut level), and the dark end
	var fl := StandardMaterial3D.new(); fl.albedo_color = Color(0.2, 0.15, 0.1); fl.roughness = 1.0
	_box(Vector3(-ROCK_W, y0 - 0.2, END_Z), Vector3(ROCK_W, y0 + 0.02, MOUTH_Z + 0.3), fl, false)
	var void_m := StandardMaterial3D.new(); void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_m.albedo_color = Color(0.0, 0.0, 0.0)
	var vq := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(ROCK_W * 2.0, ROOF); vq.mesh = qm
	vq.material_override = void_m; vq.position = Vector3(0, y0 + ROOF * 0.5, END_Z + 0.03)
	vq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(vq)
	# darkness gathering down the tunnel: a soft black veil over its far half
	var veil := StandardMaterial3D.new(); veil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; veil.albedo_color = Color(0, 0, 0, 0.55)
	veil.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 2:
		var vz := MOUTH_Z - 2.6 - k * 1.5
		var v := MeshInstance3D.new(); var vm := QuadMesh.new(); vm.size = Vector2(ROCK_W * 2.0, ROOF); v.mesh = vm
		v.material_override = veil; v.position = Vector3(0, y0 + ROOF * 0.5, vz)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(v)
	# a warm glimmer deep inside: goblin torches somewhere down there
	var gl := OmniLight3D.new(); gl.light_color = Color(1.0, 0.55, 0.22); gl.light_energy = 1.3; gl.omni_range = 4.5
	gl.position = Vector3(0, y0 + 1.6, END_Z + 0.8); w.add_child(gl)

# --- timber sets holding the tunnel up; a heavy one at the mouth ------------------------
func _timbers() -> void:
	for k in 3:
		var z := MOUTH_Z + 0.15 - k * 2.3
		var heavy := k == 0
		var t := 0.62 if heavy else 0.45
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * (IN_W + t * 0.5)
			_box(Vector3(x - t * 0.5, y0 - 0.1, z - t * 0.5), Vector3(x + t * 0.5, y0 + IN_H, z + t * 0.5), wood, heavy)
		var cap := 0.75 if heavy else 0.5
		var half := ROCK_W + (0.9 if heavy else 0.1)
		_box(Vector3(-half, y0 + IN_H, z - t * 0.6), Vector3(half, y0 + IN_H + cap, z + t * 0.6), wood, heavy)
		if heavy:
			# corner braces
			for sx in [-1.0, 1.0]:
				var br := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, 1.5, 0.35); br.mesh = bm
				br.material_override = wood
				br.position = Vector3(sx * (IN_W - 0.35), y0 + IN_H - 0.45, z + 0.05); br.rotation.z = sx * 0.78
				w.add_child(br)
			# iron bands on the posts
			for sx in [-1.0, 1.0]:
				for hy in [0.6, 2.9]:
					var x2: float = sx * (IN_W + t * 0.5)
					_box(Vector3(x2 - t * 0.5 - 0.03, y0 + hy, z - t * 0.5 - 0.03), Vector3(x2 + t * 0.5 + 0.03, y0 + hy + 0.14, z + t * 0.5 + 0.03), iron, false)

# --- the sign over the tunnel ------------------------------------------------------------
func _sign() -> void:
	var z := MOUTH_Z + 0.6
	var board_y := y0 + IN_H + 1.25
	var dark_wood := StandardMaterial3D.new(); dark_wood.albedo_color = Color(0.3, 0.19, 0.1); dark_wood.roughness = 0.9
	_box(Vector3(-2.9, board_y - 0.5, z - 0.1), Vector3(2.9, board_y + 0.5, z + 0.06), dark_wood, false)
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * 2.0 - 0.09, y0 + IN_H + 0.7, z - 0.12), Vector3(sx * 2.0 + 0.09, board_y - 0.45, z), iron, false)
	var lb := Label3D.new(); lb.text = "THE GOBLIN WARREN"; lb.font = UIKit.title_font()
	lb.font_size = 72; lb.pixel_size = 0.0052; lb.outline_size = 14
	lb.modulate = Color(1.0, 0.78, 0.4); lb.outline_modulate = Color(0.12, 0.05, 0.02)
	lb.position = Vector3(0, board_y, z + 0.08)
	w.add_child(lb)
	for sx in [-1.0, 1.0]:
		w._model("skull", Vector3(sx * 3.45, board_y - 0.35, z + 0.05), 0.0, 1.3)

# --- rails from the yard into the dark ---------------------------------------------------
func _rails() -> void:
	var z0 := YARD_FRONT + 1.0
	var z1 := END_Z + 0.2
	for sx in [-0.62, 0.62]:
		_box(Vector3(sx - 0.05, y0 + 0.12, z1), Vector3(sx + 0.05, y0 + 0.24, z0), iron, false)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var sl := BoxMesh.new(); sl.size = Vector3(1.75, 0.12, 0.26); sl.material = wood
	mm.mesh = sl
	var n := int((z0 - z1) / 0.95)
	mm.instance_count = n
	for k in n:
		mm.set_instance_transform(k, Transform3D(Basis(), Vector3(0, y0 + 0.06, z0 - 0.4 - k * 0.95)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; w.add_child(mi)

# --- a goblin ore cart, full of gold, parked on a siding ---------------------------------
func _cart() -> void:
	var c := Vector3(5.2, y0, -93.0)
	for sx in [-0.55, 0.55]:
		_box(Vector3(c.x + sx - 0.05, y0 + 0.12, c.z - 2.2), Vector3(c.x + sx + 0.05, y0 + 0.24, c.z + 2.2), iron, false)
	var cart := Node3D.new(); w.add_child(cart); cart.position = c + Vector3(0, 0, 0.3); cart.rotation.y = 0.06
	var body := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.5, 0.85, 2.1); body.mesh = bm
	body.material_override = wood; body.position = Vector3(0, 0.85, 0); cart.add_child(body)
	for hz in [-0.9, 0.0, 0.9]:
		var band := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(1.56, 0.9, 0.12); band.mesh = bb
		band.material_override = iron; band.position = Vector3(0, 0.85, hz); cart.add_child(band)
	var gold := StandardMaterial3D.new(); gold.albedo_color = Color(1.0, 0.78, 0.25); gold.metallic = 0.9; gold.roughness = 0.3
	gold.emission_enabled = true; gold.emission = Color(1.0, 0.7, 0.2); gold.emission_energy_multiplier = 0.25
	for k in 9:
		var nug := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = rng.randf_range(0.16, 0.26); sm.height = sm.radius * 1.6
		sm.radial_segments = 6; sm.rings = 3; nug.mesh = sm; nug.material_override = gold
		nug.position = Vector3(rng.randf_range(-0.5, 0.5), 1.3 + rng.randf_range(0.0, 0.12), rng.randf_range(-0.75, 0.75))
		cart.add_child(nug)
	for wx in [-0.8, 0.8]:
		for wz in [-0.65, 0.65]:
			var wh := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.3; cy.bottom_radius = 0.3; cy.height = 0.14
			cy.radial_segments = 12; wh.mesh = cy; wh.material_override = iron
			wh.position = Vector3(wx, 0.32, wz); wh.rotation.z = PI * 0.5; cart.add_child(wh)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.7, 1.3, 2.2)
	cs.shape = bs; cs.position = Vector3(0, 0.65, 0); sb.add_child(cs); cart.add_child(sb)

# --- braziers either side of the tunnel, and the big beacon on the rock above -------------
func _fires() -> void:
	for sx in [-4.9, 4.9]:
		var bp := Vector3(sx, y0, MOUTH_Z + 1.6)
		Props.place(w, "pillar", bp, 0.0, 1.0, true)
		_fire(bp + Vector3(0, 4.1, 0), 0.7, 50, 4.0, 14.0, 0.4)
	var beacon := Vector3(0, y0 + TOP, MOUTH_Z - 2.0)
	Props.place(w, "pillar", beacon, 0.0, 1.4, false)
	_fire(beacon + Vector3(0, 5.9, 0), 1.3, 90, 8.0, 30.0, 0.9)

func _fire(at: Vector3, size: float, amount: int, energy: float, rng_m: float, rad: float) -> void:
	var fire := Node3D.new(); w.add_child(fire); fire.position = at
	var fl := CPUParticles3D.new(); fl.amount = amount; fl.lifetime = 0.9 if size < 1.0 else 1.3
	fl.mesh = FX.quad(size); fl.material_override = FX.glow_material(Color(1.0, 0.45, 0.12), 3.5)
	fl.direction = Vector3.UP; fl.spread = 15; fl.initial_velocity_min = 1.5 * size * 1.4; fl.initial_velocity_max = 3.0 * size * 1.4
	fl.gravity = Vector3(0, 1.5, 0); fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; fl.emission_sphere_radius = rad
	fl.color_ramp = FX._fade_ramp(Color(1.0, 0.5, 0.15))
	fire.add_child(fl)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.5, 0.2); l.light_energy = energy; l.omni_range = rng_m
	l.set_script(load("res://scripts/world/flicker.gd")); l.position.y = 0.6; fire.add_child(l)

# --- the yard: flags where the road comes in, goblin junk along the walls -----------------
func _yard_dressing() -> void:
	for sx in [-1.0, 1.0]:
		w._model("flag_red", Vector3(sx * 6.6, y0, YARD_FRONT - 0.5), 180.0, 10.0)
		w._model("post_skull", Vector3(sx * 4.2, y0, YARD_FRONT + 0.5), 180.0, 1.1, true)
	w._model("crate_A_big", Vector3(-6.4, y0, MOUTH_Z + 1.6), 12.0, 6.0, true)
	w._model("crate_A_big", Vector3(-6.7, y0, MOUTH_Z + 3.4), -20.0, 5.0, true)
	w._model("barrel", Vector3(-6.6, y0, MOUTH_Z + 5.2), 0.0, 6.0, true)
	w._model("barrel", Vector3(6.6, y0, MOUTH_Z + 2.0), 40.0, 6.0, true)
	w._model("sack", Vector3(-5.7, y0, MOUTH_Z + 4.4), 70.0, 6.0)
	w._model("lantern_standing", Vector3(-3.6, y0, MOUTH_Z + 3.2), 0.0, 1.0)
	w._model("lantern_standing", Vector3(3.6, y0, MOUTH_Z + 3.2), 0.0, 1.0)

# --- boulders: soften the rock's edges, and a few at the foot of the walls ---------------
func _rocks() -> void:
	var names := ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"]
	var k := 0
	# along the top of the rock face, and on the hill over the tunnel
	for x in [-11.5, -8.4, -5.4, 5.4, 8.4, 11.5]:        # (the beacon stands in the middle)
		w._instance(names[k % 5], Vector3(x + rng.randf_range(-0.6, 0.6), y0 + TOP - 0.9, MOUTH_Z - 1.2 - rng.randf_range(0.0, 1.6)),
			rng.randf() * TAU, rng.randf_range(16.0, 22.0))
		k += 1
	for x in [-4.5, 0.5, 4.8]:
		w._instance(names[k % 5], Vector3(x, y0 + ridge_top(BACK - 1.0) + 0.1, BACK - 1.5 - rng.randf_range(0.0, 2.0)),
			rng.randf() * TAU, rng.randf_range(18.0, 24.0))
		k += 1
	# along the tops of the side walls
	for sx in [-1.0, 1.0]:
		for z in [MOUTH_Z + 1.2, MOUTH_Z + 4.0, MOUTH_Z + 7.0]:
			var t := ridge_top(z - 1.5) + 0.7
			if t < 1.2:
				t = 0.6
			w._instance(names[k % 5], Vector3(sx * (YARD_HALF + 1.6 + rng.randf_range(0.0, 1.2)), y0 + t - 0.7, z),
				rng.randf() * TAU, rng.randf_range(12.0, 17.0))
			k += 1
		# at the foot of the walls (solid)
		w._instance(names[k % 5], Vector3(sx * (YARD_HALF - 0.6), y0 - 0.25, MOUTH_Z + 7.5), rng.randf() * TAU, 8.0, 0.9)
		k += 1
