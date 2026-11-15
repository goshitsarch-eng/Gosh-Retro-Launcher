extends TestCase
## Every Be shell script that does not touch an autoload must compile (headless test runs have no autoload globals,
## so scripts naming ProgramStore/UIState/Platform are compiled by the visual harness: tests/visual/be_scenarios.gd).

const AUTOLOADS := ["ProgramStore", "UIState", "MdiState", "Platform", "Sounds"]


func _uses_autoload(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return true
	var text := f.get_as_text()
	for a in AUTOLOADS:
		var re := RegEx.new()
		re.compile("\\b" + a + "\\b")
		if re.search(text) != null:
			return true
	return false


func test_all_pure_be_scripts_load() -> void:
	var d := DirAccess.open("res://src/shells/be")
	var loaded := 0
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var path := "res://src/shells/be/" + f
		if _uses_autoload(path):
			continue
		var s: Variant = load(path)
		expect(s is GDScript, "cannot load " + path)
		loaded += 1
	expect(loaded >= 10, "expected the pure Be modules to be checked, got %d" % loaded)


func test_shell_id_and_class() -> void:
	expect(FileAccess.file_exists("res://src/shells/be/be_shell.gd"))
	var text := FileAccess.get_file_as_string("res://src/shells/be/be_shell.gd")
	expect(text.contains("class_name BeShell") and text.contains("extends ShellBase"))
	expect(text.contains('return "be"'))
