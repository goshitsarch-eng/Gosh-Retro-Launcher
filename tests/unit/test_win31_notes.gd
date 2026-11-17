extends TestCase

const MAIN := preload("res://src/app/main.gd")
## Sticky notes in the WfW shell: New Sticky Note / note Properties rules and dialogs, Quick Search,
## launch group members, the note icon, the note layer (stacking, font, input), drop-downs showing
## "&" literally, the .GRP export status and the Launcher Tools width.

const SHELL_SCRIPT := preload("res://src/shells/win31/win31_shell.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w31-notes-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _mount_shell() -> Win31Shell:
	var shell: Win31Shell = SHELL_SCRIPT.new()
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.size = Vector2(640, 480)
	return shell


# ------------------------------------------------------------------ rules

func test_new_object_offers_sticky_note() -> void:
	var groups := [{"id": "g1", "name": "Main", "items": []}]
	expect_eq(W31DialogLogic.new_object_next("note", "", groups), {"type": "newNote", "data": {"groupId": "g1"}})
	expect_eq(W31DialogLogic.new_object_next("note", "g9", groups).data.groupId, "g9", "the active group wins")
	expect_eq(W31DialogLogic.new_object_next("item", "", groups).type, "newItem", "program items unchanged")
	var dlg := W31FormDialogs.NewObject.new({}, groups)
	_tree().root.add_child(dlg)
	dlg.build(480)
	var labels := []
	for w in dlg._all_widgets(dlg):
		if w is W31Radio:
			labels.append(RetroFont.parse_access(w.text).text if "text" in w else "")
	expect(labels.has("Sticky Note"), str(labels))
	dlg.free()


func test_note_form_and_values() -> void:
	var colors := W31DialogLogic.note_color_choices()
	expect_eq(colors.values, ["yellow", "pink", "blue", "green", "purple", "gray"])
	expect_eq(colors.labels[1], "Pink")
	var blank := W31DialogLogic.note_form()
	expect_eq(blank.noteColor, "yellow")
	expect_eq(blank.win31Icon, "note")
	var existing := Notes.make_note("Todo", "x", "blue")
	existing.merge({"launchGroup": 3, "win31Icon": "clock"}, true)
	var f := W31DialogLogic.note_form(existing)
	expect_eq([f.name, f.text, f.noteColor, f.launchGroup, f.win31Icon], ["Todo", "x", "blue", 3, "clock"])
	var v := W31DialogLogic.note_values({"name": "  ", "noteColor": "plaid", "launchGroup": -2, "win31Icon": ""})
	expect_eq(v, {"name": "Note", "noteColor": "yellow", "launchGroup": 0, "win31Icon": "note"})
	expect(not v.has("path") and not v.has("workingDir") and not v.has("shortcutKey"), "no program fields")


func test_apply_new_note_and_properties() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	expect_eq(W31DialogLogic.apply_new_note(ProgramStore, "", {"name": "x"}), "", "needs a group")
	var id := W31DialogLogic.apply_new_note(ProgramStore, g, {"name": "Call", "text": "Bob\r\n555", "noteColor": "green", "launchGroup": 2})
	var it: Dictionary = ProgramStore.find_item(g, id)
	expect(Notes.is_note(it))
	expect_eq([it.name, it.note, it.noteColor, int(it.launchGroup)], ["Call", "Bob\n555", "green", 2])
	expect(W31DialogLogic.apply_note_properties(ProgramStore, g, id, {"name": "Call Bob", "noteColor": "pink", "launchGroup": 0, "win31Icon": "readme"}))
	it = ProgramStore.find_item(g, id)
	expect_eq([it.name, it.noteColor, int(it.launchGroup), it.win31Icon, it.note, it.path], ["Call Bob", "pink", 0, "readme", "Bob\n555", ""])
	expect(not W31DialogLogic.apply_note_properties(ProgramStore, g, "nope", {}))
	_restore_store(saved)


func test_dialog_layer_routes_notes() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo")
	var prog_id: String = ProgramStore.add_item(g, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""})
	var d1 := Win31DialogLayer.create_dialog("itemProperties", {"groupId": g, "item": ProgramStore.find_item(g, id)})
	expect(d1 is W31NoteDialogs.NoteProperties, "a note gets note Properties")
	expect_eq(d1.title, "Sticky Note Properties")
	var d2 := Win31DialogLayer.create_dialog("itemProperties", {"groupId": g, "item": ProgramStore.find_item(g, prog_id)})
	expect(d2 is W31PropertiesDialogs.ItemProperties, "programs keep the full Properties")
	var d3 := Win31DialogLayer.create_dialog("newNote", {"groupId": g})
	expect(d3 is W31NoteDialogs.NewNote)
	for d in [d1, d2, d3]:
		d.free()
	ProgramStore.delete_group(g)
	expect_eq(Win31DialogLayer.create_dialog("newNote", {}), null, "no groups, no note")
	_restore_store(saved)


func test_note_properties_has_no_program_fields() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "", "blue")
	var dlg := W31NoteDialogs.NoteProperties.new({"groupId": g, "item": ProgramStore.find_item(g, id)}, ProgramStore.groups)
	_tree().root.add_child(dlg)
	dlg.build(480)
	var texts := []
	for t in dlg.body.texts:
		texts.append(String(t.text))
	for want in ["Title:", "Color:", "Launch Group:", "Icon:"]:
		expect(texts.has(want), want)
	for unwanted in ["Command Line:", "Working Directory:", "Shortcut Key:", "Arguments:"]:
		expect(not texts.has(unwanted), unwanted)
	dlg.form.noteColor = "gray"
	dlg.form.name = "Renamed"
	dlg._submit()
	expect_eq(ProgramStore.find_item(g, id).noteColor, "gray")
	expect_eq(ProgramStore.find_item(g, id).name, "Renamed")
	dlg.free()
	_restore_store(saved)


# --------------------------------------------------------------- search

func test_quick_search_finds_notes_by_title_and_text() -> void:
	var groups := [{"id": "g", "name": "Desk", "items": [
		{"id": "p", "name": "Plumber App", "path": "plumb.exe", "icon": "default", "workingDir": ""},
		{"id": "n1", "kind": "note", "name": "Shopping", "path": "", "note": "milk\ncall the plumber", "icon": "note", "workingDir": ""},
		{"id": "n2", "kind": "note", "name": "Plumbing", "path": "", "note": "pipes", "icon": "note", "workingDir": ""},
	]}]
	var r := W31DialogLogic.quick_search_results(groups, "plumb")
	var ids := r.map(func(x): return x.item.id)
	expect_eq(ids, ["p", "n2", "n1"], "title matches rank above a text match")
	expect_eq(W31DialogLogic.quick_search_results(groups, "milk").size(), 1)
	expect_eq(W31DialogLogic.quick_search_results(groups, "").size(), 0)
	expect_eq(W31DialogLogic.quick_search_detail(r[2]), "milk", "a note shows its first line")
	expect_eq(W31DialogLogic.quick_search_detail(r[0]), "Desk", "a program shows its group")
	expect_eq(W31DialogLogic.quick_search_view(groups, "pipes").total, 1)


func test_members_list_marks_notes() -> void:
	var groups := [{"id": "g", "name": "Desk", "items": [
		{"id": "p", "name": "Calc", "path": "calc.exe", "launchGroup": 1},
		{"id": "n", "kind": "note", "name": "Todo", "path": "", "note": "", "launchGroup": 1}]}]
	var rows := W31DialogLogic.member_rows(groups, {}, 1, {"g:n": true})
	expect_eq(rows[1].text, "Calc")
	expect_eq(rows[2].text, "Todo (note)")
	expect(rows[2].checked)


# ---------------------------------------------------------------- icons

func test_note_icon_is_in_the_wfw_set_and_pickable() -> void:
	expect(W31Icons.IDS.has("note"))
	expect(WfwIcons.IDS.has("note"))
	expect_eq(W31Icons.icon_id(Notes.ICON), "note")
	expect(W31Icons.filter_ids("note").has("note"), "Change Icon / the icon filter offer it")
	var path := WfwIcons.catalog_path("note")
	expect(path.ends_with("note-32.png") and (FileAccess.file_exists(path) or ResourceLoader.exists(path)), path)
	var tex := W31Icons.texture("note")
	expect(tex != null and tex.get_size() == Vector2(32, 32))
	expect(tex.get_image().get_pixel(10, 10).is_equal_approx(Color("#ffff00")), "yellow paper")
	for s in [64, 96, 128]:
		expect(FileAccess.file_exists("res://assets/wfw/note-%d.png" % s) or ResourceLoader.exists("res://assets/wfw/note-%d.png" % s), str(s))


# --------------------------------------------------------------- combos

func test_combo_shows_ampersand_literally() -> void:
	var f := W31.font()
	var src := W31Combo.fit_label("Group 1: Morning & Mail", 400)
	expect_eq(RetroFont.parse_access(src).text, "Group 1: Morning & Mail")
	expect_eq(RetroFont.parse_access(src).accessIndex, -1, "no access key")
	expect_eq(f.measure(src), f.measure("Group 1: Morning && Mail"))
	expect_eq(RetroFont.parse_access(W31Combo.fit_label("A&&B", 400)).text, "A&&B")
	var clipped := W31Combo.fit_label("Q&A long long long name", 30)
	expect(RetroFont.parse_access(clipped).text.begins_with("Q&A"), clipped)
	expect(f.measure(clipped) <= 30)


# ---------------------------------------------------------- the shell

func test_note_layer_stacking_and_style() -> void:
	var shell := _mount_shell()
	var layer := shell.note_layer()
	expect(layer != null and layer != shell)
	expect_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks between notes reach the windows")
	var order := shell.get_children()
	expect(order.find(layer) > order.find(shell.pm) and order.find(layer) > order.find(shell.desktop_icon), "above the Program Manager")
	expect(order.find(layer) < order.find(shell.dialogs) and order.find(layer) < order.find(shell.quick), "below dialogs and Quick Search")
	expect(shell.pm.popup_layer.z_index > layer.z_index and shell.pm.client.popup_layer.z_index > layer.z_index, "menus draw over notes")
	for o in [shell.feedback, shell.dialogs, shell.quick]:
		expect(o.z_index > shell.pm.popup_layer.z_index)
	var st := shell.note_style()
	expect_eq(st.font, W31.font().font)
	expect_eq(st.font_size, 11)
	expect_eq(layer.size, Vector2(640, 480))
	shell.free()


func test_notes_open_from_the_shell_and_take_input() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "hi", "pink")
	ProgramStore.update_note_quietly(id, {"noteBounds": {"x": 100, "y": 100, "width": 180, "height": 140}})
	var shell := _mount_shell()
	shell.launch_item(ProgramStore.find_item(g, id), g)
	await _tree().process_frame
	var notes := shell.open_notes()
	expect_eq(notes.size(), 1, "double-click / Enter / Open open the note window")
	var n: StickyNote = notes[0]
	expect_eq(n.get_parent(), shell.note_layer())
	expect_eq(n.font, W31.font().font)
	# A real press-drag-release on the title strip moves it (nothing in the shell eats the events).
	var vp := shell.get_viewport()
	var start := Vector2(190, 106)
	for ev in _drag_events(start, start + Vector2(-40, 30)):
		vp.push_input(ev, true)
		await _tree().process_frame
	expect_eq(ProgramStore.find_item(g, id).noteBounds, {"x": 60, "y": 130, "width": 180, "height": 140})
	shell.free()
	_restore_store(saved)


func _drag_events(from: Vector2, to: Vector2) -> Array:
	var out := []
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	out.append(down)
	var mv := InputEventMouseMotion.new()
	mv.position = to
	mv.global_position = to
	mv.relative = to - from
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	out.append(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	out.append(up)
	return out


func test_new_note_dialog_creates_and_opens_the_note() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var shell := _mount_shell()
	UIState.open_dialog("newNote", {"groupId": g})
	await _tree().process_frame
	var dlg := shell.dialogs.current_dialog()
	expect(dlg is W31NoteDialogs.NewNote)
	dlg.form.name = "Q&A"
	dlg.form.text = "first\nsecond"
	dlg.form.noteColor = "blue"
	dlg._submit()
	await _tree().process_frame
	expect_eq(UIState.active_dialog, "")
	var items: Array = ProgramStore.find_group(g).items
	expect_eq(items.size(), 1)
	expect_eq([items[0].name, items[0].note, items[0].noteColor], ["Q&A", "first\nsecond", "blue"])
	expect_eq(shell.open_notes().size(), 1, "the new note opens")
	shell.free()
	_restore_store(saved)


func test_host_notice_icon_follows_its_severity() -> void:
	expect_eq(Win31Shell.notice_icon(false), "information", "a successful Import All")
	expect_eq(Win31Shell.notice_icon(true), "warning", "a save failure or a refused import")
	expect_eq(MAIN.import_notice({"success": true}).alert, false)
	expect_eq(MAIN.import_notice({"success": false, "error": "Invalid file format"}).alert, true)


# ------------------------------------------------------ Launcher Tools

func test_grp_export_status_says_notes_were_left_out() -> void:
	var ok := {"success": true}
	expect_eq(LauncherToolsLogic.export_grp_status("Main", ok), "Exported “Main” as a Windows 3.x .GRP file.")
	expect(LauncherToolsLogic.export_grp_status("Main", ok, 1).ends_with("1 sticky note was left out: a .GRP file has no sticky notes."))
	expect(LauncherToolsLogic.export_grp_status("Main", ok, 3).contains("3 sticky notes were left out"))


func test_launcher_tools_fits_its_default_and_minimum_width() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("A Program Group With A Rather Long Name For A Drop-down")
	for i in 4:
		var id: String = ProgramStore.add_item(g, {"name": "Program %d With A Long Descriptive Name That Goes On" % i,
			"path": "p%d.exe" % i, "icon": "default", "workingDir": ""})
		ProgramStore.update_item(g, id, {"launchGroup": i + 1})
		ProgramStore.set_launch_group_name(i + 1, "Launch group & name number %d, rather long" % (i + 1))
	var w := LauncherToolsWindow.new()
	_tree().root.add_child(w)
	await _tree().process_frame
	w._selected_item_key = "%s:%s" % [g, ProgramStore.find_group(g).items[0].id]
	w._rebuild()
	await _tree().process_frame
	expect(w._root.get_combined_minimum_size().x <= LauncherToolsWindow.BASE_MIN_SIZE.x,
		"needs %s px, minimum window is %d" % [w._root.get_combined_minimum_size().x, LauncherToolsWindow.BASE_MIN_SIZE.x])
	w.free()
	_restore_store(saved)
