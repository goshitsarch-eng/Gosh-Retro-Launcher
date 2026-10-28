class_name Win95ListViewState
extends RefCounted
## Pure folder list-view layouts for the four Win95 views. Port of shells/win95/listViewState.ts.
## mode: "large" | "small" | "list" | "details". viewport: {width, height}.
## Returns {items: [{id,x,y,width,height}], contentWidth, contentHeight, columns, rowsPerPage}.

const DEFAULT_REPORT_WIDTHS := {"name": 220, "type": 110, "location": 180}
const REPORT_ROW_HEIGHT := 19
const REPORT_HEADER := 18


static func layout(ids: Array, mode: String, viewport: Dictionary, manual_positions: Dictionary = {}, auto_arrange: bool = true, report_widths: Dictionary = DEFAULT_REPORT_WIDTHS) -> Dictionary:
	var width := maxf(1.0, float(viewport.width))
	var height := maxf(1.0, float(viewport.height))
	if mode == "details":
		var total_width: float = float(report_widths.name) + float(report_widths.type) + float(report_widths.location)
		var items: Array = []
		for index in ids.size():
			items.append({"id": ids[index], "x": 0, "y": REPORT_HEADER + index * REPORT_ROW_HEIGHT, "width": total_width, "height": REPORT_ROW_HEIGHT})
		return {
			"items": items,
			"contentWidth": maxf(width, total_width),
			"contentHeight": maxf(height, REPORT_HEADER + ids.size() * REPORT_ROW_HEIGHT),
			"columns": 1,
			"rowsPerPage": maxi(1, int(floorf((height - REPORT_HEADER) / REPORT_ROW_HEIGHT))),
		}
	if mode == "list":
		var cell_w := 150
		var cell_h := 20
		var rows := maxi(1, int(floorf((height - 8.0) / cell_h)))
		var cols := maxi(1, int(ceilf(float(ids.size()) / rows)))
		var list_items: Array = []
		for index in ids.size():
			list_items.append({"id": ids[index], "x": 4 + (index / rows) * cell_w, "y": 4 + (index % rows) * cell_h, "width": cell_w, "height": cell_h})
		return {
			"items": list_items,
			"contentWidth": maxf(width, 8 + cols * cell_w),
			"contentHeight": height,
			"columns": cols,
			"rowsPerPage": rows,
		}
	var large := mode == "large"
	var cw := 76 if large else 150
	var ch := 68 if large else 20
	var inset_x := 5 if large else 4
	var inset_y := 8 if large else 4
	var columns := maxi(1, int(floorf((width - inset_x * 2.0) / cw)))
	var icon_items: Array = []
	var content_w := width
	var content_h := height
	for index in ids.size():
		var id = ids[index]
		var px: float = inset_x + (index % columns) * cw
		var py: float = inset_y + (index / columns) * ch
		if not auto_arrange and manual_positions.get(id) != null:
			px = float(manual_positions[id].x)
			py = float(manual_positions[id].y)
		icon_items.append({"id": id, "x": px, "y": py, "width": cw, "height": ch})
		content_w = maxf(content_w, px + cw + inset_x)
		content_h = maxf(content_h, py + ch + inset_y)
	return {
		"items": icon_items,
		"contentWidth": content_w,
		"contentHeight": content_h,
		"columns": columns,
		"rowsPerPage": maxi(1, int(floorf((height - inset_y * 2.0) / ch))),
	}


static func resize_report_column(width: float, delta: float, minimum: float = 40.0) -> int:
	return int(maxf(minimum, floorf(width + delta + 0.5)))


## direction: -1 | 1. Returns -1 when empty.
static func page_selection_index(index: int, direction: int, rows_per_page: int, count: int) -> int:
	if count <= 0:
		return -1
	return maxi(0, mini(count - 1, index + direction * maxi(1, rows_per_page)))
