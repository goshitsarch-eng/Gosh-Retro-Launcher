class_name Win95GroupBox
extends Control
## Win95 group box: etched frame with the caption sitting on the top border (`fieldset`/`legend`).

var label := "":
	set(v):
		label = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## Content origin: children are expected at this offset (fieldset padding 10px 8px 8px).
func content_origin() -> Vector2:
	return Vector2(9, 8 + 7 + 10 - 6)


func _draw() -> void:
	var frame := Rect2(0, 6, size.x - 1, size.y - 7)
	Win95Draw.group_box(self, frame)
	if label != "":
		var tw := Win95Draw.measure(label)
		Win95Draw.fill(self, Rect2(8, 0, tw + 8, 13), Win95Draw.FACE)
		Win95Draw.text(self, Vector2(12, 0), label, Win95Draw.TEXT)
