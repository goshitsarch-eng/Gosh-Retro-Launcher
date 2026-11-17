extends TestCase
## Be shell launch groups: the Launch Groups manager's rows and wording, the Members checklist, Get Info options,
## List View column, launch toast and the Deskbar menu rows (names, Launch Groups…, Export All… / Import All…).

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "be"
	s.settings["saveSettingsOnExit"] = false
	return s


## Work: a (group 1), b (group 2), c; Play: d (group 1). Group 1 is named "Morning", 4 is named "Later" (empty).
## Returns [store, workId, playId, {a, b, c, d}].
func _fixture() -> Array:
	var s := _store()
	var work: String = s.add_group("Work")
	var play: String = s.add_group("Play")
	var ids := {}
	ids["a"] = s.add_item(work, {"name": "Alpha", "path": "/bin/a", "icon": "terminal", "workingDir": "", "launchGroup": 1})
	ids["b"] = s.add_item(work, {"name": "Beta", "path": "/bin/b", "icon": "default", "workingDir": "", "launchGroup": 2})
	ids["c"] = s.add_item(work, {"name": "Gamma", "path": "/bin/c", "icon": "default", "workingDir": ""})
	ids["d"] = s.add_item(play, {"name": "Delta", "path": "/bin/d", "icon": "default", "workingDir": "", "launchGroup": 1})
	s.set_launch_group_name(1, "Morning")
	s.set_launch_group_name(4, "Later")
	return [s, work, play, ids]


func _labels(rows: Array) -> Array:
	return rows.map(func(r): return "-" if r.get("sep", false) else String(r.label))


func test_manager_rows_list_every_group_with_counts() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var rows := BeDialogLogic.manager_rows(s.groups, s.launch_group_names())
	expect_eq(rows.map(func(r): return r.label), ["Group 1: Morning", "Group 2", "Group 4: Later"])
	expect_eq(rows.map(func(r): return r.sub), ["2 items", "1 item", "empty"])
	expect_eq(rows[2].id, "4")
	expect_eq(rows[2].number, 4)
	expect_eq(BeDialogLogic.manager_rows([], {}), [])
	s.free()


func test_manager_status() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect_eq(BeDialogLogic.manager_status([], {}), "No launch groups yet. Click New… to make one.")
	expect_eq(BeDialogLogic.manager_status(s.groups, s.launch_group_names()), "3 of 8 group numbers in use.")
	for n in range(5, 9):
		s.set_launch_group_name(n, "G%d" % n)
	s.set_launch_group_name(3, "Three")
	expect_eq(BeDialogLogic.manager_status(s.groups, s.launch_group_names()), "All 8 group numbers are in use.")
	s.free()


func test_new_group_errors_explain_full_and_blank() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect_eq(BeDialogLogic.new_group_error(s.groups, s.launch_group_names(), "Night"), "")
	expect_eq(BeDialogLogic.new_group_error(s.groups, s.launch_group_names(), "  "), BeDialogLogic.LAUNCH_GROUP_NAME_NEEDED)
	for n in [3, 5, 6, 7, 8]:
		s.set_launch_group_name(n, "G%d" % n)
	var full := BeDialogLogic.new_group_error(s.groups, s.launch_group_names(), "Night")
	expect_eq(full, BeDialogLogic.LAUNCH_GROUPS_FULL)
	expect(full.contains("All 8"), "says every number is in use")
	expect_eq(s.create_launch_group("Night"), 0, "the store refuses too")
	s.free()


func test_number_options_mark_current_and_swaps() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var o := BeDialogLogic.number_options(s.groups, s.launch_group_names(), 2)
	expect_eq(o.size(), 8)
	expect_eq(o[0], ["1", "1 (swap with Group 1: Morning)"])
	expect_eq(o[1], ["2", "2 (current)"])
	expect_eq(o[2], ["3", "3"])
	expect_eq(o[3], ["4", "4 (swap with Group 4: Later)"])
	s.free()


func test_renumber_text_says_when_it_swaps() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var names: Dictionary = s.launch_group_names()
	expect_eq(BeDialogLogic.renumber_text(s.groups, names, 1, 3), "“Morning” is now Group 3.")
	expect_eq(BeDialogLogic.renumber_text(s.groups, names, 2, 5), "Group 2 is now Group 5.")
	expect_eq(BeDialogLogic.renumber_text(s.groups, names, 1, 2),
		"Swapped numbers: “Morning” is now Group 2 and the old Group 2 is now Group 1.")
	expect_eq(BeDialogLogic.renumber_text(s.groups, names, 2, 4),
		"Swapped numbers: Group 2 is now Group 4 and “Later” is now Group 2.")
	expect_eq(BeDialogLogic.renumber_text(s.groups, names, 2, 2), "")
	# the store does what the text says
	expect(s.renumber_launch_group(1, 2))
	expect_eq(int(s.find_item(f[1], f[3].a).launchGroup), 2)
	expect_eq(int(s.find_item(f[1], f[3].b).launchGroup), 1)
	expect_eq(BeDialogLogic.batch_text(2, s.launch_group_names()), "Group 2: Morning")
	s.free()


func test_delete_prompt_says_programs_are_kept() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var lines := BeDialogLogic.delete_prompt(s.groups, s.launch_group_names(), 1)
	expect_eq(lines[0].t, "Delete the launch group “Group 1: Morning”?")
	expect_eq(lines[1], "Its 2 programs stay in their folders; they only leave the launch group.")
	expect_eq(BeDialogLogic.delete_prompt(s.groups, s.launch_group_names(), 4)[1], "No programs are deleted.")
	expect_eq(BeDialogLogic.delete_prompt(s.groups, s.launch_group_names(), 2)[1],
		"Its program stays in its folder; it only leaves the launch group.")
	s.delete_launch_group(1)
	expect_eq(s.find_group(f[1]).items.size(), 3, "programs kept")
	expect_eq(int(s.find_item(f[1], f[3].a).launchGroup), 0)
	s.free()


func test_member_rows_label_folder_and_other_groups() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var rows := BeDialogLogic.member_rows(s.groups, s.launch_group_names(), 1)
	expect_eq(rows.map(func(r): return r.label), ["Alpha", "Beta (Group 2)", "Gamma", "Delta"])
	expect_eq(rows.map(func(r): return r.sub), ["Work", "Work", "Work", "Play"])
	expect_eq(rows.map(func(r): return r.checked), [true, false, false, true])
	expect_eq(rows[0].id, "%s:%s" % [f[1], f[3].a])
	expect_eq(rows[0].icon, "terminal")
	var for2 := BeDialogLogic.member_rows(s.groups, s.launch_group_names(), 2)
	expect_eq(for2[0].label, "Alpha (Group 1: Morning)", "other groups are named")
	expect_eq(BeDialogLogic.checked_keys(rows), ["%s:%s" % [f[1], f[3].a], "%s:%s" % [f[2], f[3].d]])
	s.free()


func test_members_result_and_apply() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var keys := ["%s:%s" % [f[1], f[3].a], "%s:%s" % [f[1], f[3].b], "%s:%s" % [f[1], f[3].c]]
	expect_eq(BeDialogLogic.members_result(s.groups, s.launch_group_names(), 1, keys),
		"Group 1: Morning now has 3 programs (1 moved from another group).")
	s.set_launch_group_members(1, keys)
	expect_eq(int(s.find_item(f[1], f[3].b).launchGroup), 1)
	expect_eq(int(s.find_item(f[2], f[3].d).launchGroup), 0, "unchecked members leave")
	expect_eq(BeDialogLogic.members_result(s.groups, s.launch_group_names(), 1, keys.slice(0, 1)),
		"Group 1: Morning now has 1 program.")
	s.free()


func test_get_info_options_and_list_view_use_names() -> void:
	var names := {"3": "Morning"}
	var o := BeDialogLogic.launch_group_options(names)
	expect_eq(o.size(), 9)
	expect_eq(o[0], ["0", "None"])
	expect_eq(o[3], ["3", "Group 3: Morning"])
	expect_eq(o[8], ["8", "Group 8"])
	expect_eq(BeDialogLogic.launch_group_options(names, 12).back(), ["12", "Group 12"], "a stored number above 8 stays selectable")
	expect_eq(BeDialogLogic.batch_text(3, names), "Group 3: Morning")
	var f := _fixture()
	var s: Node = f[0]
	var ents := BeDialogLogic.entries_for("g:" + f[1], s.groups, s.launch_group_names())
	expect_eq(ents.map(func(e): return e.c3), ["Group 1: Morning", "Group 2", "—"])
	expect_eq(BeDialogLogic.launch_group_summary(s.find_group(f[1]), s.launch_group_names()), "2 items (Group 1: Morning, Group 2)")
	expect_eq(BeDialogLogic.launch_group_summary({"items": [{"launchGroup": 0}]}), "None")
	s.free()


func test_get_info_keeps_a_stored_number_above_eight() -> void:
	var s := _store()
	var gid: String = s.add_group("G")
	var iid: String = s.add_item(gid, {"name": "X", "path": "/x", "icon": "default", "workingDir": "", "launchGroup": 12})
	BeDialogLogic.apply_item_info(s, gid, iid, {"name": "X", "path": "/x", "launchGroup": 12})
	expect_eq(int(s.find_item(gid, iid).launchGroup), 12)
	BeDialogLogic.apply_item_info(s, gid, iid, {"name": "X", "path": "/x", "launchGroup": 3})
	expect_eq(int(s.find_item(gid, iid).launchGroup), 3)
	BeDialogLogic.apply_item_info(s, gid, iid, {"name": "X", "path": "/x", "launchGroup": 20})
	expect_eq(int(s.find_item(gid, iid).launchGroup), 8, "a new value is still clamped")
	s.free()


func test_launch_toast_names_the_group() -> void:
	var fb := {"visible": true, "status": "launching", "currentGroup": 3, "completedGroups": 1, "totalGroups": 2}
	expect_eq(BeDialogLogic.feedback_text(fb, {"3": "Morning"}), "Launching Group 3: Morning (2 of 2)…")
	expect_eq(BeDialogLogic.feedback_text(fb), "Launching Group 3 (2 of 2)…")


func test_deskbar_menu_names_groups_and_offers_manager_and_transfer() -> void:
	var buckets := [{"groupNumber": 1, "items": [{}, {}]}, {"groupNumber": 3, "items": [{}]}]
	var d := BeMenuModel.deskbar_menu(buckets, {"1": "Morning"})
	var labels := _labels(d)
	var i := labels.find("Launch Group 1: Morning (2 items)")
	expect(i > 0, "launch rows use the names")
	expect_eq(d[i].args.n, 1)
	expect(labels.has("Launch Group 3 (1 item)"))
	var m := labels.find("Launch Groups…")
	expect_eq(m, labels.find("Launch Group 3 (1 item)") + 1, "the manager follows the launch rows")
	expect_eq(d[m].action, "launchgroups.open")
	expect_eq(labels.slice(m + 1, m + 4), ["-", "Export All…", "Import All…"])
	expect_eq(d[labels.find("Export All…")].action, "data.export")
	expect_eq(d[labels.find("Import All…")].action, "data.import")
	expect_eq(labels.back(), "Shut Down…")
	var empty := BeMenuModel.deskbar_menu([])
	expect(_labels(empty).has("Launch Groups…"), "the manager is offered before any group exists")


func test_import_confirm_and_transfer_reports() -> void:
	var lines := BeDialogLogic.import_confirm_lines()
	expect_eq(lines[0].t, DataTransfer.IMPORT_TITLE)
	expect_eq("\n\n".join(lines.slice(1)), DataTransfer.IMPORT_CONFIRM, "the shared confirm text, one paragraph per line")
	expect_eq(BeDialogLogic.transfer_report("export", {"success": false, "canceled": true}), {"show": false})
	expect_eq(BeDialogLogic.transfer_report("import", {"success": false, "error": "Canceled"}), {"show": false})
	var ex := BeDialogLogic.transfer_report("export", {"success": true, "path": "/tmp/x/all.json"})
	expect(ex.show and ex.toast, "a successful export is a toast")
	expect_eq(ex.text, "Exported everything to all.json.")
	var bad := BeDialogLogic.transfer_report("export", {"success": false, "error": "Could not write all.json."})
	expect(bad.show and not bad.toast)
	expect_eq(bad.icon, "warning")
	expect_eq(bad.lines[1], "Could not write all.json.")
	var im := BeDialogLogic.transfer_report("import", {"success": true})
	expect(im.show and not im.toast, "an import is confirmed in an alert")
	expect_eq(im.icon, "information")
	expect(String(im.text).begins_with("Imported everything."))
	var im_bad := BeDialogLogic.transfer_report("import", {"success": false, "error": "Invalid JSON"})
	expect_eq(im_bad.icon, "warning")
	expect_eq(im_bad.text, "Invalid JSON")
