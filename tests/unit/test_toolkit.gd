extends TestCase
## Ports of win95/tokens.test.ts, win95/primitives.test.ts (text part), win31/tokens + layout tests.

func test_auto_scale() -> void:
	for c in [[639, 479, 1], [640, 480, 1], [1279, 959, 1], [1280, 960, 2], [1920, 1080, 2], [2560, 1440, 3], [3840, 2160, 4], [10000, 10000, 4],
			[1366, 768, 1], [7680, 4320, 4], [400, 300, 1]]:
		expect_eq(ShellScale.resolve_auto(c[0], c[1]), c[2], "%dx%d" % [c[0], c[1]])
		expect_eq(Win95Tokens.resolve_auto_scale(c[0], c[1]), c[2])
		expect_eq(WfwTokens.resolve_auto_scale(c[0], c[1]), c[2])


func test_logical_viewport_and_raster_variant() -> void:
	expect_eq(ShellScale.logical_viewport_size(1920, 1080, 2), Vector2i(960, 540))
	expect_eq(ShellScale.logical_viewport_size(2561, 1441, 3), Vector2i(854, 481))
	expect_eq(ShellScale.raster_variant(1, 1), 1)
	expect_eq(ShellScale.raster_variant(2, 1.25), 3)
	expect_eq(ShellScale.raster_variant(3, 1.5), 4)
	expect_eq(ShellScale.raster_variant(4, 2), 4)
	expect_eq(ShellScale.to_logical_delta(96, 3), 32.0)
	expect_eq(ShellScale.to_logical_point(Vector2(330, 180), 3, Vector2(30, 30)), Vector2(100, 50))


func test_locked_token_values() -> void:
	for k in {"taskbarHeight": 28, "startButtonWidth": 54, "trayWidth": 63, "startMenuWidth": 164, "startMenuHeight": 235,
			"startTopItemHeight": 32, "captionHeight": 18, "captionButtonWidth": 16, "captionButtonHeight": 14,
			"runDialogWidth": 347, "runDialogHeight": 163, "shutdownDialogWidth": 347, "shutdownDialogHeight": 222}:
		expect_eq(Win95Tokens.m(k), {"taskbarHeight": 28, "startButtonWidth": 54, "trayWidth": 63, "startMenuWidth": 164, "startMenuHeight": 235,
			"startTopItemHeight": 32, "captionHeight": 18, "captionButtonWidth": 16, "captionButtonHeight": 14,
			"runDialogWidth": 347, "runDialogHeight": 163, "shutdownDialogWidth": 347, "shutdownDialogHeight": 222}[k], k)
	expect_eq(Pal.W95_DESKTOP.to_html(false), "008080")
	expect_eq(Pal.W95_HIGHLIGHT.to_html(false), "dfdfdf")
	expect_eq(Pal.W95_ACTIVE_CAPTION.to_html(false), "000080")


func test_bitmap_text_metrics() -> void:
	var f := RetroFont.instance(RetroFont.WIN95)
	expect_eq(RetroFont.parse_access("&Name && Location"), {"text": "Name & Location", "accessIndex": 0, "accessKey": "n"})
	expect_eq(f.measure("Start"), 22)
	expect_eq(f.measure("Start", true), 27)
	expect(f.advance("W") > f.advance("i"))
	expect_eq(f.clip("Programs", f.measure("Prog")), "Prog")
	expect_eq(Array(f.wrap("Network Neighborhood", 50)), ["Network", "Neighborh", "ood"])
	expect_eq(f.advance("\t"), 12)


func test_tile_layout() -> void:
	var three := Win31Layout.calculate_tile_layout(3, 600, 400)
	expect_eq(three.map(func(r): return [r.position.x, r.position.y, r.size.x, r.size.y]),
		[[0, 0, 300, 200], [300, 0, 300, 200], [0, 200, 600, 200]])
	var b := Win31Layout.calculate_tile_layout(5, 601, 401)
	var area := 0.0
	for r in b:
		area += r.size.x * r.size.y
	expect_eq(b.size(), 5)
	expect_eq(area, 601.0 * 401.0)
	expect_eq(Win31Layout.calculate_tile_layout(0, 600, 400), [])
