extends TestCase
## DesktopBridge: real hide-to-tray and the OS-wide Quick Search hotkey.

## Stand-in for the Windows helper speaking the same line protocol ("fire" simulates WM_HOTKEY).
const FAKE_HELPER := 'echo ready; echo "hotkey-ready"; while IFS= read -r l; do case "$l" in ' \
	+ 'show) echo shown ;; fire) echo hotkey ;; env) echo "$PM_FAKE_VAR" > "$PM_FAKE_OUT" ;; quit) exit 0 ;; esac; done'


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _until(cond: Callable, ms: int = 3000) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func test_windows_helper_launch_payload() -> void:
	var l := DesktopBridge.windows_helper_launch(0x1234, 77, true)
	expect_eq(l.args[0], "-NoLogo")
	expect(l.args.has("-NonInteractive") and l.args.has("-EncodedCommand"))
	var decoded := Marshalls.base64_to_raw(l.args[l.args.size() - 1]).get_string_from_utf16()
	expect_eq(decoded, DesktopBridge.WIN_HELPER_PS)
	expect(decoded.contains("Add-Type -TypeDefinition $env:PM_HELPER_CS"), "C# travels in the environment")
	expect(decoded.contains("ShowWindow($h,0)") and decoded.contains("ShowWindow($h,5)"), "SW_HIDE / SW_SHOW")
	expect_eq(l.env.PM_HELPER_HWND, str(0x1234))
	expect_eq(l.env.PM_HELPER_PID, "77")
	expect_eq(l.env.PM_HELPER_HOTKEY, "1")
	expect_eq(DesktopBridge.windows_helper_launch(1, 1, false).env.PM_HELPER_HOTKEY, "0")
	# Ctrl+Shift+Space without auto-repeat, and foreground rights handed to the app on press.
	expect(DesktopBridge.WIN_HELPER_CS.contains("0x0002 | 0x0004 | 0x4000, 0x20"))
	expect(DesktopBridge.WIN_HELPER_CS.contains("AllowSetForegroundWindow(ownerPid)"))


func test_mac_hide_targets_our_pid() -> void:
	var a := DesktopBridge.mac_hide_args(4242)
	expect_eq(Array(a.slice(0, 3)), ["-l", "JavaScript", "-e"])
	expect(a[3].contains("runningApplicationWithProcessIdentifier(4242).hide"))


func test_helper_lines() -> void:
	expect_eq(DesktopBridge.parse_helper_line("ready\r\n"), "ready")
	expect_eq(DesktopBridge.parse_helper_line("hotkey"), "hotkey")
	expect_eq(DesktopBridge.parse_helper_line("shown"), "shown")
	expect_eq(DesktopBridge.parse_helper_line("Exception: boom"), "")
	expect_eq(DesktopBridge.parse_helper_line(""), "")


func test_can_hide_policy() -> void:
	var b := DesktopBridge.new()
	b._os = "linux"
	expect(not b.can_hide(true), "Linux minimizes")
	b._os = "darwin"
	expect(b.can_hide(false), "macOS: the Dock icon restores")
	b._os = "win32"
	expect(not b.can_hide(true), "Windows without a running helper")
	b._ready = true
	expect(not b.can_hide(false), "never hide on Windows without a tray icon")
	expect(b.can_hide(true))
	b._ready = false
	expect_eq(b.show_window(), DesktopBridge.SHOW_FAILED, "dead helper: caller re-shows the window")
	b.free()


func test_helper_protocol_over_pipes() -> void:
	if Launcher.platform() == "win32":
		return
	var b := DesktopBridge.new()
	_tree().root.add_child(b)
	b._os = "win32"
	var events := []
	b.hotkey_pressed.connect(func() -> void: events.append("hotkey"))
	b.shown.connect(func() -> void: events.append("shown"))
	var out := PlatformFixtures.tmp_dir().path_join("env.txt")
	var had := OS.has_environment("PM_FAKE_VAR")
	expect(b.start_helper("/bin/sh", {"args": PackedStringArray(["-c", FAKE_HELPER]), "env": {"PM_FAKE_VAR": "v1", "PM_FAKE_OUT": out}}))
	expect_eq(OS.has_environment("PM_FAKE_VAR"), had, "helper environment does not leak into the app")
	expect(await _until(func() -> bool: return b.helper_ready() and b.hotkey_registered()), "ready + hotkey-ready")
	expect(b.can_hide(true))
	expect(b.hide_window())
	expect_eq(b.show_window(), DesktopBridge.SHOW_PENDING)
	expect(await _until(func() -> bool: return events.has("shown")), "shown")
	b._send("fire")
	expect(await _until(func() -> bool: return events.has("hotkey")), "hotkey forwarded")
	b._send("env")
	expect(await _until(func() -> bool: return FileAccess.file_exists(out) and FileAccess.get_file_as_string(out).strip_edges() == "v1"), "helper got its environment")
	b._send("quit")
	expect(await _until(func() -> bool: return not b.helper_ready()), "helper exit noticed")
	expect(not b.can_hide(true), "falls back to minimizing once the helper is gone")
	b.stop()
	b.queue_free()
	PlatformFixtures.rm_rf(out.get_base_dir())


func test_stop_kills_a_silent_helper() -> void:
	if Launcher.platform() == "win32":
		return
	var b := DesktopBridge.new()
	_tree().root.add_child(b)
	expect(b.start_helper("/bin/sh", {"args": PackedStringArray(["-c", "sleep 30"])}))
	var t0 := Time.get_ticks_msec()
	b.stop()  # must not hang on the blocked reader thread
	expect(Time.get_ticks_msec() - t0 < 5000)
	expect(not b.helper_ready())
	b.queue_free()


func test_quick_search_command_line_flag() -> void:
	var main_script: GDScript = load("res://src/app/main.gd")
	expect(main_script.wants_quick_search({"quick-search": "1"}, PackedStringArray()))
	expect(main_script.wants_quick_search({}, PackedStringArray(["--quick-search"])), "no `--` separator needed")
	expect(not main_script.wants_quick_search({}, PackedStringArray(["--path", "x"])))


func test_single_instance_forwards_quick_search() -> void:
	expect_eq(SingleInstance.request_line("/p", SingleInstance.QUICK_SEARCH_REQUEST), "QUICKSEARCH\t/p\n")
	expect_eq(SingleInstance.handle_request("QUICKSEARCH\t/p", "/p"), "OK\t/p\n")
	expect_eq(SingleInstance.handle_request("QUICKSEARCH\t/q", "/p"), "", "other profile")
	var first := SingleInstance.new()
	_tree().root.add_child(first)
	var got := []
	first.show_requested.connect(func() -> void: got.append("show"))
	first.quick_search_requested.connect(func() -> void: got.append("qs"))
	var port := 0
	for p in range(52400, 52800):
		var probe := TCPServer.new()
		if probe.listen(p, "127.0.0.1") == OK:
			probe.stop()
			port = p
			break
	expect(port > 0)
	var r1: int = await first.acquire("qs-prof", _tree(), [port])
	expect_eq(r1, SingleInstance.Result.PRIMARY)
	var second := SingleInstance.new()
	second.command = SingleInstance.QUICK_SEARCH_REQUEST
	_tree().root.add_child(second)
	var r2: int = await second.acquire("qs-prof", _tree(), [port])
	expect_eq(r2, SingleInstance.Result.SECONDARY)
	expect_eq(got, ["qs"], "Quick Search, not a plain show")
	first.release()
	second.release()
	first.queue_free()
	second.queue_free()
