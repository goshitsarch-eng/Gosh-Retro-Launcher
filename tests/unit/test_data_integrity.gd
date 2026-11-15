extends TestCase
## CORE-01: invalid stored values are normalised on load, a save is never skipped silently, and
## valid data loads and saves byte-for-byte as before.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-integrity-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _store_text(dir: String) -> String:
	return FileAccess.get_file_as_string(dir.path_join(Persistence.STORE_FILE))


func _stored(dir: String) -> Dictionary:
	return Jsonx.parse(_store_text(dir))


const BAD_STORE := '{"schemaVersion": 5, "groups": [{"id": "g1", "name": "Main", "icon": "group",
	"windowState": {"x": 1, "y": 2, "width": 300, "height": 200, "minimized": false, "maximized": false},
	"items": [
		{"id": "a", "name": "Neg", "path": "/bin/a", "icon": "default", "workingDir": "", "launchGroup": -1},
		{"id": "b", "name": "Half", "path": "/bin/b", "icon": "default", "workingDir": "", "launchGroup": 2.5},
		{"id": "c", "name": "Ok", "path": "/bin/c", "icon": "default", "workingDir": "", "launchGroup": 3,
			"shortcutKey": "enter"}
	]}],
	"settings": {"theme": "blue", "launchDelay": 750, "futureKey": {"keep": true}}}'


func test_invalid_store_loads_normalised_and_later_edits_persist() -> void:
	var dir := _tmp()
	_write(dir.path_join(Persistence.STORE_FILE), BAD_STORE)
	var a := _open(dir)
	expect_eq(a.load_report.normalized, 3, "two launchGroups and one setting repaired")
	var items: Array = a.groups[0].items
	expect_eq(items[0].launchGroup, 0, "-1 becomes 0")
	expect_eq(items[1].launchGroup, 0, "2.5 becomes 0")
	expect_eq(items[2].launchGroup, 3, "valid value kept")
	expect_eq(items[2].shortcutKey, "enter", "migration never clears the user's own shortcut keys")
	expect_eq(a.settings.theme, "light", "invalid theme reset to the default")
	expect_eq(a.settings.launchDelay, 750, "valid setting kept")
	expect_eq(a.settings.futureKey, {"keep": true}, "unknown key kept untouched")
	expect(Validators.is_valid_settings(a.settings))
	expect(Validators.is_valid_group(a.groups[0]))
	# The normalised data is what is on disk now.
	var disk := _stored(dir)
	expect_eq(disk.groups[0].items[0].launchGroup, 0)
	expect_eq(disk.settings.theme, "light")
	expect_eq(disk.settings.futureKey, {"keep": true})
	a.free()

	var b := _open(dir)  # reopen, then edit: the edit must be written
	expect_eq(b.load_report.normalized, 0, "already clean on the second load")
	b.update_item("g1", "a", {"name": "Renamed"})
	b.update_settings({"soundEnabled": false})
	b.flush()
	b.free()
	var c := _open(dir)
	expect_eq(c.groups[0].items[0].name, "Renamed", "later group edit persisted")
	expect_eq(c.settings.soundEnabled, false, "later settings edit persisted")
	c.free()


func test_invalid_in_memory_groups_are_repaired_and_saved_not_skipped() -> void:
	var dir := _tmp()
	var a := _open(dir)
	var g: String = a.add_group("G")
	var i: String = a.add_item(g, {"name": "X", "path": "/bin/x", "icon": "default", "workingDir": ""})
	a.flush()
	var seen := []
	a.data_normalized.connect(func(src: String, rep: Dictionary) -> void: seen.append([src, rep]))
	var failed := []
	a.save_failed.connect(func(kind: String, msg: String) -> void: failed.append(kind))
	# A caller that bypasses the editors' clamping. Before the fix this made every later save a no-op.
	a.update_item(g, i, {"launchGroup": -1, "name": "Edited"})
	a.flush()
	expect_eq(seen.size(), 1, "repair announced")
	expect_eq(seen[0][0], "save")
	expect_eq(seen[0][1].normalized, 1)
	expect_eq(failed, [], "nothing was left unsaved")
	expect_eq(a.groups[0].items[0].launchGroup, 0, "repair applied in memory too")
	a.free()
	var b := _open(dir)
	expect_eq(b.groups[0].items[0].name, "Edited", "the edit reached the disk")
	expect_eq(b.groups[0].items[0].launchGroup, 0)
	b.free()


func test_invalid_in_memory_settings_are_reset_and_saved() -> void:
	var dir := _tmp()
	var a := _open(dir)
	var seen := []
	a.data_normalized.connect(func(src: String, rep: Dictionary) -> void: seen.append(rep.normalized))
	a.update_settings({"theme": "purple", "launchDelay": 900})
	a.flush()
	expect_eq(seen, [1])
	expect_eq(a.settings.theme, "light")
	a.free()
	var b := _open(dir)
	expect_eq(b.settings.launchDelay, 900, "the valid part of the edit was written")
	expect_eq(b.settings.theme, "light")
	b.free()


func test_migration_output_always_passes_the_validators() -> void:
	var junk := [null, 5, "x", [], {}, -1, 2.5, 12, true, {"a": 1}, INF]
	for v in junk:
		var m := Migration.migrate_store_data({
			"groups": [{"id": "g", "name": "n", "icon": v, "windowState": v, "shellWindowState": v, "win31IconPosition": v,
				"items": [{"id": "i", "name": "n", "path": "/p", "icon": v, "workingDir": v, "arguments": v,
					"runMode": v, "launchGroup": v, "shortcutKey": v, "runMinimized": v, "win31Position": v}]}],
			"settings": {"autoArrange": v, "launchDelay": v, "groupChromeScale": v, "theme": v, "labelDisplay": v,
				"shell": v, "soundEnabled": v, "win31Scale": v, "win95DesktopIconPositions": v,
				"win31ProgramManagerBounds": v, "trayOnClose": v},
			"workspaceProfiles": [{"id": "p", "name": "P", "groups": [{"id": "g", "name": "n",
				"items": [{"id": "i", "name": "n", "path": "/p", "launchGroup": v}]}]}],
		})
		expect(Validators.is_valid_settings(m.settings), "settings valid for %s" % str(v))
		expect(Validators.is_valid_group(m.groups[0]), "group valid for %s" % str(v))
		expect(Validators.is_valid_workspace_profile(m.workspaceProfiles[0]), "profile valid for %s" % str(v))


func test_normalisation_counts_and_keeps_unknown_keys() -> void:
	var ctx := {"normalized": 0}
	var s := Migration.normalize_settings({"launchDelay": -5, "groupChromeScale": 0, "shell": "amiga", "mystery": "x",
		"soundEnabled": "yes", "macScale": 3}, ctx)
	expect_eq(ctx.normalized, 4)
	expect_eq(s.launchDelay, 500)
	expect_eq(s.groupChromeScale, 1)
	expect_eq(s.shell, "win31")
	expect_eq(s.soundEnabled, true)
	expect_eq(s.macScale, 3)
	expect_eq(s.mystery, "x")
	# Without a counter nothing is recorded and nothing fails.
	var plain := Migration.normalize_settings({"theme": "blue"})
	expect_eq(plain.theme, "light")
	expect(Validators.is_valid_launch_group(8) and Validators.is_valid_launch_group(0.0))
	expect(not Validators.is_valid_launch_group(9) and not Validators.is_valid_launch_group(-1))
	expect(not Validators.is_valid_launch_group(2.5) and not Validators.is_valid_launch_group("3"))


func test_valid_data_round_trips_byte_for_byte() -> void:
	var dir := _tmp()
	var a := _open(dir)
	var g: String = a.add_group("Web")
	a.add_item(g, {"name": "GitHub", "path": "https://github.com", "icon": "network", "workingDir": "",
		"launchGroup": 8, "runMode": "minimized", "shortcutKey": "Ctrl+Alt+G", "arguments": "--x"})
	a.add_item(g, {"name": "Plain", "path": "/bin/plain", "icon": "default", "workingDir": "/tmp"})
	a.update_settings({"shell": "be", "beScale": 2, "launchDelay": 1250, "theme": "dark", "customKey": [1, 2]})
	a.save_workspace_profile("Snap")
	a.flush()
	a.free()
	var before := _store_text(dir)
	var b := _open(dir)
	expect_eq(b.load_report.normalized, 0, "valid data needs no repair")
	b.save_groups_now()
	b.save_settings_now()
	b.free()
	var after := _store_text(dir)
	expect(before == after, "store text unchanged after reopen and save:\n%s\n----\n%s" % [before, after])
	var disk := _stored(dir)
	var top_keys: Array = disk.keys()
	top_keys.sort()
	expect_eq(top_keys, ["groups", "schemaVersion", "settings", "workspaceProfiles"], "same top-level keys")
	expect_eq(disk.settings.customKey, [1, 2])
	expect_eq(disk.groups[0].items[0].launchGroup, 8)
	expect_eq(disk.groups[0].items[0].shortcutKey, "Ctrl+Alt+G")
	expect(not disk.groups[0].items[1].has("launchGroup"), "no launchGroup key added where there was none")


func test_hand_written_electron_layout_is_kept() -> void:
	# A valid file in the Electron build's shape: loading it must not count or alter any value.
	var dir := _tmp()
	_write(dir.path_join(Persistence.STORE_FILE), '{"schemaVersion": 5, "groups": [{"id": "g", "name": "M", "icon": "group",
		"windowState": {"x": 1, "y": 2, "width": 416, "height": 201, "minimized": false, "maximized": false},
		"items": [{"id": "i", "name": "App", "path": "/bin/app", "icon": "dos", "workingDir": "", "launchGroup": 2,
		"runMode": "normal", "shortcutKey": "Ctrl+Alt+A"}]}],
		"settings": {"shell": "win95", "win95Scale": 2, "trayOnClose": false, "launchDelay": 0, "groupChromeScale": 1.5}}')
	var a := _open(dir)
	expect_eq(a.load_report.normalized, 0)
	var first := _store_text(dir)
	a.free()
	var b := _open(dir)
	b.free()
	expect(first == _store_text(dir), "second load writes identical text")
	var disk := _stored(dir)
	expect_eq(disk.settings.groupChromeScale, 1.5)
	expect_eq(disk.settings.launchDelay, 0)
	expect_eq(disk.groups[0].items[0].launchGroup, 2)


const ICON_AND_STATE_STORE := '{"schemaVersion": 5, "groups": [
	{"id": "g1", "name": "NumIcon", "icon": 5,
		"windowState": {"x": 1, "y": 2, "width": 300, "height": 200, "minimized": false, "maximized": false}, "items": []},
	{"id": "g2", "name": "BadState", "icon": "group", "windowState": "tall", "items": []}],
	"settings": {}}'


func test_load_counts_a_non_string_icon_and_an_invalid_window_state() -> void:
	var dir := _tmp()
	_write(dir.path_join(Persistence.STORE_FILE), ICON_AND_STATE_STORE)
	var a := _open(dir)
	expect_eq(a.load_report.normalized, 2, "the icon and the windowState are counted")
	a.free()
	var disk := _stored(dir)
	expect_eq(disk.groups[0].icon, "folder", "non-string icon replaced")
	expect(Validators.is_window_state(disk.groups[1].windowState), "windowState valid on disk")
	expect(Validators.is_valid_group(disk.groups[0]) and Validators.is_valid_group(disk.groups[1]))
	# Each repair on its own is counted too.
	for g in Jsonx.parse(ICON_AND_STATE_STORE).groups:
		var ctx := {"normalized": 0}
		Migration.normalize_group(g, ctx)
		expect(int(ctx.normalized) > 0, "counted for %s" % g.name)


func test_save_repair_counts_a_non_string_icon_and_an_invalid_window_state() -> void:
	var dir := _tmp()
	var a := _open(dir)
	var g1: String = a.add_group("Icon")
	var g2: String = a.add_group("State")
	a.flush()
	var seen := []
	a.data_normalized.connect(func(src: String, rep: Dictionary) -> void: seen.append([src, rep.normalized]))
	a.update_group(g1, {"icon": 7})
	a.flush()
	expect_eq(seen, [["save", 1]], "icon repair counted, so the notice is shown")
	seen.clear()
	# Without a valid shellWindowState the invalid windowState is what the save guard sees.
	a.update_group(g2, {"windowState": "tall", "shellWindowState": null})
	a.flush()
	expect_eq(seen.size(), 1)
	if seen.size() == 1:
		expect(int(seen[0][1]) > 0, "windowState repair counted")
	a.free()
	var disk := _stored(dir)
	expect_eq(disk.groups[0].icon, "folder", "saved icon is a string")
	expect(Validators.is_window_state(disk.groups[1].windowState), "saved windowState is valid")
	expect(Validators.is_valid_group(disk.groups[0]) and Validators.is_valid_group(disk.groups[1]))


func test_item_value_repairs_are_counted() -> void:
	var ctx := {"normalized": 0}
	var it: Variant = Migration._normalize_item({"id": "i", "name": "n", "path": "/p", "icon": 3, "workingDir": 1,
		"arguments": [], "runMinimized": "yes", "win31Position": {"x": "a"}}, ctx)
	expect_eq(ctx.normalized, 5)
	expect(Validators.is_valid_item(it))
	var clean := {"normalized": 0}
	Migration._normalize_item({"id": "i", "name": "n", "path": "/p", "icon": "dos"}, clean)
	expect_eq(clean.normalized, 0, "a missing optional workingDir is filled in, not counted")
