extends TestCase
## Mac icon catalog: MACMAP ids, pass-through of user icons, assets present.


func test_catalog_ids_pass_through() -> void:
	for id in MacIconCatalog.MAC_IDS:
		expect_eq(MacIconCatalog.get_icon_id(id), id, id)


func test_design_macmap() -> void:
	expect_eq(MacIconCatalog.get_icon_id("folder-open"), "folder")
	expect_eq(MacIconCatalog.get_icon_id("group"), "folder")
	expect_eq(MacIconCatalog.get_icon_id("my-computer"), "volume")
	expect_eq(MacIconCatalog.get_icon_id("drive"), "volume")
	expect_eq(MacIconCatalog.get_icon_id("network"), "url")
	expect_eq(MacIconCatalog.get_icon_id("dos"), "terminal")
	expect_eq(MacIconCatalog.get_icon_id("clipbook"), "doc")
	expect_eq(MacIconCatalog.get_icon_id("control-panel"), "tools")
	expect_eq(MacIconCatalog.get_icon_id("question"), "note")
	expect_eq(MacIconCatalog.get_icon_id("warning"), "caution")
	expect_eq(MacIconCatalog.get_icon_id("critical"), "stop")
	expect_eq(MacIconCatalog.get_icon_id("recycle-empty"), "trash")


func test_unknown_and_empty_fall_back_to_application() -> void:
	expect_eq(MacIconCatalog.get_icon_id(""), "application")
	expect_eq(MacIconCatalog.get_icon_id("file-manager"), "application")
	expect_eq(MacIconCatalog.get_icon_id("default"), "application")
	expect_eq(MacIconCatalog.get_icon_id("zzz"), "application")


func test_external_icons_are_detected() -> void:
	expect(MacIconCatalog.is_external("data:image/png;base64,AAAA"))
	expect(MacIconCatalog.is_external("C:\\icons\\a.png"))
	expect(MacIconCatalog.is_external("/usr/share/icons/a.png"))
	expect(not MacIconCatalog.is_external("folder"))


func test_textures_resolve_for_every_size() -> void:
	for id in MacIconCatalog.MAC_IDS:
		for size in ["small", "large"]:
			var t := MacIconCatalog.texture(id, size)
			expect(t != null, "%s/%s missing" % [size, id])
			var native := 16 if size == "small" else 32
			expect_eq(t.get_size(), Vector2(native, native), "%s/%s native size" % [size, id])
	expect(MacIconCatalog.texture("data:image/png;base64,broken", "large") != null, "bad data URL falls back")
	expect(MacIconCatalog.logo("small") != null)
