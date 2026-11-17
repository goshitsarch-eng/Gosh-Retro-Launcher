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
## A write was refused (invalid data), the store file could not be written (read-only or full disk),
## or a safety backup could not be made. `kind` is "groups", "settings", "profiles" or "backup". For
## groups, settings and profiles the change stays in memory and marked dirty. Groups and settings are
## retried by their own next flush, profiles by the next flush of any kind, and all of them by the
## flush on exit.
signal save_failed(kind: String, message: String)
## The first successful save of `kind` ("groups", "settings" or "profiles") after save_failed reported it.
signal save_recovered(kind: String)

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
var _profiles_dirty := false
## Kinds ("groups", "settings", "profiles") whose last flush failed.
var _failing := {}

const WRITE_FAILED_GROUPS := "Your program groups could not be saved because the data folder could not be written (it may be read-only or full)."
const WRITE_FAILED_PROFILES := "Your workspace profiles could not be saved because the data folder could not be written (it may be read-only or full)."
const WRITE_FAILED_SETTINGS := "Your settings could not be saved because the data folder could not be written (it may be read-only or full)."


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
	if not _groups_dirty and not _settings_dirty:
		_retry_profiles()  # otherwise the group/settings flush below retries them first
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
## write skipped. The same happens when the store file cannot be written (read-only or full disk).
## Either way push_error + save_failed fire and the dirty flag stays set, so the change is kept in
## memory and retried on the next flush (including the one on exit). The first successful save after
## a failure emits save_recovered.
func _flush_groups() -> void:
	_groups_dirty = false
	_groups_timer.stop()
	if not persistence:
		return
	_retry_profiles()
	if not _groups_valid(groups):
		var ctx := {"normalized": 0}
		groups = Migration.normalize_groups(groups, ctx)
		push_error("Program Manager: repaired %d invalid group/item value(s) before saving." % ctx.normalized)
		data_normalized.emit("save", {"normalized": ctx.normalized, "shortcutsCleared": 0})
		groups_changed.emit()
		if not _groups_valid(groups):
			_save_failed("groups", "groups could not be saved because they are invalid.",
				"Your program groups could not be saved because they contain invalid data.")
			return
	if not persistence.set_groups(groups):
		_save_failed("groups", "groups could not be written to %s." % persistence.store_path(), WRITE_FAILED_GROUPS)
		return
	_save_succeeded("groups")


func _flush_settings() -> void:
	_settings_dirty = false
	_settings_timer.stop()
	if not persistence:
		return
	_retry_profiles()
	if not Validators.is_valid_settings(settings):
		var ctx := {"normalized": 0}
		settings = Migration.normalize_settings(settings, ctx)
		push_error("Program Manager: reset %d invalid setting(s) to their defaults before saving." % ctx.normalized)
		data_normalized.emit("save", {"normalized": ctx.normalized, "shortcutsCleared": 0})
		settings_changed.emit()
		if not Validators.is_valid_settings(settings):
			_save_failed("settings", "settings could not be saved because they are invalid.",
				"Your settings could not be saved because they contain invalid data.")
			return
	if not persistence.set_settings(settings):
		_save_failed("settings", "settings could not be written to %s." % persistence.store_path(), WRITE_FAILED_SETTINGS)
		return
	_save_succeeded("settings")


## Keeps `kind` pending (dirty) for the next flush, logs `log_text` and tells the host.
func _save_failed(kind: String, log_text: String, message: String) -> void:
	match kind:
		"groups":
			_groups_dirty = true
		"settings":
			_settings_dirty = true
		"profiles":
			_profiles_dirty = true
	_failing[kind] = true
	push_error("Program Manager: " + log_text)
	save_failed.emit(kind, message)


func _save_succeeded(kind: String) -> void:
	if _failing.erase(kind):
		save_recovered.emit(kind)


static func _groups_valid(g: Array) -> bool:
	for x in g:
		if not Validators.is_valid_group(x):
			return false
	return true


func save_groups_now() -> void:
	_flush_groups()


func save_settings_now() -> void:
	_flush_settings()


## Writes the whole in-memory profile list, so a change made while an earlier write is still pending
## is included. On failure persistence rolls its data back; the profiles stay dirty and are written
## again (before the groups/settings write) by the next flush of any kind.
func _save_profiles() -> void:
	_profiles_dirty = false
	if not persistence:
		return
	if not persistence.set_workspace_profiles(workspace_profiles):
		_save_failed("profiles", "workspace profiles could not be written to %s." % persistence.store_path(), WRITE_FAILED_PROFILES)
		return
	_save_succeeded("profiles")


func _retry_profiles() -> void:
	if _profiles_dirty:
		_save_profiles()


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


# ----------------------------------------------------------- launch groups
# A launch group is a number (item.launchGroup) plus an optional name in settings.launchGroupNames.
# A named group with no members still exists (that is how an empty group is created).

func launch_group_names() -> Dictionary:
	return LaunchGroups.names_from(settings)


## Names group `number`; a blank name removes the name (the group then exists only while it has members).
func set_launch_group_name(number: int, name: String) -> void:
	if number <= 0:
		return
	var names := launch_group_names().duplicate()
	var cleaned := LaunchGroups.clean_name(name)
	if cleaned == "":
		names.erase(str(number))
	else:
		names[str(number)] = cleaned
	update_settings({"launchGroupNames": names})


## Makes exactly the items in `keys` ("groupId:itemId") the members of group `number`: listed items
## join it (leaving any other launch group) and current members that are not listed leave it.
func set_launch_group_members(number: int, keys: Array) -> void:
	if number <= 0:
		return
	var wanted := {}
	for k in keys:
		wanted[String(k)] = true
	var changed := false
	for g in groups:
		for it in g.items:
			var key := "%s:%s" % [g.id, it.id]
			var current := int(it.get("launchGroup", 0))
			if wanted.has(key) and current != number:
				it["launchGroup"] = number
				changed = true
			elif not wanted.has(key) and current == number:
				it["launchGroup"] = 0
				changed = true
	if changed:
		_dirty_groups()


## Creates a launch group on the lowest free number with `name` and the items in `keys`.
## Returns the number, or 0 when every number from 1 to LaunchGroups.MAX_GROUP is taken or the
## group would be empty and unnamed (and so would not exist).
func create_launch_group(name: String, keys: Array = []) -> int:
	var number := LaunchGroups.next_free_number(groups, launch_group_names())
	if number == 0 or (LaunchGroups.clean_name(name) == "" and keys.is_empty()):
		return 0
	set_launch_group_name(number, name)
	set_launch_group_members(number, keys)
	return number


## Removes group `number`: its members go back to no launch group and its name is forgotten.
## The programs themselves are not touched.
func delete_launch_group(number: int) -> void:
	if number <= 0:
		return
	set_launch_group_members(number, [])
	if launch_group_names().has(str(number)):
		var names := launch_group_names().duplicate()
		names.erase(str(number))
		update_settings({"launchGroupNames": names})


## Moves group `from` to number `to` (members and name). If `to` is already a group, the two swap,
## so Launch All runs them in the new order. Returns false for an invalid or unchanged number.
func renumber_launch_group(from: int, to: int) -> bool:
	if from <= 0 or to <= 0 or from == to:
		return false
	var changed := false
	for g in groups:
		for it in g.items:
			var current := int(it.get("launchGroup", 0))
			if current == from:
				it["launchGroup"] = to
				changed = true
			elif current == to:
				it["launchGroup"] = from
				changed = true
	var names := launch_group_names().duplicate()
	var name_from: Variant = names.get(str(from))
	var name_to: Variant = names.get(str(to))
	names.erase(str(from))
	names.erase(str(to))
	if name_from != null:
		names[str(to)] = name_from
	if name_to != null:
		names[str(from)] = name_to
	if not Jsonx.equal(names, launch_group_names()):
		update_settings({"launchGroupNames": names})
		changed = true
	if changed:
		_dirty_groups()
	return true


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
	if not persistence.set_settings(next):
		push_error("Program Manager: settings could not be written to %s." % persistence.store_path())
		return {"success": false, "error": "The settings file could not be written"}
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
## profiles alike. Like restore_backup, a forced "store-replaced" backup of the current data (pending
## edits flushed first) is written before anything is replaced; if it cannot be written, save_failed
## ("backup") is emitted and nothing is imported. A store file that cannot be written also refuses the
## import and leaves the data as it was. Returns {"success": true}, plus "normalized" and
## "shortcutsCleared" counts when anything was changed so the UI can report it, or
## {"success": false, "error"}.
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
	if create_backup("store-replaced").is_empty():
		var msg := "Could not back up your current data before importing, so the file was not imported."
		push_error("Program Manager: " + msg)
		save_failed.emit("backup", msg)
		return {"success": false, "error": msg}
	if not persistence.set_all_data(migrated, false):
		push_error("Program Manager: imported data could not be written to %s." % persistence.store_path())
		return {"success": false, "error": "Failed to save the imported data"}
	_cancel_pending()
	load_data()
	data_reloaded.emit()
	var report := {"normalized": int(ctx.normalized), "shortcutsCleared": cleared}
	if report.normalized > 0 or cleared > 0:
		data_normalized.emit("import", report)
		return {"success": true, "normalized": report.normalized, "shortcutsCleared": cleared}
	return {"success": true}


## Value-level repairs made before import_from's strict checks, so a file is refused only for its
## structure (missing or mistyped records, missing settings keys) and not for a value the store can
## repair: a launchGroup that is not an integer >= 0 becomes 0 and a known setting with a wrong value takes its
## default. Missing settings keys are not filled in. Each repair is counted in ctx.
static func _repair_import_values(d: Dictionary, ctx: Dictionary) -> void:
	if Jsonx.is_obj(d.get("settings")):
		var s: Dictionary = d.settings
		var defaults := Types.default_settings()
		for k in s.keys():
			if str(k) == "launchGroupNames" and Jsonx.is_obj(s[k]) and not Validators.is_launch_group_names(s[k]):
				s[k] = Migration._normalize_launch_group_names(s[k])  # keep the usable names
				Migration._bump(ctx)
				continue
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


## Replaces all data with the backup. Like apply_workspace_profile, a forced "store-replaced" backup
## of the current data is written first (create_backup flushes pending edits, so it holds the latest
## data); if it cannot be written, nothing is restored. The backup to restore is read before that, so
## pruning cannot remove it. Persistence.set_all_data is told not to write a second backup of the same
## data, so each restore uses up exactly one restore point. Returns {"success", "backup"?, "error"?}.
func restore_backup(id: String) -> Dictionary:
	var d := persistence.read_backup(id)
	if d.is_empty():
		return {"success": false, "error": "Invalid backup identifier"}
	var backup := create_backup("store-replaced")
	if backup.is_empty():
		var msg := "Could not back up your current data before restoring, so the backup was not restored."
		push_error("Program Manager: " + msg)
		save_failed.emit("backup", msg)
		return {"success": false, "error": msg}
	if not persistence.set_all_data(d, false):
		push_error("Program Manager: the restored data could not be written to %s." % persistence.store_path())
		return {"success": false, "error": "Failed to save the restored data"}
	_cancel_pending()
	load_data()
	data_reloaded.emit()
	return {"success": true, "backup": backup}


func _cancel_pending() -> void:
	_groups_dirty = false
	_settings_dirty = false
	_profiles_dirty = false
	if _groups_timer:
		_groups_timer.stop()
	if _settings_timer:
		_settings_timer.stop()
