extends TestCase
## Optional RTM bitmap-font atlas override (port of the atlas path in bitmapText.tsx).

func _atlas_font() -> RetroFont:
	var f := RetroFont.new(RetroFont.WIN95)
	var img := Image.create(40, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(1, 1, Color(0, 0, 0, 1))
	f.load_atlas(false, img, {"height": 8, "glyphs": {"65": {"x": 0, "width": 5, "advance": 9}, "63": {"x": 10, "width": 4, "advance": 4}}})
	return f


func test_atlas_advances_override_table() -> void:
	var plain := RetroFont.new(RetroFont.WIN95)
	var f := _atlas_font()
	expect(not plain.has_atlas(false))
	expect(f.has_atlas(false))
	expect_eq(f.advance("A"), 9)
	expect_eq(plain.advance("A"), 7)
	expect_eq(f.advance("Z"), 4, "unknown glyph falls back to '?'")
	expect_eq(f.measure("AA"), 18)
	expect_eq(f.advance("A", true), 8, "bold has no atlas: table advance (7+1)")
	expect_eq(f.advance("\t"), 12)


func test_wfw_family_ignores_atlas() -> void:
	expect(not RetroFont.new(RetroFont.WFW).has_atlas(false))
