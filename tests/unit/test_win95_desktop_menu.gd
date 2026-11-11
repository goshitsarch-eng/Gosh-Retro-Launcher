extends TestCase
## Win95 desktop context menu commands that differ from the folder-window flows.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_new_folder_creates_group_and_opens_its_properties() -> void:
	var saved_groups := ProgramStore.groups.duplicate(true)
	var shell := Win95Shell.new()
	shell.host = _tree().root
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	await _tree().process_frame
	var before := ProgramStore.groups.size()
	var entry: Dictionary = {}
	for e in shell.desktop._desktop_menu():
		if e.get("id", "") == "new-folder":
			entry = e
	expect(not entry.is_empty())
	entry.onSelect.call()
	await _tree().process_frame
	# Win95Desktop.tsx: addGroup('New Folder') then the group property sheet (no name prompt).
	expect_eq(ProgramStore.groups.size(), before + 1)
	expect_eq(ProgramStore.groups[-1].name, "New Folder")
	var titles := []
	for m in shell.find_children("*", "Win95Modal", true, false):
		titles.append(String(m.get("title")))
	expect(titles.has("New Folder Properties"), "got: %s" % str(titles))
	shell.queue_free()
	await _tree().process_frame
	ProgramStore.groups = saved_groups
