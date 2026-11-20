extends TestCase
## Mac shell polish around sticky notes and lists: the note's contextual menu (right-click / Control-click), Cmd-keys
## while typing in a note or the Find field (item commands must not reach the folder selection), the list view's
## Launch Group column, and pop-up buttons that open over themselves with the current item on the button.

const SHELL_SCRIPT := preload("res://src/shells/mac/mac_shell.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-mac-note-menu-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _use_scratch_store() -> Dictionary:
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence}
	ProgramStore.init_store(_tmp())
	return saved


func _restore_store(saved: Dictionary) -> void:
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	ProgramStore.groups_changed.emit()
	ProgramStore.settings_changed.emit()
	MacTheme.refresh_from_settings()


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


var _old_root_size := Vector2i.ZERO


func _mount() -> MacShell:
	# the headless window is 64x64; injected clicks only reach controls inside the window
	_old_root_size = _tree().root.size
	_tree().root.size = Vector2i(640, 480)
	var shell: MacShell = SHELL_SCRIPT.new()
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.on_activate()
	return shell


func _unmount(shell: MacShell) -> void:
	shell.free()
	if _old_root_size != Vector2i.ZERO:
		_tree().root.size = _old_root_size


func _dialogs(shell: MacShell) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is MacDialog and not c.is_queued_for_deletion())


func _popup(shell: MacShell) -> MacPopupMenu:
	for c in shell.popup_layer.get_children():
		if c is MacPopupMenu and not c.is_queued_for_deletion():
			return c
	return null


func _checked(m: MacPopupMenu) -> Array:
	return m.items.filter(func(i): return i.get("check", false)).map(func(i): return String(i.id))


# ------------------------------------------------------------------ pure helpers

func test_note_menu_rows() -> void:
	var swatch := MacDraw.swatch_texture(Notes.COLORS.pink)
	var m := MacMenuModel.note_menu("pink", {"pink": swatch})
	var ids := m.map(func(i): return String(i.get("id", "-")))
	expect_eq(ids, ["note-close", "note-info", "-", "note-color:yellow", "note-color:pink", "note-color:blue",
		"note-color:green", "note-color:purple", "note-color:gray", "-", "note-trash"])
	expect_eq(m.slice(0, 2).map(func(i): return String(i.label)), ["Close", "Get Info"])
	expect_eq(m[10].label, "Move To Trash…", "the File menu's wording, with an ellipsis: it asks first")
	var checked := m.filter(func(i): return i.get("check", false)).map(func(i): return i.id)
	expect_eq(checked, ["note-color:pink"], "only the current colour is checked")
	expect_eq(m[4].icon, swatch, "colour rows carry their swatch")
	expect(not m[3].has("icon"), "no swatch passed, no icon")
	expect_eq(MacMenuModel.note_menu("plaid").filter(func(i): return i.get("check", false)).map(func(i): return i.id),
		["note-color:yellow"], "an unknown colour shows the default")
	expect_eq(swatch.get_size(), Vector2(16, 16))
	expect_eq(MacDraw.swatch_texture(Notes.COLORS.pink), swatch, "cached")
	expect_eq(swatch.get_image().get_pixel(8, 8), Notes.COLORS.pink)
	expect_eq(swatch.get_image().get_pixel(0, 0).a, 0.0, "transparent around the square")
	expect_eq(MacDialogLogic.note_trash_prompt("Todo"), "Delete the sticky note “Todo”?")
	expect(MacDialogLogic.is_context_click(MOUSE_BUTTON_RIGHT, false))
	expect(MacDialogLogic.is_context_click(MOUSE_BUTTON_LEFT, true), "Control-click")
	expect(not MacDialogLogic.is_context_click(MOUSE_BUTTON_LEFT, false))
	expect(not MacDialogLogic.is_context_click(MOUSE_BUTTON_MIDDLE, true))


func test_set_note_color() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Todo", "x", "yellow")
	var prog: String = ProgramStore.add_item(g, {"name": "Calc", "path": "/usr/bin/calc", "icon": "default", "workingDir": ""})
	expect(MacDialogLogic.set_note_color(ProgramStore, id, "green"))
	expect_eq(ProgramStore.find_item(g, id).noteColor, "green")
	expect(not MacDialogLogic.set_note_color(ProgramStore, id, "plaid"))
	expect_eq(ProgramStore.find_item(g, id).noteColor, "green", "an unknown colour changes nothing")
	expect(not MacDialogLogic.set_note_color(ProgramStore, prog, "pink"), "programs have no paper")
	expect(not ProgramStore.find_item(g, prog).has("noteColor"))
	expect(not MacDialogLogic.set_note_color(ProgramStore, "gone", "pink"))
	_restore_store(saved)


func test_typing_commands_and_list_columns() -> void:
	for cmd in ["close-window", "find"]:
		expect(MacMenuModel.allowed_while_typing(cmd), cmd)
	for cmd in ["trash", "duplicate", "get-info", "open", "new-folder", "run", ""]:
		expect(not MacMenuModel.allowed_while_typing(cmd), cmd + " is left to the text box")
	expect_eq(MacDialogLogic.list_headers(false, 200), ["Name", "Command", "Launch Group"])
	expect_eq(MacDialogLogic.list_headers(false, MacDraw.measure("Launch Group") - 1), ["Name", "Command", "Group"], "short form when tight")
	expect_eq(MacDialogLogic.list_headers(true, 200), ["Name", "Size", "Type"])
	expect_eq(MacDialogLogic.launch_group_cell(0, {}), "—")
	var long := MacDialogLogic.launch_group_cell(3, {"3": "Morning coffee and the news"})
	var fitted := MacDraw.fit(long, 86)
	expect(fitted.ends_with("...") and MacDraw.measure(fitted) <= 86, fitted)
	expect(fitted.begins_with("Group 3: Mor"), fitted)
	expect_eq(MacDraw.fit("Group 2", 86), "Group 2", "fits: unchanged")
	expect(not MacDraw.fit("Group 3: a b", MacDraw.measure("Group 3:...") + 1).contains(" ..."), "no space before the dots")
	var narrow := MacGeometry.details_layout([], 300)
	var wide := MacGeometry.details_layout([], 600)
	expect_eq(narrow.cols[2].w, 100)
	expect_eq(wide.cols[2].w, 150, "the launch group column grows with the window")
	for d in [narrow, wide]:
		expect_eq(d.cols[0].w + d.cols[1].w + d.cols[2].w, d.width)
		expect(MacDraw.measure("Launch Group") <= int(d.cols[2].w) - 14, "the full header fits at the narrowest")


func test_file_chooser_palette_follows_the_theme() -> void:
	var was := MacTheme.dark
	MacTheme.dark = false
	var light := MacTheme.file_dialog_palette()
	expect_eq(light.face, Color8(221, 221, 221), "platinum")
	expect_eq(light.text, Color.BLACK)
	expect_eq(light.select, Color8(204, 204, 255), "the lavender highlight")
	expect_eq(light.folder, Color8(153, 153, 255), "the shell's folder colour")
	for k in FileDialogTheme.DEFAULT_PALETTE:
		expect(light.has(k), "sets " + k)
	MacTheme.dark = true
	var dark := MacTheme.file_dialog_palette()
	expect_eq(dark.face, Color("#323337"))
	expect_eq(dark.field, Color("#1d1e21"))
	expect_eq(dark.text, Color("#e3e4e6"), "light text on the dark face")
	expect(dark.text.get_luminance() - dark.field.get_luminance() > 0.5, "readable")
	MacTheme.dark = was
	expect(FileDialogTheme.make({}, light) is Theme)


func test_select_popup_origin() -> void:
	var b := Rect2(100, 200, 150, 21)
	expect_eq(MacGeometry.select_popup_origin(b, 0, 20, 3, 15), Vector2(85, 197), "the first row on the button")
	expect_eq(MacGeometry.select_popup_origin(b, 2, 20, 3, 15), Vector2(85, 157), "the third row on the button")
	expect_eq(MacGeometry.select_popup_origin(b, -1, 20, 3, 15), Vector2(85, 197), "no current item: the first row")


# ------------------------------------------------------------------ mounted shell

func test_select_opens_over_the_button_with_the_current_item_on_it() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Todo", "x", "blue")
	var shell := _mount()
	await _frames(2)
	var a := Automation.new(_tree())
	MacDialogs.get_info_item(shell, g, id)
	await _frames(1)
	var sel_rect := a.find_rect("mac.dialog.select:Color")
	await a.click_id("mac.dialog.select:Color")
	await _frames(1)
	var cur := a.find_rect("mac.select-item:Blue")
	expect(cur.size.y > 0, "the menu is open")
	expect(cur.has_point(sel_rect.get_center()), "the current item lies on the button: %s %s" % [cur, sel_rect])
	var menus := shell.select_layer.get_children().filter(func(c): return c is MacPopupMenu)
	expect_eq(menus.size(), 1)
	if menus.size() == 1:
		var pr: Rect2 = menus[0].panel_rect
		expect(pr.position.x < sel_rect.position.x and pr.end.x >= sel_rect.end.x - 1, "the menu covers the button: %s" % pr)
	# a pick still works, and the next opening puts the new value on the button
	await a.click_id("mac.select-item:Gray")
	await _frames(1)
	expect(shell.select_layer.get_children().filter(func(c): return c is MacPopupMenu and not c.is_queued_for_deletion()).is_empty())
	await a.click_id("mac.dialog.select:Color")
	await _frames(1)
	expect(a.find_rect("mac.select-item:Gray").has_point(sel_rect.get_center()))
	await a.key(KEY_ESCAPE)
	await _frames(1)
	_unmount(shell)
	_restore_store(saved)


func test_cmd_keys_in_a_note_leave_the_folder_selection_alone() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var prog: String = ProgramStore.add_item(g, {"name": "Calc", "path": "/usr/bin/calc", "icon": "default", "workingDir": ""})
	var id: String = ProgramStore.add_note(g, "Todo", "", "yellow")
	ProgramStore.update_note_quietly(id, {"noteBounds": {"x": 250, "y": 200, "width": 180, "height": 140}})
	var shell := _mount()
	await _frames(2)
	shell.open_group_window(g)
	shell.desktop.store.set_selection("g:" + g, prog)
	var note := shell.open_note(id, false)
	await _frames(2)
	var a := Automation.new(_tree())
	await a.click(note.global_position + Vector2(40, 60))
	await a.type_text("abc")
	await _frames(1)
	var item_count: int = ProgramStore.find_group(g).items.size()
	var windows := shell.desktop.store.windows.size()
	for mods in [{"meta": true}, {"ctrl": true}]:
		for key in [KEY_T, KEY_D, KEY_I, KEY_O, KEY_N, KEY_R, KEY_BACKSPACE, KEY_DELETE]:
			await a.key(key, mods)
			await _frames(1)
			expect_eq(_dialogs(shell).size(), 0, "%s %s opened nothing" % [OS.get_keycode_string(key), mods])
			for d in _dialogs(shell):
				d.close()
		await a.key(KEY_N, mods.merged({"shift": true}))
		await _frames(1)
		expect_eq(_dialogs(shell).size(), 0, "Shift-Cmd-N opened nothing")
	expect(note._edit.has_focus(), "the caret stayed in the note")
	expect_eq(ProgramStore.find_group(g).items.size(), item_count, "nothing was trashed or duplicated")
	expect(not ProgramStore.find_item(g, prog).is_empty(), "the selected program is still there")
	expect_eq(String(shell.desktop.store.find("g:" + g).get("sel", "")), prog)
	expect_eq(shell.desktop.store.windows.size(), windows, "no window opened")
	# text editing keys still reach the note (the headless display has no clipboard, so Select All and Undo).
	# Cmd/Ctrl-Delete above deleted words in the note, as it does in a text editor.
	await a.type_text("abc")
	var edit_modifier := {"meta": true} if OS.get_name() == "macOS" else {"ctrl": true}
	await a.key(KEY_A, edit_modifier)
	await a.type_text("xy")
	await _frames(1)
	expect_eq(note.text(), "xy", "Select All selected the note's text")
	await a.key(KEY_Z, edit_modifier)
	await _frames(1)
	expect(note.text() != "xy", "Undo undid the typing: " + note.text())
	# Cmd-W closes the note (not the folder window); the Find window below is then in the clear
	await a.key(KEY_W, {"meta": true})
	await _frames(2)
	expect_eq(shell.open_notes().size(), 0)
	expect_eq(shell.desktop.store.windows.size(), windows)
	# Cmd-F still opens Find (window-level, not an item command)
	await a.key(KEY_F, {"meta": true})
	await _frames(2)
	expect(shell.desktop.store.has("find"), "Cmd-F opened Find")
	# the Find field has the same rule: Cmd-T while typing there does not trash the selected result
	var w: MacFindWindow = shell.desktop.window_for("find")
	w.query.text = "calc"
	w.run_search()
	await _frames(1)
	await a.click_id("mac.find.result:0")
	w.query.edit.grab_focus()
	await _frames(1)
	expect(not w.selected_result().is_empty(), "a result is selected")
	await a.key(KEY_T, {"meta": true})
	await a.key(KEY_D, {"meta": true})
	await _frames(1)
	expect_eq(_dialogs(shell).size(), 0, "Cmd-T in the Find field asked nothing")
	expect_eq(ProgramStore.find_group(g).items.size(), item_count)
	# with the keyboard back on the desktop, the item commands work again
	w.query.edit.release_focus()
	shell.desktop.open_window("g:" + g)
	shell.desktop.store.set_selection("g:" + g, prog)
	await _frames(1)
	await a.key(KEY_T, {"meta": true})
	await _frames(1)
	var ds := _dialogs(shell)
	expect_eq(ds.size(), 1, "Cmd-T asks to trash the selection")
	for d in ds:
		d.close()
	_unmount(shell)
	_restore_store(saved)


func test_note_context_menu() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Todo", "", "yellow")
	ProgramStore.update_note_quietly(id, {"noteBounds": {"x": 250, "y": 200, "width": 180, "height": 140}})
	var other: String = ProgramStore.add_note(g, "Other", "", "blue")
	var shell := _mount()
	await _frames(2)
	var note := shell.open_note(id, false)
	await _frames(2)
	var a := Automation.new(_tree())
	# right-click in the text: the menu opens at the click, the current colour checked
	await a.click(note.global_position + Vector2(40, 60))
	await a.type_text("typed")
	var at := note.global_position + Vector2(60, 30)
	await a.rclick(at)
	await _frames(1)
	var m := _popup(shell)
	expect(m != null, "right-click in the text opened the note menu")
	if m == null:
		_unmount(shell)
		_restore_store(saved)
		return
	expect(m.panel_rect.position.distance_to(at) < 2.0, "at the click: %s" % m.panel_rect)
	for label in ["Close", "Get Info", "Yellow", "Pink", "Blue", "Green", "Purple", "Gray", "Move To Trash…"]:
		expect(a.has("mac.popup-item:" + label), label)
	expect_eq(_checked(m), ["note-color:yellow"])
	await a.click_id("mac.popup-item:Pink")
	await _frames(2)
	expect(_popup(shell) == null, "the menu closed")
	expect_eq(ProgramStore.find_item(g, id).noteColor, "pink")
	expect_eq(note.paper, Notes.COLORS.pink, "the open note was repainted")
	expect_eq(note.text(), "typed", "what was typed is kept")
	expect_eq(ProgramStore.find_item(g, id).note, "typed", "and saved")
	# Control-click on the title strip opens it too, now with Pink checked
	await a.click(a.center("note.title:" + id), {"ctrl": true})
	await _frames(1)
	m = _popup(shell)
	expect(m != null, "Control-click opened the note menu")
	if m != null:
		expect_eq(_checked(m), ["note-color:pink"])
		await a.click_id("mac.popup-item:Get Info")
		await _frames(2)
	var ds := _dialogs(shell)
	expect_eq(ds.size(), 1, "Get Info opened")
	if ds.size() == 1:
		expect(a.has("mac.dialog.select:Color"), "the note's Get Info")
		ds[0].close()
	await _frames(1)
	# Move To Trash… asks first; Cancel keeps the note
	await a.rclick(note.global_position + Vector2(60, 80))
	await _frames(1)
	await a.click_id("mac.popup-item:Move To Trash…")
	await _frames(2)
	ds = _dialogs(shell)
	expect_eq(ds.size(), 1, "an alert asks first")
	if ds.size() == 1:
		var labels: Array = ds[0].find_children("*", "MacLabel", true, false).map(func(l): return l.text)
		expect(labels.has("Delete the sticky note “Todo”?"), str(labels))
		await a.click_id("mac.dialog.button:Cancel")
		await _frames(2)
	expect(not ProgramStore.find_item(g, id).is_empty(), "Cancel kept it")
	await a.rclick(note.global_position + Vector2(60, 80))
	await _frames(1)
	await a.click_id("mac.popup-item:Move To Trash…")
	await _frames(2)
	await a.click_id("mac.dialog.button:Delete")
	await _frames(2)
	expect(ProgramStore.find_item(g, id).is_empty(), "Delete removed the note")
	expect_eq(shell.open_notes().size(), 0, "and its window")
	expect(not ProgramStore.find_item(g, other).is_empty(), "the other note is untouched")
	# Close
	var n2 := shell.open_note(other, false)
	await _frames(2)
	await a.rclick(n2.global_position + Vector2(60, 80))
	await _frames(1)
	await a.click_id("mac.popup-item:Close")
	await _frames(2)
	expect_eq(shell.open_notes().size(), 0, "Close closed it")
	expect_eq(ProgramStore.find_item(g, other).noteOpen, false)
	# a right-click on the desktop still opens the desktop's own menu
	await a.rclick(Vector2(200, 400))
	await _frames(1)
	m = _popup(shell)
	expect(m != null and a.has("mac.popup-item:Clean Up") and not a.has("mac.popup-item:Move To Trash…"), "the desktop's own menu")
	if m != null:
		m.close()
	_unmount(shell)
	_restore_store(saved)


func test_tab_reaches_note_dialog_controls_and_return_cancels_without_creating_a_note() -> void:
	var saved := _use_scratch_store()
	var gid: String = ProgramStore.add_group("Main")
	var shell := _mount()
	var a := Automation.new(_tree())
	await _frames(3)
	var dlg := MacDialogs.new_note(shell, gid)
	await _frames(2)
	var saw_select := false
	for i in 8:
		await a.key(KEY_TAB)
		var owner := shell.get_viewport().gui_get_focus_owner()
		if owner == null or not dlg.is_ancestor_of(owner):
			break
		saw_select = saw_select or owner is MacSelect
		if owner is MacButton and owner.label == "Cancel":
			await a.key(KEY_ENTER)
			break
	expect(saw_select,
		"Tab reaches the paper and folder selectors")
	expect(_dialogs(shell).is_empty(), "Return on the focused Cancel closes the form")
	expect_eq(ProgramStore.find_group(gid).items.size(), 0, "Cancel leaves the folder alone")
	_unmount(shell)
	_restore_store(saved)
