class_name RetroFont
extends RefCounted
## Deterministic bitmap-style text for the retro shells. Port of
## src/renderer/src/shells/win95/bitmapText.tsx (measure/clip/wrap/access keys/draw).
##
## Glyphs come from the bundled pixel fonts rasterized 1-bit (no AA, no hinting, no subpixel)
## and are positioned glyph-by-glyph with exact integer advances, so layout never depends on
## the host OS font stack. Draw into any CanvasItem inside a scaled shell; nearest filtering
## keeps every logical pixel a crisp block at 1x-4x.

const WIN95 := "win95"
const WFW := "wfw"

# Widths from the 8-point, 96-DPI MS Sans Serif strike for ASCII 32..126.
const RTM_ASCII_WIDTHS := [3,3,5,7,6,8,6,2,3,3,4,6,3,3,3,5,6,6,6,6,6,6,6,6,6,6,3,3,6,6,6,6,11,7,7,7,8,7,6,8,8,3,5,7,6,9,8,8,7,8,8,7,7,8,7,11,7,7,7,3,5,3,6,6,3,6,6,6,6,6,3,6,6,2,2,6,2,8,6,6,6,6,3,5,3,6,6,8,5,5,5,4,2,4,7]

const SYSTEM_FONT_PX := 11
const LABEL_LINE_HEIGHT := 13

static var _cache := {}

var family: String
var font: FontFile
var bold_font: FontFile
var font_px := SYSTEM_FONT_PX


static func instance(which: String = WIN95) -> RetroFont:
	if not _cache.has(which):
		_cache[which] = RetroFont.new(which)
	return _cache[which]


static func _load(path: String) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	f.generate_mipmaps = false
	return f


func _init(which: String = WIN95) -> void:
	family = which
	if which == WFW:
		font = _load("res://assets/fonts/wfw/WfWSans.woff2")
		bold_font = _load("res://assets/fonts/wfw/WfWSans-Bold.woff2")
	else:
		font = _load("res://assets/fonts/win95/Win95Sans.woff2")
		bold_font = _load("res://assets/fonts/win95/Win95Sans-Bold.woff2")


func _f(bold: bool) -> FontFile:
	return bold_font if bold else font


## Exact advance in logical pixels for one character.
func advance(ch: String, bold: bool = false) -> int:
	if ch == "\t":
		return 12
	var code := ch.unicode_at(0) if ch.length() > 0 else 63
	if family == WIN95:
		if code >= 32 and code <= 126:
			return RTM_ASCII_WIDTHS[code - 32] + (1 if (bold and code != 32) else 0)
		return 7 if bold else 6
	return maxi(1, int(roundf(_f(bold).get_char_size(code, font_px).x)))


## Splits "&File" style source. Returns {text, accessIndex, accessKey}.
static func parse_access(source: String) -> Dictionary:
	var text := ""
	var access_index := -1
	var access_key := ""
	var i := 0
	var n := source.length()
	while i < n:
		var ch := source[i]
		if ch != "&":
			text += ch
			i += 1
			continue
		if i + 1 < n and source[i + 1] == "&":
			text += "&"
			i += 2
			continue
		if i + 1 < n and access_index < 0:
			access_index = text.length()
			access_key = source[i + 1].to_lower()
			i += 1
			continue
		i += 1
	return {"text": text, "accessIndex": access_index, "accessKey": access_key}


func measure(source: String, bold: bool = false) -> int:
	var text: String = parse_access(source).text
	var w := 0
	for ch in text:
		w += advance(ch, bold)
	return w


func clip(source: String, max_width: int, bold: bool = false) -> String:
	var parsed: String = parse_access(source).text
	if measure(parsed, bold) <= max_width:
		return parsed
	var result := ""
	var width := 0
	for ch in parsed:
		var nxt := width + advance(ch, bold)
		if nxt > max_width:
			break
		result += ch
		width = nxt
	return result


## Word-wraps to max_width; over-long words are hard-broken. Returns PackedStringArray of lines.
func wrap(source: String, max_width: int, bold: bool = false) -> PackedStringArray:
	var text: String = parse_access(source).text
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		if paragraph.is_empty():
			lines.append("")
			continue
		var line := ""
		for word in paragraph.split(" "):
			var candidate := "%s %s" % [line, word] if line != "" else word
			if measure(candidate, bold) <= max_width:
				line = candidate
				continue
			if line != "":
				lines.append(line)
			if measure(word, bold) <= max_width:
				line = word
				continue
			var remainder := word
			while remainder != "":
				var chunk := clip(remainder, max_width, bold)
				if chunk.is_empty():
					break
				lines.append(chunk)
				remainder = remainder.substr(chunk.length())
			line = ""
		if line != "" or lines.is_empty():
			lines.append(line)
	return lines


func ascent_px(bold: bool = false) -> int:
	return int(roundf(_f(bold).get_ascent(font_px)))


func descent_px(bold: bool = false) -> int:
	return int(roundf(_f(bold).get_descent(font_px)))


## y offset from the top of a line box to the glyph baseline (CSS half-leading model).
func baseline_offset(line_height: int = LABEL_LINE_HEIGHT, bold: bool = false) -> int:
	var a := ascent_px(bold)
	var d := descent_px(bold)
	return int(floorf((line_height - (a + d)) / 2.0)) + a + baseline_adjust


## Calibration knob (px) applied to every baseline; set per family after comparing to references.
var baseline_adjust := 0
## Calibration knob (px): horizontal glyph offset (advances/underlines are unaffected).
var x_adjust := 0


## Draw one run of text with its line box top-left at `pos`. Returns the drawn size.
## opts: bold, disabled, desktop_shadow, show_access, max_width (clip), wrap (bool), line_height
func draw(ci: CanvasItem, pos: Vector2, source: String, color: Color = Color.BLACK, opts: Dictionary = {}) -> Vector2:
	var bold: bool = opts.get("bold", false)
	var disabled: bool = opts.get("disabled", false)
	var shadow: bool = opts.get("desktop_shadow", false)
	var show_access: bool = opts.get("show_access", true)
	var max_width: int = opts.get("max_width", 0)
	var do_wrap: bool = opts.get("wrap", false)
	var line_height: int = opts.get("line_height", LABEL_LINE_HEIGHT)
	var parsed := parse_access(source)
	var esc: String = String(parsed.text).replace("&", "&&")  # already-parsed text must not be re-parsed for access keys
	var lines: PackedStringArray
	if do_wrap and max_width > 0:
		lines = self.wrap(esc, max_width, bold)  # explicit self: bare wrap() is the global utility
	elif max_width > 0:
		lines = PackedStringArray([clip(esc, max_width, bold)])
	else:
		lines = PackedStringArray([parsed.text])
	var base := baseline_offset(line_height, bold)
	var gray := Color("#808080")
	var natural := 1
	for li in lines.size():
		var x := floorf(pos.x)
		var y := floorf(pos.y) + li * line_height
		var width := measure(String(lines[li]).replace("&", "&&"), bold)
		natural = maxi(natural, width)
		if disabled:
			_run(ci, Vector2(x + 1, y + 1), lines[li], Color.WHITE, bold, base)
			_run(ci, Vector2(x, y), lines[li], gray, bold, base)
		else:
			if shadow:
				_run(ci, Vector2(x + 1, y + 1), lines[li], Color.BLACK, bold, base)
			_run(ci, Vector2(x, y), lines[li], color, bold, base)
		if show_access and parsed.accessIndex >= 0 and lines.size() == 1:
			var ax: int = measure(String(parsed.text.substr(0, parsed.accessIndex)).replace("&", "&&"), bold)
			if ax < width:
				var uw := maxi(1, advance(parsed.text[parsed.accessIndex], bold) - 1)
				uw = mini(uw, width - ax)
				ci.draw_rect(Rect2(x + ax, y + line_height - 2, uw, 1), gray if disabled else color)
	return Vector2(natural, maxi(line_height, lines.size() * line_height))


func _run(ci: CanvasItem, pos: Vector2, text: String, color: Color, bold: bool, baseline: int) -> void:
	var f := _f(bold)
	var x := pos.x
	var y := pos.y + baseline
	var gx := x_adjust
	for ch in text:
		if ch != " " and ch != "\t":
			if family == WIN95 and _lacks_glyph(f, ch, bold):
				_synth(ci, Vector2(x + gx, y), ch, color, bold)
			else:
				ci.draw_char(f, Vector2(x + gx, y), ch, font_px, color)
		x += advance(ch, bold)


# The bundled Win95Sans faces lack a few ASCII glyphs (normal: < > | `; bold: " ' * + , . / < = > ? \ _ |).
# The original fell back to a system font; these 1-bit shapes stand in. Rows are strings ('#' = ink),
# `y` is the first row's offset below the cap-height line (cap top = baseline - 9).
const _SYNTH_NORMAL := {
	"<": {"y": 1, "rows": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"]},
	">": {"y": 1, "rows": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."]},
	"|": {"y": 0, "rows": ["#", "#", "#", "#", "#", "#", "#", "#", "#", "#", "#"]},
	"`": {"y": 0, "rows": ["#.", ".#"]},
}
const _SYNTH_BOLD := {
	"\"": {"y": 0, "rows": ["##.##", "##.##", "#..#."]},
	"'": {"y": 0, "rows": ["##", "##", "#."]},
	"*": {"y": 1, "rows": [".#.#.", "..#..", "#####", "..#..", ".#.#."]},
	"+": {"y": 3, "rows": ["..#..", "..#..", "#####", "..#..", "..#.."]},
	",": {"y": 7, "rows": ["##", "##", ".#", "#."]},
	".": {"y": 7, "rows": ["##", "##"]},
	"/": {"y": 0, "rows": ["....#", "....#", "...#.", "...#.", "..#..", "..#..", ".#...", ".#...", "#...."]},
	"<": {"y": 1, "rows": ["...##", "..##.", ".##..", "##...", ".##..", "..##.", "...##"]},
	"=": {"y": 3, "rows": ["#####", ".....", "#####"]},
	">": {"y": 1, "rows": ["##...", ".##..", "..##.", "...##", "..##.", ".##..", "##..."]},
	"?": {"y": 0, "rows": [".####.", "##..##", "....##", "...##.", "..##..", "..##..", "......", "..##..", "..##.."]},
	"\\": {"y": 0, "rows": ["#....", "#....", ".#...", ".#...", "..#..", "..#..", "...#.", "...#.", "....#"]},
	"_": {"y": 10, "rows": ["######"]},
	"|": {"y": 0, "rows": ["##", "##", "##", "##", "##", "##", "##", "##", "##", "##", "##"]},
}
static var _lack_cache := {}


func _lacks_glyph(f: FontFile, ch: String, bold: bool) -> bool:
	var key := ("b" if bold else "n") + ch
	if not _lack_cache.has(key):
		_lack_cache[key] = (_SYNTH_BOLD if bold else _SYNTH_NORMAL).has(ch) and not f.has_char(ch.unicode_at(0))
	return _lack_cache[key]


func _synth(ci: CanvasItem, pos: Vector2, ch: String, color: Color, bold: bool) -> void:
	var g: Dictionary = (_SYNTH_BOLD if bold else _SYNTH_NORMAL)[ch]
	var rows: Array = g.rows
	var top := pos.y - 9 + int(g.y)
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] == "#":
				ci.draw_rect(Rect2(pos.x + 1 + c, top + r, 1, 1), color)


## Natural (unclipped) text size for layout.
func text_size(source: String, bold: bool = false, line_height: int = LABEL_LINE_HEIGHT) -> Vector2:
	var lines: PackedStringArray = parse_access(source).text.split("\n")
	var w := 0
	for l in lines:
		w = maxi(w, measure(l, bold))
	return Vector2(w, lines.size() * line_height)
