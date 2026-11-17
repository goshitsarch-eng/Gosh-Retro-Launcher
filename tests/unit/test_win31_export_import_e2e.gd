extends TestCase
## End to end through the real WfW shell: File > Export All... writes the whole launcher (programs,
## a sticky note, launch group names, settings) to the file the chooser returns, and File > Import
## All... asks first, then (after the dialog's real OK button) brings it all back and reports the
## result through Platform.import_finished for the host to show; the shell shows no box of its own.
## Input is real: menu and button clicks are injected into the viewport (Automation). The file
## chooser is Platform.dialog_provider. The ProgramStore, Platform and UIState autoloads are restored.

const SHELL_SCRIPT := preload("res://src/shells/win31/win31_shell.gd")


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-w31-e2e-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 4) -> void:
	for i in n:
		await _tree().process_frame


func _use_scratch_store() -> Dictionary:
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"profiles": ProgramStore.workspace_profiles.duplicate(true), "persistence": ProgramStore.persistence}
	ProgramStore.init_store(_tmp())
	return saved


func _restore_store(saved: Dictionary) -> void:
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	ProgramStore.workspace_profiles = saved.profiles


## Opens the File menu and clicks `label` with injected mouse events, like a user.
func _file_menu(auto: Automation, label: String) -> void:
	await auto.click_id("wfw.menu:0")
	await _frames(2)
	expect(auto.has("wfw.popup-item:" + label), "File menu has " + label)
	await auto.click_id("wfw.popup-item:" + label)
	await _frames(4)


func _group_named(groups: Array, name: String) -> Dictionary:
	for g in groups:
		if String(g.name) == name:
			return g
	return {}


func test_export_all_and_import_all_through_the_file_menu() -> void:
	var saved := _use_scratch_store()
	var saved_provider: Callable = Platform.dialog_provider
	var file := _tmp().path_join("everything.json")
	var requests := []
	Platform.dialog_provider = func(request: Dictionary) -> String:
		requests.append(request.duplicate(true))
		return file
	var finished := []
	var on_finished := func(result: Dictionary): finished.append(result)
	Platform.import_finished.connect(on_finished)

	# Some data: a program in launch group 2 (named, with an "&"), a sticky note, a changed setting.
	var g: String = ProgramStore.add_group("Work")
	var prog: String = ProgramStore.add_item(g, {"name": "Editor", "path": "/usr/bin/vi", "icon": "default", "workingDir": ""})
	ProgramStore.update_item(g, prog, {"launchGroup": 2})
	var note: String = ProgramStore.add_note(g, "Todo", "buy & sell\nsecond line", "pink")
	ProgramStore.set_launch_group_name(2, "Morning & Mail")
	ProgramStore.update_settings({"launchDelay": 1300})
	ProgramStore.flush()

	var shell: Win31Shell = SHELL_SCRIPT.new()
	_tree().root.add_child(shell)
	shell.size = Vector2(640, 480)
	shell.on_activate()  # starts showing notices (not awaited: it only waits to play a sound)
	await _frames(4)
	var auto := Automation.new(_tree())

	# ---- File > Export All...
	await _file_menu(auto, "Export All...")
	await _frames(4)
	expect_eq(requests.size(), 1, "one file chooser")
	expect_eq(String(requests[0].get("mode", "")), "save")
	expect_eq(String(requests[0].get("title", "")), DataTransfer.EXPORT_TITLE)
	expect(FileAccess.file_exists(file), "the export file was written")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	expect(parsed is Dictionary, "the export is JSON")
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var work := _group_named(data.get("groups", []), "Work")
	expect(not work.is_empty(), "the program group is in the file")
	var names := []
	var exported_note := {}
	for it in work.get("items", []):
		names.append(String(it.name))
		if Notes.is_note(it):
			exported_note = it
	expect_eq(names, ["Editor", "Todo"])
	expect_eq(String(exported_note.get("note", "")), "buy & sell\nsecond line", "the note's text")
	expect_eq(String(exported_note.get("noteColor", "")), "pink")
	expect_eq(int(work.items[0].get("launchGroup", 0)), 2)
	expect_eq(data.get("settings", {}).get("launchGroupNames", {}), {"2": "Morning & Mail"}, "launch group names")
	expect_eq(int(data.get("settings", {}).get("launchDelay", 0)), 1300, "settings")
	expect(data.has("workspaceProfiles"))
	# The shell says where it went in its OK box; its real OK button closes it.
	expect_eq(UIState.active_dialog, "unavailable")
	expect(String(UIState.dialog_data.get("message", "")).contains("everything.json"), str(UIState.dialog_data))
	await auto.click_id("wfw.dialog.button:OK")
	await _frames(2)
	expect_eq(UIState.active_dialog, "")

	# ---- change everything
	ProgramStore.delete_item(g, note)
	ProgramStore.update_item(g, prog, {"name": "Changed", "launchGroup": 0})
	ProgramStore.set_launch_group_name(2, "Evening")
	ProgramStore.update_settings({"launchDelay": 2000})
	ProgramStore.add_group("Junk")
	ProgramStore.flush()

	# ---- File > Import All...: asks first; Cancel would do nothing, OK imports.
	await _file_menu(auto, "Import All...")
	expect_eq(UIState.active_dialog, "confirm", "Import All asks first")
	expect_eq(requests.size(), 1, "no file chooser before OK")
	await auto.click_id("wfw.dialog.button:OK")
	for i in 30:
		if not finished.is_empty():
			break
		await _tree().process_frame
	await _frames(4)
	expect_eq(requests.size(), 2, "the file chooser opened after OK")
	expect_eq(String(requests[1].get("mode", "")), "open")
	expect_eq(finished.size(), 1, "Platform.import_finished fired once")
	expect(finished.size() == 1 and finished[0].get("success", false), str(finished))
	var back := _group_named(ProgramStore.groups, "Work")
	expect(_group_named(ProgramStore.groups, "Junk").is_empty(), "the later group is gone")
	var back_names := []
	var back_note := {}
	for it in back.get("items", []):
		back_names.append(String(it.name))
		if Notes.is_note(it):
			back_note = it
	expect_eq(back_names, ["Editor", "Todo"], "programs and the note are back")
	expect_eq(String(back_note.get("note", "")), "buy & sell\nsecond line")
	expect_eq(ProgramStore.launch_group_names(), {"2": "Morning & Mail"})
	expect_eq(int(ProgramStore.settings.get("launchDelay", 0)), 1300)
	# The result box is the host's job (main.gd _on_import_finished); the shell adds none of its own.
	expect_eq(UIState.active_dialog, "", "no second message box from the shell")
	expect(shell._notices.is_empty(), "nothing queued by the shell")
	expect(not ProgramStore.list_backups().is_empty(), "the previous setup was backed up first")

	# ---- restore the autoloads
	Platform.import_finished.disconnect(on_finished)
	Platform.dialog_provider = saved_provider
	UIState.close_dialog()
	UIState.win31_selection = {}
	shell.free()
	_restore_store(saved)
