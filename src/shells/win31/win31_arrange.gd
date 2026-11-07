class_name Win31Arrange
extends RefCounted
## Window arrangement and geometry math of the MDI client. Port of the cascade/tile/arrangeIcons
## effects in Win31MDIContainer.tsx and the drag/resize clamps in Win31MDIWindow.tsx.
## `client` is the MDI client's border-box size (the TS clientSize). Rects are Rect2 with
## integer components; positions are Vector2i.

const CASCADE_OFFSET := 22
const MIN_WIDTH := 150
const MIN_HEIGHT := 92
const CAPTION_KEEP_VISIBLE := 24
const GROUP_CELL_W := 75
const GROUP_CELL_H := 58


## JS Math.round (ties toward +infinity).
static func js_round(v: float) -> int:
	return int(floorf(v + 0.5))


static func icon_columns(client_w: float) -> int:
	return maxi(1, int(floorf(client_w / GROUP_CELL_W)))


## Pixels at the bottom of the client reserved for minimized group icons.
static func reserved_bottom(minimized_count: int, client_w: float) -> int:
	if minimized_count <= 0:
		return 0
	var cols := icon_columns(client_w)
	var rows := int(ceilf(float(minimized_count) / cols))
	return rows * GROUP_CELL_H + 8


## Rect2 per restorable window (z/array order), the Cascade command.
static func cascade(count: int, client_w: float, client_h: float, reserved: int) -> Array:
	var out := []
	if count <= 0:
		return out
	var available := maxf(MIN_HEIGHT, client_h - reserved)
	var steps := maxi(1, count - 1)
	var width := maxf(MIN_WIDTH, client_w - CASCADE_OFFSET * steps)
	var height := maxf(MIN_HEIGHT, available - CASCADE_OFFSET * steps)
	for i in count:
		out.append(Rect2(i * CASCADE_OFFSET, i * CASCADE_OFFSET, width, height))
	return out


## Rect2 per restorable window, the Tile command (balanced rows/columns filling the client).
static func tile(count: int, client_w: float, client_h: float, reserved: int) -> Array:
	if count <= 0:
		return []
	var available := maxf(MIN_HEIGHT, client_h - reserved)
	return Win31Layout.calculate_tile_layout(count, client_w, available)


## Arrange Icons: packs minimized group icons along the bottom, rows growing upward.
static func arrange_icons(count: int, client_w: float, client_h: float) -> Array:
	var out := []
	var cols := icon_columns(client_w)
	for i in count:
		out.append(icon_fallback_position(i, cols, client_h))
	return out


static func icon_fallback_position(index: int, cols: int, client_h: float) -> Vector2i:
	var row_from_bottom := index / cols
	var col := index % cols
	return Vector2i(col * GROUP_CELL_W, int(maxf(0.0, client_h - (row_from_bottom + 1) * GROUP_CELL_H - 8)))


static func clamp_icon_position(pos: Vector2, client_w: float, client_h: float) -> Vector2i:
	return Vector2i(
		int(maxf(0.0, minf(client_w - GROUP_CELL_W, pos.x))),
		int(maxf(0.0, minf(client_h - GROUP_CELL_H, pos.y))))


## Dragging a minimized group icon (rounded, clamped).
static func icon_drag_position(origin: Vector2, delta: Vector2, client_w: float, client_h: float) -> Vector2i:
	return Vector2i(
		js_round(maxf(0.0, minf(client_w - GROUP_CELL_W, origin.x + delta.x))),
		js_round(maxf(0.0, minf(client_h - GROUP_CELL_H, origin.y + delta.y))))


## On-screen rect of a window: maximized fills the client, otherwise clamped into it.
static func window_rect(state: Dictionary, client_w: float, client_h: float) -> Rect2:
	if state.get("maximized", false):
		return Rect2(0, 0, client_w, client_h)
	return Rect2(
		maxf(0.0, minf(float(state.x), client_w - 40.0)),
		maxf(0.0, minf(float(state.y), client_h - CAPTION_KEEP_VISIBLE)),
		minf(float(state.width), client_w),
		minf(float(state.height), client_h))


## Caption drag: new window position for a pointer delta (clamped, rounded).
static func drag_position(state: Dictionary, delta: Vector2, client_w: float, client_h: float) -> Vector2i:
	return Vector2i(
		js_round(maxf(0.0, minf(client_w - float(state.width), float(state.x) + delta.x))),
		js_round(maxf(0.0, minf(client_h - CAPTION_KEEP_VISIBLE, float(state.y) + delta.y))))


## Edge/corner resize. `direction` is any of n,e,s,w,ne,nw,se,sw. Returns {x,y,width,height}.
static func resize_rect(direction: String, state: Dictionary, delta: Vector2, client_w: float, client_h: float) -> Dictionary:
	var x := float(state.x)
	var y := float(state.y)
	var width := float(state.width)
	var height := float(state.height)
	if direction.contains("e"):
		width = maxf(MIN_WIDTH, minf(client_w - x, float(state.width) + delta.x))
	if direction.contains("s"):
		height = maxf(MIN_HEIGHT, minf(client_h - y, float(state.height) + delta.y))
	if direction.contains("w"):
		x = maxf(0.0, minf(float(state.x) + float(state.width) - MIN_WIDTH, float(state.x) + delta.x))
		width = float(state.width) + (float(state.x) - x)
	if direction.contains("n"):
		y = maxf(0.0, minf(float(state.y) + float(state.height) - MIN_HEIGHT, float(state.y) + delta.y))
		height = float(state.height) + (float(state.y) - y)
	return {"x": js_round(x), "y": js_round(y), "width": js_round(width), "height": js_round(height)}


## Topmost window under `point` (client coordinates). `entries` is z-ordered bottom -> top:
## [{groupId, rect: Rect2}]. Returns the group id or "".
static func window_at(entries: Array, point: Vector2) -> String:
	for i in range(entries.size() - 1, -1, -1):
		if Rect2(entries[i].rect).has_point(point):
			return String(entries[i].groupId)
	return ""


## Drop target for a dragged program item / OS file at `point`: minimized group icons sit above
## windows (z-index 10000), then the topmost window. `icon_entries` is [{groupId, rect}].
static func drop_target(window_entries: Array, icon_entries: Array, point: Vector2) -> String:
	for e in icon_entries:
		if Rect2(e.rect).has_point(point):
			return String(e.groupId)
	return window_at(window_entries, point)


## Resize handle (edge/corner) hit zone of a restored window, in window-local coordinates.
## Mirrors .wfw-resize-handle (edges 4px thick inset 5px, corners 7x7, offset by the 1px border).
## Corners are tested first because they are later siblings with the same z-index.
static func resize_zone(local: Vector2, w: float, h: float) -> String:
	var zones := [
		["sw", Rect2(1, h - 1 - 7, 7, 7)],
		["se", Rect2(w - 1 - 7, h - 1 - 7, 7, 7)],
		["nw", Rect2(1, 1, 7, 7)],
		["ne", Rect2(w - 1 - 7, 1, 7, 7)],
		["w", Rect2(1, 1 + 5, 4, h - 2 - 10)],
		["s", Rect2(1 + 5, h - 1 - 4, w - 2 - 10, 4)],
		["e", Rect2(w - 1 - 4, 1 + 5, 4, h - 2 - 10)],
		["n", Rect2(1 + 5, 1, w - 2 - 10, 4)],
	]
	for z in zones:
		if Rect2(z[1]).has_point(local):
			return z[0]
	return ""
