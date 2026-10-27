extends Node
## Autoload "Platform": everything the Electron main process / preload bridge used to provide.
## Shells and dialogs call ONLY this (never OS/DisplayServer directly) so behavior stays testable.
## Coroutine methods are marked (await). Paths are plain OS paths.

signal quick_search_requested                     ## global/tray Quick Search toggle
signal files_dropped(files: PackedStringArray, logical_pos: Vector2)
signal window_state_changed(state: Dictionary)    ## {focused, maximized, minimized, bounds: Rect2i}
signal display_changed
signal launcher_tools_requested

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
# TODO(platform agent): implement with DisplayServer.file_dialog_show (native) + fallback.

## (await) -> String path or "" when canceled
func select_executable() -> String:
	push_warning("Platform.select_executable not implemented")
	return ""


## (await) -> String path or ""
func select_icon() -> String:
	push_warning("Platform.select_icon not implemented")
	return ""


## (await) -> {success, group?, error?}   (Program Manager .GRP import)
func import_grp() -> Dictionary:
	push_warning("Platform.import_grp not implemented")
	return {"success": false, "error": "Canceled"}


## (await) -> {success, error?}
func export_grp(_group: Dictionary) -> Dictionary:
	push_warning("Platform.export_grp not implemented")
	return {"success": false, "error": "Canceled"}


## (await) -> {success, error?}  JSON backup import (validated, replaces data, reloads store)
func import_data() -> Dictionary:
	push_warning("Platform.import_data not implemented")
	return {"success": false, "error": "Canceled"}


## (await) -> bool
func export_data() -> bool:
	push_warning("Platform.export_data not implemented")
	return false


## (await) -> AppInfo {name, path, icon?, win31Icon?, workingDir?, arguments?} for a dropped/browsed file.
## `icon`/`win31Icon` are PNG data URLs when an icon could be extracted.
func get_app_info(path: String) -> Dictionary:
	return {"name": path.get_file().get_basename(), "path": path}


# ----------------------------------------------------------------- window control
# TODO(platform agent): minimize-to-tray, frame toggling, bounds persistence, display work area.

func minimize_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func toggle_maximize_window() -> void:
	var m := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_MAXIMIZED)


func is_window_maximized() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED


## Frameless (Win31) windows: hand the drag/resize gesture to the window manager.
func start_window_drag() -> void:
	DisplayServer.window_start_drag()


## edge: DisplayServer.WindowResizeEdge value (RESIZE_TOP_LEFT ... RESIZE_BOTTOM_RIGHT).
func start_window_resize(edge: int) -> void:
	DisplayServer.window_start_resize(edge)


func set_window_title(title: String) -> void:
	DisplayServer.window_set_title(title)


## Honors "Minimize to Tray on Close" (hide) vs quit.
func close_window() -> void:
	if ProgramStore.settings.get("trayOnClose", true):
		hide_window()
	else:
		quit_app()


func hide_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func show_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()


func quit_app() -> void:
	ProgramStore.flush()
	get_tree().quit()


func get_window_bounds() -> Rect2i:
	return Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())


func set_window_bounds(bounds: Rect2i) -> void:
	DisplayServer.window_set_position(bounds.position)
	DisplayServer.window_set_size(bounds.size)


## Usable desktop area of the screen the window is on, in DIPs (physical / display ratio).
func work_area() -> Vector2:
	var screen := DisplayServer.window_get_current_screen()
	return Vector2(DisplayServer.screen_get_usable_rect(screen).size) / ShellScale.display_ratio(get_window())
