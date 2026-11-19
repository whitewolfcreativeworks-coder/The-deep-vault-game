class_name SignText
## The game's sign lettering: Lilita One (SIL Open Font License, Google Fonts), a
## round, chunky, friendly face. Every Label3D in the game uses it (Game hooks
## node_added), and `fit` sizes the words on a sign so they always fit the board.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
static var _font: Font

static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font

## Shrink (never grow past `max_px`) so the text fits a `w` x `h` metre board,
## centred, with a little margin all round.
static func fit(l: Label3D, w: float, h: float, max_px := 0.012) -> void:
	var f := font()
	l.font = f
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size)
	var lines := l.text.count("\n") + 1
	sz.y = maxf(sz.y, f.get_height(l.font_size) * lines) + l.line_spacing * (lines - 1)
	sz += Vector2(l.outline_size, l.outline_size) * 2.0
	l.pixel_size = minf(max_px, minf(w * 0.9 / maxf(sz.x, 1.0), h * 0.86 / maxf(sz.y, 1.0)))
