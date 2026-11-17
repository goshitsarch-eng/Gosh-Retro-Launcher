extends TestCase
## BUG-004: the Create Shortcut wizard keeps its step fields alive across Back/Next by detaching
## them; the ones detached when the modal closes must be freed with it, not orphaned.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make_shell() -> Win95Shell:
	var shell := Win95Shell.new()
	shell.host = _tree().root
	shell.size = Vector2(640, 480)
	_tree().root.add_child(shell)
	return shell


func _open(shell: Win95Shell) -> Win95Modal:
	Win95DialogForms.open_wizard(shell, {})
	var modals := shell.find_children("*", "Win95Modal", true, false)
	return modals[-1] if modals.size() > 0 else null


func _fields(m: Win95Modal) -> Array:
	for c in m.body.get_children():
		if c.get("fields") is Array:
			return (c.get("fields") as Array).duplicate()
	return []


func _button(m: Win95Modal, label: String) -> Win95Button:
	for b in m.find_children("*", "Win95Button", true, false):
		if b.label == label:
			return b
	return null


func _close_and_settle(m: Win95Modal) -> void:
	m.close()
	await _tree().process_frame
	await _tree().process_frame


func test_cancel_on_step_one_frees_detached_step_two_fields() -> void:
	var shell := _make_shell()
	await _tree().process_frame
	var m := _open(shell)
	expect(m != null)
	var fields := _fields(m)
	expect_eq(fields.size(), 4, "command, name, program group and launch group")
	expect(fields[0].is_inside_tree(), "command is shown on step 1")
	expect(not fields[1].is_inside_tree() and not fields[2].is_inside_tree() and not fields[3].is_inside_tree(), "step-2 fields are detached")
	await _close_and_settle(m)
	for f in fields:
		expect(not is_instance_valid(f), "wizard field outlived the modal")
	shell.queue_free()
	await _tree().process_frame


func test_cancel_on_step_two_frees_detached_command_field() -> void:
	var saved_groups := ProgramStore.groups.duplicate(true)
	var shell := _make_shell()
	await _tree().process_frame
	var m := _open(shell)
	var fields := _fields(m)
	fields[0].text = "notepad.exe"
	_button(m, "&Next >").pressed.emit()
	expect(not fields[0].is_inside_tree(), "command is detached on step 2")
	expect(fields[1].is_inside_tree() and fields[2].is_inside_tree() and fields[3].is_inside_tree())
	await _close_and_settle(m)
	for f in fields:
		expect(not is_instance_valid(f), "wizard field outlived the modal")
	shell.queue_free()
	await _tree().process_frame
	ProgramStore.groups = saved_groups


func test_repeated_open_cancel_keeps_object_count_flat() -> void:
	var shell := _make_shell()
	await _tree().process_frame
	await _close_and_settle(_open(shell))  # warm-up (first-use caches)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 4:
		await _close_and_settle(_open(shell))
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	expect(after - before <= 1, "object count grew by %d over 4 cycles" % (after - before))
	shell.queue_free()
	await _tree().process_frame
