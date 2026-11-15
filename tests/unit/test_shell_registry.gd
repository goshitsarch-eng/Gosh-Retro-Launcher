extends TestCase
## Shell ids shared by the host, validators, migration and window layout (win31, win95, mac, be).


func test_every_shell_has_its_own_scale_key() -> void:
	expect_eq(Types.scale_key("win31"), "win31Scale")
	expect_eq(Types.scale_key("win95"), "win95Scale")
	expect_eq(Types.scale_key("mac"), "macScale")
	expect_eq(Types.scale_key("be"), "beScale")
	expect_eq(Types.scale_key("nonsense"), "win31Scale", "unknown shells fall back to the WfW key")


func test_default_settings_carry_the_new_scales() -> void:
	var s := Types.default_settings()
	expect_eq(s.macScale, "auto")
	expect_eq(s.beScale, "auto")
	expect(Validators.is_valid_settings(s), "defaults stay valid")


func test_validators_accept_new_shells_and_scales() -> void:
	var s := Types.default_settings()
	for shell in Types.SHELLS:
		s["shell"] = shell
		expect(Validators.is_valid_settings(s), "shell " + shell)
		expect(Validators.is_valid_shell_frame_request(shell), "frame request " + shell)
	s["macScale"] = 3
	s["beScale"] = 2
	expect(Validators.is_valid_settings(s))
	s["macScale"] = 1.5
	expect(not Validators.is_valid_settings(s), "bad macScale")
	s["macScale"] = "auto"
	s["beScale"] = 9
	expect(not Validators.is_valid_settings(s), "bad beScale")
	expect(not Validators.is_valid_shell_frame_request("win98"))
	expect(Validators.uses_native_window_frame("mac") and Validators.uses_native_window_frame("be"))
	expect(not Validators.uses_native_window_frame("win31"))


func test_migration_normalizes_new_scales() -> void:
	var m := Migration.migrate_store_data({"groups": [], "settings": {"macScale": 3, "beScale": "bad"}})
	expect_eq(m.settings.macScale, 3)
	expect_eq(m.settings.beScale, "auto")
	var legacy := Migration.migrate_store_data({"groups": []})
	expect_eq(legacy.settings.macScale, "auto")
	expect_eq(legacy.settings.beScale, "auto")


func test_window_layout_knows_every_shell() -> void:
	var s := Types.default_settings()
	s["macScale"] = 2
	expect_eq(WindowLayout.initial_size("mac", s, 2000, 1200), Vector2i(1280, 960), "mac honours macScale")
	expect_eq(WindowLayout.initial_size("be", s, 800, 600), Vector2i(640, 480), "be auto scale 1")
	expect_eq(WindowLayout.initial_size("amiga", s, 2000, 1200), Vector2i(800, 600))
	expect_eq(WindowLayout.background_color("mac").to_html(false), "6c6ca8")
	expect_eq(WindowLayout.background_color("be").to_html(false), "336698")
	expect_eq(WindowLayout.window_title("mac"), "Gosh Mac")
	expect_eq(WindowLayout.window_title("be"), "Gosh Be")
