class_name Win31MdiClient
extends Control
## The white MDI work area (Win31MDIContainer.tsx, .wfw-mdi-client): hosts one Win31GroupWindow per
## group, the minimized group icons, Cascade/Tile/Arrange Icons, window activation and the
## drop targets for program-item drags and OS file drops.
## Geometry convention (as in the TS): children are positioned relative to the 1px-inset inner
## area, while `client_size()` is the border-box size used for every clamp.

signal launch_requested(item: Dictionary)

var popup_layer: Control
var windows := {}      ## group id -> Win31GroupWindow
var icons := {}        ## group id -> Win31GroupIcon

var _inner: Control
var _overlay: Control
var _ghost := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	_inner = Control.new()
	_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	_inner.clip_contents = true
	add_child(_inner)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_inner.add_child(_overlay)
	popup_layer = Control.new()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(popup_layer)
	add_to_group("pm_auto")


func _ready() -> void:
	MdiState.windows_changed.connect(_restack)
	MdiState.cascade_requested.connect(cascade)
	MdiState.tile_requested.connect(tile)
	MdiState.arrange_icons_requested.connect(arrange_icons)


func _exit_tree() -> void:
	for sig in [[MdiState.windows_changed, _restack], [MdiState.cascade_requested, cascade],
			[MdiState.tile_requested, tile], [MdiState.arrange_icons_requested, arrange_icons]]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])


func client_size() -> Vector2:
	return Vector2(maxf(1.0, size.x), maxf(1.0, size.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _inner != null:
		apply_layout()


func apply_layout() -> void:
	_inner.position = Vector2(1, 1)
	_inner.size = Vector2(maxf(0.0, size.x - 2), maxf(0.0, size.y - 2))
	_overlay.size = _inner.size
	popup_layer.size = _inner.size
	refresh_all()


func _draw() -> void:
	Win31Chrome.client_edge(self, Rect2(Vector2.ZERO, size))


# ------------------------------------------------------------------- sync

## Mirrors the TS effect: every group gets an MDI window record, stale ones close, and the active
## window must be a visible group (otherwise the last non-minimized group).
func sync_mdi_state() -> void:
	var groups: Array = ProgramStore.groups
	var known := {}
	for w in MdiState.windows:
		known[w.groupId] = true
	var ids := {}
	for g in groups:
		ids[g.id] = true
	for g in groups:
		if not known.has(g.id):
			MdiState.open_window(g.id)
	for id in known.keys():
		if not ids.has(id):
			MdiState.close_window(id)
	var active_visible := false
	for g in groups:
		if g.id == MdiState.active_window_id and not Win31Commands.is_minimized(g):
			active_visible = true
	if not active_visible:
		var next := ""
		for i in range(groups.size() - 1, -1, -1):
			if not Win31Commands.is_minimized(groups[i]):
				next = groups[i].id
				break
		MdiState.set_active_window(next)


## Re-reads groups: creates/removes child nodes, applies geometry, restacks.
func refresh_all() -> void:
	if _inner == null:
		return
	sync_mdi_state()
	var ids := {}
	for g in ProgramStore.groups:
		ids[g.id] = true
		if not windows.has(g.id):
			var w := Win31GroupWindow.new()
			w.group_id = g.id
			w.client = self
			w.activate_requested.connect(_on_activate)
			w.maximize_requested.connect(_on_maximize)
			w.launch_requested.connect(func(item): launch_requested.emit(item))
			_inner.add_child(w)
			windows[g.id] = w
		if not icons.has(g.id):
			var ic := Win31GroupIcon.new()
			ic.group_id = g.id
			ic.client = self
			ic.restore_requested.connect(restore_group)
			_inner.add_child(ic)
			icons[g.id] = ic
	for id in windows.keys():
		if not ids.has(id):
			windows[id].queue_free()
			windows.erase(id)
			icons[id].queue_free()
			icons.erase(id)
	for id in windows:
		windows[id].apply_state()
	refresh_icons()
	_restack()
	queue_redraw()


func refresh_icons() -> void:
	var minimized := Win31Commands.minimized_groups(ProgramStore.groups)
	var cs := client_size()
	var cols := Win31Arrange.icon_columns(cs.x)
	for g in ProgramStore.groups:
		icons[g.id].visible = false
	for i in minimized.size():
		var g: Dictionary = minimized[i]
		var stored: Variant = g.get("win31IconPosition")
		var p: Vector2
		if stored != null:
			p = Vector2(float(stored.x), float(stored.y))
		else:
			p = Vector2(Win31Arrange.icon_fallback_position(i, cols, cs.y))
		var icon: Win31GroupIcon = icons[g.id]
		icon.visible = true
		icon.position = Vector2(Win31Arrange.clamp_icon_position(p, cs.x, cs.y))
		icon.size = Win31GroupIcon.CELL
		icon.queue_redraw()


## Stacks windows by MdiState z-index; icons above all windows (z-index 10000), then overlays.
func _restack() -> void:
	if _inner == null:
		return
	var order := MdiState.windows.duplicate()
	order.sort_custom(func(a, b): return a.zIndex < b.zIndex)
	for w in order:
		if windows.has(w.groupId):
			_inner.move_child(windows[w.groupId], _inner.get_child_count() - 1)
	for g in ProgramStore.groups:
		if icons.has(g.id):
			_inner.move_child(icons[g.id], _inner.get_child_count() - 1)
	_inner.move_child(_overlay, _inner.get_child_count() - 1)
	_inner.move_child(popup_layer, _inner.get_child_count() - 1)
	for id in windows:
		var win: Win31GroupWindow = windows[id]
		var is_active: bool = MdiState.active_window_id == id
		if win.active != is_active:
			win.active = is_active
			win.queue_redraw()


# ---------------------------------------------------------------- commands

## Store write for the group's win31 window state, then repaint (the store's geometry writes are
## quiet, so the UI refreshes itself like a Zustand re-render).
func update_state(group_id: String, updates: Dictionary) -> void:
	ProgramStore.update_group_window_state(group_id, updates, "win31")
	sync_mdi_state()
	if windows.has(group_id):
		windows[group_id].apply_state()
	refresh_icons()
	_restack()


func _on_activate(group_id: String) -> void:
	MdiState.focus_window(group_id)
	UIState.clear_selection()


func _on_maximize(group_id: String) -> void:
	for g in ProgramStore.groups:
		if g.id != group_id and Types.get_group_window_state(g, "win31").get("maximized", false):
			ProgramStore.update_group_window_state(g.id, {"maximized": false}, "win31")
	MdiState.focus_window(group_id)
	refresh_all()


func restore_group(group_id: String) -> void:
	update_state(group_id, {"minimized": false})
	MdiState.focus_window(group_id)
	UIState.clear_selection()
	refresh_all()


func cascade() -> void:
	var restorable := Win31Commands.visible_groups(ProgramStore.groups)
	if restorable.is_empty():
		return
	var cs := client_size()
	var reserved := Win31Arrange.reserved_bottom(Win31Commands.minimized_groups(ProgramStore.groups).size(), cs.x)
	var layout := Win31Arrange.cascade(restorable.size(), cs.x, cs.y, reserved)
	for i in restorable.size():
		_apply_layout(restorable[i].id, layout[i])
	refresh_all()


func tile() -> void:
	var restorable := Win31Commands.visible_groups(ProgramStore.groups)
	if restorable.is_empty():
		return
	var cs := client_size()
	var reserved := Win31Arrange.reserved_bottom(Win31Commands.minimized_groups(ProgramStore.groups).size(), cs.x)
	var layout := Win31Arrange.tile(restorable.size(), cs.x, cs.y, reserved)
	for i in restorable.size():
		_apply_layout(restorable[i].id, layout[i])
	refresh_all()


func _apply_layout(group_id: String, r: Rect2) -> void:
	ProgramStore.update_group_window_state(group_id, {
		"x": int(r.position.x), "y": int(r.position.y), "width": int(r.size.x), "height": int(r.size.y), "maximized": false,
	}, "win31")


func arrange_icons() -> void:
	var minimized := Win31Commands.minimized_groups(ProgramStore.groups)
	var cs := client_size()
	var layout := Win31Arrange.arrange_icons(minimized.size(), cs.x, cs.y)
	for i in minimized.size():
		ProgramStore.update_group_icon_position(minimized[i].id, {"x": layout[i].x, "y": layout[i].y})
	refresh_all()


## Alt+- : the active window's control menu.
func open_active_system_menu() -> void:
	var id := MdiState.active_window_id
	if windows.has(id) and windows[id].visible:
		windows[id].open_system_menu()


func has_open_system_menu() -> bool:
	for id in windows:
		if windows[id].has_system_menu():
			return true
	return false


# ------------------------------------------------------------- pointer input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UIState.clear_selection()  # pointerdown on the client itself (event.target === root)
		grab_focus()


# ------------------------------------------------------------ drag and drop

func _inner_origin() -> Vector2:
	return _inner.get_global_rect().position


## [{groupId, rect}] of visible group windows, bottom -> top, in inner coordinates.
func _window_entries() -> Array:
	var out := []
	for child in _inner.get_children():
		if child is Win31GroupWindow and child.visible:
			out.append({"groupId": child.group_id, "rect": Rect2(child.position, child.size)})
	return out


func _icon_entries() -> Array:
	var out := []
	for child in _inner.get_children():
		if child is Win31GroupIcon and child.visible:
			out.append({"groupId": child.group_id, "rect": Rect2(child.position, child.size)})
	return out


## Group under a logical (global) position, or "". Icons win over windows.
func drop_target_at(global_pos: Vector2) -> String:
	return Win31Arrange.drop_target(_window_entries(), _icon_entries(), global_pos - _inner_origin())


func item_drag_update(from_group: String, item: Dictionary, global_pos: Vector2) -> void:
	var settings: Dictionary = ProgramStore.settings
	var inside_origin := drop_target_at(global_pos) == from_group
	if inside_origin and not bool(settings.get("autoArrange", true)):
		_ghost = {}
	else:
		_ghost = {"item": item, "pos": global_pos - _inner_origin(), "ok": drop_target_at(global_pos) != "" and not inside_origin}
	_overlay.queue_redraw()


## Called when an item drag is released. Returns true when the item was moved/copied into another
## group (Ctrl copies, like the original Program Manager).
func item_drag_end(from_group: String, item: Dictionary, global_pos: Vector2, ctrl: bool) -> bool:
	_ghost = {}
	_overlay.queue_redraw()
	var target := drop_target_at(global_pos)
	if target == "" or target == from_group:
		return false
	if ctrl:
		ProgramStore.copy_item(from_group, target, item.id)
		UIState.clear_selection()
	else:
		ProgramStore.move_item(from_group, target, item.id)
		UIState.set_win31_selection({"kind": "item", "groupId": target, "itemId": item.id})
		UIState.set_selected_item(item.id, target)
	refresh_all()
	return true


func _draw_overlay() -> void:
	if _ghost.is_empty():
		return
	var p: Vector2 = _ghost.pos - Vector2(37, 16)
	Win31ItemGrid.draw_item(_overlay, _ghost.item, p.floor(), false, false, String(ProgramStore.settings.get("labelDisplay", "wrap")))


## OS file drop at a logical position: adds an item per file to the group window under it.
## Coroutine (get_app_info may await). Returns the number of items added.
func add_dropped_files(files: PackedStringArray, logical_pos: Vector2) -> int:
	var target := drop_target_at(logical_pos)
	if target == "":
		return 0
	var added := 0
	for path in files:
		var info: Dictionary = await Platform.get_app_info(path)
		var item := Win31Drop.item_from_app_info(path, info)
		ProgramStore.add_item(target, item)
		added += 1
	refresh_all()
	return added


# ------------------------------------------------------------- automation

## Automation ids: first program item, first minimized group icon, child caption buttons.
func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return null
	if id == "wfw.program-item:first":
		for g in ProgramStore.groups:
			if windows.has(g.id) and windows[g.id].visible and g.items.size() > 0:
				return windows[g.id].grid.item_global_rect(0)
		return null
	if id.begins_with("wfw.program-item:"):
		var item_id := id.substr(17)
		for g in ProgramStore.groups:
			for i in g.items.size():
				if g.items[i].id == item_id and windows.has(g.id) and windows[g.id].visible:
					return windows[g.id].grid.item_global_rect(i)
		return null
	if id == "wfw.minimized-group:first":
		for g in ProgramStore.groups:
			if icons.has(g.id) and icons[g.id].visible:
				return icons[g.id].get_global_rect()
		return null
	if id.begins_with("wfw.minimized-group:"):
		var gid := id.substr(20)
		if icons.has(gid) and icons[gid].visible:
			return icons[gid].get_global_rect()
		return null
	if id.begins_with("wfw.child-window:button:"):
		var label := id.substr(24)
		var win := _auto_window()
		if win != null:
			var r := win.button_global_rect(label)
			if r.size != Vector2.ZERO:
				return r
		return null
	if id.begins_with("wfw.child-window:caption"):
		var win2 := _auto_window()
		if win2 != null:
			return Rect2(win2.get_global_rect().position + win2.caption_rect().position, win2.caption_rect().size)
		return null
	if id.begins_with("wfw.window:"):
		var wid := id.substr(11)
		if windows.has(wid) and windows[wid].visible:
			return windows[wid].get_global_rect()
		return null
	return null


## The active visible group window, else the first visible one.
func _auto_window() -> Win31GroupWindow:
	var active: Win31GroupWindow = windows.get(MdiState.active_window_id)
	if active != null and active.visible:
		return active
	for g in ProgramStore.groups:
		if windows.has(g.id) and windows[g.id].visible:
			return windows[g.id]
	return null
