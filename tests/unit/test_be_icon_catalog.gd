extends TestCase
## BeIconCatalog: BEK / BEMAP / BE() port, name hash fallback, external icon pass-through.


func test_catalog_keys_pass_through() -> void:
	for k in BeIconCatalog.KEYS:
		expect_eq(BeIconCatalog.key_for(k), k)


func test_map_follows_the_design_table() -> void:
	expect_eq(BeIconCatalog.key_for("folder-open"), "folder")
	expect_eq(BeIconCatalog.key_for("my-computer"), "volume")
	expect_eq(BeIconCatalog.key_for("dos"), "terminal")
	expect_eq(BeIconCatalog.key_for("readme"), "doc")
	expect_eq(BeIconCatalog.key_for("control-panel"), "tools")
	expect_eq(BeIconCatalog.key_for("help"), "question")
	expect_eq(BeIconCatalog.key_for("program-manager"), "logo")
	expect_eq(BeIconCatalog.key_for("network"), "url")


func test_unknown_icons_hash_the_name_like_the_design() -> void:
	# h = h * 31 + code (uint32), icon = app-(h % 6); the name seeds it, the icon id is the fallback seed.
	expect_eq(BeIconCatalog.name_hash("Notes"), 75456161)
	expect_eq(BeIconCatalog.name_hash("Code Editor"), 3799866112, "values above 2^31 stay unsigned")
	expect_eq(BeIconCatalog.key_for("default", "Notes"), "app-%d" % (75456161 % 6))
	expect_eq(BeIconCatalog.key_for("clock", ""), "app-%d" % (BeIconCatalog.name_hash("clock") % 6))
	expect_eq(BeIconCatalog.name_hash(""), 0)
	var long_name := "zzzzzzzzzzzzzzzzzzz"
	expect(BeIconCatalog.name_hash(long_name) <= 0xFFFFFFFF, "stays unsigned 32-bit")
	for n in ["a", "File Manager", "Ünï"]:
		var key := BeIconCatalog.key_for("default", n)
		expect(key.begins_with("app-") and int(key.substr(4)) < BeIconCatalog.APP_VARIANTS, key)


func test_paths_and_textures_exist_for_every_key() -> void:
	var keys: Array = BeIconCatalog.KEYS.duplicate()
	for i in BeIconCatalog.APP_VARIANTS:
		keys.append("app-%d" % i)
	for k in keys:
		expect(ResourceLoader.exists(BeIconCatalog.path_for(k)), k)
		expect(BeIconCatalog.texture(k) != null, "texture " + k)


func test_external_icons_are_recognised_and_fall_back() -> void:
	expect(BeIconCatalog.is_external("data:image/png;base64,abc"))
	expect(BeIconCatalog.is_external("C:\\Apps\\a.png"))
	expect(not BeIconCatalog.is_external("folder"))
	# an unreadable external icon shows the generic application icon for the name
	var t := BeIconCatalog.texture("/definitely/not/here.png", "Notes")
	expect(t != null)
	expect(t == BeIconCatalog.texture("default", "Notes"))


func test_picker_options_are_distinct_images() -> void:
	var seen := {}
	for o in BeIconCatalog.picker_options():
		expect(not seen.has(o.key), "duplicate " + o.key)
		seen[o.key] = true
	expect(seen.size() >= 4)
