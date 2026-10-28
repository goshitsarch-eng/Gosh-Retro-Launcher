extends TestCase
## Port of win95/__tests__/windowStore.test.ts. Uses a throwaway ProgramStore instance.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _group(id: String) -> Dictionary:
	return {
		"id": id, "name": id, "icon": "folder",
		"windowState": Types.default_window_state(),
		"shellWindowState": Types.create_shell_window_state(),
		"items": [],
	}


func _make() -> Array:
	var store: Node = STORE_SCRIPT.new()
	store.groups = [_group("one"), _group("two")]
	store.settings = Types.default_settings()
	store.settings["shell"] = "win95"
	store.settings["saveSettingsOnExit"] = false
	var windows := Win95WindowStore.new(store)
	return [store, windows]


func _minimized(store: Node, id: String) -> bool:
	return bool(Types.get_group_window_state(store.find_group(id), "win95").minimized)


func test_reactivates_a_single_group_instance_and_restores_it_before_focus() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_group("one")
	w.open_group("one")
	expect_eq(w.windows.size(), 1)
	store.update_group_window_state("one", {"minimized": true}, "win95")
	w.activate_desktop()
	w.focus_window("group:one")
	expect_eq(w.active_window_id, "")
	w.open_group("one")
	expect_eq(_minimized(store, "one"), false)
	expect_eq(w.active_window_id, "group:one")
	store.free()


func test_never_chooses_a_minimized_window_when_deactivating_or_closing() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_group("one")
	w.open_group("two")
	store.update_group_window_state("one", {"minimized": true}, "win95")
	w.deactivate_window("group:two")
	expect_eq(w.active_window_id, "")
	w.open_my_computer()
	w.close_window("my-computer")
	expect_eq(w.active_window_id, "group:two")
	store.free()


func test_opens_find_and_my_computer_as_independent_single_instance_tasks() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_find()
	w.open_find()
	w.open_my_computer()
	w.open_my_computer()
	expect_eq(w.windows.map(func(e): return e.id), ["find", "my-computer"])
	expect_eq(w.find_entry("find").systemBounds, {"x": 96, "y": 58, "width": 439, "height": 237})
	store.free()


func test_routes_one_shot_move_size_requests_to_the_target_id() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_my_computer()
	w.request_window_command("my-computer", "size")
	var request := w.requested_command
	expect_eq(request.id, "my-computer")
	expect_eq(request.command, "size")
	w.clear_window_command(int(request.nonce))
	expect_eq(w.requested_command, {})
	store.free()


func test_focus_raises_z_order_and_close_activates_the_next_visible_window() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_group("one")
	w.open_group("two")
	w.focus_window("group:one")
	expect_eq(w.active_window_id, "group:one")
	expect(w.find_entry("group:one").zIndex > w.find_entry("group:two").zIndex)
	w.close_window("group:one")
	expect_eq(w.active_window_id, "group:two")
	w.close_window("group:two")
	expect_eq(w.active_window_id, "")
	expect_eq(w.by_z().size(), 0)
	store.free()
