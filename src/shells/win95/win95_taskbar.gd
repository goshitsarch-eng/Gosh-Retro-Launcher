class_name Win95Taskbar
extends Control
## The taskbar (port of Win95Taskbar.tsx): Start button, one task button per primary window
## (click = minimize / focus / restore, right-click = window menu, drag-hover activates after 500 ms)
## and per open sticky note (click = front + keyboard, right-click = the note menu; see
## Win95TaskbarState.task_list), background context menu (Cascade / Tile / Minimize All / Properties)
## and the notification tray with the clock. In visual captures the clock shows Engine meta
## "pm_capture_clock".

const M := Win95Tokens.M

var shell: Control
## Task ids in button order (Win95TaskbarState.merge_order keeps a button where it is).
var _order: Array = []

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
	A11y.track(self)


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
	ProgramStore.groups_changed.connect(queue_redraw)  # renamed folders and notes
	if shell.has_signal("notes_changed"):
		shell.notes_changed.connect(queue_redraw)
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


## The task buttons in taskbar order (Win95TaskbarState.task_list) with their rects:
## [{id, kind: "window"|"note", key, state, entry (the window entry, {} for a note), rect}].
func task_buttons() -> Array:
	var wins: Array = []
	var entries := {}
	for e in shell.windows.windows:
		if e.kind == "group" and ProgramStore.find_group(e.groupId).is_empty():
			continue
		wins.append({"id": e.id, "minimized": shell.windows.entry_is_minimized(e)})
		entries[e.id] = e
	var note_ids: Array = []
	if shell.has_method("open_notes"):
		for n in shell.open_notes():
			note_ids.append(n.item_id)
	var tasks := Win95TaskbarState.task_list(wins, note_ids, _order, shell.windows.active_window_id, shell.windows.active_note_id())
	_order = tasks.map(func(t): return t.id)
	if tasks.is_empty():
		return tasks
	var avail := size.x - 4 - M.startButtonWidth - M.trayWidth - 4  # start | tasks | tray with 2px gaps
	var n := tasks.size()
	var w := minf(160.0, (avail - (n - 1) * 2.0) / n)
	w = maxf(22.0, floorf(w))
	var x := 2.0 + M.startButtonWidth + 2.0
	for t in tasks:
		t["entry"] = entries.get(t.key, {}) if t.kind == "window" else {}
		t["rect"] = Rect2(x, 4, w, 22)
		x += w + 2
	return tasks


func _task_title(t: Dictionary) -> String:
	if t.kind == "note":
		return String(ProgramStore.locate_item(String(t.key)).get("item", {}).get("name", "Note"))
	var e: Dictionary = t.entry
	if e.kind == "my-computer":
		return "My Computer"
	if e.kind == "find":
		return "Find: Programs"
	return String(ProgramStore.find_group(e.groupId).get("name", ""))


func _task_icon(t: Dictionary) -> String:
	if t.kind == "note":
		return Notes.ICON
	var e: Dictionary = t.entry
	if e.kind == "my-computer":
		return "my-computer"
	if e.kind == "find":
		return "find"
	return String(ProgramStore.find_group(e.groupId).get("icon", "folder"))


## The button text: `title` shortened with "..." to fit `room` pixels, its "&" kept literal.
static func fit_title(title: String, room: int, bold: bool) -> String:
	var measure := func(s: String) -> int: return Win95Draw.measure(s.replace("&", "&&"), bold)
	return Win95TaskbarState.ellipsize(title, room, measure).replace("&", "&&")


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
	Win95Draw.text(self, sr.position + Vector2(22, 4) + off, "Start", Win95Draw.TEXT, {"bold": true})
	# tasks
	for t in task_buttons():
		var r: Rect2 = t.rect
		var active: bool = t.state == "active"
		if active or _pressed_task == t.id:
			Win95Draw.pressed(self, r)
			if active:
				Win95Draw.dither_checker(self, r.grow(-2), r.position + Vector2(2, 2), Win95Draw.HIGHLIGHT)
		else:
			Win95Draw.raised(self, r)
		var o := Vector2.ZERO  # .pressed/:active only change the border and shadow, not the content position
		Win95Draw.icon(self, Win95IconCatalog.texture(_task_icon(t), "small"), r.position + Vector2(6, 3) + o)
		if r.size.x > 40:
			var room := mini(126, int(r.size.x) - 33)
			Win95Draw.text(self, r.position + Vector2(25, 4) + o, fit_title(_task_title(t), room, active), Win95Draw.TEXT, {"bold": active, "max_width": room})
	# tray
	var tr := tray_rect()
	Win95Draw.status(self, tr)
	var cw := Win95Draw.measure(_clock)
	Win95Draw.text(self, Vector2(tr.position.x + 4 + int((55 - cw + 1) / 2), tr.position.y + 4), _clock, Win95Draw.TEXT)


# -------------------------------------------------------------------- input

## The task button under `p` (see task_buttons), or {}.
func _task_at(p: Vector2) -> Dictionary:
	for t in task_buttons():
		if (t.rect as Rect2).has_point(p):
			return t
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
			var t := _task_at(mb.position)
			_open_menu(get_global_transform() * mb.position, t)
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
	var t := _task_at(p)
	if not t.is_empty():
		_pressed_task = t.id
		queue_redraw()


func _release(p: Vector2) -> void:
	_start_press = false
	var id := _pressed_task
	_pressed_task = ""
	queue_redraw()
	if id != "":
		var t := _task_at(p)
		if not t.is_empty() and t.id == id:
			click_button(t)


## A click on a task button (see task_buttons): windows as click_task; a note comes to the front
## with the keyboard, and its button while it is the active one keeps it there
## (Win95TaskbarState.note_click_action).
func click_button(t: Dictionary) -> void:
	if t.kind != "note":
		click_task(t.entry)
		return
	if Win95TaskbarState.note_click_action(t.state == "active") == "keep" and shell.note_has_focus():
		return
	shell.open_note(String(t.key))  # front + keyboard (back, for "keep", if a dialog took it)


## A click on a window's task button: minimize the active one, restore a minimized one, else focus it.
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
	var t := _task_at(local) if Rect2(Vector2.ZERO, size).has_point(local) else {}
	_set_hover(String(t.get("id", "")))
	return false


func _set_hover(id: String) -> void:
	if _hover_id == id:
		return
	_hover_id = id
	_hover_timer.stop()
	if id != "":
		_hover_timer.start(0.5)


func _on_hover_timeout() -> void:
	if Win95TaskbarState.is_note_task(_hover_id):
		if shell.note_window(Win95TaskbarState.note_item_id(_hover_id)) != null:
			shell.activate_task(_hover_id)
	else:
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


## The menu for a right-click at `at`: the note menu on a note's button, the window menu on a
## window's, the taskbar menu elsewhere (`task` is {} then; see task_buttons).
func _open_menu(at: Vector2, task: Dictionary) -> void:
	_close_menu()
	var opts := {"bottom_inset": M.taskbarHeight, "on_close": func(): _menu = null}
	if task.get("kind", "") == "note":
		_menu = shell.open_note_menu(String(task.key), at, opts)
		return
	var entry: Dictionary = task.get("entry", {})
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
	_menu = Win95Menu.open(shell, items, at, opts)


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
	if id.begins_with("w95.task:"):  # w95.task:<window entry id> or w95.task:note:<note item id>
		for t in task_buttons():
			if t.id == id.substr(9):
				return Rect2(global_position + (t.rect as Rect2).position, (t.rect as Rect2).size)
	return null


# ------------------------------------------------------------------ accessibility

var _a11y_parts: Array = []


## Start button, one button per task (pressed = active window) and the clock.
func a11y_part_specs() -> Array:
	var open: bool = shell.input.start_menu_open
	var start := A11y.button("Start")
	start["bounds"] = start_rect()
	start["popup"] = DisplayServer.POPUP_MENU
	start["expanded"] = open
	start["click"] = func(_d: Variant) -> void: shell.input.toggle_start_menu()
	var out := [start]
	for t in task_buttons():
		var spec := A11y.button(_task_title(t).replace("&", "&&"))
		spec["bounds"] = t.rect
		spec["description"] = t.state if t.state != "inactive" else ""
		spec["click"] = _a11y_click_task.bind(String(t.id))
		out.append(spec)
	out.append(A11y.static_text(_clock, tray_rect()))
	return out


func _a11y_click_task(_data: Variant, id: String) -> void:
	for t in task_buttons():
		if t.id == id:
			click_button(t)
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var ae := get_accessibility_element()
		A11y.apply(ae, {"role": DisplayServer.ROLE_CONTAINER, "name": "Taskbar"})
		if shell != null:
			A11y.sync_children(ae, _a11y_parts, a11y_part_specs())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		_a11y_parts.clear()
