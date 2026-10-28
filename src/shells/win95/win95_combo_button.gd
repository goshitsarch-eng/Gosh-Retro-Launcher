class_name Win95ComboButton
extends Control
## The 16x17 drop-down arrow button of a Win95 combo box (Run's "Open" field). Signal pressed.

signal pressed

var _down := false


func _init() -> void:
	size = Vector2(16, 17)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Win95Draw.fill(self, r, Win95Draw.FACE)
	if _down:
		Win95Draw.border(self, r, 1, Win95Draw.DARK, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.DARK)
		Win95Draw.inset_shadow(self, r.grow(-1), 1, 1, Win95Draw.SHADOW)
	else:
		Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
		Win95Draw.inset_shadow(self, r.grow(-1), -1, -1, Win95Draw.SHADOW)
	Win95Draw.glyph(self, "combo-down", Vector2(1, 2) + (Vector2(1, 1) if _down else Vector2.ZERO), Win95Draw.DARK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		else:
			var was := _down
			_down = false
			if was and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		queue_redraw()
		accept_event()
