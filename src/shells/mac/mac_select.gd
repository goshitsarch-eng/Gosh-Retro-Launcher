class_name MacSelect
extends Control
## Pop-up menu button (the design's <select>): rounded face with a triangle; click opens a MacPopupMenu.

signal selected(index: int)

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
	focus_mode = Control.FOCUS_NONE
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and host != null:
		var items := []
		for i in options.size():
			items.append(MacMenuModel.item("opt:%d" % i, String(options[i].label), {"check": i == selected_index}))
		var m := MacPopupMenu.open(host, items, global_position + Vector2(0, size.y), {"min_width": int(size.x), "auto_prefix": "mac.select-item:"})
		m.chosen.connect(func(id: String):
			selected_index = id.substr(4).to_int()
			selected.emit(selected_index))
		accept_event()
