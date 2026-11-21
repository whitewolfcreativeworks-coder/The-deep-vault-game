extends Node3D
class_name DiscoParty
## DISCO TIME (Insane). Jason, Nov 21: "a disco ball that appears and disco music
## while the effect is going on... underneath the feet is the different colored
## checkers... Saturday Night Fever".
##   - a mirror ball spins above you, throwing coloured beams of light about;
##   - a lit-up dance floor of coloured squares follows your feet, changing colour
##     on every beat (the square you're standing on glows brightest);
##   - two coloured lights circle you, and the music turns into a disco groove
##     (loop_disco: a four-on-the-floor beat with a fairy-tale lute on top) while
##     the level's own music goes quiet.
## Cheap to draw: the whole floor is one mesh-set, the ball one mesh, four beams,
## one sparkle effect and two lights.

const TILES := 7                  # the floor is TILES x TILES squares
const TILE := 1.25                # metres
const BPM := 120.0
const PALETTE := [Color(1.0, 0.2, 0.6), Color(0.2, 0.85, 1.0), Color(1.0, 0.9, 0.2), Color(0.65, 0.3, 1.0),
	Color(0.3, 1.0, 0.45), Color(1.0, 0.5, 0.15), Color(1.0, 1.0, 1.0)]

var player: Node3D
var life := 14.0
var beats := 0                    # (for the tests)
var _t := 0.0
var _beat_t := 0.0
var _ball_root: Node3D
var _ball: MeshInstance3D
var _beams: Node3D
var _floor: MultiMesh
var _floor_node: MultiMeshInstance3D
var _cells := {}                  # tile colours, by grid square
var _centre := Vector2i(99999, 99999)
var _heights: Array = []
var _music: AudioStreamPlayer
var _lights: Array = []
var _rng := RandomNumberGenerator.new()
var _ending := false

static func start(parent: Node, p: Node3D, secs := 14.0) -> DiscoParty:
	for c in parent.get_children():
		if c is DiscoParty and not (c as DiscoParty)._ending:
			(c as DiscoParty).life = maxf((c as DiscoParty).life, secs)
			return c
	var d := DiscoParty.new()
	d.player = p
	d.life = secs
	parent.add_child(d)
	return d

func _ready() -> void:
	_rng.randomize()
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_ball()
	_build_floor()
	for k in 2:
		var l := OmniLight3D.new(); l.light_energy = 3.0; l.omni_range = 9.0
		add_child(l)
		_lights.append(l)
	_music = AudioStreamPlayer.new()
	_music.stream = Sfx.get_stream("loop_disco")
	_music.volume_db = -30.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -7.0, 0.8)
	Sfx.duck_music(true)
	_ball_root.scale = Vector3.ONE * 0.05
	create_tween().tween_property(_ball_root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	Sfx.duck_music(false)

# --- the mirror ball -------------------------------------------------------------------
func _build_ball() -> void:
	_ball_root = Node3D.new(); add_child(_ball_root)
	_ball = MeshInstance3D.new()
	_ball.mesh = _faceted_sphere(0.55)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic = 0.7; m.roughness = 0.15
	m.emission_enabled = true; m.emission = Color(0.25, 0.25, 0.3); m.emission_energy_multiplier = 0.8
	_ball.material_override = m
	_ball_root.add_child(_ball)
	var rod := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.02; cm.bottom_radius = 0.02; cm.height = 1.2
	rod.mesh = cm; rod.material_override = HomeBuilding.mat(Color(0.6, 0.6, 0.65), 0.4, 0.8)
	_ball_root.add_child(rod); rod.position.y = 1.15
	var sp := CPUParticles3D.new(); sp.amount = 40; sp.lifetime = 0.5
	sp.mesh = FX.quad(0.09); sp.material_override = FX.glow_material(Color(1, 1, 1), 2.5)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE; sp.emission_sphere_radius = 0.58
	sp.direction = Vector3.UP; sp.spread = 180; sp.initial_velocity_min = 0.0; sp.initial_velocity_max = 0.1
	sp.gravity = Vector3.ZERO; sp.hue_variation_min = -1.0; sp.hue_variation_max = 1.0
	sp.color = Color(1.0, 0.7, 0.9)
	_ball_root.add_child(sp)
	_beams = Node3D.new(); _ball_root.add_child(_beams)
	for k in 4:
		var b := MeshInstance3D.new(); var bm := CylinderMesh.new()
		bm.top_radius = 0.03; bm.bottom_radius = 0.7; bm.height = 6.0; bm.radial_segments = 10; bm.cap_top = false; bm.cap_bottom = false
		b.mesh = bm
		b.material_override = FX.beam_material(PALETTE[k], 1.2, 0.22, true)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new(); _beams.add_child(pivot)
		pivot.rotation = Vector3(0.0, k * TAU / 4.0, 0.0)
		pivot.add_child(b)
		# hanging down and out from the ball
		b.rotation.x = deg_to_rad(35.0)
		b.position = Vector3(0, -3.0 * cos(deg_to_rad(35.0)), -3.0 * sin(deg_to_rad(35.0)))

## A sphere with flat facets, like the little mirrors on a disco ball.
static func _faceted_sphere(r: float) -> ArrayMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 18; s.rings = 9
	var arr := s.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rr := RandomNumberGenerator.new(); rr.seed = 1977
	var tones := [Color(1, 1, 1), Color(0.75, 0.78, 0.85), Color(0.55, 0.58, 0.66), Color(1.0, 0.75, 0.95), Color(0.7, 0.95, 1.0), Color(0.9, 0.92, 1.0)]
	for i in range(0, idx.size(), 3):
		st.set_color(HomeDecor._vc(tones[rr.randi() % tones.size()]))     # (every little mirror catches the light differently)
		var a := v[idx[i]]; var b := v[idx[i + 1]]; var c := v[idx[i + 2]]
		var n := (b - a).cross(c - a)
		if n.length() < 1e-8:
			continue
		n = n.normalized()
		if n.dot(a + b + c) < 0.0:
			n = -n
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()

# --- the dance floor -------------------------------------------------------------------
func _build_floor() -> void:
	_floor = MultiMesh.new(); _floor.transform_format = MultiMesh.TRANSFORM_3D; _floor.use_colors = true
	var q := QuadMesh.new(); q.size = Vector2(TILE * 0.92, TILE * 0.92); q.orientation = PlaneMesh.FACE_Y
	_floor.mesh = q
	_floor.instance_count = TILES * TILES
	_floor_node = MultiMeshInstance3D.new(); _floor_node.multimesh = _floor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_node.material_override = m
	_floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_node.extra_cull_margin = 10.0
	add_child(_floor_node)
	_heights.resize(TILES * TILES)

## Lay the floor out round the square you're standing on (each square sits on the ground).
func _place_floor(c: Vector2i) -> void:
	_centre = c
	var space := get_world_3d().direct_space_state
	var py := player.global_position.y
	var h: int = TILES >> 1
	for j in TILES:
		for i in TILES:
			var gx := (c.x + i - h) * TILE
			var gz := (c.y + j - h) * TILE
			var q := PhysicsRayQueryParameters3D.create(Vector3(gx, py + 2.5, gz), Vector3(gx, py - 4.0, gz), 1)
			var hit := space.intersect_ray(q)
			var y := (hit.position as Vector3).y if not hit.is_empty() else -10000.0
			_heights[j * TILES + i] = y
			_floor.set_instance_transform(j * TILES + i, Transform3D(Basis(), Vector3(gx, y + 0.05, gz)))
	_paint()

func _paint() -> void:
	var h: int = TILES >> 1
	var me := Vector2i(roundi(player.global_position.x / TILE), roundi(player.global_position.z / TILE))
	for j in TILES:
		for i in TILES:
			var cell := Vector2i(_centre.x + i - h, _centre.y + j - h)
			var col: Color = _cells.get(cell, Color(0, 0, 0, 0))
			var k := j * TILES + i
			var y: float = _heights[k]
			if y < -9999.0:
				col = Color(0, 0, 0, 0)                        # (no ground there: no square)
			elif cell == me:
				col = Color(1.0, 1.0, 1.0, 0.95)                # where you're dancing
			var edge := maxi(absi(i - h), absi(j - h))
			col.a *= 1.0 - 0.18 * maxf(edge - 1, 0)          # fading out towards the edges
			var lit := HomeDecor._vc(Color(col.r, col.g, col.b))      # (bright, saturated colours on either renderer)
			if not Game.is_compat():
				lit = lit * 1.6
			_floor.set_instance_color(k, Color(lit.r, lit.g, lit.b, col.a))

## A new beat: the squares light up in new colours.
func _new_colours() -> void:
	var h: int = TILES >> 1
	for j in TILES:
		for i in TILES:
			var cell := Vector2i(_centre.x + i - h, _centre.y + j - h)
			if _rng.randf() < 0.25:
				_cells[cell] = Color(0.12, 0.1, 0.18, 0.75)      # a dark square now and then
			else:
				var c: Color = PALETTE[_rng.randi() % PALETTE.size()]
				_cells[cell] = Color(c.r, c.g, c.b, 0.93)
	if _cells.size() > 400:
		_cells.clear()

# --- every frame -------------------------------------------------------------------------
func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_t += delta
	life -= delta
	var at := player.global_position
	_ball_root.global_position = _ball_root.global_position.lerp(at + Vector3(0, 4.8, 0), 1.0 - exp(-4.0 * delta)) if _t > 0.1 else at + Vector3(0, 4.8, 0)
	_ball.rotation.y += delta * 1.2
	_beams.rotation.y -= delta * 0.9
	for i in _lights.size():
		var l: OmniLight3D = _lights[i]
		var a := _t * 2.2 + i * PI
		l.global_position = at + Vector3(cos(a) * 4.0, 2.5, sin(a) * 4.0)
		l.light_color = Color.from_hsv(fmod(_t * 0.25 + i * 0.5, 1.0), 0.85, 1.0)
	var c := Vector2i(roundi(at.x / TILE), roundi(at.z / TILE))
	if c != _centre and (player as CharacterBody3D).is_on_floor():
		_place_floor(c)
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t += 60.0 / BPM
		beats += 1
		_new_colours()
	_paint()
	if life <= 0.0 and not _ending:
		_end()

func _end() -> void:
	_ending = true
	Sfx.duck_music(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music, "volume_db", -40.0, 0.8)
	tw.tween_property(_ball_root, "scale", Vector3.ONE * 0.05, 0.5)
	tw.tween_property(_floor_node, "transparency", 1.0, 0.6)
	tw.chain().tween_callback(queue_free)
