class_name Win95DialogLogic
extends RefCounted
## Pure rules behind the Win95 dialogs, Find window and property sheets (ports of the state
## handling in Win95Dialogs.tsx / Win95FindView.tsx). No UI; every function takes the store as an
## argument so tests can pass a throwaway ProgramStore instance.

const FIND_PAGE_STEP := 3
## Find > Advanced > Of type: ids and labels ("launch-group" = items in any launch group, "note" =
## sticky notes only).
const FIND_TYPES := ["all", "application", "internet", "launch-group", "note"]
const FIND_TYPE_LABELS := ["All launcher items", "Application", "Internet Shortcut", "In a launch group", "Sticky notes"]
## Longest note preview shown after a note's name in the Find results.
const FIND_PREVIEW_CHARS := 32
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


## ProgramSearch.find_programs for programs and web sites, plus sticky notes (found by their title or
## their text, see find_notes) and the win95-only types "note" and "launch-group" (items in any
## launch group). Programs keep ProgramSearch's ranking; notes are merged in by the same rule.
static func find_results(groups: Array, filters: Dictionary) -> Array:
	var type := String(filters.get("type", "all"))
	var out: Array = []
	if type != "note":
		var program_filters := filters.duplicate()
		if type == "launch-group":
			program_filters["type"] = "all"
		out = ProgramSearch.find_programs(groups, program_filters).filter(func(r): return not Notes.is_note(r.item))
	if type == "all" or type == "note" or type == "launch-group":
		out.append_array(find_notes(groups, filters))
	if type == "launch-group":
		out = out.filter(func(r): return int(r.item.get("launchGroup", 0)) > 0)
	out.sort_custom(func(a, b):
		if a.score != b.score:
			return a.score > b.score
		return String(a.item.name).naturalnocasecmp_to(String(b.item.name)) < 0)
	return out


## The sticky notes matching `filters` ({named, groupId?, containing?, path?}) as Find results
## {group, item, score}. "Named" matches the title (as for programs) or anywhere in the text;
## "Containing text" searches the title and text; notes have no path, so "Path contains" skips them.
static func find_notes(groups: Array, filters: Dictionary) -> Array:
	var named := String(filters.get("named", "")).strip_edges()
	if named.is_empty():
		named = "*"
	var wild := named.contains("*") or named.contains("?")
	var name_re := ProgramSearch._wildcard(named if wild else "*" + named + "*")
	var text_re := ProgramSearch._wildcard("*" + named + "*")
	var containing := String(filters.get("containing", "")).strip_edges().to_lower()
	var group_id := String(filters.get("groupId", ""))
	if String(filters.get("path", "")).strip_edges() != "":
		return []
	var named_l := named.to_lower()
	var out := []
	for group in groups:
		if group_id != "" and group.id != group_id:
			continue
		for item in group.items:
			if not Notes.is_note(item):
				continue
			var text := String(item.get("note", ""))
			var by_name := name_re.search(String(item.name)) != null
			if not by_name and text_re.search(text) == null:
				continue
			if containing != "" and not (String(item.name) + "\n" + text).to_lower().contains(containing):
				continue
			var lname := String(item.name).to_lower()
			var score := 1
			if by_name:
				score = 3 if lname == named_l else (2 if lname.begins_with(named_l) else 1)
			out.append({"group": group, "item": item, "score": score})
	return out


## Text drawn after a result's name in the Find list: a note's first line, else "".
static func find_preview(item: Dictionary) -> String:
	return Notes.preview(item, FIND_PREVIEW_CHARS) if Notes.is_note(item) else ""


## The Type column of a folder window in Details view.
static func item_type_label(item: Dictionary) -> String:
	return "Sticky Note" if Notes.is_note(item) else "Application"


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


## Creates the item; returns its id or "" when the form is invalid. `launch_group` > 0 puts the new
## item in that launch group.
static func wizard_finish(store: Object, group_id: String, name: String, command: String, icon: String, working_dir: String,
		launch_group: int = 0) -> String:
	if not wizard_can_finish(name, group_id, command):
		return ""
	var item := {"name": name.strip_edges(), "path": command.strip_edges(), "icon": icon, "workingDir": working_dir.strip_edges()}
	if launch_group > 0:
		item["launchGroup"] = launch_group
	return String(store.add_item(group_id, item))


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


# --------------------------------------------------------------- Sticky notes

const NOTE_DEFAULT_TITLE := "New Sticky Note"


## Ids and labels of the paper colours, in Notes.color_choices() order.
static func note_color_ids() -> Array:
	return Notes.color_choices().map(func(c): return String(c.id))


static func note_color_labels() -> Array:
	return Notes.color_choices().map(func(c): return String(c.label))


## Index of `color` in note_color_ids() (the default colour when unknown).
static func note_color_index(color: String) -> int:
	var ids := note_color_ids()
	var i := ids.find(color)
	return i if i >= 0 else maxi(0, ids.find(Notes.DEFAULT_COLOR))


static func note_color_at(index: int) -> String:
	var ids := note_color_ids()
	return String(ids[index]) if index >= 0 and index < ids.size() else Notes.DEFAULT_COLOR


static func can_create_note(name: String, group_id: String) -> bool:
	return group_id != "" and not name.strip_edges().is_empty()


## New Sticky Note OK: adds the note to `group_id` and returns its id, or "" when the form is
## invalid (blank title or no folder). `launch_group` > 0 puts it in that launch group.
static func create_note(store: Object, group_id: String, name: String, text: String, color: String, launch_group: int = 0) -> String:
	if not can_create_note(name, group_id):
		return ""
	var id := String(store.add_note(group_id, name.strip_edges(), text, color))
	if id != "" and launch_group > 0:
		store.update_item(group_id, id, {"launchGroup": launch_group})
	return id


## Note property sheet Apply/OK. fields: {name, color, launchGroup?, icon?}. Only these change; the
## text, window and program fields are left alone. Returns false (nothing applied) for a blank title.
static func apply_note_properties(store: Object, group_id: String, item_id: String, fields: Dictionary) -> bool:
	var name := String(fields.get("name", "")).strip_edges()
	if name.is_empty():
		return false
	var updates := {"name": name, "noteColor": note_color_at(note_color_index(String(fields.get("color", Notes.DEFAULT_COLOR))))}
	if fields.has("launchGroup"):
		updates["launchGroup"] = maxi(0, int(fields.launchGroup))
	var icon := String(fields.get("icon", "")).strip_edges()
	if icon != "":
		updates["icon"] = icon
	store.update_item(group_id, item_id, updates)
	return true


# ------------------------------------------------------------------ Properties

## Item sheet Apply/OK. fields: {name, command, workingDir, arguments, runMode, groupId, launchGroup?}.
## Returns {"ok": bool, "groupId": String (the group the item now lives in)}.
static func apply_item_properties(store: Object, persisted_group_id: String, item_id: String, fields: Dictionary) -> Dictionary:
	if String(fields.name).strip_edges().is_empty() or String(fields.command).strip_edges().is_empty() or String(fields.groupId) == "":
		return {"ok": false, "groupId": persisted_group_id}
	var updates := {
		"name": String(fields.name).strip_edges(),
		"path": String(fields.command).strip_edges(),
		"workingDir": String(fields.workingDir).strip_edges(),
		"arguments": String(fields.arguments).strip_edges(),
		"runMode": fields.runMode,
	}
	if fields.has("launchGroup"):
		updates["launchGroup"] = maxi(0, int(fields.launchGroup))
	store.update_item(persisted_group_id, item_id, updates)
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
