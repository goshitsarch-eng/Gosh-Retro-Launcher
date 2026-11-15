class_name MacDesktop
extends Control
## The Mac desktop surface: periwinkle background, the Launcher HD and Trash icons in the right-hand column,
## and one child control per open window (z-order mirrors MacWindowStore). Clicking the bare desktop clears the
## selection; right-click opens the desktop menu.

var shell: Control          ## MacShell
var store := MacWindowStore.new()
var desk_sel := ""          ## "computer" | "trash" | ""

var _windows := {}          ## key -> MacWindow
var _icon_rects: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("pm_auto")
	store.changed.connect(sync)
	resized.connect(_on_resized)


func setup(p_shell: Control) -> void:
	shell = p_shell
	sync()


func desk_size() -> Vector2:
	return size


func _on_resized() -> void:
	store.fit(size)
	queue_redraw()
	sync()


# ------------------------------------------------------------------ windows

func default_rect(key: String) -> Rect2:
	if key == "find":
		return Rect2(MacGeometry.cascade_rect(store.open_counter, size, Vector2(440, 310)))
	if key == "computer":
		return MacGeometry.cascade_rect(store.open_counter, size, Vector2(470, 300))
	return MacGeometry.cascade_rect(store.open_counter, size, Vector2(420, 290))


func open_window(key: String) -> void:
	if store.has(key):
		store.raise(key)
		if store.find(key).shaded:
			store.toggle_shade(key)
		return
	store.open(key, default_rect(key))


func close_window(key: String) -> void:
	store.close(key)


func activate_window(key: String) -> void:
	desk_sel = ""
	store.raise(key)
	queue_redraw()


func sync() -> void:
	for key in _windows.keys():
		if not store.has(key):
			var w: Control = _windows[key]
			_windows.erase(key)
			w.queue_free()
	for st in store.windows:
		var key: String = st.key
		if not _windows.has(key):
			var w: MacWindow = MacFindWindow.new() if key == "find" else MacFolderWindow.new()
			w.desk = self
			w.key = key
			_windows[key] = w
			add_child(w)
			if w is MacFindWindow:
				(w as MacFindWindow).setup()
		_windows[key].sync_from_store()
	var idx := 0
	for st in store.windows:
		move_child(_windows[st.key], idx)
		idx += 1
	for w in _windows.values():
		w.queue_redraw()
	queue_redraw()


func window_for(key: String) -> MacWindow:
	return _windows.get(key)


## Redraw everything (theme / data changes).
func refresh() -> void:
	store.close_where(func(w): return String(w.key).begins_with("g:") and ProgramStore.find_group(String(w.key).substr(2)).is_empty())
	for w in _windows.values():
		if w is MacFindWindow:
			(w as MacFindWindow).refresh_groups()
		w.queue_redraw()
		if w is MacFolderWindow:
			(w as MacFolderWindow).view.queue_redraw()
	queue_redraw()


# ------------------------------------------------------------------- entries

func entry_activated(win_key: String, id: String) -> void:
	if win_key == "computer":
		shell.open_group_window(id)
	else:
		var item := ProgramStore.find_item(win_key.substr(2), id)
		if not item.is_empty():
			shell.launch_item(item)


func entry_context(win_key: String, id: String, global_pos: Vector2) -> void:
	if id == "":
		shell.show_menu(MacMenuModel.folder_background_menu(win_key == "computer", String(store.find(win_key).get("view", "large"))), global_pos, {"kind": "background", "win": win_key})
	elif win_key == "computer":
		shell.show_menu(MacMenuModel.group_menu(), global_pos, {"kind": "group", "groupId": id, "win": win_key})
	else:
		shell.show_menu(MacMenuModel.item_menu(), global_pos, {"kind": "item", "groupId": win_key.substr(2), "itemId": id, "win": win_key})


# ------------------------------------------------------------------- drawing

func _desk_items() -> Array:
	return [{"id": "computer", "name": "Launcher HD", "icon": "volume"}, {"id": "trash", "name": "Trash", "icon": "trash"}]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MacTheme.desktop())
	var items := _desk_items()
	_icon_rects = MacGeometry.desktop_icons(size, items.size())
	for i in items.size():
		var d: Dictionary = _icon_rects[i]
		var on: bool = desk_sel == items[i].id
		MacDraw.icon(self, MacIconCatalog.texture(String(items[i].icon), "large"), d.icon.position, Vector2(32, 32), on)
		MacDraw.icon_label(self, d.label, PackedStringArray([String(items[i].name)]), on, MacTheme.b("ffffff"), MacTheme.t("000000"))


func _icon_at(p: Vector2) -> String:
	var items := _desk_items()
	var rects := MacGeometry.desktop_icons(size, items.size())
	for i in items.size():
		var d: Dictionary = rects[i]
		var w := MacDraw.measure(String(items[i].name)) + 8
		var label_box := Rect2(d.label.position.x + floorf((d.label.size.x - w) / 2.0), d.label.position.y, w, d.label.size.y)
		if (d.icon as Rect2).grow(2).has_point(p) or label_box.has_point(p):
			return String(items[i].id)
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var id := _icon_at(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			desk_sel = id
			queue_redraw()
			if id != "" and mb.double_click:
				shell.open_desktop_icon(id)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			desk_sel = id
			queue_redraw()
			if id == "":
				shell.show_menu(MacMenuModel.desktop_menu(), mb.global_position, {"kind": "desktop"})
			else:
				shell.show_menu(MacMenuModel.desk_icon_menu(id), mb.global_position, {"kind": "desk", "id": id})
			accept_event()


func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return null
	if id.begins_with("mac.desktop-icon:"):
		var items := _desk_items()
		var rects := MacGeometry.desktop_icons(size, items.size())
		var want := id.substr("mac.desktop-icon:".length())
		for i in items.size():
			if items[i].id == want or String(items[i].name) == want:
				var ic: Rect2 = rects[i].icon
				return Rect2(global_position + ic.position, ic.size)
	if id == "mac.desktop":
		return Rect2(global_position + Vector2(8, 60), Vector2(60, 60))
	return null
