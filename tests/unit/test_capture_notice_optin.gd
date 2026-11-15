extends TestCase
## Capture runs show store notices only when PM_CAPTURE_NOTICE=1, and the normal start-up path is
## unchanged (tray, desktop bridge and Mac app menu stay outside the capture branch).

const MAIN := preload("res://src/app/main.gd")


func test_opt_in_needs_exactly_one() -> void:
	expect_eq(MAIN.capture_notices_enabled("1"), true)
	expect_eq(MAIN.capture_notices_enabled(""), false)
	expect_eq(MAIN.capture_notices_enabled("0"), false)
	expect_eq(MAIN.capture_notices_enabled("yes"), false)


func test_normal_startup_block_is_not_inside_the_capture_branch() -> void:
	var src := FileAccess.get_file_as_string("res://src/app/main.gd")
	var block := src.find("\tif not is_capture:\n\t\t_show_load_notice.call_deferred()\n\t\t_setup_tray()\n")
	expect(block != -1, "tray setup stays in the non-capture block")
	var opt_in := src.find("\tif is_capture and capture_notices_enabled(")
	expect(opt_in != -1 and opt_in < block, "opt-in is its own statement before it")
