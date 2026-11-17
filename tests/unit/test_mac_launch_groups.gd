extends TestCase
## Mac shell launch group management: the Special and File menu rows, the Launch Groups manager's rows, labels
## and store actions (new / rename / renumber / members / delete), names in Get Info, the folder list, Find and
## the launch toasts, and the Export All / Import All messages. Runs against a real ProgramStore (not persisted).

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _store() -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["shell"] = "mac"
	s.settings["saveSettingsOnExit"] = false
	return s


## Main: Mail, Editor, Clock; Games: Chess. Returns {s, main, games, mail, editor, clock, chess} plus keys k_*.
func _fixture() -> Dictionary:
	var s := _store()
	var main: String = s.add_group("Main")
	var games: String = s.add_group("Games")
	var f := {"s": s, "main": main, "games": games}
	for n in ["Mail", "Editor", "Clock"]:
		f[n.to_lower()] = s.add_item(main, {"name": n, "path": "/bin/" + n, "icon": "default", "workingDir": ""})
		f["k_" + n.to_lower()] = "%s:%s" % [main, f[n.to_lower()]]
	f["chess"] = s.add_item(games, {"name": "Chess", "path": "/bin/chess", "icon": "default", "workingDir": ""})
	f["k_chess"] = "%s:%s" % [games, f.chess]
	return f


func _lg(f: Dictionary, gid: String, iid: String) -> int:
	return int(f.s.find_item(f[gid], f[iid]).get("launchGroup", 0))


func _find_menu(menus: Array, id: String) -> Dictionary:
	for m in menus:
		if m.id == id:
			return m
	return {}


func _ids(items: Array) -> Array:
	return items.map(func(i): return "-" if MacMenuModel.is_sep(i) else String(i.id))


# ------------------------------------------------------------------ menus

func test_special_menu_rows_show_names_and_the_manager() -> void:
	var buckets := [{"groupNumber": 1, "items": [{}, {}]}, {"groupNumber": 3, "items": [{}]}]
	var items := MacMenuModel.special_menu(buckets, {"1": "Morning"})
	expect_eq(_ids(items), ["launch-all", "launch-group:1", "launch-group:3", "-", "launch-groups", "-", "run", "-", "restart", "shutdown"])
	expect_eq(items[1].label, "Launch Group 1: Morning (2 items)")
	expect_eq(items[2].label, "Launch Group 3 (1 item)")
	expect_eq(items[4].label, "Launch Groups…")
	expect(not items[4].get("disabled", false), "the manager is always available, even with no groups")
	var empty := MacMenuModel.special_menu([])
	expect(empty[0].disabled)
	expect_eq(empty[2].id, "launch-groups")


func test_menu_bar_passes_names_to_the_special_menu() -> void:
	var ctx := {"groups": [], "active_key": "", "view": "", "selected": {"kind": ""},
		"buckets": [{"groupNumber": 2, "items": [{}]}], "launch_names": {"2": "Evening"}}
	var special := _find_menu(MacMenuModel.menu_bar(ctx), "special")
	expect_eq(special.items[1].label, "Launch Group 2: Evening (1 item)")


func test_file_menu_ends_with_export_and_import_all() -> void:
	var ctx := {"groups": [], "active_key": "", "view": "", "selected": {"kind": ""}, "buckets": []}
	var file := _find_menu(MacMenuModel.menu_bar(ctx), "file")
	var n: int = file.items.size()
	expect(MacMenuModel.is_sep(file.items[n - 3]))
	expect_eq(file.items[n - 2].id, "export-all")
	expect_eq(file.items[n - 2].label, "Export All…")
	expect_eq(file.items[n - 1].id, "import-all")
	expect_eq(file.items[n - 1].label, "Import All…")
	expect(not file.items[n - 2].get("disabled", false) and not file.items[n - 1].get("disabled", false))


# ------------------------------------------------------------------ labels

func test_get_info_options_carry_names() -> void:
	var opts := MacDialogLogic.launch_group_options({"3": "Morning"})
	expect_eq(opts.size(), 9)
	expect_eq(opts[0], {"id": "0", "label": "None"})
	expect_eq(opts[2].label, "Group 2", "an unnamed group keeps the plain label (automation ids rely on it)")
	expect_eq(opts[3].label, "Group 3: Morning")
	var kept := MacDialogLogic.launch_group_options({}, 12)
	expect_eq(kept.size(), 10)
	expect_eq(kept[9], {"id": "12", "label": "Group 12"})


func test_get_info_keeps_a_stored_number_above_eight() -> void:
	var f := _fixture()
	f.s.update_item(f.main, f.mail, {"launchGroup": 12})
	var fields := {"name": "Mail", "path": "/bin/Mail", "launchGroup": "12", "groupId": f.main}
	expect(MacDialogLogic.apply_item_info(f.s, f.main, f.mail, fields).ok)
	expect_eq(_lg(f, "main", "mail"), 12)
	fields.launchGroup = "13"
	expect(not MacDialogLogic.apply_item_info(f.s, f.main, f.mail, fields).ok, "only the stored number is accepted")
	f.s.free()


func test_folder_column_and_launch_toasts_use_names() -> void:
	expect_eq(MacDialogLogic.launch_group_cell(0, {"1": "x"}), "—")
	expect_eq(MacDialogLogic.launch_group_cell(1, {"1": "Morning"}), "Group 1: Morning")
	expect_eq(MacDialogLogic.launch_group_cell(4, {}), "Group 4")
	var names := {"3": "Morning"}
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": false, "status": "launching"}, names), "")
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": true, "status": "launching", "totalGroups": 2, "completedGroups": 0,
		"currentGroup": null}, names), "Launching group 1 of 2…")
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": true, "status": "launching", "totalGroups": 2, "completedGroups": 1,
		"currentGroup": 3}, names), "Launching Group 3: Morning (2 of 2)…")
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": true, "status": "launching", "totalGroups": 1, "completedGroups": 0,
		"currentGroup": 3}, names), "Launching Group 3: Morning…")
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": true, "status": "complete", "totalItems": 1}, names), "Launched 1 item.")
	expect_eq(MacDialogLogic.launch_feedback_text({"visible": true, "status": "error", "failures": 2}, names), "2 items failed to launch.")


func test_about_stats_count_launch_groups() -> void:
	var f := _fixture()
	expect_eq(MacDialogLogic.stats_line(f.s.groups, {}), "2 folders, 4 programs")
	f.s.create_launch_group("Morning")
	f.s.set_launch_group_members(4, [f.k_chess])
	expect_eq(MacDialogLogic.stats_line(f.s.groups, f.s.launch_group_names()), "2 folders, 4 programs, 2 launch groups")
	f.s.free()


func test_find_launch_groups_matches_group_names() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_clock])
	f.s.set_launch_group_members(2, [f.k_chess])
	var names: Dictionary = f.s.launch_group_names()
	var hits := MacDialogLogic.find_items(f.s.groups, "morn", "all", "batch", names)
	expect_eq(hits.map(func(r): return r.item.name), ["Clock"])
	var by_name := MacDialogLogic.find_items(f.s.groups, "ch", "all", "batch", names)
	expect_eq(by_name.map(func(r): return r.item.name), ["Chess"], "name matches still work and come first")
	var all := MacDialogLogic.find_items(f.s.groups, "", "all", "batch", names)
	expect_eq(all.size(), 2)
	expect(MacDialogLogic.find_items(f.s.groups, "morn", f.games, "batch", names).is_empty(), "the folder filter applies")
	expect(MacDialogLogic.find_items(f.s.groups, "morn", "all", "all", names).is_empty(), "only the launch group search")
	f.s.free()


# ------------------------------------------------------------------ manager

func test_manager_rows_list_number_name_and_count() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_mail, f.k_editor])
	f.s.create_launch_group("Later")
	f.s.set_launch_group_members(5, [f.k_chess])
	var rows := MacDialogLogic.launch_group_rows(f.s.groups, f.s.launch_group_names())
	expect_eq(rows.map(func(r): return r.id), ["1", "2", "5"])
	expect_eq(rows[0].label, "Group 1: Morning")
	expect_eq(rows[0].sub, "2 items")
	expect_eq(rows[1].sub, "empty")
	expect_eq(rows[2].label, "Group 5")
	expect_eq(rows[2].sub, "1 item")
	expect_eq(rows[2].count, 1)
	expect(MacDialogLogic.launch_group_rows([], {}).is_empty())
	f.s.free()


func test_new_group_names_it_and_refuses_when_full() -> void:
	var f := _fixture()
	expect_eq(MacDialogLogic.new_group_prompt(f.s.groups, {}), "The new launch group will be Group 1. Name it, then check the programs it starts.")
	var blank := MacDialogLogic.new_launch_group(f.s, "   ")
	expect_eq(blank.number, 0)
	expect(String(blank.error).contains("name"))
	var r := MacDialogLogic.new_launch_group(f.s, " Morning ")
	expect_eq(r, {"number": 1, "error": ""})
	expect_eq(f.s.launch_group_names(), {"1": "Morning"})
	for i in 7:
		expect(int(MacDialogLogic.new_launch_group(f.s, "g%d" % i).number) > 0)
	var full := MacDialogLogic.new_launch_group(f.s, "Ninth")
	expect_eq(full.number, 0)
	expect_eq(full.error, MacDialogLogic.ALL_NUMBERS_IN_USE)
	expect(String(full.error).contains("All 8"))
	expect_eq(MacDialogLogic.new_group_prompt(f.s.groups, f.s.launch_group_names()), MacDialogLogic.ALL_NUMBERS_IN_USE)
	f.s.free()


func test_rename_sets_and_clears_the_name() -> void:
	var f := _fixture()
	f.s.set_launch_group_members(2, [f.k_mail])
	expect_eq(MacDialogLogic.rename_launch_group(f.s, 2, " Evening\n"), "Group 2 is now called “Evening”.")
	expect_eq(f.s.launch_group_names(), {"2": "Evening"})
	expect_eq(MacDialogLogic.rename_launch_group(f.s, 2, ""), "Group 2 no longer has a name.")
	expect_eq(f.s.launch_group_names(), {})
	expect_eq(_lg(f, "main", "mail"), 2, "members are untouched")
	f.s.create_launch_group("Empty")
	expect(MacDialogLogic.rename_launch_group(f.s, 1, " ").contains("removed"), "an empty unnamed group is gone")
	expect(MacDialogLogic.launch_group_rows(f.s.groups, f.s.launch_group_names()).map(func(r): return r.id) == ["2"])
	expect(MacDialogLogic.rename_hint(0).contains("removed"))
	expect(not MacDialogLogic.rename_hint(2).contains("removed"))
	f.s.free()


func test_number_options_mark_swaps() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_mail])
	f.s.create_launch_group("Evening", [f.k_chess])
	var opts := MacDialogLogic.number_options(f.s.groups, f.s.launch_group_names(), 1)
	expect_eq(opts.size(), 8)
	expect_eq(opts[0], {"id": "1", "label": "Group 1: Morning"})
	expect_eq(opts[1], {"id": "2", "label": "Group 2: Evening (swap)"})
	expect_eq(opts[2], {"id": "3", "label": "Group 3"})
	f.s.free()


func test_renumber_moves_or_swaps_and_says_which() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_mail])
	f.s.create_launch_group("Evening", [f.k_chess])
	var moved := MacDialogLogic.renumber_launch_group(f.s, 1, 6)
	expect(moved.ok and not moved.swapped)
	expect_eq(moved.status, "Group 1: Morning is now Group 6.")
	expect_eq(_lg(f, "main", "mail"), 6)
	expect_eq(f.s.launch_group_names(), {"6": "Morning", "2": "Evening"})
	var swapped := MacDialogLogic.renumber_launch_group(f.s, 6, 2)
	expect(swapped.ok and swapped.swapped)
	expect_eq(swapped.status, "Group 6: Morning and Group 2: Evening swapped numbers, so Launch All now starts them in the new order.")
	expect_eq(_lg(f, "main", "mail"), 2)
	expect_eq(_lg(f, "games", "chess"), 6)
	var same := MacDialogLogic.renumber_launch_group(f.s, 2, 2)
	expect(not same.ok)
	f.s.free()


func test_member_rows_mark_other_groups_and_apply() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_mail])
	f.s.create_launch_group("Evening", [f.k_chess])
	var rows := MacDialogLogic.member_rows(f.s.groups, 1, f.s.launch_group_names())
	expect_eq(rows.map(func(r): return r.label), ["Mail", "Editor", "Clock", "Chess (Group 2: Evening)"])
	expect_eq(rows.map(func(r): return r.sub), ["Main", "Main", "Main", "Games"])
	expect_eq(rows.map(func(r): return r.checked), [true, false, false, false])
	expect_eq(rows[3].auto, "Chess")
	expect_eq(rows[0].id, f.k_mail)
	expect_eq(MacDialogLogic.members_summary(rows), "1 of 4 programs checked")
	rows[0].checked = false
	rows[2].checked = true
	rows[3].checked = true
	var keys := MacDialogLogic.checked_keys(rows)
	expect_eq(keys, [f.k_clock, f.k_chess])
	f.s.set_launch_group_members(1, keys)
	expect_eq(_lg(f, "main", "mail"), 0)
	expect_eq(_lg(f, "main", "clock"), 1)
	expect_eq(_lg(f, "games", "chess"), 1, "checking an item in another group moves it")
	expect_eq(MacDialogLogic.members_status(1, 2, true), "Group 1 now starts 2 programs.")
	expect_eq(MacDialogLogic.members_status(4, 0, true), "Group 4 now starts 0 programs.")
	expect(MacDialogLogic.members_status(4, 0, false).contains("removed"))
	f.s.free()


func test_delete_prompt_says_programs_are_kept() -> void:
	var f := _fixture()
	f.s.create_launch_group("Morning", [f.k_mail, f.k_editor])
	f.s.create_launch_group("Empty")
	var names: Dictionary = f.s.launch_group_names()
	expect_eq(MacDialogLogic.delete_prompt(f.s.groups, names, 1),
		"Delete Group 1: Morning? Its 2 programs stay in their folders; they just stop launching together.")
	expect_eq(MacDialogLogic.delete_prompt(f.s.groups, names, 2), "Delete Group 2: Empty? It has no programs.")
	f.s.delete_launch_group(1)
	expect_eq(_lg(f, "main", "mail"), 0)
	expect(not f.s.find_item(f.main, f.mail).is_empty(), "the program itself stays")
	f.s.free()


# ------------------------------------------------------------- export / import

func test_transfer_messages() -> void:
	var ok := MacDialogLogic.transfer_message("export", {"success": true, "path": "/x/everything.json"})
	expect_eq(ok, {"text": "Exported everything to everything.json.", "icon": "note"})
	expect_eq(MacDialogLogic.transfer_message("export", {"success": false, "canceled": true}).text, "")
	expect_eq(MacDialogLogic.transfer_message("export", {"success": false, "error": "Could not write a.json."}),
		{"text": "Could not write a.json.", "icon": "stop"})
	var imported := MacDialogLogic.transfer_message("import", {"success": true})
	expect_eq(imported.icon, "note")
	expect(String(imported.text).begins_with("Imported everything."))
	expect_eq(MacDialogLogic.transfer_message("import", {"success": false, "error": "Canceled"}).text, "")
	expect_eq(MacDialogLogic.transfer_message("import", {"success": false, "error": "Invalid file format"}),
		{"text": "Invalid file format", "icon": "stop"})


func test_help_mentions_the_manager_and_export() -> void:
	var text := ""
	for t in MacDialogLogic.HELP_TOPICS:
		text += String(t[1]) + "\n"
	expect(text.contains("Launch Groups"))
	expect(text.contains("Export All") and text.contains("Import All"))
