class_name Win95ScrollbarState
extends RefCounted
## Pure scrollbar math. Port of shells/win95/scrollbarState.ts.
## Metrics: {trackLength, thumbLength, thumbOffset, maxScroll}.


static func js_round(v: float) -> int:
	return int(floorf(v + 0.5))


static func clamp_scroll(value: float, content_size: float, viewport_size: float) -> int:
	return maxi(0, mini(int(maxf(0.0, content_size - viewport_size)), js_round(value)))


static func thumb_metrics(viewport_size: float, content_size: float, track_length: float, minimum_thumb: float = 8.0) -> Dictionary:
	var safe_track := maxf(0.0, track_length)
	var max_scroll := maxf(0.0, content_size - viewport_size)
	if max_scroll == 0.0 or content_size <= 0.0:
		return {"trackLength": safe_track, "thumbLength": safe_track, "thumbOffset": 0, "maxScroll": max_scroll}
	var thumb_length := maxf(minimum_thumb, minf(safe_track, floorf(safe_track * viewport_size / content_size)))
	return {"trackLength": safe_track, "thumbLength": thumb_length, "thumbOffset": 0, "maxScroll": max_scroll}


static func thumb_offset(value: float, metrics: Dictionary) -> int:
	if float(metrics.maxScroll) == 0.0 or float(metrics.trackLength) <= float(metrics.thumbLength):
		return 0
	return js_round(float(clamp_scroll(value, metrics.maxScroll, 0.0)) / float(metrics.maxScroll) * (float(metrics.trackLength) - float(metrics.thumbLength)))


static func scroll_from_thumb(offset: float, metrics: Dictionary) -> int:
	var available := float(metrics.trackLength) - float(metrics.thumbLength)
	if available <= 0.0 or float(metrics.maxScroll) <= 0.0:
		return 0
	return js_round(maxf(0.0, minf(available, offset)) / available * float(metrics.maxScroll))


## direction: -1 | 1
static func scroll_step(value: float, direction: int, line_size: float, content_size: float, viewport_size: float) -> int:
	return clamp_scroll(value + direction * line_size, content_size, viewport_size)


static func scroll_page(value: float, direction: int, content_size: float, viewport_size: float) -> int:
	return clamp_scroll(value + direction * maxf(1.0, viewport_size - 16.0), content_size, viewport_size)
