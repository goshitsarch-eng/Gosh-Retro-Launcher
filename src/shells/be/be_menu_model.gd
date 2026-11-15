class_name BeMenuModel
extends RefCounted
## Pure menu definitions (port of itemMenu / groupMenu / sysMenu / deskMenu / deskIconMenu / folderBgMenu / the folder
## menu bar / the Deskbar menu in the design). Rows are {label, action, args, bold?, disabled?, dot?} or {sep: true};
## BeShell dispatches `action` with `args`. Nothing here touches nodes or autoloads.

const VIEWS := [["large", "Icon View"], ["small", "Mini Icon View"], ["details", "List View"]]

const SEP := {"sep": true}


static func row(label: String, action: String, args: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var r := {"label": label, "action": action, "args": args}
	for k in opts:
		r[k] = opts[k]
	return r


static func item_menu(gid: String, iid: String) -> Array:
	var a := {"gid": gid, "iid": iid}
	return [row("Open", "item.open", a, {"bold": true}), row("Get Info", "item.info", a), row("Edit Name", "item.rename", a),
		SEP, row("Duplicate", "item.duplicate", a), row("Move to Trash", "item.trash", a)]


static func group_menu(gid: String) -> Array:
	var a := {"gid": gid}
	return [row("Open", "group.open", a, {"bold": true}), row("Get Info", "group.info", a), row("Edit Name", "group.rename", a),
		SEP, row("Move to Trash", "group.trash", a)]


## Deskbar task / window system menu.
static func window_menu(key: String) -> Array:
	var a := {"key": key}
	return [row("Show", "window.show", a), row("Hide", "window.hide", a), row("Zoom", "window.zoom", a), SEP,
		row("Close", "window.close", a)]


static func desktop_menu() -> Array:
	return [row("New Folder", "folder.new"), SEP, row("Clean Up", "desktop.cleanup"),
		row("Select All", "none", {}, {"disabled": true}), SEP, row("Find…", "find.open"),
		row("Launcher Tools…", "tools.open"), row("Backgrounds…", "backgrounds.open"), SEP, row("Help", "help.open")]


## `id` is "computer" or "g:<groupId>".
static func desktop_icon_menu(id: String) -> Array:
	if id.begins_with("g:"):
		return group_menu(id.substr(2))
	return [row("Open", "computer.open", {}, {"bold": true}), row("Get Info", "about.open"), SEP, row("Find…", "find.open")]


## Right-click on the white area of a folder window.
static func folder_background_menu(key: String, is_computer: bool, view: String) -> Array:
	var out := [row("New Folder" if is_computer else "Add Program…", "folder.new" if is_computer else "program.new", {"key": key})]
	if not is_computer:
		out.append(row("Add Website…", "website.new", {"key": key}))
	out.append(SEP)
	for v in VIEWS:
		out.append(row(v[1], "window.view", {"key": key, "view": v[0]}, {"dot": view == v[0]}))
	out.append_array([SEP, row("Clean Up", "window.cleanup", {"key": key}), row("Select All", "none", {}, {"disabled": true}), SEP,
		row("Get Info", "about.open" if is_computer else "group.info", {} if is_computer else {"gid": BeWindowStore.group_id_of(key)}),
		row("Close", "window.close", {"key": key})])
	return out


## The File / Edit / View / Help menu bar of a folder window. `sel` = selected entry id in that window or "".
static func menu_bar(key: String, is_computer: bool, view: String, sel: String) -> Array:
	var none := sel == ""
	var gid := "" if is_computer else BeWindowStore.group_id_of(key)
	var a := {"gid": sel} if is_computer else {"gid": gid, "iid": sel}
	var file := [
		row("Open", "group.open" if is_computer else "item.open", a, {"bold": true, "disabled": none}), SEP,
		row("New Folder" if is_computer else "Add Program…", "folder.new" if is_computer else "program.new", {"key": key}),
		row("Add Website…", "website.new", {"key": key}, {"disabled": is_computer}), SEP,
		row("Move to Trash", "group.trash" if is_computer else "item.trash", a, {"disabled": none}),
		row("Edit Name", "group.rename" if is_computer else "item.rename", a, {"disabled": none}),
		row("Get Info", "group.info" if is_computer else "item.info", a, {"disabled": none}), SEP,
		row("Close", "window.close", {"key": key})]
	var edit := [row("Undo", "none", {}, {"disabled": true}), SEP, row("Cut", "none", {}, {"disabled": true}),
		row("Copy", "none", {}, {"disabled": true}), row("Paste", "none", {}, {"disabled": true}), SEP,
		row("Select All", "none", {}, {"disabled": true}), row("Invert Selection", "none", {}, {"disabled": true})]
	var view_rows := []
	for v in VIEWS:
		view_rows.append(row(v[1], "window.view", {"key": key, "view": v[0]}, {"dot": view == v[0]}))
	view_rows.append_array([SEP, row("Clean Up", "window.cleanup", {"key": key}), row("Refresh", "window.refresh", {"key": key})])
	var help := [row("Help Topics", "help.open"), SEP, row("About Program Manager", "about.open")]
	return [{"id": "file", "label": "File", "items": file}, {"id": "edit", "label": "Edit", "items": edit},
		{"id": "view", "label": "View", "items": view_rows}, {"id": "help", "label": "Help", "items": help}]


## Deskbar (logo) menu: [icon-key, label, action] rows.
## `buckets` = LaunchGroups.collect_launch_groups(): when given (even empty) Launch All and one
## "Launch Group N" row per used number are listed, like the Classic Mac OS Special menu.
static func deskbar_menu(buckets: Variant = null) -> Array:
	var out := [
		row("About Program Manager...", "about.open", {}, {"icon": "logo"}), SEP,
		row("Find...", "find.open", {}, {"icon": "find"}), row("Run...", "run.open", {}, {"icon": "terminal"}),
		row("Launcher Tools...", "tools.open", {}, {"icon": "tools"}), row("Backgrounds...", "backgrounds.open", {}, {"icon": "tools"})]
	if buckets is Array:
		out.append(SEP)
		out.append(row("Launch All", "launch.all", {}, {"icon": "terminal", "disabled": buckets.is_empty()}))
		for b in buckets:
			var c: int = b.items.size()
			out.append(row("Launch Group %d (%d %s)" % [int(b.groupNumber), c, "item" if c == 1 else "items"],
				"launch.group", {"n": int(b.groupNumber)}, {"icon": "terminal"}))
	out.append_array([row("Help", "help.open", {}, {"icon": "question"}), SEP,
		row("Restart", "session.restart", {}, {"icon": "info"}), row("Shut Down...", "session.shutdown", {}, {"icon": "critical"})])
	return out


## Right-click on the Deskbar logo button.
static func deskbar_context_menu() -> Array:
	return [row("About Program Manager…", "about.open"), row("Launcher Tools…", "tools.open")]
