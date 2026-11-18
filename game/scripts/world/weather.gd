extends Node3D
class_name WeatherWorks
## Cloud Island's precipitation corner, built on the Precipitation Simulator
## (a 6th-grade science project): Adad the Weather-Keeper and his three quests.
##
##   Hailstone Rings (D, the storm layer): the Hail Tower is a storm updraft that
##       tosses you up above the freezing line and back down again. Each trip up
##       freezes a new ring of ice onto your hailstone; three rings and it's too
##       heavy for the updraft.
##   Six Sides of Snow (F, the Snow Cloud): catch six real snowflakes. Mr. Bubbles
##       has blown fake ones with four or five arms: real snowflakes have six.
##   The Glaze (G, the Ice Cloud): freezing rain has glazed the whole island in
##       slippery clear ice and put out the four sun lamps. Slide across and
##       relight them.

var w: CloudWorld
var hail_rings := 0
var _hail_above := false
var _hail_ball: Node3D
var _hail_t := 0.0
var _hud: CanvasLayer
var _hud_label: Label
var _flakes: Array = []          # [Node3D, real: bool, vel]
var _flake_t := 0.0
var _lamps: Array = []           # Node3D lamps (meta "lit")
const HAIL := Vector3(-10, 62, -108)      # the Hail Tower's base (on the storm layer)
const HAIL_R := 2.8
const HAIL_TOP := 25.0                     # how high the tower goes above its base
const FREEZE_Y := 74.0                     # the freezing line
const ADAD := Vector3(24, 20, -14)

static func build_in(cw: CloudWorld) -> WeatherWorks:
	var ww := WeatherWorks.new()
	ww.name = "WeatherWorks"
	ww.w = cw
	cw.add_child(ww)
	ww._station()
	ww._hail_tower()
	ww._snow_island()
	ww._ice_island()
	ww._make_hud()
	return ww

func _quest_on(id: String) -> bool:
	return Game.quest_state(id) == "active"

# ---------------------------------------------------------------------------
# Adad's weather station on the temple island
func _station() -> void:
	var npc := NPC.create(w, "adad", ADAD, -110.0, {"hero": "Knight", "hat": false, "hair_style": "long",
		"hair_color": Color(0.22, 0.24, 0.32), "hair_tint": Color(0.22, 0.24, 0.32), "face": "beard",
		"outfit_color": Color(0.3, 0.38, 0.62), "cape_color": Color(0.45, 0.5, 0.7), "skin_color": Color(0.78, 0.6, 0.45), "height": 1.15})
	npc.body.add_child(AngelWings.make(Color(0.62, 0.66, 0.78), 1.15))
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.55, 0.42, 0.3)
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.85, 0.7, 0.35); brass.metallic = 0.8; brass.roughness = 0.3
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.8, 0.9, 1.0, 0.35); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var at := ADAD + Vector3(2.5, 0, -2.0)
	# a rain gauge (a tall glass tube with blue water in it)
	var tube := MeshInstance3D.new(); var tcm := CylinderMesh.new(); tcm.top_radius = 0.18; tcm.bottom_radius = 0.18; tcm.height = 1.2
	tube.mesh = tcm; tube.material_override = glass; add_child(tube); tube.global_position = at + Vector3(0, 0.6, 0)
	var water := MeshInstance3D.new(); var wcm := CylinderMesh.new(); wcm.top_radius = 0.15; wcm.bottom_radius = 0.15; wcm.height = 0.5
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.3, 0.55, 0.95); wm.emission_enabled = true; wm.emission = Color(0.2, 0.4, 0.8); wm.emission_energy_multiplier = 0.5
	water.mesh = wcm; water.material_override = wm; add_child(water); water.global_position = at + Vector3(0, 0.27, 0)
	# a thermometer post
	var post := MeshInstance3D.new(); var pbm := BoxMesh.new(); pbm.size = Vector3(0.3, 1.8, 0.1)
	post.mesh = pbm; post.material_override = wood; add_child(post); post.global_position = at + Vector3(1.0, 0.9, 0)
	var mercury := MeshInstance3D.new(); var mbm := BoxMesh.new(); mbm.size = Vector3(0.06, 1.2, 0.04)
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.95, 0.2, 0.2); mm.emission_enabled = true; mm.emission = Color(0.9, 0.1, 0.1)
	mercury.mesh = mbm; mercury.material_override = mm; add_child(mercury); mercury.global_position = at + Vector3(1.0, 0.85, -0.07)
	# a weathervane that turns in the wind
	var vane_pole := MeshInstance3D.new(); var vcm := CylinderMesh.new(); vcm.top_radius = 0.04; vcm.bottom_radius = 0.05; vcm.height = 3.0
	vane_pole.mesh = vcm; vane_pole.material_override = brass; add_child(vane_pole); vane_pole.global_position = at + Vector3(-1.2, 1.5, 0.5)
	var vane := Node3D.new(); add_child(vane); vane.global_position = at + Vector3(-1.2, 3.0, 0.5)
	var arrow := MeshInstance3D.new(); var abm := BoxMesh.new(); abm.size = Vector3(0.06, 0.06, 1.2)
	arrow.mesh = abm; arrow.material_override = brass; vane.add_child(arrow)
	var tail := MeshInstance3D.new(); var tbm := BoxMesh.new(); tbm.size = Vector3(0.04, 0.35, 0.35)
	tail.mesh = tbm; tail.material_override = brass; tail.position.z = 0.55; vane.add_child(tail)
	var tw := vane.create_tween().set_loops()
	tw.tween_property(vane, "rotation:y", 1.2, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(vane, "rotation:y", -0.8, 3.5).set_trans(Tween.TRANS_SINE)
	# a chalkboard with today's weather
	var board := Label3D.new()
	board.text = "ADAD'S WEATHER WORKS\n\nToday: cloudy with a\nchance of HAIL, SNOW\nand FREEZING RAIN"
	board.font_size = 44; board.pixel_size = 0.005; board.outline_size = 10; board.modulate = Color(0.95, 0.95, 0.85)
	add_child(board); board.global_position = at + Vector3(0.2, 2.4, -0.6); board.rotation.y = deg_to_rad(-110.0)

# ---------------------------------------------------------------------------
# The Hail Tower: a storm updraft on the storm layer
func _hail_tower() -> void:
	var col := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = HAIL_R; cm.bottom_radius = HAIL_R + 0.3; cm.height = HAIL_TOP
	cm.cap_top = false; cm.cap_bottom = false
	col.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.albedo_color = Color(0.6, 0.75, 1.0, 0.13)
	col.material_override = m; col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(col); col.global_position = HAIL + Vector3(0, HAIL_TOP * 0.5, 0)
	col.add_to_group("hail_tower")
	col.set_meta("item", "hailstone")
	# swirling ice and rain going up the tower
	var sp := CPUParticles3D.new(); sp.amount = 70; sp.lifetime = 3.0
	sp.mesh = FX.quad(0.1); sp.material_override = FX.glow_material(Color(0.8, 0.9, 1.0), 1.6)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sp.emission_box_extents = Vector3(HAIL_R * 0.8, 0.3, HAIL_R * 0.8)
	sp.direction = Vector3.UP; sp.spread = 6; sp.initial_velocity_min = 6.0; sp.initial_velocity_max = 9.0
	sp.gravity = Vector3.ZERO; sp.color_ramp = FX._fade_ramp(Color(0.8, 0.9, 1.0))
	add_child(sp); sp.global_position = HAIL + Vector3(0, 0.3, 0)
	# the freezing line: a glittering ring of ice crystals around the tower
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = HAIL_R + 0.2; tm.outer_radius = HAIL_R + 0.6
	ring.mesh = tm; ring.material_override = FX.beam_material(Color(0.7, 0.9, 1.0), 2.0, 0.7, true)
	add_child(ring); ring.global_position = Vector3(HAIL.x, FREEZE_Y, HAIL.z)
	var ice := CPUParticles3D.new(); ice.amount = 40; ice.lifetime = 2.0
	ice.mesh = FX.quad(0.08); ice.material_override = FX.glow_material(Color(0.85, 0.95, 1.0), 3.0)
	ice.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; ice.emission_ring_axis = Vector3.UP
	ice.emission_ring_radius = HAIL_R + 1.2; ice.emission_ring_inner_radius = HAIL_R; ice.emission_ring_height = 0.2
	ice.gravity = Vector3.ZERO; ice.spread = 180; ice.initial_velocity_max = 0.3; ice.color_ramp = FX._fade_ramp(Color(0.85, 0.95, 1.0))
	add_child(ice); ice.global_position = Vector3(HAIL.x, FREEZE_Y, HAIL.z)
	var lbl := Label3D.new(); lbl.text = "FREEZING LINE  (below 32°F above here)"; lbl.font_size = 40; lbl.pixel_size = 0.006
	lbl.outline_size = 10; lbl.modulate = Color(0.75, 0.9, 1.0); lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(lbl); lbl.global_position = Vector3(HAIL.x, FREEZE_Y + 0.8, HAIL.z)
	var sign := Label3D.new(); sign.text = "THE HAIL TOWER\nstep in for a ride"; sign.font_size = 56; sign.pixel_size = 0.006
	sign.outline_size = 12; sign.modulate = Color(0.8, 0.9, 1.0); sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign); sign.global_position = HAIL + Vector3(0, 3.6, 0)

## The tower pushes you up past the freezing line, then lets you sink below it,
## over and over: that's how hail grows its rings.
func _hail_step(delta: float) -> void:
	var p := w.player
	var pp := p.global_position
	var inside := Vector2(pp.x - HAIL.x, pp.z - HAIL.z).length() < HAIL_R and pp.y > HAIL.y - 0.5 and pp.y < HAIL.y + HAIL_TOP + 2.0
	if not inside:
		if _hail_t > 0.0:
			_hail_t = 0.0
			if p.lift > -100.0 and not is_instance_valid(p.float_hold):
				p.lift = -999.0
		return
	_hail_t += delta
	# a 7-second storm cycle: big push up (never past the top of the tower), then
	# a lull you sink through, back below the freezing line
	var cyc := fmod(_hail_t, 7.0)
	p.lift = lerpf(9.0, 4.0, w.weight) if cyc < 4.0 else -5.0
	if pp.y > HAIL.y + HAIL_TOP - 3.0:
		p.lift = minf(p.lift, 0.0)
	# keep you in the column
	var to_c := Vector3(HAIL.x - pp.x, 0, HAIL.z - pp.z)
	p.wind = to_c * 1.5
	var above := pp.y > FREEZE_Y
	if not _quest_on("hail_rings") or Game.flags.get("cl_hailstone", false):
		_hail_above = above
		return
	if above and not _hail_above:
		hail_rings += 1
		_ring_fx(true)
		if hail_rings >= 3:
			Game.flags["cl_hailstone"] = true
			Game.on_quest_item("hailstone")
			Game.say("CRACK! Three rings of ice: your hailstone is too heavy for the updraft now. Take it to Adad!", Color(0.8, 0.95, 1.0))
			p.lift = -999.0
			p.velocity = Vector3(-to_c.x, 2.0, -to_c.z).normalized() * 6.0     # it throws you out of the column
			_hail_t = 0.0
		else:
			Game.say("Above the freezing line: the water on your hailstone freezes into ring %d! Sink back down to get it wet again." % hail_rings, Color(0.8, 0.95, 1.0))
	elif not above and _hail_above and hail_rings > 0 and hail_rings < 3:
		_ring_fx(false)
		Game.say("Below the freezing line: a fresh coat of water. Ride it back up!", Color(0.6, 0.85, 1.0))
	_hail_above = above

func _ring_fx(freeze: bool) -> void:
	var p := w.player
	if _hail_ball == null or not is_instance_valid(_hail_ball):
		_hail_ball = Node3D.new()
		p.add_child(_hail_ball)
		_hail_ball.position = Vector3(0, 2.6, 0)
	if freeze:
		var shell := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.12 + hail_rings * 0.07; sm.height = sm.radius * 2.0
		shell.mesh = sm
		var im := StandardMaterial3D.new(); im.albedo_color = Color(0.85, 0.93, 1.0, 0.45 if hail_rings % 2 == 1 else 0.75)
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; im.roughness = 0.15; im.metallic_specular = 1.0
		shell.material_override = im
		_hail_ball.add_child(shell)
		Sfx.play("clang", -10.0, 0.3)
		FX.burst(p.global_position + Vector3(0, 2.6, 0), Color(0.85, 0.95, 1.0), 24, 3.0, 0.1, 0.5, 0.0)
	else:
		Sfx.play("splash", -10.0, 0.2)
		FX.burst(p.global_position + Vector3(0, 2.6, 0), Color(0.5, 0.75, 1.0), 16, 2.0, 0.08, 0.4, -2.0)

# ---------------------------------------------------------------------------
# The Snow Cloud (F)
func _snow_island() -> void:
	var c: Vector3 = CloudWorld.ISLANDS.F.c
	var snow := CPUParticles3D.new(); snow.amount = 220; snow.lifetime = 7.0; snow.preprocess = 7.0
	snow.mesh = FX.quad(0.09); snow.material_override = FX.glow_material(Color(1, 1, 1), 1.2)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; snow.emission_box_extents = Vector3(18, 0.5, 18)
	snow.direction = Vector3.DOWN; snow.spread = 25; snow.initial_velocity_min = 0.8; snow.initial_velocity_max = 1.6
	snow.gravity = Vector3(0, -0.2, 0)
	add_child(snow); snow.global_position = c + Vector3(0, 12, 0)
	# a snow cloud hanging overhead
	for k in 14:
		var a := k * TAU / 14.0
		w._puff(c + Vector3(cos(a) * 9.0, 14.0 + randf_range(-1, 1), sin(a) * 9.0), Vector3.ONE * randf_range(3.0, 4.5), Color(0.86, 0.9, 1.0))
	# snowdrifts and a snowman
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.97, 0.98, 1.0); sm.roughness = 0.9
	for k in 10:
		var a := randf() * TAU; var d := randf_range(4.0, 12.0)
		var drift := MeshInstance3D.new(); var dm := SphereMesh.new(); dm.radius = randf_range(0.8, 1.6); dm.height = dm.radius * 0.8
		drift.mesh = dm; drift.material_override = sm; add_child(drift)
		drift.global_position = c + Vector3(cos(a) * d, -dm.radius * 0.15, sin(a) * d)
	var man := c + Vector3(-6, 0, 5)
	for k in 3:
		var ball := MeshInstance3D.new(); var bm := SphereMesh.new(); bm.radius = 0.6 - k * 0.15; bm.height = bm.radius * 2.0
		ball.mesh = bm; ball.material_override = sm; add_child(ball)
		ball.global_position = man + Vector3(0, 0.5 + k * 0.85 - k * k * 0.05, 0)
	var carrot := MeshInstance3D.new(); var ccm := CylinderMesh.new(); ccm.top_radius = 0.0; ccm.bottom_radius = 0.06; ccm.height = 0.35
	var om := StandardMaterial3D.new(); om.albedo_color = Color(1.0, 0.5, 0.1)
	carrot.mesh = ccm; carrot.material_override = om; add_child(carrot)
	carrot.global_position = man + Vector3(0, 2.05, -0.4); carrot.rotation.x = -PI * 0.5
	var sign := Label3D.new(); sign.text = "THE SNOW CLOUD\nReal snowflakes have SIX sides"; sign.font_size = 48; sign.pixel_size = 0.0045
	sign.outline_size = 12; sign.modulate = Color(0.85, 0.95, 1.0); sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign); sign.global_position = c + Vector3(-9, 3.0, 4)
	var mk := Marker3D.new(); mk.add_to_group("snow_field"); mk.set_meta("item", "snowflake"); add_child(mk); mk.global_position = c

## A snowflake you can catch: six arms (real), or four or five (one of Mr. Bubbles' fakes).
func _make_flake(real: bool) -> Node3D:
	var f := Node3D.new()
	var arms := 6 if real else (4 if randf() < 0.5 else 5)
	var mat := FX.glow_material(Color(0.85, 0.95, 1.0) if real else Color(0.9, 0.85, 1.0), 2.2 if real else 1.2)
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.07, 0.62, 0.03)
	var small := BoxMesh.new(); small.size = Vector3(0.05, 0.22, 0.02)
	for i in arms:
		var arm := Node3D.new(); arm.rotation.z = i * TAU / arms; f.add_child(arm)
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position.y = 0.3; arm.add_child(mi)
		for sd in [-1.0, 1.0]:
			var br := MeshInstance3D.new(); br.mesh = small; br.material_override = mat
			br.position = Vector3(sd * 0.08, 0.38, 0); br.rotation.z = -sd * 0.8; arm.add_child(br)
	var l := OmniLight3D.new(); l.light_color = Color(0.8, 0.9, 1.0); l.light_energy = 0.6; l.omni_range = 2.5; f.add_child(l)
	return f

func _snow_step(delta: float) -> void:
	var on := _quest_on("six_sides")
	if not on:
		for fl in _flakes:
			(fl[0] as Node3D).queue_free()
		_flakes.clear()
		return
	var c: Vector3 = CloudWorld.ISLANDS.F.c
	var pp := w.player.global_position
	if pp.distance_to(c) > 40.0:
		return
	_flake_t -= delta
	if _flake_t <= 0.0 and _flakes.size() < 7:
		_flake_t = 0.9
		var real := randf() < 0.65
		var f := _make_flake(real)
		add_child(f)
		var a := randf() * TAU; var d := randf_range(0.0, 11.0)
		f.global_position = c + Vector3(cos(a) * d, randf_range(4.0, 6.5), sin(a) * d)
		_flakes.append([f, real, randf() * TAU])
	var keep: Array = []
	for fl in _flakes:
		var f: Node3D = fl[0]
		fl[2] += delta
		# drifting down slowly (1 to 4 mph), swaying
		f.global_position += Vector3(sin(fl[2] * 1.3) * 0.5, -0.45, cos(fl[2]) * 0.3) * delta
		f.rotation.y += delta * 0.8
		f.rotation.x = sin(fl[2]) * 0.4
		var chest := pp + Vector3(0, 1.1, 0)
		if f.global_position.distance_to(chest) < 1.35:
			if fl[1]:
				Game.on_quest_item("snowflake")
				Sfx.play("pickup", -6.0, 0.2)
				FX.burst(f.global_position, Color(0.85, 0.95, 1.0), 24, 3.0, 0.1, 0.5, 0.0)
			else:
				Sfx.play("pop", -6.0, 0.2)
				FX.burst(f.global_position, Color(0.9, 0.8, 1.0), 18, 2.0, 0.1, 0.4, 0.0)
				Game.say("Only %d arms! That's one of Mr. Bubbles' fakes. Real snowflakes always have SIX sides." % (f.get_child_count() - 1), Color(0.9, 0.85, 1.0))
			f.queue_free()
			continue
		if f.global_position.y < c.y + 0.2:
			f.queue_free()          # it lands and joins the snow
			continue
		keep.append(fl)
	_flakes = keep

# ---------------------------------------------------------------------------
# The Ice Cloud (G): glazed in clear ice by freezing rain
func _ice_island() -> void:
	var c: Vector3 = CloudWorld.ISLANDS.G.c
	var r: float = CloudWorld.ISLANDS.G.r
	# the glaze: a shiny sheet of clear ice over the whole top
	var glaze := MeshInstance3D.new(); var gm := CylinderMesh.new(); gm.top_radius = r - 1.0; gm.bottom_radius = r - 1.0; gm.height = 0.04
	gm.radial_segments = 48
	glaze.mesh = gm
	var im := StandardMaterial3D.new(); im.albedo_color = Color(0.75, 0.88, 1.0, 0.55); im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.roughness = 0.05; im.metallic = 0.3; im.metallic_specular = 1.0
	glaze.material_override = im; glaze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glaze); glaze.global_position = c + Vector3(0, 0.07, 0)
	# freezing rain falling on it
	var rain := CPUParticles3D.new(); rain.amount = 180; rain.lifetime = 1.2
	rain.mesh = FX.quad(0.05); rain.material_override = FX.glow_material(Color(0.75, 0.88, 1.0), 0.7)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(r, 0.3, r)
	rain.direction = Vector3.DOWN; rain.spread = 3; rain.initial_velocity_min = 9.0; rain.initial_velocity_max = 11.0
	rain.gravity = Vector3(0, -4, 0); rain.scale_amount_min = 1.0; rain.scale_amount_max = 3.0
	add_child(rain); rain.global_position = c + Vector3(0, 13, 0)
	for k in 12:
		var a := k * TAU / 12.0
		w._puff(c + Vector3(cos(a) * 8.0, 14.0 + randf_range(-1, 1), sin(a) * 8.0), Vector3.ONE * randf_range(3.0, 4.2), Color(0.66, 0.7, 0.8))
	# frozen trees: branches coated in clear ice
	var bark := StandardMaterial3D.new(); bark.albedo_color = Color(0.35, 0.28, 0.22)
	var icy := StandardMaterial3D.new(); icy.albedo_color = Color(0.85, 0.93, 1.0, 0.5); icy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	icy.roughness = 0.05; icy.metallic_specular = 1.0
	for p in [Vector3(-8, 0, -5), Vector3(9, 0, 4), Vector3(-3, 0, 10)]:
		var trunk := MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.12; tc.bottom_radius = 0.2; tc.height = 2.6
		trunk.mesh = tc; trunk.material_override = bark; add_child(trunk); trunk.global_position = c + p + Vector3(0, 1.3, 0)
		var coat := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.17; cc.bottom_radius = 0.26; cc.height = 2.7
		coat.mesh = cc; coat.material_override = icy; add_child(coat); coat.global_position = trunk.global_position
		for k in 5:
			var br := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.03; bc.bottom_radius = 0.07; bc.height = 1.2
			br.mesh = bc; br.material_override = bark; add_child(br)
			var a := k * TAU / 5.0
			br.global_position = c + p + Vector3(cos(a) * 0.45, 2.0 + k * 0.15, sin(a) * 0.45)
			br.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)
			var bcoat := MeshInstance3D.new(); var bcc := CylinderMesh.new(); bcc.top_radius = 0.07; bcc.bottom_radius = 0.11; bcc.height = 1.25
			bcoat.mesh = bcc; bcoat.material_override = icy; br.add_child(bcoat)
			for j in 3:
				var icicle := MeshInstance3D.new(); var icm := CylinderMesh.new(); icm.top_radius = 0.04; icm.bottom_radius = 0.0; icm.height = 0.3
				icicle.mesh = icm; icicle.material_override = icy; br.add_child(icicle); icicle.position = Vector3(0, -0.3 + j * 0.3, 0.08)
	# four sun lamps, put out by the freezing rain
	var lamp_spots := [Vector3(-10, 0, 3), Vector3(10, 0, -4), Vector3(2, 0, -11), Vector3(4, 0, 12)]
	for i in lamp_spots.size():
		var lamp := Node3D.new(); add_child(lamp); lamp.global_position = c + lamp_spots[i]
		lamp.add_to_group("sun_lamp")
		lamp.set_meta("item", "sunlamp")
		lamp.set_meta("uid", "cl_sunlamp_%d" % i)
		var pole := MeshInstance3D.new(); var pcm := CylinderMesh.new(); pcm.top_radius = 0.07; pcm.bottom_radius = 0.1; pcm.height = 1.6
		var gold := StandardMaterial3D.new(); gold.albedo_color = Color(0.9, 0.75, 0.35); gold.metallic = 0.8; gold.roughness = 0.3
		pole.mesh = pcm; pole.material_override = gold; pole.position.y = 0.8; lamp.add_child(pole)
		var globe := MeshInstance3D.new(); var gsm := SphereMesh.new(); gsm.radius = 0.35; gsm.height = 0.7
		globe.mesh = gsm; globe.position.y = 1.85; globe.name = "Globe"; lamp.add_child(globe)
		var ice_shell := MeshInstance3D.new(); var ism := SphereMesh.new(); ism.radius = 0.45; ism.height = 0.95
		ice_shell.mesh = ism; ice_shell.material_override = icy; ice_shell.position.y = 1.85; ice_shell.name = "Ice"; lamp.add_child(ice_shell)
		var ll := OmniLight3D.new(); ll.name = "Light"; ll.light_color = Color(1.0, 0.85, 0.5); ll.omni_range = 8.0; ll.position.y = 1.9
		lamp.add_child(ll)
		_lamps.append(lamp)
		_lamp_look(lamp, Game.flags.get("cl_sunlamp_%d" % i, false))
	var sign := Label3D.new(); sign.text = "THE ICE CLOUD\nFreezing rain: SLIPPERY!"; sign.font_size = 48; sign.pixel_size = 0.0045
	sign.outline_size = 12; sign.modulate = Color(0.8, 0.92, 1.0); sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign); sign.global_position = c + Vector3(9, 3.0, 4)

func _lamp_look(lamp: Node3D, lit: bool) -> void:
	lamp.set_meta("lit", lit)
	var g := lamp.get_node("Globe") as MeshInstance3D
	g.material_override = FX.glow_material(Color(1.0, 0.85, 0.45), 2.5) if lit else _dark_globe()
	(lamp.get_node("Ice") as Node3D).visible = not lit
	(lamp.get_node("Light") as OmniLight3D).light_energy = 2.4 if lit else 0.0

var _dark_mat: StandardMaterial3D
func _dark_globe() -> StandardMaterial3D:
	if _dark_mat == null:
		_dark_mat = StandardMaterial3D.new(); _dark_mat.albedo_color = Color(0.45, 0.42, 0.38); _dark_mat.roughness = 0.4
	return _dark_mat

func _ice_step() -> void:
	if not _quest_on("the_glaze"):
		return
	var pp := w.player.global_position
	for lamp in _lamps:
		if lamp.get_meta("lit", false):
			continue
		if Vector2(pp.x - lamp.global_position.x, pp.z - lamp.global_position.z).length() < 1.4 and absf(pp.y - lamp.global_position.y) < 2.0:
			Game.flags[String(lamp.get_meta("uid"))] = true
			_lamp_look(lamp, true)
			Game.on_quest_item("sunlamp")
			Sfx.play("fire_burst", -6.0, 0.1)
			FX.burst(lamp.global_position + Vector3(0, 1.9, 0), Color(1.0, 0.85, 0.45), 40, 4.0, 0.15, 0.6, 0.0)
			Game.say("CRACK! The ice shell breaks and the sun lamp glows again.", Color(1.0, 0.9, 0.6))

# ---------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new(); _hud.layer = 5; add_child(_hud)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 26)
	_hud_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud_label.add_theme_constant_override("outline_size", 8)
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hud_label.position.y = 150
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_hud_label)

func _physics_process(delta: float) -> void:
	if w == null or w.player == null or w.player.dead:
		return
	_hail_step(delta)
	_snow_step(delta)
	_ice_step()
	var txt := ""
	if _hail_t > 0.0 and _quest_on("hail_rings") and not Game.flags.get("cl_hailstone", false):
		txt = "HAILSTONE RINGS:  %d / 3     (%s the freezing line)" % [hail_rings, "above" if _hail_above else "below"]
	_hud_label.text = txt
	if txt != "":
		_hud_label.position.x = (_hud_label.get_viewport_rect().size.x - _hud_label.size.x) * 0.5
