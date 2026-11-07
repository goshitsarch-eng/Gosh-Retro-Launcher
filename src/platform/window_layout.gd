class_name WindowLayout
extends RefCounted
## Pure window-geometry helpers (ports of createWindow() in src/main/window.ts and the bounds
## validation of windowHandlers.ts). All sizes are in DIPs unless stated otherwise; the app host
## multiplies by the display ratio when talking to DisplayServer (physical pixels).

const MIN_WIDTH := 400
const MIN_HEIGHT := 300
const DEFAULT_WIDTH := 800
const DEFAULT_HEIGHT := 600


## Scale used for the initial window size: the shell's preference, or the auto scale of the work area.
static func initial_scale(shell: String, settings: Dictionary, work_w: float, work_h: float) -> int:
	var key := "win95Scale" if shell == "win95" else "win31Scale"
	var pref: Variant = settings.get(key, "auto")
	if Types.is_scale_factor(pref):
		return int(pref)
	return ShellScale.resolve_auto(work_w, work_h)


## Initial content size in DIPs: min(work area, 640x480 * scale) for both shells (`useContentSize`
## for Win95, frameless outer == content for Win31). Unknown shells get 800x600.
static func initial_size(shell: String, settings: Dictionary, work_w: float, work_h: float) -> Vector2i:
	if shell != "win31" and shell != "win95":
		return Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)
	var scale := initial_scale(shell, settings, work_w, work_h)
	return Vector2i(
		int(minf(work_w, float(ShellScale.REFERENCE_WIDTH * scale))),
		int(minf(work_h, float(ShellScale.REFERENCE_HEIGHT * scale))))


## Desktop colour behind the shell (BrowserWindow.backgroundColor): #c0c0c0 for Win31, #008080 else.
static func background_color(shell: String) -> Color:
	return Color8(0xc0, 0xc0, 0xc0) if shell == "win31" else Color8(0x00, 0x80, 0x80)


static func window_title(shell: String) -> String:
	return "Gosh 95" if shell == "win95" else "Program Manager"


## Port of isHostWindowBounds: finite numbers and at least the minimum size.
static func is_valid_bounds(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for k in ["x", "y", "width", "height"]:
		if not Jsonx.is_num(value.get(k)) or not is_finite(float(value[k])):
			return false
	return float(value.width) >= MIN_WIDTH and float(value.height) >= MIN_HEIGHT


## Top-left that centres an outer window of `outer_size` in `usable` (clamped to its origin).
static func centered_position(usable: Rect2i, outer_size: Vector2i) -> Vector2i:
	return Vector2i(
		usable.position.x + maxi(0, (usable.size.x - outer_size.x) / 2),
		usable.position.y + maxi(0, (usable.size.y - outer_size.y) / 2))


## Client rect that makes the window's outer rect equal `outer`, given decoration insets
## (top-left offset of the client area inside the frame and the total frame size added to the client).
static func client_rect_for_outer(outer: Rect2i, deco_origin: Vector2i, deco_size: Vector2i) -> Rect2i:
	return Rect2i(outer.position + deco_origin, Vector2i(maxi(1, outer.size.x - deco_size.x), maxi(1, outer.size.y - deco_size.y)))
