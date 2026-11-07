class_name Win95Geometry
extends RefCounted
## Pure logical-pixel window geometry. Port of shells/win95/geometry.ts.
## Rects are Dictionaries {x, y, width, height}; sizes are {width, height}; the persisted
## window-state dictionaries use the same keys, so they can be passed straight in.

const DEFAULT_MIN := {"width": 160, "height": 100}


static func rect(x: float, y: float, width: float, height: float) -> Dictionary:
	return {"x": x, "y": y, "width": width, "height": height}


static func size(width: float, height: float) -> Dictionary:
	return {"width": width, "height": height}


static func to_rect2(r: Dictionary) -> Rect2:
	return Rect2(float(r.x), float(r.y), float(r.width), float(r.height))


static func from_rect2(r: Rect2) -> Dictionary:
	return rect(r.position.x, r.position.y, r.size.x, r.size.y)


static func constrain_rect(r: Dictionary, area: Dictionary, minimum: Dictionary = DEFAULT_MIN) -> Dictionary:
	var min_w := minf(float(minimum.width), maxf(1.0, float(area.width)))
	var min_h := minf(float(minimum.height), maxf(1.0, float(area.height)))
	var width := maxf(min_w, minf(float(r.width), maxf(min_w, float(area.width))))
	var height := maxf(min_h, minf(float(r.height), maxf(min_h, float(area.height))))
	var x := maxf(0.0, minf(float(r.x), maxf(0.0, float(area.width) - width)))
	var y := maxf(0.0, minf(float(r.y), maxf(0.0, float(area.height) - height)))
	return rect(x, y, width, height)


static func drag_rect(start: Dictionary, dx: float, dy: float, area: Dictionary) -> Dictionary:
	var moved := rect(float(start.x) + dx, float(start.y) + dy, start.width, start.height)
	return constrain_rect(moved, area, size(minf(float(start.width), float(area.width)), minf(float(start.height), float(area.height))))


## Edge chosen while sizing with the keyboard: arrows pick/extend a side. current may be "".
static func keyboard_resize_edge(current: String, key: String) -> String:
	var horizontal := ""
	if key == "ArrowLeft":
		horizontal = "w"
	elif key == "ArrowRight":
		horizontal = "e"
	elif current.contains("w"):
		horizontal = "w"
	elif current.contains("e"):
		horizontal = "e"
	var vertical := ""
	if key == "ArrowUp":
		vertical = "n"
	elif key == "ArrowDown":
		vertical = "s"
	elif current.contains("n"):
		vertical = "n"
	elif current.contains("s"):
		vertical = "s"
	return vertical + horizontal


static func resize_rect(start: Dictionary, edge: String, dx: float, dy: float, area: Dictionary, minimum: Dictionary = DEFAULT_MIN) -> Dictionary:
	var x := float(start.x)
	var y := float(start.y)
	var width := float(start.width)
	var height := float(start.height)
	if edge.contains("e"):
		width += dx
	if edge.contains("s"):
		height += dy
	if edge.contains("w"):
		x += dx
		width -= dx
	if edge.contains("n"):
		y += dy
		height -= dy
	var min_w := minf(float(minimum.width), maxf(1.0, float(area.width)))
	var min_h := minf(float(minimum.height), maxf(1.0, float(area.height)))
	if width < min_w:
		if edge.contains("w"):
			x -= min_w - width
		width = min_w
	if height < min_h:
		if edge.contains("n"):
			y -= min_h - height
		height = min_h
	if x < 0:
		width += x
		x = 0
	if y < 0:
		height += y
		y = 0
	width = minf(width, float(area.width) - x)
	height = minf(height, float(area.height) - y)
	return rect(x, y, maxf(min_w, width), maxf(min_h, height))
