extends SceneTree
## Headless unit-test runner.
##   godot --headless --path . --script tests/run_tests.gd [-- filter]
## Exits non-zero on any failure.


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
			await tc.call(m)
			total += 1
			if tc.failures.size() > before:
				failed += 1
				for i in range(before, tc.failures.size()):
					printerr("FAIL ", tc.failures[i])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
