extends TestCase
## Sticky notes in the Mac shell: the pure helpers behind New Note…, the note Get Info, Find, the folder list view,
## Launch Groups and the About counts (MacDialogLogic), the menus (MacMenuModel), the icon, and the mounted shell
## hosting the notes (layer order, font, opening, keyboard and mouse routing, menus over notes, dialogs).

const SHELL_SCRIPT := preload("res://src/shells/mac/mac_shell.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-mac-notes-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _groups() -> Array:
	var note := Notes.make_note("Shopping", "milk\nfresh eggs", "blue")
	note["id"] = "n1"
	var todo := Notes.make_note("Todo", "call the plumber", "yellow")
	todo["id"] = "n2"
	todo["launchGroup"] = 2
	return [
		{"id": "a", "name": "Main", "items": [
			{"id": "p1", "name": "Egg Timer", "path": "/usr/bin/timer", "icon": "default", "workingDir": ""},
			{"id": "p2", "name": "Mail", "path": "/usr/bin/mail", "icon": "default", "workingDir": "", "launchGroup": 2},
			note]},
		{"id": "b", "name": "Web", "items": [
			{"id": "w1", "name": "News", "path": "https://example.com/eggs", "icon": "network", "workingDir": ""},
			todo]},
	]


func _ids(results: Array) -> Array:
	return results.map(func(r): return String(r.item.id))


# ------------------------------------------------------------------ pure helpers

func test_find_matches_notes_by_title_and_text() -> void:
	var gs := _groups()
	expect_eq(_ids(MacDialogLogic.find_items(gs, "egg", "all", "all")), ["p1", "n1"],
		"names first (Egg Timer; a command line containing eggs does not count), then a note whose text matches")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "shop", "all", "all")), ["n1"], "a note matches by its title")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "EGGS", "all", "note")), ["n1"], "notes only, text match ignores case")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "", "all", "note")), ["n1", "n2"], "every note when the query is blank")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "plumber", "a", "all")), [], "text matches respect the folder")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "plumber", "b", "all")), ["n2"])
	expect_eq(_ids(MacDialogLogic.find_items(gs, "", "all", "app")), ["p1", "p2"], "programs leaves notes (and web sites) out")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "", "all", "url")), ["w1"])
	expect_eq(_ids(MacDialogLogic.find_items(gs, "", "all", "batch")), ["p2", "n2"], "a note can be in a launch group")
	expect_eq(_ids(MacDialogLogic.find_items(gs, "*plumb*", "all", "all")), [], "wildcards match names only")


func test_find_columns_and_list_cells() -> void:
	var gs := _groups()
	var note: Dictionary = gs[0].items[2]
	expect_eq(MacDialogLogic.find_detail(note, false), "milk", "a note shows its first line")
	expect_eq(MacDialogLogic.find_detail(gs[0].items[0], false), "/usr/bin/timer")
	expect_eq(MacDialogLogic.find_detail(gs[1].items[1], true, {"2": "Evening"}), "Group 2: Evening")
	expect_eq(MacDialogLogic.find_detail_header("note"), "Text")
	expect_eq(MacDialogLogic.find_detail_header("batch"), "Launch Group")
	expect_eq(MacDialogLogic.find_detail_header("all"), "Command")
	expect_eq(MacDialogLogic.command_cell(note), "sticky note")
	expect_eq(MacDialogLogic.command_cell(gs[0].items[0]), "/usr/bin/timer")
	expect_eq(MacDialogLogic.kind_of(note), "sticky note")
	expect_eq(MacDialogLogic.kind_of(gs[1].items[0]), "Internet shortcut", "programs keep their kinds")


func test_note_group_color_and_counts() -> void:
	var gs := _groups()
	expect_eq(MacDialogLogic.note_group(gs, "g:b"), "b", "the front folder")
	expect_eq(MacDialogLogic.note_group(gs, "computer"), "a", "else the first folder")
	expect_eq(MacDialogLogic.note_group(gs, "g:gone"), "a")
	expect_eq(MacDialogLogic.note_group([], "g:a"), "")
	expect_eq(MacDialogLogic.note_color_options(), Notes.color_choices())
	expect_eq(MacDialogLogic.note_color_index("pink"), 1)
	expect_eq(MacDialogLogic.note_color_index("plaid"), 0)
	expect_eq(MacDialogLogic.count_items(gs), {"programs": 3, "notes": 2})
	expect_eq(MacDialogLogic.stats_line(gs, {}), "2 folders, 3 programs, 2 sticky notes, 1 launch group")
	expect_eq(MacDialogLogic.computer_line(gs), "2 folders, 3 programs, 2 sticky notes")
	expect_eq(MacDialogLogic.computer_line([{"id": "x", "name": "X", "items": []}]), "1 folder, 0 programs")
	expect(MacDialogLogic.ICON_CHOICES.has("note"), "the note icon is pickable in Change Icon")
	expect_eq(MacIconCatalog.get_icon_id(Notes.ICON), "note")
	expect(ResourceLoader.exists(MacIconCatalog.path_for("note", "large")) and ResourceLoader.exists(MacIconCatalog.path_for("note", "small")))
	expect(ResourceLoader.exists(MacIconCatalog.path_for("info", "large")), "the alert balloon kept its art")
	var big := MacIconCatalog.texture("note", "large")
	var small := MacIconCatalog.texture("note", "small")
	expect_eq(big.get_size(), Vector2(32, 32))
	expect_eq(small.get_size(), Vector2(16, 16))
	expect(big != MacIconCatalog.texture("information", "large"), "the sticky note is not the alert balloon")


func test_member_rows_include_notes() -> void:
	var gs := _groups()
	var rows := MacDialogLogic.member_rows(gs, 2, {"2": "Evening"})
	expect_eq(rows.map(func(r): return r.label), ["Egg Timer", "Mail", "Shopping", "News", "Todo"])
	expect_eq(rows.map(func(r): return r.sub), ["Main", "Main", "Main (note)", "Web", "Web (note)"])
	expect_eq(rows.map(func(r): return r.checked), [false, true, false, false, true])
	expect_eq(MacDialogLogic.members_summary(rows), "2 of 5 items checked")
	var programs_only := rows.filter(func(r): return not r.note)
	expect_eq(MacDialogLogic.members_summary(programs_only), "1 of 3 programs checked")


func test_store_helpers_create_and_edit_notes() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var other: String = ProgramStore.add_group("Other")
	var id := MacDialogLogic.create_note(ProgramStore, g, "  ", "line one\r\nline two", "green")
	var it := ProgramStore.find_item(g, id)
	expect(Notes.is_note(it))
	expect_eq(it.name, MacDialogLogic.DEFAULT_NOTE_NAME, "a blank title becomes the default")
	expect_eq(it.note, "line one\nline two")
	expect_eq(it.noteColor, "green")
	expect_eq(it.icon, "note")
	expect_eq(MacDialogLogic.create_note(ProgramStore, "gone", "x", "", "pink"), "")
	var bad := MacDialogLogic.apply_note_info(ProgramStore, g, id, {"name": " ", "noteColor": "pink", "launchGroup": "0"})
	expect(not bad.ok and String(bad.error).contains("title"))
	var bad_lg := MacDialogLogic.apply_note_info(ProgramStore, g, id, {"name": "x", "launchGroup": "12"})
	expect(not bad_lg.ok)
	var ok := MacDialogLogic.apply_note_info(ProgramStore, g, id, {"name": "Plans", "noteColor": "purple", "launchGroup": "3",
		"icon": "readme", "groupId": other})
	expect(ok.ok)
	expect_eq(ok.groupId, other)
	var moved := ProgramStore.find_item(other, id)
	expect_eq([moved.name, moved.noteColor, moved.launchGroup, moved.icon], ["Plans", "purple", 3, "readme"])
	expect_eq(moved.note, "line one\nline two", "the text is kept")
	expect(not moved.has("path") or String(moved.path) == "", "no target is added")
	MacDialogLogic.apply_note_info(ProgramStore, other, id, {"name": "Plans", "noteColor": "plaid", "launchGroup": "None"})
	expect_eq(ProgramStore.find_item(other, id).noteColor, "purple", "an unknown colour is ignored")
	expect_eq(ProgramStore.find_item(other, id).launchGroup, 0)
	ProgramStore.update_note_quietly(id, {"noteOpen": true, "noteBounds": {"x": 1, "y": 2, "width": 120, "height": 90}})
	var copy_id := MacDialogLogic.duplicate_item(ProgramStore, other, id, "copy")
	var copy := ProgramStore.find_item(other, copy_id)
	expect(Notes.is_note(copy) and copy.name == "Plans copy" and copy.note == "line one\nline two")
	expect(not copy.has("noteOpen") and not copy.has("noteBounds"), "a copy starts closed")
	_restore_store(saved)


func test_menus_offer_new_note() -> void:
	var ctx := {"groups": [{"id": "a", "name": "Main"}], "active_key": "computer", "view": "", "selected": {"kind": ""}, "buckets": []}
	var file: Array = MacMenuModel.menu_bar(ctx)[1].items
	var ids := file.map(func(i): return String(i.get("id", "-")))
	expect_eq(ids.slice(0, 5), ["new-folder", "new-program", "new-website", "new-note", "open"])
	expect(MacMenuModel.desktop_menu().any(func(i): return i.get("id", "") == "new-note"))
	expect(MacMenuModel.folder_background_menu(false, "large").any(func(i): return i.get("id", "") == "new-note"))
	expect(not MacMenuModel.folder_background_menu(true, "large").any(func(i): return i.get("id", "") == "new-note"),
		"Launcher HD makes folders, not notes")


# ------------------------------------------------------------------ mounted shell

var _old_root_size := Vector2i.ZERO


func _unmount(shell: MacShell) -> void:
	shell.free()
	if _old_root_size != Vector2i.ZERO:
		_tree().root.size = _old_root_size


func _mount() -> MacShell:
	# the headless window is 64x64; injected clicks only reach controls inside the window
	_old_root_size = _tree().root.size
	_tree().root.size = Vector2i(640, 480)
	var shell: MacShell = SHELL_SCRIPT.new()
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.on_activate()
	return shell


func _dialogs(shell: MacShell) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is MacDialog and not c.is_queued_for_deletion())


func test_shell_hosts_notes_between_windows_and_menus() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Todo", "first", "pink")
	var shell := _mount()
	await _frames(2)
	var layer := shell.note_layer()
	expect_eq(layer, shell.notes_layer)
	expect(layer.get_index() > shell.desktop.get_index(), "above the desktop and its folder windows")
	for above in [shell.popup_layer, shell.menu_bar, shell.toast_ctl, shell.dialog_layer, shell.select_layer]:
		expect(layer.get_index() < above.get_index(), "below " + String(above.get_class()))
	expect_eq(layer.get_rect(), Rect2(0, MacGeometry.MENU_H, 640, 480 - MacGeometry.MENU_H), "the desktop under the menu bar")
	expect_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks between notes reach the desktop")
	var style := shell.note_style()
	expect_eq(style.font, MacDraw.font().font)
	expect_eq(style.font_size, 11)
	expect_eq(style.text_color, Color.BLACK)
	# opening goes through Platform.launch; a host would answer note_open_requested (here a stand-in host does)
	var host_calls := []
	var host := func(item_id: String):
		host_calls.append(item_id)
		shell.open_note(item_id)
	Platform.note_open_requested.connect(host)
	shell.open_group_window(g)
	shell.desktop.store.set_selection("g:" + g, id)
	shell.run_command("open", shell._target())
	Platform.note_open_requested.disconnect(host)
	expect_eq(host_calls, [id], "the payload kept the note's id")
	expect_eq(shell.open_notes().size(), 1)
	var note: StickyNote = shell.open_notes()[0]
	expect_eq(note.get_parent(), layer)
	expect_eq(note.font, MacDraw.font().font)
	# without a host the shell opens it itself, and never twice
	shell.launch_item(ProgramStore.find_item(g, id))
	expect_eq(shell.open_notes().size(), 1)
	# dark theme: the paper stays light and the text black
	ProgramStore.update_settings({"theme": "dark"})
	await _frames(1)
	var id2: String = ProgramStore.add_note(g, "Dark", "x", "blue")
	var dark_note := shell.open_note(id2, false)
	expect_eq(dark_note.text_color, Color.BLACK)
	expect_eq(dark_note.paper, Notes.COLORS.blue)
	_unmount(shell)
	_restore_store(saved)


func test_notes_take_clicks_drags_and_keys_without_the_desktop_eating_them() -> void:
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
	# drag by the title strip
	var before := note.position
	await a.drag(a.center("note.title:" + id), a.center("note.title:" + id) + Vector2(-60, -40), 4, true)
	await _frames(1)
	expect_eq(note.position, before + Vector2(-60, -40), "the note moved")
	expect_eq(ProgramStore.find_item(g, id).noteBounds.x, int(before.x) - 60, "and saved where")
	# click into the text and type: Return, arrows and Delete go to the note, not to the folder window
	await a.click(note.global_position + Vector2(40, 60))
	await _frames(1)
	expect(note._edit.has_focus(), "a click in the paper puts the caret in the note")
	await a.type_text("hi")
	await a.key(KEY_ENTER)
	await a.type_text("yo")
	await a.key(KEY_LEFT)
	await a.key(KEY_BACKSPACE)
	await _frames(1)
	expect_eq(note.text(), "hi\no", "typed into the note")
	expect_eq(String(shell.desktop.store.find("g:" + g).get("sel", "")), prog, "the folder selection did not move")
	expect_eq(_dialogs(shell).size(), 0, "Delete did not ask to trash the selected program")
	expect(not ProgramStore.find_item(g, prog).is_empty())
	# a click on the desktop gives the keyboard back to the folder windows
	await a.click(Vector2(20, 400))
	await _frames(1)
	expect(not note._edit.has_focus(), "clicking outside the note releases its text")
	# menus drop down over notes and take the click
	note.place(Rect2i(0, 0, 240, 200))
	await _frames(1)
	await a.click_id("mac.menu:File")
	await _frames(1)
	var item_at := a.center("mac.popup-item:New Folder")
	expect(note.get_global_rect().has_point(item_at), "the menu item lies over the note")
	await a.click(item_at)
	await _frames(2)
	var ds := _dialogs(shell)
	expect_eq(ds.size(), 1, "the menu command ran")
	if ds.size() == 1:
		expect_eq(ds[0].title, "New Folder")
		ds[0].close()
	await _frames(1)
	# a modal alert takes the keyboard from the note behind it
	note.focus_text()
	await _frames(1)
	var before_text := note.text()
	var alert := MacDialogs.message(shell, "Hello", "note")
	await a.type_text("z")
	await _frames(1)
	expect_eq(note.text(), before_text, "keys did not type into the note behind the alert")
	expect(not note._edit.has_focus())
	alert.close()
	await _frames(1)
	# Cmd-W while typing in a note closes the note, not the folder window
	note.focus_text()
	await _frames(1)
	await a.key(KEY_W, {"meta": true})
	await _frames(2)
	expect_eq(shell.open_notes().size(), 0, "the note closed")
	expect(shell.desktop.store.has("g:" + g), "the folder window stayed open")
	expect_eq(ProgramStore.find_item(g, id).noteOpen, false)
	_unmount(shell)
	_restore_store(saved)


func test_new_note_dialog_creates_and_opens_the_note() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var other: String = ProgramStore.add_group("Other")
	var shell := _mount()
	await _frames(2)
	shell.open_group_window(other)
	await _frames(1)
	var a := Automation.new(_tree())
	await a.click_id("mac.menu:File")
	await _frames(1)
	await a.click_id("mac.popup-item:New Note…")
	await _frames(2)
	var ds := _dialogs(shell)
	expect_eq(ds.size(), 1)
	if ds.size() != 1:
		_unmount(shell)
		_restore_store(saved)
		return
	var d: MacDialog = ds[0]
	expect_eq(d.title, "New Note")
	for id in ["mac.dialog.field:Title", "mac.dialog.select:Color", "mac.dialog.select:Folder", "mac.dialog.field:Text", "mac.dialog.swatch:Color"]:
		expect(a.has(id), id)
	var folder: MacSelect = d.find_children("*", "MacSelect", true, false).filter(func(s): return s.get_meta("auto_id") == "mac.dialog.select:Folder")[0]
	expect_eq(folder.current_id(), other, "the front folder")
	await a.type_text("Plans")
	await a.click_id("mac.dialog.select:Color")
	await _frames(1)
	await a.click_id("mac.select-item:Green")
	await _frames(1)
	await a.click_id("mac.dialog.field:Text")
	await a.type_text("ab")
	await a.key(KEY_ENTER)
	await a.type_text("c")
	await _frames(1)
	expect_eq(_dialogs(shell).size(), 1, "Return in the text makes a new line instead of pressing OK")
	await a.click_id("mac.dialog.button:OK")
	await _frames(2)
	expect_eq(_dialogs(shell).size(), 0)
	var items: Array = ProgramStore.find_group(other).items
	expect_eq(items.size(), 1)
	if items.size() == 1:
		expect(Notes.is_note(items[0]))
		expect_eq([items[0].name, items[0].noteColor, items[0].note], ["Plans", "green", "ab\nc"])
		expect_eq(shell.open_notes().map(func(n): return n.item_id), [String(items[0].id)], "the new note opened")
	expect(ProgramStore.find_group(g).items.is_empty())
	_unmount(shell)
	_restore_store(saved)


func test_get_info_for_a_note_has_no_program_fields() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Todo", "x", "yellow")
	var prog: String = ProgramStore.add_item(g, {"name": "Calc", "path": "/usr/bin/calc", "icon": "default", "workingDir": ""})
	var shell := _mount()
	await _frames(2)
	var a := Automation.new(_tree())
	var note := shell.open_note(id, false)
	MacDialogs.get_info_item(shell, g, id)
	await _frames(1)
	for present in ["mac.dialog.field:Name", "mac.dialog.select:Where", "mac.dialog.select:Color", "mac.dialog.select:Launch group",
			"mac.dialog.button:Change Icon..."]:
		expect(a.has(present), present)
	for absent in ["mac.dialog.field:Target", "mac.dialog.field:Start in", "mac.dialog.field:Arguments", "mac.dialog.field:Environment",
			"mac.dialog.field:Shortcut key", "mac.dialog.select:Open as"]:
		expect(not a.has(absent), absent + " is not offered for a note")
	var labels: Array = _dialogs(shell)[0].find_children("*", "MacLabel", true, false).map(func(l): return l.text)
	expect(labels.has("sticky note"), str(labels))
	await a.click_id("mac.dialog.select:Color")
	await _frames(1)
	await a.click_id("mac.select-item:Purple")
	await a.click_id("mac.dialog.button:OK")
	await _frames(2)
	expect_eq(ProgramStore.find_item(g, id).noteColor, "purple")
	expect_eq(note.paper, Notes.COLORS.purple, "the open note follows")
	# programs keep the full form
	MacDialogs.get_info_item(shell, g, prog)
	await _frames(1)
	expect(a.has("mac.dialog.field:Target") and a.has("mac.dialog.select:Open as"))
	expect(not a.has("mac.dialog.select:Color"))
	_unmount(shell)
	_restore_store(saved)


func test_find_window_lists_notes() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Main")
	var id: String = ProgramStore.add_note(g, "Shopping", "milk and eggs", "yellow")
	var shell := _mount()
	await _frames(2)
	shell.open_find()
	var w: MacFindWindow = shell.desktop.window_for("find")
	expect(w.type_sel.options.any(func(o): return o.id == "note"), "a notes choice")
	w.query.text = "eggs"
	w.run_search()
	expect_eq(w.results.map(func(r): return String(r.item.id)), [id])
	w.type_sel.select_id("note")
	w.query.text = ""
	w.run_search()
	expect_eq(w.results.size(), 1)
	_unmount(shell)
	_restore_store(saved)
