class_name LauncherToolsLogic
extends RefCounted
## UI-free actions of the Launcher Tools window (port of the handlers in
## components/LauncherTools/LauncherTools.tsx). Every action takes the store node (the
## ProgramStore autoload, or a scratch instance in tests) and returns a status line.

const SHELL_LABELS := {"win31": "Windows for Workgroups 3.11", "win95": "Windows 95"}


static func shell_label(shell: String) -> String:
	return SHELL_LABELS.get(shell, SHELL_LABELS.win31)


static func appearance_form(settings: Dictionary) -> Dictionary:
	return {
		"shell": settings.get("shell", "win31"), "win31Scale": settings.get("win31Scale", "auto"),
		"win95Scale": settings.get("win95Scale", "auto"), "win31DesktopMode": settings.get("win31DesktopMode", false),
		"soundEnabled": settings.get("soundEnabled", true), "trayOnClose": settings.get("trayOnClose", true),
	}


## Apply: persist-first settings transaction (shellSwitch.applyShellSettingsTransaction).
## Returns {success, status, previousShell}.
static func apply_appearance(store: Node, form: Dictionary) -> Dictionary:
	var previous: Dictionary = store.settings.duplicate(true)
	var next: Dictionary = previous.duplicate(true)
	for k in ["shell", "win31Scale", "win95Scale", "win31DesktopMode", "soundEnabled", "trayOnClose"]:
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


## Import .GRP: `result` is Platform.import_grp(). Returns {status, groupId?}.
static func import_grp(store: Node, result: Dictionary, info_fn: Callable) -> Dictionary:
	if not result.get("success", false) or not result.has("group"):
		if result.get("error", "") != "Canceled":
			return {"status": String(result.get("error", "")) if String(result.get("error", "")) != "" else "Could not import the group."}
		return {"status": ""}
	var enriched := enrich_group(result.group, info_fn)
	store.import_group(enriched)
	store.save_groups_now()
	var gid: String = store.groups[store.groups.size() - 1].id
	return {"status": "Imported “%s” from .GRP." % enriched.name, "groupId": gid}


static func export_grp_status(group_name: String, result: Dictionary) -> String:
	if result.get("success", false):
		return "Exported “%s” as a Windows 3.x .GRP file." % group_name
	if result.get("error", "") != "Canceled":
		return String(result.get("error", "")) if String(result.get("error", "")) != "" else "Could not export the group."
	return ""


static func import_json_status(result: Dictionary) -> String:
	if result.get("success", false):
		return "Launcher backup imported."
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


static func launch_status_start(buckets: Array) -> String:
	if buckets.size() == 1:
		return "Launching Group %d..." % int(buckets[0].groupNumber)
	return "Launching all groups..."


static func launch_status_done(results: Array) -> String:
	var failures := 0
	for r in results:
		if not r.get("success", false):
			failures += 1
	if failures > 0:
		return "Launch finished with %d %s." % [failures, "failure" if failures == 1 else "failures"]
	return "Launched %d %s." % [results.size(), "item" if results.size() == 1 else "items"]


static func launch_group_label(bucket: Dictionary) -> String:
	var n: int = bucket.items.size()
	return "Launch Group %d (%d %s)" % [int(bucket.groupNumber), n, "item" if n == 1 else "items"]


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
		"launchGroup": clampi(int(launch_group), 0, 8)}


static func save_launch_profile(store: Node, group_id: String, item_id: String, updates: Dictionary) -> String:
	store.update_item(group_id, item_id, updates)
	return "Launch profile saved."


static func save_profile(store: Node, name: String) -> Dictionary:
	var id: String = store.save_workspace_profile(name)
	return {"id": id, "status": "Workspace profile saved."}


static func apply_profile(store: Node, id: String) -> String:
	store.apply_workspace_profile(id)
	return "Workspace profile applied."


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


static func restore_backup(store: Node, id: String) -> String:
	var r: Dictionary = store.restore_backup(id)
	if r.get("success", false):
		return "Backup restored."
	return String(r.get("error", "")) if String(r.get("error", "")) != "" else "Restore failed."
