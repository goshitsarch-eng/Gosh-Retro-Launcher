extends TestCase


func test_columns() -> void:
	expect_eq(Win31GridLogic.columns(300), 4)
	expect_eq(Win31GridLogic.columns(74), 1)
	expect_eq(Win31GridLogic.columns(10), 1)
	expect_eq(Win31GridLogic.columns(416 - 10), 5)


func test_auto_arrange_positions() -> void:
	var items := []
	for i in 7:
		items.append({"id": str(i), "win31Position": {"x": 500, "y": 500}})
	var p := Win31GridLogic.positions(items, true, 300)
	expect_eq(p[0], Vector2i(0, 0))
	expect_eq(p[3], Vector2i(225, 0))
	expect_eq(p[4], Vector2i(0, 72), "wraps after 4 columns")
	expect_eq(p[6], Vector2i(150, 72))


func test_manual_positions() -> void:
	var items := [{"id": "a", "win31Position": {"x": 12, "y": 34}}, {"id": "b"}]
	var p := Win31GridLogic.positions(items, false, 300)
	expect_eq(p[0], Vector2i(12, 34))
	expect_eq(p[1], Vector2i(75, 0), "missing position flows by index")


func test_navigation() -> void:
	expect_eq(Win31GridLogic.navigate("right", 0, 8, 5), 1)
	expect_eq(Win31GridLogic.navigate("right", 7, 8, 5), 7)
	expect_eq(Win31GridLogic.navigate("left", 0, 8, 5), 0)
	expect_eq(Win31GridLogic.navigate("down", 1, 8, 5), 6)
	expect_eq(Win31GridLogic.navigate("down", 4, 8, 5), 7, "clamps to the last item")
	expect_eq(Win31GridLogic.navigate("up", 6, 8, 5), 1)
	expect_eq(Win31GridLogic.navigate("up", 2, 8, 5), 0)
	expect_eq(Win31GridLogic.navigate("home", 5, 8, 5), 0)
	expect_eq(Win31GridLogic.navigate("end", 0, 8, 5), 7)
	expect_eq(Win31GridLogic.navigate("right", -1, 8, 5), 0, "nothing selected starts at the first item")
	expect_eq(Win31GridLogic.navigate("tab", 0, 8, 5), -1)
	expect_eq(Win31GridLogic.navigate("right", 0, 0, 5), -1)


func test_drag_clamp() -> void:
	expect_eq(Win31GridLogic.drag_position(Vector2(10, 10), Vector2(-50, -50), 300, 200), Vector2i(0, 0))
	expect_eq(Win31GridLogic.drag_position(Vector2(10, 10), Vector2(999, 999), 300, 200), Vector2i(225, 128))
	expect_eq(Win31GridLogic.drag_position(Vector2(10, 10), Vector2(2.5, 3.4), 300, 200), Vector2i(13, 13))


func test_hit_testing_topmost() -> void:
	var pos := [Vector2i(0, 0), Vector2i(50, 0)]
	expect_eq(Win31GridLogic.item_at(pos, Vector2(10, 10)), 0)
	expect_eq(Win31GridLogic.item_at(pos, Vector2(60, 10)), 1, "later items are on top")
	expect_eq(Win31GridLogic.item_at(pos, Vector2(200, 10)), -1)
	expect_eq(Win31GridLogic.item_at(pos, Vector2(10, 72)), -1)


func test_scrollbar_visibility() -> void:
	var small := Win31GridLogic.content_size([Vector2i(0, 0), Vector2i(75, 0)])
	expect_eq(small, Vector2i(150, 72))
	expect_eq(Win31GridLogic.scrollbars(small, 300, 100), {"v": false, "h": false})
	expect_eq(Win31GridLogic.scrollbars(Vector2i(150, 300), 300, 100), {"v": true, "h": false})
	expect_eq(Win31GridLogic.scrollbars(Vector2i(500, 72), 300, 100), {"v": false, "h": true})
	expect_eq(Win31GridLogic.scrollbars(Vector2i(290, 90), 300, 100), {"v": false, "h": false})
	expect_eq(Win31GridLogic.scrollbars(Vector2i(290, 90), 300, 100).v, false)
	var both := Win31GridLogic.scrollbars(Vector2i(300, 90), 300, 100)
	expect_eq(both.h, false)
	var cascade := Win31GridLogic.scrollbars(Vector2i(295, 95), 300, 100)
	expect_eq(cascade, {"v": false, "h": false})
	var forced := Win31GridLogic.scrollbars(Vector2i(300, 101), 300, 100)
	expect_eq(forced, {"v": true, "h": true}, "the vertical bar eats width and forces a horizontal one")


func test_label_layout() -> void:
	var f := RetroFont.instance(RetroFont.WFW)
	var short := Win31GridLogic.label_layout(f, "Read Me")
	expect_eq(short.lines.size(), 1)
	expect_eq(short.box_w, f.measure("Read Me") + 4)
	var long := Win31GridLogic.label_layout(f, "ClipBook Viewer Professional Edition")
	expect(long.lines.size() > 1, "long names wrap")
	expect_eq(long.box_w, 72)
	for l in long.lines:
		expect(f.measure(Win31GridLogic.lit(l)) <= 68, "every wrapped line fits the 68px text area")
	var word := Win31GridLogic.label_layout(f, "Supercalifragilisticexpialidocious")
	expect(word.lines.size() > 1, "over-long words hard break")
	var ell := Win31GridLogic.label_layout(f, "ClipBook Viewer Professional Edition", "ellipsis")
	expect_eq(ell.lines.size(), 1)
	expect(ell.lines[0].ends_with("..."))
	expect(f.measure(Win31GridLogic.lit(ell.lines[0])) <= 68)
	var amp := Win31GridLogic.label_layout(f, "Q&A")
	expect_eq(amp.lines[0], "Q&A", "ampersands are literal in names")


func test_ellipsize_keeps_short_text() -> void:
	var f := RetroFont.instance(RetroFont.WFW)
	expect_eq(Win31GridLogic.ellipsize(f, "Hi", 68), "Hi")
