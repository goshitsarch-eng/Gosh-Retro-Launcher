class_name MacGeometry
extends RefCounted
## Pure layout maths for the Mac shell (all integer logical pixels): window chrome rectangles, icon-grid and
## details layouts, desktop icon column, scrollbar thumb, cascading default positions. Nothing here draws.

const MENU_H := 22
const TITLE_H := 22
const BOX := 13
const BODY_MARGIN := 4
const INFO_H := 22
const GRIP := 15
const GRIP_INSET := 5
const SCROLL_W := 16
const MIN_W := 180
const MIN_H := 120
const SHADED_H := TITLE_H + 2

const CELL_W := 104
const CELL_GAP_X := 6
const CELL_GAP_Y := 14
const ICON := 32
const LABEL_LINE := 13
const GRID_PAD := 8
const DETAILS_HEADER_H := 20
const DETAILS_ROW_H := 20
const DETAILS_MIN_W := 300

const DESK_CELL_W := 100
const DESK_RIGHT := 10
const DESK_TOP := 34
const DESK_BOTTOM := 10


## Window chrome rectangles for a window frame `r`. Keys: frame, title, close, zoom, shade, stripe_l, stripe_r,
## title_text (the area the caption occupies), info, content, grip. `has_zoom` is false for Find.
static func chrome(r: Rect2, shaded: bool, has_zoom: bool, caption_w: int) -> Dictionary:
	var x := int(r.position.x)
	var y := int(r.position.y)
	var w := int(r.size.x)
	var h := SHADED_H if shaded else int(r.size.y)
	var inner_x := x + 1
	var inner_w := w - 2
	var by := y + 1 + (TITLE_H - BOX) / 2
	var right := inner_x + inner_w - 6
	var left := inner_x + 6
	var out := {"frame": Rect2(x, y, w, h), "title": Rect2(inner_x, y + 1, inner_w, TITLE_H)}
	out["close"] = Rect2(left, by, BOX, BOX)
	var rx := right
	if has_zoom:
		rx -= BOX
		out["shade"] = Rect2(rx, by, BOX, BOX)
		rx -= 5 + BOX
		out["zoom"] = Rect2(rx, by, BOX, BOX)
	else:
		rx -= BOX
		out["shade"] = Rect2(rx, by, BOX, BOX)
		out["zoom"] = Rect2()
	var sx0 := left + BOX + 5
	var sx1 := rx - 5
	var avail := maxi(0, sx1 - sx0)
	var cap := mini(caption_w + 12, int(avail * 0.7))
	var stripe_each := maxi(0, (avail - cap - 10) / 2)
	var sy := y + 1 + (TITLE_H - 11) / 2
	out["stripe_l"] = Rect2(sx0, sy, stripe_each, 11)
	out["title_text"] = Rect2(sx0 + stripe_each + 5, y + 1, cap, TITLE_H)
	out["stripe_r"] = Rect2(sx0 + stripe_each + 5 + cap + 5, sy, maxi(0, sx1 - (sx0 + stripe_each + 5 + cap + 5)), 11)
	var bx := x + 1 + BODY_MARGIN
	var bw := w - 2 - BODY_MARGIN * 2
	var top := y + 1 + TITLE_H
	out["info"] = Rect2(bx, top, bw, INFO_H)
	out["content"] = Rect2(bx, top + INFO_H, bw, maxi(0, y + h - 1 - BODY_MARGIN - (top + INFO_H)))
	out["grip"] = Rect2(x + w - GRIP_INSET - GRIP, y + h - GRIP_INSET - GRIP, GRIP, GRIP)
	return out


## Content rect of the Find window (no info bar; the whole body is the form).
static func find_body(r: Rect2) -> Rect2:
	return Rect2(r.position.x + 1, r.position.y + 1 + TITLE_H, r.size.x - 2, maxf(0.0, r.size.y - 2 - TITLE_H))


## Icon-grid layout inside a content rect. entries: [{id, lines: int}] (label line counts, >= 1).
## Returns {cells: [{id, rect, icon, label}], height} with rects relative to the *scrolled* content origin
## (0,0 = top-left of the content rect before scrolling); `height` is the total content height.
static func grid_layout(entries: Array, content_w: int) -> Dictionary:
	var cells := []
	var usable := content_w - GRID_PAD * 2
	var per_row := maxi(1, (usable + CELL_GAP_X) / (CELL_W + CELL_GAP_X))
	var y := GRID_PAD
	var i := 0
	while i < entries.size():
		var row_lines := 1
		for k in range(i, mini(i + per_row, entries.size())):
			row_lines = maxi(row_lines, int(entries[k].get("lines", 1)))
		var cell_h := 2 + ICON + 3 + LABEL_LINE * row_lines + 2
		for k in range(i, mini(i + per_row, entries.size())):
			var cx := GRID_PAD + (k - i) * (CELL_W + CELL_GAP_X)
			var lines := int(entries[k].get("lines", 1))
			cells.append({
				"id": entries[k].id,
				"rect": Rect2(cx, y, CELL_W, cell_h),
				"icon": Rect2(cx + (CELL_W - ICON) / 2, y + 2, ICON, ICON),
				"label": Rect2(cx + 2, y + 2 + ICON + 3, CELL_W - 4, LABEL_LINE * lines),
			})
		y += cell_h + CELL_GAP_Y
		i += per_row
	var total := y - CELL_GAP_Y + GRID_PAD if entries.size() > 0 else GRID_PAD * 2
	return {"cells": cells, "height": total}


## Details (list) layout: column x/width list and rows. Returns {cols: [{x, w}], rows: [{id, rect}], header: Rect2, height, width}.
static func details_layout(entries: Array, content_w: int) -> Dictionary:
	var total_w := maxi(DETAILS_MIN_W, content_w)
	var last := 100
	var rest := total_w - last
	var c1 := maxi(120, rest * 2 / 5)
	var c2 := rest - c1
	var cols := [{"x": 0, "w": c1}, {"x": c1, "w": c2}, {"x": c1 + c2, "w": last}]
	var rows := []
	for i in entries.size():
		rows.append({"id": entries[i].id, "rect": Rect2(0, DETAILS_HEADER_H + i * DETAILS_ROW_H, total_w, DETAILS_ROW_H)})
	return {"cols": cols, "rows": rows, "header": Rect2(0, 0, total_w, DETAILS_HEADER_H), "width": total_w,
		"height": DETAILS_HEADER_H + entries.size() * DETAILS_ROW_H}


## Desktop icons (Launcher HD at the top of the right-hand column, Trash at the bottom).
## Returns [{id, rect (cell), icon, label}] for `count` icons in a desktop of size `desk`.
static func desktop_icons(desk: Vector2, count: int) -> Array:
	var cell_h := 2 + ICON + 3 + LABEL_LINE + 2
	var x := int(desk.x) - DESK_RIGHT - DESK_CELL_W
	var top := DESK_TOP
	var bottom := int(desk.y) - DESK_BOTTOM
	var out := []
	for i in count:
		var y := top
		if count > 1:
			y = top + (bottom - top - cell_h) * i / (count - 1)
		out.append({"rect": Rect2(x, y, DESK_CELL_W, cell_h),
			"icon": Rect2(x + (DESK_CELL_W - ICON) / 2, y + 2, ICON, ICON),
			"label": Rect2(x + 2, y + 2 + ICON + 3, DESK_CELL_W - 4, LABEL_LINE)})
	return out


## Scrollbar geometry for a viewport of `view` px showing `total` px at offset `offset`, track length `track`.
## Returns {thumb_y, thumb_h}; thumb spans the whole track when nothing scrolls.
static func scroll_thumb(view: int, total: int, offset: int, track: int) -> Dictionary:
	if total <= view or track <= 0:
		return {"thumb_y": 0, "thumb_h": track}
	var th := maxi(16, track * view / total)
	var travel := track - th
	var max_off := total - view
	return {"thumb_y": travel * clampi(offset, 0, max_off) / maxi(1, max_off), "thumb_h": th}


static func max_scroll(view: int, total: int) -> int:
	return maxi(0, total - view)


## Default frame for the nth opened window (cascade) inside a desktop of size `desk`.
static func cascade_rect(index: int, desk: Vector2, preferred: Vector2 = Vector2(430, 300)) -> Rect2:
	var w := mini(int(preferred.x), maxi(MIN_W, int(desk.x) - 140))
	var h := mini(int(preferred.y), maxi(MIN_H, int(desk.y) - MENU_H - 24))
	var step := index % 8
	var x := 12 + step * 24
	var y := MENU_H + 10 + step * 20
	x = clampi(x, 0, maxi(0, int(desk.x) - w - 8))
	y = clampi(y, MENU_H, maxi(MENU_H, int(desk.y) - h - 8))
	return Rect2(x, y, w, h)


## Keeps a window title bar reachable: at least 32 px of the title strip visible horizontally and the
## top edge below the menu bar.
static func clamp_position(pos: Vector2, size: Vector2, desk: Vector2) -> Vector2:
	var x := clampf(pos.x, 32.0 - size.x, desk.x - 32.0)
	var y := clampf(pos.y, float(MENU_H), maxf(float(MENU_H), desk.y - TITLE_H))
	return Vector2(x, y)


## Zoomed frame: fills the desktop below the menu bar.
static func zoom_rect(desk: Vector2) -> Rect2:
	return Rect2(0, MENU_H, desk.x, maxf(float(MIN_H), desk.y - MENU_H))
