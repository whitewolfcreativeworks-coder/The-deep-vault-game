extends Object
class_name UIKit
## Shared look for every interface element: dark stone panels, gold trim.

const GOLD := Color(0.86, 0.70, 0.40)
const PARCH := Color(0.93, 0.89, 0.80)
const DIM := Color(0.62, 0.58, 0.52)
static var _title_font: Font
static var _body_font: Font

## Bigger text everywhere in the menus (Jason, Nov 26: "a little bigger text would be good",
## for his eyes and for younger kids). Every size in the interface goes through fs().
const TEXT_SCALE := 1.25
static func fs(size: float) -> int:
	return int(round(size * TEXT_SCALE))

## The menus' letters: Andika, made by SIL for children learning to read (clear letter
## shapes: I, l and 1 all different, a plain 0). The same on every device: the iPad's
## browser can't use the computer's own fonts. A few symbols (★ ✔ ▶ ...) come from a tiny
## piece of DejaVu Sans.
static func _font_file(path: String, symbols: String) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var f := load(path) as FontFile
	if f == null:
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	if ResourceLoader.exists(symbols):
		var sym := load(symbols) as FontFile
		if sym:
			f.fallbacks = [sym]
	return f

static func title_font() -> Font:
	if _title_font == null:
		_title_font = _font_file("res://assets/fonts/Andika-Bold.ttf", "res://assets/fonts/DejaVuSans-Bold-UISymbols.ttf")
	return _title_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = _font_file("res://assets/fonts/Andika-Regular.ttf", "res://assets/fonts/DejaVuSans-UISymbols.ttf")
	return _body_font

static func panel_style(alpha := 0.86, border := GOLD, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.065, 0.075, alpha)
	s.border_color = Color(border.r, border.g, border.b, 0.75)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 8
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 14; s.content_margin_bottom = 14
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = fs(18)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.13, 0.11, 0.10, 0.92)
	btn.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	btn.set_border_width_all(2); btn.set_corner_radius_all(4)
	btn.content_margin_left = 16; btn.content_margin_right = 16; btn.content_margin_top = 8; btn.content_margin_bottom = 8
	var hov := btn.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.25, 0.19, 0.12, 0.95); hov.border_color = GOLD
	var prs := btn.duplicate() as StyleBoxFlat
	prs.bg_color = Color(0.35, 0.26, 0.14, 1.0)
	var foc := hov.duplicate() as StyleBoxFlat
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", prs)
	t.set_stylebox("focus", "Button", foc)
	t.set_color("font_color", "Button", PARCH)
	t.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", fs(19))
	t.set_color("font_color", "Label", PARCH)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var le := btn.duplicate() as StyleBoxFlat
	le.bg_color = Color(0.04, 0.04, 0.05, 0.95)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", hov)
	t.set_color("font_color", "LineEdit", PARCH)
	t.set_font_size("font_size", "LineEdit", fs(22))
	return t

static func label(text: String, size := 18, color := PARCH, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", title_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func bar(color: Color, w := 260.0, h := 16.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.04, 0.85)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.9)
	bg.set_border_width_all(2); bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(2)
	fg.border_color = color.lightened(0.35)
	fg.border_width_top = 2
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p
