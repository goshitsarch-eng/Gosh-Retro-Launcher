extends TestCase
## CORE-14: a capture run must pick its temporary profile before ProgramStore.init_store() opens
## anything, so without PM_USER_DATA the real store is never read, migrated or rewritten.

const Capture := preload("res://src/app/capture.gd")


func test_profile_dir_prefers_explicit_user_data() -> void:
	expect_eq(Capture.capture_profile_dir("/x/explicit", "/cache", 42), "/x/explicit")


func test_profile_dir_defaults_to_per_process_cache_folder() -> void:
	expect_eq(Capture.capture_profile_dir("", "/cache", 42), "/cache/program-manager-capture-42")


func test_select_profile_sets_env_and_is_idempotent() -> void:
	var had := OS.has_environment("PM_USER_DATA")
	var saved := OS.get_environment("PM_USER_DATA")
	OS.unset_environment("PM_USER_DATA")
	var first: String = Capture.select_profile()
	expect_eq(first, OS.get_cache_dir().path_join("program-manager-capture-%d" % OS.get_process_id()))
	expect_eq(OS.get_environment("PM_USER_DATA"), first, "the store will open the capture profile")
	expect_eq(Persistence.default_user_data_dir(), first, "init_store() resolves to the capture profile")
	expect_eq(Capture.select_profile(), first, "prepare() gets the same folder again")
	OS.set_environment("PM_USER_DATA", "/explicit/profile")
	expect_eq(Capture.select_profile(), "/explicit/profile", "an explicit PM_USER_DATA is kept")
	if had:
		OS.set_environment("PM_USER_DATA", saved)
	else:
		OS.unset_environment("PM_USER_DATA")


func test_main_selects_profile_before_init_store() -> void:
	# Source-order guard: the selection must precede the first ProgramStore.init_store() call.
	var src := FileAccess.get_file_as_string("res://src/app/main.gd")
	var sel := src.find("select_profile()")
	var init := src.find("ProgramStore.init_store()")
	expect(sel > 0 and init > 0, "both calls present")
	expect(sel < init, "capture profile chosen before the store is opened")
