extends TestCase
## Sticky notes: the item model, validation and repair, opening through Platform (also inside a
## launch group), the StickyNote window saving what is typed, moved and closed, and .GRP export
## leaving notes out. Also the host's Import All notice.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")
const MAIN_SCRIPT := preload("res://src/app/main.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-notes-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Points the ProgramStore autoload at a scratch folder; returns the previous state to restore.
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


func test_make_note_is_a_valid_item() -> void:
	var n := Notes.make_note("  Shopping ", "milk\r\neggs", "pink")
	n["id"] = "n1"
	expect(Validators.is_valid_item(n))
	expect(Notes.is_note(n))
	expect_eq(n.note, "milk\neggs")
	expect_eq(n.noteColor, "pink")
	expect_eq(n.name, "Shopping")
	expect_eq(Notes.make_note("").name, "Note")
	expect_eq(Notes.make_note("x", "", "plaid").noteColor, Notes.DEFAULT_COLOR)
	expect(Validators.is_launch_item(n), "a note can be in a launch batch")


func test_validation_rejects_bad_note_fields() -> void:
	var base := Notes.make_note("x")
	base["id"] = "n"
	for bad in [{"kind": "widget"}, {"note": 3}, {"noteColor": "plaid"}, {"noteBounds": {"x": 0, "y": 0, "width": 0, "height": 5}},
			{"noteOpen": "yes"}, {"note": "x".repeat(Notes.MAX_TEXT + 1)}]:
		var it := base.duplicate()
		it.merge(bad, true)
		expect(not Validators.is_valid_item(it), str(bad))


func test_migration_keeps_good_note_fields_and_repairs_bad_ones() -> void:
	var ctx := {"normalized": 0}
	var good := Notes.make_note("a", "text", "blue")
	good.merge({"id": "n", "noteBounds": {"x": 5, "y": 6, "width": 120, "height": 90}, "noteOpen": true})
	var out: Dictionary = Migration._normalize_item(good, ctx)
	expect_eq(ctx.normalized, 0)
	for k in ["kind", "note", "noteColor", "noteBounds", "noteOpen"]:
		expect_eq(out[k], good[k], k)
	var bad := good.duplicate(true)
	bad.merge({"kind": "widget", "noteColor": 7, "noteOpen": "no"}, true)
	var fixed: Dictionary = Migration._normalize_item(bad, ctx)
	expect_eq(ctx.normalized, 3)
	expect(not fixed.has("kind") and not fixed.has("noteColor") and not fixed.has("noteOpen"))


func test_window_rect_keeps_the_note_on_screen() -> void:
	var area := Rect2i(0, 0, 640, 440)
	expect_eq(Notes.window_rect({}, area, 0), Rect2i(56, 64, 180, 140), "default")
	expect_eq(Notes.window_rect({}, area, 2).position, Vector2i(96, 104), "cascaded")
	var far := {"noteBounds": {"x": 900, "y": -50, "width": 5000, "height": 20}}
	var r := Notes.window_rect(far, area)
	expect(area.encloses(r), str(r))
	expect_eq(r.size, Vector2i(640, Notes.MIN_SIZE.y))


func test_preview_and_colors() -> void:
	expect_eq(Notes.preview({"note": "\n  first line  \nsecond"}), "first line")
	expect_eq(Notes.preview({"note": "abcdefghij"}, 5), "abcd…")
	expect_eq(Notes.color_choices()[0], {"id": "yellow", "label": "Yellow"})
	expect_eq(Notes.color_of({"noteColor": "nope"}), Notes.COLORS.yellow)


func test_platform_opens_notes_instead_of_launching() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "call mum")
	var opened := []
	var cb := func(i: String): opened.append(i)
	Platform.note_open_requested.connect(cb)
	var r: Dictionary = Platform.launch(ProgramStore.find_item(g, id))
	expect(r.success)
	var trimmed := {"id": id, "name": "Todo", "path": "", "icon": "note", "workingDir": ""}
	expect(Platform.launch(trimmed).success, "a trimmed payload is recognised by its id")
	var batch: Array = await Platform.launch_batch([ProgramStore.find_item(g, id)], 0)
	expect(batch[0].success, "a note in a launch group opens")
	expect_eq(opened, [id, id, id])
	Platform.note_open_requested.disconnect(cb)
	expect_eq(ProgramStore.add_note("missing-group", "x"), "")
	_restore_store(saved)


func test_grp_export_leaves_notes_out() -> void:
	var group := {"id": "g", "name": "Mixed", "icon": "folder", "items": [
		{"id": "a", "name": "Calc", "path": "calc.exe", "icon": "default", "workingDir": ""},
		Notes.make_note("Note")]}
	var r := Grp.serialize(group)
	expect(r.get("ok", false), str(r.get("error", "")))
	var back := Grp.parse(r.bytes)
	expect_eq(back.group.items.size(), 1)
	expect_eq(back.group.items[0].name, "Calc")


func test_sticky_note_saves_text_bounds_and_close() -> void:
	var saved := _use_scratch_store()
	var g: String = ProgramStore.add_group("Desk")
	var id: String = ProgramStore.add_note(g, "Todo", "first", "green")
	var shell := ShellBase.new()
	shell.size = Vector2(640, 480)
	(Engine.get_main_loop() as SceneTree).root.add_child(shell)
	var note := shell.open_note(id, false)
	expect(note != null)
	expect_eq(shell.open_note(id, false), note, "opening again reuses the window")
	expect_eq(note.text(), "first")
	expect_eq(note.paper, Notes.COLORS.green)
	expect(ProgramStore.find_item(g, id).noteOpen)
	expect_eq(note.auto_lookup("note.text:" + id), Rect2(note.global_position + Vector2(3, note.title_h + 2), note._edit.size))
	note.focus_text()
	expect_eq([note._edit.get_caret_line(), note._edit.get_caret_column()], [0, 5], "caret after the text")
	note.set_text_for_test("second")
	note._save_text()
	expect_eq(ProgramStore.find_item(g, id).note, "second")
	note.position = Vector2(100, 120)
	note._save_bounds()
	expect_eq(ProgramStore.find_item(g, id).noteBounds, {"x": 100, "y": 120, "width": 180, "height": 140})
	note.close()
	expect_eq(ProgramStore.find_item(g, id).noteOpen, false)
	await (Engine.get_main_loop() as SceneTree).process_frame
	expect_eq(shell.open_notes(), [])
	ProgramStore.update_note_quietly(id, {"noteOpen": true})
	shell.restore_open_notes()
	expect_eq(shell.open_notes().size(), 1, "an open note comes back")
	ProgramStore.delete_item(g, id)
	await (Engine.get_main_loop() as SceneTree).process_frame
	expect_eq(shell.open_notes(), [], "deleting the note closes its window")
	shell.free()
	_restore_store(saved)


func test_host_import_notice() -> void:
	expect_eq(MAIN_SCRIPT.import_notice({"success": false, "error": "Canceled"}), {})
	var ok: Dictionary = MAIN_SCRIPT.import_notice({"success": true, "normalized": 2})
	expect(String(ok.text).begins_with("Imported everything."))
	expect(String(ok.text).contains("2 stored values were repaired"))
	expect_eq(ok.alert, false)
	expect_eq(MAIN_SCRIPT.import_notice({"success": false, "error": "Invalid file format"}).alert, true)
