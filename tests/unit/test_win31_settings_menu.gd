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
