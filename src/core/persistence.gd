class_name Persistence
extends RefCounted
## JSON persistence compatible with the Electron build's electron-store file
## (`program-manager-data.json` in the platform userData dir) plus versioned backups.
## Port of src/main/store.ts and src/main/backups.ts.

const STORE_FILE := "program-manager-data.json"
const BACKUP_LIMIT := 12
const AUTO_BACKUP_INTERVAL_MS := 30000
const APP_DIR_NAME := "program-manager"

var user_data_dir: String
var data: Dictionary = {}
var _last_auto_backup_ms := 0


static func default_user_data_dir() -> String:
	var override := OS.get_environment("PM_USER_DATA")
	if override != "":
		return override
	match OS.get_name():
		"Windows":
			var appdata := OS.get_environment("APPDATA")
			if appdata == "":
				appdata = OS.get_environment("USERPROFILE").path_join("AppData/Roaming")
			return appdata.path_join(APP_DIR_NAME)
		"macOS":
			return OS.get_environment("HOME").path_join("Library/Application Support").path_join(APP_DIR_NAME)
		_:
			var xdg := OS.get_environment("XDG_CONFIG_HOME")
			if xdg == "":
				xdg = OS.get_environment("HOME").path_join(".config")
			return xdg.path_join(APP_DIR_NAME)


func _init(dir: String = "") -> void:
	user_data_dir = dir if dir != "" else default_user_data_dir()


func store_path() -> String:
	return user_data_dir.path_join(STORE_FILE)


func backup_dir() -> String:
	return user_data_dir.path_join("backups")


# ---------------------------------------------------------------- store

## Loads (recovering a corrupt file from the newest backup) and migrates.
func init_store() -> void:
	DirAccess.make_dir_recursive_absolute(user_data_dir)
	recover_corrupt_store_file()
	var raw: Variant = {}
	if FileAccess.file_exists(store_path()):
		var parsed := Jsonx.parse_checked(FileAccess.get_file_as_string(store_path()))
		if parsed[0]:
			raw = parsed[1]
	data = Migration.migrate_store_data(raw)
	_write_store()


func _write_store() -> bool:
	DirAccess.make_dir_recursive_absolute(user_data_dir)
	var tmp := store_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(Jsonx.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, store_path())
	if err != OK:
		# Windows cannot rename over an existing file via some paths; fall back.
		DirAccess.remove_absolute(store_path())
		err = DirAccess.rename_absolute(tmp, store_path())
	return err == OK


func get_groups() -> Array:
	return data.get("groups", []).duplicate(true)


func set_groups(groups: Array) -> void:
	create_backup(get_all_data(), "groups-changed")
	data["groups"] = Jsonx.clone(groups)
	_write_store()


func get_settings() -> Dictionary:
	var s := Types.default_settings()
	var stored: Dictionary = data.get("settings", {})
	for k in stored:
		s[k] = Jsonx.clone(stored[k])
	return s


func set_settings(settings: Dictionary) -> void:
	create_backup(get_all_data(), "settings-changed")
	var merged := Types.default_settings()
	for k in settings:
		merged[k] = Jsonx.clone(settings[k])
	data["settings"] = merged
	_write_store()


func get_workspace_profiles() -> Array:
	return data.get("workspaceProfiles", []).duplicate(true)


func set_workspace_profiles(profiles: Array) -> void:
	create_backup(get_all_data(), "profiles-changed")
	data["workspaceProfiles"] = Jsonx.clone(profiles)
	_write_store()


func get_all_data() -> Dictionary:
	return Migration.migrate_store_data({
		"schemaVersion": data.get("schemaVersion", Types.CURRENT_SCHEMA_VERSION),
		"groups": get_groups(),
		"settings": get_settings(),
		"workspaceProfiles": get_workspace_profiles(),
	})


func set_all_data(value: Dictionary) -> void:
	var normalized := Migration.migrate_store_data(value)
	create_backup(get_all_data(), "store-replaced", true)
	data = normalized
	_write_store()


func clear_store() -> void:
	create_backup(get_all_data(), "store-cleared", true)
	data = Migration.migrate_store_data({})
	_write_store()


# -------------------------------------------------------------- backups

static func _safe_reason(reason: String) -> String:
	var re := RegEx.new()
	re.compile("[^a-z0-9]+")
	var s := re.sub(reason.to_lower(), "-", true)
	while s.begins_with("-"):
		s = s.substr(1)
	while s.ends_with("-"):
		s = s.substr(0, s.length() - 1)
	s = s.substr(0, 32)
	return s if s != "" else "backup"


static func _iso(ms: int) -> String:
	var secs := ms / 1000
	var dt := Time.get_datetime_dict_from_unix_time(secs)
	return "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, ms % 1000]


static func parse_backup_name(name: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^(\\d{4}-\\d{2}-\\d{2})T(\\d{2})-(\\d{2})-(\\d{2})[.-](\\d{3})Z--(.+)\\.json$")
	var m := re.search(name)
	if m == null:
		return {}
	return {
		"createdAt": "%sT%s:%s:%s.%sZ" % [m.get_string(1), m.get_string(2), m.get_string(3), m.get_string(4), m.get_string(5)],
		"reason": m.get_string(6),
	}


func list_backups() -> Array:
	var dir := DirAccess.open(backup_dir())
	if dir == null:
		return []
	var out := []
	for f in dir.get_files():
		var parsed := parse_backup_name(f)
		if parsed.is_empty():
			continue
		var fa := FileAccess.open(backup_dir().path_join(f), FileAccess.READ)
		if fa == null:
			continue
		out.append({"id": f, "createdAt": parsed.createdAt, "reason": parsed.reason, "size": fa.get_length()})
	out.sort_custom(func(a, b): return String(a.createdAt) > String(b.createdAt) or (a.createdAt == b.createdAt and String(a.id) > String(b.id)))
	return out


func _prune_backups() -> void:
	var all := list_backups()
	for i in range(BACKUP_LIMIT, all.size()):
		DirAccess.remove_absolute(backup_dir().path_join(all[i].id))


## Returns the BackupInfo dictionary, or {} when throttled/unwritable.
func create_backup(payload: Dictionary, reason: String, force: bool = false) -> Dictionary:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	if not force and now - _last_auto_backup_ms < AUTO_BACKUP_INTERVAL_MS and _last_auto_backup_ms != 0:
		return {}
	if not force:
		_last_auto_backup_ms = now
	DirAccess.make_dir_recursive_absolute(backup_dir())
	var created := _iso(now)
	var id := "%s--%s.json" % [created.replace(":", "-"), _safe_reason(reason)]
	var text := Jsonx.stringify(Migration.migrate_store_data(payload), "  ")
	var f := FileAccess.open(backup_dir().path_join(id), FileAccess.WRITE)
	if f == null:
		return {}
	f.store_string(text)
	f.close()
	_prune_backups()
	return {"id": id, "createdAt": created, "reason": _safe_reason(reason), "size": text.to_utf8_buffer().size()}


## Returns the migrated StoreData, or {} if the id is invalid/unreadable.
func read_backup(id: String) -> Dictionary:
	if id.get_file() != id or not id.ends_with(".json"):
		return {}
	var path := backup_dir().path_join(id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed := Jsonx.parse_checked(FileAccess.get_file_as_string(path))
	if not parsed[0]:
		return {}
	return Migration.migrate_store_data(parsed[1])


## Recovers malformed store JSON from the most recent backup before it is loaded.
func recover_corrupt_store_file() -> bool:
	var path := store_path()
	if not FileAccess.file_exists(path):
		return false
	if Jsonx.parse_checked(FileAccess.get_file_as_string(path))[0]:
		return false
	var corrupt := "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system() * 1000.0)]
	DirAccess.rename_absolute(path, corrupt)
	var backups := list_backups()
	if backups.is_empty():
		return false
	return DirAccess.copy_absolute(backup_dir().path_join(backups[0].id), path) == OK
