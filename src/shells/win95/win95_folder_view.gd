class_name Win95FolderView
extends Control
## The list-view client of My Computer / group windows (port of Win95FolderView.tsx):
## Large Icon / Small Icon / List / Details (report) views, Ctrl/Shift extended selection, marquee,
## type-to-select, Ctrl+A, manual icon placement (Auto Arrange off), resizable report columns,
## deterministic scrollbars, context menu, launching and delete confirmation.
## The view fills the window's client content box; the window feeds it keys via handle_key().

signal selection_changed(focused_id: String)

const M := Win95Tokens.M
const SCROLLBAR := 16

var shell: Control
var kind := "my-computer"        ## "my-computer" | "group"
var group_id := ""
var view_mode := "large"         ## "large" | "small" | "list" | "details"
var selection_active := true

var selection: Dictionary = Win95SelectionState.empty()
var scroll := Vector2i.ZERO
var report_widths: Dictionary = Win95ListViewState.DEFAULT_REPORT_WIDTHS.duplicate()

var _computed: Dictionary = {}
var _hscroll: Win95Scrollbar
var _vscroll: Win95Scrollbar
var _marquee: Dictionary = {}     ## {start: Vector2, rect: Dictionary, base: Array}
var _drag: Dictionary = {}        ## {id, start: Vector2, origin: Vector2, delta: Vector2, moved: bool}
var _col_drag: Dictionary = {}    ## {column, x}
var _type_prefix := ""
var _type_at := 0
var _menu: Win95Menu
var _marquee_layer: Win95DifferenceLayer
var window_id := ""


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(p_shell: Control, p_kind: String, p_group_id: String) -> void:
	shell = p_shell
	kind = p_kind
	group_id = p_group_id
	_vscroll = Win95Scrollbar.new()
	_vscroll.vertical = true
	_vscroll.scrolled.connect(func(v): _set_scroll(Vector2i(scroll.x, v)))
	_hscroll = Win95Scrollbar.new()
	_hscroll.vertical = false
	_hscroll.scrolled.connect(func(v): _set_scroll(Vector2i(v, scroll.y)))
	add_child(_vscroll)
	add_child(_hscroll)
	_vscroll.hide()
	_hscroll.hide()
	_marquee_layer = Win95DifferenceLayer.new()
	add_child(_marquee_layer)
	ProgramStore.groups_changed.connect(_on_groups_changed)
	resized.connect(_recompute)
	add_to_group("pm_auto")
	_recompute()


func _exit_tree() -> void:
	if ProgramStore.groups_changed.is_connected(_on_groups_changed):
		ProgramStore.groups_changed.disconnect(_on_groups_changed)


# ------------------------------------------------------------------ model

func group() -> Dictionary:
	return ProgramStore.find_group(group_id) if kind == "group" else {}


## Entries shown: groups for My Computer, items for a group window. Each: {id, name, icon, is_group, data}.
func entries() -> Array:
	var out: Array = []
	if kind == "my-computer":
		for g in ProgramStore.groups:
			out.append({"id": g.id, "name": g.name, "icon": "folder", "is_group": true, "data": g})
	else:
		for it in group().get("items", []):
			out.append({"id": it.id, "name": it.name, "icon": String(it.get("icon", "")), "is_group": false, "data": it})
	return out


func entry_ids() -> Array:
	return entries().map(func(e): return e.id)


func _entry(id: String) -> Dictionary:
	for e in entries():
		if e.id == id:
			return e
	return {}


func _on_groups_changed() -> void:
	var valid := entry_ids()
	selection = {
		"selected": selection.selected.filter(func(i): return valid.has(i)),
		"focused": selection.focused if valid.has(selection.focused) else "",
		"anchor": selection.anchor if valid.has(selection.anchor) else "",
	}
	_recompute()
	_emit_selection()


func set_view_mode(mode: String) -> void:
	view_mode = mode
	scroll = Vector2i.ZERO
	_recompute()


func select_all() -> void:
	selection = Win95SelectionState.select_all(entry_ids())
	_emit_selection()
	queue_redraw()


func focused_id() -> String:
	if selection.focused != "":
		return selection.focused
	return String(selection.selected[0]) if selection.selected.size() > 0 else ""


func _emit_selection() -> void:
	selection_changed.emit(focused_id())


# ------------------------------------------------------------------ layout

func _manual_positions() -> Dictionary:
	var out := {}
	if kind == "group":
		for e in entries():
			var p: Variant = e.data.get("win95Position")
			if Jsonx.is_obj(p):
				out[e.id] = p
	return out


func _layout(viewport: Dictionary) -> Dictionary:
	return Win95ListViewState.layout(entry_ids(), view_mode, viewport, _manual_positions(),
		bool(ProgramStore.settings.get("autoArrange", true)), report_widths)


func _recompute() -> void:
	if shell == null:
		return
	var viewport := {"width": size.x, "height": size.y}
	var layout := _layout(viewport)
	var vertical: bool = layout.contentHeight > viewport.height
	var horizontal: bool = layout.contentWidth > viewport.width
	viewport = {
		"width": maxf(1.0, size.x - (SCROLLBAR if vertical else 0)),
		"height": maxf(1.0, size.y - (SCROLLBAR if horizontal else 0)),
	}
	layout = _layout(viewport)
	vertical = layout.contentHeight > viewport.height
	horizontal = layout.contentWidth > viewport.width
	if vertical and viewport.width == size.x:
		viewport.width = maxf(1.0, viewport.width - SCROLLBAR)
	if horizontal and viewport.height == size.y:
		viewport.height = maxf(1.0, viewport.height - SCROLLBAR)
	layout = _layout(viewport)
	vertical = layout.contentHeight > viewport.height
	horizontal = layout.contentWidth > viewport.width
	_computed = {"layout": layout, "viewport": viewport, "vertical": vertical, "horizontal": horizontal}
	scroll = Vector2i(
		Win95ScrollbarState.clamp_scroll(scroll.x, layout.contentWidth, viewport.width),
		Win95ScrollbarState.clamp_scroll(scroll.y, layout.contentHeight, viewport.height))
	_sync_scrollbars()
	queue_redraw()


func _sync_scrollbars() -> void:
	var layout: Dictionary = _computed.layout
	var viewport: Dictionary = _computed.viewport
	_vscroll.visible = _computed.vertical
	_hscroll.visible = _computed.horizontal
	if _computed.vertical:
		_vscroll.position = Vector2(size.x - SCROLLBAR, 0)
		_vscroll.configure(scroll.y, viewport.height, layout.contentHeight, viewport.height, 19 if view_mode == "details" else 20)
	if _computed.horizontal:
		_hscroll.position = Vector2(0, size.y - SCROLLBAR)
		_hscroll.configure(scroll.x, viewport.width, layout.contentWidth, viewport.width, 80)


func _set_scroll(s: Vector2i) -> void:
	scroll = Vector2i(
		Win95ScrollbarState.clamp_scroll(s.x, _computed.layout.contentWidth, _computed.viewport.width),
		Win95ScrollbarState.clamp_scroll(s.y, _computed.layout.contentHeight, _computed.viewport.height))
	_sync_scrollbars()
	queue_redraw()


func _item_layout(id: String) -> Dictionary:
	for it in _computed.layout.items:
		if it.id == id:
			return it
	return {}


func _reveal(id: String) -> void:
	var item := _item_layout(id)
	if item.is_empty():
		return
	var vp: Dictionary = _computed.viewport
	var head := 18 if view_mode == "details" else 0
	var x: float = scroll.x
	if item.x < scroll.x:
		x = item.x
	elif item.x + item.width > scroll.x + vp.width:
		x = item.x + item.width - vp.width
	var y: float = scroll.y
	if item.y < scroll.y + head:
		y = maxf(0.0, item.y - head)
	elif item.y + item.height > scroll.y + vp.height:
		y = item.y + item.height - vp.height
	_set_scroll(Vector2i(int(x), int(y)))


# ----------------------------------------------------------------- selection

func choose(id: String, modifiers: Dictionary = {}) -> void:
	selection = Win95SelectionState.select_item(selection, id, entry_ids(), modifiers)
	_reveal(id)
	_emit_selection()
	queue_redraw()


func _label_max_width(layout: Dictionary) -> int:
	return maxi(20, int(layout.width) - 4) if view_mode == "large" else maxi(20, int(report_widths.name) - 22)


# ------------------------------------------------------------------ drawing

func _label_text_color(selected: bool) -> Color:
	return Win95Draw.SELECTED_TEXT if (selected and selection_active) else Win95Draw.TEXT


func _draw() -> void:
	if _computed.is_empty():
		return
	var vp: Dictionary = _computed.viewport
	Win95Draw.fill(self, Rect2(0, 0, size.x, size.y), Win95Draw.WINDOW)
	var selected_set := {}
	for s in selection.selected:
		selected_set[s] = true
	var ents := entries()
	var item_by_id := {}
	for it in _computed.layout.items:
		item_by_id[it.id] = it
	for e in ents:
		var lay: Dictionary = item_by_id.get(e.id, {})
		if lay.is_empty():
			continue
		var x: float = lay.x - scroll.x
		var y: float = lay.y - scroll.y
		if x > vp.width or y > vp.height or x + lay.width < 0 or y + lay.height < 0:
			continue
		_draw_entry(e, lay, Vector2(x, y), selected_set.has(e.id))
	if view_mode == "details":
		_draw_header(vp)
	_update_marquee_layer()
	if not _drag.is_empty() and _drag.moved:
		_draw_drag_image(ents)


func _update_marquee_layer() -> void:
	if _marquee.is_empty():
		_marquee_layer.set_rects([])
		return
	var r: Dictionary = _marquee.rect
	_marquee_layer.set_rects([{"rect": Rect2(float(r.x) - scroll.x, float(r.y) - scroll.y, float(r.width), float(r.height)), "thickness": 1}])


func _draw_entry(e: Dictionary, lay: Dictionary, p: Vector2, selected: bool) -> void:
	var focused: bool = selection.focused == e.id
	var name: String = e.name
	var fg := _label_text_color(selected)
	var sel_bg := Win95Draw.SELECTED if selection_active else Win95Draw.FACE
	match view_mode:
		"large":
			var tex := Win95IconCatalog.texture(e.icon, "large")
			var icon_pos := Vector2(p.x + 21, p.y + 1)
			Win95Draw.icon(self, tex, icon_pos)
			if selected:
				Win95Draw.icon_selection(self, tex, icon_pos, Win95Draw.SELECTED if selection_active else Win95Draw.SHADOW)
			var lines := Win95Draw.font().wrap(name, _label_max_width(lay))
			var text_w := 1
			for l in lines:
				text_w = maxi(text_w, Win95Draw.measure(l))
			var box_w := text_w + 4
			var box_h := maxi(13, lines.size() * 13) + 2
			var box_x := p.x + 2 + int((72 - box_w + 1) / 2)
			var box := Rect2(box_x, p.y + 38, box_w, box_h)
			if selected:
				Win95Draw.fill(self, box, sel_bg)
			Win95Draw.text(self, Vector2(box.position.x + 2, box.position.y + 1), name, fg, {"max_width": _label_max_width(lay), "wrap": true})
			if focused:
				Win95Draw.dotted_rect(self, box, fg)
		"small", "list":
			var tex := Win95IconCatalog.texture(e.icon, "small")
			var icon_pos := Vector2(p.x + 2, p.y + 2)
			Win95Draw.icon(self, tex, icon_pos)
			if selected:
				Win95Draw.icon_selection(self, tex, icon_pos, Win95Draw.SELECTED if selection_active else Win95Draw.SHADOW)
			var clipped := Win95Draw.font().clip(name, _label_max_width(lay))
			var box := Rect2(p.x + 21, p.y + 3, Win95Draw.measure(clipped) + 4, 15)
			if selected:
				Win95Draw.fill(self, box, sel_bg)
			Win95Draw.text(self, Vector2(box.position.x + 2, box.position.y + 1), clipped, fg)
			if focused:
				Win95Draw.dotted_rect(self, box, fg)
		_:
			_draw_report_row(e, lay, p, selected, focused, fg, sel_bg)


func _draw_report_row(e: Dictionary, lay: Dictionary, p: Vector2, selected: bool, focused: bool, fg: Color, sel_bg: Color) -> void:
	var row := Rect2(p.x, p.y, lay.width, 19)
	if selected:
		Win95Draw.fill(self, row, sel_bg)
	var tex := Win95IconCatalog.texture(e.icon, "small")
	var icon_pos := Vector2(p.x + 2, p.y + 2)
	Win95Draw.icon(self, tex, icon_pos)
	if selected:
		Win95Draw.icon_selection(self, tex, icon_pos, Win95Draw.SELECTED if selection_active else Win95Draw.SHADOW)
	var name_w: int = int(report_widths.name) - 22
	var clipped := Win95Draw.font().clip(e.name, maxi(20, name_w))
	var box := Rect2(p.x + 18, p.y + 2, Win95Draw.measure(clipped) + 4, 15)
	if selected:
		Win95Draw.fill(self, box, sel_bg)
	Win95Draw.text(self, Vector2(box.position.x + 2, box.position.y + 1), clipped, fg)
	if focused:
		Win95Draw.dotted_rect(self, box, fg)
	var col2 := p.x + float(report_widths.name)
	var type_text := "File Folder" if e.is_group else "Application"
	var loc_text := "My Computer" if e.is_group else String(group().get("name", ""))
	Win95Draw.text(self, Vector2(col2 + 4, p.y + 3), Win95Draw.font().clip(type_text, int(report_widths.type) - 8), fg)
	Win95Draw.text(self, Vector2(col2 + float(report_widths.type) + 4, p.y + 3), Win95Draw.font().clip(loc_text, int(report_widths.location) - 8), fg)


func _draw_header(vp: Dictionary) -> void:
	var x := -float(scroll.x)
	var total := float(report_widths.name) + float(report_widths.type) + float(report_widths.location)
	Win95Draw.fill(self, Rect2(x, 0, total, 18), Win95Draw.FACE)
	var cols := [["name", "&Name"], ["type", "&Type"], ["location", "&Location"]]
	for c in cols:
		var w: float = float(report_widths[c[0]])
		var r := Rect2(x, 0, w, 18)
		Win95Draw.fill(self, r, Win95Draw.FACE)
		Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
		Win95Draw.inset_shadow(self, r.grow(-1), -1, -1, Win95Draw.SHADOW)
		Win95Draw.text(self, Vector2(x + 5, 3), c[1], Win95Draw.TEXT, {"max_width": int(w) - 10})
		x += w


func _draw_drag_image(ents: Array) -> void:
	var e := _entry(_drag.id)
	if e.is_empty():
		return
	var pos: Vector2 = _drag.origin + _drag.delta - Vector2(scroll)
	var faded := Color(1, 1, 1, 0.55)
	if view_mode == "large":
		Win95Draw.icon(self, Win95IconCatalog.texture(e.icon, "large"), pos + Vector2(21, 1), faded)
		Win95Draw.text(self, pos + Vector2(4, 39), e.name, Color(0, 0, 0, 0.55), {"max_width": 72, "wrap": true})
	else:
		Win95Draw.icon(self, Win95IconCatalog.texture(e.icon, "small"), pos + Vector2(2, 2), faded)
		Win95Draw.text(self, pos + Vector2(21, 4), e.name, Color(0, 0, 0, 0.55))


# --------------------------------------------------------------- hit testing

## Id of the entry under a point (view-local coordinates), or "".
func entry_at(p: Vector2) -> String:
	var vp: Dictionary = _computed.viewport
	if p.x >= vp.width or p.y >= vp.height:
		return ""
	if view_mode == "details" and p.y < 18:
		return ""
	var items: Array = _computed.layout.items
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		var r := Rect2(float(it.x) - scroll.x, float(it.y) - scroll.y, float(it.width), float(it.height))
		if r.has_point(p):
			return String(it.id)
	return ""


func _header_hit(p: Vector2) -> Dictionary:
	if view_mode != "details" or p.y >= 18:
		return {}
	var x := -float(scroll.x)
	for c in ["name", "type", "location"]:
		var w: float = float(report_widths[c])
		var right := x + w
		if p.x >= right - 3 and p.x < right + 2:
			return {"resize": c}
		if p.x >= x and p.x < right:
			return {"column": c}
		x += w
	return {}


## Rect (shell coordinates) of an entry, for automation.
func entry_rect(index: int) -> Rect2:
	var ids := entry_ids()
	if index < 0 or index >= ids.size():
		return Rect2()
	var it := _item_layout(ids[index])
	if it.is_empty():
		return Rect2()
	var origin: Vector2 = get_global_rect().position
	var r := Rect2(float(it.x) - scroll.x, float(it.y) - scroll.y, float(it.width), float(it.height))
	var vp: Dictionary = _computed.viewport
	r = r.intersection(Rect2(0, 18 if view_mode == "details" else 0, vp.width, vp.height))
	return Rect2(origin + r.position, r.size)


# --------------------------------------------------------------- pointer input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb)
			else:
				_on_release(mb)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_on_context(mb)
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_on_wheel(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			accept_event()
	elif event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)


func _on_wheel(dir: int) -> void:
	if _computed.vertical:
		_set_scroll(Vector2i(scroll.x, scroll.y + dir * 48))
	elif _computed.horizontal:
		_set_scroll(Vector2i(scroll.x + dir * 80, scroll.y))


func _close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.close()
	_menu = null


func _on_press(mb: InputEventMouseButton) -> void:
	shell.windows.focus_window(window_id)
	var p := mb.position
	var header := _header_hit(p)
	if not header.is_empty():
		if header.has("resize"):
			_col_drag = {"column": header.resize, "x": p.x}
		return
	var id := entry_at(p)
	if id != "":
		choose(id, {"ctrl": mb.ctrl_pressed, "shift": mb.shift_pressed})
		var auto_arrange: bool = ProgramStore.settings.get("autoArrange", true)
		if not auto_arrange and kind == "group" and (view_mode == "large" or view_mode == "small"):
			var lay := _item_layout(id)
			_drag = {"id": id, "start": p, "origin": Vector2(lay.x, lay.y), "delta": Vector2.ZERO, "moved": false}
		if mb.double_click:
			_drag = {}
			open_entry(_entry(id))
		return
	# empty space: marquee
	var start := p + Vector2(scroll)
	var base: Array = selection.selected.duplicate() if mb.ctrl_pressed else []
	if not mb.ctrl_pressed:
		selection = Win95SelectionState.empty()
		_emit_selection()
	_marquee = {"start": start, "rect": {"x": start.x, "y": start.y, "width": 0, "height": 0}, "base": base}
	queue_redraw()


func _on_motion(mm: InputEventMouseMotion) -> void:
	var p := mm.position
	if not _col_drag.is_empty():
		var delta: float = p.x - float(_col_drag.x)
		_col_drag.x = p.x
		report_widths[_col_drag.column] = Win95ListViewState.resize_report_column(float(report_widths[_col_drag.column]), delta)
		_recompute()
		return
	if not _drag.is_empty():
		_drag.delta = p - _drag.start
		if not _drag.moved and absf(_drag.delta.x) + absf(_drag.delta.y) > 3:
			_drag.moved = true
			shell.set_dragging(true)
		queue_redraw()
		return
	if not _marquee.is_empty():
		var content_point := p + Vector2(scroll)
		_marquee.rect = Win95SelectionState.normalize_marquee(_marquee.start, content_point)
		var hit := Win95SelectionState.items_in_marquee(_computed.layout.items, _marquee.rect)
		var selected: Array = _marquee.base.duplicate()
		for h in hit:
			if not selected.has(h):
				selected.append(h)
		selection = {
			"selected": selected,
			"focused": String(hit[hit.size() - 1]) if hit.size() > 0 else selection.focused,
			"anchor": selection.anchor,
		}
		_emit_selection()
		queue_redraw()


func _on_release(_mb: InputEventMouseButton) -> void:
	if not _col_drag.is_empty():
		_col_drag = {}
		return
	if not _drag.is_empty():
		var d := _drag
		_drag = {}
		shell.set_dragging(false)
		if d.moved and kind == "group":
			var minimum_y := 18 if view_mode == "details" else 0
			ProgramStore.update_win95_item_position(group_id, d.id, {
				"x": Win95ShellInput.js_round(maxf(0.0, d.origin.x + d.delta.x)),
				"y": Win95ShellInput.js_round(maxf(minimum_y, d.origin.y + d.delta.y)),
			})
			_recompute()
		queue_redraw()
		return
	if not _marquee.is_empty():
		_marquee = {}
		queue_redraw()


func _on_context(mb: InputEventMouseButton) -> void:
	shell.windows.focus_window(window_id)
	var id := entry_at(mb.position)
	if id != "" and not selection.selected.has(id):
		selection = {"selected": [id], "focused": id, "anchor": id}
		_emit_selection()
		queue_redraw()
	_open_context(get_global_transform() * mb.position, id)


func _open_context(at: Vector2, target_id: String) -> void:
	_close_menu()
	_menu = Win95Menu.open(shell, _context_items(target_id), at, {"on_close": func(): _menu = null})


# ----------------------------------------------------------------- commands

func open_entry(e: Dictionary) -> void:
	if e.is_empty():
		return
	if e.is_group:
		shell.windows.open_group(e.id)
		return
	shell.launch_item(e.data)


func open_focused() -> void:
	var id := focused_id()
	if id != "":
		open_entry(_entry(id))


func delete_selected() -> void:
	if kind != "group" or selection.selected.is_empty():
		return
	var chosen: Array = entries().filter(func(e): return not e.is_group and selection.selected.has(e.id))
	if chosen.is_empty():
		return
	var gid := group_id
	var message: String
	if chosen.size() == 1:
		message = "Are you sure you want to remove '%s'?" % chosen[0].name
	else:
		message = "Are you sure you want to remove these %d items?" % chosen.size()
	Win95Dialogs.confirm(shell, "Confirm File Delete", message, func():
		for e in chosen:
			ProgramStore.delete_item(gid, e.id))


func _context_items(target_id: String) -> Array:
	var target := _entry(target_id) if target_id != "" else {}
	if not target.is_empty():
		var items := [{"id": "open", "label": "&Open", "defaultItem": true, "onSelect": func(): open_entry(target)},
			{"id": "sep-1", "separator": true}]
		if kind == "group" and not target.is_group:
			items.append({"id": "delete", "label": "&Delete", "onSelect": delete_selected})
			items.append({"id": "properties", "label": "P&roperties", "icon": "properties",
				"onSelect": func(): Win95Dialogs.open_properties(shell, {"kind": "item", "groupId": group_id, "item": target.data})})
		else:
			items.append({"id": "properties", "label": "P&roperties", "icon": "properties",
				"onSelect": func(): Win95Dialogs.open_properties(shell, {"kind": "group", "group": target.data})})
		return items
	if kind == "group":
		return [
			{"id": "new-program", "label": "&New Program...", "icon": "new-shortcut", "onSelect": func(): Win95Dialogs.open_wizard(shell, {"groupId": group_id})},
			{"id": "new-url", "label": "New &URL...", "onSelect": func(): Win95Dialogs.open_new_url(shell, {"groupId": group_id})},
			{"id": "sep", "separator": true},
			{"id": "select-all", "label": "Select &All", "disabled": entries().is_empty(), "onSelect": select_all},
		]
	return [
		{"id": "new-folder", "label": "&New Folder...", "onSelect": func(): Win95Dialogs.open_new_folder(shell, {})},
		{"id": "properties", "label": "P&roperties", "icon": "properties", "onSelect": func(): shell.request_show_launcher_tools.emit()},
	]


# ------------------------------------------------------------------ keyboard

## Folder-view keyboard (called by the active window). Returns true when consumed.
func handle_key(event: Dictionary) -> bool:
	var key: String = event.key
	var ctrl: bool = event.get("ctrlKey", false)
	var shift: bool = event.get("shiftKey", false)
	var alt: bool = event.get("altKey", false)
	var meta: bool = event.get("metaKey", false)
	var ids := entry_ids()
	if ctrl and key.to_lower() == "a":
		select_all()
		return true
	var focused := focused_id()
	var selected_index := maxi(0, ids.find(focused))
	if key == "Enter" and focused != "":
		var entry := _entry(focused)
		if not entry.is_empty():
			open_entry(entry)
		return true
	if key == "Delete":
		delete_selected()
		return true
	if (shift and key == "F10") or key == "ContextMenu":
		var it := _item_layout(focused)
		var local := Vector2(float(it.get("x", 2)) - scroll.x + 18, float(it.get("y", 2)) - scroll.y + 18)
		_open_context(get_global_transform() * local, focused)
		return true
	var next_id := ""
	if key in ["ArrowRight", "ArrowLeft", "ArrowDown", "ArrowUp"]:
		next_id = Win95SelectionState.find_directional_item(_computed.layout.items, focused, key.replace("Arrow", "").to_lower())
	elif key == "Home":
		next_id = String(ids[0]) if ids.size() > 0 else ""
	elif key == "End":
		next_id = String(ids[ids.size() - 1]) if ids.size() > 0 else ""
	elif key == "PageDown" or key == "PageUp":
		var index := Win95ListViewState.page_selection_index(selected_index, 1 if key == "PageDown" else -1, _computed.layout.rowsPerPage, ids.size())
		next_id = String(ids[index]) if index >= 0 else ""
	elif key.length() == 1 and not ctrl and not alt and not meta:
		var now := Time.get_ticks_msec()
		_type_prefix = key if now - _type_at > 1000 else _type_prefix + key
		_type_at = now
		next_id = Win95SelectionState.find_type_match(entries().map(func(e): return {"id": e.id, "label": e.name}), _type_prefix, focused)
	else:
		return false
	if next_id == "":
		return false
	if ctrl:
		selection = selection.duplicate()
		selection["focused"] = next_id
		queue_redraw()
	else:
		choose(next_id, {"shift": shift})
	return true


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree() or shell.windows.active_window_id != window_id:
		return null
	if id.begins_with("w95.folder-item:"):
		var r := entry_rect(int(id.get_slice(":", 1)))
		return r if r.size != Vector2.ZERO else null
	return null
