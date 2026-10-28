class_name Win95Window
extends Control
## A Win95 primary window (My Computer, program-group folder, Find): the generic window chrome
## (port of Win95Window.tsx). It draws the frame, caption (system menu icon, title, Minimize /
## Maximize / Close), the File/Edit/View/Help menu bar, the sunken client, the status bar with size grip,
## and owns outline Move/Size (mouse: eight edges; keyboard: system menu Move/Size with arrows,
## Shift = 8 px, Enter commits, Esc cancels). Geometry/minimize/maximize state lives in the
## ProgramStore ("win95" window state) or the Win95WindowStore (system windows).
##
## The client is a child Control: Win95FolderView for My Computer/groups; for Find it is whatever
## Win95Dialogs.build_find_view(shell, window) returns (a later agent supplies it). A client may
## expose: signal result_count_changed(count), signal selection_changed(id), open_selected(),
## select_all(). Another window type can reuse this chrome by passing kind "find" or a custom kind
## with `client` assigned via set_client().

const M := Win95Tokens.M
const MENU_IDS := ["file", "edit", "view", "help"]
const MENU_LABELS := ["&File", "&Edit", "&View", "&Help"]

var shell: Control
var entry_id := ""
var kind := "group"
var group_id := ""

var view_mode := "large"
var selected_id := ""
var find_result_count := 0
var folder_view: Win95FolderView
var client: Control

var menu_id := ""
var menu_bar_index := -1
var system_menu_open := false
var kbd_geom: Dictionary = {}
var outline: Dictionary = {}

var _menu: Win95Menu
var _geom_drag: Dictionary = {}
var _pressed := ""               ## caption part held down: "min" | "max" | "close" | "icon"
var _title_rects: Array = []
var _last_size := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(p_shell: Control, entry: Dictionary) -> void:
	shell = p_shell
	entry_id = entry.id
	kind = entry.kind
	group_id = String(entry.get("groupId", ""))
	if kind == "group" or kind == "my-computer":
		folder_view = Win95FolderView.new()
		folder_view.window_id = entry_id
		add_child(folder_view)
		folder_view.setup(shell, "group" if kind == "group" else "my-computer", group_id)
		folder_view.selection_changed.connect(func(id): selected_id = id)
		client = folder_view
	elif kind == "find":
		var view: Control = Win95Dialogs.build_find_view(shell, self)
		if view != null:
			set_client(view)
	shell.input.register_key("window", "window-" + entry_id, _on_key)
	_wire_auto()
	refresh()


## Attach/replace the client control (it is sized to the client area automatically).
func set_client(c: Control) -> void:
	if client != null and client != folder_view and is_instance_valid(client):
		client.queue_free()
	client = c
	add_child(c)
	if c.has_signal("result_count_changed"):
		c.connect("result_count_changed", func(n): find_result_count = n; queue_redraw())
	if c.has_signal("selection_changed"):
		c.connect("selection_changed", func(id): selected_id = String(id))
	_layout_client()


func _wire_auto() -> void:
	add_to_group("pm_auto")


func _exit_tree() -> void:
	if shell != null and is_instance_valid(shell) and shell.input != null:
		shell.input.unregister_key("window", "window-" + entry_id)


# -------------------------------------------------------------- state access

func entry() -> Dictionary:
	return shell.windows.find_entry(entry_id)


func group() -> Dictionary:
	return ProgramStore.find_group(group_id) if group_id != "" else {}


func is_active() -> bool:
	return shell.windows.active_window_id == entry_id


func looks_active() -> bool:
	return is_active() and shell.host_focused


func is_minimized() -> bool:
	var e := entry()
	return e.is_empty() or shell.windows.entry_is_minimized(e)


func is_maximized() -> bool:
	var e := entry()
	return not e.is_empty() and shell.windows.entry_is_maximized(e)


func title_text() -> String:
	if kind == "find":
		return "Find: All Files"
	if kind == "my-computer":
		return "My Computer"
	return String(group().get("name", "My Computer"))


func icon_id() -> String:
	if kind == "find":
		return "find"
	if kind == "my-computer":
		return "my-computer"
	return String(group().get("icon", "my-computer"))


func desktop_size() -> Dictionary:
	var d: Vector2 = shell.desktop_size()
	return {"width": d.x, "height": d.y}


## Restored rectangle, constrained to the desktop.
func current_rect() -> Dictionary:
	return Win95Geometry.constrain_rect(shell.windows.entry_rect(entry()), desktop_size())


func drawn_rect() -> Rect2:
	if is_maximized():
		var d: Vector2 = shell.desktop_size()
		return Rect2(0, 0, d.x, d.y)
	return Win95Geometry.to_rect2(current_rect())


func object_count() -> int:
	if kind == "find":
		return find_result_count
	if kind == "group":
		return group().get("items", []).size()
	return ProgramStore.groups.size()


# --------------------------------------------------------------------- layout

func refresh() -> void:
	var e := entry()
	if e.is_empty():
		return
	visible = not shell.windows.entry_is_minimized(e)
	var r := drawn_rect()
	position = r.position
	size = r.size
	if client is Win95FolderView:
		(client as Win95FolderView).selection_active = looks_active()
	_layout_client()
	queue_redraw()


func _client_rect() -> Rect2:
	return Rect2(4, 42, size.x - 8, size.y - 66)


func _layout_client() -> void:
	if client == null:
		return
	var inner := _client_rect().grow(-2)
	client.position = inner.position
	client.size = inner.size


func _caption_rect() -> Rect2:
	return Rect2(4, 4, size.x - 8, 18)


func _icon_rect() -> Rect2:
	return Rect2(6, 5, 16, 16)


func _button_rect(name: String) -> Rect2:
	var x0 := size.x - 6 - 52
	match name:
		"min": return Rect2(x0, 6, 16, 14)
		"max": return Rect2(x0 + 18, 6, 16, 14)
		_: return Rect2(x0 + 36, 6, 16, 14)


func _menubar_rects() -> Array:
	var out: Array = []
	var x := 6.0
	for i in MENU_IDS.size():
		var w: float = Win95Draw.measure(MENU_LABELS[i]) + 14
		out.append(Rect2(x, 23, w, 18))
		x += w
	return out


func _status_rect() -> Rect2:
	return Rect2(4, size.y - 22, size.x - 8 - 15, 18)


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	if size.x < 10 or size.y < 40:
		return
	var active := looks_active()
	Win95Draw.window_frame(self, Rect2(Vector2.ZERO, size))
	# caption
	var cap := _caption_rect()
	Win95Draw.fill(self, cap, Win95Draw.CAPTION if active else Win95Draw.INACTIVE)
	var icon_r := _icon_rect()
	Win95Draw.icon(self, Win95IconCatalog.texture(icon_id(), "small"), icon_r.position)
	var title_color := Color.WHITE if active else Win95Draw.FACE
	Win95Draw.text(self, Vector2(24, 7), title_text(), title_color, {"bold": true, "max_width": maxi(1, int(size.x) - 94)})
	for name in ["min", "max", "close"]:
		var br := _button_rect(name)
		var down: bool = _pressed == name
		if down:
			Win95Draw.pressed(self, br)
		else:
			Win95Draw.raised(self, br)
		var glyph := "minimize" if name == "min" else ("close" if name == "close" else ("restore" if is_maximized() else "maximize"))
		var off := Vector2(1, 1) if down else Vector2.ZERO
		Win95Draw.glyph(self, glyph, br.position + Vector2(2, 2) + off)
	# menu bar
	var rects := _menubar_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var open: bool = menu_id == MENU_IDS[i]
		if open:
			Win95Draw.border(self, r, 1, Win95Draw.SHADOW, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.SHADOW)
		Win95Draw.text(self, Vector2(r.position.x + 7, r.position.y + 3), MENU_LABELS[i], Win95Draw.TEXT)
		if menu_bar_index == i and not open:
			Win95Draw.dotted_rect(self, Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Win95Draw.TEXT)
	# client frame
	Win95Draw.sunken(self, _client_rect(), client_background(), client != null)
	# status bar
	var sr := _status_rect()
	Win95Draw.status(self, sr)
	var n := object_count()
	Win95Draw.text(self, Vector2(sr.position.x + 5, sr.position.y + 3), "%d object%s" % [n, "" if n == 1 else "s"], Win95Draw.TEXT)
	if not is_maximized():
		Win95Draw.glyph(self, "size-grip", Vector2(size.x - 4 - 13, size.y - 17))


func client_background() -> Color:
	return Win95Draw.FACE if kind == "find" else Win95Draw.WINDOW


# ------------------------------------------------------------------- geometry

func _edge_at(p: Vector2) -> String:
	if is_maximized():
		return ""
	var w := size.x
	var h := size.y
	if Rect2(0, 0, 7, 7).has_point(p):
		return "nw"
	if Rect2(w - 7, 0, 7, 7).has_point(p):
		return "ne"
	if Rect2(0, h - 7, 7, 7).has_point(p):
		return "sw"
	if Rect2(w - 7, h - 7, 7, 7).has_point(p):
		return "se"
	if Rect2(4, 0, w - 8, 3).has_point(p):
		return "n"
	if Rect2(4, h - 3, w - 8, 3).has_point(p):
		return "s"
	if Rect2(w - 3, 4, 3, h - 8).has_point(p):
		return "e"
	if Rect2(0, 4, 3, h - 8).has_point(p):
		return "w"
	return ""


static func cursor_for_edge(edge: String) -> int:
	match edge:
		"n", "s": return Control.CURSOR_VSIZE
		"e", "w": return Control.CURSOR_HSIZE
		"ne", "sw": return Control.CURSOR_BDIAGSIZE
		"nw", "se": return Control.CURSOR_FDIAGSIZE
	return Control.CURSOR_ARROW


func _set_outline(r: Dictionary) -> void:
	outline = r
	shell.desktop.set_outline(r)


func _begin_pointer_geometry(kind_or_edge: String, global_pos: Vector2) -> void:
	if is_maximized():
		return
	shell.windows.focus_window(entry_id)
	var start := current_rect()
	_geom_drag = {"kind": kind_or_edge, "start": global_pos, "rect": start}
	_set_outline(start)


func _geom_rect(kind_or_edge: String, start: Dictionary, d: Vector2) -> Dictionary:
	if kind_or_edge == "move":
		return Win95Geometry.drag_rect(start, d.x, d.y, desktop_size())
	return Win95Geometry.resize_rect(start, kind_or_edge, d.x, d.y, desktop_size())


func _persist_rect(next: Dictionary) -> void:
	var rounded := Win95Geometry.rect(Win95ShellInput.js_round(next.x), Win95ShellInput.js_round(next.y),
		Win95ShellInput.js_round(next.width), Win95ShellInput.js_round(next.height))
	var constrained := Win95Geometry.constrain_rect(rounded, desktop_size())
	var e := entry()
	if not e.is_empty():
		shell.windows.set_rect(e, constrained)


# ----------------------------------------------------------------- operations

func close_menus() -> void:
	if _menu != null and is_instance_valid(_menu):
		var m := _menu
		_menu = null
		m.close()
	menu_id = ""
	menu_bar_index = -1 if menu_bar_index < 0 else menu_bar_index
	system_menu_open = false
	queue_redraw()


func minimize() -> void:
	close_menus()
	menu_bar_index = -1
	shell.windows.minimize_entry(entry())


func restore() -> void:
	close_menus()
	menu_bar_index = -1
	shell.windows.restore_entry(entry())


func toggle_maximize() -> void:
	close_menus()
	menu_bar_index = -1
	shell.windows.maximize_entry(entry())


func close() -> void:
	close_menus()
	shell.windows.close_entry(entry())


func _menu_on_close() -> void:
	_menu = null
	menu_id = ""
	menu_bar_index = -1
	system_menu_open = false
	queue_redraw()


func open_menu(id: String, tracking: bool = false) -> void:
	var i := MENU_IDS.find(id)
	if i < 0:
		return
	_dispose_menu()
	var rects := _menubar_rects()
	var r: Rect2 = rects[i]
	menu_bar_index = i
	system_menu_open = false
	menu_id = id
	var anchors := rects.map(func(x): return Rect2(position + (x as Rect2).position, (x as Rect2).size))
	_menu = Win95Menu.open(shell, _menu_items(id), position + Vector2(r.position.x, r.end.y), {
		"on_close": _menu_on_close, "anchors": anchors, "tracking": tracking})
	queue_redraw()


func open_system_menu(tracking: bool = false) -> void:
	_dispose_menu()
	system_menu_open = true
	menu_id = ""
	var maximized := is_maximized()
	var minimized := is_minimized()
	var items := [
		{"id": "restore", "label": "&Restore", "disabled": not maximized and not minimized, "onSelect": restore},
		{"id": "move", "label": "&Move", "disabled": maximized, "onSelect": func(): begin_keyboard_geometry("move")},
		{"id": "size", "label": "&Size", "disabled": maximized, "onSelect": func(): begin_keyboard_geometry("size")},
		{"id": "minimize", "label": "Mi&nimize", "disabled": minimized, "onSelect": minimize},
		{"id": "maximize", "label": "Ma&ximize", "disabled": maximized, "onSelect": toggle_maximize},
		{"id": "sep", "separator": true},
		{"id": "close", "label": "&Close", "defaultItem": true, "onSelect": close},
	]
	var icon := Rect2(position + _icon_rect().position, _icon_rect().size)
	_menu = Win95Menu.open(shell, items, position + Vector2(3, 18), {
		"on_close": _menu_on_close, "anchors": [icon], "tracking": tracking})
	queue_redraw()


func _dispose_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		var m := _menu
		_menu = null
		m.on_close = Callable()
		m.close()
	_menu = null


func begin_keyboard_geometry(geom_kind: String) -> void:
	var r := current_rect()
	kbd_geom = {"kind": geom_kind, "original": r, "current": r, "edge": ""}
	_set_outline(r)
	shell.windows.focus_window(entry_id)


## Used by the taskbar menu / window store requests.
func request_command(command: String) -> void:
	if is_minimized() or (is_maximized() and command == "size"):
		return
	begin_keyboard_geometry(command)


func _menu_items(id: String) -> Array:
	var has_selection := selected_id != ""
	if kind == "find":
		match id:
			"file":
				return [
					{"id": "open", "label": "&Open", "disabled": not has_selection, "onSelect": func(): _client_call("open_selected")},
					{"id": "sep", "separator": true},
					{"id": "close", "label": "&Close", "defaultItem": true, "onSelect": close},
				]
			"edit":
				return [
					{"id": "cut", "label": "Cu&t", "disabled": true},
					{"id": "copy", "label": "&Copy", "disabled": true},
					{"id": "sep", "separator": true},
					{"id": "select-all", "label": "Select &All", "disabled": find_result_count == 0, "onSelect": func(): _client_call("select_all")},
				]
			"view":
				return [
					{"id": "details", "label": "&Details", "checked": true},
					{"id": "sep", "separator": true},
					{"id": "status", "label": "Status &Bar", "checked": true},
				]
			_:
				return [
					{"id": "topics", "label": "&Help Topics", "onSelect": func(): Win95Dialogs.open_help(shell)},
					{"id": "sep", "separator": true},
					{"id": "about", "label": "&About Gosh 95...", "onSelect": func(): Win95Dialogs.open_about(shell)},
				]
	match id:
		"file":
			return [
				{"id": "open", "label": "&Open", "disabled": not has_selection, "onSelect": func(): _open_selected()},
				{"id": "new", "label": "&New Program...", "onSelect": func():
					if group_id != "":
						Win95Dialogs.open_wizard(shell, {"groupId": group_id})
					else:
						Win95Dialogs.open_new_folder(shell, {})},
				{"id": "sep-1", "separator": true},
				{"id": "delete", "label": "&Delete", "disabled": not has_selection, "onSelect": func(): _delete_selected()},
				{"id": "properties", "label": "P&roperties", "onSelect": func():
					if group_id != "":
						Win95Dialogs.open_properties(shell, {"kind": "group", "group": group()})
					else:
						shell.request_show_launcher_tools.emit()},
				{"id": "sep-2", "separator": true},
				{"id": "close", "label": "&Close", "onSelect": close},
			]
		"edit":
			var count := object_count()
			return [
				{"id": "undo", "label": "&Undo", "disabled": true},
				{"id": "sep-1", "separator": true},
				{"id": "cut", "label": "Cu&t", "disabled": true},
				{"id": "copy", "label": "&Copy", "disabled": true},
				{"id": "paste", "label": "&Paste", "disabled": true},
				{"id": "sep-2", "separator": true},
				{"id": "select-all", "label": "Select &All", "disabled": count == 0, "onSelect": func(): if folder_view: folder_view.select_all()},
			]
		"view":
			return [
				{"id": "large", "label": "Lar&ge Icons", "checked": view_mode == "large", "onSelect": func(): _set_view("large")},
				{"id": "small", "label": "S&mall Icons", "checked": view_mode == "small", "onSelect": func(): _set_view("small")},
				{"id": "list", "label": "&List", "checked": view_mode == "list", "onSelect": func(): _set_view("list")},
				{"id": "details", "label": "&Details", "checked": view_mode == "details", "onSelect": func(): _set_view("details")},
				{"id": "sep-1", "separator": true},
				{"id": "status", "label": "Status &Bar", "checked": true},
			]
		_:
			return [
				{"id": "topics", "label": "&Help Topics", "onSelect": func(): Win95Dialogs.open_help(shell)},
				{"id": "sep-1", "separator": true},
				{"id": "about", "label": "&About Gosh 95...", "onSelect": func(): Win95Dialogs.open_about(shell)},
			]


func _client_call(method: String) -> void:
	if client != null and client.has_method(method):
		client.call(method)


func _set_view(mode: String) -> void:
	view_mode = mode
	if folder_view:
		folder_view.set_view_mode(mode)
	queue_redraw()


func _open_selected() -> void:
	if folder_view:
		folder_view.open_focused()


func _delete_selected() -> void:
	if folder_view == null or selected_id == "":
		return
	if kind == "my-computer":
		var g := ProgramStore.find_group(selected_id)
		if not g.is_empty():
			var gid: String = g.id
			Win95Dialogs.confirm(shell, "Confirm Folder Delete",
				"Are you sure you want to remove '%s' and all of its contents?" % g.name, func():
					ProgramStore.delete_group(gid)
					shell.windows.close_window("group:" + gid))
		return
	folder_view.delete_selected()


# ------------------------------------------------------------------ pointer

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb)
			else:
				_release(mb)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			shell.windows.focus_window(entry_id)
			var p := mb.position
			if _caption_rect().has_point(p):
				if system_menu_open:
					close_menus()
				else:
					open_system_menu()
			accept_event()
	elif event is InputEventMouseMotion:
		_motion(event as InputEventMouseMotion)


func _press(mb: InputEventMouseButton) -> void:
	var p := mb.position
	shell.windows.focus_window(entry_id)
	var edge := _edge_at(p)
	if edge != "":
		_begin_pointer_geometry(edge, mb.global_position)
		return
	var cap := _caption_rect()
	if cap.has_point(p):
		for name in ["min", "max", "close"]:
			if _button_rect(name).has_point(p):
				_pressed = name
				queue_redraw()
				return
		if _icon_rect().has_point(p):
			if mb.double_click:
				close()
				return
			_pressed = "icon"
			return
		if mb.double_click:
			toggle_maximize()
			return
		_begin_pointer_geometry("move", mb.global_position)
		return
	var rects := _menubar_rects()
	for i in rects.size():
		if (rects[i] as Rect2).has_point(p):
			if menu_id == MENU_IDS[i]:
				close_menus()
				menu_bar_index = -1
			else:
				open_menu(MENU_IDS[i], true)
			return


func _release(mb: InputEventMouseButton) -> void:
	var p := mb.position
	if not _geom_drag.is_empty():
		var d := _geom_drag
		_geom_drag = {}
		var next := _geom_rect(d.kind, d.rect, mb.global_position - d.start)
		_set_outline({})
		_persist_rect(next)
		return
	if _pressed != "":
		var which := _pressed
		_pressed = ""
		queue_redraw()
		if which == "icon":
			if _icon_rect().has_point(p):
				if system_menu_open:
					close_menus()
				else:
					open_system_menu(true)
			return
		if _button_rect(which).has_point(p):
			match which:
				"min": minimize()
				"max": toggle_maximize()
				"close": close()


func _motion(mm: InputEventMouseMotion) -> void:
	var p := mm.position
	if not _geom_drag.is_empty():
		var d := _geom_drag
		_set_outline(_geom_rect(d.kind, d.rect, mm.global_position - d.start))
		return
	if _pressed != "":
		queue_redraw()
		return
	mouse_default_cursor_shape = cursor_for_edge(_edge_at(p)) as CursorShape
	if menu_id != "":
		var rects := _menubar_rects()
		for i in rects.size():
			if (rects[i] as Rect2).has_point(p) and menu_id != MENU_IDS[i]:
				open_menu(MENU_IDS[i], false)
				return


# ---------------------------------------------------------------------- keys

func _on_key(event: Dictionary) -> bool:
	if not is_active() or is_minimized():
		return false
	var key: String = event.key
	var alt: bool = event.get("altKey", false)
	var shift: bool = event.get("shiftKey", false)
	if not kbd_geom.is_empty():
		return _geometry_key(key, shift)
	if key == "Alt" and not alt:
		close_menus()
		menu_bar_index = 0
		queue_redraw()
		return true
	if menu_bar_index >= 0 and not alt:
		if key == "Escape":
			close_menus()
			menu_bar_index = -1
			queue_redraw()
			return true
		if key == "ArrowLeft" or key == "ArrowRight":
			var delta := 1 if key == "ArrowRight" else -1
			var next := (menu_bar_index + delta + MENU_IDS.size()) % MENU_IDS.size()
			var was_open := menu_id != ""
			menu_bar_index = next
			if was_open:
				open_menu(MENU_IDS[next])
			queue_redraw()
			return true
		if key == "ArrowDown" or key == "Enter":
			open_menu(MENU_IDS[menu_bar_index])
			return true
	if alt and key == " ":
		if system_menu_open:
			close_menus()
		else:
			open_system_menu()
		return true
	if alt and key == "F4":
		close()
		return true
	if alt and key.length() == 1 and key.to_lower() in ["f", "e", "v", "h"]:
		open_menu({"f": "file", "e": "edit", "v": "view", "h": "help"}[key.to_lower()])
		return true
	if menu_bar_index < 0 and client != null and client.has_method("handle_key") and client.handle_key(event):
		return true
	return false


func _geometry_key(key: String, shift: bool) -> bool:
	if key == "Escape" or key == "Enter":
		if key == "Enter":
			_persist_rect(kbd_geom.current)
		kbd_geom = {}
		_set_outline({})
		return true
	if not key in ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"]:
		return false
	var amount := 8 if shift else 1
	var dx := -amount if key == "ArrowLeft" else (amount if key == "ArrowRight" else 0)
	var dy := -amount if key == "ArrowUp" else (amount if key == "ArrowDown" else 0)
	var edge: String = kbd_geom.edge
	var next: Dictionary
	if kbd_geom.kind == "size":
		edge = Win95Geometry.keyboard_resize_edge(edge, key)
		next = Win95Geometry.resize_rect(kbd_geom.current, edge if edge != "" else "se", dx, dy, desktop_size())
	else:
		next = Win95Geometry.drag_rect(kbd_geom.current, dx, dy, desktop_size())
	kbd_geom["current"] = next
	kbd_geom["edge"] = edge
	_set_outline(next)
	return true


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if not is_active() or not visible:
		return null
	var origin := global_position
	if id.begins_with("w95.window.active:menu:"):
		var name := id.get_slice(":", 2)
		var i := MENU_IDS.find(name)
		if i >= 0:
			var r: Rect2 = _menubar_rects()[i]
			return Rect2(origin + r.position, r.size)
	if id.begins_with("w95.window.active:button:"):
		var label := id.get_slice(":", 2)
		var rr := Rect2()
		match label:
			"Minimize": rr = _button_rect("min")
			"Maximize":
				if not is_maximized():
					rr = _button_rect("max")
			"Restore":
				if is_maximized():
					rr = _button_rect("max")
			"Close": rr = _button_rect("close")
		if rr.size != Vector2.ZERO:
			return Rect2(origin + rr.position, rr.size)
	if id == "w95.window.active:caption-icon":
		return Rect2(origin + _icon_rect().position, _icon_rect().size)
	return null
