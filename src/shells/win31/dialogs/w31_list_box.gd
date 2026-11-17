class_name W31ListBox
extends W31Widget
## WfW list box: sunken white well of 15px rows, navy highlight on the current row, dotted focus
## rectangle while focused, 16px scroll bar when the rows overflow. One tab stop.
## Rows: [{text, right?, header?, checked?, indent?}]. `header` rows are bold captions that the
## cursor skips. With `checkboxes` every other row gets a 13px check box that Space or a click on
## the box toggles (the Members checklist). Up/Down/Home/End/PageUp/PageDown move the cursor;
## a double click emits `activated`.

signal selection_changed(index: int)
signal activated(index: int)
signal toggled(index: int, checked: bool)

const ROW := 15
const BOX := 13

var rows: Array = []
var checkboxes := false
var visible_rows := 8
var current := -1:
	set(v):
		current = v
		queue_redraw()

var _top := 0
var _sb: W31ScrollBar


func _init(p_visible_rows: int = 8, p_checkboxes: bool = false) -> void:
	visible_rows = p_visible_rows
	checkboxes = p_checkboxes
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_auto_id("wfw.dialog.list")
	_sb = W31ScrollBar.new()
	_sb.visible = false
	_sb.step = 1
	_sb.scrolled.connect(func(v: float):
		_top = int(v)
		queue_redraw())
	add_child(_sb)


## Height for `visible_rows` rows: 1px black + 1px grey on top, rows, 1px black at the bottom.
func fit_height() -> int:
	return visible_rows * ROW + 3


## Replaces the rows and puts the cursor on `select` (or the first selectable row from there).
func set_rows(p_rows: Array, select: int = -1) -> void:
	rows = p_rows
	var i := select if select >= 0 else current
	current = _selectable_from(clampi(i, 0, maxi(rows.size() - 1, 0)), 1)
	if current < 0:
		current = _selectable_from(rows.size() - 1, -1)
	_relayout()
	_ensure_visible()


func _relayout() -> void:
	var overflow := rows.size() > visible_rows
	_sb.visible = overflow
	_sb.position = Vector2(size.x - 1 - W31ScrollBar.WIDTH, 1)
	_sb.size = Vector2(W31ScrollBar.WIDTH, maxf(size.y - 2, 2 * W31ScrollBar.BUTTON))
	_sb.total = rows.size()
	_sb.page = visible_rows
	_top = clampi(_top, 0, maxi(0, rows.size() - visible_rows))
	_sb.value = _top
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _sb != null:
		_relayout()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		A11y.sync_children(get_accessibility_element(), _a11y_items, a11y_item_specs())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		_a11y_items.clear()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func is_selectable(i: int) -> bool:
	return i >= 0 and i < rows.size() and not rows[i].get("header", false)


## First selectable row at `i` or beyond in direction `dir` (+1/-1), or -1.
func _selectable_from(i: int, dir: int) -> int:
	while i >= 0 and i < rows.size():
		if is_selectable(i):
			return i
		i += dir
	return -1


func row_rect(i: int) -> Rect2:
	var w := size.x - 3 - (W31ScrollBar.WIDTH if _sb.visible else 0)
	return Rect2(2, 2 + (i - _top) * ROW, w, ROW)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	W31.sunken_field(self, r)
	var f := W31.font()
	for vi in visible_rows:
		var i := _top + vi
		if i >= rows.size():
			break
		var row: Dictionary = rows[i]
		var rr := row_rect(i)
		var header: bool = row.get("header", false)
		var sel := i == current and not header
		if sel:
			Px.fill_rect(self, rr, W31.NAVY)
		var ink := W31.WHITE if sel else W31.BLACK
		var x := int(rr.position.x) + 2 + int(row.get("indent", 0))
		if checkboxes and not header:
			_draw_box(Vector2(x, rr.position.y + 1), bool(row.get("checked", false)))
			x += BOX + 4
		var right := String(row.get("right", ""))
		var right_w := f.measure(right) if right != "" else 0
		var avail := int(rr.end.x) - 2 - x - (right_w + 12 if right != "" else 0)
		# Row text is literal: "&" is doubled so the font's access-key parsing keeps it.
		var label := f.clip(String(row.get("text", "")).replace("&", "&&"), avail, header).replace("&", "&&")
		f.draw(self, Vector2(x, rr.position.y + 1), label, ink, {"bold": header, "show_access": false})
		if right != "":
			f.draw(self, Vector2(rr.end.x - 3 - right_w, rr.position.y + 1), right, ink, {"show_access": false})
		if sel and has_focus():
			Px.focus_rect(self, rr, W31.WHITE)
	if has_focus() and current < 0:
		Px.focus_rect(self, Rect2(2, 2, size.x - 3 - (W31ScrollBar.WIDTH if _sb.visible else 0), ROW))


## 13px check box with W31Checkbox's check glyph; on the white well it is a plain black square
## (the sunken face-colour bevel of the dialog check box would vanish against white).
func _draw_box(p: Vector2, on: bool) -> void:
	var box := Rect2(p, Vector2(BOX, BOX))
	Px.fill_rect(self, box, W31.WHITE)
	Px.outline(self, box, W31.BLACK)
	if on:
		for y in W31Checkbox.CHECK.size():
			for x in W31Checkbox.CHECK[y].length():
				if W31Checkbox.CHECK[y][x] == "#":
					Px.fill(self, p.x + 3 + x, p.y + 4 + y, 1, 1, W31.BLACK)


func _row_at(p: Vector2) -> int:
	if p.y < 2:
		return -1
	var i := _top + int((p.y - 2) / ROW)
	return i if i < rows.size() and i < _top + visible_rows else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			var i := _row_at(event.position)
			if is_selectable(i):
				_move_to(i)
				if event.double_click:
					activated.emit(i)
				elif checkboxes:
					var rr := row_rect(i)
					var bx := rr.position.x + 2 + int(rows[i].get("indent", 0))
					if event.position.x >= bx - 2 and event.position.x < bx + BOX + 2:
						toggle(i)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _sb.visible:
				_sb.value += -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				_top = int(_sb.value)
				queue_redraw()
			accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		if handle_key(event.keycode, event.echo):
			accept_event()


## Keyboard model (focused list): arrows/Home/End/PageUp/PageDown move over selectable rows, Space
## toggles a check box. Returns true when the key was used.
func handle_key(keycode: Key, echo: bool = false) -> bool:
	if rows.is_empty():
		return false
	var target := -1
	match keycode:
		KEY_DOWN:
			target = _selectable_from(current + 1, 1)
		KEY_UP:
			target = _selectable_from(current - 1, -1)
		KEY_HOME:
			target = _selectable_from(0, 1)
		KEY_END:
			target = _selectable_from(rows.size() - 1, -1)
		KEY_PAGEDOWN:
			target = _selectable_from(mini(current + visible_rows - 1, rows.size() - 1), -1)
		KEY_PAGEUP:
			target = _selectable_from(maxi(current - visible_rows + 1, 0), 1)
		KEY_SPACE:
			if checkboxes and is_selectable(current) and not echo:
				toggle(current)
			return checkboxes
		_:
			return false
	if target >= 0:
		_move_to(target)
	return true


func _move_to(i: int) -> void:
	if i == current:
		return
	current = i
	_ensure_visible()
	selection_changed.emit(i)


func toggle(i: int) -> void:
	if not checkboxes or not is_selectable(i):
		return
	rows[i]["checked"] = not bool(rows[i].get("checked", false))
	queue_redraw()
	toggled.emit(i, rows[i].checked)


## Checks or clears every selectable row.
func set_all_checked(on: bool) -> void:
	for i in rows.size():
		if is_selectable(i):
			rows[i]["checked"] = on
	queue_redraw()


func _ensure_visible() -> void:
	if current < 0:
		return
	if current < _top:
		_top = current
	elif current >= _top + visible_rows:
		_top = current - visible_rows + 1
	if current == _selectable_from(0, 1):
		_top = 0  # show the caption above the first row
	_top = clampi(_top, 0, maxi(0, rows.size() - visible_rows))
	_sb.value = _top
	queue_redraw()


# ------------------------------------------------------------------ accessibility

var _a11y_items: Array = []


func a11y_spec() -> Dictionary:
	var name := a11y_label()
	return {"role": DisplayServer.ROLE_LIST_BOX, "name": name, "count": rows.size()}


func a11y_item_specs() -> Array:
	var out := []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var spec: Dictionary
		if row.get("header", false):
			spec = A11y.static_text(String(row.get("text", "")), row_rect(i))
		elif checkboxes:
			spec = A11y.check_box(String(row.get("text", "")), bool(row.get("checked", false)))
			spec["bounds"] = row_rect(i)
			spec["click"] = _a11y_toggle.bind(i)
		else:
			var right := String(row.get("right", ""))
			spec = A11y.option(String(row.get("text", "")) + (", " + right if right != "" else ""), i == current, i, rows.size(), row_rect(i))
			spec["click"] = _a11y_pick.bind(i)
		spec["hidden"] = i < _top or i >= _top + visible_rows
		out.append(spec)
	return out


func _a11y_pick(_data: Variant, i: int) -> void:
	if is_selectable(i):
		_move_to(i)


func _a11y_toggle(_data: Variant, i: int) -> void:
	_move_to(i)
	toggle(i)


func _get_focused_accessibility_element() -> RID:
	return A11y.resolve(A11y.child_or(_a11y_items, current, get_accessibility_element()))
