extends Node3D
class_name RainbowSlide
## After Mr. Bubbles is calmed, a rainbow appears at the edge of the
## thunderhead. Step on and press USE: you whoosh all the way down it and land
## in front of the sky temple, right next to Anu. It's solid, too: you can run
## back UP it from the temple to the thunderhead (or walk down it).

signal finished

var prompt := "Ride the rainbow slide down to Anu!"
var p0: Vector3      # top (where you get on)
var p1: Vector3
var p2: Vector3
var p3: Vector3      # bottom (where you land)
var land_yaw := 0.0
var _player: Player
var _t := -1.0
const RIDE_TIME := 7.0
const WIDTH := 3.6
const BANDS := [Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 0.92, 0.3),
	Color(0.4, 0.9, 0.4), Color(0.35, 0.65, 1.0), Color(0.65, 0.45, 1.0)]

static func make(parent: Node, top: Vector3, c1: Vector3, c2: Vector3, bottom: Vector3, yaw_at_bottom: float) -> RainbowSlide:
	var s := RainbowSlide.new()
	s.name = "RainbowSlide"
	s.p0 = top; s.p1 = c1; s.p2 = c2; s.p3 = bottom; s.land_yaw = yaw_at_bottom
	parent.add_child(s)
	s.global_position = top
	s.add_to_group("interactable")
	s.process_physics_priority = 100     # move the hero after their own physics step
	s._build()
	return s

func point(t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

func _build() -> void:
	# the ribbon: six coloured bands along the curve, glowing softly
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 90
	var width := WIDTH
	for i in segs:
		var a := point(float(i) / segs) - global_position
		var b := point(float(i + 1) / segs) - global_position
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var dir2 := (point(minf(1.0, float(i + 2) / segs)) - global_position - b).normalized()
		var side2 := dir2.cross(Vector3.UP).normalized() if dir2.length() > 0.01 else side
		for k in BANDS.size():
			var w0 := -width * 0.5 + width * float(k) / BANDS.size()
			var w1 := -width * 0.5 + width * float(k + 1) / BANDS.size()
			var col: Color = BANDS[k]
			var v := [a + side * w0, a + side * w1, b + side2 * w1, b + side2 * w0]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.add_vertex(v[idx])
	# solid, so you can run up (and down) it: a chain of thin tilted slabs under the ribbon
	var sb := StaticBody3D.new(); sb.collision_layer = 1; add_child(sb)
	var csegs := 70
	for i in csegs:
		var a := point(float(i) / csegs) - global_position
		var b := point(float(i + 1) / csegs) - global_position
		var mid := (a + b) * 0.5
		var dir := (b - a)
		var ln := dir.length()
		if ln < 0.01:
			continue
		dir /= ln
		var side := dir.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var up := side.cross(dir).normalized()
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(WIDTH, 0.3, ln + 0.25)
		cs.shape = bs
		cs.transform = Transform3D(Basis(side, up, -dir), mid - up * 0.15)
		sb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.85)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# a glowing cloud pad at the top so you can see where to get on
	var pad := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.8; cm.bottom_radius = 1.8; cm.height = 0.06
	pad.mesh = cm; var pm := FX.glow_material(Color(1.0, 0.95, 0.6), 1.2); pm.albedo_color.a = 0.5
	pad.material_override = pm; pad.position.y = 0.05; add_child(pad)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.9, 0.7); l.light_energy = 2.5; l.omni_range = 9.0
	l.position.y = 2.0; add_child(l)
	var sp := CPUParticles3D.new(); sp.amount = 40; sp.lifetime = 2.0
	sp.mesh = FX.quad(0.14); sp.material_override = FX.glow_material(Color(1.0, 0.95, 0.75), 2.5)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 1.6
	sp.direction = Vector3.UP; sp.spread = 25; sp.initial_velocity_min = 0.5; sp.initial_velocity_max = 1.5
	sp.gravity = Vector3.ZERO; sp.color_ramp = FX._fade_ramp(Color(1.0, 0.95, 0.75))
	sp.position.y = 0.5; add_child(sp)
	# a tall beam so it's easy to spot from across the cloud
	var beam := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.15; bm.bottom_radius = 0.4; bm.height = 14.0
	beam.mesh = bm; var bmm := FX.glow_material(Color(1.0, 0.92, 0.6), 1.5); bmm.albedo_color.a = 0.35
	beam.material_override = bmm; beam.position.y = 7.0; add_child(beam)

func get_prompt() -> String:
	return prompt if _t < 0.0 else ""

func interact(by: Node) -> void:
	if _t >= 0.0 or not (by is Player):
		return
	_player = by as Player
	if _player.mounted:
		_player.dismount()
	_player.input_enabled = false
	_player.body.hold_clip = "Sit_Chair_Idle"
	_t = 0.0
	Sfx.play("pop", -4.0, 0.2)
	Sfx.play("portal", -8.0, 0.4)
	Game.say("Wheeee! Down the rainbow!", Color(1.0, 0.9, 0.5))

func riding() -> bool:
	return _t >= 0.0

func _physics_process(delta: float) -> void:
	if _t < 0.0 or _player == null or not is_instance_valid(_player):
		return
	_t += delta / RIDE_TIME
	# ease in and out a little so it starts gently and lands softly
	var e := clampf(_t, 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e) * 0.35 + e * 0.65
	var here := point(e) + Vector3(0, 0.25, 0)
	var ahead := point(minf(1.0, e + 0.01))
	_player.global_position = here
	_player.velocity = Vector3.ZERO
	var d := ahead - point(e)
	if Vector2(d.x, d.z).length() > 0.001:
		_player.facing = atan2(-d.x, -d.z)
		_player.yaw = _player.facing
	if Engine.get_physics_frames() % 6 == 0:
		FX.burst(here, BANDS[randi() % BANDS.size()], 4, 1.5, 0.1, 0.5, 0.0)
	if _t >= 1.0:
		_t = -1.0
		_player.global_position = p3 + Vector3(0, 0.3, 0)
		_player.facing = land_yaw
		_player.yaw = land_yaw
		_player.body.hold_clip = ""
		_player.input_enabled = true
		if _player.has_method("snap_view"):
			_player.snap_view()
		FX.burst(p3 + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.6), 40, 4.0, 0.2, 0.7, 0.0)
		Sfx.play("pop", -2.0, 0.1)
		finished.emit()
