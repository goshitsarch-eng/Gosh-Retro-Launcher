extends TestCase
## Launch groups as editable things: names, members, create / rename / renumber / delete, and that
## all of it survives a restart and an Export All -> Import All round trip.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-lgm-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _open(dir: String) -> Node:
	var s: Node = STORE_SCRIPT.new()
	s.init_store(dir)
	return s


## Store with group "Work" holding a, b, c and group "Play" holding d. Returns [store, workId, playId, ids].
func _fixture() -> Array:
	var s := _open(_tmp())
	var work: String = s.add_group("Work")
	var play: String = s.add_group("Play")
	var ids := {}
	for n in ["a", "b", "c"]:
		ids[n] = s.add_item(work, {"name": n, "path": "/bin/" + n, "icon": "default", "workingDir": ""})
	ids["d"] = s.add_item(play, {"name": "d", "path": "/bin/d", "icon": "default", "workingDir": ""})
	return [s, work, play, ids]


func _lg(s: Node, gid: String, iid: String) -> int:
	return int(s.find_item(gid, iid).get("launchGroup", 0))


func test_format_and_labels_use_names() -> void:
	var names := {"3": "Morning"}
	expect_eq(LaunchGroups.format_launch_group(0, names), "None")
	expect_eq(LaunchGroups.format_launch_group(2, names), "Group 2")
	expect_eq(LaunchGroups.format_launch_group(3, names), "Group 3: Morning")
	expect_eq(LaunchGroups.format_launch_group(3), "Group 3", "old one-argument callers unchanged")
	expect_eq(LaunchGroups.launch_label(3, 1, names), "Launch Group 3: Morning (1 item)")
	expect_eq(LaunchGroups.launch_label(5, 2), "Launch Group 5 (2 items)")


func test_clean_name() -> void:
	expect_eq(LaunchGroups.clean_name("  Morning\nstuff\t "), "Morning stuff")
	expect_eq(LaunchGroups.clean_name("x".repeat(60)).length(), LaunchGroups.MAX_NAME_LENGTH)
	expect_eq(LaunchGroups.clean_name("   "), "")


func test_create_names_and_members() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var n: int = s.create_launch_group("Morning", ["%s:%s" % [f[1], f[3].a], "%s:%s" % [f[2], f[3].d]])
	expect_eq(n, 1)
	expect_eq(s.settings.launchGroupNames, {"1": "Morning"})
	expect_eq(_lg(s, f[1], f[3].a), 1)
	expect_eq(_lg(s, f[2], f[3].d), 1)
	expect_eq(_lg(s, f[1], f[3].b), 0)
	var defined := LaunchGroups.defined_groups(s.groups, s.launch_group_names())
	expect_eq(defined, [{"number": 1, "name": "Morning", "label": "Group 1: Morning", "count": 2}])
	s.free()


func test_named_empty_group_exists_and_takes_a_number() -> void:
	var f := _fixture()
	var s: Node = f[0]
	expect_eq(s.create_launch_group("Later"), 1)
	expect_eq(LaunchGroups.defined_groups(s.groups, s.launch_group_names())[0].count, 0)
	expect_eq(LaunchGroups.next_free_number(s.groups, s.launch_group_names()), 2)
	expect_eq(LaunchGroups.collect_launch_groups(s.groups), [], "an empty group has nothing to launch")
	expect_eq(s.create_launch_group("   "), 0, "an empty unnamed group would not exist")
	s.free()


func test_create_refuses_when_all_numbers_taken() -> void:
	var f := _fixture()
	var s: Node = f[0]
	for i in LaunchGroups.MAX_GROUP:
		expect_eq(s.create_launch_group("G%d" % (i + 1)), i + 1)
	expect_eq(s.create_launch_group("One too many"), 0)
	s.free()


func test_set_members_moves_items_between_groups() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var a := "%s:%s" % [f[1], f[3].a]
	var b := "%s:%s" % [f[1], f[3].b]
	s.set_launch_group_members(2, [a, b])
	s.set_launch_group_members(5, [b])
	expect_eq(_lg(s, f[1], f[3].a), 2)
	expect_eq(_lg(s, f[1], f[3].b), 5, "joining 5 takes it out of 2")
	s.set_launch_group_members(2, [])
	expect_eq(_lg(s, f[1], f[3].a), 0)
	expect_eq(LaunchGroups.member_keys(s.groups, 5), [b])
	s.free()


func test_rename_and_clear_name() -> void:
	var f := _fixture()
	var s: Node = f[0]
	s.set_launch_group_name(4, "  Work stuff ")
	expect_eq(s.launch_group_names(), {"4": "Work stuff"})
	s.set_launch_group_name(4, "")
	expect_eq(s.launch_group_names(), {})
	s.free()


func test_renumber_moves_and_swaps() -> void:
	var f := _fixture()
	var s: Node = f[0]
	var a := "%s:%s" % [f[1], f[3].a]
	var c := "%s:%s" % [f[1], f[3].c]
	s.create_launch_group("First", [a])
	s.create_launch_group("Second", [c])
	expect(s.renumber_launch_group(1, 2), "swap")
	expect_eq(_lg(s, f[1], f[3].a), 2)
	expect_eq(_lg(s, f[1], f[3].c), 1)
	expect_eq(s.launch_group_names(), {"1": "Second", "2": "First"})
	expect(s.renumber_launch_group(2, 7), "move to a free number")
	expect_eq(_lg(s, f[1], f[3].a), 7)
	expect_eq(s.launch_group_names(), {"1": "Second", "7": "First"})
	expect(not s.renumber_launch_group(7, 7))
	expect(not s.renumber_launch_group(0, 3))
	s.free()


func test_delete_unassigns_members_but_keeps_programs() -> void:
	var f := _fixture()
	var s: Node = f[0]
	s.create_launch_group("Gone", ["%s:%s" % [f[1], f[3].a], "%s:%s" % [f[1], f[3].b]])
	s.delete_launch_group(1)
	expect_eq(s.launch_group_names(), {})
	expect_eq(_lg(s, f[1], f[3].a), 0)
	expect_eq(s.find_group(f[1]).items.size(), 3, "programs are not deleted")
	expect_eq(LaunchGroups.defined_groups(s.groups, s.launch_group_names()), [])
	s.free()


func test_names_survive_restart_and_export_import() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var g: String = s.add_group("Work")
	var i: String = s.add_item(g, {"name": "a", "path": "/bin/a", "icon": "default", "workingDir": ""})
	s.create_launch_group("Morning", ["%s:%s" % [g, i]])
	s.flush()
	var export_path := dir + "/export.json"
	expect(s.export_to(export_path))
	s.free()
	var again := _open(dir)
	expect_eq(again.launch_group_names(), {"1": "Morning"}, "restart")
	again.delete_launch_group(1)
	again.flush()
	var r: Dictionary = again.import_from(export_path)
	expect(r.success, "import")
	expect_eq(again.launch_group_names(), {"1": "Morning"}, "import brings names back")
	expect_eq(int(again.groups[0].items[0].launchGroup), 1)
	again.free()


func test_bad_names_are_repaired_not_fatal() -> void:
	var ctx := {"normalized": 0}
	var s := Migration.normalize_settings({"launchGroupNames": {"2": "Ok", "x": "bad key", "3": 7, "0": "zero"}}, ctx)
	expect_eq(s.launchGroupNames, {"2": "Ok"})
	expect(ctx.normalized > 0)
	expect(Validators.is_launch_group_names({"1": "A", "12": "B"}))
	expect(not Validators.is_launch_group_names({"01": "A"}))
	expect(not Validators.is_launch_group_names({"1": ""}))
	expect(not Validators.is_launch_group_names([]))


func test_import_keeps_good_names_from_a_partly_bad_file() -> void:
	var dir := _tmp()
	var s := _open(dir)
	var data: Dictionary = s.persistence.get_all_data()
	data.settings["launchGroupNames"] = {"1": "Keep", "nope": "Drop"}
	var path := dir + "/partly-bad.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(Jsonx.stringify(data))
	f.close()
	var r: Dictionary = s.import_from(path)
	expect(r.success)
	expect_eq(s.launch_group_names(), {"1": "Keep"})
	s.free()


func test_data_transfer_wording() -> void:
	expect_eq(DataTransfer.default_export_name({"year": 2026, "month": 3, "day": 9}), "program-manager-export-2026-03-09.json")
	expect_eq(DataTransfer.export_status({"success": true, "path": "/home/x/out.json"}), "Exported everything to out.json.")
	expect_eq(DataTransfer.export_status({"success": false, "canceled": true}), "")
	expect_eq(DataTransfer.import_status({"success": false, "error": "Canceled"}), "")
	expect_eq(DataTransfer.import_status({"success": false, "error": "Invalid file format"}), "Invalid file format")
	expect(DataTransfer.import_status({"success": true}).begins_with("Imported everything."))
