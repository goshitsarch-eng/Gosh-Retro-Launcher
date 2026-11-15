extends TestCase
## Launcher Tools status lines report what the store actually did: profile Apply refusals (F1),
## repaired values and cleared shortcut keys after an import (F2), and the .GRP group id (F4).

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-ltres-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


## A plain file where the backups folder should be makes every backup write fail.
func _block_backups(s: Node) -> void:
	var bdir: String = s.persistence.backup_dir()
	_rm(bdir)
	var blocker := FileAccess.open(bdir, FileAccess.WRITE)
	blocker.store_string("not a folder")
	blocker.close()


func _grp(id: String, name: String, items: Array) -> Dictionary:
	return {"id": id, "name": name, "icon": "group", "windowState": Types.default_window_state(),
		"shellWindowState": Types.create_shell_window_state(), "items": items}


# ------------------------------------------------------------------- F1

func test_apply_profile_reports_the_store_refusal() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Saved")
	var pid: String = s.save_workspace_profile("Snap")
	s.add_group("Precious")
	s.flush()
	_block_backups(s)
	var st := LauncherToolsLogic.apply_profile(s, pid)
	expect_eq(st, "Could not create a backup before applying the workspace profile, so it was not applied.")
	expect_eq(s.groups.size(), 2, "nothing replaced")
	s.free()
	_rm(dir)


func test_apply_profile_status_wording() -> void:
	expect_eq(LauncherToolsLogic.apply_profile_status({"success": true}), "Workspace profile applied.")
	expect_eq(LauncherToolsLogic.apply_profile_status({"success": false, "error": "Workspace profile not found"}),
		"Workspace profile not found")
	expect_eq(LauncherToolsLogic.apply_profile_status({"success": false}), "The workspace profile could not be applied.")


func test_apply_unknown_profile_is_not_reported_as_applied() -> void:
	var dir := _tmp()
	var s := _open(dir)
	expect_eq(LauncherToolsLogic.apply_profile(s, "nope"), "Workspace profile not found")
	s.free()
	_rm(dir)


# ------------------------------------------------------------------- F2

func test_repair_summary_wording() -> void:
	expect_eq(LauncherToolsLogic.repair_summary(0, 0), "")
	expect_eq(LauncherToolsLogic.repair_summary(1, 0), "1 stored value was repaired.")
	expect_eq(LauncherToolsLogic.repair_summary(3, 0), "3 stored values were repaired.")
	expect_eq(LauncherToolsLogic.repair_summary(0, 1),
		"1 shortcut key was cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	expect_eq(LauncherToolsLogic.repair_summary(2, 1),
		"2 stored values were repaired and 1 shortcut key was cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	expect_eq(LauncherToolsLogic.repair_summary(1, 4),
		"1 stored value was repaired and 4 shortcut keys were cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")


func test_import_json_status_includes_counts_and_errors() -> void:
	expect_eq(LauncherToolsLogic.import_json_status({"success": true}), "Launcher backup imported.")
	expect_eq(LauncherToolsLogic.import_json_status({"success": true, "normalized": 2, "shortcutsCleared": 1}),
		"Launcher backup imported. 2 stored values were repaired and 1 shortcut key was cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	expect_eq(LauncherToolsLogic.import_json_status({"success": false, "error": "Invalid file format"}), "Invalid file format")
	expect_eq(LauncherToolsLogic.import_json_status({"success": false, "error": "Canceled"}), "")


func test_import_json_from_a_real_file_reports_cleared_shortcut() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var data := {"groups": [_grp("g1", "G", [{"id": "i1", "name": "A", "path": "/bin/a", "icon": "default",
		"workingDir": "", "shortcutKey": "F"}])], "settings": Types.default_settings(), "workspaceProfiles": []}
	var path := dir.path_join("in.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var r: Dictionary = s.import_from(path)
	expect_eq(r.success, true)
	var st := LauncherToolsLogic.import_json_status(r)
	expect(st.begins_with("Launcher backup imported. "), st)
	expect(st.contains("1 shortcut key was cleared"), st)
	s.free()
	_rm(dir)


func test_import_grp_status_mentions_cleared_shortcut() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var g := _grp("grp-x", "Tools", [{"id": "a", "name": "A", "path": "/bin/a", "icon": "default", "workingDir": "",
		"shortcutKey": "Q"}])
	var r := LauncherToolsLogic.import_grp(s, {"success": true, "group": g}, func(_p: String) -> Dictionary: return {})
	expect_eq(r.status,
		"Imported “Tools” from .GRP. 1 shortcut key was cleared (shortcut keys need Ctrl, Alt, Shift or Meta).")
	s.free()
	_rm(dir)


# ------------------------------------------------------------------- F4

func test_import_grp_returns_the_new_id_when_it_clashes() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var first := LauncherToolsLogic.import_grp(s, {"success": true, "group": _grp("same", "First", [])},
		func(_p: String) -> Dictionary: return {})
	expect_eq(first.groupId, "same")
	var second := LauncherToolsLogic.import_grp(s, {"success": true, "group": _grp("same", "Second", [])},
		func(_p: String) -> Dictionary: return {})
	expect(second.groupId != "same", "clashing id replaced")
	expect_eq(s.find_group(second.groupId).name, "Second")
	s.free()
	_rm(dir)


func test_import_grp_finds_the_group_when_it_is_not_last() -> void:
	var s := StubGrpStore.new()
	s.groups = [{"id": "old"}]
	var r := LauncherToolsLogic.import_grp(s, {"success": true, "group": _grp("x", "Imported", [])},
		func(_p: String) -> Dictionary: return {})
	expect_eq(r.groupId, "new-id", "the id that was not there before, not the last element")
	expect_eq(s.saved, true)
	s.free()


func test_import_grp_reports_store_refusal() -> void:
	var s := StubGrpStore.new()
	s.refuse = true
	var r := LauncherToolsLogic.import_grp(s, {"success": true, "group": _grp("x", "Imported", [])},
		func(_p: String) -> Dictionary: return {})
	expect_eq(r.status, "Could not import the group: Invalid group data.")
	expect(not r.has("groupId"), "no group selected")
	expect_eq(s.saved, false, "nothing saved")
	s.free()


## Stand-in for ProgramStore: inserts the imported group at the front, or refuses it.
class StubGrpStore extends Node:
	var groups: Array = []
	var refuse := false
	var saved := false

	func import_group(_group: Dictionary) -> Dictionary:
		if refuse:
			return {"success": false, "error": "Invalid group data", "normalized": 0, "shortcutsCleared": 0}
		groups.insert(0, {"id": "new-id"})
		return {"success": true, "normalized": 0, "shortcutsCleared": 0}

	func save_groups_now() -> void:
		saved = true
