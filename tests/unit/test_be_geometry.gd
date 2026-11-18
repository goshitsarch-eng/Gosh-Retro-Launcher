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


func test_find_default_clears_the_deskbar_at_640x480() -> void:
	# Regression: the Find window used to start at y=32, under the Deskbar's top-right block (x >= 440).
	var view := Vector2(640, 480)
	var f := BeGeometry.default_rect("find", 0, view)
	# Compare against the Deskbar as BeGeometry lays it out (two tasks), not against the constant the fix uses.
	var deskbar: Rect2 = BeGeometry.deskbar_parts(2, view.x)["rect"]
	expect(not f.intersects(deskbar), "clear of the Deskbar with two tasks")
	expect(f.position.y + f.size.y <= view.y, "fits on screen")
	expect(f.size.y >= BeGeometry.FIND_MIN_H, "keeps its minimum height")


func test_find_default_clears_the_deskbar_for_each_task_count_at_640x480() -> void:
	# n windows already open -> the Deskbar lists n + 1 tasks once Find opens (BeWindowStore.order after the append).
	var view := Vector2(640, 480)
	for tasks in [1, 2, 3]:
		var f := BeGeometry.default_rect("find", tasks - 1, view)
		var deskbar: Rect2 = BeGeometry.deskbar_parts(tasks, view.x)["rect"]
		expect(not f.intersects(deskbar), "clear of the Deskbar with %d tasks: %s vs %s" % [tasks, f, deskbar])
		expect(f.position.x >= 0.0 and f.end.x <= view.x and f.position.y >= 0.0 and f.end.y <= view.y, "on screen with %d tasks: %s" % [tasks, f])
		expect(f.size.x >= BeGeometry.FIND_MIN_W and f.size.y >= BeGeometry.FIND_MIN_H, "minimum size with %d tasks" % tasks)


func test_find_with_four_tasks_at_640x480_stays_clear_and_on_screen_below_minimum_height() -> void:
	# Documented trade-off: the Deskbar ends at y=204 with four tasks, 204 + FIND_MIN_H (280) > 480, and the 460 px
	# window cannot fit in the 440 px left of the Deskbar. Rule: clear of the Deskbar and on screen, height gives way.
	var view := Vector2(640, 480)
	var deskbar: Rect2 = BeGeometry.deskbar_parts(4, view.x)["rect"]
	expect(deskbar.end.y + BeGeometry.FIND_MIN_H > view.y, "precondition: no placement satisfies all three")
	var f := BeGeometry.default_rect("find", 3, view)
	expect(not f.intersects(deskbar), "clear of the Deskbar with 4 tasks: %s vs %s" % [f, deskbar])
	expect(f.position.y >= 0.0 and f.end.y <= view.y and f.end.x <= view.x, "on screen with 4 tasks: %s" % f)
	expect(f.size.y >= view.y - deskbar.end.y - 1.0, "uses all the height below the Deskbar: %s" % f)
	expect(f.size.x >= BeGeometry.FIND_MIN_W)


func test_find_with_many_tasks_keeps_a_usable_height_on_screen() -> void:
	# Past ~5 tasks at 640x480 the area below the Deskbar is shorter than MIN_H: keep MIN_H and stay on screen.
	var view := Vector2(640, 480)
	var f := BeGeometry.default_rect("find", 9, view)
	expect(f.size.y >= BeGeometry.MIN_H, "usable height with 10 tasks: %s" % f)
	expect(f.position.y >= 0.0 and f.end.y <= view.y, "on screen with 10 tasks: %s" % f)


func test_find_placement_accepts_an_explicit_deskbar_bottom() -> void:
	var view := Vector2(640, 480)
	var f := BeGeometry.default_rect("find", 0, view, 180.0)
	expect(f.position.y >= 180.0 and f.end.y <= view.y, "below the given Deskbar bottom: %s" % f)
	# Windows that do not reach the Deskbar column are left where the design formula puts them.
	var wide := BeGeometry.default_rect("find", 0, Vector2(1280, 800))
	expect_eq(wide.position, Vector2(124, 40))


func test_scroll_bars_for_list_view() -> void:
	# 640x480 List View: inner 368 wide, columns need 520 -> horizontal bar; 8 rows fit vertically.
	var b := BeGeometry.scroll_bars(520.0, 27.0 + 8 * 24.0, Vector2(368, 240))
	expect(b.h and not b.v, "horizontal bar only: %s" % b)
	expect_eq(b.view, Vector2(368, 240 - BeGeometry.SCROLLBAR))
	expect_eq(b.max, Vector2(520 - 368, 0))
	# wide enough: no bars, columns stretch to the view
	var w := BeGeometry.scroll_bars(520.0, 100.0, Vector2(700, 300))
	expect(not w.h and not w.v)
	expect_eq(w.content_w, 700.0)
	expect_eq(w.max, Vector2.ZERO)
	# both: the horizontal bar shortens the view height and the vertical bar the width; maxima account for both
	var both := BeGeometry.scroll_bars(520.0, 500.0, Vector2(368, 240))
	expect(both.h and both.v)
	expect_eq(both.view, Vector2(368 - 12, 240 - 12))
	expect_eq(both.max, Vector2(520 - 356, 500 - 228))


func test_scroll_bars_force_each_other() -> void:
	# Fits by height alone, but the horizontal bar takes 12 px -> vertical bar too.
	var a := BeGeometry.scroll_bars(520.0, 235.0, Vector2(400, 240))
	expect(a.h and a.v, "horizontal forces vertical: %s" % a)
	# Fits by width alone (525 >= 520), but the vertical bar takes 12 px -> horizontal bar too.
	var c := BeGeometry.scroll_bars(520.0, 400.0, Vector2(525, 240))
	expect(c.h and c.v, "vertical forces horizontal: %s" % c)
	expect_eq(c.max.x, 520.0 - 513.0)
	# Icon grids (min width 0) never get a horizontal bar; the vertical bar overlays as before.
	var g := BeGeometry.scroll_bars(0.0, 400.0, Vector2(300, 240))
	expect(g.v and not g.h)
	expect_eq(g.view, Vector2(300, 240))
	expect_eq(g.max, Vector2(0, 160))


func test_scroll_thumb_size_position_and_drag_inverse() -> void:
	var t := BeGeometry.scroll_thumb(368.0, 368.0, 520.0, 0.0)
	expect_eq(t.x, 0.0)
	expect(absf(t.y - 368.0 * 368.0 / 520.0) < 0.01, "proportional length: %s" % t)
	var end := BeGeometry.scroll_thumb(368.0, 368.0, 520.0, 152.0)
	expect(absf(end.x + end.y - 368.0) < 0.01, "at max scroll the thumb touches the track end: %s" % end)
	expect_eq(BeGeometry.scroll_thumb(100.0, 100.0, 10000.0, 0.0).y, 24.0, "minimum 24 px")
	expect_eq(BeGeometry.scroll_thumb(100.0, 100.0, 50.0, 0.0), Vector2(0, 100), "no overflow: full track")
	var mid := BeGeometry.scroll_thumb(368.0, 368.0, 520.0, 76.0)
	expect(absf(BeGeometry.scroll_from_thumb(368.0, 368.0, 520.0, mid.x) - 76.0) < 0.01, "drag inverts the thumb")
	expect_eq(BeGeometry.scroll_from_thumb(368.0, 368.0, 520.0, 9999.0), 152.0, "clamped to max")
	expect_eq(BeGeometry.scroll_from_thumb(368.0, 368.0, 520.0, -50.0), 0.0, "clamped to 0")


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
	expect_eq(cols[5], BeGeometry.DETAILS_LAST_W)
	var wide := BeGeometry.details_columns(1000.0)
	expect_eq(wide[1] + wide[3] + wide[5], 1000.0)
	expect(wide[1] < wide[3], "2fr:3fr")
	# the bold "Launch Group" heading (drawn 10 px in) clears the slim scrollbar over the right edge
	expect(10.0 + BeFont.width(BeDialogLogic.LAUNCH_GROUP_HEADING, BeGeometry.FONT, true) <= cols[5] - BeGeometry.SCROLLBAR,
		"the Launch Group heading fits its column")


func test_find_columns_fit_every_heading_and_fill_the_list() -> void:
	for w in [300.0, 430.0, 640.0, 1000.0]:
		var c := BeGeometry.find_columns(w)
		expect_eq(c.size(), 8)
		for n in 3:
			expect_eq(c[n * 2] + c[n * 2 + 1], c[n * 2 + 2], "columns are contiguous at %d" % w)
		var heads := BeFindView.HEADINGS
		for n in 4:
			expect(10.0 + BeFont.width(heads[n], BeGeometry.FONT, true) <= c[n * 2 + 1], "%s fits at %d" % [heads[n], w])
	var mid := BeGeometry.find_columns(430.0)
	expect_eq(mid[6] + mid[7], 430.0, "Command takes the rest of the list")
	expect(mid[7] >= 90.0, "Command stays readable at 640x480")
	var wide := BeGeometry.find_columns(1000.0)
	expect_eq(wide[6] + wide[7], 1000.0)
	expect(wide[7] > mid[7] + 150.0 and wide[1] > mid[1] + 150.0, "a wide window gives the extra room to Name and Command")


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
