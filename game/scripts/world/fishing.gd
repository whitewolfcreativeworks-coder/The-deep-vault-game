extends Node3D
class_name FishingSpot
## Fishing at the end of the pier on the Misty Mere (Ghost Knight Castle).
##   USE          start fishing (cast the line)
##   wait...      the bobber floats; then it dips and splashes: "!"
##   ATTACK/USE   hook it, quick! Then tap ATTACK/USE fast to reel it in
##                before it gets away (the fish pulls back the whole time)
##   JUMP / move  stop fishing
## Five kinds of fish; the glowing Ghost Pike is the rare prize (and always the
## last catch of Old Gill's quest).

const FISH := [
	{"name": "Moor Minnow", "w": 34.0, "pull": 0.55, "gold": 6, "color": Color(0.75, 0.78, 0.8), "size": 0.5},
	{"name": "Bog Trout", "w": 28.0, "pull": 0.8, "gold": 12, "color": Color(0.45, 0.55, 0.35), "size": 0.75},
	{"name": "Lantern Carp", "w": 18.0, "pull": 1.0, "gold": 20, "color": Color(1.0, 0.6, 0.2), "size": 0.85, "glow": true},
	{"name": "Spooky Eel", "w": 13.0, "pull": 1.2, "gold": 26, "color": Color(0.55, 0.35, 0.75), "size": 1.0},
	{"name": "Ghost Pike", "w": 7.0, "pull": 1.45, "gold": 80, "color": Color(0.6, 0.95, 1.0), "size": 1.3, "glow": true},
]

var water_y := 0.0
var cast_dir := Vector3.FORWARD
var _p: Player
var _state := ""             # "", "cast", "wait", "bite", "reel", "caught"
var _t := 0.0
var _wait := 0.0
var _fish: Dictionary = {}
var _reel := 0.0
var _rod: Node3D
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _ui: CanvasLayer
var _bar: ProgressBar
var _label: Label
var _excl: Label3D
var _rng := RandomNumberGenerator.new()
var catches := 0

static func make(parent: Node3D, pos: Vector3, dir: Vector3, water: float) -> FishingSpot:
	var f := FishingSpot.new()
	f.name = "FishingSpot"
	f.water_y = water
	f.cast_dir = Vector3(dir.x, 0, dir.z).normalized()
	parent.add_child(f)
	f.global_position = pos
	f.add_to_group("interactable")
	f.add_to_group("fishing_spot")
	f._rng.randomize()
	# a little sign and a bucket so you know it's the place
	var sg := Label3D.new(); sg.text = "GOOD FISHING\n(press USE)"; sg.font_size = 48; sg.pixel_size = 0.005
	sg.modulate = Color(0.85, 0.95, 1.0); sg.outline_size = 10; sg.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sg.position = Vector3(0, 2.2, 0); f.add_child(sg)
	var bucket := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.22; cm.bottom_radius = 0.17; cm.height = 0.32
	bucket.mesh = cm; var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.5, 0.52, 0.55); bm.metallic = 0.6
	bucket.material_override = bm; bucket.position = Vector3(0.7, 0.16, 0.4); f.add_child(bucket)
	return f

func can_interact() -> bool:
	return _state == ""

func get_prompt() -> String:
	return "[E] Go fishing"

func interact(by: Node) -> void:
	if not (by is Player) or _state != "":
		return
	_p = by as Player
	_p.ride_vehicle(self, "")
	_p.global_position = global_position + Vector3(0, 0.05, 0)
	_p.facing = atan2(-cast_dir.x, -cast_dir.z)
	_p.yaw = _p.facing
	_p.body.rotation.y = _p.facing
	_make_gear()
	_make_ui()
	_cast()
	Game.say("Fishing! Wait for the bobber to dip, then press ATTACK to hook it. JUMP to stop.", Color(0.7, 0.9, 1.0))

func _make_gear() -> void:
	if _p.body.weapon_root:
		_p.body.weapon_root.visible = false
	_rod = Node3D.new()
	var att := _p.body._attach("handslot.r")
	att.add_child(_rod)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.45, 0.3, 0.16)
	var rod := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.03; cm.height = 1.8
	rod.mesh = cm; rod.material_override = wood; rod.position.y = 0.8; _rod.add_child(rod)
	_bobber = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.1; sm.height = 0.2; _bobber.mesh = sm
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(1.0, 0.2, 0.15); bm.emission_enabled = true
	bm.emission = Color(1.0, 0.25, 0.15); bm.emission_energy_multiplier = 0.6
	_bobber.material_override = bm
	get_tree().current_scene.add_child(_bobber)
	_line = MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = 0.006; lm.bottom_radius = 0.006; lm.height = 1.0
	_line.mesh = lm; var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color(0.9, 0.9, 0.9); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = lmat
	get_tree().current_scene.add_child(_line)
	_excl = Label3D.new(); _excl.text = "!"; _excl.font_size = 160; _excl.pixel_size = 0.006; _excl.outline_size = 24
	_excl.modulate = Color(1.0, 0.85, 0.2); _excl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _excl.no_depth_test = true
	_excl.visible = false
	get_tree().current_scene.add_child(_excl)

func _make_ui() -> void:
	_ui = CanvasLayer.new(); _ui.layer = 15; add_child(_ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_top = -230; box.offset_bottom = -150; box.offset_left = -260; box.offset_right = 260
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(box)
	_label = Label.new(); _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0)); _label.add_theme_constant_override("outline_size", 8)
	box.add_child(_label)
	_bar = ProgressBar.new(); _bar.min_value = 0.0; _bar.max_value = 1.0; _bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(520, 26)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.35, 0.8, 1.0); fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.55); bg.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill); _bar.add_theme_stylebox_override("background", bg)
	_bar.visible = false
	box.add_child(_bar)

func _float_point() -> Vector3:
	return global_position + cast_dir * 6.5 + Vector3(0, water_y - global_position.y + 0.05, 0)

func _cast() -> void:
	_state = "cast"; _t = 0.0
	_label.text = "Casting..."
	_bar.visible = false
	Sfx.play("swing", -6.0, 0.2)
	_p.body.oneshot("a1", 0.5)

func _physics_process(delta: float) -> void:
	if _state == "":
		return
	if _p == null or not is_instance_valid(_p) or _p.dead or _p.vehicle != self:
		_stop(false)
		return
	_t += delta
	var tip := (_rod.global_position + _rod.global_transform.basis.y * 1.7) if _rod else global_position + Vector3(0, 2, 0)
	var fp := _float_point()
	match _state:
		"cast":
			var k := clampf(_t / 0.6, 0.0, 1.0)
			_bobber.global_position = tip.lerp(fp, k) + Vector3(0, sin(k * PI) * 2.0, 0)
			if k >= 1.0:
				FX.burst(fp, Color(0.8, 0.9, 1.0), 12, 2.0, 0.1, 0.5, -4.0)
				Sfx.play_at("splash", fp, -10.0, 0.2)
				_state = "wait"; _t = 0.0; _wait = _rng.randf_range(2.0, 5.5)
				_label.text = "Waiting for a bite..."
		"wait":
			_bobber.global_position = fp + Vector3(0, sin(_t * 2.5) * 0.03, 0)
			if _t > _wait:
				_state = "bite"; _t = 0.0
				_fish = _pick_fish()
				_excl.visible = true
				_label.text = "BITE! Press ATTACK to hook it!"
				Sfx.play_at("splash", fp, -4.0, 0.1)
				FX.burst(fp, Color(0.8, 0.95, 1.0), 20, 3.0, 0.12, 0.5, -5.0)
		"bite":
			_bobber.global_position = fp + Vector3(0, -absf(sin(_t * 18.0)) * 0.12, 0)
			_excl.global_position = fp + Vector3(0, 1.0 + sin(_t * 10.0) * 0.05, 0)
			if _hook_pressed():
				_state = "reel"; _t = 0.0; _reel = 0.35
				_excl.visible = false
				_bar.visible = true
				_label.text = "Hooked! Tap ATTACK fast to reel it in!"
				Sfx.play("whistle", -10.0, 0.2)
			elif _t > 1.3:
				_excl.visible = false
				_label.text = "It got away! Waiting again..."
				_state = "wait"; _t = 0.0; _wait = _rng.randf_range(2.0, 4.5)
		"reel":
			_reel -= delta * 0.16 * float(_fish.pull)
			if _hook_pressed():
				_reel += 0.11
				Sfx.play("pickup", -16.0, 0.3)
			_reel = clampf(_reel, 0.0, 1.0)
			_bar.value = _reel
			var shake := Vector3(sin(_t * 23.0), 0, cos(_t * 17.0)) * 0.25 * float(_fish.pull)
			_bobber.global_position = fp.lerp(global_position + Vector3(0, water_y - global_position.y, 0), _reel * 0.6) + shake
			if _reel >= 1.0:
				_land_fish()
			elif _reel <= 0.0 or _t > 9.0:
				_label.text = "The %s got away! Waiting again..." % ("fish" if _fish.name != "Ghost Pike" else "GHOST PIKE")
				_bar.visible = false
				_state = "wait"; _t = 0.0; _wait = _rng.randf_range(2.0, 4.5)
		"caught":
			if _t > 1.8:
				_cast()
	# the fishing line from the rod tip to the bobber
	var a := tip
	var b := _bobber.global_position
	_line.global_position = (a + b) * 0.5
	var d := b - a
	if d.length() > 0.01:
		_line.basis = Basis(Quaternion(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(1, d.length(), 1))
	# stop fishing: jump or walk away
	if _state != "caught" and (Input.is_action_just_pressed("jump") or Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.6):
		_stop(true)

func _hook_pressed() -> bool:
	return Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")

func _pick_fish() -> Dictionary:
	# the last fish for Old Gill is always the Ghost Pike
	if Game.quest_state("fishing") == "active" and Game.quest_progress("fishing") >= 4:
		return FISH[4]
	var total := 0.0
	for f in FISH:
		total += float(f.w)
	var r := _rng.randf() * total
	for f in FISH:
		r -= float(f.w)
		if r <= 0.0:
			return f
	return FISH[0]

func _land_fish() -> void:
	_state = "caught"; _t = 0.0
	_bar.visible = false
	catches += 1
	var f := _fish
	_label.text = "You caught a %s!" % f.name
	Game.say("Caught a %s! (+%d gold)" % [f.name, f.gold], f.color.lerp(Color.WHITE, 0.3))
	Game.add_gold(int(f.gold))
	Game.add_xp(int(15.0 * float(f.pull)))
	Game.on_quest_item("fish")
	Game.flags["fish_caught"] = int(Game.flags.get("fish_caught", 0)) + 1
	if f.name == "Ghost Pike":
		Game.flags["ghost_pike"] = true
		FX.screen_flash(Color(0.7, 0.95, 1.0), 0.35, 0.6)
		Sfx.play("levelup", -2.0, 0.0)
	else:
		Sfx.play("coins", -6.0)
	# the fish leaps out of the water and flops into your bucket
	var fish := _fish_model(f)
	get_tree().current_scene.add_child(fish)
	var from := _bobber.global_position
	var to := global_position + Vector3(0.7, 0.4, 0.4)
	var tw := fish.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(fish):
			fish.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 2.5, 0)
			fish.rotation.z = k * TAU * 1.5, 0.0, 1.0, 1.0)
	tw.tween_callback(func() -> void:
		FX.burst(to, f.color, 20, 2.0, 0.1, 0.6, 0.0)
		fish.queue_free())
	FX.burst(from, Color(0.8, 0.95, 1.0), 30, 4.0, 0.12, 0.7, -5.0)

func _fish_model(f: Dictionary) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new(); m.albedo_color = f.color; m.roughness = 0.3; m.metallic = 0.3
	if f.get("glow", false):
		m.emission_enabled = true; m.emission = f.color; m.emission_energy_multiplier = 1.5
	var s: float = f.size
	var body := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.18 * s; sm.height = 0.36 * s
	body.mesh = sm; body.scale = Vector3(0.6, 1.0, 2.0); body.material_override = m; n.add_child(body)
	var tail := MeshInstance3D.new(); var tm := PrismMesh.new(); tm.size = Vector3(0.3 * s, 0.3 * s, 0.05)
	tail.mesh = tm; tail.material_override = m; tail.position = Vector3(0, 0, 0.42 * s); tail.rotation = Vector3(PI / 2, 0, 0)
	n.add_child(tail)
	if f.get("glow", false):
		var l := OmniLight3D.new(); l.light_color = f.color; l.light_energy = 1.5; l.omni_range = 3.0; n.add_child(l)
	return n

func _stop(by_choice: bool) -> void:
	_state = ""
	for node in [_bobber, _line, _excl]:
		if node and is_instance_valid(node):
			node.queue_free()
	if _rod and is_instance_valid(_rod):
		_rod.queue_free()
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
	_bobber = null; _line = null; _excl = null; _rod = null; _ui = null
	if _p and is_instance_valid(_p):
		if _p.body.weapon_root:
			_p.body.weapon_root.visible = true
		if _p.vehicle == self:
			_p.leave_vehicle()
		if by_choice:
			Game.say("You put the rod away.", Color(0.8, 0.85, 0.9))
	_p = null
