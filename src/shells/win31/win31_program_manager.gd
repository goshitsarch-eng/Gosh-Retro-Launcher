class_name Win31ProgramManager
extends Control
## The outer "Program Manager" window (.wfw-program-manager): 3px frame, caption with control
## menu / minimize / maximize, the menu bar and the MDI client. The same node is the full-window
## frame (OS window drag/resize) or the movable internal window in desktop mode.

signal command_chosen(command: String)
signal minimize_requested
signal maximize_toggle_requested
## Desktop mode: caption drag (phase "move"/"end", pointer delta in logical px since the press).
signal desktop_move(phase: String, delta: Vector2)
## Desktop mode: frame resize drag ("resize"/"end", direction, delta).
signal desktop_resize(phase: String, direction: String, delta: Vector2)

const FRAME := 4              ## 1px border + 3px padding
const CAPTION_H := 18
const MENU_H := 20
const RESIZE_CORNER := 8

var active := true
var maximized := false
var desktop_window := false

var menu_bar: Win31MenuBar
var client: Win31MdiClient
var popup_layer: Control

var _sys_menu: Win31PopupMenu
var _pressed_button := ""
var _caption_drag := {}
var _frame_drag := {}
var _born_frame := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	add_to_group("pm_auto")
	menu_bar = Win31MenuBar.new()
	add_child(menu_bar)
	client = Win31MdiClient.new()
	add_child(client)
	popup_layer = Control.new()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)
	menu_bar.popup_layer = popup_layer
	menu_bar.command_chosen.connect(func(c): command_chosen.emit(c))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and menu_bar != null:
		_layout()


func apply_layout() -> void:
	_layout()


func _layout() -> void:
	menu_bar.position = Vector2(FRAME, FRAME + CAPTION_H)
	menu_bar.size = Vector2(maxf(0.0, size.x - FRAME * 2), MENU_H)
	client.position = Vector2(FRAME, FRAME + CAPTION_H + MENU_H)
	client.size = Vector2(maxf(0.0, size.x - FRAME * 2), maxf(0.0, size.y - FRAME * 2 - CAPTION_H - MENU_H))
	popup_layer.position = Vector2.ZERO
	popup_layer.size = size
	queue_redraw()


# ---------------------------------------------------------------- geometry

func caption_rect() -> Rect2:
	return Rect2(FRAME, FRAME, size.x - FRAME * 2, CAPTION_H)


func system_button_rect() -> Rect2:
	return Rect2(FRAME + 1, FRAME + 1, 16, 16)


func min_button_rect() -> Rect2:
	return Rect2(size.x - FRAME - 35, FRAME + 1, 16, 16)


func max_button_rect() -> Rect2:
	return Rect2(size.x - FRAME - 17, FRAME + 1, 16, 16)


func button_at(local: Vector2) -> String:
	if system_button_rect().has_point(local):
		return "system"
	if min_button_rect().has_point(local):
		return "min"
	if max_button_rect().has_point(local):
		return "max"
	return ""


## Resize edge zone of the 3px frame ring ("" inside / when maximized).
func frame_zone(local: Vector2) -> String:
	if maximized:
		return ""
	var r := Rect2(Vector2.ZERO, size)
	if not r.has_point(local) or r.grow(-3).has_point(local):
		return ""
	var left := local.x < RESIZE_CORNER
	var right := local.x >= size.x - RESIZE_CORNER
	var top := local.y < RESIZE_CORNER
	var bottom := local.y >= size.y - RESIZE_CORNER
	var edge_l := local.x < 3
	var edge_r := local.x >= size.x - 3
	var edge_t := local.y < 3
	var edge_b := local.y >= size.y - 3
	if (edge_t or edge_l) and left and top:
		return "nw"
	if (edge_t or edge_r) and right and top:
		return "ne"
	if (edge_b or edge_l) and left and bottom:
		return "sw"
	if (edge_b or edge_r) and right and bottom:
		return "se"
	if edge_t:
		return "n"
	if edge_b:
		return "s"
	if edge_l:
		return "w"
	if edge_r:
		return "e"
	return ""


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if desktop_window:
		Px.fill(self, 2, 2, size.x, size.y, Pal.BLACK)
	Win31Chrome.window_frame(self, Rect2(Vector2.ZERO, size))
	Win31Chrome.caption(self, caption_rect(), "Program Manager", active)
	Win31Chrome.caption_button(self, system_button_rect(), "system", _pressed_button == "system")
	Win31Chrome.caption_button(self, min_button_rect(), "down", _pressed_button == "min")
	Win31Chrome.caption_button(self, max_button_rect(), "restore" if maximized else "up", _pressed_button == "max")


func set_active(value: bool) -> void:
	if active != value:
		active = value
		queue_redraw()


func set_maximized(value: bool) -> void:
	if maximized != value:
		maximized = value
		queue_redraw()
		if _sys_menu != null:
			close_system_menu()


# -------------------------------------------------------------- system menu

func toggle_system_menu() -> void:
	if _sys_menu != null:
		close_system_menu()
	else:
		open_system_menu()


func open_system_menu() -> void:
	if _sys_menu != null:
		return
	_sys_menu = Win31PopupMenu.new()
	_sys_menu.min_width = 144
	_sys_menu.command_chosen.connect(func(c):
		close_system_menu()
		command_chosen.emit(c))
	_sys_menu.dismissed.connect(close_system_menu)
	popup_layer.add_child(_sys_menu)
	_sys_menu.set_items(Win31Commands.system_items("outer-", maximized), false)
	_sys_menu.position = Vector2(FRAME, FRAME + 17)
	_born_frame = Engine.get_process_frames()


func close_system_menu() -> void:
	if _sys_menu != null:
		if is_instance_valid(_sys_menu):
			if _sys_menu.get_parent():
				_sys_menu.get_parent().remove_child(_sys_menu)
			_sys_menu.queue_free()
		_sys_menu = null


func is_system_menu_open() -> bool:
	return _sys_menu != null


func close_all_menus() -> void:
	close_system_menu()
	menu_bar.close_menu()
	for id in client.windows:
		client.windows[id].close_system_menu()


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event)
		else:
			_release(event)
	elif event is InputEventMouseMotion:
		_motion(event)


func _press(ev: InputEventMouseButton) -> void:
	var local := ev.position
	var zone := frame_zone(local)
	if zone != "":
		if desktop_window:
			_frame_drag = {"dir": zone, "start": ev.global_position}
		else:
			Platform.start_window_resize(_edge_for(zone))
		accept_event()
		return
	var btn := button_at(local)
	if btn != "":
		_pressed_button = btn
		queue_redraw()
		if btn == "system" and ev.double_click:
			_pressed_button = ""
			close_system_menu()
			command_chosen.emit("outer-close")
		accept_event()
		return
	if caption_rect().has_point(local):
		if ev.double_click:
			maximize_toggle_requested.emit()
		elif desktop_window:
			if not maximized:
				_caption_drag = {"start": ev.global_position}
		elif not maximized:
			Platform.start_window_drag()
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
					minimize_requested.emit()
				"max":
					maximize_toggle_requested.emit()
		accept_event()
		return
	if not _caption_drag.is_empty():
		var d: Vector2 = ev.global_position - _caption_drag.start
		_caption_drag = {}
		desktop_move.emit("end", d)
		accept_event()
	if not _frame_drag.is_empty():
		var fd := _frame_drag
		_frame_drag = {}
		desktop_resize.emit("end", fd.dir, ev.global_position - fd.start)
		accept_event()


func _motion(ev: InputEventMouseMotion) -> void:
	if not _caption_drag.is_empty():
		desktop_move.emit("move", ev.global_position - _caption_drag.start)
		accept_event()
	elif not _frame_drag.is_empty():
		desktop_resize.emit("resize", _frame_drag.dir, ev.global_position - _frame_drag.start)
		accept_event()
	else:
		mouse_default_cursor_shape = _cursor_for(frame_zone(ev.position))


func _cursor_for(zone: String) -> Control.CursorShape:
	match zone:
		"n", "s":
			return Control.CURSOR_VSIZE
		"e", "w":
			return Control.CURSOR_HSIZE
		"ne", "sw":
			return Control.CURSOR_BDIAGSIZE
		"nw", "se":
			return Control.CURSOR_FDIAGSIZE
	return Control.CURSOR_ARROW


static func _edge_for(zone: String) -> int:
	match zone:
		"n":
			return DisplayServer.WINDOW_EDGE_TOP
		"s":
			return DisplayServer.WINDOW_EDGE_BOTTOM
		"e":
			return DisplayServer.WINDOW_EDGE_RIGHT
		"w":
			return DisplayServer.WINDOW_EDGE_LEFT
		"ne":
			return DisplayServer.WINDOW_EDGE_TOP_RIGHT
		"nw":
			return DisplayServer.WINDOW_EDGE_TOP_LEFT
		"se":
			return DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT
	return DisplayServer.WINDOW_EDGE_BOTTOM_LEFT


func _input(event: InputEvent) -> void:
	if _sys_menu == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var local: Vector2 = event.position - get_global_rect().position
		var on_button := get_global_rect().has_point(event.position) and button_at(local) == "system"
		if not on_button and not _sys_menu.get_global_rect().has_point(event.position):
			close_system_menu()


# -------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return null
	var o := get_global_rect().position
	match id:
		"wfw.system-button":
			return Rect2(o + system_button_rect().position, Vector2(16, 16))
		"wfw.caption-button:Minimize":
			return Rect2(o + min_button_rect().position, Vector2(16, 16))
		"wfw.caption-button:Maximize":
			return null if maximized else Rect2(o + max_button_rect().position, Vector2(16, 16))
		"wfw.caption-button:Restore":
			return Rect2(o + max_button_rect().position, Vector2(16, 16)) if maximized else null
		"wfw.outer-caption":
			return Rect2(o + caption_rect().position, caption_rect().size)
		"wfw.program-manager":
			return Rect2(o, size)
		"wfw.menu-bar":
			return Rect2(menu_bar.get_global_rect())
	if id.begins_with("wfw.popup-item:") and _sys_menu != null:
		return _sys_menu.auto_row(id.substr(15))
	return null
