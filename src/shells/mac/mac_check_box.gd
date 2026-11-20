class_name MacCheckBox
extends Control
## Check box with label (13x13 gradient box + check).

signal toggled(on: bool)

var label := ""
var checked := false:
	set(v):
		checked = v
		queue_redraw()


func _init(p_label: String = "", p_checked: bool = false) -> void:
	label = p_label
	checked = p_checked
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	size = Vector2(MacDraw.measure(p_label) + 21, 16)
	add_to_group("pm_auto")
	set_meta("auto_id", "mac.dialog.check:" + p_label)


func _draw() -> void:
	MacDraw.checkbox(self, Rect2(0, 1, 13, 13), checked)
	MacDraw.text_centered_y(self, 21, 0, size.y, label, MacTheme.t("000000"))
	if has_focus():
		Px.focus_rect(self, Rect2(Vector2.ZERO, size), MacTheme.t("444444"))


func _gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var key: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	if click or key:
		checked = not checked
		toggled.emit(checked)
		accept_event()
