class_name Px
extends RefCounted
## Integer-pixel drawing helpers. Every rect is in logical pixels; the shell root is scaled
## with nearest filtering so these stay crisp at 1x-4x.


static func fill(ci: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	if w > 0 and h > 0:
		ci.draw_rect(Rect2(x, y, w, h), color)


static func fill_rect(ci: CanvasItem, r: Rect2, color: Color) -> void:
	if r.size.x > 0 and r.size.y > 0:
		ci.draw_rect(r, color)


static func hline(ci: CanvasItem, x: float, y: float, w: float, color: Color) -> void:
	fill(ci, x, y, w, 1, color)


static func vline(ci: CanvasItem, x: float, y: float, h: float, color: Color) -> void:
	fill(ci, x, y, 1, h, color)


## 1px border with separate top-left and bottom-right colors (classic bevel edge).
static func edge(ci: CanvasItem, r: Rect2, tl: Color, br: Color) -> void:
	hline(ci, r.position.x, r.position.y, r.size.x, tl)
	vline(ci, r.position.x, r.position.y, r.size.y, tl)
	hline(ci, r.position.x, r.end.y - 1, r.size.x, br)
	vline(ci, r.end.x - 1, r.position.y, r.size.y, br)


## 1px solid outline.
static func outline(ci: CanvasItem, r: Rect2, color: Color) -> void:
	edge(ci, r, color, color)


## Two-pixel bevel: outer ring (o_tl/o_br) then inner ring (i_tl/i_br). The fill is not drawn.
static func bevel(ci: CanvasItem, r: Rect2, o_tl: Color, o_br: Color, i_tl: Color, i_br: Color) -> void:
	edge(ci, r, o_tl, o_br)
	edge(ci, r.grow(-1), i_tl, i_br)


## Alternating-pixel checker fill (pressed/scroll-track patterns). Phase 0/1 picks which colour starts.
static func checker(ci: CanvasItem, r: Rect2, a: Color, b: Color, phase: int = 0) -> void:
	fill_rect(ci, r, b)
	var y := int(r.position.y)
	var end_y := int(r.end.y)
	var end_x := int(r.end.x)
	while y < end_y:
		var x := int(r.position.x) + ((y + phase) % 2)
		while x < end_x:
			ci.draw_rect(Rect2(x, y, 1, 1), a)
			x += 2
		y += 1


## Dotted focus rectangle (1px on / 1px off), as drawn by DrawFocusRect.
static func focus_rect(ci: CanvasItem, r: Rect2, color: Color = Color.BLACK) -> void:
	var x0 := int(r.position.x)
	var y0 := int(r.position.y)
	var x1 := int(r.end.x) - 1
	var y1 := int(r.end.y) - 1
	var x := x0
	while x <= x1:
		ci.draw_rect(Rect2(x, y0, 1, 1), color)
		ci.draw_rect(Rect2(x, y1, 1, 1), color)
		x += 2
	var y := y0
	while y <= y1:
		ci.draw_rect(Rect2(x0, y, 1, 1), color)
		ci.draw_rect(Rect2(x1, y, 1, 1), color)
		y += 2


## Draws a texture at its native pixel size (or `size`) at integer position.
static func tex(ci: CanvasItem, t: Texture2D, pos: Vector2, size: Vector2 = Vector2.ZERO, modulate: Color = Color.WHITE) -> void:
	if t == null:
		return
	var s := size if size != Vector2.ZERO else t.get_size()
	ci.draw_texture_rect(t, Rect2(pos.floor(), s), false, modulate)


## Draws 1-pixel dots from a list of [x, y] pairs relative to origin (glyph masks).
static func pixels(ci: CanvasItem, origin: Vector2, points: Array, color: Color) -> void:
	for p in points:
		ci.draw_rect(Rect2(origin.x + p[0], origin.y + p[1], 1, 1), color)
