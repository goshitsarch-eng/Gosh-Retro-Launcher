class_name Win95Taskbar
extends Control
## The taskbar (port of Win95Taskbar.tsx): Start button, one task button per primary window
## (click = minimize / focus / restore, right-click = window menu, drag-hover activates after 500 ms),
## background context menu (Cascade / Tile / Minimize All / Properties) and the notification
## tray with the clock. In visual captures the clock shows Engine meta "pm_capture_clock".

const M := Win95Tokens.M

var shell: Control

var _clock := ""
var _clock_timer: Timer
var _pressed_task := ""
var _start_press := false
var _menu: Win95Menu
var _hover_id := ""
var _hover_timer: Timer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	tooltip_text = ""


func setup(p_shell: Control) -> void:
	shell = p_shell
	add_to_group("pm_auto")
	set_meta("auto_id", "w95.taskbar")
	_clock = _format_clock()
	_clock_timer = Timer.new()
	_clock_timer.wait_time = 20.0
	_clock_timer.timeout.connect(func():
		var c := _format_clock()
		if c != _clock:
			_clock = c
			queue_redraw())
	add_child(_clock_timer)
	_clock_timer.autostart = true
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.timeout.connect(_on_hover_timeout)
	add_child(_hover_timer)
	shell.windows.changed.connect(queue_redraw)
	ProgramStore.groups_changed.connect(queue_redraw)
	shell.input.start_menu_changed.connect(func(_o): queue_redraw())
	shell.input.register_pointer("move", "taskbar-drag-hover", _on_drag_move)


func _format_clock() -> String:
	if Engine.has_meta("pm_capture") and Engine.has_meta("pm_capture_clock"):
		return String(Engine.get_meta("pm_capture_clock"))
	var t := Time.get_datetime_dict_from_system()
	var h: int = t.hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, t.minute, "AM" if t.hour < 12 else "PM"]


# ------------------------------------------------------------------- layout

func start_rect() -> Rect2:
	return Rect2(2, 4, M.startButtonWidth, M.startButtonHeight)


func tray_rect() -> Rect2:
	return Rect2(size.x - 2 - M.trayWidth, 4, M.trayWidth, 22)


## Task entries in taskbar order with their rects.
func task_buttons() -> Array:
	var out: Array = []
	var entries: Array = []
	for e in shell.windows.windows:
		if e.kind == "group" and ProgramStore.find_group(e.groupId).is_empty():
			continue
		entries.append(e)
	if entries.is_empty():
		return out
	var avail := size.x - 4 - M.startButtonWidth - M.trayWidth - 4  # start | tasks | tray with 2px gaps
	var n := entries.size()
	var w := minf(160.0, (avail - (n - 1) * 2.0) / n)
	w = maxf(22.0, floorf(w))
	var x := 2.0 + M.startButtonWidth + 2.0
	for e in entries:
		out.append({"entry": e, "rect": Rect2(x, 4, w, 22)})
		x += w + 2
	return out


func _task_title(e: Dictionary) -> String:
	if e.kind == "my-computer":
		return "My Computer"
	if e.kind == "find":
		return "Find: Programs"
	return String(ProgramStore.find_group(e.groupId).get("name", ""))


func _task_icon(e: Dictionary) -> String:
	if e.kind == "my-computer":
		return "my-computer"
	if e.kind == "find":
		return "find"
	return String(ProgramStore.find_group(e.groupId).get("icon", "folder"))


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	Win95Draw.fill(self, Rect2(Vector2.ZERO, size), Win95Draw.FACE)
	Win95Draw.fill(self, Rect2(0, 0, size.x, 1), Win95Draw.HIGHLIGHT)
	Win95Draw.fill(self, Rect2(0, 1, size.x, 1), Win95Draw.LIGHT)
	# Start button
	var sr := start_rect()
	var open: bool = shell.input.start_menu_open
	var down := open or _start_press
	var off := Vector2(1, 1) if down else Vector2.ZERO
	if down:
		Win95Draw.pressed(self, sr)
		Win95Draw.dither_checker(self, sr.grow(-2), sr.position + Vector2(2, 2), Win95Draw.HIGHLIGHT)
		Win95Draw.dotted_rect(self, sr.grow(-5), Win95Draw.TEXT)
	else:
		Win95Draw.raised(self, sr)
	Win95Draw.icon(self, Win95IconCatalog.texture("windows-logo", "small"), sr.position + Vector2(4, 3) + off)
	Win95Draw.text(self, sr.position + Vector2(22, 5) + off, "Start", Win95Draw.TEXT, {"bold": true})
	# tasks
	var active_id: String = shell.windows.active_window_id
	for t in task_buttons():
		var e: Dictionary = t.entry
		var r: Rect2 = t.rect
		var minimized: bool = shell.windows.entry_is_minimized(e)
		var state := Win95TaskbarState.button_state(e.id, active_id, minimized)
		var active := state == "active"
		if active or _pressed_task == e.id:
			Win95Draw.pressed(self, r)
			if active:
				Win95Draw.dither_checker(self, r.grow(-2), r.position + Vector2(2, 2), Win95Draw.HIGHLIGHT)
		else:
			Win95Draw.raised(self, r)
		var o := Vector2(1, 1) if (active or _pressed_task == e.id) else Vector2.ZERO
		Win95Draw.icon(self, Win95IconCatalog.texture(_task_icon(e), "small"), r.position + Vector2(6, 3) + o)
		if r.size.x > 40:
			Win95Draw.text(self, r.position + Vector2(25, 5) + o, _task_title(e), Win95Draw.TEXT, {"bold": active, "max_width": mini(126, int(r.size.x) - 33)})
	# tray
	var tr := tray_rect()
	Win95Draw.status(self, tr)
	var cw := Win95Draw.measure(_clock)
	Win95Draw.text(self, Vector2(tr.position.x + 4 + int((55 - cw + 1) / 2), tr.position.y + 5), _clock, Win95Draw.TEXT)


# -------------------------------------------------------------------- input

func _task_at(p: Vector2) -> Dictionary:
	for t in task_buttons():
		if (t.rect as Rect2).has_point(p):
			return t.entry
	return {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var e := _task_at(mb.position)
			_open_menu(get_global_transform() * mb.position, e)
			accept_event()


func _press(p: Vector2) -> void:
	if start_rect().has_point(p):
		_start_press = true
		if not shell.input.start_menu_open:
			shell.input.start_tracking = true
			shell.input.open_start_menu()
		else:
			shell.input.start_tracking = false
			shell.input.close_start_menu()
		queue_redraw()
		return
	var e := _task_at(p)
	if not e.is_empty():
		_pressed_task = e.id
		queue_redraw()


func _release(p: Vector2) -> void:
	_start_press = false
	var id := _pressed_task
	_pressed_task = ""
	queue_redraw()
	if id != "":
		var e := _task_at(p)
		if not e.is_empty() and e.id == id:
			click_task(e)


func click_task(e: Dictionary) -> void:
	var windows: Win95WindowStore = shell.windows
	var minimized := windows.entry_is_minimized(e)
	match Win95TaskbarState.click_action(e.id, windows.active_window_id, minimized):
		"minimize":
			windows.minimize_entry(e)
		"restore-focus":
			activate_window(e)
		_:
			windows.focus_window(e.id)


func activate_window(e: Dictionary) -> void:
	shell.windows.unminimize(e)
	shell.windows.focus_window(e.id)


func _on_drag_move(_event: InputEventMouse, pos: Vector2) -> bool:
	if not shell.dragging:
		_set_hover("")
		return false
	var local := pos - global_position
	var e := _task_at(local) if Rect2(Vector2.ZERO, size).has_point(local) else {}
	_set_hover(String(e.get("id", "")))
	return false


func _set_hover(id: String) -> void:
	if _hover_id == id:
		return
	_hover_id = id
	_hover_timer.stop()
	if id != "":
		_hover_timer.start(0.5)


func _on_hover_timeout() -> void:
	var e: Dictionary = shell.windows.find_entry(_hover_id)
	if not e.is_empty():
		activate_window(e)
	_hover_id = ""


# --------------------------------------------------------------------- menus

func _close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.close()
	_menu = null


func _visible_entries() -> Array:
	return shell.windows.windows.filter(func(e): return not shell.windows.entry_is_minimized(e))


func _arrange(mode: String) -> void:
	var visible := _visible_entries()
	if visible.is_empty():
		return
	var work: Vector2 = shell.desktop_size()
	for i in visible.size():
		var r: Dictionary
		match mode:
			"cascade":
				r = Win95Geometry.rect(18 + i * 24, 18 + i * 24, maxf(250, work.x - 180), maxf(150, work.y - 140))
			"horizontal":
				r = Win95Geometry.rect(0, floorf(i * work.y / visible.size()), work.x, ceilf(work.y / visible.size()))
			_:
				r = Win95Geometry.rect(floorf(i * work.x / visible.size()), 0, ceilf(work.x / visible.size()), work.y)
		shell.windows.apply_rect(visible[i], r)


func _minimize_all() -> void:
	for e in _visible_entries():
		shell.windows.minimize_entry(e)


func _open_menu(at: Vector2, entry: Dictionary) -> void:
	_close_menu()
	var items: Array
	if entry.is_empty():
		var any := not _visible_entries().is_empty()
		items = [
			{"id": "cascade", "label": "&Cascade Windows", "disabled": not any, "onSelect": func(): _arrange("cascade")},
			{"id": "tile-h", "label": "Tile Windows &Horizontally", "disabled": not any, "onSelect": func(): _arrange("horizontal")},
			{"id": "tile-v", "label": "Tile Windows &Vertically", "disabled": not any, "onSelect": func(): _arrange("vertical")},
			{"id": "minimize-all", "label": "&Minimize All Windows", "disabled": not any, "onSelect": _minimize_all},
			{"id": "sep", "separator": true},
			{"id": "properties", "label": "&Properties", "icon": "properties", "onSelect": func(): shell.request_show_launcher_tools.emit()},
		]
	else:
		var s: Dictionary = shell.windows.entry_state(entry)
		var win: Win95Window = shell.desktop.window_for(entry.id)
		items = [
			{"id": "restore", "label": "&Restore", "disabled": not s.minimized and not s.maximized, "onSelect": func(): shell.windows.restore_entry(entry)},
			{"id": "move", "label": "&Move", "disabled": s.minimized, "onSelect": func(): shell.windows.request_window_command(entry.id, "move"); _run_request(win)},
			{"id": "size", "label": "&Size", "disabled": s.minimized or s.maximized, "onSelect": func(): shell.windows.request_window_command(entry.id, "size"); _run_request(win)},
			{"id": "minimize", "label": "Mi&nimize", "disabled": s.minimized, "onSelect": func(): shell.windows.minimize_entry(entry)},
			{"id": "maximize", "label": "Ma&ximize", "disabled": s.maximized, "onSelect": func(): shell.windows.maximize_entry(entry)},
			{"id": "sep", "separator": true},
			{"id": "close", "label": "&Close", "defaultItem": true, "onSelect": func(): shell.windows.close_entry(entry)},
		]
	_menu = Win95Menu.open(shell, items, at, {"bottom_inset": M.taskbarHeight, "on_close": func(): _menu = null})


func _run_request(win: Win95Window) -> void:
	if win == null:
		return
	var req: Dictionary = shell.windows.requested_command
	if req.is_empty() or req.id != win.entry_id:
		return
	win.request_command(req.command)
	shell.windows.clear_window_command(int(req.nonce))


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if id == "w95.start-button":
		return Rect2(global_position + start_rect().position, start_rect().size)
	if id == "w95.task-window:first":
		var tb := task_buttons()
		if tb.size() > 0:
			return Rect2(global_position + (tb[0].rect as Rect2).position, (tb[0].rect as Rect2).size)
	return null
