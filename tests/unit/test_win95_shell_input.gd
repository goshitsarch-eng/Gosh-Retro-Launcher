extends TestCase
## Port of win95/__tests__/shellInputSelection.test.ts.


func test_routes_required_shell_accelerators() -> void:
	expect_eq(Win95ShellInput.route_shortcut({"key": "Escape", "ctrlKey": true}), "toggle-start")
	expect_eq(Win95ShellInput.route_shortcut({"key": "r", "metaKey": true}), "open-run")
	expect_eq(Win95ShellInput.route_shortcut({"key": "f", "metaKey": true}), "open-find")
	expect_eq(Win95ShellInput.route_shortcut({"key": "e", "metaKey": true}), "open-explorer")
	expect_eq(Win95ShellInput.route_shortcut({"key": "Tab", "altKey": true}), "cycle-window")
	expect_eq(Win95ShellInput.route_shortcut({"key": "Tab", "altKey": true, "shiftKey": true}), "cycle-window-reverse")
	expect_eq(Win95ShellInput.route_shortcut({"key": "Tab", "metaKey": true}), "cycle-window")
	expect_eq(Win95ShellInput.route_shortcut({"key": " ", "altKey": true}), "system-menu")
	expect_eq(Win95ShellInput.route_shortcut({"key": "F4", "altKey": true}), "close-window")
	expect_eq(Win95ShellInput.route_shortcut({"key": "F10", "shiftKey": true}), "context-menu")
	expect_eq(Win95ShellInput.route_shortcut({"key": "ContextMenu"}), "context-menu")
	expect_eq(Win95ShellInput.route_shortcut({"key": "a"}), "")


func test_tracks_latched_and_press_drag_release_menu_modes_by_level() -> void:
	var state := Win95ShellInput.reduce_menu_tracking(Win95ShellInput.closed_tracking(), {"type": "open", "index": 1, "tracking": true})
	expect_eq(state, {"open": true, "mode": "tracking", "path": [1]})
	state = Win95ShellInput.reduce_menu_tracking(state, {"type": "hover", "level": 1, "index": 3, "hasChild": true})
	expect_eq(state.path, [1, 3])
	state = Win95ShellInput.reduce_menu_tracking(state, {"type": "release", "hasChild": true})
	expect_eq(state.mode, "latched")
	expect_eq(Win95ShellInput.reduce_menu_tracking(state, {"type": "close-level"}).path, [1])
	expect_eq(Win95ShellInput.reduce_menu_tracking(state, {"type": "close-all"}).open, false)
	expect_eq(Win95ShellInput.reduce_menu_tracking(state, {"type": "release", "hasChild": false}).open, false)
	# hovering back to a shallower level truncates the path
	var hovered := Win95ShellInput.reduce_menu_tracking(state, {"type": "hover", "level": 0, "index": 4, "hasChild": false})
	expect_eq(hovered.path, [4])


func test_places_cascades_at_edges_builds_overflow_columns_and_preserves_submenu_corridors() -> void:
	expect_eq(Win95ShellInput.place_menu({"x": 600, "y": 430, "width": 35, "height": 20}, {"width": 170, "height": 100}, {"width": 640, "height": 452}),
		{"x": 431, "y": 352, "flippedX": true, "flippedY": true})
	expect_eq(Win95ShellInput.place_menu({"x": 10, "y": 20, "width": 35, "height": 20}, {"width": 170, "height": 100}, {"width": 640, "height": 452}, "below"),
		{"x": 10, "y": 39, "flippedX": false, "flippedY": false})
	expect_eq(Win95ShellInput.menu_column_layout([20, 20, 20, 20, 20], 60), [[0, 1, 2], [3, 4]])
	expect(Win95ShellInput.is_point_in_menu_corridor({"x": 100, "y": 30}, {"x": 150, "y": 35}, {"x": 200, "top": 10, "bottom": 70}))
	expect(not Win95ShellInput.is_point_in_menu_corridor({"x": 100, "y": 30}, {"x": 80, "y": 100}, {"x": 200, "top": 10, "bottom": 70}))


func test_supports_anchor_ranges_disjoint_toggles_and_select_all() -> void:
	var ids := ["a", "b", "c", "d"]
	var state := Win95SelectionState.select_item(Win95SelectionState.empty(), "b", ids)
	state = Win95SelectionState.select_item(state, "d", ids, {"shift": true})
	expect_eq(state.selected, ["b", "c", "d"])
	state = Win95SelectionState.select_item(state, "a", ids, {"ctrl": true})
	expect_eq(state.selected, ["b", "c", "d", "a"])
	state = Win95SelectionState.select_item(state, "c", ids, {"ctrl": true})
	expect_eq(state.selected, ["b", "d", "a"])
	expect_eq(Win95SelectionState.select_all(ids).selected, ids)
	expect_eq(Win95SelectionState.select_all([]).focused, "")


func test_supports_spatial_navigation_type_matching_marquee_intersection_and_grid_snap() -> void:
	var items := [
		{"id": "a", "x": 0, "y": 0, "width": 20, "height": 20},
		{"id": "b", "x": 50, "y": 0, "width": 20, "height": 20},
		{"id": "c", "x": 0, "y": 50, "width": 20, "height": 20},
	]
	expect_eq(Win95SelectionState.find_directional_item(items, "a", "right"), "b")
	expect_eq(Win95SelectionState.find_directional_item(items, "a", "down"), "c")
	expect_eq(Win95SelectionState.find_directional_item(items, "a", "left"), "a")
	var marquee := Win95SelectionState.normalize_marquee(Vector2(55, 55), Vector2(-1, -1))
	expect_eq(Win95SelectionState.items_in_marquee(items, marquee), ["a", "b", "c"])
	expect_eq(Win95SelectionState.find_type_match([{"id": "a", "label": "Accessories"}, {"id": "b", "label": "Applications"}], "app", "a"), "b")
	expect_eq(Win95SelectionState.find_type_match([{"id": "a", "label": "Accessories"}], "z", ""), "")
	expect_eq(Win95SelectionState.snap_position(Vector2(78, 77), Vector2(75, 74)), Vector2(79, 78))
