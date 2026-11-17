extends TestCase
## The WfW sticky note right-click menu (Close, Properties..., Delete...): its items, where it opens,
## how it looks up and acts, the delete confirmation, and how it closes.

const SHELL_SCRIPT := preload("res://src/shells/win31/win31_shell.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w31-note-menu-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _press(button: MouseButton, at: Vector2, pressed: bool = true) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	return ev


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _push(shell: Control, ev: InputEvent) -> void:
	shell.get_viewport().push_input(ev, true)
	await _tree().process_frame


## A note open at (100, 100) 180x140 in a fresh shell: [shell, group id, note id].
func _shell_with_note(title: String = "Todo") -> Array:
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, title, "hi", "yellow")
	ProgramStore.update_note_quietly(id, {"noteBounds": {"x": 100, "y": 100, "width": 180, "height": 140}})
	var shell := _mount_shell()
	shell.open_note(id, false)
	await _tree().process_frame
	return [shell, g, id]


# ------------------------------------------------------------------ rules

func test_menu_items_and_mnemonics() -> void:
	var items := Win31Commands.note_menu_items()
	var labels := items.map(func(it): return String(it.get("label", "-")))
	expect_eq(labels, ["&Close", "&Properties...", "-", "&Delete..."])
	expect(items[2].get("separator", false))
	expect_eq(Win31Commands.mnemonic_match(items, "c"), 0)
	expect_eq(Win31Commands.mnemonic_match(items, "p"), 1)
	expect_eq(Win31Commands.mnemonic_match(items, "d"), 3)
	expect_eq(Win31Commands.enabled_indexes(items), [0, 1, 3], "the separator is skipped by the arrows")


func test_popup_origin_stays_inside_the_area() -> void:
	var area := Vector2(640, 480)
	var sz := Vector2(120, 63)
	expect_eq(Win31Commands.popup_origin(Vector2(100.6, 50.2), sz, area), Vector2(100, 50), "at the pointer")
	expect_eq(Win31Commands.popup_origin(Vector2(600, 50), sz, area), Vector2(520, 50), "moved left at the right edge")
	expect_eq(Win31Commands.popup_origin(Vector2(100, 460), sz, area), Vector2(100, 397), "flipped above the pointer")
	expect_eq(Win31Commands.popup_origin(Vector2(10, 40), Vector2(120, 300), Vector2(640, 200)), Vector2(10, 0), "too tall: top")
	expect_eq(Win31Commands.popup_origin(Vector2(5, 5), Vector2(700, 50), area), Vector2(0, 5), "too wide: left edge")


func test_delete_prompt_names_the_kind() -> void:
	var note := Notes.make_note("Q&A", "", "yellow")
	var p := W31DialogLogic.delete_item_prompt(note)
	expect_eq(p, {"title": "Delete Sticky Note", "message": "Delete the sticky note “Q&A”?"})
	var prog := W31DialogLogic.delete_item_prompt({"name": "Calc", "path": "calc.exe"})
	expect_eq(prog.title, "Delete Program Item")
	expect_eq(prog.message, "Delete the program item “Calc”?")
	var lines := W31Dialog.paragraph_lines(p.message, 400)
	expect_eq(lines[0], "Delete the sticky note “Q&A”?", "the message box shows the & as written")


# ---------------------------------------------------------------- the shell

func test_right_click_opens_the_menu_above_the_notes() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	await _push(shell, _press(MOUSE_BUTTON_RIGHT, Vector2(150, 160)))
	await _push(shell, _press(MOUSE_BUTTON_RIGHT, Vector2(150, 160), false))
	expect(shell.is_note_menu_open(), "right-click on the note's text opens the menu")
	if shell.is_note_menu_open():
		var m: Win31PopupMenu = shell._note_menu
		expect_eq(m.get_parent(), shell.note_menus)
		expect_eq(m.position, Vector2(150, 160), "at the pointer")
		expect(shell.note_menus.z_index > shell.notes.z_index, "drawn above the notes")
		expect(shell.get_children().find(shell.note_menus) > shell.get_children().find(shell.notes))
		expect(shell.get_children().find(shell.note_menus) < shell.get_children().find(shell.dialogs), "below dialogs")
		expect_eq(m.highlighted, 0, "Close is highlighted, like a WfW menu")
		var a := Automation.new(_tree())
		expect(a.has("wfw.note-menu"))
		expect(a.has("wfw.popup-item:Properties..."))
		expect(m.size.x >= Win31Shell.NOTE_MENU_W)
	shell.free()
	_restore_store(saved)


func test_right_click_near_the_corner_keeps_the_menu_on_screen() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	ProgramStore.update_note_quietly(r[2], {"noteBounds": {"x": 500, "y": 380, "width": 140, "height": 100}})
	shell.close_note(r[2])
	await _tree().process_frame
	var n := shell.open_note(r[2], false)
	await _tree().process_frame
	shell.show_note_menu(r[2], n.global_position + Vector2(130, 90))
	var m: Win31PopupMenu = shell._note_menu
	expect(m != null)
	if m:
		expect(m.get_rect().end.x <= 640 and m.get_rect().end.y <= 480, str(m.get_rect()))
	shell.free()
	_restore_store(saved)


func test_close_and_escape() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	await _push(shell, _key(KEY_ESCAPE))
	expect(not shell.is_note_menu_open(), "Esc closes the menu")
	expect_eq(shell.open_notes().size(), 1, "and leaves the note open")
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	await _push(shell, _key(KEY_C))
	await _tree().process_frame
	expect(not shell.is_note_menu_open())
	expect_eq(shell.open_notes().size(), 0, "C (Close) closes the note window")
	expect(not ProgramStore.locate_item(r[2]).is_empty(), "closing keeps the note")
	expect_eq(ProgramStore.locate_item(r[2]).item.noteOpen, false)
	shell.free()
	_restore_store(saved)


func test_click_outside_closes_and_is_used_up() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	await _push(shell, _press(MOUSE_BUTTON_LEFT, Vector2(400, 300)))
	await _push(shell, _press(MOUSE_BUTTON_LEFT, Vector2(400, 300), false))
	expect(not shell.is_note_menu_open(), "a click elsewhere closes the menu")
	expect_eq(UIState.active_dialog, "")
	shell.free()
	_restore_store(saved)


func test_properties_by_keyboard_and_by_click() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	await _push(shell, _key(KEY_DOWN))
	await _push(shell, _key(KEY_ENTER))
	await _tree().process_frame
	expect_eq(UIState.active_dialog, "itemProperties", "Down, Enter: Properties...")
	expect(shell.dialogs.current_dialog() is W31NoteDialogs.NoteProperties)
	UIState.close_dialog()
	await _tree().process_frame
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	var a := Automation.new(_tree())
	var at := a.center("wfw.popup-item:Properties...")
	await _push(shell, _press(MOUSE_BUTTON_LEFT, at))
	await _push(shell, _press(MOUSE_BUTTON_LEFT, at, false))
	await _tree().process_frame
	expect_eq(UIState.active_dialog, "itemProperties", "a click on Properties... works too")
	expect(not shell.is_note_menu_open())
	shell.free()
	_restore_store(saved)


func test_delete_confirms_and_the_window_closes() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note("Q&A")
	var shell: Win31Shell = r[0]
	shell.show_note_menu(r[2], Vector2(150, 160))
	await _tree().process_frame
	await _push(shell, _key(KEY_D))
	await _tree().process_frame
	expect_eq(UIState.active_dialog, "confirm")
	var dlg := shell.dialogs.current_dialog()
	expect(dlg is W31MessageDialogs.Confirm)
	expect_eq(dlg.title, "Delete Sticky Note")
	expect_eq(dlg.body.texts[0].text, "Delete the sticky note “Q&A”?")
	expect(not ProgramStore.locate_item(r[2]).is_empty(), "nothing is deleted before Yes")
	dlg._on_yes()
	await _tree().process_frame
	await _tree().process_frame
	expect(ProgramStore.locate_item(r[2]).is_empty(), "Yes deletes the note")
	expect_eq(shell.open_notes().size(), 0, "its window closes by itself")
	shell.free()
	_restore_store(saved)


func test_file_delete_on_a_note_says_sticky_note() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	UIState.set_win31_selection({"kind": "item", "groupId": r[1], "itemId": r[2]})
	shell.run_command("delete")
	await _tree().process_frame
	expect_eq(shell.dialogs.current_dialog().title, "Delete Sticky Note")
	shell.free()
	_restore_store(saved)


func test_a_dialog_closes_the_menu_and_no_menu_opens_under_one() -> void:
	var saved := _use_scratch_store()
	var r: Array = await _shell_with_note()
	var shell: Win31Shell = r[0]
	shell.show_note_menu(r[2], Vector2(150, 160))
	UIState.open_dialog("about")
	await _tree().process_frame
	expect(not shell.is_note_menu_open(), "a dialog closes the menu")
	shell.show_note_menu(r[2], Vector2(150, 160))
	expect(not shell.is_note_menu_open(), "no menu while a dialog is open")
	UIState.close_dialog()
	shell.show_note_menu("nope", Vector2(150, 160))
	expect(not shell.is_note_menu_open(), "no menu for an unknown note")
	shell.free()
	_restore_store(saved)
