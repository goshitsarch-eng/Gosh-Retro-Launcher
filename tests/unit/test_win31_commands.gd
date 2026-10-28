extends TestCase

static func _ws(minimized: bool) -> Dictionary:
	return {"x": 0, "y": 0, "width": 300, "height": 200, "minimized": minimized, "maximized": false}


static func _group(id: String, name: String, minimized: bool, items: Array = []) -> Dictionary:
	var ws := _ws(minimized)
	return {"id": id, "name": name, "icon": "group", "windowState": ws,
		"shellWindowState": {"win31": ws.duplicate(), "win95": ws.duplicate()}, "items": items}


static func _item(id: String, launch_group: int = 0, shortcut: String = "") -> Dictionary:
	var it := {"id": id, "name": id, "path": "", "icon": "default", "workingDir": "", "launchGroup": launch_group}
	if shortcut != "":
		it["shortcutKey"] = shortcut
	return it


func _groups() -> Array:
	return [_group("a", "Main", false, [_item("i1", 1), _item("i2", 2), _item("i3", 1)]),
		_group("b", "Games", true, [_item("i4", 0, "Ctrl+Alt+G")])]


func test_selected_objects() -> void:
	var g := _groups()
	var s := Win31Commands.selected_objects(g, {"kind": "item", "groupId": "a", "itemId": "i2"}, "b")
	expect_eq(s.group.id, "a")
	expect_eq(s.item.id, "i2")
	s = Win31Commands.selected_objects(g, {"kind": "groupIcon", "groupId": "b"}, "a")
	expect_eq(s.group.id, "b")
	expect(s.item.is_empty())
	s = Win31Commands.selected_objects(g, {}, "a")
	expect_eq(s.group.id, "a", "falls back to the active window")
	s = Win31Commands.selected_objects(g, {"kind": "item", "groupId": "zzz", "itemId": "i2"}, "a")
	expect(s.group.is_empty() and s.item.is_empty())


func test_command_state() -> void:
	var g := _groups()
	var settings := {"autoArrange": true, "minimizeOnUse": false, "saveSettingsOnExit": true}
	var none := {}
	expect_eq(Win31Commands.command_state("open", g, none, "a", settings).disabled, true, "no item, no icon")
	expect_eq(Win31Commands.command_state("open", g, {"kind": "groupIcon", "groupId": "b"}, "a", settings).disabled, false)
	var item_sel := {"kind": "item", "groupId": "a", "itemId": "i1"}
	expect_eq(Win31Commands.command_state("open", g, item_sel, "a", settings).disabled, false)
	expect_eq(Win31Commands.command_state("move", g, item_sel, "a", settings).disabled, false)
	expect_eq(Win31Commands.command_state("move", g, none, "a", settings).disabled, true)
	expect_eq(Win31Commands.command_state("copy", [], item_sel, "a", settings).disabled, true)
	expect_eq(Win31Commands.command_state("delete", g, none, "a", settings).disabled, false, "active group counts")
	expect_eq(Win31Commands.command_state("properties", g, none, "", settings).disabled, true)
	expect_eq(Win31Commands.command_state("cascade", g, none, "a", settings).disabled, false)
	expect_eq(Win31Commands.command_state("tile", [_group("x", "X", true)], none, "", settings).disabled, true)
	expect_eq(Win31Commands.command_state("arrange-icons", g, none, "a", settings).disabled, false)
	expect_eq(Win31Commands.command_state("arrange-icons", [_group("x", "X", false)], none, "", settings).disabled, true)
	expect_eq(Win31Commands.command_state("auto-arrange", g, none, "a", settings).checked, true)
	expect_eq(Win31Commands.command_state("minimize-on-use", g, none, "a", settings).checked, false)
	expect_eq(Win31Commands.command_state("save-settings", g, none, "a", settings).checked, true)
	expect_eq(Win31Commands.command_state("new", g, none, "a", settings), {})


func test_menu_tree() -> void:
	var menus := Win31Commands.build_menus(_groups(), "a", {}, {"autoArrange": true})
	var ids := []
	for m in menus:
		ids.append(m.id)
	expect_eq(ids, ["file", "options", "window", "launcher", "help"])
	var file_labels := []
	for it in menus[0].items:
		file_labels.append("-" if it.get("separator", false) else it.label)
	expect_eq(file_labels, ["&New...", "&Open", "-", "&Move...", "&Copy...", "&Delete", "&Properties...", "-", "&Run...", "-", "E&xit Windows..."])
	var win: Array = menus[2].items
	expect_eq(win[3].get("separator", false), true)
	expect_eq(win[4].label, "&1 Main")
	expect_eq(win[4].checked, true)
	expect_eq(win[5].label, "&2 Games")
	expect_eq(win[5].checked, false)
	expect_eq(win[4].command, "group:a")
	var launcher: Array = menus[3].items
	expect_eq(launcher[0].command, "launch-all")
	expect_eq(launcher[0].disabled, false)
	expect_eq(launcher[2].label, "Launch Group &1 (2 items)")
	expect_eq(launcher[3].label, "Launch Group &2 (1 item)")
	expect_eq(launcher[3].command, "launch-group:2")
	expect_eq(launcher[launcher.size() - 1].label, "Launcher &Tools...")


func test_launcher_menu_without_groups() -> void:
	var menus := Win31Commands.build_menus([_group("a", "Main", false)], "a", {}, {})
	var launcher: Array = menus[3].items
	expect_eq(launcher[0].disabled, true)
	expect_eq(launcher.size(), 3, "Launch All, separator, Launcher Tools")


func test_window_menu_numbers_only_first_nine() -> void:
	var gs := []
	for i in 11:
		gs.append(_group("g%d" % i, "G%d" % i, false))
	var items: Array = Win31Commands.build_menus(gs, "g0", {}, {})[2].items
	expect_eq(items[4 + 8].label, "&9 G8")
	expect_eq(items[4 + 9].label, "G9", "no number after nine")


func test_system_items() -> void:
	var normal := Win31Commands.system_items("outer-", false)
	expect_eq(normal[0].disabled, true, "Restore disabled when not maximized")
	expect_eq(normal[1].disabled, false)
	expect_eq(normal[4].disabled, false)
	var maxed := Win31Commands.system_items("child-", true)
	expect_eq(maxed[0].disabled, false)
	expect_eq(maxed[1].disabled, true)
	expect_eq(maxed[2].disabled, true)
	expect_eq(maxed[4].disabled, true)
	expect_eq(maxed[6].command, "child-close")


func test_popup_navigation() -> void:
	var items := [{"command": "a", "label": "&Alpha"}, {"separator": true}, {"command": "b", "label": "&Beta", "disabled": true},
		{"command": "c", "label": "Mi&nimize"}]
	var en := Win31Commands.enabled_indexes(items)
	expect_eq(en, [0, 3])
	expect_eq(Win31Commands.step_highlight(en, 0, 1), 3)
	expect_eq(Win31Commands.step_highlight(en, 3, 1), 0, "wraps")
	expect_eq(Win31Commands.step_highlight(en, 0, -1), 3)
	expect_eq(Win31Commands.step_highlight([], 0, 1), -1)
	expect_eq(Win31Commands.mnemonic_match(items, "a"), 0)
	expect_eq(Win31Commands.mnemonic_match(items, "b"), -1, "disabled item has no mnemonic")
	expect_eq(Win31Commands.mnemonic_match(items, "n"), 3)
	expect_eq(Win31Commands.mnemonic_of("E&xit"), "x")
	expect_eq(Win31Commands.mnemonic_of("Plain"), "")


func test_accelerators() -> void:
	var menus := Win31Commands.build_menus([], "", {}, {})
	expect_eq(Win31Commands.menu_for_accelerator(menus, "f"), "file")
	expect_eq(Win31Commands.menu_for_accelerator(menus, "o"), "options")
	expect_eq(Win31Commands.menu_for_accelerator(menus, "w"), "window")
	expect_eq(Win31Commands.menu_for_accelerator(menus, "l"), "launcher")
	expect_eq(Win31Commands.menu_for_accelerator(menus, "h"), "help")
	expect_eq(Win31Commands.menu_for_accelerator(menus, "x"), "")


func test_shortcut_matching() -> void:
	expect(Win31Commands.shortcut_matches("Ctrl+Alt+G", "g", true, true, false, false))
	expect(not Win31Commands.shortcut_matches("Ctrl+Alt+G", "g", true, false, false, false), "missing modifier")
	expect(not Win31Commands.shortcut_matches("Ctrl+G", "g", true, true, false, false), "extra modifier")
	expect(Win31Commands.shortcut_matches("F5", "f5", false, false, false, false))
	expect(Win31Commands.shortcut_matches("Win+E", "e", false, false, false, true))
	expect(not Win31Commands.shortcut_matches("   ", "e", false, false, false, false))
	expect(not Win31Commands.shortcut_matches("", "e", false, false, false, false))


func test_key_names() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F4
	expect_eq(Win31Commands.key_name(ev), "f4")
	ev.keycode = KEY_ENTER
	expect_eq(Win31Commands.key_name(ev), "enter")
	ev.keycode = KEY_SPACE
	expect_eq(Win31Commands.key_name(ev), " ")
	ev.keycode = KEY_ESCAPE
	expect_eq(Win31Commands.key_name(ev), "escape")
	ev.keycode = KEY_G
	expect_eq(Win31Commands.key_name(ev), "g")
	ev.keycode = KEY_DOWN
	expect_eq(Win31Commands.key_name(ev), "down")
	expect(Win31Commands.is_reserved_alt_key("f", false, false, false, true))
	expect(not Win31Commands.is_reserved_alt_key("f", true, false, false, true))
	expect(not Win31Commands.is_reserved_alt_key("g", false, false, false, true))


func test_launch_group_counts() -> void:
	expect_eq(Win31Commands.launch_group_counts(_groups()), [[1, 2], [2, 1]])


func test_keyboard_steps() -> void:
	var b := {"x": 10, "y": 10, "width": 400, "height": 300}
	expect_eq(Win31Commands.desktop_key_step("move", b, "left", false).x, 9)
	expect_eq(Win31Commands.desktop_key_step("move", b, "left", true).x, 2)
	expect_eq(Win31Commands.desktop_key_step("move", {"x": 3, "y": 0, "width": 400, "height": 300}, "left", true).x, 0, "clamped at 0")
	expect_eq(Win31Commands.desktop_key_step("size", {"x": 0, "y": 0, "width": 322, "height": 242}, "left", true).width, 320)
	expect_eq(Win31Commands.desktop_key_step("size", {"x": 0, "y": 0, "width": 322, "height": 242}, "up", true).height, 240)
	expect_eq(Win31Commands.desktop_key_step("move", b, "tab", false), {})
	expect_eq(Win31Commands.host_key_step("move", b, "right", true).x, 20)
	expect_eq(Win31Commands.host_key_step("size", {"x": 0, "y": 0, "width": 405, "height": 305}, "left", true).width, 400)
	expect_eq(Win31Commands.host_key_step("size", {"x": 0, "y": 0, "width": 405, "height": 305}, "up", true).height, 300)
	var st := {"x": 10, "y": 20, "width": 200, "height": 100}
	expect_eq(Win31Commands.child_key_step("move", st, "right", false, 300, 400), {"x": 11, "y": 20})
	expect_eq(Win31Commands.child_key_step("move", st, "right", true, 205, 400).x, 5, "keeps the window inside the client")
	expect_eq(Win31Commands.child_key_step("size", st, "left", true, 634, 430), {"width": 192, "height": 100})
	expect_eq(Win31Commands.child_key_step("size", {"x": 0, "y": 0, "width": 152, "height": 94}, "left", true, 634, 430).width, 150)
	expect_eq(Win31Commands.child_key_step("move", st, "home", false, 300, 400), {})


func test_desktop_drag_and_resize() -> void:
	var start := {"x": 68, "y": 49, "width": 511, "height": 335}
	var b := Win31Commands.desktop_drag_bounds(start, 10, -100, 640, 480)
	expect_eq(b.x, 78)
	expect_eq(b.y, 0, "clamped to the top")
	b = Win31Commands.desktop_drag_bounds(start, 1000, 1000, 640, 480)
	expect_eq(b.x, 560, "at least 80px stay on screen")
	expect_eq(b.y, 456)
	expect_eq(b.width, 511)
	var r := Win31Commands.desktop_resize_bounds(start, "se", Vector2(20, 10))
	expect_eq([r.width, r.height], [531, 345])
	r = Win31Commands.desktop_resize_bounds(start, "nw", Vector2(-10, -5))
	expect_eq([r.x, r.y, r.width, r.height], [58, 44, 521, 340])
	r = Win31Commands.desktop_resize_bounds(start, "e", Vector2(-1000, 0))
	expect_eq(r.width, 320, "minimum width")
