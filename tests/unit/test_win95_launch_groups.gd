extends TestCase
## Win95 launch groups: the Start > Programs > Launch Groups cascade rows, the "Launch group:"
## drop-down, the Launch Groups manager (rows, buttons, wording, refresh on store changes), the
## Members check list and Number picker, batch-launch failure text, Find's launch-group filter and
## the list/select keyboard helpers.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _item(id: String, name: String, lg: int = 0, path: String = "/bin/x") -> Dictionary:
	return {"id": id, "name": name, "path": path, "icon": "application", "workingDir": "", "launchGroup": lg}


## Work: a (1), b (1), c; Play: d (2), e (12: stored above the editor range).
func _groups() -> Array:
	return [
		{"id": "work", "name": "Work", "items": [_item("a", "Alpha", 1), _item("b", "B & Co", 1), _item("c", "Gamma")]},
		{"id": "play", "name": "Play", "items": [_item("d", "Delta", 2), _item("e", "Echo", 12)]},
	]


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = _groups()
	s.settings = Types.default_settings()
	return s


# ------------------------------------------------------------ Start menu

func test_menu_rows_without_groups_offer_only_manage() -> void:
	var rows := Win95LaunchGroupLogic.menu_rows([{"id": "g", "name": "G", "items": [_item("x", "X")]}], {})
	expect_eq(rows.map(func(r): return r.id), ["launch-all", "manage"])
	expect(rows[0].disabled, "Launch All is disabled when nothing is in a launch group")
	expect(rows[1].separatorBefore)
	expect_eq(rows[1].label, "&Manage Launch Groups...")


func test_menu_rows_list_groups_with_members_using_names_and_digit_access_keys() -> void:
	var rows := Win95LaunchGroupLogic.menu_rows(_groups(), {"1": "Morning & Mail", "3": "Empty"})
	expect_eq(rows.map(func(r): return r.id), ["launch-all", "launch:1", "launch:2", "launch:12", "manage"])
	expect(not rows[0].disabled)
	expect_eq(rows[0].label, "Launch &All")
	expect_eq(rows[1].label, "Launch Group &1: Morning && Mail (2 items)", "names are escaped, the digit is the access key")
	expect_eq(rows[2].label, "Launch Group &2 (1 item)")
	expect_eq(rows[1].number, 1)
	expect_eq(Win95MenuState.mnemonic_index(rows.map(func(r): return r.label), "2"), 2)
	expect_eq(Win95MenuState.mnemonic_index(rows.map(func(r): return r.label), "m"), 4)


func test_buckets_for_rows() -> void:
	var g := _groups()
	expect_eq(Win95LaunchGroupLogic.buckets_for(g, "launch-all").map(func(b): return b.groupNumber), [1, 2, 12])
	var one := Win95LaunchGroupLogic.buckets_for(g, "launch:1")
	expect_eq(one.size(), 1)
	expect_eq(one[0].items.map(func(i): return i.id), ["a", "b"])
	expect_eq(Win95LaunchGroupLogic.buckets_for(g, "launch:5"), [])
	expect_eq(Win95LaunchGroupLogic.buckets_for(g, "manage"), [])


func test_programs_row_and_cascade_geometry() -> void:
	var row := Win95LaunchGroupLogic.programs_row()
	expect_eq(row.id, Win95LaunchGroupLogic.PROGRAMS_ROW_ID)
	expect_eq(row.name, "Launch Groups")
	# Unchanged heights for the existing cascades: Find (3 rows) and the old Settings (4 rows + 1 separator).
	expect_eq(Win95StartMenu.cascade_height([{}, {}, {}]), 3 * 22 + 8)
	expect_eq(Win95StartMenu.cascade_height([{}, {}, {}, {"separatorBefore": true}]), 4 * 22 + 6 + 8)
	expect_eq(Win95StartMenu.cascade_height([]), 30, "(Empty) row")
	var settings_h := Win95StartMenu.cascade_height(Win95StartMenu.SETTINGS_ITEMS)
	expect_eq(settings_h, 7 * 22 + 2 * 6 + 8)
	expect_eq(Win95StartMenu.launch_groups_width([{"label": "x"}]), 164, "never narrower than a normal cascade")
	var wide := Win95StartMenu.launch_groups_width([{"label": "Launch Group &1: A rather long launch group name (12 items)"}])
	expect(wide > 164 and wide <= 360, "sized to the label: %d" % wide)


func test_settings_cascade_has_launch_groups_export_and_import() -> void:
	var ids := Win95StartMenu.SETTINGS_ITEMS.map(func(i): return i.id)
	expect_eq(ids, ["control", "printers", "taskbar", "tools", "groups", "export", "import"])
	var labels := Win95StartMenu.SETTINGS_ITEMS.map(func(i): return i.label)
	expect_eq(Win95MenuState.mnemonic_index(labels, "g"), 4)
	expect_eq(Win95MenuState.mnemonic_index(labels, "x"), 5)
	expect_eq(Win95MenuState.mnemonic_index(labels, "i"), 6)


# --------------------------------------------------------- launch results

func test_launch_title_and_failure_message() -> void:
	var g := _groups()
	var all := Win95LaunchGroupLogic.buckets_for(g, "launch-all")
	expect_eq(Win95LaunchGroupLogic.launch_title(all, {}), "Launch All")
	expect_eq(Win95LaunchGroupLogic.launch_title(Win95LaunchGroupLogic.buckets_for(g, "launch:1"), {"1": "Morning"}), "Launch Group 1: Morning")
	var ok := [{"id": "a", "success": true}, {"id": "b", "success": true}]
	expect_eq(Win95LaunchGroupLogic.failure_message(ok, all), "")
	var mixed := [{"id": "a", "success": true}, {"id": "b", "success": false, "error": "Cannot find 'b'."},
		{"id": "d", "success": false}]
	expect_eq(Win95LaunchGroupLogic.failure_message(mixed, all),
		"2 of 3 programs could not be started:\n\nB & Co: Cannot find 'b'.\nDelta: The program could not be started.")
	expect_eq(Win95LaunchGroupLogic.failure_message([{"id": "zz", "success": false, "error": "Nope"}], all),
		"The program could not be started:\n\nNope")


func test_failure_message_is_capped() -> void:
	var items := []
	var results := []
	for i in 9:
		items.append(_item("i%d" % i, "P%d" % i, 1))
		results.append({"id": "i%d" % i, "success": false, "error": "x"})
	var text := Win95LaunchGroupLogic.failure_message(results, [{"groupNumber": 1, "items": items}])
	expect(text.begins_with("9 of 9 programs could not be started:"))
	expect(text.contains("P5: x") and not text.contains("P6: x"))
	expect(text.ends_with("...and 3 more."))


# ---------------------------------------------------------------- drop-down

func test_choices_show_names_and_keep_out_of_range_values() -> void:
	var c := Win95LaunchGroupLogic.choices({"2": "Night"})
	expect_eq(c.size(), 1 + LaunchGroups.MAX_GROUP)
	expect_eq(Win95LaunchGroupLogic.choice_labels(c).slice(0, 3), ["None", "Group 1", "Group 2: Night"])
	expect_eq(Win95LaunchGroupLogic.choice_index(c, 2), 2)
	expect_eq(Win95LaunchGroupLogic.choice_index(c, 99), 0)
	expect_eq(Win95LaunchGroupLogic.choice_value(c, 0), 0)
	expect_eq(Win95LaunchGroupLogic.choice_value(c, 8), 8)
	expect_eq(Win95LaunchGroupLogic.choice_value(c, 40), 0)
	var kept := Win95LaunchGroupLogic.choices({}, 12)
	expect_eq(kept.size(), 2 + LaunchGroups.MAX_GROUP)
	expect_eq(Win95LaunchGroupLogic.choice_value(kept, Win95LaunchGroupLogic.choice_index(kept, 12)), 12)


func test_properties_and_wizard_save_launch_group() -> void:
	var s := _store()
	var r := Win95DialogLogic.apply_item_properties(s, "work", "c", {"name": "Gamma", "command": "/bin/g", "workingDir": "",
		"arguments": "", "runMode": "normal", "groupId": "work", "launchGroup": 3})
	expect(r.ok)
	expect_eq(int(s.find_item("work", "c").launchGroup), 3)
	Win95DialogLogic.apply_item_properties(s, "work", "c", {"name": "Gamma", "command": "/bin/g", "workingDir": "",
		"arguments": "", "runMode": "normal", "groupId": "work", "launchGroup": 0})
	expect_eq(int(s.find_item("work", "c").launchGroup), 0)
	Win95DialogLogic.apply_item_properties(s, "play", "e", {"name": "Echo", "command": "/bin/x", "workingDir": "",
		"arguments": "", "runMode": "normal", "groupId": "play"})
	expect_eq(int(s.find_item("play", "e").launchGroup), 12, "a sheet without the field leaves it alone")
	var id := Win95DialogLogic.wizard_finish(s, "work", "New", "/bin/n", "application", "", 4)
	expect_eq(int(s.find_item("work", id).launchGroup), 4)
	var plain := Win95DialogLogic.wizard_finish(s, "work", "Plain", "/bin/p", "application", "")
	expect(not s.find_item("work", plain).has("launchGroup"))
	s.free()


# ------------------------------------------------------------------- manager

func test_manager_rows_buttons_and_selection() -> void:
	var rows := Win95LaunchGroupLogic.manager_rows(_groups(), {"1": "Morning", "5": "Later"})
	expect_eq(rows.map(func(r): return r.number), [1, 2, 5, 12])
	expect_eq(rows[0].cells, ["Group 1", "Morning", "2"])
	expect_eq(rows[1].cells, ["Group 2", "(no name)", "1"])
	expect_eq(rows[2].cells, ["Group 5", "Later", "0"])
	expect_eq(Win95LaunchGroupLogic.row_index(rows, 5), 2)
	expect_eq(Win95LaunchGroupLogic.row_index(rows, 7, 9), 3, "missing number falls back to a clamped index")
	expect_eq(Win95LaunchGroupLogic.row_index([], 1), -1)
	var b := Win95LaunchGroupLogic.manager_buttons(rows[2])
	expect(b.new and b.rename and b.number and b.delete and b.members)
	expect(not b.launch, "an empty group cannot be launched")
	var none := Win95LaunchGroupLogic.manager_buttons({})
	expect(none.new, "New stays enabled so it can explain when all numbers are used")
	expect(not none.rename and not none.number and not none.delete and not none.members and not none.launch)


func test_manager_wording() -> void:
	expect(Win95LaunchGroupLogic.all_numbers_used_message().begins_with("All 8 launch group numbers are in use."))
	expect_eq(Win95LaunchGroupLogic.delete_prompt(3, 0, {"3": "X"}), "Are you sure you want to delete Group 3: X?")
	expect_eq(Win95LaunchGroupLogic.delete_prompt(2, 1),
		"Are you sure you want to delete Group 2?\n\nIts 1 program will not be deleted; they just leave the launch group.")
	expect_eq(Win95LaunchGroupLogic.created_status(4, {"4": "Work"}), "Created Group 4: Work.")
	expect_eq(Win95LaunchGroupLogic.renamed_status(4, {"4": "Work"}), "Renamed to Group 4: Work.")
	expect_eq(Win95LaunchGroupLogic.renamed_status(4, {}), "Group 4 no longer has a name.")


func test_number_choices_note_and_status() -> void:
	var names := {"1": "Morning"}
	var c := Win95LaunchGroupLogic.number_choices(_groups(), names, 2)
	expect_eq(c.size(), LaunchGroups.MAX_GROUP)
	expect_eq(Win95LaunchGroupLogic.choice_labels(c).slice(0, 3), ["1 (swap with Group 1: Morning)", "2 (current)", "3"])
	expect_eq(Win95LaunchGroupLogic.number_note(_groups(), names, 2, 3), "")
	expect_eq(Win95LaunchGroupLogic.number_note(_groups(), names, 2, 2), "")
	expect_eq(Win95LaunchGroupLogic.number_note(_groups(), names, 2, 1),
		"Group 1: Morning already uses number 1. The two groups will swap numbers.")
	expect(Win95LaunchGroupLogic.is_number_used(_groups(), names, 1))
	expect(not Win95LaunchGroupLogic.is_number_used(_groups(), names, 3))
	expect_eq(Win95LaunchGroupLogic.renumbered_status(2, 5, false, names), "Group 2 is now number 5.")
	expect_eq(Win95LaunchGroupLogic.renumbered_status(2, 1, true, names), "Group 2 is now number 1; Group 1: Morning is now number 2.")


func test_member_rows_mark_other_groups_and_summarise() -> void:
	var rows := Win95LaunchGroupLogic.member_rows(_groups(), 1)
	expect_eq(rows.map(func(r): return r.key), ["work:a", "work:b", "work:c", "play:d", "play:e"])
	expect_eq(rows.map(func(r): return r.checked), [true, true, false, false, false])
	expect_eq(rows[0].cells, ["Alpha", "Work", ""])
	expect_eq(rows[3].cells, ["Delta", "Play", "Group 2"])
	expect_eq(Win95LaunchGroupLogic.checked_keys(rows), ["work:a", "work:b"])
	expect_eq(Win95LaunchGroupLogic.members_summary(rows, 1), "2 programs selected.")
	rows[3].checked = true
	expect_eq(Win95LaunchGroupLogic.members_summary(rows, 1), "3 programs selected; 1 will leave its other launch group.")
	var fresh := Win95LaunchGroupLogic.member_rows(_groups(), 0)
	expect(fresh.all(func(r): return not r.checked), "a group not created yet starts empty")
	expect_eq(fresh[0].cells[2], "Group 1")


# -------------------------------------------------------------- Find / keys

func test_find_launch_group_type() -> void:
	expect_eq(Win95DialogLogic.FIND_TYPES.size(), Win95DialogLogic.FIND_TYPE_LABELS.size())
	expect_eq(Win95DialogLogic.FIND_TYPE_LABELS[3], "In a launch group")
	var f := Win95DialogLogic.find_filters("*", "", true, "launch-group", "", "")
	var names := Win95DialogLogic.find_results(_groups(), f).map(func(r): return r.item.name)
	names.sort()
	expect_eq(names, ["Alpha", "B & Co", "Delta", "Echo"])
	expect_eq(Win95DialogLogic.find_results(_groups(), Win95DialogLogic.find_filters("*", "", true, "all", "", "")).size(), 5)


func test_list_and_select_keys() -> void:
	expect_eq(Win95ListBox.next_index(-1, "ArrowDown", 5, 4), 0)
	expect_eq(Win95ListBox.next_index(4, "ArrowDown", 5, 4), 4)
	expect_eq(Win95ListBox.next_index(2, "ArrowUp", 5, 4), 1)
	expect_eq(Win95ListBox.next_index(0, "PageDown", 10, 4), 3)
	expect_eq(Win95ListBox.next_index(9, "PageUp", 10, 4), 6)
	expect_eq(Win95ListBox.next_index(3, "End", 10, 4), 9)
	expect_eq(Win95ListBox.next_index(3, "x", 10, 4), -2)
	expect_eq(Win95ListBox.next_index(0, "Home", 0, 4), -1)
	expect_eq(Win95Select.key_index(0, "ArrowDown", 3), 1)
	expect_eq(Win95Select.key_index(2, "ArrowDown", 3), 2)
	expect_eq(Win95Select.key_index(0, "ArrowUp", 3), 0)
	expect_eq(Win95Select.key_index(1, "End", 3), 2)
	expect_eq(Win95Select.key_index(1, "Enter", 3), -1)


func test_list_box_rows_selection_and_checks() -> void:
	var lb := Win95ListBox.new()
	lb.size = Vector2(200, 100)
	lb.checkboxes = true
	var toggled := []
	lb.check_toggled.connect(func(i, on): toggled.append([i, on]))
	lb.set_rows([{"cells": ["a"]}, {"cells": ["b"], "checked": true}], 5)
	expect_eq(lb.selected, 1, "clamped")
	lb.click()
	expect_eq(toggled, [[1, false]])
	lb.set_rows([], 0)
	expect_eq(lb.selected, -1)
	lb.free()


func test_message_height_grows_only_for_long_text() -> void:
	expect_eq(Win95Dialogs.message_height("Short."), 145.0)
	expect(Win95Dialogs.message_height(DataTransfer.IMPORT_CONFIRM) > 145.0)


# ------------------------------------------------------------- integration

func test_manager_lists_groups_and_follows_store_changes() -> void:
	var saved_groups := ProgramStore.groups.duplicate(true)
	var saved_settings := ProgramStore.settings.duplicate(true)
	ProgramStore.groups = _groups()
	ProgramStore.settings["launchGroupNames"] = {"1": "Morning"}
	var shell := Win95Shell.new()
	shell.host = _tree().root
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	await _tree().process_frame
	var m := Win95LaunchGroups.open_manager(shell)
	expect(Win95LaunchGroups.open_manager(shell) == m, "one manager at a time")
	var list: Win95ListBox = m.find_children("*", "Win95ListBox", true, false)[0]
	expect_eq(list.rows.map(func(r): return r.number), [1, 2, 12])
	expect_eq(list.selected, 0)
	list.select(1)
	var n: int = ProgramStore.create_launch_group("Evening")
	expect_eq(n, 3)
	expect_eq(list.rows.map(func(r): return r.number), [1, 2, 3, 12], "refreshes on store changes")
	expect_eq(list.rows[list.selected].number, 2, "keeps the selected group")
	ProgramStore.renumber_launch_group(2, 5)
	expect_eq(list.rows.map(func(r): return r.number), [1, 3, 5, 12])
	expect(list.selected >= 0 and list.selected < list.rows.size(), "keeps a valid selection")
	m.close()
	await _tree().process_frame
	shell.queue_free()
	await _tree().process_frame
	ProgramStore.groups = saved_groups
	ProgramStore.settings = saved_settings


func test_start_menu_keyboard_reaches_launch_groups_and_manager() -> void:
	var saved_groups := ProgramStore.groups.duplicate(true)
	var saved_settings := ProgramStore.settings.duplicate(true)
	ProgramStore.groups = _groups()
	ProgramStore.settings["launchGroupNames"] = {}
	var shell := Win95Shell.new()
	shell.host = _tree().root
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	await _tree().process_frame
	shell.input.open_start_menu()
	var sm: Win95StartMenu = shell.start_menu
	sm._on_key({"key": "p"})
	expect_eq(sm.open_top, "programs")
	expect_eq(sm._level_items(1)[-1].id, Win95LaunchGroupLogic.PROGRAMS_ROW_ID, "Launch Groups is the last Programs row")
	sm._on_key({"key": "ArrowUp"})
	sm._on_key({"key": "ArrowRight"})
	expect_eq(sm.open_group, Win95LaunchGroupLogic.PROGRAMS_ROW_ID)
	expect_eq(sm._level_items(2).map(func(r): return r.id), ["launch-all", "launch:1", "launch:2", "launch:12", "manage"])
	expect(sm.level_rect(2).size.x >= 164)
	sm._on_key({"key": "m"})
	expect(not shell.input.start_menu_open, "activating a row closes the menu")
	var titles := shell.find_children("*", "Win95Modal", true, false).map(func(x): return String(x.title))
	expect(titles.has("Launch Groups"), "Manage Launch Groups... opens the manager: %s" % str(titles))
	for x in shell.find_children("*", "Win95Modal", true, false):
		x.close()
	await _tree().process_frame
	shell.queue_free()
	await _tree().process_frame
	ProgramStore.groups = saved_groups
	ProgramStore.settings = saved_settings
