class_name MacDialogLogic
extends RefCounted
## Pure helpers behind the Mac dialogs (unit-tested with a fake store): folder / item creation, rename,
## Get Info apply, duplicate/alias, Move To Trash, Clean Up, Find filtering, Run resolution. `store` is a
## ProgramStore-like object (groups, add_group, update_group, delete_group, add_item, update_item,
## move_item, delete_item, replace_groups).

const RUN_MODES := ["normal", "minimized", "maximized"]
const RUN_MODE_LABELS := ["Normal window", "Minimized", "Maximized"]
const LAUNCH_GROUP_MAX := 8
const DEFAULT_FOLDER_NAME := "untitled folder"
## Change Icon options (design ICONIDS reduced to distinct Mac icons): catalog id -> Mac icon.
const ICON_CHOICES := ["default", "readme", "terminal", "network", "setup", "accessories"]

const HELP_TOPICS := [
	["Starting programs", "Double-click an icon in a folder window to start it. Select an icon and choose Open from the File menu, or press Return."],
	["Creating folders and items", "Choose New Folder from the File menu to create a folder. Use New Program in a folder window's context menu, or drag files into a folder window."],
	["Batch launching", "Give items a launch group number from 1 to 8 in Get Info. Then use Launch Group or Launch All in the Special menu to start them with the delay you set."],
	["Importing .GRP files", "Open Launcher Tools and choose Import .GRP to bring in an original Windows 3.x program group. Export .GRP writes one back out."],
	["Switching shells", "Press Ctrl+Alt+T to open Launcher Tools, pick a shell under Appearance, and click Apply."],
	["Backups and profiles", "Settings are saved automatically. The newest 12 automatic restore points are kept, and you can create manual restore points and named workspace profiles in Launcher Tools."],
]


static func plural(n: int, singular: String, plural_form: String = "") -> String:
	return "%d %s" % [n, singular if n == 1 else (plural_form if plural_form != "" else singular + "s")]


static func create_folder(store: Object, name: String) -> String:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return ""
	return String(store.add_group(trimmed))


static func rename(store: Object, group_id: String, item_id: String, name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return false
	if item_id != "":
		store.update_item(group_id, item_id, {"name": trimmed})
	else:
		store.update_group(group_id, {"name": trimmed})
	return true


static func group_of_item(store: Object, item_id: String) -> String:
	for g in store.groups:
		for it in g.items:
			if it.id == item_id:
				return String(g.id)
	return ""


static func is_internet_url(path: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)^https?://")
	return re.search(path) != null


static func kind_of(item: Dictionary) -> String:
	return "Internet shortcut" if is_internet_url(String(item.get("path", ""))) else "Application program"


## Parses the launch-group field: "" / "0" / "None" -> 0; "1".."8" -> n; anything else -> -1 (invalid).
static func parse_launch_group(text: String) -> int:
	var t := text.strip_edges()
	if t == "" or t.to_lower() == "none":
		return 0
	if not t.is_valid_int():
		return -1
	var n := t.to_int()
	return n if n >= 0 and n <= LAUNCH_GROUP_MAX else -1


## Get Info OK. fields: {name, path, workingDir, arguments, environment, runMode, launchGroup (String), shortcutKey,
## icon, groupId}. Returns {ok, error, groupId}.
static func apply_item_info(store: Object, persisted_group_id: String, item_id: String, fields: Dictionary) -> Dictionary:
	var name := String(fields.get("name", "")).strip_edges()
	var path := String(fields.get("path", "")).strip_edges()
	if name.is_empty() or path.is_empty():
		return {"ok": false, "error": "Enter a name and a target for this item.", "groupId": persisted_group_id}
	var lg := parse_launch_group(String(fields.get("launchGroup", "")))
	if lg < 0:
		return {"ok": false, "error": "Launch group must be a number from 1 to %d, or None." % LAUNCH_GROUP_MAX, "groupId": persisted_group_id}
	var run_mode := String(fields.get("runMode", "normal"))
	if not RUN_MODES.has(run_mode):
		run_mode = "normal"
	var updates := {
		"name": name, "path": path,
		"workingDir": String(fields.get("workingDir", "")).strip_edges(),
		"arguments": String(fields.get("arguments", "")).strip_edges(),
		"environment": String(fields.get("environment", "")),
		"runMode": run_mode, "launchGroup": lg,
		"shortcutKey": String(fields.get("shortcutKey", "")).strip_edges(),
	}
	if String(fields.get("icon", "")) != "":
		updates["icon"] = String(fields.icon)
	store.update_item(persisted_group_id, item_id, updates)
	var gid := persisted_group_id
	var target := String(fields.get("groupId", persisted_group_id))
	if target != "" and target != persisted_group_id:
		store.move_item(persisted_group_id, target, item_id)
		gid = target
	return {"ok": true, "error": "", "groupId": gid}


## Duplicate / Make Alias: appends "<name> <suffix>" to the same group. Returns the new item id or "".
static func duplicate_item(store: Object, group_id: String, item_id: String, suffix: String) -> String:
	var src: Dictionary = {}
	for g in store.groups:
		if g.id == group_id:
			for it in g.items:
				if it.id == item_id:
					src = it
	if src.is_empty():
		return ""
	var copy: Dictionary = src.duplicate(true)
	copy.erase("id")
	copy.erase("win31Position")
	copy.erase("win95Position")
	copy["name"] = "%s %s" % [src.name, suffix]
	return String(store.add_item(group_id, copy))


static func trash_item(store: Object, group_id: String, item_id: String) -> void:
	store.delete_item(group_id, item_id)


static func trash_folder(store: Object, group_id: String) -> void:
	store.delete_group(group_id)


static func add_program(store: Object, group_id: String, name: String, path: String) -> String:
	var p := path.strip_edges()
	if group_id == "" or p.is_empty():
		return ""
	var n := name.strip_edges()
	if n.is_empty():
		n = Launcher.suggested_name(p)
	return String(store.add_item(group_id, {"name": n, "path": p, "icon": "network" if is_internet_url(p) else "default", "workingDir": ""}))


## Clean Up: alphabetical order for a folder's items (group_id) or for the folders themselves ("").
static func clean_up(store: Object, group_id: String) -> void:
	if group_id == "":
		var sorted: Array = store.groups.duplicate()
		sorted.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
		store.replace_groups(sorted)
		return
	for g in store.groups:
		if g.id == group_id:
			var items: Array = g.items.duplicate()
			items.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
			store.update_group(group_id, {"items": items})


## Find window filter. kind: "all" | "app" | "url" | "batch"; where: "all" or a group id. Returns
## [{group, item}] ranked like Quick Search.
static func find_items(groups: Array, query: String, where: String, kind: String) -> Array:
	var type := "all"
	if kind == "app":
		type = "application"
	elif kind == "url":
		type = "internet"
	var found := ProgramSearch.find_programs(groups, {"named": query, "groupId": "" if where == "all" else where, "type": type})
	var out := []
	for r in found:
		if kind == "batch" and int(r.item.get("launchGroup", 0)) <= 0:
			continue
		out.append(r)
	return out


## Item to launch for Run: an existing item whose name matches, otherwise an ad-hoc command item. {} when blank.
static func run_item(groups: Array, text: String) -> Dictionary:
	var value := text.strip_edges()
	if value.is_empty():
		return {}
	for g in groups:
		for it in g.items:
			if String(it.name).to_lower() == value.to_lower():
				return it
	return {"id": "mac-run", "name": value, "path": value, "icon": "terminal", "workingDir": ""}


## The payload handed to the launcher (workingDir is mandatory there).
static func launch_payload(item: Dictionary) -> Dictionary:
	var p: Dictionary = item.duplicate(true)
	if not p.has("workingDir"):
		p["workingDir"] = ""
	return p


static func window_title(key: String, groups: Array) -> String:
	if key == "computer":
		return "Launcher HD"
	if key == "find":
		return "Find"
	for g in groups:
		if "g:" + String(g.id) == key:
			return String(g.name)
	return ""


static func info_line(entry_count: int, program_count: int, is_computer: bool) -> String:
	var s := plural(entry_count, "item")
	if is_computer:
		s += ", %d programs" % program_count
	return s
