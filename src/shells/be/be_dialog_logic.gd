class_name BeDialogLogic
extends RefCounted
## Pure data operations behind the Be dialogs and menus. Every function takes the store as a parameter
## (ProgramStore in the app, a stub in tests) and returns plain values.

const RUN_MODE_LABELS := [["normal", "Normal window"], ["minimized", "Minimized"], ["maximized", "Maximized"]]
const MAX_LAUNCH_GROUP := 8
const NOTE_KIND := "Sticky note"
const NEW_NOTE_HELP := "Type a title and choose a paper color. The text is optional: you can also type it in the note."
const NO_FOLDER_FOR_NOTE := "There are no folders yet. Make a folder first, then add notes to it."


static func plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


static func is_url(path: String) -> bool:
	return Win95DialogLogic.is_internet_url(path.strip_edges())


static func kind_of(item: Dictionary) -> String:
	if Notes.is_note(item):
		return NOTE_KIND
	return "Internet shortcut" if is_url(String(item.get("path", ""))) else "Shortcut to program"


## The List View / Find "Command" column: the command line, or for a sticky note "Sticky note: <first line>".
static func command_text(item: Dictionary) -> String:
	if Notes.is_note(item):
		var p := Notes.preview(item)
		return NOTE_KIND + (": " + p if p != "" else "")
	return String(item.get("path", ""))


## "None", "Group 3" or "Group 3: Morning" (`names` = settings.launchGroupNames).
static func batch_text(launch_group: int, names: Variant = null) -> String:
	return LaunchGroups.format_launch_group(launch_group, names)


## Get Info "Launch group" select options: None, then 1..8 with their names. A stored number above 8
## (kept by the store) stays selectable so opening Get Info does not change it.
static func launch_group_options(names: Variant = null, current: int = 0) -> Array:
	var out := [["0", "None"]]
	for n in range(1, MAX_LAUNCH_GROUP + 1):
		out.append([str(n), batch_text(n, names)])
	if current > MAX_LAUNCH_GROUP:
		out.append([str(current), batch_text(current, names)])
	return out


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


## Folder Get Info line: "None" or "2 items (Group 1: Morning, Group 3)".
static func launch_group_summary(group: Dictionary, names: Variant = null) -> String:
	var stats := group_stats(group)
	if int(stats.batched) == 0:
		return "None"
	var numbers := []
	for it in group.get("items", []):
		var n := int(it.get("launchGroup", 0))
		if n > 0 and not numbers.has(n):
			numbers.append(n)
	numbers.sort()
	var labels := []
	for n in numbers:
		labels.append(batch_text(n, names))
	return "%s (%s)" % [plural(int(stats.batched), "item", "items"), ", ".join(labels)]


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
	copy.erase("noteOpen")  # a duplicated note starts closed
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
		n = Launcher.suggested_name(p)
	var ic := icon
	if ic == "" or ic == "default":
		ic = "url" if is_url(p) else "default"
	return String(store.add_item(gid, {"name": n, "path": p, "icon": ic, "workingDir": working_dir.strip_edges()}))


# ------------------------------------------------------------------ notes

## [[id, label]] of the paper colours for a BeSelect (Notes.color_choices order).
static func note_color_options() -> Array:
	var out := []
	for c in Notes.color_choices():
		out.append([String(c.id), String(c.label)])
	return out


## The folder New Note… puts the note in: the folder of window `key` (a menu of that window), else the
## active folder window, else the first folder. "" when there are no folders.
static func note_group_for(key: String, active_key: String, groups: Array) -> String:
	for k in [key, active_key]:
		if BeWindowStore.is_group_key(String(k)):
			var gid := BeWindowStore.group_id_of(String(k))
			for g in groups:
				if String(g.id) == gid:
					return gid
	return String(groups[0].id) if not groups.is_empty() else ""


## New Note… OK: a note in folder `gid` (blank title = "Note"). Returns its id, or "" without a folder.
static func new_note(store: Object, gid: String, title: String, text: String, color: String) -> String:
	if gid == "" or store.find_group(gid).is_empty():
		return ""
	return String(store.add_item(gid, Notes.make_note(title, text, color)))


## Get Info OK/Apply for a note. fields: {name, noteColor, launchGroup, icon, groupId}. A blank title keeps
## the old one. Returns {ok, groupId}.
static func apply_note_info(store: Object, gid: String, iid: String, fields: Dictionary) -> Dictionary:
	var item: Dictionary = store.find_item(gid, iid)
	if item.is_empty() or not Notes.is_note(item):
		return {"ok": false, "groupId": gid}
	var name := String(fields.get("name", "")).strip_edges()
	var color := String(fields.get("noteColor", item.get("noteColor", Notes.DEFAULT_COLOR)))
	var icon := String(fields.get("icon", Notes.ICON))
	store.update_item(gid, iid, {
		"name": name if name != "" else String(item.get("name", "Note")),
		"noteColor": color if Notes.COLORS.has(color) else Notes.DEFAULT_COLOR,
		"launchGroup": _launch_group_value(int(fields.get("launchGroup", 0)), int(item.get("launchGroup", 0))),
		"icon": icon if icon != "" else Notes.ICON,
	})
	var target := String(fields.get("groupId", gid))
	if target != "" and target != gid and not store.find_group(target).is_empty():
		store.move_item(gid, target, iid)
		return {"ok": true, "groupId": target}
	return {"ok": true, "groupId": gid}


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
		"launchGroup": _launch_group_value(int(fields.get("launchGroup", 0)), int(store.find_item(gid, iid).get("launchGroup", 0))),
		"shortcutKey": String(fields.get("shortcutKey", "")).strip_edges(),
		"icon": icon,
	})
	var target := String(fields.get("groupId", gid))
	if target != "" and target != gid and not store.find_group(target).is_empty():
		store.move_item(gid, target, iid)
		return {"ok": true, "groupId": target}
	return {"ok": true, "groupId": gid}


## 0..8, or the stored number above 8 when the form left it unchanged.
static func _launch_group_value(value: int, stored: int) -> int:
	if value > MAX_LAUNCH_GROUP and value == stored:
		return value
	return clampi(value, 0, MAX_LAUNCH_GROUP)


## Form values for the Get Info dialog from a stored item.
static func info_fields(item: Dictionary, gid: String) -> Dictionary:
	return {
		"name": String(item.get("name", "")), "path": String(item.get("path", "")),
		"workingDir": String(item.get("workingDir", "")), "arguments": String(item.get("arguments", "")),
		"environment": String(item.get("environment", "")),
		"runMode": String(item.get("runMode", "minimized" if item.get("runMinimized", false) else "normal")),
		"launchGroup": int(item.get("launchGroup", 0)), "shortcutKey": String(item.get("shortcutKey", "")),
		"icon": String(item.get("icon", "default")), "groupId": gid,
		"isNote": Notes.is_note(item), "noteColor": String(item.get("noteColor", Notes.DEFAULT_COLOR)),
	}


# ------------------------------------------------------------------- Find

## Find window query (design: name contains, text in path, type all/app/url/note/batch, group). A sticky
## note matches `query` by its title or its text, and `text` by its text. Returns [{group, item}] in store order.
static func find(groups: Array, query: String, where: String, type: String, text: String) -> Array:
	var out := []
	var q := query.strip_edges().to_lower()
	var tx := text.strip_edges().to_lower()
	for g in groups:
		if where != "all" and where != g.id:
			continue
		for it in g.items:
			var note := Notes.is_note(it)
			var url := not note and is_url(String(it.get("path", "")))
			var body := String(it.get("note", "")).to_lower() if note else ""
			if q != "" and not (String(it.name).to_lower().contains(q) or body.contains(q)):
				continue
			if tx != "" and not (body.contains(tx) if note else String(it.get("path", "")).to_lower().contains(tx)):
				continue
			if type == "app" and (url or note):
				continue
			if type == "url" and not url:
				continue
			if type == "note" and not note:
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


## Toast text for a launch-feedback snapshot (UIState.launch_feedback); "" = hide. currentGroup is the
## launch group number being started and completedGroups its position in the run.
static func feedback_text(fb: Dictionary, names: Variant = null) -> String:
	if not bool(fb.get("visible", false)):
		return ""
	match String(fb.get("status", "")):
		"launching":
			var cur: Variant = fb.get("currentGroup")
			if cur == null:
				return "Starting programs…"
			var total := int(fb.get("totalGroups", 1))
			var label := batch_text(int(cur), names)
			if total <= 1:
				return "Launching %s…" % label
			return "Launching %s (%d of %d)…" % [label, int(fb.get("completedGroups", 0)) + 1, total]
		"complete":
			return "Launched %s." % plural(int(fb.get("totalItems", 0)), "program", "programs")
		"error":
			return "%s could not be started." % plural(int(fb.get("failures", 0)), "program", "programs")
	return ""


static func launch_error(result: Dictionary, item: Dictionary) -> String:
	return String(result.get("error", "Cannot find '%s'." % String(item.get("path", ""))))


## Entries of a folder window: "computer" lists every group, "g:<id>" lists that group's items.
## [{id, name, icon, c2, c3, is_group}]; c2/c3 are the List View columns (c3 of an item is its launch group,
## named from `names` = settings.launchGroupNames).
static func entries_for(key: String, groups: Array, names: Variant = null) -> Array:
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
				"c2": command_text(it), "c3": batch_text(lg, names) if lg > 0 else "—", "is_note": Notes.is_note(it)})
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


# ------------------------------------------------------ export / import all

## Lines of the Import All… OK / Cancel box (BeDialogs.message format).
static func import_confirm_lines() -> Array:
	var lines: Array = [{"t": DataTransfer.IMPORT_TITLE, "w": 700}]
	lines.append_array(Array(DataTransfer.IMPORT_CONFIRM.split("\n\n")))
	return lines


## How to report Platform.export_all() / import_data() (`kind` "export" or "import"):
## {show: false} when the user canceled, else {show, text, toast (a successful export), lines, icon} for an alert.
static func transfer_report(kind: String, result: Dictionary) -> Dictionary:
	var text := DataTransfer.export_status(result) if kind == "export" else DataTransfer.import_status(result)
	if text == "":
		return {"show": false}
	var ok := bool(result.get("success", false))
	var title := DataTransfer.EXPORT_TITLE if kind == "export" else DataTransfer.IMPORT_TITLE
	return {"show": true, "text": text, "toast": ok and kind == "export", "lines": [{"t": title, "w": 700}, text],
		"icon": "information" if ok else "warning"}


# ---------------------------------------------------------- launch groups
# The Launch Groups manager (Deskbar > Launch Groups…). `groups` = ProgramStore.groups,
# `names` = settings.launchGroupNames.

const LAUNCH_GROUPS_INTRO := "A launch group starts several programs one after another. Launch All starts every group in number order."
const LAUNCH_GROUPS_FULL := "All 8 launch group numbers are in use. Delete a launch group before making another."
const LAUNCH_GROUP_NAME_NEEDED := "Type a name for the new launch group."
const MEMBERS_HELP := "Check the programs and sticky notes this group opens. Each is in one launch group at a time, so checking one from another group moves it here."


## Manager list rows: [{id: "3", number, label: "Group 3: Morning", sub: "2 items"}].
static func manager_rows(groups: Array, names: Variant = null) -> Array:
	var out := []
	for d in LaunchGroups.defined_groups(groups, names):
		out.append({"id": str(d.number), "number": int(d.number), "label": String(d.label),
			"sub": "empty" if int(d.count) == 0 else plural(int(d.count), "item", "items")})
	return out


## The status line under the manager list.
static func manager_status(groups: Array, names: Variant = null) -> String:
	var n := LaunchGroups.defined_groups(groups, names).size()
	if n == 0:
		return "No launch groups yet. Click New… to make one."
	if LaunchGroups.next_free_number(groups, names) == 0:
		return "All 8 group numbers are in use."
	return "%d of 8 group numbers in use." % n


## How a group is called in sentences: “Morning” when named, else Group 3.
static func launch_group_subject(number: int, names: Variant = null) -> String:
	var n := LaunchGroups.name_of(names, number)
	return "“%s”" % n if n != "" else "Group %d" % number


## Number select options for moving group `from`:
## [["1", "1"], ["2", "2 (current)"], ["3", "3 (swap with Group 3: Evening)"], ...].
static func number_options(groups: Array, names: Variant, from: int) -> Array:
	var taken := {}
	for d in LaunchGroups.defined_groups(groups, names):
		taken[int(d.number)] = String(d.label)
	var out := []
	for n in range(1, MAX_LAUNCH_GROUP + 1):
		var label := str(n)
		if n == from:
			label += " (current)"
		elif taken.has(n):
			label += " (swap with %s)" % taken[n]
		out.append([str(n), label])
	return out


## What moving group `from` to `to` does, worded from the state BEFORE the move. "" when nothing changes.
static func renumber_text(groups: Array, names: Variant, from: int, to: int) -> String:
	if from <= 0 or to <= 0 or from == to:
		return ""
	var swap := false
	for d in LaunchGroups.defined_groups(groups, names):
		if int(d.number) == to:
			swap = true
	var a := launch_group_subject(from, names)
	if not swap:
		return "%s is now Group %d." % [a, to]
	var b := launch_group_subject(to, names)
	if b == "Group %d" % to:
		b = "the old Group %d" % to
	return "Swapped numbers: %s is now Group %d and %s is now Group %d." % [a, to, b, from]


## Delete confirmation lines (BeDialogs.message format).
static func delete_prompt(groups: Array, names: Variant, number: int) -> Array:
	var count := LaunchGroups.member_keys(groups, number).size()
	var keep := "No programs are deleted."
	if count == 1:
		keep = "Its program stays in its folder; it only leaves the launch group."
	elif count > 1:
		keep = "Its %d programs stay in their folders; they only leave the launch group." % count
	return [{"t": "Delete the launch group “%s”?" % batch_text(number, names), "w": 700}, keep]


## "" when a new group named `name` can be made, else the message to show.
static func new_group_error(groups: Array, names: Variant, name: String) -> String:
	if LaunchGroups.next_free_number(groups, names) == 0:
		return LAUNCH_GROUPS_FULL
	if LaunchGroups.clean_name(name) == "":
		return LAUNCH_GROUP_NAME_NEEDED
	return ""


## Members checklist rows for group `number`, every program and sticky note in folder order: [{id: "gid:iid",
## label: "Notepad" or "Notepad (Group 2: Evening)", sub: folder name (", sticky note" for notes), checked,
## launchGroup, icon, name}].
static func member_rows(groups: Array, names: Variant, number: int) -> Array:
	var out := []
	for g in groups:
		for it in g.get("items", []):
			var lg := int(it.get("launchGroup", 0))
			var label := String(it.get("name", ""))
			if lg > 0 and lg != number:
				label += " (%s)" % batch_text(lg, names)
			var sub := String(g.get("name", ""))
			if Notes.is_note(it):
				sub += ", sticky note"
			out.append({"id": "%s:%s" % [g.id, it.id], "label": label, "sub": sub,
				"checked": lg == number, "launchGroup": lg, "icon": String(it.get("icon", "default")),
				"name": String(it.get("name", ""))})
	return out


## The ids of the checked rows (BeChoice "checks" cells), in row order.
static func checked_keys(rows: Array) -> Array:
	var out := []
	for r in rows:
		if bool(r.get("checked", false)):
			out.append(String(r.id))
	return out


## Status after the Members dialog, worded from the state BEFORE applying `keys`:
## "Group 1: Morning now has 3 programs (1 moved from another group)."
static func members_result(groups: Array, names: Variant, number: int, keys: Array) -> String:
	var moved := 0
	for r in member_rows(groups, names, number):
		if keys.has(r.id) and int(r.launchGroup) > 0 and int(r.launchGroup) != number:
			moved += 1
	var text := "%s now has %s" % [batch_text(number, names), plural(keys.size(), "program", "programs")]
	if moved > 0:
		text += " (%d moved from another group)" % moved
	return text + "."
