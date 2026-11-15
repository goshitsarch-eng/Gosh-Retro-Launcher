extends Node
## Autoload "ProgramStore". Port of src/renderer/src/store/programStore.ts (Zustand) plus the
## main-process store handlers. Holds groups/settings/profiles, validates, and persists with a
## 300 ms debounce (flushed on exit, so quitting never loses the last edit).

signal groups_changed
signal settings_changed
signal profiles_changed
signal data_loaded
signal data_reloaded  ## emitted after import/restore replaced everything
## Values that had to be repaired to keep the data storable. `source` is "load", "import",
## "grp-import", "profile-apply" or "save"; `report` is {"normalized": n, "shortcutsCleared": n}.
## Hosts can show it to the user. (Load runs before anything connects, so `load_report` keeps it too.)
signal data_normalized(source: String, report: Dictionary)
## A write was refused or a safety backup could not be made. `kind` is "groups", "settings" or
## "backup". The change stays in memory and marked dirty, so the next flush retries it.
signal save_failed(kind: String, message: String)

const SAVE_DEBOUNCE := 0.3

var persistence: Persistence
var groups: Array = []
var settings: Dictionary = Types.default_settings()
var workspace_profiles: Array = []
var is_loading := true
## {"normalized": n} from the last init_store: stored values repaired while loading.
var load_report: Dictionary = {"normalized": 0}

var _groups_timer: Timer
var _settings_timer: Timer
var _groups_dirty := false
var _settings_dirty := false


func _init() -> void:
	_groups_timer = _make_timer(_flush_groups)
	_settings_timer = _make_timer(_flush_settings)


func _make_timer(cb: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = SAVE_DEBOUNCE
	t.timeout.connect(cb)
	add_child(t)
	return t


func _exit_tree() -> void:
	flush()


## Writes anything still pending to disk immediately.
func flush() -> void:
	if _groups_dirty:
		_flush_groups()
	if _settings_dirty:
		_flush_settings()


# ----------------------------------------------------------------- loading

func init_store(user_data_dir: String = "") -> void:
	persistence = Persistence.new(user_data_dir)
	persistence.init_store()
	load_report = persistence.load_report.duplicate()
	load_data()
	if int(load_report.get("normalized", 0)) > 0:
		push_warning("Program Manager repaired %d invalid stored value(s) while loading." % load_report.normalized)
		data_normalized.emit("load", {"normalized": load_report.normalized, "shortcutsCleared": 0})


func load_data() -> void:
	var all := persistence.get_all_data()
	groups = all.groups
	settings = all.settings
	workspace_profiles = all.workspaceProfiles
	is_loading = false
	groups_changed.emit()
	settings_changed.emit()
	profiles_changed.emit()
	data_loaded.emit()


## Save guard. A write is never skipped silently: data the validator refuses is first repaired with
## the same normaliser used on load (the repair is applied in memory too, logged with push_error and
## announced through data_normalized), then written. Only if it is still invalid after that is the
## write skipped; then push_error + save_failed fire and the dirty flag stays set, so the change is
## kept in memory and retried on the next flush (including the one on exit).
func _flush_groups() -> void:
	_groups_dirty = false
	_groups_timer.stop()
	if not persistence:
		return
	if not _groups_valid(groups):
		var ctx := {"normalized": 0}
		groups = Migration.normalize_groups(groups, ctx)
		push_error("Program Manager: repaired %d invalid group/item value(s) before saving." % ctx.normalized)
		data_normalized.emit("save", {"normalized": ctx.normalized, "shortcutsCleared": 0})
		groups_changed.emit()
		if not _groups_valid(groups):
			_groups_dirty = true
			push_error("Program Manager: groups could not be saved because they are invalid.")
			save_failed.emit("groups", "Your program groups could not be saved because they contain invalid data.")
			return
	persistence.set_groups(groups)


func _flush_settings() -> void:
	_settings_dirty = false
	_settings_timer.stop()
	if not persistence:
		return
	if not Validators.is_valid_settings(settings):
		var ctx := {"normalized": 0}
		settings = Migration.normalize_settings(settings, ctx)
		push_error("Program Manager: reset %d invalid setting(s) to their defaults before saving." % ctx.normalized)
		data_normalized.emit("save", {"normalized": ctx.normalized, "shortcutsCleared": 0})
		settings_changed.emit()
		if not Validators.is_valid_settings(settings):
			_settings_dirty = true
			push_error("Program Manager: settings could not be saved because they are invalid.")
			save_failed.emit("settings", "Your settings could not be saved because they contain invalid data.")
			return
	persistence.set_settings(settings)


static func _groups_valid(g: Array) -> bool:
	for x in g:
		if not Validators.is_valid_group(x):
			return false
	return true


func save_groups_now() -> void:
	_flush_groups()


func save_settings_now() -> void:
	_flush_settings()


func _save_profiles() -> void:
	if persistence:
		persistence.set_workspace_profiles(workspace_profiles)


func _dirty_groups() -> void:
	_groups_dirty = true
	if _groups_timer and is_inside_tree():
		_groups_timer.start()
	groups_changed.emit()


func _dirty_groups_quiet() -> void:
	## Persist without announcing (geometry written back from the live UI).
	_groups_dirty = true
	if _groups_timer and is_inside_tree():
		_groups_timer.start()


# ------------------------------------------------------------------ groups

static func make_group(name: String, index: int) -> Dictionary:
	var d := Types.default_window_state()
	var base := d.duplicate(true)
	base.x = d.x + index * 30
	base.y = d.y + index * 30
	return {
		"id": Types.make_id(),
		"name": name,
		"icon": "folder",
		"windowState": base.duplicate(true),
		"shellWindowState": Types.create_shell_window_state(base),
		"win31IconPosition": {"x": (index % 8) * 75, "y": 368 - (index / 8) * 58},
		"items": [],
	}


func find_group(id: String) -> Dictionary:
	for g in groups:
		if g.id == id:
			return g
	return {}


func find_item(group_id: String, item_id: String) -> Dictionary:
	for it in find_group(group_id).get("items", []):
		if it.id == item_id:
			return it
	return {}


func add_group(name: String) -> String:
	var group := make_group(name, groups.size())
	groups.append(group)
	_dirty_groups()
	return group.id


## Adds an imported (.GRP) group. It is normalised like stored data, and shortcut keys without a
## modifier are cleared. Returns {"success", "normalized", "shortcutsCleared"} (success is false and
## nothing is added when the group has no usable id/name).
func import_group(group: Dictionary) -> Dictionary:
	var ctx := {"normalized": 0}
	var normalized: Variant = Migration.normalize_group(group, ctx)
	if normalized == null:
		push_error("Program Manager: the imported group is invalid and was not added.")
		return {"success": false, "error": "Invalid group data", "normalized": 0, "shortcutsCleared": 0}
	var imported: Dictionary = normalized
	var cleared := Migration.clear_unsafe_shortcuts([imported])
	var existing_group_ids := {}
	var existing_item_ids := {}
	for g in groups:
		existing_group_ids[g.id] = true
		for it in g.items:
			existing_item_ids[it.id] = true
	if existing_group_ids.has(imported.id):
		imported.id = Types.make_id()
	for it in imported.items:
		if existing_item_ids.has(it.id):
			it.id = Types.make_id()
	groups.append(imported)
	_dirty_groups()
	var report := {"normalized": int(ctx.normalized), "shortcutsCleared": cleared}
	if report.normalized > 0 or cleared > 0:
		data_normalized.emit("grp-import", report)
	return {"success": true, "normalized": report.normalized, "shortcutsCleared": cleared}


func replace_groups(new_groups: Array) -> void:
	groups = new_groups.duplicate(true)
	_dirty_groups()


func add_starter_workspace() -> void:
	var existing := {}
	for g in groups:
		existing[String(g.name).to_lower()] = true
	var created := []
	var index := 0
	for name in ["Main", "Accessories", "Games", "Utilities", "Internet"]:
		if existing.has(name.to_lower()):
			continue
		var g := make_group(name, groups.size() + index)
		var minimized: bool = name != "Main"
		g.shellWindowState.win31.minimized = minimized
		g.shellWindowState.win95.minimized = minimized
		g.windowState.minimized = minimized
		created.append(g)
		index += 1
	if created.is_empty():
		return
	groups.append_array(created)
	_dirty_groups()


func update_group(id: String, updates: Dictionary) -> void:
	for g in groups:
		if g.id == id:
			for k in updates:
				g[k] = updates[k]
	_dirty_groups()


func delete_group(id: String) -> void:
	groups = groups.filter(func(g): return g.id != id)
	_dirty_groups()


func update_group_window_state(id: String, updates: Dictionary, shell_override: String = "") -> void:
	var shell := shell_override if shell_override != "" else String(settings.get("shell", "win31"))
	for g in groups:
		if g.id != id:
			continue
		var current := Types.get_group_window_state(g, shell).duplicate(true)
		for k in updates:
			if updates[k] == null:
				current.erase(k)
			else:
				current[k] = updates[k]
		if not Jsonx.is_obj(g.get("shellWindowState")):
			g["shellWindowState"] = Types.create_shell_window_state(Types.get_group_window_state(g, "win31"))
		g.shellWindowState[shell] = current
		g["windowState"] = g.shellWindowState.win31.duplicate(true)
	if settings.get("saveSettingsOnExit", true):
		_dirty_groups_quiet()


func update_group_icon_position(id: String, position: Dictionary) -> void:
	for g in groups:
		if g.id == id:
			g["win31IconPosition"] = position
	if settings.get("saveSettingsOnExit", true):
		_dirty_groups_quiet()


# ------------------------------------------------------------------- items

func add_item(group_id: String, item: Dictionary) -> String:
	var new_item: Dictionary = item.duplicate(true)
	new_item["id"] = Types.make_id()
	for g in groups:
		if g.id == group_id:
			g.items.append(new_item)
	_dirty_groups()
	return new_item.id


func update_item(group_id: String, item_id: String, updates: Dictionary) -> void:
	for g in groups:
		if g.id != group_id:
			continue
		for it in g.items:
			if it.id == item_id:
				for k in updates:
					if updates[k] == null:
						it.erase(k)
					else:
						it[k] = updates[k]
	_dirty_groups()


func update_item_position(group_id: String, item_id: String, position: Dictionary) -> void:
	update_item(group_id, item_id, {"win31Position": position})


func update_win95_item_position(group_id: String, item_id: String, position: Dictionary) -> void:
	update_item(group_id, item_id, {"win95Position": position})


func delete_item(group_id: String, item_id: String) -> void:
	for g in groups:
		if g.id == group_id:
			g.items = g.items.filter(func(i): return i.id != item_id)
	_dirty_groups()


func move_item(from_group_id: String, to_group_id: String, item_id: String) -> void:
	if from_group_id == to_group_id:
		return
	var item := find_item(from_group_id, item_id)
	if item.is_empty():
		return
	var moved: Dictionary = item.duplicate(true)
	moved.erase("win31Position")
	moved.erase("win95Position")
	for g in groups:
		if g.id == from_group_id:
			g.items = g.items.filter(func(i): return i.id != item_id)
		elif g.id == to_group_id:
			g.items.append(moved)
	_dirty_groups()


func copy_item(from_group_id: String, to_group_id: String, item_id: String) -> void:
	var item := find_item(from_group_id, item_id)
	if item.is_empty():
		return
	var copy: Dictionary = item.duplicate(true)
	copy["id"] = Types.make_id()
	copy.erase("win31Position")
	copy.erase("win95Position")
	for g in groups:
		if g.id == to_group_id:
			g.items.append(copy)
	_dirty_groups()


# ---------------------------------------------------------------- profiles

func _now_iso() -> String:
	return Persistence._iso(int(Time.get_unix_time_from_system() * 1000.0))


func save_workspace_profile(name: String) -> String:
	var now := _now_iso()
	var trimmed := name.strip_edges()
	var profile := {
		"id": Types.make_id(),
		"name": trimmed if trimmed != "" else "Workspace %d" % (workspace_profiles.size() + 1),
		"groups": groups.duplicate(true),
		"createdAt": now,
		"updatedAt": now,
	}
	workspace_profiles.append(profile)
	_save_profiles()
	profiles_changed.emit()
	return profile.id


## Replaces every group with the profile's groups. A forced backup of the current data (pending
## edits flushed first) is written beforehand under the existing "store-replaced" reason, so the
## replaced groups can be restored from Backups. If that backup cannot be written, nothing is
## replaced. Returns {"success", "backup"?, "normalized"?, "error"?}.
func apply_workspace_profile(id: String) -> Dictionary:
	for p in workspace_profiles:
		if p.id != id:
			continue
		var backup := {}
		if persistence:
			backup = create_backup("store-replaced")
			if backup.is_empty():
				var msg := "Could not create a backup before applying the workspace profile, so it was not applied."
				push_error("Program Manager: " + msg)
				save_failed.emit("backup", msg)
				return {"success": false, "error": msg}
		var ctx := {"normalized": 0}
		replace_groups(Migration.normalize_groups(p.groups, ctx))
		if int(ctx.normalized) > 0:
			data_normalized.emit("profile-apply", {"normalized": ctx.normalized, "shortcutsCleared": 0})
		return {"success": true, "backup": backup, "normalized": ctx.normalized}
	return {"success": false, "error": "Workspace profile not found"}


func delete_workspace_profile(id: String) -> void:
	workspace_profiles = workspace_profiles.filter(func(p): return p.id != id)
	_save_profiles()
	profiles_changed.emit()


func rename_workspace_profile(id: String, name: String) -> void:
	var trimmed := name.strip_edges()
	if trimmed == "":
		return
	for p in workspace_profiles:
		if p.id == id:
			p["name"] = trimmed
			p["updatedAt"] = _now_iso()
	_save_profiles()
	profiles_changed.emit()


# ---------------------------------------------------------------- settings

func update_settings(updates: Dictionary) -> void:
	for k in updates:
		settings[k] = updates[k]
	_settings_dirty = true
	if _settings_timer and is_inside_tree():
		_settings_timer.start()
	settings_changed.emit()


## Persist-first settings transaction (port of shellSwitch.applyShellSettingsTransaction).
## Returns {"success": bool, "error": String}.
func apply_settings_transaction(next: Dictionary) -> Dictionary:
	var previous := settings.duplicate(true)
	if not Validators.is_valid_settings(next):
		return {"success": false, "error": "Invalid settings data"}
	persistence.set_settings(next)
	settings = next.duplicate(true)
	settings_changed.emit()
	return {"success": true, "previous": previous}


# ---------------------------------------------------- import / export / backups

const MAX_IMPORT_BYTES := 10 * 1024 * 1024


func export_to(path: String) -> bool:
	flush()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(Jsonx.stringify(persistence.get_all_data(), "  "))
	return true


## Repairable values are fixed first (_repair_import_values), then top-level groups and settings are
## validated and a structurally malformed file is refused. Everything that passes, and the workspace
## profiles (which have no strict check), is then normalised like stored data, and item shortcut keys without a modifier are cleared in groups and
## profiles alike. Returns {"success": true}, plus "normalized" and "shortcutsCleared" counts when
## anything was changed so the UI can report it, or {"success": false, "error"}.
func import_from(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"success": false, "error": "Failed to read file"}
	if f.get_length() > MAX_IMPORT_BYTES:
		return {"success": false, "error": "Import file is too large (max %dMB)" % (MAX_IMPORT_BYTES / (1024 * 1024))}
	var parsed := Jsonx.parse_checked(f.get_as_text())
	if not parsed[0] or not Jsonx.is_obj(parsed[1]):
		return {"success": false, "error": "Failed to read file"}
	var d: Dictionary = parsed[1]
	var ctx := {"normalized": 0}
	_repair_import_values(d, ctx)
	if not Jsonx.is_arr(d.get("groups")) or not Validators.is_valid_settings(d.get("settings")):
		return {"success": false, "error": "Invalid file format"}
	for g in d.groups:
		if not Validators.is_valid_group(g):
			return {"success": false, "error": "Invalid group or item data in file"}
	var migrated := Migration.migrate_store_data(d, ctx)
	var cleared := Migration.clear_unsafe_shortcuts(migrated.groups)
	for p in migrated.workspaceProfiles:
		cleared += Migration.clear_unsafe_shortcuts(p.groups)
	_cancel_pending()
	persistence.set_all_data(migrated)
	load_data()
	data_reloaded.emit()
	var report := {"normalized": int(ctx.normalized), "shortcutsCleared": cleared}
	if report.normalized > 0 or cleared > 0:
		data_normalized.emit("import", report)
		return {"success": true, "normalized": report.normalized, "shortcutsCleared": cleared}
	return {"success": true}


## Value-level repairs made before import_from's strict checks, so a file is refused only for its
## structure (missing or mistyped records, missing settings keys) and not for a value the store can
## repair: an out-of-range launchGroup becomes 0 and a known setting with a wrong value takes its
## default. Missing settings keys are not filled in. Each repair is counted in ctx.
static func _repair_import_values(d: Dictionary, ctx: Dictionary) -> void:
	if Jsonx.is_obj(d.get("settings")):
		var s: Dictionary = d.settings
		var defaults := Types.default_settings()
		for k in s.keys():
			if defaults.has(k) and not Validators.is_valid_setting_value(str(k), s[k]):
				s[k] = Jsonx.clone(defaults[k])
				Migration._bump(ctx)
	if Jsonx.is_arr(d.get("groups")):
		for g in d.groups:
			if not Jsonx.is_obj(g) or not Jsonx.is_arr(g.get("items")):
				continue
			for it in g.items:
				if Jsonx.is_obj(it) and it.has("launchGroup") and not Validators.is_valid_launch_group(it.launchGroup):
					it["launchGroup"] = 0
					Migration._bump(ctx)


func list_backups() -> Array:
	return persistence.list_backups()


func create_backup(reason: String = "manual") -> Dictionary:
	flush()
	return persistence.create_backup(persistence.get_all_data(), reason, true)


func restore_backup(id: String) -> Dictionary:
	var d := persistence.read_backup(id)
	if d.is_empty():
		return {"success": false, "error": "Invalid backup identifier"}
	_cancel_pending()
	persistence.set_all_data(d)
	load_data()
	data_reloaded.emit()
	return {"success": true}


func _cancel_pending() -> void:
	_groups_dirty = false
	_settings_dirty = false
	if _groups_timer:
		_groups_timer.stop()
	if _settings_timer:
		_settings_timer.stop()
