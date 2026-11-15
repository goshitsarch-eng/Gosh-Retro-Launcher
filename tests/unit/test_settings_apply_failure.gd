extends TestCase
## F5: a refused WfW Settings change is shown to the user (OK message box) instead of only being
## logged; the dialog still closes before it applies.


func test_failure_notice_wording() -> void:
	expect_eq(W31DialogLogic.settings_failure_notice({"success": true}), {})
	expect_eq(W31DialogLogic.settings_failure_notice({"success": false, "error": "Invalid settings data"}),
		{"title": "Settings", "message": "The settings could not be applied: Invalid settings data. Nothing was changed."})
	expect_eq(W31DialogLogic.settings_failure_notice({"success": false}),
		{"title": "Settings", "message": "The settings could not be applied. Nothing was changed."})
	expect_eq(W31DialogLogic.settings_failure_notice({}).is_empty(), false, "no success flag is a failure")


func test_apply_settings_refusal_produces_a_notice() -> void:
	var store := StubSettingsStore.new()
	var r := W31DialogLogic.apply_settings(store, W31DialogLogic.settings_form(store.settings))
	expect_eq(r.success, false)
	expect_eq(W31DialogLogic.settings_failure_notice(r).message,
		"The settings could not be applied: Disk full. Nothing was changed.")
	store.free()


func test_submit_with_invalid_settings_opens_a_message_box() -> void:
	# The autoload store refuses an unknown shell before it touches persistence, so nothing is written.
	var before: Dictionary = ProgramStore.settings.duplicate(true)
	var dlg := W31SettingsDialog.new()
	dlg.form.shell = "not-a-shell"
	UIState.open_dialog("settings")
	var seen := []
	var track := func() -> void: seen.append(UIState.active_dialog)
	UIState.dialog_changed.connect(track)
	dlg._submit()
	UIState.dialog_changed.disconnect(track)
	expect_eq(seen, ["", "unavailable"], "closed first, then the message box")
	expect_eq(UIState.dialog_data.get("title"), "Settings")
	expect(String(UIState.dialog_data.get("message", "")).begins_with("The settings could not be applied"))
	expect(Jsonx.equal(ProgramStore.settings, before), "settings unchanged")
	UIState.close_dialog()
	dlg.free()


func test_submit_success_shows_nothing() -> void:
	var store := StubSettingsStore.new()
	store.refuse = false
	var r := W31DialogLogic.apply_settings(store, W31DialogLogic.settings_form(store.settings))
	expect_eq(W31DialogLogic.settings_failure_notice(r), {})
	store.free()


class StubSettingsStore extends Node:
	var settings: Dictionary = Types.default_settings()
	var refuse := true

	func apply_settings_transaction(_next: Dictionary) -> Dictionary:
		if refuse:
			return {"success": false, "error": "Disk full"}
		return {"success": true}
