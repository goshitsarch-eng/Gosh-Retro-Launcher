extends TestCase
## Win95 sticky notes as tasks: the taskbar button list (order, active state, click rules), Alt+Tab
## through windows and notes, the note menu (Close, Properties, Delete with its question), the
## Move/Size outline above the notes, and which task takes over when the active note closes.

const SHELL_SCRIPT := preload("res://src/shells/win95/win95_shell.gd")
const TS := preload("res://src/shells/win95/taskbar_state.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w95-notetask-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
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


func _key(shell: Win95Shell, keycode: Key, mods: Dictionary = {}) -> bool:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.alt_pressed = mods.get("alt", false)
	ev.shift_pressed = mods.get("shift", false)
	return shell.input.on_key(ev)


func _ids(tasks: Array) -> Array:
	return tasks.map(func(t): return t.id)


func _menus(shell: Win95Shell) -> Array:
	return shell.popup_layer.get_children().filter(func(c): return c is Win95Menu and not c.is_queued_for_deletion())


func _modals(shell: Win95Shell) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is Win95Modal and not c.is_queued_for_deletion())


func _button(root: Node, label: String) -> Win95Button:
	for b in root.find_children("*", "Win95Button", true, false):
		if String(b.label).replace("&", "") == label:
			return b
	return null


## A desk with a folder ("Desk") holding two notes; returns [gid, note a, note b].
func _desk() -> Array:
	var gid := ProgramStore.add_group("Desk")
	var a := ProgramStore.add_note(gid, "Shopping", "milk")
	var b := ProgramStore.add_note(gid, "Call back", "dentist")
	return [gid, a, b]


# ------------------------------------------------------------------ pure rules

func test_note_task_ids() -> void:
	expect_eq(TS.note_task_id("n1"), "note:n1")
	expect(TS.is_note_task("note:n1"))
	expect(not TS.is_note_task("group:n1"))
	expect_eq(TS.note_item_id("note:n1"), "n1")
	expect_eq(TS.note_item_id("my-computer"), "")


func test_merge_order_keeps_buttons_in_place_and_appends_new_ones() -> void:
	expect_eq(TS.merge_order([], ["a", "b"]), ["a", "b"])
	expect_eq(TS.merge_order(["b", "a"], ["a", "b", "c"]), ["b", "a", "c"], "activation never reorders")
	expect_eq(TS.merge_order(["a", "b", "c"], ["c", "a"]), ["a", "c"], "closed ones drop out")
	expect_eq(TS.merge_order(["a"], ["d", "a", "c"]), ["a", "d", "c"], "new ones keep their own order")


func test_task_list_merges_windows_and_notes_with_their_states() -> void:
	var wins := [{"id": "group:g", "minimized": false}, {"id": "my-computer", "minimized": true}]
	var tasks := TS.task_list(wins, ["n1", "n2"], [], "group:g", "")
	expect_eq(_ids(tasks), ["group:g", "my-computer", "note:n1", "note:n2"])
	expect_eq(tasks.map(func(t): return t.state), ["active", "minimized", "inactive", "inactive"])
	expect_eq(tasks.map(func(t): return t.kind), ["window", "window", "note", "note"])
	expect_eq(tasks[2].key, "n1", "a note button is keyed by its item id")
	# a note is active: only its button is pressed, whatever the store's window id says
	tasks = TS.task_list(wins, ["n1", "n2"], ["note:n2", "group:g"], Win95WindowStore.NOTE_ACTIVE, "n1")
	expect_eq(_ids(tasks), ["note:n2", "group:g", "my-computer", "note:n1"], "the previous order is kept")
	expect_eq(tasks.map(func(t): return t.state), ["inactive", "inactive", "minimized", "active"])
	tasks = TS.task_list(wins, ["n1"], [], "group:g", "n1")
	expect_eq(tasks[0].state, "inactive", "the window is not pressed while a note is active")
	expect(TS.task_list([], [], ["x"], "", "").is_empty())


func test_note_button_clicks_focus_or_keep() -> void:
	expect_eq(TS.note_click_action(false), "focus")
	expect_eq(TS.note_click_action(true), "keep", "a note cannot be minimized")


func test_cycle_target_walks_the_stack() -> void:
	var stack := ["group:a", "group:b", "note:n1", "note:n2"]
	expect_eq(TS.cycle_target(stack, "note:n2", false), "group:a", "from the top it wraps to the bottom")
	expect_eq(TS.cycle_target(stack, "group:b", false), "note:n1")
	expect_eq(TS.cycle_target(stack, "group:a", true), "note:n2")
	expect_eq(TS.cycle_target(stack, "", false), "group:a")
	expect_eq(TS.cycle_target(stack, "", true), "note:n2")
	expect_eq(TS.cycle_target([], "", false), "")


func test_recent_tasks_and_who_takes_over() -> void:
	var r := TS.touch_recent([], "group:a")
	r = TS.touch_recent(r, "note:n1")
	r = TS.touch_recent(r, "group:a")
	expect_eq(r, ["group:a", "note:n1"])
	expect_eq(TS.touch_recent(r, ""), r, "the desktop is not a task")
	expect_eq(TS.next_active(["note:n2", "note:n1", "group:a"], ["group:a", "note:n1"]), "note:n1")
	expect_eq(TS.next_active(["note:n2"], ["group:a"]), "")
	var many: Array = []
	for i in 40:
		many = TS.touch_recent(many, "t%d" % i)
	expect_eq(many.size(), 32, "the list stays short")


func test_ellipsize_shortens_with_three_dots() -> void:
	var m := func(s: String) -> int: return s.length() * 6
	expect_eq(TS.ellipsize("Short", 60, m), "Short")
	expect_eq(TS.ellipsize("Shopping list", 60, m), "Shoppin...")
	expect_eq(TS.ellipsize("Call back", 36, m), "Cal...")
	expect_eq(TS.ellipsize("Ab cdef", 36, m), "Ab...", "no space before the dots")
	expect_eq(TS.ellipsize("Shopping", 18, m), "...")
	expect_eq(TS.ellipsize("Shopping", 10, m), "")


func test_delete_question_keeps_ampersands() -> void:
	expect_eq(TS.delete_note_message("Shopping"), "Are you sure you want to delete 'Shopping'?")
	expect_eq(TS.delete_note_message("Tom & Jerry"), "Are you sure you want to delete 'Tom && Jerry'?")


func test_fit_title_measures_the_drawn_text() -> void:
	var long := "A very long sticky note title for the taskbar"
	var fit := Win95Taskbar.fit_title(long, 80, false)
	expect(fit.ends_with("..."), fit)
	expect(Win95Draw.measure(fit) <= 80)
	expect_eq(Win95Taskbar.fit_title("Tom & Jerry", 200, true), "Tom && Jerry", "& is drawn, not an access key")


# ------------------------------------------------------------------ the taskbar

func test_open_notes_get_taskbar_buttons() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	shell.windows.open_group(d[0])
	shell.open_note(d[1], false)
	shell.open_note(d[2])
	await _tree().process_frame
	var tasks: Array = shell.taskbar.task_buttons()
	expect_eq(_ids(tasks), ["group:" + d[0], "note:" + d[1], "note:" + d[2]], "in the order they opened")
	expect_eq(tasks.map(func(t): return t.state), ["inactive", "inactive", "active"])
	expect_eq(shell.taskbar._task_title(tasks[1]), "Shopping")
	expect_eq(shell.taskbar._task_icon(tasks[1]), Notes.ICON)
	expect(tasks[1].rect.position.x > tasks[0].rect.position.x)
	expect(shell.taskbar.auto_lookup("w95.task:note:" + d[1]) is Rect2)
	# renaming the note renames its button
	ProgramStore.update_item(d[0], d[1], {"name": "Groceries"})
	expect_eq(shell.taskbar._task_title(shell.taskbar.task_buttons()[1]), "Groceries")
	# closing removes it; the others keep their places
	shell.close_note(d[1])
	await _tree().process_frame
	expect_eq(_ids(shell.taskbar.task_buttons()), ["group:" + d[0], "note:" + d[2]])
	var names := shell.taskbar.a11y_part_specs().map(func(s): return s.get("name", ""))
	expect(names.has("Call back"), "screen readers see the note button")
	await _unmount(shell)
	_restore_store(saved)


func test_clicking_note_buttons() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	shell.windows.open_group(d[0])
	var a := shell.open_note(d[1])
	var b := shell.open_note(d[2])
	await _tree().process_frame
	expect_eq(shell.focused_note(), b)
	var by_id := func(id: String) -> Dictionary:
		for t in shell.taskbar.task_buttons():
			if t.id == id:
				return t
		return {}
	shell.taskbar.click_button(by_id.call("note:" + d[1]))
	await _tree().process_frame
	expect_eq(shell.windows.active_note_id(), d[1], "an inactive note's button activates it")
	expect_eq(shell.focused_note(), a, "with the keyboard")
	expect_eq(shell.notes_layer.get_child(shell.notes_layer.get_child_count() - 1), a, "in front")
	shell.taskbar.click_button(by_id.call("note:" + d[1]))
	await _tree().process_frame
	expect_eq(shell.windows.active_note_id(), d[1], "the active note's button leaves it active")
	expect_eq(shell.focused_note(), a)
	expect_eq(shell.open_notes().size(), 2)
	shell.taskbar.click_button(by_id.call("group:" + d[0]))
	expect_eq(shell.windows.active_window_id, "group:" + d[0], "a window's button activates the window")
	expect(not shell.note_has_focus(), "and the note gives up the keyboard")
	expect_eq(by_id.call("note:" + d[1]).state, "inactive")
	# a right-click on a note's button opens the note menu
	shell.taskbar._open_menu(Vector2(200, 460), by_id.call("note:" + d[2]))
	var menus := _menus(shell)
	expect_eq(menus.size(), 1)
	expect_eq(menus[0].items.map(func(i): return i.id), ["note-close", "note-properties", "sep", "note-delete"])
	expect(menus[0].position.y + menus[0].size.y <= 480 - Win95Tokens.M.taskbarHeight, "above the taskbar")
	menus[0].close()
	await _unmount(shell)
	_restore_store(saved)


func test_alt_tab_includes_notes() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	shell.windows.open_group(d[0])
	shell.open_note(d[1])
	await _tree().process_frame
	expect_eq(shell.task_stack(), ["group:" + d[0], "note:" + d[1]])
	expect_eq(shell.active_task_id(), "note:" + d[1])
	expect(_key(shell, KEY_TAB, {"alt": true}), "Alt+Tab works from a note's text")
	expect_eq(shell.windows.active_window_id, "group:" + d[0])
	expect(not shell.note_has_focus())
	expect(_key(shell, KEY_TAB, {"alt": true}))
	await _tree().process_frame
	expect_eq(shell.windows.active_note_id(), d[1], "and back to the note")
	expect(shell.note_has_focus())
	await _unmount(shell)
	_restore_store(saved)


func test_closing_the_active_note_returns_to_the_previous_task() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	shell.windows.open_group(d[0])
	shell.open_note(d[1])
	shell.open_note(d[2])
	await _tree().process_frame
	shell.close_note(d[2])
	await _tree().process_frame
	expect_eq(shell.windows.active_note_id(), d[1], "the note that was active before")
	expect(shell.note_has_focus())
	shell.close_note(d[1])
	await _tree().process_frame
	expect_eq(shell.windows.active_window_id, "group:" + d[0], "then the window")
	await _unmount(shell)
	_restore_store(saved)


func test_a_press_on_the_title_gives_the_note_the_keyboard() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	shell.windows.open_group(d[0])
	var n := shell.open_note(d[1])
	await _tree().process_frame
	var edit := shell._note_text(n)
	edit.set_caret_column(2)
	shell.windows.focus_window("group:" + d[0])
	expect(not shell.note_has_focus())
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	expect(not shell._route_note_press(mb, n.position + Vector2(60, 4)), "the press goes on to the note (drag)")
	expect_eq(shell.windows.active_note_id(), d[1])
	expect(shell.note_has_focus())
	expect_eq(edit.get_caret_column(), 2, "the caret stays where it was")
	expect(_key(shell, KEY_F4, {"alt": true}), "so Alt+F4 closes it")
	await _tree().process_frame
	expect_eq(shell.note_window(d[1]), null)
	await _unmount(shell)
	_restore_store(saved)


# ------------------------------------------------------------------ note menu

func test_note_menu_delete_asks_first() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	ProgramStore.update_item(d[0], d[1], {"name": "Tom & Jerry"})
	var shell := await _mount()
	shell.open_note(d[1])
	await _tree().process_frame
	var items: Array = shell.note_menu_items(d[1])
	expect_eq(items.map(func(i): return String(i.get("label", ""))), ["&Close", "P&roperties", "", "&Delete"])
	expect(items[0].get("defaultItem", false), "Close is the default")
	items[3].onSelect.call()
	var modals := _modals(shell)
	expect_eq(modals.size(), 1)
	expect_eq(modals[0].title, "Confirm File Delete")
	var labels: Array = modals[0].find_children("*", "Win95Label", true, false).map(func(l): return l.text)
	expect(labels.has("Are you sure you want to delete 'Tom && Jerry'?"), str(labels))
	_button(modals[0], "No").click()
	await _tree().process_frame
	expect(not ProgramStore.find_item(d[0], d[1]).is_empty(), "No keeps it")
	expect(shell.note_has_focus(), "and gives the note the keyboard back")
	shell.confirm_delete_note(d[1])
	_button(_modals(shell)[0], "Yes").click()
	await _tree().process_frame
	await _tree().process_frame
	expect(ProgramStore.find_item(d[0], d[1]).is_empty(), "Yes deletes it")
	expect_eq(shell.note_window(d[1]), null, "and its window")
	expect(not _ids(shell.taskbar.task_buttons()).has("note:" + d[1]), "and its button")
	await _unmount(shell)
	_restore_store(saved)


func test_shift_f10_in_a_note_opens_its_menu() -> void:
	var saved := _use_scratch_store()
	var d := _desk()
	var shell := await _mount()
	var n := shell.open_note(d[1])
	await _tree().process_frame
	expect(_key(shell, KEY_F10, {"shift": true}))
	var menus := _menus(shell)
	expect_eq(menus.size(), 1)
	expect(Rect2(n.position, n.size).has_point(menus[0].position), "inside the note")
	expect(_key(shell, KEY_ESCAPE), "the menu takes the keys")
	await _tree().process_frame
	expect(_menus(shell).is_empty())
	await _unmount(shell)
	_restore_store(saved)


# ------------------------------------------------------------------ Move/Size outline

func test_move_outline_is_drawn_above_the_notes() -> void:
	var saved := _use_scratch_store()
	var shell := await _mount()
	expect(shell.outline_layer.get_index() > shell.notes_layer.get_index())
	expect(shell.outline_layer.get_index() < shell.taskbar.get_index())
	expect_eq(shell.outline_layer.size, shell.desktop.size)
	expect(shell.outline_layer.clip_contents)
	shell.desktop.set_outline({"x": 10, "y": 20, "width": 200, "height": 100})
	var layers := shell.outline_layer.get_children().filter(func(c): return c is Win95DifferenceLayer)
	expect_eq(layers.size(), 1)
	expect_eq(layers[0].rects.size(), 1)
	expect_eq(layers[0].rects[0].rect, Rect2(10, 20, 200, 100))
	shell.desktop.set_outline({})
	expect(layers[0].rects.is_empty())
	await _unmount(shell)
	_restore_store(saved)
