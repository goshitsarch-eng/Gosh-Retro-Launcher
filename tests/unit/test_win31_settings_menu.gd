extends TestCase
## W31-001: Options > Settings... opens the WfW Settings dialog.


func _options(menus: Array) -> Array:
	for m in menus:
		if m.id == "options":
			return m.items
	return []


func test_options_menu_has_settings_item() -> void:
	var items := _options(Win31Commands.build_menus([], "", {}, {}))
	var found := {}
	for it in items:
		if it.get("command", "") == "settings":
			found = it
	expect(not found.is_empty(), "Options menu has a settings command")
	expect_eq(found.get("label", ""), "S&ettings...")
	expect(not found.get("disabled", false), "always enabled")
	expect_eq(items[items.size() - 1].get("command", ""), "settings", "last item")
	expect_eq(items[items.size() - 2].get("separator", false), true, "after a separator")


func test_options_mnemonics_are_unique() -> void:
	var items := _options(Win31Commands.build_menus([], "", {}, {}))
	var seen := {}
	for it in items:
		if it.get("separator", false):
			continue
		var m := Win31Commands.mnemonic_of(String(it.label))
		expect(m != "", "%s has a mnemonic" % it.label)
		expect(not seen.has(m), "mnemonic %s is unique" % m)
		seen[m] = true
	expect_eq(items[Win31Commands.mnemonic_match(items, "e")].command, "settings")
	expect_eq(items[Win31Commands.mnemonic_match(items, "s")].command, "save-settings")


func test_settings_command_opens_settings_dialog() -> void:
	UIState.close_dialog()
	var shell := Win31Shell.new()
	shell.run_command("settings")
	expect_eq(UIState.active_dialog, "settings")
	UIState.close_dialog()
	shell.free()


func test_settings_dialog_is_created_and_builds() -> void:
	var dlg := Win31DialogLayer.create_dialog("settings", {})
	expect(dlg is W31SettingsDialog, "dialog layer creates the settings dialog")
	if dlg == null:
		return
	dlg.build(600)
	var form: Dictionary = (dlg as W31SettingsDialog).form
	for k in ["launchDelay", "autoArrange", "theme", "labelDisplay", "shell", "soundEnabled", "trayOnClose"]:
		expect(form.has(k), "form reads %s from the current settings" % k)
	expect_eq(form.launchDelay, int(ProgramStore.settings.get("launchDelay", 500)))
	dlg.free()


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-test-sm-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _rm(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for d in dir.get_directories():
		_rm(path.path_join(d))
	DirAccess.remove_absolute(path)


func test_settings_dialog_changes_use_the_persist_first_transaction() -> void:
	var dir := _tmp()
	var s: Node = load("res://src/core/program_store.gd").new()
	s.init_store(dir)
	var f := W31DialogLogic.settings_form(s.settings)
	f.launchDelay = 900
	f.theme = "dark"
	f.labelDisplay = "ellipsis"
	var r := W31DialogLogic.apply_settings(s, f)
	expect_eq(r.success, true)
	expect_eq(r.shellChanged, false)
	var p := Persistence.new(dir)
	p.init_store()
	var on_disk: Dictionary = p.get_settings()
	expect_eq(on_disk.launchDelay, 900, "written to disk at once, not on a debounce timer")
	expect_eq(on_disk.theme, "dark")
	expect_eq(on_disk.labelDisplay, "ellipsis")
	# invalid settings are rejected and change nothing
	var bad := W31DialogLogic.settings_form(s.settings)
	bad.theme = "neon"
	var r2 := W31DialogLogic.apply_settings(s, bad)
	expect_eq(r2.success, false)
	expect_eq(s.settings.theme, "dark")
	s.free()
	_rm(dir)
