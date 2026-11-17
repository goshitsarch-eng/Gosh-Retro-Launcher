class_name Win95LaunchGroupLogic
extends RefCounted
## Pure rules behind the Win95 launch-group UI: the Start > Programs > Launch Groups cascade, the
## "Launch group:" drop-downs, the Launch Groups manager, its Members checklist and Number picker, and
## the wording of the batch-launch failure box. No autoloads: callers pass ProgramStore.groups and
## ProgramStore.launch_group_names() in, so every function is unit-testable.

## Id of the extra "Launch Groups" folder row at the end of Start > Programs.
const PROGRAMS_ROW_ID := "__launch-groups__"
const PROGRAMS_ROW_NAME := "Launch Groups"
const MANAGER_TITLE := "Launch Groups"
const MAX_FAILURE_LINES := 6


## `&` is the access-key marker in Win95 labels, so data shown in a label is escaped.
static func escape(text: String) -> String:
	return text.replace("&", "&&")


static func _escaped_names(names: Variant) -> Dictionary:
	var out := {}
	if names is Dictionary:
		for k in names:
			out[k] = escape(LaunchGroups.name_of(names, String(k).to_int()))
	return out


static func plural_programs(n: int) -> String:
	return "%d program%s" % [n, "" if n == 1 else "s"]


# ------------------------------------------------------------- Start menu

## The Programs-cascade folder row that opens the Launch Groups cascade.
static func programs_row() -> Dictionary:
	return {"id": PROGRAMS_ROW_ID, "name": PROGRAMS_ROW_NAME, "icon": "programs"}


## Rows of Start > Programs > Launch Groups (Win95StartMenu level 2):
## Launch All, one "Launch Group N: Name (k items)" row per group with members (access key = its
## digit), then a separator and Manage Launch Groups... Each row: {id, label, icon, disabled?,
## separatorBefore?, number?}; ids are "launch-all", "launch:<n>" and "manage".
static func menu_rows(groups: Array, names: Variant = null) -> Array:
	var buckets := LaunchGroups.collect_launch_groups(groups)
	var esc := _escaped_names(names)
	var rows := [{"id": "launch-all", "label": "Launch &All", "icon": "run", "disabled": buckets.is_empty()}]
	for b in buckets:
		var n := int(b.groupNumber)
		var label := LaunchGroups.launch_label(n, b.items.size(), esc)
		label = "Launch Group &" + label.substr("Launch Group ".length())  # the digit is the access key
		rows.append({"id": "launch:%d" % n, "label": label, "icon": "application", "number": n})
	rows.append({"id": "manage", "label": "&Manage Launch Groups...", "icon": "properties", "separatorBefore": rows.size() > 0})
	return rows


## The buckets a menu row id launches ([] for "manage" or an empty group).
static func buckets_for(groups: Array, row_id: String) -> Array:
	var buckets := LaunchGroups.collect_launch_groups(groups)
	if row_id == "launch-all":
		return buckets
	if row_id.begins_with("launch:"):
		var n := row_id.get_slice(":", 1).to_int()
		return buckets.filter(func(b): return int(b.groupNumber) == n)
	return []


## Title of the launch-failure box for a set of buckets.
static func launch_title(buckets: Array, names: Variant = null) -> String:
	if buckets.size() == 1:
		return "Launch %s" % LaunchGroups.format_launch_group(int(buckets[0].groupNumber), names)
	return "Launch All"


## Text of the warning box after a batch launch, or "" when every program started.
## `results` are LaunchGroups.launch_group_buckets results ({id, success, error?}); the program
## names come from the buckets' items.
static func failure_message(results: Array, buckets: Array) -> String:
	var names_by_id := {}
	for b in buckets:
		for it in b.items:
			names_by_id[String(it.id)] = String(it.get("name", ""))
	var failures := results.filter(func(r): return not r.get("success", false))
	if failures.is_empty():
		return ""
	var lines := []
	for i in mini(failures.size(), MAX_FAILURE_LINES):
		var f: Dictionary = failures[i]
		var who := String(names_by_id.get(String(f.get("id", "")), ""))
		var why := String(f.get("error", "The program could not be started."))
		lines.append(("%s: %s" % [who, why]) if who != "" else why)
	if failures.size() > MAX_FAILURE_LINES:
		lines.append("...and %d more." % (failures.size() - MAX_FAILURE_LINES))
	var head := "%d of %s could not be started:" % [failures.size(), plural_programs(results.size())] \
		if results.size() > 1 else "The program could not be started:"
	return head + "\n\n" + "\n".join(lines)


# ---------------------------------------------------------- drop-downs

## Choices of a "Launch group:" drop-down: [{value, label}] for None and Group 1..MAX_GROUP (named
## groups show their name). A stored number above MAX_GROUP is kept as an extra last choice so
## opening and OK-ing the sheet does not change it.
static func choices(names: Variant = null, current: int = 0) -> Array:
	var out := [{"value": 0, "label": "None"}]
	for n in range(1, LaunchGroups.MAX_GROUP + 1):
		out.append({"value": n, "label": LaunchGroups.format_launch_group(n, names)})
	if current > LaunchGroups.MAX_GROUP:
		out.append({"value": current, "label": LaunchGroups.format_launch_group(current, names)})
	return out


static func choice_labels(list: Array) -> Array:
	return list.map(func(c): return String(c.label))


static func choice_index(list: Array, value: int) -> int:
	for i in list.size():
		if int(list[i].value) == value:
			return i
	return 0


static func choice_value(list: Array, index: int) -> int:
	return int(list[index].value) if index >= 0 and index < list.size() else 0


# ------------------------------------------------------------- manager

## Rows of the manager's list: defined_groups plus the three column texts.
static func manager_rows(groups: Array, names: Variant = null) -> Array:
	var out := []
	for d in LaunchGroups.defined_groups(groups, names):
		var row: Dictionary = d.duplicate()
		row["cells"] = ["Group %d" % int(d.number), String(d.name) if String(d.name) != "" else "(no name)", str(int(d.count))]
		out.append(row)
	return out


## Index of group `number` in `rows`, else the nearest valid index (-1 when empty).
static func row_index(rows: Array, number: int, fallback: int = 0) -> int:
	for i in rows.size():
		if int(rows[i].number) == number:
			return i
	if rows.is_empty():
		return -1
	return clampi(fallback, 0, rows.size() - 1)


## Enabled state of the manager's buttons for the selected row ({} = nothing selected). New stays
## enabled when all numbers are taken so that it can say why it cannot create one.
static func manager_buttons(row: Dictionary, _groups: Array = [], _names: Variant = null) -> Dictionary:
	var has := not row.is_empty()
	return {"new": true, "rename": has, "number": has,
		"delete": has, "members": has, "launch": has and int(row.get("count", 0)) > 0}


static func all_numbers_used_message() -> String:
	return "All %d launch group numbers are in use.\n\nDelete a launch group, or change the members of an existing one, before you create another." % LaunchGroups.MAX_GROUP


static func delete_prompt(number: int, count: int, names: Variant = null) -> String:
	var label := LaunchGroups.format_launch_group(number, names)
	if count == 0:
		return "Are you sure you want to delete %s?" % label
	return "Are you sure you want to delete %s?\n\nIts %s will not be deleted; they just leave the launch group." % [label, plural_programs(count)]


## Status line after creating a group.
static func created_status(number: int, names: Variant = null) -> String:
	return "Created %s." % LaunchGroups.format_launch_group(number, names)


## Status line after a rename (names = the names after the change).
static func renamed_status(number: int, names: Variant = null) -> String:
	if LaunchGroups.name_of(names, number) == "":
		return "Group %d no longer has a name." % number
	return "Renamed to %s." % LaunchGroups.format_launch_group(number, names)


# ------------------------------------------------------------ Number

## Choices of the Number picker for group `from`: [{value, label}] for 1..MAX_GROUP.
static func number_choices(groups: Array, names: Variant, from: int) -> Array:
	var used := {}
	for d in LaunchGroups.defined_groups(groups, names):
		used[int(d.number)] = true
	var out := []
	for n in range(1, LaunchGroups.MAX_GROUP + 1):
		var label := str(n)
		if n == from:
			label += " (current)"
		elif used.has(n):
			label += " (swap with %s)" % LaunchGroups.format_launch_group(n, names)
		out.append({"value": n, "label": label})
	return out


## Note under the Number picker: "" when `to` is free or unchanged, else the swap warning.
static func number_note(groups: Array, names: Variant, from: int, to: int) -> String:
	if to == from or to <= 0:
		return ""
	for d in LaunchGroups.defined_groups(groups, names):
		if int(d.number) == to:
			return "%s already uses number %d. The two groups will swap numbers." % [LaunchGroups.format_launch_group(to, names), to]
	return ""


## Status line after renumber_launch_group(from, to). `swapped` = `to` was in use before.
## names = the names before the change.
static func renumbered_status(from: int, to: int, swapped: bool, names: Variant = null) -> String:
	var moved := LaunchGroups.format_launch_group(from, names)
	if swapped:
		return "%s is now number %d; %s is now number %d." % [moved, to, LaunchGroups.format_launch_group(to, names), from]
	return "%s is now number %d." % [moved, to]


static func is_number_used(groups: Array, names: Variant, number: int) -> bool:
	for d in LaunchGroups.defined_groups(groups, names):
		if int(d.number) == number:
			return true
	return false


# ------------------------------------------------------------ Members

## Rows of the Members checklist for group `number` (0 = a group not created yet):
## all_items plus checked and cells [name, program group, "Group 2" when in another launch group].
static func member_rows(groups: Array, number: int) -> Array:
	var out := []
	for e in LaunchGroups.all_items(groups):
		var row: Dictionary = e.duplicate()
		var lg := int(e.launchGroup)
		row["checked"] = number > 0 and lg == number
		row["cells"] = [String(e.name), String(e.groupName), ("Group %d" % lg) if lg > 0 and lg != number else ""]
		out.append(row)
	return out


static func checked_keys(rows: Array) -> Array:
	var out := []
	for r in rows:
		if r.get("checked", false):
			out.append(String(r.key))
	return out


## The summary under the checklist: "3 programs selected; 1 will move from another launch group."
static func members_summary(rows: Array, number: int) -> String:
	var picked := 0
	var moving := 0
	for r in rows:
		if r.get("checked", false):
			picked += 1
			var lg := int(r.launchGroup)
			if lg > 0 and lg != number:
				moving += 1
	var text := "%s selected." % plural_programs(picked)
	if moving > 0:
		text = text.trim_suffix(".") + "; %d will leave %s other launch group." % [moving, "its" if moving == 1 else "their"]
	return text
