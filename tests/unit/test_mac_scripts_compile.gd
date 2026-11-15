extends TestCase
## Every Mac shell script that does not touch an autoload must compile in a headless run (the others are
## compiled by the visual harness, where the autoload globals exist).

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


func test_all_pure_mac_scripts_load() -> void:
	var d := DirAccess.open("res://src/shells/mac")
	var loaded := 0
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var path := "res://src/shells/mac/" + f
		if _uses_autoload(path):
			continue
		var s: Variant = load(path)
		expect(s is GDScript, "cannot load " + path)
		loaded += 1
	expect(loaded >= 12, "expected the pure scripts to be checked, got %d" % loaded)
