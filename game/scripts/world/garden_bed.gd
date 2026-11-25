extends Node3D
class_name GardenBed
## One raised bed in your garden (HomeGarden). USE: plant a seed (empty), water it
## (growing), or pick it (ripe: it sparkles). The plant grows in stages: a seed
## mound, a sprout, a young plant, then fully grown (GardenPlants; Game.plot_progress).

var index := 0
var garden: HomeGarden
var interact_reach := 2.9          # (Player._update_interact: a bed is big)
var stage := -1                    # 0 empty, 1 seed, 2 sprout, 3 growing, 4 ripe
var plant := ""
var _vis: Node3D
var _soil: StandardMaterial3D
var _sparkle: CPUParticles3D
var _wet := false
var _t := 0.0

static func make(g: HomeGarden, i: int, at: Vector3) -> GardenBed:
	var b := GardenBed.new()
	b.index = i
	b.garden = g
	b.name = "Bed%d" % i
	g.add_child(b)
	b.position = at
	b._build()
	return b

func _build() -> void:
	add_to_group("interactable")
	var h := HomeGarden.BED_HALF
	var wood := garden._mat(Color(0.5, 0.33, 0.18), 0.85)
	for s in [[Vector3(-h, 0, -h), Vector3(h, 0.34, -h + 0.1)], [Vector3(-h, 0, h - 0.1), Vector3(h, 0.34, h)],
			[Vector3(-h, 0, -h), Vector3(-h + 0.1, 0.34, h)], [Vector3(h - 0.1, 0, -h), Vector3(h, 0.34, h)]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s[1] - s[0]; mi.mesh = bm
		mi.material_override = wood; mi.position = (s[0] + s[1]) * 0.5; add_child(mi)
	_soil = garden._mat(Color(0.36, 0.25, 0.15), 1.0)
	var soil := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(h * 2.0 - 0.2, 0.3, h * 2.0 - 0.2); soil.mesh = sm
	soil.material_override = _soil; soil.position.y = 0.15; add_child(soil)
	for k in 3:
		var fur := MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(h * 2.0 - 0.3, 0.05, 0.12); fur.mesh = fm
		fur.material_override = _soil; fur.position = Vector3(0, 0.31, (k - 1) * 0.45); add_child(fur)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(h * 2.0, 0.5, h * 2.0)
	cs.shape = bs; cs.position.y = 0.25; sb.add_child(cs); add_child(sb)
	_vis = Node3D.new(); _vis.position.y = 0.3; add_child(_vis)
	_sparkle = CPUParticles3D.new(); _sparkle.amount = 10; _sparkle.lifetime = 1.4
	_sparkle.mesh = FX.quad(0.08); _sparkle.material_override = FX.glow_material(Color(1.0, 0.95, 0.5), 2.5)
	_sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _sparkle.emission_box_extents = Vector3(h * 0.8, 0.3, h * 0.8)
	_sparkle.direction = Vector3.UP; _sparkle.spread = 20; _sparkle.initial_velocity_min = 0.3; _sparkle.initial_velocity_max = 0.7
	_sparkle.gravity = Vector3.ZERO; _sparkle.color_ramp = FX._fade_ramp(Color(1.0, 0.95, 0.5))
	_sparkle.position.y = 0.9; _sparkle.emitting = false; add_child(_sparkle)
	tick(true)

## Catch up with the plant (main garden _process; cheap).
func tick(force := false) -> void:
	_t -= get_process_delta_time()
	if _t > 0.0 and not force:
		return
	_t = 0.5
	var p := Game.plot_progress(index)
	var id := String(Game.garden_plots[index].plant)
	var st := 0
	if id != "":
		st = 1 if p < 0.15 else (2 if p < 0.45 else (3 if p < 1.0 else 4))
	var wet := Game.plot_wet(index)
	if wet != _wet or force:
		_wet = wet
		_soil.albedo_color = Color(0.2, 0.13, 0.08) if wet else Color(0.36, 0.25, 0.15)
		_soil.roughness = 0.45 if wet else 1.0
	if st != stage or id != plant:
		stage = st
		plant = id
		for c in _vis.get_children():
			c.queue_free()
		if id != "":
			_plant_look(id, st)
		_sparkle.emitting = st == 4

func get_prompt() -> String:
	if plant == "":
		return "[E] Plant a seed" if Game.seed_count() > 0 else "[E] Plant a seed (no seeds yet: open the seed box by the gate)"
	var nm := GardenPlants.plant_name(plant)
	if stage == 4:
		return "[E] Pick the %s!" % nm
	var pct := int(Game.plot_progress(index) * 100.0)
	return "[E] Water the %s  (%d%% grown%s)" % [nm, pct, ", watered" if Game.plot_wet(index) else ""]

func interact(_by: Node) -> void:
	if plant == "":
		if Game.seed_count() <= 0:
			Game.say("No seeds yet! Open the seed box by the garden gate, or find seeds in chests on your adventures.", Color(0.8, 1.0, 0.7))
			return
		var sc := get_tree().current_scene
		if sc.has_method("open_garden"):
			sc.open_garden(index)
		return
	if stage == 4:
		var got := Game.harvest_plot(index)
		if got.is_empty():
			return
		var pl: Dictionary = GardenPlants.PLANTS[got.id]
		Sfx.play_at("leaves_rustle", global_position, -2.0)
		Sfx.play("pickup", -6.0, 0.1)
		FX.burst(global_position + Vector3(0, 0.8, 0), pl.color, 34, 3.0, 0.14, 0.9, 0.5)
		match String(pl.get("gives", "")):
			"mana": Game.say("+%d Mana Potions from your %s!" % [got.n, pl.name], Color(0.5, 0.7, 1.0))
			"potion": Game.say("+%d Healing Draughts from your %s!" % [got.n, pl.name], Color(1.0, 0.5, 0.55))
			"stamina": Game.say("+%d Energy Potions from your %s!" % [got.n, pl.name], Color(0.8, 1.0, 0.4))
			_: Game.say("%d %s for your basket! %s" % [got.n, String(pl.name).to_lower(), _basket_hint(String(pl.kind))], pl.color)
		tick(true)
		return
	Game.water_plot(index)
	Sfx.play_at("pour", global_position, -2.0)
	FX.burst(global_position + Vector3(0, 0.9, 0), Color(0.5, 0.75, 1.0), 26, 2.2, 0.1, 0.7, -1.0)
	Game.say("Watered! The %s will grow twice as fast for a while." % GardenPlants.plant_name(plant).to_lower(), Color(0.6, 0.85, 1.0))
	tick(true)

func _basket_hint(kind: String) -> String:
	return "(Eat them at your cabin table, or sell them to Tobble.)" if kind == "veg" else "(Tobble pays well for flowers.)"

# --- how each plant looks as it grows --------------------------------------------------
func _m(c: Color, r := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = r
	return m

func _glow(c: Color, e := 1.6) -> StandardMaterial3D:
	var m := _m(c, 0.4); m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	return m

func _sph(pos: Vector3, scl: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 10; sm.rings = 5
	mi.mesh = sm; mi.material_override = m; mi.position = pos; mi.scale = scl; _vis.add_child(mi)
	return mi

func _cyl(pos: Vector3, r_top: float, r_bot: float, h: float, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r_top; cm.bottom_radius = r_bot; cm.height = h
	cm.radial_segments = 8; mi.mesh = cm; mi.material_override = m; mi.position = pos; mi.rotation = rot; _vis.add_child(mi)
	return mi

func _plant_look(id: String, st: int) -> void:
	var leaf := _m(Color(0.3, 0.62, 0.24), 0.8)
	if st == 1:
		# a little mound of fresh earth with a marker stick and the seed packet's colour
		_sph(Vector3(0, 0.0, 0), Vector3(0.4, 0.08, 0.4), _m(Color(0.3, 0.2, 0.12), 1.0))
		_cyl(Vector3(0.45, 0.2, 0.45), 0.02, 0.02, 0.45, _m(Color(0.6, 0.45, 0.25)))
		_sph(Vector3(0.45, 0.42, 0.45), Vector3(0.09, 0.07, 0.02), _m(GardenPlants.PLANTS[id].color, 0.6))
		return
	if st == 2:
		for k in 3:
			var x := (k - 1) * 0.45
			_cyl(Vector3(x, 0.07, 0), 0.012, 0.015, 0.14, leaf)
			_sph(Vector3(x - 0.05, 0.15, 0), Vector3(0.07, 0.02, 0.04), leaf).rotation.z = 0.4
			_sph(Vector3(x + 0.05, 0.15, 0), Vector3(0.07, 0.02, 0.04), leaf).rotation.z = -0.4
		return
	var s := 0.7 if st == 3 else 1.0
	var ripe := st == 4
	var col: Color = GardenPlants.PLANTS[id].color
	match id:
		"carrot":
			for r in [-0.32, 0.32]:
				for k in 3:
					var p := Vector3((k - 1) * 0.42, 0, r)
					for f in 3:
						_cyl(p + Vector3((f - 1) * 0.04, 0.16 * s, 0), 0.005, 0.03, 0.34 * s, leaf, Vector3(0, 0, (f - 1) * 0.35))
					if ripe:
						_cyl(p + Vector3(0, 0.03, 0), 0.075, 0.03, 0.14, _m(col, 0.6))
		"tomato":
			for x in [-0.38, 0.38]:
				_cyl(Vector3(x, 0.5 * s, -0.05), 0.02, 0.02, 1.0 * s, _m(Color(0.6, 0.45, 0.25)))
				for k in 3:
					_sph(Vector3(x + (k - 1) * 0.07, (0.3 + k * 0.22) * s, 0.02), Vector3.ONE * 0.2 * s, leaf)
				for k in 5:
					var a := k * TAU / 5.0
					var tp := Vector3(x + cos(a) * 0.19 * s, (0.3 + (k % 3) * 0.22) * s, sin(a) * 0.19 * s + 0.04)
					_sph(tp, Vector3.ONE * (0.075 if ripe else 0.045), _m(col if ripe else Color(0.45, 0.7, 0.25), 0.35))
		"pumpkin":
			for k in 5:
				var a := k * TAU / 5.0 + 0.3
				_sph(Vector3(cos(a) * 0.45, 0.05, sin(a) * 0.45), Vector3(0.24, 0.05, 0.2) * s, leaf).rotation.y = a
			var pr := (0.38 if ripe else 0.2) * s
			var pk := _sph(Vector3(0, pr * 0.8, 0), Vector3(pr * 1.2, pr * 0.85, pr * 1.2), _m(col if ripe else Color(0.45, 0.65, 0.25), 0.55))
			for k in 6:
				var a2 := k * TAU / 6.0
				_sph(Vector3(cos(a2) * pr * 0.95, pr * 0.8, sin(a2) * pr * 0.95), Vector3(pr * 0.35, pr * 0.82, pr * 0.35), pk.material_override)
			_cyl(Vector3(0, pr * 1.55, 0), 0.03, 0.04, 0.15, _m(Color(0.35, 0.4, 0.15)))
		"sunflower":
			for x in [-0.35, 0.35]:
				var h := 1.7 * s
				_cyl(Vector3(x, h * 0.5, 0), 0.03, 0.04, h, leaf)
				for k in 2:
					_sph(Vector3(x + (0.12 if k == 0 else -0.12), h * (0.35 + k * 0.2), 0), Vector3(0.14, 0.03, 0.08), leaf).rotation.z = 0.5 if k == 0 else -0.5
				var head := Vector3(x, h + 0.05, 0.05)
				if ripe:
					_cyl(head, 0.15, 0.15, 0.06, _m(Color(0.35, 0.2, 0.08), 0.9), Vector3(PI * 0.5, 0, 0))
					for k in 12:
						var a := k * TAU / 12.0
						var pe := _sph(head + Vector3(cos(a) * 0.22, sin(a) * 0.22, -0.01), Vector3(0.09, 0.04, 0.015), _m(col, 0.6))
						pe.rotation.z = a
				else:
					_sph(head, Vector3.ONE * 0.09, leaf)
		"rose":
			for x in [-0.38, 0.38]:
				for k in 3:
					_sph(Vector3(x + (k - 1) * 0.12, 0.25 * s + (k % 2) * 0.08, 0), Vector3.ONE * 0.22 * s, _m(Color(0.22, 0.48, 0.2), 0.8))
				for k in 5:
					var a := k * TAU / 5.0
					_sph(Vector3(x + cos(a) * 0.2 * s, 0.35 * s + (k % 2) * 0.1, sin(a) * 0.18 * s + 0.05), Vector3.ONE * (0.07 if ripe else 0.035),
						_m(col if ripe else Color(0.35, 0.6, 0.3), 0.5))
		"moonpetal":
			for k in 3:
				var p := Vector3((k - 1) * 0.45, 0, (k % 2) * 0.2 - 0.1)
				var h := 0.55 * s
				_cyl(p + Vector3(0, h * 0.5, 0), 0.015, 0.02, h, leaf)
				for f in 5:
					var a := f * TAU / 5.0
					_sph(p + Vector3(cos(a) * 0.09 * s, h + 0.02, sin(a) * 0.09 * s), Vector3(0.08, 0.02, 0.05) * s,
						_glow(col, 1.8 if ripe else 0.6)).rotation.y = -a
				_sph(p + Vector3(0, h + 0.04, 0), Vector3.ONE * 0.04, _glow(Color(1, 1, 1), 2.5 if ripe else 0.8))
		"heartberry":
			for k in 3:
				_sph(Vector3((k - 1) * 0.3, 0.3 * s, 0), Vector3.ONE * 0.28 * s, _m(Color(0.15, 0.42, 0.2), 0.8))
			for k in 8:
				var a := k * TAU / 8.0
				_sph(Vector3(cos(a) * 0.45 * s, (0.25 + (k % 3) * 0.12) * s, sin(a) * 0.28 * s), Vector3.ONE * (0.07 if ripe else 0.04),
					_glow(col, 1.4) if ripe else _m(Color(0.5, 0.7, 0.3)))
		"fireblossom":
			var h := 0.6 * s
			_cyl(Vector3(0, h * 0.5, 0), 0.025, 0.035, h, _m(Color(0.35, 0.2, 0.1)))
			for k in 7:
				var a := k * TAU / 7.0
				_cyl(Vector3(cos(a) * 0.1 * s, h + 0.12 * s, sin(a) * 0.1 * s), 0.0, 0.07 * s, 0.32 * s,
					_glow(col if k % 2 == 0 else Color(1.0, 0.8, 0.2), 2.2 if ripe else 0.7), Vector3(sin(a) * 0.45, 0, -cos(a) * 0.45))
			if ripe:
				var em := CPUParticles3D.new(); em.amount = 14; em.lifetime = 1.0
				em.mesh = FX.quad(0.05); em.material_override = FX.glow_material(Color(1.0, 0.55, 0.15), 2.5)
				em.direction = Vector3.UP; em.spread = 20; em.initial_velocity_min = 0.4; em.initial_velocity_max = 0.9
				em.gravity = Vector3(0, 0.3, 0); em.color_ramp = FX._fade_ramp(Color(1.0, 0.55, 0.15))
				em.position = Vector3(0, h + 0.25, 0); _vis.add_child(em)
		"glowcap":
			for k in 5:
				var a := k * TAU / 5.0
				var p := Vector3(cos(a) * 0.38, 0, sin(a) * 0.3)
				var h := (0.22 + (k % 3) * 0.08) * s
				_cyl(p + Vector3(0, h * 0.5, 0), 0.03, 0.04, h, _m(Color(0.9, 0.9, 0.8), 0.6))
				var cap := _sph(p + Vector3(0, h, 0), Vector3(0.13, 0.08, 0.13) * s, _glow(col, 1.8 if ripe else 0.5))
				cap.scale.y = 0.07 * s
