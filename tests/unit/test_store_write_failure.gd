extends TestCase
## A store file that cannot be written (read-only or full disk) is never dropped silently: the flush
## emits save_failed, the change stays pending, and the next flush that can write saves it.
## The data folder is made read-only with chmod and made writable again right after the flush, before
## any assertion runs, so a failing expectation never leaves it read-only.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-writefail-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _rm(path: String) -> void:
	_chmod(path, "755")
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


func _chmod(path: String, mode: String) -> void:
	OS.execute("chmod", [mode, path])


## Makes `dir` read-only and reports whether that actually blocks writes (it does not for root, or
## on Windows). When it does not, the folder is made writable again and false is returned.
func _make_read_only(dir: String) -> bool:
	if OS.get_name() == "Windows":
		return false
	_chmod(dir, "555")
	var probe := dir.path_join("probe.tmp")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return true
	f.close()
	DirAccess.remove_absolute(probe)
	_chmod(dir, "755")
	return false


func _store_text(dir: String) -> String:
	return FileAccess.get_file_as_string(dir.path_join(Persistence.STORE_FILE))


func test_persistence_setters_report_write_failure_and_keep_data_in_step() -> void:
	var dir := _tmp()
	var p := Persistence.new(dir)
	p.init_store()
	expect_eq(p.set_groups([]), true, "a normal write reports success")
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		_rm(dir)
		return
	var groups_ok := p.set_groups([Migration.normalize_group({"id": "g", "name": "Lost", "items": []})])
	var settings := p.get_settings()
	settings["theme"] = "dark"
	var settings_ok := p.set_settings(settings)
	_chmod(dir, "755")
	expect_eq(groups_ok, false, "set_groups reports the failed write")
	expect_eq(settings_ok, false, "set_settings reports the failed write")
	expect_eq(p.get_groups(), [], "refused groups are not kept in memory")
	expect_eq(p.get_settings().theme, "light", "refused settings are not kept in memory")
	expect(not _store_text(dir).contains("Lost"))
	_rm(dir)


func test_read_only_folder_keeps_the_change_pending_and_the_next_flush_saves_it() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Before")
	s.flush()
	var failed := []
	s.save_failed.connect(func(kind: String, msg: String) -> void: failed.append([kind, msg]))
	s.add_group("Pending")
	s.update_settings({"launchDelay": 1234})
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		s.free()
		_rm(dir)
		return
	s.flush()
	var tx: Dictionary = s.apply_settings_transaction(s.settings.merged({"theme": "dark"}, true))
	_chmod(dir, "755")  # writable again before any assertion
	var kinds := failed.map(func(f): return f[0])
	expect_eq(kinds, ["groups", "settings"], "both failed writes reported")
	if failed.size() == 2:
		expect(String(failed[0][1]).contains("could not be written"), "message names the cause: " + String(failed[0][1]))
		expect(String(failed[1][1]).contains("could not be written"), "message names the cause: " + String(failed[1][1]))
	expect_eq(s._groups_dirty, true, "groups stay pending")
	expect_eq(s._settings_dirty, true, "settings stay pending")
	expect_eq(s.groups.map(func(g): return g.name), ["Before", "Pending"], "change kept in memory")
	expect_eq(tx.success, false, "the settings transaction reports the failed write")
	expect_eq(s.settings.theme, "light", "a failed transaction changes nothing")
	expect(not _store_text(dir).contains("Pending"), "nothing reached the disk")
	# Writable again: the next flush saves the pending change.
	s.flush()
	expect_eq(s._groups_dirty, false)
	expect_eq(s._settings_dirty, false)
	expect_eq(failed.size(), 2, "no further failures")
	s.free()
	var b := _open(dir)
	expect_eq(b.groups.map(func(g): return g.name), ["Before", "Pending"], "the retried change was saved")
	expect_eq(b.settings.launchDelay, 1234)
	b.free()
	_rm(dir)


func test_save_recovered_fires_once_after_a_failure_and_not_for_ordinary_saves() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var recovered := []
	s.save_recovered.connect(func(kind: String) -> void: recovered.append(kind))
	s.add_group("A")
	s.update_settings({"launchDelay": 700})
	s.flush()
	expect_eq(recovered, [], "an ordinary save is not a recovery")
	s.add_group("B")
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		s.free()
		_rm(dir)
		return
	s.flush()
	s.flush()  # the retry fails again
	_chmod(dir, "755")
	expect_eq(recovered, [], "no recovery while failing")
	s.flush()
	expect_eq(recovered, ["groups"], "the first successful save after the failure")
	s.add_group("C")
	s.flush()
	expect_eq(recovered, ["groups"], "only once")
	s.free()
	_rm(dir)


func test_host_shows_a_failure_again_after_recovery() -> void:
	var host: Control = preload("res://src/app/main.gd").new()
	host._on_save_failed("groups", "m")
	host._on_save_failed("settings", "s")
	expect_eq(host._shown_save_failures.size(), 2)
	host._on_save_recovered("groups")
	expect_eq(host._shown_save_failures.keys(), ["settings|s"], "only the recovered kind is forgotten")
	host._on_save_failed("groups", "m")
	expect_eq(host._shown_save_failures.size(), 2, "the new groups failure is shown and remembered again")
	host.free()


func test_read_only_folder_reports_a_failed_profile_save_and_keeps_it_pending() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Base")
	s.flush()
	var failed := []
	s.save_failed.connect(func(kind: String, msg: String) -> void: failed.append([kind, msg]))
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		s.free()
		_rm(dir)
		return
	var id: String = s.save_workspace_profile("Office")
	s.rename_workspace_profile(id, "Office 2")  # a second change while the first is pending
	_chmod(dir, "755")  # writable again before any assertion
	var kinds := failed.map(func(f): return f[0])
	expect_eq(kinds, ["profiles", "profiles"], "each failed profile write reported")
	if failed.size() > 0:
		expect(String(failed[0][1]).contains("could not be written"), "message names the cause: " + String(failed[0][1]))
	expect_eq(s._profiles_dirty, true, "profiles stay pending")
	expect_eq(s.workspace_profiles.map(func(p): return p.name), ["Office 2"], "profiles kept in memory")
	expect(not _store_text(dir).contains("Office"), "nothing reached the disk")
	s.free()
	_rm(dir)


func test_pending_profile_save_is_written_by_the_next_flush_and_recovers() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.add_group("Base")
	s.flush()
	var recovered := []
	s.save_recovered.connect(func(kind: String) -> void: recovered.append(kind))
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		s.free()
		_rm(dir)
		return
	s.save_workspace_profile("Office")
	s.flush()  # the retry fails again
	_chmod(dir, "755")
	expect_eq(s._profiles_dirty, true, "still pending while the folder is read-only")
	expect_eq(recovered, [], "no recovery while failing")
	# Writable again: a groups flush writes the pending profiles first.
	s.add_group("After")
	s.flush()
	expect_eq(s._profiles_dirty, false)
	expect_eq(recovered, ["profiles"], "the first successful profile save after the failure")
	s.free()
	var b := _open(dir)
	expect_eq(b.workspace_profiles.map(func(p): return p.name), ["Office"], "the retried profiles were saved")
	expect_eq(b.groups.map(func(g): return g.name), ["Base", "After"])
	b.free()
	_rm(dir)


func test_exit_flush_retries_a_pending_profile_save() -> void:
	var dir := _tmp()
	var s := _open(dir)
	s.flush()
	if not _make_read_only(dir):
		print("  (skipped: a read-only folder is still writable here)")
		s.free()
		_rm(dir)
		return
	s.save_workspace_profile("Home")
	_chmod(dir, "755")
	expect_eq(s._groups_dirty or s._settings_dirty, false, "only profiles are pending")
	s.flush()  # what _exit_tree runs
	expect_eq(s._profiles_dirty, false)
	s.free()
	var b := _open(dir)
	expect_eq(b.workspace_profiles.map(func(p): return p.name), ["Home"], "saved by the profile-only flush")
	b.free()
	_rm(dir)


func test_host_notice_for_a_profile_failure_says_the_change_is_kept() -> void:
	var n: Dictionary = preload("res://src/app/main.gd").save_failed_notice("profiles", "p")
	expect(String(n.text).contains("saving is tried again"), String(n.text))
	expect_eq(n.alert, true)
