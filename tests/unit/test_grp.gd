extends TestCase
## Port of src/shared/__tests__/win31Grp.test.ts

func _group() -> Dictionary:
	var state := {"x": 12, "y": 18, "width": 416, "height": 201, "minimized": false, "maximized": false}
	return {"id": "main", "name": "Main", "icon": "group", "windowState": state,
		"shellWindowState": Types.create_shell_window_state(state),
		"items": [{"id": "editor", "name": "Text Editor", "path": "C:\\Program Files\\Editor\\editor.exe",
			"arguments": "--new \"sample file.txt\"", "icon": "default", "workingDir": "C:\\Program Files\\Editor",
			"win31Position": {"x": 75, "y": 72}}]}


func test_round_trip() -> void:
	var s := Grp.serialize(_group())
	expect(s.ok)
	var bytes: PackedByteArray = s.bytes
	var sum := 0
	for o in range(0, bytes.size(), 2):
		sum = (sum + (bytes[o] | (bytes[o + 1] << 8))) & 0xffff
	expect_eq(sum, 0, "checksum")
	var p := Grp.parse(bytes)
	expect(p.ok)
	var g: Dictionary = p.group
	expect_eq(g.name, "Main")
	for k in ["x", "y", "width", "height", "minimized", "maximized"]:
		expect_eq(g.shellWindowState.win31[k], _group().windowState[k], k)
	expect_eq(g.items.size(), 1)
	expect_eq(g.items[0].name, "Text Editor")
	expect_eq(g.items[0].path, "C:\\Program Files\\Editor\\editor.exe")
	expect_eq(g.items[0].arguments, "--new \"sample file.txt\"")
	expect_eq(g.items[0].win31Position, {"x": 75, "y": 72})


func test_split_legacy_command() -> void:
	expect_eq(Grp.split_legacy_command("\"C:\\Long Path\\app.exe\" /x"), {"path": "C:\\Long Path\\app.exe", "arguments": "/x"})
	expect_eq(Grp.split_legacy_command("C:\\DOS\\EDIT.COM README.TXT"), {"path": "C:\\DOS\\EDIT.COM", "arguments": "README.TXT"})


func test_rejects_non_pmcc() -> void:
	var b := PackedByteArray()
	b.resize(64)
	var p := Grp.parse(b)
	expect(not p.ok)
