class_name BeDialogLogic
extends RefCounted
## Pure data operations behind the Be dialogs and menus. Every function takes the store as a parameter
## (ProgramStore in the app, a stub in tests) and returns plain values.

const RUN_MODE_LABELS := [["normal", "Normal window"], ["minimized", "Minimized"], ["maximized", "Maximized"]]
const MAX_LAUNCH_GROUP := 8


static func plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


static func is_url(path: String) -> bool:
	return Win95DialogLogic.is_internet_url(path.strip_edges())


static func kind_of(item: Dictionary) -> String:
	return "Internet shortcut" if is_url(String(item.get("path", ""))) else "Shortcut to program"


static func batch_text(launch_group: int) -> String:
	return LaunchGroups.format_launch_group(launch_group)


## Status bar text of a window: "<n> item(s)".
static func status_count(n: int) -> String:
	return plural(n, "item", "items")


static func basename_of(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	while p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p.get_file()


# ----------------------------------------------------------------- groups

static func create_folder(store: Object, name: String) -> String:
	return Win95DialogLogic.create_folder(store, name)


static func rename_group(store: Object, gid: String, name: String) -> bool:
	return Win95DialogLogic.apply_group_properties(store, gid, name)


static func rename_item(store: Object, gid: String, iid: String, name: String) -> bool:
	var n := name.strip_edges()
	if n.is_empty() or store.find_item(gid, iid).is_empty():
		return false
	store.update_item(gid, iid, {"name": n})
	return true


static func group_stats(group: Dictionary) -> Dictionary:
	var items: Array = group.get("items", [])
	var batched := 0
	for it in items:
		if int(it.get("launchGroup", 0)) > 0:
			batched += 1
	return {"items": items.size(), "batched": batched}


static func trash_group(store: Object, gid: String) -> void:
	store.delete_group(gid)


static func sort_groups(store: Object) -> void:
	var sorted: Array = store.groups.duplicate(true)
	sorted.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	store.replace_groups(sorted)


# ------------------------------------------------------------------ items

static func trash_item(store: Object, gid: String, iid: String) -> void:
	store.delete_item(gid, iid)


## Duplicate (name + " copy", no stored positions). Returns the new id or "".
static func duplicate_item(store: Object, gid: String, iid: String) -> String:
	var src: Dictionary = store.find_item(gid, iid)
	if src.is_empty():
		return ""
	var copy: Dictionary = src.duplicate(true)
	copy.erase("id")
	copy.erase("win31Position")
	copy.erase("win95Position")
	copy["name"] = String(src.name) + " copy"
	return String(store.add_item(gid, copy))


static func sort_items(store: Object, gid: String) -> void:
	var g: Dictionary = store.find_group(gid)
	if g.is_empty():
		return
	var sorted: Array = g.items.duplicate(true)
	sorted.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	store.update_group(gid, {"items": sorted})


## Add Program… : icon "url" for web addresses. Returns the id or "" when the command is blank.
static func new_program(store: Object, gid: String, name: String, path: String, working_dir: String = "", icon: String = "") -> String:
	var p := path.strip_edges()
	if gid == "" or p.is_empty() or store.find_group(gid).is_empty():
		return ""
	var n := name.strip_edges()
	if n.is_empty():
		n = basename_of(p)
	var ic := icon
	if ic == "" or ic == "default":
		ic = "url" if is_url(p) else "default"
	return String(store.add_item(gid, {"name": n, "path": p, "icon": ic, "workingDir": working_dir.strip_edges()}))


## Get Info OK/Apply. fields: {name, path, workingDir, arguments, environment, runMode, launchGroup, shortcutKey, icon, groupId}.
## Both name and path blank = nothing to save (ok false). Returns {ok, groupId}.
static func apply_item_info(store: Object, gid: String, iid: String, fields: Dictionary) -> Dictionary:
	var path := String(fields.get("path", "")).strip_edges()
	var name := String(fields.get("name", "")).strip_edges()
	if name.is_empty() and path.is_empty():
		return {"ok": false, "groupId": gid}
	if name.is_empty():
		name = basename_of(path)
	var icon := String(fields.get("icon", "default"))
	if is_url(path) and (icon == "default" or icon == ""):
		icon = "url"
	var mode := String(fields.get("runMode", "normal"))
	store.update_item(gid, iid, {
		"name": name, "path": path,
		"workingDir": String(fields.get("workingDir", "")).strip_edges(),
		"arguments": String(fields.get("arguments", "")).strip_edges(),
		"environment": String(fields.get("environment", "")).strip_edges(),
		"runMode": mode if Types.RUN_MODES.has(mode) else "normal",
		"launchGroup": clampi(int(fields.get("launchGroup", 0)), 0, MAX_LAUNCH_GROUP),
		"shortcutKey": String(fields.get("shortcutKey", "")).strip_edges(),
		"icon": icon,
	})
	var target := String(fields.get("groupId", gid))
	if target != "" and target != gid and not store.find_group(target).is_empty():
		store.move_item(gid, target, iid)
		return {"ok": true, "groupId": target}
	return {"ok": true, "groupId": gid}


## Form values for the Get Info dialog from a stored item.
static func info_fields(item: Dictionary, gid: String) -> Dictionary:
	return {
		"name": String(item.get("name", "")), "path": String(item.get("path", "")),
		"workingDir": String(item.get("workingDir", "")), "arguments": String(item.get("arguments", "")),
		"environment": String(item.get("environment", "")),
		"runMode": String(item.get("runMode", "minimized" if item.get("runMinimized", false) else "normal")),
		"launchGroup": int(item.get("launchGroup", 0)), "shortcutKey": String(item.get("shortcutKey", "")),
		"icon": String(item.get("icon", "default")), "groupId": gid,
	}


# ------------------------------------------------------------------- Find

## Find window query (design: name contains, text in path, type all/app/url/batch, group).
## Returns [{group, item}] in store order.
static func find(groups: Array, query: String, where: String, type: String, text: String) -> Array:
	var out := []
	var q := query.strip_edges().to_lower()
	var tx := text.strip_edges().to_lower()
	for g in groups:
		if where != "all" and where != g.id:
			continue
		for it in g.items:
			var url := is_url(String(it.path))
			if q != "" and not String(it.name).to_lower().contains(q):
				continue
			if tx != "" and not String(it.path).to_lower().contains(tx):
				continue
			if type == "app" and url:
				continue
			if type == "url" and not url:
				continue
			if type == "batch" and int(it.get("launchGroup", 0)) <= 0:
				continue
			out.append({"group": g, "item": it})
	return out


static func find_title(query: String) -> String:
	var q := query.strip_edges()
	return "Find: Programs named " + q if q != "" else "Find: All Programs"


# ------------------------------------------------------------------- misc

## "h:mm AM" (the design's fmtTime).
static func format_clock(time: Dictionary) -> String:
	var h := int(time.get("hour", 0))
	var ap := "PM" if h >= 12 else "AM"
	h = h % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, int(time.get("minute", 0)), ap]


## Item typed in Run…: a stored program with that name (case-insensitive), else the raw command.
static func run_target(groups: Array, text: String) -> Dictionary:
	var q := text.strip_edges()
	if q.is_empty():
		return {}
	for g in groups:
		for it in g.items:
			if String(it.name).to_lower() == q.to_lower():
				return it
	return Win95DialogLogic.run_item(q)


## Toast text for a launch-feedback snapshot (UIState.launch_feedback); "" = hide.
static func feedback_text(fb: Dictionary) -> String:
	if not bool(fb.get("visible", false)):
		return ""
	match String(fb.get("status", "")):
		"launching":
			var cur: Variant = fb.get("currentGroup")
			if cur == null:
				return "Starting programs…"
			return "Launching group %d of %d…" % [int(cur) + 1, int(fb.get("totalGroups", 1))]
		"complete":
			return "Launched %s." % plural(int(fb.get("totalItems", 0)), "program", "programs")
		"error":
			return "%s could not be started." % plural(int(fb.get("failures", 0)), "program", "programs")
	return ""


static func launch_error(result: Dictionary, item: Dictionary) -> String:
	return String(result.get("error", "Cannot find '%s'." % String(item.get("path", ""))))


## Entries of a folder window: "computer" lists every group, "g:<id>" lists that group's items.
## [{id, name, icon, c2, c3, is_group}]; c2/c3 are the List View columns.
static func entries_for(key: String, groups: Array) -> Array:
	var out := []
	if key == BeWindowStore.COMPUTER:
		for g in groups:
			out.append({"id": String(g.id), "name": String(g.name), "icon": "folder", "is_group": true,
				"c2": status_count(g.items.size()), "c3": "Program group"})
		return out
	var gid := BeWindowStore.group_id_of(key)
	for g in groups:
		if g.id != gid:
			continue
		for it in g.items:
			var lg := int(it.get("launchGroup", 0))
			out.append({"id": String(it.id), "name": String(it.name), "icon": String(it.get("icon", "default")), "is_group": false,
				"c2": String(it.path), "c3": ("Group %d" % lg) if lg > 0 else "—"})
	return out


## Folder-window title ("Program Manager" for the root window).
static func window_title(key: String, groups: Array, find_query: String = "") -> String:
	if key == BeWindowStore.COMPUTER:
		return "Program Manager"
	if key == BeWindowStore.FIND:
		return find_title(find_query)
	var gid := BeWindowStore.group_id_of(key)
	for g in groups:
		if g.id == gid:
			return String(g.name)
	return ""
