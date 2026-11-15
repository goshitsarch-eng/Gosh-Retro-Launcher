extends TestCase
## Win95TextInput inner LineEdit geometry. Sized before it joins the tree (Find's "Named" field, the
## Create Shortcut wizard) the LineEdit used to keep the default theme's 31px minimum height, so
## the text and caret sat ~8px low and were clipped by the 21px box.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_sized_before_entering_tree_lays_out_inner_edit() -> void:
	var t := Win95TextInput.new()
	t.text = "*"
	t.size = Vector2(257, 21)
	_tree().root.add_child(t)
	expect_eq(t.edit.position, Vector2(5, 3))
	expect_eq(t.edit.size, Vector2(247, 15))
	t.free()


func test_resized_while_detached_is_relaid_out_on_reentry() -> void:
	var t := Win95TextInput.new()
	_tree().root.add_child(t)
	await _tree().process_frame
	_tree().root.remove_child(t)
	t.size = Vector2(200, 21)
	_tree().root.add_child(t)
	await _tree().process_frame
	expect_eq(t.edit.size, Vector2(190, 15))
	t.free()


func test_setting_text_puts_caret_after_it() -> void:
	var t := Win95TextInput.new()
	t.text = "*"
	expect_eq(t.edit.caret_column, 1)
	t.text = "notepad.exe"
	expect_eq(t.edit.caret_column, 11)
	t.free()


func test_resized_in_tree_tracks_width() -> void:
	var t := Win95TextInput.new()
	_tree().root.add_child(t)
	t.size = Vector2(120, 21)
	expect_eq(t.edit.size, Vector2(110, 15))
	t.free()
