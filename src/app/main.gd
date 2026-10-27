extends Control
## App host: loads the store, mounts the active shell, applies the integer content scale and
## window frame, and relays shell requests to the platform layer. Also hosts the visual
## capture entry (`--capture=<view>`), see src/app/capture.gd.

const VERSION := "2.0.0"

var shell: ShellBase
var capture: Node

var _applied_shell := ""


func _ready() -> void:
	get_window().min_size = Vector2i(400, 300)
	var args := _parse_args()
	ProgramStore.init_store()
	if args.has("capture"):
		capture = load("res://src/app/capture.gd").new()
		capture.host = self
		capture.args = args
		add_child(capture)
		await capture.prepare()  # may rewrite the store fixture and window size
		ProgramStore.load_data()
	_apply_window_for_shell(true)
	_mount_shell()
	ProgramStore.settings_changed.connect(_on_settings_changed)
	if capture:
		capture.run()


static func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out


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
	shell.request_show_launcher_tools.connect(show_launcher_tools)
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


func _apply_window_for_shell(initial: bool) -> void:
	var win := get_window()
	var id := current_shell_id()
	win.borderless = not Validators.uses_native_window_frame(id)
	var scale := resolve_scale()
	ShellScale.apply(win, scale)
	if initial and (capture == null or not capture.owns_window_size()):
		var dpr := ShellScale.display_ratio(win)
		win.size = Vector2i(Vector2(ShellScale.REFERENCE_WIDTH, ShellScale.REFERENCE_HEIGHT) * scale * dpr)
	win.title = "Gosh 95" if id == "win95" else "Program Manager"


func _on_settings_changed() -> void:
	_apply_window_for_shell(false)
	_mount_shell()
	if shell:
		shell.on_scale_changed(int(get_window().content_scale_factor))


func show_launcher_tools() -> void:
	pass  # replaced by the Launcher Tools window in the Win31 port


func quit_app() -> void:
	ProgramStore.flush()
	get_tree().quit()
