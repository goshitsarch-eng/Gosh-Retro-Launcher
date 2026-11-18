extends TestCase
## The Be shell's sticky note menu (right-click on an open note: Close, Get Info, Color ▸, Move to Trash…), the
## Deskbar logo's right-click menu, and the launch group column of List View and Find: the pure rows and texts
## (BeMenuModel, BeDialogLogic) and the real BeShell driven with injected clicks.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")
const SHELL_SCRIPT := preload("res://src/shells/be/be_shell.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "be"
	s.settings["saveSettingsOnExit"] = false
	return s


func _labels(rows: Array) -> Array:
	return rows.map(func(r): return "-" if r.get("sep", false) else r.label)


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-be-note-menu-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _use_scratch_store() -> Dictionary:
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence, "dark": BeTheme.dark}
	ProgramStore.init_store(_tmp())
	ProgramStore.update_settings({"shell": "be", "theme": "light"})
	return saved


func _restore_store(saved: Dictionary) -> void:
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	BeTheme.dark = saved.dark


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _mount() -> BeShell:
	var shell: BeShell = SHELL_SCRIPT.new()
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.on_activate()
	return shell


func _frames(n: int = 3) -> void:
	for i in n:
		await _tree().process_frame


func _popup(shell: BeShell) -> BePopup:
	for c in shell.menu_layer.get_children():
		if c is BePopup and not c.is_queued_for_deletion():
			return c
	return null


func _dialog(shell: BeShell, auto_id: String) -> BeDialog:
	for c in shell.dialog_layer.get_children():
		if c is BeDialog and String(c.get_meta("auto_id", "")) == auto_id and not c.is_queued_for_deletion():
			return c
	return null


# ------------------------------------------------------------------ logic

func test_note_menu_rows_and_colour_marks() -> void:
	var m := BeMenuModel.note_menu("g1", "n1", "blue")
	expect_eq(_labels(m), ["Close", "Get Info", "Color", "-", "Move to Trash…"])
	expect_eq(m[0].action, "note.close")
	expect_eq(m[1].action, "item.info", "Get Info is the note's own Get Info")
	expect_eq(m[4].action, "note.trash")
	for i in [0, 1, 4]:
		expect_eq(m[i].args, {"gid": "g1", "iid": "n1"})
	var kids: Array = m[2].children
	expect_eq(_labels(kids), Notes.color_choices().map(func(c): return c.label), "the six paper colours in order")
	expect_eq(kids.size(), 6)
	expect_eq(kids.filter(func(k): return k.get("dot", false)).map(func(k): return k.args.color), ["blue"], "one mark, on the current colour")
	for k in kids:
		expect_eq(k.swatch, Notes.COLORS[k.args.color], "each row shows a sample of its paper")
		expect_eq(k.action, "note.color")
		expect_eq([k.args.gid, k.args.iid], ["g1", "n1"])
	var odd: Array = BeMenuModel.note_menu("g", "n", "plaid")[2].children
	expect_eq(odd.filter(func(k): return k.get("dot", false)).map(func(k): return k.args.color), [Notes.DEFAULT_COLOR],
		"an unknown stored colour shows as the default paper")


func test_set_note_color_and_trash_prompt() -> void:
	var s := _store()
	var g: String = s.add_group("Work")
	var n: String = s.add_item(g, Notes.make_note("Shopping", "milk", "yellow"))
	var p: String = s.add_item(g, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""})
	expect(BeDialogLogic.set_note_color(s, g, n, "green"))
	expect_eq(s.find_item(g, n).noteColor, "green")
	expect(not BeDialogLogic.set_note_color(s, g, n, "plaid"), "not a paper colour")
	expect_eq(s.find_item(g, n).noteColor, "green")
	expect(not BeDialogLogic.set_note_color(s, g, p, "pink"), "programs have no paper")
	expect(not s.find_item(g, p).has("noteColor"))
	expect(not BeDialogLogic.set_note_color(s, g, "missing", "pink"))
	expect_eq(BeDialogLogic.note_trash_lines(s.find_item(g, n))[0], "Delete the sticky note “Shopping”?")
	s.free()


func test_launch_group_cells_and_headings() -> void:
	expect_eq(BeDialogLogic.launch_group_cell({"launchGroup": 2}, {"2": "Morning"}), "Group 2: Morning")
	expect_eq(BeDialogLogic.launch_group_cell({"launchGroup": 3}, {}), "Group 3")
	expect_eq(BeDialogLogic.launch_group_cell({}), "—")
	expect_eq(BeDialogLogic.details_headings(false), ["Name", "Command", "Launch Group"], "no more \"Batch\"")
	expect_eq(BeDialogLogic.details_headings(true), ["Name", "Size", "Type"])
	expect_eq(BeFindView.HEADINGS, ["Name", "Group", "Launch Group", "Command"])
	expect_eq(BeDialogLogic.FIND_QUERY_LABEL, "Name or text contains")
	# a long launch group name is cut with an ellipsis to its List View column
	var cols := BeGeometry.details_columns(520.0)
	var clipped := BeFont.clip(BeDialogLogic.launch_group_cell({"launchGroup": 2}, {"2": "Morning routine and coffee"}),
		float(cols[5]) - 10 - BeGeometry.SCROLLBAR - 4)
	expect(clipped.begins_with("Group 2") and clipped.ends_with("…"), clipped)


# ------------------------------------------------------------- the real shell

func test_notes_at_the_main_ui_size_keep_a_tidy_strip() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "call", "yellow")
	var shell := _mount()
	await _frames()
	var n := shell.open_note(id, false)
	await _frames()
	expect_eq(n.font_size, BeGeometry.FONT)
	expect(n.title_h >= BeGeometry.LINE, "the strip fits the 15 px title")
	var auto := Automation.new(_tree())
	var box := auto.find_rect("note.close:" + id)
	var strip_top := n.global_position.y
	var above := box.position.y - strip_top
	var below := strip_top + n.title_h - box.end.y
	expect(absf(above - below) <= 1.0, "the close box is centred in the taller strip (%s / %s)" % [above, below])
	expect(box.size.x > StickyNote.CLOSE, "and grows with it")
	expect_eq(auto.find_rect("note.text:" + id).position.x - n.global_position.x, float(BeShell.NOTE_INSET), "the text clears the edge")
	n.close()
	shell.free()
	# a small-font note (the other desktops) keeps the 7 px box at the top left and the default text inset
	var small := StickyNote.new("x", {"font": BeFont.font(), "font_size": 11})
	expect_eq(small._close_rect(), Rect2(4, 3, StickyNote.CLOSE, StickyNote.CLOSE))
	expect_eq(small.text_inset, StickyNote.TEXT_MARGIN)
	small.free()
	_restore_store(saved)


func test_note_menu_opens_at_the_click_and_its_rows_work() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Shopping", "milk", "yellow")
	var shell := _mount()
	await _frames()
	var note := shell.open_note(id, false)
	await _frames()
	var auto := Automation.new(_tree())
	var at := auto.center("note.text:" + id).floor()
	await auto.rclick(at)
	await _frames()
	var p := _popup(shell)
	expect(p != null, "a Be popup menu opens")
	expect_eq(_labels(p.rows), ["Close", "Get Info", "Color", "-", "Move to Trash…"])
	expect_eq(auto.find_rect("be.popup").position, at, "at the click")
	# Color ▸ Green
	await auto.click_id("be.popup-item:Color")
	await _frames()
	expect(auto.has("be.popup-item:Green"), "the Color submenu is open")
	await auto.click_id("be.popup-item:Green")
	await _frames()
	expect_eq(ProgramStore.locate_item(id).item.noteColor, "green")
	expect_eq(note.paper, Notes.COLORS.green, "the open window repaints")
	expect(_popup(shell) == null)
	# the next menu marks Green
	await auto.rclick(at)
	await _frames()
	var kids: Array = _popup(shell).rows[2].children
	expect_eq(kids.filter(func(k): return k.get("dot", false)).map(func(k): return k.label), ["Green"])
	# Get Info: the note's own info dialog
	await auto.click_id("be.popup-item:Get Info")
	await _frames()
	expect(_dialog(shell, "be.dialog.item-info") != null, "Get Info opens")
	_dialog(shell, "be.dialog.item-info").close()
	await _frames()
	# Move to Trash… asks; Cancel keeps the note
	await auto.rclick(at)
	await _frames()
	await auto.click_id("be.popup-item:Move to Trash…")
	await _frames()
	var confirm := _dialog(shell, "be.dialog.note-trash")
	expect(confirm != null, "Move to Trash… asks first")
	await auto.click_id("be.dialog.button:Cancel")
	await _frames()
	expect(not ProgramStore.locate_item(id).is_empty(), "Cancel keeps the note")
	expect(shell.note_window(id) != null)
	# Delete removes it and its window
	await auto.rclick(at)
	await _frames()
	await auto.click_id("be.popup-item:Move to Trash…")
	await _frames()
	await auto.click_id("be.dialog.button:Delete")
	await _frames()
	expect(ProgramStore.locate_item(id).is_empty(), "the note is deleted")
	expect(shell.note_window(id) == null, "its window closes")
	shell.free()
	_restore_store(saved)


func test_note_menu_close_keeps_the_text() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "a", "pink")
	var shell := _mount()
	await _frames()
	var note := shell.open_note(id, false)
	await _frames()
	note.set_text_for_test("a and b")
	var auto := Automation.new(_tree())
	await auto.rclick(auto.center("note.title:" + id).floor())
	await _frames()
	await auto.click_id("be.popup-item:Close")
	await _frames()
	expect(shell.note_window(id) == null, "Close closes the window")
	var it: Dictionary = ProgramStore.locate_item(id).item
	expect_eq(it.note, "a and b", "typed text is saved")
	expect_eq(it.get("noteOpen", false), false)
	shell.free()
	_restore_store(saved)


func test_logo_right_click_menu_opens_launch_groups() -> void:
	var saved := _use_scratch_store()
	ProgramStore.add_group("Desk")
	var shell := _mount()
	await _frames()
	var auto := Automation.new(_tree())
	await auto.rclick_id("be.deskbar.logo")
	await _frames()
	var p := _popup(shell)
	expect(p != null)
	expect_eq(_labels(p.rows), _labels(BeMenuModel.deskbar_context_menu()))
	await auto.click_id("be.popup-item:Launch Groups…")
	await _frames()
	expect(_dialog(shell, BeLaunchGroups.AUTO_ID) != null, "the Launch Groups manager opens")
	shell.free()
	_restore_store(saved)


func test_find_shows_launch_groups_and_matches_note_text() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var prog: String = ProgramStore.add_item(g, {"name": "Coffee", "path": "/usr/bin/true", "icon": "default", "workingDir": ""})
	ProgramStore.update_item(g, prog, {"launchGroup": 2})
	ProgramStore.set_launch_group_name(2, "Morning")
	ProgramStore.add_note(g, "Shopping", "buy coffee beans", "yellow")
	var shell := _mount()
	await _frames()
	shell.open_find()
	await _frames()
	var w := shell.desktop.window_for(BeWindowStore.FIND)
	var fv: BeFindView = w.find_view
	fv.query.text = "coffee"
	shell.find_state.q = "coffee"
	fv.run()
	await _frames()
	expect_eq(fv.results.map(func(r): return r.item.name), ["Coffee", "Shopping"], "the note matches by its text")
	expect_eq(BeDialogLogic.launch_group_cell(fv.results[0].item, ProgramStore.launch_group_names()), "Group 2: Morning")
	expect_eq(fv.title_text(), "Find: “coffee” in names and notes")
	var cols := fv._columns()
	expect_eq(cols.size(), 8, "four columns")
	shell.free()
	_restore_store(saved)
