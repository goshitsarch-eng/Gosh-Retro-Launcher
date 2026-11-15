extends TestCase
## CORE-03: on Windows a working directory must reach the child for every run mode. Launcher.plan_spawn
## is pure, so the Windows decisions are tested here whatever OS runs the suite.

const NASTY_DIR := 'C:\\My "Data" & Co\\100% done'
const NASTY_EXE := 'C:\\Program Files\\A&B "Tools"\\app %PATH%.exe'


func _args(a: Array) -> PackedStringArray:
	return PackedStringArray(a)


## Splits a command line the way CommandLineToArgvW / the MSVC CRT do (the inverse of quote_windows_arg).
func _parse_windows_command_line(line: String) -> Array:
	var out: Array = []
	var cur := ""
	var in_quotes := false
	var have_token := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "\\":
			var n := 0
			while i < line.length() and line[i] == "\\":
				n += 1
				i += 1
			if i < line.length() and line[i] == '"':
				cur += "\\".repeat(n / 2)
				if n % 2 == 1:
					cur += '"'
					i += 1
			else:
				cur += "\\".repeat(n)
			have_token = true
			continue
		if ch == '"':
			in_quotes = not in_quotes
			have_token = true
		elif (ch == " " or ch == "\t") and not in_quotes:
			if have_token:
				out.append(cur)
			cur = ""
			have_token = false
		else:
			cur += ch
			have_token = true
		i += 1
	if have_token:
		out.append(cur)
	return out


func test_windows_plan_with_working_dir_carries_it_for_every_run_mode() -> void:
	for mode in ["normal", "minimized", "maximized"]:
		for args in [[], ["--flag"]]:
			var p := Launcher.plan_spawn("Windows", "C:\\Tools\\app.exe", _args(args), "C:\\Data", {}, mode)
			expect_eq(p.get("method"), "powershell", "%s %s: only Start-Process can set a cwd" % [mode, args])
			expect_eq(p.get("cwd"), "C:\\Data", "%s %s: cwd kept" % [mode, args])
			expect_eq(Array(p.get("args")), args, "%s: args kept" % mode)
			expect_eq(p.get("file"), "C:\\Tools\\app.exe")


func test_windows_plan_run_mode_styles() -> void:
	expect_eq(Launcher.plan_spawn("Windows", "a.exe", _args([]), "C:\\D", {}, "normal").get("style"), "")
	expect_eq(Launcher.plan_spawn("Windows", "a.exe", _args([]), "", {}, "minimized").get("style"), "Minimized")
	expect_eq(Launcher.plan_spawn("Windows", "a.exe", _args([]), "", {}, "maximized").get("style"), "Maximized")
	expect_eq(Launcher.plan_spawn("Windows", "a.exe", _args([]), "", {}, "minimized").get("cwd"), "", "no cwd invented")


func test_windows_plan_without_working_dir_is_unchanged() -> void:
	# Same decisions spawn_detached / launch_program made before the fix.
	var p := Launcher.plan_spawn("Windows", "C:\\Tools\\app.exe", _args(["-x"]), "", {}, "normal")
	expect_eq(p, {"method": "create_process", "command": "C:\\Tools\\app.exe", "args": _args(["-x"])})
	var e := Launcher.plan_spawn("Windows", "C:\\Tools\\app.exe", _args([]), "", {"A": "1"}, "normal")
	expect_eq(e.get("method"), "powershell", "environment still needs the wrapper")
	expect_eq(e.get("env"), {"A": "1"})
	expect_eq(e.get("cwd"), "")


func test_windows_exe_routing() -> void:
	var none := PackedStringArray()
	# The CORE-03 case: a plain .exe with a working directory is no longer handed to ShellExecute.
	expect(Launcher.windows_exe_needs_spawn(none, "", "C:\\Data", "normal"), "cwd alone forces a spawn")
	# Unchanged: nothing to apply -> ShellExecute (OS.shell_open), exactly as before.
	expect(not Launcher.windows_exe_needs_spawn(none, "", "", "normal"), "plain .exe still uses shell_open")
	expect(Launcher.windows_exe_needs_spawn(_args(["a"]), "", "", "normal"))
	expect(Launcher.windows_exe_needs_spawn(none, "A=1", "", "normal"))
	expect(Launcher.windows_exe_needs_spawn(none, "", "", "minimized"))


func test_non_windows_plan_is_posix_and_untouched() -> void:
	for os_name in ["macOS", "Linux", "FreeBSD"]:
		var p := Launcher.plan_spawn(os_name, "/bin/echo", _args(["a b"]), "/tmp/x y", {"K": "v"}, "maximized")
		expect_eq(p, {"method": "posix", "command": "/bin/echo", "args": _args(["a b"]), "cwd": "/tmp/x y", "env": {"K": "v"}}, os_name)


func test_powershell_launch_keeps_user_data_out_of_the_command_line() -> void:
	var plain := Launcher.build_powershell_launch("a.exe", _args([]), "", "C:\\D", {})
	var nasty := Launcher.build_powershell_launch(NASTY_EXE, _args(['say "hi" & exit', "50%"]), "Minimized", NASTY_DIR, {"X": "%Y% & z"})
	expect_eq(Array(nasty.args), Array(plain.args), "powershell.exe argv is constant: no user data is ever parsed as script")
	var payload: Variant = JSON.parse_string(String(nasty.env.GOSH_LAUNCH))
	expect(payload is Dictionary, "payload is JSON")
	expect_eq(payload.get("cwd"), NASTY_DIR, "cwd with spaces, quotes, & and % round-trips exactly")
	expect_eq(payload.get("file"), NASTY_EXE, "program path round-trips exactly")
	expect_eq(payload.get("env"), {"X": "%Y% & z"})
	expect_eq(payload.get("style"), "Minimized")


func test_argument_line_quoting_round_trips() -> void:
	var cases: Array = [
		["C:\\Long Path\\in put.txt", "plain"],
		['say "hi"', 'a\\"b c', "C:\\Program Files\\"],
		["A&B", "x & y", "100%", "%PATH%", "^caret|pipe<>"],
		["", "tab\there"],
	]
	for args in cases:
		var line := Launcher.windows_command_line(_args(args))
		expect_eq(_parse_windows_command_line(line), args, "round-trip of %s via %s" % [args, line])
		var payload: Variant = JSON.parse_string(String(Launcher.build_powershell_launch("a.exe", _args(args), "", "C:\\D", {}).env.GOSH_LAUNCH))
		expect_eq(payload.get("argline"), line, "Start-Process receives the quoted line")


func test_ampersand_and_percent_are_not_shell_quoted() -> void:
	# Start-Process hands the line to CreateProcess/ShellExecute, not cmd.exe, so & and % are
	# ordinary characters; quoting them would put literal quotes into the child's argv.
	expect_eq(Launcher.quote_windows_arg("A&B"), "A&B")
	expect_eq(Launcher.quote_windows_arg("%PATH%"), "%PATH%")
	expect_eq(Launcher.quote_windows_arg("a & b"), '"a & b"', "spaces still quote")
