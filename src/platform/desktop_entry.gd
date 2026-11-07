class_name DesktopEntry
extends RefCounted
## freedesktop .desktop file parsing for drag-and-drop / "Browse" app info.
## Port of getDesktopEntry() in src/main/ipc/appInfoHandlers.ts (plus the `Path=` key).


static func _strip_field_codes(command: String) -> String:
	var re := RegEx.new()
	re.compile("%[fFuUdDnNickvm]")
	return re.sub(command, "", true).strip_edges()


## Splits an Exec command like the TS code: a leading quoted token is taken verbatim, otherwise
## the first whitespace-delimited token. Returns {first, args}.
static func split_command(command: String) -> Dictionary:
	var first := ""
	var rest := ""
	if command.begins_with('"'):
		var close := command.find('"', 1)
		if close < 0:
			# Mirrors JS slice(1, -1): an unterminated quote drops the last character.
			first = command.substr(1, maxi(0, command.length() - 2))
			rest = ""
		else:
			first = command.substr(1, close - 1)
			rest = command.substr(close + 1).strip_edges()
	else:
		var re := RegEx.new()
		re.compile("\\s+")
		var m := re.search(command)
		if m == null:
			first = command
		else:
			first = command.substr(0, m.get_start())
			rest = command.substr(first.length()).strip_edges()
	return {"first": first, "args": rest}


## Parses file text. Keys outside [Desktop Entry] are ignored; later duplicates win (like the TS loop).
## Returns {name, command, icon, path_dir, terminal, has_exec}.
static func parse_text(text: String, file_path: String) -> Dictionary:
	var name := file_path.get_file().trim_suffix(".desktop")
	var command := ""
	var icon := ""
	var path_dir := ""
	var terminal := false
	var in_entry := false
	for raw in text.replace("\r\n", "\n").split("\n"):
		var line := raw.strip_edges()
		if line == "[Desktop Entry]":
			in_entry = true
			continue
		if line.begins_with("["):
			in_entry = false
			continue
		if not in_entry:
			continue
		if line.begins_with("Name="):
			name = line.substr(5)
		elif line.begins_with("Exec="):
			command = _strip_field_codes(line.substr(5))
		elif line.begins_with("Icon="):
			icon = line.substr(5)
		elif line.begins_with("Path="):
			path_dir = line.substr(5)
		elif line.begins_with("Terminal="):
			terminal = line.substr(9).strip_edges().to_lower() == "true"
	return {
		"name": name,
		"command": command,
		"icon": icon,
		"path_dir": path_dir,
		"terminal": terminal,
	}


## AppInfo skeleton (no icons): {name, path, arguments?, workingDir?, icon_name}.
static func to_app_info(text: String, file_path: String) -> Dictionary:
	var e := parse_text(text, file_path)
	var split := split_command(String(e.command))
	var info := {
		"name": e.name,
		"path": split.first if split.first != "" else file_path,
		"icon_name": e.icon,
	}
	if split.args != "":
		info["arguments"] = split.args
	if String(e.path_dir) != "":
		info["workingDir"] = e.path_dir
	return info
