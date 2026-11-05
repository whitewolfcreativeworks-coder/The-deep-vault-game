extends Node
class_name DayNight
## Day and night in the Goblin Forest.
## The clock runs in 7-minute blocks. A day block begins with sunrise and a
## night block begins with sunset; each change takes TRANSITION seconds, so you
## get about 5.5 minutes of full day, a sunset, about 5.5 minutes of night, a
## sunrise, and so on (a full cycle is 14 minutes). The clock lives in
## Game.day_clock so it carries on across saves.
## Underground (the Warren, the Sinkhole) the world script turns this off.

const BLOCK := 420.0          # 7 minutes
const TRANSITION := 90.0      # sunrise / sunset take a minute and a half

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky: ProceduralSkyMaterial
var active := true
var light := 1.0              # 1 = full day, 0 = full night (read by others)
var _stars: CPUParticles3D

const DAY := {"top": Color(0.28, 0.5, 0.82), "hor": Color(0.78, 0.82, 0.78), "fog": Color(0.62, 0.72, 0.68), "gh": Color(0.5, 0.55, 0.45)}
const DUSK := {"top": Color(0.32, 0.3, 0.55), "hor": Color(1.0, 0.52, 0.28), "fog": Color(0.75, 0.48, 0.35), "gh": Color(0.45, 0.32, 0.25)}
const NIGHT := {"top": Color(0.02, 0.03, 0.09), "hor": Color(0.07, 0.1, 0.2), "fog": Color(0.06, 0.08, 0.14), "gh": Color(0.03, 0.04, 0.05)}

func setup(e: Environment, s: DirectionalLight3D, sky_mat: ProceduralSkyMaterial, parent: Node3D) -> void:
	env = e; sun = s; sky = sky_mat
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.rotation_degrees = Vector3(-42, 150, 0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	parent.add_child(moon)
	# stars: tiny glowing points on a huge dome that follows the player
	_stars = CPUParticles3D.new()
	_stars.amount = 500; _stars.lifetime = 1000.0; _stars.preprocess = 1.0
	_stars.explosiveness = 1.0; _stars.one_shot = false
	_stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_stars.emission_sphere_radius = 380.0
	_stars.gravity = Vector3.ZERO; _stars.initial_velocity_min = 0.0; _stars.initial_velocity_max = 0.0
	_stars.mesh = FX.quad(1.6)
	_stars.scale_amount_min = 0.4; _stars.scale_amount_max = 1.4
	_stars.local_coords = true
	var sm := FX.glow_material(Color(0.85, 0.9, 1.0), 1.6)
	sm.no_depth_test = false
	_stars.material_override = sm
	_stars.visible = false
	parent.add_child(_stars)
	_apply(true)

## 0..1 through the full 14-minute cycle (for tests and the HUD).
static func phase_name(clock: float) -> String:
	var block := int(floor(clock / BLOCK)) % 2
	var u := fmod(clock, BLOCK)
	if block == 0:
		return "sunrise" if u < TRANSITION else "day"
	return "sunset" if u < TRANSITION else "night"

## How much daylight there is at `clock` seconds (1 day, 0 night).
static func daylight(clock: float) -> float:
	var block := int(floor(clock / BLOCK)) % 2
	var p := smoothstep(0.0, 1.0, clampf(fmod(clock, BLOCK) / TRANSITION, 0.0, 1.0))
	return p if block == 0 else 1.0 - p

func _process(delta: float) -> void:
	Game.day_clock += delta
	_apply(false)

func _apply(_force: bool) -> void:
	if env == null:
		return
	light = daylight(Game.day_clock)
	var dusk := clampf(4.0 * light * (1.0 - light), 0.0, 1.0)     # 1 in the middle of a sunrise/sunset
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if _stars and player:
		_stars.global_position = player.global_position
	if not active:
		moon.visible = false
		if _stars:
			_stars.visible = false
		return
	# the sun climbs in the east during sunrise and sets in the west at sunset
	var block := int(floor(Game.day_clock / BLOCK)) % 2
	var elev := lerpf(-6.0, 42.0, light)
	var az := -30.0 if block == 0 else 30.0
	sun.visible = light > 0.01
	sun.rotation_degrees = Vector3(-elev, az + (1.0 - light) * (60.0 if block == 0 else -60.0), 0)
	sun.light_energy = 1.25 * smoothstep(0.0, 0.6, light)
	sun.light_color = Color(1.0, 0.92, 0.78).lerp(Color(1.0, 0.55, 0.3), dusk * 0.8)
	moon.visible = light < 0.99
	moon.light_energy = 0.38 * (1.0 - light)
	var base: Dictionary = DAY if light > 0.5 else NIGHT
	var to := DUSK
	var k := dusk
	sky.sky_top_color = (base.top as Color).lerp(to.top, k)
	sky.sky_horizon_color = (base.hor as Color).lerp(to.hor, k)
	sky.ground_horizon_color = (base.gh as Color).lerp(to.gh, k)
	sky.sky_energy_multiplier = lerpf(0.35, 1.0, light)
	env.ambient_light_energy = lerpf(0.32, 0.9, light)
	env.ambient_light_sky_contribution = 1.0
	env.fog_light_color = (base.fog as Color).lerp(to.fog, k)
	env.volumetric_fog_albedo = Color(0.95, 0.95, 0.85).lerp(Color(0.35, 0.4, 0.6), 1.0 - light)
	env.tonemap_exposure = lerpf(1.25, 1.0, light)
	if _stars:
		_stars.visible = light < 0.6
		(_stars.material_override as StandardMaterial3D).albedo_color.a = clampf((0.6 - light) / 0.4, 0.0, 1.0)
