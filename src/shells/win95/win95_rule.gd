class_name Win95Rule
extends Control
## Etched horizontal rule (shadow line over a light line), width = size.x.


static func make(pos: Vector2, width: float) -> Win95Rule:
	var r := Win95Rule.new()
	r.position = pos
	r.size = Vector2(width, 2)
	return r


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	Win95Draw.fill(self, Rect2(0, 0, size.x, 1), Win95Draw.SHADOW)
	Win95Draw.fill(self, Rect2(0, 1, size.x, 1), Win95Draw.LIGHT)
