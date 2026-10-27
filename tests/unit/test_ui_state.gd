extends TestCase

func test_dialog_and_selection_state() -> void:
	var ui: Node = load("res://src/core/ui_state.gd").new()
	ui.open_dialog("confirm", {"title": "x"})
	expect_eq(ui.active_dialog, "confirm")
	expect_eq(ui.dialog_data.title, "x")
	ui.close_dialog()
	expect_eq(ui.active_dialog, "")
	ui.set_selected_item("i", "g")
	ui.set_win31_selection({"kind": "item", "groupId": "g", "itemId": "i"})
	ui.clear_selection()
	expect_eq(ui.selected_item_id, "")
	expect_eq(ui.win31_selection, {})
	ui.toggle_quick_search()
	expect(ui.quick_search_open)
	ui.toggle_quick_search()
	expect(not ui.quick_search_open)
	ui.free()


func test_launch_feedback_flow() -> void:
	var ui: Node = load("res://src/core/ui_state.gd").new()
	ui.begin_launch_feedback(2, 5)
	expect_eq(ui.launch_feedback.status, "launching")
	ui.update_launch_feedback(1, 0)
	expect_eq(ui.launch_feedback.currentGroup, 1)
	ui.finish_launch_feedback(1)
	expect_eq(ui.launch_feedback.status, "error")
	expect_eq(ui.launch_feedback.completedGroups, 2)
	ui.hide_launch_feedback()
	expect_eq(ui.launch_feedback.visible, false)
	ui.free()


func test_mdi_window_stacking() -> void:
	var mdi: Node = load("res://src/core/mdi_state.gd").new()
	mdi.open_window("a")
	mdi.open_window("b")
	expect_eq(mdi.active_window_id, "b")
	mdi.open_window("a")  # focuses, no duplicate
	expect_eq(mdi.windows.size(), 2)
	expect_eq(mdi.active_window_id, "a")
	expect(mdi.windows[0].zIndex > mdi.windows[1].zIndex, "a raised above b")
	mdi.close_window("a")
	expect_eq(mdi.active_window_id, "b")
	mdi.close_window("b")
	expect_eq(mdi.active_window_id, "")
	mdi.free()
