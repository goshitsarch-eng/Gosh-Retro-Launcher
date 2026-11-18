extends TestCase
## Sticky notes in the Be shell: the New Note / Get Info / Find / List View / launch group logic
## (BeDialogLogic, BeMenuModel, BeIconCatalog), and the real BeShell hosting note windows above its folder
## windows and below its Deskbar, menus and dialogs, with clicks, drags and Enter reaching the right place.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")
const SHELL_SCRIPT := preload("res://src/shells/be/be_shell.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "be"
	s.settings["saveSettingsOnExit"] = false
	return s


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-be-notes-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Points the ProgramStore autoload at a scratch folder; returns the previous state to restore.
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


# ------------------------------------------------------------------ logic

func test_new_note_goes_into_the_chosen_folder() -> void:
	var s := _store()
	var a: String = s.add_group("Work")
	var b: String = s.add_group("Play")
	expect_eq(BeDialogLogic.note_group_for("g:" + b, "", s.groups), b, "the folder whose menu was used")
	expect_eq(BeDialogLogic.note_group_for("", "g:" + b, s.groups), b, "else the active folder window")
	expect_eq(BeDialogLogic.note_group_for("computer", "find", s.groups), a, "else the first folder")
	expect_eq(BeDialogLogic.note_group_for("g:gone", "", s.groups), a)
	expect_eq(BeDialogLogic.note_group_for("", "", []), "")
	var id := BeDialogLogic.new_note(s, b, "  Groceries ", "milk\r\neggs", "pink")
	var it: Dictionary = s.find_item(b, id)
	expect(Notes.is_note(it))
	expect_eq([it.name, it.note, it.noteColor, it.icon, it.path], ["Groceries", "milk\neggs", "pink", "note", ""])
	expect_eq(s.find_item(b, BeDialogLogic.new_note(s, b, "", "", "plaid")).name, "Note", "blank title")
	expect_eq(s.find_item(b, BeDialogLogic.new_note(s, b, "x", "", "plaid")).noteColor, Notes.DEFAULT_COLOR)
	expect_eq(BeDialogLogic.new_note(s, "missing", "x", "", "yellow"), "")
	expect_eq(BeDialogLogic.new_note(s, "", "x", "", "yellow"), "")
	var opts := BeDialogLogic.note_color_options()
	expect_eq(opts.size(), Notes.COLORS.size())
	expect_eq(opts[0], ["yellow", "Yellow"])
	expect_eq(opts.map(func(o): return o[0]), Notes.color_choices().map(func(c): return c.id))
	s.free()


func test_note_get_info_changes_only_note_fields() -> void:
	var s := _store()
	var a: String = s.add_group("Work")
	var b: String = s.add_group("Play")
	var id: String = s.add_item(a, Notes.make_note("Todo", "call", "yellow"))
	var f := BeDialogLogic.info_fields(s.find_item(a, id), a)
	expect(f.isNote)
	expect_eq(f.noteColor, "yellow")
	expect_eq(f.icon, "note")
	var r := BeDialogLogic.apply_note_info(s, a, id, {"name": " Today ", "noteColor": "blue", "launchGroup": 3, "icon": "readme", "groupId": a})
	expect_eq(r, {"ok": true, "groupId": a})
	var it: Dictionary = s.find_item(a, id)
	expect_eq([it.name, it.noteColor, it.launchGroup, it.icon, it.note, it.path], ["Today", "blue", 3, "readme", "call", ""])
	for k in ["arguments", "environment", "runMode", "shortcutKey", "workingDir"]:
		expect(not it.has(k) or String(it[k]) == "", "no program field " + k)
	BeDialogLogic.apply_note_info(s, a, id, {"name": "  ", "noteColor": "plaid", "launchGroup": 99})
	it = s.find_item(a, id)
	expect_eq([it.name, it.noteColor, it.launchGroup], ["Today", Notes.DEFAULT_COLOR, 8], "blank title kept, bad colour reset, group clamped")
	var moved := BeDialogLogic.apply_note_info(s, a, id, {"name": "Today", "groupId": b})
	expect_eq(moved, {"ok": true, "groupId": b})
	expect(not s.find_item(b, id).is_empty())
	var prog: String = s.add_item(a, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""})
	expect_eq(BeDialogLogic.apply_note_info(s, a, prog, {"name": "x"}).ok, false, "programs keep using apply_item_info")
	expect(not BeDialogLogic.info_fields(s.find_item(a, prog), a).isNote)
	s.free()


func test_kind_list_view_and_duplicate() -> void:
	var s := _store()
	var a: String = s.add_group("Work")
	var n: String = s.add_item(a, Notes.make_note("Todo", "\n first line \nsecond", "green"))
	s.update_item(a, n, {"launchGroup": 2, "noteOpen": true})
	var e: String = s.add_item(a, Notes.make_note("Empty"))
	s.add_item(a, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""})
	var note: Dictionary = s.find_item(a, n)
	expect_eq(BeDialogLogic.kind_of(note), "Sticky note")
	expect_eq(BeDialogLogic.command_text(note), "Sticky note: first line")
	expect_eq(BeDialogLogic.command_text(s.find_item(a, e)), "Sticky note")
	expect_eq(BeDialogLogic.command_text({"path": "calc.exe"}), "calc.exe")
	var rows := BeDialogLogic.entries_for("g:" + a, s.groups, {"2": "Evening"})
	expect_eq(rows.map(func(r): return r.c2), ["Sticky note: first line", "Sticky note", "calc.exe"])
	expect_eq(rows.map(func(r): return r.c3), ["Group 2: Evening", "—", "—"])
	expect_eq(rows.map(func(r): return r.is_note), [true, true, false])
	expect_eq(rows[0].icon, "note")
	var copy := BeDialogLogic.duplicate_item(s, a, n)
	var c: Dictionary = s.find_item(a, copy)
	expect(Notes.is_note(c))
	expect_eq([c.name, c.note, c.noteColor], ["Todo copy", note.note, "green"])
	expect(not c.has("noteOpen"), "a duplicated note starts closed")
	s.free()


func test_find_matches_notes_by_title_and_text() -> void:
	var s := _store()
	var a: String = s.add_group("Work")
	var b: String = s.add_group("Play")
	s.add_item(a, {"name": "Eggs Timer", "path": "C:\\timer.exe", "icon": "default", "workingDir": ""})
	s.add_item(a, {"name": "Recipes", "path": "https://eggs.example", "icon": "url", "workingDir": ""})
	s.add_item(b, Notes.make_note("Shopping", "milk\nEGGS\nbread", "pink"))
	s.add_item(b, Notes.make_note("Scores", "solitaire", "blue"))
	var names := func(res: Array) -> Array: return res.map(func(r): return r.item.name)
	expect_eq(names.call(BeDialogLogic.find(s.groups, "eggs", "all", "all", "")), ["Eggs Timer", "Shopping"],
		"a note matches by its text, a program only by its name")
	expect_eq(names.call(BeDialogLogic.find(s.groups, "scor", "all", "all", "")), ["Scores"], "and a note by its title")
	expect_eq(names.call(BeDialogLogic.find(s.groups, "", "all", "note", "")), ["Shopping", "Scores"])
	expect_eq(names.call(BeDialogLogic.find(s.groups, "eggs", "all", "note", "")), ["Shopping"])
	expect_eq(names.call(BeDialogLogic.find(s.groups, "", "all", "app", "")), ["Eggs Timer"], "notes are not applications")
	expect_eq(names.call(BeDialogLogic.find(s.groups, "", "all", "url", "")), ["Recipes"])
	expect_eq(names.call(BeDialogLogic.find(s.groups, "", "all", "all", "bread")), ["Shopping"], "text filter reads note text")
	expect_eq(names.call(BeDialogLogic.find(s.groups, "", a, "note", "")), [], "group filter")
	expect(BeFindView.TYPES.has(["note", "Sticky notes"]))
	s.free()


func test_launch_group_members_include_notes() -> void:
	var s := _store()
	var a: String = s.add_group("Work")
	var p: String = s.add_item(a, {"name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": "", "launchGroup": 1})
	var n: String = s.add_item(a, Notes.make_note("Todo", "x", "yellow"))
	var rows := BeDialogLogic.member_rows(s.groups, {}, 1)
	expect_eq(rows.map(func(r): return r.id), ["%s:%s" % [a, p], "%s:%s" % [a, n]])
	expect_eq(rows[1].sub, "Work, sticky note")
	expect_eq(rows[1].icon, "note")
	s.set_launch_group_members(1, ["%s:%s" % [a, p], "%s:%s" % [a, n]])
	var buckets := LaunchGroups.collect_launch_groups(s.groups)
	expect_eq(buckets[0].items.map(func(i): return i.name), ["Calc", "Todo"], "Launch Group 1 opens the note too")
	expect(BeDialogLogic.MEMBERS_HELP.contains("sticky notes"))
	s.free()


func test_note_icon_is_a_be_catalog_icon_and_pickable() -> void:
	expect_eq(BeIconCatalog.key_for("note"), "note")
	expect_eq(BeIconCatalog.key_for(Notes.ICON, "Anything"), "note", "not a hashed application icon")
	expect_eq(BeIconCatalog.key_for("sticky-note"), "note")
	expect(ResourceLoader.exists(BeIconCatalog.path_for("note")))
	var tex := BeIconCatalog.texture("note")
	expect(tex != null and tex.get_width() == 64 and tex.get_height() == 64)
	expect(BeIconCatalog.picker_options().map(func(o): return o.id).has("note"), "Change Icon offers it")


func test_every_new_items_menu_offers_new_note() -> void:
	var find := func(rows: Array) -> Dictionary:
		for r in rows:
			if String(r.get("label", "")) == "New Note…":
				return r
		return {}
	expect_eq(find.call(BeMenuModel.desktop_menu()).action, "note.new")
	expect_eq(find.call(BeMenuModel.folder_background_menu("g:x", false, "large")).args, {"key": "g:x"})
	expect_eq(find.call(BeMenuModel.folder_background_menu("computer", true, "large")).action, "note.new")
	expect_eq(find.call(BeMenuModel.menu_bar("g:x", false, "large", "")[0].items).args, {"key": "g:x"})
	var desk: Dictionary = find.call(BeMenuModel.deskbar_menu([]))
	expect_eq(desk.icon, "note")
	expect_eq(BeMenuModel.item_menu("g", "i")[0].action, "item.open", "Open on a note opens its window")


# ------------------------------------------------------------- the real shell

func test_shell_hosts_notes_between_windows_and_deskbar() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "call", "pink")
	var shell := _mount()
	await _frames()
	expect_eq(shell.note_layer(), shell.notes)
	var order := [shell.desktop, shell.notes, shell.deskbar, shell.menu_layer, shell.dialog_layer, shell.popup_layer, shell.toast]
	for i in order.size() - 1:
		expect(order[i].get_index() < order[i + 1].get_index(), "layer %d below layer %d" % [i, i + 1])
	expect_eq(shell.notes.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the empty layer lets clicks through")
	var st := shell.note_style()
	expect_eq(st.font, BeFont.font())
	expect_eq(st.font_size, BeGeometry.FONT, "notes use the main UI size")
	expect_eq(st.text_color, Color.BLACK)
	ProgramStore.update_settings({"theme": "dark"})
	expect(BeTheme.dark)
	expect_eq(shell.note_style().text_color, Color.BLACK, "the paper stays light in dark mode, so the text stays black")
	var n := shell.open_note(id, false)
	expect(n != null and n.get_parent() == shell.notes)
	expect_eq(n.text_color, Color.BLACK)
	expect_eq(n.paper, Notes.COLORS.pink)
	# launching a note from the shell opens it through Platform without the "Starting…" toast
	var opened := []
	var cb := func(i: String): opened.append(i)
	Platform.note_open_requested.connect(cb)
	shell.launch_item(ProgramStore.locate_item(id).item)
	Platform.note_open_requested.disconnect(cb)
	expect_eq(opened, [id])
	expect(not shell.toast.visible, "no Starting toast for a note")
	shell.free()
	_restore_store(saved)


func test_notes_take_clicks_drags_and_typing_and_menus_open_over_them() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var a_id: String = ProgramStore.add_note(g, "Selected", "a", "green")
	var b_id: String = ProgramStore.add_note(g, "Typing", "b", "yellow")
	# under the Deskbar menu, which opens at the top right
	ProgramStore.update_note_quietly(b_id, {"noteBounds": {"x": 330, "y": 150, "width": 260, "height": 150}})
	var shell := _mount()
	await _frames()
	shell.open_group_window(g)
	await _frames()
	var note := shell.open_note(b_id, false)
	await _frames()
	var auto := Automation.new(_tree())
	var opened := []
	var cb := func(i: String): opened.append(i)
	Platform.note_open_requested.connect(cb)
	# drag the note by its title strip
	var t := auto.center("note.title:" + b_id)
	await auto.drag(t, t + Vector2(-30, 20), 4, true)
	expect_eq(note.position, Vector2(300, 170), "dragged by its title")
	expect_eq(ProgramStore.locate_item(b_id).item.noteBounds, {"x": 300, "y": 170, "width": 260, "height": 150})
	# select the other note's icon in the folder window, then type into this note: Enter is a new line
	await auto.click_id("be.window.active:entry:0")
	expect_eq(shell.selected_id_in("g:" + g), a_id)
	var presses := []
	note._edit.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: presses.append(e.position))
	await auto.click(auto.center("note:" + b_id) + Vector2(0, 30))
	expect_eq(presses.size(), 1, "a click on the paper reaches the note's text")
	# The headless test viewport does not move keyboard focus on an injected click (a real window does;
	# see the Xvfb click-through), so put the caret there the way the click would.
	if shell.get_viewport().gui_get_focus_owner() != note._edit:
		note.focus_text()
	expect(shell._typing())
	await auto.key(KEY_END, {"ctrl": true})
	await auto.key(KEY_ENTER)
	await auto.type_text("x")
	expect_eq(note.text(), "b\nx")
	expect_eq(opened, [], "Enter while typing does not open the selected icon")
	expect_eq(shell.dialog_layer.get_child_count(), 0)
	# a press outside the note takes the keyboard back: Enter opens the selected icon again
	await auto.click_id("be.window.active:entry:0")
	expect(shell.get_viewport().gui_get_focus_owner() == null, "the note gave up the keyboard")
	await auto.key(KEY_ENTER)
	expect_eq(opened, [a_id])
	# the Deskbar menu opens over the note and its rows take the clicks above it
	await auto.click_id("be.deskbar.logo")
	await _frames()
	var row := auto.find_rect("be.popup-item:Backgrounds…")
	expect(Rect2(note.global_position, note.size).has_point(row.get_center()), "the menu row lies over the note")
	await auto.click(row.get_center().floor())
	await _frames()
	expect(auto.has("be.dialog.backgrounds"), "the click reached the menu, not the note")
	expect_eq(presses.size(), 1)
	Platform.note_open_requested.disconnect(cb)
	note.close()
	shell.free()
	_restore_store(saved)
