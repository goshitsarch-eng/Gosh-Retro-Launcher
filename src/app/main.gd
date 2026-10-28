extends Control
## App host: loads the store, mounts the active shell, applies the integer content scale and
## window frame, and relays shell requests to the platform layer (tray, single instance, drag and
## drop, shortcuts, window state). Also hosts the visual capture entry (`--capture=<view>`),
## see src/app/capture.gd.

const VERSION := "2.0.0"
const STARTUP_CHIME_DELAY := 0.3  ## App.tsx: chime 300 ms after the data loaded (WfW only)

var shell: ShellBase
var capture: Node
var tray: TrayController
var single_instance: SingleInstance

var _applied_shell := ""
var _frame_shell := ""
var _startup_done := false


func _ready() -> void:
	var args := _parse_args()
	var is_capture := args.has("capture")
	var win := get_window()
	# Not the shell's concern: the host owns drag-and-drop routing, window state and shortcuts.
	Platform.files_dropped.connect(_on_files_dropped)
	Platform.window_state_changed.connect(_on_window_state_changed)
	Platform.display_changed.connect(_refresh_scale)
	if not is_capture and not _single_instance_disabled(args):
		if not await _acquire_single_instance():
			get_tree().quit()
			return
	ProgramStore.init_store()
	if is_capture:
		capture = load("res://src/app/capture.gd").new()
		capture.host = self
		capture.args = args
		add_child(capture)
		await capture.prepare()  # may rewrite the store fixture and window size
		ProgramStore.load_data()
	_apply_window_for_shell(true)
	_mount_shell()
	if shell:
		shell.on_host_state_changed(Platform.get_window_state())
	ProgramStore.settings_changed.connect(_on_settings_changed)
	if not is_capture:
		_setup_tray()
		_schedule_startup_chime()
		_center_initial_window.call_deferred()
	win.title = WindowLayout.window_title(current_shell_id())
	if capture:
		capture.run()


static func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


func _single_instance_disabled(args: Dictionary) -> bool:
	return args.has("no-single-instance") or OS.get_environment("PM_NO_SINGLE_INSTANCE") != "" \
		or DisplayServer.get_name() == "headless"


## True when this process may continue as the (only) app instance.
func _acquire_single_instance() -> bool:
	single_instance = SingleInstance.new()
	single_instance.name = "SingleInstance"
	add_child(single_instance)
	var result: int = await single_instance.acquire(Persistence.default_user_data_dir(), get_tree())
	if result == SingleInstance.Result.SECONDARY:
		return false
	if result == SingleInstance.Result.PRIMARY:
		single_instance.show_requested.connect(_on_second_instance)
	return true  # UNAVAILABLE (port blocked): run without the lock rather than refuse to start


func _on_second_instance() -> void:
	Platform.show_window()


func current_shell_id() -> String:
	return String(ProgramStore.settings.get("shell", "win31"))


func _mount_shell() -> void:
	var id := current_shell_id()
	if shell and _applied_shell == id:
		return
	if shell:
		remove_child(shell)
		shell.queue_free()
	shell = Win95Shell.new() if id == "win95" else Win31Shell.new()
	shell.host = self
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.request_quit.connect(quit_app)
	shell.request_hide_window.connect(Platform.close_window)
	shell.request_minimize_window.connect(Platform.minimize_window)
	shell.request_maximize_window.connect(Platform.toggle_maximize_window)
	shell.request_show_launcher_tools.connect(show_launcher_tools)
	if not Platform.quick_search_requested.is_connected(_on_quick_search):
		Platform.quick_search_requested.connect(_on_quick_search)
	add_child(shell)
	_applied_shell = id
	shell.on_activate()
	shell.on_scale_changed(int(get_window().content_scale_factor))


## Preferred whole-UI scale for the active shell resolved against the usable screen (DIPs).
func resolve_scale() -> int:
	var settings := ProgramStore.settings
	var pref: Variant = settings.get("win95Scale" if current_shell_id() == "win95" else "win31Scale", "auto")
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var dpr := ShellScale.display_ratio(get_window())
	return ShellScale.resolve_preference(pref, usable.size.x / dpr, usable.size.y / dpr)


## Initial window size of createWindow(): min(work area, 640x480 * scale) in DIPs of the PRIMARY display.
func initial_window_size() -> Vector2i:
	var primary := DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(primary)
	var dpr := ShellScale.display_ratio(null)
	var dips := WindowLayout.initial_size(current_shell_id(), ProgramStore.settings, usable.size.x / dpr, usable.size.y / dpr)
	return Vector2i(Vector2(dips) * ShellScale.display_ratio(get_window()))


func _apply_window_for_shell(initial: bool) -> void:
	var win := get_window()
	var id := current_shell_id()
	var dpr := ShellScale.display_ratio(win)
	win.min_size = Vector2i(ceili(WindowLayout.MIN_WIDTH * dpr), ceili(WindowLayout.MIN_HEIGHT * dpr))
	if initial:
		Platform.configure_window_chrome(id)  # frame flag, title, desktop colour (no bounds to keep yet)
		_frame_shell = id
	ShellScale.apply(win, resolve_scale())
	if initial and (capture == null or not capture.owns_window_size()):
		win.size = initial_window_size()
	win.title = WindowLayout.window_title(id)


## Centers the freshly sized window on the primary display like Electron's default placement
## (needs one frame so the OS frame insets are known).
func _center_initial_window() -> void:
	await get_tree().process_frame
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var outer := DisplayServer.window_get_size_with_decorations()
	var origin := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	win.position = WindowLayout.centered_position(usable, outer) + origin


func _on_settings_changed() -> void:
	var id := current_shell_id()
	if id != _frame_shell:
		_frame_shell = id
		Platform.apply_shell_frame(id)  # coroutine: keeps the outer bounds across the frame flip
	ShellScale.apply(get_window(), resolve_scale())
	_mount_shell()
	if shell:
		shell.on_scale_changed(int(get_window().content_scale_factor))


## Display metrics changed (moved to another monitor / DPI change): re-resolve the whole-UI scale.
func _refresh_scale() -> void:
	var win := get_window()
	var before := win.content_scale_factor
	ShellScale.apply(win, resolve_scale())
	if shell and before != win.content_scale_factor:
		shell.on_scale_changed(int(win.content_scale_factor))


func _on_window_state_changed(state: Dictionary) -> void:
	if shell:
		shell.on_host_state_changed(state)


func _on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	if shell and not files.is_empty():
		shell.on_files_dropped(files, logical_pos)


func _on_quick_search() -> void:
	if shell:
		shell.toggle_quick_search()


func _setup_tray() -> void:
	tray = TrayController.new()
	tray.name = "Tray"
	add_child(tray)
	if not tray.setup():
		return
	Platform.tray_present = true
	tray.show_requested.connect(Platform.show_window)
	tray.launcher_tools_requested.connect(Platform.open_launcher_tools)
	tray.quick_search_requested.connect(Platform.trigger_quick_search)
	tray.quit_requested.connect(quit_app)


func _schedule_startup_chime() -> void:
	if _startup_done:
		return
	_startup_done = true
	await get_tree().create_timer(STARTUP_CHIME_DELAY).timeout
	# Win95 no longer emits the synthetic startup tone (absent from RTM defaults).
	if current_shell_id() == "win31":
		Sounds.play("startup_chime")


func _notification(what: int) -> void:
	# macOS: clicking the Dock icon / Cmd-Tab re-activates the app; bring a tray-hidden window back.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and Platform.is_window_hidden():
		Platform.show_window()


func show_launcher_tools() -> void:
	Platform.open_launcher_tools()


func quit_app() -> void:
	Platform.quit_app()
