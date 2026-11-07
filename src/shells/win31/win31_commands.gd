class_name Win31Commands
extends RefCounted
## Pure logic behind the Program Manager menus and shortcuts. Port of the command tree in
## Win31MenuBar.tsx / commands.ts and the command/selection helpers in Win31Shell.tsx.
## Menu items are Dictionaries: {command, label, disabled?, checked?} or {separator: true}.


# ----------------------------------------------------------------- selection

## {group: Dictionary, item: Dictionary}; both empty when nothing is selected.
static func selected_objects(groups: Array, selection: Dictionary, active_group_id: String) -> Dictionary:
	var kind := String(selection.get("kind", ""))
	if kind == "item":
		var group := _find_group(groups, String(selection.get("groupId", "")))
		var item := {}
		for it in group.get("items", []):
			if it.id == selection.get("itemId", ""):
				item = it
		return {"group": group, "item": item}
	if kind == "groupIcon":
		return {"group": _find_group(groups, String(selection.get("groupId", ""))), "item": {}}
	return {"group": _find_group(groups, active_group_id), "item": {}}


static func _find_group(groups: Array, id: String) -> Dictionary:
	for g in groups:
		if g.id == id:
			return g
	return {}


static func is_minimized(group: Dictionary) -> bool:
	return bool(Types.get_group_window_state(group, "win31").get("minimized", false))


static func visible_groups(groups: Array) -> Array:
	return groups.filter(func(g): return not is_minimized(g))


static func minimized_groups(groups: Array) -> Array:
	return groups.filter(func(g): return is_minimized(g))


# ------------------------------------------------------------ command state

## {disabled?: bool, checked?: bool}. `selection` is UIState.win31_selection.
static func command_state(command: String, groups: Array, selection: Dictionary, active_group_id: String, settings: Dictionary) -> Dictionary:
	var sel := selected_objects(groups, selection, active_group_id)
	match command:
		"open":
			return {"disabled": sel.item.is_empty() and selection.get("kind", "") != "groupIcon"}
		"move", "copy":
			return {"disabled": sel.item.is_empty() or groups.size() < 1}
		"delete", "properties":
			return {"disabled": sel.group.is_empty()}
		"cascade", "tile":
			return {"disabled": visible_groups(groups).is_empty()}
		"arrange-icons":
			return {"disabled": minimized_groups(groups).is_empty()}
		"auto-arrange":
			return {"checked": bool(settings.get("autoArrange", true))}
		"minimize-on-use":
			return {"checked": bool(settings.get("minimizeOnUse", false))}
		"save-settings":
			return {"checked": bool(settings.get("saveSettingsOnExit", true))}
	return {}


# ---------------------------------------------------------------- menu tree

## [[groupNumber, itemCount]] sorted by group number (only groups > 0).
static func launch_group_counts(groups: Array) -> Array:
	var counts := {}
	for g in groups:
		for it in g.items:
			var n := int(it.get("launchGroup", 0))
			if n > 0:
				counts[n] = int(counts.get(n, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append([k, counts[k]])
	return out


static func _item(command: String, label: String, state: Dictionary = {}) -> Dictionary:
	var d := {"command": command, "label": label}
	d.merge(state, true)
	return d


static func _sep() -> Dictionary:
	return {"separator": true}


## [{id, label, mnemonic, items}] for File / Options / Window / Launcher / Help.
static func build_menus(groups: Array, active_group_id: String, selection: Dictionary, settings: Dictionary) -> Array:
	var st := func(c: String) -> Dictionary: return command_state(c, groups, selection, active_group_id, settings)
	var launch := launch_group_counts(groups)

	var window_items := [
		_item("cascade", "&Cascade", st.call("cascade")),
		_item("tile", "&Tile", st.call("tile")),
		_item("arrange-icons", "&Arrange Icons", st.call("arrange-icons")),
	]
	if groups.size() > 0:
		window_items.append(_sep())
		for i in groups.size():
			var g: Dictionary = groups[i]
			window_items.append({
				"command": "group:" + String(g.id),
				"label": "%s%s" % [("&%d " % (i + 1)) if i < 9 else "", g.name],
				"checked": g.id == active_group_id,
			})

	var launcher_items := [_item("launch-all", "Launch &All", {"disabled": launch.is_empty()})]
	if not launch.is_empty():
		launcher_items.append(_sep())
		for pair in launch:
			launcher_items.append({
				"command": "launch-group:%d" % pair[0],
				"label": "Launch Group &%d (%d %s)" % [pair[0], pair[1], "item" if pair[1] == 1 else "items"],
			})
	launcher_items.append(_sep())
	launcher_items.append(_item("launcher-tools", "Launcher &Tools..."))

	return [
		{"id": "file", "label": "&File", "mnemonic": "f", "items": [
			_item("new", "&New..."),
			_item("open", "&Open", st.call("open")),
			_sep(),
			_item("move", "&Move...", st.call("move")),
			_item("copy", "&Copy...", st.call("copy")),
			_item("delete", "&Delete", st.call("delete")),
			_item("properties", "&Properties...", st.call("properties")),
			_sep(),
			_item("run", "&Run..."),
			_sep(),
			_item("exit", "E&xit Windows..."),
		]},
		{"id": "options", "label": "&Options", "mnemonic": "o", "items": [
			_item("auto-arrange", "&Auto Arrange", st.call("auto-arrange")),
			_item("minimize-on-use", "&Minimize on Use", st.call("minimize-on-use")),
			_item("save-settings", "&Save Settings on Exit", st.call("save-settings")),
		]},
		{"id": "window", "label": "&Window", "mnemonic": "w", "items": window_items},
		{"id": "launcher", "label": "&Launcher", "mnemonic": "l", "items": launcher_items},
		{"id": "help", "label": "&Help", "mnemonic": "h", "items": [
			_item("help-contents", "&Contents"),
			_item("help-search", "&Search for Help On..."),
			_item("help-using", "&How to Use Help"),
			_sep(),
			_item("about", "&About Program Manager..."),
		]},
	]


## Control menu shared by the outer frame ("outer-") and group windows ("child-").
static func system_items(prefix: String, maximized: bool) -> Array:
	return [
		_item(prefix + "restore", "&Restore", {"disabled": not maximized}),
		_item(prefix + "move", "&Move", {"disabled": maximized}),
		_item(prefix + "size", "&Size", {"disabled": maximized}),
		_item(prefix + "minimize", "Mi&nimize"),
		_item(prefix + "maximize", "Ma&ximize", {"disabled": maximized}),
		_sep(),
		_item(prefix + "close", "&Close"),
	]


## Lower-cased mnemonic of an "&Label" or "" when none.
static func mnemonic_of(label: String) -> String:
	var i := label.find("&")
	if i >= 0 and i + 1 < label.length():
		return label[i + 1].to_lower()
	return ""


## Indices of items that can be highlighted (not separators, not disabled).
static func enabled_indexes(items: Array) -> Array:
	var out := []
	for i in items.size():
		var it: Dictionary = items[i]
		if not it.get("separator", false) and not it.get("disabled", false):
			out.append(i)
	return out


## Arrow-key stepping inside a popup menu (Win31PopupMenu keydown handler). `dir` is +1/-1.
static func step_highlight(enabled: Array, highlighted: int, dir: int) -> int:
	if enabled.is_empty():
		return -1
	var current := maxi(0, enabled.find(highlighted))
	var n := enabled.size()
	return enabled[((current + dir) % n + n) % n]


## Index of the enabled item whose mnemonic equals `key` (lower-case), or -1.
static func mnemonic_match(items: Array, key: String) -> int:
	for i in items.size():
		var it: Dictionary = items[i]
		if not it.get("disabled", false) and not it.get("separator", false) and mnemonic_of(String(it.get("label", ""))) == key:
			return i
	return -1


# ------------------------------------------------------------------- keys

## JS `event.key.toLowerCase()` equivalent for a key event.
static func key_name(ev: InputEventKey) -> String:
	var code: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
	match code:
		KEY_SPACE:
			return " "
		KEY_ESCAPE:
			return "escape"
		KEY_ENTER, KEY_KP_ENTER:
			return "enter"
		KEY_MINUS, KEY_KP_SUBTRACT:
			return "-"
	return OS.get_keycode_string(code).to_lower()


## Win31Shell.tsx shortcutMatches: "Ctrl+Alt+F5"-style item shortcut keys.
static func shortcut_matches(shortcut: String, key: String, ctrl: bool, alt: bool, shift: bool, meta: bool) -> bool:
	if shortcut.strip_edges() == "":
		return false
	var parts: Array = []
	for p in shortcut.to_lower().split("+"):
		var t := p.strip_edges()
		if t != "":
			parts.append(t)
	if parts.is_empty():
		return false
	if key != parts[parts.size() - 1]:
		return false
	return ctrl == parts.has("ctrl") and alt == parts.has("alt") and shift == parts.has("shift") \
		and meta == (parts.has("meta") or parts.has("win"))


static func shortcut_matches_event(shortcut: String, ev: InputEventKey) -> bool:
	return shortcut_matches(shortcut, key_name(ev), ev.ctrl_pressed, ev.alt_pressed, ev.shift_pressed, ev.meta_pressed)


## Alt+<letter> menu accelerator (no ctrl/meta). Returns the menu id or "".
static func menu_for_accelerator(menus: Array, key: String) -> String:
	for m in menus:
		if m.mnemonic == key:
			return m.id
	return ""


## Keys the shell must not treat as item shortcuts (Win31Shell keyboard handler).
static func is_reserved_alt_key(key: String, ctrl: bool, shift: bool, meta: bool, alt: bool) -> bool:
	return alt and not ctrl and not shift and not meta and ["f", "o", "w", "l", "h", " ", "-", "enter"].has(key)


# ----------------------------------------------- keyboard Move / Size modes

## Desktop-mode Program Manager Move/Size keyboard step (beginDesktopKeyboardOperation).
## Returns the new bounds Dictionary or {} when the key is not an arrow.
static func desktop_key_step(mode: String, bounds: Dictionary, key: String, shift: bool) -> Dictionary:
	var b: Dictionary = bounds.duplicate()
	var step := 8 if shift else 1
	match key:
		"left":
			if mode == "move":
				b.x = maxi(0, int(b.x) - step)
			else:
				b.width = maxi(320, int(b.width) - step)
		"right":
			if mode == "move":
				b.x = int(b.x) + step
			else:
				b.width = int(b.width) + step
		"up":
			if mode == "move":
				b.y = maxi(0, int(b.y) - step)
			else:
				b.height = maxi(240, int(b.height) - step)
		"down":
			if mode == "move":
				b.y = int(b.y) + step
			else:
				b.height = int(b.height) + step
		_:
			return {}
	return b


## Host-window Move/Size keyboard step (beginHostKeyboardOperation); bounds are {x,y,width,height}.
static func host_key_step(mode: String, bounds: Dictionary, key: String, shift: bool) -> Dictionary:
	var b: Dictionary = bounds.duplicate()
	var step := 10 if shift else 1
	match key:
		"left":
			if mode == "move":
				b.x = int(b.x) - step
			else:
				b.width = maxi(400, int(b.width) - step)
		"right":
			if mode == "move":
				b.x = int(b.x) + step
			else:
				b.width = int(b.width) + step
		"up":
			if mode == "move":
				b.y = int(b.y) - step
			else:
				b.height = maxi(300, int(b.height) - step)
		"down":
			if mode == "move":
				b.y = int(b.y) + step
			else:
				b.height = int(b.height) + step
		_:
			return {}
	return b


## Group-window keyboard Move/Size step (Win31MDIWindow keyboardMode). `state` is the window state
## {x,y,width,height}; returns the partial update {x,y} or {width,height}, or {} for non-arrows.
static func child_key_step(mode: String, state: Dictionary, key: String, shift: bool, client_w: float, client_h: float) -> Dictionary:
	var step := 8 if shift else 1
	var dx := 0
	var dy := 0
	match key:
		"left":
			dx = -step
		"right":
			dx = step
		"up":
			dy = -step
		"down":
			dy = step
		_:
			return {}
	if mode == "move":
		return {
			"x": int(maxf(0.0, minf(client_w - float(state.width), float(state.x + dx)))),
			"y": int(maxf(0.0, minf(client_h - 24.0, float(state.y + dy)))),
		}
	return {
		"width": int(maxf(150.0, minf(client_w - float(state.x), float(state.width + dx)))),
		"height": int(maxf(92.0, minf(client_h - float(state.y), float(state.height + dy)))),
	}


## Desktop drag of the Program Manager caption (beginDesktopDrag clamp + Math.round).
static func desktop_drag_bounds(start: Dictionary, dx: float, dy: float, logical_w: float, logical_h: float) -> Dictionary:
	var b: Dictionary = start.duplicate()
	b.x = Win31Arrange.js_round(maxf(0.0, minf(logical_w - 80.0, float(start.x) + dx)))
	b.y = Win31Arrange.js_round(maxf(0.0, minf(logical_h - 24.0, float(start.y) + dy)))
	return b


## Desktop-mode frame resize (mouse). Same 320x240 minimum as the keyboard Size mode; the origin
## stays fixed except for n/w edges which move it so the opposite edge stays put.
static func desktop_resize_bounds(start: Dictionary, direction: String, delta: Vector2) -> Dictionary:
	var x := int(start.x)
	var y := int(start.y)
	var w := int(start.width)
	var h := int(start.height)
	var dx := Win31Arrange.js_round(delta.x)
	var dy := Win31Arrange.js_round(delta.y)
	if direction.contains("e"):
		w = maxi(320, int(start.width) + dx)
	if direction.contains("s"):
		h = maxi(240, int(start.height) + dy)
	if direction.contains("w"):
		w = maxi(320, int(start.width) - dx)
		x = int(start.x) + int(start.width) - w
	if direction.contains("n"):
		h = maxi(240, int(start.height) - dy)
		y = int(start.y) + int(start.height) - h
	return {"x": maxi(0, x), "y": maxi(0, y), "width": w, "height": h}
