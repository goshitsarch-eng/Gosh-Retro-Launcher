class_name MacButton
extends Control
## Classic rounded push button. Default buttons carry the double ring. Emits `pressed` on release inside.

signal pressed

var label := "OK":
	set(v):
		label = v
		queue_redraw()
var is_default := false:
	set(v):
		is_default = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		queue_redraw()
var _down := false


func _init(p_label: String = "OK", min_w: int = 60) -> void:
	label = p_label
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	size = Vector2(maxi(min_w, MacDraw.measure(p_label) + 24), 20)
	custom_minimum_size = size
	add_to_group("pm_auto")
	set_meta("auto_id", "mac.dialog.button:" + p_label)


func _draw() -> void:
	MacDraw.button(self, Rect2(Vector2.ZERO, size), label, is_default, _down, disabled)
	if has_focus():
		Px.focus_rect(self, Rect2(Vector2.ZERO, size).grow(-4), MacTheme.t("444444"))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		accept_event()
		pressed.emit()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			queue_redraw()
		else:
			var inside := Rect2(Vector2.ZERO, size).has_point(mb.position)
			var fire := _down and inside
			_down = false
			queue_redraw()
			if fire:
				pressed.emit()
		accept_event()
