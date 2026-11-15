extends TestCase
## Mac menu bar / context menu definitions and accelerators.


func _ctx(over: Dictionary = {}) -> Dictionary:
	var c := {"groups": [{"id": "a", "name": "Main"}, {"id": "b", "name": "Games"}], "active_key": "", "view": "",
		"selected": {"kind": ""}, "buckets": []}
	for k in over:
		c[k] = over[k]
	return c


func _find_menu(menus: Array, id: String) -> Dictionary:
	for m in menus:
		if m.id == id:
			return m
	return {}


func _find_item(menu: Dictionary, id: String) -> Dictionary:
	for i in menu.items:
		if not MacMenuModel.is_sep(i) and i.id == id:
			return i
	return {}


func test_menu_bar_titles_match_the_design() -> void:
	var menus := MacMenuModel.menu_bar(_ctx())
	var labels := menus.map(func(m): return m.label)
	expect_eq(labels, ["", "File", "Edit", "View", "Special", "Help"])


func test_logo_menu_lists_every_group() -> void:
	var logo := _find_menu(MacMenuModel.menu_bar(_ctx()), "logo")
	expect_eq(_find_item(logo, "about").label, "About Program Manager…")
	expect(not _find_item(logo, "tools").is_empty() and not _find_item(logo, "desktop-pictures").is_empty() and not _find_item(logo, "find").is_empty())
	expect_eq(_find_item(logo, "open-group:a").label, "Main")
	expect_eq(_find_item(logo, "open-group:b").label, "Games")


func test_file_menu_enables_by_selection() -> void:
	var none := _find_menu(MacMenuModel.menu_bar(_ctx()), "file")
	for id in ["open", "get-info", "duplicate", "trash", "close-window"]:
		expect(_find_item(none, id).get("disabled", false), id + " disabled with nothing selected")
	expect(not _find_item(none, "new-folder").get("disabled", false))
	var item := _find_menu(MacMenuModel.menu_bar(_ctx({"selected": {"kind": "item"}, "active_key": "g:a"})), "file")
	for id in ["open", "get-info", "duplicate", "trash", "close-window"]:
		expect(not _find_item(item, id).get("disabled", false), id + " enabled for an item")
	var group := _find_menu(MacMenuModel.menu_bar(_ctx({"selected": {"kind": "group"}, "active_key": "computer"})), "file")
	expect(_find_item(group, "duplicate").get("disabled", false), "only items duplicate")


func test_view_menu_checks_current_view() -> void:
	var v := _find_menu(MacMenuModel.menu_bar(_ctx({"active_key": "g:a", "view": "details"})), "view")
	expect(_find_item(v, "view:details").check)
	expect(not _find_item(v, "view:large").check)
	var off := _find_menu(MacMenuModel.menu_bar(_ctx({"active_key": "find"})), "view")
	expect(_find_item(off, "view:large").disabled, "no icon views for the Find window")


func test_special_menu_lists_launch_groups() -> void:
	var buckets := [{"groupNumber": 1, "items": [{}, {}]}, {"groupNumber": 3, "items": [{}]}]
	var s := _find_menu(MacMenuModel.menu_bar(_ctx({"buckets": buckets})), "special")
	expect(not _find_item(s, "launch-all").get("disabled", false))
	expect_eq(_find_item(s, "launch-group:1").label, "Launch Group 1 (2 items)")
	expect_eq(_find_item(s, "launch-group:3").label, "Launch Group 3 (1 item)")
	var empty := _find_menu(MacMenuModel.menu_bar(_ctx()), "special")
	expect(_find_item(empty, "launch-all").disabled)
	expect(not _find_item(empty, "restart").is_empty() and not _find_item(empty, "shutdown").is_empty() and not _find_item(empty, "run").is_empty())


func test_context_menus_follow_the_design() -> void:
	var labels := func(items: Array) -> Array:
		return items.map(func(i): return "-" if MacMenuModel.is_sep(i) else i.label)
	expect_eq(labels.call(MacMenuModel.item_menu()), ["Help", "-", "Open", "Get Info", "Move To Trash", "-", "Duplicate", "Make Alias", "Rename"])
	expect_eq(labels.call(MacMenuModel.group_menu()), ["Help", "-", "Open", "Get Info", "Move To Trash", "-", "Rename"])
	expect_eq(labels.call(MacMenuModel.desktop_menu()), ["Help", "-", "New Folder", "Clean Up", "-", "Change Desktop Background…"])
	expect_eq(labels.call(MacMenuModel.desk_icon_menu("trash")), ["Open", "Empty Trash…"])
	expect(MacMenuModel.desk_icon_menu("trash")[1].disabled)
	var bg := MacMenuModel.folder_background_menu(false, "large")
	expect_eq(bg[2].label, "New Program…")
	expect(bg[5].check and not bg[6].check)
	expect_eq(MacMenuModel.folder_background_menu(true, "large")[2].label, "New Folder")


func test_app_menu_marks_active_window() -> void:
	var items := MacMenuModel.app_menu([{"key": "g:a"}, {"key": "computer"}], "computer", {"g:a": "Main", "computer": "Launcher HD"})
	expect_eq(items[0].id, "tools")
	expect(MacMenuModel.is_sep(items[1]))
	expect_eq(items[2].label, "Main")
	expect(not items[2].check and items[3].check)


func test_accelerators() -> void:
	expect_eq(MacMenuModel.accelerator(KEY_N), "new-folder")
	expect_eq(MacMenuModel.accelerator(KEY_F), "find")
	expect_eq(MacMenuModel.accelerator(KEY_W), "close-window")
	expect_eq(MacMenuModel.accelerator(KEY_Z), "")
	expect_eq(MacMenuModel.accelerator_text("N", true), "Cmd+N")
	expect_eq(MacMenuModel.accelerator_text("N", false), "Ctrl+N")
