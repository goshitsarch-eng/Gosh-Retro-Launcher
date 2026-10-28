class_name Win95DialogLogic
extends RefCounted
## Pure rules behind the Win95 dialogs, Find window and property sheets (ports of the state
## handling in Win95Dialogs.tsx / Win95FindView.tsx). No UI; every function takes the store as an
## argument so tests can pass a throwaway ProgramStore instance.

const FIND_PAGE_STEP := 3
const RUN_MODES := ["normal", "minimized", "maximized"]
const RUN_MODE_LABELS := ["Normal window", "Minimized", "Maximized"]
const SHUTDOWN_HELP := "Shut Down affects only Gosh Retro Launcher. Restart can recreate this launcher in Windows 95 or switch it to Windows for Workgroups 3.11. Computer and MS-DOS operations remain unavailable."

## Session-lifetime Run history (most recent first).
static var run_history: Array = []


static func plural_objects(n: int) -> String:
	return "%d object%s" % [n, "" if n == 1 else "s"]


# ------------------------------------------------------------------------ Find

## Filters passed to ProgramSearch.find_programs. type: all|application|internet.
static func find_filters(named: String, group_id: String, include_subgroups: bool, type: String, containing: String, path: String) -> Dictionary:
	var f := {"named": named, "includeSubgroups": include_subgroups, "type": type, "containing": containing, "path": path}
	if group_id != "":
		f["groupId"] = group_id
	return f


static func find_result_ids(results: Array) -> Array:
	return results.map(func(r): return "%s:%s" % [r.group.id, r.item.id])


## Keyboard navigation inside the results list. Returns the new index, or -1 when the key is not a
## navigation key. PageUp/PageDown move 3 rows (as the TS does).
static func find_next_index(index: int, key: String, count: int) -> int:
	if count <= 0:
		return -1
	match key:
		"ArrowDown": return mini(count - 1, index + 1)
		"ArrowUp": return maxi(0, index - 1)
		"Home": return 0
		"End": return count - 1
		"PageDown": return mini(count - 1, index + FIND_PAGE_STEP)
		"PageUp": return maxi(0, index - FIND_PAGE_STEP)
	return -1


## New scroll offset that keeps row `index` visible in a viewport of `view_h` px.
static func find_reveal(scroll: int, index: int, row_h: int, view_h: int) -> int:
	var y := index * row_h
	if y < scroll:
		return y
	if y + row_h > scroll + view_h:
		return y + row_h - view_h
	return scroll


# ------------------------------------------------------------------------- Run

## Launch item for a typed command; {} when the text is blank.
static func run_item(command: String) -> Dictionary:
	var value := command.strip_edges()
	if value.is_empty():
		return {}
	return {"id": "win95-run", "name": value, "path": value, "icon": "run", "workingDir": ""}


static func remember_run(command: String) -> void:
	var value := command.strip_edges()
	if value.is_empty() or run_history.has(value):
		return
	run_history.push_front(value)


static func run_error(result: Dictionary, command: String) -> String:
	return String(result.get("error", "Cannot find '%s'." % command.strip_edges()))


# ------------------------------------------------------------------- Shut Down

## Settings to persist for a shut-down choice; {} when the choice needs no settings change.
static func shutdown_next_settings(settings: Dictionary, choice: String) -> Dictionary:
	if choice == "win31":
		var next := settings.duplicate(true)
		next["shell"] = "win31"
		return next
	return {}


# ---------------------------------------------------------------------- Wizard

static func wizard_can_next(command: String) -> bool:
	return not command.strip_edges().is_empty()


static func wizard_can_finish(name: String, group_id: String, command: String) -> bool:
	return group_id != "" and not name.strip_edges().is_empty() and not command.strip_edges().is_empty()


## Creates the item; returns its id or "" when the form is invalid.
static func wizard_finish(store: Object, group_id: String, name: String, command: String, icon: String, working_dir: String) -> String:
	if not wizard_can_finish(name, group_id, command):
		return ""
	return String(store.add_item(group_id, {
		"name": name.strip_edges(), "path": command.strip_edges(), "icon": icon, "workingDir": working_dir.strip_edges()}))


## Applies browse results (AppInfo) to the wizard fields: {name, workingDir, icon?}.
static func wizard_apply_app_info(info: Dictionary, current_icon: String) -> Dictionary:
	var name := String(info.get("name", ""))
	return {
		"name": name if name != "" else "New Shortcut",
		"workingDir": String(info.get("workingDir", "")),
		"icon": String(info.get("icon", current_icon)) if String(info.get("icon", "")) != "" else current_icon,
	}


# ----------------------------------------------------------- New folder / URL

## Creates a group from the typed name; returns its id or "" when blank.
static func create_folder(store: Object, name: String) -> String:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return ""
	return String(store.add_group(trimmed))


static func is_internet_url(url: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)^https?://")
	return re.search(url) != null


static func create_url_item(store: Object, group_id: String, name: String, url: String) -> String:
	if group_id == "" or name.strip_edges().is_empty() or not is_internet_url(url):
		return ""
	return String(store.add_item(group_id, {"name": name.strip_edges(), "path": url.strip_edges(), "icon": "url", "workingDir": ""}))


# ------------------------------------------------------------------ Properties

## Item sheet Apply/OK. fields: {name, command, workingDir, arguments, runMode, groupId}.
## Returns {"ok": bool, "groupId": String (the group the item now lives in)}.
static func apply_item_properties(store: Object, persisted_group_id: String, item_id: String, fields: Dictionary) -> Dictionary:
	if String(fields.name).strip_edges().is_empty() or String(fields.command).strip_edges().is_empty() or String(fields.groupId) == "":
		return {"ok": false, "groupId": persisted_group_id}
	store.update_item(persisted_group_id, item_id, {
		"name": String(fields.name).strip_edges(),
		"path": String(fields.command).strip_edges(),
		"workingDir": String(fields.workingDir).strip_edges(),
		"arguments": String(fields.arguments).strip_edges(),
		"runMode": fields.runMode,
	})
	var group_id: String = persisted_group_id
	if fields.groupId != persisted_group_id:
		store.move_item(persisted_group_id, fields.groupId, item_id)
		group_id = fields.groupId
	return {"ok": true, "groupId": group_id}


## Group sheet Apply/OK. Returns true when the name was applied.
static func apply_group_properties(store: Object, group_id: String, name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return false
	store.update_group(group_id, {"name": trimmed})
	return true


static func group_of_item(store: Object, item_id: String) -> String:
	for g in store.groups:
		for it in g.items:
			if it.id == item_id:
				return String(g.id)
	return ""
