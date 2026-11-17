extends TestCase
## WfW Launch Groups manager (Launcher > Launch Groups...), its New/Rename, Number and Members
## dialogs, launch group names in the menus, editors, feedback and Launcher Tools, and File >
## Import All / Export All.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w31lg-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Scratch store: "Work" has Notepad, Write, Clock; "Play" has Solitaire. Notepad and Solitaire are
## in group 1 "Morning", Clock in group 2 (no name). Returns [store, work, play, ids].
func _fixture() -> Array:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(_tmp())
	var work: String = s.add_group("Work")
	var play: String = s.add_group("Play")
	var ids := {}
	for n in ["Notepad", "Write", "Clock"]:
		ids[n] = s.add_item(work, {"name": n, "path": "/bin/" + n, "icon": "default", "workingDir": ""})
	ids["Solitaire"] = s.add_item(play, {"name": "Solitaire", "path": "/bin/sol", "icon": "default", "workingDir": ""})
	s.set_launch_group_members(1, ["%s:%s" % [work, ids.Notepad], "%s:%s" % [play, ids.Solitaire]])
	s.set_launch_group_name(1, "Morning")
	s.set_launch_group_members(2, ["%s:%s" % [work, ids.Clock]])
	return [s, work, play, ids]


func _key(f: Array, name: String) -> String:
	return "%s:%s" % [f[2] if name == "Solitaire" else f[1], f[3][name]]


func _lg(f: Array, name: String) -> int:
	return int(f[0].find_item(f[2] if name == "Solitaire" else f[1], f[3][name]).get("launchGroup", 0))


# ------------------------------------------------------------------- menus

func test_launcher_menu_names_groups_and_keeps_number_mnemonics() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var launcher: Array = Win31Commands.build_menus(s.groups, "", {}, s.settings)[3].items
	expect_eq(launcher[2].label, "Launch Group &1: Morning (2 items)")
	expect_eq(launcher[2].command, "launch-group:1")
	expect_eq(launcher[3].label, "Launch Group &2 (1 item)")
	expect_eq(Win31Commands.mnemonic_of(launcher[2].label), "1")
	expect_eq(launcher[5].command, "launch-groups", "Launch Groups... sits below the launch rows")
	expect_eq(launcher[5].label, "Launch &Groups...")
	var amp := Win31Commands.launch_menu_label(3, 2, {"3": "A & B"})
	expect_eq(amp, "Launch Group &3: A && B (2 items)")
	expect_eq(RetroFont.parse_access(amp).text, "Launch Group 3: A & B (2 items)", "a name's & shows as written")
	expect_eq(Win31Commands.mnemonic_of(amp), "3")
	s.free()


func test_file_menu_has_import_and_export_all_with_unique_mnemonics() -> void:
	var file: Array = Win31Commands.build_menus([], "", {}, {})[0].items
	var commands := []
	var seen := {}
	for it in file:
		if it.get("separator", false):
			continue
		commands.append(it.command)
		var m := Win31Commands.mnemonic_of(String(it.label))
		expect(not seen.has(m), "File mnemonic %s is unique" % m)
		seen[m] = true
	expect(commands.has("import-all") and commands.has("export-all"))
	expect_eq(file[Win31Commands.mnemonic_match(file, "i")].command, "import-all")
	expect_eq(file[Win31Commands.mnemonic_match(file, "a")].command, "export-all")
	expect_eq(file[file.size() - 1].command, "exit", "Exit stays last")


# ------------------------------------------------------------- names shown

func test_editor_dropdowns_feedback_and_tools_use_names() -> void:
	var names := {"3": "Morning"}
	var c := W31DialogLogic.launch_group_choices(names)
	expect_eq(c.values, [0, 1, 2, 3, 4, 5, 6, 7, 8])
	expect_eq(c.labels[0], "None")
	expect_eq(c.labels[3], "Group 3: Morning")
	expect_eq(c.labels[4], "Group 4")
	expect_eq(W31DialogLogic.launch_group_choices().labels[3], "Group 3", "no names")
	var fb := {"status": "launching", "currentGroup": 3, "completedGroups": 0, "totalGroups": 2}
	expect_eq(W31DialogLogic.feedback_status_text(fb, names), "Launching Group 3: Morning")
	expect_eq(W31DialogLogic.feedback_status_text(fb), "Launching Group 3")
	var bucket := {"groupNumber": 3, "items": [{}, {}]}
	expect_eq(LauncherToolsLogic.launch_group_label(bucket, names), "Launch Group 3: Morning (2 items)")
	expect_eq(LauncherToolsLogic.launch_group_label(bucket), "Launch Group 3 (2 items)")
	expect_eq(LauncherToolsLogic.launch_status_start([bucket], names), "Launching Group 3: Morning...")
	expect_eq(LauncherToolsLogic.batch_group_labels(names)[3], "Group 3: Morning")


# ---------------------------------------------------------------- manager rules

func test_manager_rows_actions_and_detail() -> void:
	var f := _fixture()
	var s: Node = f[0]
	s.create_launch_group("Later")
	var rows := W31DialogLogic.launch_group_rows(s.groups, s.launch_group_names())
	expect_eq(rows.map(func(r): return r.text), ["Group 1: Morning", "Group 2", "Group 3: Later"])
	expect_eq(rows.map(func(r): return r.right), ["2 programs", "1 program", "No programs"])
	expect_eq(W31DialogLogic.launch_group_row_index(rows, 3), 2)
	expect_eq(W31DialogLogic.launch_group_row_index(rows, 7), 0)
	expect_eq(W31DialogLogic.launch_group_row_index([], 1), -1)
	var a := W31DialogLogic.launch_group_actions(rows, 2)
	expect(a.rename and a.number and a.delete and a.members and a.new)
	expect(not a.launch, "an empty group has nothing to launch")
	expect(W31DialogLogic.launch_group_actions(rows, 0).launch)
	expect(not W31DialogLogic.launch_group_actions(rows, 0, true).launch, "not while a batch runs")
	var none := W31DialogLogic.launch_group_actions([], -1)
	expect(none.new and not none.rename and not none.delete and not none.members and not none.launch)
	expect_eq(W31DialogLogic.launch_group_detail(s.groups, s.launch_group_names(), 1),
		"Group 1: Morning starts Notepad and Solitaire.")
	expect_eq(W31DialogLogic.launch_group_detail(s.groups, s.launch_group_names(), 3),
		"Group 3: Later has no programs yet. Choose Members... to add some.")
	expect_eq(W31DialogLogic.launch_group_detail([], {}, 0), W31DialogLogic.NO_LAUNCH_GROUPS)
	expect_eq(W31DialogLogic._join_names(["a", "b", "c", "d", "e", "f", "g", "h"], 6), "a, b, c, d, e and 3 more")
	expect_eq(W31DialogLogic._join_names(["a", "b", "c"], 6), "a, b and c")
	s.free()


func test_new_and_rename_rules() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect(not W31DialogLogic.launch_group_name_ok("new", "   "), "New needs a name")
	expect(W31DialogLogic.launch_group_name_ok("rename", ""), "a blank rename clears the name")
	expect_eq(W31DialogLogic.new_launch_group_number(s.groups, s.launch_group_names()), 3)
	var r := W31DialogLogic.apply_new_launch_group(s, "Evening")
	expect_eq([r.number, r.status], [3, "Created Group 3: Evening."])
	expect_eq(W31DialogLogic.apply_rename_launch_group(s, 3, " Night "), "Group 3 is now called “Night”.")
	expect_eq(s.launch_group_names()["3"], "Night")
	expect_eq(W31DialogLogic.apply_rename_launch_group(s, 1, ""), "Group 1 has no name now.")
	expect(not s.launch_group_names().has("1"))
	for i in 5:
		s.create_launch_group("Extra %d" % i)
	expect_eq(W31DialogLogic.new_launch_group_number(s.groups, s.launch_group_names()), 0, "all 8 in use")
	expect_eq(W31DialogLogic.apply_new_launch_group(s, "Ninth"),
		{"number": 0, "status": W31DialogLogic.ALL_LAUNCH_GROUPS_IN_USE})
	expect_eq(LauncherToolsLogic.new_launch_group(s, "Ninth"), W31DialogLogic.ALL_LAUNCH_GROUPS_IN_USE)
	s.free()


func test_number_choices_note_and_swap() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var names: Dictionary = s.launch_group_names()
	var choices := W31DialogLogic.launch_group_number_choices(s.groups, names, 1)
	expect_eq(choices.size(), 8)
	expect_eq(choices[0].label, "1 (current)")
	expect_eq(choices[1].label, "2 - swap with Group 2")
	expect_eq(choices[4], {"value": 5, "label": "5"})
	expect_eq(W31DialogLogic.renumber_note(s.groups, names, 1, 1), "")
	expect_eq(W31DialogLogic.renumber_note(s.groups, names, 1, 2), "Group 2 becomes Group 1: the two swap places in Launch All.")
	expect_eq(W31DialogLogic.renumber_note(s.groups, names, 1, 5), "Launch All starts the groups in number order, lowest first.")
	var r := W31DialogLogic.apply_renumber_launch_group(s, 1, 2)
	expect_eq(r, {"ok": true, "number": 2, "status": "Group 1: Morning is now Group 2. Group 2 is now Group 1."})
	expect_eq(_lg(f, "Notepad"), 2)
	expect_eq(_lg(f, "Clock"), 1)
	expect_eq(s.launch_group_names(), {"2": "Morning"})
	expect_eq(W31DialogLogic.apply_renumber_launch_group(s, 2, 2).ok, false, "same number changes nothing")
	expect_eq(LauncherToolsLogic.renumber_launch_group(s, 2, 6), "Group 2: Morning is now Group 6.")
	s.free()


func test_delete_keeps_programs_and_says_so() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect_eq(W31DialogLogic.delete_launch_group_message(s.groups, s.launch_group_names(), 1),
		"Delete Group 1: Morning? Its 2 programs will stay in their program groups; they just stop launching with this group.")
	s.create_launch_group("Empty")
	expect_eq(W31DialogLogic.delete_launch_group_message(s.groups, s.launch_group_names(), 3), "Delete Group 3: Empty? It has no programs.")
	var count_before := LaunchGroups.all_items(s.groups).size()
	expect_eq(W31DialogLogic.apply_delete_launch_group(s, 1), "Deleted Group 1: Morning. Its programs were kept.")
	expect_eq(LaunchGroups.all_items(s.groups).size(), count_before)
	expect_eq(_lg(f, "Notepad"), 0)
	expect(not s.launch_group_names().has("1"))
	expect_eq(LauncherToolsLogic.delete_launch_group(s, 3), "Deleted Group 3: Empty. Its programs were kept.")
	s.free()


func test_member_rows_and_apply() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var names: Dictionary = s.launch_group_names()
	var checked := W31DialogLogic.member_check_set(s.groups, 1)
	expect_eq(checked.keys().size(), 2)
	var rows := W31DialogLogic.member_rows(s.groups, names, 1, checked)
	expect_eq(rows.map(func(r): return r.text), ["Work", "Notepad", "Write", "Clock (Group 2)", "Play", "Solitaire"])
	expect_eq(rows.map(func(r): return r.get("header", false)), [true, false, false, false, true, false])
	expect_eq(rows.map(func(r): return r.get("checked", false)), [false, true, false, false, false, true])
	var for_two := W31DialogLogic.member_rows(s.groups, names, 2, {})
	expect_eq(for_two[1].text, "Notepad (Group 1: Morning)", "other groups are named")
	expect_eq(for_two[3].text, "Clock", "its own members are not marked")
	rows[2].checked = true  # Write joins
	rows[3].checked = true  # Clock moves over from group 2
	rows[5].checked = false  # Solitaire leaves
	var keys := W31DialogLogic.checked_member_keys(rows)
	expect_eq(keys, [_key(f, "Notepad"), _key(f, "Write"), _key(f, "Clock")])
	expect_eq(W31DialogLogic.apply_launch_group_members(s, 1, keys), "Group 1: Morning has 3 programs.")
	expect_eq([_lg(f, "Notepad"), _lg(f, "Write"), _lg(f, "Clock"), _lg(f, "Solitaire")], [1, 1, 1, 0])
	expect_eq(W31DialogLogic.launch_group_bucket(s.groups, 1)[0].items.size(), 3)
	expect_eq(W31DialogLogic.launch_group_bucket(s.groups, 2), [], "group 2 lost its only member")
	s.free()


# ----------------------------------------------------------------- widgets

func test_list_box_skips_headers_and_toggles() -> void:
	var list := W31ListBox.new(3, true)
	list.size = Vector2(200, list.fit_height())
	list.set_rows([{"header": true, "text": "Work"}, {"key": "a", "text": "A"}, {"key": "b", "text": "B", "checked": true},
		{"header": true, "text": "Play"}, {"key": "c", "text": "C"}])
	expect_eq(list.current, 1, "the cursor starts on the first selectable row")
	expect_eq(list.fit_height(), 3 * W31ListBox.ROW + 3)
	list.handle_key(KEY_DOWN)
	list.handle_key(KEY_DOWN)
	expect_eq(list.current, 4, "Down skips the Play caption")
	list.handle_key(KEY_DOWN)
	expect_eq(list.current, 4, "and stops at the end")
	list.handle_key(KEY_HOME)
	expect_eq(list.current, 1)
	list.handle_key(KEY_END)
	expect_eq(list.current, 4)
	expect(list.handle_key(KEY_SPACE))
	expect_eq(list.rows[4].checked, true, "Space checks")
	list.handle_key(KEY_SPACE)
	expect_eq(list.rows[4].checked, false)
	list.set_all_checked(true)
	expect_eq(W31DialogLogic.checked_member_keys(list.rows), ["a", "b", "c"])
	expect(not list.rows[0].get("checked", false), "captions never get a check")
	var specs := list.a11y_item_specs()
	expect_eq(specs[0].role, DisplayServer.ROLE_STATIC_TEXT)
	expect_eq([specs[1].role, specs[1].checked], [DisplayServer.ROLE_CHECK_BOX, true])
	expect_eq(specs.map(func(sp): return sp.hidden), [true, true, false, false, false], "End scrolled the first rows away")
	list.free()
	var plain := W31ListBox.new(4)
	plain.set_rows([{"text": "Group 1", "right": "2 programs"}, {"text": "Group 2"}], 1)
	expect_eq(plain.current, 1)
	expect(not plain.handle_key(KEY_SPACE), "no check boxes, Space is not used")
	expect_eq(plain.a11y_item_specs()[0].name, "Group 1, 2 programs")
	plain.set_rows([])
	expect_eq(plain.current, -1)
	plain.free()


func test_buttons_take_access_keys_from_their_label() -> void:
	var b := W31Button.new("N&umber...")
	expect_eq(b.access_key, "u")
	var plain := W31Button.new("OK")
	expect_eq(plain.access_key, "")
	plain.free()
	var hit := [false]
	b.pressed.connect(func(): hit[0] = true)
	b.activate_access_key()
	expect(hit[0], "Alt+key presses the button")
	b.free()


func test_confirm_and_message_options() -> void:
	UIState.close_dialog()
	var c := W31MessageDialogs.Confirm.new({"title": "T", "message": "M", "yesText": "OK", "noText": "Cancel", "width": 400,
		"onConfirm": func(): pass})
	c.build(600)
	expect_eq(c.dialog_width, 400)
	expect_eq(c.default_button.text, "OK")
	c.free()
	var back := [false]
	var m := W31MessageDialogs.Unavailable.new({"title": "T", "message": "M", "icon": "information",
		"onClose": func(): back[0] = true})
	m.build(600)
	m.default_button.click()
	expect(back[0], "onClose runs instead of closing")
	m.free()


# ------------------------------------------------------------------ dialogs

func _press(dlg: W31Dialog, auto_id: String) -> void:
	for n in dlg.tab_stops() + dlg._all_widgets(dlg):
		if n is W31Button and n.auto_id == auto_id:
			n.click()
			return
	expect(false, "no button " + auto_id)


func test_manager_lists_groups_and_enables_buttons() -> void:
	var f := _fixture()
	var s: Node = f[0]
	s.create_launch_group("Later")
	var dlg := W31LaunchGroupDialogs.Manager.new({"selected": 3}, s)
	dlg.build(600)
	expect_eq(dlg.title, "Launch Groups")
	expect_eq(dlg.list.rows.size(), 3)
	expect_eq(dlg.list.current, 2, "the requested group is selected")
	expect_eq(dlg.selected_number, 3)
	expect(dlg.buttons.launch.disabled, "nothing to launch in an empty group")
	expect(not dlg.buttons.members.disabled)
	expect_eq(dlg.default_button, dlg.buttons.close)
	expect_eq(dlg.list.access_key, "g")
	dlg.list.handle_key(KEY_HOME)
	expect_eq(dlg.selected_number, 1)
	expect(not dlg.buttons.launch.disabled)
	expect_eq(dlg._detail_text(), "Group 1: Morning starts Notepad and Solitaire.")
	UIState.close_dialog()
	_press(dlg, "wfw.dialog.launch-groups:members")
	expect_eq([UIState.active_dialog, UIState.dialog_data.get("number")], ["launchGroupMembers", 1])
	_press(dlg, "wfw.dialog.launch-groups:number")
	expect_eq(UIState.active_dialog, "launchGroupNumber")
	_press(dlg, "wfw.dialog.launch-groups:rename")
	expect_eq([UIState.active_dialog, UIState.dialog_data.mode], ["launchGroupName", "rename"])
	_press(dlg, "wfw.dialog.launch-groups:new")
	expect_eq([UIState.active_dialog, UIState.dialog_data.mode, UIState.dialog_data.number], ["launchGroupName", "new", 4])
	_press(dlg, "wfw.dialog.launch-groups:delete")
	expect_eq(UIState.active_dialog, "confirm")
	expect(String(UIState.dialog_data.confirmOptions.message).contains("will stay in their program groups"))
	UIState.close_dialog()
	dlg.free()
	s.free()


func test_manager_refreshes_when_the_store_changes() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var dlg := W31LaunchGroupDialogs.Manager.new({}, s)
	Engine.get_main_loop().root.add_child(dlg)
	dlg.build(600)
	expect_eq(dlg.list.rows.size(), 2)
	s.create_launch_group("Evening")
	await Engine.get_main_loop().process_frame
	expect_eq(dlg.list.rows.size(), 3, "a new group shows up without reopening")
	dlg.queue_free()
	await Engine.get_main_loop().process_frame
	s.free()


func test_manager_with_all_numbers_taken_explains() -> void:
	var f := _fixture()
	var s: Node = f[0]
	for i in 6:
		s.create_launch_group("G%d" % i)
	var dlg := W31LaunchGroupDialogs.Manager.new({}, s)
	dlg.build(600)
	UIState.close_dialog()
	_press(dlg, "wfw.dialog.launch-groups:new")
	expect_eq(UIState.active_dialog, "unavailable")
	expect_eq(UIState.dialog_data.message, W31DialogLogic.ALL_LAUNCH_GROUPS_IN_USE)
	(UIState.dialog_data.onClose as Callable).call()
	expect_eq(UIState.active_dialog, "launchGroups", "OK goes back to the manager")
	UIState.close_dialog()
	dlg.free()
	s.free()


func test_empty_manager() -> void:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(_tmp())
	var dlg := W31LaunchGroupDialogs.Manager.new({}, s)
	dlg.build(600)
	expect_eq(dlg.list.current, -1)
	for k in ["rename", "number", "delete", "members", "launch"]:
		expect(dlg.buttons[k].disabled, "%s needs a group" % k)
	expect(not dlg.buttons.new.disabled)
	expect_eq(dlg._detail_text(), W31DialogLogic.NO_LAUNCH_GROUPS)
	dlg.free()
	s.free()


func test_new_name_dialog_creates_then_picks_members() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var dlg := W31LaunchGroupDialogs.NameDialog.new({"mode": "new", "number": 3}, s)
	dlg.build(600)
	expect_eq(dlg.title, "New Launch Group")
	expect(dlg.ok.disabled, "OK waits for a name")
	dlg.field.text = "Evening"
	dlg._sync()
	expect(not dlg.ok.disabled)
	dlg.ok.click()
	expect_eq(s.launch_group_names()["3"], "Evening")
	expect_eq([UIState.active_dialog, UIState.dialog_data.number], ["launchGroupMembers", 3], "then straight to its programs")
	UIState.close_dialog()
	dlg.free()
	var ren := W31LaunchGroupDialogs.NameDialog.new({"mode": "rename", "number": 1}, s)
	ren.build(600)
	expect_eq(ren.field.text, "Morning")
	ren.field.text = ""
	ren._sync()
	expect(not ren.ok.disabled, "blank is allowed: it removes the name")
	ren.ok.click()
	expect(not s.launch_group_names().has("1"))
	expect_eq([UIState.active_dialog, UIState.dialog_data.selected, UIState.dialog_data.status],
		["launchGroups", 1, "Group 1 has no name now."])
	UIState.close_dialog()
	ren.free()
	s.free()


func test_number_dialog_swaps() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var dlg := W31LaunchGroupDialogs.NumberDialog.new({"number": 1}, s)
	dlg.build(600)
	expect_eq(dlg.combo.items.size(), 8)
	expect_eq(dlg.combo.value(), 1)
	dlg.combo.select_value(2)
	dlg.target = 2
	dlg.default_button.click()
	expect_eq([_lg(f, "Notepad"), _lg(f, "Clock")], [2, 1])
	expect_eq(UIState.dialog_data.selected, 2)
	expect(String(UIState.dialog_data.status).contains("Group 2 is now Group 1"), "the swap is reported")
	UIState.close_dialog()
	dlg.free()
	s.free()


func test_members_dialog_applies_checklist_and_cancel_changes_nothing() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var dlg := W31LaunchGroupDialogs.Members.new({"number": 2}, s)
	dlg.build(600)
	expect_eq(dlg.list.checkboxes, true)
	expect_eq(dlg.list.rows.size(), 6)
	dlg.list.toggle(1)  # Notepad, from group 1
	dlg.cancel()
	expect_eq(_lg(f, "Notepad"), 1, "Cancel leaves the store alone")
	expect_eq(UIState.active_dialog, "launchGroups")
	dlg.free()
	var dlg2 := W31LaunchGroupDialogs.Members.new({"number": 2}, s)
	dlg2.build(600)
	dlg2.list.toggle(1)
	dlg2.list.toggle(3)  # Clock leaves
	dlg2.default_button.click()
	expect_eq([_lg(f, "Notepad"), _lg(f, "Clock")], [2, 0])
	expect_eq(UIState.dialog_data.status, "Group 2 has 1 program.")
	UIState.close_dialog()
	dlg2.free()
	s.free()


func test_dialog_layer_creates_the_launch_group_dialogs() -> void:
	var m := Win31DialogLayer.create_dialog("launchGroups", {})
	expect(m is W31LaunchGroupDialogs.Manager)
	m.free()
	var n := Win31DialogLayer.create_dialog("launchGroupName", {"mode": "new", "number": 1})
	expect(n is W31LaunchGroupDialogs.NameDialog)
	n.free()
	expect_eq(Win31DialogLayer.create_dialog("launchGroupNumber", {}), null, "needs a group")
	expect_eq(Win31DialogLayer.create_dialog("launchGroupMembers", {}), null, "needs a group")
	var nb := Win31DialogLayer.create_dialog("launchGroupNumber", {"number": 2})
	expect(nb is W31LaunchGroupDialogs.NumberDialog)
	nb.free()


# -------------------------------------------------------------- shell commands

func test_shell_commands_open_manager_and_confirm_import() -> void:
	UIState.close_dialog()
	var shell := Win31Shell.new()
	shell.run_command("launch-groups")
	expect_eq(UIState.active_dialog, "launchGroups")
	shell.run_command("import-all")
	expect_eq(UIState.active_dialog, "confirm")
	var o: Dictionary = UIState.dialog_data.confirmOptions
	expect_eq([o.title, o.yesText, o.noText], [DataTransfer.IMPORT_TITLE, "OK", "Cancel"])
	expect_eq(o.message, DataTransfer.IMPORT_CONFIRM.replace("Launcher Tools > Backups", "Launcher Tools - Backups"),
		"the shared wording, without the > the WfW font cannot draw")
	UIState.close_dialog()
	shell.free()


func test_launcher_tools_rename_and_transfer_status() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect_eq(LauncherToolsLogic.rename_launch_group(s, 2, "Evening"), "Group 2 is now called “Evening”.")
	expect_eq(LauncherToolsLogic.launch_group_rows(s.groups, s.launch_group_names())[1].text, "Group 2: Evening")
	expect_eq(LauncherToolsLogic.new_launch_group(s, "Night"), "Created Group 3: Night. Pick its programs with Batch group below.")
	expect_eq(LauncherToolsLogic.new_launch_group(s, "  "), "Type a name for the new launch group.")
	expect_eq(LauncherToolsLogic.export_all_status({"success": true, "path": "/x/all.json"}), "Exported everything to all.json.")
	expect_eq(LauncherToolsLogic.export_all_status({"success": false, "canceled": true}), "")
	expect_eq(LauncherToolsLogic.import_all_status({"success": false, "error": "Canceled"}), "")
	expect(LauncherToolsLogic.import_all_status({"success": true}).begins_with("Imported everything."))
	s.free()
