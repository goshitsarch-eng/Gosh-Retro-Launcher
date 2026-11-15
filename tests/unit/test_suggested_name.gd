extends TestCase
## Default item names for websites and .app bundles.


func test_urls_use_the_host() -> void:
	expect_eq(Launcher.suggested_name("https://www.github.com/anthropics/x?y=1"), "github.com")
	expect_eq(Launcher.suggested_name("http://localhost:3000/app"), "localhost")
	expect_eq(Launcher.suggested_name("  https://example.org  "), "example.org")


func test_app_bundles_drop_the_suffix() -> void:
	expect_eq(Launcher.suggested_name("/Applications/Google Chrome.app"), "Google Chrome")
	expect_eq(Launcher.suggested_name("/Applications/Safari.app/"), "Safari")


func test_plain_paths_keep_their_file_name() -> void:
	expect_eq(Launcher.suggested_name("C:\\Windows\\notepad.exe"), "notepad.exe")
	expect_eq(Launcher.suggested_name("/usr/bin/vim"), "vim")
