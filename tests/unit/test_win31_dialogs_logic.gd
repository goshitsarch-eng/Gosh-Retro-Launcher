extends TestCase
## Pure logic of the Win31 dialogs: icon picker filter, validation, apply semantics, settings
## mapping, quick-search ranking/navigation and launch-feedback text.

func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-test-dlg-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


# ------------------------------------------------------------------ icon picker

func test_icon_catalog_and_aliases() -> void:
	expect_eq(W31Icons.IDS.size(), 23)
	expect_eq(W31Icons.icon_id("folder"), "group")
	expect_eq(W31Icons.icon_id("trash"), "default")
	expect_eq(W31Icons.icon_id("nonsense"), "default")
	expect_eq(W31Icons.icon_id("clock"), "clock")
	expect(W31Icons.is_external("data:image/png;base64,AA"))
	expect(W31Icons.is_external("https://x/y.png"))
	expect(not W31Icons.is_external("clock"))


func test_icon_picker_filter() -> void:
	expect_eq(W31Icons.filter_ids("").size(), 23)
	expect_eq(W31Icons.filter_ids("MAN"), ["file-manager", "print-manager", "program-manager"])
	expect_eq(W31Icons.filter_ids("zzz"), [])
	expect_eq(W31Icons.filter_ids("clo"), ["clock"])
	var named := W31Icons.filter_named([{"id": "a", "name": "Web Browser"}, {"id": "b", "name": "Games"}], "web")
	expect_eq(named.size(), 1)
	expect_eq(named[0].id, "a")


# ------------------------------------------------------------------ URL dialog

func test_url_normalization_and_validity() -> void:
	expect_eq(W31DialogLogic.normalize_url("  example.com "), "https://example.com")
	expect_eq(W31DialogLogic.normalize_url("http://a.b"), "http://a.b")
	expect_eq(W31DialogLogic.normalize_url("mailto:me@x.org"), "mailto:me@x.org")
	expect_eq(W31DialogLogic.normalize_url("   "), "")
	expect(W31DialogLogic.is_valid_url("example.com"))
	expect(W31DialogLogic.is_valid_url("https://example.com/path?q=1"))
	expect(W31DialogLogic.is_valid_url("mailto:me@x.org"))
	expect(not W31DialogLogic.is_valid_url("https://"))
	expect(not W31DialogLogic.is_valid_url(""))
	expect(not W31DialogLogic.is_valid_url("exa mple.com"))


func test_url_name_derivation() -> void:
	expect_eq(W31DialogLogic.derive_name("https://www.Example.com/a/b"), "www.example.com")
	expect_eq(W31DialogLogic.derive_name("mailto:me@x.org"), "me@x.org")
	expect_eq(W31DialogLogic.derive_name("http://localhost:3000/x"), "localhost")


func test_url_item_payload_and_validation() -> void:
	expect_eq(W31DialogLogic.url_item("", "n", 0, "g"), {})
	expect_eq(W31DialogLogic.url_item("example.com", "", 0, ""), {}, "group required")
	var item := W31DialogLogic.url_item("example.com", "  ", 3, "g")
	expect_eq(item.name, "example.com")
	expect_eq(item.path, "https://example.com")
	expect_eq(item.icon, "web")
	expect_eq(item.launchGroup, 3)
	expect_eq(item.workingDir, "")
	expect_eq(W31DialogLogic.url_item("example.com", "  My Site ", 0, "g").name, "My Site")
	expect(W31DialogLogic.url_form_valid("example.com", "g"))
	expect(not W31DialogLogic.url_form_valid("https://", "g"))


# ------------------------------------------------------------------ names / groups

func test_group_file_name() -> void:
	expect_eq(W31DialogLogic.group_file_name("Accessories"), "ACCESSOR.GRP")
	expect_eq(W31DialogLogic.group_file_name("my games!"), "MYGAMES.GRP")
	expect_eq(W31DialogLogic.group_file_name("***"), "GROUP.GRP")
	expect_eq(W31DialogLogic.group_file_name(""), "GROUP.GRP")


func test_group_name_validation_and_apply() -> void:
	var dir := _tmp()
	var s := _store(dir)
	expect(not W31DialogLogic.group_name_valid("   "))
	expect_eq(W31DialogLogic.apply_new_group(s, "  "), "")
	expect_eq(s.groups.size(), 0)
	var gid: String = W31DialogLogic.apply_new_group(s, "  Games  ")
	expect_eq(s.find_group(gid).name, "Games")
	expect(not W31DialogLogic.apply_group_properties(s, gid, "  ", "clock"))
	expect_eq(s.find_group(gid).name, "Games")
	expect(W31DialogLogic.apply_group_properties(s, gid, " Fun ", "clock"))
	expect_eq(s.find_group(gid).name, "Fun")
	expect_eq(s.find_group(gid).icon, "clock")
	expect(not W31DialogLogic.apply_rename_group(s, gid, ""))
	expect(W31DialogLogic.apply_rename_group(s, gid, "Renamed "))
	expect_eq(s.find_group(gid).name, "Renamed")
	s.free()
	_rm(dir)


func test_new_group_followup_and_new_object() -> void:
	expect_eq(W31DialogLogic.new_group_followup({}), "")
	expect_eq(W31DialogLogic.new_group_followup({"openItemAfterCreate": true}), "newItem")
	expect_eq(W31DialogLogic.new_group_followup({"openUrlAfterCreate": true}), "newUrl")
	expect_eq(W31DialogLogic.new_object_default_kind([]), "group")
	expect_eq(W31DialogLogic.new_object_default_kind([{"id": "a"}]), "item")
	var groups := [{"id": "g1"}, {"id": "g2"}]
	expect_eq(W31DialogLogic.new_object_next("group", "", groups), {"type": "newGroup", "data": {}})
	expect_eq(W31DialogLogic.new_object_next("item", "g2", groups), {"type": "newItem", "data": {"groupId": "g2"}})
	expect_eq(W31DialogLogic.new_object_next("item", "", groups).data.groupId, "g1")


# ------------------------------------------------------------------ item properties

func test_item_form_defaults() -> void:
	var f := W31DialogLogic.item_form({})
	expect_eq(f.icon, "default")
	expect_eq(f.win31Icon, "default")
	expect_eq(f.runMode, "normal")
	expect_eq(f.launchGroup, 0)
	var g := W31DialogLogic.item_form({"name": "x", "path": "p", "icon": "dos", "runMinimized": true, "launchGroup": 4})
	expect_eq(g.runMode, "minimized", "legacy runMinimized")
	expect_eq(g.win31Icon, "dos", "win31Icon falls back to icon")
	expect_eq(g.launchGroup, 4)
	expect_eq(W31DialogLogic.item_form({"runMode": "maximized", "runMinimized": true}).runMode, "maximized")


func test_item_validation_rules() -> void:
	var f := W31DialogLogic.item_form({"name": " ", "path": "p"})
	expect(not W31DialogLogic.item_form_valid(f, "g"), "blank name")
	f.name = "N"
	f.path = "  "
	expect(not W31DialogLogic.item_form_valid(f, "g"), "blank path")
	f.path = "p"
	expect(not W31DialogLogic.item_form_valid(f, ""), "group required")
	expect(W31DialogLogic.item_form_valid(f, "g"))


func test_item_values_semantics() -> void:
	var v := W31DialogLogic.item_values({"name": " A ", "path": " /bin/a ", "workingDir": " /tmp ", "arguments": " -x ",
		"environment": " K=V ", "runMode": "minimized", "icon": "dos", "win31Icon": "dos", "launchGroup": 12, "shortcutKey": " Ctrl+A "})
	expect_eq(v.name, "A")
	expect_eq(v.path, "/bin/a")
	expect_eq(v.workingDir, "/tmp")
	expect_eq(v.arguments, "-x")
	expect_eq(v.environment, "K=V")
	expect_eq(v.shortcutKey, "Ctrl+A")
	expect_eq(v.launchGroup, 8, "launchGroup clamps to 0-8")
	expect_eq(v.runMinimized, true)
	expect_eq(W31DialogLogic.item_values({"launchGroup": -3, "runMode": "maximized"}).launchGroup, 0)
	expect_eq(W31DialogLogic.item_values({"runMode": "maximized"}).runMinimized, false)
	expect_eq(W31DialogLogic.item_values({"runMode": "bogus"}).runMode, "normal")


func test_item_apply_add_edit_and_move() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var a: String = s.add_group("A")
	var b: String = s.add_group("B")
	var form := W31DialogLogic.item_form({})
	form.name = "Tool"
	form.path = "/bin/tool"
	form.launchGroup = 2
	form.runMode = "minimized"
	var id := W31DialogLogic.apply_item_properties(s, form, {}, a, a)
	expect(id != "")
	var item: Dictionary = s.find_item(a, id)
	expect_eq(item.launchGroup, 2)
	expect_eq(item.runMode, "minimized")
	expect_eq(item.runMinimized, true)
	expect(Validators.is_valid_item(item), "stored item stays valid")
	# edit
	var edit := W31DialogLogic.item_form(item)
	edit.arguments = " --fast "
	edit.workingDir = "/tmp"
	edit.launchGroup = 0
	W31DialogLogic.apply_item_properties(s, edit, item, a, a)
	var after: Dictionary = s.find_item(a, id)
	expect_eq(after.arguments, "--fast")
	expect_eq(after.workingDir, "/tmp")
	expect_eq(after.launchGroup, 0)
	# blank form is a no-op
	var bad := edit.duplicate()
	bad.name = ""
	expect_eq(W31DialogLogic.apply_item_properties(s, bad, item, a, a), "")
	# selecting another group moves the item
	W31DialogLogic.apply_item_properties(s, edit, after, a, b)
	expect_eq(s.find_group(a).items.size(), 0)
	expect_eq(s.find_group(b).items.size(), 1)
	s.free()
	_rm(dir)


func test_resolve_item_group() -> void:
	var groups := [{"id": "g1", "items": [{"id": "i1"}]}, {"id": "g2", "items": [{"id": "i2"}]}]
	expect_eq(W31DialogLogic.resolve_item_group(groups, {"groupId": "g2"}), "g2")
	expect_eq(W31DialogLogic.resolve_item_group(groups, {"item": {"id": "i2"}}), "g2")
	expect_eq(W31DialogLogic.resolve_item_group(groups, {}), "g1")
	expect_eq(W31DialogLogic.resolve_item_group([], {}), "")


func test_browse_result_fills_only_blank_fields() -> void:
	var form := W31DialogLogic.item_form({})
	var info := {"name": "Notepad", "icon": "data:icon", "win31Icon": "data:w31", "workingDir": "/w", "arguments": "-a"}
	var r := W31DialogLogic.apply_browse_result(form, "/bin/np.exe", info)
	expect_eq(r.path, "/bin/np.exe")
	expect_eq(r.name, "Notepad")
	expect_eq(r.icon, "data:icon")
	expect_eq(r.win31Icon, "data:w31")
	expect_eq(r.workingDir, "/w")
	expect_eq(r.arguments, "-a")
	var keep := form.duplicate()
	keep.name = "Mine"
	keep.icon = "dos"
	keep.workingDir = "/mine"
	var r2 := W31DialogLogic.apply_browse_result(keep, "/bin/np.exe", info)
	expect_eq(r2.name, "Mine")
	expect_eq(r2.icon, "dos")
	expect_eq(r2.workingDir, "/mine")
	expect_eq(r2.win31Icon, "data:w31", "win31Icon still default -> replaced")
	var r3 := W31DialogLogic.apply_browse_result(form, "C:\\Apps\\paint.exe", {})
	expect_eq(r3.name, "paint", "no app info: file name without extension")


func test_change_icon_apply_and_browse_choice() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var g: String = s.add_group("G")
	var i: String = s.add_item(g, {"name": "n", "path": "p", "icon": "default", "workingDir": ""})
	W31DialogLogic.apply_change_icon(s, g, i, "clock")
	expect_eq(s.find_item(g, i).win31Icon, "clock")
	expect_eq(s.find_item(g, i).icon, "default", "only win31Icon changes")
	expect_eq(W31DialogLogic.browse_icon_choice({"win31Icon": "a", "icon": "b"}, "x"), "a")
	expect_eq(W31DialogLogic.browse_icon_choice({"icon": "b"}, "x"), "b")
	expect_eq(W31DialogLogic.browse_icon_choice({}, "x"), "x")
	s.free()
	_rm(dir)


func test_move_copy_destinations_and_apply() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var a: String = s.add_group("A")
	var b: String = s.add_group("B")
	var i: String = s.add_item(a, {"name": "n", "path": "p", "icon": "default", "workingDir": ""})
	expect_eq(W31DialogLogic.move_copy_groups(s.groups, false, a).size(), 1)
	expect_eq(W31DialogLogic.move_copy_groups(s.groups, true, a).size(), 2)
	expect(not W31DialogLogic.apply_move_copy(s, false, a, "", i))
	expect(W31DialogLogic.apply_move_copy(s, true, a, b, i))
	expect_eq(s.find_group(a).items.size(), 1)
	expect_eq(s.find_group(b).items.size(), 1)
	expect(W31DialogLogic.apply_move_copy(s, false, a, b, i))
	expect_eq(s.find_group(a).items.size(), 0)
	expect_eq(s.find_group(b).items.size(), 2)
	s.free()
	_rm(dir)


# ------------------------------------------------------------------ run / help

func test_run_item_parsing() -> void:
	expect_eq(W31DialogLogic.run_item("   "), {})
	var r := W31DialogLogic.run_item("C:\\Win\\notepad.exe readme.txt")
	expect_eq(r.id, "run-command")
	expect_eq(r.path, "C:\\Win\\notepad.exe")
	expect_eq(r.arguments, "readme.txt")
	expect_eq(r.name, "notepad.exe")
	expect_eq(r.workingDir, "")
	expect_eq(r.icon, "default")
	var q := W31DialogLogic.run_item("\"/opt/my app/run\" -x")
	expect_eq(q.path, "/opt/my app/run")
	expect_eq(q.arguments, "-x")
	expect(Validators.is_launch_item(q))
	expect_eq(W31DialogLogic.run_error_message({"error": "boom"}, "p"), "boom")
	expect_eq(W31DialogLogic.run_error_message({}, "p"), "Cannot run p.")


func test_help_topics_and_headings() -> void:
	expect_eq(W31DialogLogic.help_topics("").size(), 7)
	expect_eq(W31DialogLogic.help_topics("ICON"), ["Changing program icons"])
	expect_eq(W31DialogLogic.help_topics("zzz"), [])
	expect_eq(W31DialogLogic.help_heading("search"), "Search for Help On...")
	expect_eq(W31DialogLogic.help_heading("using"), "How to Use Help")
	expect_eq(W31DialogLogic.help_heading("whatever"), "Program Manager Help Contents")


# ------------------------------------------------------------------ settings

func test_settings_form_and_updates_mapping() -> void:
	var f := W31DialogLogic.settings_form(Types.default_settings())
	expect_eq(f.launchDelay, 500)
	expect_eq(f.autoArrange, true)
	expect_eq(f.theme, "light")
	expect_eq(f.labelDisplay, "wrap")
	expect_eq(f.shell, "win31")
	expect_eq(f.win31Scale, "auto")
	f.launchDelay = 1234
	expect_eq(W31DialogLogic.settings_updates(f).launchDelay, 1200, "snaps to 100ms steps")
	expect_eq(W31DialogLogic.clamp_launch_delay(5), 100)
	expect_eq(W31DialogLogic.clamp_launch_delay(99999), 5000)
	expect_eq(W31DialogLogic.scale_from_index(0), "auto")
	expect_eq(W31DialogLogic.scale_from_index(3), 3)
	expect_eq(W31DialogLogic.scale_to_index("auto"), 0)
	expect_eq(W31DialogLogic.scale_to_index(2), 2)
	expect_eq(W31DialogLogic.scale_label("auto"), "Auto")


func test_settings_apply_writes_store_and_validates() -> void:
	var dir := _tmp()
	var s := _store(dir)
	var f := W31DialogLogic.settings_form(s.settings)
	f.autoArrange = false
	f.minimizeOnUse = true
	f.theme = "dark"
	f.labelDisplay = "ellipsis"
	f.soundEnabled = false
	f.win31Scale = 3
	f.win95Scale = 2
	f.launchDelay = 900
	var r := W31DialogLogic.apply_settings(s, f)
	expect_eq(r.success, true)
	expect_eq(r.shellChanged, false)
	expect_eq(s.settings.autoArrange, false)
	expect_eq(s.settings.minimizeOnUse, true)
	expect_eq(s.settings.theme, "dark")
	expect_eq(s.settings.labelDisplay, "ellipsis")
	expect_eq(s.settings.soundEnabled, false)
	expect_eq(s.settings.win31Scale, 3)
	expect_eq(s.settings.win95Scale, 2)
	expect_eq(s.settings.launchDelay, 900)
	expect(Validators.is_valid_settings(s.settings))
	# a shell change goes through the persist-first transaction
	f.shell = "win95"
	var r2 := W31DialogLogic.apply_settings(s, f)
	expect_eq(r2.success, true)
	expect_eq(r2.shellChanged, true)
	expect_eq(s.settings.shell, "win95")
	var reread := Persistence.new(dir)
	reread.init_store()
	expect_eq(reread.get_settings().shell, "win95", "persisted before the shell is recreated")
	s.free()
	_rm(dir)


# ------------------------------------------------------------------ quick search

func _search_groups() -> Array:
	var items := []
	for n in ["Notepad", "Calculator", "Net Meeting", "Paint", "Terminal"]:
		items.append({"id": n, "name": n, "path": "/bin/%s" % n.to_lower(), "icon": "default", "workingDir": ""})
	return [{"id": "g", "name": "Tools", "items": items}]


func test_quick_search_ranking_and_cap() -> void:
	var groups := _search_groups()
	var v := W31DialogLogic.quick_search_view(groups, "n")
	expect_eq(v.displayed[0].item.name, "Net Meeting", "prefix matches first, alphabetical")
	expect_eq(v.displayed[1].item.name, "Notepad")
	expect_eq(v.displayed[0].score, 3)
	expect_eq(v.empty, false)
	expect_eq(W31DialogLogic.quick_search_view(groups, "")["displayed"].size(), 0)
	expect_eq(W31DialogLogic.quick_search_view(groups, "zzz").empty, true)
	expect_eq(W31DialogLogic.quick_search_view(groups, " ").empty, true, "whitespace query shows No results found")
	expect_eq(W31DialogLogic.quick_search_view(groups, "").empty, false)
	# path / group name fallback ranking (score 1)
	var by_path := W31DialogLogic.quick_search_view(groups, "/bin/paint")
	expect_eq(by_path.displayed.size(), 1)
	expect_eq(by_path.displayed[0].score, 1)
	# cap at 10 with "more" text
	var many := []
	for i in 13:
		many.append({"id": "i%d" % i, "name": "App %02d" % i, "path": "p", "icon": "default", "workingDir": ""})
	var big := W31DialogLogic.quick_search_view([{"id": "g", "name": "G", "items": many}], "app")
	expect_eq(big.displayed.size(), 10)
	expect_eq(big.total, 13)
	expect_eq(big.hasMore, true)
	expect_eq(big.moreText, "3 more results not shown")
	many.resize(11)
	expect_eq(W31DialogLogic.quick_search_view([{"id": "g", "name": "G", "items": many}], "app").moreText, "1 more result not shown")


func test_quick_search_navigation_clamps() -> void:
	expect_eq(W31DialogLogic.quick_search_move(0, -1, 5), 0)
	expect_eq(W31DialogLogic.quick_search_move(0, 1, 5), 1)
	expect_eq(W31DialogLogic.quick_search_move(4, 1, 5), 4, "no wrap")
	expect_eq(W31DialogLogic.quick_search_move(2, 1, 0), 0)


# ------------------------------------------------------------------ launch feedback

func test_launch_feedback_text_and_progress() -> void:
	var fb := {"visible": true, "totalGroups": 4, "totalItems": 9, "currentGroup": null, "completedGroups": 0, "failures": 0, "status": "launching"}
	expect_eq(W31DialogLogic.feedback_status_text(fb), "Preparing launch groups")
	expect_eq(W31DialogLogic.feedback_icon_text(fb), ">>")
	expect_eq(W31DialogLogic.feedback_progress(fb), 0)
	fb.currentGroup = 2
	fb.completedGroups = 1
	expect_eq(W31DialogLogic.feedback_status_text(fb), "Launching Group 2")
	expect_eq(W31DialogLogic.feedback_progress(fb), 25)
	expect_eq(W31DialogLogic.feedback_detail_text(fb), "1 of 4 groups")
	fb.status = "complete"
	fb.completedGroups = 4
	expect_eq(W31DialogLogic.feedback_status_text(fb), "Launched 9 items")
	expect_eq(W31DialogLogic.feedback_icon_text(fb), "OK")
	expect_eq(W31DialogLogic.feedback_progress(fb), 100)
	fb.totalItems = 1
	expect_eq(W31DialogLogic.feedback_status_text(fb), "Launched 1 item")
	fb.status = "error"
	fb.failures = 1
	expect_eq(W31DialogLogic.feedback_status_text(fb), "1 launch failed")
	fb.failures = 3
	expect_eq(W31DialogLogic.feedback_status_text(fb), "3 launches failed")
	expect_eq(W31DialogLogic.feedback_icon_text(fb), "!")
	expect_eq(W31DialogLogic.feedback_progress({"totalGroups": 0, "completedGroups": 0}), 0)
	expect_eq(W31DialogLogic.feedback_progress({"totalGroups": 2, "completedGroups": 5}), 100, "capped")
	expect_eq(W31DialogLogic.feedback_progress({"totalGroups": 3, "completedGroups": 1}), 33)


func test_platform_display_names() -> void:
	expect_eq(W31DialogLogic.platform_display_name("win32"), "Windows")
	expect_eq(W31DialogLogic.platform_display_name("darwin"), "macOS")
	expect_eq(W31DialogLogic.platform_display_name("freebsd"), "freebsd")
	expect_eq(W31DialogLogic.welcome_mod_key("darwin"), "Cmd")
	expect_eq(W31DialogLogic.welcome_mod_key("linux"), "Ctrl")


# ------------------------------------------------------------------ widgets (no tree needed)

func test_radio_group_exclusive_selection() -> void:
	var group := []
	var a := W31Radio.new("Program &Group")
	var b := W31Radio.new("Program &Item")
	a.group = group
	b.group = group
	group.append(a)
	group.append(b)
	expect_eq(a.access_key, "g")
	expect_eq(b.access_key, "i")
	a.select()
	expect(a.checked and not b.checked)
	b.select()
	expect(b.checked and not a.checked)
	a.free()
	b.free()


func test_combo_value_selection() -> void:
	var c := W31Combo.new()
	c.set_items(["None", "Group 1", "Group 2"], [0, 1, 2])
	expect_eq(c.value(), 0)
	c.select_value(2)
	expect_eq(c.selected, 2)
	expect_eq(c.value(), 2)
	c._commit(1)
	expect_eq(c.value(), 1)
	c._step(5)
	expect_eq(c.selected, 2, "clamped")
	c.free()


func test_slider_snaps_to_step_and_range() -> void:
	var sl := W31Slider.new(100, 5000, 100)
	sl.value = 1234
	expect_eq(sl.value, 1200.0)
	sl.value = 99999
	expect_eq(sl.value, 5000.0)
	sl.value = -5
	expect_eq(sl.value, 100.0)
	sl.free()


func test_scrollbar_clamps_value() -> void:
	var sb := W31ScrollBar.new()
	sb.total = 100
	sb.page = 40
	sb.value = 500
	expect_eq(sb.value, 60.0)
	sb.value = -4
	expect_eq(sb.value, 0.0)
	sb.page = 100
	expect_eq(sb.max_value(), 0.0)
	sb.free()


func test_button_fit_metrics() -> void:
	var b := W31Button.new("OK", true)
	expect_eq(b.fit(), Vector2(68, 22))
	var long := W31Button.new("A very long caption")
	expect(long.fit().x > 68)
	var wrap := W31Button.new("Change Icon...")
	wrap.wrap_text = true
	expect_eq(wrap.fit(78), Vector2(78, 32), "two-line button in the 78px column")
	expect_eq(W31Button.new("Help").auto_id, "wfw.dialog.button:Help")
	b.free()
	long.free()
	wrap.free()


func test_icon_grid_geometry() -> void:
	var g := W31IconGrid.new(8, 5)
	g.size = Vector2(338, 0)
	var entries := []
	for id in W31Icons.IDS:
		entries.append({"id": id})
	g.set_entries(entries)
	expect_eq(g.fit_height(), 124, "3 rows of 36px with 2px gaps + padding + frame")
	expect_eq(g.cell_rect(0).position, Vector2(6, 6))
	expect_eq(g.cell_rect(9).position, Vector2(6 + 38, 6 + 38))
	g.free()
