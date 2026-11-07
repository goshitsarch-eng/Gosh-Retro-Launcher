extends TestCase
## Port of src/main/ipc/__tests__/launchHandlers.test.ts (+ .desktop / .lnk coverage)

func _tok(s: String) -> Array:
	return Array(Launcher.tokenize_command(s))


func test_tokenize() -> void:
	expect_eq(_tok("ls -la"), ["ls", "-la"])
	expect_eq(_tok('echo "hello world"'), ["echo", "hello world"])
	expect_eq(_tok("echo 'hello world'"), ["echo", "hello world"])
	expect_eq(_tok("echo hello\\ world"), ["echo", "hello world"])
	expect_eq(_tok(""), [])
	expect_eq(_tok("cmd 'a b' \"c d\""), ["cmd", "a b", "c d"])
	expect_eq(_tok("C:\\Temp\\input.txt \"C:\\Long Path\\output.txt\""), ["C:\\Temp\\input.txt", "C:\\Long Path\\output.txt"])
	expect_eq(_tok("a   b"), ["a", "b"])


func test_parse_environment() -> void:
	var e := Launcher.parse_environment("ALPHA=one\n# comment\nINVALID\nBETA=two=parts")
	expect_eq(e.get("ALPHA"), "one")
	expect_eq(e.get("BETA"), "two=parts")
	expect(not e.has("INVALID"))
	expect_eq(Launcher.parse_environment("A=1\r\nB=2"), {"A": "1", "B": "2"})


func test_valid_exec_path() -> void:
	expect(Launcher.is_valid_exec_path("/usr/bin/firefox"))
	expect(not Launcher.is_valid_exec_path(""))
	for bad in ["cmd; rm -rf /", "cmd & echo pwned", "cmd | cat /etc/passwd", "cmd `whoami`", "cmd $HOME", "cmd (subshell)", "cmd )", "cmd {a,b}", "cmd }"]:
		expect(not Launcher.is_valid_exec_path(bad), bad)
	expect(Launcher.is_valid_exec_path("/path/to/my app"))


func test_launch_url_validation() -> void:
	expect(Launcher.is_valid_launch_url("https://example.com/x?y=1"))
	expect(Launcher.is_valid_launch_url("http://localhost:8080"))
	expect(not Launcher.is_valid_launch_url("ftp://example.com"))
	expect(not Launcher.is_valid_launch_url("javascript:alert(1)"))
	expect(not Launcher.is_valid_launch_url("/usr/bin/true"))


func test_desktop_file_parsing() -> void:
	var path := OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp"
	path += "/pm_test.desktop"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[Desktop Entry]\nName=Demo\nExec=/usr/bin/demo --flag %U\n[Desktop Action x]\nExec=ignored\n")
	f.close()
	var d := Launcher.parse_desktop_file(path)
	expect_eq(d.get("name"), "Demo")
	expect_eq(d.get("exec"), "/usr/bin/demo --flag")
	expect_eq(Launcher.parse_desktop_file("/tmp/not-desktop.txt"), {})
	DirAccess.remove_absolute(path)


func test_lnk_rejects_garbage() -> void:
	expect_eq(LnkFile.parse(PackedByteArray([1, 2, 3])), {})
