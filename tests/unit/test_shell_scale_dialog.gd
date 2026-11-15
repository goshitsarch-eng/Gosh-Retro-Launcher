extends TestCase
## Auto UI scale for native dialog windows (HiDPI).


func test_os_reported_ratio_wins() -> void:
	expect_eq(ShellScale.dialog_scale(2160, 2.0), 2.0)
	expect_eq(ShellScale.dialog_scale(1080, 1.5), 1.5)
	expect_eq(ShellScale.dialog_scale(1080, 9.0), 4.0, "clamped")


func test_inferred_from_screen_height_when_os_reports_one() -> void:
	expect_eq(ShellScale.dialog_scale(1080, 1.0), 1.0)
	expect_eq(ShellScale.dialog_scale(1200, 1.0), 1.0, "WUXGA stays 1x")
	expect_eq(ShellScale.dialog_scale(1440, 1.0), 1.25)
	expect_eq(ShellScale.dialog_scale(2160, 1.0), 2.0)
	expect_eq(ShellScale.dialog_scale(4320, 1.0), 3.0, "capped")


func test_bad_inputs_fall_back_to_1x() -> void:
	expect_eq(ShellScale.dialog_scale(NAN, 1.0), 1.0)
	expect_eq(ShellScale.dialog_scale(0, 0.0), 1.0)
