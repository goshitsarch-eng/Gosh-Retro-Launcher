extends TestCase
## macOS app-menu integration (pure parts; the native menu needs a real display).


func test_settings_goes_after_about() -> void:
	expect_eq(MacAppMenu.settings_index(10), 2)
	expect_eq(MacAppMenu.settings_index(1), 1, "clamped to the menu size")


func test_install_is_a_noop_without_a_native_menu() -> void:
	expect_eq(MacAppMenu.install(Callable(), Callable(), Callable()), false, "headless / non-macOS")
