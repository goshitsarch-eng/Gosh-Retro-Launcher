extends Node
## Visual capture/regression driver. Port of scripts/capture-wfw.cjs.
##   godot --path . -- --capture=<view> --out=<png> [--baseline=<png>]
## Writes a deterministic fixture profile, sizes the window like the original harness,
## drives the scenario with real input events, saves the framebuffer, and (with --baseline)
## applies the original rule: same dimensions and <= 0.5% of pixels differing by > 20/255.

const FIXTURES := preload("res://tests/visual/fixtures.gd")
const SCENARIOS := preload("res://tests/visual/scenarios.gd")

var host: Node
var args: Dictionary
var view := "workspace"
var auto: Automation
var _owns_size := false


func owns_window_size() -> bool:
	return _owns_size


## The profile folder a capture run uses: PM_USER_DATA when it is set, else a per-process folder in
## the per-user cache dir (not a predictable name in the world-writable /tmp: symlink planting). Pure.
static func capture_profile_dir(user_data_env: String, cache_dir: String, pid: int) -> String:
	if user_data_env != "":
		return user_data_env
	return cache_dir.path_join("program-manager-capture-%d" % pid)


## Points PM_USER_DATA at the capture profile and returns it. main.gd calls this BEFORE
## ProgramStore.init_store() so a capture run never opens (or migrates) the real store; prepare()
## calls it again and gets the same folder, because the variable is set by then.
static func select_profile() -> String:
	var profile := capture_profile_dir(OS.get_environment("PM_USER_DATA"), OS.get_cache_dir(), OS.get_process_id())
	OS.set_environment("PM_USER_DATA", profile)
	return profile


func prepare() -> void:
	view = args.get("capture", "workspace")
	var profile := select_profile()
	DirAccess.make_dir_recursive_absolute(profile)
	var f := FileAccess.open(profile.path_join("program-manager-data.json"), FileAccess.WRITE)
	f.store_string(Jsonx.stringify(FIXTURES.data_for(view), "  "))
	f.close()
	ProgramStore.persistence = Persistence.new(profile)
	ProgramStore.persistence.init_store()
	if view == "win95-dpi125" and OS.get_environment("PM_FORCE_DPR") == "":
		OS.set_environment("PM_FORCE_DPR", "1.25")  # the original harness forced a 125% device scale
	if OS.get_environment("PM_FORCE_DPR") == "":
		OS.set_environment("PM_FORCE_DPR", "1")  # baselines are 1x; on a Retina host the min window size would otherwise force 800x600
	# project.godot runs in low-processor mode (render only on redraw requests); the harness grabs the viewport
	# after injected input, so keep rendering every frame or the grab can return the previous frame.
	OS.low_processor_usage_mode = false
	Engine.set_meta("pm_capture", true)
	Engine.set_meta("pm_capture_clock", "12:00 PM")
	_owns_size = true
	var win := host.get_window()
	var dims := FIXTURES.window_size_for(view)
	win.size = dims
	await get_tree().process_frame
	await get_tree().process_frame
	_report_unrepresentable_size(dims, win.size)


## macOS sizes windows in whole points, so on a 2x screen an odd pixel size (reference 511x335,
## win95-remainder 1281x961) comes back 1 px smaller per axis and those views cannot match their
## 1x Electron baselines (which --baseline then reports as a size mismatch). Not an app defect:
## a bare Godot window does the same. Non-fatal; capture those views on a 1x display.
func _report_unrepresentable_size(requested: Vector2i, actual: Vector2i) -> void:
	if actual == requested:
		return
	var backing := DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen()) if OS.get_name() == "macOS" else 1.0
	var why := "the OS sizes windows in whole points (screen scale %s)" % backing \
		if WindowLayout.os_representable_size(requested, backing) == actual else "the window manager changed it"
	printerr("capture %s: window is %s, fixture asks for %s; %s. Capture this view on a 1x display to compare it with its baseline." \
		% [view, actual, requested, why])


func run() -> void:
	auto = Automation.new(get_tree())
	await auto.wait_ms(800)
	await SCENARIOS.run(view, auto, host)
	await auto.wait_ms(400)  # let the last injected action finish drawing before the grab
	RenderingServer.force_draw()
	var img := host.get_viewport().get_texture().get_image()
	var out := String(args.get("out", "artifacts/%s.png" % view))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print(out)
	var code := 0
	if args.has("baseline"):
		code = _compare(img, String(args.baseline))
	host.get_tree().quit(code)


func _compare(img: Image, baseline_path: String) -> int:
	var ref := Image.load_from_file(baseline_path)
	if ref == null or ref.is_empty() or ref.get_size() != img.get_size():
		printerr("Visual baseline size mismatch: expected %s, received %s" % [ref.get_size() if ref else "none", img.get_size()])
		return 1
	img.convert(Image.FORMAT_RGBA8)
	ref.convert(Image.FORMAT_RGBA8)
	var a := img.get_data()
	var b := ref.get_data()
	var changed := 0
	var i := 0
	while i < a.size():
		if absi(a[i] - b[i]) > 20 or absi(a[i + 1] - b[i + 1]) > 20 or absi(a[i + 2] - b[i + 2]) > 20:
			changed += 1
		i += 4
	var ratio := float(changed) / float(img.get_width() * img.get_height())
	print("visual difference: %.3f%%" % (ratio * 100.0))
	if ratio > 0.005:
		printerr("visual regression exceeded the 0.5%% threshold (%s)" % view)
		return 1
	return 0
