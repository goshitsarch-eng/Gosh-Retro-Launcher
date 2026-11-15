extends TestCase
## Restore refuses when its safety backup cannot be written (like profile Apply), and the safety
## backup includes edits that were still waiting for the debounced save.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")
const REFUSED := "Could not back up your current data before restoring, so the backup was not restored."


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-rsafe-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func test_unwritable_backup_refuses_and_changes_nothing() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Old")
	var point: Dictionary = s.create_backup("manual")
	s.add_group("Precious")
	s.flush()
	# The backup to restore must stay readable while a new one cannot be written, so persistence is
	# swapped for one whose create_backup fails (same folder, same data).
	var stub := FailingBackupPersistence.new(dir)
	stub.init_store()
	s.persistence = stub
	var before: Array = s.groups.duplicate(true)
	var stored_before := FileAccess.get_file_as_string(stub.store_path())
	var failed := []
	s.save_failed.connect(func(kind: String, _m: String) -> void: failed.append(kind))
	var r: Dictionary = s.restore_backup(point.id)
	expect_eq(r.success, false)
	expect_eq(r.error, REFUSED)
	expect_eq(failed, ["backup"], "the host is told")
	expect(Jsonx.equal(s.groups, before), "groups in memory unchanged")
	expect_eq(FileAccess.get_file_as_string(stub.store_path()), stored_before, "stored file unchanged")
	# The Launcher Tools status line shows the same error.
	expect_eq(LauncherToolsLogic.restore_backup(s, point.id), REFUSED)
	s.free()
	_rm(dir)


func test_pending_edits_are_in_the_safety_backup() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Old")
	var point: Dictionary = s.create_backup("manual")
	s.add_group("Pending edit")  # not flushed: still waiting for the 300 ms debounce
	var r: Dictionary = s.restore_backup(point.id)
	expect_eq(r.success, true)
	expect_eq(r.backup.reason, "store-replaced")
	var saved: Dictionary = s.persistence.read_backup(r.backup.id)
	expect_eq(saved.groups.map(func(g): return g.name), ["Old", "Pending edit"], "pending edit backed up")
	expect_eq(s.groups.map(func(g): return g.name), ["Old"], "backup restored")
	s.free()
	_rm(dir)


## Reads backups normally but cannot write a new one.
class FailingBackupPersistence extends Persistence:
	func create_backup(_payload: Dictionary, _reason: String, _force: bool = false) -> Dictionary:
		return {}
