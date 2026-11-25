extends Node
class_name ShopUI
## The panels for Tobble's Trading Post ("shop"), the anvil ("forge") and the
## Forge Journal ("journal"). Built into the Menus layer like the gear chest.

var m: Menus
# --- the shop
var _tab := "elixir"
var _shop_list: VBoxContainer
var _shop_gold: Label
var _shop_say: Label
var _shop_boons: Label
var _tab_btns := {}
var _sell_all_armed := false
# --- the forge
var anvil: Array = []                 # the gear on the anvil (up to 3 ids, in order)
var last_forged := ""
var _gear_list: VBoxContainer
var _slot_btns: Array = []
var _whisper: Label
var _tier_lbl: Label
var _forge_btn: Button
var _result_box: VBoxContainer
var _forge_gold: Label
var _smith_say: Label
var _journal_list: VBoxContainer
var _journal_count: Label

const TABS := [["elixir", "Elixirs"], ["enchant", "Enchantments"], ["bless", "Blessings"], ["costume", "Costumes"],
	["deco", "For Your Yard"], ["seed", "Seeds"], ["special", "★ Today's Special"], ["sell", "Sell"]]

func setup(menus: Menus) -> void:
	m = menus
	_build_shop()
	_build_forge()
	_build_journal()
	Game.stats_changed.connect(func() -> void:
		if m.current == "shop":
			_refresh_gold())

func _close_btn() -> Button:
	var x := Button.new(); x.text = "✕  Close"; x.custom_minimum_size = Vector2(160, 54)
	x.pressed.connect(func() -> void: m.resume_requested.emit())
	return x

static func _spacer() -> Control:
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp

static func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = w
	return l

# =========================================================================================
# Tobble's Trading Post
func _build_shop() -> void:
	var p := m._center_panel("shop", 1460, 820)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 18); v.add_child(head)
	head.add_child(UIKit.label("Tobble's Trading Post", 36, UIKit.GOLD, true))
	head.add_child(_spacer())
	_shop_gold = UIKit.label("", 26, Color(1.0, 0.82, 0.35), true); head.add_child(_shop_gold)
	head.add_child(_close_btn())
	_shop_say = _wrap(UIKit.label("", 19, Color(1.0, 0.9, 0.7)), 1400)
	v.add_child(_shop_say)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); v.add_child(tabs)
	for t in TABS:
		var id: String = t[0]
		var b := Button.new(); b.text = String(t[1]); b.custom_minimum_size = Vector2(170, 52)
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func() -> void:
			Sfx.play("footstep", -8.0, 0.0)
			show_tab(id))
		tabs.add_child(b)
		_tab_btns[id] = b
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(1420, 540)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_shop_list = VBoxContainer.new(); _shop_list.add_theme_constant_override("separation", 8)
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_shop_list)
	_shop_boons = UIKit.label("", 17, Color(0.75, 1.0, 0.8)); v.add_child(_shop_boons)

const LINES := {
	"elixir": "Tobble: \"Elixirs! Drink one and off you go. They wear off after a while, mind.\"",
	"enchant": "Tobble: \"A little magic on your blade. One enchantment at a time, and it fades as you play.\"",
	"bless": "Tobble: \"Blessings for your armor. One at a time, and it fades as you play. Fireproof is very popular with the Insane crowd!\"",
	"costume": "Tobble: \"Costumes you won't find in any chest! Each one lasts a whole day.\"",
	"deco": "Tobble: \"Make your yard lovely! These are yours to keep. I'll set them up myself.\"",
	"seed": "Tobble: \"Seeds for your garden! Magic seeds? Ah, those you'll have to find for yourself, out in the wild.\"",
	"special": "Tobble: \"Today's Special: half price, today only! Something different tomorrow.\"",
	"sell": "Tobble: \"Got gear you're not using? I pay twice what you'd get for salvaging it. What you're wearing stays on you. Vegetables and flowers from your garden too!\"",
}

func open_shop(tab: String) -> void:
	show_tab(tab)

func show_tab(tab: String) -> void:
	_tab = tab
	_sell_all_armed = false
	_shop_say.text = String(LINES.get(tab, ""))
	for id in _tab_btns:
		(_tab_btns[id] as Button).button_pressed = id == tab
	refresh_shop()

func _refresh_gold() -> void:
	_shop_gold.text = "Gold: %d" % Game.gold
	var bt := Game.boons_text()
	_shop_boons.text = ("Active now:  " + bt.replace("\n", "   ")) if bt != "" else "Nothing active right now."
	if Game.costume_id() != "":
		_shop_boons.text += "      Costume: %s (%s left)" % [Loot.COSTUMES.get(Game.costume_id(), {}).get("name", "?"), Game.costume_time_text()]

func refresh_shop() -> void:
	if _shop_list == null:
		return
	_refresh_gold()
	for c in _shop_list.get_children():
		c.queue_free()
	if _tab == "sell":
		_build_sell()
		return
	var wares: Array = [ShopCatalog.ware(ShopCatalog.special_id())] if _tab == "special" else ShopCatalog.of_kind(_tab)
	for w in wares:
		_shop_list.add_child(_ware_row(w))

func _ware_row(w: Dictionary) -> Control:
	var id := String(w.id)
	var col: Color = w.get("color", UIKit.GOLD)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.panel_style(0.6, col, 5))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14); row.add_child(hb)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
	var special := id == ShopCatalog.special_id()
	vb.add_child(UIKit.label(String(w.name) + ("    ★ TODAY'S SPECIAL: HALF PRICE!" if special else ""), 22, col, true))
	vb.add_child(_wrap(UIKit.label(String(w.desc), 17, UIKit.PARCH), 1000))
	var how := ""
	match String(w.kind):
		"elixir", "enchant", "bless":
			how = "Lasts %d minutes of play." % int(w.mins)
			if Game.has_boon(id):
				var s := int(ceilf(float(Game.boons[id])))
				how += "   ACTIVE: %d:%02d left (buy again to add more time)" % [s / 60, s % 60]
			elif String(w.kind) != "elixir":
				how += "   (Replaces any other %s.)" % ("enchantment" if w.kind == "enchant" else "blessing")
		"costume":
			how = "You wear it for a whole day (real time). Shop only!"
			if Game.costume_id() == id:
				how += "   WEARING IT: %s left" % Game.costume_time_text()
		"deco":
			how = "Yours to keep: it goes in your yard at home."
		"seed":
			how = "Plant it in your garden at home.   You have %d." % int(Game.seeds.get(String(w.get("plant", "")), 0))
	vb.add_child(UIKit.label(how, 15, UIKit.DIM))
	var why := ShopCatalog.why_not(id)
	var price := ShopCatalog.price(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 66)
	b.add_theme_font_size_override("font_size", 22)
	if why == "In your yard":
		b.text = "In your yard ✓"
		b.disabled = true
	else:
		b.text = ("Buy  %d gold" % price) if not special else ("Buy  %d gold\n(was %d)" % [price, int(w.price)])
		b.disabled = why != ""
		if why == "Not enough gold":
			b.tooltip_text = "You need %d more gold." % (price - Game.gold)
	b.pressed.connect(func() -> void:
		if ShopCatalog.buy(id):
			_shop_say.text = "Tobble: \"%s\"" % _thanks(w)
			FX.screen_flash(col, 0.25, 0.3)
			refresh_shop())
	hb.add_child(b)
	return row

func _thanks(w: Dictionary) -> String:
	match String(w.kind):
		"costume": return "Ooh, it suits you! Wear it well, it lasts a whole day."
		"deco": return "Lovely choice! It's in your yard already. Go and have a look!"
		"seed": return "Happy planting! Don't forget to water them."
		"enchant": return "There! Your weapon's humming with it. Go get 'em!"
		"bless": return "Blessed and ready! Off you go, hero."
	return "Bottoms up! Pleasure doing business."

func _build_sell() -> void:
	var junk := ShopCatalog.junk()
	var total := 0
	for u in junk:
		total += ShopCatalog.sell_value(u)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 16)
	_shop_list.add_child(top)
	var all := Button.new(); all.custom_minimum_size = Vector2(640, 66); all.add_theme_font_size_override("font_size", 20)
	all.text = ("Sell everything I'm not using  (%d pieces: %d gold)" % [junk.size(), total]) if not _sell_all_armed else ("Are you sure? Tap again to sell %d pieces for %d gold" % [junk.size(), total])
	all.disabled = junk.is_empty()
	all.pressed.connect(func() -> void:
		if not _sell_all_armed:
			_sell_all_armed = true
			refresh_shop()
			return
		_sell_all_armed = false
		var g := 0
		for u in ShopCatalog.junk():
			g += ShopCatalog.sell(String(u))
		Sfx.play("coins", -2.0, 0.0)
		_shop_say.text = "Tobble: \"A fine haul! That's %d gold for you.\"" % g
		refresh_shop())
	top.add_child(all)
	top.add_child(_wrap(UIKit.label("(Keeps what you're wearing, and your forged and legendary gear, just in case.)", 16, UIKit.DIM), 640))
	# your garden's harvest (vegetables and flowers)
	var hv := ShopCatalog.harvest_value()
	if hv > 0:
		var hb := Button.new(); hb.name = "SellHarvest"; hb.custom_minimum_size = Vector2(640, 60); hb.add_theme_font_size_override("font_size", 20)
		var parts: Array = []
		for id in Game.basket:
			parts.append("%d %s" % [int(Game.basket[id]), GardenPlants.plant_name(String(id)).to_lower()])
		hb.text = "Sell my harvest: %s  (%d gold)" % [", ".join(parts), hv]
		hb.pressed.connect(func() -> void:
			var g := ShopCatalog.sell_harvest()
			Sfx.play("coins", -2.0, 0.0)
			_shop_say.text = "Tobble: \"Fresh from your garden! Lovely. %d gold for you.\"" % g
			refresh_shop())
		_shop_list.add_child(hb)
	var bag: Array = Game.inventory.filter(func(u: String) -> bool: return ShopCatalog.can_sell(u))
	bag.sort_custom(func(a: String, b: String) -> bool: return ShopCatalog.sell_value(a) > ShopCatalog.sell_value(b))
	if bag.is_empty():
		_shop_list.add_child(UIKit.label("Nothing to sell. (What you're wearing stays on you.)", 18, UIKit.DIM))
	for u in bag:
		var id: String = u
		var it := Game.item(id)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIKit.panel_style(0.6, it.get("color", UIKit.GOLD), 4))
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12); row.add_child(hb)
		var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
		vb.add_child(UIKit.label("%s   [%s %s]" % [it.get("name", id), Loot.rarity_label(it), Game.SLOT_NAMES.get(it.get("slot", ""), "")], 19, it.get("color", UIKit.PARCH), true))
		vb.add_child(_wrap(UIKit.label(", ".join(Game.item_lines(id)), 15, UIKit.DIM), 1000))
		var b := Button.new(); b.text = "Sell  %d gold" % ShopCatalog.sell_value(id); b.custom_minimum_size = Vector2(200, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void:
			var g := ShopCatalog.sell(id)
			if g > 0:
				Sfx.play("coins", -4.0, 0.1)
				_shop_say.text = "Tobble: \"%d gold for the %s. Thank you kindly!\"" % [g, it.get("name", "gear")]
			refresh_shop())
		hb.add_child(b)
		_shop_list.add_child(row)

# =========================================================================================
# The anvil
func _build_forge() -> void:
	var p := m._center_panel("forge", 1460, 820)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 18); v.add_child(head)
	head.add_child(UIKit.label("The Forge", 36, Color(1.0, 0.65, 0.3), true))
	head.add_child(_spacer())
	_forge_gold = UIKit.label("", 24, Color(1.0, 0.82, 0.35), true); head.add_child(_forge_gold)
	var jb := Button.new(); jb.text = "Forge Journal"; jb.custom_minimum_size = Vector2(230, 54)
	jb.pressed.connect(func() -> void: open_journal())
	head.add_child(jb)
	head.add_child(_close_btn())
	_smith_say = _wrap(UIKit.label("", 18, Color(1.0, 0.8, 0.55)), 1400)
	v.add_child(_smith_say)
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 22); v.add_child(cols)
	# your gear
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 6); cols.add_child(left)
	left.add_child(UIKit.label("Your gear (bag and chest)", 24, UIKit.GOLD, true))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(760, 610)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_gear_list = VBoxContainer.new(); _gear_list.add_theme_constant_override("separation", 6)
	_gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_gear_list)
	# the anvil
	var right := VBoxContainer.new(); right.add_theme_constant_override("separation", 10); right.custom_minimum_size.x = 620
	cols.add_child(right)
	right.add_child(UIKit.label("The Anvil", 24, UIKit.GOLD, true))
	for i in 3:
		var k := i
		var b := Button.new(); b.custom_minimum_size = Vector2(620, 64)
		b.add_theme_font_size_override("font_size", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			if k < anvil.size():
				anvil.remove_at(k)
				Sfx.play("footstep", -8.0, 0.0)
				refresh_forge())
		right.add_child(b)
		_slot_btns.append(b)
	_whisper = _wrap(UIKit.label("", 20, UIKit.PARCH), 620)
	right.add_child(_whisper)
	_tier_lbl = _wrap(UIKit.label("", 18, UIKit.DIM), 620)
	right.add_child(_tier_lbl)
	_forge_btn = Button.new(); _forge_btn.text = "FORGE!"; _forge_btn.custom_minimum_size = Vector2(620, 74)
	_forge_btn.add_theme_font_size_override("font_size", 28)
	_forge_btn.pressed.connect(_do_forge)
	right.add_child(_forge_btn)
	_result_box = VBoxContainer.new(); _result_box.add_theme_constant_override("separation", 6)
	right.add_child(_result_box)

func open_forge(say := "") -> void:
	anvil = anvil.filter(func(u) -> bool: return ForgeRecipes.usable(String(u)))
	_smith_say.text = say if say != "" else "%s: \"Three pieces in, one piece out. What it becomes depends on what you bring me... I'll never tell, but I might drop a hint if you talk to me.\"" % Game.NPC_NAMES.smith.split(" ")[0]
	refresh_forge()

func refresh_forge() -> void:
	if _gear_list == null:
		return
	_forge_gold.text = "Gold: %d" % Game.gold
	for c in _gear_list.get_children():
		c.queue_free()
	var gear: Array = []
	for u in Game.inventory + Game.stash:
		if ForgeRecipes.usable(String(u)) and not gear.has(u):
			gear.append(u)
	gear.sort_custom(func(a, b) -> bool:
		var ia := Game.item(a); var ib := Game.item(b)
		var ta := int(ia.get("tier", 0)); var tb := int(ib.get("tier", 0))
		if ta != tb:
			return ta > tb
		var ra := int(ia.get("rarity", 0)); var rb := int(ib.get("rarity", 0))
		return ra > rb if ra != rb else Game.score(a) > Game.score(b))
	if gear.is_empty():
		_gear_list.add_child(_wrap(UIKit.label("No spare gear yet! Go adventuring and bring back what you find. (What you're wearing can't go on the anvil: take it off first.)", 18, UIKit.DIM), 720))
	for u in gear:
		_gear_list.add_child(_gear_row(String(u)))
	for i in 3:
		var b: Button = _slot_btns[i]
		if i < anvil.size():
			var it := Game.item(String(anvil[i]))
			b.text = "  %d.  %s   [%s]      ✕" % [i + 1, it.get("name", "?"), Loot.rarity_label(it)]
			b.add_theme_color_override("font_color", it.get("color", UIKit.PARCH))
			b.disabled = false
		else:
			b.text = "  %d.  (empty: pick a piece of gear on the left)" % (i + 1)
			b.remove_theme_color_override("font_color")
			b.disabled = true
	var wh := ForgeRecipes.whisper(anvil)
	_whisper.text = String(wh.text)
	_whisper.add_theme_color_override("font_color", wh.color)
	if anvil.size() == 3:
		var t := ForgeRecipes.tier_of(anvil)
		_tier_lbl.text = "This will be %s (the smith asks %d gold)." % [ForgeRecipes.TIER_NAMES[t].to_upper(), ForgeRecipes.FEE[t]]
	else:
		_tier_lbl.text = "Three found pieces make a FORGED piece. Three Forged make REFORGED, then MASTERFORGED, then STARFORGED."
	var why := ForgeRecipes.why_not(anvil)
	_forge_btn.disabled = why != ""
	_forge_btn.tooltip_text = why
	_show_result()

func _gear_row(id: String) -> Control:
	var it := Game.item(id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.panel_style(0.6, it.get("color", UIKit.GOLD), 4))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10); row.add_child(hb)
	var vb := VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(vb)
	vb.add_child(UIKit.label(String(it.get("name", id)), 18, it.get("color", UIKit.PARCH), true))
	var where := "  (in the chest)" if Game.stash.has(id) else ""
	vb.add_child(_wrap(UIKit.label("%s %s%s   %s" % [Loot.rarity_label(it), Game.SLOT_NAMES.get(it.get("slot", ""), ""), where, ", ".join(Game.item_lines(id))], 14, UIKit.DIM), 520))
	var b := Button.new(); b.custom_minimum_size = Vector2(150, 54); b.add_theme_font_size_override("font_size", 18)
	if anvil.has(id):
		b.text = "On the anvil"
		b.disabled = true
	else:
		b.text = "Anvil  ⇨"
		b.disabled = anvil.size() >= 3
		b.pressed.connect(func() -> void:
			if anvil.size() < 3 and not anvil.has(id):
				anvil.append(id)
				last_forged = ""
				Sfx.play("clang", -14.0, 0.2)
				refresh_forge())
	hb.add_child(b)
	return row

func _do_forge() -> void:
	var sc := m.get_tree().current_scene
	var uid := ForgeRecipes.forge(anvil)
	if uid == "":
		return
	anvil.clear()
	last_forged = uid
	if sc and sc.has_method("forge_strike"):
		sc.forge_strike(uid)
	else:
		refresh_forge()

func _show_result() -> void:
	for c in _result_box.get_children():
		c.queue_free()
	if last_forged == "" or Game.item(last_forged).is_empty():
		return
	var it := Game.item(last_forged)
	var col: Color = it.get("color", UIKit.GOLD)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", UIKit.panel_style(0.75, col, 8))
	_result_box.add_child(pan)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 4); pan.add_child(vb)
	var grand := ForgeRecipes.is_grand(last_forged)
	vb.add_child(UIKit.label(("★ " if grand else "") + "You forged: " + String(it.name), 26, col, true))
	vb.add_child(UIKit.label("%s %s" % [Loot.rarity_label(it), Game.SLOT_NAMES.get(it.slot, "")], 18, UIKit.PARCH))
	vb.add_child(_wrap(UIKit.label(", ".join(Game.item_lines(last_forged)), 16, UIKit.PARCH), 600))
	if it.has("power2"):
		vb.add_child(_wrap(UIKit.label("★ " + ForgeRecipes.power_text(String(it.power2)), 16, UIKit.PARCH), 600))
	var eq := Button.new(); eq.text = "Wear it now"; eq.custom_minimum_size = Vector2(220, 52)
	eq.disabled = Game.equipped.values().has(last_forged)
	eq.pressed.connect(func() -> void:
		Game.equip(last_forged)
		refresh_forge())
	vb.add_child(eq)

# =========================================================================================
# The Forge Journal
func _build_journal() -> void:
	var p := m._center_panel("journal", 1240, 800)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 18); v.add_child(head)
	head.add_child(UIKit.label("The Forge Journal", 36, Color(1.0, 0.75, 0.4), true))
	head.add_child(_spacer())
	_journal_count = UIKit.label("", 22, UIKit.PARCH, true); head.add_child(_journal_count)
	var back := Button.new(); back.text = "⇦  The anvil"; back.custom_minimum_size = Vector2(200, 54)
	back.pressed.connect(func() -> void:
		m.show_panel("forge")
		open_forge())
	head.add_child(back)
	head.add_child(_close_btn())
	v.add_child(_wrap(UIKit.label("Every secret recipe you discover is written here. The ones still waiting are \"???\". Talk to the smith for riddles: they'll be written here too.", 17, UIKit.DIM), 1180))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(1200, 640)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_journal_list = VBoxContainer.new(); _journal_list.add_theme_constant_override("separation", 6)
	_journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_journal_list)

func open_journal() -> void:
	m.show_panel("journal")
	refresh_journal()

func refresh_journal() -> void:
	for c in _journal_list.get_children():
		c.queue_free()
	var found: Array = Game.forge_book.found
	var heard: Array = Game.forge_book.hints
	_journal_count.text = "Discovered: %d / %d" % [found.size(), ForgeRecipes.RECIPES.size()]
	for r in ForgeRecipes.RECIPES:
		var row := PanelContainer.new()
		var have := found.has(r.id)
		var col: Color = ForgeRecipes.TIER_COLORS[int(r.tier)] if have else UIKit.DIM
		row.add_theme_stylebox_override("panel", UIKit.panel_style(0.55, col, 4))
		var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 2); row.add_child(vb)
		if have:
			var nm: Dictionary = r.names
			vb.add_child(UIKit.label("%s  /  %s  /  %s" % [nm.weapon, nm.armor, nm.artifact], 20, col, true))
			var e: Array = r.ess
			var what: String = ForgeRecipes.ESSENCE_NAMES[e[0]] if e[0] == e[1] else "%s + %s" % [ForgeRecipes.ESSENCE_NAMES[e[0]], ForgeRecipes.ESSENCE_NAMES[e[1]]]
			if e[0] == e[1]:
				what = "Pure " + what
			vb.add_child(UIKit.label("%s, %s or better.   ★ %s" % [what, ForgeRecipes.TIER_NAMES[int(r.tier)], ForgeRecipes.power_text(String(r.power))], 16, UIKit.PARCH))
		else:
			vb.add_child(UIKit.label("???", 20, UIKit.DIM, true))
			var hint := ("%s said: \"%s\"" % [Game.NPC_NAMES.smith.split(" ")[0], r.hint]) if heard.has(r.id) else "(Talk to the smith for a hint.)"
			vb.add_child(_wrap(UIKit.label(hint, 16, Color(1.0, 0.8, 0.55) if heard.has(r.id) else UIKit.DIM), 1150))
		_journal_list.add_child(row)
