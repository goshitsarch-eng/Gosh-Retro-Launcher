class_name Launcher
extends RefCounted
## Program launching. Port of src/main/ipc/launchHandlers.ts.
## All entry points return {"success": bool, "error": String (optional)}.


static func is_valid_launch_url(url: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)^https?://[^\\s/?#]+")
	return re.search(url) != null


## Tokenize a shell-like command string, respecting quotes.
static func tokenize_command(cmd: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var current := ""
	var in_single := false
	var in_double := false
	var n := cmd.length()
	var i := 0
	while i < n:
		var ch := cmd[i]
		var nxt := cmd[i + 1] if i + 1 < n else ""
		if ch == "\\" and not in_single:
			# Preserve ordinary Windows path separators; only escape characters
			# that are meaningful to this tokenizer.
			if nxt != "" and (_is_space(nxt) or nxt == '"' or nxt == "'" or nxt == "\\"):
				current += nxt
				i += 2
			else:
				current += ch
				i += 1
			continue
		if ch == "'" and not in_double:
			in_single = not in_single
			i += 1
			continue
		if ch == '"' and not in_single:
			in_double = not in_double
			i += 1
			continue
		if _is_space(ch) and not in_single and not in_double:
			if current != "":
				tokens.append(current)
				current = ""
			i += 1
			continue
		current += ch
		i += 1
	if current != "":
		tokens.append(current)
	return tokens


static func _is_space(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "\f" or ch == "\v"


## Reject empty paths and shell metacharacters in the command name.
static func is_valid_exec_path(exec_path: String) -> bool:
	if exec_path.is_empty():
		return false
	for c in [";", "&", "|", "`", "$", "(", ")", "{", "}"]:
		if exec_path.contains(c):
			return false
	return true


## KEY=VALUE lines -> Dictionary of additions (comments/malformed lines ignored).
static func parse_environment(value: String = "") -> Dictionary:
	var out := {}
	for raw in value.replace("\r\n", "\n").split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var sep := line.find("=")
		if sep <= 0:
			continue
		out[line.substr(0, sep).strip_edges()] = line.substr(sep + 1)
	return out


## Parses a Linux .desktop file. Returns {"exec","name"} or {} on failure.
static func parse_desktop_file(file_path: String) -> Dictionary:
	if not file_path.ends_with(".desktop"):
		return {}
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	var exec := ""
	var name := ""
	var in_entry := false
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "[Desktop Entry]":
			in_entry = true
			continue
		if line.begins_with("[") and line.ends_with("]"):
			in_entry = false
			continue
		if not in_entry:
			continue
		if line.begins_with("Exec="):
			exec = line.substr(5)
		elif line.begins_with("Name="):
			name = line.substr(5)
	if exec.is_empty():
		return {}
	var re := RegEx.new()
	re.compile("%[fFuUdDnNickvm]")
	exec = re.sub(exec, "", true).strip_edges()
	return {"exec": exec, "name": name}


static func platform() -> String:
	match OS.get_name():
		"Windows":
			return "win32"
		"macOS":
			return "darwin"
		_:
			return "linux"


static func _fail(msg: String) -> Dictionary:
	return {"success": false, "error": msg}


static func _ok() -> Dictionary:
	return {"success": true}


## Detached spawn honouring cwd/env/hidden window. create_process has no cwd/env
## parameters, so a tiny wrapper (sh / PowerShell) applies them.
static func spawn_detached(command: String, args: PackedStringArray, cwd: String, env_additions: Dictionary) -> Dictionary:
	if platform() == "win32":
		if cwd.is_empty() and env_additions.is_empty():
			var pid := OS.create_process(command, args)
			return _ok() if pid > 0 else _fail("Failed to spawn %s" % command)
		var script := "$e=$env:GOSH_LAUNCH_ENV|ConvertFrom-Json;if($e){foreach($p in $e.PSObject.Properties){Set-Item -Path ('env:'+$p.Name) -Value $p.Value}};" \
			+ "$launch=@{FilePath=$args[0]};if($args.Count -gt 1){$launch.ArgumentList=$args[1..($args.Count-1)]};" \
			+ "if($env:GOSH_LAUNCH_CWD){$launch.WorkingDirectory=$env:GOSH_LAUNCH_CWD};Start-Process @launch"
		OS.set_environment("GOSH_LAUNCH_CWD", cwd)
		OS.set_environment("GOSH_LAUNCH_ENV", JSON.stringify(env_additions))
		var full := PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script, command])
		full.append_array(args)
		var wpid := OS.create_process("powershell.exe", full, false)
		OS.unset_environment("GOSH_LAUNCH_CWD")
		OS.unset_environment("GOSH_LAUNCH_ENV")
		return _ok() if wpid > 0 else _fail("Failed to spawn %s" % command)
	if cwd.is_empty() and env_additions.is_empty():
		var pid2 := OS.create_process(command, args)
		return _ok() if pid2 > 0 else _fail("Failed to spawn %s" % command)
	# POSIX: cd then exec through env(1) so KEY=VALUE additions apply to the child only.
	var sh_args := PackedStringArray(["-c", 'cd "$1" || exit 1; shift; exec env "$@"', "sh", cwd if not cwd.is_empty() else "."])
	for k in env_additions:
		sh_args.append("%s=%s" % [k, env_additions[k]])
	sh_args.append(command)
	sh_args.append_array(args)
	var spid := OS.create_process("/bin/sh", sh_args)
	return _ok() if spid > 0 else _fail("Failed to spawn %s" % command)


static func launch_program(item: Dictionary) -> Dictionary:
	var program_path := String(item.get("path", ""))
	var working_dir := String(item.get("workingDir", ""))
	var item_args := tokenize_command(String(item.get("arguments", "")))
	var env := parse_environment(String(item.get("environment", "")))
	var run_mode: String = item.get("runMode", "minimized" if item.get("runMinimized", false) else "normal")

	if is_valid_launch_url(program_path):
		var err := OS.shell_open(program_path)
		return _ok() if err == OK else _fail(error_string(err))

	match platform():
		"win32":
			var ext := program_path.to_lower().get_extension()
			if ext == "lnk":
				var details := LnkFile.read(program_path)
				if details.is_empty():
					return _fail("Could not read shortcut: %s" % program_path)
				var args := PackedStringArray()
				if String(details.get("args", "")) != "":
					args.append_array(tokenize_command(details.args))
				args.append_array(item_args)
				var cwd := String(details.get("cwd", ""))
				return spawn_detached(details.target, args, cwd if cwd != "" else working_dir, env)
			elif ["exe", "com"].has(ext) and run_mode != "normal":
				var style := "Maximized" if run_mode == "maximized" else "Minimized"
				var script := "$launch=@{FilePath=$args[0];WindowStyle='%s'}; " % style \
					+ "if($args.Count -gt 1){$launch.ArgumentList=$args[1..($args.Count-1)]}; " \
					+ "if($env:GOSH_LAUNCH_CWD){$launch.WorkingDirectory=$env:GOSH_LAUNCH_CWD}; Start-Process @launch"
				var pargs := PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script, program_path])
				pargs.append_array(item_args)
				OS.set_environment("GOSH_LAUNCH_CWD", working_dir)
				for k in env:
					OS.set_environment(k, env[k])
				var pid := OS.create_process("powershell.exe", pargs, false)
				OS.unset_environment("GOSH_LAUNCH_CWD")
				for k in env:
					OS.unset_environment(k)
				return _ok() if pid > 0 else _fail("Failed to spawn powershell.exe")
			elif ["exe", "com"].has(ext) and (item_args.size() > 0 or item.get("environment", "") != ""):
				return spawn_detached(program_path, item_args, working_dir, env)
			elif ["bat", "cmd"].has(ext):
				var com := OS.get_environment("ComSpec")
				var cargs := PackedStringArray(["/d", "/s", "/c", program_path])
				cargs.append_array(item_args)
				return spawn_detached(com if com != "" else "cmd.exe", cargs, working_dir, env)
			else:
				var oerr := OS.shell_open(program_path)
				if oerr != OK:
					return _fail(error_string(oerr))
		"darwin":
			if program_path.ends_with(".app"):
				var oargs := PackedStringArray(["-a", program_path])
				if item_args.size() > 0:
					oargs.append("--args")
					oargs.append_array(item_args)
				return spawn_detached("open", oargs, working_dir, env)
			return spawn_detached(program_path, item_args, working_dir, env)
		_:
			if program_path.ends_with(".desktop"):
				var desktop := parse_desktop_file(program_path)
				if desktop.is_empty():
					return _fail("Could not parse .desktop file")
				var parts := tokenize_command(desktop.exec)
				if parts.size() == 0 or not is_valid_exec_path(parts[0]):
					return _fail("Invalid Exec command in .desktop file")
				var dargs := parts.slice(1)
				dargs.append_array(item_args)
				return spawn_detached(parts[0], dargs, working_dir, env)
			return spawn_detached(program_path, item_args, working_dir, env)
	return _ok()
