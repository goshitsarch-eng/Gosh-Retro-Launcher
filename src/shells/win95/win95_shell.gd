class_name Win95Shell
extends ShellBase
## The Windows 95 RTM shell (port of Win95Shell.tsx): desktop + windows, taskbar, Start menu,
## popup/menu layer and dialog layer, all laid out in 640x480-style logical pixels (the host owns the
## integer content scale). It hosts the single Win95 input model (Win95InputController): every key
## and mouse event passes through _input() first.
##
## Layers (back to front): desktop (windows inside) < taskbar < Start menu < popup_layer < dialog_layer.
## Public surface used by the Win95* components: windows (Win95WindowStore), input, desktop, taskbar,
## popup_layer, dialog_layer, logical_size, desktop_size(), host_focused, dragging, launch_item().

const M := Win95Tokens.M

var windows: Win95WindowStore
var input: Win95InputController
var desktop: Win95Desktop
var taskbar: Win95Taskbar
var start_menu: Win95StartMenu
var popup_layer: Control
var dialog_layer: Control

var logical_size := Vector2(640, 480)
var host_focused := true
var dragging := false


func shell_id() -> String:
	return "win95"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	windows = Win95WindowStore.new(null)
	input = Win95InputController.new()
	input.shell = self
	add_child(input)
	desktop = Win95Desktop.new()
	add_child(desktop)
	taskbar = Win95Taskbar.new()
	add_child(taskbar)
	start_menu = Win95StartMenu.new()
	add_child(start_menu)
	popup_layer = _make_layer()
	dialog_layer = _make_layer()
	add_child(popup_layer)
	add_child(dialog_layer)
	resized.connect(_layout)


func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	if Engine.has_meta("pm_capture"):
		host_focused = true
	else:
		var win := get_window()
		if win != null:
			host_focused = win.has_focus() or true
			win.focus_entered.connect(func(): _set_host_focus(true))
			win.focus_exited.connect(func(): _set_host_focus(false))
	desktop.setup(self)
	taskbar.setup(self)
	start_menu.setup(self)
	_layout()


func _set_host_focus(focused: bool) -> void:
	host_focused = focused
	desktop.sync_windows()
	desktop.queue_redraw()
	taskbar.queue_redraw()


func on_host_state_changed(state: Dictionary) -> void:
	if state.has("focused") and not Engine.has_meta("pm_capture"):
		_set_host_focus(bool(state.focused))


func on_activate() -> void:
	_layout()


func on_scale_changed(_factor: int) -> void:
	_layout()


func _layout() -> void:
	logical_size = Vector2(ceilf(size.x), ceilf(size.y))
	if logical_size.x < 1 or logical_size.y < 1:
		return
	var h := logical_size.y - M.taskbarHeight
	desktop.position = Vector2.ZERO
	desktop.size = Vector2(logical_size.x, maxf(1.0, h))
	taskbar.position = Vector2(0, h)
	taskbar.size = Vector2(logical_size.x, M.taskbarHeight)
	for c in [start_menu, popup_layer, dialog_layer]:
		c.position = Vector2.ZERO
		c.size = logical_size
	desktop.sync_windows()
	taskbar.queue_redraw()
	start_menu.queue_redraw()


func desktop_size() -> Vector2:
	return Vector2(logical_size.x, maxf(1.0, logical_size.y - M.taskbarHeight))


func set_dragging(on: bool) -> void:
	dragging = on


# ------------------------------------------------------------------- launching

func launch_item(item: Dictionary) -> void:
	var result: Dictionary = Platform.launch(item)
	if not result.get("success", false):
		Win95Dialogs.show_message(self, String(item.name), String(result.get("error", "Windows cannot find '%s'." % item.path)), "warning")
	elif ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()


# ------------------------------------------------------------------ host events

func toggle_quick_search() -> void:
	input.close_start_menu()
	Win95Dialogs.open_find(self)


func on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	var target := ""
	for e in windows.by_z():
		if e.kind != "group" or windows.entry_is_minimized(e):
			continue
		var w: Win95Window = desktop.window_for(e.id)
		if w != null and Rect2(w.position, w.size).has_point(logical_pos):
			target = String(e.groupId)
	if target == "":
		return
	for path in files:
		var info: Dictionary = Platform.get_app_info(path)
		ProgramStore.add_item(target, {
			"name": info.get("name", path.get_file().get_basename()),
			"path": info.get("path", path),
			"icon": info.get("icon", "application"),
			"workingDir": info.get("workingDir", ""),
		})


# --------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.ctrl_pressed and k.alt_pressed and k.keycode == KEY_T:
			request_show_launcher_tools.emit()
			get_viewport().set_input_as_handled()
			return
		if input.on_key(k):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var pos := mb.position - global_position
		if input.on_pointer("down" if mb.pressed else "up", mb, pos):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if input.on_pointer("move", mm, mm.position - global_position):
			get_viewport().set_input_as_handled()
