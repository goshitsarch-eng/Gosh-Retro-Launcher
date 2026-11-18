extends Control
## App host: loads the store, mounts the active shell, applies the integer content scale and
## window frame, and relays shell requests to the platform layer (tray, single instance, drag and
## drop, shortcuts, window state). Also hosts the visual capture entry (`--capture=<view>`),
## see src/app/capture.gd.

const VERSION := "2.0.0"

var shell: ShellBase
var capture: Node
var tray: TrayController
var single_instance: SingleInstance
var desktop: DesktopBridge

var _applied_shell := ""
var _frame_shell := ""
var _shown_save_failures := {}  ## groups/settings/profiles failures already shown (they re-fire on every retry); cleared by save_recovered


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
	var capture_script: Script = load("res://src/app/capture.gd") if is_capture else null
	if capture_script:
		# Before init_store(): without PM_USER_DATA the first init would open the real store.
		capture_script.select_profile()
	ProgramStore.init_store()
	if is_capture:
		capture = capture_script.new()
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
	ProgramStore.save_failed.connect(_on_save_failed)
	ProgramStore.save_recovered.connect(_on_save_recovered)
	ProgramStore.data_normalized.connect(_on_data_normalized)
	if is_capture and capture_notices_enabled(OS.get_environment("PM_CAPTURE_NOTICE")):
		_post_capture_notice.call_deferred()
	if not is_capture:
		_show_load_notice.call_deferred()
		_setup_tray()
		_setup_desktop_bridge()
		MacAppMenu.install(Platform.open_launcher_tools, Platform.open_launcher_tools, Platform.trigger_quick_search)
		_center_initial_window.call_deferred()
		if wants_quick_search(args, OS.get_cmdline_args()):
			Platform.trigger_quick_search.call_deferred()  # `--quick-search` with no instance running yet
	# (The WfW startup chime is played by Win31Shell.on_activate, 300 ms after mounting.)
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


## `program-manager --quick-search` (OS-bindable hotkey). Godot passes unknown flags through in
## get_cmdline_args(), so the `--` separator is optional.
static func wants_quick_search(user_args: Dictionary, engine_args: PackedStringArray) -> bool:
	return user_args.has("quick-search") or engine_args.has("--quick-search")


func _single_instance_disabled(args: Dictionary) -> bool:
	return args.has("no-single-instance") or OS.get_environment("PM_NO_SINGLE_INSTANCE") != "" \
		or DisplayServer.get_name() == "headless"


## True when this process may continue as the (only) app instance.
func _acquire_single_instance() -> bool:
	single_instance = SingleInstance.new()
	single_instance.name = "SingleInstance"
	if wants_quick_search(_parse_args(), OS.get_cmdline_args()):
		single_instance.command = SingleInstance.QUICK_SEARCH_REQUEST
	add_child(single_instance)
	var result: int = await single_instance.acquire(Persistence.default_user_data_dir(), get_tree())
	if result == SingleInstance.Result.SECONDARY:
		return false
	if result == SingleInstance.Result.PRIMARY:
		single_instance.show_requested.connect(_on_second_instance)
		single_instance.quick_search_requested.connect(Platform.trigger_quick_search)
	return true  # UNAVAILABLE (port blocked): run without the lock rather than refuse to start


func _on_second_instance() -> void:
	Platform.show_window()


func current_shell_id() -> String:
	return String(ProgramStore.settings.get("shell", "win31"))


## The shells (and the Launcher Tools window) are loaded by path, never named as classes here: a
## class name in this script makes Godot compile that class and everything it uses when main.gd
## loads. Naming all four compiled about 130 scripts the running shell never uses (8.5-16.5 MB of
## static memory, 30-35 MB RSS). Another shell is compiled on its first switch.
const SHELL_SCRIPTS := {
	"win31": "res://src/shells/win31/win31_shell.gd",
	"win95": "res://src/shells/win95/win95_shell.gd",
	"mac": "res://src/shells/mac/mac_shell.gd",
	"be": "res://src/shells/be/be_shell.gd",
}
const NOTICE_DIALOGS := {
	"win95": "res://src/shells/win95/win95_dialogs.gd",
	"mac": "res://src/shells/mac/mac_dialogs.gd",
	"be": "res://src/shells/be/be_dialogs.gd",
}
const LAUNCHER_TOOLS_WINDOW := "res://src/shells/win31/dialogs/launcher_tools_window.gd"


## Script of the shell `id` mounts (unknown ids fall back to WfW, as before).
static func shell_script_path(id: String) -> String:
	return String(SHELL_SCRIPTS.get(id, SHELL_SCRIPTS.win31))


func _mount_shell() -> void:
	var id := current_shell_id()
	if shell and _applied_shell == id:
		return
	if shell:
		remove_child(shell)
		shell.queue_free()
	shell = (load(shell_script_path(id)) as GDScript).new()
	shell.host = self
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.request_quit.connect(quit_app)
	shell.request_hide_window.connect(Platform.close_window)
	shell.request_minimize_window.connect(Platform.minimize_window)
	shell.request_maximize_window.connect(Platform.toggle_maximize_window)
	shell.request_show_launcher_tools.connect(show_launcher_tools)
	if not Platform.quick_search_requested.is_connected(_on_quick_search):
		Platform.quick_search_requested.connect(_on_quick_search)
	if not Platform.launcher_tools_requested.is_connected(_open_launcher_tools_window):
		Platform.launcher_tools_requested.connect(_open_launcher_tools_window)
	if not Platform.note_open_requested.is_connected(_on_note_open_requested):
		Platform.note_open_requested.connect(_on_note_open_requested)
	if not Platform.import_finished.is_connected(_on_import_finished):
		Platform.import_finished.connect(_on_import_finished)
	Platform.dialog_style_provider = _file_dialog_look
	add_child(shell)
	_applied_shell = id
	shell.on_activate()
	shell.on_scale_changed(int(get_window().content_scale_factor))
	shell.restore_open_notes.call_deferred()


## Preferred whole-UI scale for the active shell resolved against the usable screen (DIPs).
func resolve_scale() -> int:
	var settings := ProgramStore.settings
	var pref: Variant = settings.get(Types.scale_key(current_shell_id()), "auto")
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


## Real "hide to tray" and the OS-wide Quick Search hotkey (see DesktopBridge).
func _setup_desktop_bridge() -> void:
	desktop = DesktopBridge.new()
	desktop.name = "DesktopBridge"
	add_child(desktop)
	Platform.desktop = desktop
	desktop.hotkey_pressed.connect(Platform.trigger_quick_search)
	desktop.shown.connect(Platform._on_desktop_shown)
	desktop.start(Launcher.platform(), true)


func _notification(what: int) -> void:
	# macOS: clicking the Dock icon / Cmd-Tab re-activates the app; bring a tray-hidden window back.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and Platform.is_window_hidden():
		Platform.show_window()


func _open_launcher_tools_window() -> void:
	load(LAUNCHER_TOOLS_WINDOW).show_singleton(self)


# ------------------------------------------------------------ store notices

const NOTICE_TITLE := "Program Manager"
const NORMALIZED_PLACES := {"load": "While loading your data", "import": "While importing",
	"grp-import": "While importing the .GRP group", "profile-apply": "While applying the workspace profile",
	"save": "Before saving"}


## Notice for ProgramStore.save_failed: an alert the user acknowledges. {title, text, alert}.
static func save_failed_notice(kind: String, message: String) -> Dictionary:
	var text := message if message != "" else "Program Manager could not save your data."
	if kind == "groups" or kind == "settings" or kind == "profiles":
		text += " The change is kept while Program Manager is running, and saving is tried again."
	return {"title": NOTICE_TITLE, "text": text, "alert": true}


## One-line notice for ProgramStore.data_normalized, {} when nothing was changed (counts of zero).
static func data_normalized_notice(source: String, report: Dictionary) -> Dictionary:
	var summary := LauncherToolsLogic.repair_summary(int(report.get("normalized", 0)), int(report.get("shortcutsCleared", 0)))
	if summary == "":
		return {}
	var place := String(NORMALIZED_PLACES.get(source, "While saving"))
	return {"title": NOTICE_TITLE, "text": "%s, %s" % [place, summary], "alert": false}


func _on_save_failed(kind: String, message: String) -> void:
	var n := save_failed_notice(kind, message)
	if kind == "groups" or kind == "settings" or kind == "profiles":
		var key := "%s|%s" % [kind, message]
		if _shown_save_failures.has(key):
			return
		_shown_save_failures[key] = true
	show_notice(n)


## A save of `kind` worked again, so the next failure of that kind is shown again.
func _on_save_recovered(kind: String) -> void:
	for key in _shown_save_failures.keys():
		if String(key).begins_with(kind + "|"):
			_shown_save_failures.erase(key)


func _on_data_normalized(source: String, report: Dictionary) -> void:
	if source == "import":
		return  # the Import All result (_on_import_finished) already reports the repairs
	show_notice(data_normalized_notice(source, report))


## The "load" report is emitted inside init_store, before anything can connect, so it is read back
## from ProgramStore.load_report once the shell is up.
func _show_load_notice() -> void:
	await get_tree().process_frame
	show_notice(data_normalized_notice("load", ProgramStore.load_report))


## PM_CAPTURE_NOTICE=1 (capture runs only) shows notices and posts one long save_failed notice, so
## the shells' message boxes can be checked in a capture (e.g. --capture=win95-notice).
static func capture_notices_enabled(env_value: String) -> bool:
	return env_value == "1"


func _post_capture_notice() -> void:
	_on_save_failed("groups", "Your program groups could not be saved because they contain invalid data.")


## Shows a store notice with the active shell's own OK message box (never an OS alert, which would
## block). Logged too. Suppressed during visual captures so renders stay deterministic.
func show_notice(n: Dictionary) -> void:
	if n.is_empty():
		return
	push_warning("Program Manager: " + String(n.text))
	if capture != null and not capture_notices_enabled(OS.get_environment("PM_CAPTURE_NOTICE")):
		return
	if not is_instance_valid(shell) or not shell.is_inside_tree() or shell.is_queued_for_deletion():
		return
	var alert: bool = n.get("alert", false)
	var id := shell.shell_id()
	if id == "win95":
		load(NOTICE_DIALOGS.win95).show_message(shell, String(n.title), String(n.text), "warning" if alert else "information")
	elif id == "mac":
		load(NOTICE_DIALOGS.mac).alert(shell, [String(n.text)], "caution" if alert else "note")
	elif id == "be":
		load(NOTICE_DIALOGS.be).message(shell, [String(n.text)], "warning" if alert else "information")
	elif shell.has_method("show_notice"):
		shell.show_notice(String(n.title), String(n.text), alert)


## Font and colours of the active shell for Godot's own file chooser.
func _file_dialog_look() -> Dictionary:
	if not is_instance_valid(shell):
		return {}
	return {"style": shell.note_style(), "palette": shell.file_dialog_palette()}


func _on_note_open_requested(item_id: String) -> void:
	if is_instance_valid(shell) and shell.is_inside_tree():
		shell.open_note(item_id)


## Import All result. Shown by the host, after the (possibly new) shell is mounted, because an import
## that switches the desktop frees the shell that started it.
static func import_notice(result: Dictionary) -> Dictionary:
	var text := DataTransfer.import_status(result)
	if text == "":
		return {}
	return {"title": DataTransfer.IMPORT_TITLE, "text": text, "alert": not result.get("success", false)}


func _on_import_finished(result: Dictionary) -> void:
	show_notice.call_deferred(import_notice(result))


func show_launcher_tools() -> void:
	Platform.open_launcher_tools()


func quit_app() -> void:
	Platform.quit_app()
