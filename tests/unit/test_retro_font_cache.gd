extends TestCase
## RetroFont caches measure() and advance(): every hit must equal the uncached answer, and anything
## that changes the metrics (font_px, an atlas) must drop the cached values.

const SAMPLES := ["", "A", "Program Manager", "&File", "Save &As...", "a && b", "Tab\there", "Ünïcödé ÀÉÎ ß",
	"Привет", "שלום مرحبا", "日本語", "🙂 ⋯ ▾ ▸", "<>|`\"'*+,./=?\\_", "line\nbreak", "?"]


## measure() as it was before the caches: parse access keys, then sum the per-character advances.
func _uncached_measure(f: RetroFont, source: String, bold: bool) -> int:
	var w := 0
	for ch in String(RetroFont.parse_access(source).text):
		w += 12 if ch == "\t" else f._advance_uncached(ch, ch.unicode_at(0), bold)
	return w


func test_cached_measure_equals_uncached_for_both_families() -> void:
	for family in [RetroFont.WIN95, RetroFont.WFW]:
		var f := RetroFont.new(family)
		for bold in [false, true]:
			for s in SAMPLES:
				var expected := _uncached_measure(f, s, bold)
				expect_eq(f.measure(s, bold), expected, "%s miss %s %s" % [family, s, bold])
				expect_eq(f.measure(s, bold), expected, "%s hit %s %s" % [family, s, bold])


func test_regular_and_bold_are_cached_separately() -> void:
	var f := RetroFont.new(RetroFont.WIN95)
	var regular := f.measure("Wide Bold Text")
	var bold := f.measure("Wide Bold Text", true)
	expect(bold > regular, "bold advances are wider (+1 per glyph)")
	expect_eq(f.measure("Wide Bold Text"), regular)
	expect_eq(f.advance("W", true), f.advance("W") + 1)


func test_font_px_change_drops_cached_metrics() -> void:
	var f := RetroFont.new(RetroFont.WFW)
	var at11 := f.measure("Program Manager")
	var adv11 := f.advance("M")
	f.font_px = 22
	expect(f.measure("Program Manager") > at11, "stale 11 px width not reused at 22 px")
	expect(f.advance("M") > adv11, "stale 11 px advance not reused at 22 px")
	expect_eq(f.measure("Program Manager"), _uncached_measure(f, "Program Manager", false))
	f.font_px = 11
	expect_eq(f.measure("Program Manager"), at11)


func test_loading_an_atlas_drops_cached_metrics() -> void:
	var f := RetroFont.new(RetroFont.WIN95)
	expect_eq(f.measure("AA"), 14, "table width before the atlas")
	var img := Image.create(40, 8, false, Image.FORMAT_RGBA8)
	f.load_atlas(false, img, {"height": 8, "glyphs": {"65": {"x": 0, "width": 5, "advance": 9}, "63": {"x": 10, "width": 4, "advance": 4}}})
	expect_eq(f.measure("AA"), 18, "atlas advances, not the cached table width")
	expect_eq(f.advance("A"), 9)


func test_cache_is_bounded() -> void:
	var f := RetroFont.new(RetroFont.WIN95)
	for i in RetroFont.MEASURE_CACHE_MAX + 10:
		f.measure("item %d" % i)
	expect(f._measure_cache.size() <= RetroFont.MEASURE_CACHE_MAX, "cleared when full")
	expect_eq(f.measure("item 3"), _uncached_measure(f, "item 3", false), "still exact after a clear")


func test_shared_instances_stay_consistent() -> void:
	var f := RetroFont.instance(RetroFont.WFW)
	var w := f.measure("Accessories")
	expect_eq(RetroFont.instance(RetroFont.WFW).measure("Accessories"), w)
	expect_eq(Win31GridLogic.label_layout(f, "Accessories").box_w, w + Win31GridLogic.LABEL_PAD * 2)


func test_long_strings_are_measured_but_not_kept() -> void:
	var f := RetroFont.new(RetroFont.WFW)
	var long := "Program Files ".repeat(20)
	expect(long.length() > RetroFont.MEASURE_CACHE_MAX_LEN)
	expect_eq(f.measure(long), _uncached_measure(f, long, false))
	expect_eq(f._measure_cache.size(), 0, "a long field value is not cached")
	f.measure("Short label")
	expect_eq(f._measure_cache.size(), 1)
