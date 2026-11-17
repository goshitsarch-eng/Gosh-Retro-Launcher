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
	["Batch launching", "Give items a launch group number from 1 to 8 in Get Info, or choose Launch Groups in the Special menu to create, name, renumber and fill groups. Then use Launch Group or Launch All in the Special menu to start them with the delay you set."],
	["Moving your setup", "Choose Export All in the File menu to save every folder, program, launch group and setting to one file. Import All replaces everything with the contents of such a file; your current setup is backed up first."],
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
	var stored := int(_find(store, persisted_group_id, item_id).get("launchGroup", 0))
	if lg < 0 and stored > LAUNCH_GROUP_MAX and String(fields.get("launchGroup", "")).strip_edges() == str(stored):
		lg = stored   # an imported number above 8 is kept unless the user picks another
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


static func _find(store: Object, group_id: String, item_id: String) -> Dictionary:
	for g in store.groups:
		if g.id == group_id:
			for it in g.items:
				if it.id == item_id:
					return it
	return {}


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
## [{group, item}] ranked like Quick Search. For "batch" an item also matches when its launch group's label
## ("Group 3: Morning", names = settings.launchGroupNames) contains the query; those follow the name matches.
static func find_items(groups: Array, query: String, where: String, kind: String, names: Variant = {}) -> Array:
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
	var q := query.strip_edges().to_lower()
	if kind == "batch" and q != "" and not q.contains("*") and not q.contains("?"):
		var seen := {}
		for r in out:
			seen[String(r.item.id)] = true
		for g in groups:
			if where != "all" and String(g.id) != where:
				continue
			for it in g.items:
				var n := int(it.get("launchGroup", 0))
				if n > 0 and not seen.has(String(it.id)) and LaunchGroups.format_launch_group(n, names).to_lower().contains(q):
					out.append({"group": g, "item": it})
					seen[String(it.id)] = true
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


# --------------------------------------------------------------- launch groups
# A launch group is a number (item.launchGroup) plus an optional name (settings.launchGroupNames). LaunchGroups
# and ProgramStore do the work; these shape it for the Mac dialogs. `store` is a ProgramStore.

const ALL_NUMBERS_IN_USE := "All 8 launch group numbers are in use. Delete a group, or add programs to one of the existing groups instead."


## Get Info "Launch group" pop-up: None, then Group 1..8 with their names. A stored number above 8 (kept from an
## import) is offered too, so OK does not silently drop it.
static func launch_group_options(names: Variant, current: int = 0) -> Array:
	var out := [{"id": "0", "label": "None"}]
	for n in range(1, LaunchGroups.MAX_GROUP + 1):
		out.append({"id": str(n), "label": LaunchGroups.format_launch_group(n, names)})
	if current > LaunchGroups.MAX_GROUP:
		out.append({"id": str(current), "label": LaunchGroups.format_launch_group(current, names)})
	return out


## Folder list view "Batch" column: the launch group label, or a dash when the item is in none.
static func launch_group_cell(number: int, names: Variant) -> String:
	return LaunchGroups.format_launch_group(number, names) if number > 0 else "—"


## Rows of the Launch Groups list: {id: "3", label: "Group 3: Morning", sub: "2 items" | "empty", count}.
static func launch_group_rows(groups: Array, names: Variant) -> Array:
	var out := []
	for d in LaunchGroups.defined_groups(groups, names):
		out.append({"id": str(d.number), "label": String(d.label), "count": int(d.count),
			"sub": "empty" if int(d.count) == 0 else plural(int(d.count), "item")})
	return out


## Rows of the Members checklist for group `number`: every program, labelled with its folder (sub); one that is in
## another launch group says which ("Mail (Group 2: Evening)"). {id: "groupId:itemId", label, sub, checked, auto}.
static func member_rows(groups: Array, number: int, names: Variant) -> Array:
	var out := []
	for e in LaunchGroups.all_items(groups):
		var lg := int(e.launchGroup)
		var label := String(e.name)
		if lg > 0 and lg != number:
			label += " (%s)" % LaunchGroups.format_launch_group(lg, names)
		out.append({"id": String(e.key), "label": label, "sub": String(e.groupName), "checked": lg == number, "auto": String(e.name)})
	return out


## The keys of the checked rows (what set_launch_group_members takes).
static func checked_keys(rows: Array) -> Array:
	var out := []
	for r in rows:
		if r.get("checked", false):
			out.append(String(r.id))
	return out


## Members checklist summary: "2 of 14 programs checked".
static func members_summary(rows: Array) -> String:
	return "%d of %s checked" % [checked_keys(rows).size(), plural(rows.size(), "program")]


## Status line after the Members checklist's OK: a group left with no programs and no name no longer exists.
static func members_status(number: int, count: int, has_name: bool) -> String:
	if count == 0 and not has_name:
		return "Group %d has no programs and no name, so it was removed." % number
	return "Group %d now starts %s." % [number, plural(count, "program")]


## Export All / Import All outcome for an alert: {text, icon} ("" text when the user canceled the file picker).
## kind: "export" | "import"; result: Platform.export_all() / Platform.import_data().
static func transfer_message(kind: String, result: Dictionary) -> Dictionary:
	var text := DataTransfer.export_status(result) if kind == "export" else DataTransfer.import_status(result)
	return {"text": text, "icon": "note" if result.get("success", false) else "stop"}


## Number pop-up for group `current`: Group 1..8; a number another group uses says it will swap.
static func number_options(groups: Array, names: Variant, current: int) -> Array:
	var taken := {}
	for d in LaunchGroups.defined_groups(groups, names):
		taken[int(d.number)] = true
	var out := []
	for n in range(1, LaunchGroups.MAX_GROUP + 1):
		var label := LaunchGroups.format_launch_group(n, names)
		if taken.has(n) and n != current:
			label += " (swap)"
		out.append({"id": str(n), "label": label})
	if current > LaunchGroups.MAX_GROUP:
		out.append({"id": str(current), "label": LaunchGroups.format_launch_group(current, names)})
	return out


## New…: {number, error}. Refuses when all eight numbers are taken or the name is blank.
static func new_launch_group(store: Object, name: String) -> Dictionary:
	if LaunchGroups.next_free_number(store.groups, store.launch_group_names()) == 0:
		return {"number": 0, "error": ALL_NUMBERS_IN_USE}
	if LaunchGroups.clean_name(name) == "":
		return {"number": 0, "error": "Type a name for the new launch group."}
	var n: int = store.create_launch_group(name)
	if n == 0:
		return {"number": 0, "error": ALL_NUMBERS_IN_USE}
	return {"number": n, "error": ""}


## Text of the New… prompt: which number the group will get, or why there is none.
static func new_group_prompt(groups: Array, names: Variant) -> String:
	var n := LaunchGroups.next_free_number(groups, names)
	if n == 0:
		return ALL_NUMBERS_IN_USE
	return "The new launch group will be Group %d. Name it, then check the programs it starts." % n


## Rename…: stores the name (blank clears it) and returns the status line.
static func rename_launch_group(store: Object, number: int, name: String) -> String:
	var had_members := not LaunchGroups.member_keys(store.groups, number).is_empty()
	store.set_launch_group_name(number, name)
	var cleaned := LaunchGroups.clean_name(name)
	if cleaned != "":
		return "Group %d is now called “%s”." % [number, cleaned]
	if not had_members:
		return "Group %d had no name and no programs, so it was removed." % number
	return "Group %d no longer has a name." % number


## Explanation under the Rename… field.
static func rename_hint(count: int) -> String:
	if count == 0:
		return "Leave it blank to remove the name. This group has no programs, so without a name it is removed."
	return "Leave it blank to remove the name."


## Number: moves group `from` to `to` (swapping with a group already there). {ok, swapped, status}.
static func renumber_launch_group(store: Object, from: int, to: int) -> Dictionary:
	var names: Dictionary = store.launch_group_names().duplicate()
	var label_from := LaunchGroups.format_launch_group(from, names)
	var label_to := LaunchGroups.format_launch_group(to, names)
	var swapped := false
	for d in LaunchGroups.defined_groups(store.groups, names):
		if int(d.number) == to:
			swapped = true
	if not store.renumber_launch_group(from, to):
		return {"ok": false, "swapped": false, "status": ""}
	if swapped:
		return {"ok": true, "swapped": true,
			"status": "%s and %s swapped numbers, so Launch All now starts them in the new order." % [label_from, label_to]}
	return {"ok": true, "swapped": false, "status": "%s is now Group %d." % [label_from, to]}


## Delete… confirmation: makes clear the programs stay.
static func delete_prompt(groups: Array, names: Variant, number: int) -> String:
	var count := LaunchGroups.member_keys(groups, number).size()
	var label := LaunchGroups.format_launch_group(number, names)
	if count == 0:
		return "Delete %s? It has no programs." % label
	return "Delete %s? Its %s stay in their folders; they just stop launching together." % [label, plural(count, "program")]


## Toast text for UIState.launch_feedback ("" when there is nothing to show).
static func launch_feedback_text(fb: Dictionary, names: Variant) -> String:
	if not fb.get("visible", false):
		return ""
	match String(fb.get("status", "")):
		"launching":
			var total := int(fb.get("totalGroups", 1))
			var index := int(fb.get("completedGroups", 0)) + 1
			var current: Variant = fb.get("currentGroup")
			if current != null and int(current) > 0:
				var label := LaunchGroups.format_launch_group(int(current), names)
				return "Launching %s…" % label if total <= 1 else "Launching %s (%d of %d)…" % [label, index, total]
			return "Launching group %d of %d…" % [index, total]
		"complete":
			return "Launched %s." % plural(int(fb.get("totalItems", 0)), "item")
		"error":
			return "%s failed to launch." % plural(int(fb.get("failures", 0)), "item")
	return ""


## About box statistics: "5 folders, 23 programs" plus ", 2 launch groups" when there are any.
static func stats_line(groups: Array, names: Variant) -> String:
	var n := 0
	for g in groups:
		n += g.items.size()
	var s := "%d folders, %d programs" % [groups.size(), n]
	var lg := LaunchGroups.defined_groups(groups, names).size()
	if lg > 0:
		s += ", " + plural(lg, "launch group")
	return s


static func info_line(entry_count: int, program_count: int, is_computer: bool) -> String:
	var s := plural(entry_count, "item")
	if is_computer:
		s += ", %d programs" % program_count
	return s
