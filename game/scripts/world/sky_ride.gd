extends Node3D
class_name SkyRide
## THE SKY RIDE: the flight home as its own little arcade game.
##
## Your dragonfly flies itself along the course (about a minute and a half);
## you steer left and right with the stick, hold FLY (JUMP) to climb and BLOCK
## to dive, and let go to sink gently. Thread the rings:
##   gold   rings      points; every ring in a row raises your STREAK, and the
##                     streak multiplies your points (up to x3)
##   blue   BOOST      a burst of speed (whoosh!)
##   rainbow STAR      hard to reach, worth five gold rings
##   pink   HOME       the welcome-home arch over the yard
## Miss a ring and your streak starts again. Five parts: Sky School (easy
## rings), the Storm Gate (weave past the lightning), Thunder Bird Rocks (a
## corkscrew), the Floating Lake (through the waterfall, under the rainbow) and
## Home Valley (the spiral down). At the end: your score and a medal.

const SECTIONS := [[0.0, "SKY SCHOOL"], [290.0, "THE STORM GATE"], [560.0, "THUNDER BIRD ROCKS"], [820.0, "THE FLOATING LAKE"], [1120.0, "HOME VALLEY"]]
const POINTS := {"gold": 100, "boost": 150, "star": 500, "home": 1000}
const COLORS := {"gold": Color(1.0, 0.72, 0.1), "boost": Color(0.1, 0.75, 1.0), "star": Color(1.0, 0.45, 0.9), "home": Color(1.0, 0.4, 0.7)}

var home: HomeWorld
var length := 0.0
var ride_s := 0.0              # how far along the course you are (metres)
var riding := false
var finished := false
var score := 0
var streak := 0
var best_streak := 0
var max_score := 0
var missed := 0
var _arc_s := PackedFloat32Array()
var _arc_t := PackedFloat32Array()
var _next := 0
var _boost_t := 0.0
var _start_t := 0.0
var _bolts: Array = []         # [centre, timer, column]
var _section := -1
var _hud: CanvasLayer
var _score_l: Label
var _streak_l: Label
var _rings_l: Label
var _pops: Control
var _results: PanelContainer
var _trail: CPUParticles3D
var _wind: CPUParticles3D
var _wind_boost: CPUParticles3D
var _rng := RandomNumberGenerator.new()

static func build_in(h: HomeWorld) -> SkyRide:
	var r := SkyRide.new()
	r.name = "SkyRide"
	r.home = h
	h.add_child(r)
	r._build()
	return r

func _build() -> void:
	_rng.seed = 2026
	_arc_table()
	_rings()
	_storm()
	_rocks()
	_lake()
	_rainbow_arch(1090.0)
	_lanterns()
	_balloons()
	_pastel_clouds()
	_make_hud()

# --- the course, measured in metres ------------------------------------------------
func _arc_table() -> void:
	var prev := home.path_point(0.0)
	var acc := 0.0
	_arc_s.append(0.0); _arc_t.append(0.0)
	for i in range(1, 3001):
		var t := float(i) / 3000.0
		var p := home.path_point(t)
		acc += p.distance_to(prev)
		prev = p
		_arc_s.append(acc); _arc_t.append(t)
	length = acc

func t_at(s: float) -> float:
	s = clampf(s, 0.0, length)
	var lo := 0
	var hi := _arc_s.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _arc_s[mid] < s:
			lo = mid
		else:
			hi = mid
	var span := _arc_s[hi] - _arc_s[lo]
	var u := 0.0 if span <= 0.0 else (s - _arc_s[lo]) / span
	return lerpf(_arc_t[lo], _arc_t[hi], u)

func point(s: float) -> Vector3:
	return home.path_point(t_at(s))

func forward(s: float) -> Vector3:
	var d := point(s + 3.0) - point(s - 3.0)
	return d.normalized() if d.length() > 0.01 else Vector3.BACK

func right_of(fwd: Vector3) -> Vector3:
	var r := Vector3(-fwd.z, 0, fwd.x)
	return r.normalized() if r.length() > 0.01 else Vector3.RIGHT

## The point on the course nearest to `p`, searched near where you were.
func nearest_s(p: Vector3, around: float) -> float:
	var best := around
	var bd := INF
	var s := maxf(0.0, around - 40.0)
	while s <= minf(length, around + 80.0):
		var d := point(s).distance_squared_to(p)
		if d < bd:
			bd = d; best = s
		s += 2.0
	return best

func at(s: float, ox: float, oy: float) -> Vector3:
	return point(s) + right_of(forward(s)) * ox + Vector3(0, oy, 0)

# --- the rings --------------------------------------------------------------------
func _rings() -> void:
	var plan: Array = []          # [s, sideways, up, kind]
	# Sky School: straight, a gentle slalom, then up and down
	var s := 70.0
	for i in 3:
		plan.append([s, 0.0, 0.0, "gold"]); s += 34.0
	for i in 4:
		plan.append([s, 5.0 if i % 2 == 0 else -5.0, 0.0, "gold"]); s += 32.0
	plan.append([s, 0.0, 5.0, "gold"]); s += 32.0
	plan.append([s, 0.0, -4.0, "gold"]); s += 32.0
	# the Storm Gate: weave from side to side past the lightning columns
	s = 310.0
	for i in 7:
		plan.append([s, 6.0 if i % 2 == 0 else -6.0, 2.0 if i % 3 == 0 else -1.0, "gold"]); s += 33.0
	plan.append([s, 0.0, 3.0, "boost"])
	# Thunder Bird Rocks: a corkscrew round the course, then a diving star
	s = 590.0
	for i in 6:
		var a := i * PI / 3.0
		plan.append([s, cos(a) * 6.0, sin(a) * 5.0, "gold"]); s += 30.0
	plan.append([s, 0.0, -6.0, "star"]); s += 34.0
	plan.append([s, 0.0, 1.0, "boost"])
	# the Floating Lake: rings up to the waterfall (a star right in the falling
	# water), then down and under the rainbow (another star)
	s = 850.0
	for i in 4:
		plan.append([s, -5.0 + i * 3.3, 3.0 - i * 2.0, "gold"]); s += 34.0
	plan.append([s, 4.0, 0.0, "gold"]); s += 34.0
	plan.append([1000.0, 0.0, -2.0, "star"])
	plan.append([1034.0, -4.0, 0.0, "gold"])
	plan.append([1062.0, 0.0, -3.0, "gold"])
	plan.append([1090.0, 0.0, -1.0, "star"])
	# Home Valley: the spiral down, a last boost, and home
	s = 1130.0
	for i in 8:
		plan.append([s, sin(i * 1.1) * 6.0, cos(i * 0.9) * 2.5, "boost" if i == 4 else "gold"]); s += 34.0
	for r in plan:
		if float(r[0]) < length - 40.0:
			_ring(at(float(r[0]), float(r[1]), float(r[2])), forward(float(r[0])), String(r[3]), float(r[0]))
	# the welcome-home arch over the yard
	var hm := home.ground(HomeWorld.LAND.x, HomeWorld.LAND.z) + Vector3(0, 4.0, 0)
	_ring(hm, (hm - point(length - 40.0)).normalized() * Vector3(1, 0, 1), "home", length)
	# the best score you could get: every ring, one long streak
	var st := 0
	for rg in home.rings:
		st += 1
		max_score += int(POINTS[rg[3]] * (1.0 + minf(st, 20) * 0.1))

func _ring(c: Vector3, nrm: Vector3, kind: String, s: float) -> void:
	var n := Node3D.new(); add_child(n); n.global_position = c
	var r := {"gold": 4.4, "boost": 4.0, "star": 3.3, "home": 6.0}[kind] as float
	var col: Color = COLORS[kind]
	var bands: Array = [[r, col]]
	if kind == "star":
		bands = [[r, Color(1.0, 0.3, 0.3)], [r - 0.32, Color(1.0, 0.85, 0.3)], [r - 0.64, Color(0.35, 0.95, 0.5)], [r - 0.96, Color(0.4, 0.6, 1.0)]]
	for b in bands:
		var tor := MeshInstance3D.new(); var tm := TorusMesh.new()
		tm.inner_radius = float(b[0]) - (0.32 if kind == "star" else 0.4); tm.outer_radius = float(b[0])
		tm.rings = 36; tm.ring_segments = 10
		tor.mesh = tm
		tor.material_override = FX.beam_material(b[1], 1.05, 1.0, false)     # (bright, true colours: the sunset sky is pale)
		tor.rotation.x = PI * 0.5
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(tor)
	if kind == "boost":
		# a second, spinning ring inside: whoosh
		var spin := Node3D.new(); spin.name = "Spin"; n.add_child(spin)
		var inner := MeshInstance3D.new(); var im := TorusMesh.new(); im.inner_radius = r - 1.25; im.outer_radius = r - 1.0
		im.rings = 6; im.ring_segments = 4
		inner.mesh = im; inner.material_override = FX.beam_material(Color(0.85, 1.0, 1.0), 3.0, 0.9, false)
		inner.rotation.x = PI * 0.5
		spin.add_child(inner)
	if kind == "star":
		var star := Node3D.new(); star.name = "Star"; n.add_child(star)
		for a in [0.0, PI * 0.5]:
			var arm := MeshInstance3D.new(); var bm2 := BoxMesh.new(); bm2.size = Vector3(0.35, 1.5, 0.12)
			arm.mesh = bm2; arm.material_override = FX.beam_material(Color(1.0, 0.95, 0.6), 3.5, 1.0, false)
			arm.rotation.z = a + PI * 0.25
			star.add_child(arm)
	var sp := CPUParticles3D.new(); sp.amount = 18; sp.lifetime = 1.4
	sp.mesh = FX.quad(0.16); sp.material_override = FX.glow_material(col, 2.0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; sp.emission_ring_axis = Vector3(0, 0, 1)
	sp.emission_ring_radius = r; sp.emission_ring_inner_radius = r - 0.4; sp.emission_ring_height = 0.1
	sp.gravity = Vector3.ZERO; sp.spread = 180; sp.initial_velocity_max = 0.5; sp.color_ramp = FX._fade_ramp(col)
	n.add_child(sp)
	var nn := nrm.normalized() if nrm.length() > 0.01 else Vector3.BACK
	n.look_at(c + nn, Vector3.UP if absf(nn.y) < 0.95 else Vector3.RIGHT)
	if kind == "home":
		var lbl := Label3D.new(); lbl.text = "WELCOME HOME"; lbl.font_size = 96; lbl.pixel_size = 0.01; lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.85, 0.9); lbl.position.y = r + 1.2; lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		n.add_child(lbl)
	# [node, centre, normal, kind, passed, radius, missed, s]
	home.rings.append([n, c, nn, kind, false, r, false, s])

func _check_rings() -> void:
	var p := home.player
	var pp := p.global_position + Vector3(0, 1.0, 0)
	for i in home.rings.size():
		var rg: Array = home.rings[i]
		if rg[4] or rg[6]:
			continue
		var c: Vector3 = rg[1]
		var rel := pp - c
		var along: float = rel.dot(rg[2])
		if absf(rel.length()) > 60.0:
			continue
		var side := (rel - (rg[2] as Vector3) * along).length()
		if absf(along) < 2.2 and side < float(rg[5]) + 0.3:
			_hit(i)
		elif String(rg[3]) != "home" and ((along > 2.5 and along < 30.0 and side < 30.0) or float(rg[7]) < ride_s - 25.0):
			_miss(i)
	# the next ring to go for pulses
	_next = -1
	for i in home.rings.size():
		var rg2: Array = home.rings[i]
		if not rg2[4] and not rg2[6]:
			_next = i
			break
	for i in home.rings.size():
		var rg3: Array = home.rings[i]
		if rg3[4] or rg3[6]:
			continue
		var nd: Node3D = rg3[0]
		var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() * 0.01) if i == _next else 0.0)
		nd.scale = Vector3.ONE * pulse
		var star := nd.get_node_or_null("Star")
		if star:
			(star as Node3D).rotation.z += 0.05
		var spin := nd.get_node_or_null("Spin")
		if spin:
			(spin as Node3D).rotation.z += 0.12

func _hit(i: int) -> void:
	var rg: Array = home.rings[i]
	rg[4] = true
	home.rings_passed += 1
	var kind := String(rg[3])
	var c: Vector3 = rg[1]
	if kind != "home":
		home.checkpoint = c
	streak += 1
	best_streak = maxi(best_streak, streak)
	var pts := int(POINTS[kind] * (1.0 + minf(streak, 20) * 0.1))
	score += pts
	Sfx.play_pitched("pickup", -3.0, 0.9 + minf(streak, 14) * 0.055)
	var col: Color = COLORS[kind]
	FX.burst(c, col, 50, 7.0, 0.16, 0.6, 0.0)
	if kind == "star":
		for k in 6:
			FX.burst(c, Color.from_hsv(k / 6.0, 0.7, 1.0), 14, 9.0, 0.14, 0.8, 0.0)
		Sfx.play("levelup", -6.0, 0.0)
	var n: Node3D = rg[0]
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 1.7, 0.3)
	tw.tween_property(n, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(n.queue_free)
	match kind:
		"boost":
			home.player.ride_boost = 0.75
			home.player.fov_kick = 16.0
			_boost_t = 1.4
			Sfx.play("spell", -2.0, 0.0)
			_pop("BOOST!  +%d" % pts, Color(0.5, 0.9, 1.0), 40)
		"star":
			_pop("STAR!  +%d" % pts, Color(1.0, 0.7, 1.0), 44)
		"home":
			_pop("HOME!  +%d" % pts, Color(1.0, 0.75, 0.85), 44)
			_finish()
		_:
			_pop("+%d" % pts, Color(1.0, 0.92, 0.6), 30)
	if streak in [5, 10, 15, 20, 30]:
		_pop("STREAK x%d!" % streak, Color(0.6, 1.0, 0.6), 38, 0.4)
	Game.add_gold(2)

func _miss(i: int) -> void:
	var rg: Array = home.rings[i]
	rg[6] = true
	missed += 1
	home.checkpoint = rg[1]
	if streak >= 3:
		_pop("streak lost", Color(1.0, 0.5, 0.4), 26)
	streak = 0
	var n: Node3D = rg[0]
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.6, 0.4)
	tw.tween_callback(n.queue_free)

# --- riding -------------------------------------------------------------------------
func start() -> void:
	if riding or finished:
		return
	riding = true
	_start_t = 0.0
	ride_s = nearest_s(home.player.global_position, 0.0)
	_trail_on()
	Game.say("THE SKY RIDE! Steer with the stick, hold FLY (JUMP) to climb, BLOCK to dive.", Color(1.0, 0.92, 0.6))

func _physics_process(delta: float) -> void:
	_bolt_step(delta)
	var p: Player = home.player if home else null
	if p == null or not riding:
		return
	_start_t += delta
	ride_s = nearest_s(p.global_position, ride_s)
	var fwd := forward(ride_s + 10.0)
	var c := point(ride_s)
	var rel := p.global_position + Vector3(0, 1.0, 0) - c
	var r := right_of(fwd)
	var lat := rel.dot(r)
	var d := fwd
	# a soft corridor: wander too far and the dragonfly drifts back to the course
	if absf(lat) > 14.0:
		d -= r * signf(lat) * minf((absf(lat) - 14.0) * 0.06, 0.6)
	if rel.y > 16.0:
		d.y -= minf((rel.y - 16.0) * 0.05, 0.5)
	elif rel.y < -12.0:
		d.y += minf((-12.0 - rel.y) * 0.06, 0.6)
	p.ride_dir = d.normalized()
	# start gently: a moment to get going, and slower at Sky School
	var cruise := 17.0 if ride_s < 250.0 else (19.0 if ride_s > 1120.0 else 21.0)
	p.ride_speed = cruise * smoothstep(0.0, 1.5, _start_t)
	_check_rings()
	# keep the camera behind you (not the high overhead view) so you can see ahead
	p.zoom_target = clampf(p.zoom_target, 2.5, 4.2)
	_boost_t -= delta
	if _wind_boost:
		_wind_boost.emitting = _boost_t > 0.0
	# a new part of the course: its name across the screen
	var sec := 0
	for k in SECTIONS.size():
		if ride_s >= float(SECTIONS[k][0]):
			sec = k
	if sec != _section:
		_section = sec
		home.area = String(SECTIONS[sec][1])
		home._show_banner(home.area)
		if sec == 1:
			Game.say("Lightning strikes where the columns glow. Fly through the rings to stay clear!", Color(1.0, 0.92, 0.5))
		elif sec == 3:
			Game.say("Rainbow STAR rings are worth five gold ones!", Color(1.0, 0.7, 1.0))
	if ride_s > length - 6.0 and not finished:
		_finish()

func _process(_delta: float) -> void:
	if _hud == null:
		return
	var on := riding or (finished and _results and _results.visible)
	_score_l.visible = riding
	_streak_l.visible = riding and streak >= 2
	_rings_l.visible = riding
	if riding:
		_score_l.text = "SCORE  %s" % _commas(score)
		_streak_l.text = "STREAK x%d" % streak
		_streak_l.add_theme_color_override("font_color", Color.from_hsv(fmod(streak * 0.07, 1.0), 0.5, 1.0))
		var total := home.rings.size()
		_rings_l.text = "RINGS  %d / %d" % [home.rings_passed, total]
	if _trail and home.player:
		_trail.global_position = home.player.global_position + Vector3(0, 0.9, 0)
	if not on and _trail and _trail.emitting and finished:
		_trail.emitting = false

func _finish() -> void:
	if finished:
		return
	finished = true
	riding = false
	if home.player:
		home.player.ride_dir = Vector3.ZERO
		home.player.ride_boost = 0.0
	if _wind:
		_wind.emitting = false
	if _wind_boost:
		_wind_boost.emitting = false
	var frac := float(score) / maxf(float(max_score), 1.0)
	var all_rings := missed == 0
	var medal := "RAINBOW" if all_rings and frac > 0.6 else ("GOLD" if frac >= 0.7 else ("SILVER" if frac >= 0.45 else ("BRONZE" if frac >= 0.2 else "")))
	var best := int(Game.flags.get("sky_ride_best", 0))
	var new_best := score > best
	if new_best:
		Game.flags["sky_ride_best"] = score
		Game.flags["sky_ride_medal"] = medal
	_show_results(medal, new_best, best)
	Game.say("Now glide down and land in the yard!", Color(1.0, 0.85, 0.9))
	for k in 6:
		get_tree().create_timer(0.3 * k).timeout.connect(func() -> void:
			if home.player:
				var at2 := home.player.global_position + Vector3(randf_range(-14, 14), randf_range(6, 16), randf_range(-14, 14))
				FX.burst(at2, Color.from_hsv(randf(), 0.7, 1.0), 60, 8.0, 0.22, 1.1, -2.0)
				Sfx.play_at("pop", at2, -4.0, 0.3))

static func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out

# --- the lightning of the Storm Gate ---------------------------------------------
func _storm() -> void:
	for k in 40:
		var s := _rng.randf_range(290.0, 560.0)
		var p := at(s, _rng.randf_range(-45.0, 45.0), _rng.randf_range(8.0, 24.0))
		var r := _rng.randf_range(5.0, 9.0)
		home._puff(p, Vector3(r, r * 0.6, r), Color(0.45, 0.42, 0.55))
	# a column beside each weaving ring, on the course itself: go through the
	# rings and you stay clear; cut the corner and you might get zapped
	for k in 7:
		var c := at(310.0 + k * 33.0, 0.0, 0.0)
		var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.4; cm.bottom_radius = 2.4; cm.height = 40.0
		cm.cap_top = false; cm.cap_bottom = false
		col.mesh = cm; col.material_override = FX.beam_material(Color(1.0, 0.95, 0.4), 1.5, 0.5, true)
		col.visible = false; col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(col); col.global_position = c
		_bolts.append([c, _rng.randf_range(0.5, 3.0), col])

func _bolt_step(delta: float) -> void:
	if finished:
		return
	var p: Player = home.player if home else null
	for b in _bolts:
		b[1] -= delta
		var col: MeshInstance3D = b[2]
		if b[1] <= 0.0:
			if not col.visible:
				col.visible = true                 # warning: the column glows
				b[1] = 1.0
			else:
				col.visible = false
				b[1] = _rng.randf_range(1.5, 3.0)
				var c: Vector3 = b[0]
				FX.beam(c + Vector3(0, 22, 0), c - Vector3(0, 18, 0), Color(1.0, 0.97, 0.6), 0.5, 0.35)
				FX.flash_light(c, Color(1.0, 0.95, 0.6), 10.0, 30.0, 0.3)
				Sfx.play_at("thunder", c, -2.0, 0.1)
				if p:
					var pp := p.global_position
					if Vector2(pp.x - c.x, pp.z - c.z).length() < 3.0 and absf(pp.y - c.y) < 20.0:
						p.take_damage(Game.max_hp() * 0.1, c, 3.0)
						streak = 0
						_pop("ZAP!", Color(1.0, 0.95, 0.4), 40)

# --- scenery ------------------------------------------------------------------------
func _rocks() -> void:
	for k in 5:
		var s := 600.0 + k * 50.0
		var side := -1.0 if k % 2 == 0 else 1.0
		var c := at(s, side * _rng.randf_range(16.0, 22.0), -_rng.randf_range(6.0, 10.0))
		home._rock(c, _rng.randf_range(5.0, 7.0))
		var nest := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 1.2
		var straw := StandardMaterial3D.new(); straw.albedo_color = Color(0.8, 0.65, 0.35)
		nest.mesh = tm; nest.material_override = straw; add_child(nest); nest.global_position = c + Vector3(0, 0.15, 0)
		var e := Enemy.new()
		e.configure("thunder_bird", "", 0.0)
		e.position = c + Vector3(0, 0.4, 0)
		home.add_child(e)

func _lake() -> void:
	var p := point(1000.0)
	var c := p + Vector3(-26.0, 10.0, 0)
	home._rock(c, 16.0)
	var water := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = 12.0; wc.bottom_radius = 12.0; wc.height = 0.1
	wc.radial_segments = 32
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.3, 0.6, 0.9, 0.8); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05; wm.metallic = 0.3; wm.emission_enabled = true; wm.emission = Color(0.1, 0.3, 0.5); wm.emission_energy_multiplier = 0.4
	water.mesh = wc; water.material_override = wm; add_child(water); water.global_position = c + Vector3(0, 0.05, 0)
	# the waterfall pours off the edge right across the course (a star ring in it)
	home._waterfall_x = Vector3(p.x, c.y, p.z)
	var fall := CPUParticles3D.new(); fall.amount = 260; fall.lifetime = 2.2
	fall.mesh = FX.quad(0.3); fall.material_override = FX.glow_material(Color(0.75, 0.88, 1.0), 0.7)
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; fall.emission_box_extents = Vector3(0.6, 0.2, 3.0)
	fall.direction = Vector3(0.6, -1, 0); fall.spread = 6; fall.initial_velocity_min = 3.0; fall.initial_velocity_max = 5.0
	fall.gravity = Vector3(0, -14, 0); fall.scale_amount_min = 1.0; fall.scale_amount_max = 2.5
	add_child(fall); fall.global_position = Vector3(p.x - 10.0, c.y, p.z)
	var sheet := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(7.0, 44.0)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.7, 0.85, 1.0, 0.35); sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.emission_enabled = true; sm.emission = Color(0.5, 0.7, 0.9); sm.emission_energy_multiplier = 0.4
	sheet.mesh = qm; sheet.material_override = sm; add_child(sheet)
	sheet.global_position = Vector3(p.x, c.y - 20.0, p.z)
	var f := forward(1000.0)
	sheet.rotation.y = atan2(f.x, f.z)
	var mist := CPUParticles3D.new(); mist.amount = 30; mist.lifetime = 3.0
	mist.mesh = FX.quad(3.0); mist.material_override = FX.glow_material(Color(0.9, 0.95, 1.0), 0.3)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; mist.emission_sphere_radius = 4.0
	mist.gravity = Vector3(0, 0.5, 0); mist.spread = 180; mist.initial_velocity_max = 1.0
	add_child(mist); mist.global_position = Vector3(p.x, c.y - 30.0, p.z)

## A great glowing rainbow arching over the course: fly under it.
func _rainbow_arch(s: float) -> void:
	var c := point(s)
	var f := forward(s)
	var r := right_of(f)
	var R := 34.0
	var w := 8.0
	var centre := c + Vector3(0, 7.0 - R, 0)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var steps := 48
	for i in steps + 1:
		var a := PI * float(i) / steps
		var dir := r * cos(a) + Vector3.UP * sin(a)
		var fade := smoothstep(0.0, 0.25, sin(a))
		for j in 8:
			var k := float(j) / 7.0
			verts.append(centre + dir * (R - w * k))
			var cc := Color.from_hsv(k * 0.78, 0.75, 1.0)
			cols.append(Color(cc.r, cc.g, cc.b, 0.75 * fade))
	var idx := PackedInt32Array()
	for i in steps:
		for j in 7:
			var a0 := i * 8 + j
			var b0 := (i + 1) * 8 + j
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new(); mi.mesh = am; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Paper lanterns floating beside the course all the way home.
func _lanterns() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cm := CylinderMesh.new(); cm.top_radius = 0.45; cm.bottom_radius = 0.38; cm.height = 1.0; cm.radial_segments = 10
	mm.mesh = cm
	var spots: Array = []
	var s := 110.0
	while s < length - 60.0:
		for sd in [-1.0, 1.0]:
			spots.append([at(s, sd * _rng.randf_range(10.0, 15.0), _rng.randf_range(-3.0, 4.0)), Color.from_hsv(_rng.randf_range(0.0, 0.14) if _rng.randf() < 0.7 else _rng.randf_range(0.85, 0.95), 0.7, 1.0)])
		s += 46.0
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i][0]))
		mm.set_instance_color(i, spots[i][1])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## Hot air balloons drifting in the sunset.
func _balloons() -> void:
	var palette := [Color(1.0, 0.35, 0.35), Color(1.0, 0.75, 0.2), Color(0.35, 0.7, 1.0), Color(0.6, 0.4, 1.0), Color(0.35, 0.85, 0.5), Color(1.0, 0.5, 0.8), Color(1.0, 0.6, 0.25)]
	for k in 7:
		var s := 160.0 + k * 175.0
		if s > length - 120.0:
			break
		var c := at(s, (-1.0 if k % 2 == 0 else 1.0) * _rng.randf_range(24.0, 38.0), _rng.randf_range(4.0, 14.0))
		var n := Node3D.new(); add_child(n); n.global_position = c
		var col: Color = palette[k % palette.size()]
		var env := StandardMaterial3D.new(); env.albedo_color = col; env.roughness = 0.6
		var stripe := StandardMaterial3D.new(); stripe.albedo_color = col.lightened(0.6); stripe.roughness = 0.6
		var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 3.2; sm.height = 7.4
		b.mesh = sm; b.material_override = env; n.add_child(b)
		for y in [-0.6, 1.4]:
			var band := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 3.0; tm.outer_radius = 3.35
			band.mesh = tm; band.material_override = stripe; band.position.y = y; n.add_child(band)
		var basket := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.4, 1.0, 1.4)
		var wicker := StandardMaterial3D.new(); wicker.albedo_color = Color(0.6, 0.42, 0.22)
		basket.mesh = bm; basket.material_override = wicker; basket.position.y = -5.4; n.add_child(basket)
		var fire := MeshInstance3D.new(); var fq := QuadMesh.new(); fq.size = Vector2(0.6, 0.8)
		fire.mesh = fq; fire.material_override = FX.glow_material(Color(1.0, 0.6, 0.2), 3.0)
		(fire.material_override as BaseMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fire.position.y = -4.4; n.add_child(fire)

func _pastel_clouds() -> void:
	var tints := [Color(1.0, 0.8, 0.88), Color(0.88, 0.82, 1.0), Color(1.0, 0.9, 0.75), Color(0.8, 0.92, 1.0)]
	for k in 60:
		var s := _rng.randf_range(40.0, length - 200.0)
		if s > 290.0 and s < 560.0:
			continue          # (the Storm Gate has its own dark clouds)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var p := at(s, side * _rng.randf_range(20.0, 55.0), _rng.randf_range(-14.0, 10.0))
		var r := _rng.randf_range(4.0, 8.0)
		home._puff(p, Vector3(r, r * 0.55, r), tints[k % tints.size()])

# --- effects round the hero ----------------------------------------------------------
func _trail_on() -> void:
	var p := home.player
	if p == null:
		return
	_trail = CPUParticles3D.new(); _trail.amount = 110; _trail.lifetime = 1.1
	_trail.mesh = FX.quad(0.5)
	var tm := StandardMaterial3D.new()          # (not additive: the colours must show against the bright sky)
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tm.albedo_texture = FX.soft_texture()
	tm.vertex_color_use_as_albedo = true
	_trail.material_override = tm
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _trail.emission_sphere_radius = 0.25
	_trail.gravity = Vector3.ZERO; _trail.initial_velocity_max = 0.2
	var sc := Curve.new(); sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 0.1)); _trail.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0])
	g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.65, 0.2), Color(1, 1, 0.3), Color(0.3, 1, 0.4), Color(0.3, 0.6, 1), Color(0.7, 0.35, 1), Color(1, 0.4, 0.9, 0)])
	_trail.color_ramp = g
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	# wind streaking past the camera (thicker in a boost)
	var cam := p.camera
	if cam:
		_wind = _streaks(18, Color(1, 1, 1, 0.35), 34.0)
		cam.add_child(_wind)
		_wind_boost = _streaks(60, Color(0.6, 0.9, 1.0, 0.7), 60.0)
		_wind_boost.emitting = false
		cam.add_child(_wind_boost)

func _streaks(n: int, col: Color, v: float) -> CPUParticles3D:
	var w := CPUParticles3D.new(); w.amount = n; w.lifetime = 0.5; w.local_coords = true
	var q := QuadMesh.new(); q.size = Vector2(0.03, 1.4)
	w.mesh = q; w.material_override = FX.glow_material(col, 1.5)
	(w.material_override as BaseMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	w.particle_flag_align_y = true
	w.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; w.emission_box_extents = Vector3(9.0, 6.0, 2.0)
	w.position = Vector3(0, 0, -16.0)
	w.direction = Vector3(0, 0, 1); w.spread = 2.0
	w.initial_velocity_min = v; w.initial_velocity_max = v * 1.3
	w.gravity = Vector3.ZERO
	w.color_ramp = FX._fade_ramp(col)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return w

# --- the HUD --------------------------------------------------------------------------
func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_font_override("font", SignText.font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_hud() -> void:
	_hud = CanvasLayer.new(); _hud.layer = 5; add_child(_hud)
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -300; top.offset_right = 300; top.offset_top = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	_score_l = _label(44, Color(1.0, 0.92, 0.55)); top.add_child(_score_l)
	_streak_l = _label(30, Color(0.6, 1.0, 0.6)); top.add_child(_streak_l)
	_rings_l = _label(24, Color(1.0, 0.95, 0.85))
	_rings_l.position = Vector2(24, 300); _rings_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud.add_child(_rings_l)
	_pops = Control.new(); _pops.set_anchors_preset(Control.PRESET_FULL_RECT); _pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_pops)
	for l in [_score_l, _streak_l, _rings_l]:
		(l as Label).visible = false

## Big numbers that float up and fade: "+120", "BOOST!", "STREAK x10!"
func _pop(txt: String, col: Color, size: int, delay := 0.0) -> void:
	var l := _label(size, col)
	l.text = txt
	_pops.add_child(l)
	var vs := _pops.get_viewport_rect().size
	l.position = Vector2(vs.x * 0.5 - 200.0 + randf_range(-30, 30), vs.y * 0.38)
	l.size = Vector2(400, 60)
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(l, "scale", Vector2.ONE * 1.15, 0.1)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

func _show_results(medal: String, new_best: bool, old_best: int) -> void:
	_results = PanelContainer.new()
	_results.add_theme_stylebox_override("panel", UIKit.panel_style(0.88, Color(1.0, 0.8, 0.4), 10))
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_results.offset_left = -330; _results.offset_right = 330; _results.offset_top = -200; _results.offset_bottom = 150
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_results)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); _results.add_child(v)
	v.add_child(_label(40, Color(1.0, 0.88, 0.55)))
	(v.get_child(0) as Label).text = "SKY RIDE COMPLETE!"
	var mcol := {"RAINBOW": Color.from_hsv(0.85, 0.5, 1.0), "GOLD": Color(1.0, 0.82, 0.3), "SILVER": Color(0.85, 0.88, 0.95), "BRONZE": Color(0.85, 0.55, 0.3)}.get(medal, Color(0.9, 0.9, 0.9)) as Color
	var ml := _label(46, mcol)
	ml.text = ("%s MEDAL!" % medal) if medal != "" else "You made it home!"
	v.add_child(ml)
	var lines := ["Score  %s" % _commas(score), "Rings  %d / %d" % [home.rings_passed, home.rings.size()], "Best streak  x%d" % best_streak]
	if new_best and old_best > 0:
		lines.append("NEW BEST! (was %s)" % _commas(old_best))
	elif old_best > 0:
		lines.append("Your best: %s" % _commas(old_best))
	for t in lines:
		var l := _label(28, Color(1.0, 0.97, 0.9))
		l.text = t
		v.add_child(l)
	if medal == "RAINBOW":
		Sfx.play("victory", -2.0, 0.0)
	_results.modulate.a = 0.0
	var tw := _results.create_tween()
	tw.tween_property(_results, "modulate:a", 1.0, 0.4)
	tw.tween_interval(6.5)
	tw.tween_property(_results, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_results.hide)
