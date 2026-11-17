extends TestCase
## Export All and Import All through Godot's own file chooser (the fallback when the system has none),
## clicked and typed into like a person would: no dialog_provider. The chooser must open embedded in
## the launcher window, fit inside it, and take ordinary clicks and keys.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-fdlg-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Root point at the centre of `c`, a control inside the embedded chooser.
func _point(dlg: Window, c: Control) -> Vector2:
	return Vector2(dlg.position) + c.get_global_rect().get_center()


func _wait_dialog(a: Automation) -> FileDialog:
	for i in 60:
		if Platform.fallback_dialog and Platform.fallback_dialog.visible:
			await a.frames(2)
			return Platform.fallback_dialog
		await a.frames(1)
	return null


## Click the file name box, replace its text by typing, then click the OK (Save/Open) button.
func _choose(a: Automation, dlg: FileDialog, dir: String, file_name: String) -> void:
	dlg.current_dir = dir
	await a.frames(2)
	var field := dlg.get_line_edit()
	await a.click(_point(dlg, field))
	await a.frames(1)
	field.select_all()
	await a.type_text(file_name)
	await a.frames(1)
	await a.click(_point(dlg, dlg.get_ok_button()))
	await a.frames(3)


## Every visible Tree / ItemList in the chooser (its file list, plus the favourites and recent lists).
func _lists(n: Node, out: Array = []) -> Array:
	for c in n.get_children(true):
		if (c is Tree or c is ItemList) and (c as Control).is_visible_in_tree():
			out.append(c)
		_lists(c, out)
	return out


## Where `file_name` is drawn in one of the chooser's lists: [list, point inside it], or [].
func _find_listed(dlg: FileDialog, file_name: String) -> Array:
	var lists := _lists(dlg)
	# The file list is the biggest one; "Recent" may also show the file, but picking it there only
	# navigates.
	lists.sort_custom(func(x, y): return x.size.x * x.size.y > y.size.x * y.size.y)
	for list in lists:
		if list is ItemList:
			for i in (list as ItemList).item_count:
				if (list as ItemList).get_item_text(i) == file_name:
					return [list, (list as ItemList).get_item_rect(i).get_center()]
		elif (list as Tree).get_root():
			var it := (list as Tree).get_root().get_first_child()
			while it:
				if it.get_text(0) == file_name:
					return [list, (list as Tree).get_item_area_rect(it).get_center()]
				it = it.get_next()
	return []


## Open mode: click the file in the list, then click Open.
func _pick_listed(a: Automation, dlg: FileDialog, dir: String, file_name: String) -> void:
	dlg.current_dir = dir
	var hit := []
	for i in 20:
		await a.frames(1)
		hit = _find_listed(dlg, file_name)
		if not hit.is_empty():
			break
	expect(not hit.is_empty(), "%s is listed" % file_name)
	if hit.is_empty():
		return
	var list: Control = hit[0]
	# Click the file, then Open, as a person does.
	await a.click(Vector2(dlg.position) + list.get_global_rect().position + hit[1])
	await a.frames(2)
	expect(not dlg.get_ok_button().disabled, "clicking the file enables Open")
	await a.click(_point(dlg, dlg.get_ok_button()))
	await a.frames(3)


func test_export_and_import_through_the_fallback_chooser() -> void:
	var tree := _tree()
	var old_size := tree.root.size
	tree.root.size = Vector2i(640, 480)
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence, "provider": Platform.dialog_provider}
	var dir := _tmp()
	ProgramStore.init_store(_tmp())
	var g: String = ProgramStore.add_group("Desk")
	ProgramStore.add_item(g, {"name": "Calc", "path": "/bin/calc", "icon": "default", "workingDir": ""})
	ProgramStore.add_note(g, "Todo", "call mum", "pink")
	ProgramStore.create_launch_group("Morning")
	ProgramStore.flush()
	Platform.dialog_provider = Callable()
	Platform.allow_fallback_dialog_headless = true
	var a := Automation.new(tree)
	var embedding_before := tree.root.gui_embed_subwindows

	var export := {}
	var run_export := func(): export.merge(await Platform.export_all()); export["done"] = true
	run_export.call()
	var dlg := await _wait_dialog(a)
	expect(dlg != null, "the fallback chooser opened")
	if dlg:
		expect(dlg.is_embedded(), "embedded in the launcher window")
		expect(Rect2(tree.root.get_visible_rect()).encloses(Rect2(Vector2(dlg.position) - Vector2(0, 18), Vector2(dlg.size) + Vector2(0, 18))),
			"fits inside the window: %s at %s" % [dlg.size, dlg.position])
		expect_eq(dlg.title, DataTransfer.EXPORT_TITLE)
		expect(dlg.theme != null, "uses the launcher look, not the editor theme")
		await _choose(a, dlg, dir, "everything.json")
	for i in 30:
		if export.get("done", false):
			break
		await a.frames(1)
	expect(export.get("success", false), "export finished: %s" % str(export))
	var text := FileAccess.get_file_as_string(dir.path_join("everything.json"))
	expect(text.contains("call mum") and text.contains("Morning"), "the file holds the note and launch group names")

	ProgramStore.delete_group(g)
	ProgramStore.flush()
	var finished := []
	var on_done := func(r: Dictionary): finished.append(r)
	Platform.import_finished.connect(on_done)
	var imported := {}
	var run_import := func(): imported.merge(await Platform.import_data()); imported["done"] = true
	run_import.call()
	dlg = await _wait_dialog(a)
	if dlg:
		dlg.get_line_edit().clear()
		await a.frames(2)
		expect(dlg.get_ok_button().disabled, "Open is greyed out while no file name is given")
	expect(dlg != null, "the open chooser appeared")
	if dlg:
		expect_eq(dlg.title, DataTransfer.IMPORT_TITLE)
		await _pick_listed(a, dlg, dir, "everything.json")
	for i in 30:
		if imported.get("done", false):
			break
		await a.frames(1)
	expect(imported.get("success", false), "import finished: %s" % str(imported))
	expect_eq(finished.size(), 1, "import_finished fired once")
	expect_eq(ProgramStore.groups.size(), 1, "the deleted group is back")
	var note_back := false
	for it in ProgramStore.groups[0].items if ProgramStore.groups.size() > 0 else []:
		note_back = note_back or (Notes.is_note(it) and it.note == "call mum")
	expect(note_back, "the note is back")
	Platform.import_finished.disconnect(on_done)

	var canceled := {}
	var run_cancel := func(): canceled.merge(await Platform.export_all()); canceled["done"] = true
	run_cancel.call()
	dlg = await _wait_dialog(a)
	if dlg:
		await a.click(_point(dlg, dlg.get_cancel_button()))
	for i in 30:
		if canceled.get("done", false):
			break
		await a.frames(1)
	expect(canceled.get("canceled", false), "Cancel gives back nothing: %s" % str(canceled))
	expect_eq(tree.root.gui_embed_subwindows, embedding_before, "embedding is put back afterwards")

	Platform.allow_fallback_dialog_headless = false
	Platform.dialog_provider = saved.provider
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	tree.root.size = old_size
