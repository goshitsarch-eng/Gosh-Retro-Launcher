extends TestCase
## W31-002 data side: applying a workspace profile first writes a forced backup of the current data.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-profbak-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


func test_apply_creates_a_backup_of_the_replaced_groups() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Saved")
	var pid: String = s.save_workspace_profile("Snap")
	var later: String = s.add_group("Added after the snapshot")
	s.add_item(later, {"name": "New", "path": "/bin/new", "icon": "default", "workingDir": ""})
	# Not flushed on purpose: the pending edit must still end up in the backup.
	var before: Array = s.list_backups().filter(func(b): return b.reason == "store-replaced")
	expect_eq(before.size(), 0)
	var r: Dictionary = s.apply_workspace_profile(pid)
	expect_eq(r.success, true)
	expect(not r.backup.is_empty(), "backup info returned")
	expect_eq(r.backup.reason, "store-replaced")
	var after: Array = s.list_backups().filter(func(b): return b.reason == "store-replaced")
	expect_eq(after.size(), 1, "one forced backup written")
	expect(FileAccess.file_exists(dir.path_join("backups").path_join(r.backup.id)), "backup file exists")
	var saved: Dictionary = s.persistence.read_backup(r.backup.id)
	var names: Array = saved.groups.map(func(g): return g.name)
	expect_eq(names, ["Saved", "Added after the snapshot"], "backup holds the groups being replaced")
	expect_eq(saved.groups[1].items[0].name, "New")
	expect_eq(s.groups.map(func(g): return g.name), ["Saved"], "profile applied")
	# The backup restores what the profile replaced.
	expect_eq(s.restore_backup(r.backup.id).success, true)
	expect_eq(s.groups.size(), 2)
	s.free()


func test_apply_unknown_profile_does_nothing() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Keep")
	var r: Dictionary = s.apply_workspace_profile("nope")
	expect_eq(r.success, false)
	expect_eq(s.groups.size(), 1)
	expect_eq(s.list_backups().filter(func(b): return b.reason == "store-replaced").size(), 0)
	s.free()


func test_apply_is_refused_when_no_backup_can_be_written() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Saved")
	var pid: String = s.save_workspace_profile("Snap")
	s.add_group("Precious")
	s.flush()
	# A plain file where the backups folder should be makes every backup write fail.
	var bdir: String = s.persistence.backup_dir()
	for f in DirAccess.get_files_at(bdir):
		DirAccess.remove_absolute(bdir.path_join(f))
	DirAccess.remove_absolute(bdir)
	var blocker := FileAccess.open(bdir, FileAccess.WRITE)
	blocker.store_string("not a folder")
	blocker.close()
	var failed := []
	s.save_failed.connect(func(kind: String, msg: String) -> void: failed.append(kind))
	var r: Dictionary = s.apply_workspace_profile(pid)
	expect_eq(r.success, false)
	expect_eq(failed, ["backup"], "the host is told")
	expect_eq(s.groups.size(), 2, "nothing replaced without a backup")
	s.free()


func test_apply_normalises_profile_groups() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.workspace_profiles = [{"id": "p", "name": "P", "createdAt": "a", "updatedAt": "b", "groups": [
		{"id": "g", "name": "G", "items": [{"id": "i", "name": "I", "path": "/bin/i", "launchGroup": -3,
			"shortcutKey": "F2"}]}]}]
	var r: Dictionary = s.apply_workspace_profile("p")
	expect_eq(r.success, true)
	expect_eq(r.normalized, 1)
	expect(Validators.is_valid_group(s.groups[0]))
	expect_eq(s.groups[0].items[0].launchGroup, 0)
	expect_eq(s.groups[0].items[0].shortcutKey, "F2", "applying a stored profile keeps its shortcut keys")
	s.free()
