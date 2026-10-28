class_name Win95Select
extends Control
## Win95 drop-down list (combo without editing): sunken 21px field + 16x17 arrow button; opens a
## popup list with Win95Menu. API: options (Array of String), selected_index, signal item_selected(index).

signal item_selected(index: int)

var shell: Control
var options: Array = []:
	set(v):
		options = v
		queue_redraw()
var selected_index := 0:
	set(v):
		selected_index = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var _menu: Win95Menu


func _init() -> void:
	size = Vector2(150, 21)
	custom_minimum_size = Vector2(0, 21)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func current_text() -> String:
	return String(options[selected_index]) if selected_index >= 0 and selected_index < options.size() else ""


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	Win95Draw.sunken(self, r, Win95Draw.FACE if disabled else Win95Draw.WINDOW)
	var btn := Rect2(size.x - 18, 2, 16, 17)
	Win95Draw.fill(self, btn, Win95Draw.FACE)
	Win95Draw.border(self, btn, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
	Win95Draw.inset_shadow(self, btn.grow(-1), -1, -1, Win95Draw.SHADOW)
	Win95Draw.glyph(self, "combo-down", btn.position + Vector2(1, 2), Win95Draw.DISABLED if disabled else Win95Draw.DARK)
	Win95Draw.text(self, Vector2(5, 4), current_text(), Win95Draw.TEXT, {"disabled": disabled, "max_width": int(size.x) - 26})
	if has_focus():
		Win95Draw.dotted_rect(self, r.grow(-4), Win95Draw.TEXT)


func open_list() -> void:
	if disabled or shell == null:
		return
	var items: Array = []
	for i in options.size():
		var idx := i
		items.append({"id": "opt-%d" % i, "label": String(options[i]).replace("&", "&&"), "checked": i == selected_index,
			"onSelect": func():
				selected_index = idx
				item_selected.emit(idx)})
	var at := get_global_transform() * Vector2(0, size.y - 1)
	_menu = Win95Menu.open(shell, items, at, {"on_close": func(): _menu = null})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		if _menu != null and is_instance_valid(_menu):
			_menu.close()
		else:
			open_list()
		accept_event()
