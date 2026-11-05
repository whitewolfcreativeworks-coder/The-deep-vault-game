extends Control
class_name QuestCompass
## A compass in the top-right corner. It turns with the camera so "up" is the way
## you're looking; N (red), E, S, W go round the dial. North is world -Z: in the
## Goblin Forest that's the road up to the Warren.
## While you're on a quest, a gold QUEST ARROW sits on the outer ring and points
## the way to go for the quest you're following (pick one by tapping it in the
## quest list, tapping the compass, or pressing T). It points to:
##   * the quest giver, once the quest is ready to hand in
##   * the nearest goblin / quest item for kill and collect quests
##   * Chief Gruk for the Warren quest
##   * the Warren door when the target is down in the Warren (and the way out
##     when you're down there and need to come back up)

const R := 62.0                         # dial radius
var player: Node3D
var _target := Vector3.ZERO
var _has_target := false
var _below := 0                         # -1 target is below you, 1 above, 0 same level
var _where := ""
var _dist := 0.0
var _retarget := 0.0
var _pulse := 0.0
var _font: Font
var _title := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(2 * R + 60, 2 * R + 70)
	size = custom_minimum_size
	_font = ThemeDB.fallback_font

## Bearing of a world direction, clockwise from north (-Z), in radians.
static func bearing(d: Vector3) -> float:
	return atan2(d.x, -d.z)

func heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_transform.basis.z
	if Vector2(f.x, f.z).length() < 0.01:
		f = cam.global_transform.basis.y      # looking straight down: use the camera's up
	return bearing(f)

func _process(delta: float) -> void:
	_pulse += delta
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.4
		_pick_quest()
		_find_target()
	if _has_target and player:
		var d := _target - player.global_position
		_dist = Vector2(d.x, d.z).length()
	queue_redraw()

# --- which quest, and where is it? --------------------------------------------
func _pick_quest() -> void:
	if Game.current_quest() != "":
		return
	var ids := Game.tracked_quests()
	if ids.is_empty():
		Game.tracked_quest = ""
		return
	# nothing chosen: hand-ins first, then whatever is closest
	var best := ""
	var best_d := INF
	for id in ids:
		var t: Variant = quest_target(id)
		var d := 1e6 if t == null else (t as Vector3).distance_to(player.global_position) if player else 0.0
		if Game.quest_state(id) == "ready":
			d -= 1e7
		if d < best_d:
			best_d = d; best = id
	Game.tracked_quest = best
	Game.tracked_manual = false
	Game.quests_changed.emit()

func _find_target() -> void:
	_has_target = false
	var id := Game.current_quest()
	_title = Game.QUESTS[id].title if id != "" else ""
	if id == "" or player == null:
		return
	var t: Variant = quest_target(id)
	if t != null:
		_target = t
		_has_target = true

## 0 = the forest floor, 1 = the Warren, 2 = the Sinkhole of Death (far below).
func _level(p: Vector3) -> int:
	if Game.zone == "castle":
		return 1 if p.y < CastleWorld.CY + 20.0 else 0
	if Game.zone != "forest":
		return 0
	if p.y < SinkholeOfDeath.SY + 30.0:
		return 2
	if p.y < ForestWorld.WY + 20.0:
		return 1
	return 0

func _first(group: String, test: Callable) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if n is Node3D and test.call(n):
			var d := (n as Node3D).global_position.distance_to(player.global_position)
			if d < bd:
				bd = d; best = n
	return best

## Where the compass should send you for quest `id` (null if nowhere sensible).
func quest_target(id: String) -> Variant:
	if player == null:
		return null
	var q: Dictionary = Game.QUESTS[id]
	var spot: Node3D = null
	if Game.quest_state(id) == "ready":
		spot = _first("npc", func(n: Node) -> bool: return n.get("id") == q.giver)
	else:
		var g: Dictionary = q.goal
		match String(g.type):
			"collect":
				spot = _first("quest_item", func(n: Node) -> bool: return n.get("item") == g.item and (n as Node3D).visible)
			"kill":
				var types: Array = g.get("types", Game.GOBLINS)
				spot = _first("enemy", func(n: Node) -> bool: return n.get("type_id") in types and not n.get("dead") \
					and _level((n as Node3D).global_position) == _level(player.global_position))
				if spot == null:
					spot = _first("enemy", func(n: Node) -> bool: return n.get("type_id") in types and not n.get("dead"))
			"boss":
				spot = _first("enemy", func(n: Node) -> bool: return n.get("uid") == g.uid and not n.get("dead"))
	if spot == null:
		return null
	var at := spot.global_position
	# a different level (the Warren and the Sinkhole are far beneath the forest):
	# point the way in (the Warren door / the sinkhole pit) or the way back up
	var here := _level(player.global_position)
	var there := _level(at)
	_below = 0
	_where = ""
	if here == 0 and there != 0:
		_below = -1
		if Game.zone == "castle":
			_where = "down in the crypt"
			var cd := _first("interactable", func(n: Node) -> bool: return n is Passage and _level((n as Node3D).global_position) == 0)
			if cd:
				return cd.global_position
		elif there == 1:
			_where = "down in the Warren"
			var door := _first("interactable", func(n: Node) -> bool: return n is WarrenDoor)
			if door:
				return door.global_position
		else:
			_where = "down the Sinkhole"
			var pit := _first("sinkhole_pit", func(n: Node) -> bool: return true)
			if pit:
				return pit.global_position
	elif here != 0 and there != here:
		_below = 1
		_where = "climb out"
		var out := _first("interactable", func(n: Node) -> bool: return (n is ClimbOut or n is Passage) and _level((n as Node3D).global_position) == here)
		if out:
			return out.global_position
	return at

## Tapping the compass steps to the next quest.
func tap(pos: Vector2) -> bool:
	if Rect2(Vector2.ZERO, size).has_point(pos - global_position) and not Game.tracked_quests().is_empty():
		Game.track_next()
		_retarget = 0.0
		return true
	return false

# --- drawing ---------------------------------------------------------------------
func _draw() -> void:
	var c := Vector2(size.x * 0.5, R + 22.0)
	var h := heading()
	draw_circle(c, R + 2.0, Color(0.05, 0.04, 0.03, 0.72))
	draw_arc(c, R, 0, TAU, 64, Color(0.85, 0.68, 0.32, 0.95), 3.0, true)
	draw_arc(c, R - 7.0, 0, TAU, 64, Color(0.85, 0.68, 0.32, 0.25), 1.0, true)
	# ticks every 30 degrees
	for k in 12:
		var a := deg_to_rad(k * 30.0) - h
		var dir := Vector2(sin(a), -cos(a))
		var l := 9.0 if k % 3 == 0 else 5.0
		draw_line(c + dir * (R - 1.0), c + dir * (R - 1.0 - l), Color(0.95, 0.85, 0.6, 0.8), 2.0)
	# letters
	var names := ["N", "E", "S", "W"]
	for k in 4:
		var a := deg_to_rad(k * 90.0) - h
		var p := c + Vector2(sin(a), -cos(a)) * (R - 22.0)
		var fs := 22 if k == 0 else 17
		var col := Color(1.0, 0.35, 0.25) if k == 0 else Color(1.0, 0.95, 0.85)
		var w := _font.get_string_size(names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, p + Vector2(-w * 0.5, fs * 0.36), names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(_font, p + Vector2(-w * 0.5, fs * 0.36), names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# you: a small fixed marker at the top (the way you're facing)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -R + 12), c + Vector2(-6, -R + 22), c + Vector2(6, -R + 22)]), Color(1, 1, 1, 0.9))
	draw_circle(c, 3.0, Color(1, 1, 1, 0.8))
	# the quest arrow, on the outside of the ring
	if _has_target and player:
		var d := _target - player.global_position
		var a := bearing(d) - h
		var dir := Vector2(sin(a), -cos(a))
		var side := Vector2(-dir.y, dir.x)
		var near := _dist < 4.0
		var grow := 1.0 + 0.12 * sin(_pulse * 5.0)
		var base := c + dir * (R + 3.0)
		var tip := c + dir * (R + 3.0 + 20.0 * grow)
		var gold := Color(1.0, 0.82, 0.2) if not near else Color(0.5, 1.0, 0.45)
		var pts := PackedVector2Array([tip, base + side * 11.0, base - side * 11.0])
		draw_colored_polygon(pts, gold)
		pts.append(tip)
		draw_polyline(pts, Color(0.25, 0.12, 0.0, 0.95), 2.0, true)
		# the quest name and how far
		var dist_txt := "here!" if near else "%d m" % int(_dist)
		if _where != "":
			dist_txt += "  (%s)" % _where
		var line := "%s  ·  %s" % [_title, dist_txt]
		var fs2 := 15
		var w2 := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var at := Vector2(size.x - w2 - 6.0, c.y + R + 38.0)
		draw_string_outline(_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5, Color(0, 0, 0, 0.9))
		draw_string(_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.88, 0.5))
