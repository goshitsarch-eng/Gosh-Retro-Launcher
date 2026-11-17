class_name LauncherToolsLogic
extends RefCounted
## UI-free actions of the Launcher Tools window (port of the handlers in
## components/LauncherTools/LauncherTools.tsx). Every action takes the store node (the
## ProgramStore autoload, or a scratch instance in tests) and returns a status line.

const SHELL_LABELS := {"win31": "Windows for Workgroups 3.11", "win95": "Windows 95", "mac": "Classic Mac OS", "be": "BeOS"}


static func shell_label(shell: String) -> String:
	return SHELL_LABELS.get(shell, SHELL_LABELS.win31)


static func appearance_form(settings: Dictionary) -> Dictionary:
	return {
		"shell": settings.get("shell", "win31"), "win31Scale": settings.get("win31Scale", "auto"),
		"win95Scale": settings.get("win95Scale", "auto"), "macScale": settings.get("macScale", "auto"),
		"beScale": settings.get("beScale", "auto"), "win31DesktopMode": settings.get("win31DesktopMode", false),
		"soundEnabled": settings.get("soundEnabled", true), "trayOnClose": settings.get("trayOnClose", true),
	}


## Apply: persist-first settings transaction (shellSwitch.applyShellSettingsTransaction).
## Returns {success, status, previousShell}.
static func apply_appearance(store: Node, form: Dictionary) -> Dictionary:
	var previous: Dictionary = store.settings.duplicate(true)
	var next: Dictionary = previous.duplicate(true)
	for k in ["shell", "win31Scale", "win95Scale", "macScale", "beScale", "win31DesktopMode", "soundEnabled", "trayOnClose"]:
		next[k] = form[k]
	var result: Dictionary = store.apply_settings_transaction(next)
	if result.get("success", false):
		return {"success": true, "previousShell": previous.get("shell", "win31"),
			"status": "Appearance settings applied. Active shell: %s." % shell_label(String(form.shell))}
	return {"success": false, "previousShell": previous.get("shell", "win31"),
		"status": "Could not switch shells: %s" % result.get("error", "unknown error")}


## Enriches every imported item with Platform.get_app_info data (icon/win31Icon/workingDir),
## like importGrp(). `info_fn(path) -> Dictionary` (may be empty). Returns the enriched group.
static func enrich_group(group: Dictionary, info_fn: Callable) -> Dictionary:
	var enriched: Dictionary = group.duplicate(true)
	var items := []
	for item in enriched.get("items", []):
		var info: Dictionary = info_fn.call(String(item.path))
		var it: Dictionary = item.duplicate(true)
		if not info.is_empty():
			if String(info.get("icon", "")) != "":
				it["icon"] = info.icon
			if String(info.get("win31Icon", "")) != "":
				it["win31Icon"] = info.win31Icon
			var wd: String = it.get("workingDir", "")
			if wd == "":
				wd = String(info.get("workingDir", ""))
			it["workingDir"] = wd
		else:
			it["workingDir"] = it.get("workingDir", "")
		items.append(it)
	enriched["items"] = items
	return enriched


## Import .GRP: `result` is Platform.import_grp(). Returns {status, groupId?}. The new group is
## found by its id (the one id that was not there before), not by its position in the list; the
## store may give the group a new id when it clashes with an existing one.
static func import_grp(store: Node, result: Dictionary, info_fn: Callable) -> Dictionary:
	if not result.get("success", false) or not result.has("group"):
		if result.get("error", "") != "Canceled":
			return {"status": String(result.get("error", "")) if String(result.get("error", "")) != "" else "Could not import the group."}
		return {"status": ""}
	var enriched := enrich_group(result.group, info_fn)
	var known := {}
	for g in store.groups:
		known[String(g.id)] = true
	var r: Dictionary = store.import_group(enriched)
	if not r.get("success", false):
		var err := String(r.get("error", ""))
		return {"status": "Could not import the group: %s." % err if err != "" else "Could not import the group."}
	store.save_groups_now()
	var gid := ""
	for g in store.groups:
		if not known.has(String(g.id)):
			gid = String(g.id)
			break
	var status := "Imported “%s” from .GRP." % enriched.name
	var details := repair_summary(int(r.get("normalized", 0)), int(r.get("shortcutsCleared", 0)))
	if details != "":
		status += " " + details
	var out := {"status": status}
	if gid != "":
		out["groupId"] = gid
	return out


## One sentence about values an import (or load) had to repair, "" when nothing was changed.
## e.g. "2 stored values were repaired and 1 shortcut key was cleared (shortcut keys need Ctrl, Alt,
## Shift or Meta)."
static func repair_summary(normalized: int, shortcuts_cleared: int) -> String:
	return DataTransfer.repair_summary(normalized, shortcuts_cleared)


## `skipped_notes`: sticky notes in the group, which a .GRP file cannot hold (Grp leaves them out).
static func export_grp_status(group_name: String, result: Dictionary, skipped_notes: int = 0) -> String:
	if result.get("success", false):
		var line := "Exported “%s” as a Windows 3.x .GRP file." % group_name
		if skipped_notes > 0:
			line += " %s left out: a .GRP file has no sticky notes." % ("1 sticky note was" if skipped_notes == 1 else "%d sticky notes were" % skipped_notes)
		return line
	if result.get("error", "") != "Canceled":
		return String(result.get("error", "")) if String(result.get("error", "")) != "" else "Could not export the group."
	return ""


static func import_json_status(result: Dictionary) -> String:
	if result.get("success", false):
		var details := repair_summary(int(result.get("normalized", 0)), int(result.get("shortcutsCleared", 0)))
		return "Launcher backup imported." + (" " + details if details != "" else "")
	if result.get("error", "") != "Canceled":
		return String(result.get("error", "")) if String(result.get("error", "")) != "" else "Import failed."
	return ""


static func url_valid(group_id: String, name: String, url: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)^https?://")
	return group_id != "" and not name.strip_edges().is_empty() and re.search(url) != null


## Add URL: returns the status line, "" when the inputs are not acceptable (no-op).
static func add_url(store: Node, group_id: String, name: String, url: String) -> String:
	if not url_valid(group_id, name, url):
		return ""
	store.add_item(group_id, {"name": name.strip_edges(), "path": url.strip_edges(), "workingDir": "",
		"icon": "network", "win31Icon": "network"})
	return "URL launcher added."


static func clamp_delay(value: Variant) -> int:
	var n := int(value) if (value is int or value is float) else int(String(value).to_int())
	if n == 0:
		n = 100
	return maxi(100, mini(5000, n))


static func set_delay(store: Node, value: Variant) -> int:
	var d := clamp_delay(value)
	store.update_settings({"launchDelay": d})
	return d


static func launch_status_start(buckets: Array, names: Variant = null) -> String:
	if buckets.size() == 1:
		return "Launching %s..." % LaunchGroups.format_launch_group(int(buckets[0].groupNumber), names)
	return "Launching all groups..."


static func launch_status_done(results: Array) -> String:
	var failures := 0
	for r in results:
		if not r.get("success", false):
			failures += 1
	if failures > 0:
		return "Launch finished with %d %s." % [failures, "failure" if failures == 1 else "failures"]
	return "Launched %d %s." % [results.size(), "item" if results.size() == 1 else "items"]


static func launch_group_label(bucket: Dictionary, names: Variant = null) -> String:
	return LaunchGroups.launch_label(int(bucket.groupNumber), bucket.items.size(), names)


# -------------------------------------------------------- launch group editing
# The "Launch groups" section edits groups in place; the wording and rules are the WfW manager's
# (W31DialogLogic), so every surface says the same thing.

## [{number, name, count, text, right}] of every launch group, named or with members.
static func launch_group_rows(groups: Array, names: Variant) -> Array:
	return W31DialogLogic.launch_group_rows(groups, names)


## Labels for the per-item "Batch group" choice: None, Group 1, Group 2: Morning, ... Group 8.
static func batch_group_labels(names: Variant, current: int = 0) -> Array:
	return W31DialogLogic.launch_group_choices(names, current).labels


## The launch group number shown at `index` of batch_group_labels(names, current).
static func batch_group_value(index: int, current: int = 0) -> int:
	return int(W31DialogLogic.launch_group_choices(null, current).values[index])


static func new_launch_group(store: Node, name: String) -> String:
	if W31DialogLogic.new_launch_group_number(store.groups, store.launch_group_names()) == 0:
		return W31DialogLogic.ALL_LAUNCH_GROUPS_IN_USE
	return String(W31DialogLogic.apply_new_launch_group(store, name).status) + \
		(" Pick its programs with Batch group below." if LaunchGroups.clean_name(name) != "" else "")


static func rename_launch_group(store: Node, number: int, name: String) -> String:
	return W31DialogLogic.apply_rename_launch_group(store, number, name)


static func renumber_launch_group(store: Node, from: int, to: int) -> String:
	return String(W31DialogLogic.apply_renumber_launch_group(store, from, to).status)


static func delete_launch_group_confirmation(groups: Array, names: Variant, number: int) -> String:
	return W31DialogLogic.delete_launch_group_message(groups, names, number)


static func delete_launch_group(store: Node, number: int) -> String:
	return W31DialogLogic.apply_delete_launch_group(store, number)


# ------------------------------------------------------- Export All / Import All

## Status line after Export All (Platform.export_all()); "" on Cancel.
static func export_all_status(result: Dictionary) -> String:
	return DataTransfer.export_status(result)


## Status line after Import All (Platform.import_data()); "" on Cancel.
static func import_all_status(result: Dictionary) -> String:
	return DataTransfer.import_status(result)


## Items of every group as [{key "groupId:itemId", label "Group — Item"}].
static func item_choices(groups: Array) -> Array:
	var out := []
	for g in groups:
		for it in g.items:
			out.append({"key": "%s:%s" % [g.id, it.id], "label": "%s — %s" % [g.name, it.name]})
	return out


static func launch_profile_updates(args: String, working_dir: String, environment: String, run_mode: String, launch_group: Variant) -> Dictionary:
	return {"arguments": args, "workingDir": working_dir, "environment": environment,
		"runMode": run_mode if Types.RUN_MODES.has(run_mode) else "normal",
		"launchGroup": maxi(0, int(launch_group))}


static func save_launch_profile(store: Node, group_id: String, item_id: String, updates: Dictionary) -> String:
	store.update_item(group_id, item_id, updates)
	return "Launch profile saved."


static func save_profile(store: Node, name: String) -> Dictionary:
	var id: String = store.save_workspace_profile(name)
	return {"id": id, "status": "Workspace profile saved."}


## Apply asks before it replaces every group and item. Returns {required, message}; required is
## false when no known profile is selected (nothing would be applied).
static func apply_profile_confirmation(profiles: Array, id: String) -> Dictionary:
	if id == "":
		return {"required": false, "message": ""}
	for p in profiles:
		if String(p.get("id", "")) == id:
			return {"required": true, "message":
				"Replace all groups and items with profile '%s'? A backup of your current data is saved first." % String(p.get("name", ""))}
	return {"required": false, "message": ""}


## The status line for Apply: the store's own error text when it refused (for example when the
## safety backup could not be written), and "Workspace profile applied." only on success.
static func apply_profile(store: Node, id: String) -> String:
	var r: Dictionary = store.apply_workspace_profile(id)
	return apply_profile_status(r)


static func apply_profile_status(result: Dictionary) -> String:
	if result.get("success", false):
		return "Workspace profile applied."
	var err := String(result.get("error", ""))
	return err if err != "" else "The workspace profile could not be applied."


static func rename_profile(store: Node, id: String, name: String) -> void:
	store.rename_workspace_profile(id, name)


static func delete_profile(store: Node, id: String) -> void:
	store.delete_workspace_profile(id)


static func profile_summary(profile: Dictionary) -> String:
	var n: int = profile.groups.size()
	return "%d %s · updated %s" % [n, "group" if n == 1 else "groups", profile.updatedAt]


static func backup_label(backup: Dictionary) -> String:
	return "%s — %s" % [backup.createdAt, String(backup.reason).replace("-", " ")]


static func create_backup(store: Node) -> String:
	store.create_backup("manual")
	return "Restore point created."


## "2026-11-14T10:22:33.123Z" -> "2026-11-14 10:22:33 UTC" (the stored time, which is UTC; the
## backup list shows the same value).
static func backup_time_text(created_at: String) -> String:
	var re := RegEx.new()
	re.compile("^(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}:\\d{2})")
	var m := re.search(created_at)
	if m == null:
		return created_at
	return "%s %s UTC" % [m.get_string(1), m.get_string(2)]


## Restore replaces all data, so it asks first. Returns {required, message}; required is false when
## the id is not in `backups` (nothing would be restored). "Backed up first" holds because
## ProgramStore.restore_backup writes a forced "store-replaced" backup and refuses if it cannot.
static func restore_confirmation(backups: Array, id: String) -> Dictionary:
	if id == "":
		return {"required": false, "message": ""}
	for b in backups:
		if String(b.get("id", "")) == id:
			return {"required": true, "message": "Restore the backup from %s? Your current data is backed up first." %
				backup_time_text(String(b.get("createdAt", "")))}
	return {"required": false, "message": ""}


static func restore_backup(store: Node, id: String) -> String:
	var r: Dictionary = store.restore_backup(id)
	if r.get("success", false):
		return "Backup restored."
	return String(r.get("error", "")) if String(r.get("error", "")) != "" else "Restore failed."
