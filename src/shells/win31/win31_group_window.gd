class_name Win31GroupWindow
extends Control
## One MDI child window of the Program Manager (Win31MDIWindow.tsx + .wfw-child-window CSS):
## frame, caption with system menu / minimize / maximize, eight resize zones, keyboard Move/Size
## mode and the program item area.

signal activate_requested(group_id: String)
signal maximize_requested(group_id: String)
signal launch_requested(item: Dictionary)

var group_id := ""
var client: Control               ## Win31MdiClient (client size, state updates, popup layer)
var active := false
var keyboard_mode := ""           ## "" | "move" | "size"

var grid: Win31ItemGrid
var _menu: Win31PopupMenu
var _pressed_button := ""
var _press_pos := Vector2.ZERO
var _op := {}                     ## active mouse drag: {kind: move|resize, dir, start, state}
var _live := {}                   ## live rect during drag (not persisted until release)
var _kb_initial := {}
var _born_frame := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	add_to_group("pm_auto")
	grid = Win31ItemGrid.new()
	add_child(grid)
	grid.launch_requested.connect(func(item): launch_requested.emit(item))


func _group() -> Dictionary:
	return ProgramStore.find_group(group_id)


func state() -> Dictionary:
	return Types.get_group_window_state(_group(), "win31")


func _client_size() -> Vector2:
	return client.client_size() if client != null else Vector2(634, 430)


## Positions the window (and its item area) from the stored state, or the live drag rect.
func apply_state() -> void:
	var st := state()
	if st.get("minimized", false):
		visible = false
		return
	visible = true
	var cs := _client_size()
	var r: Rect2
	if not _live.is_empty():
		r = Rect2(_live.x, _live.y, _live.width, _live.height)
	else:
		r = Win31Arrange.window_rect(st, cs.x, cs.y)
	position = r.position  # relative to the client's 1px-inset inner area
	size = r.size
	_layout()
	queue_redraw()


func _layout() -> void:
	grid.position = Vector2(5, 25)
	grid.size = Vector2(maxf(0.0, size.x - 10), maxf(0.0, size.y - 30))
	grid.client = client
	grid.group_id = group_id
	grid.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and grid != null:
		_layout()


# ---------------------------------------------------------------- geometry

func caption_rect() -> Rect2:
	return Rect2(4, 4, size.x - 8, 18)


func system_button_rect() -> Rect2:
	return Rect2(5, 5, 16, 16)


func min_button_rect() -> Rect2:
	return Rect2(size.x - 39, 5, 16, 16)


func max_button_rect() -> Rect2:
	return Rect2(size.x - 21, 5, 16, 16)


func content_rect() -> Rect2:
	return Rect2(4, 24, size.x - 8, size.y - 28)


func button_at(local: Vector2) -> String:
	if system_button_rect().has_point(local):
		return "system"
	if min_button_rect().has_point(local):
		return "min"
	if max_button_rect().has_point(local):
		return "max"
	return ""


func is_maximized() -> bool:
	return bool(state().get("maximized", false))


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var g := _group()
	if g.is_empty():
		return
	var maximized := is_maximized()
	Win31Chrome.window_frame(self, Rect2(Vector2.ZERO, size))
	Win31Chrome.caption(self, caption_rect(), String(g.name), active)
	Win31Chrome.caption_button(self, system_button_rect(), "system", _pressed_button == "system")
	Win31Chrome.caption_button(self, min_button_rect(), "down", _pressed_button == "min")
	Win31Chrome.caption_button(self, max_button_rect(), "restore" if maximized else "up", _pressed_button == "max")
	var c := content_rect()
	Px.fill_rect(self, c, Pal.WHITE)
	Px.hline(self, c.position.x, c.position.y, c.size.x, Pal.SHADOW)
	Px.vline(self, c.position.x, c.position.y, c.size.y, Pal.SHADOW)
	Px.hline(self, c.position.x, c.end.y - 1, c.size.x, Pal.WHITE)
	Px.vline(self, c.end.x - 1, c.position.y, c.size.y, Pal.WHITE)
	if keyboard_mode != "":
		Px.focus_rect(self, Rect2(Vector2.ZERO, size).grow(3), Pal.BLACK)


# --------------------------------------------------------------- activation

func _activate() -> void:
	activate_requested.emit(group_id)


func restore() -> void:
	var st := state()
	var u := {"minimized": false, "maximized": false}
	for k in [["restoreX", "x"], ["restoreY", "y"], ["restoreWidth", "width"], ["restoreHeight", "height"]]:
		if st.has(k[0]):
			u[k[1]] = st[k[0]]
	client.update_state(group_id, u)
	_activate()


func maximize() -> void:
	var st := state()
	if st.get("maximized", false):
		restore()
		return
	client.update_state(group_id, {
		"maximized": true, "minimized": false,
		"restoreX": st.x, "restoreY": st.y, "restoreWidth": st.width, "restoreHeight": st.height,
	})
	maximize_requested.emit(group_id)


func minimize() -> void:
	client.update_state(group_id, {"minimized": true, "maximized": false})
	UIState.set_win31_selection({"kind": "groupIcon", "groupId": group_id})


# ---------------------------------------------------------------- system menu

func toggle_system_menu() -> void:
	if _menu != null:
		close_system_menu()
	else:
		open_system_menu()


func open_system_menu() -> void:
	if _menu != null or client == null:
		return
	_menu = Win31PopupMenu.new()
	_menu.min_width = 140
	_menu.command_chosen.connect(_system_command)
	_menu.dismissed.connect(close_system_menu)
	client.popup_layer.add_child(_menu)
	_menu.set_items(Win31Commands.system_items("child-", is_maximized()), false)
	_menu.position = position + Vector2(4, 4 + 17)
	_born_frame = Engine.get_process_frames()


func close_system_menu() -> void:
	if _menu != null:
		if is_instance_valid(_menu):
			if _menu.get_parent():
				_menu.get_parent().remove_child(_menu)
			_menu.queue_free()
		_menu = null


func has_system_menu() -> bool:
	return _menu != null


func _system_command(command: String) -> void:
	close_system_menu()
	match command:
		"child-restore":
			restore()
		"child-move":
			begin_keyboard_mode("move")
		"child-size":
			begin_keyboard_mode("size")
		"child-minimize", "child-close":
			minimize()
		"child-maximize":
			maximize()


func begin_keyboard_mode(mode: String) -> void:
	keyboard_mode = mode
	_kb_initial = state().duplicate(true)
	_born_frame = Engine.get_process_frames()
	queue_redraw()


func _exit_tree() -> void:
	close_system_menu()


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event)
		else:
			_release(event)
	elif event is InputEventMouseButton and event.pressed:
		_activate()  # non-left presses still raise the window (onPointerDown on the root)
	elif event is InputEventMouseMotion:
		_motion(event)


func _press(ev: InputEventMouseButton) -> void:
	var local := ev.position
	var st := state()
	if not st.get("maximized", false) and _op.is_empty():
		var dir := Win31Arrange.resize_zone(local, size.x, size.y)
		if dir != "":
			_op = {"kind": "resize", "dir": dir, "start": ev.global_position, "state": st.duplicate(true)}
			_live = {"x": st.x, "y": st.y, "width": st.width, "height": st.height}
			accept_event()
			return
	var btn := button_at(local)
	if btn == "system":
		_pressed_button = "system"  # stopPropagation: neither drags nor activates
		if ev.double_click:
			maximize()  # the dblclick bubbles from the button to the caption handler
			_pressed_button = ""
		queue_redraw()
		accept_event()
		return
	_activate()
	if btn != "":
		_pressed_button = btn
		queue_redraw()
		accept_event()
		return
	if caption_rect().has_point(local):
		if ev.double_click:
			maximize()
			accept_event()
			return
		if not st.get("maximized", false):
			_op = {"kind": "move", "start": ev.global_position, "state": st.duplicate(true)}
			_live = {"x": st.x, "y": st.y, "width": st.width, "height": st.height}
		accept_event()
		return
	accept_event()


func _release(ev: InputEventMouseButton) -> void:
	if _pressed_button != "":
		var btn := _pressed_button
		_pressed_button = ""
		queue_redraw()
		if button_at(ev.position) == btn:
			match btn:
				"system":
					toggle_system_menu()
				"min":
					minimize()
				"max":
					maximize()
		accept_event()
		return
	if not _op.is_empty():
		var op := _op
		_op = {}
		_live = {}
		var delta: Vector2 = ev.global_position - op.start
		var cs := _client_size()
		if op.kind == "move":
			var pos := Win31Arrange.drag_position(op.state, delta, cs.x, cs.y)
			client.update_state(group_id, {"x": pos.x, "y": pos.y})
		else:
			client.update_state(group_id, Win31Arrange.resize_rect(op.dir, op.state, delta, cs.x, cs.y))
		apply_state()
		accept_event()


func _motion(ev: InputEventMouseMotion) -> void:
	if _op.is_empty():
		mouse_default_cursor_shape = _cursor_for(ev.position)
		return
	var delta: Vector2 = ev.global_position - _op.start
	var cs := _client_size()
	var st: Dictionary = _op.state
	if _op.kind == "move":
		var x := maxf(0.0, minf(cs.x - float(st.width), float(st.x) + delta.x))
		var y := maxf(0.0, minf(cs.y - Win31Arrange.CAPTION_KEEP_VISIBLE, float(st.y) + delta.y))
		_live = {"x": Win31Arrange.js_round(x), "y": Win31Arrange.js_round(y), "width": st.width, "height": st.height}
	else:
		_live = Win31Arrange.resize_rect(_op.dir, st, delta, cs.x, cs.y)
	apply_state()
	accept_event()


func _input(event: InputEvent) -> void:
	if _menu != null and event is InputEventMouseButton and event.pressed:
		if not _menu.get_global_rect().has_point(event.position) and not (event.button_index == MOUSE_BUTTON_LEFT and \
				get_global_rect().has_point(event.position) and system_button_rect().has_point(event.position - get_global_rect().position)):
			close_system_menu()
	if keyboard_mode != "" and event is InputEventKey and event.pressed:
		if Engine.get_process_frames() == _born_frame:
			return
		_keyboard_mode_key(event)


func _keyboard_mode_key(ev: InputEventKey) -> void:
	var key := Win31Commands.key_name(ev)
	if key == "escape":
		get_viewport().set_input_as_handled()
		client.update_state(group_id, _kb_initial)
		keyboard_mode = ""
		apply_state()
		return
	if key == "enter":
		get_viewport().set_input_as_handled()
		keyboard_mode = ""
		queue_redraw()
		return
	var cs := _client_size()
	var step := Win31Commands.child_key_step(keyboard_mode, state(), key, ev.shift_pressed, cs.x, cs.y)
	if step.is_empty():
		return
	get_viewport().set_input_as_handled()
	client.update_state(group_id, step)
	apply_state()


func _cursor_for(pos: Vector2) -> Control.CursorShape:
	if not is_maximized():
		match Win31Arrange.resize_zone(pos, size.x, size.y):
			"n", "s":
				return Control.CURSOR_VSIZE
			"e", "w":
				return Control.CURSOR_HSIZE
			"ne", "sw":
				return Control.CURSOR_BDIAGSIZE
			"nw", "se":
				return Control.CURSOR_FDIAGSIZE
		if caption_rect().has_point(pos) and button_at(pos) == "":
			return Control.CURSOR_MOVE
	return Control.CURSOR_ARROW


## Automation ids resolved by the shell: caption buttons ("Minimize", "Maximize"/"Restore").
func button_global_rect(label: String) -> Rect2:
	var origin := get_global_rect().position
	match label:
		"Minimize":
			return Rect2(origin + min_button_rect().position, Vector2(16, 16))
		"Maximize":
			if not is_maximized():
				return Rect2(origin + max_button_rect().position, Vector2(16, 16))
		"Restore":
			if is_maximized():
				return Rect2(origin + max_button_rect().position, Vector2(16, 16))
		"System":
			return Rect2(origin + system_button_rect().position, Vector2(16, 16))
	return Rect2()
