class_name W31
extends RefCounted
## Shared drawing helpers for the Win31 (WfW 3.11) dialog widgets. Everything is drawn in
## logical pixels with integer coordinates; text always goes through RetroFont.WFW.

const FACE := Color("#c0c0c0")
const SHADOW := Color("#808080")
const WHITE := Color("#ffffff")
const BLACK := Color("#000000")
const NAVY := Color("#000080")
const CORNER := Color("#bfbfbf")  ## blended diagonal corner pixel of 1px two-colour borders

static var _fonts := {}


## WfWSans at an exact pixel size (CSS font-size). 11 is the strike's native size.
static func font(px: int = 11) -> RetroFont:
	if px == 11:
		return RetroFont.instance(RetroFont.WFW)
	if not _fonts.has(px):
		var f := RetroFont.new(RetroFont.WFW)
		f.font_px = px
		_fonts[px] = f
	return _fonts[px]


static func text(ci: CanvasItem, x: float, y: float, s: String, color: Color = BLACK, px: int = 11, opts: Dictionary = {}) -> Vector2:
	return font(px).draw(ci, Vector2(x, y), s, color, opts)


static func text_w(s: String, px: int = 11, bold: bool = false) -> int:
	return font(px).measure(s, bold)


## Chromium-style 1px two-colour border: top/left `tl`, bottom/right `br`; the two diagonal
## corner pixels are a blend of both.
static func border2(ci: CanvasItem, r: Rect2, tl: Color, br: Color, corner: Color = CORNER) -> void:
	Px.edge(ci, r, tl, br)
	Px.fill(ci, r.end.x - 1, r.position.y, 1, 1, corner)
	Px.fill(ci, r.position.x, r.end.y - 1, 1, 1, corner)


## `.win31-input`: 1px black border, inset 1px grey line top/left, white fill.
static func sunken_field(ci: CanvasItem, r: Rect2, bg: Color = WHITE) -> void:
	Px.fill_rect(ci, r, bg)
	Px.outline(ci, r, BLACK)
	Px.hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, SHADOW)
	Px.vline(ci, r.position.x + 1, r.position.y + 2, r.size.y - 3, SHADOW)


## WfW raised control (scroll arrows, combo button): white/black outer with a grey inner shadow.
static func raised(ci: CanvasItem, r: Rect2, pressed: bool = false) -> void:
	Px.fill_rect(ci, r, FACE)
	if pressed:
		Px.outline(ci, r, BLACK)
		Px.hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, SHADOW)
		Px.vline(ci, r.position.x + 1, r.position.y + 2, r.size.y - 3, SHADOW)
	else:
		border2(ci, r, WHITE, BLACK, SHADOW)
		Px.hline(ci, r.position.x + 1, r.end.y - 2, r.size.x - 2, SHADOW)
		Px.vline(ci, r.end.x - 2, r.position.y + 1, r.size.y - 2, SHADOW)


## Solid triangle glyph of `n` rows (base width 2n-1); dir 0=up 1=down 2=left 3=right.
## `c` is the centre of the bounding box (integers).
static func triangle(ci: CanvasItem, c: Vector2, dir: int, n: int = 4, color: Color = BLACK) -> void:
	var cx := int(c.x)
	var cy := int(c.y)
	for i in n:
		var w := 2 * (n - 1 - i) + 1  # tip last
		match dir:
			0:  # up: tip on top
				Px.fill(ci, cx - i, cy - n / 2 + i, 2 * i + 1, 1, color)
			1:  # down: tip at bottom
				Px.fill(ci, cx - (n - 1 - i), cy - n / 2 + i, w, 1, color)
			2:  # left: tip on the left
				Px.fill(ci, cx - n / 2 + i, cy - i, 1, 2 * i + 1, color)
			3:  # right: tip on the right
				Px.fill(ci, cx - n / 2 + i, cy - (n - 1 - i), 1, w, color)


## Frame of a Win31 dialog box: black border, white/grey inset, 1px black drop shadow.
static func dialog_frame(ci: CanvasItem, r: Rect2) -> void:
	Px.fill(ci, r.position.x + 1, r.end.y, r.size.x, 1, BLACK)
	Px.fill(ci, r.end.x, r.position.y + 1, 1, r.size.y, BLACK)
	Px.fill_rect(ci, r, FACE)
	Px.outline(ci, r, BLACK)
	var inner := r.grow(-1)
	Px.hline(ci, inner.position.x, inner.position.y, inner.size.x, WHITE)
	Px.vline(ci, inner.position.x, inner.position.y, inner.size.y, WHITE)
	Px.hline(ci, inner.position.x, inner.end.y - 1, inner.size.x, SHADOW)
	Px.vline(ci, inner.end.x - 1, inner.position.y, inner.size.y, SHADOW)


## CSS "etched" group box: 1px frame dark top/left, white bottom/right.
static func group_frame(ci: CanvasItem, r: Rect2) -> void:
	border2(ci, r, SHADOW, WHITE, CORNER)
