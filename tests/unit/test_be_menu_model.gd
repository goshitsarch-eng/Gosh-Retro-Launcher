extends TestCase
## BeMenuModel: the design's itemMenu / groupMenu / sysMenu / deskMenu / folderBgMenu / folder menu bar / Deskbar menu.


func _labels(rows: Array) -> Array:
	return rows.map(func(r): return "-" if r.get("sep", false) else r.label)


func test_item_menu() -> void:
	var m := BeMenuModel.item_menu("g", "i")
	expect_eq(_labels(m), ["Open", "Get Info", "Edit Name", "-", "Duplicate", "Move to Trash"])
	expect(m[0].bold)
	expect_eq(m[1].action, "item.info")
	expect_eq(m[5].args, {"gid": "g", "iid": "i"})


func test_group_and_window_menus() -> void:
	expect_eq(_labels(BeMenuModel.group_menu("g")), ["Open", "Get Info", "Edit Name", "-", "Move to Trash"])
	expect_eq(_labels(BeMenuModel.window_menu("g:x")), ["Show", "Hide", "Zoom", "-", "Close"])
	expect_eq(BeMenuModel.window_menu("g:x")[2].action, "window.zoom")


func test_desktop_menus() -> void:
	var d := BeMenuModel.desktop_menu()
	expect_eq(_labels(d), ["New Folder", "-", "Clean Up", "Select All", "-", "Find…", "Launcher Tools…", "Backgrounds…", "-", "Help"])
	expect(d[3].disabled)
	expect_eq(d[6].action, "tools.open")
	expect_eq(_labels(BeMenuModel.desktop_icon_menu("computer")), ["Open", "Get Info", "-", "Find…"])
	expect_eq(_labels(BeMenuModel.desktop_icon_menu("g:x")), _labels(BeMenuModel.group_menu("x")))
	expect_eq(BeMenuModel.desktop_icon_menu("g:x")[0].args.gid, "x")


func test_folder_background_menu_depends_on_window_kind_and_view() -> void:
	var c := BeMenuModel.folder_background_menu("computer", true, "large")
	expect_eq(_labels(c), ["New Folder", "-", "Icon View", "Mini Icon View", "List View", "-", "Clean Up", "Select All", "-", "Get Info", "Close"])
	expect(c[2].dot and not c[3].dot)
	expect_eq(c[9].action, "about.open")
	var g := BeMenuModel.folder_background_menu("g:x", false, "details")
	expect_eq(g[0].label, "Add Program…")
	expect_eq(g[1].label, "Add Website…")
	expect_eq(g[1].action, "website.new")
	expect(g[5].dot)
	expect_eq(g[10].action, "group.info")
	expect_eq(g[10].args.gid, "x")


func test_menu_bar_enables_selection_commands_only_with_a_selection() -> void:
	var bar := BeMenuModel.menu_bar("g:x", false, "large", "")
	expect_eq(bar.map(func(m): return m.label), ["File", "Edit", "View", "Help"])
	var file: Array = bar[0].items
	expect_eq(_labels(file), ["Open", "-", "Add Program…", "Add Website…", "-", "Move to Trash", "Edit Name", "Get Info", "-", "Close"])
	expect(file[0].disabled and file[5].disabled and file[6].disabled and file[7].disabled)
	expect(not file[2].get("disabled", false) and not file[9].get("disabled", false))
	var sel := BeMenuModel.menu_bar("g:x", false, "small", "i1")
	expect(not sel[0].items[0].get("disabled", false))
	expect_eq(sel[0].items[0].args, {"gid": "x", "iid": "i1"})
	expect(sel[2].items[1].dot, "Mini Icon View is the current view")
	var comp := BeMenuModel.menu_bar("computer", true, "large", "g1")
	expect_eq(comp[0].items[0].action, "group.open")
	expect_eq(comp[0].items[2].label, "New Folder")
	expect_eq(_labels(comp[2].items), ["Icon View", "Mini Icon View", "List View", "-", "Clean Up", "Refresh"])
	expect_eq(_labels(comp[3].items), ["Help Topics", "-", "About Program Manager"])
	expect_eq(_labels(comp[1].items), ["Undo", "-", "Cut", "Copy", "Paste", "-", "Select All", "Invert Selection"])


func test_deskbar_lists_launch_groups_like_the_mac_special_menu() -> void:
	var buckets := [{"groupNumber": 1, "items": [{}, {}]}, {"groupNumber": 3, "items": [{}]}]
	var d := BeMenuModel.deskbar_menu(buckets)
	var labels := _labels(d)
	expect(labels.has("Launch All") and labels.has("Launch Group 1 (2 items)") and labels.has("Launch Group 3 (1 item)"))
	expect_eq(d[labels.find("Launch Group 3 (1 item)")].args.n, 3)
	expect_eq(d[labels.find("Launch All")].action, "launch.all")
	var empty := BeMenuModel.deskbar_menu([])
	expect(empty[_labels(empty).find("Launch All")].disabled, "Launch All disabled with no launch groups")


func test_file_menu_offers_add_website_next_to_add_program() -> void:
	var file: Array = BeMenuModel.menu_bar("g:x", false, "large", "")[0]["items"]
	var labels := _labels(file)
	expect(labels.has("Add Program…") and labels.has("Add Website…"))
	expect_eq(file[labels.find("Add Website…")].action, "website.new")
	expect(not file[labels.find("Add Website…")].get("disabled", false))


func test_deskbar_menu_matches_the_design_items() -> void:
	var d := BeMenuModel.deskbar_menu()
	expect_eq(_labels(d), ["About Program Manager...", "-", "Find...", "Run...", "Launcher Tools...", "Backgrounds...", "Help", "-", "Restart", "Shut Down..."])
	expect_eq(d[0].icon, "logo")
	expect_eq(d[9].icon, "critical")
	expect_eq(d[4].action, "tools.open")
	expect_eq(_labels(BeMenuModel.deskbar_context_menu()), ["About Program Manager…", "Launcher Tools…"])
