extends TestCase
## Every Win95 shell script that does not touch an autoload must compile (headless test runs have no
## autoload globals, so scripts naming ProgramStore/UIState/Platform are compiled by the visual harness).

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


func test_all_pure_win95_scripts_load() -> void:
	var d := DirAccess.open("res://src/shells/win95")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var path := "res://src/shells/win95/" + f
		if _uses_autoload(path):
			continue
		var s: Variant = load(path)
		expect(s is GDScript, "cannot load " + path)
