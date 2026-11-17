class_name Win95ProgressBar
extends Control
## The Windows 95 progress bar (comctl32 "msctls_progress32"): a 1px static edge (shadow top/left,
## white bottom/right) round the face colour, filled from the left with separate navy blocks
## (block width = 2/3 of the inner height, 2px apart). Block count: Win95LaunchGroupLogic.progress_blocks.

const GAP := 2

var done := 0
var total := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = Vector2(200, 16)


func set_progress(p_done: int, p_total: int) -> void:
	if p_done == done and p_total == total:
		return
	done = p_done
	total = p_total
	queue_redraw()


## Width of one block for a bar `height` px tall (inner height minus the 1px margins, times 2/3).
static func block_width(height: int) -> int:
	return maxi(2, (height - 4) * 2 / 3)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size.floor())
	Win95Draw.fill(self, r, Win95Draw.FACE)
	Win95Draw.status(self, r)
	var inner_w := int(r.size.x) - 4
	var h := int(r.size.y) - 4
	var bw := block_width(int(r.size.y))
	var n := Win95LaunchGroupLogic.progress_blocks(done, total, inner_w, bw, GAP)
	for i in n:
		var x := 2 + i * (bw + GAP)
		Win95Draw.fill(self, Rect2(x, 2, mini(bw, inner_w + 2 - x), h), Win95Draw.SELECTED)
