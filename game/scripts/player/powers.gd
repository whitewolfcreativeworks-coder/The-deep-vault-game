extends Node
class_name Powers
## Forge powers (on forged gear: see ForgeRecipes) and the Trading Post's weapon
## enchantments and armor blessings (see ShopCatalog), in action. The player calls
## the hooks below; none of it does anything unless you wear forged gear with a
## power or bought the matching magic at the shop.

var p: Player
var fired := {}              # power -> times it went off (for the tests)
var phoenix_used := false    # rise from the ashes once per level (a new level = a new player)
var _thunder_t := 3.0
var _chain_cd := 0.0
var _spark_cd := 0.0
var _shock_cd := 0.0
var _steam_cd := 0.0
var _nova_cd := 0.0
var _veil_cd := 0.0
var _trail_drop := 0.0
var _trail_check := 0.0
var _trail: Array = []       # [CPUParticles3D, seconds left]
var _risen: Array = []       # allies raised by Bonecaller / Moonfang

## The shop's enchantments and blessings work just like these powers.
const BOON_FOR := {"burn_hit": "flame_edge", "frost_hit": "frost_edge", "spark_hit": "storm_edge", "thorns": "thorns"}

static func attach(player: Player) -> Powers:
	var w := Powers.new()
	w.name = "Powers"
	w.p = player
	player.add_child(w)
	return w

func _ready() -> void:
	Game.foe_down.connect(_on_kill)

func has(tag: String) -> bool:
	return Game.has_power(tag) or (BOON_FOR.has(tag) and Game.has_boon(String(BOON_FOR[tag])))

func _went(tag: String) -> void:
	fired[tag] = int(fired.get(tag, 0)) + 1

# --- your hits ------------------------------------------------------------------------
func on_hit(e: Node3D, dmg: float) -> void:
	if not is_instance_valid(e) or e.is_in_group("critter") or e.get("dead") == true:
		return
	if has("burn_hit"):
		ignite(e, Game.attack_damage() * 0.2, 3.0)
		_went("burn_hit")
	if has("frost_hit"):
		chill(e, 1.6)
		_went("frost_hit")
	if has("chain_lightning") and _chain_cd <= 0.0:
		_chain_cd = 0.3
		if _arc(e, 3, maxf(dmg * 0.45, Game.attack_damage() * 0.4), 7.5) > 0:
			_went("chain_lightning")
	elif has("spark_hit") and _spark_cd <= 0.0 and randf() < 0.3:
		_spark_cd = 0.5
		if _arc(e, 1, maxf(dmg * 0.5, Game.attack_damage() * 0.4), 6.0) > 0:
			_went("spark_hit")

## Set a foe on fire: it keeps burning for a few seconds.
func ignite(e: Node3D, dps: float, secs: float) -> void:
	if e.has_method("ignite"):
		e.ignite(dps, secs)
	elif e.has_method("take_damage"):
		e.take_damage(dps * secs * 0.5, e.global_position, 0.0, false)

## Chill a foe: it moves and swings in slow motion for a moment.
func chill(e: Node3D, secs: float) -> void:
	if "slow_t" in e:
		e.slow_t = maxf(float(e.slow_t), secs)
		var b = e.get("body")
		if b is CharacterModel:
			(b as CharacterModel).slow = 0.4
	FX.burst(e.global_position + Vector3(0, 1.1, 0), Color(0.6, 0.92, 1.0), 10, 2.0, 0.12, 0.45, -3.0)

## Lightning jumps from one foe to the next (up to n of them). Returns how many it hit.
func _arc(from_e: Node3D, n: int, dmg: float, reach: float) -> int:
	var hit: Array = [from_e]
	var at := from_e.global_position + Vector3(0, 1.1, 0)
	for i in n:
		var best: Node3D = null
		var bd := reach
		for e in p._live_enemies():
			if hit.has(e):
				continue
			var d := (e as Node3D).global_position.distance_to(at)
			if d < bd:
				bd = d; best = e
		if best == null:
			break
		var to := best.global_position + Vector3(0, 1.1, 0)
		FX.beam(at, to, Color(0.75, 0.85, 1.0), 0.14, 0.25)
		FX.sparks(to, Color(0.8, 0.9, 1.0))
		best.take_damage(dmg, at, 1.0, false)
		hit.append(best)
		at = to
	if hit.size() > 1:
		Sfx.play_at("spell_hit", at, -6.0, 0.2)
	return hit.size() - 1

# --- blows you take ---------------------------------------------------------------------
## After a foe's blow lands (not fire or falling).
func on_hurt(dmg: float, from_pos: Vector3) -> void:
	if p.dead:
		return
	if has("thorns"):
		var e := _nearest(from_pos, 4.5)
		if e:
			e.take_damage(Game.attack_damage() * 0.35 + dmg * 0.4, p.global_position, 1.5, false)
			FX.burst(e.global_position + Vector3(0, 1.1, 0), Color(0.55, 0.9, 0.35), 12, 3.0, 0.1, 0.4, -4.0)
			_went("thorns")
	if has("steam") and _steam_cd <= 0.0:
		_steam_cd = 6.0
		var c := p.global_position + Vector3(0, 1.0, 0)
		FX.burst(c, Color(0.95, 0.97, 1.0), 50, 5.0, 0.6, 1.4, 1.5)
		FX.dome(p.global_position, Color(0.9, 0.95, 1.0), 5.0, 0.5)
		Sfx.play("fire_burst", -7.0, 0.1)
		for e in _foes_near(p.global_position, 5.5):
			if e.has_method("lose_target"):
				e.lose_target(2.5)
			e.take_damage(Game.attack_damage() * 0.6, p.global_position, 4.0, false)
		_went("steam")
	if has("frost_nova") and _nova_cd <= 0.0 and dmg >= Game.max_hp() * 0.1:
		_nova_cd = 8.0
		FX.shockwave(p.global_position + Vector3(0, 0.1, 0), Color(0.6, 0.92, 1.0), 5.5, 0.5)
		FX.burst(p.global_position + Vector3(0, 1.0, 0), Color(0.75, 0.95, 1.0), 40, 6.0, 0.15, 0.6, -4.0)
		Sfx.play("clang", -6.0, 0.2)
		for e in _foes_near(p.global_position, 5.5):
			if e.has_method("freeze"):
				e.freeze(2.5)
		_went("frost_nova")

## A blow stopped by your shield.
func on_block(_from_pos: Vector3) -> void:
	if not has("shockwave") or _shock_cd > 0.0:
		return
	_shock_cd = 2.5
	FX.shockwave(p.global_position + Vector3(0, 0.1, 0), Color(0.85, 0.75, 0.55), 4.5, 0.4)
	Sfx.play("slam", -8.0, 0.1)
	for e in _foes_near(p.global_position, 4.5):
		e.take_damage(Game.attack_damage() * 0.6, p.global_position, 7.0, false)
	_went("shockwave")

func on_dodge() -> void:
	if not has("shadow_veil") or _veil_cd > 0.0:
		return
	_veil_cd = 4.0
	FX.burst(p.global_position + Vector3(0, 1.0, 0), Color(0.35, 0.2, 0.55), 30, 2.5, 0.5, 1.0, 0.5)
	for e in _foes_near(p.global_position, 12.0):
		if e.has_method("lose_target"):
			e.lose_target(1.8)
	_went("shadow_veil")

## Phoenix: about to fall? Rise from the ashes instead (once per level).
func save_from_death() -> bool:
	if phoenix_used or not has("phoenix"):
		return false
	phoenix_used = true
	Game.hp = Game.max_hp() * 0.5
	p.invuln = 2.5
	p._burn_t = 0.0
	var at := p.global_position
	FX.pillar(at, Color(1.0, 0.55, 0.15), 1.6, 10.0, 0.9)
	FX.shockwave(at + Vector3(0, 0.1, 0), Color(1.0, 0.7, 0.25), 6.5, 0.6)
	FX.burst(at + Vector3(0, 1.2, 0), Color(1.0, 0.8, 0.3), 60, 7.0, 0.2, 0.9, 1.0)
	FX.screen_flash(Color(1.0, 0.75, 0.3), 0.6, 0.6)
	Sfx.play("fire_burst", -2.0, 0.0)
	Sfx.play("levelup", -6.0, 0.0)
	for e in _foes_near(at, 6.5):
		e.take_damage(Game.attack_damage() * 1.5, at, 8.0, false)
	Game.say("PHOENIX! You rise from the ashes!", Color(1.0, 0.7, 0.25))
	Game.stats_changed.emit()
	_went("phoenix")
	return true

# --- foes you defeat --------------------------------------------------------------------
func _on_kill(pos: Vector3) -> void:
	if p == null or p.dead or p.global_position.distance_to(pos) > 40.0:
		return
	if has("radiance"):
		p.heal(Game.max_hp() * 0.06)
		FX.burst(p.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.92, 0.55), 12, 2.0, 0.12, 0.6, 1.0)
		_went("radiance")
	_risen = _risen.filter(func(a) -> bool: return is_instance_valid(a))
	if has("raise_dead") and _risen.size() < 2 and randf() < 0.35:
		_risen.append(Ally.spawn(p, "skeleton", pos + Vector3(0, 0.1, 0), 25.0))
		Game.say("The fallen rise to fight for you!", Color(0.7, 1.0, 0.85))
		_went("raise_dead")
	elif has("summon_wolf") and _risen.is_empty() and randf() < 0.3:
		_risen.append(Ally.spawn(p, "wolf", pos + Vector3(0, 0.2, 0), 20.0))
		FX.burst(pos + Vector3(0, 1.0, 0), Color(0.6, 0.65, 1.0), 30, 3.0, 0.2, 0.8, 0.0)
		Game.say("A spirit wolf answers the call!", Color(0.7, 0.8, 1.0))
		_went("summon_wolf")

# --- always on --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_chain_cd -= delta; _spark_cd -= delta; _shock_cd -= delta
	_steam_cd -= delta; _nova_cd -= delta; _veil_cd -= delta
	if p == null or p.dead:
		return
	if has("wild_heart") and Game.hp < Game.max_hp():
		Game.hp = minf(Game.max_hp(), Game.hp + Game.max_hp() * 0.008 * delta)
	if has("thunderking"):
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = 1.0
			var e := _nearest(p.global_position, 14.0)
			if e:
				_thunder_t = 6.0
				var at := e.global_position
				FX.pillar(at, Color(0.75, 0.85, 1.0), 0.5, 16.0, 0.35)
				FX.beam(at + Vector3(0, 18, 0), at + Vector3(0, 0.5, 0), Color(0.85, 0.9, 1.0), 0.3, 0.3)
				FX.flash_light(at + Vector3(0, 2, 0), Color(0.7, 0.8, 1.0), 6.0, 10.0, 0.2)
				Sfx.play_at("thunder", at, -10.0, 0.1)
				e.take_damage(Game.attack_damage() * 1.5, at + Vector3(0, 3, 0), 2.0, false)
				_went("thunderking")
	_fire_trail(delta)

## Blazewalker: running leaves little fires behind you that burn foes.
func _fire_trail(delta: float) -> void:
	for t in _trail:
		if float(t[1]) > 0.0:
			t[1] = float(t[1]) - delta
			if float(t[1]) <= 0.0:
				(t[0] as CPUParticles3D).emitting = false
	if not has("fire_trail"):
		return
	_trail_drop -= delta
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	if _trail_drop <= 0.0 and hs > Player.WALK + 0.5 and p.is_on_floor():
		_trail_drop = 0.3
		var slot: Array = []
		for t in _trail:
			if float(t[1]) <= 0.0:
				slot = t
				break
		if slot.is_empty() and _trail.size() < 8:
			var f := CPUParticles3D.new(); f.amount = 10; f.lifetime = 0.6
			f.mesh = FX.quad(0.35); f.material_override = FX.glow_material(Color(1.0, 0.5, 0.15), 2.5)
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; f.emission_sphere_radius = 0.35
			f.direction = Vector3.UP; f.spread = 12; f.initial_velocity_min = 1.0; f.initial_velocity_max = 2.0
			f.gravity = Vector3(0, 1.5, 0); f.color_ramp = FX._fade_ramp(Color(1.0, 0.55, 0.15))
			f.top_level = true
			add_child(f)
			slot = [f, 0.0]
			_trail.append(slot)
		if not slot.is_empty():
			var f2: CPUParticles3D = slot[0]
			f2.global_position = p.global_position + Vector3(0, 0.15, 0)
			f2.emitting = true
			slot[1] = 3.0
	_trail_check -= delta
	if _trail_check <= 0.0:
		_trail_check = 0.25
		for e in _foes_near(p.global_position, 14.0):
			for t in _trail:
				if float(t[1]) > 0.0 and (t[0] as Node3D).global_position.distance_to(e.global_position) < 1.4:
					ignite(e, Game.attack_damage() * 0.25, 2.0)
					_went("fire_trail")
					break

# --- helpers ----------------------------------------------------------------------------
func _foes_near(at: Vector3, r: float) -> Array:
	var out: Array = []
	for e in p._live_enemies():
		if (e as Node3D).global_position.distance_to(at) < r:
			out.append(e)
	return out

func _nearest(at: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for e in p._live_enemies():
		var d := (e as Node3D).global_position.distance_to(at)
		if d < bd:
			bd = d; best = e
	return best
