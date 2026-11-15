extends TestCase
## The PowerShell launch cannot report a failed start, so Windows plans are checked on the host
## first (Launcher.validate_spawn_plan). Temporary folders only; nothing is spawned.

var _dir := ""


func _tmp() -> String:
	if _dir == "":
		var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else OS.get_user_data_dir()
		_dir = base.path_join("pm_spawn_validation_%d" % OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(_dir.path_join("[old] dir"))
		var f := FileAccess.open(_dir.path_join("[old] dir/app.exe"), FileAccess.WRITE)
		f.store_string("x")
		f.close()
	return _dir


func _plan(file: String, cwd: String) -> Dictionary:
	return Launcher.plan_spawn("Windows", file, PackedStringArray(), cwd, {}, "normal")


func test_missing_cwd_is_reported() -> void:
	var missing := _tmp().path_join("no such dir")
	expect_eq(Launcher.validate_spawn_plan(_plan(_tmp().path_join("[old] dir/app.exe"), missing)), "Working directory not found: %s" % missing)


func test_missing_absolute_program_is_reported() -> void:
	var missing := _tmp().path_join("[old] dir/missing.exe")
	expect_eq(Launcher.validate_spawn_plan(_plan(missing, _tmp())), "Program not found: %s" % missing)


func test_present_cwd_and_program_pass() -> void:
	# Brackets in the path are fine: no wildcard matching on the host or in the script.
	var dir := _tmp().path_join("[old] dir")
	expect_eq(Launcher.validate_spawn_plan(_plan(dir.path_join("app.exe"), dir)), "")


func test_bare_command_name_is_not_checked() -> void:
	expect_eq(Launcher.validate_spawn_plan(_plan("notepad.exe", _tmp())), "")
	expect_eq(Launcher.validate_spawn_plan(_plan("notepad.exe", "")), "")


func test_ps_script_uses_process_start_info() -> void:
	expect(Launcher.PS_SCRIPT.contains("ProcessStartInfo"), "ProcessStartInfo launch")
	expect(not Launcher.PS_SCRIPT.contains("Start-Process"), "Start-Process applies wildcard matching to [ ] paths")
	expect(Launcher.PS_SCRIPT.contains("$ErrorActionPreference='Stop'"))
	expect(Launcher.PS_SCRIPT.contains("$env:GOSH_LAUNCH"))
