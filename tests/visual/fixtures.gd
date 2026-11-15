extends RefCounted
## Deterministic profiles for the visual harness. Port of the fixture block in
## scripts/capture-wfw.cjs (do not use as first-run seed data).


static func is_win95_view(view: String) -> bool:
	return view == "win95" or view.begins_with("win95-")


## Shell shown by a capture view: "mac-*" / "be-*" / "win95-*" views start in that shell, everything else in WfW.
static func shell_for_view(view: String) -> String:
	if is_win95_view(view):
		return "win95"
	if view == "mac" or view.begins_with("mac-"):
		return "mac"
	if view == "be" or view.begins_with("be-"):
		return "be"
	return "win31"


static func fixture_scale(view: String) -> int:
	if view == "scale2" or view == "mac-scale2":
		return 2
	if ["win95-scale2", "win95-remainder", "win95-dpi125"].has(view):
		return 2
	if view == "scale3" or view.ends_with("-scale3"):
		return 3
	if view == "scale4" or view == "win95-scale4":
		return 4
	return 1


## Window size in pixels, as the Electron harness set it. `reference` (511x335) and `win95-remainder`
## (1281x961, i.e. 640.5x480.5 logical at scale 2: the non-divisible case) have odd sizes, which a
## macOS window on a 2x screen cannot take (it sizes in whole points and rounds down to 510x334 /
## 1280x960, where 1280x960 divides evenly). Capture those two views on a 1x display; capture.gd
## prints a notice when the window did not get the requested size.
static func window_size_for(view: String) -> Vector2i:
	var s := fixture_scale(view)
	if view == "reference":
		return Vector2i(511, 335)
	if view == "win95-remainder":
		return Vector2i(1281, 961)
	if view == "win95-dpi125":
		return Vector2i(round(640 * s * 1.25), round(480 * s * 1.25))
	return Vector2i(640 * s, 480 * s)


static func _ws(x: int, y: int, w: int, h: int, minimized: bool = false) -> Dictionary:
	return {"x": x, "y": y, "width": w, "height": h, "minimized": minimized, "maximized": false}


static func data_for(view: String) -> Dictionary:
	var icon_y := 219 if view == "reference" else 367
	var main_items := []
	var specs := [["File Manager", "file-manager"], ["Control Panel", "control-panel"], ["Print Manager", "print-manager"],
		["ClipBook Viewer", "clipbook"], ["MS-DOS Prompt", "dos"], ["Windows Setup", "setup"], ["PIF Editor", "pif"], ["Read Me", "readme"]]
	for i in specs.size():
		main_items.append({"id": "main-%d" % i, "name": specs[i][0], "path": "", "icon": specs[i][1], "workingDir": "",
			"win31Position": {"x": (i % 5) * 75 + 4, "y": (i / 5) * 72 + 5}})
	var groups := [{
		"id": "main", "name": "Main", "icon": "group", "windowState": _ws(0, 0, 416, 201),
		"shellWindowState": {"win31": _ws(0, 0, 416, 201), "win95": _ws(20, 20, 416, 201)},
		"win31IconPosition": {"x": 300, "y": icon_y}, "items": main_items,
	}]
	var names := ["Accessories", "Network", "Games", "StartUp"]
	for i in names.size():
		groups.append({
			"id": names[i].to_lower(), "name": names[i], "icon": "group", "windowState": _ws(20, 20, 300, 200, true),
			"shellWindowState": {"win31": _ws(20, 20, 300, 200, true), "win95": _ws(20, 20, 300, 200, true)},
			"win31IconPosition": {"x": i * 75, "y": icon_y}, "items": [],
		})
	var s := fixture_scale(view)
	return {
		"schemaVersion": 2,
		"groups": groups,
		"settings": {
			"shell": shell_for_view(view),
			"win31Scale": s, "win95Scale": s, "macScale": s, "beScale": s, "trayOnClose": false, "soundEnabled": false,
			"theme": "dark" if view.begins_with("mac-dark") else "light",
			"win31DesktopMode": view == "desktop" or view == "desktop-minimized",
			"win31ProgramManagerMinimized": view == "desktop-minimized",
		},
	}
