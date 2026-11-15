extends TestCase
## Mac dialog rules against a real ProgramStore instance (not persisted): folder/item creation, rename,
## Get Info apply, duplicate/alias, trash, clean-up, Find and Run.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "mac"
	s.settings["saveSettingsOnExit"] = false
	return s


func _seed(s: Node) -> Dictionary:
	var g1: String = s.add_group("Main")
	var g2: String = s.add_group("Games")
	var a: String = s.add_item(g1, {"name": "Zed", "path": "/bin/zed", "icon": "default", "workingDir": ""})
	var b: String = s.add_item(g1, {"name": "Alpha", "path": "https://example.com", "icon": "network", "workingDir": "", "launchGroup": 2})
	return {"g1": g1, "g2": g2, "a": a, "b": b}


func test_create_folder_and_rename() -> void:
	var s := _store()
	expect_eq(MacDialogLogic.create_folder(s, "   "), "")
	var id := MacDialogLogic.create_folder(s, "  Tools ")
	expect_eq(s.find_group(id).name, "Tools")
	expect(MacDialogLogic.rename(s, id, "", " Utilities "))
	expect_eq(s.find_group(id).name, "Utilities")
	expect(not MacDialogLogic.rename(s, id, "", "  "))
	s.free()


func test_rename_item() -> void:
	var s := _store()
	var ids := _seed(s)
	expect(MacDialogLogic.rename(s, ids.g1, ids.a, "Zebra"))
	expect_eq(s.find_item(ids.g1, ids.a).name, "Zebra")
	s.free()


func test_apply_item_info_updates_every_field() -> void:
	var s := _store()
	var ids := _seed(s)
	var r := MacDialogLogic.apply_item_info(s, ids.g1, ids.a, {
		"name": " Editor ", "path": " /usr/bin/ed ", "workingDir": "/tmp", "arguments": "-x", "environment": "A=1",
		"runMode": "maximized", "launchGroup": "3", "shortcutKey": "Ctrl+E", "icon": "terminal", "groupId": ids.g1})
	expect(r.ok)
	var it: Dictionary = s.find_item(ids.g1, ids.a)
	expect_eq(it.name, "Editor")
	expect_eq(it.path, "/usr/bin/ed")
	expect_eq(it.workingDir, "/tmp")
	expect_eq(it.arguments, "-x")
	expect_eq(it.environment, "A=1")
	expect_eq(it.runMode, "maximized")
	expect_eq(it.launchGroup, 3)
	expect_eq(it.shortcutKey, "Ctrl+E")
	expect_eq(it.icon, "terminal")
	expect(Validators.is_valid_item(it), "result still validates")
	s.free()


func test_apply_item_info_validates_and_can_move() -> void:
	var s := _store()
	var ids := _seed(s)
	expect(not MacDialogLogic.apply_item_info(s, ids.g1, ids.a, {"name": "", "path": "x", "groupId": ids.g1}).ok)
	expect(not MacDialogLogic.apply_item_info(s, ids.g1, ids.a, {"name": "n", "path": " ", "groupId": ids.g1}).ok)
	var bad := MacDialogLogic.apply_item_info(s, ids.g1, ids.a, {"name": "n", "path": "p", "launchGroup": "99", "groupId": ids.g1})
	expect(not bad.ok and String(bad.error).contains("Launch group"))
	var moved := MacDialogLogic.apply_item_info(s, ids.g1, ids.a, {"name": "n", "path": "p", "launchGroup": "None", "runMode": "bogus", "groupId": ids.g2})
	expect(moved.ok)
	expect_eq(moved.groupId, ids.g2)
	expect_eq(s.find_item(ids.g1, ids.a), {})
	expect_eq(s.find_item(ids.g2, ids.a).runMode, "normal", "invalid run mode falls back")
	s.free()


func test_launch_group_parser() -> void:
	expect_eq(MacDialogLogic.parse_launch_group(""), 0)
	expect_eq(MacDialogLogic.parse_launch_group("None"), 0)
	expect_eq(MacDialogLogic.parse_launch_group("5"), 5)
	expect_eq(MacDialogLogic.parse_launch_group("9"), -1)
	expect_eq(MacDialogLogic.parse_launch_group("x"), -1)
	expect_eq(MacDialogLogic.parse_launch_group("-1"), -1)


func test_duplicate_and_alias() -> void:
	var s := _store()
	var ids := _seed(s)
	var copy := MacDialogLogic.duplicate_item(s, ids.g1, ids.a, "copy")
	var alias := MacDialogLogic.duplicate_item(s, ids.g1, ids.a, "alias")
	expect(copy != "" and alias != "" and copy != alias)
	expect_eq(s.find_item(ids.g1, copy).name, "Zed copy")
	expect_eq(s.find_item(ids.g1, alias).name, "Zed alias")
	expect_eq(s.find_item(ids.g1, copy).path, "/bin/zed")
	expect_eq(MacDialogLogic.duplicate_item(s, ids.g1, "missing", "copy"), "")
	s.free()


func test_trash_removes_through_the_store() -> void:
	var s := _store()
	var ids := _seed(s)
	MacDialogLogic.trash_item(s, ids.g1, ids.a)
	expect_eq(s.find_group(ids.g1).items.size(), 1)
	MacDialogLogic.trash_folder(s, ids.g1)
	expect_eq(s.find_group(ids.g1), {})
	expect_eq(s.groups.size(), 1)
	s.free()


func test_add_program() -> void:
	var s := _store()
	var ids := _seed(s)
	expect_eq(MacDialogLogic.add_program(s, ids.g2, "x", "  "), "")
	var id := MacDialogLogic.add_program(s, ids.g2, "", "C:\\Tools\\app.exe")
	expect_eq(s.find_item(ids.g2, id).name, "app.exe")
	var url := MacDialogLogic.add_program(s, ids.g2, "Site", "https://example.com")
	expect_eq(s.find_item(ids.g2, url).icon, "network")
	s.free()


func test_clean_up_sorts_items_and_folders() -> void:
	var s := _store()
	var ids := _seed(s)
	MacDialogLogic.clean_up(s, ids.g1)
	expect_eq(s.find_group(ids.g1).items.map(func(i): return i.name), ["Alpha", "Zed"])
	MacDialogLogic.clean_up(s, "")
	expect_eq(s.groups.map(func(g): return g.name), ["Games", "Main"])
	s.free()


func test_find_items_filters() -> void:
	var s := _store()
	var ids := _seed(s)
	expect_eq(MacDialogLogic.find_items(s.groups, "", "all", "all").size(), 2)
	expect_eq(MacDialogLogic.find_items(s.groups, "alp", "all", "all").size(), 1)
	expect_eq(MacDialogLogic.find_items(s.groups, "", "all", "url").size(), 1)
	expect_eq(MacDialogLogic.find_items(s.groups, "", "all", "app").size(), 1)
	expect_eq(MacDialogLogic.find_items(s.groups, "", "all", "batch").size(), 1)
	expect_eq(MacDialogLogic.find_items(s.groups, "", ids.g2, "all").size(), 0)
	s.free()


func test_run_item_resolution() -> void:
	var s := _store()
	_seed(s)
	expect_eq(MacDialogLogic.run_item(s.groups, "   "), {})
	expect_eq(MacDialogLogic.run_item(s.groups, " zed ").path, "/bin/zed")
	var adhoc := MacDialogLogic.run_item(s.groups, "calc")
	expect_eq(adhoc, {"id": "mac-run", "name": "calc", "path": "calc", "icon": "terminal", "workingDir": ""})
	expect(Validators.is_launch_item(adhoc))
	expect(Validators.is_launch_item(MacDialogLogic.launch_payload({"id": "x", "name": "n", "path": "p", "icon": "i"})), "workingDir added")
	s.free()


func test_labels_and_titles() -> void:
	expect_eq(MacDialogLogic.plural(1, "item"), "1 item")
	expect_eq(MacDialogLogic.plural(2, "item"), "2 items")
	expect_eq(MacDialogLogic.info_line(1, 8, false), "1 item")
	expect_eq(MacDialogLogic.info_line(5, 8, true), "5 items, 8 programs")
	var groups := [{"id": "g", "name": "Main"}]
	expect_eq(MacDialogLogic.window_title("computer", groups), "Launcher HD")
	expect_eq(MacDialogLogic.window_title("g:g", groups), "Main")
	expect_eq(MacDialogLogic.window_title("find", groups), "Find")
	expect_eq(MacDialogLogic.kind_of({"path": "http://x"}), "Internet shortcut")
	expect_eq(MacDialogLogic.kind_of({"path": "/bin/x"}), "Application program")
