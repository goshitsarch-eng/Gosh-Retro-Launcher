extends TestCase
## Web sites in the WfW shell: File > New... offers Program Group, Program Item, Web Site and Sticky
## Note; Web Site opens New Web Site, which adds a URL item with the web icon; a web site item's
## Properties show the URL instead of the program fields.

const SHELL_SCRIPT := preload("res://src/shells/win31/win31_shell.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w31-web-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _use_scratch_store() -> Dictionary:
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"profiles": ProgramStore.workspace_profiles.duplicate(true), "persistence": ProgramStore.persistence}
	ProgramStore.init_store(_tmp())
	return saved


func _restore_store(saved: Dictionary) -> void:
	UIState.close_dialog()
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	ProgramStore.workspace_profiles = saved.profiles


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Types into a field the way a user does (the field reports the change).
func _type(tf: W31TextField, t: String) -> void:
	tf.text = t
	tf.edit.text_changed.emit(t)


func _radios(dlg: W31Dialog) -> Array:
	var out := []
	for w in dlg._all_widgets(dlg):
		if w is W31Radio:
			out.append(w)
	return out


# ------------------------------------------------------------- New Program Object

func test_new_object_kinds_in_order() -> void:
	var kinds: Array = W31DialogLogic.NEW_OBJECT_KINDS.map(func(k): return k[0])
	expect_eq(kinds, ["group", "item", "url", "note"])
	var labels: Array = W31DialogLogic.NEW_OBJECT_KINDS.map(func(k): return RetroFont.parse_access(k[1]).text)
	expect_eq(labels, ["Program Group", "Program Item", "Web Site", "Sticky Note"])
	var keys: Array = W31DialogLogic.NEW_OBJECT_KINDS.map(func(k): return RetroFont.parse_access(k[1]).accessKey)
	expect_eq(keys, ["g", "i", "w", "n"], "one access key each, none shared with the buttons")
	var groups := [{"id": "g1", "name": "Main", "items": []}]
	expect_eq(W31DialogLogic.new_object_next("url", "", groups), {"type": "newUrl", "data": {"groupId": "g1"}})
	expect_eq(W31DialogLogic.new_object_next("url", "g7", groups).data.groupId, "g7")
	expect(W31DialogLogic.new_object_kind_enabled("group", []))
	expect(not W31DialogLogic.new_object_kind_enabled("url", []), "a web site needs a group")
	expect(W31DialogLogic.new_object_kind_enabled("url", groups))


func test_new_object_dialog_has_four_choices() -> void:
	var groups := [{"id": "g1", "name": "Main", "items": []}]
	var dlg := W31FormDialogs.NewObject.new({"groupId": "g1"}, groups)
	_tree().root.add_child(dlg)
	dlg.build(480)
	var radios := _radios(dlg)
	expect_eq(radios.map(func(r): return RetroFont.parse_access(r.text).text), ["Program Group", "Program Item", "Web Site", "Sticky Note"])
	expect_eq(radios.map(func(r): return int(r.position.y)), [35, 55, 75, 95], "20 px apart")
	expect_eq(dlg.initial_focus, radios[1], "the chosen kind (Program Item) has the focus")
	for b in dlg._all_widgets(dlg):
		if b is W31Button:
			expect(b.position.y > radios[3].position.y + radios[3].size.y + 10, "the buttons sit under the box")
	radios[2].activate_access_key()
	expect_eq(dlg.kind, "url")
	dlg.free()
	var empty := W31FormDialogs.NewObject.new({}, [])
	_tree().root.add_child(empty)
	empty.build(480)
	var r2 := _radios(empty)
	expect_eq(r2.map(func(r): return r.disabled), [false, true, true, true], "without groups only Program Group")
	expect(r2[0].checked)
	empty.free()


func test_ok_on_web_site_opens_new_web_site() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var layer := Win31DialogLayer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layer.size = Vector2(640, 480)
	_tree().root.add_child(layer)
	UIState.open_dialog("newObject", {"groupId": g})
	await _tree().process_frame
	var dlg: W31FormDialogs.NewObject = layer.current_dialog()
	_radios(dlg)[2].select()
	dlg._submit()
	await _tree().process_frame
	expect_eq(UIState.active_dialog, "newUrl")
	expect(layer.current_dialog() is W31FormDialogs.NewUrl)
	expect_eq(layer.current_dialog().title, "New Web Site")
	layer.free()
	_restore_store(saved)


# ---------------------------------------------------------------- New Web Site

func test_new_web_site_end_to_end() -> void:
	var saved := _use_scratch_store()
	var g1: String = ProgramStore.add_group("Main")
	var g2: String = ProgramStore.add_group("Web & Mail")
	ProgramStore.set_launch_group_name(2, "Morning & News")
	var dlg := W31FormDialogs.NewUrl.new({"groupId": g2}, ProgramStore.groups)
	_tree().root.add_child(dlg)
	dlg.build(480)
	expect_eq(dlg.group_combo.value(), g2, "the active group is chosen")
	expect_eq(RetroFont.parse_access(W31Combo.fit_label(String(dlg.group_combo.items[dlg.group_combo.selected]), 300)).text, "Web & Mail")
	var lg_labels: Array = dlg.launch_combo.items
	expect(lg_labels.has("Group 2: Morning & News"), str(lg_labels))
	expect_eq(RetroFont.parse_access(W31Combo.fit_label("Group 2: Morning & News", 300)).text, "Group 2: Morning & News", "& shown")
	expect_eq(dlg.initial_focus, dlg.url_field)
	expect(dlg.ok.disabled, "OK waits for a URL")
	var texts := []
	for t in dlg.body.texts:
		texts.append(String(t.text))
	for want in ["Program Group:", "URL:", "Description:", "Launch Group:"]:
		expect(texts.has(want), want)
	dlg.url_field.text = "example.com/news"
	dlg._sync()
	expect(not dlg.ok.disabled)
	dlg.launch_combo.select_value(2)
	dlg._submit()
	var items: Array = ProgramStore.find_group(g2).items
	expect_eq(items.size(), 1)
	expect_eq([items[0].name, items[0].path, items[0].icon, int(items[0].launchGroup)],
		["example.com", "https://example.com/news", "web", 2])
	expect(W31DialogLogic.is_web_item(items[0]))
	expect_eq(WfwIcons.icon_id(WfwIcons.item_icon_string(items[0])), "web", "drawn with the WfW web icon")
	expect_eq(ProgramStore.find_group(g1).items.size(), 0)
	dlg.free()
	_restore_store(saved)


func test_apply_new_url_rules() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	expect_eq(W31DialogLogic.apply_new_url(ProgramStore, g, "", "x", 0), "", "needs a URL")
	expect_eq(W31DialogLogic.apply_new_url(ProgramStore, g, "not a url", "x", 0), "")
	expect_eq(W31DialogLogic.apply_new_url(ProgramStore, "nope", "example.com", "x", 0), "", "needs a real group")
	var id := W31DialogLogic.apply_new_url(ProgramStore, g, " https://a.org ", " A & B ", 0)
	expect_eq(ProgramStore.find_item(g, id).name, "A & B")
	expect_eq(ProgramStore.find_item(g, id).path, "https://a.org")
	_restore_store(saved)


# ------------------------------------------------------------- Properties

func test_is_web_item() -> void:
	expect(W31DialogLogic.is_web_item({"path": "https://example.com"}))
	expect(W31DialogLogic.is_web_item({"path": "mailto:bob@example.com"}))
	expect(not W31DialogLogic.is_web_item({"path": "C:\\WINDOWS\\NOTEPAD.EXE"}), "a drive letter is not a scheme")
	expect(not W31DialogLogic.is_web_item({"path": "/usr/bin/xterm"}))
	expect(not W31DialogLogic.is_web_item({"path": "file:///tmp/a.txt"}), "a file URL is a document")
	expect(not W31DialogLogic.is_web_item(Notes.make_note("x", "", "yellow")))
	expect(not W31DialogLogic.is_web_item({}))


func test_web_form_and_values() -> void:
	var f := W31DialogLogic.web_form({"name": "News", "path": "https://n.example", "icon": "web", "launchGroup": 3, "shortcutKey": "Ctrl+Alt+N"})
	expect_eq(f, {"name": "News", "url": "https://n.example", "launchGroup": 3, "shortcutKey": "Ctrl+Alt+N", "win31Icon": "web"})
	expect_eq(W31DialogLogic.web_form({"path": "https://x.org", "icon": "web", "win31Icon": "network"}).win31Icon, "network")
	var v := W31DialogLogic.web_values({"name": "  ", "url": "example.org", "launchGroup": -1, "shortcutKey": " ", "win31Icon": ""})
	expect_eq(v, {"name": "example.org", "path": "https://example.org", "launchGroup": 0, "shortcutKey": "", "win31Icon": "web"})
	expect_eq(W31DialogLogic.web_values({"url": "bad url"}), {})
	expect(not v.has("workingDir") and not v.has("arguments") and not v.has("runMode"), "no program fields")


func test_properties_route_and_save() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id := W31DialogLogic.apply_new_url(ProgramStore, g, "https://news.example", "News", 1)
	var prog: String = ProgramStore.add_item(g, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""})
	var d := Win31DialogLayer.create_dialog("itemProperties", {"groupId": g, "item": ProgramStore.find_item(g, id)})
	expect(d is W31PropertiesDialogs.WebSiteProperties, "a web site gets Web Site Properties")
	var d2 := Win31DialogLayer.create_dialog("itemProperties", {"groupId": g, "item": ProgramStore.find_item(g, prog)})
	expect(d2 is W31PropertiesDialogs.ItemProperties and not (d2 is W31PropertiesDialogs.WebSiteProperties))
	d2.free()
	_tree().root.add_child(d)
	d.build(480)
	expect_eq(d.title, "Web Site Properties")
	var texts := []
	for t in d.body.texts:
		texts.append(String(t.text))
	for want in ["Description:", "URL:", "Shortcut Key:", "Launch Group:", "Icon:"]:
		expect(texts.has(want), want)
	for unwanted in ["Command Line:", "Working Directory:", "Arguments:", "Environment:", "Run:"]:
		expect(not texts.has(unwanted), unwanted)
	var buttons := []
	for w in d._all_widgets(d):
		if w is W31Button:
			buttons.append(RetroFont.parse_access(w.text).text)
	expect_eq(buttons, ["OK", "Cancel", "Change Icon...", "Help"])
	_type(d._fields["url"], "  ")
	expect(d.ok.disabled, "OK needs a URL")
	_type(d._fields["url"], "news.example/today")
	_type(d._fields["name"], "Today")
	expect(not d.ok.disabled)
	d._submit()
	var it: Dictionary = ProgramStore.find_item(g, id)
	expect_eq([it.name, it.path, int(it.launchGroup)], ["Today", "https://news.example/today", 1])
	expect_eq(UIState.active_dialog, "")
	d.free()
	_restore_store(saved)


func test_change_icon_comes_back_to_web_site_properties() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id := W31DialogLogic.apply_new_url(ProgramStore, g, "https://news.example", "News", 0)
	var layer := Win31DialogLayer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	layer.size = Vector2(640, 480)
	_tree().root.add_child(layer)
	UIState.open_dialog("itemProperties", {"groupId": g, "item": ProgramStore.find_item(g, id)})
	await _tree().process_frame
	var d: W31PropertiesDialogs.WebSiteProperties = layer.current_dialog()
	_type(d._fields["name"], "Typed")
	d._change_icon()
	await _tree().process_frame
	var ci: W31FormDialogs.ChangeIcon = layer.current_dialog()
	expect(ci is W31FormDialogs.ChangeIcon)
	expect_eq(ci.grid.size.y, ci.grid.content_height(), "the whole catalog shows without a scroll bar")
	ci.icon = "network"
	ci._submit()
	await _tree().process_frame
	var back := layer.current_dialog()
	expect(back is W31PropertiesDialogs.WebSiteProperties, "back to Web Site Properties")
	expect_eq(back.form.name, "Typed", "what was typed is kept")
	expect_eq(back.form.win31Icon, "network")
	layer.free()
	_restore_store(saved)


func test_wfw_web_icon() -> void:
	expect(W31Icons.IDS.has("web") and WfwIcons.IDS.has("web"))
	expect_eq(WfwIcons.icon_id("url"), "web", "Windows 95 URL items show the web icon")
	expect_eq(W31Icons.icon_id("url"), "web")
	var tex := W31Icons.texture("web")
	expect(tex != null and tex.get_size() == Vector2(32, 32))
	expect(WfwIcons.catalog_path("web").ends_with("web-32.png"))
	for s in [64, 96, 128]:
		expect(ResourceLoader.exists("res://assets/wfw/web-%d.png" % s), str(s))
