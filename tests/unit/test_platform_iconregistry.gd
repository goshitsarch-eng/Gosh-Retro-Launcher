extends TestCase
## Port of src/renderer/src/utils/__tests__/icons.test.ts (semantics, not data-URL equality) + catalog checks.

func _default_src() -> String:
	return IconRegistry.builtin_path("default")


func test_builtin_id_resolves_to_its_asset() -> void:
	expect_eq(IconRegistry.get_icon_src("web"), "res://assets/builtin_icons/web.svg")
	var tex := IconRegistry.resolve("web")
	expect(tex != null)
	expect_eq(tex.get_size(), Vector2(32, 32))
	expect(tex == IconRegistry.builtin_texture("web"), "resolve returns the cached builtin texture")


func test_empty_returns_default() -> void:
	expect_eq(IconRegistry.get_icon_src(""), _default_src())
	expect(IconRegistry.resolve("") == IconRegistry.default_item_texture())
	expect(IconRegistry.default_item_texture() != null)


func test_legacy_names() -> void:
	expect_eq(IconRegistry.get_icon_src("default-item.png"), _default_src())
	expect_eq(IconRegistry.get_icon_src("folder.png"), IconRegistry.builtin_path("folder"))
	expect_eq(IconRegistry.get_icon_src("question.png"), IconRegistry.builtin_path("question"))
	expect_eq(IconRegistry.get_icon_src("program-manager.png"), IconRegistry.builtin_path("program-manager"))
	for legacy in ["default-item.png", "folder.png", "question.png", "program-manager.png"]:
		expect(IconRegistry.resolve(legacy) != null, legacy)
	expect(IconRegistry.resolve("question.png") != IconRegistry.default_item_texture(), "question icon is its own image")


func test_passes_through_data_and_http_urls() -> void:
	var data_url := "data:image/png;base64,abc123"
	expect_eq(IconRegistry.get_icon_src(data_url), data_url)
	var http_url := "https://example.com/icon.png"
	expect_eq(IconRegistry.get_icon_src(http_url), http_url)


func test_windows_and_unix_paths() -> void:
	expect_eq(IconRegistry.get_icon_src("C:\\icons\\test.png"), "file:///C:/icons/test.png")
	expect_eq(IconRegistry.get_icon_src("d:/x/y.ico"), "file:///d:/x/y.ico")
	expect_eq(IconRegistry.get_icon_src("\\\\server\\share\\i.png"), "file://server/share/i.png")
	expect_eq(IconRegistry.get_icon_src("/usr/share/icon.png"), "/usr/share/icon.png")
	expect_eq(IconRegistry.get_icon_src("file:///tmp/a.png"), "file:///tmp/a.png")


func test_unknown_strings_fall_back_to_default() -> void:
	expect_eq(IconRegistry.get_icon_src("some-random-string"), _default_src())
	expect_eq(IconRegistry.get_icon_src("relative/path.png"), _default_src())
	expect(IconRegistry.resolve("some-random-string") == IconRegistry.default_item_texture())


func test_file_url_to_path() -> void:
	expect_eq(IconRegistry.file_url_to_path("file:///C:/icons/test.png"), "C:/icons/test.png")
	expect_eq(IconRegistry.file_url_to_path("file:///usr/share/a%20b.png"), "/usr/share/a b.png")
	expect_eq(IconRegistry.file_url_to_path("file://server/share/i.png"), "//server/share/i.png")


func test_resolve_data_url_file_and_http() -> void:
	var img := Image.create_empty(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color8(1, 2, 3))
	var url := IconImage.to_data_url(img)
	expect_eq(IconRegistry.resolve(url).get_size(), Vector2(8, 6))
	expect(IconRegistry.resolve("data:image/png;base64,AAAA") == IconRegistry.default_item_texture(), "undecodable data url")
	expect(IconRegistry.resolve("https://example.com/x.png") == IconRegistry.default_item_texture(), "no network fetch")
	var dir := PlatformFixtures.tmp_dir()
	var path := dir.path_join("icon.png")
	img.save_png(path)
	expect_eq(IconRegistry.resolve(path).get_size(), Vector2(8, 6))
	expect_eq(IconRegistry.resolve("file://" + path).get_size(), Vector2(8, 6))
	expect(IconRegistry.resolve(dir.path_join("missing.png")) == IconRegistry.default_item_texture())
	PlatformFixtures.rm_rf(dir)


func test_catalog_is_complete_and_loads() -> void:
	var list := IconRegistry.builtin_list()
	expect_eq(list.size(), 80)
	expect_eq(list[0].id, "default")
	expect_eq(list[1].id, "folder")
	expect_eq(list[2].id, "web")
	expect_eq(list[list.size() - 1].id, "moon")
	var seen := {}
	for e in list:
		expect(not seen.has(e.id), "duplicate id " + e.id)
		seen[e.id] = true
		expect(String(e.name) != "")
		var tex := IconRegistry.builtin_texture(e.id)
		expect(tex != null, "texture for " + e.id)
		if tex:
			expect_eq(tex.get_size(), Vector2(32, 32), e.id)
	expect(IconRegistry.builtin_texture("nope") == null)


func test_svg_text_replacements_render_ink() -> void:
	# terminal/calendar/money used <text> (ignored by Godot's SVG rasterizer): glyph paths must paint.
	var g := IconRegistry.builtin_texture("terminal").get_image()
	var green := 0
	for y in 32:
		for x in 32:
			var c := g.get_pixel(x, y)
			if c.g > 0.8 and c.r < 0.3 and c.b < 0.3:
				green += 1
	expect(green > 20, "terminal prompt drawn (%d green px)" % green)


func test_scaled_textures() -> void:
	expect_eq(IconRegistry.texture_scaled("web", 4).get_size(), Vector2(128, 128))
	expect(IconRegistry.texture_scaled("web", 4) == IconRegistry.texture_scaled("web", 4), "cached")
	expect_eq(IconRegistry.texture_scaled("web", 1).get_size(), Vector2(32, 32))
	expect_eq(IconRegistry.texture_scaled("default", 3).get_size(), Vector2(32, 32), "png icons are not re-rasterized")
