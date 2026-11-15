extends TestCase
## The Windows PowerShell wrapper must never make a launch fail that OS.shell_open could still do.
## Only pure helpers are tested here: nothing is spawned or opened. Temporary folders only.

var _dir := ""


func _tmp() -> String:
	if _dir == "":
		var base := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else OS.get_user_data_dir()
		_dir = base.path_join("pm_launch_fallback_%d" % OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(_dir)
		var f := FileAccess.open(_dir.path_join("app.exe"), FileAccess.WRITE)
		f.store_string("x")
		f.close()
	return _dir


func _plan(file: String, cwd: String, args: Array = []) -> Dictionary:
	return Launcher.plan_spawn("Windows", file, PackedStringArray(args), cwd, {}, "normal")


func _lines(a: Array) -> PackedStringArray:
	return PackedStringArray(a)


func test_result_exit_0_is_started() -> void:
	expect_eq(Launcher.interpret_powershell_result(0, _lines([])), {"status": "started", "message": ""})


func test_result_exit_2_with_message_is_start_failed() -> void:
	var r := Launcher.interpret_powershell_result(2, _lines(["", "  The operation was canceled by the user.  ", "second"]))
	expect_eq(r.status, "start_failed")
	expect_eq(r.message, "The operation was canceled by the user.", "first non-empty line")


func test_result_exit_2_without_message_is_unavailable() -> void:
	expect_eq(Launcher.interpret_powershell_result(2, _lines(["", "   "])).status, "unavailable")
	expect_eq(Launcher.interpret_powershell_result(2, _lines([])).status, "unavailable")


func test_result_other_codes_are_unavailable() -> void:
	for code in [-1, 1, 3]:
		expect_eq(Launcher.interpret_powershell_result(code, _lines(["some text"])).status, "unavailable", "exit %d" % code)
		expect_eq(Launcher.interpret_powershell_result(code, _lines([])).status, "unavailable", "exit %d, no output" % code)


func test_missing_working_folder_falls_back_to_shell_open() -> void:
	var missing := _tmp().path_join("no such dir")
	var r := Launcher.powershell_route(_plan(_tmp().path_join("app.exe"), missing))
	expect_eq(r.route, "shell_open", "a missing working folder never fails a plain .exe")
	var bare := Launcher.powershell_route(_plan("notepad.EXE", "%USERPROFILE%\\nowhere"))
	expect_eq(bare.route, "shell_open", "unexpanded %USERPROFILE% folder: started without it")
	expect_eq(Launcher.powershell_route(_plan("tool.com", missing)).route, "shell_open")


func test_existing_working_folder_uses_the_wrapper() -> void:
	expect_eq(Launcher.powershell_route(_plan(_tmp().path_join("app.exe"), _tmp())), {"route": "wrapper", "error": ""})


func test_missing_folder_without_safe_fallback_still_fails() -> void:
	var missing := _tmp().path_join("no such dir")
	# The .bat route: cmd.exe /c script. shell_open(cmd.exe) would open an empty console.
	var bat := Launcher.powershell_route(_plan("cmd.exe", missing, ["/d", "/s", "/c", "C:\\x.bat"]))
	expect_eq(bat, {"route": "fail", "error": "Working directory not found: %s" % missing})
	# A .exe with arguments: shell_open would silently drop them.
	expect_eq(Launcher.powershell_route(_plan("app.exe", missing, ["--dry-run"])).route, "fail")
	# Not a .exe/.com at all.
	expect_eq(Launcher.powershell_route(_plan("run.ps1", missing)).route, "fail")


func test_missing_program_is_reported_first() -> void:
	var gone := _tmp().path_join("gone.exe")
	expect_eq(Launcher.powershell_route(_plan(gone, _tmp().path_join("no such dir"))), {"route": "fail", "error": "Program not found: %s" % gone})


func test_shell_open_fallback_eligibility() -> void:
	expect(Launcher.can_fall_back_to_shell_open(_plan("C:\\A\\app.exe", "C:\\A")))
	expect(Launcher.can_fall_back_to_shell_open(_plan("C:\\A\\APP.COM", "C:\\A")))
	expect(not Launcher.can_fall_back_to_shell_open(_plan("C:\\A\\app.exe", "C:\\A", ["x"])))
	expect(not Launcher.can_fall_back_to_shell_open(_plan("C:\\A\\script.bat", "C:\\A")))


func test_script_reports_failures_through_exit_codes() -> void:
	var s := Launcher.PS_SCRIPT
	expect(s.contains("try"), "try")
	expect(s.contains("catch"), "catch")
	expect(s.contains("exit 2"), "Process.Start failure -> exit 2")
	expect(s.contains("exit 0"), "success -> exit 0")
	expect(s.contains("exit 3"), "blocked before Process.Start -> exit 3 (unavailable)")
	expect(s.contains("[Console]::Out.Write"), "message written to stdout")
	expect(s.contains("ProcessStartInfo") and s.contains("UseShellExecute"))
	expect(s.find("$s=1") < s.find("[System.Diagnostics.Process]::Start"), "marker set right before Process.Start")


func test_wrapper_window_is_hidden() -> void:
	var args := Array(Launcher.build_powershell_launch("a.exe", PackedStringArray(), "", "C:\\D", {}).args)
	var i := args.find("-WindowStyle")
	expect(i >= 0, "-WindowStyle present")
	expect_eq(args[i + 1] if i >= 0 else "", "Hidden")
	expect(args.has("-EncodedCommand"))
