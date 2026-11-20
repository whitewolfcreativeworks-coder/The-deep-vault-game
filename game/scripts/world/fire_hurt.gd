extends Node3D
class_name FireHurt
## INSANE: any fire hurts. Campfires, braziers, fire bowls, torches you can reach:
## touch the flames and they burn you like a fire vent does (most of your health,
## and armor doesn't help; see Game.HAZARDS). Jason, Nov 20: "any fire at all
## should hurt you in insane mode".
##
## In Normal and Hard this never exists (attach() does nothing), so those modes
## are exactly as they were.

var radius := 0.6       # how close (sideways) counts as touching the flames
var height := 0.8       # and how far above or below the flame's middle
var _t := 0.0
var _cd := 0.0
var _player: Node3D
## one burn at a time from all the flames together (a campfire can have several
## flame spots; standing in two shouldn't burn you twice at once)
static var _last_hit_ms := -100000

static func attach(parent: Node3D, r: float, h: float, at := Vector3.ZERO) -> void:
	if Game.mode != "insane" or parent == null:
		return
	var f := FireHurt.new()
	f.name = "FireHurt"
	f.radius = r
	f.height = h
	parent.add_child(f)
	f.position = at

func _physics_process(delta: float) -> void:
	_cd -= delta
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.12
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _cd > 0.0 or _player.get("dead") == true or not is_visible_in_tree():
		return
	var d := global_position - (_player.global_position + Vector3(0, 0.9, 0))
	if Vector2(d.x, d.z).length() < radius + 0.3 and absf(d.y) < height + 0.9:
		_cd = 0.8
		if Time.get_ticks_msec() - _last_hit_ms < 800:
			return
		_last_hit_ms = Time.get_ticks_msec()
		if _player.has_method("hazard_hit"):
			_player.hazard_hit(Game.hazard("fire"), 2.0, Game.hazard("fire_burn"), "fire")
