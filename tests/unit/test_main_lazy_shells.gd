extends TestCase
## The host loads shells, their notice dialogs and the Launcher Tools window by path. A class name in
## main.gd would make Godot compile that class and its dependencies whenever main.gd loads (about 130
## scripts for all four shells), so these tests keep the paths right and the class names out.

const MAIN := preload("res://src/app/main.gd")
const MAIN_PATH := "res://src/app/main.gd"
const BY_PATH_ONLY := ["Win31Shell", "Win95Shell", "MacShell", "BeShell", "Win95Dialogs", "MacDialogs", "BeDialogs",
	"LauncherToolsWindow"]


func test_shell_paths_load_the_matching_shell() -> void:
	var expected := {"win31": "Win31Shell", "win95": "Win95Shell", "mac": "MacShell", "be": "BeShell"}
	for id in expected:
		var script: GDScript = load(MAIN.shell_script_path(id))
		expect_eq(script.get_global_name(), StringName(expected[id]), id)
	expect_eq(MAIN.shell_script_path("unknown"), MAIN.SHELL_SCRIPTS.win31, "unknown ids still mount WfW")
	expect_eq(MAIN.shell_script_path(""), MAIN.SHELL_SCRIPTS.win31)


func test_notice_dialog_paths_have_the_methods_the_host_calls() -> void:
	var calls := {"win95": ["Win95Dialogs", "show_message"], "mac": ["MacDialogs", "alert"], "be": ["BeDialogs", "message"]}
	for id in calls:
		var script: GDScript = load(MAIN.NOTICE_DIALOGS[id])
		expect_eq(script.get_global_name(), StringName(calls[id][0]), id)
		var names := script.get_script_method_list().map(func(m): return m.name)
		expect(names.has(calls[id][1]), "%s.%s exists" % [calls[id][0], calls[id][1]])
	var tools: GDScript = load(MAIN.LAUNCHER_TOOLS_WINDOW)
	expect_eq(tools.get_global_name(), &"LauncherToolsWindow")
	expect(tools.get_script_method_list().map(func(m): return m.name).has("show_singleton"))


func test_main_names_no_shell_class_in_code() -> void:
	var re := RegEx.create_from_string("\\b(%s)\\b" % "|".join(BY_PATH_ONLY))
	var n := 0
	for line in FileAccess.get_file_as_string(MAIN_PATH).split("\n"):
		n += 1
		var code := line
		var hash_at := line.find("#")
		if hash_at >= 0:
			code = line.substr(0, hash_at)  # comments may mention the classes
		var m := re.search(code)
		expect(m == null, "main.gd:%d names %s; load it by path instead" % [n, m.get_string() if m else ""])
