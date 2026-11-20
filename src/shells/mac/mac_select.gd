class_name MacSelect
extends Control
## Pop-up menu button (the design's <select>): rounded face with a triangle; click opens a MacPopupMenu.

signal selected(index: int)

const LABEL_X := 8          ## where MacDraw.select_face starts the label

var options: Array = []     ## [{id, label}]
var selected_index := 0:
	set(v):
		selected_index = v
		queue_redraw()
var host: Control           ## overlay layer that receives the pop-up


func _init(p_auto_id: String = "") -> void:
	size = Vector2(150, 22)
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	add_to_group("pm_auto")
	if p_auto_id != "":
		set_meta("auto_id", p_auto_id)


func current_id() -> String:
	return String(options[selected_index].id) if selected_index >= 0 and selected_index < options.size() else ""


func select_id(id: String) -> void:
	for i in options.size():
		if String(options[i].id) == id:
			selected_index = i


func _draw() -> void:
	var label := String(options[selected_index].label) if selected_index >= 0 and selected_index < options.size() else ""
	MacDraw.select_face(self, Rect2(Vector2.ZERO, size - Vector2(0, 1)), label)
	if has_focus():
		Px.focus_rect(self, Rect2(Vector2.ZERO, size).grow(-4), MacTheme.t("444444"))


func _gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var key: bool = event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]
	if host != null and (click or key):
		var items := []
		for i in options.size():
			items.append(MacMenuModel.item("opt:%d" % i, String(options[i].label), {"check": i == selected_index}))
		# Over the button with the current item under the pointer (the face is drawn 1px short of the control).
		var inset := 1 + MacPopupMenu.PAD_L - LABEL_X
		var at := MacGeometry.select_popup_origin(Rect2(global_position, size - Vector2(0, 1)), selected_index, MacPopupMenu.ROW_H,
			1 + MacPopupMenu.PAD_Y, inset)
		var m := MacPopupMenu.open(host, items, at, {"min_width": int(size.x) + inset, "auto_prefix": "mac.select-item:"})
		if key:
			m.hover = selected_index
		m.chosen.connect(func(id: String):
			selected_index = id.substr(4).to_int()
			selected.emit(selected_index))
		accept_event()
