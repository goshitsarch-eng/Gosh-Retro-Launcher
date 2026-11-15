extends TestCase
## F3: ProgramStore.save_failed and data_normalized reach the user. The host (main.gd) words the
## notice; the WfW shell shows it as its OK message box, waiting for any open dialog to close.

const MAIN := preload("res://src/app/main.gd")


func test_save_failed_notice_is_an_alert() -> void:
	var n: Dictionary = MAIN.save_failed_notice("groups", "Your program groups could not be saved because they contain invalid data.")
	expect_eq(n.title, "Program Manager")
	expect_eq(n.alert, true)
	expect_eq(n.text, "Your program groups could not be saved because they contain invalid data. The change is kept while Program Manager is running, and saving is tried again.")
	var b: Dictionary = MAIN.save_failed_notice("backup", "Could not create a backup before applying the workspace profile, so it was not applied.")
	expect_eq(b.text, "Could not create a backup before applying the workspace profile, so it was not applied.",
		"a refused action is not retried, so no retry sentence")
	expect_eq(MAIN.save_failed_notice("settings", "").text.begins_with("Program Manager could not save your data."), true)


func test_load_notice_is_one_line() -> void:
	var n: Dictionary = MAIN.data_normalized_notice("load", {"normalized": 2})
	expect_eq(n.text, "While loading your data, 2 stored values were repaired.")
	expect_eq(n.alert, false)
	expect(not String(n.text).contains("\n"), "one line")
	expect_eq(MAIN.data_normalized_notice("load", {"normalized": 0}), {}, "nothing repaired, nothing shown")


func test_other_sources_only_when_counts_are_not_zero() -> void:
	expect_eq(MAIN.data_normalized_notice("save", {"normalized": 0, "shortcutsCleared": 0}), {})
	expect_eq(MAIN.data_normalized_notice("import", {}), {})
	expect_eq(MAIN.data_normalized_notice("import", {"normalized": 1, "shortcutsCleared": 2}).text,
		"While importing, 1 stored value was repaired and 2 shortcut keys were cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	expect_eq(MAIN.data_normalized_notice("grp-import", {"normalized": 0, "shortcutsCleared": 1}).text,
		"While importing the .GRP group, 1 shortcut key was cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	expect_eq(MAIN.data_normalized_notice("profile-apply", {"normalized": 3}).text,
		"While applying the workspace profile, 3 stored values were repaired.")
	expect_eq(MAIN.data_normalized_notice("save", {"normalized": 1}).text, "Before saving, 1 stored value was repaired.")


func test_host_without_a_shell_only_logs() -> void:
	var host: Control = MAIN.new()
	host.show_notice(MAIN.save_failed_notice("groups", "x"))  # no shell: must not crash or open anything
	host.show_notice({})
	expect_eq(UIState.active_dialog, "")
	host.free()


func test_wfw_notice_waits_for_the_open_dialog() -> void:
	UIState.close_dialog()
	var shell := Win31Shell.new()
	shell._notices_live = true  # as after on_activate
	UIState.open_dialog("about")
	shell.show_notice("Program Manager", "First")
	shell.show_notice("Program Manager", "Second")
	expect_eq(UIState.active_dialog, "about", "an open dialog is not replaced")
	UIState.close_dialog()
	await Engine.get_main_loop().process_frame
	expect_eq(UIState.active_dialog, "unavailable")
	expect_eq(UIState.dialog_data, {"title": "Program Manager", "message": "First"})
	UIState.close_dialog()
	await Engine.get_main_loop().process_frame
	expect_eq(UIState.dialog_data, {"title": "Program Manager", "message": "Second"}, "queued notices follow in order")
	UIState.close_dialog()
	await Engine.get_main_loop().process_frame
	expect_eq(UIState.active_dialog, "", "queue drained")
	shell._exit_tree()
	shell.free()


func test_wfw_notice_shows_at_once_when_free_and_not_before_activation() -> void:
	UIState.close_dialog()
	var shell := Win31Shell.new()
	shell.show_notice("Program Manager", "Early")
	expect_eq(UIState.active_dialog, "", "not shown before the shell is active")
	shell._notices_live = true
	shell.show_notice("Program Manager", "Now")
	expect_eq(UIState.active_dialog, "unavailable")
	expect_eq(UIState.dialog_data.message, "Early", "oldest first")
	UIState.close_dialog()
	await Engine.get_main_loop().process_frame
	expect_eq(UIState.dialog_data.get("message"), "Now")
	UIState.close_dialog()
	await Engine.get_main_loop().process_frame
	shell._exit_tree()
	shell.free()


func test_repeated_retry_failures_are_shown_once() -> void:
	var host: Control = MAIN.new()
	host._on_save_failed("groups", "m")
	host._on_save_failed("groups", "m")
	expect_eq(host._shown_save_failures.size(), 1, "the retry on the next flush is not shown again")
	host._on_save_failed("backup", "b")
	expect_eq(host._shown_save_failures.size(), 1, "backup refusals answer a user action and are always shown")
	host.free()
