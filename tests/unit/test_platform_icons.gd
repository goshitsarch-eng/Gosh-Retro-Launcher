extends TestCase
## Icon extraction: ICO (PNG + BMP/DIB entries), PE resources, ICNS, plist, palette quantization.

func _px(img: Image, x: int, y: int) -> Color:
	return img.get_pixel(x, y)


func _is_color(c: Color, r: int, g: int, b: int, a: int = 255, tol: int = 0) -> bool:
	return absi(c.r8 - r) <= tol and absi(c.g8 - g) <= tol and absi(c.b8 - b) <= tol and absi(c.a8 - a) <= tol


func _expect_quad(img: Image, size: int, label: String, check_alpha_hole: bool = true) -> void:
	expect(img != null, label + ": decoded")
	if img == null:
		return
	expect_eq(img.get_width(), size, label + " width")
	expect_eq(img.get_height(), size, label + " height")
	var h := size / 2
	expect(_is_color(_px(img, size - 1, 0), 0, 255, 0), label + " top-right green")
	expect(_is_color(_px(img, 0, size - 1), 0, 0, 255), label + " bottom-left blue")
	expect(_is_color(_px(img, size - 1, size - 1), 255, 255, 0), label + " bottom-right yellow")
	expect(_is_color(_px(img, h - 1, h - 1), 255, 0, 0), label + " top-left red")
	if check_alpha_hole:
		expect_eq(_px(img, 0, 0).a8, 0, label + " transparent corner")
		expect_eq(_px(img, 1, 1).a8, 0, label + " transparent corner 2")
		expect_eq(_px(img, 2, 2).a8, 255, label + " opaque inside")


# --------------------------------------------------------------------------- ICO / DIB

func test_dib_depths_roundtrip() -> void:
	var src := PlatformFixtures.quad(16)
	for bpp in [32, 24, 8]:
		var dib := PlatformFixtures.build_dib(src, bpp)
		var img := IcoFile.decode_dib(dib)
		_expect_quad(img, 16, "dib%d" % bpp)


func test_dib_1bpp_two_colours() -> void:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color8(0, 0, 0))
	img.fill_rect(Rect2i(8, 0, 8, 16), Color8(255, 255, 255))
	var out := IcoFile.decode_dib(PlatformFixtures.build_dib(img, 1, false))
	expect(out != null)
	expect(_is_color(_px(out, 0, 5), 0, 0, 0))
	expect(_is_color(_px(out, 15, 5), 255, 255, 255))
	expect(_is_color(_px(out, 7, 15), 0, 0, 0))
	expect(_is_color(_px(out, 8, 15), 255, 255, 255))


func test_dib_32bit_with_zero_alpha_uses_and_mask() -> void:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color8(10, 20, 30, 255))
	var dib := PlatformFixtures.build_dib(img, 32, true)
	# Zero every alpha byte: legacy icons rely on the AND mask when the alpha channel is empty.
	var stride := 8 * 4
	for row in 8:
		for x in 8:
			dib[40 + row * stride + x * 4 + 3] = 0
	var out := IcoFile.decode_dib(dib)
	expect(out != null)
	expect_eq(_px(out, 3, 3).a8, 255, "mask says opaque -> alpha restored")
	# ... and a masked-out pixel stays transparent.
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	var dib2 := PlatformFixtures.build_dib(img, 32, true)
	for row in 8:
		for x in 8:
			dib2[40 + row * stride + x * 4 + 3] = 0
	var out2 := IcoFile.decode_dib(dib2)
	expect_eq(_px(out2, 0, 0).a8, 0)
	expect_eq(_px(out2, 1, 0).a8, 255)


func test_ico_picks_largest_entry_png_and_bmp() -> void:
	var ico := PlatformFixtures.build_ico([
		{"image": PlatformFixtures.quad(16), "bpp": 32},
		{"image": PlatformFixtures.quad(48), "png": true},
		{"image": PlatformFixtures.quad(32), "bpp": 8},
	])
	expect(IcoFile.is_ico(ico))
	expect_eq(IcoFile.parse_entries(ico).size(), 3)
	_expect_quad(IcoFile.best_image(ico), 48, "png entry wins")
	var bmp_only := PlatformFixtures.build_ico([
		{"image": PlatformFixtures.quad(16), "bpp": 24},
		{"image": PlatformFixtures.quad(32), "bpp": 32},
	])
	_expect_quad(IcoFile.best_image(bmp_only), 32, "bmp entry wins")


func test_ico_256_entry_uses_zero_dimension_convention() -> void:
	var big := PlatformFixtures.quad(256)
	var ico := PlatformFixtures.build_ico([{"image": PlatformFixtures.quad(32), "bpp": 32}, {"image": big, "png": true}])
	var entries := IcoFile.parse_entries(ico)
	expect_eq(entries[1].width, 256)
	_expect_quad(IcoFile.best_image(ico), 256, "256px")


func test_ico_falls_back_when_best_entry_is_corrupt() -> void:
	var ico := PlatformFixtures.build_ico([
		{"image": PlatformFixtures.quad(32), "bpp": 32},
		{"image": PlatformFixtures.quad(64), "png": true},
	])
	# Corrupt the PNG payload (second entry) but keep the directory valid.
	var entries := IcoFile.parse_entries(ico)
	var off: int = entries[1].offset
	for i in 16:
		ico[off + 8 + i] = 0
	_expect_quad(IcoFile.best_image(ico), 32, "falls back to the BMP entry")


func test_ico_malformed_inputs_are_safe() -> void:
	expect_null(IcoFile.best_image(PackedByteArray()))
	expect_null(IcoFile.best_image(PackedByteArray([0, 0, 1, 0, 1, 0, 1])))
	var junk := PackedByteArray()
	for i in 200:
		junk.append((i * 37) & 0xff)
	expect_null(IcoFile.best_image(junk))
	expect_null(IcoFile.decode_dib(junk))
	var ico := PlatformFixtures.build_ico([{"image": PlatformFixtures.quad(32), "bpp": 32}])
	expect_null(IcoFile.best_image(ico.slice(0, ico.size() - 40)), "truncated image data")
	# Header claims a gigantic image.
	var dib := PlatformFixtures.build_dib(PlatformFixtures.quad(16), 32)
	dib.encode_s32(4, 100000)
	expect_null(IcoFile.decode_dib(dib))


# --------------------------------------------------------------------------- PE

func test_pe_extracts_largest_icon_of_first_group() -> void:
	var pe := PlatformFixtures.build_pe([[
		{"image": PlatformFixtures.quad(16), "bpp": 32},
		{"image": PlatformFixtures.quad(32), "bpp": 8},
		{"image": PlatformFixtures.quad(64), "png": true},
	]])
	_expect_quad(PeIcon.image_from_bytes(pe), 64, "pe32 png group")
	_expect_quad(PeIcon.image_from_bytes(PlatformFixtures.build_pe([[
		{"image": PlatformFixtures.quad(16), "bpp": 32},
		{"image": PlatformFixtures.quad(48), "bpp": 24},
	]], true)), 48, "pe32+ bmp group")


func test_pe_uses_first_group_not_largest_group() -> void:
	var pe := PlatformFixtures.build_pe([
		[{"image": PlatformFixtures.quad(32), "bpp": 32}],
		[{"image": PlatformFixtures.quad(64), "bpp": 32}],
	])
	_expect_quad(PeIcon.image_from_bytes(pe), 32, "first group is the application icon")


func test_pe_falls_back_to_decodable_entry() -> void:
	var pe := PlatformFixtures.build_pe([[
		{"image": PlatformFixtures.quad(32), "bpp": 32},
		{"image": PlatformFixtures.quad(64), "png": true},
	]])
	# Smash the PNG signature of the 64px resource (it is the second RT_ICON blob).
	var sig := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	var at := _find(pe, sig)
	expect(at > 0)
	pe[at + 1] = 0x00
	_expect_quad(PeIcon.image_from_bytes(pe), 32, "falls back to the DIB icon")


func test_pe_from_file_reads_only_resource_section() -> void:
	var dir := PlatformFixtures.tmp_dir()
	var pe := PlatformFixtures.build_pe([[{"image": PlatformFixtures.quad(32), "bpp": 32}]])
	var path := PlatformFixtures.write_bytes(dir.path_join("app.exe"), pe)
	_expect_quad(PeIcon.load_image(path), 32, "file load")
	# A multi-megabyte "payload" appended after the resources must not matter.
	var big := pe.duplicate()
	big.resize(pe.size() + 3 * 1024 * 1024)
	var big_path := PlatformFixtures.write_bytes(dir.path_join("big.dll"), big)
	_expect_quad(PeIcon.load_image(big_path), 32, "padded file")
	PlatformFixtures.rm_rf(dir)


func test_pe_rejects_non_pe_and_truncated() -> void:
	expect_null(PeIcon.image_from_bytes(PackedByteArray()))
	expect_null(PeIcon.image_from_bytes("MZ".to_ascii_buffer()))
	var junk := PackedByteArray()
	junk.resize(1024)
	junk[0] = 0x4D
	junk[1] = 0x5A
	junk.encode_u32(0x3C, 0x80)
	expect_null(PeIcon.image_from_bytes(junk), "MZ without PE header")
	var pe := PlatformFixtures.build_pe([[{"image": PlatformFixtures.quad(32), "bpp": 32}]])
	expect_null(PeIcon.image_from_bytes(pe.slice(0, 0x180)), "cut inside the headers")
	expect_null(PeIcon.image_from_bytes(pe.slice(0, pe.size() - 600)), "cut inside the resource data")
	expect_null(PeIcon.load_image("/nonexistent/file.exe"))
	# Resource directory with a self-referencing subdirectory must terminate.
	var loop := PlatformFixtures.build_pe([[{"image": PlatformFixtures.quad(16), "bpp": 32}]])
	var rsrc_ptr := 0x200
	loop.encode_u32(rsrc_ptr + 20, 0x80000000 | 0)
	expect_null(PeIcon.image_from_bytes(loop))


func _find(hay: PackedByteArray, needle: PackedByteArray) -> int:
	for i in range(0, hay.size() - needle.size()):
		var ok := true
		for j in needle.size():
			if hay[i + j] != needle[j]:
				ok = false
				break
		if ok:
			return i
	return -1


# --------------------------------------------------------------------------- ICNS

func test_icns_picks_largest_png_element() -> void:
	var small := PlatformFixtures.quad(32).save_png_to_buffer()
	var large := PlatformFixtures.quad(128).save_png_to_buffer()
	var icns := PlatformFixtures.icns_build([
		PlatformFixtures.icns_element("icp5", small),
		PlatformFixtures.icns_element("ic07", large),
	])
	expect(IcnsFile.is_icns(icns))
	expect_eq(IcnsFile.parse_elements(icns).size(), 2)
	_expect_quad(IcnsFile.best_image(icns), 128, "icns png")


func test_icns_legacy_rle_with_mask() -> void:
	var src := PlatformFixtures.quad(32)
	var r := PackedByteArray()
	var g := PackedByteArray()
	var b := PackedByteArray()
	var m := PackedByteArray()
	for y in 32:
		for x in 32:
			var c := src.get_pixel(x, y)
			r.append(c.r8)
			g.append(c.g8)
			b.append(c.b8)
			m.append(c.a8)
	var rgb := PlatformFixtures.icns_pack_rle(r)
	rgb.append_array(PlatformFixtures.icns_pack_rle(g))
	rgb.append_array(PlatformFixtures.icns_pack_rle(b))
	var icns := PlatformFixtures.icns_build([
		PlatformFixtures.icns_element("il32", rgb),
		PlatformFixtures.icns_element("l8mk", m),
	])
	_expect_quad(IcnsFile.best_image(icns), 32, "il32 + l8mk")


func test_icns_it32_has_four_byte_prefix_and_argb_type() -> void:
	var size := 128
	var plane := PackedByteArray()
	plane.resize(size * size)
	plane.fill(200)
	var body := PackedByteArray([0, 0, 0, 0])
	for _i in 3:
		body.append_array(PlatformFixtures.icns_pack_rle(plane))
	var icns := PlatformFixtures.icns_build([PlatformFixtures.icns_element("it32", body)])
	var img := IcnsFile.best_image(icns)
	expect(img != null)
	expect_eq(img.get_width(), 128)
	expect(_is_color(_px(img, 64, 64), 200, 200, 200))
	# ARGB (ic05): "ARGB" + four RLE planes A,R,G,B
	var n := 32 * 32
	var a_plane := PackedByteArray()
	a_plane.resize(n)
	a_plane.fill(128)
	var r_plane := PackedByteArray()
	r_plane.resize(n)
	r_plane.fill(10)
	var g_plane := PackedByteArray()
	g_plane.resize(n)
	g_plane.fill(20)
	var b_plane := PackedByteArray()
	b_plane.resize(n)
	b_plane.fill(30)
	var argb := "ARGB".to_ascii_buffer()
	for p in [a_plane, r_plane, g_plane, b_plane]:
		argb.append_array(PlatformFixtures.icns_pack_rle(p))
	var img2 := IcnsFile.best_image(PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic05", argb)]))
	expect(img2 != null)
	expect(_is_color(_px(img2, 5, 5), 10, 20, 30, 128))


func test_icns_skips_jpeg2000_and_garbage() -> void:
	var jp2 := PackedByteArray([0, 0, 0, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A, 1, 2, 3, 4])
	expect_null(IcnsFile.best_image(PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic09", jp2)])))
	expect_null(IcnsFile.best_image(PackedByteArray([1, 2, 3])))
	expect_null(IcnsFile.best_image("icns".to_ascii_buffer()))
	var truncated := PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic07", PlatformFixtures.quad(128).save_png_to_buffer())])
	expect_null(IcnsFile.best_image(truncated.slice(0, 40)))
	# RLE stream that ends early must not decode.
	expect_eq(IcnsFile.unpack_rle(PackedByteArray([5, 1, 2]), 0, 6), {})
	expect_eq(Array(IcnsFile.unpack_rle(PackedByteArray([128, 9]), 0, 3).data), [9, 9, 9])


# --------------------------------------------------------------------------- plist / bundle

func test_plist_xml_and_binary() -> void:
	var xml := '<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleName</key><string>My &amp; App</string><key>CFBundleIconFile</key><string>AppIcon</string><key>LSUIElement</key><true/><key>N</key><integer>42</integer></dict></plist>'
	var d := PlistReader.parse(xml.to_utf8_buffer())
	expect_eq(d.get("CFBundleName"), "My & App")
	expect_eq(d.get("CFBundleIconFile"), "AppIcon")
	expect_eq(d.get("LSUIElement"), true)
	expect_eq(d.get("N"), 42)
	var bin := PlistReader.parse(PlatformFixtures.plist_binary({"CFBundleIconFile": "icon.icns", "N": 7, "Flag": true}))
	expect_eq(bin.get("CFBundleIconFile"), "icon.icns")
	expect_eq(bin.get("N"), 7)
	expect_eq(bin.get("Flag"), true)
	expect_eq(PlistReader.parse("bplist00garbage".to_ascii_buffer()), {})
	expect_eq(PlistReader.parse(PackedByteArray()), {})


func test_app_bundle_icon_lookup() -> void:
	var dir := PlatformFixtures.tmp_dir()
	var icns := PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic07", PlatformFixtures.quad(128).save_png_to_buffer())])
	# Name without extension in an XML plist.
	var app := dir.path_join("Demo.app")
	PlatformFixtures.write_text(app.path_join("Contents/Info.plist"), '<plist><dict><key>CFBundleIconFile</key><string>AppIcon</string></dict></plist>')
	PlatformFixtures.write_bytes(app.path_join("Contents/Resources/AppIcon.icns"), icns)
	PlatformFixtures.write_bytes(app.path_join("Contents/Resources/Other.icns"), icns)
	expect_eq(AppBundle.icon_path(app), app.path_join("Contents/Resources/AppIcon.icns"))
	_expect_quad(AppBundle.icon_image(app), 128, "bundle icon")
	# Binary plist with an explicit extension.
	var app2 := dir.path_join("Bin.app")
	PlatformFixtures.write_bytes(app2.path_join("Contents/Info.plist"), PlatformFixtures.plist_binary({"CFBundleIconFile": "x.icns"}))
	PlatformFixtures.write_bytes(app2.path_join("Contents/Resources/x.icns"), icns)
	expect_eq(AppBundle.icon_path(app2), app2.path_join("Contents/Resources/x.icns"))
	# Missing plist: first icns in Resources (alphabetical).
	var app3 := dir.path_join("Noplist.app")
	PlatformFixtures.write_bytes(app3.path_join("Contents/Resources/b.icns"), icns)
	PlatformFixtures.write_bytes(app3.path_join("Contents/Resources/a.icns"), icns)
	expect_eq(AppBundle.icon_path(app3), app3.path_join("Contents/Resources/a.icns"))
	expect_eq(AppBundle.icon_path(dir.path_join("Empty.app")), "")
	expect(AppBundle.is_bundle_path("/Applications/Foo.app"))
	expect(AppBundle.is_bundle_path("/Applications/Foo.APP/"))
	expect(not AppBundle.is_bundle_path("/Applications/Foo.application"))
	PlatformFixtures.rm_rf(dir)


# --------------------------------------------------------------------------- palette

func test_palette_matches_ts_table() -> void:
	expect_eq(IconImage.WFW_PALETTE.size(), 16)
	expect_eq(IconImage.WFW_PALETTE[0], [0, 0, 0])
	expect_eq(IconImage.WFW_PALETTE[2], [192, 192, 192])
	expect_eq(IconImage.WFW_PALETTE[15], [255, 0, 255])
	for i in 16:
		var c: Array = IconImage.WFW_PALETTE[i]
		expect_eq(IconImage.nearest_index(c[0], c[1], c[2]), i, "palette colour %d maps to itself" % i)


func test_nearest_colour_cases() -> void:
	expect_eq(IconImage.nearest_index(250, 250, 250), 3)  # white
	expect_eq(IconImage.nearest_index(10, 10, 10), 0)     # black
	expect_eq(IconImage.nearest_index(0, 0, 100), 4)      # navy
	expect_eq(IconImage.nearest_index(100, 100, 100), 1)  # grey 128 (closer than 192 or black)
	expect_eq(IconImage.nearest_index(255, 100, 0), 11)   # red
	expect_eq(IconImage.nearest_index(0, 200, 200), 14)   # cyan
	# Exact tie between black and grey(128)? 64 is equidistant: first palette entry wins.
	expect_eq(IconImage.nearest_index(64, 64, 64), 0)


func test_quantize_keeps_alpha_and_skips_transparent_pixels() -> void:
	var img := Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color8(250, 250, 250, 255))
	img.set_pixel(1, 0, Color8(17, 33, 77, 15))     # alpha < 16: untouched
	img.set_pixel(2, 0, Color8(17, 33, 77, 16))     # alpha == 16: quantized
	img.set_pixel(3, 0, Color8(0, 0, 120, 200))     # semi transparent: quantized, alpha kept
	var q := IconImage.quantize_to_wfw(img)
	expect(_is_color(q.get_pixel(0, 0), 255, 255, 255))
	expect(_is_color(q.get_pixel(1, 0), 17, 33, 77, 15))
	expect(_is_color(q.get_pixel(2, 0), 0, 0, 128, 16), "(17,33,77) is closer to navy than to black")
	expect(_is_color(q.get_pixel(3, 0), 0, 0, 128, 200))
	# Source untouched.
	expect(_is_color(img.get_pixel(0, 0), 250, 250, 250))


func test_icons_from_image_sizes_and_palette() -> void:
	var src := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			src.set_pixel(x, y, Color8(x, y, (x + y) / 2, 255))
	var icons := IconImage.icons_from_image(src)
	expect(String(icons.get("icon", "")).begins_with("data:image/png;base64,"))
	var big := Assets.from_data_url(icons.icon)
	expect_eq(big.get_width(), 128)
	expect_eq(big.get_height(), 128)
	var small := Assets.from_data_url(icons.win31Icon)
	expect_eq(small.get_width(), 32)
	var simg := small.get_image()
	simg.convert(Image.FORMAT_RGBA8)
	var palette := {}
	for c in IconImage.WFW_PALETTE:
		palette[(int(c[0]) << 16) | (int(c[1]) << 8) | int(c[2])] = true
	for y in 32:
		for x in 32:
			var c := simg.get_pixel(x, y)
			expect(palette.has((c.r8 << 16) | (c.g8 << 8) | c.b8), "pixel %d,%d in palette" % [x, y])
	expect_eq(IconImage.icons_from_image(null), {})
	expect_eq(IconImage.icons_from_image(Image.new()), {})


func test_non_square_images_are_letterboxed_not_stretched() -> void:
	var src := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	src.fill(Color8(255, 0, 0))
	var out := IconImage.fit_square(src, 128)
	expect_eq(out.get_size(), Vector2i(128, 128))
	expect_eq(out.get_pixel(64, 0).a8, 0, "top padding")
	expect_eq(out.get_pixel(64, 127).a8, 0, "bottom padding")
	expect_eq(out.get_pixel(64, 64).a8, 255)
	expect_eq(out.get_pixel(0, 64).a8, 255, "full width used")


func test_load_any_sniffs_formats() -> void:
	var quad := PlatformFixtures.quad(32)
	expect_eq(IconImage.load_any(quad.save_png_to_buffer()).get_size(), Vector2i(32, 32))
	var rgb := quad.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	expect_eq(IconImage.load_any(rgb.save_jpg_to_buffer()).get_size(), Vector2i(32, 32))
	expect_eq(IconImage.load_any(quad.save_webp_to_buffer()).get_size(), Vector2i(32, 32))
	expect_eq(IconImage.load_any(PlatformFixtures.build_ico([{"image": quad, "bpp": 32}])).get_size(), Vector2i(32, 32))
	var icns := PlatformFixtures.icns_build([PlatformFixtures.icns_element("ic07", PlatformFixtures.quad(128).save_png_to_buffer())])
	expect_eq(IconImage.load_any(icns).get_size(), Vector2i(128, 128))
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="#f00"/></svg>'
	var s := IconImage.load_any(svg.to_utf8_buffer(), 64)
	expect(s != null)
	expect_eq(s.get_size(), Vector2i(64, 64))
	expect(_is_color(s.get_pixel(32, 32), 255, 0, 0))
	expect_null(IconImage.load_any("not an image at all".to_utf8_buffer()))
	expect_null(IconImage.load_any(PackedByteArray()))
	expect_null(IconImage.load_file("/nonexistent/none.png"))
