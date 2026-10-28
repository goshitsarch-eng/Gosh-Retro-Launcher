extends TestCase


func test_icon_ids_and_aliases() -> void:
	expect_eq(WfwIcons.icon_id("file-manager"), "file-manager")
	expect_eq(WfwIcons.icon_id("wfw-file-manager"), "file-manager")
	expect_eq(WfwIcons.icon_id("folder"), "group")
	expect_eq(WfwIcons.icon_id("drive"), "file-manager")
	expect_eq(WfwIcons.icon_id("trash"), "default")
	expect_eq(WfwIcons.icon_id("anything-else"), "default")
	expect_eq(WfwIcons.icon_id(""), "default")


func test_external_icons() -> void:
	expect(WfwIcons.is_external_icon("data:image/png;base64,AA=="))
	expect(WfwIcons.is_external_icon("file:///tmp/x.png"))
	expect(WfwIcons.is_external_icon("https://example.com/i.png"))
	expect(not WfwIcons.is_external_icon("group"))
	expect(not WfwIcons.is_external_icon("/tmp/x.png"))


func test_item_icon_prefers_win31_icon() -> void:
	expect_eq(WfwIcons.item_icon_string({"icon": "dos", "win31Icon": "setup"}), "setup")
	expect_eq(WfwIcons.item_icon_string({"icon": "dos"}), "dos")
	expect(WfwIcons.is_external_item({"icon": "data:image/png;base64,AA=="}))
	expect(not WfwIcons.is_external_item({"icon": "data:image/png;base64,AA==", "win31Icon": "default"}))


func test_catalog_paths_point_at_32px_assets() -> void:
	for id in WfwIcons.IDS:
		var path := WfwIcons.catalog_path(id)
		expect(path.ends_with("%s-32.png" % id), "path for %s: %s" % [id, path])
		expect(FileAccess.file_exists(path) or ResourceLoader.exists(path), "asset exists: " + path)


func test_tokens_match_reference_metrics() -> void:
	expect_eq(WfwTokens.m("programCellWidth"), Win31GridLogic.CELL_W)
	expect_eq(WfwTokens.m("programCellHeight"), Win31GridLogic.CELL_H)
	expect_eq(WfwTokens.m("groupCellWidth"), Win31Arrange.GROUP_CELL_W)
	expect_eq(WfwTokens.m("groupCellHeight"), Win31Arrange.GROUP_CELL_H)
