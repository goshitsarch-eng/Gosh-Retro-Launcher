class_name BeFont
extends RefCounted
## The Be shell's smooth UI font. The design uses the platform Helvetica stack; no new font is bundled, so this is a
## SystemFont with the same family list (falling back to Godot's built-in default when none is installed).
## Text is positioned on a fixed line box (18 px for 15 px type) so layout does not depend on the font's metrics.

const FAMILIES := ["Helvetica Neue", "Helvetica", "Nimbus Sans", "Liberation Sans", "Arial", "DejaVu Sans"]

static var _regular: Font
static var _bold: Font
static var _width_cache := {}


static func font(bold: bool = false) -> Font:
	if bold:
		if _bold == null:
			_bold = _make(700)
		return _bold
	if _regular == null:
		_regular = _make(400)
	return _regular


static func _make(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FAMILIES)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


static func width(text: String, size: int = BeGeometry.FONT, bold: bool = false) -> float:
	var key := "%s|%d|%s" % [text, size, bold]
	if _width_cache.has(key):
		return _width_cache[key]
	var w := ceilf(font(bold).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if _width_cache.size() > 4000:
		_width_cache.clear()
	_width_cache[key] = w
	return w


## Draws `text` with its line box (height `line`) starting at `top_left`. Returns the text width.
static func draw(ci: CanvasItem, top_left: Vector2, text: String, color: Color, size: int = BeGeometry.FONT,
		bold: bool = false, line: int = BeGeometry.LINE) -> float:
	var f := font(bold)
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var base := floorf(top_left.y + (line - (asc + desc)) / 2.0 + asc + 0.5)
	ci.draw_string(f, Vector2(floorf(top_left.x), base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return width(text, size, bold)


## Draws centred on `cx` (single line).
static func draw_centered(ci: CanvasItem, cx: float, y: float, text: String, color: Color, size: int = BeGeometry.FONT,
		bold: bool = false, line: int = BeGeometry.LINE) -> void:
	draw(ci, Vector2(cx - width(text, size, bold) / 2.0, y), text, color, size, bold, line)


## Single line clipped with an ellipsis (CSS text-overflow).
static func clip(text: String, max_w: float, size: int = BeGeometry.FONT, bold: bool = false) -> String:
	if width(text, size, bold) <= max_w:
		return text
	var lo := 0
	var hi := text.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if width(text.substr(0, mid) + "…", size, bold) <= max_w:
			lo = mid
		else:
			hi = mid - 1
	return text.substr(0, lo) + "…"


## Word wrap to `max_w` (long words are broken). Always returns at least one line.
static func wrap(text: String, max_w: float, size: int = BeGeometry.FONT, bold: bool = false) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for word in text.split(" ", true):
		var trial := word if cur == "" else cur + " " + word
		if width(trial, size, bold) <= max_w:
			cur = trial
			continue
		if cur != "":
			lines.append(cur)
			cur = ""
		var rest: String = word
		while width(rest, size, bold) > max_w and rest.length() > 1:
			var n := rest.length() - 1
			while n > 1 and width(rest.substr(0, n), size, bold) > max_w:
				n -= 1
			lines.append(rest.substr(0, n))
			rest = rest.substr(n)
		cur = rest
	lines.append(cur)
	return lines
