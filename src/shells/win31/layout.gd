class_name Win31Layout
extends RefCounted
## Port of shells/win31/layout.ts.


## Fill the whole MDI client with balanced rows/columns; a short last row expands.
## Returns Array[Rect2].
static func calculate_tile_layout(count: int, width: float, height: float) -> Array:
	var out := []
	if count <= 0:
		return out
	var rows := maxi(1, int(roundf(sqrt(float(count)))))
	var base := count / rows
	var fuller := count % rows
	for row in rows:
		var in_row := base + (1 if row < fuller else 0)
		var top := int(floorf(row * height / rows))
		var bottom := int(floorf((row + 1) * height / rows))
		for col in in_row:
			var left := int(floorf(col * width / in_row))
			var right := int(floorf((col + 1) * width / in_row))
			out.append(Rect2(left, top, right - left, bottom - top))
	return out
