class_name Win95StartMenu
extends Control
## The Start menu (port of Win95StartMenu.tsx): 164x235 main menu with the vertical "Windows95"
## strip and seven 32px commands, cascading Programs (launcher groups, multi-column overflow) ->
## group items, Documents, Settings (incl. Launcher Tools...) and Find. Cascades open after
## 220 ms; keyboard navigation uses Win95MenuState; press-drag-release from the Start button
## activates the row under the pointer on release.
## Automation ids: w95.start-command:<Label>, w95.start-level:<n>:first-command.

const M := Win95Tokens.M
const TOP_ITEMS := [
	{"id": "programs", "label": "&Programs", "icon": "programs", "child": true},
	{"id": "documents", "label": "&Documents", "icon": "documents", "child": true},
	{"id": "settings", "label": "&Settings", "icon": "settings", "child": true},
	{"id": "find", "label": "&Find", "icon": "find", "child": true},
	{"id": "help", "label": "&Help", "icon": "help"},
	{"id": "run", "label": "&Run...", "icon": "run"},
	{"id": "shutdown", "label": "Sh&ut Down...", "icon": "shutdown", "separatorBefore": true},
]
const FIND_ITEMS := [
	{"id": "programs", "label": "&Files or Folders...", "icon": "find"},
	{"id": "computer", "label": "&Computer...", "icon": "my-computer"},
	{"id": "internet", "label": "On the &Internet...", "icon": "url"},
]
const SETTINGS_ITEMS := [
	{"id": "control", "label": "&Control Panel", "icon": "control-panel"},
	{"id": "printers", "label": "&Printers", "icon": "printers"},
	{"id": "taskbar", "label": "&Taskbar...", "icon": "taskbar"},
	{"id": "tools", "label": "&Launcher Tools...", "icon": "settings", "separatorBefore": true},
]

var shell: Control
var open_top := ""
var open_group := ""
var level := 0
var indices: Array = [-1, 0, 0]

var _delay: Timer
var _delay_action: Callable = Callable()
var _hover_key := ""
var _press_key := ""
var _registered := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false


func setup(p_shell: Control) -> void:
	shell = p_shell
	_delay = Timer.new()
	_delay.one_shot = true
	_delay.timeout.connect(func():
		if _delay_action.is_valid():
			var a := _delay_action
			_delay_action = Callable()
			a.call())
	add_child(_delay)
	add_to_group("pm_auto")
	shell.input.start_menu_changed.connect(_on_open_changed)


func _on_open_changed(open: bool) -> void:
	visible = open
	_clear_delay()
	if open:
		open_top = ""
		open_group = ""
		level = 0
		indices = [-1, 0, 0]
		_hover_key = ""
		_press_key = ""
		if not _registered:
			_registered = true
			shell.input.set_menu_scope("start-menu", true)
			shell.input.register_key("menu", "start-menu", _on_key)
			shell.input.register_pointer("down", "start-menu", _on_down)
			shell.input.register_pointer("move", "start-menu", _on_move)
			shell.input.register_pointer("up", "start-menu", _on_up)
	elif _registered:
		_registered = false
		shell.input.set_menu_scope("start-menu", false)
		shell.input.unregister_key("menu", "start-menu")
		shell.input.unregister_pointer("down", "start-menu")
		shell.input.unregister_pointer("move", "start-menu")
		shell.input.unregister_pointer("up", "start-menu")
	queue_redraw()


func close() -> void:
	shell.input.close_start_menu()


# ------------------------------------------------------------------- model

func _groups() -> Array:
	return ProgramStore.groups


func _level_items(lv: int) -> Array:
	if lv == 0:
		return TOP_ITEMS
	if lv == 1:
		match open_top:
			"programs": return _groups()
			"settings": return SETTINGS_ITEMS
			"find": return FIND_ITEMS
			_: return []
	if lv == 2 and open_group != "":
		return ProgramStore.find_group(open_group).get("items", [])
	return []


# ---------------------------------------------------------------- geometry

func _vh() -> float:
	return shell.logical_size.y


func main_rect() -> Rect2:
	return Rect2(2, _vh() - M.taskbarHeight - M.startMenuHeight, M.startMenuWidth, M.startMenuHeight)


func _program_rows() -> int:
	return maxi(1, int(floorf((M.startMenuHeight - 4.0) / M.startSubItemHeight)))


func _program_columns() -> int:
	var rows := _program_rows()
	return maxi(1, int(ceilf(float(_groups().size()) / rows)))


func _level_one_top() -> float:
	if open_top == "":
		return -2.0
	var idx := 0
	for i in TOP_ITEMS.size():
		if TOP_ITEMS[i].id == open_top:
			idx = i
	return maxf(-2.0, idx * M.startTopItemHeight - 2.0)


## Rect of cascade level 1 or 2 (absolute), or empty when closed.
func level_rect(lv: int) -> Rect2:
	var mr := main_rect()
	var pad := mr.position + Vector2(2, 2)
	if lv == 1:
		if open_top == "":
			return Rect2()
		var top := _level_one_top()
		if open_top == "programs" and _program_columns() > 1:
			return Rect2(pad.x + 156, pad.y + top, _program_columns() * 164, _program_rows() * 22 + 8)
		var n := maxi(1, _level_items(1).size())
		var h := n * 22 + 8
		if open_top == "settings":
			h = 4 * 22 + 6 + 8
		return Rect2(pad.x + 156, pad.y + top, 164, h)
	if lv == 2:
		if open_top != "programs" or open_group == "":
			return Rect2()
		var level_one_width := _program_columns() * 164
		var natural := M.startMenuWidth - 1 + level_one_width - 1
		var third_left := natural
		if natural + 164 > shell.logical_size.x:
			third_left = M.startMenuWidth - 1 - 164 + 1
		var count := _level_items(2).size()
		var third_h := maxi(1, count) * 22 + 4
		var main_top := _vh() - M.taskbarHeight - M.startMenuHeight
		var gi := 0
		for i in _groups().size():
			if _groups()[i].id == open_group:
				gi = i
		var row := gi % _program_rows()
		var third_top := maxf(-main_top, minf(_level_one_top() + row * 22 - 2, _vh() - M.taskbarHeight - main_top - third_h))
		return Rect2(pad.x + third_left, pad.y + third_top, 164, maxi(1, count) * 22 + 8)
	return Rect2()


## Rows of a level: [{rect: Rect2 (absolute), item: Dictionary, index: int, sep: Rect2?}]
func level_rows(lv: int) -> Array:
	var out: Array = []
	var mr := main_rect()
	if lv == 0:
		var x := mr.position.x + 2 + 21
		var y := mr.position.y + 2
		for i in TOP_ITEMS.size():
			if TOP_ITEMS[i].get("separatorBefore", false):
				y += 7
			out.append({"rect": Rect2(x, y, 139, 32), "item": TOP_ITEMS[i], "index": i})
			y += 32
		return out
	var lr := level_rect(lv)
	if lr.size == Vector2.ZERO:
		return out
	var items := _level_items(lv)
	if items.is_empty():
		out.append({"rect": Rect2(lr.position.x + 4, lr.position.y + 4, 156, 22), "item": {"id": "(empty)", "label": "(Empty)", "disabled": true}, "index": -1})
		return out
	if lv == 1 and open_top == "programs" and _program_columns() > 1:
		var rows := _program_rows()
		for i in items.size():
			out.append({"rect": Rect2(lr.position.x + 4 + (i / rows) * 164, lr.position.y + 4 + (i % rows) * 22, 156, 22), "item": items[i], "index": i})
		return out
	var y := lr.position.y + 4
	for i in items.size():
		if items[i].get("separatorBefore", false):
			y += 6
		out.append({"rect": Rect2(lr.position.x + 4, y, lr.size.x - 8, 22), "item": items[i], "index": i})
		y += 22
	return out


func _row_label(item: Dictionary, lv: int) -> String:
	if item.has("label"):
		return String(item.label)
	return String(item.name)


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	if not visible:
		return
	var mr := main_rect()
	Win95Draw.popup_frame(self, mr)
	var pad := mr.position + Vector2(2, 2)
	var strip := Rect2(pad.x, pad.y, 21, 231)
	Win95Draw.fill(self, strip, Win95Draw.SHADOW)
	_draw_strip_text(strip)
	for r in level_rows(0):
		var item: Dictionary = r.item
		var rect: Rect2 = r.rect
		if item.get("separatorBefore", false):
			Win95Draw.fill(self, Rect2(rect.position.x + 2, rect.position.y - 7 + 1, rect.size.x - 4, 2), Win95Draw.SHADOW)
			Win95Draw.fill(self, Rect2(rect.position.x + 2, rect.position.y - 7 + 3, rect.size.x - 4, 1), Win95Draw.LIGHT)
		var sel: bool = indices[0] == r.index
		if sel:
			Win95Draw.fill(self, rect, Win95Draw.SELECTED)
		Win95Draw.icon(self, Win95IconCatalog.texture(item.icon, "large"), rect.position + Vector2(2, 0))
		Win95Draw.text(self, rect.position + Vector2(46, 10), item.label, Color.WHITE if sel else Win95Draw.TEXT)
		if item.get("child", false):
			Win95Draw.glyph(self, "menu-right", Vector2(rect.end.x - 2 - 14, rect.position.y + 10), Color.WHITE if sel else Win95Draw.TEXT)
	for lv in [1, 2]:
		var lr := level_rect(lv)
		if lr.size == Vector2.ZERO:
			continue
		Win95Draw.popup_frame(self, lr)
		var rows := level_rows(lv)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var item: Dictionary = r.item
			var rect: Rect2 = r.rect
			if item.get("separatorBefore", false):
				Win95Draw.fill(self, Rect2(rect.position.x + 2, rect.position.y - 6 + 1, rect.size.x - 4, 2), Win95Draw.SHADOW)
				Win95Draw.fill(self, Rect2(rect.position.x + 2, rect.position.y - 6 + 3, rect.size.x - 4, 1), Win95Draw.LIGHT)
			var disabled: bool = item.get("disabled", false)
			var sel: bool = level == lv and indices[lv] == r.index and not disabled
			if sel:
				Win95Draw.fill(self, rect, Win95Draw.SELECTED)
			var fg := Color.WHITE if sel else Win95Draw.TEXT
			var icon := "programs" if (lv == 1 and open_top == "programs") else String(item.get("icon", ""))
			if lv == 2:
				icon = String(item.get("icon", ""))
			if icon != "" and not disabled:
				Win95Draw.icon(self, Win95IconCatalog.texture(icon, "small"), rect.position + Vector2(3, 3))
			Win95Draw.text(self, rect.position + Vector2(21, 5), _row_label(item, lv), fg, {"disabled": disabled, "max_width": int(rect.size.x) - 21 - 12})
			if lv == 1 and open_top == "programs" and not disabled:
				Win95Draw.glyph(self, "menu-right", Vector2(rect.end.x - 3 - 14, rect.position.y + 5), fg)


func _draw_strip_text(strip: Rect2) -> void:
	var f := Win95Draw.font().bold_font
	draw_set_transform(Vector2(strip.position.x + 3 + 15, strip.end.y - 3), -PI / 2.0, Vector2.ONE)
	draw_string(f, Vector2.ZERO, "Windows95", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------- hit testing

## {lv, row} for the row under the point, or {}.
func _hit(p: Vector2) -> Dictionary:
	for lv in [2, 1, 0]:
		for r in level_rows(lv):
			if (r.rect as Rect2).has_point(p):
				return {"lv": lv, "row": r}
	return {}


func contains_point(p: Vector2) -> bool:
	if main_rect().has_point(p):
		return true
	return level_rect(1).has_point(p) or level_rect(2).has_point(p)


func _key_of(h: Dictionary) -> String:
	return "%d:%d" % [h.lv, h.row.index] if not h.is_empty() else ""


func _on_down(event: InputEventMouse, pos: Vector2) -> bool:
	if not (event is InputEventMouseButton) or not shell.input.start_menu_open:
		return false
	var h := _hit(pos)
	if contains_point(pos):
		if event.button_index == MOUSE_BUTTON_LEFT:
			_press_key = _key_of(h)
		return true
	var tb: Win95Taskbar = shell.taskbar
	if tb.start_rect().has_point(pos - tb.position):
		return false
	close()
	return false


func _on_move(_event: InputEventMouse, pos: Vector2) -> bool:
	if not shell.input.start_menu_open:
		return false
	var h := _hit(pos)
	var key := _key_of(h)
	if key == _hover_key:
		return false
	_hover_key = key
	if h.is_empty():
		return false
	_hover(h.lv, h.row)
	return false


func _hover(lv: int, row: Dictionary) -> void:
	var item: Dictionary = row.item
	if lv == 0:
		indices[0] = row.index
		level = 0
		_delayed_open(String(item.id) if item.get("child", false) else "", "")
	elif lv == 1:
		if row.index < 0:
			return
		level = 1
		indices[1] = row.index
		if open_top == "programs":
			_delayed_open("programs", String(item.id))
		else:
			_clear_delay()
			open_group = ""
	else:
		if row.index < 0:
			return
		level = 2
		indices[2] = row.index
	queue_redraw()


func _on_up(event: InputEventMouse, pos: Vector2) -> bool:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not shell.input.start_menu_open:
		return false
	var h := _hit(pos)
	var press := _press_key
	_press_key = ""
	var tracking: bool = shell.input.start_tracking
	shell.input.start_tracking = false
	if h.is_empty():
		return false
	if tracking or press == _key_of(h):
		_activate_row(h.lv, h.row)
		return true
	return false


# ------------------------------------------------------------------ delayed open

func _clear_delay() -> void:
	if _delay != null:
		_delay.stop()
	_delay_action = Callable()


func _delayed_open(top: String, group_id: String) -> void:
	_clear_delay()
	_delay_action = func():
		open_top = top
		open_group = group_id
		queue_redraw()
	_delay.start(M.submenuDelayMs / 1000.0)


# ---------------------------------------------------------------- activation

func _activate_row(lv: int, row: Dictionary) -> void:
	var item: Dictionary = row.item
	if row.index < 0 and lv > 0:
		return
	if lv == 0:
		indices[0] = row.index
		_activate_top(String(item.id))
	elif lv == 1:
		indices[1] = row.index
		if open_top == "programs":
			open_group = String(item.id)
			level = 2
			queue_redraw()
		elif open_top == "settings":
			_activate_settings(String(item.id))
		elif open_top == "find":
			_activate_find(String(item.id))
	else:
		shell.launch_item(item)
		close()


func _activate_top(id: String) -> void:
	match id:
		"programs", "documents", "settings", "find":
			open_top = id
			level = 1
			indices[1] = 0
			indices[2] = 0
			_clear_delay()
			queue_redraw()
		"help":
			close()
			Win95Dialogs.open_help(shell)
		"run":
			close()
			Win95Dialogs.open_run(shell)
		"shutdown":
			close()
			Win95Dialogs.open_shutdown(shell)


func _activate_find(id: String) -> void:
	close()
	if id == "programs":
		Win95Dialogs.open_find(shell)
	else:
		var label := String(FIND_ITEMS.filter(func(i): return i.id == id)[0].label).replace("&", "")
		Win95Dialogs.show_message(shell, label, "This search target is not available in the application launcher.", "warning")


func _activate_settings(id: String) -> void:
	close()
	if id == "tools":
		shell.request_show_launcher_tools.emit()
	else:
		var label := String(SETTINGS_ITEMS.filter(func(i): return i.id == id)[0].label).replace("&", "")
		Win95Dialogs.show_message(shell, label, "This Windows system feature is not available in the application launcher.", "warning")


# ------------------------------------------------------------------- keyboard

func _on_key(event: Dictionary) -> bool:
	if not shell.input.start_menu_open:
		return false
	var key: String = event.key
	if not key in ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Home", "End", "Enter", "Escape"]:
		if key.length() != 1:
			return false
		var items := _level_items(level)
		var labels := items.map(func(i): return i.label if i.has("label") else "&" + String(i.name))
		var m := Win95MenuState.mnemonic_index(labels, key)
		if m < 0:
			return false
		indices[level] = m
		var rows := level_rows(level)
		for r in rows:
			if r.index == m:
				_activate_row(level, r)
		queue_redraw()
		return true
	var items := _level_items(level)
	var selected: Variant = null
	if int(indices[level]) >= 0 and int(indices[level]) < items.size():
		selected = items[int(indices[level])]
	var has_child := false
	if level == 0:
		has_child = selected != null and selected.get("child", false)
	elif level == 1:
		has_child = open_top == "programs" and selected != null
	var counts := [TOP_ITEMS.size(), _level_items(1).size(), _level_items(2).size()]
	var result := Win95MenuState.reduce_navigation({"level": level, "indices": indices}, key, counts, has_child)
	indices = result.indices
	while indices.size() < 3:
		indices.append(0)
	queue_redraw()
	match result.action:
		"close-all":
			close()
			return true
		"close-level":
			level = result.level
			if result.level < 2:
				open_group = ""
			if result.level == 0:
				open_top = ""
			return true
		"open-child":
			if level == 0 and selected != null:
				open_top = String(selected.id)
				level = 1
			elif level == 1 and open_top == "programs" and selected != null:
				open_group = String(selected.id)
				level = 2
			return true
		"activate":
			if selected != null:
				var rows2 := level_rows(level)
				for r in rows2:
					if r.index == int(indices[level]):
						_activate_row(level, r)
			return true
	return true


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if not visible:
		return null
	if id.begins_with("w95.start-command:"):
		var label := id.substr("w95.start-command:".length())
		for r in level_rows(0):
			if String(r.item.label).replace("&", "") == label:
				return r.rect
	if id.begins_with("w95.start-level:"):
		var lv := int(id.get_slice(":", 1))
		var rows := level_rows(lv)
		if rows.size() > 0:
			return rows[0].rect
	return null
