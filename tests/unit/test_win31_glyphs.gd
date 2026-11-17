extends TestCase
## WfW text shows shared wording as written: the font now draws stand-ins for the ASCII punctuation
## its faces lack, so the old ">" -> "-" rewrite is gone; characters with no stand-in (bold curly
## quotes, "…", "×", "→") are spelled out; message text and names show "&" literally.


func test_drawable_spells_out_only_what_the_face_lacks() -> void:
	expect_eq(W31.drawable("Plain text"), "Plain text")
	expect_eq(W31.drawable("Launcher Tools > Backups"), "Launcher Tools > Backups", "a > is drawn by the font now")
	expect_eq(W31.drawable("Bob’s “Notes”", true), "Bob's \"Notes\"", "the bold face has no curly quotes")
	expect_eq(W31.drawable("Bob’s “Notes”", false), "Bob’s “Notes”", "the regular face has them")
	expect_eq(W31.drawable("milk and eggs…"), "milk and eggs...")
	expect_eq(W31.drawable("2×"), "2x")
	expect_eq(W31.drawable("File → New"), "File -> New")
	var f := RetroFont.instance(RetroFont.WFW)
	for ch in W31.GLYPH_FALLBACKS:
		for bold in [false, true]:
			var out := W31.drawable(ch, bold)
			for c in out:
				expect(f._f(bold).has_char(c.unicode_at(0)) or (RetroFont._SYNTH_BOLD if bold else RetroFont._SYNTH_NORMAL).has(c),
					"%s (bold %s) -> %s is drawable" % [ch, bold, out])


func test_bold_apostrophe_titles_measure_and_clip() -> void:
	var f := W31.font()
	expect(W31.text_w("Bob's Notes", 11, true) > W31.text_w("Bobs Notes", 11, true), "the bold ' takes room")
	expect_eq(W31.text_w("Bob’s Notes", 11, true), W31.text_w("Bob's Notes", 11, true), "a curly ’ is drawn as '")
	var clipped := f.clip(W31.drawable("What’s new?", true), 400, true)
	expect_eq(clipped, "What's new?")


func test_shared_wording_is_not_rewritten() -> void:
	expect(not W31DialogLogic.new().has_method("wfw_text"), "the > rewrite is gone")
	var src := FileAccess.get_file_as_string("res://src/shells/win31/win31_shell.gd")
	expect(not src.contains("wfw_text"), "Export All / Import All show the shared wording")


func test_paragraphs_are_literal() -> void:
	var lines := W31Dialog.paragraph_lines("Group 1: Morning & Mail has 2 programs.", 400)
	expect_eq(lines, PackedStringArray(["Group 1: Morning & Mail has 2 programs."]))
	expect_eq(W31Dialog.paragraph_lines("A && B", 400)[0], "A && B")
	var wrapped := W31Dialog.paragraph_lines("Your current setup is backed up first, so you can get it back from Launcher Tools > Backups.", 200)
	expect(wrapped.size() > 1)
	expect(wrapped[wrapped.size() - 1].ends_with("> Backups.") or "".join(wrapped).contains(">"), str(wrapped))


func test_window_menu_shows_group_names_literally() -> void:
	var groups := [{"id": "a", "name": "Q&A", "items": []}]
	var menus := Win31Commands.build_menus(groups, "a", {}, {})
	var win: Array = menus[2].items
	var row: Dictionary = win[win.size() - 1]
	expect_eq(RetroFont.parse_access(row.label).text, "1 Q&A")
	expect_eq(RetroFont.parse_access(row.label).accessKey, "1")


func test_grid_labels_spell_out_missing_glyphs() -> void:
	expect_eq(Win31GridLogic.lit("Q&A…"), "Q&&A...")
	expect_eq(W31Combo.fit_label("2×", 200), "2x")
