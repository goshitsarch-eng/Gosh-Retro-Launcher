extends TestCase
## End-to-end: what a person adds and every setting survives a restart and an export -> import.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-rt-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


func _populate(s: Node) -> void:
	var g: String = s.add_group("Web")
	s.add_item(g, {"name": "GitHub", "path": "https://github.com", "icon": "network", "workingDir": ""})
	s.add_item(g, {"name": "Chrome", "path": "/Applications/Google Chrome.app", "icon": "default", "workingDir": "",
		"arguments": "--incognito", "runMode": "minimized", "shortcutKey": "Ctrl+Alt+C"})
	s.update_settings({"shell": "mac", "macScale": 3, "win95Scale": 2, "soundEnabled": false, "trayOnClose": false,
		"launchDelay": 750, "minimizeOnUse": true})
	s.flush()


func _check(s: Node, label: String) -> void:
	expect_eq(s.groups.size(), 1, label + ": group kept")
	expect_eq(s.groups[0].name, "Web", label)
	expect_eq(s.groups[0].items.size(), 2, label + ": items kept")
	expect_eq(s.groups[0].items[0].path, "https://github.com", label)
	expect_eq(s.groups[0].items[1].arguments, "--incognito", label)
	expect_eq(s.groups[0].items[1].shortcutKey, "Ctrl+Alt+C", label)
	expect_eq(s.settings.shell, "mac", label)
	expect_eq(s.settings.macScale, 3, label)
	expect_eq(s.settings.win95Scale, 2, label)
	expect_eq(s.settings.soundEnabled, false, label)
	expect_eq(s.settings.trayOnClose, false, label)
	expect_eq(s.settings.launchDelay, 750, label)
	expect_eq(s.settings.minimizeOnUse, true, label)


func test_data_and_settings_survive_a_restart() -> void:
	var dir := _tmp()
	var a := _open(dir)
	_populate(a)
	a.free()
	var b := _open(dir)  # "restart"
	_check(b, "restart")
	b.free()


func test_export_then_import_into_a_fresh_profile() -> void:
	var src := _tmp()
	var a := _open(src)
	_populate(a)
	var file := src.path_join("backup.json")
	expect(a.export_to(file), "export writes the file")
	a.free()

	var dst := _tmp()
	var b := _open(dst)
	expect_eq(b.groups.size(), 0)
	expect_eq(b.import_from(file).success, true)
	_check(b, "after import")
	b.free()
	var c := _open(dst)  # the import itself must persist
	_check(c, "import then restart")
	c.free()


func test_failed_imports_leave_data_untouched() -> void:
	var dir := _tmp()
	var a := _open(dir)
	_populate(a)
	var junk := dir.path_join("junk.json")
	var f := FileAccess.open(junk, FileAccess.WRITE)
	f.store_string('{"groups": "nope"}')
	f.close()
	expect_eq(a.import_from(junk).success, false, "invalid file refused")
	expect_eq(a.import_from(dir.path_join("missing.json")).success, false)
	_check(a, "after failed imports")
	a.free()
