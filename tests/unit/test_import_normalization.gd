extends TestCase
## CORE-01 / CORE-02 import side: JSON, profile and .GRP imports are normalised, shortcut keys without
## a modifier are cleared and counted, while the user's own stored shortcut keys are never cleared.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-importnorm-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


func _write_json(path: String, value: Variant) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()
	return path


func _item(id: String, extra: Dictionary = {}) -> Dictionary:
	var it := {"id": id, "name": id, "path": "/bin/" + id, "icon": "default", "workingDir": ""}
	it.merge(extra, true)
	return it


func _group(id: String, items: Array) -> Dictionary:
	return {"id": id, "name": id, "icon": "group", "windowState": Types.default_window_state(), "items": items}


func _import_file(dir: String) -> String:
	return _write_json(dir.path_join("import.json"), {
		"schemaVersion": 5,
		"groups": [_group("top", [
			_item("t1", {"shortcutKey": "F5"}),
			_item("t2", {"shortcutKey": "Ctrl+Alt+T", "launchGroup": 12}),
		])],
		"settings": Types.default_settings(),
		"workspaceProfiles": [{"id": "p1", "name": "Bad profile", "createdAt": "x", "updatedAt": "y", "groups": [
			_group("pg", [
				_item("p1", {"launchGroup": -1, "shortcutKey": "enter"}),
				_item("p2", {"launchGroup": 2.5, "runMode": "bogus", "shortcutKey": "Cmd+K"}),
				_item("p3", {"shortcutKey": "Shift+Down", "launchGroup": 4}),
				{"id": "broken"},
			]),
		]}],
	})


func test_safe_shortcut_rules() -> void:
	for ok in ["", "  ", "Ctrl+Alt+F5", "alt+x", "Shift+Enter", "Meta+K", "Win+E", "ctrl + q"]:
		expect(Validators.is_safe_shortcut(ok), "safe: '%s'" % ok)
	for bad in ["enter", "F5", "a", "down", "Cmd+K", "Ctrl", "x+Ctrl"]:
		expect(not Validators.is_safe_shortcut(bad), "unsafe: '%s'" % bad)


func test_json_import_normalises_profiles_and_clears_bare_shortcuts() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var seen := []
	s.data_normalized.connect(func(src: String, rep: Dictionary) -> void: seen.append([src, rep]))
	var r: Dictionary = s.import_from(_import_file(dir))
	expect_eq(r.success, true)
	# launchGroup 12, -1, 2.5, runMode "bogus" and the item without name/path.
	expect_eq(r.normalized, 5, "values changed")
	expect_eq(r.shortcutsCleared, 3, "F5, enter and Cmd+K cleared")
	expect_eq(seen.size(), 1)
	expect_eq(seen[0][0], "import")
	expect_eq(seen[0][1], {"normalized": 5, "shortcutsCleared": 3})
	var top: Array = s.groups[0].items
	expect_eq(top[0].shortcutKey, "", "bare F5 cleared")
	expect_eq(top[1].shortcutKey, "Ctrl+Alt+T", "modifier shortcut kept")
	expect_eq(top[1].launchGroup, 0, "12 is out of range")
	var prof: Dictionary = s.workspace_profiles[0]
	expect(Validators.is_valid_workspace_profile(prof), "imported profile is valid")
	var pitems: Array = prof.groups[0].items
	expect_eq(pitems.size(), 3, "unrepairable item dropped")
	expect_eq(pitems[0].launchGroup, 0)
	expect_eq(pitems[0].shortcutKey, "")
	expect_eq(pitems[1].launchGroup, 0)
	expect(not pitems[1].has("runMode"), "invalid runMode dropped")
	expect_eq(pitems[1].shortcutKey, "")
	expect_eq(pitems[2].shortcutKey, "Shift+Down")
	expect_eq(pitems[2].launchGroup, 4)
	# Applying the imported profile, then editing: the edit must be persisted (the CORE-01 repro).
	expect_eq(s.apply_workspace_profile("p1").success, true)
	s.update_item("pg", "p3", {"name": "Renamed"})
	s.flush()
	s.free()
	var b := _open(dir)
	expect_eq(b.groups[0].id, "pg")
	expect_eq(b.groups[0].items[2].name, "Renamed", "edit after applying the profile survived a restart")
	expect_eq(b.groups[0].items[0].shortcutKey, "")
	b.free()


func test_json_import_repairs_top_level_values_instead_of_refusing() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var settings := Types.default_settings()
	settings["theme"] = "blue"
	settings["extra"] = 1
	var path := _write_json(dir.path_join("vals.json"), {"groups": [_group("g", [_item("a", {"launchGroup": -1})])],
		"settings": settings})
	var r: Dictionary = s.import_from(path)
	expect_eq(r, {"success": true, "normalized": 2, "shortcutsCleared": 0})
	expect_eq(s.groups[0].items[0].launchGroup, 0)
	expect_eq(s.settings.theme, "light")
	expect_eq(s.settings.extra, 1, "unknown key kept")
	# Structure problems are still refused.
	expect_eq(s.import_from(_write_json(dir.path_join("s.json"), {"groups": [], "settings": {}})).success, false)
	expect_eq(s.import_from(_write_json(dir.path_join("n.json"), {"groups": [{"id": "x"}], "settings": Types.default_settings()})).success, false)
	s.free()


func test_clean_import_reports_nothing() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var path := _write_json(dir.path_join("clean.json"), {"groups": [_group("g", [_item("a", {"shortcutKey": "Alt+A"})])],
		"settings": Types.default_settings()})
	expect_eq(s.import_from(path), {"success": true})
	expect_eq(s.groups[0].items[0].shortcutKey, "Alt+A")
	s.free()


func test_grp_import_clears_bare_shortcuts_and_normalises() -> void:
	# Grp.parse never sets shortcutKey, so the store entry point is exercised with a group dict.
	var dir := _tmp()
	var s := _open(dir)
	var r: Dictionary = s.import_group(_group("grp", [
		_item("a", {"shortcutKey": "space"}),
		_item("b", {"shortcutKey": "Ctrl+Alt+B", "launchGroup": 9}),
	]))
	expect_eq(r, {"success": true, "normalized": 1, "shortcutsCleared": 1})
	expect_eq(s.groups[0].items[0].shortcutKey, "")
	expect_eq(s.groups[0].items[1].shortcutKey, "Ctrl+Alt+B")
	expect_eq(s.groups[0].items[1].launchGroup, 0)
	expect(Validators.is_valid_group(s.groups[0]))
	expect_eq(s.import_group({"name": "no id"}).success, false, "unusable group refused")
	expect_eq(s.groups.size(), 1)
	s.save_groups_now()
	s.free()
	var b := _open(dir)
	expect_eq(b.groups[0].items[0].shortcutKey, "", "persisted")
	b.free()


func test_real_grp_parse_result_imports_unchanged() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var encoded := Grp.serialize(_group("Games", [_item("sol", {"arguments": "-x"})]))
	expect(encoded.ok)
	var parsed := Grp.parse(encoded.bytes)
	expect(parsed.ok)
	var r: Dictionary = s.import_group(parsed.group)
	expect_eq(r, {"success": true, "normalized": 0, "shortcutsCleared": 0})
	expect_eq(s.groups[0].name, "Games")
	expect_eq(s.groups[0].items[0].arguments, "-x")
	s.free()


func test_migration_keeps_stored_bare_shortcuts() -> void:
	var dir := _tmp()
	var f := FileAccess.open(dir.path_join(Persistence.STORE_FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({"groups": [_group("g", [_item("a", {"shortcutKey": "F5"})])],
		"workspaceProfiles": [{"id": "p", "name": "P", "groups": [_group("g", [_item("a", {"shortcutKey": "enter"})])]}]}))
	f.close()
	var s := _open(dir)
	expect_eq(s.load_report.normalized, 0)
	expect_eq(s.groups[0].items[0].shortcutKey, "F5", "the user's own key is not cleared on load")
	expect_eq(s.workspace_profiles[0].groups[0].items[0].shortcutKey, "enter")
	# Restoring a backup is also the user's own data: keys stay.
	var backup: Dictionary = s.create_backup("manual")
	s.update_item("g", "a", {"shortcutKey": "Ctrl+Alt+Z"})
	s.flush()
	expect_eq(s.restore_backup(backup.id).success, true)
	expect_eq(s.groups[0].items[0].shortcutKey, "F5")
	s.free()
	var b := _open(dir)
	expect_eq(b.groups[0].items[0].shortcutKey, "F5", "still there after a restart")
	b.free()
