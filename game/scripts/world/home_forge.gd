extends HomeBuilding
class_name HomeForge
## THE FORGE: an open stone smithy beside the yard, its furnace glowing day and
## night. Ironbeard the smith (Jason's son gets to give them a real name) works
## the anvil:
##   the anvil         put three pieces of gear on it and forge them into one
##                     piece you can't find anywhere else (see ForgeRecipes)
##   Ironbeard         talk for a riddle about the forge's secret recipes
##   the journal       the Forge Journal: every recipe you've discovered, and
##                     "???" for the ones still waiting to be found
## You walk straight in (no door): it's open at the front.

const AT := Vector3(-23, 0, 10.5)     # the smithy, open side facing the yard (+x) (further out from Nov 25)
const YAW := 90.0
const HW := 3.6                       # half width (local x) and half depth (local z)
const HD := 3.0

var shop: Node3D                      # everything, turned to face the yard
var smith: ShopNPC
var anvil_top := Vector3.ZERO         # (world) where the gear sparks fly
var _fire_light: OmniLight3D
var _t := 0.0
var _floor_y := 0.0

static func build_in(h: HomeWorld) -> HomeForge:
	var f := HomeForge.new()
	f.name = "Forge"
	f.home = h
	h.add_child(f)
	f._build()
	return f

## Local (smithy) to world.
func w(p: Vector3) -> Vector3:
	return shop.global_transform * p

func _build() -> void:
	var g := home.ground(AT.x, AT.z)
	_floor_y = g.y + 0.18
	# the floor sits just above the highest corner of the ground
	for dx in [-HW, HW]:
		for dz in [-HD, HD]:
			var c := AT + Basis(Vector3.UP, deg_to_rad(YAW)) * Vector3(dx, 0, dz)
			_floor_y = maxf(_floor_y, home.ground(c.x, c.z).y + 0.12)
	shop = Node3D.new(); shop.name = "Smithy"
	add_child(shop)
	shop.position = Vector3(AT.x, _floor_y, AT.z)
	shop.rotation.y = deg_to_rad(YAW)
	var stone := mat(Color(0.56, 0.54, 0.52), 0.92)
	var stone2 := mat(Color(0.46, 0.44, 0.43), 0.92)
	var timber := mat(Color(0.36, 0.22, 0.12), 0.8)
	var roof := mat(Color(0.62, 0.42, 0.32), 0.85)
	box(shop, Vector3(-HW, -1.6, -HD), Vector3(HW, 0, HD), stone2)                     # floor slab
	box(shop, Vector3(-HW + 0.4, -0.25, HD), Vector3(HW - 0.4, -0.05, HD + 0.6), stone2)   # a step
	for k in 6:                                                                        # flagstone lines
		var x := -HW + 1.0 + k * 1.15
		box(shop, Vector3(x - 0.02, 0, -HD), Vector3(x + 0.02, 0.006, HD), stone, false)
	box(shop, Vector3(-HW, 0, -HD - 0.4), Vector3(HW, 3.4, -HD), stone)                  # back wall
	box(shop, Vector3(-HW - 0.4, 0, -HD - 0.4), Vector3(-HW, 1.2, HD), stone)            # low side walls
	box(shop, Vector3(HW, 0, -HD - 0.4), Vector3(HW + 0.4, 1.2, HD), stone)
	for x in [-HW - 0.2, HW + 0.2]:                                                     # timber posts
		for z in [-HD - 0.2, 0.0, HD - 0.1]:
			box(shop, Vector3(x - 0.14, 0, z - 0.14), Vector3(x + 0.14, 3.6, z + 0.14), timber)
	for x in [-HW - 0.2, HW + 0.2]:
		box(shop, Vector3(x - 0.16, 3.2, -HD - 0.4), Vector3(x + 0.16, 3.45, HD + 0.2), timber, false)
	box(shop, Vector3(-HW - 0.3, 3.2, HD - 0.26), Vector3(HW + 0.3, 3.45, HD + 0.06), timber, false)   # front beam
	var r := box(shop, Vector3(-HW - 0.7, -0.12, -HD - 1.4), Vector3(HW + 0.7, 0.12, HD + 1.2), roof, false)   # the roof
	r.position = Vector3(0, 3.95, -0.1)
	r.rotation.x = -0.2
	# the chimney and the furnace (back left), always glowing
	box(shop, Vector3(-HW + 0.2, 0, -HD - 0.3), Vector3(-HW + 2.2, 1.3, -HD + 1.4), stone2)
	box(shop, Vector3(-HW + 0.5, 1.3, -HD - 0.3), Vector3(-HW + 1.9, 2.2, -HD + 1.1), stone2)
	box(shop, Vector3(-HW + 0.7, 2.2, -HD - 0.3), Vector3(-HW + 1.7, 6.2, -HD + 0.7), stone)
	box(shop, Vector3(-HW + 0.6, 1.3, -HD + 1.1), Vector3(-HW + 1.8, 2.05, -HD + 1.15), mat(Color(0.05, 0.03, 0.02)), false)   # the mouth
	var coals := box(shop, Vector3(-HW + 0.65, 1.3, -HD + 0.2), Vector3(-HW + 1.75, 1.42, -HD + 1.12), glow(Color(1.0, 0.38, 0.08), 3.5), false)
	coals.name = "Coals"
	var fire_at := Node3D.new(); shop.add_child(fire_at); fire_at.position = Vector3(-HW + 1.2, 1.45, -HD + 0.75)
	Props.fire_particles(fire_at, 1.1, Color(1.0, 0.55, 0.2), true, false)      # (home is safe: it never burns you)
	_fire_light = OmniLight3D.new(); _fire_light.light_color = Color(1.0, 0.55, 0.25); _fire_light.light_energy = 2.4
	_fire_light.omni_range = 8.0
	shop.add_child(_fire_light); _fire_light.position = Vector3(-HW + 1.2, 1.9, -HD + 1.6)
	var smoke := CPUParticles3D.new(); smoke.amount = 14; smoke.lifetime = 4.0; smoke.preprocess = 4.0
	smoke.mesh = FX.quad(0.9)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.55, 0.55, 0.58, 0.35); sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = FX.soft_texture()
	smoke.material_override = sm
	smoke.direction = Vector3(0.2, 1, 0); smoke.spread = 10; smoke.initial_velocity_min = 0.6; smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.15, 0.1, 0); smoke.scale_amount_min = 0.8; smoke.scale_amount_max = 2.0
	shop.add_child(smoke); smoke.position = Vector3(-HW + 1.2, 6.4, -HD + 0.2)
	# the anvil in the middle
	var iron := mat(Color(0.2, 0.2, 0.22), 0.35, 0.8)
	var a := Vector3(0.4, 0, 0.3)
	box(shop, a + Vector3(-0.4, 0, -0.3), a + Vector3(0.4, 0.45, 0.3), timber)           # the stump
	box(shop, a + Vector3(-0.22, 0.45, -0.15), a + Vector3(0.22, 0.7, 0.15), iron)
	box(shop, a + Vector3(-0.45, 0.7, -0.2), a + Vector3(0.38, 0.88, 0.2), iron)
	var horn := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = 0.13; cm.height = 0.45; cm.radial_segments = 10
	horn.mesh = cm; horn.material_override = iron
	shop.add_child(horn); horn.position = a + Vector3(0.58, 0.8, 0); horn.rotation.z = -PI * 0.5
	anvil_top = w(a + Vector3(0, 0.9, 0))
	var ham := box(shop, a + Vector3(-0.05, 0.9, 0.05), a + Vector3(0.25, 0.98, 0.13), iron, false)
	ham.rotation.y = 0.4
	box(shop, a + Vector3(-0.32, 0.9, 0.08), a + Vector3(-0.04, 0.92, 0.1), timber, false)
	# the quench barrel, a weapon rack and a grindstone
	var bar := Props.place(shop, "barrel_small", Vector3(HW - 0.8, 0, -HD + 0.8), 0.0, 1.0)
	var ba := Props.mesh_aabb(bar)
	if ba.size.y > 0.0:
		bar.scale = Vector3.ONE * clampf(0.9 / ba.size.y, 0.3, 3.0)
	cylinder(shop, Vector3(HW - 0.8, 0.86, -HD + 0.8), 0.33, 0.33, 0.02, mat(Color(0.25, 0.4, 0.5), 0.05, 0.3))
	box(shop, Vector3(-0.4, 1.3, -HD - 0.05), Vector3(2.4, 1.42, -HD + 0.1), timber, false)
	for k in 3:
		var wpn := Props.place(shop, ["sword_shield", "sword_shield_broken", "sword_shield_gold"][k], Vector3(0.0 + k * 0.85, 0.2, -HD + 0.25), 0.0, 0.7)
		wpn.rotation_degrees = Vector3(0, 0, 0)
	cylinder(shop, Vector3(HW - 1.0, 0, HD - 1.2), 0.08, 0.08, 0.6, timber)
	var wheel := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = 0.38; wm.bottom_radius = 0.38; wm.height = 0.14
	wheel.mesh = wm; wheel.material_override = stone2
	shop.add_child(wheel); wheel.position = Vector3(HW - 1.0, 0.8, HD - 1.2); wheel.rotation.z = PI * 0.5
	# the Forge Journal on a stand
	var jl := Vector3(HW - 1.0, 0, 0.3)
	box(shop, jl + Vector3(-0.12, 0, -0.12), jl + Vector3(0.12, 0.95, 0.12), timber)
	var jt := box(shop, jl + Vector3(-0.32, 0.95, -0.25), jl + Vector3(0.32, 1.01, 0.25), timber, false)
	jt.rotation.x = 0.3
	var jb := box(shop, jl + Vector3(-0.26, 1.02, -0.19), jl + Vector3(0.26, 1.07, 0.19), mat(Color(0.5, 0.15, 0.1)), false)
	jb.rotation.x = 0.3
	# signs
	var sg := label_sign(shop, Vector3(0, 2.88, HD + 0.2), "THE FORGE", Color(1.0, 0.7, 0.35), 2.2, 0.45)
	sg.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_sign(shop, jl + Vector3(0, 1.55, 0), "FORGE JOURNAL", Color(1.0, 0.85, 0.5), 1.4, 0.22)
	label_sign(shop, a + Vector3(0, 1.55, 0), "ANVIL", Color(1.0, 0.75, 0.4), 0.9, 0.22)
	# the smith, by the furnace
	smith = ShopNPC.make(self, "smith", w(Vector3(-1.4, 0, -0.9)), YAW + 160.0,
		{"hero": "Barbarian", "face": "beard", "hair_color": Color(0.55, 0.3, 0.14), "hair_tint": Color(0.55, 0.3, 0.14),
		"outfit_color": Color(0.35, 0.25, 0.18), "build": 1.3, "height": 1.05, "hat": false},
		"[E] Talk to %s (a riddle about the forge)" % Game.NPC_NAMES.smith, talk)
	Usable.make(self, w(a + Vector3(0, 0.9, 0.9)), "[E] Use the anvil (forge three pieces of gear into one)", func() -> void: open())
	Usable.make(self, w(jl + Vector3(-0.7, 1.0, 0)), "[E] Read the Forge Journal", func() -> void: open(true))

func _process(delta: float) -> void:
	_t += delta
	if _fire_light:
		_fire_light.light_energy = 2.2 + sin(_t * 9.0) * 0.18 + sin(_t * 23.0) * 0.1

func open(journal := false) -> void:
	var sc := scene_main()
	if sc and sc.has_method("open_forge"):
		sc.open_forge(journal)

## Talking to the smith: a riddle, which goes into the Forge Journal.
func talk() -> void:
	var h := ForgeRecipes.next_hint()
	if smith and smith.body:
		smith.body.play_role("interact")
	Game.say("%s: \"%s\"" % [Game.NPC_NAMES.smith.split(" ")[0], h], Color(1.0, 0.75, 0.45))
	var sc := scene_main()
	if sc and sc.has_method("autosave"):
		sc.autosave()

## The hammer falls: sparks, clangs and (for something special) a golden flash.
func strike(grand: bool) -> void:
	if smith and smith.body:
		smith.body.oneshot("1H_Melee_Attack_Chop", 0.6)
	for k in 3:
		get_tree().create_timer(0.25 + k * 0.35, true, false, true).timeout.connect(func() -> void:
			Sfx.play("clang", -4.0 + k * 1.5, 0.15)
			FX.sparks(anvil_top, Color(1.0, 0.75, 0.35))
			FX.burst(anvil_top, Color(1.0, 0.6, 0.2), 18, 4.0, 0.06, 0.5, -6.0))
	get_tree().create_timer(1.4, true, false, true).timeout.connect(func() -> void:
		var c := Color(1.0, 0.85, 0.35) if grand else Color(1.0, 0.6, 0.3)
		FX.pillar(anvil_top - Vector3(0, 0.9, 0), c, 0.6 if grand else 0.35, 6.0 if grand else 3.0, 0.8)
		FX.burst(anvil_top, c, 60 if grand else 25, 5.0, 0.12, 0.9, 0.0)
		FX.flash_light(anvil_top, c, 8.0 if grand else 4.0, 8.0, 0.4)
		Sfx.play("levelup" if grand else "spell", -4.0, 0.0))
