class_name Win95Desktop
extends Control
## The desktop work area (port of Win95Desktop.tsx): teal background, My Computer / Network
## Neighborhood / Recycle Bin icons with persisted positions (settings.win95DesktopIconPositions),
## selection (Ctrl/Shift, marquee, keyboard, type-to-select), manual placement, Line Up /
## Auto Arrange, desktop + icon context menus, and the host of all primary windows.
## Windows are children (z-order == child order); the Move/Size outline layer sits above them.

const M := Win95Tokens.M
const ICONS := [
	{"id": "my-computer", "label": "My Computer"},
	{"id": "network-neighborhood", "label": "Network Neighborhood"},
	{"id": "recycle-empty", "label": "Recycle Bin"},
]
const DEFAULT_POSITIONS := {
	"my-computer": Vector2(4, 4),
	"network-neighborhood": Vector2(4, 78),
	"recycle-empty": Vector2(4, 152),
}
const CELL := Vector2(75, 74)

var shell: Control
var selection: Dictionary = Win95SelectionState.empty()
var positions: Dictionary = {}

var _windows: Dictionary = {}          ## entry id -> Win95Window
var _drag: Dictionary = {}
var _marquee: Dictionary = {}
var _marquee_layer: Win95DifferenceLayer
var _outline_layer: Win95DifferenceLayer
var _menu: Win95Menu
var _type_prefix := ""
var _type_at := 0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(p_shell: Control) -> void:
	shell = p_shell
	_load_positions()
	_marquee_layer = Win95DifferenceLayer.new()
	add_child(_marquee_layer)
	_outline_layer = Win95DifferenceLayer.new()
	add_child(_outline_layer)
	shell.windows.changed.connect(sync_windows)
	ProgramStore.groups_changed.connect(sync_windows)
	ProgramStore.settings_changed.connect(_on_settings)
	shell.input.register_key("desktop", "desktop", _on_key)
	add_to_group("pm_auto")
	resized.connect(sync_windows)
	sync_windows()


func _exit_tree() -> void:
	if ProgramStore.groups_changed.is_connected(sync_windows):
		ProgramStore.groups_changed.disconnect(sync_windows)
	if ProgramStore.settings_changed.is_connected(_on_settings):
		ProgramStore.settings_changed.disconnect(_on_settings)


func _load_positions() -> void:
	var saved: Variant = ProgramStore.settings.get("win95DesktopIconPositions", {})
	positions = {}
	for icon in ICONS:
		var p: Variant = saved.get(icon.id) if Jsonx.is_obj(saved) else null
		positions[icon.id] = Vector2(float(p.x), float(p.y)) if Jsonx.is_obj(p) else DEFAULT_POSITIONS[icon.id]


func _on_settings() -> void:
	queue_redraw()


func selection_active() -> bool:
	return shell.host_focused and shell.windows.active_window_id == ""


# ------------------------------------------------------------------- windows

func sync_windows() -> void:
	if shell == null:
		return
	var store: Win95WindowStore = shell.windows
	var valid := {}
	for g in ProgramStore.groups:
		valid["group:" + String(g.id)] = true
	for e in store.windows.duplicate():
		if e.kind == "group" and not valid.has(e.id):
			store.close_window(e.id)
			return  # close_window re-emits changed
	var seen := {}
	for e in store.windows:
		seen[e.id] = true
		if not _windows.has(e.id):
			var w := Win95Window.new()
			add_child(w)
			w.setup(shell, e)
			_windows[e.id] = w
	for id in _windows.keys():
		if not seen.has(id):
			var w: Win95Window = _windows[id]
			_windows.erase(id)
			w.close_menus()
			w.queue_free()
	var ordered := store.by_z()
	for e in ordered:
		var w: Win95Window = _windows[e.id]
		move_child(w, get_child_count() - 1)
	move_child(_outline_layer, get_child_count() - 1)  # outline stays above every window
	for e in store.windows:
		(_windows[e.id] as Win95Window).refresh()
	queue_redraw()


func window_for(id: String) -> Win95Window:
	return _windows.get(id)


func set_outline(r: Dictionary) -> void:
	if r.is_empty():
		_outline_layer.set_rects([])
	else:
		_outline_layer.set_rects([{"rect": Win95Geometry.to_rect2(r), "thickness": 2}])


# ------------------------------------------------------------------- drawing

func _icon_cell(id: String) -> Rect2:
	return Rect2(positions[id], Vector2(M.desktopCellWidth, 70))


func _draw() -> void:
	Win95Draw.fill(self, Rect2(Vector2.ZERO, size), Pal.W95_DESKTOP)
	var selected := {}
	for s in selection.selected:
		selected[s] = true
	var active := selection_active()
	for icon in ICONS:
		_draw_icon(icon, positions[icon.id], selected.has(icon.id), selection.focused == icon.id, active, 1.0)
	if not _drag.is_empty() and _drag.moved:
		for id in _drag.ids:
			var icon: Dictionary = ICONS.filter(func(i): return i.id == id)[0]
			_draw_icon(icon, _drag.origins[id] + _drag.delta, false, false, true, 0.55)


func _draw_icon(icon: Dictionary, p: Vector2, selected: bool, focused: bool, active: bool, alpha: float) -> void:
	var tex := Win95IconCatalog.texture(icon.id, "large")
	var ipos := Vector2(p.x + 21, p.y)
	Win95Draw.icon(self, tex, ipos, Color(1, 1, 1, alpha))
	var blend := Win95Draw.SELECTED if active else Win95Draw.SHADOW
	if selected:
		Win95Draw.icon_selection(self, tex, ipos, blend)
	var lines := Win95Draw.font().wrap(icon.label, 71)
	var text_w := 1
	for l in lines:
		text_w = maxi(text_w, Win95Draw.measure(l))
	var box_w := text_w + 4
	var box := Rect2(p.x + 2 + 2 + int((71 - box_w + 1) / 2) - 2, p.y + 37, box_w, maxi(13, lines.size() * 13) + 2)
	if selected:
		Win95Draw.fill(self, box, blend)
	var col := Color(1, 1, 1, alpha)
	Win95Draw.text(self, Vector2(box.position.x + 3, box.position.y + 1), icon.label, col,
		{"max_width": 71, "wrap": true, "desktop_shadow": not selected})
	if focused:
		Win95Draw.dotted_rect(self, box, Color.WHITE)


# -------------------------------------------------------------------- input

func _icon_at(p: Vector2) -> String:
	for i in range(ICONS.size() - 1, -1, -1):
		if _icon_cell(ICONS[i].id).has_point(p):
			return ICONS[i].id
	return ""


func _spatial_items() -> Array:
	return ICONS.map(func(i): return {"id": i.id, "x": positions[i.id].x, "y": positions[i.id].y, "width": CELL.x, "height": CELL.y})


func _icon_ids() -> Array:
	return ICONS.map(func(i): return i.id)


func _close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.close()
	_menu = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb)
			else:
				_release()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_context(mb)
			accept_event()
	elif event is InputEventMouseMotion:
		_motion(event as InputEventMouseMotion)


func _select_icon(id: String, ctrl: bool, shift: bool) -> void:
	shell.windows.activate_desktop()
	selection = Win95SelectionState.select_item(selection, id, _icon_ids(), {"ctrl": ctrl, "shift": shift})
	queue_redraw()


func _press(mb: InputEventMouseButton) -> void:
	var id := _icon_at(mb.position)
	if id != "":
		var before: Array = selection.selected.duplicate()
		_select_icon(id, mb.ctrl_pressed, mb.shift_pressed)
		var ids: Array = before if before.has(id) else [id]
		var origins := {}
		for i in ids:
			origins[i] = positions[i]
		_drag = {"ids": ids, "start": mb.position, "origins": origins, "delta": Vector2.ZERO, "moved": false}
		if mb.double_click:
			_drag = {}
			open_icon(id)
		return
	shell.windows.activate_desktop()
	_close_menu()
	var base: Array = selection.selected.duplicate() if mb.ctrl_pressed else []
	if not mb.ctrl_pressed:
		selection = Win95SelectionState.empty()
	_marquee = {"start": mb.position, "rect": {"x": mb.position.x, "y": mb.position.y, "width": 0, "height": 0}, "base": base}
	_update_marquee()
	queue_redraw()


func _update_marquee() -> void:
	if _marquee.is_empty():
		_marquee_layer.set_rects([])
	else:
		_marquee_layer.set_rects([{"rect": Win95Geometry.to_rect2(_marquee.rect), "thickness": 1}])


func _motion(mm: InputEventMouseMotion) -> void:
	if not _drag.is_empty():
		_drag.delta = mm.position - _drag.start
		if not _drag.moved and absf(_drag.delta.x) + absf(_drag.delta.y) > 3:
			_drag.moved = true
			shell.set_dragging(true)
		queue_redraw()
	elif not _marquee.is_empty():
		_marquee.rect = Win95SelectionState.normalize_marquee(_marquee.start, mm.position)
		var hit := Win95SelectionState.items_in_marquee(_spatial_items(), _marquee.rect)
		var sel: Array = _marquee.base.duplicate()
		for h in hit:
			if not sel.has(h):
				sel.append(h)
		selection = {"selected": sel, "focused": String(hit[hit.size() - 1]) if hit.size() > 0 else selection.focused, "anchor": selection.anchor}
		_update_marquee()
		queue_redraw()


func _release() -> void:
	if not _drag.is_empty():
		var d := _drag
		_drag = {}
		shell.set_dragging(false)
		queue_redraw()
		if d.moved:
			if ProgramStore.settings.get("autoArrange", true):
				auto_arrange()
				return
			var next := positions.duplicate()
			for id in d.ids:
				var o: Vector2 = d.origins[id]
				next[id] = Vector2(
					Win95ShellInput.js_round(maxf(0.0, minf(size.x - M.desktopCellWidth, o.x + d.delta.x))),
					Win95ShellInput.js_round(maxf(0.0, minf(size.y - M.desktopCellHeight, o.y + d.delta.y))))
			persist_positions(next)
		return
	if not _marquee.is_empty():
		_marquee = {}
		_update_marquee()


func _context(mb: InputEventMouseButton) -> void:
	_close_menu()
	shell.windows.activate_desktop()
	var id := _icon_at(mb.position)
	if id != "" and not selection.selected.has(id):
		selection = {"selected": [id], "focused": id, "anchor": id}
	queue_redraw()
	_open_context(mb.position, id)


func _open_context(at: Vector2, icon_id: String) -> void:
	_close_menu()
	_menu = Win95Menu.open(shell, _icon_menu(icon_id) if icon_id != "" else _desktop_menu(), at, {"on_close": func(): _menu = null})


# ---------------------------------------------------------------- commands

func open_icon(id: String) -> void:
	if id == "my-computer":
		shell.windows.open_my_computer()
	elif id == "network-neighborhood":
		Win95Dialogs.show_message(shell, "Network Neighborhood", "Network browsing is not available in this application launcher.", "warning")
	else:
		Win95Dialogs.show_message(shell, "Recycle Bin", "The launcher does not store deleted files in the Recycle Bin.", "warning")


func persist_positions(next: Dictionary) -> void:
	positions = next
	var out := {}
	for k in next:
		out[k] = {"x": next[k].x, "y": next[k].y}
	ProgramStore.update_settings({"win95DesktopIconPositions": out})
	queue_redraw()


func line_up() -> void:
	var ordered := _icon_ids()
	ordered.sort_custom(func(a, b):
		if positions[a].y != positions[b].y:
			return positions[a].y < positions[b].y
		return positions[a].x < positions[b].x)
	var occupied := {}
	var next := positions.duplicate()
	for index in ordered.size():
		var id: String = ordered[index]
		var pt := Win95SelectionState.snap_position(positions[id], CELL)
		pt.x = maxf(4.0, minf(size.x - M.desktopCellWidth, pt.x))
		pt.y = maxf(4.0, minf(size.y - M.desktopCellHeight, pt.y))
		while occupied.has("%d:%d" % [pt.x, pt.y]):
			pt = Vector2(4 + (index / 6) * M.desktopCellWidth, 4 + (index % 6) * M.desktopCellHeight)
			if not occupied.has("%d:%d" % [pt.x, pt.y]):
				break
			pt.y += M.desktopCellHeight
		occupied["%d:%d" % [pt.x, pt.y]] = true
		next[id] = pt
	persist_positions(next)


func auto_arrange() -> void:
	persist_positions(DEFAULT_POSITIONS.duplicate())


func _desktop_menu() -> Array:
	var auto: bool = ProgramStore.settings.get("autoArrange", true)
	return [
		{"id": "arrange", "label": "&Arrange Icons", "children": [
			{"id": "name", "label": "by &Name", "onSelect": line_up},
			{"id": "type", "label": "by &Type", "disabled": true},
			{"id": "sep-auto", "separator": true},
			{"id": "auto", "label": "&Auto Arrange", "checked": auto, "onSelect": func():
				var enabled: bool = not ProgramStore.settings.get("autoArrange", true)
				ProgramStore.update_settings({"autoArrange": enabled})
				if enabled:
					auto_arrange()},
		]},
		{"id": "line-up", "label": "Line &Up Icons", "onSelect": line_up},
		{"id": "sep-1", "separator": true},
		{"id": "paste", "label": "&Paste", "disabled": true},
		{"id": "paste-shortcut", "label": "Paste &Shortcut", "disabled": true},
		{"id": "sep-2", "separator": true},
		{"id": "new-folder", "label": "&New Folder...", "onSelect": func(): Win95Dialogs.open_new_folder(shell, {})},
		{"id": "new-shortcut", "label": "New &Shortcut...", "icon": "new-shortcut", "onSelect": func():
			if ProgramStore.groups.size() > 0:
				Win95Dialogs.open_wizard(shell, {"groupId": ProgramStore.groups[0].id})
			else:
				Win95Dialogs.open_new_folder(shell, {"openItemAfterCreate": true})},
		{"id": "sep-3", "separator": true},
		{"id": "properties", "label": "P&roperties", "icon": "properties", "onSelect": func(): shell.request_show_launcher_tools.emit()},
	]


func _icon_menu(icon_id: String) -> Array:
	return [
		{"id": "open", "label": "&Open", "defaultItem": true, "onSelect": func(): open_icon(icon_id)},
		{"id": "sep", "separator": true},
		{"id": "properties", "label": "P&roperties", "icon": "properties", "onSelect": func():
			var label := String(ICONS.filter(func(i): return i.id == icon_id)[0].label)
			Win95Dialogs.show_message(shell, label, "No additional properties are available for this launcher object.", "information")},
	]


# ---------------------------------------------------------------------- keys

func _on_key(event: Dictionary) -> bool:
	if shell.windows.active_window_id != "":
		return false
	var key: String = event.key
	var ctrl: bool = event.get("ctrlKey", false)
	var shift: bool = event.get("shiftKey", false)
	var focused: String = selection.focused if selection.focused != "" else (String(selection.selected[0]) if selection.selected.size() > 0 else "")
	var ids := _icon_ids()
	if ctrl and key.to_lower() == "a":
		selection = Win95SelectionState.select_all(ids)
		queue_redraw()
		return true
	if key == "Enter" and focused != "":
		open_icon(focused)
		return true
	if (key == "ContextMenu" or (shift and key == "F10")) and focused != "":
		_open_context(Vector2(positions[focused].x, positions[focused].y + 35), focused)
		return true
	if key == "Escape":
		_close_menu()
		selection = Win95SelectionState.empty()
		queue_redraw()
		return true
	if key == " " and focused != "":
		selection = Win95SelectionState.select_item(selection, focused, ids, {"ctrl": ctrl})
		queue_redraw()
		return true
	if key in ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"]:
		var nxt := Win95SelectionState.find_directional_item(_spatial_items(), focused, key.replace("Arrow", "").to_lower())
		if nxt == "":
			return true
		if ctrl:
			selection = selection.duplicate()
			selection["focused"] = nxt
		else:
			selection = Win95SelectionState.select_item(selection, nxt, ids, {"shift": shift})
		queue_redraw()
		return true
	if key == "Home" or key == "End":
		var id: String = ids[0] if key == "Home" else ids[ids.size() - 1]
		selection = Win95SelectionState.select_item(selection, id, ids, {"shift": shift, "ctrl": ctrl})
		queue_redraw()
		return true
	if key.length() == 1 and not ctrl and not event.get("altKey", false) and not event.get("metaKey", false):
		var now := Time.get_ticks_msec()
		_type_prefix = key if now - _type_at > 1000 else _type_prefix + key
		_type_at = now
		var match := Win95SelectionState.find_type_match(ICONS, _type_prefix, focused)
		if match != "":
			selection = {"selected": [match], "focused": match, "anchor": match}
			queue_redraw()
			return true
	return false


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if id.begins_with("w95.desktop-icon:"):
		var key := id.get_slice(":", 1)
		if key == "first":
			key = "my-computer"
		if positions.has(key):
			return Rect2(global_position + positions[key], Vector2(M.desktopCellWidth, 70))
	return null
