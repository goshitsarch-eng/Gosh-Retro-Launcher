extends TestCase
## Launcher Tools actions against a scratch ProgramStore.

func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-test-lt-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _store(dir: String) -> Node:
	var s: Node = load("res://src/core/program_store.gd").new()
	s.init_store(dir)
	return s


func test_appearance_apply_is_persist_first_and_reports_status() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var form := LauncherToolsLogic.appearance_form(s.settings)
	form.shell = "win95"
	form.win95Scale = 3
	form.win31DesktopMode = true
	form.soundEnabled = false
	form.trayOnClose = false
	var r := LauncherToolsLogic.apply_appearance(s, form)
	expect_eq(r.success, true)
	expect_eq(r.status, "Appearance settings applied. Active shell: Windows 95.")
	expect_eq(s.settings.shell, "win95")
	expect_eq(s.settings.win95Scale, 3)
	expect_eq(s.settings.win31DesktopMode, true)
	expect_eq(s.settings.soundEnabled, false)
	expect_eq(s.settings.trayOnClose, false)
	var p := Persistence.new(dir)
	p.init_store()
	expect_eq(p.get_settings().shell, "win95", "settings were written to disk")
	form.shell = "win31"
	expect_eq(LauncherToolsLogic.apply_appearance(s, form).status, "Appearance settings applied. Active shell: Windows for Workgroups 3.11.")
	s.free()
	_rm(dir)


func test_appearance_invalid_settings_roll_back_without_touching_store() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var form := LauncherToolsLogic.appearance_form(s.settings)
	form.win31Scale = 9  # not a valid preference
	var r := LauncherToolsLogic.apply_appearance(s, form)
	expect_eq(r.success, false)
	expect_eq(r.status, "Could not switch shells: Invalid settings data")
	expect_eq(s.settings.win31Scale, "auto", "previous settings kept")
	s.free()
	_rm(dir)


func test_url_launcher_rules() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("Net")
	expect_eq(LauncherToolsLogic.add_url(s, g, "  ", "https://x.org"), "", "name required")
	expect_eq(LauncherToolsLogic.add_url(s, g, "X", "ftp://x.org"), "", "http(s) only")
	expect_eq(LauncherToolsLogic.add_url(s, "", "X", "https://x.org"), "", "group required")
	expect_eq(s.find_group(g).items.size(), 0)
	expect_eq(LauncherToolsLogic.add_url(s, g, " X ", "HTTPS://x.org "), "URL launcher added.")
	var it: Dictionary = s.find_group(g).items[0]
	expect_eq(it.name, "X")
	expect_eq(it.path, "HTTPS://x.org")
	expect_eq(it.icon, "network")
	expect_eq(it.win31Icon, "network")
	expect_eq(it.workingDir, "")
	expect(Validators.is_valid_item(it))
	s.free()
	_rm(dir)


func test_launch_delay_clamp_and_labels() -> void:
	var dir := _tmp()
	var s := _store(dir)
	expect_eq(LauncherToolsLogic.set_delay(s, 20), 100)
	expect_eq(s.settings.launchDelay, 100)
	expect_eq(LauncherToolsLogic.set_delay(s, 999999), 5000)
	expect_eq(LauncherToolsLogic.set_delay(s, "abc"), 100)
	expect_eq(LauncherToolsLogic.set_delay(s, 1300), 1300)
	var buckets := [{"groupNumber": 2, "items": [1, 2]}, {"groupNumber": 5, "items": [1]}]
	expect_eq(LauncherToolsLogic.launch_group_label(buckets[0]), "Launch Group 2 (2 items)")
	expect_eq(LauncherToolsLogic.launch_group_label(buckets[1]), "Launch Group 5 (1 item)")
	expect_eq(LauncherToolsLogic.launch_status_start([buckets[0]]), "Launching Group 2...")
	expect_eq(LauncherToolsLogic.launch_status_start(buckets), "Launching all groups...")
	expect_eq(LauncherToolsLogic.launch_status_done([{"success": true}, {"success": true}]), "Launched 2 items.")
	expect_eq(LauncherToolsLogic.launch_status_done([{"success": true}]), "Launched 1 item.")
	expect_eq(LauncherToolsLogic.launch_status_done([{"success": true}, {"success": false}]), "Launch finished with 1 failure.")
	expect_eq(LauncherToolsLogic.launch_status_done([{"success": false}, {"success": false}]), "Launch finished with 2 failures.")
	s.free()
	_rm(dir)


func test_launch_groups_collected_from_assigned_items() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("G")
	s.add_item(g, {"name": "a", "path": "p", "icon": "default", "workingDir": "", "launchGroup": 2})
	s.add_item(g, {"name": "b", "path": "p", "icon": "default", "workingDir": "", "launchGroup": 1})
	s.add_item(g, {"name": "c", "path": "p", "icon": "default", "workingDir": "", "launchGroup": 2})
	s.add_item(g, {"name": "d", "path": "p", "icon": "default", "workingDir": ""})
	var buckets := LaunchGroups.collect_launch_groups(s.groups)
	expect_eq(buckets.size(), 2)
	expect_eq(buckets[0].groupNumber, 1)
	expect_eq(buckets[1].items.size(), 2)
	# the same buckets drive Launch Group / Launch All through the batch launcher
	var launched := []
	var fake := func(items: Array, _delay: Variant) -> Array:
		for it in items:
			launched.append(it.name)
		return items.map(func(it): return {"id": it.id, "success": true})
	var results: Array = await LaunchGroups.launch_group_buckets(null, buckets, 0, Callable(), fake)
	expect_eq(results.size(), 3)
	expect_eq(launched, ["b", "a", "c"])
	s.free()
	_rm(dir)


func test_item_choices_and_launch_profile_save() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("Main")
	var i: String = s.add_item(g, {"name": "Tool", "path": "p", "icon": "default", "workingDir": "/w"})
	var choices := LauncherToolsLogic.item_choices(s.groups)
	expect_eq(choices.size(), 1)
	expect_eq(choices[0].key, "%s:%s" % [g, i])
	expect_eq(choices[0].label, "Main — Tool")
	var u := LauncherToolsLogic.launch_profile_updates("-a", "/x", "K=V", "maximized", 99)
	expect_eq(u.launchGroup, 8, "batch group clamps to 0-8")
	expect_eq(u.runMode, "maximized")
	expect_eq(LauncherToolsLogic.launch_profile_updates("", "", "", "weird", -1).runMode, "normal")
	expect_eq(LauncherToolsLogic.launch_profile_updates("", "", "", "normal", -1).launchGroup, 0)
	expect_eq(LauncherToolsLogic.save_launch_profile(s, g, i, u), "Launch profile saved.")
	var it: Dictionary = s.find_item(g, i)
	expect_eq(it.arguments, "-a")
	expect_eq(it.workingDir, "/x")
	expect_eq(it.environment, "K=V")
	expect_eq(it.runMode, "maximized")
	expect_eq(it.launchGroup, 8)
	expect(Validators.is_valid_item(it))
	s.free()
	_rm(dir)


func test_grp_import_enriches_items_and_selects_group() -> void:
	var dir := _tmp()
	var s := _store(dir)
	s.add_group("Existing")
	var imported := {"id": "grp-1", "name": "Imported", "icon": "group",
		"windowState": Types.default_window_state(), "shellWindowState": Types.create_shell_window_state(),
		"items": [
			{"id": "a", "name": "A", "path": "/bin/a", "icon": "default", "workingDir": ""},
			{"id": "b", "name": "B", "path": "/bin/b", "icon": "default", "workingDir": "/keep"},
			{"id": "c", "name": "C", "path": "/bin/c", "icon": "default", "workingDir": ""}]}
	var info := func(path: String) -> Dictionary:
		if path == "/bin/c":
			return {}
		return {"icon": "data:icon-" + path, "win31Icon": "data:w31-" + path, "workingDir": "/info" + path}
	var r := LauncherToolsLogic.import_grp(s, {"success": true, "group": imported}, info)
	expect_eq(r.status, "Imported “Imported” from .GRP.")
	expect_eq(r.groupId, "grp-1")
	var g: Dictionary = s.find_group("grp-1")
	expect_eq(g.items[0].icon, "data:icon-/bin/a")
	expect_eq(g.items[0].win31Icon, "data:w31-/bin/a")
	expect_eq(g.items[0].workingDir, "/info/bin/a")
	expect_eq(g.items[1].workingDir, "/keep", "existing working dir wins")
	expect_eq(g.items[2].icon, "default", "no app info leaves the item untouched")
	expect_eq(s.groups.size(), 2)
	# cancel is silent, errors surface
	expect_eq(LauncherToolsLogic.import_grp(s, {"success": false, "error": "Canceled"}, info).status, "")
	expect_eq(LauncherToolsLogic.import_grp(s, {"success": false, "error": "Bad file"}, info).status, "Bad file")
	expect_eq(LauncherToolsLogic.import_grp(s, {"success": false}, info).status, "Could not import the group.")
	expect_eq(LauncherToolsLogic.export_grp_status("G", {"success": true}), "Exported “G” as a Windows 3.x .GRP file.")
	expect_eq(LauncherToolsLogic.export_grp_status("G", {"success": false, "error": "Canceled"}), "")
	expect_eq(LauncherToolsLogic.export_grp_status("G", {"success": false}), "Could not export the group.")
	expect_eq(LauncherToolsLogic.import_json_status({"success": true}), "Launcher backup imported.")
	expect_eq(LauncherToolsLogic.import_json_status({"success": false, "error": "Canceled"}), "")
	expect_eq(LauncherToolsLogic.import_json_status({"success": false}), "Import failed.")
	s.free()
	_rm(dir)


func test_workspace_profiles_flow() -> void:
	var dir := _tmp()
	var s := _store(dir)
	s.add_group("One")
	var saved := LauncherToolsLogic.save_profile(s, "  Work ")
	expect_eq(saved.status, "Workspace profile saved.")
	expect_eq(s.workspace_profiles[0].name, "Work")
	expect_eq(LauncherToolsLogic.profile_summary(s.workspace_profiles[0]).begins_with("1 group · updated "), true)
	s.add_group("Two")
	expect_eq(s.groups.size(), 2)
	expect_eq(LauncherToolsLogic.apply_profile(s, saved.id), "Workspace profile applied.")
	expect_eq(s.groups.size(), 1)
	LauncherToolsLogic.rename_profile(s, saved.id, "Home")
	expect_eq(s.workspace_profiles[0].name, "Home")
	LauncherToolsLogic.rename_profile(s, saved.id, "   ")
	expect_eq(s.workspace_profiles[0].name, "Home", "blank rename ignored")
	LauncherToolsLogic.delete_profile(s, saved.id)
	expect_eq(s.workspace_profiles.size(), 0)
	var unnamed := LauncherToolsLogic.save_profile(s, "")
	expect_eq(s.workspace_profiles[0].name, "Workspace 1")
	expect(unnamed.id != "")
	s.free()
	_rm(dir)


func test_backups_create_list_restore() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("Before")
	var before: int = s.list_backups().size()
	expect_eq(LauncherToolsLogic.create_backup(s), "Restore point created.")
	var list: Array = s.list_backups()
	expect(list.size() > before, "backup created")
	var manual := list.filter(func(b): return b.reason == "manual")
	expect(manual.size() >= 1)
	expect_eq(LauncherToolsLogic.backup_label(manual[0]).ends_with("— manual"), true)
	s.update_group(g, {"name": "After"})
	s.flush()
	expect_eq(LauncherToolsLogic.restore_backup(s, manual[0].id), "Backup restored.")
	expect_eq(s.groups[0].name, "Before")
	expect_eq(LauncherToolsLogic.restore_backup(s, "../evil"), "Invalid backup identifier")
	s.free()
	_rm(dir)
