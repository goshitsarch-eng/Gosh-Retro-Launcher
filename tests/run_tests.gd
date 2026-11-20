extends SceneTree
## Headless unit-test runner.
##   godot --headless --path . --script tests/run_tests.gd [-- filter]
## Exits non-zero on any failure.

class ScriptErrors extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			count += 1


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame  # autoloads (ProgramStore, Platform, Sounds...) join the tree after _init
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var dir := DirAccess.open("res://tests/unit")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and (filter.is_empty() or f.contains(filter)):
			files.append(f)
	files.sort()
	var total := 0
	var failed := 0
	var script_errors := ScriptErrors.new()
	OS.add_logger(script_errors)
	for f in files:
		var script: GDScript = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():
			printerr("FAILED TO LOAD ", f)
			failed += 1
			continue
		var tc: TestCase = script.new()
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				methods.append(m.name)
		methods.sort()
		for m in methods:
			tc._current = "%s::%s" % [f.get_basename(), m]
			var before := tc.failures.size()
			var errors_before := script_errors.count
			await tc.call(m)
			if script_errors.count > errors_before:
				tc.failures.append("%s: GDScript runtime error (see log above)" % tc._current)
			total += 1
			if tc.failures.size() > before:
				failed += 1
				for i in range(before, tc.failures.size()):
					printerr("FAIL ", tc.failures[i])
	OS.remove_logger(script_errors)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
