extends TestCase
## CORE-02 (dispatch side): navigation keys are never item shortcuts in the WfW shell.

const NAV := [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_SPACE, KEY_BACKSPACE, KEY_DELETE,
	KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN]


static func _ev(code: Key, ctrl: bool = false, alt: bool = false, shift: bool = false, meta: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	e.shift_pressed = shift
	e.meta_pressed = meta
	return e


func test_key_names_of_navigation_keys_are_navigation() -> void:
	for code in NAV:
		var name := Win31Commands.key_name(_ev(code))
		expect(Win31Commands.is_navigation_key(name), "%s (%d) is a navigation key" % [name, code])


func test_navigation_keys_never_match_bare_or_with_modifiers() -> void:
	for code in NAV:
		var name := Win31Commands.key_name(_ev(code))
		var stored := OS.get_keycode_string(code)  # how the key would be typed in a Shortcut Key field
		for shortcut in [name, stored, "Ctrl+" + stored, "Alt+" + stored, "Shift+" + stored, "Ctrl+Alt+" + stored, "Win+" + stored]:
			var parts := String(shortcut).to_lower()
			var ev := _ev(code, parts.contains("ctrl"), parts.contains("alt"), parts.contains("shift"), parts.contains("win"))
			expect(not Win31Commands.shortcut_matches_event(shortcut, ev), "%s never launches (key %s)" % [shortcut, name])


func test_stored_spellings_of_navigation_keys_never_match() -> void:
	for shortcut in ["Enter", "Return", "Esc", "Escape", "Tab", "Space", "Backspace", "Delete", "Del", "ArrowUp",
			"ArrowDown", "ArrowLeft", "ArrowRight", "Up", "Down", "Left", "Right", "Home", "End", "PageUp", "PageDown",
			"PgUp", "PgDn", "Ctrl+ArrowUp", "Alt+Home"]:
		var last: String = shortcut.split("+")[-1].to_lower()
		expect(Win31Commands.is_navigation_key(last), "%s is a navigation token" % shortcut)
		var ctrl: bool = shortcut.begins_with("Ctrl+")
		var alt: bool = shortcut.begins_with("Alt+")
		expect(not Win31Commands.shortcut_matches(shortcut, last, ctrl, alt, false, false), shortcut)


func test_other_keys_still_match() -> void:
	expect(Win31Commands.shortcut_matches_event("G", _ev(KEY_G)), "bare letter")
	expect(Win31Commands.shortcut_matches_event("F5", _ev(KEY_F5)), "bare function key")
	expect(Win31Commands.shortcut_matches_event("Ctrl+Alt+G", _ev(KEY_G, true, true)), "modified letter")
	expect(Win31Commands.shortcut_matches_event("Shift+F2", _ev(KEY_F2, false, false, true)))
	expect(Win31Commands.shortcut_matches_event("1", _ev(KEY_1)), "digit")
	expect(not Win31Commands.shortcut_matches_event("G", _ev(KEY_H)), "different key")
	for k in ["g", "f5", "1", "a", "insert", "f12"]:
		expect(not Win31Commands.is_navigation_key(k), "%s is not a navigation key" % k)
