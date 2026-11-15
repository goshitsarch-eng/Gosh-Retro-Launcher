extends TestCase
## MacFolderView.is_name_sorted: the list view's Name-column shading is a sort indicator, shown only when the
## displayed (store) order really is name order, e.g. after Clean Up.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _es(names: Array) -> Array:
	var out := []
	for n in names:
		out.append({"id": n, "name": n})
	return out


func test_empty_and_single_are_sorted() -> void:
	expect(MacFolderView.is_name_sorted([]))
	expect(MacFolderView.is_name_sorted(_es(["Only"])))


func test_default_store_order_is_not_sorted() -> void:
	expect(not MacFolderView.is_name_sorted(_es(["File Manager", "Control Panel", "Print Manager", "ClipBook Viewer",
		"MS-DOS Prompt", "Windows Setup", "PIF Editor", "Read Me"])))


func test_case_and_natural_order() -> void:
	expect(MacFolderView.is_name_sorted(_es(["alpha", "Beta", "gamma"])))
	expect(MacFolderView.is_name_sorted(_es(["Item2", "Item10"])))
	expect(not MacFolderView.is_name_sorted(_es(["Item10", "Item2"])))
	expect(MacFolderView.is_name_sorted(_es(["Same", "same"])))


func test_clean_up_output_is_sorted() -> void:
	var s: Node = STORE_SCRIPT.new()
	s.groups = []
	s.settings = Types.default_settings()
	s.settings["saveSettingsOnExit"] = false
	var g: String = s.add_group("Main")
	for n in ["Zed", "item10", "Alpha", "Item2", "beta"]:
		s.add_item(g, {"name": n, "path": "/bin/x", "icon": "default", "workingDir": ""})
	expect(not MacFolderView.is_name_sorted(s.find_group(g).items))
	MacDialogLogic.clean_up(s, g)
	expect(MacFolderView.is_name_sorted(s.find_group(g).items))
	s.add_group("Aardvark")
	expect(not MacFolderView.is_name_sorted(s.groups))
	MacDialogLogic.clean_up(s, "")
	expect(MacFolderView.is_name_sorted(s.groups))
	s.free()
