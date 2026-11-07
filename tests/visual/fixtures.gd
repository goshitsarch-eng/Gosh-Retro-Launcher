extends RefCounted
## Deterministic profiles for the visual harness. Port of the fixture block in
## scripts/capture-wfw.cjs (do not use as first-run seed data).


static func is_win95_view(view: String) -> bool:
	return view == "win95" or view.begins_with("win95-")


static func fixture_scale(view: String) -> int:
	if view == "scale2":
		return 2
	if ["win95-scale2", "win95-remainder", "win95-dpi125"].has(view):
		return 2
	if view == "scale3" or view == "win95-scale3":
		return 3
	if view == "scale4" or view == "win95-scale4":
		return 4
	return 1


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
			"shell": "win95" if is_win95_view(view) else "win31",
			"win31Scale": s, "win95Scale": s, "trayOnClose": false, "soundEnabled": false,
			"win31DesktopMode": view == "desktop" or view == "desktop-minimized",
			"win31ProgramManagerMinimized": view == "desktop-minimized",
		},
	}
