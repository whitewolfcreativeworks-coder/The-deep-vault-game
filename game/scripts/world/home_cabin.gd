extends Node3D
class_name HomeCabin
## Bobek's cabin, back home after the flight: the very room from the opening movie
## (bed, wardrobe, wash stand, stove, breakfast table), now with things to do:
##   the writing desk  change your name and your looks (pick a name all your own:
##                     you'll want one when the open world portal opens)
##   the gear chest    keep gear you don't want to carry, and take it back any time
##   the bed           have a nap: full health, magic and stamina
## The front door leads in and out (the room itself is built out of sight, deep
## under the valley, like a film set).

const AT := Vector3(0, -30, 0)               # where the room is
const S := 1.0 / IntroMovie.INDOOR           # the movie set was sized for a smaller hero
const IN_DOOR := Vector3(-1.4, 0, 4.0)       # room-local: the door on the front wall
const DESK := Vector3(-1.0, 0, -3.6)         # room-local: the desk under the window
const CHEST := Vector3(-3.2, 0, 0.35)        # room-local: the gear chest at the foot of the bed

var home: HomeWorld
var room: IntroMovie
var _body: StaticBody3D

static func build_in(h: HomeWorld) -> HomeCabin:
	var c := HomeCabin.new()
	c.name = "Cabin"
	c.home = h
	h.add_child(c)
	c._build()
	return c

## Room-local (as in the movie set) to world.
func w(p: Vector3) -> Vector3:
	return AT + p * S

func is_inside(p: Vector3) -> bool:
	return absf(p.y - AT.y - 2.0) < 6.0 and absf(p.x - AT.x) < 9.0 and absf(p.z - AT.z) < 8.0

func _build() -> void:
	room = IntroMovie.new()
	room.name = "CabinRoom"
	add_child(room)
	room.set_process(false)
	room.scale = Vector3.ONE * S
	room.position = AT - IntroMovie.ROOM * S
	room._cabin_interior()
	# the set's lights were placed for an unscaled room
	for l in room.find_children("*", "Light3D", true, false):
		if l is OmniLight3D:
			(l as OmniLight3D).omni_range *= S
		elif l is SpotLight3D:
			(l as SpotLight3D).spot_range *= S
			(l as SpotLight3D).look_at(w(Vector3(-3.0, 0.3, -1.0)))
	_desk()
	_chest()
	_door_inside()
	_body = StaticBody3D.new(); _body.collision_layer = 1; add_child(_body)
	_collide_set()
	# the doors, the desk, the chest and the bed
	Usable.make(self, home.ground(IntroMovie.DOOR.x, 3.9) + Vector3(0, 1.0, 0), "[E] Go inside your cabin", go_in)
	Usable.make(self, w(IN_DOOR + Vector3(0.0, 0.8, -0.5)), "[E] Go out to the yard", go_out)
	Usable.make(self, w(DESK + Vector3(0, 0.8, 0.55)), "[E] Sit at your desk (change your name and looks)", _use_desk)
	Usable.make(self, w(CHEST + Vector3(0.55, 0.5, 0)), "[E] Open your gear chest", _use_chest)
	Usable.make(self, w(room._bed + Vector3(1.0, 0.6, 0.2)), "[E] Have a nap in your bed", nap)

func _process(_delta: float) -> void:
	# no sunshine through the roof
	if home.player and home.sun:
		home.sun.visible = not is_inside(home.player.global_position)

# --- furniture -------------------------------------------------------------------
func _desk() -> void:
	var wood := room._mat(Color(0.5, 0.31, 0.17), 0.7)
	var dark := room._mat(Color(0.3, 0.19, 0.1), 0.8)
	var d := DESK
	room._box(d + Vector3(-0.75, 0.74, -0.36), d + Vector3(0.75, 0.8, 0.34), wood)                 # top
	for sx in [-0.68, 0.68]:
		for sz in [-0.3, 0.27]:
			room._box(d + Vector3(sx - 0.035, 0, sz - 0.035), d + Vector3(sx + 0.035, 0.74, sz + 0.035), dark)
	room._box(d + Vector3(-0.66, 0.56, -0.3), d + Vector3(0.66, 0.735, 0.3), dark)                  # drawers
	room._box(d + Vector3(-0.6, 0.58, 0.3), d + Vector3(-0.04, 0.715, 0.32), wood)
	room._box(d + Vector3(0.04, 0.58, 0.3), d + Vector3(0.6, 0.715, 0.32), wood)
	var brass := room._mat(Color(0.9, 0.7, 0.3), 0.3, 0.8)
	for kx in [-0.32, 0.32]:
		room._box(d + Vector3(kx - 0.04, 0.635, 0.32), d + Vector3(kx + 0.04, 0.66, 0.34), brass)
	# a big book, the ink pot and quill, and a name card
	var book := room._mat(Color(0.55, 0.12, 0.12), 0.6)
	room._box(d + Vector3(-0.5, 0.8, -0.16), d + Vector3(-0.08, 0.86, 0.14), book)
	room._box(d + Vector3(-0.49, 0.805, -0.155), d + Vector3(-0.09, 0.855, 0.135), room._mat(Color(0.95, 0.92, 0.82)))
	var ink := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.045; cm.height = 0.07
	ink.mesh = cm; ink.material_override = room._mat(Color(0.08, 0.1, 0.2), 0.2)
	room.add_child(ink); ink.position = IntroMovie.ROOM + d + Vector3(0.25, 0.835, -0.15)
	var quill := MeshInstance3D.new(); var qm := CylinderMesh.new(); qm.top_radius = 0.003; qm.bottom_radius = 0.012; qm.height = 0.3
	quill.mesh = qm; quill.material_override = room._mat(Color(0.97, 0.97, 0.95), 0.6)
	room.add_child(quill); quill.position = IntroMovie.ROOM + d + Vector3(0.27, 0.95, -0.13); quill.rotation = Vector3(0.35, 0, -0.3)
	Props.place(room, "candle_triple", IntroMovie.ROOM + d + Vector3(0.55, 0.8, -0.2), 0.0, 0.4)
	var card := room._box(d + Vector3(0.0, 0.8, 0.02), d + Vector3(0.45, 1.06, 0.04), room._mat(Color(0.98, 0.93, 0.7)))
	card.rotation.x = -0.25
	var lbl := Label3D.new(); lbl.text = "NAME\n& LOOKS"; lbl.modulate = Color(0.55, 0.15, 0.1)
	lbl.outline_size = 0; lbl.font_size = 64
	card.add_child(lbl); lbl.position = Vector3(0, 0, 0.011)
	SignText.fit(lbl, 0.42, 0.24)
	Props.place(room, "stool", IntroMovie.ROOM + d + Vector3(0, 0, 0.85), 0.0, 1.0)

func _chest() -> void:
	var t := Props.place(room, "trunk_medium_A", IntroMovie.ROOM + CHEST, 90.0, 1.0)
	var a := Props.mesh_aabb(t)
	if a.size.y > 0.0:
		t.scale = Vector3.ONE * clampf(0.62 / a.size.y, 0.3, 2.0)    # knee-high
	var lbl := Label3D.new(); lbl.text = "GEAR CHEST"; lbl.modulate = Color(1.0, 0.85, 0.4)
	lbl.outline_size = 10; lbl.outline_modulate = Color(0.2, 0.1, 0.05); lbl.font_size = 64
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	room.add_child(lbl); lbl.position = IntroMovie.ROOM + CHEST + Vector3(0, 1.05, 0)
	SignText.fit(lbl, 0.9, 0.2)

func _door_inside() -> void:
	var door := room._mat(Color(0.45, 0.28, 0.15), 0.75)
	var dark := room._mat(Color(0.27, 0.17, 0.09), 0.8)
	var d := IN_DOOR
	room._box(d + Vector3(-0.55, 0, -0.05), d + Vector3(0.55, 2.3, 0.0), door)
	for k in 4:
		var x := -0.41 + k * 0.275
		room._box(d + Vector3(x - 0.012, 0.02, -0.058), d + Vector3(x + 0.012, 2.28, -0.05), dark)
	for y in [0.4, 1.9]:
		room._box(d + Vector3(-0.52, y - 0.06, -0.066), d + Vector3(0.52, y + 0.06, -0.05), dark)
	room._box(d + Vector3(-0.66, 0, -0.08), d + Vector3(-0.55, 2.42, 0.0), dark)
	room._box(d + Vector3(0.55, 0, -0.08), d + Vector3(0.66, 2.42, 0.0), dark)
	room._box(d + Vector3(-0.66, 2.3, -0.08), d + Vector3(0.66, 2.42, 0.0), dark)
	var knob := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.045; sm.height = 0.09
	knob.mesh = sm; knob.material_override = room._mat(Color(0.9, 0.7, 0.3), 0.3, 0.8)
	room.add_child(knob); knob.position = IntroMovie.ROOM + d + Vector3(0.38, 1.05, -0.1)
	room._box(d + Vector3(-0.6, 0.0, -0.75), d + Vector3(0.6, 0.012, -0.12), room._mat(Color(0.55, 0.25, 0.2)))   # door mat

## Solid walls, floor and furniture (the set's boxes and the models standing on the floor).
func _collide_set() -> void:
	for c in room.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if not mi.mesh is BoxMesh:
				continue
			var sz: Vector3 = (mi.mesh as BoxMesh).size
			if sz.y < 0.1 and (sz.x < 2.0 or sz.z < 2.0):
				continue          # floorboards, trims, the door mat
			if mi.rotation != Vector3.ZERO:
				continue          # the little name card
			_col(mi.global_transform * AABB(-sz * 0.5, sz))
		elif c is Node3D and not (c is Light3D or c is GeometryInstance3D or c is Label3D):
			var n := c as Node3D
			if n.position.y - IntroMovie.ROOM.y > 0.3:
				continue          # things on shelves and tables
			var a := Props.mesh_aabb(n)
			if a.size.y < 0.25:
				continue
			_col(n.global_transform * a)

func _col(a: AABB) -> void:
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = a.size
	cs.shape = bs; cs.position = a.get_center()
	_body.add_child(cs)

# --- using things ------------------------------------------------------------------
func go_in() -> void:
	var sc := get_tree().current_scene
	if sc.has_method("teleport_player"):
		Sfx.play("door", -4.0, 0.1)
		sc.teleport_player(w(IN_DOOR + Vector3(0, 0.05, -1.2)), 0.0, "Home sweet home!")

func go_out() -> void:
	var sc := get_tree().current_scene
	if sc.has_method("teleport_player"):
		Sfx.play("door", -4.0, 0.1)
		sc.teleport_player(home.ground(IntroMovie.DOOR.x, 5.8) + Vector3(0, 0.1, 0), PI, "Out into the yard.")

func _use_desk() -> void:
	var sc := get_tree().current_scene
	if sc.has_method("open_desk"):
		sc.open_desk()

func _use_chest() -> void:
	var sc := get_tree().current_scene
	if sc.has_method("open_stash"):
		Sfx.play("chest", -6.0, 0.1)
		sc.open_stash()

func nap() -> void:
	var sc := get_tree().current_scene
	var p := home.player
	if p == null or sc == null or not "menus" in sc:
		return
	p.input_enabled = false
	Game.say("You snuggle under the patchwork blanket... Zzz...", Color(0.75, 0.8, 1.0))
	var tw: Tween = sc.menus.fade_to(1.0, 0.8)
	tw.finished.connect(func() -> void:
		Game.hp = Game.max_hp(); Game.mana = Game.max_mana(); Game.stamina = Game.max_stamina()
		Game.stats_changed.emit()
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			sc.menus.fade_to(0.0, 1.0)
			p.input_enabled = true
			Game.say("What a lovely nap! You feel fully rested.", Color(1.0, 0.9, 0.6))
			if sc.has_method("autosave"):
				sc.autosave()))
