extends TestCase
## F6: Restore in Launcher Tools asks first, and the store backs up the current data before it
## replaces everything with the backup.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-restore-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _replaced(s: Node) -> Array:
	return s.list_backups().filter(func(b): return b.reason == "store-replaced")


func test_restore_writes_a_backup_of_the_current_data_first() -> void:
	# ProgramStore.restore_backup writes a forced "store-replaced" backup first.
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Old")
	var point: Dictionary = s.create_backup("manual")
	s.add_group("Current")
	s.flush()
	expect_eq(_replaced(s).size(), 0)
	expect_eq(s.restore_backup(point.id).success, true)
	var replaced := _replaced(s)
	expect(replaced.size() >= 1, "forced backup written")
	var saved: Dictionary = s.persistence.read_backup(replaced[0].id)
	expect_eq(saved.groups.map(func(g): return g.name), ["Old", "Current"], "backup holds the replaced data")
	expect_eq(s.groups.map(func(g): return g.name), ["Old"], "backup restored")
	s.free()
	_rm(dir)


func test_restore_writes_exactly_one_safety_backup() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Old")
	var point: Dictionary = s.create_backup("manual")
	s.add_group("Current")
	s.flush()
	# Count the backups actually written: two in the same millisecond would share a file name, so the
	# listing alone could hide a second one.
	var counting := CountingPersistence.new(dir)
	counting.init_store()
	s.persistence = counting
	var listed_before: int = s.list_backups().size()
	expect_eq(s.restore_backup(point.id).success, true)
	expect_eq(counting.written, ["store-replaced"], "one safety backup, no second copy from set_all_data")
	expect_eq(s.list_backups().size(), listed_before + 1, "the backup count grows by exactly one")
	expect_eq(s.groups.map(func(g): return g.name), ["Old"], "backup restored")
	s.free()
	_rm(dir)


func test_import_still_writes_its_safety_backup() -> void:
	var p := Persistence.new(_tmp())
	p.init_store()
	expect_eq(p.set_all_data({"groups": []}), true)
	expect_eq(p.list_backups().filter(func(b): return b.reason == "store-replaced").size(), 1,
		"set_all_data backs up by default (import relies on it)")
	_rm(p.user_data_dir)


func test_invalid_id_writes_no_backup() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Keep")
	expect_eq(s.restore_backup("../evil").success, false)
	expect_eq(_replaced(s).size(), 0)
	s.free()
	_rm(dir)


func test_backup_time_text() -> void:
	expect_eq(LauncherToolsLogic.backup_time_text("2026-11-14T10:22:33.123Z"), "2026-11-14 10:22:33 UTC")
	expect_eq(LauncherToolsLogic.backup_time_text("odd"), "odd")


func test_restore_confirmation_text_includes_the_date() -> void:
	var backups := [{"id": "a.json", "createdAt": "2026-11-14T10:22:33.123Z", "reason": "manual"},
		{"id": "b.json", "createdAt": "2026-10-01T08:00:00.000Z", "reason": "auto"}]
	var c := LauncherToolsLogic.restore_confirmation(backups, "b.json")
	expect_eq(c.required, true)
	expect_eq(c.message, "Restore the backup from 2026-10-01 08:00:00 UTC? Your current data is backed up first.")
	expect_eq(LauncherToolsLogic.restore_confirmation(backups, "").required, false)
	expect_eq(LauncherToolsLogic.restore_confirmation(backups, "zzz.json").required, false)


func test_window_cancel_changes_nothing_and_ok_restores() -> void:
	# Real window logic pointed at a scratch store; kept out of the tree (no autoload store in tests).
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Before")
	var point: Dictionary = s.create_backup("manual")
	s.add_group("After")
	s.flush()
	var before: Array = s.groups.duplicate(true)
	var backups_before: int = s.list_backups().size()
	var w := LauncherToolsWindow.new()
	w.profile_store = s
	w._refresh_backups()
	w._request_restore(point.id)
	expect_eq(w.restore_confirm.dialog_text, "Restore the backup from %s? Your current data is backed up first." %
		LauncherToolsLogic.backup_time_text(point.createdAt))
	expect(w.restore_confirm.dialog_text.contains(String(point.createdAt).substr(0, 10)), "date shown")
	expect_eq(w.restore_confirm.ok_button_text, "OK")
	expect_eq(w.restore_confirm.cancel_button_text, "Cancel")
	expect(Jsonx.equal(s.groups, before), "asking changes nothing")
	w.restore_confirm.canceled.emit()
	w._confirm_restore()  # a stray confirm after Cancel must not restore
	expect(Jsonx.equal(s.groups, before), "Cancel changes nothing")
	expect_eq(s.list_backups().size(), backups_before, "Cancel writes no backup")
	w._request_restore(point.id)
	w.restore_confirm.confirmed.emit()
	expect_eq(s.groups.map(func(g): return g.name), ["Before"], "OK restores")
	expect(_replaced(s).size() >= 1, "current data backed up first")
	w.free()
	s.free()
	_rm(dir)



## Records every backup written, then writes it as usual.
class CountingPersistence extends Persistence:
	var written: Array = []

	func create_backup(payload: Dictionary, reason: String, force: bool = false) -> Dictionary:
		var info := super.create_backup(payload, reason, force)
		if not info.is_empty():
			written.append(info.reason)
		return info
