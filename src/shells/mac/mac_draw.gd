class_name MacDraw
extends RefCounted
## Drawing primitives for the Mac shell (integer logical pixels; colours via MacTheme so the dark theme applies).
## They reproduce the rendered result of the design's CSS: 1px #444 borders, inset highlights, 2px offset
## shadows, striped title bars and gradient push buttons / boxes.

const CHECK_MASK := [
	"........#", ".......##", "......##.", "#....##..", "##..##...", ".####....", "..##.....",
]
const DOWN_ARROW_MASK := ["#######", ".#####.", "..###..", "...#..."]
const UP_ARROW_MASK := ["...#...", "..###..", ".#####.", "#######"]
const LEFT_ARROW_MASK := ["...#", "..##", ".###", "####", ".###", "..##", "...#"]
const RIGHT_ARROW_MASK := ["#...", "##..", "###.", "####", "###.", "##..", "#..."]


static func font() -> RetroFont:
	return RetroFont.instance(RetroFont.WIN95)


## The bundled pixel font lacks a few typographic glyphs the design uses (ellipsis, curly quotes, em dash).
static func glyph_safe(s: String) -> String:
	return s.replace("\u2026", "...").replace("\u201c", "\"").replace("\u201d", "\"").replace("\u2014", "-")


## Draws text with its line box top-left at pos. Returns the drawn width.
static func text(ci: CanvasItem, pos: Vector2, s: String, color: Color, bold: bool = false, max_width: int = 0) -> int:
	var opts := {"bold": bold, "show_access": false}
	if max_width > 0:
		opts["max_width"] = max_width
	return int(font().draw(ci, pos, glyph_safe(s).replace("&", "&&"), color, opts).x)


static func measure(s: String, bold: bool = false) -> int:
	return font().measure(glyph_safe(s).replace("&", "&&"), bold)


## Text vertically centred in a row of `h` px starting at y.
static func text_centered_y(ci: CanvasItem, x: float, y: float, h: float, s: String, color: Color, bold: bool = false, max_width: int = 0) -> int:
	return text(ci, Vector2(x, y + floorf((h - RetroFont.LABEL_LINE_HEIGHT) / 2.0)), s, color, bold, max_width)


static func mask(ci: CanvasItem, origin: Vector2, rows: Array, color: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2(origin.x + x, origin.y + y, 1, 1), color)


static func check(ci: CanvasItem, origin: Vector2, color: Color) -> void:
	mask(ci, origin, CHECK_MASK, color)


static func _corner_inset(radius: int, row: int) -> int:
	# Pixels cut from the left/right at distance `row` from the top (or bottom) edge of a rounded rect.
	if radius <= 0 or row >= radius:
		return 0
	var dy := float(radius - row) - 0.5
	var dx := sqrt(maxf(0.0, float(radius * radius) - dy * dy))
	return radius - int(roundf(dx))


## Filled rounded rect (radius px corners), optionally with a vertical gradient top -> bottom.
static func round_fill(ci: CanvasItem, r: Rect2, radius: int, top: Color, bottom: Color) -> void:
	var h := int(r.size.y)
	for i in h:
		var inset := _corner_inset(radius, i) if i < radius else (_corner_inset(radius, h - 1 - i) if i >= h - radius else 0)
		var t := float(i) / maxf(1.0, h - 1.0)
		ci.draw_rect(Rect2(r.position.x + inset, r.position.y + i, r.size.x - inset * 2, 1), top.lerp(bottom, t))


static func _row_inset(radius: int, h: int, i: int) -> int:
	if i < 0 or i >= h:
		return radius
	if i < radius:
		return _corner_inset(radius, i)
	if i >= h - radius:
		return _corner_inset(radius, h - 1 - i)
	return 0


## 1px rounded outline.
static func round_outline(ci: CanvasItem, r: Rect2, radius: int, color: Color) -> void:
	var h := int(r.size.y)
	for i in h:
		var inset := _row_inset(radius, h, i)
		if i == 0 or i == h - 1:
			ci.draw_rect(Rect2(r.position.x + inset, r.position.y + i, r.size.x - inset * 2, 1), color)
			continue
		var run := 1 + maxi(0, maxi(_row_inset(radius, h, i - 1), _row_inset(radius, h, i + 1)) - inset)
		ci.draw_rect(Rect2(r.position.x + inset, r.position.y + i, run, 1), color)
		ci.draw_rect(Rect2(r.end.x - inset - run, r.position.y + i, run, 1), color)


static func outline(ci: CanvasItem, r: Rect2, color: Color) -> void:
	Px.outline(ci, r, color)


## Drop shadow: the design's `2px 2px 0 rgba(0,0,0,a)`.
static func drop_shadow(ci: CanvasItem, r: Rect2, alpha: float, offset: int = 2) -> void:
	var c := MacTheme.shadow(alpha)
	ci.draw_rect(Rect2(r.position.x + offset, r.end.y, r.size.x, offset), c)
	ci.draw_rect(Rect2(r.end.x, r.position.y + offset, offset, r.size.y - offset), c)


## Panel with the design's frame: bg #ddd, 1px #444 border, inset 1px white (top/left) and #999 (bottom/right).
static func panel(ci: CanvasItem, r: Rect2, shadow_alpha: float = 0.3, inset_bottom_right: bool = true) -> void:
	drop_shadow(ci, r, shadow_alpha)
	Px.fill_rect(ci, r, MacTheme.b("dddddd"))
	var inner := r.grow(-1)
	Px.hline(ci, inner.position.x, inner.position.y, inner.size.x, MacTheme.s("ffffff"))
	Px.vline(ci, inner.position.x, inner.position.y, inner.size.y, MacTheme.s("ffffff"))
	if inset_bottom_right:
		Px.hline(ci, inner.position.x, inner.end.y - 1, inner.size.x, MacTheme.s("999999"))
		Px.vline(ci, inner.end.x - 1, inner.position.y, inner.size.y, MacTheme.s("999999"))
	Px.outline(ci, r, MacTheme.b("444444"))


## Popup menu panel (menu bar drop-downs, context menus): shadow .45, only the white inset on top/left.
static func menu_panel(ci: CanvasItem, r: Rect2) -> void:
	drop_shadow(ci, r, 0.45)
	Px.fill_rect(ci, r, MacTheme.b("dddddd"))
	Px.hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, MacTheme.s("ffffff"))
	Px.vline(ci, r.position.x + 1, r.position.y + 1, r.size.y - 2, MacTheme.s("ffffff"))
	Px.outline(ci, r, MacTheme.b("444444"))


static func separator(ci: CanvasItem, x: float, y: float, w: float) -> void:
	Px.hline(ci, x, y, w, MacTheme.b("999999"))
	Px.hline(ci, x, y + 1, w, MacTheme.s("ffffff"))


## 135deg white -> #aaa gradient box with a 1px #444 border (close / zoom / shade / check boxes).
static func gradient_box(ci: CanvasItem, r: Rect2, pressed: bool = false) -> void:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var a := MacTheme.b("ffffff")
	var b := MacTheme.b("aaaaaa")
	if pressed:
		var t := a
		a = b
		b = t
	for y in h:
		for x in w:
			var t := float(x + y) / maxf(1.0, float(w + h - 2))
			ci.draw_rect(Rect2(r.position.x + x, r.position.y + y, 1, 1), a.lerp(b, t))
	Px.outline(ci, r, MacTheme.b("444444"))


static func stripes(ci: CanvasItem, r: Rect2) -> void:
	var light := MacTheme.b("ffffff")
	var dark := MacTheme.b("999999")
	for y in int(r.size.y):
		ci.draw_rect(Rect2(r.position.x, r.position.y + y, r.size.x, 1), light if y % 2 == 0 else dark)


## Classic push button: rounded gradient, 1px #444 border; default buttons get the double ring.
static func button(ci: CanvasItem, r: Rect2, label: String, is_default: bool, pressed: bool, disabled: bool = false) -> void:
	if is_default:
		var ring := r.grow(4)
		round_fill(ci, ring, 8, MacTheme.b("444444"), MacTheme.b("444444"))
		round_fill(ci, r.grow(2), 7, MacTheme.b("dddddd"), MacTheme.b("dddddd"))
	var top := MacTheme.b("999999") if pressed else MacTheme.b("ffffff")
	var bottom := MacTheme.b("cccccc")
	round_fill(ci, r, 5, top, bottom)
	round_outline(ci, r, 5, MacTheme.b("444444"))
	var color := MacTheme.t("ffffff") if pressed else (MacTheme.t("999999") if disabled else MacTheme.t("000000"))
	var w := measure(label)
	text(ci, Vector2(r.position.x + floorf((r.size.x - w) / 2.0), r.position.y + floorf((r.size.y - RetroFont.LABEL_LINE_HEIGHT) / 2.0)), label, color)


## Pop-up (select) face: rounded gradient with a down triangle at the right.
static func select_face(ci: CanvasItem, r: Rect2, label: String, open: bool = false) -> void:
	round_fill(ci, r, 4, MacTheme.b("ffffff"), MacTheme.b("dddddd"))
	round_outline(ci, r, 4, MacTheme.b("444444"))
	Px.hline(ci, r.position.x + 2, r.end.y, r.size.x - 2, MacTheme.s("888888"))
	text_centered_y(ci, r.position.x + 8, r.position.y, r.size.y, label, MacTheme.t("000000"), false, int(r.size.x) - 30)
	mask(ci, Vector2(r.end.x - 15, r.position.y + floorf((r.size.y - 4) / 2.0)), DOWN_ARROW_MASK, MacTheme.t("000000"))


## Text field frame: white, 1px #444 border, inset #999 on top/left.
static func field(ci: CanvasItem, r: Rect2) -> void:
	Px.fill_rect(ci, r, MacTheme.b("ffffff"))
	Px.hline(ci, r.position.x + 1, r.position.y + 1, r.size.x - 2, MacTheme.s("999999"))
	Px.vline(ci, r.position.x + 1, r.position.y + 1, r.size.y - 2, MacTheme.s("999999"))
	Px.outline(ci, r, MacTheme.b("444444"))


## Check box: 13x13 gradient box with a check when on.
static func checkbox(ci: CanvasItem, r: Rect2, on: bool) -> void:
	gradient_box(ci, r)
	if on:
		check(ci, Vector2(r.position.x + 2, r.position.y + 3), MacTheme.t("000000"))


## Grow-box texture: 15x15, #ddd face, 1px #888 top/left, diagonal stripes.
static func grip(ci: CanvasItem, r: Rect2, active: bool = true) -> void:
	Px.fill_rect(ci, r, MacTheme.b("dddddd"))
	Px.hline(ci, r.position.x, r.position.y, r.size.x, MacTheme.b("888888"))
	Px.vline(ci, r.position.x, r.position.y, r.size.y, MacTheme.b("888888"))
	if not active:
		return
	var dark := MacTheme.b("888888")
	var light := MacTheme.b("ffffff")
	for y in range(1, int(r.size.y)):
		for x in range(1, int(r.size.x)):
			var d := (x + y) % 5   # repeating-linear-gradient(135deg, transparent 0 3, #888 3 4, #fff 4 5)
			if d == 3:
				ci.draw_rect(Rect2(r.position.x + x, r.position.y + y, 1, 1), dark)
			elif d == 4:
				ci.draw_rect(Rect2(r.position.x + x, r.position.y + y, 1, 1), light)


## Dotted selection / drag-outline rectangle (1px on, 1px off).
static func dotted_outline(ci: CanvasItem, r: Rect2, color: Color) -> void:
	Px.focus_rect(ci, r, color)


## A "folder tab" style marker is not needed; icons are drawn from PNGs. Draws an icon darkened (selected).
static func icon(ci: CanvasItem, tex: Texture2D, pos: Vector2, size: Vector2, selected: bool) -> void:
	if tex == null:
		return
	var mod := Color(0.55, 0.55, 0.55, 1.0) if selected else Color.WHITE
	ci.draw_texture_rect(tex, Rect2(pos.floor(), size), false, mod)


## Icon label: centred text on a white (or desktop) background; selected = white on black.
## `lines` are pre-wrapped. Returns nothing; `bg_unselected` is the box fill when not selected (transparent allowed).
static func icon_label(ci: CanvasItem, area: Rect2, lines: PackedStringArray, selected: bool, bg_unselected: Color, fg_unselected: Color) -> void:
	for i in lines.size():
		var w := measure(lines[i])
		var lx := area.position.x + floorf((area.size.x - w) / 2.0)
		var ly := area.position.y + i * RetroFont.LABEL_LINE_HEIGHT
		var box := Rect2(lx - 4, ly, w + 8, RetroFont.LABEL_LINE_HEIGHT)
		if selected:
			ci.draw_rect(box, MacTheme.b("000000"))
			text(ci, Vector2(lx, ly), lines[i], Color.WHITE)
		else:
			if bg_unselected.a > 0.0:
				ci.draw_rect(box, bg_unselected)
			text(ci, Vector2(lx, ly), lines[i], fg_unselected)


## Wraps/clips an icon label to at most `max_lines` lines of `width` px (wrap or ellipsis mode).
static func label_lines(s: String, width: int, wrap: bool, max_lines: int = 2) -> PackedStringArray:
	var f := font()
	if not wrap:
		return PackedStringArray([_ellipsize(s, width)])
	var lines := f.wrap(glyph_safe(s).replace("&", "&&"), width)
	if lines.size() <= max_lines:
		return lines
	var out := PackedStringArray()
	for i in max_lines - 1:
		out.append(lines[i])
	out.append(_ellipsize(" ".join(lines.slice(max_lines - 1)), width))
	return out


## `s` cut to `width` px with a trailing ellipsis ("..." in the pixel font) when it does not fit; list cells use it.
static func fit(s: String, width: int) -> String:
	return _ellipsize(s, width) if width > 0 else s


## A 16x16 menu-row icon: a `color` square with a dark 1px frame (the note menu's paper colours). Cached.
static var _swatches := {}


static func swatch_texture(color: Color) -> Texture2D:
	var key := color.to_html()
	if _swatches.has(key):
		return _swatches[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(2, 2, 12, 12), Color8(68, 68, 68))
	img.fill_rect(Rect2i(3, 3, 10, 10), color)
	var tex := ImageTexture.create_from_image(img)
	_swatches[key] = tex
	return tex


static func _ellipsize(s: String, width: int) -> String:
	if measure(s) <= width:
		return s
	var t := s
	while t.length() > 1 and measure(t + "...") > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges(false, true) + "..."
