class_name W31DialogLogic
extends RefCounted
## Pure (UI-free) rules of the Win31 dialogs: validation, value mapping and apply semantics.
## Port of the logic embedded in components/Dialogs/*.tsx, QuickSearchOverlay.tsx and
## LaunchFeedback.tsx. Store mutations take the store node as a parameter so they are testable
## against a scratch ProgramStore.

const LAUNCH_GROUP_OPTIONS := [0, 1, 2, 3, 4, 5, 6, 7, 8]
const MAX_QUICK_SEARCH_RESULTS := 10
const RUN_MODE_LABELS := {"normal": "Normal Window", "minimized": "Minimized", "maximized": "Maximized"}
const SHELL_NAMES := {"win31": "Windows 3.1", "win95": "Windows 95"}
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


static func format_launch_group(value: int) -> String:
	return LaunchGroups.format_launch_group(value)


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


## NewProgramObjectDialog OK: which dialog opens next -> {type, data}.
static func new_object_next(kind: String, preferred_group_id: String, groups: Array) -> Dictionary:
	if kind == "group":
		return {"type": "newGroup", "data": {}}
	var gid := preferred_group_id
	if gid == "" and groups.size() > 0:
		gid = groups[0].id
	return {"type": "newItem", "data": {"groupId": gid}}


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
## launchGroup clamped to 0-8).
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
		"launchGroup": clampi(int(form.get("launchGroup", 0)), 0, 8),
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
		if String(t).to_lower().contains(q):
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


## SettingsDialog submit. Persists through ProgramStore. A shell change goes through the
## persist-first transaction (the host remounts the shell on settings_changed).
## Returns {success, shellChanged, error?}.
static func apply_settings(store: Node, form: Dictionary) -> Dictionary:
	var updates := settings_updates(form)
	var shell_changed: bool = updates.shell != store.settings.get("shell", "win31")
	if shell_changed:
		var next: Dictionary = store.settings.duplicate(true)
		for k in updates:
			next[k] = updates[k]
		var result: Dictionary = store.apply_settings_transaction(next)
		result["shellChanged"] = true
		return result
	store.update_settings(updates)
	return {"success": true, "shellChanged": false}


# ---------------------------------------------------------- Quick Search

## {displayed, total, hasMore, moreCount, moreText, empty (show "No results found")}.
static func quick_search_view(groups: Array, query: String) -> Dictionary:
	var results := ProgramSearch.search_programs(groups, query)
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


static func feedback_status_text(fb: Dictionary) -> String:
	var status: String = fb.get("status", "idle")
	if status == "complete":
		var n := int(fb.get("totalItems", 0))
		return "Launched %d item%s" % [n, "" if n == 1 else "s"]
	if status == "error":
		var f := int(fb.get("failures", 0))
		return "%d launch%s failed" % [f, "" if f == 1 else "es"]
	if fb.get("currentGroup") != null:
		return "Launching Group %d" % int(fb.currentGroup)
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
