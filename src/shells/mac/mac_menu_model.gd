class_name MacMenuModel
extends RefCounted
## Pure menu definitions for the Mac shell (menu bar menus, context menus). An item is
## {id, label, disabled?, check?, key?} or {sep: true}; `id` is a command string the shell dispatches
## ("new-folder", "open-group:<gid>", "launch-group:<n>", ...). `key` is the Ctrl/Cmd+<letter> accelerator.
## ctx for menu_bar(): {groups, active_key, view, selected: {kind: ""|"item"|"group", groupId, itemId}, buckets}.

const SEP := {"sep": true}


static func item(id: String, label: String, opts: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "label": label}
	for k in opts:
		d[k] = opts[k]
	return d


static func is_sep(entry: Dictionary) -> bool:
	return entry.get("sep", false)


static func has_selection(ctx: Dictionary) -> bool:
	return String(ctx.get("selected", {}).get("kind", "")) != ""


static func menu_bar(ctx: Dictionary) -> Array:
	var sel: Dictionary = ctx.get("selected", {})
	var kind := String(sel.get("kind", ""))
	var has_sel := kind != ""
	var is_item := kind == "item"
	var active := String(ctx.get("active_key", ""))
	var view := String(ctx.get("view", ""))
	var buckets: Array = ctx.get("buckets", [])
	var logo_items := [
		item("about", "About Program Manager…"), SEP,
		item("tools", "Launcher Tools…"), item("desktop-pictures", "Desktop Pictures…"), item("find", "Find…", {"key": "F"}), SEP,
	]
	for g in ctx.get("groups", []):
		logo_items.append(item("open-group:" + String(g.id), String(g.name)))
	var special := [item("launch-all", "Launch All", {"disabled": buckets.is_empty()})]
	for b in buckets:
		var n := int(b.groupNumber)
		var c: int = b.items.size()
		special.append(item("launch-group:%d" % n, "Launch Group %d (%d %s)" % [n, c, "item" if c == 1 else "items"]))
	special.append_array([SEP, item("run", "Run…", {"key": "R"}), SEP, item("restart", "Restart"), item("shutdown", "Shut Down")])
	return [
		{"id": "logo", "label": "", "items": logo_items},
		{"id": "file", "label": "File", "items": [
			item("new-folder", "New Folder", {"key": "N"}),
			item("open", "Open", {"disabled": not has_sel, "key": "O"}),
			item("close-window", "Close Window", {"disabled": active == "", "key": "W"}), SEP,
			item("get-info", "Get Info", {"disabled": not has_sel, "key": "I"}),
			item("duplicate", "Duplicate", {"disabled": not is_item, "key": "D"}),
			item("trash", "Move To Trash", {"disabled": not has_sel, "key": "T"}), SEP,
			item("find", "Find…", {"key": "F"})]},
		{"id": "edit", "label": "Edit", "items": [
			item("undo", "Undo", {"disabled": true}), SEP,
			item("cut", "Cut", {"disabled": true}), item("copy", "Copy", {"disabled": true}),
			item("paste", "Paste", {"disabled": true}), item("clear", "Clear", {"disabled": true}),
			item("select-all", "Select All", {"disabled": true})]},
		{"id": "view", "label": "View", "items": [
			item("view:large", "as Icons", {"disabled": not _is_folder_view(active), "check": view == "large"}),
			item("view:details", "as List", {"disabled": not _is_folder_view(active), "check": view == "details"})]},
		{"id": "special", "label": "Special", "items": special},
		{"id": "help", "label": "Help", "items": [
			item("help", "Program Manager Help"), item("balloons", "Show Balloons", {"disabled": true})]},
	]


static func _is_folder_view(key: String) -> bool:
	return key == "computer" or key.begins_with("g:")


## Items of the Program Manager application menu (right end of the menu bar): Launcher Tools… then windows.
static func app_menu(windows: Array, active_key: String, titles: Dictionary) -> Array:
	var out := [item("tools", "Launcher Tools…"), SEP]
	for w in windows:
		out.append(item("raise:" + String(w.key), String(titles.get(w.key, w.key)), {"check": w.key == active_key, "icon": w.get("icon")}))
	return out


static func item_menu() -> Array:
	return [item("help", "Help"), SEP, item("open", "Open"), item("get-info", "Get Info"), item("trash", "Move To Trash"), SEP,
		item("duplicate", "Duplicate"), item("alias", "Make Alias"), item("rename", "Rename")]


static func group_menu() -> Array:
	return [item("help", "Help"), SEP, item("open", "Open"), item("get-info", "Get Info"), item("trash", "Move To Trash"), SEP,
		item("rename", "Rename")]


static func desktop_menu() -> Array:
	return [item("help", "Help"), SEP, item("new-folder", "New Folder"), item("clean-up", "Clean Up"), SEP,
		item("desktop-pictures", "Change Desktop Background…")]


static func desk_icon_menu(id: String) -> Array:
	if id == "trash":
		return [item("open", "Open"), item("empty-trash", "Empty Trash…", {"disabled": true})]
	return [item("help", "Help"), SEP, item("open", "Open"), item("get-info", "Get Info")]


static func folder_background_menu(is_computer: bool, view: String) -> Array:
	return [item("help", "Help"), SEP,
		item("new-folder" if is_computer else "new-program", "New Folder" if is_computer else "New Program…"),
		item("close-window", "Close Window"), SEP,
		item("view:large", "as Icons", {"check": view == "large"}), item("view:details", "as List", {"check": view == "details"}),
		item("clean-up", "Clean Up"), SEP, item("get-info", "Get Info")]


## Command id for a Ctrl/Cmd+<letter> accelerator, "" when none.
static func accelerator(keycode: int) -> String:
	match keycode:
		KEY_N: return "new-folder"
		KEY_O: return "open"
		KEY_W: return "close-window"
		KEY_I: return "get-info"
		KEY_D: return "duplicate"
		KEY_T: return "trash"
		KEY_F: return "find"
		KEY_R: return "run"
	return ""


## Label of an accelerator for display ("Cmd+N" on macOS, "Ctrl+N" elsewhere).
static func accelerator_text(letter: String, mac_os: bool) -> String:
	return ("Cmd+" if mac_os else "Ctrl+") + letter
