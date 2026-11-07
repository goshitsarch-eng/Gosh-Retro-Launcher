class_name Win31Chrome
extends RefCounted
## Pixel painters for the WfW 3.11 chrome (wfw.css): window frames, captions, caption buttons,
## popup menus, client borders and the shared bitmap text helper. Everything is integer-aligned
## logical pixels drawn into the caller's CanvasItem.

const GRAY_BL := Color("#7f7f7f")
const CORNER_TR := Color("#bfbfbf")

## Calibration of the 1-bit WfWSans baseline against the reference line boxes (see win31_shell.gd).
const BASELINE_ADJUST := 1
## 13px label line boxes sit one pixel higher than the 18px menu/caption boxes in the reference.
const LABEL_DY := -1

static var _font: RetroFont


static func font() -> RetroFont:
	if _font == null:
		_font = RetroFont.instance(RetroFont.WFW)
		_font.baseline_adjust = BASELINE_ADJUST
	return _font


## Draws literal text (no "&" access parsing) with the line box top-left at `pos`.
static func text(ci: CanvasItem, pos: Vector2, s: String, color: Color = Color.BLACK, opts: Dictionary = {}) -> Vector2:
	return font().draw(ci, pos, s.replace("&", "&&"), color, opts)


## Draws an "&Label" with its access underline (underline drawn like text-decoration, offset 1px).
static func access_text(ci: CanvasItem, pos: Vector2, label: String, color: Color, line_height: int, disabled: bool = false) -> void:
	var f := font()
	var parsed := RetroFont.parse_access(label)
	var opts := {"line_height": line_height, "show_access": false, "disabled": disabled}
	f.draw(ci, pos, label, color, opts)
	if parsed.accessIndex >= 0:
		var before: String = parsed.text.substr(0, parsed.accessIndex)
		var ch: String = parsed.text[parsed.accessIndex]
		var ux := floorf(pos.x) + f.measure(before)
		var uy := floorf(pos.y) + f.baseline_offset(line_height) + 1
		var uw := f.advance(ch)
		if disabled:
			Px.fill(ci, ux + 1, uy + 1, uw, 1, Color.WHITE)
			Px.fill(ci, ux, uy, uw, 1, Pal.SHADOW)
		else:
			Px.fill(ci, ux, uy, uw, 1, color)


# ------------------------------------------------------------------ frames

## Window frame (.wfw-program-manager / .wfw-child-window): 1px black border, inset bevel
## (white top/left, shadow bottom/right; white wins at the corners), face fill.
static func window_frame(ci: CanvasItem, r: Rect2) -> void:
	Px.fill_rect(ci, r, Pal.FACE)
	Px.outline(ci, r, Pal.BLACK)
	var inner := r.grow(-1)
	Px.hline(ci, inner.position.x, inner.end.y - 1, inner.size.x, Pal.SHADOW)
	Px.vline(ci, inner.end.x - 1, inner.position.y, inner.size.y, Pal.SHADOW)
	Px.hline(ci, inner.position.x, inner.position.y, inner.size.x, Pal.WHITE)
	Px.vline(ci, inner.position.x, inner.position.y, inner.size.y, Pal.WHITE)


## Recessed client edge: shadow top/left, white bottom/right (blended corner pixels like Chromium).
static func client_edge(ci: CanvasItem, r: Rect2) -> void:
	Px.fill_rect(ci, r, Pal.WHITE)
	Px.hline(ci, r.position.x, r.position.y, r.size.x, Pal.SHADOW)
	Px.vline(ci, r.position.x, r.position.y, r.size.y, Pal.SHADOW)
	Px.hline(ci, r.position.x, r.end.y - 1, r.size.x, Pal.WHITE)
	Px.vline(ci, r.end.x - 1, r.position.y, r.size.y, Pal.WHITE)
	Px.fill(ci, r.end.x - 1, r.position.y, 1, 1, CORNER_TR)
	Px.fill(ci, r.position.x, r.end.y - 1, 1, 1, Pal.FACE)


## Popup/system menu frame including the 1px black drop edge (`1px 1px 0 black`).
static func popup_frame(ci: CanvasItem, r: Rect2) -> void:
	Px.fill(ci, r.position.x + 1, r.position.y + 1, r.size.x, r.size.y, Pal.BLACK)
	window_frame(ci, r)


# ----------------------------------------------------------------- captions

## Caption bar (18px). Title is bold, centered between the 37px control gutters and clipped.
static func caption(ci: CanvasItem, r: Rect2, title: String, active: bool) -> void:
	Px.fill_rect(ci, r, Pal.NAVY if active else Pal.SHADOW)
	var f := font()
	var box_w := int(r.size.x) - 74
	if box_w <= 0:
		return
	var shown := f.clip(title.replace("&", "&&"), box_w, true)
	var w := f.measure(shown.replace("&", "&&"), true)
	var x := r.position.x + 37 + (floorf((box_w - w) / 2.0) if w < box_w else 0.0)
	f.draw(ci, Vector2(x, r.position.y), shown.replace("&", "&&"), Pal.WHITE if active else Pal.FACE,
		{"bold": true, "line_height": 18, "show_access": false})


## 16x16 caption button at `r.position`; kind: "system" | "down" | "up" | "restore".
static func caption_button(ci: CanvasItem, r: Rect2, kind: String, pressed: bool = false) -> void:
	var o := r.position
	Px.fill(ci, o.x, o.y, 16, 16, Pal.FACE)
	if not pressed:
		Px.hline(ci, o.x, o.y, 15, Pal.WHITE)
		Px.vline(ci, o.x, o.y, 15, Pal.WHITE)
		Px.fill(ci, o.x + 15, o.y, 1, 1, Pal.SHADOW)
		Px.fill(ci, o.x, o.y + 15, 1, 1, GRAY_BL)
		Px.vline(ci, o.x + 15, o.y + 1, 15, Pal.BLACK)
		Px.hline(ci, o.x + 1, o.y + 15, 15, Pal.BLACK)
		Px.vline(ci, o.x + 14, o.y + 1, 14, Pal.SHADOW)
		Px.hline(ci, o.x + 1, o.y + 14, 14, Pal.SHADOW)
	else:
		Px.hline(ci, o.x, o.y, 15, Pal.BLACK)
		Px.vline(ci, o.x, o.y, 15, Pal.BLACK)
		Px.fill(ci, o.x + 15, o.y, 1, 1, Pal.SHADOW)
		Px.fill(ci, o.x, o.y + 15, 1, 1, Pal.SHADOW)
		Px.vline(ci, o.x + 15, o.y + 1, 15, Pal.WHITE)
		Px.hline(ci, o.x + 1, o.y + 15, 15, Pal.WHITE)
		Px.vline(ci, o.x + 1, o.y + 1, 14, Pal.SHADOW)
		Px.hline(ci, o.x + 1, o.y + 1, 14, Pal.SHADOW)
	match kind:
		"system":
			Px.fill(ci, o.x + 4, o.y + 9, 8, 1, Pal.BLACK)
			Px.fill(ci, o.x + 4, o.y + 11, 8, 1, Pal.BLACK)
		"down":
			_glyph(ci, o, [[5, 7, 63], [6, 7, 0], [7, 7, 0], [8, 7, 0], [9, 7, 0], [10, 7, 63],
				[5, 8, 162], [6, 8, 0], [7, 8, 0], [8, 8, 0], [9, 8, 0], [10, 8, 162],
				[6, 9, 96], [7, 9, 0], [8, 9, 0], [9, 9, 96],
				[7, 10, 30], [8, 10, 30], [7, 11, 129], [8, 11, 129]])
		"up":
			_glyph(ci, o, [[7, 5, 129], [8, 5, 129], [7, 6, 30], [8, 6, 30],
				[6, 7, 96], [7, 7, 0], [8, 7, 0], [9, 7, 96],
				[5, 8, 162], [6, 8, 0], [7, 8, 0], [8, 8, 0], [9, 8, 0], [10, 8, 162],
				[5, 9, 63], [6, 9, 0], [7, 9, 0], [8, 9, 0], [9, 9, 0], [10, 9, 63]])
		"restore":
			_restore_box(ci, o + Vector2(6, 4))
			_restore_box(ci, o + Vector2(4, 7))


## Pixel list of [x, y, gray] entries (the antialiased CSS border triangles of the reference).
static func _glyph(ci: CanvasItem, o: Vector2, pixels: Array) -> void:
	for p in pixels:
		var g: int = p[2]
		ci.draw_rect(Rect2(o.x + p[0], o.y + p[1], 1, 1), Color8(g, g, g))


static func _restore_box(ci: CanvasItem, p: Vector2) -> void:
	Px.fill(ci, p.x, p.y, 7, 6, Pal.FACE)
	Px.outline(ci, Rect2(p.x, p.y, 7, 6), Pal.BLACK)


# ------------------------------------------------------------------- popups

const CHECK_PIXELS := [
	[7, 0], [8, 0], [6, 1], [7, 1], [8, 1], [5, 2], [6, 2], [7, 2],
	[0, 3], [1, 3], [4, 3], [5, 3], [6, 3], [0, 4], [1, 4], [2, 4], [4, 4], [5, 4],
	[1, 5], [2, 5], [3, 5], [4, 5], [5, 5], [2, 6], [3, 6], [4, 6], [3, 7],
]


## Menu check mark glyph at its top-left.
static func check_mark(ci: CanvasItem, pos: Vector2, color: Color) -> void:
	Px.pixels(ci, pos, CHECK_PIXELS, color)


## Menu separator (2px: shadow over white) spanning `w` starting at x.
static func separator(ci: CanvasItem, x: float, y: float, w: float) -> void:
	Px.hline(ci, x, y, w, Pal.SHADOW)
	Px.hline(ci, x, y + 1, w, Pal.WHITE)
