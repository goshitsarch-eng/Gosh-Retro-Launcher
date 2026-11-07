extends TestCase
## Port of win95/__tests__/listScrollbarFind.test.ts.


func _groups() -> Array:
	return [{
		"id": "tools", "name": "Tools", "icon": "folder",
		"windowState": {"x": 0, "y": 0, "width": 300, "height": 200, "minimized": false, "maximized": false},
		"shellWindowState": Types.create_shell_window_state(),
		"items": [
			{"id": "paint", "name": "Paint", "path": "C:\\Tools\\paint.exe", "icon": "application", "workingDir": "", "arguments": "/safe"},
			{"id": "site", "name": "Project Site", "path": "https://example.com/project", "icon": "url", "workingDir": ""},
		],
	}, {
		"id": "games", "name": "Games", "icon": "folder",
		"windowState": {"x": 0, "y": 0, "width": 300, "height": 200, "minimized": false, "maximized": false},
		"shellWindowState": Types.create_shell_window_state(),
		"items": [{"id": "cards", "name": "Card Game", "path": "C:\\Games\\cards.exe", "icon": "application", "workingDir": ""}],
	}]


func _ids(results: Array) -> Array:
	return results.map(func(r): return r.item.id)


func test_keeps_icon_small_icon_list_and_report_layouts_distinct() -> void:
	var ids := []
	for i in 12:
		ids.append("item-%d" % i)
	var vp := {"width": 320, "height": 180}
	var icon := Win95ListViewState.layout(ids, "large", vp)
	var small := Win95ListViewState.layout(ids, "small", vp)
	var lst := Win95ListViewState.layout(ids, "list", vp)
	var report := Win95ListViewState.layout(ids, "details", vp)
	expect_eq(icon.items[1].x, 81)
	expect_eq(small.items[1].x, 154)
	expect_eq(lst.items[1].y, 24)
	expect_eq(lst.items[9].x, 154)
	expect_eq(report.items[0].y, 18)
	expect_eq(report.items[1].y, 37)


func test_uses_manual_icon_positions_only_when_auto_arrange_is_off() -> void:
	var ids := []
	for i in 12:
		ids.append("item-%d" % i)
	var manual := {"item-0": {"x": 222, "y": 111}}
	var vp := {"width": 320, "height": 180}
	var off: Dictionary = Win95ListViewState.layout(ids, "large", vp, manual, false).items[0]
	expect_eq(off.x, 222)
	expect_eq(off.y, 111)
	var on: Dictionary = Win95ListViewState.layout(ids, "large", vp, manual, true).items[0]
	expect_eq(on.x, 5)
	expect_eq(on.y, 8)
	expect_eq(Win95ListViewState.resize_report_column(60, -100), 40)
	expect_eq(Win95ListViewState.resize_report_column(60, 12.4), 72)
	expect_eq(Win95ListViewState.page_selection_index(3, 1, 5, 12), 8)
	expect_eq(Win95ListViewState.page_selection_index(3, -1, 5, 12), 0)
	expect_eq(Win95ListViewState.page_selection_index(3, 1, 5, 0), -1)


func test_content_extents_grow_with_the_layout() -> void:
	var ids := []
	for i in 40:
		ids.append("i%d" % i)
	var r := Win95ListViewState.layout(ids, "details", {"width": 100, "height": 100})
	expect_eq(r.contentWidth, 510)
	expect_eq(r.contentHeight, 18 + 40 * 19)
	var l := Win95ListViewState.layout(ids, "list", {"width": 100, "height": 100})
	expect_eq(l.rowsPerPage, 4)
	expect_eq(l.columns, 10)
	expect_eq(l.contentWidth, 8 + 10 * 150)


func test_calculates_proportional_thumbs_and_reversible_drag_positions() -> void:
	var metrics := Win95ScrollbarState.thumb_metrics(100, 400, 168)
	expect_eq(metrics.thumbLength, 42)
	var offset := Win95ScrollbarState.thumb_offset(150, metrics)
	expect_eq(offset, 63)
	expect_eq(Win95ScrollbarState.scroll_from_thumb(offset, metrics), 150)


func test_clamps_line_and_shaft_page_actions_at_both_ends() -> void:
	expect_eq(Win95ScrollbarState.clamp_scroll(-10, 300, 100), 0)
	expect_eq(Win95ScrollbarState.clamp_scroll(500, 300, 100), 200)
	expect_eq(Win95ScrollbarState.scroll_step(195, 1, 16, 300, 100), 200)
	expect_eq(Win95ScrollbarState.scroll_page(100, -1, 300, 100), 16)
	var none := Win95ScrollbarState.thumb_metrics(100, 100, 50)
	expect_eq(none.thumbLength, 50)
	expect_eq(Win95ScrollbarState.thumb_offset(10, none), 0)


func test_find_maps_named_wildcards_and_look_in_filters_to_launcher_groups() -> void:
	expect_eq(_ids(ProgramSearch.find_programs(_groups(), {"named": "P*"})), ["paint", "site"])
	expect_eq(_ids(ProgramSearch.find_programs(_groups(), {"named": "*", "groupId": "games"})), ["cards"])


func test_find_maps_item_type_path_and_containing_text_predicates() -> void:
	expect_eq(_ids(ProgramSearch.find_programs(_groups(), {"named": "*", "type": "internet"})), ["site"])
	expect_eq(_ids(ProgramSearch.find_programs(_groups(), {"named": "*", "type": "application", "path": "games"})), ["cards"])
	expect_eq(_ids(ProgramSearch.find_programs(_groups(), {"named": "*", "containing": "/safe"})), ["paint"])
