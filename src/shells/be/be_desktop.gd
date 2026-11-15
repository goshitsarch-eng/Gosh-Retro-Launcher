class_name BeDesktop
extends Control
## The Be desktop: backdrop colour, the column of desktop icons (Program Manager + one folder per group) and the host
## of every window. Windows are children (child order == z-order). Automation ids: "be.desktop-icon:<index|id>".

var shell: Control
var _windows := {}        ## key -> BeWindow
var _labels: Array = []   ## per icon: wrapped label lines
var _icons: Array = []    ## [{id, name, icon}]
var _cells: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true


func setup(p_shell: Control) -> void:
	shell = p_shell
	add_to_group("pm_auto")
	resized.connect(_on_resized)
	sync()


func _on_resized() -> void:
	if shell != null:
		shell.windows.view_size = size
	sync()


func icon_list() -> Array:
	var out := [{"id": "computer", "name": "Program Manager", "icon": "my-computer"}]
	for g in ProgramStore.groups:
		out.append({"id": "g:" + String(g.id), "name": String(g.name), "icon": "folder"})
	return out


func _relayout_icons() -> void:
	_icons = icon_list()
	_labels.clear()
	var counts := []
	for ic in _icons:
		var lines := BeFont.wrap(String(ic.name), 96.0)
		_labels.append(lines)
		counts.append(lines.size())
	_cells = BeGeometry.desktop_cells(counts, size.y)


func window_for(key: String) -> BeWindow:
	return _windows.get(key)


## Brings the BeWindow nodes in line with the window store and the group list.
func sync() -> void:
	if shell == null:
		return
	var store: BeWindowStore = shell.windows
	store.view_size = size
	var seen := {}
	for key in store.order:
		seen[key] = true
		if not _windows.has(key):
			var w := BeWindow.new()
			add_child(w)
			w.setup(shell, key)
			_windows[key] = w
	for key in _windows.keys():
		if not seen.has(key):
			var w: BeWindow = _windows[key]
			_windows.erase(key)
			w.close_menus()
			remove_child(w)
			w.queue_free()
	for key in store.z:
		var w: BeWindow = _windows[key]
		move_child(w, get_child_count() - 1)
	for key in store.order:
		var w: BeWindow = _windows[key]
		var e: Dictionary = store.get_entry(key)
		var r := store.rect_of(key)
		w.position = r.position
		w.size = r.size
		w.visible = not e.hidden
		w.refresh()
	_relayout_icons()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BeTheme.desktop(shell.desktop_color if shell != null else ""))
	if shell == null:
		return
	for i in _icons.size():
		var c: Rect2 = _cells[i]
		var on: bool = shell.desk_sel == _icons[i].id
		var tint := Color(0.6, 0.6, 0.6, 1.0) if on else Color.WHITE
		BeDraw.icon(self, BeIconCatalog.texture(String(_icons[i].icon), String(_icons[i].name)), Rect2(c.position.x + (c.size.x - 32) / 2.0, c.position.y + 2, 32, 32), tint)
		var lines: PackedStringArray = _labels[i]
		var tw := 0.0
		for l in lines:
			tw = maxf(tw, BeFont.width(l))
		var box := Rect2(c.position.x + (c.size.x - tw - 10) / 2.0, c.position.y + 2 + 32 + 4, tw + 10, lines.size() * BeGeometry.LINE + 2)
		if on:
			BeDraw.fill(self, box, BeTheme.b("000000"))
		for n in lines.size():
			BeFont.draw_centered(self, c.position.x + c.size.x / 2.0, box.position.y + 1 + n * BeGeometry.LINE, lines[n], BeTheme.t("ffffff"))


func _icon_at(p: Vector2) -> int:
	for i in range(_cells.size() - 1, -1, -1):
		if (_cells[i] as Rect2).has_point(p):
			return i
	return -1


func icon_rect(index: int) -> Rect2:
	if index < 0 or index >= _cells.size():
		return Rect2()
	var c: Rect2 = _cells[index]
	return Rect2(global_position + c.position, c.size)


func auto_lookup(id: String) -> Variant:
	if id.begins_with("be.desktop-icon:"):
		var n := id.substr("be.desktop-icon:".length())
		for i in _icons.size():
			if n == str(i) or n == String(_icons[i].id) or (n == "first" and i == 0):
				return icon_rect(i)
	if id == "be.desktop":
		return Rect2(global_position, size)
	return null


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		shell.close_all_menus()
		var i := _icon_at(mb.position)
		if i >= 0:
			shell.select_desktop_icon(String(_icons[i].id))
			if mb.double_click:
				shell.open_desktop_icon(String(_icons[i].id))
		else:
			shell.clear_selection()
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		var j := _icon_at(mb.position)
		if j >= 0:
			shell.select_desktop_icon(String(_icons[j].id))
			shell.open_menu(BeMenuModel.desktop_icon_menu(String(_icons[j].id)), mb.global_position)
		else:
			shell.clear_selection()
			shell.open_menu(BeMenuModel.desktop_menu(), mb.global_position)
		accept_event()
