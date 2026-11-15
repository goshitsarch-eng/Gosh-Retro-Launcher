extends TestCase
## W31-002 (UI side): applying a workspace profile asks for confirmation first.

func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-test-pc-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func test_confirmation_required_when_profile_selected() -> void:
	var profiles := [{"id": "p1", "name": "Work"}, {"id": "p2", "name": "Games"}]
	var c := LauncherToolsLogic.apply_profile_confirmation(profiles, "p2")
	expect_eq(c.required, true)
	expect_eq(c.message, "Replace all groups and items with profile 'Games'? A backup of your current data is saved first.")


func test_no_confirmation_without_a_known_profile() -> void:
	var profiles := [{"id": "p1", "name": "Work"}]
	expect_eq(LauncherToolsLogic.apply_profile_confirmation(profiles, "").required, false, "nothing selected")
	expect_eq(LauncherToolsLogic.apply_profile_confirmation(profiles, "zzz").required, false, "unknown id")
	expect_eq(LauncherToolsLogic.apply_profile_confirmation([], "p1").required, false, "no profiles")


func test_window_cancel_leaves_groups_and_ok_applies() -> void:
	# The real Launcher Tools window logic, with Apply pointed at a scratch store (never the autoload).
	# It stays out of the tree: _ready needs the initialized autoload store, which tests do not have.
	var dir := _tmp()
	var s: Node = load("res://src/core/program_store.gd").new()
	s.init_store(dir)
	var id: String = s.save_workspace_profile("Work")
	s.add_group("Only Before Apply")
	var before: Array = s.groups.duplicate(true)
	var w := LauncherToolsWindow.new()
	w.profile_store = s
	w._selected_profile = id
	w._request_apply_profile()
	expect_eq(w.profile_confirm.dialog_text,
		"Replace all groups and items with profile 'Work'? A backup of your current data is saved first.")
	expect_eq(w.profile_confirm.ok_button_text, "OK")
	expect_eq(w.profile_confirm.cancel_button_text, "Cancel")
	expect(Jsonx.equal(s.groups, before), "asking changes nothing")
	w.profile_confirm.canceled.emit()
	w._confirm_apply_profile()  # a stray confirm after Cancel must not apply
	expect(Jsonx.equal(s.groups, before), "Cancel changes nothing")
	w._selected_profile = "unknown"
	w._request_apply_profile()
	w.profile_confirm.confirmed.emit()
	expect(Jsonx.equal(s.groups, before), "no confirmation and no apply for an unknown profile")
	w._selected_profile = id
	w._request_apply_profile()
	w.profile_confirm.confirmed.emit()
	expect(not Jsonx.equal(s.groups, before), "OK applies the profile")
	expect_eq(s.groups.size(), before.size() - 1)
	w.free()
	s.free()
	_rm(dir)
