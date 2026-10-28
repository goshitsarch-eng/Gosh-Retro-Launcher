extends TestCase


func test_js_round() -> void:
	expect_eq(Win31Arrange.js_round(2.5), 3)
	expect_eq(Win31Arrange.js_round(-2.5), -2)
	expect_eq(Win31Arrange.js_round(2.4), 2)


func test_icon_rows_and_reserved_space() -> void:
	expect_eq(Win31Arrange.icon_columns(503), 6)
	expect_eq(Win31Arrange.icon_columns(10), 1)
	expect_eq(Win31Arrange.reserved_bottom(0, 503), 0)
	expect_eq(Win31Arrange.reserved_bottom(4, 503), 58 + 8)
	expect_eq(Win31Arrange.reserved_bottom(7, 503), 2 * 58 + 8)


func test_cascade() -> void:
	var r := Win31Arrange.cascade(3, 500, 400, 66)
	expect_eq(r.size(), 3)
	expect_eq(r[0], Rect2(0, 0, 456, 290))
	expect_eq(r[2], Rect2(44, 44, 456, 290))
	var single := Win31Arrange.cascade(1, 500, 400, 0)
	expect_eq(single[0], Rect2(0, 0, 478, 378), "TS subtracts one offset even for a single window")
	var tiny := Win31Arrange.cascade(30, 300, 200, 0)
	expect_eq(tiny[0].size, Vector2(150, 92), "minimum window size")
	expect_eq(Win31Arrange.cascade(0, 500, 400, 0), [])


func test_tile_reserves_icon_rows() -> void:
	var r := Win31Arrange.tile(2, 500, 400, 66)
	expect_eq(r.size(), 2)
	expect_eq(r[0], Rect2(0, 0, 250, 334))
	expect_eq(r[1], Rect2(250, 0, 250, 334))
	expect_eq(Win31Arrange.tile(0, 500, 400, 0), [])


func test_arrange_icons() -> void:
	var p := Win31Arrange.arrange_icons(8, 503, 289)
	expect_eq(p[0], Vector2i(0, 289 - 58 - 8))
	expect_eq(p[5], Vector2i(375, 223))
	expect_eq(p[6], Vector2i(0, 289 - 2 * 58 - 8), "second row grows upward")


func test_icon_position_clamping() -> void:
	expect_eq(Win31Arrange.clamp_icon_position(Vector2(-5, 9999), 503, 289), Vector2i(0, 231))
	expect_eq(Win31Arrange.clamp_icon_position(Vector2(9999, 5), 503, 289), Vector2i(428, 5))
	expect_eq(Win31Arrange.icon_drag_position(Vector2(75, 100), Vector2(10.5, -3), 503, 289), Vector2i(86, 97))


func test_window_rect_clamp() -> void:
	var st := {"x": 600, "y": 500, "width": 900, "height": 700, "maximized": false}
	expect_eq(Win31Arrange.window_rect(st, 503, 289), Rect2(463, 265, 503, 289))
	expect_eq(Win31Arrange.window_rect({"x": -9, "y": -9, "width": 100, "height": 100, "maximized": false}, 503, 289), Rect2(0, 0, 100, 100))
	expect_eq(Win31Arrange.window_rect(st, 503, 289).size, Vector2(503, 289))
	st.maximized = true
	expect_eq(Win31Arrange.window_rect(st, 503, 289), Rect2(0, 0, 503, 289))


func test_caption_drag_and_resize() -> void:
	var st := {"x": 20, "y": 20, "width": 300, "height": 200}
	expect_eq(Win31Arrange.drag_position(st, Vector2(10.4, -50), 503, 289), Vector2i(30, 0))
	expect_eq(Win31Arrange.drag_position(st, Vector2(999, 999), 503, 289), Vector2i(203, 265))
	var e := Win31Arrange.resize_rect("e", st, Vector2(50, 0), 503, 289)
	expect_eq(e, {"x": 20, "y": 20, "width": 350, "height": 200})
	e = Win31Arrange.resize_rect("se", st, Vector2(9999, 9999), 503, 289)
	expect_eq([e.width, e.height], [483, 269])
	e = Win31Arrange.resize_rect("w", st, Vector2(-10, 0), 503, 289)
	expect_eq([e.x, e.width], [10, 310])
	e = Win31Arrange.resize_rect("w", st, Vector2(9999, 0), 503, 289)
	expect_eq([e.x, e.width], [170, 150], "min width keeps the right edge")
	e = Win31Arrange.resize_rect("n", st, Vector2(0, 9999), 503, 289)
	expect_eq([e.y, e.height], [128, 92])
	e = Win31Arrange.resize_rect("nw", st, Vector2(-30, -30), 503, 289)
	expect_eq([e.x, e.y, e.width, e.height], [0, 0, 320, 220], "clamped at the client origin")


func test_resize_zones() -> void:
	expect_eq(Win31Arrange.resize_zone(Vector2(2, 2), 300, 200), "nw")
	expect_eq(Win31Arrange.resize_zone(Vector2(150, 2), 300, 200), "n")
	expect_eq(Win31Arrange.resize_zone(Vector2(298, 100), 300, 200), "e")
	expect_eq(Win31Arrange.resize_zone(Vector2(296, 196), 300, 200), "se")
	expect_eq(Win31Arrange.resize_zone(Vector2(2, 196), 300, 200), "sw")
	expect_eq(Win31Arrange.resize_zone(Vector2(150, 100), 300, 200), "")
	expect_eq(Win31Arrange.resize_zone(Vector2(150, 10), 300, 200), "")


func test_drop_target_resolution() -> void:
	var windows := [{"groupId": "back", "rect": Rect2(0, 0, 300, 200)}, {"groupId": "front", "rect": Rect2(100, 50, 300, 200)}]
	var icons := [{"groupId": "icon", "rect": Rect2(0, 230, 75, 58)}]
	expect_eq(Win31Arrange.window_at(windows, Vector2(150, 100)), "front", "topmost wins")
	expect_eq(Win31Arrange.window_at(windows, Vector2(10, 10)), "back")
	expect_eq(Win31Arrange.window_at(windows, Vector2(450, 10)), "")
	expect_eq(Win31Arrange.drop_target(windows, icons, Vector2(10, 240)), "icon")
	expect_eq(Win31Arrange.drop_target(windows, icons, Vector2(150, 100)), "front")
	expect_eq(Win31Arrange.drop_target(windows, icons, Vector2(600, 600)), "")


func test_drop_item_payload() -> void:
	var item := Win31Drop.item_from_app_info("/tmp/My Game.exe", {"name": "My Game", "path": "/tmp/My Game.exe", "icon": "data:image/png;base64,AA==", "workingDir": "/tmp"})
	expect_eq(item.name, "My Game")
	expect_eq(item.icon, "data:image/png;base64,AA==")
	expect_eq(item.launchGroup, 0)
	expect(not item.has("win31Icon"))
	var fallback := Win31Drop.item_from_app_info("/tmp/tool.v2.exe", {})
	expect_eq(fallback.name, "tool.v2")
	expect_eq(fallback.path, "/tmp/tool.v2.exe")
	expect_eq(fallback.icon, "default")
	expect_eq(fallback.workingDir, "")
	var w := Win31Drop.item_from_app_info("/a/b.exe", {"name": "B", "path": "/a/b.exe", "icon": "", "win31Icon": "data:x"})
	expect_eq(w.icon, "default")
	expect_eq(w.win31Icon, "data:x")
