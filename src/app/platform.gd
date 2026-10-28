extends Node
## Autoload "Platform": everything the Electron main process / preload bridge used to provide.
## Shells and dialogs call ONLY this (never OS/DisplayServer directly) so behavior stays testable.
## Coroutine methods are marked (await). Paths are plain OS paths.
##
## Window geometry (bounds, work area) is expressed in the units DisplayServer uses: physical
## pixels. `get_display_work_area()` and `work_area()` are in DIPs (physical / display ratio), like
## Electron's screen API.

signal quick_search_requested                     ## global/tray Quick Search toggle
signal files_dropped(files: PackedStringArray, logical_pos: Vector2)
signal window_state_changed(state: Dictionary)    ## {focused, maximized, minimized, bounds: Rect2i}
signal display_changed
signal launcher_tools_requested

const MAX_GRP_BYTES := 10 * 1024 * 1024
const GRP_UNSAFE := "[<>:\"/\\\\|?*]+"

## Tests / automation: Callable(request: Dictionary) -> PackedStringArray (may be a coroutine).
## request = {title, mode: "open"|"save", filters: Array, default_name: String, start_dir: String}.
var dialog_provider: Callable = Callable()

## Set by the app host once the tray icon exists (informational: Godot cannot hide its main window,
## so "hide to tray" always minimizes and the window can never be stranded invisible).
var tray_present := false

var _quitting := false
var _hidden := false  ## minimized by "close to tray" and not restored yet
var _state_pending := false
var _last_state: Dictionary = {}
var _last_screen := -1
var _last_mouse_px := Vector2.ZERO
var _was_maximized := false
var _last_dir := ""
var _settle_timer: Timer
var _settle_ticks := 0
var _settle_stable := 0
var _settle_bounds := Rect2i()


class _Waiter extends RefCounted:
	signal done(paths: PackedStringArray)

	## DisplayServer.file_dialog_show callback: (status, selected_paths, selected_filter_index)
	func native(status: bool, paths: PackedStringArray, _filter_index: int) -> void:
		emit_signal.call_deferred("done", paths if status else PackedStringArray())

	func finish(paths: PackedStringArray) -> void:
		emit_signal.call_deferred("done", paths)

	func cancel() -> void:
		emit_signal.call_deferred("done", PackedStringArray())


func _ready() -> void:
	var win := get_window()
	get_tree().auto_accept_quit = false  # close requests go through close_window() (tray-on-close)
	win.close_requested.connect(close_window)
	win.files_dropped.connect(_on_files_dropped)
	win.window_input.connect(_on_window_input)
	win.focus_entered.connect(_on_focus_entered)
	win.focus_exited.connect(_queue_state)
	win.size_changed.connect(_queue_state)
	win.visibility_changed.connect(_queue_state)
	win.dpi_changed.connect(_on_dpi_changed)
	win.mouse_entered.connect(_queue_state)  # first event after a window-manager move/resize


# ------------------------------------------------------------------ system

func os_name() -> String:
	return Launcher.platform()  # "win32" | "darwin" | "linux"


func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "2.0.0"))


func open_external(url: String) -> Dictionary:
	if not Launcher.is_valid_launch_url(url):
		return {"success": false, "error": "Only http and https URLs are allowed"}
	var err := OS.shell_open(url)
	return {"success": err == OK} if err == OK else {"success": false, "error": error_string(err)}


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


# ------------------------------------------------------------------ launching

func launch(item: Dictionary) -> Dictionary:
	if not Validators.is_launch_item(item):
		return {"success": false, "error": "Invalid program item payload"}
	return Launcher.launch_program(item)


## (await) -> Array[{id, success, error?}]
func launch_batch(items: Array, delay_ms: Variant) -> Array:
	return await LaunchGroups.launch_batch(self, items, delay_ms)


# --------------------------------------------------------------- native dialogs

## (await) Opens a file chooser. Returns the chosen path or "" when canceled.
func pick_open_file(title: String, filters: Array) -> String:
	var paths := await _pick({"title": title, "mode": "open", "filters": filters, "default_name": ""})
	return paths[0] if paths.size() > 0 else ""


## (await) Opens a save chooser; appends the first filter's extension when the user typed none.
func pick_save_file(title: String, default_name: String, filters: Array) -> String:
	var paths := await _pick({"title": title, "mode": "save", "filters": filters, "default_name": default_name})
	if paths.is_empty():
		return ""
	var path := paths[0]
	var ext := PlatformFilters.default_extension(filters)
	if ext != "" and path.get_extension() == "":
		path += "." + ext
	return path


## (await) -> String path or "" when canceled
func select_executable() -> String:
	return await pick_open_file("Select Program", PlatformFilters.executable_filters(os_name()))


## (await) -> String path or ""
func select_icon() -> String:
	return await pick_open_file("Select Icon", PlatformFilters.image_filters())


## (await) -> {success, group?, error?}   (Program Manager .GRP import)
func import_grp() -> Dictionary:
	var path := await pick_open_file("Import Program Manager Group", PlatformFilters.grp_open_filters())
	if path == "":
		return {"success": false, "error": "Canceled"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"success": false, "error": error_string(FileAccess.get_open_error())}
	if f.get_length() > MAX_GRP_BYTES:
		return {"success": false, "error": "The .GRP file is too large."}
	var parsed := Grp.parse(f.get_buffer(f.get_length()))
	if not parsed.get("ok", false):
		return {"success": false, "error": String(parsed.get("error", "Invalid .GRP file"))}
	return {"success": true, "group": parsed.group}


## "My: Group?" -> "My- Group-" (illegal filename characters collapse to '-'); "" -> "program-group".
static func safe_group_filename(group_name: String) -> String:
	var re := RegEx.new()
	re.compile(GRP_UNSAFE)
	var safe := re.sub(group_name, "-", true).strip_edges()
	return safe if safe != "" else "program-group"


## (await) -> {success, error?}
func export_grp(group: Dictionary) -> Dictionary:
	if not Jsonx.is_str(group.get("name")) or not Jsonx.is_arr(group.get("items")):
		return {"success": false, "error": "Invalid program group."}
	var path := await pick_save_file("Export Program Manager Group", safe_group_filename(String(group.name)) + ".grp",
			PlatformFilters.grp_save_filters())
	if path == "":
		return {"success": false, "error": "Canceled"}
	var encoded := Grp.serialize(group)
	if not encoded.get("ok", false):
		return {"success": false, "error": String(encoded.get("error", "Could not encode the group."))}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "error": error_string(FileAccess.get_open_error())}
	f.store_buffer(encoded.bytes)
	f.close()
	return {"success": true}


## (await) -> {success, error?}  JSON backup import (validated, replaces data, reloads store)
func import_data() -> Dictionary:
	var path := await pick_open_file("Import Settings", PlatformFilters.json_filters())
	if path == "":
		return {"success": false, "error": "Canceled"}
	return ProgramStore.import_from(path)


## (await) -> bool
func export_data() -> bool:
	var path := await pick_save_file("Export Settings", "program-manager-backup.json", PlatformFilters.json_filters())
	if path == "":
		return false
	return ProgramStore.export_to(path)


## AppInfo {name, path, icon?, win31Icon?, workingDir?, arguments?} for a dropped/browsed file.
## `icon` (128x128) / `win31Icon` (32x32, 16-colour WfW palette) are PNG data URLs when an icon
## could be extracted. May be `await`ed (synchronous today, icon decoding takes a few ms).
func get_app_info(path: String) -> Dictionary:
	if path == "":
		return {"name": "", "path": ""}
	return AppInfoReader.get_app_info(path)


## Single choke point for every file chooser: injected provider (tests) -> native dialog -> Godot
## FileDialog fallback. Returns the selected paths ([] = canceled / unavailable).
func _pick(request: Dictionary) -> PackedStringArray:
	if dialog_provider.is_valid():
		var provided: Variant = await dialog_provider.call(request)
		if provided is PackedStringArray:
			return provided
		var out := PackedStringArray()
		if provided is Array:
			for p in provided:
				out.append(String(p))
		elif provided is String and provided != "":
			out.append(provided)
		return out
	if DisplayServer.get_name() == "headless":
		return PackedStringArray()
	var save: bool = request.mode == "save"
	var start_dir := _last_dir if _last_dir != "" else OS.get_environment("USERPROFILE" if os_name() == "win32" else "HOME")
	var result := PackedStringArray()
	var done := false
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var waiter := _Waiter.new()
		var err := DisplayServer.file_dialog_show(String(request.title), start_dir, String(request.default_name), false,
				DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if save else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
				PlatformFilters.to_godot(request.filters, os_name()), waiter.native, 0)
		if err == OK:
			result = await waiter.done
			done = true
	if not done:
		result = await _pick_with_godot_dialog(request, start_dir)
	if result.size() > 0:
		_last_dir = result[0].get_base_dir()
	return result


func _pick_with_godot_dialog(request: Dictionary, start_dir: String) -> PackedStringArray:
	var save: bool = request.mode == "save"
	var dlg := FileDialog.new()
	dlg.use_native_dialog = false
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	dlg.title = String(request.title)
	for f in request.filters:
		var patterns := PackedStringArray()
		for ext in f.extensions:
			patterns.append("*" if ext == "*" else "*." + String(ext))
		dlg.add_filter(", ".join(patterns), String(f.name))
	if start_dir != "" and DirAccess.dir_exists_absolute(start_dir):
		dlg.current_dir = start_dir
	if save:
		dlg.current_file = String(request.default_name)
	var waiter := _Waiter.new()
	dlg.file_selected.connect(func(p: String) -> void: waiter.finish(PackedStringArray([p])))
	dlg.dir_selected.connect(func(p: String) -> void: waiter.finish(PackedStringArray([p])))
	dlg.canceled.connect(waiter.cancel)
	dlg.close_requested.connect(waiter.cancel)
	add_child(dlg)
	dlg.popup_centered(Vector2i(760, 520))
	var res: PackedStringArray = await waiter.done
	dlg.queue_free()
	return res


# ----------------------------------------------------------------- window control

func minimize_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func toggle_maximize_window() -> void:
	var m := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_MAXIMIZED)


func is_window_maximized() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED


func is_window_minimized() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


## True after "close to tray" until the window is shown again (the window itself is minimized).
func is_window_hidden() -> bool:
	return _hidden


## Frameless (Win31) windows: hand the drag/resize gesture to the window manager.
func start_window_drag() -> void:
	DisplayServer.window_start_drag()
	_settle_bounds_after_gesture()


## edge: DisplayServer.WindowResizeEdge value (RESIZE_TOP_LEFT ... RESIZE_BOTTOM_RIGHT).
func start_window_resize(edge: int) -> void:
	DisplayServer.window_start_resize(edge)
	_settle_bounds_after_gesture()


func set_window_title(title: String) -> void:
	get_window().title = title


## Honors "Minimize to Tray on Close" (hide) vs quit.
func close_window() -> void:
	if _quitting or not ProgramStore.settings.get("trayOnClose", true):
		quit_app()
	else:
		hide_window()


## "Hide to tray". Godot refuses to hide the main window ("Can't change visibility of main
## window"), so this minimizes it; the tray icon (or the taskbar/Dock) restores it.
func hide_window() -> void:
	_hidden = true
	minimize_window()
	_queue_state()


## Restores, un-hides and focuses the window (tray click, second instance, quick search...).
func show_window() -> void:
	var win := get_window()
	_hidden = false
	if win.mode == Window.MODE_MINIMIZED:
		win.mode = Window.MODE_MAXIMIZED if _was_maximized else Window.MODE_WINDOWED
	win.grab_focus()
	DisplayServer.window_move_to_foreground()
	_queue_state()


func quit_app() -> void:
	_quitting = true
	ProgramStore.flush()
	Sounds.stop_all()
	get_tree().quit()


## Outer window rect (including the OS frame), like BrowserWindow.getBounds().
func get_window_bounds() -> Rect2i:
	return Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())


## Sets the OUTER rect (frame included). Ignored while maximized/minimized or below the minimum size.
func set_window_bounds(bounds: Rect2i) -> void:
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		return
	var origin := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	var frame := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var client := WindowLayout.client_rect_for_outer(bounds, origin, frame)
	client.size = client.size.max(win.min_size)
	win.size = client.size
	win.position = client.position
	_queue_state()


## Usable desktop area of the screen the window is on, in DIPs (physical / display ratio).
func work_area() -> Vector2:
	var screen := DisplayServer.window_get_current_screen()
	return Vector2(DisplayServer.screen_get_usable_rect(screen).size) / ShellScale.display_ratio(get_window())


## DisplayWorkArea of the Electron API: {id, width, height, scaleFactor} (DIPs).
func get_display_work_area() -> Dictionary:
	var screen := DisplayServer.window_get_current_screen()
	var wa := work_area()
	return {"id": screen, "width": wa.x, "height": wa.y, "scaleFactor": ShellScale.display_ratio(get_window())}


func get_window_state() -> Dictionary:
	return {
		"focused": get_window().has_focus(),
		"maximized": is_window_maximized(),
		"minimized": is_window_minimized(),
		"bounds": get_window_bounds(),
	}


## Window chrome for a shell: title, desktop colour and frame flag (Win31 frameless, Win95 with the
## OS frame). Synchronous and bounds-agnostic; returns true when the frame flag changed.
func configure_window_chrome(shell: String) -> bool:
	var win := get_window()
	win.title = WindowLayout.window_title(shell)
	RenderingServer.set_default_clear_color(WindowLayout.background_color(shell))
	var want_borderless := not Validators.uses_native_window_frame(shell)
	if win.borderless == want_borderless:
		return false
	win.borderless = want_borderless
	return true


## Switches the frame for a shell keeping the OUTER bounds, like recreateWindowForShell() did by
## recreating the BrowserWindow (here the same window is simply flipped). (await)
func apply_shell_frame(shell: String) -> void:
	var win := get_window()
	var maximized := win.mode == Window.MODE_MAXIMIZED
	var outer := get_window_bounds()
	if not configure_window_chrome(shell):
		return
	# The window manager applies the new decorations asynchronously.
	await get_tree().process_frame
	await get_tree().create_timer(0.06).timeout
	if not maximized and win.mode == Window.MODE_WINDOWED:
		set_window_bounds(outer)
	_queue_state()


## (await) -> bool. Parity with preload `window.recreateForShell`: the shell setting must already be saved.
func recreate_for_shell(shell: String) -> bool:
	if not Validators.is_valid_shell_frame_request(shell):
		return false
	if String(ProgramStore.settings.get("shell", "win31")) != shell:
		return false
	await apply_shell_frame(shell)
	return true


# ------------------------------------------------------------ app-level requests

## Tray / shortcut entry for Quick Search (Win31 overlay or Win95 Find): shows the window first.
func trigger_quick_search() -> void:
	if is_window_hidden() or is_window_minimized():
		show_window()
	quick_search_requested.emit()


## Opens Launcher Tools: emits `launcher_tools_requested` for whoever implements the tools window;
## falls back to the in-window Settings dialog (what App.tsx did) when nobody is connected.
func open_launcher_tools() -> void:
	show_window()
	if launcher_tools_requested.get_connections().is_empty():
		UIState.open_dialog("settings")
	else:
		launcher_tools_requested.emit()


# ------------------------------------------------------------------ internals

func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_last_mouse_px = event.position
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# In-app stand-in for the Electron global shortcuts (a Godot app cannot register OS-wide hotkeys).
	if event.keycode == KEY_SPACE and event.shift_pressed and event.is_command_or_control_pressed() and not event.alt_pressed:
		get_window().set_input_as_handled()
		trigger_quick_search()
	elif event.keycode == KEY_T and event.ctrl_pressed and event.alt_pressed and not event.shift_pressed and not event.meta_pressed:
		get_window().set_input_as_handled()
		open_launcher_tools()


## Drop position in shell logical pixels: the cursor position at drop time, converted from
## screen pixels to window pixels and divided by the content scale.
func current_drop_position() -> Vector2:
	var win := get_window()
	var scale := maxf(win.content_scale_factor, 0.0001)
	var local := Vector2(DisplayServer.mouse_get_position() - DisplayServer.window_get_position())
	if Rect2(Vector2.ZERO, Vector2(win.size)).has_point(local):
		return local / scale
	return _last_mouse_px / scale


func _on_files_dropped(files: PackedStringArray) -> void:
	files_dropped.emit(files, current_drop_position())


func _on_focus_entered() -> void:
	_hidden = false  # restored through the taskbar / Dock / alt-tab instead of the tray
	_queue_state()


func _on_dpi_changed() -> void:
	display_changed.emit()
	_queue_state()


func _queue_state() -> void:
	if _state_pending:
		return
	_state_pending = true
	_emit_state.call_deferred()


func _emit_state() -> void:
	_state_pending = false
	var win := get_window()
	if win.mode == Window.MODE_MAXIMIZED:
		_was_maximized = true
	elif win.mode == Window.MODE_WINDOWED:
		_was_maximized = false
	var state := get_window_state()
	var screen := DisplayServer.window_get_current_screen()
	if _last_screen != -1 and screen != _last_screen:
		display_changed.emit()
	_last_screen = screen
	if state == _last_state:
		return
	_last_state = state
	window_state_changed.emit(state)


## There is no move event in Godot: after a WM-driven drag/resize, poll briefly until the bounds
## stop changing (no idle cost: the timer exists only for a few seconds).
func _settle_bounds_after_gesture() -> void:
	if _settle_timer == null:
		_settle_timer = Timer.new()
		_settle_timer.wait_time = 0.12
		_settle_timer.timeout.connect(_settle_tick)
		add_child(_settle_timer)
	_settle_ticks = 0
	_settle_stable = 0
	_settle_bounds = get_window_bounds()
	_settle_timer.start()


func _settle_tick() -> void:
	_settle_ticks += 1
	var b := get_window_bounds()
	if b != _settle_bounds:
		_settle_bounds = b
		_settle_stable = 0
		_queue_state()
	else:
		_settle_stable += 1
	if _settle_stable >= 8 or _settle_ticks >= 100:  # ~1s without change or 12s total
		_settle_timer.stop()
		_queue_state()
