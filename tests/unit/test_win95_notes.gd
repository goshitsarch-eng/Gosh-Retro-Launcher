extends TestCase
## Win95 sticky notes: the note icon and Change Icon list, Find (title, text, preview, "Sticky notes"
## type), New Sticky Note (menus, wizard, dialog), the note property sheet, hosting (layer order,
## font, keyboard and pointer routing) and the batch-launch progress window with Cancel.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")
const SHELL_SCRIPT := preload("res://src/shells/win95/win95_shell.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w95-notes-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _mount() -> Win95Shell:
	var shell: Win95Shell = SHELL_SCRIPT.new()
	shell.host = _tree().root
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	await _tree().process_frame
	return shell


func _unmount(shell: Win95Shell) -> void:
	shell.queue_free()
	await _tree().process_frame


func _modals(shell: Win95Shell) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is Win95Modal and not c.is_queued_for_deletion())


func _button(root: Node, label: String) -> Win95Button:
	for b in root.find_children("*", "Win95Button", true, false):
		if String(b.label).replace("&", "") == label:
			return b
	return null


func _auto(root: Node, id: String) -> Control:
	for c in root.find_children("*", "Control", true, false):
		if c.has_meta("auto_id") and c.get_meta("auto_id") == id:
			return c
	return null


func _key(shell: Win95Shell, keycode: Key, mods: Dictionary = {}) -> bool:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.ctrl_pressed = mods.get("ctrl", false)
	ev.alt_pressed = mods.get("alt", false)
	return shell.input.on_key(ev)


func _note(id: String, name: String, text: String, lg: int = 0) -> Dictionary:
	var n := Notes.make_note(name, text)
	n["id"] = id
	if lg > 0:
		n["launchGroup"] = lg
	return n


func _groups() -> Array:
	return [
		{"id": "work", "name": "Work", "items": [
			{"id": "p1", "name": "Notepad", "path": "/bin/notepad", "icon": "application", "workingDir": "", "launchGroup": 1},
			{"id": "p2", "name": "Web", "path": "https://example.com", "icon": "url", "workingDir": ""},
			_note("n1", "Shopping", "milk, eggs\nbread", 1)]},
		{"id": "home", "name": "Home", "items": [_note("n2", "Call back", "Dentist about eggs")]},
	]


# ------------------------------------------------------------------ icon

func test_note_icon_is_in_the_catalog_and_change_icon_list() -> void:
	expect(Win95IconCatalog.ICON_IDS.has("note"))
	expect_eq(Win95IconCatalog.get_icon_id(Notes.ICON), "note")
	expect_eq(Win95IconCatalog.get_icon_id("sticky-note"), "note")
	expect_eq(Win95IconCatalog.texture("note", "large").get_size(), Vector2(32, 32))
	expect_eq(Win95IconCatalog.texture("note", "small").get_size(), Vector2(16, 16))
	expect_eq(Win95IconCatalog.PICKABLE_IDS[0], "note")
	for id in Win95IconCatalog.PICKABLE_IDS:
		expect(Win95IconCatalog.ICON_IDS.has(id), id)


func test_icon_grid_cells_fill_column_by_column_and_fit_the_change_icon_box() -> void:
	expect_eq(Win95IconGrid.cell_rect(0).position, Vector2(2, 2))
	expect_eq(Win95IconGrid.cell_rect(2).position, Vector2(2, 2 + 2 * 38))
	expect_eq(Win95IconGrid.cell_rect(3).position, Vector2(42, 2))
	expect_eq(Win95IconGrid.index_at(Vector2(45, 3), 10), 3)
	expect_eq(Win95IconGrid.index_at(Vector2(45, 200), 10), -1, "below the last row")
	expect_eq(Win95IconGrid.index_at(Vector2(400, 3), 10), -1, "past the last icon")
	expect_eq(Win95IconGrid.next_index(4, "ArrowRight", 10), 7)
	expect_eq(Win95IconGrid.next_index(8, "ArrowRight", 10), 8, "no column to the right")
	expect_eq(Win95IconGrid.next_index(4, "ArrowLeft", 10), 1)
	expect_eq(Win95IconGrid.next_index(4, "ArrowDown", 10), 5)
	expect_eq(Win95IconGrid.next_index(0, "ArrowUp", 10), 0)
	expect_eq(Win95IconGrid.next_index(4, "End", 10), 9)
	var columns := ceili(Win95IconCatalog.PICKABLE_IDS.size() / float(Win95IconGrid.ROWS))
	expect(columns * Win95IconGrid.CELL.x + 4 <= 380 - 8 - 18, "every pickable icon is visible without scrolling")


# ------------------------------------------------------------------ Find

func test_find_finds_notes_by_title_and_by_text() -> void:
	var g := _groups()
	var f := Win95DialogLogic.find_filters("shop", "", true, "all", "", "")
	expect_eq(Win95DialogLogic.find_results(g, f).map(func(r): return r.item.id), ["n1"])
	f = Win95DialogLogic.find_filters("eggs", "", true, "all", "", "")
	var by_text := Win95DialogLogic.find_results(g, f).map(func(r): return r.item.id)
	by_text.sort()
	expect_eq(by_text, ["n1", "n2"], "found by the words in their text")
	f = Win95DialogLogic.find_filters("*", "", true, "all", "dentist", "")
	expect_eq(Win95DialogLogic.find_results(g, f).map(func(r): return r.item.id), ["n2"], "Containing text searches note text")
	f = Win95DialogLogic.find_filters("*", "", true, "all", "", "bin")
	expect_eq(Win95DialogLogic.find_results(g, f).map(func(r): return r.item.id), ["p1"], "notes have no path")
	f = Win95DialogLogic.find_filters("*", "home", true, "all", "", "")
	expect_eq(Win95DialogLogic.find_results(g, f).map(func(r): return r.item.id), ["n2"], "Look in")
	f = Win95DialogLogic.find_filters("Shopping", "", true, "all", "", "")
	expect_eq(Win95DialogLogic.find_results(g, f)[0].score, 3, "an exact title ranks like a program")


func test_find_of_type_sticky_notes_and_the_other_types() -> void:
	var g := _groups()
	expect_eq(Win95DialogLogic.FIND_TYPES.size(), Win95DialogLogic.FIND_TYPE_LABELS.size())
	var i := Win95DialogLogic.FIND_TYPES.find("note")
	expect_eq(Win95DialogLogic.FIND_TYPE_LABELS[i], "Sticky notes")
	var ids := func(type: String) -> Array:
		var out: Array = Win95DialogLogic.find_results(g, Win95DialogLogic.find_filters("*", "", true, type, "", "")).map(func(r): return r.item.id)
		out.sort()
		return out
	expect_eq(ids.call("note"), ["n1", "n2"])
	expect_eq(ids.call("application"), ["p1"], "a note is not an application")
	expect_eq(ids.call("internet"), ["p2"])
	expect_eq(ids.call("launch-group"), ["n1", "p1"], "notes in a launch group are found too")
	expect_eq(ids.call("all"), ["n1", "n2", "p1", "p2"])


func test_find_preview_and_details_type() -> void:
	var n := _note("n", "Shopping", "  milk, eggs and a very long list of other things \nbread")
	expect_eq(Win95DialogLogic.find_preview(n), Notes.preview(n, Win95DialogLogic.FIND_PREVIEW_CHARS))
	expect(Win95DialogLogic.find_preview(n).begins_with("milk, eggs"))
	expect_eq(Win95DialogLogic.find_preview({"name": "Calc", "path": "calc"}), "")
	expect_eq(Win95DialogLogic.item_type_label(n), "Sticky Note")
	expect_eq(Win95DialogLogic.item_type_label({"name": "Calc", "path": "calc"}), "Application")


# ------------------------------------------------------- dialog rules

func test_note_colors_follow_notes_color_choices() -> void:
	expect_eq(Win95DialogLogic.note_color_ids(), Notes.color_choices().map(func(c): return c.id))
	expect_eq(Win95DialogLogic.note_color_labels()[0], "Yellow")
	expect_eq(Win95DialogLogic.note_color_index("pink"), 1)
	expect_eq(Win95DialogLogic.note_color_index("plaid"), Win95DialogLogic.note_color_index(Notes.DEFAULT_COLOR))
	expect_eq(Win95DialogLogic.note_color_at(2), "blue")
	expect_eq(Win95DialogLogic.note_color_at(99), Notes.DEFAULT_COLOR)


func test_create_note_and_apply_note_properties() -> void:
	var s: Node = STORE_SCRIPT.new()
	s.groups = _groups()
	s.settings = Types.default_settings()
	expect_eq(Win95DialogLogic.create_note(s, "work", "   ", "x", "pink"), "", "a title is required")
	expect_eq(Win95DialogLogic.create_note(s, "", "T", "x", "pink"), "", "a folder is required")
	var id := Win95DialogLogic.create_note(s, "home", " Todo ", "a\r\nb", "green", 3)
	var it: Dictionary = s.find_item("home", id)
	expect(Notes.is_note(it))
	expect_eq([it.name, it.note, it.noteColor, it.launchGroup], ["Todo", "a\nb", "green", 3])
	expect(not Win95DialogLogic.apply_note_properties(s, "home", id, {"name": " ", "color": "blue"}))
	expect_eq(s.find_item("home", id).name, "Todo", "a blank title changes nothing")
	expect(Win95DialogLogic.apply_note_properties(s, "home", id, {"name": "Errands", "color": "blue", "launchGroup": 0, "icon": "documents"}))
	it = s.find_item("home", id)
	expect_eq([it.name, it.noteColor, it.launchGroup, it.icon, it.note], ["Errands", "blue", 0, "documents", "a\nb"])
	expect_eq(it.path, "", "no program fields appear")
	s.free()


func test_note_key_actions() -> void:
	expect_eq(Win95ShellInput.note_key_action("toggle-start"), "toggle-start")
	expect_eq(Win95ShellInput.note_key_action("cycle-window"), "cycle-window")
	expect_eq(Win95ShellInput.note_key_action("close-window"), "close-note")
	expect_eq(Win95ShellInput.note_key_action("system-menu"), "")
	expect_eq(Win95ShellInput.note_key_action("context-menu"), "note-menu", "Shift+F10 opens the note menu")
	expect_eq(Win95ShellInput.note_key_action(""), "")


# ------------------------------------------------------- batch progress rules

func test_batch_steps_count_across_groups_and_pause_inside_a_group() -> void:
	var buckets := [{"groupNumber": 1, "items": [{"id": "a"}, {"id": "b"}]}, {"groupNumber": 4, "items": [{"id": "c"}]}]
	var steps := Win95LaunchGroupLogic.batch_steps(buckets)
	expect_eq(steps.map(func(s): return s.item.id), ["a", "b", "c"])
	expect_eq(steps.map(func(s): return s.index), [0, 1, 2])
	expect_eq(steps.map(func(s): return s.total), [3, 3, 3])
	expect_eq(steps.map(func(s): return s.groupNumber), [1, 1, 4])
	expect_eq(steps.map(func(s): return s.pauseAfter), [true, false, false], "no pause between groups or after the last")
	var big := []
	for i in LaunchGroups.MAX_BATCH_ITEMS + 1:
		big.append({"id": "x%d" % i})
	var mixed := [{"groupNumber": 2, "items": big}, {"groupNumber": 3, "items": [{"id": "ok"}]}]
	expect_eq(Win95LaunchGroupLogic.batch_steps(mixed).map(func(s): return s.item.id), ["ok"])
	var refused := Win95LaunchGroupLogic.batch_refusals(mixed)
	expect_eq(refused.size(), 1)
	expect(not refused[0].success and String(refused[0].error).contains(str(LaunchGroups.MAX_BATCH_ITEMS)))


func test_launch_delay_is_clamped_like_launch_batch() -> void:
	expect_eq(Win95LaunchGroupLogic.clamp_delay(500), 500)
	expect_eq(Win95LaunchGroupLogic.clamp_delay(250.9), 250)
	expect_eq(Win95LaunchGroupLogic.clamp_delay(-4), 0)
	expect_eq(Win95LaunchGroupLogic.clamp_delay(LaunchGroups.MAX_LAUNCH_DELAY_MS + 1), LaunchGroups.MAX_LAUNCH_DELAY_MS)
	expect_eq(Win95LaunchGroupLogic.clamp_delay("500"), 0)
	expect_eq(Win95LaunchGroupLogic.clamp_delay(null), 0)


func test_progress_texts_and_blocks() -> void:
	expect_eq(Win95LaunchGroupLogic.progress_title(1, {"1": "Morning"}), "Launching Group 1: Morning")
	expect_eq(Win95LaunchGroupLogic.progress_title(2, {}), "Launching Group 2")
	expect_eq(Win95LaunchGroupLogic.progress_line({"name": "Notepad", "path": "x"}), "Starting Notepad...")
	expect_eq(Win95LaunchGroupLogic.progress_line(Notes.make_note("Shopping")), "Opening Shopping...")
	expect_eq(Win95LaunchGroupLogic.progress_count(2, 5), "3 of 5")
	expect_eq(Win95LaunchGroupLogic.progress_count(9, 5), "5 of 5")
	expect_eq(Win95ProgressBar.block_width(16), 8)
	# 300 px inside, 8 px blocks 2 px apart: 30 blocks
	expect_eq(Win95LaunchGroupLogic.progress_blocks(0, 5, 300, 8, 2), 0)
	expect_eq(Win95LaunchGroupLogic.progress_blocks(1, 5, 300, 8, 2), 6)
	expect_eq(Win95LaunchGroupLogic.progress_blocks(4, 5, 300, 8, 2), 24)
	expect_eq(Win95LaunchGroupLogic.progress_blocks(5, 5, 300, 8, 2), 30)
	expect_eq(Win95LaunchGroupLogic.progress_blocks(7, 5, 300, 8, 2), 30)
	expect_eq(Win95LaunchGroupLogic.progress_blocks(1, 0, 300, 8, 2), 0)


func test_members_list_includes_notes() -> void:
	var rows := Win95LaunchGroupLogic.member_rows(_groups(), 1)
	var note_row: Array = rows.filter(func(r): return r.itemId == "n1")
	expect_eq(note_row.size(), 1)
	expect(note_row[0].checked, "a note can be a member")


# ------------------------------------------------------------ hosting

func test_notes_layer_sits_between_the_desktop_and_the_taskbar() -> void:
	var saved := _use_scratch_store()
	var shell := await _mount()
	expect_eq(shell.note_layer(), shell.notes_layer)
	var order := [shell.desktop, shell.notes_layer, shell.taskbar, shell.start_menu, shell.dialog_layer, shell.popup_layer]
	for i in order.size() - 1:
		expect(order[i].get_index() < order[i + 1].get_index(), "layer %d below layer %d" % [i, i + 1])
	expect_eq(shell.notes_layer.size, shell.desktop.size, "notes stay above the taskbar")
	expect_eq(shell.notes_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var style := shell.note_style()
	expect_eq(style.font, RetroFont.instance(RetroFont.WIN95).font)
	expect_eq(style.font_size, 11)
	await _unmount(shell)
	_restore_store(saved)


func test_opening_a_note_from_a_folder_find_or_start_opens_its_window() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	var id := ProgramStore.add_note(gid, "Todo", "call mum", "pink")
	ProgramStore.update_settings({"minimizeOnUse": true})
	var shell := await _mount()
	shell.windows.open_group(gid)
	shell.launch_item(ProgramStore.find_item(gid, id))
	var notes := shell.open_notes()
	expect_eq(notes.size(), 1)
	expect_eq(notes[0].get_parent(), shell.notes_layer)
	expect_eq(notes[0].paper, Notes.COLORS.pink)
	expect_eq(shell.windows.active_window_id, Win95WindowStore.NOTE_ACTIVE, "the note is the active window")
	expect(not shell.desktop.window_for("group:" + gid).is_active())
	await _tree().process_frame
	expect(shell.note_has_focus(), "its text takes the keyboard")
	expect_eq(shell.focused_note(), notes[0])
	expect(_modals(shell).is_empty(), "no error box")
	notes[0].close()
	await _tree().process_frame
	expect_eq(shell.windows.active_window_id, "group:" + gid, "closing it gives the window its activation back")
	await _unmount(shell)
	_restore_store(saved)


func test_keys_typed_in_a_note_never_reach_the_windows_or_the_desktop() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	ProgramStore.add_item(gid, {"name": "Calc", "path": "/nonexistent/calc", "icon": "application", "workingDir": ""})
	var id := ProgramStore.add_note(gid, "Todo", "")
	var shell := await _mount()
	shell.desktop.selection = {"selected": ["my-computer"], "focused": "my-computer", "anchor": "my-computer"}
	var note := shell.open_note(id)
	await _tree().process_frame
	expect(shell.note_has_focus())
	for k in [KEY_ENTER, KEY_DELETE, KEY_A, KEY_DOWN, KEY_ESCAPE]:
		expect(not _key(shell, k), "key %d is left to the note" % k)
	expect(shell.windows.windows.is_empty(), "Enter did not open My Computer")
	expect_eq(ProgramStore.find_group(gid).items.size(), 2, "Delete removed nothing")
	expect(_key(shell, KEY_ESCAPE, {"ctrl": true}), "Ctrl+Esc still opens Start")
	expect(shell.input.start_menu_open)
	expect(_key(shell, KEY_ESCAPE), "an open menu still takes the keys")
	expect(not shell.input.start_menu_open)
	expect(_key(shell, KEY_F4, {"alt": true}), "Alt+F4 closes the note")
	await _tree().process_frame
	expect(not is_instance_valid(note) or note.is_queued_for_deletion())
	expect_eq(ProgramStore.find_item(gid, id).noteOpen, false)
	await _unmount(shell)
	_restore_store(saved)


func test_pointer_routing_around_notes() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	var id := ProgramStore.add_note(gid, "Todo", "x")
	var shell := await _mount()
	var note := shell.open_note(id)
	note.place(Rect2i(200, 100, 180, 140))
	await _tree().process_frame
	expect_eq(shell.note_at(Vector2(250, 150)), note)
	expect_eq(shell.note_at(Vector2(50, 50)), null)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	shell.windows.activate_desktop()
	expect(not shell.note_has_focus(), "activating the desktop takes the keyboard from the note")
	expect(not shell._route_note_press(mb, Vector2(250, 150)), "a left press goes on to the note itself")
	expect_eq(shell.windows.active_window_id, Win95WindowStore.NOTE_ACTIVE)
	expect_eq(shell.windows.active_note_id(), id)
	mb.position = Vector2(50, 60)  # in the note's text
	note._gui_input(mb)
	expect(shell.note_has_focus())
	expect(not shell._route_note_press(mb, Vector2(50, 300)), "a press elsewhere goes on to what is there")
	expect(not shell.note_has_focus(), "and takes the keyboard back from the note")
	mb.button_index = MOUSE_BUTTON_RIGHT
	expect(shell._route_note_press(mb, Vector2(250, 150)), "a right-click on the note's text opens its menu")
	var menus := shell.popup_layer.get_children().filter(func(c): return c is Win95Menu and not c.is_queued_for_deletion())
	expect_eq(menus.size(), 1)
	expect_eq(menus[0].items.map(func(i): return i.id), ["note-close", "note-properties", "sep", "note-delete"])
	expect_eq(menus[0].position, Vector2(250, 150), "at the pointer")
	menus[0].close()
	await _tree().process_frame
	mb.global_position = shell.global_position + Vector2(260, 104)
	note._gui_input(mb)  # the note's own request (its title strip) takes the same path
	menus = shell.popup_layer.get_children().filter(func(c): return c is Win95Menu and not c.is_queued_for_deletion())
	expect_eq(menus.size(), 1, "show_note_menu")
	expect_eq(menus[0].position, Vector2(260, 104))
	menus[0].close()
	# the Start menu and the desktop menu are drawn above the notes
	expect(shell.start_menu.get_index() > shell.notes_layer.get_index())
	expect(shell.popup_layer.get_index() > shell.notes_layer.get_index())
	await _unmount(shell)
	_restore_store(saved)


# ------------------------------------------------------ New Sticky Note

func test_every_new_item_menu_offers_a_sticky_note() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	var shell := await _mount()
	var ids := func(items: Array) -> Array: return items.map(func(i): return i.get("id", ""))
	var desk: Array = ids.call(shell.desktop._desktop_menu())
	expect(desk.find("new-note") == desk.find("new-shortcut") + 1, "desktop: after New Shortcut")
	shell.windows.open_group(gid)
	var w := shell.desktop.window_for("group:" + gid)
	var file: Array = ids.call(w._menu_items("file"))
	expect(file.find("new-note") == file.find("new") + 1, "File menu: after New Program")
	var ctx: Array = ids.call(w.folder_view._context_items(""))
	expect(ctx.find("new-note") == ctx.find("new-url") + 1, "folder background menu: after New URL")
	var labels: Array = w.folder_view._context_items("").map(func(i): return String(i.get("label", "")))
	expect_eq(Win95MenuState.mnemonic_index(labels, "t"), ctx.find("new-note"), "its access key is unique")
	shell.windows.open_my_computer()
	var mc: Array = ids.call(shell.desktop.window_for("my-computer")._menu_items("file"))
	expect(mc.has("new") and not mc.has("new-note"), "My Computer holds only folders, so it offers no note")
	await _unmount(shell)
	_restore_store(saved)


func test_new_sticky_note_dialog_creates_the_note_and_opens_it() -> void:
	var saved := _use_scratch_store()
	var g1 := ProgramStore.add_group("Desk")
	var g2 := ProgramStore.add_group("Kitchen")
	var shell := await _mount()
	var m := Win95DialogForms.open_new_note(shell, {"groupId": g1})
	expect_eq(m.title, "New Sticky Note")
	var title: Win95TextInput = _auto(m, "w95.new-note.title")
	var color: Win95Select = _auto(m, "w95.new-note.color")
	var group: Win95Select = _auto(m, "w95.new-note.group")
	var text: Win95TextArea = _auto(m, "w95.new-note.text")
	expect_eq(title.text, Win95DialogLogic.NOTE_DEFAULT_TITLE)
	expect_eq(color.options, Win95DialogLogic.note_color_labels())
	expect_eq(group.current_text(), "Desk")
	title.text = "Groceries"
	title.edit.text_changed.emit("Groceries")
	color.selected_index = 3
	group.selected_index = 1
	group.item_selected.emit(1)
	text.text = "milk\neggs"
	_button(m, "OK").click()
	await _tree().process_frame
	var items: Array = ProgramStore.find_group(g2).items
	expect_eq(items.size(), 1)
	expect(Notes.is_note(items[0]))
	expect_eq([items[0].name, items[0].note, items[0].noteColor], ["Groceries", "milk\neggs", "green"])
	expect(_modals(shell).is_empty(), "the dialog closed")
	expect_eq(shell.open_notes().map(func(n): return n.item_id), [items[0].id], "and the note is open")
	# a blank title keeps OK from creating anything
	var m2 := Win95DialogForms.open_new_note(shell, {"groupId": g1})
	var t2: Win95TextInput = _auto(m2, "w95.new-note.title")
	t2.text = "  "
	t2.edit.text_changed.emit("  ")
	expect(_button(m2, "OK").disabled)
	m2.close()
	await _unmount(shell)
	_restore_store(saved)


func test_new_url_dialog_uses_the_group_picked_in_it() -> void:
	# The New Sticky Note dialog is built like New Internet Shortcut; both kept the first folder even
	# when another was picked (a lambda assigned to a captured local).
	var saved := _use_scratch_store()
	ProgramStore.add_group("Desk")
	var g2 := ProgramStore.add_group("Web")
	var shell := await _mount()
	Win95Dialogs.open_new_url(shell, {})
	var m: Win95Modal = _modals(shell)[0]
	var group: Win95Select = m.find_children("*", "Win95Select", true, false)[0]
	group.selected_index = 1
	group.item_selected.emit(1)
	_button(m, "OK").click()
	expect_eq(ProgramStore.find_group(g2).items.size(), 1)
	await _unmount(shell)
	_restore_store(saved)


func test_enter_in_the_note_text_is_a_new_line_not_ok() -> void:
	var saved := _use_scratch_store()
	var g1 := ProgramStore.add_group("Desk")
	var shell := await _mount()
	var m := Win95DialogForms.open_new_note(shell, {"groupId": g1})
	var text: Win95TextArea = _auto(m, "w95.new-note.text")
	text.focus_edit()
	await _tree().process_frame
	expect(not _key(shell, KEY_ENTER), "Enter goes to the text field")
	expect_eq(ProgramStore.find_group(g1).items.size(), 0)
	expect(_key(shell, KEY_TAB), "Tab still moves focus")
	m.close()
	await _unmount(shell)
	_restore_store(saved)


func test_wizard_offers_a_sticky_note_instead() -> void:
	var saved := _use_scratch_store()
	var g1 := ProgramStore.add_group("Desk")
	var shell := await _mount()
	Win95DialogForms.open_wizard(shell, {"groupId": g1})
	var wizard: Win95Modal = _modals(shell)[0]
	var sn: Win95Button = _auto(wizard, "w95.wizard.button:sticky-note")
	expect(sn != null)
	expect_eq(sn.access_key(), "s")
	sn.click()
	await _tree().process_frame
	var titles := _modals(shell).map(func(x): return x.title)
	expect_eq(titles, ["New Sticky Note"])
	await _unmount(shell)
	_restore_store(saved)


# ------------------------------------------------------------ Properties

func test_note_properties_sheet_has_only_note_fields_and_saves() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	var id := ProgramStore.add_note(gid, "Todo", "keep me")
	var shell := await _mount()
	Win95Dialogs.open_properties(shell, {"kind": "item", "groupId": gid, "item": ProgramStore.find_item(gid, id)})
	var m: Win95Modal = _modals(shell)[0]
	expect_eq(m.title, "Todo Properties")
	expect_eq(m.find_children("*", "Win95TextInput", true, false).size(), 1, "only the title is typed: no command line or working directory")
	expect_eq(m.find_children("*", "Win95TabStrip", true, false)[0].tabs.map(func(t): return t.id), ["general"])
	var title: Win95TextInput = _auto(m, "w95.note-props.title")
	var color: Win95Select = _auto(m, "w95.note-props.color")
	var lg: Win95Select = _auto(m, "w95.note-props.launchGroup")
	title.text = "Errands"
	color.selected_index = Win95DialogLogic.note_color_index("purple")
	lg.selected_index = 2
	_auto(m, "w95.note-props.change-icon").click()
	var picker: Win95Modal = _modals(shell)[1]
	expect_eq(picker.title, "Change Icon")
	var grid: Win95IconGrid = _auto(picker, "w95.change-icon.list")
	expect_eq(grid.selected_icon(), "note", "the current icon is selected")
	grid.select_icon("documents")
	_button(picker, "OK").click()
	expect_eq((_auto(m, "w95.note-props.icon") as Win95IconBox).icon, "documents")
	_button(m, "OK").click()
	var it := ProgramStore.find_item(gid, id)
	expect_eq([it.name, it.noteColor, it.launchGroup, it.icon, it.note], ["Errands", "purple", 2, "documents", "keep me"])
	await _unmount(shell)
	_restore_store(saved)


# ------------------------------------------------------- batch progress

func test_batch_launch_shows_progress_opens_notes_and_reports_failures() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	ProgramStore.add_item(gid, {"name": "Missing", "path": "/nonexistent/program", "icon": "application", "workingDir": "", "launchGroup": 1})
	var id := ProgramStore.add_note(gid, "Todo", "x")
	ProgramStore.update_item(gid, id, {"launchGroup": 1})
	ProgramStore.update_settings({"launchDelay": 0, "launchGroupNames": {"1": "Morning"}})
	var shell := await _mount()
	shell.launch_group_row("launch:1")
	expect(shell.is_launching_groups())
	var p := shell.launch_progress
	expect(p != null and p.is_open())
	expect_eq(p.modal.title, "Launching Group 1: Morning")
	expect_eq(p.line.text, "Starting Missing...")
	expect_eq(p.count.text, "1 of 2")
	expect_eq(p.cancel_button.label, "Cancel")
	while shell.is_launching_groups():
		await _tree().process_frame
	await _tree().process_frame
	expect(not p.is_open(), "the progress window closes when the batch ends")
	expect_eq(shell.open_notes().map(func(n): return n.item_id), [id], "the note opened")
	expect(not shell.note_has_focus(), "without taking the keyboard")
	var boxes := _modals(shell)
	expect_eq(boxes.size(), 1, "then the failure box")
	expect_eq(boxes[0].title, "Launch Group 1: Morning")
	await _unmount(shell)
	_restore_store(saved)


func test_cancel_stops_the_items_not_started_yet() -> void:
	var saved := _use_scratch_store()
	var gid := ProgramStore.add_group("Desk")
	var ids := []
	for i in 3:
		var id := ProgramStore.add_note(gid, "Note %d" % i, "")
		ProgramStore.update_item(gid, id, {"launchGroup": 2})
		ids.append(id)
	ProgramStore.update_settings({"launchDelay": 400})
	var shell := await _mount()
	shell.launch_group_row("launch:2")
	var p := shell.launch_progress
	while shell.open_notes().size() < 1:
		await _tree().process_frame
	expect_eq(p.count.text, "1 of 3")
	_button(p.modal, "Cancel").click()
	expect(p.cancelled)
	expect(p.cancel_button.disabled)
	var t0 := Time.get_ticks_msec()
	while shell.is_launching_groups():
		await _tree().process_frame
	expect(Time.get_ticks_msec() - t0 < 300, "Cancel cuts the pause short")
	expect_eq(shell.open_notes().map(func(n): return n.item_id), [ids[0]], "only the first item started")
	expect(_modals(shell).is_empty(), "nothing failed, so no box")
	await _unmount(shell)
	_restore_store(saved)
