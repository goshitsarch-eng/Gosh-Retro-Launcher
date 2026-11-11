class_name DesktopBridge
extends Node
## OS integration Godot has no API for: really hiding the main window ("Minimize to Tray on
## Close") and the OS-wide Quick Search hotkey (Electron's globalShortcut Ctrl/Cmd+Shift+Space).
##
##  * Windows: one long-lived helper (powershell.exe running a small Add-Type C# class) owns
##    RegisterHotKey(Ctrl+Shift+Space) and calls ShowWindow(SW_HIDE / SW_SHOW) on our HWND. We talk
##    to it over its stdin/stdout. If PowerShell or Add-Type is unavailable (policy, constrained
##    language mode) the helper never reports "ready" and everything falls back: close-to-tray
##    minimizes and the hotkey is in-app only.
##  * macOS: hiding is NSRunningApplication.hide on our own pid via osascript (no permission
##    prompt); un-hiding is DisplayServer.window_move_to_foreground (activation unhides the app),
##    which the Dock and Cmd-Tab also do natively. A permission-free OS-wide hotkey needs native
##    code, so macOS/Linux bind `program-manager --quick-search` in the system keyboard settings.
##  * Linux: no portable way to hide a window (Wayland forbids it): close-to-tray minimizes.
##
## Godot itself refuses `Window.visible = false` on the main window.

signal hotkey_pressed
signal shown  ## the helper has made the window visible again (Windows)

const HOTKEY_LABEL := "Ctrl+Shift+Space"

enum { SHOW_DONE, SHOW_PENDING, SHOW_FAILED }  ## show_window() results

## C# compiled once by Add-Type when the helper starts. stdin: "hide" | "show" | "quit".
## stdout: "ready", "hotkey-ready" | "hotkey-unavailable", "hotkey", "shown".
const WIN_HELPER_CS := """
using System; using System.Runtime.InteropServices; using System.Threading;
public static class PmDesktopHelper {
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int x; public int y; }
  [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mods, uint vk);
  [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint min, uint max);
  [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int pid);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  static readonly object Gate = new object();
  public static void Say(string s) { lock (Gate) { Console.Out.WriteLine(s); Console.Out.Flush(); } }
  public static void StartHotkey(int ownerPid) {
    var t = new Thread(() => {
      // MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_SPACE
      if (!RegisterHotKey(IntPtr.Zero, 1, 0x0002 | 0x0004 | 0x4000, 0x20)) { Say("hotkey-unavailable"); return; }
      Say("hotkey-ready");
      MSG m;
      while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) {
        if (m.message == 0x0312) { AllowSetForegroundWindow(ownerPid); Say("hotkey"); }
      }
    });
    t.IsBackground = true;
    t.Start();
  }
}
"""

## The PowerShell side: compile, start the hotkey thread, then serve stdin until it closes (our
## process exited) or the window is gone.
const WIN_HELPER_PS := "$ErrorActionPreference='Stop';Add-Type -TypeDefinition $env:PM_HELPER_CS;" \
	+ "Remove-Item Env:PM_HELPER_CS;$h=[IntPtr][long]$env:PM_HELPER_HWND;$o=[int]$env:PM_HELPER_PID;" \
	+ "[PmDesktopHelper]::Say('ready');if($env:PM_HELPER_HOTKEY -eq '1'){[PmDesktopHelper]::StartHotkey($o)};" \
	+ "while($null -ne ($l=[Console]::In.ReadLine())){" \
	+ "if(($l -eq 'quit') -or (-not [PmDesktopHelper]::IsWindow($h))){break}" \
	+ "elseif($l -eq 'hide'){[void][PmDesktopHelper]::ShowWindow($h,0)}" \
	+ "elseif($l -eq 'show'){[void][PmDesktopHelper]::ShowWindow($h,5);[PmDesktopHelper]::Say('shown')}}"

var _os := ""
var _ready := false     ## the helper compiled and is serving commands
var _hotkey := false    ## the OS-wide hotkey is registered
var _pipe: FileAccess
var _pid := -1
var _reader: Thread


# ---------------------------------------------------------------- pure (unit-tested)

## powershell.exe argv + environment for the Windows helper.
static func windows_helper_launch(hwnd: int, owner_pid: int, hotkey: bool) -> Dictionary:
	return {
		"args": PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
			"-EncodedCommand", Marshalls.raw_to_base64(WIN_HELPER_PS.to_utf16_buffer())]),
		"env": {
			"PM_HELPER_CS": WIN_HELPER_CS,
			"PM_HELPER_HWND": str(hwnd),
			"PM_HELPER_PID": str(owner_pid),
			"PM_HELPER_HOTKEY": "1" if hotkey else "0",
		},
	}


## osascript argv hiding the application with this pid (macOS Cmd-H equivalent).
static func mac_hide_args(pid: int) -> PackedStringArray:
	return PackedStringArray(["-l", "JavaScript", "-e",
		"ObjC.import('AppKit');$.NSRunningApplication.runningApplicationWithProcessIdentifier(%d).hide;undefined" % pid])


## Event name for a helper stdout line ("" for noise).
static func parse_helper_line(line: String) -> String:
	var l := line.strip_edges()
	return l if l in ["ready", "hotkey-ready", "hotkey-unavailable", "hotkey", "shown"] else ""


# ---------------------------------------------------------------- lifecycle

## Starts whatever the platform needs. `register_hotkey`: claim the OS-wide shortcut (Windows).
func start(os_name: String, register_hotkey: bool) -> void:
	_os = os_name
	if _os == "win32":
		var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
		if hwnd != 0:
			start_helper("powershell.exe", windows_helper_launch(hwnd, OS.get_process_id(), register_hotkey))


## Runs a helper speaking the line protocol above (tests use a stand-in script).
func start_helper(path: String, launch: Dictionary) -> bool:
	stop()
	var env: Dictionary = launch.get("env", {})
	var saved := {}
	for k in env:
		saved[k] = OS.get_environment(k) if OS.has_environment(k) else null
		OS.set_environment(k, env[k])
	var res := OS.execute_with_pipe(path, launch.get("args", PackedStringArray()))
	for k in saved:
		if saved[k] == null:
			OS.unset_environment(k)
		else:
			OS.set_environment(k, saved[k])
	if res.is_empty() or res.get("stdio") == null:
		return false
	_pipe = res.stdio
	_pid = int(res.get("pid", -1))
	_reader = Thread.new()
	_reader.start(_read_loop.bind(_pipe))
	return true


func stop() -> void:
	if _pipe:
		_send("quit")
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	if _reader:
		_reader.wait_to_finish()
		_reader = null
	_pipe = null
	_pid = -1
	_ready = false
	_hotkey = false


func _exit_tree() -> void:
	stop()


func _read_loop(pipe: FileAccess) -> void:
	# Blocking reads on a worker thread; EOF (helper exited or was killed) ends the loop. The helper
	# never prints empty lines, so "" plus an error is the end of the stream.
	while true:
		var line := pipe.get_line()
		if line == "" and pipe.get_error() != OK:
			break
		var ev := parse_helper_line(line)
		if ev != "":
			_on_helper_event.call_deferred(ev)
	_on_helper_event.call_deferred("exited")


func _on_helper_event(ev: String) -> void:
	match ev:
		"ready":
			_ready = true
		"hotkey-ready":
			_hotkey = true
		"hotkey-unavailable":
			_hotkey = false
		"hotkey":
			hotkey_pressed.emit()
		"shown":
			shown.emit()
		"exited":
			_ready = false
			_hotkey = false


func _send(cmd: String) -> bool:
	if _pipe == null or not _pipe.is_open():
		return false
	_pipe.store_line(cmd)
	_pipe.flush()
	return _pipe.get_error() == OK


# ---------------------------------------------------------------- queries / commands

func helper_ready() -> bool:
	return _ready


func hotkey_registered() -> bool:
	return _hotkey


## Whether hide_window() really hides (otherwise the caller minimizes).
func can_hide(tray_present: bool) -> bool:
	match _os:
		"darwin":
			return true  # the Dock icon always brings the app back
		"win32":
			return _ready and tray_present  # never strand an invisible window with no tray to restore it
	return false


## Hides the window. Returns false when nothing was done.
func hide_window() -> bool:
	match _os:
		"darwin":
			return OS.create_process("/usr/bin/osascript", mac_hide_args(OS.get_process_id())) > 0
		"win32":
			return _ready and _send("hide")
	return false


## Makes a hidden window visible again. SHOW_DONE: the caller's restore + focus finishes the job
## (macOS: activating the app unhides it). SHOW_PENDING: wait for `shown` (Windows helper).
## SHOW_FAILED: the helper is gone; the caller must re-show the window itself.
func show_window() -> int:
	match _os:
		"darwin":
			return SHOW_DONE
		"win32":
			return SHOW_PENDING if _ready and _send("show") else SHOW_FAILED
	return SHOW_DONE
