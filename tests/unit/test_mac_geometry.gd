extends TestCase
## Window chrome, grid/list layout, desktop icon column, scroll thumb.


func test_chrome_boxes_follow_the_design() -> void:
	var c := MacGeometry.chrome(Rect2(10, 30, 300, 200), false, true, 60)
	expect_eq(c.close.size, Vector2(13, 13))
	expect_eq(c.close.position.x, 10 + 1 + 6, "close box 6px inside the 1px border")
	expect_eq(c.shade.end.x, 10 + 300 - 1 - 6, "collapse box at the right edge")
	expect_eq(c.zoom.end.x + 5, c.shade.position.x, "5px gap between zoom and collapse")
	expect(c.stripe_l.size.y == 11 and c.stripe_r.size.y == 11)
	expect_eq(c.info.size.y, MacGeometry.INFO_H)
	expect(c.content.position.y == 30 + 1 + MacGeometry.TITLE_H + MacGeometry.INFO_H)
	expect_eq(c.grip.size, Vector2(15, 15))
	expect_eq(c.grip.end, Vector2(10 + 300 - 5, 30 + 200 - 5))


func test_shaded_window_is_title_only() -> void:
	var c := MacGeometry.chrome(Rect2(0, 22, 300, 200), true, true, 40)
	expect_eq(c.frame.size.y, MacGeometry.SHADED_H)


func test_find_chrome_has_no_zoom_box() -> void:
	var c := MacGeometry.chrome(Rect2(0, 22, 300, 200), false, false, 20)
	expect_eq(c.zoom, Rect2())


func test_grid_wraps_by_width() -> void:
	var specs := []
	for i in 7:
		specs.append({"id": str(i), "lines": 1})
	var narrow := MacGeometry.grid_layout(specs, 250)
	expect_eq(narrow.cells.size(), 7)
	var per_row := 0
	for c in narrow.cells:
		if c.rect.position.y == narrow.cells[0].rect.position.y:
			per_row += 1
	expect_eq(per_row, 2, "(250-16+6)/(104+6) = 2 columns")
	var wide := MacGeometry.grid_layout(specs, 600)
	expect(wide.height < narrow.height)
	expect_eq(MacGeometry.grid_layout([], 300).cells.size(), 0)


func test_grid_row_height_grows_with_label_lines() -> void:
	var one := MacGeometry.grid_layout([{"id": "a", "lines": 1}], 300)
	var two := MacGeometry.grid_layout([{"id": "a", "lines": 2}], 300)
	expect_eq(int(two.height) - int(one.height), MacGeometry.LABEL_LINE)


func test_details_columns_sum_to_width() -> void:
	var d := MacGeometry.details_layout([{"id": "a"}, {"id": "b"}], 500)
	expect_eq(d.cols[0].w + d.cols[1].w + d.cols[2].w, 500)
	expect_eq(d.rows.size(), 2)
	expect_eq(d.height, MacGeometry.DETAILS_HEADER_H + 2 * MacGeometry.DETAILS_ROW_H)
	expect_eq(MacGeometry.details_layout([], 100).width, MacGeometry.DETAILS_MIN_W)


func test_desktop_icons_sit_in_the_right_column() -> void:
	var icons := MacGeometry.desktop_icons(Vector2(640, 480), 2)
	expect_eq(icons.size(), 2)
	expect_eq(icons[0].rect.position.x, 640 - 10 - 100)
	expect_eq(icons[0].rect.position.y, MacGeometry.DESK_TOP)
	expect_eq(icons[1].rect.end.y, 480 - MacGeometry.DESK_BOTTOM, "last icon flush with the bottom margin")


func test_scroll_thumb() -> void:
	expect_eq(MacGeometry.scroll_thumb(100, 100, 0, 80).thumb_h, 80)
	var t := MacGeometry.scroll_thumb(100, 400, 150, 100)
	expect_eq(t.thumb_h, 25)
	expect_eq(t.thumb_y, 75 * 150 / 300)
	expect_eq(MacGeometry.scroll_thumb(100, 400, 9999, 100).thumb_y, 75, "clamped at the end")
	expect_eq(MacGeometry.max_scroll(100, 90), 0)
	expect_eq(MacGeometry.max_scroll(100, 340), 240)


func test_cascade_and_clamp() -> void:
	var desk := Vector2(640, 480)
	var r0 := MacGeometry.cascade_rect(0, desk)
	var r1 := MacGeometry.cascade_rect(1, desk)
	expect_eq(r1.position - r0.position, Vector2(24, 20))
	for i in 20:
		var r := MacGeometry.cascade_rect(i, desk)
		expect(r.position.y >= MacGeometry.MENU_H and r.end.x <= 640 and r.end.y <= 480, "cascade %d on screen" % i)
	expect_eq(MacGeometry.clamp_position(Vector2(-900, -50), Vector2(300, 200), desk), Vector2(32 - 300, MacGeometry.MENU_H))
	expect_eq(MacGeometry.clamp_position(Vector2(900, 900), Vector2(300, 200), desk), Vector2(640 - 32, 480 - MacGeometry.TITLE_H))
