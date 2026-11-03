extends Node
## Sound manager. All sounds are synthesized by tools/make_audio.py.

const DIR := "res://assets/audio/"
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new(); add_child(_music_a)
	_music_b = AudioStreamPlayer.new(); add_child(_music_b)

func get_stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Missing sound: " + name)
		_streams[name] = null
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and (name.begins_with("loop_") or name.begins_with("music_")):
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_streams[name] = s
	return s

func play(name: String, vol_db := 0.0, pitch_var := 0.06) -> void:
	var s := get_stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return

func play_at(name: String, pos: Vector3, vol_db := 0.0, pitch_var := 0.08, size := 6.0) -> void:
	var s := get_stream(name)
	var tree := get_tree()
	if s == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.unit_size = size
	p.max_distance = 60.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

## Attach a looping positional sound to a node (torches, river...).
func loop_on(node: Node3D, name: String, vol_db := -6.0, size := 5.0, max_dist := 30.0) -> AudioStreamPlayer3D:
	var s := get_stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.unit_size = size
	p.max_distance = max_dist
	p.autoplay = true
	node.add_child(p)
	return p

func music(name: String, vol_db := -10.0) -> void:
	if name == _music_name:
		return
	_music_name = name
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var tw := create_tween().set_parallel(true)
	if name != "":
		incoming.stream = get_stream(name)
		incoming.volume_db = -50.0
		incoming.play()
		tw.tween_property(incoming, "volume_db", vol_db, 2.5)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -60.0, 2.5)
		tw.chain().tween_callback(outgoing.stop)

func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
