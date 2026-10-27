extends TestCase
## Covers store.ts / backups.ts / programStore.ts behavior with a scratch user-data dir.

func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-test-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func test_fresh_store_has_defaults_and_writes_file() -> void:
	var dir := _tmp()
	var p := Persistence.new(dir)
	p.init_store()
	expect(FileAccess.file_exists(dir.path_join("program-manager-data.json")))
	expect_eq(p.get_groups(), [])
	expect_eq(p.get_settings().shell, "win31")
	expect_eq(p.get_all_data().schemaVersion, Types.CURRENT_SCHEMA_VERSION)
	_rm(dir)


func test_reads_existing_electron_store_file() -> void:
	# Same on-disk shape electron-store wrote (tab-indented, schemaVersion 2, legacy window state).
	var dir := _tmp()
	var f := FileAccess.open(dir.path_join("program-manager-data.json"), FileAccess.WRITE)
	f.store_string('{\n\t"schemaVersion": 2,\n\t"groups": [{"id":"g","name":"Main","icon":"group","windowState":{"x":1,"y":2,"width":416,"height":201,"minimized":false,"maximized":false},"items":[{"id":"i","name":"App","path":"/bin/app","icon":"dos","workingDir":""}]}],\n\t"settings": {"shell":"win95","win95Scale":2,"trayOnClose":false,"soundEnabled":false}\n}')
	f.close()
	var p := Persistence.new(dir)
	p.init_store()
	var all := p.get_all_data()
	expect_eq(all.groups[0].name, "Main")
	expect_eq(all.groups[0].shellWindowState.win95.width, 416)
	expect_eq(all.settings.shell, "win95")
	expect_eq(all.settings.win95Scale, 2)
	expect_eq(all.settings.trayOnClose, false)
	expect_eq(all.settings.launchDelay, 500, "defaults merged")
	_rm(dir)


func test_whole_numbers_serialize_like_js() -> void:
	var text := Jsonx.stringify({"a": 1.0, "b": 2.5, "c": [3.0], "d": {"e": 10}}, "")
	expect(text.contains('"a":1,') or text.contains('"a": 1,'), text)
	expect(not text.contains("1.0"), text)


func test_corrupt_store_recovers_from_latest_backup() -> void:
	var dir := _tmp()
	var p := Persistence.new(dir)
	p.init_store()
	p.set_groups([Migration.normalize_group({"id": "g", "name": "Keep", "windowState": Types.default_window_state(), "items": []})])
	p.create_backup(p.get_all_data(), "unit test", true)
	var f := FileAccess.open(p.store_path(), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var p2 := Persistence.new(dir)
	p2.init_store()
	expect_eq(p2.get_groups().size(), 1)
	expect_eq(p2.get_groups()[0].name, "Keep")
	var corrupt := 0
	for n in DirAccess.get_files_at(dir):
		if n.contains(".corrupt-"):
			corrupt += 1
	expect_eq(corrupt, 1, "corrupt file preserved")
	_rm(dir)


func test_backups_list_prune_and_read() -> void:
	var dir := _tmp()
	var p := Persistence.new(dir)
	p.init_store()
	var info := p.create_backup(p.get_all_data(), "Manual Restore Point!", true)
	expect_eq(info.reason, "manual-restore-point")
	expect(String(info.id).ends_with("--manual-restore-point.json"), info.id)
	expect_eq(p.list_backups().size(), 1)
	expect_eq(p.list_backups()[0].id, info.id)
	expect(not p.read_backup(info.id).is_empty())
	expect(p.read_backup("../evil.json").is_empty(), "path traversal rejected")
	expect(p.read_backup("nope.txt").is_empty())
	# pruning keeps the newest BACKUP_LIMIT
	for i in 15:
		var f := FileAccess.open(p.backup_dir().path_join("2020-01-%02dT00-00-00.000Z--old.json" % (i + 1)), FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	p.create_backup(p.get_all_data(), "again", true)
	expect_eq(p.list_backups().size(), Persistence.BACKUP_LIMIT)
	_rm(dir)


func test_automatic_backups_are_throttled() -> void:
	var dir := _tmp()
	var p := Persistence.new(dir)
	p.init_store()
	expect(not p.create_backup(p.get_all_data(), "a").is_empty())
	expect(p.create_backup(p.get_all_data(), "b").is_empty(), "second auto backup inside 30s skipped")
	expect(not p.create_backup(p.get_all_data(), "c", true).is_empty(), "forced still works")
	_rm(dir)


func _store(dir: String) -> Node:
	var s: Node = load("res://src/core/program_store.gd").new()
	s.init_store(dir)
	return s


func test_program_store_mutations_persist_on_flush() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var gid: String = s.add_group("Games")
	var iid: String = s.add_item(gid, {"name": "Doom", "path": "/bin/doom", "icon": "games", "workingDir": ""})
	s.update_item(gid, iid, {"launchGroup": 2})
	s.update_settings({"shell": "win95", "win95Scale": 3})
	s.flush()
	var s2 := _store(dir)
	expect_eq(s2.groups.size(), 1)
	expect_eq(s2.groups[0].items[0].name, "Doom")
	expect_eq(s2.groups[0].items[0].launchGroup, 2)
	expect_eq(s2.settings.shell, "win95")
	expect_eq(s2.settings.win95Scale, 3)
	s.free()
	s2.free()
	_rm(dir)


func test_item_move_copy_and_group_ops() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var a: String = s.add_group("A")
	var b: String = s.add_group("B")
	var iid: String = s.add_item(a, {"name": "X", "path": "x", "icon": "default", "workingDir": "", "win31Position": {"x": 1, "y": 2}})
	s.copy_item(a, b, iid)
	expect_eq(s.find_group(b).items.size(), 1)
	expect(not s.find_group(b).items[0].has("win31Position"), "copy drops positions")
	expect(s.find_group(b).items[0].id != iid, "copy gets new id")
	s.move_item(a, b, iid)
	expect_eq(s.find_group(a).items.size(), 0)
	expect_eq(s.find_group(b).items.size(), 2)
	s.delete_group(a)
	expect_eq(s.groups.size(), 1)
	s.add_starter_workspace()
	expect_eq(s.groups.size(), 6, "B plus the five starter groups")
	expect_eq(s.groups[1].name, "Main")
	expect_eq(s.groups[1].shellWindowState.win31.minimized, false, "Main stays open")
	expect_eq(s.groups[2].shellWindowState.win31.minimized, true)
	s.free()
	_rm(dir)


func test_win95_and_win31_window_state_are_independent() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("A")
	s.update_group_window_state(g, {"x": 99, "width": 400}, "win95")
	var grp: Dictionary = s.find_group(g)
	expect_eq(grp.shellWindowState.win95.x, 99)
	expect_eq(grp.shellWindowState.win95.width, 400)
	expect_eq(grp.shellWindowState.win31.x, 20)
	s.free()
	_rm(dir)


func test_import_validation_and_export_roundtrip() -> void:
	var dir := _tmp()
	var s := _store(dir)
	s.add_group("Exported")
	var out := dir.path_join("export.json")
	expect(s.export_to(out))
	var s2 := _store(_tmp())
	var r: Dictionary = s2.import_from(out)
	expect_eq(r.success, true)
	expect_eq(s2.groups[0].name, "Exported")
	# malformed
	var bad := dir.path_join("bad.json")
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string('{"groups": [{"id": 1}], "settings": {}}')
	f.close()
	expect_eq(s2.import_from(bad).error, "Invalid file format")
	f = FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	expect_eq(s2.import_from(bad).error, "Failed to read file")
	s.free()
	s2.free()
	_rm(dir)


func test_workspace_profiles() -> void:
	var dir := _tmp()
	var s := _store(dir)
	s.add_group("One")
	var pid: String = s.save_workspace_profile("  Work  ")
	expect_eq(s.workspace_profiles[0].name, "Work")
	s.delete_group(s.groups[0].id)
	expect_eq(s.groups.size(), 0)
	s.apply_workspace_profile(pid)
	expect_eq(s.groups.size(), 1)
	s.rename_workspace_profile(pid, "   ")
	expect_eq(s.workspace_profiles[0].name, "Work", "blank rename ignored")
	s.delete_workspace_profile(pid)
	expect_eq(s.workspace_profiles.size(), 0)
	s.free()
	_rm(dir)
