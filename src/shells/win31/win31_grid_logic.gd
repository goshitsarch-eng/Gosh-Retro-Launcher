class_name Win31GridLogic
extends RefCounted
## Pure logic of the program item area. Port of the layout/navigation/drag clamps in
## Win31ItemGrid.tsx plus the label box rules from wfw.css (.wfw-program-item > span).

const CELL_W := 75
const CELL_H := 72
const ICON := 32
const LABEL_MAX_W := 72      ## span max-width (border-box, includes the 2px side padding)
const LABEL_PAD := 2
const LABEL_LINE := 13
const SCROLLBAR := 16


static func columns(area_w: float) -> int:
	return maxi(1, int(floorf((area_w - WfwTokens.m("programGridInsetX") * 2) / CELL_W)))


## Top-left of every item cell (area coordinates, before scrolling). Auto arrange (or a missing
## manual position) flows the items through the fixed 75x72 cells in stored order.
static func positions(items: Array, auto_arrange: bool, area_w: float) -> Array:
	var cols := columns(area_w)
	var out := []
	for i in items.size():
		var it: Dictionary = items[i]
		var manual: Variant = it.get("win31Position")
		if auto_arrange or manual == null:
			out.append(Vector2i(
				WfwTokens.m("programGridInsetX") + (i % cols) * CELL_W,
				WfwTokens.m("programGridInsetY") + (i / cols) * CELL_H))
		else:
			out.append(Vector2i(int(manual.x), int(manual.y)))
	return out


## Arrow/Home/End navigation. Returns the new index, or -1 when the key is not a navigation key.
## `current` is -1 when nothing in this group is selected.
static func navigate(key: String, current: int, count: int, cols: int) -> int:
	if count <= 0:
		return -1
	match key:
		"right":
			return mini(count - 1, maxi(0, current + 1))
		"left":
			return maxi(0, current - 1)
		"down":
			return mini(count - 1, maxi(0, current + cols))
		"up":
			return maxi(0, current - cols)
		"home":
			return 0
		"end":
			return count - 1
	return -1


## Pointer drag of an item (manual arrangement): clamped and rounded like the TS move/end handlers.
static func drag_position(origin: Vector2, delta: Vector2, area_w: float, area_h: float) -> Vector2i:
	return Vector2i(
		Win31Arrange.js_round(maxf(0.0, minf(area_w - CELL_W, origin.x + delta.x))),
		Win31Arrange.js_round(maxf(0.0, minf(area_h - CELL_H, origin.y + delta.y))))


## Index of the item whose cell contains `point` (area coordinates incl. scroll), topmost = last.
static func item_at(item_positions: Array, point: Vector2) -> int:
	for i in range(item_positions.size() - 1, -1, -1):
		var p: Vector2i = item_positions[i]
		if Rect2(p.x, p.y, CELL_W, CELL_H).has_point(point):
			return i
	return -1


## Scrollable content extent (absolute children: right/bottom edge of the furthest cell).
static func content_size(item_positions: Array) -> Vector2i:
	var w := 0
	var h := 0
	for p in item_positions:
		w = maxi(w, p.x + CELL_W)
		h = maxi(h, p.y + CELL_H)
	return Vector2i(w, h)


## overflow:auto scrollbar visibility. Returns {v: bool, h: bool} for an area_w x area_h box.
static func scrollbars(content: Vector2i, area_w: float, area_h: float) -> Dictionary:
	var v := float(content.y) > area_h
	var h := float(content.x) > area_w - (SCROLLBAR if v else 0)
	if h and not v:
		v = float(content.y) > area_h - SCROLLBAR
	return {"v": v, "h": h}


## Label lines for an item name. mode "wrap" (default) wraps at spaces and breaks long words,
## "ellipsis" keeps one line truncated with "...". Returns {lines: PackedStringArray, box_w: int}
## where box_w is the label span width (text + 2*2px padding, 72 when it wrapped/overflowed).
static func label_layout(font: RetroFont, name: String, mode: String = "wrap") -> Dictionary:
	var content_max := LABEL_MAX_W - LABEL_PAD * 2
	name = lit(name)
	var natural := font.measure(name)
	var lines: PackedStringArray
	var box_w: int
	if natural <= content_max and not name.contains("\n"):
		lines = PackedStringArray([RetroFont.parse_access(name).text])
		box_w = natural + LABEL_PAD * 2
	elif mode == "ellipsis":
		lines = PackedStringArray([ellipsize(font, name, content_max)])
		box_w = LABEL_MAX_W
	else:
		lines = font.wrap(name, content_max)
		box_w = LABEL_MAX_W
	return {"lines": lines, "box_w": box_w}


## `text` must already be escaped with lit(); the result is plain (unescaped) text.
static func ellipsize(font: RetroFont, text: String, max_w: int) -> String:
	if font.measure(text) <= max_w:
		return RetroFont.parse_access(text).text
	var dots := font.measure("...")
	var kept := font.clip(text, maxi(0, max_w - dots))
	return kept + "..."


## Escapes "&" so RetroFont shows user-supplied names literally (no access-key parsing).
static func lit(text: String) -> String:
	return text.replace("&", "&&")


## Minimized-group icon label (single block, same span rules).
static func group_label_layout(font: RetroFont, name: String) -> Dictionary:
	return label_layout(font, name, "wrap")
