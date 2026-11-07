class_name Win95ShellInput
extends RefCounted
## Pure shell-input logic: accelerator routing, menu placement/columns/corridor and the
## press-drag-release menu tracking reducer. Port of shells/win95/shellInput.ts.
## Events are DOM-style Dictionaries: {key, code?, ctrlKey?, altKey?, shiftKey?, metaKey?}.

const LAYERS := ["modal", "menu", "window", "desktop"]


static func js_round(v: float) -> int:
	return int(floorf(v + 0.5))


## Returns "toggle-start" | "open-run" | "open-find" | "open-explorer" | "cycle-window" |
## "cycle-window-reverse" | "system-menu" | "close-window" | "context-menu" | "" (none).
## Bare Meta/Alt are resolved on key-up by the controller.
static func route_shortcut(event: Dictionary) -> String:
	var key := String(event.get("key", "")).to_lower()
	var ctrl: bool = event.get("ctrlKey", false)
	var alt: bool = event.get("altKey", false)
	var shift: bool = event.get("shiftKey", false)
	var meta: bool = event.get("metaKey", false)
	if ctrl and not alt and key == "escape":
		return "toggle-start"
	if meta:
		if key == "r":
			return "open-run"
		if key == "f":
			return "open-find"
		if key == "e":
			return "open-explorer"
		if key == "tab":
			return "cycle-window-reverse" if shift else "cycle-window"
	if alt:
		if key == "tab":
			return "cycle-window-reverse" if shift else "cycle-window"
		if key == " ":
			return "system-menu"
		if key == "f4":
			return "close-window"
	if key == "contextmenu" or (shift and key == "f10"):
		return "context-menu"
	return ""


## anchor/menu/viewport: {x,y,width,height} / {width,height}. kind: "below" | "cascade".
static func place_menu(anchor: Dictionary, menu: Dictionary, viewport: Dictionary, kind: String = "cascade") -> Dictionary:
	var below := kind == "below"
	var x: float = float(anchor.x) if below else float(anchor.x) + float(anchor.width) - 1.0
	var y: float = (float(anchor.y) + float(anchor.height) - 1.0) if below else float(anchor.y)
	var flipped_x := false
	var flipped_y := false
	if x + float(menu.width) > float(viewport.width):
		x = maxf(0.0, float(viewport.width) - float(menu.width)) if below else float(anchor.x) - float(menu.width) + 1.0
		flipped_x = true
	if y + float(menu.height) > float(viewport.height):
		y = (float(anchor.y) - float(menu.height) + 1.0) if below else float(viewport.height) - float(menu.height)
		flipped_y = true
	return {
		"x": maxi(0, js_round(x)),
		"y": maxi(0, js_round(y)),
		"flippedX": flipped_x,
		"flippedY": flipped_y,
	}


## Splits rows into columns of indices so a column never exceeds available_height.
static func menu_column_layout(row_heights: Array, available_height: float) -> Array:
	var columns: Array = [[]]
	var used := 0.0
	for index in row_heights.size():
		var height := maxf(1.0, float(row_heights[index]))
		var last: Array = columns[columns.size() - 1]
		if last.size() > 0 and used + height > available_height:
			columns.append([])
			used = 0.0
			last = columns[columns.size() - 1]
		last.append(index)
		used += height
	return columns


static func _triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
	return absf((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2.0)


## True while the pointer stays inside the parent-origin -> child-edge corridor triangle.
## origin/point: {x,y}; child_edge: {x, top, bottom}.
static func is_point_in_menu_corridor(origin: Dictionary, point: Dictionary, child_edge: Dictionary) -> bool:
	var a := Vector2(origin.x, origin.y)
	var b := Vector2(child_edge.x, child_edge.top)
	var c := Vector2(child_edge.x, child_edge.bottom)
	var p := Vector2(point.x, point.y)
	var total := _triangle_area(a, b, c)
	var parts := _triangle_area(p, b, c) + _triangle_area(a, p, c) + _triangle_area(a, b, p)
	return absf(total - parts) < 0.5


static func closed_tracking() -> Dictionary:
	return {"open": false, "mode": "closed", "path": []}


## Tracking reducer. state: {open, mode: closed|tracking|latched, path: Array[int]}.
## action: {type: open|hover|release|close-level|close-all, index?, tracking?, level?, hasChild?}
static func reduce_menu_tracking(state: Dictionary, action: Dictionary) -> Dictionary:
	var type: String = action.type
	if type == "open":
		return {
			"open": true,
			"mode": "tracking" if action.get("tracking", false) else "latched",
			"path": [int(action.get("index", 0))],
		}
	if type == "hover":
		var path: Array = state.path.slice(0, int(action.level))
		while path.size() < int(action.level):
			path.append(null)
		if path.size() == int(action.level):
			path.append(int(action.index))
		else:
			path[int(action.level)] = int(action.index)
		var out: Dictionary = state.duplicate(true)
		out["path"] = path
		return out
	if type == "release":
		if action.get("hasChild", false):
			var latched: Dictionary = state.duplicate(true)
			latched["mode"] = "latched"
			return latched
		return closed_tracking()
	if type == "close-level":
		if state.path.size() <= 1:
			return closed_tracking()
		var out2: Dictionary = state.duplicate(true)
		out2["mode"] = "latched"
		out2["path"] = state.path.slice(0, state.path.size() - 1)
		return out2
	return closed_tracking()
