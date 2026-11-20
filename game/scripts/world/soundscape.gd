extends Node3D
class_name Soundscape
## The sounds of the valley around the cabin. Instead of one short loop of the
## same chirp, it plays a soft breeze in the trees and crickets in the grass, and
## every few seconds a different bird somewhere around you: a warbling song, a
## "fee-bee" whistle, a fast trill, a few chips, sometimes answered by another of
## its kind from across the clearing. Now and then a dove coos far off, a cuckoo
## calls, a woodpecker drums or a gust rustles the leaves. Each call comes from
## its own spot (up in the trees, 8-40 m away), at a slightly different pitch, so
## it never sounds like a loop. Bees buzz by the garden.
##
## It only plays near the valley (not up in the sky on the Sky Ride), and indoors
## it's quieter and calmer (inside_fn).

const CALLS := [
	# [sounds, weight, volume dB, min dist, max dist, answers?]
	[["bird_warble_1", "bird_warble_2", "bird_warble_3"], 30, -9.0, 8.0, 32.0, true],
	[["bird_whistle_1", "bird_whistle_2"], 16, -11.0, 10.0, 36.0, true],
	[["bird_trill_1", "bird_trill_2"], 14, -11.0, 8.0, 30.0, false],
	[["bird_chip_1", "bird_chip_2"], 18, -10.0, 6.0, 24.0, true],
	[["dove"], 6, -15.0, 25.0, 45.0, false],
	[["cuckoo"], 4, -17.0, 30.0, 50.0, false],
	[["woodpecker"], 5, -14.0, 18.0, 40.0, false],
	[["leaves_rustle"], 9, -17.0, 6.0, 18.0, false],
]

var radius := 90.0                 # beyond this (or high above), the valley goes quiet
var inside_fn: Callable            # optional: returns true when the listener is indoors
var bees_at := Vector3.INF         # optional: where the garden is
var calls_played := 0              # (for the tests)
var heard: Array = []              # the last calls played (for the tests)

var _rng := RandomNumberGenerator.new()
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 1.5
var _last := ""
var _breeze: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _bees: AudioStreamPlayer3D
var _t := 0.0
var _level := 0.0                  # 0 silent .. 1 full (fades in and out)
var _answers: Array = []           # [time left, sound, position, pitch, volume]

static func make(parent: Node3D, at: Vector3, garden := Vector3.INF) -> Soundscape:
	var s := Soundscape.new()
	s.bees_at = garden
	parent.add_child(s)
	s.global_position = at
	return s

func _ready() -> void:
	_rng.randomize()
	for i in 5:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 90.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool.append(p)
	_breeze = AudioStreamPlayer.new(); _breeze.stream = Sfx.get_stream("loop_breeze"); _breeze.volume_db = -80.0; add_child(_breeze)
	_crickets = AudioStreamPlayer.new(); _crickets.stream = Sfx.get_stream("loop_crickets"); _crickets.volume_db = -80.0; add_child(_crickets)
	_breeze.play(_rng.randf() * 20.0)
	_crickets.play(_rng.randf() * 14.0)
	if bees_at != Vector3.INF:
		_bees = AudioStreamPlayer3D.new(); _bees.stream = Sfx.get_stream("loop_bees")
		_bees.unit_size = 2.5; _bees.max_distance = 14.0; _bees.volume_db = -12.0
		add_child(_bees)
		_bees.global_position = bees_at + Vector3(0, 0.6, 0)
		_bees.play(_rng.randf() * 10.0)

func _listener() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else global_position

func _process(delta: float) -> void:
	_t += delta
	var at := _listener()
	var off := at - global_position
	var near := Vector2(off.x, off.z).length() < radius and off.y < 45.0
	var inside := inside_fn.is_valid() and bool(inside_fn.call(at))
	_level = move_toward(_level, 1.0 if near else 0.0, delta * 0.5)
	# the breeze swells and dies away in slow gusts; indoors you only just hear it
	var gust := 0.5 + 0.5 * sin(_t * 0.23) * sin(_t * 0.071 + 1.0)
	var room := -9.0 if inside else 0.0
	_breeze.volume_db = _db(_level) + room - 20.0 + gust * 5.0
	_crickets.volume_db = _db(_level) + room - 27.0
	if _bees:
		_bees.volume_db = -12.0 if near else -80.0
	if not near:
		return
	for a in _answers.duplicate():
		a[0] -= delta
		if a[0] <= 0.0:
			_answers.erase(a)
			_play(a[1], a[2], a[3], a[4])
	_next -= delta
	if _next > 0.0:
		return
	# indoors, birds are fewer and further between
	_next = _rng.randf_range(1.6, 5.0) * (2.2 if inside else 1.0)
	var c := _pick()
	var names: Array = c[0]
	var nm: String = names[_rng.randi() % names.size()]
	if nm == _last and names.size() > 1:
		nm = names[(names.find(nm) + 1) % names.size()]
	_last = nm
	var pos := _spot(at, float(c[3]), float(c[4]))
	var pitch := _rng.randf_range(0.92, 1.08)
	var vol := float(c[2]) + _rng.randf_range(-3.0, 1.5) + room
	_play(nm, pos, pitch, vol)
	# sometimes another bird of the same kind answers from across the clearing
	if bool(c[5]) and _rng.randf() < 0.35:
		_answers.append([_rng.randf_range(0.8, 2.2), nm, _spot(at, float(c[3]), float(c[4])), pitch * _rng.randf_range(0.95, 1.05), vol - 2.0])

func _db(lv: float) -> float:
	return linear_to_db(maxf(lv, 0.0001))

func _pick() -> Array:
	var total := 0
	for c in CALLS:
		total += int(c[1])
	var r := _rng.randi() % total
	for c in CALLS:
		r -= int(c[1])
		if r < 0:
			return c
	return CALLS[0]

## Somewhere around you: a random direction, at a distance, up in the trees.
func _spot(at: Vector3, d0: float, d1: float) -> Vector3:
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(d0, d1)
	return Vector3(at.x + cos(a) * d, global_position.y + _rng.randf_range(3.0, 9.0), at.z + sin(a) * d)

func _play(nm: String, pos: Vector3, pitch: float, vol: float) -> void:
	var s := Sfx.get_stream(nm)
	if s == null:
		return
	var p: AudioStreamPlayer3D = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		return          # (plenty going on already)
	p.stream = s
	p.global_position = pos
	p.pitch_scale = pitch
	p.volume_db = vol
	p.play()
	calls_played += 1
	heard.append(nm)
	if heard.size() > 60:
		heard.pop_front()
