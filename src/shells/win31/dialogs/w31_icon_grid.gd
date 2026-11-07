class_name W31IconGrid
extends W31Widget
## Icon chooser: framed white well of 36x36 cells (32px icon, 2px gap). The chosen cell is
## navy with a dotted white focus ring. One tab stop; arrows move, Enter/Space/click choose.
## Port of .wfw-change-icon-grid / .win31-icon-picker. entries: [{id, name?}].

signal chosen(id: String)

const CELL := 36
const GAP := 2

var entries: Array = []
var columns := 8
var padding := 5
var selected_id := "":
	set(v):
		selected_id = v
		queue_redraw()
var max_height := 0  ## 0 = grow to fit; otherwise scroll
var heavy_frame := true  ## wfw-change-icon-grid (black frame) vs win31-icon-picker (same colours)

var _cursor := 0
var _scroll := 0.0
var _sb: W31ScrollBar
var _texture_for: Callable = func(id: String) -> Texture2D: return W31Icons.texture(id)


func _init(p_columns: int = 8, p_padding: int = 5) -> void:
	columns = p_columns
	padding = p_padding
	focus_mode = Control.FOCUS_ALL
	set_auto_id("wfw.dialog.icon-grid")
	_sb = W31ScrollBar.new()
	_sb.visible = false
	_sb.step = CELL + GAP
	_sb.scrolled.connect(func(v: float):
		_scroll = v
		queue_redraw())
	add_child(_sb)


func set_entries(p_entries: Array) -> void:
	entries = p_entries
	_cursor = clampi(_cursor, 0, maxi(entries.size() - 1, 0))
	_relayout()


func content_height() -> int:
	var rows := ceili(float(entries.size()) / columns)
	return maxi(rows * CELL + maxi(rows - 1, 0) * GAP, CELL) + 2 * padding + 2


func fit_height() -> int:
	var h := content_height()
	return mini(h, max_height) if max_height > 0 else h


func _relayout() -> void:
	var h := fit_height()
	size = Vector2(size.x, h)
	var overflow := content_height() > h
	_sb.visible = overflow
	if overflow:
		_sb.position = Vector2(size.x - 1 - W31ScrollBar.WIDTH, 1)
		_sb.size = Vector2(W31ScrollBar.WIDTH, h - 2)
		_sb.total = content_height() - 2
		_sb.page = h - 2
	queue_redraw()


func cell_rect(i: int) -> Rect2:
	var col := i % columns
	var row := i / columns
	return Rect2(1 + padding + col * (CELL + GAP), 1 + padding + row * (CELL + GAP) - _scroll, CELL, CELL)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	W31.sunken_field(self, r)
	for i in entries.size():
		var cr := cell_rect(i)
		if cr.end.y < 1 or cr.position.y > size.y - 1:
			continue
		var id: String = entries[i].id
		var sel := id == selected_id
		if sel:
			Px.fill_rect(self, cr, W31.NAVY)
		var tex: Texture2D = _texture_for.call(id)
		Px.tex(self, tex, cr.position + Vector2(2, 2))
		if sel or (has_focus() and i == _cursor):
			Px.focus_rect(self, cr.grow(-3), W31.WHITE if sel else W31.BLACK)


func _index_at(p: Vector2) -> int:
	for i in entries.size():
		if cell_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			var i := _index_at(event.position)
			if i >= 0:
				_cursor = i
				chosen.emit(entries[i].id)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and _sb.visible:
			_sb.value -= _sb.step
			_scroll = _sb.value
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _sb.visible:
			_sb.value += _sb.step
			_scroll = _sb.value
			queue_redraw()
			accept_event()
	elif event is InputEventKey and event.pressed and has_focus() and not entries.is_empty():
		var d := 0
		match event.keycode:
			KEY_LEFT:
				d = -1
			KEY_RIGHT:
				d = 1
			KEY_UP:
				d = -columns
			KEY_DOWN:
				d = columns
			KEY_HOME:
				d = -_cursor
			KEY_END:
				d = entries.size() - 1 - _cursor
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if event.keycode == KEY_SPACE:
					chosen.emit(entries[_cursor].id)
					accept_event()
				return
			_:
				return
		_cursor = clampi(_cursor + d, 0, entries.size() - 1)
		chosen.emit(entries[_cursor].id)
		_ensure_visible()
		accept_event()
		queue_redraw()


func _ensure_visible() -> void:
	if not _sb.visible:
		return
	var cr := cell_rect(_cursor)
	if cr.position.y < 1:
		_scroll += cr.position.y - 1
	elif cr.end.y > size.y - 1:
		_scroll += cr.end.y - (size.y - 1)
	_sb.value = _scroll
	_scroll = _sb.value
