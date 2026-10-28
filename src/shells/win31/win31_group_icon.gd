class_name Win31GroupIcon
extends Control
## Minimized group window icon along the bottom of the MDI client (.wfw-minimized-group):
## 75x58 cell, 32px icon, selectable/draggable label, double-click or Enter restores.

signal restore_requested(group_id: String)

const CELL := Vector2(75, 58)
const ICON_X := 22
const LABEL_Y := 34

var group_id := ""
var client: Control
var _drag := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = CELL
	size = CELL
	add_to_group("pm_auto")


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _group() -> Dictionary:
	return ProgramStore.find_group(group_id)


func is_selected() -> bool:
	var sel: Dictionary = UIState.win31_selection
	return sel.get("kind", "") == "groupIcon" and sel.get("groupId", "") == group_id


func _draw() -> void:
	var g := _group()
	if g.is_empty():
		return
	var f := Win31Chrome.font()
	var icon := String(g.get("icon", ""))
	var tex := WfwIcons.texture(icon if icon != "" else "group")
	if tex != null:
		Px.tex(self, tex, Vector2(ICON_X, 1), Vector2(32, 32))
	var layout := Win31GridLogic.group_label_layout(f, String(g.name))
	var lines: PackedStringArray = layout.lines
	var box_w: int = layout.box_w
	var box := Rect2(1 + floorf((73 - box_w + 1) / 2.0), LABEL_Y, box_w, maxi(1, lines.size()) * 13)
	var selected := is_selected()
	var color := Pal.WHITE if selected else Pal.BLACK
	if selected:
		Px.fill_rect(self, box, Pal.NAVY)
	var content_w := box_w - 4
	for li in lines.size():
		var lit := Win31GridLogic.lit(lines[li])
		var w := f.measure(lit)
		f.draw(self, Vector2(box.position.x + 2 + floorf((content_w - w) / 2.0), box.position.y + li * 13 + Win31Chrome.LABEL_DY), lit, color,
			{"line_height": 13, "show_access": false})
	if selected and has_focus():
		Px.focus_rect(self, box, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			UIState.set_win31_selection({"kind": "groupIcon", "groupId": group_id})
			UIState.set_selected_item("", "")
			grab_focus()
			if event.double_click:
				_drag = {}
				restore_requested.emit(group_id)
			else:
				_drag = {"start": event.global_position, "origin": position}
			accept_event()
		else:
			if not _drag.is_empty():
				var drag := _drag
				_drag = {}
				var cs: Vector2 = client.client_size()
				var pos := Win31Arrange.icon_drag_position(drag.origin, event.global_position - drag.start, cs.x, cs.y)
				ProgramStore.update_group_icon_position(group_id, {"x": pos.x, "y": pos.y})
				client.refresh_icons()
			accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty() and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var cs2: Vector2 = client.client_size()
		var pos2 := Win31Arrange.icon_drag_position(_drag.origin, event.global_position - _drag.start, cs2.x, cs2.y)
		position = Vector2(pos2)
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		if Win31Commands.key_name(event) == "enter":
			accept_event()
			restore_requested.emit(group_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_drag = {}
