extends TestCase
## End to end: the real Mac shell, mounted at 640x480 with the ProgramStore autoload on a scratch folder, runs
## File > Export All… and File > Import All… through its own menu bar, pop-up menu and confirm dialog (clicked
## with injected mouse events through the automation ids). Platform.dialog_provider hands back the file path.
## Checks the written JSON (programs, a sticky note, launch group names, settings), that Import All brings
## changed data back, that Platform.import_finished fires and that the shell no longer shows its own result
## (the host does). The autoloads are restored afterwards.

const SHELL_SCRIPT := preload("res://src/shells/mac/mac_shell.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _tmp() -> String:
	var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	var d := "%s/pm-mac-e2e-%d-%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _use_scratch_store() -> Dictionary:
	var saved := {"groups": ProgramStore.groups.duplicate(true), "settings": ProgramStore.settings.duplicate(true),
		"persistence": ProgramStore.persistence, "provider": Platform.dialog_provider}
	ProgramStore.init_store(_tmp())
	return saved


func _restore(saved: Dictionary) -> void:
	Platform.dialog_provider = saved.provider
	ProgramStore.flush()
	ProgramStore.persistence = saved.persistence
	ProgramStore.groups = saved.groups
	ProgramStore.settings = saved.settings
	ProgramStore.groups_changed.emit()
	ProgramStore.settings_changed.emit()


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


var _old_root_size := Vector2i.ZERO


func _unmount(shell: MacShell) -> void:
	shell.free()
	if _old_root_size != Vector2i.ZERO:
		_tree().root.size = _old_root_size


func _mount() -> MacShell:
	# the headless window is 64x64; injected clicks only reach controls inside the window
	_old_root_size = _tree().root.size
	_tree().root.size = Vector2i(640, 480)
	var shell: MacShell = SHELL_SCRIPT.new()
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	shell.on_activate()
	return shell


## The dialogs open in the shell's dialog layer (the topmost one is visible).
func _dialogs(shell: MacShell) -> Array:
	return shell.dialog_layer.get_children().filter(func(c): return c is MacDialog and not c.is_queued_for_deletion())


func _labels_of(d: MacDialog) -> String:
	var out := []
	for c in d.find_children("*", "MacLabel", true, false):
		out.append(String(c.text))
	return "\n".join(out)


func _menu_command(a: Automation, menu: String, label: String) -> void:
	await a.click_id("mac.menu:" + menu)
	await _frames(2)
	expect(a.has("mac.popup-item:" + label), "%s menu offers %s" % [menu, label])
	await a.click_id("mac.popup-item:" + label)
	await _frames(3)


func _item_named(gid: String, name: String) -> Dictionary:
	for it in ProgramStore.find_group(gid).get("items", []):
		if String(it.name) == name:
			return it
	return {}


func test_export_all_and_import_all_through_the_mac_menus() -> void:
	var saved := _use_scratch_store()
	var dir := _tmp()
	var path := dir.path_join("everything.json")
	var requests := []
	Platform.dialog_provider = func(request: Dictionary) -> PackedStringArray:
		requests.append(request)
		return PackedStringArray([path])
	var main: String = ProgramStore.add_group("Main")
	var calc: String = ProgramStore.add_item(main, {"name": "Calculator", "path": "/usr/bin/calc", "icon": "default",
		"workingDir": "", "launchGroup": 1})
	ProgramStore.add_item(main, {"name": "News", "path": "https://example.com/", "icon": "network", "workingDir": ""})
	var note: String = ProgramStore.add_note(main, "Shopping", "milk\neggs", "pink")
	ProgramStore.set_launch_group_name(1, "Morning")
	ProgramStore.update_settings({"launchDelay": 750})
	ProgramStore.flush()
	var shell := _mount()
	await _frames(3)
	var a := Automation.new(_tree())

	# ---- Export All…
	await _menu_command(a, "File", "Export All…")
	await _frames(2)
	expect_eq(requests.size(), 1)
	expect_eq(String(requests[0].get("mode", "")), "save")
	expect_eq(String(requests[0].get("title", "")), DataTransfer.EXPORT_TITLE)
	expect(FileAccess.file_exists(path), "Export All wrote the file")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(parsed is Dictionary, "the export is a JSON object")
	if not parsed is Dictionary:
		_unmount(shell)
		_restore(saved)
		return
	var exported: Dictionary = parsed
	var groups: Array = exported.get("groups", [])
	expect_eq(groups.size(), 1)
	var items: Array = groups[0].get("items", []) if groups.size() > 0 else []
	expect_eq(items.map(func(i): return String(i.name)), ["Calculator", "News", "Shopping"])
	var by_name := {}
	for it in items:
		by_name[String(it.name)] = it
	expect_eq(int(by_name.get("Calculator", {}).get("launchGroup", 0)), 1)
	expect_eq(String(by_name.get("News", {}).get("path", "")), "https://example.com/")
	var exported_note: Dictionary = by_name.get("Shopping", {})
	expect_eq(String(exported_note.get("kind", "")), Notes.KIND)
	expect_eq(String(exported_note.get("note", "")), "milk\neggs")
	expect_eq(String(exported_note.get("noteColor", "")), "pink")
	var settings: Dictionary = exported.get("settings", {})
	expect_eq(settings.get("launchGroupNames", {}), {"1": "Morning"})
	expect_eq(int(settings.get("launchDelay", 0)), 750)
	# the shell reports the export itself (it is still mounted)
	var after_export := _dialogs(shell)
	expect_eq(after_export.size(), 1, "one result alert")
	if after_export.size() == 1:
		expect(_labels_of(after_export[0]).contains("Exported everything to everything.json."), _labels_of(after_export[0]))
	await a.click_id("mac.dialog.button:OK")
	await _frames(2)
	expect_eq(_dialogs(shell).size(), 0, "OK dismissed the alert")

	# ---- change everything
	ProgramStore.delete_item(main, note)
	ProgramStore.update_item(main, calc, {"launchGroup": 0, "name": "Abacus"})
	ProgramStore.update_group(main, {"name": "Changed"})
	ProgramStore.set_launch_group_name(1, "")
	ProgramStore.update_settings({"launchDelay": 100})
	await _frames(2)
	expect(_item_named(main, "Shopping").is_empty())

	# ---- Import All…
	var finished := []
	var on_finished := func(result: Dictionary): finished.append(result)
	Platform.import_finished.connect(on_finished)
	await _menu_command(a, "File", "Import All…")
	var confirm := _dialogs(shell)
	expect_eq(confirm.size(), 1, "Import All asks first")
	if confirm.size() == 1:
		expect(_labels_of(confirm[0]).contains("Importing replaces all your program groups"), _labels_of(confirm[0]))
	expect(a.has("mac.dialog.button:Cancel"), "the confirm has Cancel")
	await a.click_id("mac.dialog.button:OK")
	await _frames(4)
	Platform.import_finished.disconnect(on_finished)
	expect_eq(requests.size(), 2)
	if requests.size() == 2:
		expect_eq(String(requests[1].get("mode", "")), "open")
		expect_eq(String(requests[1].get("title", "")), DataTransfer.IMPORT_TITLE)
	expect_eq(finished.size(), 1, "Platform.import_finished fired once")
	if finished.size() == 1:
		expect(finished[0].get("success", false), str(finished[0]))
	expect_eq(_dialogs(shell).size(), 0, "the shell shows no result of its own: the host does")
	expect_eq(ProgramStore.groups.size(), 1)
	var g: Dictionary = ProgramStore.groups[0] if ProgramStore.groups.size() > 0 else {}
	expect_eq(String(g.get("name", "")), "Main")
	var back_note := _item_named(String(g.get("id", "")), "Shopping")
	expect(Notes.is_note(back_note), "the note is back")
	expect_eq(String(back_note.get("note", "")), "milk\neggs")
	expect_eq(String(back_note.get("noteColor", "")), "pink")
	expect_eq(int(_item_named(String(g.get("id", "")), "Calculator").get("launchGroup", 0)), 1)
	expect_eq(ProgramStore.launch_group_names(), {"1": "Morning"})
	expect_eq(int(ProgramStore.settings.get("launchDelay", 0)), 750)
	# the shell follows the reloaded data: the Special menu lists the named launch group again
	await a.click_id("mac.menu:Special")
	await _frames(2)
	expect(a.has("mac.popup-item:" + LaunchGroups.launch_label(1, 1, ProgramStore.launch_group_names())), "Special lists Group 1: Morning")
	await a.key(KEY_ESCAPE)
	await _frames(2)
	_unmount(shell)
	_restore(saved)


func test_import_all_cancel_changes_nothing() -> void:
	var saved := _use_scratch_store()
	var asked := []
	Platform.dialog_provider = func(request: Dictionary) -> PackedStringArray:
		asked.append(request)
		return PackedStringArray()
	var main: String = ProgramStore.add_group("Main")
	ProgramStore.add_note(main, "Keep", "me")
	var shell := _mount()
	await _frames(3)
	var a := Automation.new(_tree())
	var finished := []
	var on_finished := func(result: Dictionary): finished.append(result)
	Platform.import_finished.connect(on_finished)
	await _menu_command(a, "File", "Import All…")
	await a.click_id("mac.dialog.button:Cancel")
	await _frames(2)
	expect_eq(asked.size(), 0, "Cancel in the confirm never opens the file chooser")
	expect_eq(finished.size(), 0)
	# OK, then cancel the file chooser: nothing imported, nothing to report
	await _menu_command(a, "File", "Import All…")
	await a.click_id("mac.dialog.button:OK")
	await _frames(3)
	expect_eq(asked.size(), 1)
	expect_eq(finished.size(), 0, "a canceled file chooser does not finish an import")
	expect_eq(_dialogs(shell).size(), 0)
	expect(Notes.is_note(_item_named(main, "Keep")))
	Platform.import_finished.disconnect(on_finished)
	_unmount(shell)
	_restore(saved)
