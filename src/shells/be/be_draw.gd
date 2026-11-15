class_name BeDraw
extends RefCounted
## Drawing primitives for the Be chrome: flat 1px borders, vertical/diagonal gradients, rounded gradient buttons,
## smooth icons and the window-tab widgets. All coordinates are logical pixels.


static func fill(ci: CanvasItem, r: Rect2, color: Color) -> void:
	if r.size.x > 0 and r.size.y > 0:
		ci.draw_rect(r, color)


## 1px border drawn inside `r`.
static func border(ci: CanvasItem, r: Rect2, color: Color) -> void:
	Px.outline(ci, r, color)


static func hline(ci: CanvasItem, x: float, y: float, w: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, 1), color)


static func vline(ci: CanvasItem, x: float, y: float, h: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, 1, h), color)


## box-shadow: inset 1px 1px (tl) , inset -1px -1px (br).
static func inset_edges(ci: CanvasItem, r: Rect2, tl: Color, br: Color) -> void:
	if tl.a > 0.0:
		hline(ci, r.position.x, r.position.y, r.size.x, tl)
		vline(ci, r.position.x, r.position.y, r.size.y, tl)
	if br.a > 0.0:
		hline(ci, r.position.x, r.end.y - 1, r.size.x, br)
		vline(ci, r.end.x - 1, r.position.y, r.size.y, br)


static func gradient_v(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## linear-gradient(135deg, a, b): top-left a to bottom-right b.
static func gradient_diag(ci: CanvasItem, r: Rect2, a: Color, b: Color) -> void:
	var mid := a.lerp(b, 0.5)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([a, mid, b, mid]))


## Rounded rect polygon (radius r, 3 segments per corner).
static func _rounded_points(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2.0],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	for c in corners:
		for i in 4:
			var a: float = c[1] + (PI / 2.0) * float(i) / 3.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	return pts


## Rounded gradient control (BeOS button / select): 1px border, radius 4.
static func button_face(ci: CanvasItem, r: Rect2, top: Color, bottom: Color, border_color: Color, radius: float = 4.0) -> void:
	var pts := _rounded_points(r, radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	var line := pts.duplicate()
	line.append(pts[0])
	ci.draw_polyline(line, border_color, 1.0, true)


## Default-button ring: 0 0 0 2px face, 0 0 0 3px border.
static func default_ring(ci: CanvasItem, r: Rect2, face: Color, edge: Color, radius: float = 4.0) -> void:
	for spec in [[3.0, edge], [2.0, face]]:
		var rr: Rect2 = r.grow(spec[0] - 0.5)
		var pts := _rounded_points(rr, radius + spec[0])
		var line := pts.duplicate()
		line.append(pts[0])
		ci.draw_polyline(line, spec[1], 1.0, true)


## Smooth icon scaled into `box` (aspect-fit, centred). `tint` multiplies RGB (selection darkening).
static func icon(ci: CanvasItem, tex: Texture2D, box: Rect2, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var s := tex.get_size()
	var k := minf(box.size.x / s.x, box.size.y / s.y)
	var sz := s * k
	ci.draw_texture_rect(tex, Rect2((box.position + (box.size - sz) / 2.0).floor(), sz), false, tint)


## Dropdown arrow (CSS border triangle): 8 wide, 5 tall, pointing down.
static func caret_down(ci: CanvasItem, x: float, y: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 8, y), Vector2(x + 4, y + 5)]), color)


## Submenu arrow: 5 wide, 8 tall, pointing right.
static func caret_right(ci: CanvasItem, x: float, y: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 5, y + 4), Vector2(x, y + 8)]), color)


## The resize grip: repeating 135deg hatch (8a8a8a line, white line).
static func grip(ci: CanvasItem, r: Rect2) -> void:
	var dark := BeTheme.b("8a8a8a")
	var light := BeTheme.b("ffffff")
	# Hatch lines across the lower-right triangle (lines from the right/bottom edges going up-left).
	var k := 4
	while k < r.size.x + r.size.y:
		var p0 := Vector2(r.position.x + minf(k, r.size.x), r.position.y + maxf(0.0, k - r.size.x))
		var p1 := Vector2(r.position.x + maxf(0.0, k - r.size.y), r.position.y + minf(k, r.size.y))
		ci.draw_line(p0 + Vector2(0.5, 0.5), p1 + Vector2(0.5, 0.5), dark, 1.0)
		ci.draw_line(p0 + Vector2(1.5, 0.5), p1 + Vector2(0.5, 1.5), light, 1.0)
		k += 5


## Folder-window title tab (and dialog tab). Returns nothing; `active` picks the yellow fill.
static func tab(ci: CanvasItem, r: Rect2, active: bool, with_right_edge: bool = true) -> void:
	fill(ci, r, BeTheme.b("ffcb00") if active else BeTheme.b("e2e2e2"))
	var edge := BeTheme.b("6a6a6a")
	hline(ci, r.position.x, r.position.y, r.size.x, edge)
	vline(ci, r.position.x, r.position.y, r.size.y, edge)
	vline(ci, r.end.x - 1, r.position.y, r.size.y, edge)
	# inset 1px 1px rgba(255,255,255,.75), inset -1px 0 rgba(0,0,0,.2)
	hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, Color(1, 1, 1, 0.75))
	vline(ci, r.position.x + 1, r.position.y + 1, r.size.y - 1, Color(1, 1, 1, 0.75))
	if with_right_edge:
		vline(ci, r.end.x - 2, r.position.y + 1, r.size.y - 1, Color(0, 0, 0, 0.2))


## 15px close box: border + 135deg white-to-dark gradient.
static func close_box(ci: CanvasItem, r: Rect2) -> void:
	gradient_diag(ci, r.grow(-1), Color(1, 1, 1, 0.95), Color(0, 0, 0, 0.12))
	border(ci, r, BeTheme.b("6a6a6a"))


## Zoom box: small white square top-left over a larger gradient square bottom-right.
static func zoom_box(ci: CanvasItem, r: Rect2) -> void:
	var edge := BeTheme.b("6a6a6a")
	var big := Rect2(r.end.x - 11, r.end.y - 11, 11, 11)
	gradient_diag(ci, big.grow(-1), Color(1, 1, 1, 0.95), Color(0, 0, 0, 0.12))
	border(ci, big, edge)
	var small := Rect2(r.position, Vector2(9, 9))
	fill(ci, small, Color(1, 1, 1, 0.7))
	border(ci, small, edge)


## The framed panel used by windows and dialogs: border 6a6a6a, fill d8d8d8, inset white / a8a8a8 edges.
static func panel(ci: CanvasItem, r: Rect2) -> void:
	fill(ci, r, BeTheme.b("d8d8d8"))
	border(ci, r, BeTheme.b("6a6a6a"))
	inset_edges(ci, r.grow(-1), BeTheme.s("ffffff"), BeTheme.s("a8a8a8"))


## Popup menu frame: e8e8e8 fill, 6a6a6a border, 2px 2px 0 rgba(0,0,0,.25) shadow.
static func popup_frame(ci: CanvasItem, r: Rect2) -> void:
	fill(ci, Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.25))
	fill(ci, r, BeTheme.b("e8e8e8"))
	border(ci, r, BeTheme.b("6a6a6a"))


## Separator: 1px a8a8a8 over 1px white with 3px margins (8px tall).
static func separator(ci: CanvasItem, x: float, y: float, w: float) -> void:
	hline(ci, x, y + 3, w, BeTheme.b("a8a8a8"))
	hline(ci, x, y + 4, w, BeTheme.b("ffffff"))


## Sunken text field (white, border 989898, inset c8c8c8).
static func field(ci: CanvasItem, r: Rect2) -> void:
	fill(ci, r, BeTheme.b("ffffff"))
	border(ci, r, BeTheme.b("989898"))
	hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, BeTheme.s("c8c8c8"))
	vline(ci, r.position.x + 1, r.position.y + 1, r.size.y - 2, BeTheme.s("c8c8c8"))
