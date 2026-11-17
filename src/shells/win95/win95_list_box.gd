class_name Win95ListBox
extends Control
## Win95 report-style list for dialogs (a ListView in details mode, as in the Taskbar Properties
## Start Menu Programs page): sunken white field, optional column header, optional row check boxes,
## single selection drawn navy, dotted focus rectangle, vertical Win95Scrollbar when needed.
##   var lb := Win95ListBox.new()
##   lb.columns = [{"label": "Group", "width": 60}, {"label": "Name", "width": 140}, {"label": "Programs"}]
##   lb.checkboxes = true
##   lb.set_rows([{"cells": ["Group 1", "Morning", "2"], "checked": false}, ...])
## Keyboard (while focused): Up/Down/Home/End/PageUp/PageDown move the selection; Space (routed by
## Win95Modal through click()) toggles the selected row's box; Delete/F2/Enter-free keys are passed on
## through `command_key`. Mouse: click selects (the box toggles), double-click emits row_activated,
## the wheel scrolls.

signal selection_changed(index: int)
signal row_activated(index: int)
signal check_toggled(index: int, checked: bool)
signal command_key(key: String)

const ROW_H := 17
const HEADER_H := 18
const BOX := 13

var columns: Array = []
var show_header := true
var checkboxes := false
var rows: Array = []
var selected := -1
var scroll := 0
var empty_text := ""

var _body: _Body
var _sb: Win95Scrollbar


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(200, 120)
	_body = _Body.new()
	_body.box = self
	add_child(_body)
	_sb = Win95Scrollbar.new()
	_sb.vertical = true
	_sb.visible = false
	_sb.scrolled.connect(func(v: int):
		scroll = v
		_body.queue_redraw())
	add_child(_sb)
	resized.connect(_layout)
	A11y.track(self)


## Replaces the rows and selects row `want` (clamped; -1 = no selection). Emits nothing.
func set_rows(new_rows: Array, want: int = -1) -> void:
	rows = new_rows
	selected = -1 if rows.is_empty() or want < 0 else clampi(want, 0, rows.size() - 1)
	_layout()
	reveal(selected)
	queue_redraw()
	_body.queue_redraw()
	queue_accessibility_update()


func _header_h() -> int:
	return HEADER_H if show_header and columns.size() > 0 else 0


func _viewport_h() -> int:
	return maxi(0, int(size.y) - 4 - _header_h())


func _needs_scroll() -> bool:
	return rows.size() * ROW_H > _viewport_h()


func visible_rows() -> int:
	return maxi(1, _viewport_h() / ROW_H)


func _layout() -> void:
	var need := _needs_scroll()
	_sb.visible = need
	var inner_w := int(size.x) - 4 - (Win95Scrollbar.ARROW if need else 0)
	_body.position = Vector2(2, 2 + _header_h())
	_body.size = Vector2(maxi(1, inner_w), maxi(1, _viewport_h()))
	scroll = Win95ScrollbarState.clamp_scroll(scroll, rows.size() * ROW_H, _viewport_h())
	if need:
		_sb.position = Vector2(size.x - 2 - Win95Scrollbar.ARROW, 2)
		_sb.configure(scroll, _viewport_h(), rows.size() * ROW_H, size.y - 4, ROW_H)
	queue_redraw()
	_body.queue_redraw()


## Column [x, width] in body coordinates; the last column takes the remaining width.
func column_span(i: int) -> Vector2:
	var x := 0.0
	for c in i:
		x += float(columns[c].get("width", 80))
	var w := float(columns[i].get("width", 80)) if i < columns.size() - 1 else maxf(20.0, _body.size.x - x)
	return Vector2(x, w)


func reveal(index: int) -> void:
	if index < 0:
		return
	var top := index * ROW_H
	if top < scroll:
		scroll = top
	elif top + ROW_H > scroll + _viewport_h():
		scroll = top + ROW_H - _viewport_h()
	scroll = Win95ScrollbarState.clamp_scroll(scroll, rows.size() * ROW_H, _viewport_h())
	if _sb.visible:
		_sb.configure(scroll, _viewport_h(), rows.size() * ROW_H, size.y - 4, ROW_H)
	_body.queue_redraw()


func select(index: int) -> void:
	if rows.is_empty():
		index = -1
	else:
		index = clampi(index, 0, rows.size() - 1)
	var changed := index != selected
	selected = index
	reveal(index)
	_body.queue_redraw()
	queue_accessibility_update()
	if changed:
		selection_changed.emit(index)


func toggle(index: int) -> void:
	if not checkboxes or index < 0 or index >= rows.size():
		return
	var on := not bool(rows[index].get("checked", false))
	rows[index]["checked"] = on
	_body.queue_redraw()
	queue_accessibility_update()
	check_toggled.emit(index, on)


## Space from the modal key router: toggles the selected row's box.
func click() -> void:
	toggle(selected)


## Next selection for a navigation key, or -2 when `key` does not navigate. Pure.
static func next_index(index: int, key: String, count: int, page: int) -> int:
	if not key in ["ArrowUp", "ArrowDown", "Home", "End", "PageUp", "PageDown"]:
		return -2
	if count <= 0:
		return -1
	match key:
		"ArrowDown": return 0 if index < 0 else mini(count - 1, index + 1)
		"ArrowUp": return 0 if index < 0 else maxi(0, index - 1)
		"Home": return 0
		"End": return count - 1
		"PageDown": return mini(count - 1, maxi(0, index) + maxi(1, page - 1))
		"PageUp": return maxi(0, index - maxi(1, page - 1))
	return -2


func _row_at(p: Vector2) -> int:
	var local := p - _body.position
	if local.x < 0 or local.y < 0 or local.x >= _body.size.x or local.y >= _body.size.y:
		return -1
	var i := int((local.y + scroll) / ROW_H)
	return i if i < rows.size() else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			var dir := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			scroll = Win95ScrollbarState.clamp_scroll(scroll + dir * ROW_H * 3, rows.size() * ROW_H, _viewport_h())
			_layout()
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		grab_focus()
		var i := _row_at(mb.position)
		if i >= 0:
			select(i)
			var local := mb.position - _body.position
			if checkboxes and not mb.double_click and local.x < 2 + BOX + 2:
				toggle(i)
			elif mb.double_click:
				row_activated.emit(i)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var key := Win95InputController.key_name(event as InputEventKey)
		var n := next_index(selected, key, rows.size(), visible_rows())
		if n != -2:
			if n >= 0:
				select(n)
			accept_event()
		elif key in ["Delete", "F2"]:
			command_key.emit(key)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		if what == NOTIFICATION_FOCUS_ENTER and selected < 0 and rows.size() > 0:
			select(0)
		_body.queue_redraw()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var ae := get_accessibility_element()
		A11y.apply(ae, {"role": DisplayServer.ROLE_LIST_BOX, "name": accessibility_name if accessibility_name != "" else Win95Label.caption_near(self),
			"count": rows.size()})
		var specs := []
		for i in rows.size():
			var cells: Array = rows[i].get("cells", [])
			var spec := A11y.option(", ".join(cells.filter(func(c): return String(c) != "")), i == selected, i, rows.size(),
				Rect2(_body.position + Vector2(0, i * ROW_H - scroll), Vector2(_body.size.x, ROW_H)))
			if checkboxes:
				spec["checked"] = bool(rows[i].get("checked", false))
			specs.append(spec)
		A11y.sync_children(ae, _a11y_rows, specs)
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		_a11y_rows.clear()


var _a11y_rows: Array = []


func _get_focused_accessibility_element() -> RID:
	return A11y.child_or(_a11y_rows, selected, A11y.resolve(get_accessibility_element()))


func _draw() -> void:
	Win95Draw.sunken(self, Rect2(Vector2.ZERO, size), Win95Draw.WINDOW, true)
	var hh := _header_h()
	if hh > 0:
		var right := int(size.x) - 2 - (Win95Scrollbar.ARROW if _sb.visible else 0)
		Win95Draw.fill(self, Rect2(2, 2, right - 2, hh), Win95Draw.FACE)
		for i in columns.size():
			var span := column_span(i)
			var w := minf(span.y, right - 2 - span.x)
			if w <= 0:
				continue
			var r := Rect2(2 + span.x, 2, w, hh)
			Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
			Win95Draw.inset_shadow(self, r.grow(-1), -1, -1, Win95Draw.SHADOW)
			Win95Draw.text(self, Vector2(r.position.x + 5, 5), String(columns[i].get("label", "")), Win95Draw.TEXT, {"max_width": maxi(1, int(w) - 10)})


func _draw_rows(ci: Control) -> void:
	var w := ci.size.x
	if rows.is_empty() and empty_text != "":
		Win95Draw.text(ci, Vector2(4, 4), empty_text, Win95Draw.TEXT, {"show_access": false, "max_width": int(w) - 8})
		return
	var first := scroll / ROW_H
	var last := mini(rows.size() - 1, (scroll + int(ci.size.y)) / ROW_H)
	for i in range(first, last + 1):
		var y := i * ROW_H - scroll
		var row: Dictionary = rows[i]
		var sel := i == selected
		var fg := Win95Draw.SELECTED_TEXT if sel else Win95Draw.TEXT
		var text_x := 2.0
		if checkboxes:
			var b := Rect2(2, y + 2, BOX, BOX)
			Win95Draw.fill(ci, b, Win95Draw.WINDOW)
			Win95Draw.border(ci, b, 2, Win95Draw.SHADOW, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.SHADOW)
			Win95Draw.inset_shadow(ci, b.grow(-2), 1, 1, Win95Draw.DARK)
			if row.get("checked", false):
				Win95Draw.glyph(ci, "menu-check", b.position + Vector2(1, 1), Win95Draw.DARK)
			text_x = 2 + BOX + 3
		var cells: Array = row.get("cells", [])
		var row_rect := Rect2(text_x, y, w - text_x, ROW_H)
		if sel:
			Win95Draw.fill(ci, row_rect, Win95Draw.SELECTED)
		var ncol := maxi(1, columns.size())
		for c in ncol:
			if c >= cells.size():
				break
			var x0 := text_x
			var cw := w - text_x
			if columns.size() > 0:
				var span := column_span(c)
				x0 = maxf(text_x, span.x)
				cw = span.x + span.y - x0
			Win95Draw.text(ci, Vector2(x0 + 3, y + 2), String(cells[c]).replace("&", "&&"), fg,
				{"show_access": false, "max_width": maxi(1, int(cw) - 8)})
		if sel and has_focus():
			Win95Draw.dotted_rect(ci, row_rect, Win95Draw.SELECTED_TEXT)


## The clipped rows area.
class _Body extends Control:
	var box: Win95ListBox

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		if box != null:
			box._draw_rows(self)


# ---------------------------------------------------------------- automation

## Row rect (global) for automation: "<auto_id>:row:<i>".
func row_rect(i: int) -> Rect2:
	return Rect2(global_position + _body.position + Vector2(0, i * ROW_H - scroll), Vector2(_body.size.x, ROW_H))
