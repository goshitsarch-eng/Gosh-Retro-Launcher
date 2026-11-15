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


func test_normalize_web_address_adds_https() -> void:
	expect_eq(Launcher.normalize_web_address(" github.com "), "https://github.com")
	expect_eq(Launcher.normalize_web_address("http://x.y"), "http://x.y")
	expect_eq(Launcher.normalize_web_address(""), "")


func test_add_website_names_and_validates() -> void:
	var store: Node = preload("res://src/core/program_store.gd").new()
	store.groups = []
	store.settings = Types.default_settings()
	store.settings["saveSettingsOnExit"] = false
	var gid: String = store.add_group("Main")
	var id := Launcher.add_website(store, gid, "", "www.example.com/a")
	expect(id != "")
	var item: Dictionary = store.find_group(gid).items[0]
	expect_eq(item.name, "example.com")
	expect_eq(item.path, "https://www.example.com/a")
	expect_eq(Launcher.add_website(store, gid, "x", "not a url"), "")
	expect_eq(Launcher.add_website(store, "", "x", "example.com"), "")
	store.free()
