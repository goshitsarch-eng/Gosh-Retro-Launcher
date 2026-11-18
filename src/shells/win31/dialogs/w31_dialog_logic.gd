class_name W31DialogLogic
extends RefCounted
## Pure (UI-free) rules of the Win31 dialogs: validation, value mapping and apply semantics.
## Port of the logic embedded in components/Dialogs/*.tsx, QuickSearchOverlay.tsx and
## LaunchFeedback.tsx. Store mutations take the store node as a parameter so they are testable
## against a scratch ProgramStore.

const LAUNCH_GROUP_OPTIONS := [0, 1, 2, 3, 4, 5, 6, 7, 8]
const MAX_QUICK_SEARCH_RESULTS := 10
const RUN_MODE_LABELS := {"normal": "Normal Window", "minimized": "Minimized", "maximized": "Maximized"}
const SHELL_NAMES := {"win31": "Windows 3.1", "win95": "Windows 95", "mac": "Classic Mac OS", "be": "BeOS"}
const HELP_TOPICS := [
	"Creating program groups", "Creating program items", "Moving and copying items",
	"Arranging group windows", "Changing program icons", "Running a program", "Keyboard commands",
]
const HELP_HEADINGS := {
	"contents": "Program Manager Help Contents",
	"search": "Search for Help On...",
	"using": "How to Use Help",
}
const HELP_BODY_CONTENTS := "Use Program Manager to organize programs into groups. Double-click a program icon to run it. Use File to create, move, copy, delete, and inspect objects."
const HELP_BODY_USING := "Choose a menu command or select an object, then choose Help for information about that operation. Press F10 to enter menu mode and use the arrow keys to move."


## "None", "Group 3" or "Group 3: Morning" (`names` is settings.launchGroupNames).
static func format_launch_group(value: int, names: Variant = null) -> String:
	return LaunchGroups.format_launch_group(value, names)


## Labels and values of the "Launch Group:" drop-downs (None, Group 1 .. Group 8, with names). A
## `current` number above 8 (stored or imported) is added as an extra choice, so OK keeps it.
static func launch_group_choices(names: Variant = null, current: int = 0) -> Dictionary:
	var values: Array = LAUNCH_GROUP_OPTIONS.duplicate()
	if current > LaunchGroups.MAX_GROUP:
		values.append(current)
	var labels := []
	for v in values:
		labels.append(format_launch_group(v, names))
	return {"labels": labels, "values": values}


# ------------------------------------------------------------------ URLs (NewUrlDialog)

static func has_scheme(raw: String) -> bool:
	var re := RegEx.new()
	re.compile("^[a-zA-Z][a-zA-Z0-9+.-]*:")
	return re.search(raw) != null


static func normalize_url(raw: String) -> String:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return trimmed
	return trimmed if has_scheme(trimmed) else "https://" + trimmed


const _SPECIAL_SCHEMES := ["http", "https", "ftp", "ws", "wss", "file"]


## Minimal WHATWG-style split. Returns {} when `new URL(raw)` would throw, else
## {scheme, host, pathname, href}.
static func parse_url(raw: String) -> Dictionary:
	var s := raw.strip_edges()
	var re := RegEx.new()
	re.compile("^([a-zA-Z][a-zA-Z0-9+.-]*):(.*)$")
	var m := re.search(s)
	if m == null:
		return {}
	var scheme := m.get_string(1).to_lower()
	var rest := m.get_string(2)
	if _SPECIAL_SCHEMES.has(scheme):
		var r2 := rest
		while r2.begins_with("/") or r2.begins_with("\\"):
			r2 = r2.substr(1)
		var end := r2.length()
		for i in r2.length():
			if "/?#\\".contains(r2[i]):
				end = i
				break
		var authority := r2.substr(0, end)
		var host := authority.substr(authority.rfind("@") + 1) if authority.contains("@") else authority
		var port_re := RegEx.new()
		port_re.compile(":[0-9]*$")
		host = port_re.sub(host, "")
		if scheme != "file" and host.is_empty():
			return {}
		for ch in host:
			if " \t\n\r<>^|%".contains(ch):
				return {}
		var tail := r2.substr(end)
		return {"scheme": scheme, "host": host.to_lower(), "pathname": tail if tail != "" else "/",
			"href": "%s://%s%s" % [scheme, authority.to_lower(), tail if tail != "" else "/"]}
	var host2 := ""
	var pathname := rest
	if rest.begins_with("//"):
		var r3 := rest.substr(2)
		var end2 := r3.length()
		for i in r3.length():
			if "/?#".contains(r3[i]):
				end2 = i
				break
		host2 = r3.substr(0, end2)
		pathname = r3.substr(end2)
	return {"scheme": scheme, "host": host2, "pathname": pathname, "href": s}


static func is_valid_url(raw: String) -> bool:
	return not parse_url(normalize_url(raw)).is_empty()


static func derive_name(url: String) -> String:
	var parsed := parse_url(url)
	if parsed.is_empty():
		return url
	if String(parsed.host) != "":
		return parsed.host
	if parsed.scheme == "mailto" and String(parsed.pathname) != "":
		return parsed.pathname
	return parsed.href


## NewUrlDialog: can the OK button be enabled?
static func url_form_valid(url: String, group_id: String) -> bool:
	return not url.strip_edges().is_empty() and group_id != "" and is_valid_url(url)


## NewUrlDialog submit: returns the item payload or {} when the form is not submittable.
static func url_item(url: String, name: String, launch_group: int, group_id: String) -> Dictionary:
	if not url_form_valid(url, group_id):
		return {}
	var normalized := normalize_url(url)
	var final_name := name.strip_edges()
	if final_name.is_empty():
		final_name = derive_name(normalized)
	return {"name": final_name, "path": normalized, "icon": "web", "workingDir": "", "launchGroup": launch_group}


## A web site item: its command line is a URL (a scheme of two or more letters, "https:", "mailto:",
## ...), not a file. Its Properties show the URL instead of the program fields.
static func is_web_item(item: Dictionary) -> bool:
	if item.is_empty() or Notes.is_note(item):
		return false
	var p := String(item.get("path", "")).strip_edges()
	return Launcher.has_uri_scheme(p) and not p.to_lower().begins_with("file:")


## Initial values of the Web Site Properties form.
static func web_form(existing: Dictionary) -> Dictionary:
	var icon := String(existing.get("win31Icon", ""))
	if icon == "":
		icon = String(existing.get("icon", ""))
	return {
		"name": String(existing.get("name", "")), "url": String(existing.get("path", "")),
		"launchGroup": int(existing.get("launchGroup", 0)), "shortcutKey": String(existing.get("shortcutKey", "")),
		"win31Icon": icon if icon != "" else "web",
	}


## The values Web Site Properties writes ({} when the URL is not valid). An empty description
## becomes the site's host, like New Web Site.
static func web_values(form: Dictionary) -> Dictionary:
	var url := String(form.get("url", ""))
	if url.strip_edges().is_empty() or not is_valid_url(url):
		return {}
	var normalized := normalize_url(url)
	var name := String(form.get("name", "")).strip_edges()
	var icon := String(form.get("win31Icon", ""))
	return {
		"name": name if name != "" else derive_name(normalized), "path": normalized,
		"launchGroup": maxi(0, int(form.get("launchGroup", 0))),
		"shortcutKey": String(form.get("shortcutKey", "")).strip_edges(),
		"win31Icon": icon if icon != "" else "web",
	}


static func apply_web_properties(store: Node, group_id: String, item_id: String, form: Dictionary) -> bool:
	var values := web_values(form)
	if values.is_empty() or store.find_item(group_id, item_id).is_empty():
		return false
	store.update_item(group_id, item_id, values)
	return true


## New Web Site OK: adds the site to `group_id`; returns its id or "".
static func apply_new_url(store: Node, group_id: String, url: String, name: String, launch_group: int) -> String:
	var item := url_item(url, name, launch_group, group_id)
	if item.is_empty() or store.find_group(group_id).is_empty():
		return ""
	return String(store.add_item(group_id, item))


## {title, message} of the File > Delete / note menu confirmation for `item`. The name is shown as
## written (message box text is literal, so an "&" in it is not an access key).
static func delete_item_prompt(item: Dictionary) -> Dictionary:
	var name := String(item.get("name", ""))
	if Notes.is_note(item):
		return {"title": "Delete Sticky Note", "message": "Delete the sticky note “%s”?" % name}
	return {"title": "Delete Program Item", "message": "Delete the program item “%s”?" % name}


# ------------------------------------------------------------- groups

static func group_file_name(name: String) -> String:
	var re := RegEx.new()
	re.compile("[^a-zA-Z0-9]+")
	var stem := re.sub(name, "", true).substr(0, 8)
	if stem.is_empty():
		stem = "GROUP"
	return (stem + ".GRP").to_upper()


static func group_name_valid(name: String) -> bool:
	return not name.strip_edges().is_empty()


## GroupPropertiesDialog submit. Returns false (no-op) for a blank description.
static func apply_group_properties(store: Node, group_id: String, name: String, icon: String) -> bool:
	if not group_name_valid(name):
		return false
	store.update_group(group_id, {"name": name.strip_edges(), "icon": icon})
	return true


static func apply_rename_group(store: Node, group_id: String, name: String) -> bool:
	if group_id == "" or not group_name_valid(name):
		return false
	store.update_group(group_id, {"name": name.strip_edges()})
	return true


## NewGroupDialog submit. Returns the new group id or "" for a blank name.
static func apply_new_group(store: Node, name: String) -> String:
	if not group_name_valid(name):
		return ""
	return store.add_group(name.strip_edges())


## What NewGroupDialog does after the group exists: "newItem" | "newUrl" | "" (close).
static func new_group_followup(data: Dictionary) -> String:
	if data.get("openItemAfterCreate", false):
		return "newItem"
	if data.get("openUrlAfterCreate", false):
		return "newUrl"
	return ""


## The New Program Object choices, in order: [kind, radio label]. Programs, web sites and sticky
## notes are the three kinds of item; a group holds them.
const NEW_OBJECT_KINDS := [
	["group", "Program &Group"], ["item", "Program &Item"], ["url", "&Web Site"], ["note", "Sticky &Note"],
]
const NEW_OBJECT_DIALOGS := {"item": "newItem", "url": "newUrl", "note": "newNote"}


## NewProgramObjectDialog OK: which dialog opens next -> {type, data}. `kind` is "group", "item",
## "url" (Web Site) or "note" (Sticky Note).
static func new_object_next(kind: String, preferred_group_id: String, groups: Array) -> Dictionary:
	if kind == "group":
		return {"type": "newGroup", "data": {}}
	var gid := preferred_group_id
	if gid == "" and groups.size() > 0:
		gid = groups[0].id
	return {"type": String(NEW_OBJECT_DIALOGS.get(kind, "newItem")), "data": {"groupId": gid}}


## Whether choice `kind` can be picked: everything but a group needs a group to go in.
static func new_object_kind_enabled(kind: String, groups: Array) -> bool:
	return kind == "group" or not groups.is_empty()


static func new_object_default_kind(groups: Array) -> String:
	return "item" if groups.size() > 0 else "group"


# ------------------------------------------------------------- items

## Initial form values for ItemPropertiesDialog (from an existing item or empty).
static func item_form(existing: Dictionary) -> Dictionary:
	var run_mode: String = existing.get("runMode", "")
	if run_mode == "":
		run_mode = "minimized" if existing.get("runMinimized", false) else "normal"
	var icon: String = existing.get("icon", "")
	if icon == "":
		icon = "default"
	var win31_icon: String = existing.get("win31Icon", "")
	if win31_icon == "":
		win31_icon = existing.get("icon", "")
	if win31_icon == "":
		win31_icon = "default"
	return {
		"name": existing.get("name", ""), "path": existing.get("path", ""),
		"workingDir": existing.get("workingDir", ""), "arguments": existing.get("arguments", ""),
		"environment": existing.get("environment", ""), "runMode": run_mode,
		"icon": icon, "win31Icon": win31_icon,
		"launchGroup": int(existing.get("launchGroup", 0)), "shortcutKey": existing.get("shortcutKey", ""),
	}


static func item_form_valid(form: Dictionary, group_id: String) -> bool:
	return not String(form.get("name", "")).strip_edges().is_empty() \
		and not String(form.get("path", "")).strip_edges().is_empty() and group_id != ""


## The values ItemPropertiesDialog writes (trimmed strings, runMinimized derived from runMode,
## launchGroup never below 0; a number above 8 is kept).
static func item_values(form: Dictionary) -> Dictionary:
	var run_mode: String = form.get("runMode", "normal")
	if not Types.RUN_MODES.has(run_mode):
		run_mode = "normal"
	return {
		"name": String(form.get("name", "")).strip_edges(),
		"path": String(form.get("path", "")).strip_edges(),
		"workingDir": String(form.get("workingDir", "")).strip_edges(),
		"arguments": String(form.get("arguments", "")).strip_edges(),
		"environment": String(form.get("environment", "")).strip_edges(),
		"runMode": run_mode,
		"icon": form.get("icon", "default"),
		"win31Icon": form.get("win31Icon", "default"),
		"launchGroup": maxi(0, int(form.get("launchGroup", 0))),
		"shortcutKey": String(form.get("shortcutKey", "")).strip_edges(),
		"runMinimized": run_mode == "minimized",
	}


## ItemPropertiesDialog submit. `existing` = the item being edited ({} = new), `resolved_group_id`
## its current group. Returns the affected item id or "" when the form is not submittable.
static func apply_item_properties(store: Node, form: Dictionary, existing: Dictionary, resolved_group_id: String, selected_group_id: String) -> String:
	if not item_form_valid(form, selected_group_id):
		return ""
	var values := item_values(form)
	if not existing.is_empty():
		store.update_item(resolved_group_id, existing.id, values)
		if resolved_group_id != "" and selected_group_id != resolved_group_id:
			store.move_item(resolved_group_id, selected_group_id, existing.id)
		return existing.id
	return store.add_item(selected_group_id, values)


## Group that owns the item (dialogData.groupId || the group containing the item || first group).
static func resolve_item_group(groups: Array, data: Dictionary) -> String:
	var gid: String = data.get("groupId", "")
	if gid != "":
		return gid
	var item: Dictionary = data.get("item", {})
	if not item.is_empty():
		for g in groups:
			for it in g.items:
				if it.id == item.id:
					return g.id
		return ""
	return groups[0].id if groups.size() > 0 else ""


## Browse... result applied to the form. `info` is Platform.get_app_info(path) (may be empty).
## Only fills fields the user has not already set, like handleBrowsePath.
static func apply_browse_result(form: Dictionary, selected_path: String, info: Dictionary) -> Dictionary:
	var f: Dictionary = form.duplicate()
	f.path = selected_path
	if info.is_empty():
		if String(f.name) == "":
			var file_name := selected_path.replace("\\", "/").get_file()
			var dot := file_name.rfind(".")
			f.name = file_name.substr(0, dot) if dot > 0 else file_name
		return f
	if String(f.name) == "" and String(info.get("name", "")) != "":
		f.name = info.name
	if String(info.get("icon", "")) != "" and (f.icon == "default" or f.icon == "default-item.png"):
		f.icon = info.icon
	if String(info.get("win31Icon", "")) != "" and (f.win31Icon == "default" or f.win31Icon == "default-item.png"):
		f.win31Icon = info.win31Icon
	if String(f.workingDir) == "" and String(info.get("workingDir", "")) != "":
		f.workingDir = info.workingDir
	if String(f.arguments) == "" and String(info.get("arguments", "")) != "":
		f.arguments = info.arguments
	return f


## Change Icon > Browse...: icon chosen from an extracted app icon (win31Icon, then icon).
static func browse_icon_choice(info: Dictionary, current: String) -> String:
	var v: String = info.get("win31Icon", "")
	if v == "":
		v = info.get("icon", "")
	return v if v != "" else current


## ChangeIconDialog submit: persists win31Icon only.
static func apply_change_icon(store: Node, group_id: String, item_id: String, icon: String) -> void:
	store.update_item(group_id, item_id, {"win31Icon": icon})


## Move/Copy destinations (copy allows the source group).
static func move_copy_groups(groups: Array, copy: bool, source_group_id: String) -> Array:
	if copy:
		return groups
	return groups.filter(func(g): return g.id != source_group_id)


static func apply_move_copy(store: Node, copy: bool, source_group_id: String, destination: String, item_id: String) -> bool:
	if destination == "":
		return false
	if copy:
		store.copy_item(source_group_id, destination, item_id)
	else:
		store.move_item(source_group_id, destination, item_id)
	return true


# ---------------------------------------------------------- sticky notes

## Labels and ids of the "Color:" drop-down, in Notes.COLORS order.
static func note_color_choices() -> Dictionary:
	var labels := []
	var values := []
	for c in Notes.color_choices():
		labels.append(String(c.label))
		values.append(String(c.id))
	return {"labels": labels, "values": values}


## Initial values of the New Sticky Note / note Properties form ({} = a new note).
static func note_form(existing: Dictionary = {}) -> Dictionary:
	var color := String(existing.get("noteColor", Notes.DEFAULT_COLOR))
	if not Notes.COLORS.has(color):
		color = Notes.DEFAULT_COLOR
	var icon := String(existing.get("win31Icon", ""))
	if icon == "":
		icon = String(existing.get("icon", ""))
	return {
		"name": String(existing.get("name", "")),
		"text": String(existing.get("note", "")),
		"noteColor": color,
		"launchGroup": maxi(0, int(existing.get("launchGroup", 0))),
		"win31Icon": icon if icon != "" else Notes.ICON,
	}


## OK needs a group to put the note in (a blank title becomes "Note", like Notes.make_note).
static func note_form_valid(group_id: String) -> bool:
	return group_id != ""


## New Sticky Note OK: adds the note to `group_id` and returns its id ("" when refused).
static func apply_new_note(store: Node, group_id: String, form: Dictionary) -> String:
	if not note_form_valid(group_id):
		return ""
	var id: String = store.add_note(group_id, String(form.get("name", "")), String(form.get("text", "")),
		String(form.get("noteColor", Notes.DEFAULT_COLOR)))
	var lg := maxi(0, int(form.get("launchGroup", 0)))
	if id != "" and lg > 0:
		store.update_item(group_id, id, {"launchGroup": lg})
	return id


## What note Properties writes: title, paper colour, launch group and icon only (the text is
## edited in the note itself; a note has no command line, directory or shortcut key).
static func note_values(form: Dictionary) -> Dictionary:
	var name := String(form.get("name", "")).strip_edges()
	var color := String(form.get("noteColor", Notes.DEFAULT_COLOR))
	var icon := String(form.get("win31Icon", ""))
	return {
		"name": name if name != "" else "Note",
		"noteColor": color if Notes.COLORS.has(color) else Notes.DEFAULT_COLOR,
		"launchGroup": maxi(0, int(form.get("launchGroup", 0))),
		"win31Icon": icon if icon != "" else Notes.ICON,
	}


## Note Properties OK. Returns false when the group or item is missing.
static func apply_note_properties(store: Node, group_id: String, item_id: String, form: Dictionary) -> bool:
	if group_id == "" or item_id == "" or store.find_item(group_id, item_id).is_empty():
		return false
	store.update_item(group_id, item_id, note_values(form))
	return true


# --------------------------------------------------------------- Run

## RunProgramDialog: the item passed to Platform.launch. {} for a blank command line.
static func run_item(command: String) -> Dictionary:
	if command.strip_edges().is_empty():
		return {}
	var parsed := Grp.split_legacy_command(command)
	var path: String = parsed.path
	var file_name := path.replace("\\", "/").get_file()
	return {"id": "run-command", "name": file_name if file_name != "" else path, "path": path,
		"arguments": parsed.arguments, "workingDir": "", "icon": "default"}


static func run_error_message(result: Dictionary, path: String) -> String:
	var e: String = result.get("error", "")
	return e if e != "" else "Cannot run %s." % path


# ---------------------------------------------------------------- Help

static func help_topics(query: String) -> Array:
	var q := query.to_lower()
	var out := []
	for t in HELP_TOPICS:
		if q.is_empty() or String(t).to_lower().contains(q):
			out.append(t)
	return out


static func help_heading(topic: String) -> String:
	return HELP_HEADINGS.get(topic, HELP_HEADINGS.contents)


# ------------------------------------------------------------- Settings

static func settings_form(settings: Dictionary) -> Dictionary:
	return {
		"launchDelay": int(settings.get("launchDelay", 500)),
		"autoArrange": settings.get("autoArrange", true),
		"minimizeOnUse": settings.get("minimizeOnUse", false),
		"saveSettingsOnExit": settings.get("saveSettingsOnExit", true),
		"trayOnClose": settings.get("trayOnClose", true),
		"groupChromeScale": settings.get("groupChromeScale", 1),
		"win31Scale": settings.get("win31Scale", "auto"),
		"win95Scale": settings.get("win95Scale", "auto"),
		"macScale": settings.get("macScale", "auto"),
		"beScale": settings.get("beScale", "auto"),
		"theme": settings.get("theme", "light"),
		"labelDisplay": settings.get("labelDisplay", "wrap") if settings.get("labelDisplay", "") != "" else "wrap",
		"shell": settings.get("shell", "win31") if settings.get("shell", "") != "" else "win31",
		"soundEnabled": settings.get("soundEnabled", true),
	}


## Normalizes the launch delay slider value to 100-5000 in steps of 100.
static func clamp_launch_delay(value: Variant) -> int:
	var v := int(roundf(float(value) / 100.0)) * 100
	return clampi(v, 100, 5000)


static func settings_updates(form: Dictionary) -> Dictionary:
	var out := form.duplicate()
	out.launchDelay = clamp_launch_delay(form.get("launchDelay", 500))
	return out


static func scale_label(value: Variant) -> String:
	return "Auto" if str(value) == "auto" else "%d×" % int(value)


static func scale_from_index(index: int) -> Variant:
	return "auto" if index <= 0 else clampi(index, 1, 4)


static func scale_to_index(value: Variant) -> int:
	return 0 if str(value) == "auto" else clampi(int(value), 1, 4)


## SettingsDialog submit. Every change goes through ProgramStore's validated, persist-first
## settings transaction, like Launcher Tools' Apply (the host remounts the shell on
## settings_changed when the shell changed). Invalid settings leave the store untouched.
## Returns {success, shellChanged, error?}.
static func apply_settings(store: Node, form: Dictionary) -> Dictionary:
	var updates := settings_updates(form)
	var shell_changed: bool = updates.shell != store.settings.get("shell", "win31")
	var next: Dictionary = store.settings.duplicate(true)
	for k in updates:
		next[k] = updates[k]
	var result: Dictionary = store.apply_settings_transaction(next)
	result["shellChanged"] = shell_changed
	return result


## What the Settings dialog shows after apply_settings: {} on success, otherwise the payload for an
## OK message box ({title, message}) so a refused change is never silent.
static func settings_failure_notice(result: Dictionary) -> Dictionary:
	if result.get("success", false):
		return {}
	var err := String(result.get("error", ""))
	return {"title": "Settings", "message": "The settings could not be applied%s. Nothing was changed." %
		((": " + err) if err != "" else "")}


# ---------------------------------------------------------- Quick Search

## Quick Search matches: ProgramSearch's ranking (name, path, group) plus sticky notes whose text
## contains the query (ranked like a path match), each item once.
static func quick_search_results(groups: Array, query: String) -> Array:
	var results := ProgramSearch.search_programs(groups, query)
	var q := query.strip_edges().to_lower()
	if q.is_empty():
		return results
	var seen := {}
	for r in results:
		seen[String(r.item.get("id", ""))] = true
	var extra := []
	for g in groups:
		for item in g.get("items", []):
			if Notes.is_note(item) and not seen.has(String(item.get("id", ""))) \
					and String(item.get("note", "")).to_lower().contains(q):
				extra.append({"group": g, "item": item, "score": 1})
	if extra.is_empty():
		return results
	results.append_array(extra)
	results.sort_custom(ProgramSearch._cmp)
	return results


## Second line of a Quick Search row: a note's first line of text (when it has any), else the group.
static func quick_search_detail(result: Dictionary) -> String:
	var item: Dictionary = result.get("item", {})
	if Notes.is_note(item):
		var p := Notes.preview(item)
		if p != "":
			return p
	return String(result.get("group", {}).get("name", ""))


## {displayed, total, hasMore, moreCount, moreText, empty (show "No results found")}.
static func quick_search_view(groups: Array, query: String) -> Dictionary:
	var results := quick_search_results(groups, query)
	var displayed := results.slice(0, MAX_QUICK_SEARCH_RESULTS)
	var more := results.size() - MAX_QUICK_SEARCH_RESULTS
	return {
		"displayed": displayed, "total": results.size(), "hasMore": results.size() > MAX_QUICK_SEARCH_RESULTS,
		"moreCount": maxi(more, 0),
		"moreText": "%d more result%s not shown" % [more, "" if more == 1 else "s"] if more > 0 else "",
		"empty": query != "" and results.is_empty(),
	}


## Arrow-key navigation: delta is +1 (Down) / -1 (Up); clamped, never wraps.
static func quick_search_move(index: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(index + delta, 0, count - 1)


# -------------------------------------------------------- Launch feedback

static func feedback_progress(fb: Dictionary) -> int:
	var total := int(fb.get("totalGroups", 0))
	if total <= 0:
		return 0
	return mini(100, int(floorf(float(fb.get("completedGroups", 0)) / float(total) * 100.0 + 0.5)))


static func feedback_status_text(fb: Dictionary, names: Variant = null) -> String:
	var status: String = fb.get("status", "idle")
	if status == "complete":
		var n := int(fb.get("totalItems", 0))
		return "Launched %d item%s" % [n, "" if n == 1 else "s"]
	if status == "error":
		var f := int(fb.get("failures", 0))
		return "%d launch%s failed" % [f, "" if f == 1 else "es"]
	if fb.get("currentGroup") != null:
		return "Launching " + format_launch_group(int(fb.currentGroup), names)
	return "Preparing launch groups"


static func feedback_detail_text(fb: Dictionary) -> String:
	return "%d of %d groups" % [int(fb.get("completedGroups", 0)), int(fb.get("totalGroups", 0))]


static func feedback_icon_text(fb: Dictionary) -> String:
	var status: String = fb.get("status", "idle")
	if status == "launching":
		return ">>"
	return "!" if status == "error" else "OK"


# ------------------------------------------------------------------ About

static func platform_display_name(os_name: String) -> String:
	var names := {"win32": "Windows", "darwin": "macOS", "linux": "Linux"}
	return names.get(os_name, os_name)


static func welcome_mod_key(os_name: String) -> String:
	return "Cmd" if os_name == "darwin" else "Ctrl"


# ---------------------------------------------------------- Launch groups
# Rules of the Launch Groups manager and its New/Rename, Number and Members dialogs. A launch group
# is a number on each item plus an optional name (settings.launchGroupNames); ProgramStore does the
# editing, these turn it into rows, labels and messages.

const ALL_LAUNCH_GROUPS_IN_USE := "All 8 launch group numbers are in use. Delete a launch group first, or add programs to one you already have."
const NO_LAUNCH_GROUPS := "There are no launch groups yet. Choose New... to make one, then pick its programs."
const MEMBERS_MOVE_NOTE := "Checking a program that is in another launch group moves it to this one."


## "No programs", "1 program", "3 programs".
static func program_count_text(n: int) -> String:
	if n <= 0:
		return "No programs"
	return "1 program" if n == 1 else "%d programs" % n


## Rows of the manager's list: [{number, name, count, text "Group 3: Morning", right "2 programs"}].
static func launch_group_rows(groups: Array, names: Variant) -> Array:
	var out := []
	for d in LaunchGroups.defined_groups(groups, names):
		out.append({"number": int(d.number), "name": String(d.name), "count": int(d.count),
			"text": String(d.label), "right": program_count_text(int(d.count))})
	return out


## Index of launch group `number` in `rows`; 0 when it is not there, -1 when there are no rows.
static func launch_group_row_index(rows: Array, number: int) -> int:
	for i in rows.size():
		if int(rows[i].number) == number:
			return i
	return 0 if not rows.is_empty() else -1


## Which manager buttons are enabled for the selected row `index` ({new, rename, number, delete,
## members, launch}). Launch needs members and no batch already running.
static func launch_group_actions(rows: Array, index: int, launching: bool = false) -> Dictionary:
	var has := index >= 0 and index < rows.size()
	var count := int(rows[index].count) if has else 0
	return {"new": true, "rename": has, "number": has, "delete": has, "members": has,
		"launch": has and count > 0 and not launching}


## The text under the manager's list: who is in the selected group (or how to start).
static func launch_group_detail(groups: Array, names: Variant, number: int) -> String:
	if number <= 0:
		return NO_LAUNCH_GROUPS
	var label := format_launch_group(number, names)
	var members := []
	for e in LaunchGroups.all_items(groups):
		if int(e.launchGroup) == number:
			members.append(String(e.name))
	if members.is_empty():
		return "%s has no programs yet. Choose Members... to add some." % label
	return "%s starts %s." % [label, _join_names(members, 6)]


## "A", "A and B", "A, B and C", "A, B, C, D, E and 3 more" (at most `limit` parts).
static func _join_names(list: Array, limit: int) -> String:
	if list.size() == 1:
		return String(list[0])
	if list.size() > limit:
		var shown := list.slice(0, limit - 1)
		return "%s and %d more" % [", ".join(shown), list.size() - shown.size()]
	return "%s and %s" % [", ".join(list.slice(0, list.size() - 1)), list[list.size() - 1]]


## The number New would use, or 0 when all of 1..8 are taken (then show ALL_LAUNCH_GROUPS_IN_USE).
static func new_launch_group_number(groups: Array, names: Variant) -> int:
	return LaunchGroups.next_free_number(groups, names)


## Can the New / Rename name dialog's OK be pressed? New needs a name; a blank rename clears it.
static func launch_group_name_ok(mode: String, text: String) -> bool:
	return mode != "new" or LaunchGroups.clean_name(text) != ""


## Creates a named, empty launch group. Returns {number, status}; number 0 when refused.
static func apply_new_launch_group(store: Node, name: String) -> Dictionary:
	if LaunchGroups.clean_name(name) == "":
		return {"number": 0, "status": "Type a name for the new launch group."}
	var n: int = store.create_launch_group(name)
	if n == 0:
		return {"number": 0, "status": ALL_LAUNCH_GROUPS_IN_USE}
	return {"number": n, "status": "Created %s." % format_launch_group(n, store.launch_group_names())}


## Renames group `number` (blank removes the name). Returns the status line.
static func apply_rename_launch_group(store: Node, number: int, name: String) -> String:
	if number <= 0:
		return ""
	store.set_launch_group_name(number, name)
	var cleaned := LaunchGroups.clean_name(name)
	if cleaned == "":
		return "Group %d has no name now." % number
	return "Group %d is now called “%s”." % [number, cleaned]


## Choices of the Number dialog: [{value, label}] for 1..MAX_GROUP; a taken number says it swaps.
static func launch_group_number_choices(groups: Array, names: Variant, current: int) -> Array:
	var taken := {}
	for d in LaunchGroups.defined_groups(groups, names):
		taken[int(d.number)] = true
	var out := []
	for v in range(1, LaunchGroups.MAX_GROUP + 1):
		var label := "%d" % v
		if v == current:
			label += " (current)"
		elif taken.has(v):
			label += " - swap with " + format_launch_group(v, names)
		out.append({"value": v, "label": label})
	return out


## What moving group `from` to `to` will do, for the Number dialog ("" when nothing changes).
static func renumber_note(groups: Array, names: Variant, from: int, to: int) -> String:
	if from <= 0 or to <= 0 or from == to:
		return ""
	for d in LaunchGroups.defined_groups(groups, names):
		if int(d.number) == to:
			return "%s becomes Group %d: the two swap places in Launch All." % [String(d.label), from]
	return "Launch All starts the groups in number order, lowest first."


## Renumbers group `from` to `to` through the store. Returns {ok, number, status}.
static func apply_renumber_launch_group(store: Node, from: int, to: int) -> Dictionary:
	if from == to:
		return {"ok": false, "number": from, "status": ""}
	var names: Dictionary = store.launch_group_names().duplicate()
	var before_from := format_launch_group(from, names)
	var swapped := ""
	for d in LaunchGroups.defined_groups(store.groups, names):
		if int(d.number) == to:
			swapped = String(d.label)
	if not store.renumber_launch_group(from, to):
		return {"ok": false, "number": from, "status": ""}
	var status := "%s is now Group %d." % [before_from, to]
	if swapped != "":
		status += " %s is now Group %d." % [swapped, from]
	return {"ok": true, "number": to, "status": status}


## Delete confirmation text; says plainly that the programs are kept.
static func delete_launch_group_message(groups: Array, names: Variant, number: int) -> String:
	var label := format_launch_group(number, names)
	var count := LaunchGroups.member_keys(groups, number).size()
	if count == 0:
		return "Delete %s? It has no programs." % label
	return "Delete %s? Its %s will stay in their program groups; they just stop launching with this group." % [
		label, program_count_text(count).to_lower()]


static func apply_delete_launch_group(store: Node, number: int) -> String:
	var label := format_launch_group(number, store.launch_group_names())
	store.delete_launch_group(number)
	return "Deleted %s. Its programs were kept." % label


## "groupId:itemId" keys of the current members of `number`, as a set.
static func member_check_set(groups: Array, number: int) -> Dictionary:
	var out := {}
	for k in LaunchGroups.member_keys(groups, number):
		out[k] = true
	return out


## Rows of the Members checklist: a bold header per program group that has items, then its items
## [{key, text, checked, indent}]; an item in another launch group says so: "Clock (Group 2: Evening)".
static func member_rows(groups: Array, names: Variant, number: int, checked: Dictionary) -> Array:
	var out := []
	var last_group := ""
	var note_keys := {}  # sticky notes can be members too (they open when the group runs); say which rows are notes
	for g in groups:
		for it in g.get("items", []):
			if Notes.is_note(it):
				note_keys["%s:%s" % [g.id, it.id]] = true
	for e in LaunchGroups.all_items(groups):
		if String(e.groupId) != last_group:
			last_group = String(e.groupId)
			out.append({"header": true, "text": String(e.groupName)})
		var text := String(e.name)
		if note_keys.has(String(e.key)):
			text += " (note)"
		var lg := int(e.launchGroup)
		if lg > 0 and lg != number:
			text += " (%s)" % format_launch_group(lg, names)
		out.append({"key": String(e.key), "text": text, "checked": checked.has(String(e.key)), "indent": 10})
	return out


## Keys of the checked rows, in list order.
static func checked_member_keys(rows: Array) -> Array:
	var out := []
	for r in rows:
		if not r.get("header", false) and r.get("checked", false):
			out.append(String(r.key))
	return out


## Applies the Members checklist. Returns the status line.
static func apply_launch_group_members(store: Node, number: int, keys: Array) -> String:
	store.set_launch_group_members(number, keys)
	return "%s has %s." % [format_launch_group(number, store.launch_group_names()), program_count_text(keys.size()).to_lower()]


## The bucket list Launch starts for group `number` ([] when it has no members).
static func launch_group_bucket(groups: Array, number: int) -> Array:
	for b in LaunchGroups.collect_launch_groups(groups):
		if int(b.groupNumber) == number:
			return [b]
	return []
