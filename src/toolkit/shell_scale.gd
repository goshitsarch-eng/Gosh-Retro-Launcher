class_name ShellScale
extends RefCounted
## Whole-shell integer scaling. Port of resolve*AutoScale / logicalViewportSize / pointer
## conversion from shells/win95/tokens.ts and shells/win31/tokens.ts.

const REFERENCE_WIDTH := 640
const REFERENCE_HEIGHT := 480
const FACTORS := [1, 2, 3, 4]


## Largest integer 640x480 canvas that fits, clamped to 1..4.
static func resolve_auto(width: float, height: float) -> int:
	var w := maxf(0.0, width) if is_finite(width) else 0.0
	var h := maxf(0.0, height) if is_finite(height) else 0.0
	var fit := int(floorf(minf(w / REFERENCE_WIDTH, h / REFERENCE_HEIGHT)))
	return clampi(fit, 1, 4)


## Logical viewport without fractional layout pixels (ceil).
static func logical_viewport_size(physical_w: float, physical_h: float, scale: float) -> Vector2i:
	return Vector2i(maxi(1, int(ceilf(physical_w / scale))), maxi(1, int(ceilf(physical_h / scale))))


static func to_logical_delta(physical_delta: float, scale: float) -> float:
	return physical_delta / scale


static func to_logical_point(px: Vector2, scale: float, origin: Vector2 = Vector2.ZERO) -> Vector2:
	return (px - origin) / scale


## Atlas variant (1-4) for a given scale and display ratio; kept for parity with the web build.
static func raster_variant(scale: float, dpr: float, maximum: int = 4) -> int:
	var d := maxf(1.0, dpr) if is_finite(dpr) else 1.0
	return clampi(int(ceilf(scale * d)), 1, maximum)


## Physical device-pixels-per-DIP of the screen the window is on (1.0 when unknown).
static func display_ratio(window: Window = null) -> float:
	var screen := DisplayServer.window_get_current_screen(window.get_window_id()) if window else DisplayServer.get_primary_screen()
	var s := DisplayServer.screen_get_scale(screen)
	return s if s > 0.0 else 1.0


## Resolves an Auto/1-4 preference to a whole-UI factor in DIPs given the work area in DIPs.
static func resolve_preference(preference: Variant, work_w: float, work_h: float) -> int:
	if Types.is_scale_factor(preference):
		return int(preference)
	return resolve_auto(work_w, work_h)


## Applies logical scale `factor_dips` (x display ratio) to the window's content.
static func apply(window: Window, factor_dips: float) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = maxf(1.0, factor_dips * display_ratio(window))


## Logical size of the content area (window pixels divided by the content scale factor).
static func logical_size(window: Window) -> Vector2:
	return Vector2(window.size) / window.content_scale_factor
