extends TestCase
## Port of win95/__tests__/taskbarState.test.ts.


func test_presses_only_the_active_visible_window() -> void:
	expect_eq(Win95TaskbarState.button_state("one", "one", false), "active")
	expect_eq(Win95TaskbarState.button_state("two", "one", false), "inactive")
	expect_eq(Win95TaskbarState.button_state("one", "one", true), "minimized")


func test_maps_button_clicks_to_minimize_focus_or_restore() -> void:
	expect_eq(Win95TaskbarState.click_action("one", "one", false), "minimize")
	expect_eq(Win95TaskbarState.click_action("two", "one", false), "focus")
	expect_eq(Win95TaskbarState.click_action("one", "one", true), "restore-focus")
