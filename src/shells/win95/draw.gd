class_name Win95Draw
extends RefCounted
## Win95 drawing primitives (integer logical pixels). They reproduce the *rendered output* of the
## original CSS boxes: mitred 1px/2px borders, inset/outer 1px box-shadows, the 2px dither
## backgrounds and the pixel glyph masks. Everything draws into a CanvasItem inside _draw().
##
## Typical use:
##   Win95Draw.raised(self, rect)                       # Start/task/caption/dialog button face
##   Win95Draw.pressed(self, rect)
##   Win95Draw.sunken(self, rect)                       # 2px sunken field (client, text input)
##   Win95Draw.glyph(self, "close", origin, color)      # 14x12 glyph canvas at origin
##   Win95Draw.text(self, pos, "Label", color, opts)    # RetroFont.draw wrapper

const FACE := Color("#c0c0c0")
const LIGHT := Color("#ffffff")
const HIGHLIGHT := Color("#dfdfdf")
const SHADOW := Color("#808080")
const DARK := Color("#000000")
const WINDOW := Color("#ffffff")
const TEXT := Color("#000000")
const DISABLED := Color("#808080")
const CAPTION := Color("#000080")
const INACTIVE := Color("#808080")
const SELECTED := Color("#000080")
const SELECTED_TEXT := Color("#ffffff")

const GLYPH_PIXELS := {
	"close": [
		[3, 2], [4, 2], [10, 2], [11, 2], [4, 3], [5, 3], [9, 3], [10, 3],
		[5, 4], [6, 4], [8, 4], [9, 4], [6, 5], [7, 5], [8, 5],
		[6, 6], [7, 6], [8, 6], [5, 7], [6, 7], [8, 7], [9, 7],
		[4, 8], [5, 8], [9, 8], [10, 8], [3, 9], [4, 9], [10, 9], [11, 9],
	],
	"help": [
		[4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 3], [9, 4], [8, 5],
		[7, 6], [6, 6], [6, 7], [6, 8], [6, 10], [7, 10],
	],
	"minimize": [[3, 9], [4, 9], [5, 9], [6, 9], [7, 9], [8, 9]],
	"maximize": [
		[3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2],
		[3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
		[3, 4], [10, 4], [3, 5], [10, 5], [3, 6], [10, 6], [3, 7], [10, 7],
		[3, 8], [4, 8], [5, 8], [6, 8], [7, 8], [8, 8], [9, 8], [10, 8],
	],
	"restore": [
		[5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
		[5, 4], [10, 4], [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [8, 6],
		[2, 6], [3, 6], [4, 6], [2, 7], [8, 7], [2, 8], [8, 8], [2, 9], [3, 9], [4, 9], [5, 9], [6, 9], [7, 9], [8, 9],
	],
	"menu-right": [[3, 2], [3, 3], [4, 3], [3, 4], [4, 4], [5, 4], [3, 5], [4, 5], [5, 5], [6, 5], [3, 6], [4, 6], [5, 6], [3, 7], [4, 7], [3, 8]],
	"menu-check": [[2, 5], [3, 5], [3, 6], [4, 6], [4, 7], [5, 7], [5, 6], [6, 6], [6, 5], [7, 5], [7, 4], [8, 4], [8, 3], [9, 3]],
	"menu-radio": [[5, 4], [6, 4], [4, 5], [5, 5], [6, 5], [7, 5], [4, 6], [5, 6], [6, 6], [7, 6], [5, 7], [6, 7]],
	"scroll-up": [[6, 3], [5, 4], [6, 4], [7, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [3, 6], [4, 6], [5, 6], [6, 6], [7, 6], [8, 6], [9, 6]],
	"scroll-down": [[3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [6, 6], [7, 6], [6, 7]],
	"scroll-left": [[3, 6], [4, 5], [4, 6], [4, 7], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [6, 3], [6, 4], [6, 5], [6, 6], [6, 7], [6, 8], [6, 9]],
	"scroll-right": [[8, 6], [7, 5], [7, 6], [7, 7], [6, 4], [6, 5], [6, 6], [6, 7], [6, 8], [5, 3], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [5, 9]],
	"combo-down": [[3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [6, 6], [7, 6], [6, 7]],
}

const GLYPH_SIZE := Vector2(14, 12)
const GRIP_SIZE := Vector2(13, 13)

static var _alpha_cache := {}


static func glyph_size(name: String) -> Vector2:
	return GRIP_SIZE if name == "size-grip" else GLYPH_SIZE


## Draws a glyph canvas (14x12, or the 13x13 size grip) with its top-left at origin.
static func glyph(ci: CanvasItem, name: String, origin: Vector2, color: Color = DARK) -> void:
	if name == "size-grip":
		for start in [4, 8, 12]:
			var point := 0
			while point < start:
				var x := 12 - point
				var y: int = start - point
				ci.draw_rect(Rect2(origin.x + x - 1, origin.y + y - 1, 2, 2), LIGHT)
				ci.draw_rect(Rect2(origin.x + x, origin.y + y, 2, 2), SHADOW)
				point += 4
		return
	for p in GLYPH_PIXELS[name]:
		ci.draw_rect(Rect2(origin.x + p[0], origin.y + p[1], 1, 1), color)


static func fill(ci: CanvasItem, r: Rect2, color: Color) -> void:
	if r.size.x > 0 and r.size.y > 0:
		ci.draw_rect(r, color)


static func _px(ci: CanvasItem, x: float, y: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, 1, 1), color)


## CSS-like mitred border. Diagonal corner pixels are the 50/50 blend of the two adjoining sides
## (what Chrome rasterises for differently coloured borders). w = 1 or 2 (any width works).
static func border(ci: CanvasItem, r: Rect2, w: int, top: Color, right: Color, bottom: Color, left: Color) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var iw := r.size.x - 2.0 * w
	var ih := r.size.y - 2.0 * w
	if r.size.x < 2 * w or r.size.y < 2 * w:
		fill(ci, r, top)
		return
	fill(ci, Rect2(x0 + w, y0, iw, w), top)
	fill(ci, Rect2(x0 + w, y1 - w, iw, w), bottom)
	fill(ci, Rect2(x0, y0 + w, w, ih), left)
	fill(ci, Rect2(x1 - w, y0 + w, w, ih), right)
	for j in w:
		for i in w:
			# top-left
			var c := top if j < i else (left if j > i else top.lerp(left, 0.5))
			_px(ci, x0 + i, y0 + j, c)
			# top-right
			var k := w - 1 - i
			c = top if j < k else (right if j > k else top.lerp(right, 0.5))
			_px(ci, x1 - w + i, y0 + j, c)
			# bottom-right
			c = right if i > j else (bottom if j > i else right.lerp(bottom, 0.5))
			_px(ci, x1 - w + i, y1 - w + j, c)
			# bottom-left
			var s := i + j
			c = left if s < w - 1 else (bottom if s > w - 1 else left.lerp(bottom, 0.5))
			_px(ci, x0 + i, y1 - w + j, c)


## Inset box-shadow band (blur 0, spread 0) inside `pad` (the padding box): the L-shaped
## region of pad not covered by pad translated by (dx, dy).
static func inset_shadow(ci: CanvasItem, pad: Rect2, dx: int, dy: int, color: Color) -> void:
	if dy > 0:
		fill(ci, Rect2(pad.position.x, pad.position.y, pad.size.x, minf(dy, pad.size.y)), color)
	elif dy < 0:
		var h := minf(-dy, pad.size.y)
		fill(ci, Rect2(pad.position.x, pad.end.y - h, pad.size.x, h), color)
	if dx > 0:
		fill(ci, Rect2(pad.position.x, pad.position.y, minf(dx, pad.size.x), pad.size.y), color)
	elif dx < 0:
		var w := minf(-dx, pad.size.x)
		fill(ci, Rect2(pad.end.x - w, pad.position.y, w, pad.size.y), color)


## Outer 1px-offset box-shadow (blur 0): the right/bottom strips of the border box shifted by (dx, dy).
static func outer_shadow(ci: CanvasItem, r: Rect2, dx: int, dy: int, color: Color) -> void:
	fill(ci, Rect2(r.end.x, r.position.y + dy, dx, r.size.y), color)
	fill(ci, Rect2(r.position.x + dx, r.end.y, r.size.x - dx, dy), color)


## `.win95-edge-raised` / buttons / caption buttons: 2px light-dark border + inset shadow/highlight.
static func raised(ci: CanvasItem, r: Rect2, face: Color = FACE) -> void:
	fill(ci, r, face)
	border(ci, r, 2, LIGHT, DARK, DARK, LIGHT)
	var pad := r.grow(-2)
	inset_shadow(ci, pad, 1, 1, HIGHLIGHT)
	inset_shadow(ci, pad, -1, -1, SHADOW)


## Pressed/`active` state of the same boxes.
static func pressed(ci: CanvasItem, r: Rect2, face: Color = FACE) -> void:
	fill(ci, r, face)
	border(ci, r, 2, DARK, LIGHT, LIGHT, DARK)
	inset_shadow(ci, r.grow(-2), 1, 1, SHADOW)


## `.win95-edge-sunken` without content covering it: 2px shadow-light border + inset dark band.
## cover_inset=true skips the inset band (it is hidden by opaque children like the folder view).
static func sunken(ci: CanvasItem, r: Rect2, face: Color = WINDOW, cover_inset: bool = false) -> void:
	fill(ci, r, face)
	border(ci, r, 2, SHADOW, LIGHT, LIGHT, SHADOW)
	if not cover_inset:
		inset_shadow(ci, r.grow(-2), 1, 1, DARK)


## 1px sunken (status bar fields, tray).
static func status(ci: CanvasItem, r: Rect2) -> void:
	border(ci, r, 1, SHADOW, LIGHT, LIGHT, SHADOW)


## `.win95-group-box`: 1px sunken border plus a light 1px 1px outer shadow.
static func group_box(ci: CanvasItem, r: Rect2) -> void:
	outer_shadow(ci, r, 1, 1, LIGHT)
	border(ci, r, 1, SHADOW, LIGHT, LIGHT, SHADOW)


## `.win95-window` / `.win95-dialog` frame (1px border + inset 1px light / 2px face / -1px shadow).
static func window_frame(ci: CanvasItem, r: Rect2) -> void:
	fill(ci, r, FACE)
	border(ci, r, 1, HIGHLIGHT, DARK, DARK, HIGHLIGHT)
	var pad := r.grow(-1)
	inset_shadow(ci, pad, -1, -1, SHADOW)
	inset_shadow(ci, pad, 2, 2, FACE)
	inset_shadow(ci, pad, 1, 1, LIGHT)


## Start/popup menu frame: 2px light-dark border + outer 1px dark shadow, face fill.
static func popup_frame(ci: CanvasItem, r: Rect2) -> void:
	outer_shadow(ci, r, 1, 1, DARK)
	fill(ci, r, FACE)
	border(ci, r, 2, LIGHT, DARK, DARK, LIGHT)


## 1px-offset dither backgrounds. `origin` is the padding-box origin the tiles are anchored to.
## Two-layer pattern (task button / set button): (x + y) odd gets `color`.
static func dither_checker(ci: CanvasItem, r: Rect2, origin: Vector2, color: Color) -> void:
	var y := int(r.position.y)
	while y < int(r.end.y):
		var x := int(r.position.x)
		while x < int(r.end.x):
			if (int(x - origin.x) + int(y - origin.y)) & 1 == 1:
				_px(ci, x, y, color)
			x += 1
		y += 1


## Single-layer gradient pattern: pixels (odd x, even y) relative to the origin.
static func dither_sparse(ci: CanvasItem, r: Rect2, origin: Vector2, color: Color, mask: Image = null, mask_origin: Vector2 = Vector2.ZERO) -> void:
	var y := int(r.position.y)
	while y < int(r.end.y):
		var x := int(r.position.x)
		while x < int(r.end.x):
			var rx := int(x - origin.x)
			var ry := int(y - origin.y)
			if (rx & 1) == 1 and (ry & 1) == 0:
				if mask == null or _mask_alpha(mask, int(x - mask_origin.x), int(y - mask_origin.y)):
					_px(ci, x, y, color)
			x += 1
		y += 1


static func _mask_alpha(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.0


static func texture_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var key := tex.get_rid().get_id()
	if _alpha_cache.has(key):
		return _alpha_cache[key]
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	_alpha_cache[key] = img
	return img


## Draws the selected-state dither of an icon (50% blend look) over a drawn icon texture.
static func icon_selection(ci: CanvasItem, tex: Texture2D, pos: Vector2, color: Color) -> void:
	var img := texture_image(tex)
	if img == null:
		return
	dither_sparse(ci, Rect2(pos, tex.get_size()), pos, color, img, pos)


static func icon(ci: CanvasItem, tex: Texture2D, pos: Vector2, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	ci.draw_texture(tex, pos.floor(), modulate)


static func font() -> RetroFont:
	return RetroFont.instance(RetroFont.WIN95)


## Draws text (line box top-left at pos). opts: bold, disabled, desktop_shadow, show_access,
## max_width, wrap, line_height. Returns the drawn size.
static func text(ci: CanvasItem, pos: Vector2, source: String, color: Color = TEXT, opts: Dictionary = {}) -> Vector2:
	return font().draw(ci, pos, source, color, opts)


static func measure(source: String, bold: bool = false) -> int:
	return font().measure(source, bold)


## Draws a 1px dotted focus rectangle the way Chrome paints `outline: 1px dotted`.
static func dotted_rect(ci: CanvasItem, r: Rect2, color: Color) -> void:
	var x0 := int(r.position.x)
	var y0 := int(r.position.y)
	var x1 := int(r.end.x) - 1
	var y1 := int(r.end.y) - 1
	var x := x0
	while x <= x1:
		_px(ci, x, y0, color)
		_px(ci, x, y1, color)
		x += 2
	var y := y0 + 2
	while y < y1:
		_px(ci, x0, y, color)
		_px(ci, x1, y, color)
		y += 2
