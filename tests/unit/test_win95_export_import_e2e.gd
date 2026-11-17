extends TestCase
## End to end: the real Win95 shell, mounted at 640x480 on a scratch store, runs Start > Settings >
## Export All... and Import All... with clicks injected through the viewport (Automation). The file
## chooser is Platform.dialog_provider handing back a temp path. Checks the written JSON (programs,
## a sticky note, launch group names, settings), changes the data, imports through the confirm box's
## real OK button, and checks the data came back, Platform.import_finished fired, and that the shell
## shows no result box of its own (the host shows it, see main.gd _on_import_finished).

const SHELL_SCRIPT := preload("res://src/shells/win95/win95_shell.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w95-e2e-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _modals(shell: Control) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is Win95Modal and not c.is_queued_for_deletion())


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


## Start > Settings > <label>, clicked the way a user does (press and release on each row).
func _settings_command(a: Automation, label: String) -> void:
	await a.click_id("w95.start-button")
	await _frames(2)
	await a.click_id("w95.start-command:Settings")
	await _frames(2)
	await a.click_id("w95.start-item:1:" + label)
	await _frames(3)


func test_export_all_then_import_all_through_the_start_menu() -> void:
	# ---- scratch store and autoload state (restored at the end)
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence, "provider": Platform.dialog_provider}
	var dir := _tmp()
	ProgramStore.init_store(dir.path_join("store"))
	var gid := ProgramStore.add_group("Main")
	var prog_id := ProgramStore.add_item(gid, {"name": "Calculator", "path": "/usr/bin/calc", "icon": "application", "workingDir": "", "launchGroup": 1})
	var note_id := ProgramStore.add_note(gid, "Shopping", "milk\neggs", "pink")
	ProgramStore.update_settings({"launchGroupNames": {"1": "Morning"}, "launchDelay": 750})
	var export_path := dir.path_join("everything.json")
	var requests := []
	Platform.dialog_provider = func(request: Dictionary) -> String:
		requests.append(request)
		return export_path
	var finished := []
	var on_finished := func(result: Dictionary): finished.append(result)
	Platform.import_finished.connect(on_finished)
	# ---- the real shell at 640x480 (the host is only used for its tree here)
	var host := Node.new()
	_tree().root.add_child(host)
	var shell: Win95Shell = SHELL_SCRIPT.new()
	shell.host = host
	shell.position = Vector2.ZERO
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	await _frames(2)
	var a := Automation.new(_tree())

	# ---- Export All
	await _settings_command(a, "Export All...")
	await _frames(3)
	expect_eq(requests.size(), 1)
	expect_eq(String(requests[0].get("mode", "")), "save")
	expect_eq(String(requests[0].get("title", "")), DataTransfer.EXPORT_TITLE)
	expect(FileAccess.file_exists(export_path), "the file was written")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(export_path))
	var group: Dictionary = data.groups.filter(func(g): return g.id == gid)[0]
	var prog: Dictionary = group.items.filter(func(i): return i.id == prog_id)[0]
	var note: Dictionary = group.items.filter(func(i): return i.id == note_id)[0]
	expect_eq([prog.name, prog.path, int(prog.launchGroup)], ["Calculator", "/usr/bin/calc", 1])
	expect_eq([note.kind, note.name, note.note, note.noteColor], [Notes.KIND, "Shopping", "milk\neggs", "pink"])
	expect_eq(data.settings.launchGroupNames, {"1": "Morning"})
	expect_eq(int(data.settings.launchDelay), 750)
	var boxes := _modals(shell)
	expect_eq(boxes.map(func(m): return m.title), [DataTransfer.EXPORT_TITLE], "Export All reports where it saved")
	if boxes.size() > 0:
		await a.click_id("w95.dialog.button:OK")
		await _frames(2)
	expect(_modals(shell).is_empty())

	# ---- change everything that was exported
	ProgramStore.update_group(gid, {"name": "Renamed"})
	ProgramStore.delete_item(gid, note_id)
	ProgramStore.update_item(gid, prog_id, {"launchGroup": 0})
	ProgramStore.update_settings({"launchGroupNames": {}, "launchDelay": 100})
	expect(ProgramStore.locate_item(note_id).is_empty())

	# ---- Import All: the confirm box, its real OK button, then the chooser
	await _settings_command(a, "Import All...")
	boxes = _modals(shell)
	expect_eq(boxes.map(func(m): return m.title), [DataTransfer.IMPORT_TITLE], "Import All asks first")
	expect_eq(requests.size(), 1, "nothing is picked before OK")
	await a.click_id("w95.dialog.button:OK")
	await _frames(4)
	expect_eq(requests.size(), 2)
	expect_eq(String(requests[1].get("mode", "")), "open")
	expect_eq(finished.size(), 1, "Platform.import_finished fired")
	if finished.size() > 0:
		expect(finished[0].get("success", false), str(finished[0]))
	expect_eq(ProgramStore.find_group(gid).name, "Main")
	var back := ProgramStore.locate_item(note_id)
	expect(not back.is_empty(), "the note is back")
	if not back.is_empty():
		expect_eq([back.item.name, back.item.note, back.item.noteColor], ["Shopping", "milk\neggs", "pink"])
	expect_eq(int(ProgramStore.find_item(gid, prog_id).get("launchGroup", 0)), 1)
	expect_eq(ProgramStore.launch_group_names(), {"1": "Morning"})
	expect_eq(int(ProgramStore.settings.launchDelay), 750)
	expect(_modals(shell).is_empty(), "the shell shows no result box of its own; the host does")

	# ---- Import All, Cancel: nothing is picked or imported
	await _settings_command(a, "Import All...")
	await a.click_id("w95.dialog.button:Cancel")
	await _frames(2)
	expect_eq(requests.size(), 2)
	expect_eq(finished.size(), 1)

	# ---- restore the autoloads
	Platform.import_finished.disconnect(on_finished)
	Platform.dialog_provider = saved.provider
	shell.queue_free()
	host.queue_free()
	await _frames(1)
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
