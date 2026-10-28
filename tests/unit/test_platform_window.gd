extends TestCase
## Window layout math, tray model, Platform dialogs/shortcuts/drop routing, launcher fixes.

var _calls: Array = []


# --------------------------------------------------------------------------- WindowLayout

func test_initial_size_matches_create_window() -> void:
	var s := Types.default_settings()
	expect_eq(WindowLayout.initial_size("win31", s, 1920, 1040), Vector2i(1280, 960), "auto scale 2")
	expect_eq(WindowLayout.initial_size("win31", s, 3840, 1500), Vector2i(1920, 1440), "auto scale 3")
	expect_eq(WindowLayout.initial_size("win31", s, 3840, 2160), Vector2i(2560, 1920), "auto scale 4")
	expect_eq(WindowLayout.initial_size("win95", s, 800, 600), Vector2i(640, 480), "auto scale 1")
	expect_eq(WindowLayout.initial_size("win95", s, 500, 400), Vector2i(500, 400), "clamped to the work area")
	var forced := s.duplicate()
	forced["win95Scale"] = 4
	expect_eq(WindowLayout.initial_size("win95", forced, 1920, 1040), Vector2i(1920, 1040), "min(work, 2560x1920)")
	forced["win31Scale"] = 3
	expect_eq(WindowLayout.initial_size("win31", forced, 3840, 2160), Vector2i(1920, 1440))
	forced["win31Scale"] = "bogus"
	expect_eq(WindowLayout.initial_size("win31", forced, 1920, 1040), Vector2i(1280, 960), "invalid preference -> auto")
	expect_eq(WindowLayout.initial_size("other", s, 1920, 1040), Vector2i(800, 600))
	expect_eq(WindowLayout.initial_scale("win31", {}, 640, 480), 1, "missing setting -> auto")


func test_titles_colours_and_min_size() -> void:
	expect_eq(WindowLayout.window_title("win31"), "Program Manager")
	expect_eq(WindowLayout.window_title("win95"), "Gosh 95")
	expect_eq(WindowLayout.background_color("win31").to_html(false), "c0c0c0")
	expect_eq(WindowLayout.background_color("win95").to_html(false), "008080")
	expect_eq(Vector2i(WindowLayout.MIN_WIDTH, WindowLayout.MIN_HEIGHT), Vector2i(400, 300))


func test_bounds_validation_matches_window_handlers() -> void:
	expect(WindowLayout.is_valid_bounds({"x": 0, "y": 0, "width": 400, "height": 300}))
	expect(WindowLayout.is_valid_bounds({"x": -50.5, "y": 10, "width": 1000, "height": 800}))
	expect(not WindowLayout.is_valid_bounds({"x": 0, "y": 0, "width": 399, "height": 300}))
	expect(not WindowLayout.is_valid_bounds({"x": 0, "y": 0, "width": 400, "height": 299}))
	expect(not WindowLayout.is_valid_bounds({"x": 0, "y": 0, "width": 400}))
	expect(not WindowLayout.is_valid_bounds({"x": "0", "y": 0, "width": 400, "height": 300}))
	expect(not WindowLayout.is_valid_bounds({"x": INF, "y": 0, "width": 400, "height": 300}))
	expect(not WindowLayout.is_valid_bounds({"x": NAN, "y": 0, "width": 400, "height": 300}))
	expect(not WindowLayout.is_valid_bounds(null))
	expect(not WindowLayout.is_valid_bounds([1, 2, 3, 4]))


func test_centering_and_outer_to_client_conversion() -> void:
	expect_eq(WindowLayout.centered_position(Rect2i(0, 0, 1920, 1040), Vector2i(1280, 960)), Vector2i(320, 40))
	expect_eq(WindowLayout.centered_position(Rect2i(100, 50, 800, 600), Vector2i(1000, 700)), Vector2i(100, 50), "never above/left of the work area")
	var client := WindowLayout.client_rect_for_outer(Rect2i(100, 100, 800, 600), Vector2i(8, 31), Vector2i(16, 39))
	expect_eq(client, Rect2i(108, 131, 784, 561))
	expect_eq(WindowLayout.client_rect_for_outer(Rect2i(0, 0, 10, 10), Vector2i.ZERO, Vector2i(20, 20)).size, Vector2i(1, 1))


# --------------------------------------------------------------------------- tray

func _groups() -> Array:
	return [
		{"id": "g1", "name": "Games", "items": [{"id": "i1", "name": "Doom"}, {"id": "i2", "name": "Quake"}]},
		{"id": "g2", "name": "Empty", "items": []},
	]


func test_tray_menu_model() -> void:
	var m := TrayController.build_model(_groups())
	var kinds := m.map(func(e: Dictionary) -> String: return e.kind)
	expect_eq(kinds, ["action", "action", "action", "separator", "submenu", "disabled", "separator", "action"])
	expect_eq(m[0].label, "Show Program Manager")
	expect_eq(m[1].label, "Launcher Tools...")
	expect_eq(m[2].label, "Quick Search")
	expect_eq(m[4].label, "Games")
	expect_eq(m[4].items.size(), 2)
	expect_eq(m[4].items[1], {"label": "Quake", "group_id": "g1", "item_id": "i2"})
	expect_eq(m[5].label, "Empty")
	expect_eq(m[7].label, "Exit")
	var none := TrayController.build_model([])
	expect_eq(none.map(func(e: Dictionary) -> String: return e.kind), ["action", "action", "action", "separator", "action"], "no groups: no trailing separator")


func test_tray_menu_is_applied_to_a_popup() -> void:
	var tray := TrayController.new()
	tray._menu = PopupMenu.new()
	tray.add_child(tray._menu)
	tray._apply_model(TrayController.build_model(_groups()))
	var menu: PopupMenu = tray._menu
	expect_eq(menu.item_count, 8)
	expect_eq(menu.get_item_text(0), "Show Program Manager")
	expect(menu.is_item_separator(3))
	expect_eq(menu.get_item_text(4), "Games")
	expect(menu.get_item_submenu_node(4) != null)
	expect_eq(menu.get_item_submenu_node(4).item_count, 2)
	expect_eq(menu.get_item_submenu_node(4).get_item_text(0), "Doom")
	expect(menu.is_item_disabled(5))
	expect_eq(menu.get_item_text(7), "Exit")
	# Rebuilding replaces the submenus instead of leaking them.
	tray._apply_model(TrayController.build_model([]))
	expect_eq(menu.item_count, 5)
	expect_eq(menu.get_child_count(), 0)
	tray.free()


func test_tray_click_policy_and_unavailable_environment() -> void:
	expect(not TrayController.should_restore("win32", 1000, -100000), "single click on Windows does nothing")
	expect(TrayController.should_restore("win32", 1300, 1000), "double click restores on Windows")
	expect(not TrayController.should_restore("win32", 1600, 1000), "too slow")
	expect(TrayController.should_restore("linux", 1000, -100000))
	expect(TrayController.should_restore("darwin", 1000, -100000))
	var tray := TrayController.new()
	expect(not tray.setup(), "no tray in the headless test display")
	expect(not tray.available)
	tray.free()
	for os in ["win32", "darwin", "linux", "freebsd"]:
		expect(TrayController.load_icon(os) != null, "icon for " + os)


# --------------------------------------------------------------------------- Platform helpers

func test_safe_group_filename() -> void:
	expect_eq(Platform.safe_group_filename("Games"), "Games")
	expect_eq(Platform.safe_group_filename("A/B\\C"), "A-B-C")
	expect_eq(Platform.safe_group_filename("What? <is> \"this\": *"), "What- -is- -this- -")
	expect_eq(Platform.safe_group_filename("a///b"), "a-b", "runs collapse to one dash")
	expect_eq(Platform.safe_group_filename("   "), "program-group")
	expect_eq(Platform.safe_group_filename(""), "program-group")
	expect_eq(Platform.safe_group_filename("  Spaced  "), "Spaced")


func _provider(result: Variant) -> Callable:
	return func(req: Dictionary) -> Variant:
		_calls.append(req)
		return result


func _with_store(dir: String) -> void:
	ProgramStore.persistence = Persistence.new(dir)
	ProgramStore.persistence.init_store()
	ProgramStore.load_data()


func _reset_store() -> void:
	ProgramStore.persistence = null
	ProgramStore.groups = []
	ProgramStore.settings = Types.default_settings()


func test_select_dialogs_use_the_right_filters() -> void:
	_calls.clear()
	Platform.dialog_provider = _provider(PackedStringArray(["/x/app.exe"]))
	expect_eq(await Platform.select_executable(), "/x/app.exe")
	expect_eq(_calls[0].title, "Select Program")
	expect_eq(_calls[0].mode, "open")
	expect_eq(_calls[0].filters, PlatformFilters.executable_filters(Platform.os_name()))
	expect_eq(await Platform.select_icon(), "/x/app.exe")
	expect_eq(_calls[1].title, "Select Icon")
	expect_eq(_calls[1].filters, PlatformFilters.image_filters())
	Platform.dialog_provider = _provider(PackedStringArray())
	expect_eq(await Platform.select_executable(), "", "canceled")
	Platform.dialog_provider = _provider("/plain/string.png")
	expect_eq(await Platform.select_icon(), "/plain/string.png", "provider may return a String")
	Platform.dialog_provider = Callable()


func test_import_and_export_grp() -> void:
	var dir := PlatformFixtures.tmp_dir()
	var group := {
		"id": "g", "name": "My: Games/Stuff", "icon": "group",
		"windowState": {"x": 10, "y": 20, "width": 300, "height": 200, "minimized": false, "maximized": false},
		"items": [{"id": "i", "name": "Calc", "path": "C:\\WINDOWS\\CALC.EXE", "arguments": "/x", "workingDir": "", "icon": "default"}],
	}
	_calls.clear()
	Platform.dialog_provider = _provider(PackedStringArray([dir.path_join("out")]))
	var exported := await Platform.export_grp(group)
	expect_eq(exported, {"success": true})
	expect_eq(_calls[0].mode, "save")
	expect_eq(_calls[0].default_name, "My- Games-Stuff.grp", "safeName default filename")
	expect_eq(_calls[0].filters, PlatformFilters.grp_save_filters())
	expect(FileAccess.file_exists(dir.path_join("out.grp")), ".grp appended when the user typed no extension")
	Platform.dialog_provider = _provider(PackedStringArray([dir.path_join("out.grp")]))
	var imported := await Platform.import_grp()
	expect_eq(imported.success, true)
	expect_eq(imported.group.items.size(), 1)
	expect_eq(imported.group.items[0].name, "Calc")
	expect_eq(imported.group.items[0].path, "C:\\WINDOWS\\CALC.EXE")
	expect_eq(_calls[1].filters, PlatformFilters.grp_open_filters())
	# Errors
	expect_eq((await Platform.export_grp({"name": 5, "items": []})), {"success": false, "error": "Invalid program group."})
	expect_eq((await Platform.export_grp({"name": "x"})), {"success": false, "error": "Invalid program group."})
	var junk := PlatformFixtures.write_bytes(dir.path_join("junk.grp"), PackedByteArray([1, 2, 3]))
	Platform.dialog_provider = _provider(PackedStringArray([junk]))
	var bad := await Platform.import_grp()
	expect_eq(bad.success, false)
	expect(String(bad.error).contains("too small"), String(bad.error))
	var big := PackedByteArray()
	big.resize(10 * 1024 * 1024 + 1)
	Platform.dialog_provider = _provider(PackedStringArray([PlatformFixtures.write_bytes(dir.path_join("big.grp"), big)]))
	expect_eq(await Platform.import_grp(), {"success": false, "error": "The .GRP file is too large."})
	Platform.dialog_provider = _provider(PackedStringArray([dir.path_join("missing.grp")]))
	expect_eq((await Platform.import_grp()).success, false)
	Platform.dialog_provider = _provider(PackedStringArray())
	expect_eq(await Platform.import_grp(), {"success": false, "error": "Canceled"})
	expect_eq(await Platform.export_grp(group), {"success": false, "error": "Canceled"})
	Platform.dialog_provider = Callable()
	PlatformFixtures.rm_rf(dir)


func test_export_and_import_data_roundtrip() -> void:
	var dir := PlatformFixtures.tmp_dir()
	_with_store(dir.path_join("profile"))
	ProgramStore.add_group("Backed up")
	_calls.clear()
	Platform.dialog_provider = _provider(PackedStringArray([dir.path_join("backup.json")]))
	expect_eq(await Platform.export_data(), true)
	expect_eq(_calls[0].default_name, "program-manager-backup.json")
	expect_eq(_calls[0].filters, PlatformFilters.json_filters())
	expect(FileAccess.file_exists(dir.path_join("backup.json")))
	ProgramStore.add_group("Added later")
	expect_eq(ProgramStore.groups.size(), 2)
	var res := await Platform.import_data()
	expect_eq(res, {"success": true})
	expect_eq(ProgramStore.groups.size(), 1, "import replaces the data")
	expect_eq(ProgramStore.groups[0].name, "Backed up")
	# Invalid file is rejected and leaves data alone.
	Platform.dialog_provider = _provider(PackedStringArray([PlatformFixtures.write_text(dir.path_join("bad.json"), '{"groups": 5}')]))
	var rejected := await Platform.import_data()
	expect_eq(rejected, {"success": false, "error": "Invalid file format"})
	expect_eq(ProgramStore.groups.size(), 1)
	Platform.dialog_provider = _provider(PackedStringArray())
	expect_eq(await Platform.import_data(), {"success": false, "error": "Canceled"})
	expect_eq(await Platform.export_data(), false)
	Platform.dialog_provider = Callable()
	_reset_store()
	PlatformFixtures.rm_rf(dir)


func test_get_app_info_delegates() -> void:
	var dir := PlatformFixtures.tmp_dir()
	PlatformFixtures.quad(32).save_png(dir.path_join("a.png"))
	var info := await Platform.get_app_info(dir.path_join("a.png"))
	expect_eq(info.name, "a")
	expect(info.has("icon"))
	expect_eq(Platform.get_app_info(""), {"name": "", "path": ""})
	PlatformFixtures.rm_rf(dir)


# --------------------------------------------------------------------------- Platform window behaviour

func test_shortcuts_route_to_signals() -> void:
	var hits := {"qs": 0, "tools": 0}
	var qs := func() -> void: hits.qs += 1
	var tools := func() -> void: hits.tools += 1
	Platform.quick_search_requested.connect(qs)
	Platform.launcher_tools_requested.connect(tools)
	var key := func(code: int, ctrl: bool, shift: bool, alt: bool, meta: bool) -> InputEventKey:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = true
		e.ctrl_pressed = ctrl
		e.shift_pressed = shift
		e.alt_pressed = alt
		e.meta_pressed = meta
		return e
	var win := Platform.get_window()
	var cmd_is_meta := OS.get_name() == "macOS"
	win.window_input.emit(key.call(KEY_SPACE, not cmd_is_meta, true, false, cmd_is_meta))
	expect_eq(hits.qs, 1, "Ctrl/Cmd+Shift+Space")
	win.window_input.emit(key.call(KEY_SPACE, not cmd_is_meta, false, false, cmd_is_meta))
	win.window_input.emit(key.call(KEY_SPACE, false, true, false, false))
	expect_eq(hits.qs, 1, "needs Ctrl/Cmd and Shift")
	win.window_input.emit(key.call(KEY_T, true, false, true, false))
	expect_eq(hits.tools, 1, "Ctrl+Alt+T")
	win.window_input.emit(key.call(KEY_T, true, false, false, false))
	expect_eq(hits.tools, 1)
	Platform.quick_search_requested.disconnect(qs)
	Platform.launcher_tools_requested.disconnect(tools)


func test_launcher_tools_fallback_opens_settings_dialog() -> void:
	UIState.close_dialog()
	Platform.open_launcher_tools()
	expect_eq(UIState.active_dialog, "settings")
	UIState.close_dialog()


func test_files_dropped_is_forwarded_with_logical_position() -> void:
	var got := []
	var cb := func(files: PackedStringArray, pos: Vector2) -> void: got.append([files, pos])
	Platform.files_dropped.connect(cb)
	Platform.get_window().files_dropped.emit(PackedStringArray(["/tmp/a.exe", "/tmp/b.lnk"]))
	Platform.files_dropped.disconnect(cb)
	expect_eq(got.size(), 1)
	expect_eq(Array(got[0][0]), ["/tmp/a.exe", "/tmp/b.lnk"])
	expect(got[0][1] is Vector2)


func test_window_state_and_display_area_shapes() -> void:
	var st := Platform.get_window_state()
	for k in ["focused", "maximized", "minimized", "bounds"]:
		expect(st.has(k), k)
	expect(st.bounds is Rect2i)
	var wa := Platform.get_display_work_area()
	for k in ["id", "width", "height", "scaleFactor"]:
		expect(wa.has(k), k)
	expect(wa.scaleFactor >= 1.0)


func test_hide_to_tray_minimizes_and_show_restores() -> void:
	# Godot cannot hide its main window, so "hide" is a minimize that remembers it was a hide.
	expect(not Platform.is_window_hidden())
	Platform.hide_window()
	expect(Platform.is_window_hidden())
	var trig := []
	var cb := func() -> void: trig.append(1)
	Platform.quick_search_requested.connect(cb)
	Platform.trigger_quick_search()
	expect(not Platform.is_window_hidden(), "quick search restores a hidden window first")
	expect_eq(trig.size(), 1)
	Platform.quick_search_requested.disconnect(cb)
	Platform.hide_window()
	Platform._on_focus_entered()
	expect(not Platform.is_window_hidden(), "restoring through the taskbar clears the flag")


func test_window_state_signal_is_coalesced() -> void:
	var seen := []
	var cb := func(state: Dictionary) -> void: seen.append(state)
	Platform.window_state_changed.connect(cb)
	Platform._last_state = {}
	Platform._queue_state()
	Platform._queue_state()
	Platform._queue_state()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	Platform.window_state_changed.disconnect(cb)
	expect_eq(seen.size(), 1, "three requests in a frame -> one emission")


func test_chrome_configuration_flips_frame_flag() -> void:
	var win := Platform.get_window()
	var before := win.borderless
	var changed := Platform.configure_window_chrome("win31")
	expect_eq(win.title, "Program Manager")
	if DisplayServer.get_name() != "headless":  # the headless server does not store window flags
		expect(win.borderless)
		expect(not Platform.configure_window_chrome("win31"), "idempotent")
		expect(Platform.configure_window_chrome("win95"))
		expect(not win.borderless)
	else:
		expect(changed is bool)
	Platform.configure_window_chrome("win95")
	expect_eq(win.title, "Gosh 95")
	win.borderless = before


func test_recreate_for_shell_requires_saved_setting() -> void:
	ProgramStore.settings["shell"] = "win31"
	expect_eq(await Platform.recreate_for_shell("win95"), false, "setting must be saved first")
	expect_eq(await Platform.recreate_for_shell("bogus"), false)


# --------------------------------------------------------------------------- launcher fixes

func test_powershell_launch_payload_and_encoding() -> void:
	var l := Launcher.build_powershell_launch("C:\\Program Files\\App\\app.exe", PackedStringArray(["--name", "John Smith", "say \"hi\""]),
			"Minimized", "C:\\Work Dir", {"FOO": "bar baz"})
	expect_eq(l.args[0], "-NoLogo")
	expect_eq(l.args[3], "-EncodedCommand")
	var decoded := Marshalls.base64_to_raw(l.args[4]).get_string_from_utf16()
	expect_eq(decoded, Launcher.PS_SCRIPT, "script round-trips through UTF-16LE base64")
	expect(not decoded.contains("$args"), "does not rely on $args (unset under -Command)")
	var payload: Dictionary = JSON.parse_string(l.env.GOSH_LAUNCH)
	expect_eq(payload.file, "C:\\Program Files\\App\\app.exe")
	expect_eq(payload.args, ["--name", "John Smith", "say \"hi\""])
	expect_eq(payload.style, "Minimized")
	expect_eq(payload.cwd, "C:\\Work Dir")
	expect_eq(payload.env, {"FOO": "bar baz"})


func _wait_for_file(path: String, ms: int = 3000) -> String:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).ends_with("\n"):
			return FileAccess.get_file_as_string(path)
		await Engine.get_main_loop().create_timer(0.05).timeout
	return ""


func test_posix_launch_applies_cwd_env_and_arguments() -> void:
	if Launcher.platform() == "win32":
		return
	var dir := PlatformFixtures.tmp_dir()
	var item := {"id": "i", "name": "t", "path": "/bin/sh", "icon": "default", "workingDir": dir,
		"arguments": "-c 'echo \"$FOO|$1|$PWD\" > out.txt' sh \"two words\"", "environment": "FOO=bar"}
	expect_eq(Launcher.launch_program(item), {"success": true})
	var out := await _wait_for_file(dir.path_join("out.txt"))
	expect(out.begins_with("bar|two words|"), "got: " + out)
	expect(out.strip_edges().ends_with(dir.get_file()), "cwd honoured")
	# Missing working directory is reported instead of silently doing nothing.
	var missing := Launcher.launch_program({"id": "i", "name": "t", "path": "/bin/true", "icon": "default", "workingDir": "/definitely/not/here"})
	expect_eq(missing.success, false)
	expect(String(missing.error).contains("Working directory"))
	# Nonexistent program.
	expect_eq(Launcher.launch_program({"id": "i", "name": "t", "path": "/no/such/program", "icon": "default", "workingDir": ""}).success, false)
	PlatformFixtures.rm_rf(dir)


func test_platform_launch_validates_payload() -> void:
	expect_eq(Platform.launch({"id": 1}), {"success": false, "error": "Invalid program item payload"})
	expect_eq(Platform.open_external("ftp://x"), {"success": false, "error": "Only http and https URLs are allowed"})
	var r := await Platform.launch_batch([{"nope": true}], 0)
	expect_eq(r[0].success, false)
	expect_eq(Platform.version(), "2.0.0")
