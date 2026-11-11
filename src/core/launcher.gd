class_name Launcher
extends RefCounted
## Program launching. Port of src/main/ipc/launchHandlers.ts.
## All entry points return {"success": bool, "error": String (optional)}.


static func is_valid_launch_url(url: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)^https?://[^\\s/?#]+")
	return re.search(url) != null


## "scheme:..." with a scheme of 2+ characters (a single letter is a drive: "C:\\x", "C:/x").
static func has_uri_scheme(value: String) -> bool:
	var re := RegEx.new()
	re.compile("^[A-Za-z][A-Za-z0-9+.\\-]+:")
	return re.search(value.strip_edges()) != null


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


## POSIX: absolute/relative path with a slash must exist; bare names are looked up on $PATH.
## fork() succeeds even when exec() later fails, so this is the only way to report a missing program.
static func resolve_executable(command: String) -> String:
	if command.contains("/"):
		return command if FileAccess.file_exists(command) else ""
	for dir in OS.get_environment("PATH").split(":", false):
		var candidate := String(dir).path_join(command)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


## Detached spawn honouring cwd/env/hidden window. create_process has no cwd/env parameters:
## on POSIX the env additions are set in this process around the fork (the child inherits them,
## exactly like Node's spawn({env})) and a tiny /bin/sh wrapper only performs the `cd`; on
## Windows a PowerShell wrapper applies both.
static func spawn_detached(command: String, args: PackedStringArray, cwd: String, env_additions: Dictionary) -> Dictionary:
	if platform() == "win32":
		if cwd.is_empty() and env_additions.is_empty():
			var pid := OS.create_process(command, args)
			return _ok() if pid > 0 else _fail("Failed to spawn %s" % command)
		return _spawn_powershell(command, args, "", cwd, env_additions)
	if resolve_executable(command).is_empty():
		return _fail("Program not found: %s" % command)
	if not cwd.is_empty() and not DirAccess.dir_exists_absolute(cwd):
		return _fail("Working directory not found: %s" % cwd)
	var bad_key := _invalid_env_key(env_additions)
	if bad_key != "":
		return _fail("Invalid environment variable name: %s" % bad_key)
	var saved := _push_env(env_additions)
	var spid: int
	if cwd.is_empty():
		spid = OS.create_process(command, args)
	else:
		# Positional parameters only: nothing user-supplied is ever parsed as shell text, and
		# leading dashes cannot be mistaken for options of cd/exec.
		var sh_args := PackedStringArray(["-c", POSIX_CD_EXEC, "sh", _no_leading_dash(cwd), _no_leading_dash(command)])
		sh_args.append_array(args)
		spid = OS.create_process("/bin/sh", sh_args)
	_pop_env(saved)
	return _ok() if spid > 0 else _fail("Failed to spawn %s" % command)


const POSIX_CD_EXEC := 'cd "$1" || exit 1; shift; exec "$@"'


## "-x" -> "./-x" so a relative operand is never parsed as an option.
static func _no_leading_dash(path: String) -> String:
	return "./" + path if path.begins_with("-") else path


## First key that cannot be an environment variable name (empty or containing '='), or "".
static func _invalid_env_key(env_additions: Dictionary) -> String:
	for k in env_additions:
		var key := String(k)
		if key.is_empty() or key.contains("="):
			return key if not key.is_empty() else "(empty)"
	return ""


## Applies env additions to this process; returns what is needed to undo them.
static func _push_env(env_additions: Dictionary) -> Dictionary:
	var saved := {}
	for k in env_additions:
		var key := String(k)
		saved[key] = OS.get_environment(key) if OS.has_environment(key) else null
		OS.set_environment(key, String(env_additions[k]))
	return saved


static func _pop_env(saved: Dictionary) -> void:
	for key in saved:
		if saved[key] == null:
			OS.unset_environment(key)
		else:
			OS.set_environment(key, saved[key])


## Quotes one argument for a Windows command line the way CommandLineToArgvW / the MSVC CRT
## parse it back (what Node's spawn does): backslashes are literal except before a quote, so
## runs of them are doubled in front of an embedded or the closing quote.
static func quote_windows_arg(arg: String) -> String:
	if arg.is_empty():
		return '""'
	var needs := false
	for ch in [" ", "\t", "\n", "\v", '"']:
		if arg.contains(ch):
			needs = true
			break
	if not needs:
		return arg
	var out := '"'
	var slashes := 0
	for ch in arg:
		if ch == "\\":
			slashes += 1
		elif ch == '"':
			out += "\\".repeat(slashes * 2 + 1) + '"'
			slashes = 0
		else:
			out += "\\".repeat(slashes) + ch
			slashes = 0
	return out + "\\".repeat(slashes * 2) + '"'


static func windows_command_line(args: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for a in args:
		parts.append(quote_windows_arg(a))
	return " ".join(parts)


## Start-Process wrapper. Everything (file, args, window style, cwd, env) travels as JSON in the
## GOSH_LAUNCH environment variable and the script is passed with -EncodedCommand: `-Command
## <script> <args...>` does NOT populate $args (PowerShell pastes the arguments into the command
## text). Start-Process joins ArgumentList verbatim, so the arguments arrive as one command line
## already quoted by quote_windows_arg().
const PS_SCRIPT := "$ErrorActionPreference='Stop';$j=$env:GOSH_LAUNCH|ConvertFrom-Json;Remove-Item Env:GOSH_LAUNCH;" \
	+ "if($j.env){foreach($e in $j.env.PSObject.Properties){Set-Item -Path ('env:'+$e.Name) -Value ([string]$e.Value)}};" \
	+ "$l=@{FilePath=$j.file};if($j.style){$l.WindowStyle=$j.style};if($j.cwd){$l.WorkingDirectory=$j.cwd};" \
	+ "if($j.argline){$l.ArgumentList=$j.argline};Start-Process @l"


## {"args": PackedStringArray for powershell.exe, "env": {"GOSH_LAUNCH": json}} (pure; unit-tested).
static func build_powershell_launch(file: String, args: PackedStringArray, window_style: String, cwd: String, env_additions: Dictionary) -> Dictionary:
	var payload := {"file": file, "argline": windows_command_line(args), "style": window_style, "cwd": cwd, "env": env_additions}
	return {
		"args": PackedStringArray(["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", Marshalls.raw_to_base64(PS_SCRIPT.to_utf16_buffer())]),
		"env": {"GOSH_LAUNCH": JSON.stringify(payload)},
	}


static func _spawn_powershell(file: String, args: PackedStringArray, window_style: String, cwd: String, env_additions: Dictionary) -> Dictionary:
	var launch := build_powershell_launch(file, args, window_style, cwd, env_additions)
	for k in launch.env:
		OS.set_environment(k, launch.env[k])
	var pid := OS.create_process("powershell.exe", launch.args, false)
	for k in launch.env:
		OS.unset_environment(k)
	return _ok() if pid > 0 else _fail("Failed to spawn %s" % file)


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
				return _spawn_powershell(program_path, item_args, style, working_dir, env)
			elif ["exe", "com"].has(ext) and (item_args.size() > 0 or item.get("environment", "") != ""):
				return spawn_detached(program_path, item_args, working_dir, env)
			elif ["bat", "cmd"].has(ext):
				var com := OS.get_environment("ComSpec")
				var cargs := PackedStringArray(["/d", "/s", "/c", program_path])
				cargs.append_array(item_args)
				return spawn_detached(com if com != "" else "cmd.exe", cargs, working_dir, env)
			else:
				# ShellExecute also dispatches URI schemes (ms-msdt:, search-ms:, file:, ...); only
				# http(s) URLs are allowed to launch, so anything scheme-like that got here is refused.
				if has_uri_scheme(program_path):
					return _fail("Only http and https URLs are allowed")
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
