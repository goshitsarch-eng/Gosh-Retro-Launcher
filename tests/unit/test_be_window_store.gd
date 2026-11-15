extends TestCase
## BeWindowStore + BeMenuState: window lifecycle, z-order, zoom, session geometry.


func _store() -> BeWindowStore:
	var s := BeWindowStore.new()
	s.view_size = Vector2(1280, 800)
	return s


func test_open_places_and_activates() -> void:
	var s := _store()
	s.open("computer")
	expect_eq(s.order, ["computer"])
	expect_eq(s.active(), "computer")
	expect_eq(s.rect_of("computer").position, Vector2(124, 40))
	s.open("g:main")
	expect_eq(s.active(), "g:main")
	expect_eq(s.rect_of("g:main").position, Vector2(124 + 30, 70), "n-th window cascades by 30")
	s.open("computer")
	expect_eq(s.order.size(), 2, "re-opening does not duplicate")
	expect_eq(s.active(), "computer")


func test_raise_hide_and_task_click() -> void:
	var s := _store()
	s.open("computer")
	s.open("g:a")
	s.hide("g:a")
	expect_eq(s.active(), "computer", "hidden windows are skipped")
	s.task_click("g:a")
	expect_eq(s.active(), "g:a", "clicking a hidden task shows it")
	s.task_click("g:a")
	expect_eq(s.active(), "computer", "clicking the active task hides it")
	expect(s.get_entry("g:a").hidden)
	s.raise("g:a")
	expect(not s.get_entry("g:a").hidden)
	expect_eq(s.z, ["computer", "g:a"])


func test_close_removes_everywhere() -> void:
	var s := _store()
	s.open("computer")
	s.open("g:a")
	s.close("g:a")
	expect(not s.has("g:a"))
	expect_eq(s.order, ["computer"])
	expect_eq(s.z, ["computer"])
	s.close("g:a")
	expect_eq(s.active(), "computer")
	s.close_all()
	expect_eq(s.active(), "")


func test_zoom_fills_the_view_and_toggles() -> void:
	var s := _store()
	s.open("g:a")
	var before := s.rect_of("g:a")
	s.toggle_zoom("g:a")
	expect_eq(s.rect_of("g:a"), Rect2(0, 0, 1280, 800))
	s.toggle_zoom("g:a")
	expect_eq(s.rect_of("g:a"), before)


func test_move_resize_respect_limits() -> void:
	var s := _store()
	s.open("g:a")
	s.move_to("g:a", Vector2(300, -50))
	expect_eq(s.rect_of("g:a").position, Vector2(300, 0), "top clamped at 0")
	s.resize_to("g:a", Vector2(10, 10))
	expect_eq(s.rect_of("g:a").size, Vector2(320, 220))
	s.open("find")
	s.resize_to("find", Vector2(10, 10))
	expect_eq(s.rect_of("find").size, Vector2(460, 280))


func test_views_and_sync_groups() -> void:
	var s := _store()
	s.open("g:a")
	s.open("g:b")
	s.open("computer")
	s.set_view("g:a", "details")
	expect_eq(s.get_entry("g:a").view, "details")
	s.set_view("g:a", "bogus")
	expect_eq(s.get_entry("g:a").view, "details")
	s.sync_groups(["b"])
	expect(not s.has("g:a"))
	expect(s.has("g:b") and s.has("computer"), "other windows survive")


func test_changed_signal_fires_on_mutations() -> void:
	var s := _store()
	var count := [0]
	s.changed.connect(func(): count[0] += 1)
	s.open("computer")
	s.hide("computer")
	s.raise("computer")
	s.close("computer")
	expect(count[0] >= 4, "changed fired %d times" % count[0])


func test_group_keys() -> void:
	expect_eq(BeWindowStore.group_key("x"), "g:x")
	expect(BeWindowStore.is_group_key("g:x") and not BeWindowStore.is_group_key("find"))
	expect_eq(BeWindowStore.group_id_of("g:x"), "x")
	expect_eq(BeWindowStore.group_id_of("computer"), "")


func test_menu_state_toggle_enter_close() -> void:
	var m := BeMenuState.new()
	expect(not m.is_open())
	m.enter("g:a", "view")
	expect(not m.is_open(), "hover alone does not open")
	m.toggle("g:a", "file")
	expect_eq(m.open_menu_id(), "file")
	expect_eq(m.open_window_key(), "g:a")
	m.enter("g:a", "view")
	expect_eq(m.open_menu_id(), "view", "moving across titles switches menus")
	m.enter("g:b", "file")
	expect_eq(m.open_window_key(), "g:a", "other windows' titles are ignored")
	m.toggle("g:a", "view")
	expect(not m.is_open(), "clicking the open title closes it")
	m.toggle("g:a", "view")
	m.close()
	expect(not m.is_open())


func test_menu_state_keyboard_stepping_skips_separators_and_disabled() -> void:
	var items := [{"label": "a"}, {"sep": true}, {"label": "b", "disabled": true}, {"label": "c"}]
	expect_eq(BeMenuState.step(items, -1, 1), 0)
	expect_eq(BeMenuState.step(items, 0, 1), 3)
	expect_eq(BeMenuState.step(items, 3, 1), 0, "wraps")
	expect_eq(BeMenuState.step(items, 0, -1), 3)
	expect_eq(BeMenuState.step([{"label": "x", "disabled": true}], 0, 1), -1)
	expect_eq(BeMenuState.step([], 0, 1), -1)
	expect_eq(BeMenuState.step_menu(4, 3, 1), 0)
	expect_eq(BeMenuState.step_menu(4, 0, -1), 3)
