class_name Win95Checkbox
extends Control
## Win95 checkbox (13x13 sunken box + label). Signal toggled(checked).

signal toggled(checked: bool)

var label := "":
	set(v):
		label = v
		_fit()
var checked := false:
	set(v):
		checked = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _fit() -> void:
	size = Vector2(13 + 4 + Win95Draw.measure(label), 13)
	custom_minimum_size = size
	queue_redraw()


func access_key() -> String:
	return String(RetroFont.parse_access(label).accessKey)


func click() -> void:
	if disabled:
		return
	checked = not checked
	toggled.emit(checked)


func _draw() -> void:
	var box := Rect2(0, 0, 13, 13)
	Win95Draw.fill(self, box, Win95Draw.FACE if disabled else Win95Draw.WINDOW)
	Win95Draw.border(self, box, 2, Win95Draw.SHADOW, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.SHADOW)
	Win95Draw.inset_shadow(self, box.grow(-2), 1, 1, Win95Draw.DARK)
	if checked:
		Win95Draw.glyph(self, "menu-check", Vector2(1, 1), Win95Draw.DISABLED if disabled else Win95Draw.DARK)
	Win95Draw.text(self, Vector2(17, 0), label, Win95Draw.TEXT, {"disabled": disabled})
	if has_focus():
		Win95Draw.dotted_rect(self, Rect2(15, -1, size.x - 15 + 2, 15), Win95Draw.TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
		else:
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				click()
		accept_event()
