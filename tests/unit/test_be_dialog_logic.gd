extends TestCase
## BeDialogLogic: folder/item operations against a ProgramStore, Find, clock, feedback text.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "be"
	s.settings["saveSettingsOnExit"] = false
	return s


func _seed(s: Node) -> Array:
	var gid: String = s.add_group("Work")
	var other: String = s.add_group("Play")
	var a: String = s.add_item(gid, {"name": "Zed", "path": "C:\\zed.exe", "icon": "default", "workingDir": "", "launchGroup": 2})
	var b: String = s.add_item(gid, {"name": "Alpha", "path": "https://example.com", "icon": "url", "workingDir": ""})
	return [gid, other, a, b]


func test_create_rename_and_stats() -> void:
	var s := _store()
	expect_eq(BeDialogLogic.create_folder(s, "  "), "")
	var gid := BeDialogLogic.create_folder(s, " Tools ")
	expect_eq(s.find_group(gid).name, "Tools")
	expect(BeDialogLogic.rename_group(s, gid, "Utils"))
	expect(not BeDialogLogic.rename_group(s, gid, "   "))
	expect_eq(s.find_group(gid).name, "Utils")
	var ids := _seed(s)
	expect_eq(BeDialogLogic.group_stats(s.find_group(ids[0])), {"items": 2, "batched": 1})
	expect(BeDialogLogic.rename_item(s, ids[0], ids[2], "Zed 2"))
	expect(not BeDialogLogic.rename_item(s, ids[0], ids[2], ""))
	expect(not BeDialogLogic.rename_item(s, ids[0], "nope", "x"))
	expect_eq(s.find_item(ids[0], ids[2]).name, "Zed 2")
	s.free()


func test_duplicate_adds_a_copy_without_positions() -> void:
	var s := _store()
	var ids := _seed(s)
	s.update_item(ids[0], ids[2], {"win95Position": {"x": 1, "y": 2}})
	var copy_id := BeDialogLogic.duplicate_item(s, ids[0], ids[2])
	var copy: Dictionary = s.find_item(ids[0], copy_id)
	expect_eq(copy.name, "Zed copy")
	expect_eq(copy.path, "C:\\zed.exe")
	expect(not copy.has("win95Position"))
	expect(copy_id != ids[2])
	expect_eq(BeDialogLogic.duplicate_item(s, ids[0], "missing"), "")
	s.free()


func test_trash_item_and_group() -> void:
	var s := _store()
	var ids := _seed(s)
	BeDialogLogic.trash_item(s, ids[0], ids[2])
	expect_eq(s.find_group(ids[0]).items.size(), 1)
	BeDialogLogic.trash_group(s, ids[0])
	expect(s.find_group(ids[0]).is_empty())
	expect_eq(s.groups.size(), 1)
	s.free()


func test_sorting_groups_and_items() -> void:
	var s := _store()
	var ids := _seed(s)
	BeDialogLogic.sort_items(s, ids[0])
	expect_eq(s.find_group(ids[0]).items.map(func(i): return i.name), ["Alpha", "Zed"])
	BeDialogLogic.sort_groups(s)
	expect_eq(s.groups.map(func(g): return g.name), ["Play", "Work"])
	BeDialogLogic.sort_items(s, "missing")
	s.free()


func test_new_program_rules() -> void:
	var s := _store()
	var ids := _seed(s)
	expect_eq(BeDialogLogic.new_program(s, ids[0], "x", "  "), "")
	expect_eq(BeDialogLogic.new_program(s, "missing", "x", "calc"), "")
	var id := BeDialogLogic.new_program(s, ids[0], "", "C:\\Tools\\calc.exe", " C:\\Tools ")
	var it: Dictionary = s.find_item(ids[0], id)
	expect_eq(it.name, "calc.exe", "name defaults to the file name")
	expect_eq(it.icon, "default")
	expect_eq(it.workingDir, "C:\\Tools")
	var url_id := BeDialogLogic.new_program(s, ids[0], "Site", "https://example.com/x")
	expect_eq(s.find_item(ids[0], url_id).icon, "url")
	s.free()


func test_apply_item_info_saves_every_field_and_moves() -> void:
	var s := _store()
	var ids := _seed(s)
	var res := BeDialogLogic.apply_item_info(s, ids[0], ids[2], {
		"name": " New ", "path": " C:\\n.exe ", "workingDir": "C:\\", "arguments": "-x", "environment": "A=1",
		"runMode": "maximized", "launchGroup": 5, "shortcutKey": "Ctrl+Alt+N", "icon": "terminal", "groupId": ids[1]})
	expect(res.ok)
	expect_eq(res.groupId, ids[1])
	var it: Dictionary = s.find_item(ids[1], ids[2])
	expect_eq([it.name, it.path, it.workingDir, it.arguments, it.environment, it.runMode, it.launchGroup, it.shortcutKey, it.icon],
		["New", "C:\\n.exe", "C:\\", "-x", "A=1", "maximized", 5, "Ctrl+Alt+N", "terminal"])
	expect(s.find_item(ids[0], ids[2]).is_empty(), "moved out of the old group")
	expect(Validators.is_valid_item(it), "result stays a valid stored item")
	s.free()


func test_apply_item_info_validation() -> void:
	var s := _store()
	var ids := _seed(s)
	var none := BeDialogLogic.apply_item_info(s, ids[0], ids[2], {"name": " ", "path": ""})
	expect(not none.ok)
	expect_eq(s.find_item(ids[0], ids[2]).name, "Zed", "nothing changed")
	var fb := BeDialogLogic.apply_item_info(s, ids[0], ids[2], {"name": "", "path": "/usr/bin/tool", "runMode": "bogus", "launchGroup": 99, "icon": "default"})
	expect(fb.ok)
	var it: Dictionary = s.find_item(ids[0], ids[2])
	expect_eq(it.name, "tool", "name falls back to the target's file name")
	expect_eq(it.runMode, "normal")
	expect_eq(it.launchGroup, 8)
	var web := BeDialogLogic.apply_item_info(s, ids[0], ids[2], {"name": "W", "path": "https://x.org", "icon": "default"})
	expect(web.ok)
	expect_eq(s.find_item(ids[0], ids[2]).icon, "url")
	s.free()


func test_info_fields_round_trip() -> void:
	var f := BeDialogLogic.info_fields({"name": "N", "path": "p", "icon": "dos", "runMinimized": true, "launchGroup": 3}, "g")
	expect_eq(f.runMode, "minimized", "legacy runMinimized maps to a run mode")
	expect_eq(f.launchGroup, 3)
	expect_eq(f.groupId, "g")
	expect_eq(f.arguments, "")


func test_kind_batch_and_labels() -> void:
	expect_eq(BeDialogLogic.kind_of({"path": "https://a.b"}), "Internet shortcut")
	expect_eq(BeDialogLogic.kind_of({"path": "C:\\a.exe"}), "Shortcut to program")
	expect_eq(BeDialogLogic.batch_text(0), "None")
	expect_eq(BeDialogLogic.batch_text(3), "Group 3")
	expect_eq(BeDialogLogic.status_count(1), "1 item")
	expect_eq(BeDialogLogic.status_count(8), "8 items")
	expect_eq(BeDialogLogic.basename_of("C:\\a\\b\\c.exe"), "c.exe")
	expect_eq(BeDialogLogic.basename_of("/usr/bin/"), "bin")


func test_find_filters() -> void:
	var s := _store()
	var ids := _seed(s)
	var groups: Array = s.groups
	expect_eq(BeDialogLogic.find(groups, "", "all", "all", "").size(), 2)
	expect_eq(BeDialogLogic.find(groups, "ZE", "all", "all", "").size(), 1, "case-insensitive name contains")
	expect_eq(BeDialogLogic.find(groups, "", "all", "url", "")[0].item.name, "Alpha")
	expect_eq(BeDialogLogic.find(groups, "", "all", "app", "")[0].item.name, "Zed")
	expect_eq(BeDialogLogic.find(groups, "", "all", "batch", "").size(), 1)
	expect_eq(BeDialogLogic.find(groups, "", ids[1], "all", "").size(), 0, "group filter")
	expect_eq(BeDialogLogic.find(groups, "", "all", "all", "example").size(), 1, "text in path")
	expect_eq(BeDialogLogic.find_title(" "), "Find: All Programs")
	expect_eq(BeDialogLogic.find_title(" ab "), "Find: “ab” in names and notes")
	s.free()


func test_entries_and_titles() -> void:
	var s := _store()
	var ids := _seed(s)
	var comp := BeDialogLogic.entries_for("computer", s.groups)
	expect_eq(comp.size(), 2)
	expect_eq(comp[0].c2, "2 items")
	expect_eq(comp[0].c3, "Program group")
	expect(comp[0].is_group)
	var items := BeDialogLogic.entries_for("g:" + ids[0], s.groups)
	expect_eq(items.map(func(e): return e.name), ["Zed", "Alpha"])
	expect_eq(items[0].c3, "Group 2")
	expect_eq(items[1].c3, "—")
	expect_eq(BeDialogLogic.entries_for("g:missing", s.groups), [])
	expect_eq(BeDialogLogic.window_title("computer", s.groups), "Program Manager")
	expect_eq(BeDialogLogic.window_title("g:" + ids[0], s.groups), "Work")
	expect_eq(BeDialogLogic.window_title("find", s.groups, "q"), "Find: “q” in names and notes")
	s.free()


func test_clock_run_target_and_feedback_text() -> void:
	expect_eq(BeDialogLogic.format_clock({"hour": 0, "minute": 5}), "12:05 AM")
	expect_eq(BeDialogLogic.format_clock({"hour": 12, "minute": 0}), "12:00 PM")
	expect_eq(BeDialogLogic.format_clock({"hour": 15, "minute": 9}), "3:09 PM")
	var groups := [{"id": "g", "name": "G", "items": [{"id": "i", "name": "Notes", "path": "n.exe", "icon": "x", "workingDir": ""}]}]
	expect_eq(BeDialogLogic.run_target(groups, " notes ").id, "i", "matches a stored program by name")
	expect_eq(BeDialogLogic.run_target(groups, "calc").path, "calc")
	expect_eq(BeDialogLogic.run_target(groups, " "), {})
	expect_eq(BeDialogLogic.feedback_text({"visible": false}), "")
	expect_eq(BeDialogLogic.feedback_text({"visible": true, "status": "launching", "currentGroup": 5, "completedGroups": 1, "totalGroups": 3}),
		"Launching Group 5 (2 of 3)…", "the group number, then its place in the run")
	expect_eq(BeDialogLogic.feedback_text({"visible": true, "status": "launching", "currentGroup": 5, "completedGroups": 0, "totalGroups": 1},
		{"5": "Evening"}), "Launching Group 5: Evening…")
	expect_eq(BeDialogLogic.feedback_text({"visible": true, "status": "complete", "totalItems": 1}), "Launched 1 program.")
	expect_eq(BeDialogLogic.feedback_text({"visible": true, "status": "error", "failures": 2}), "2 programs could not be started.")
	expect_eq(BeDialogLogic.launch_error({"error": "bad"}, {"path": "p"}), "bad")
	expect_eq(BeDialogLogic.launch_error({}, {"path": "p"}), "Cannot find 'p'.")


func test_theme_tables_and_dark_flag() -> void:
	BeTheme.dark = false
	expect_eq(BeTheme.b("e8e8e8"), Color("#e8e8e8"))
	expect_eq(BeTheme.desktop(""), Color("#336698"))
	expect_eq(BeTheme.desktop("#5a5a6a"), Color("#5a5a6a"))
	BeTheme.dark = true
	expect_eq(BeTheme.b("e8e8e8"), Color("#36373b"))
	expect_eq(BeTheme.t("000000"), Color("#e3e4e6"))
	expect_eq(BeTheme.s("ffffff"), Color("#58595f"))
	expect_eq(BeTheme.desktop(""), Color("#1b2a3b"), "the default desktop darkens")
	expect_eq(BeTheme.desktop("#5a5a6a"), Color("#5a5a6a"), "a chosen colour is verbatim")
	expect_eq(BeTheme.b("123456"), Color("#123456"), "unmapped colours pass through")
	BeTheme.dark = false
	expect(BeTheme.is_dark({"theme": "dark"}) and not BeTheme.is_dark({"theme": "light"}) and not BeTheme.is_dark({}))


func test_find_status_counts_items() -> void:
	expect_eq(BeDialogLogic.found_text(1), "1 item found")
	expect_eq(BeDialogLogic.found_text(0), "0 items found")
	expect_eq(BeDialogLogic.found_text(3), "3 items found")
