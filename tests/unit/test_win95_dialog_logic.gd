extends TestCase
## Validation and apply rules of the Win95 dialogs, wizard, property sheets and Find (pure logic).

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "win95"
	s.settings["saveSettingsOnExit"] = false
	return s


func test_find_filters_and_result_ids() -> void:
	expect_eq(Win95DialogLogic.find_filters("*", "", true, "all", "", ""),
		{"named": "*", "includeSubgroups": true, "type": "all", "containing": "", "path": ""})
	expect_eq(Win95DialogLogic.find_filters("P*", "g", false, "internet", "x", "y").groupId, "g")
	expect_eq(Win95DialogLogic.find_result_ids([{"group": {"id": "g"}, "item": {"id": "i"}}]), ["g:i"])


func test_find_keyboard_navigation_and_reveal() -> void:
	expect_eq(Win95DialogLogic.find_next_index(0, "ArrowUp", 8), 0)
	expect_eq(Win95DialogLogic.find_next_index(6, "ArrowDown", 8), 7)
	expect_eq(Win95DialogLogic.find_next_index(7, "ArrowDown", 8), 7)
	expect_eq(Win95DialogLogic.find_next_index(1, "PageDown", 8), 4)
	expect_eq(Win95DialogLogic.find_next_index(6, "PageDown", 8), 7)
	expect_eq(Win95DialogLogic.find_next_index(5, "PageUp", 8), 2)
	expect_eq(Win95DialogLogic.find_next_index(3, "Home", 8), 0)
	expect_eq(Win95DialogLogic.find_next_index(3, "End", 8), 7)
	expect_eq(Win95DialogLogic.find_next_index(3, "x", 8), -1)
	expect_eq(Win95DialogLogic.find_next_index(0, "End", 0), -1)
	expect_eq(Win95DialogLogic.find_reveal(0, 5, 19, 53), 95 + 19 - 53)
	expect_eq(Win95DialogLogic.find_reveal(100, 2, 19, 53), 38)
	expect_eq(Win95DialogLogic.find_reveal(10, 1, 19, 53), 10)


func test_run_command_rules() -> void:
	expect_eq(Win95DialogLogic.run_item("   "), {})
	expect_eq(Win95DialogLogic.run_item(" calc "), {"id": "win95-run", "name": "calc", "path": "calc", "icon": "run", "workingDir": ""})
	Win95DialogLogic.run_history.clear()
	Win95DialogLogic.remember_run("a")
	Win95DialogLogic.remember_run("b")
	Win95DialogLogic.remember_run("a")
	Win95DialogLogic.remember_run("")
	expect_eq(Win95DialogLogic.run_history, ["b", "a"])
	expect_eq(Win95DialogLogic.run_error({}, " x "), "Cannot find 'x'.")
	expect_eq(Win95DialogLogic.run_error({"error": "nope"}, "x"), "nope")
	Win95DialogLogic.run_history.clear()


func test_shutdown_settings_only_change_for_the_win31_choice() -> void:
	var settings := Types.default_settings()
	settings["shell"] = "win95"
	expect_eq(Win95DialogLogic.shutdown_next_settings(settings, "quit"), {})
	expect_eq(Win95DialogLogic.shutdown_next_settings(settings, "restart"), {})
	var next := Win95DialogLogic.shutdown_next_settings(settings, "win31")
	expect_eq(next.shell, "win31")
	expect_eq(settings.shell, "win95", "input untouched")
	expect_eq(next.win95Scale, settings.win95Scale)


func test_wizard_validation_and_creation() -> void:
	var s := _store()
	var gid: String = s.add_group("Tools")
	expect(not Win95DialogLogic.wizard_can_next("  "))
	expect(Win95DialogLogic.wizard_can_next("calc.exe"))
	expect(not Win95DialogLogic.wizard_can_finish("", gid, "x"))
	expect(not Win95DialogLogic.wizard_can_finish("n", "", "x"))
	expect(not Win95DialogLogic.wizard_can_finish("n", gid, " "))
	expect_eq(Win95DialogLogic.wizard_finish(s, gid, "n", "", "new-shortcut", ""), "")
	var id := Win95DialogLogic.wizard_finish(s, gid, " Calc ", " calc.exe ", "new-shortcut", " /tmp ")
	expect(id != "")
	var item: Dictionary = s.find_item(gid, id)
	expect_eq(item.name, "Calc")
	expect_eq(item.path, "calc.exe")
	expect_eq(item.workingDir, "/tmp")
	var applied := Win95DialogLogic.wizard_apply_app_info({"name": "", "workingDir": "/w"}, "new-shortcut")
	expect_eq(applied, {"name": "New Shortcut", "workingDir": "/w", "icon": "new-shortcut"})
	expect_eq(Win95DialogLogic.wizard_apply_app_info({"name": "App", "icon": "data:x"}, "new-shortcut").icon, "data:x")
	s.free()


func test_folder_and_url_creation_rules() -> void:
	var s := _store()
	expect_eq(Win95DialogLogic.create_folder(s, "   "), "")
	var gid := Win95DialogLogic.create_folder(s, " Games ")
	expect_eq(s.find_group(gid).name, "Games")
	expect(Win95DialogLogic.is_internet_url("HTTPS://a.b"))
	expect(not Win95DialogLogic.is_internet_url("ftp://a.b"))
	expect_eq(Win95DialogLogic.create_url_item(s, gid, "Site", "ftp://x"), "")
	expect_eq(Win95DialogLogic.create_url_item(s, "", "Site", "http://x"), "")
	expect_eq(Win95DialogLogic.create_url_item(s, gid, " ", "http://x"), "")
	var id := Win95DialogLogic.create_url_item(s, gid, "Site", "https://x.y ")
	expect_eq(s.find_item(gid, id).path, "https://x.y")
	expect_eq(s.find_item(gid, id).icon, "url")
	s.free()


func test_item_property_apply_rules() -> void:
	var s := _store()
	var a: String = s.add_group("A")
	var b: String = s.add_group("B")
	var id: String = s.add_item(a, {"name": "Old", "path": "old", "icon": "application", "workingDir": ""})
	var bad := Win95DialogLogic.apply_item_properties(s, a, id, {"name": " ", "command": "c", "workingDir": "", "arguments": "", "runMode": "normal", "groupId": a})
	expect_eq(bad.ok, false)
	expect_eq(s.find_item(a, id).name, "Old")
	var ok := Win95DialogLogic.apply_item_properties(s, a, id, {"name": " New ", "command": " cmd ", "workingDir": " /x ", "arguments": " -v ", "runMode": "minimized", "groupId": b})
	expect_eq(ok, {"ok": true, "groupId": b})
	expect_eq(s.find_item(a, id), {})
	var moved: Dictionary = s.find_item(b, id)
	expect_eq(moved.name, "New")
	expect_eq(moved.path, "cmd")
	expect_eq(moved.arguments, "-v")
	expect_eq(moved.runMode, "minimized")
	expect_eq(Win95DialogLogic.group_of_item(s, id), b)
	s.free()


func test_group_property_apply_rules() -> void:
	var s := _store()
	var g: String = s.add_group("A")
	expect(not Win95DialogLogic.apply_group_properties(s, g, "  "))
	expect_eq(s.find_group(g).name, "A")
	expect(Win95DialogLogic.apply_group_properties(s, g, " Renamed "))
	expect_eq(s.find_group(g).name, "Renamed")
	expect_eq(Win95DialogLogic.plural_objects(1), "1 object")
	expect_eq(Win95DialogLogic.plural_objects(8), "8 objects")
	s.free()


func test_every_ascii_glyph_missing_from_the_win95_fonts_has_a_synthetic_shape() -> void:
	var f := RetroFont.instance(RetroFont.WIN95)
	for c in range(33, 127):
		var ch := String.chr(c)
		if not f.font.has_char(c):
			expect(RetroFont._SYNTH_NORMAL.has(ch) or ch == "`", "normal font lacks '%s' without a fallback" % ch)
		if not f.bold_font.has_char(c):
			expect(RetroFont._SYNTH_BOLD.has(ch), "bold font lacks '%s' without a fallback" % ch)
