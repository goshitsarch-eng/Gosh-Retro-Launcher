extends TestCase
## End to end: the real BeShell at 640x480 on a scratch ProgramStore. Export All… and Import All… are
## driven through the real Deskbar menu with injected clicks; Platform.dialog_provider hands back a temp
## path instead of a file dialog. Checks the written JSON (programs, a note, launch group names,
## settings), changes everything, imports through the menu and the confirm dialog's real OK button,
## and checks the data came back, Platform.import_finished fired, and the shell itself shows no result
## (the host does). The autoloads are restored afterwards.

const SHELL_SCRIPT := preload("res://src/shells/be/be_shell.gd")


class StubHost extends Node:
	pass


var _requests: Array = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 3) -> void:
	for i in n:
		await _tree().process_frame


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-be-e2e-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _save_autoloads() -> Dictionary:
	return {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence, "provider": Platform.dialog_provider, "dark": BeTheme.dark}


func _restore_autoloads(saved: Dictionary) -> void:
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	Platform.dialog_provider = saved.provider
	BeTheme.dark = saved.dark


func _item_named(name: String) -> Dictionary:
	for g in ProgramStore.groups:
		for it in g.items:
			if String(it.name) == name:
				return it
	return {}


## Opens the Deskbar menu and clicks `label` in it (the menu scrolls to show the row first).
func _deskbar(auto: Automation, label: String) -> void:
	await auto.click_id("be.deskbar.logo")
	await _frames()
	expect(auto.has("be.popup-item:" + label), "Deskbar menu offers " + label)
	await auto.click_id("be.popup-item:" + label)
	await _frames()


func test_export_all_then_import_all_through_the_deskbar() -> void:
	var saved := _save_autoloads()
	var dir := _tmp()
	var path := dir.path_join("everything.json")
	ProgramStore.init_store(dir.path_join("store"))
	ProgramStore.update_settings({"shell": "be", "theme": "light", "launchDelay": 750,
		"launchGroupNames": {"1": "Morning", "3": "Writing"}})
	var work: String = ProgramStore.add_group("Work")
	var notes_group: String = ProgramStore.add_group("Notes")
	ProgramStore.add_item(work, {"name": "Editor", "path": "/usr/bin/editor", "icon": "terminal", "workingDir": "/tmp",
		"arguments": "--new", "launchGroup": 1})
	ProgramStore.add_item(work, {"name": "Docs", "path": "https://example.com/docs", "icon": "url", "workingDir": "", "launchGroup": 3})
	var note_id: String = ProgramStore.add_note(notes_group, "Plan", "ship it\nthen rest", "blue")
	ProgramStore.update_item(notes_group, note_id, {"launchGroup": 1})
	_requests = []
	Platform.dialog_provider = func(request: Dictionary) -> String:
		_requests.append(request)
		return path
	var finished := []
	var on_finished := func(r: Dictionary): finished.append(r)
	Platform.import_finished.connect(on_finished)

	var host := StubHost.new()
	_tree().root.add_child(host)
	var shell: BeShell = SHELL_SCRIPT.new()
	shell.host = host
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.on_activate()
	await _frames()
	var auto := Automation.new(_tree())

	# ---- Export All… from the Deskbar menu
	await _deskbar(auto, "Export All…")
	await _frames()
	expect_eq(_requests.size(), 1, "one save dialog")
	if _requests.size() > 0:
		expect_eq(_requests[0].mode, "save")
		expect_eq(_requests[0].title, DataTransfer.EXPORT_TITLE)
	expect(FileAccess.file_exists(path), "the file was written")
	expect(shell.toast.visible and shell.toast.text.contains("everything.json"), "be reports the export: " + shell.toast.text)
	var parsed := Jsonx.parse_checked(FileAccess.get_file_as_string(path))
	expect(parsed[0], "the export is JSON")
	var data: Dictionary = parsed[1] if parsed[0] else {}
	var groups: Array = data.get("groups", [])
	expect_eq(groups.map(func(g): return g.name), ["Work", "Notes"])
	var written := {}
	for g in groups:
		for it in g.items:
			written[String(it.name)] = it
	expect_eq(written.get("Editor", {}).get("path"), "/usr/bin/editor")
	expect_eq(written.get("Editor", {}).get("arguments"), "--new")
	expect_eq(written.get("Editor", {}).get("launchGroup"), 1)
	expect_eq(written.get("Docs", {}).get("path"), "https://example.com/docs")
	var wn: Dictionary = written.get("Plan", {})
	expect_eq([wn.get("kind"), wn.get("note"), wn.get("noteColor"), wn.get("launchGroup")], ["note", "ship it\nthen rest", "blue", 1],
		"the note travels with its text, colour and launch group")
	var ws: Dictionary = data.get("settings", {})
	expect_eq(ws.get("launchGroupNames"), {"1": "Morning", "3": "Writing"})
	expect_eq(ws.get("shell"), "be")
	expect_eq(int(ws.get("launchDelay", 0)), 750)

	# ---- change everything
	ProgramStore.update_group(work, {"name": "Job"})
	ProgramStore.delete_item(notes_group, note_id)
	ProgramStore.add_group("Scratch")
	ProgramStore.update_settings({"launchGroupNames": {"2": "Other"}, "launchDelay": 100, "theme": "dark"})
	await _frames()
	expect(_item_named("Plan").is_empty())
	expect(BeTheme.dark)

	# ---- Import All… through the menu and the confirm dialog's own OK button
	await _deskbar(auto, "Import All…")
	expect(auto.has("be.dialog.import-confirm"), "Import All asks first")
	expect_eq(_requests.size(), 1, "no file dialog before the confirm")
	expect_eq(finished, [], "nothing imported before OK")
	await auto.click_id("be.dialog.button:OK")
	await _frames(5)
	expect_eq(_requests.size(), 2, "one open dialog")
	if _requests.size() > 1:
		expect_eq(_requests[1].mode, "open")
		expect_eq(_requests[1].title, DataTransfer.IMPORT_TITLE)
	expect_eq(finished.size(), 1, "Platform.import_finished fired once")
	if finished.size() > 0:
		expect(finished[0].get("success", false), str(finished[0]))
	expect_eq(ProgramStore.groups.map(func(g): return g.name), ["Work", "Notes"], "the folders are back")
	var plan := _item_named("Plan")
	expect(Notes.is_note(plan), "the note is back")
	expect_eq([plan.get("note"), plan.get("noteColor"), plan.get("launchGroup")], ["ship it\nthen rest", "blue", 1])
	expect_eq(_item_named("Editor").get("arguments"), "--new")
	expect_eq(ProgramStore.launch_group_names(), {"1": "Morning", "3": "Writing"})
	expect_eq(int(ProgramStore.settings.launchDelay), 750)
	expect_eq(ProgramStore.settings.theme, "light")
	expect(not BeTheme.dark, "the shell followed the imported theme")
	# be no longer reports the import itself: the host shows the result after (re)mounting the shell
	expect(not auto.has("be.dialog.import-confirm"), "the confirm closed")
	expect_eq(shell.dialog_layer.get_child_count(), 0, "no be result alert")
	expect(not shell.toast.visible or not shell.toast.text.contains("Import"), "no be result toast")
	# the shell is still alive and shows the imported folders
	var icons: Array = shell.desktop.icon_list().map(func(i): return i.name)
	expect_eq(icons, ["Program Manager", "Work", "Notes"])
	# Launch Group 1 still holds the program and the note
	var buckets := LaunchGroups.collect_launch_groups(ProgramStore.groups)
	expect_eq(buckets[0].items.map(func(i): return i.name), ["Editor", "Plan"])

	Platform.import_finished.disconnect(on_finished)
	shell.free()
	host.free()
	_restore_autoloads(saved)
	expect(not Platform.dialog_provider.is_valid() or Platform.dialog_provider == saved.provider)
