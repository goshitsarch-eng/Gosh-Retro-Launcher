class_name BeGeometry
extends RefCounted
## Pure layout for the Be shell, in logical pixels, derived from the design's CSS (box model of the folder window,
## Deskbar, desktop icon column, view grids, default window placement). No node or autoload access.

const FONT := 15
const FONT_SMALL := 13
const FONT_CLOCK := 14
const LINE := 18                 ## line-height 1.2 at 15px
const DESKBAR_W := 200
const ARRANGE_RESERVE := 212     ## the design's arrange logic subtracts this from the desktop width
const LOGO_H := 46
const CLOCK_ROW_H := 28
const TASK_H := 30
const TAB_H := 26
const MENU_H := 26
const STATUS_H := 20
const GRIP := 16
const MIN_W := 320
const MIN_H := 220
const FIND_MIN_W := 460
const FIND_MIN_H := 280
const DESK_X := 8
const DESK_Y := 14
const DESK_BOTTOM := 8
const DESK_GAP := 14
const DESK_CELL_W := 110
const ICON := 32
const SMALL_ICON := 16
const LARGE_CELL_W := 104
const MENU_ITEM_H := 28
const CTX_ITEM_H := 26
const MENU_SEP_H := 8


# ----------------------------------------------------------- desktop icons

## Height of a large-icon cell: padding 2 + icon 32 + gap 4 + label (lines * 18 + 2) + padding 2.
static func icon_cell_height(label_lines: int) -> int:
	return 2 + ICON + 4 + maxi(1, label_lines) * LINE + 2 + 2


## Column-wrapping layout of the desktop icons (flex column, wrap, gap 14, left 8, top 14, bottom 8).
## `lines` = label line count per icon. Returns Rect2 cells (width 110) in logical px.
static func desktop_cells(lines: Array, view_h: float) -> Array:
	var avail := maxf(1.0, view_h - DESK_Y - DESK_BOTTOM)
	var out := []
	var col := 0
	var y := 0.0
	for n in lines.size():
		var h := float(icon_cell_height(int(lines[n])))
		if y > 0.0 and y + h > avail:
			col += 1
			y = 0.0
		out.append(Rect2(DESK_X + col * (DESK_CELL_W + DESK_GAP), DESK_Y + y, DESK_CELL_W, h))
		y += h + DESK_GAP
	return out


# ----------------------------------------------------------- window frames

## Default window rectangle for key ("computer", "g:<id>", "find") as the n-th opened window.
static func default_rect(key: String, n: int, view: Vector2) -> Rect2:
	var w_area := maxf(view.x, 640.0) - 336.0
	var h_area := maxf(view.y, 480.0) - 34.0
	var w := 0.0
	var h := 0.0
	if key == "find":
		w = maxf(FIND_MIN_W, minf(720.0, w_area - 140.0))
		h = maxf(FIND_MIN_H, minf(500.0, h_area - 40.0))
	elif key == "computer":
		w = maxf(400.0, minf(820.0, w_area - 150.0))
		h = maxf(300.0, minf(520.0, h_area - 48.0))
	else:
		w = maxf(380.0, minf(680.0, w_area - 190.0))
		h = maxf(280.0, minf(420.0, h_area - 90.0))
	var x := 124.0 + maxf(0.0, minf(n * 30.0, w_area - w - 8.0))
	var y := maxf(30.0, minf(40.0 + n * 30.0, h_area - h - 8.0))
	return Rect2(x, y, w, h)


static func clamp_size(key: String, size: Vector2) -> Vector2:
	var min_w := FIND_MIN_W if key == "find" else MIN_W
	var min_h := FIND_MIN_H if key == "find" else MIN_H
	return Vector2(maxf(min_w, size.x), maxf(min_h, size.y))


## Keeps the tab reachable: top >= 0, and at least 40 px of the tab on screen horizontally.
static func clamp_position(pos: Vector2, size: Vector2, view: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 40.0 - size.x, maxf(40.0 - size.x, view.x - 40.0)), maxf(0.0, pos.y))


## Tab width: borders 2 + padding + close (15) + gaps (10) + bold title [+ gap 10 + zoom 15]; at most window width - 24.
static func tab_width(title_w: float, win_w: float, with_zoom: bool = true) -> float:
	var w := title_w + (64.0 if with_zoom else 43.0)
	return minf(w, win_w - 24.0)


## All parts of a folder window whose outer rect (tab + body) is `r`.
## Keys: tab, close, zoom, title, body, menu, content, status, grip.
static func folder_parts(r: Rect2, title_w: float) -> Dictionary:
	var tw := tab_width(title_w, r.size.x)
	var tab := Rect2(r.position.x, r.position.y + 1, tw, TAB_H)
	var body := Rect2(r.position.x, r.position.y + TAB_H, r.size.x, maxf(0.0, r.size.y - TAB_H))
	var menu := Rect2(body.position.x + 5, body.position.y + 5, maxf(0.0, body.size.x - 10), MENU_H)
	var status := Rect2(body.position.x + 5, body.end.y - 5 - STATUS_H, maxf(0.0, body.size.x - 10), STATUS_H)
	var top := menu.end.y + 4
	var content := Rect2(menu.position.x, top, menu.size.x, maxf(0.0, status.position.y - 4 - top))
	return {
		"tab": tab,
		"close": Rect2(tab.position.x + 7, tab.position.y + 5, 15, 15),
		"zoom": Rect2(tab.end.x - 7 - 15, tab.position.y + 5, 15, 15),
		"title": Rect2(tab.position.x + 7 + 15 + 10, tab.position.y, maxf(0.0, tw - 7 - 15 - 10 - 10 - 15 - 7), TAB_H),
		"body": body, "menu": menu, "content": content, "status": status,
		"grip": Rect2(status.end.x - GRIP, status.position.y + 2, GRIP, GRIP),
	}


## Find window: tab (close only) + body with padding 14.
static func find_parts(r: Rect2, title_w: float) -> Dictionary:
	var tab := Rect2(r.position.x, r.position.y + 1, tab_width(title_w, r.size.x, false), TAB_H)
	var body := Rect2(r.position.x, r.position.y + TAB_H, r.size.x, maxf(0.0, r.size.y - TAB_H))
	return {
		"tab": tab, "close": Rect2(tab.position.x + 7, tab.position.y + 5, 15, 15),
		"body": body, "inner": body.grow(-15),
		"grip": Rect2(body.end.x - 15 - GRIP, body.end.y - 15 - GRIP, GRIP, GRIP),
	}


# ----------------------------------------------------------- folder views

## Large-icon grid: cells 104 wide, gaps 14 (rows) / 8 (cols), padding 8. `lines` = label lines per entry.
## Returns {rects: Array[Rect2] relative to the scroll origin, height: float}.
static func large_cells(lines: Array, inner_w: float) -> Dictionary:
	var avail := maxf(LARGE_CELL_W, inner_w - 16.0)
	var per_row := maxi(1, int(floorf((avail + 8.0) / (LARGE_CELL_W + 8.0))))
	var rects := []
	var y := 8.0
	var i := 0
	while i < lines.size():
		var row_h := 0.0
		for j in range(i, mini(i + per_row, lines.size())):
			row_h = maxf(row_h, float(icon_cell_height(int(lines[j]))))
		for j in range(i, mini(i + per_row, lines.size())):
			rects.append(Rect2(8 + (j - i) * (LARGE_CELL_W + 8), y, LARGE_CELL_W, float(icon_cell_height(int(lines[j])))))
		y += row_h + 14.0
		i += per_row
	return {"rects": rects, "height": (y - 14.0 + 8.0) if lines.size() > 0 else 16.0}


## Small-icon grid: auto-fill columns of at least 190 px, gaps 4 / 12, padding 8, rows 24 px.
static func small_cells(count: int, inner_w: float) -> Dictionary:
	var avail := maxf(190.0, inner_w - 16.0)
	var cols := maxi(1, int(floorf((avail + 12.0) / (190.0 + 12.0))))
	var col_w := (avail - (cols - 1) * 12.0) / cols
	var rects := []
	for i in count:
		rects.append(Rect2(8 + (i % cols) * (col_w + 12.0), 8 + (i / cols) * 28.0, col_w, 24))
	var rows := int(ceilf(float(count) / cols))
	return {"rects": rects, "height": 16.0 + (rows * 28.0 - 4.0 if rows > 0 else 0.0)}


const DETAILS_MIN_W := 520
const DETAILS_HEAD_H := 27
const DETAILS_ROW_H := 24


## Details columns [x0, w0, x1, w1, x2, w2] for a view `w` wide (min 520): 2fr / 3fr / 110px, each >= 180 / 200.
static func details_columns(w: float) -> Array:
	var total := maxf(w, DETAILS_MIN_W)
	var free := total - 110.0
	var c0 := maxf(180.0, free * 2.0 / 5.0)
	var c1 := maxf(200.0, free - c0)
	if c0 + c1 > free:
		c0 = maxf(180.0, free - c1)
	return [0.0, c0, c0, c1, c0 + c1, total - c0 - c1]


# ----------------------------------------------------------- Deskbar

## Deskbar rect parts for `task_count` running windows; height is content-sized.
static func deskbar_parts(task_count: int, view_w: float) -> Dictionary:
	var x := view_w - DESKBAR_W
	var logo := Rect2(x, 0, DESKBAR_W, LOGO_H)
	var clock := Rect2(x + 4, LOGO_H + 4, DESKBAR_W - 8, CLOCK_ROW_H)
	var tasks_top := clock.end.y + 4
	var tasks := []
	for i in task_count:
		tasks.append(Rect2(x, tasks_top + i * TASK_H, DESKBAR_W, TASK_H))
	var h := tasks_top + task_count * TASK_H + 2.0
	return {"rect": Rect2(x, 0, DESKBAR_W, h), "logo": logo, "clock": clock, "tools": Rect2(clock.position.x + 10, clock.position.y + 6, 16, 16), "tasks": tasks}


# ----------------------------------------------------------- menus

## Size of a popup menu for `items` ({sep:true} or label items). Width from widest label (given in px).
static func menu_size(items: Array, widest: float, item_h: int, min_w: float, left_pad: float, right_pad: float = 16.0) -> Vector2:
	var h := 6.0
	for it in items:
		h += MENU_SEP_H if bool(it.get("sep", false)) else float(item_h)
	return Vector2(maxf(min_w, widest + left_pad + right_pad + 2.0), h + 2.0)


## Keeps a popup of `size` on screen, preferring `at`.
static func fit_popup(at: Vector2, size: Vector2, view: Vector2) -> Vector2:
	return Vector2(maxf(0.0, minf(at.x, view.x - size.x)), maxf(0.0, minf(at.y, view.y - size.y - 4.0)))
