class_name Win95Menu
extends Control
## One popup-menu level (menu-bar drop-downs, context menus, system menu, cascades).
## Port of Win95Menu.tsx. The ROOT level owns the whole cascade and the input:
##   var m := Win95Menu.open(shell, items, Vector2(x, y), {bottom_inset, on_close, anchors, tracking})
## Item models are Dictionaries:
##   {id, label ("&Open" access keys), icon (Win95 catalog id), separator, disabled,
##    checked (bool), radio, defaultItem (bold), children: [..], onSelect: Callable}
## opts: bottom_inset (px kept free above the taskbar), on_close: Callable, on_select: Callable(item),
##   anchors: Array[Rect2] (pointer-downs inside them are not "outside" clicks - e.g. the menu-bar title),
##   tracking: bool (opened by a pressed button: releasing over an item activates it).
## Keyboard: the root registers a "menu"-layer handler (Up/Down/Home/End/Left/Right/Enter/Escape/mnemonics).
## Pointer: hover selects; left press+release activates; cascades open after 220 ms.

const M := Win95Tokens.M
const ITEM_H := 20
const SEP_H := 6
const ESTIMATED_CHILD_WIDTH := 176

var shell: Control
var items: Array = []
var root: Win95Menu              ## the root level (self for the root)
var level := 0
var selected_id := ""
var bottom_inset := 0
var on_close: Callable = Callable()
var on_select: Callable = Callable()
var anchors: Array = []
var tracking := false

var _levels: Array = []          ## root only: [root, child1, child2...]
var _rows: Array = []            ## [{item, y, h}]
var _delay_timer: Timer
var _pending_item_id := ""
var _closed := false
var _uid := ""
static var _counter := 0


static func open(p_shell: Control, p_items: Array, at: Vector2, opts: Dictionary = {}) -> Win95Menu:
	var menu := Win95Menu.new()
	menu.shell = p_shell
	menu.root = menu
	menu.level = 0
	menu.items = p_items
	menu.bottom_inset = int(opts.get("bottom_inset", 0))
	menu.on_close = opts.get("on_close", Callable())
	menu.on_select = opts.get("on_select", Callable())
	menu.anchors = opts.get("anchors", [])
	menu.tracking = bool(opts.get("tracking", false))
	menu._uid = "popup-%d" % Win95Menu._counter
	Win95Menu._counter += 1
	menu._levels = [menu]
	p_shell.popup_layer.add_child(menu)
	menu._place(at)
	menu._register()
	return menu


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _register() -> void:
	var input: Win95InputController = shell.input
	input.set_menu_scope(_uid, true)
	input.register_key("menu", _uid, _on_key)
	input.register_pointer("down", _uid, _on_pointer_down)
	input.register_pointer("move", _uid, _on_pointer_move)
	input.register_pointer("up", _uid, _on_pointer_up)


func _unregister() -> void:
	if shell == null or not is_instance_valid(shell) or shell.input == null:
		return
	var input: Win95InputController = shell.input
	input.set_menu_scope(_uid, false)
	input.unregister_key("menu", _uid)
	input.unregister_pointer("down", _uid)
	input.unregister_pointer("move", _uid)
	input.unregister_pointer("up", _uid)


func _exit_tree() -> void:
	if root == self:
		_unregister()


# ------------------------------------------------------------------ layout

func _selectable(item: Dictionary) -> bool:
	return not item.get("separator", false) and not item.get("disabled", false)


func _label_width(item: Dictionary) -> int:
	return Win95Draw.measure(String(item.get("label", "")), bool(item.get("defaultItem", false)))


func _layout() -> void:
	_rows.clear()
	var y := 4
	var widest := 90
	for item in items:
		var h: int = SEP_H if item.get("separator", false) else ITEM_H
		_rows.append({"item": item, "y": y, "h": h})
		y += h
		if not item.get("separator", false):
			widest = maxi(widest, _label_width(item))
	var width := maxi(164, 51 + widest)
	size = Vector2(width, y + 4)
	if selected_id == "":
		for item in items:
			if _selectable(item):
				selected_id = String(item.id)
				break


func _place(at: Vector2) -> void:
	_layout()
	var vp: Vector2 = shell.logical_size
	var x := clampf(at.x, 0.0, vp.x - size.x)
	var y := clampf(at.y, 0.0, vp.y - bottom_inset - size.y)
	position = Vector2(Win95ShellInput.js_round(x), Win95ShellInput.js_round(y))
	queue_redraw()


func menu_rect() -> Rect2:
	return Rect2(position, size)


func _row_at(local: Vector2) -> int:
	if local.x < 4 or local.x >= size.x - 4:
		return -1
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if local.y >= r.y and local.y < r.y + r.h:
			return i
	return -1


func row_rect(index: int) -> Rect2:
	var r: Dictionary = _rows[index]
	return Rect2(position.x + 4, position.y + r.y, size.x - 8, r.h)


## Rect (shell coordinates) of the row whose id/label matches (automation).
func find_row(id_or_label: String) -> Rect2:
	for i in _rows.size():
		var item: Dictionary = _rows[i].item
		if item.get("separator", false):
			continue
		var label := String(item.get("label", "")).replace("&", "")
		if String(item.id) == id_or_label or label == id_or_label:
			return row_rect(i)
	return Rect2()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	Win95Draw.popup_frame(self, box)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var item: Dictionary = r.item
		var x0 := 4.0
		var y0: float = r.y
		if item.get("separator", false):
			var w := size.x - 8
			# margin 0 2px; 1px transparent top border, 2 shadow rows, 1 light row
			Win95Draw.fill(self, Rect2(x0 + 2, y0 + 1, w - 4, 2), Win95Draw.SHADOW)
			Win95Draw.fill(self, Rect2(x0 + 2, y0 + 3, w - 4, 1), Win95Draw.LIGHT)
			continue
		var sel := String(item.id) == selected_id and not item.get("disabled", false)
		var row_w := size.x - 8
		if sel:
			Win95Draw.fill(self, Rect2(x0, y0, row_w, r.h), Win95Draw.SELECTED)
		var fg := Win95Draw.SELECTED_TEXT if sel else Win95Draw.TEXT
		if item.get("checked", false):
			Win95Draw.glyph(self, "menu-radio" if item.get("radio", false) else "menu-check", Vector2(x0, y0 + 4), fg)
		var icon := String(item.get("icon", ""))
		if icon != "":
			Win95Draw.icon(self, Win95IconCatalog.texture(icon, "small"), Vector2(x0 + 12, y0 + 2))
		var label := String(item.get("label", ""))
		Win95Draw.text(self, Vector2(x0 + 30, y0 + 3), label, fg, {
			"bold": item.get("defaultItem", false), "disabled": item.get("disabled", false)})
		if item.get("children", []).size() > 0:
			Win95Draw.glyph(self, "menu-right", Vector2(x0 + row_w - 3 - 14, y0 + 4), fg)


# ------------------------------------------------------------------ selection / cascades

func _item_has_children(item: Dictionary) -> bool:
	return item.get("children", []).size() > 0


func _find_item(id: String) -> Dictionary:
	for item in items:
		if String(item.get("id", "")) == id:
			return item
	return {}


func _select_item(item: Dictionary, with_delay: bool) -> void:
	if item.get("separator", false) or item.get("disabled", false):
		return
	selected_id = String(item.id)
	queue_redraw()
	var rt: Win95Menu = root
	var has_child := _item_has_children(item)
	# Only one open cascade per level.
	var child_open: bool = rt._levels.size() > level + 1
	rt._clear_delay()
	if not has_child:
		if child_open:
			rt._schedule_truncate(level)
		return
	if child_open and rt._levels[level + 1].get_meta("owner_id", "") == String(item.id):
		return
	rt._schedule_open(self, item, with_delay)


func _clear_delay() -> void:
	if _delay_timer != null:
		_delay_timer.stop()


func _ensure_timer() -> void:
	if _delay_timer == null:
		_delay_timer = Timer.new()
		_delay_timer.one_shot = true
		add_child(_delay_timer)


var _delay_action: Callable = Callable()


func _schedule_truncate(from_level: int) -> void:
	_ensure_timer()
	_delay_action = func(): _truncate(from_level)
	_restart_delay()


func _schedule_open(level_menu: Win95Menu, item: Dictionary, with_delay: bool) -> void:
	if not with_delay:
		_open_child(level_menu, item)
		return
	_ensure_timer()
	_delay_action = func(): _open_child(level_menu, item)
	_restart_delay()


func _restart_delay() -> void:
	if _delay_timer.timeout.is_connected(_on_delay):
		_delay_timer.timeout.disconnect(_on_delay)
	_delay_timer.timeout.connect(_on_delay)
	_delay_timer.start(M.submenuDelayMs / 1000.0)


func _on_delay() -> void:
	if _delay_action.is_valid():
		var a := _delay_action
		_delay_action = Callable()
		a.call()


## Root only: drops every level deeper than `keep_level`.
func _truncate(keep_level: int) -> void:
	while _levels.size() > keep_level + 1:
		var m: Win95Menu = _levels.pop_back()
		if is_instance_valid(m):
			m.queue_free()
	for m in _levels:
		m.queue_redraw()


func _open_child(parent: Win95Menu, item: Dictionary) -> void:
	if _closed or not is_instance_valid(parent):
		return
	_truncate(parent.level)
	var kids: Array = item.get("children", [])
	if kids.is_empty():
		return
	var child := Win95Menu.new()
	child.shell = shell
	child.root = self
	child.level = parent.level + 1
	child.items = kids
	child.bottom_inset = bottom_inset
	child.set_meta("owner_id", String(item.id))
	var row := parent.row_rect(parent._index_of(String(item.id)))
	var vp: Vector2 = shell.logical_size
	var right := parent.position.x + parent.size.x
	var left := parent.position.x
	var child_x: float
	if right - 1 + ESTIMATED_CHILD_WIDTH > vp.x:
		child_x = left - ESTIMATED_CHILD_WIDTH + 1
	else:
		child_x = right - 1
	shell.popup_layer.add_child(child)
	_levels.append(child)
	child._place(Vector2(child_x, row.position.y))


func _index_of(id: String) -> int:
	for i in _rows.size():
		if String(_rows[i].item.id) == id:
			return i
	return -1


# ------------------------------------------------------------------ activation / closing

func _activate(menu: Win95Menu, item: Dictionary) -> bool:
	if item.is_empty() or item.get("disabled", false) or item.get("separator", false):
		return false
	if _item_has_children(item):
		menu.selected_id = String(item.id)
		_clear_delay()
		_open_child(menu, item)
		menu.queue_redraw()
		return true
	var cb: Variant = item.get("onSelect")
	close()
	if cb is Callable and cb.is_valid():
		cb.call()
	if on_select.is_valid():
		on_select.call(item)
	return true


## Closes the whole cascade (root only; children forward).
func close() -> void:
	if root != self:
		root.close()
		return
	if _closed:
		return
	_closed = true
	_unregister()
	for m in _levels:
		if is_instance_valid(m):
			m.queue_free()
	_levels.clear()
	if on_close.is_valid():
		on_close.call()


func is_open() -> bool:
	return not _closed


## Closes one cascade level: the last level only, or the whole menu at level 0.
func _close_level(menu: Win95Menu) -> void:
	if menu.level == 0:
		close()
	else:
		_truncate(menu.level - 1)


func point_inside(pos: Vector2) -> bool:
	for m in _levels:
		if is_instance_valid(m) and m.menu_rect().has_point(pos):
			return true
	return false


func _level_at(pos: Vector2) -> Win95Menu:
	for i in range(_levels.size() - 1, -1, -1):
		var m: Win95Menu = _levels[i]
		if is_instance_valid(m) and m.menu_rect().has_point(pos):
			return m
	return null


# ------------------------------------------------------------------ pointer (root)

func _on_pointer_down(event: InputEventMouse, pos: Vector2) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var m := _level_at(pos)
	if m != null:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var idx := m._row_at(pos - m.position)
		if idx >= 0:
			tracking = true
			var item: Dictionary = m._rows[idx].item
			if m._selectable(item):
				m._select_item(item, false)
		return true
	for a in anchors:
		if (a as Rect2).has_point(pos):
			return false
	close()
	return false


func _on_pointer_move(_event: InputEventMouse, pos: Vector2) -> bool:
	var m := _level_at(pos)
	if m == null:
		return false
	var idx := m._row_at(pos - m.position)
	if idx < 0:
		return false
	var item: Dictionary = m._rows[idx].item
	if m._selectable(item) and (String(item.id) != m.selected_id or (m._item_has_children(item) and m.root._levels.size() <= m.level + 1)):
		m._select_item(item, true)
	return false


func _on_pointer_up(event: InputEventMouse, pos: Vector2) -> bool:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not tracking:
		return false
	tracking = false
	var m := _level_at(pos)
	if m == null:
		return false
	var idx := m._row_at(pos - m.position)
	if idx < 0:
		return false
	var item: Dictionary = m._rows[idx].item
	if _item_has_children(item):
		return true
	return _activate(m, item)


# ------------------------------------------------------------------ keyboard (root)

func _on_key(event: Dictionary) -> bool:
	for i in range(_levels.size() - 1, -1, -1):
		var m: Win95Menu = _levels[i]
		if is_instance_valid(m) and m._handle_key(event):
			return true
	return false


func _handle_key(event: Dictionary) -> bool:
	var key: String = event.key
	var selectable: Array = items.filter(func(i): return _selectable(i))
	if selectable.is_empty():
		return key == "Escape"
	var index := -1
	for i in selectable.size():
		if String(selectable[i].id) == selected_id:
			index = i
	if key == "ArrowDown" or key == "ArrowUp" or key == "Home" or key == "End":
		if key == "Home":
			index = 0
		elif key == "End":
			index = selectable.size() - 1
		elif key == "ArrowDown":
			index = (index + 1 + selectable.size()) % selectable.size()
		else:
			index = (index - 1 + selectable.size()) % selectable.size()
		selected_id = String(selectable[index].id)
		root._clear_delay()
		queue_redraw()
		return true
	var item: Dictionary = selectable[maxi(0, index)]
	if key == "ArrowRight" and _item_has_children(item):
		return root._activate(self, item)
	if key == "ArrowLeft" and level > 0:
		root._close_level(self)
		return true
	if key == "Enter":
		return root._activate(self, item)
	if key == "Escape":
		root._close_level(self)
		return true
	if key.length() == 1 and not event.get("ctrlKey", false) and not event.get("altKey", false):
		var labels := selectable.map(func(c): return String(c.get("label", "")))
		var match := Win95MenuState.mnemonic_index(labels, key)
		if match >= 0:
			selected_id = String(selectable[match].id)
			queue_redraw()
			root._activate(self, selectable[match])
			return true
	return false
