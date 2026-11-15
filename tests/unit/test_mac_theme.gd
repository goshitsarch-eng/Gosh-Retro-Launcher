extends TestCase
## Light/dark colour mapping of the design (DARK.b/t/s) and the draw helpers' text substitutions.


func test_light_theme_is_identity() -> void:
	MacTheme.dark = false
	expect_eq(MacTheme.b("dddddd"), Color("#dddddd"))
	expect_eq(MacTheme.t("000000"), Color("#000000"))
	expect_eq(MacTheme.s("ffffff"), Color("#ffffff"))
	expect_eq(MacTheme.desktop(), Color("#6c6ca8"))


func test_dark_theme_maps_like_the_design() -> void:
	MacTheme.dark = true
	expect_eq(MacTheme.b("dddddd"), Color("#323337"))
	expect_eq(MacTheme.b("ffffff"), Color("#1d1e21"))
	expect_eq(MacTheme.b("33339a"), Color("#4a4ab8"))
	expect_eq(MacTheme.t("000000"), Color("#e3e4e6"))
	expect_eq(MacTheme.s("ffffff"), Color("#58595f"))
	expect_eq(MacTheme.desktop(), Color("#2b2b46"))
	expect_eq(MacTheme.b("123456"), Color("#123456"), "unmapped hex passes through")
	MacTheme.dark = false


func test_desktop_override_wins() -> void:
	MacTheme.desk_override = "#3a6a8a"
	expect_eq(MacTheme.desktop(), Color("#3a6a8a"))
	MacTheme.desk_override = ""


func test_glyph_safe_substitutes_missing_glyphs() -> void:
	expect_eq(MacDraw.glyph_safe("Find\u2026"), "Find...")
	expect_eq(MacDraw.glyph_safe("\u201cX\u201d"), "\"X\"")
	expect_eq(MacDraw.glyph_safe("\u2014"), "-")


func test_label_lines_wrap_and_ellipsize() -> void:
	var wrapped := MacDraw.label_lines("Alpha Beta Gamma Delta Epsilon Zeta", 60, true)
	expect(wrapped.size() <= 2 and wrapped.size() >= 2)
	expect(String(wrapped[wrapped.size() - 1]).ends_with("..."), "overflow is ellipsized on the last line")
	var one := MacDraw.label_lines("A very long label that cannot fit", 60, false)
	expect_eq(one.size(), 1)
	expect(MacDraw.measure(one[0]) <= 60)
