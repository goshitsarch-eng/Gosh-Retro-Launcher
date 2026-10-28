class_name PlatformFilters
extends RefCounted
## File-dialog filter tables (exact port of getExecutableFilters / getImageFilters and the
## inline filters in src/main/ipc/fileHandlers.ts and storeHandlers.ts) and their conversion
## to DisplayServer.file_dialog_show / FileDialog filter strings.
## A filter is {name: String, extensions: Array[String]}; "*" means "any file".


static func executable_filters(os_name: String) -> Array:
	match os_name:
		"win32":
			return [
				{"name": "Executables", "extensions": ["exe", "bat", "cmd", "msi"]},
				{"name": "Shortcuts", "extensions": ["lnk"]},
				{"name": "All Files", "extensions": ["*"]},
			]
		"darwin":
			return [
				{"name": "Applications", "extensions": ["app"]},
				{"name": "All Files", "extensions": ["*"]},
			]
		"linux":
			return [
				{"name": "Desktop Entries", "extensions": ["desktop"]},
				{"name": "Shell Scripts", "extensions": ["sh"]},
				{"name": "All Files", "extensions": ["*"]},
			]
	return [{"name": "All Files", "extensions": ["*"]}]


static func image_filters() -> Array:
	return [
		{"name": "Images", "extensions": ["png", "jpg", "jpeg", "gif", "ico", "svg"]},
		{"name": "Icons", "extensions": ["ico", "icns"]},
		{"name": "All Files", "extensions": ["*"]},
	]


static func grp_open_filters() -> Array:
	return [
		{"name": "Program Manager Groups", "extensions": ["grp"]},
		{"name": "All Files", "extensions": ["*"]},
	]


static func grp_save_filters() -> Array:
	return [{"name": "Program Manager Groups", "extensions": ["grp"]}]


static func json_filters() -> Array:
	return [{"name": "JSON Files", "extensions": ["json"]}]


## Godot filter strings: "*.exe, *.bat ; Executables". The wildcard is "*.*" on Windows (the
## only spelling its dialogs understand) and "*" elsewhere (also matches extension-less files).
static func to_godot(filters: Array, os_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in filters:
		var patterns := PackedStringArray()
		for ext in f.extensions:
			if ext == "*":
				patterns.append("*.*" if os_name == "win32" else "*")
			else:
				patterns.append("*." + String(ext))
		out.append("%s ; %s" % [", ".join(patterns), f.name])
	return out


## Extensions of the first filter (used to append a missing extension to a save path).
static func default_extension(filters: Array) -> String:
	if filters.is_empty():
		return ""
	var ext := String(filters[0].extensions[0])
	return "" if ext == "*" else ext
