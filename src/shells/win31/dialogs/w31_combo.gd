class_name W31Combo
extends W31Widget
## Drop-down list ("select.win31-input"). Sunken field + raised arrow button; the list opens in
## a framed popup. Up/Down change the value while closed, Space/Alt+Down/click open it.

signal selection_changed(index: int)

const HEIGHT := 19
const ROW := 15
const MAX_ROWS := 8
const ARROW_W := 16

var items: Array = []  ## display strings
var values: Array = []  ## parallel payloads (defaults to the strings)
var selected := 0:
	set(v):
		selected = clampi(v, 0, maxi(items.size() - 1, 0))
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		queue_redraw()

var _popup: Control


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_items(p_items: Array, p_values: Array = []) -> void:
	items = p_items
	values = p_values if p_values.size() == p_items.size() else p_items.duplicate()
	selected = selected
	queue_redraw()


func value() -> Variant:
	return values[selected] if selected < values.size() else null


func select_value(v: Variant) -> void:
	var i := values.find(v)
	if i >= 0:
		selected = i


func is_open() -> bool:
	return _popup != null and is_instance_valid(_popup)


func consume_escape() -> bool:
	if is_open():
		close_popup()
		return true
	return false


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	W31.sunken_field(self, r, W31.FACE if disabled else W31.WHITE)
	var btn := Rect2(size.x - 1 - ARROW_W, 1, ARROW_W, size.y - 2)
	W31.raised(self, btn, is_open())
	W31.triangle(self, btn.get_center() + Vector2(0, 0), 1, 4, W31.SHADOW if disabled else W31.BLACK)
	if items.is_empty():
		return
	var label: String = items[selected]
	var text_w := int(size.x) - 2 - ARROW_W - 4
	var clipped := W31.font().clip(label, text_w)
	var line_y := floorf((size.y - 13) / 2.0)
	if has_focus() and not is_open():
		var hw := W31.font().measure(clipped)
		Px.fill(self, 3, 3, mini(hw + 2, text_w + 2), size.y - 6, W31.NAVY)
		W31.font().draw(self, Vector2(4, line_y), clipped, W31.WHITE)
	else:
		W31.font().draw(self, Vector2(4, line_y), clipped, W31.BLACK, {"disabled": disabled})


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		if is_open():
			close_popup()
		else:
			open_popup()
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		match event.keycode:
			KEY_DOWN:
				if event.alt_pressed:
					open_popup()
				else:
					_step(1)
				accept_event()
			KEY_UP:
				_step(-1)
				accept_event()
			KEY_HOME:
				_commit(0)
				accept_event()
			KEY_END:
				_commit(items.size() - 1)
				accept_event()
			KEY_SPACE, KEY_F4:
				open_popup()
				accept_event()


func _step(d: int) -> void:
	_commit(clampi(selected + d, 0, maxi(items.size() - 1, 0)))


func _commit(i: int) -> void:
	if items.is_empty() or i == selected:
		return
	selected = i
	selection_changed.emit(i)


func open_popup() -> void:
	if is_open() or items.is_empty():
		return
	_popup = _Popup.new(self)
	_popup.top_level = true
	_popup.z_index = 200
	_popup.z_as_relative = false
	add_child(_popup)
	_popup.global_position = global_position + Vector2(0, size.y - 1)
	queue_redraw()


func close_popup() -> void:
	if is_open():
		_popup.queue_free()
	_popup = null
	queue_redraw()


func _exit_tree() -> void:
	_popup = null


class _Popup extends Control:
	var combo: W31Combo
	var hover := -1
	var top := 0  ## first visible row
	var sb: W31ScrollBar

	func _init(p_combo: W31Combo) -> void:
		combo = p_combo
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		var rows := mini(combo.items.size(), MAX_ROWS)
		size = Vector2(combo.size.x, rows * ROW + 2)
		hover = combo.selected
		top = clampi(combo.selected - rows + 1, 0, maxi(0, combo.items.size() - rows)) if combo.selected >= rows else 0
		if combo.items.size() > MAX_ROWS:
			sb = W31ScrollBar.new()
			sb.total = combo.items.size()
			sb.page = rows
			sb.step = 1
			sb.value = top
			sb.position = Vector2(size.x - 1 - W31ScrollBar.WIDTH, 1)
			sb.size = Vector2(W31ScrollBar.WIDTH, size.y - 2)
			sb.scrolled.connect(func(v: float):
				top = int(v)
				queue_redraw())
			add_child(sb)

	func _rows() -> int:
		return mini(combo.items.size(), MAX_ROWS)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Px.fill_rect(self, r, W31.WHITE)
		Px.outline(self, r, W31.BLACK)
		var text_w := int(size.x) - 4 - (W31ScrollBar.WIDTH if sb else 0) - 4
		for i in _rows():
			var idx := top + i
			var y := 1 + i * ROW
			var sel := idx == hover
			var row_w := int(size.x) - 2 - (W31ScrollBar.WIDTH if sb else 0)
			if sel:
				Px.fill(self, 1, y, row_w, ROW, W31.NAVY)
			W31.font().draw(self, Vector2(4, y + 1), W31.font().clip(combo.items[idx], text_w), W31.WHITE if sel else W31.BLACK)

	func _row_at(p: Vector2) -> int:
		var i := int((p.y - 1) / ROW)
		return top + i if i >= 0 and i < _rows() else -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var i := _row_at(event.position)
			if i >= 0 and i != hover:
				hover = i
				queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var i := _row_at(event.position)
			if i >= 0 and (not sb or event.position.x < size.x - W31ScrollBar.WIDTH - 1):
				combo._commit(i)
				combo.close_popup()
			accept_event()
		elif event is InputEventMouseButton and event.pressed and sb and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			sb.value += -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			top = int(sb.value)
			queue_redraw()
			accept_event()

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			var local: Vector2 = get_global_transform().affine_inverse() * event.position
			if not Rect2(Vector2.ZERO, size).has_point(local) and not Rect2(Vector2.ZERO, combo.size).has_point(combo.get_global_transform().affine_inverse() * event.position):
				combo.close_popup()
		elif event is InputEventKey and event.pressed:
			var handled := true
			match event.keycode:
				KEY_DOWN:
					hover = mini(hover + 1, combo.items.size() - 1)
				KEY_UP:
					hover = maxi(hover - 1, 0)
				KEY_HOME:
					hover = 0
				KEY_END:
					hover = combo.items.size() - 1
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					combo._commit(hover)
					combo.close_popup()
					get_viewport().set_input_as_handled()
					return
				KEY_ESCAPE:
					combo.close_popup()
					get_viewport().set_input_as_handled()
					return
				_:
					handled = false
			if handled:
				if hover < top:
					top = hover
				elif hover >= top + _rows():
					top = hover - _rows() + 1
				if sb:
					sb.value = top
				queue_redraw()
				get_viewport().set_input_as_handled()
