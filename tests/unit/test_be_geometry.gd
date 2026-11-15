extends TestCase
## BeGeometry: the design's CSS box model in logical pixels.


func test_default_window_placement_follows_the_design_formula() -> void:
	var view := Vector2(1280, 800)
	var w_area := 1280.0 - 336.0
	var h_area := 800.0 - 34.0
	var r := BeGeometry.default_rect("computer", 0, view)
	expect_eq(r.size, Vector2(maxf(400.0, minf(820.0, w_area - 150.0)), maxf(300.0, minf(520.0, h_area - 48.0))))
	expect_eq(r.position, Vector2(124, 40))
	var g := BeGeometry.default_rect("g:x", 2, view)
	expect_eq(g.size, Vector2(680, 420))
	expect_eq(g.position, Vector2(124 + 60, 100))
	var f := BeGeometry.default_rect("find", 0, view)
	expect_eq(f.size, Vector2(720, 500))


func test_small_views_keep_the_minimum_sizes() -> void:
	var f := BeGeometry.default_rect("find", 0, Vector2(640, 480))
	expect(f.size.x >= BeGeometry.FIND_MIN_W and f.size.y >= BeGeometry.FIND_MIN_H)
	var g := BeGeometry.default_rect("g:x", 0, Vector2(640, 480))
	expect(g.size.x >= 380 and g.size.y >= 280)
	expect(g.position.y >= 30)


func test_clamp_size_and_position() -> void:
	expect_eq(BeGeometry.clamp_size("g:x", Vector2(10, 10)), Vector2(320, 220))
	expect_eq(BeGeometry.clamp_size("find", Vector2(10, 10)), Vector2(460, 280))
	expect_eq(BeGeometry.clamp_size("g:x", Vector2(500, 400)), Vector2(500, 400))
	var p := BeGeometry.clamp_position(Vector2(-900, -30), Vector2(400, 300), Vector2(800, 600))
	expect_eq(p.y, 0.0)
	expect(p.x >= 40.0 - 400.0)
	expect_eq(BeGeometry.clamp_position(Vector2(100, 50), Vector2(400, 300), Vector2(800, 600)), Vector2(100, 50))


func test_tab_width_is_content_sized_and_limited() -> void:
	expect_eq(BeGeometry.tab_width(100, 400), 164.0)
	expect_eq(BeGeometry.tab_width(100, 400, false), 143.0)
	expect_eq(BeGeometry.tab_width(500, 400), 376.0, "max-width: calc(100% - 24px)")


func test_folder_parts_stack_like_the_markup() -> void:
	var r := Rect2(100, 40, 400, 300)
	var p := BeGeometry.folder_parts(r, 80)
	expect_eq(p.tab, Rect2(100, 41, 144, 26))
	expect_eq(p.body, Rect2(100, 66, 400, 274))
	expect_eq(p.menu, Rect2(105, 71, 390, 26))
	expect_eq(p.status, Rect2(105, 340 - 5 - 20, 390, 20))
	expect_eq(p.content.position, Vector2(105, 101))
	expect_eq(p.content.end.y, p.status.position.y - 4)
	expect_eq(p.close, Rect2(107, 46, 15, 15))
	expect_eq(p.zoom.end.x, p.tab.end.x - 7)
	expect(p.grip.end.x <= p.status.end.x and p.grip.size == Vector2(16, 16))


func test_desktop_icon_column_wraps_at_the_bottom_margin() -> void:
	var lines := [1, 1, 1, 1, 1, 1, 1, 1]
	var cells := BeGeometry.desktop_cells(lines, 480)
	expect_eq(cells.size(), 8)
	expect_eq(cells[0], Rect2(8, 14, 110, BeGeometry.icon_cell_height(1)))
	expect_eq(BeGeometry.icon_cell_height(1), 60)
	expect_eq(cells[1].position.y, 14.0 + 60 + 14)
	# 6 fit (6*60 + 5*14 = 430 <= 458), the 7th starts a second column at x = 8 + 110 + 14
	expect_eq(cells[5].position.x, 8.0)
	expect_eq(cells[6].position, Vector2(132, 14))
	# a two-line label makes its cell taller and pushes the wrap earlier
	var tall := BeGeometry.desktop_cells([2, 2, 2, 2, 2, 2], 480)
	expect(tall[tall.size() - 1].position.x > 8.0)


func test_large_view_grid() -> void:
	var res := BeGeometry.large_cells([1, 1, 1, 1], 400.0)
	var rects: Array = res.rects
	expect_eq(rects[0], Rect2(8, 8, 104, 60))
	expect_eq(rects[1].position.x, 8.0 + 112)
	# 3 columns fit in 400 - 16 (104 + 8 gaps); the 4th wraps with a 14px row gap
	expect_eq(rects[3].position, Vector2(8, 8 + 60 + 14))
	expect_eq(res.height, 8.0 + 60 + 14 + 60 + 8)
	expect_eq(BeGeometry.large_cells([], 400.0).height, 16.0)


func test_small_view_grid_and_details_columns() -> void:
	var s := BeGeometry.small_cells(5, 500.0)
	expect_eq((s.rects as Array).size(), 5)
	expect_eq(s.rects[0].size.y, 24.0)
	expect_eq(s.rects[0].position, Vector2(8, 8))
	var cols := BeGeometry.details_columns(400.0)
	expect_eq(cols[4] + cols[5], 520.0, "min-width 520")
	expect_eq(cols[5], 110.0)
	var wide := BeGeometry.details_columns(1000.0)
	expect_eq(wide[1] + wide[3] + wide[5], 1000.0)
	expect(wide[1] < wide[3], "2fr:3fr")


func test_deskbar_parts() -> void:
	var p := BeGeometry.deskbar_parts(2, 1000.0)
	expect_eq(p.rect.position.x, 800.0)
	expect_eq(p.logo, Rect2(800, 0, 200, 46))
	expect_eq(p.clock, Rect2(804, 50, 192, 28))
	expect_eq(p.tasks[0], Rect2(800, 82, 200, 30))
	expect_eq(p.tasks[1].position.y, 112.0)
	expect_eq(p.rect.size.y, 82.0 + 60 + 2)
	expect_eq(BeGeometry.ARRANGE_RESERVE, 212)


func test_menu_sizing_and_popup_fit() -> void:
	var items := [{"label": "a"}, {"sep": true}, {"label": "b"}]
	var s := BeGeometry.menu_size(items, 50.0, 28, 200.0, 26.0)
	expect_eq(s.x, 200.0)
	expect_eq(s.y, 6.0 + 28 + 8 + 28 + 2)
	expect_eq(BeGeometry.menu_size(items, 300.0, 28, 200.0, 26.0).x, 300.0 + 26 + 16 + 2)
	expect_eq(BeGeometry.fit_popup(Vector2(900, 700), Vector2(200, 100), Vector2(1000, 720)), Vector2(800, 616))
	expect_eq(BeGeometry.fit_popup(Vector2(-5, -5), Vector2(200, 100), Vector2(1000, 720)), Vector2(0, 0))
