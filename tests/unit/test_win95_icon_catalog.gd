extends TestCase
## Port of win95/__tests__/iconCatalog.test.ts.


func test_maps_stored_legacy_ids_to_win95_owned_silhouettes() -> void:
	expect_eq(Win95IconCatalog.get_icon_id("default"), "application")
	expect_eq(Win95IconCatalog.get_icon_id("file-manager"), "drive")
	expect_eq(Win95IconCatalog.get_icon_id("control-panel"), "control-panel")
	expect_eq(Win95IconCatalog.get_icon_id("trash"), "recycle-empty")
	expect_eq(Win95IconCatalog.get_icon_id("web"), "url")
	expect_eq(Win95IconCatalog.get_icon_id("error"), "critical")
	expect_eq(Win95IconCatalog.get_icon_id("shortcut"), "new-shortcut")
	expect_eq(Win95IconCatalog.get_icon_id("properties"), "properties")
	expect_eq(Win95IconCatalog.get_icon_id("unknown-old-id"), "application")
	expect_eq(Win95IconCatalog.get_icon_id(""), "application")


func test_contains_the_native_size_families_needed_by_shell_surfaces() -> void:
	for id in ["my-computer", "network-neighborhood", "recycle-empty", "folder", "programs", "run", "find", "shutdown",
			"taskbar", "warning", "information", "question", "critical", "application", "url"]:
		expect(Win95IconCatalog.ICON_IDS.has(id), id)
	expect_eq(Win95IconCatalog.ICON_IDS.size(), 26)


func test_does_not_replace_extracted_application_icons() -> void:
	expect(Win95IconCatalog.is_external("data:image/png;base64,abc"))
	expect(Win95IconCatalog.is_external("C:\\Apps\\app.exe"))
	expect(Win95IconCatalog.is_external("file:///tmp/app.png"))
	expect(Win95IconCatalog.is_external("https://example.com/i.png"))
	expect(Win95IconCatalog.is_external("/usr/share/icons/a.png"))
	expect(not Win95IconCatalog.is_external("file-manager"))
	expect(not Win95IconCatalog.is_external("c:relative"))


func test_every_catalog_id_resolves_to_a_texture_of_its_native_size() -> void:
	for id in Win95IconCatalog.ICON_IDS:
		var large := Win95IconCatalog.texture(id, "large")
		var small := Win95IconCatalog.texture(id, "small")
		expect(large != null and large.get_size() == Vector2(32, 32), "large " + id)
		expect(small != null and small.get_size() == Vector2(16, 16), "small " + id)
	# unknown / external-without-file icons fall back to the application glyph
	expect(Win95IconCatalog.texture("nope", "large").get_size() == Vector2(32, 32))
	expect(Win95IconCatalog.texture("https://example.com/a.png", "small").get_size() == Vector2(16, 16))
