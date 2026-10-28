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


func prepare() -> void:
	view = args.get("capture", "workspace")
	var profile := OS.get_environment("PM_USER_DATA")
	if profile == "":
		profile = "%s/pm-capture-%d" % [OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp", OS.get_process_id()]
		OS.set_environment("PM_USER_DATA", profile)
	DirAccess.make_dir_recursive_absolute(profile)
	var f := FileAccess.open(profile.path_join("program-manager-data.json"), FileAccess.WRITE)
	f.store_string(Jsonx.stringify(FIXTURES.data_for(view), "  "))
	f.close()
	ProgramStore.persistence = Persistence.new(profile)
	ProgramStore.persistence.init_store()
	if view == "win95-dpi125" and OS.get_environment("PM_FORCE_DPR") == "":
		OS.set_environment("PM_FORCE_DPR", "1.25")  # the original harness forced a 125% device scale
	Engine.set_meta("pm_capture", true)
	Engine.set_meta("pm_capture_clock", "12:00 PM")
	_owns_size = true
	var win := host.get_window()
	var dims := FIXTURES.window_size_for(view)
	win.size = dims
	await get_tree().process_frame


func run() -> void:
	auto = Automation.new(get_tree())
	await auto.wait_ms(800)
	await SCENARIOS.run(view, auto, host)
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
