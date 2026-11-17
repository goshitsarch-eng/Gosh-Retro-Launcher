class_name MacFolderView
extends Control
## Scrollable content of a folder window: icon grid ("as Icons") or list ("as List"), classic scroll bar,
## selection, open (double-click), context menu and the grow box. Entries are groups (Launcher HD window) or
## the items of a group.

var win: Control            ## MacFolderWindow
var _drag_scroll := false
var _drag_off := 0
var _arrow_hold := 0
var _cache_key := ""
var _layout: Dictionary = {}
var _scroll_visible := false
var _content_h := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	add_to_group("pm_auto")


# ------------------------------------------------------------------ model

func is_computer() -> bool:
	return win.key == "computer"


func group_id() -> String:
	return win.key.substr(2) if win.key.begins_with("g:") else ""


func entries() -> Array:
	var out := []
	if is_computer():
		for g in ProgramStore.groups:
			out.append({"id": String(g.id), "name": String(g.name), "icon": "folder", "c2": MacDialogLogic.plural(g.items.size(), "item"), "c3": "Program group"})
	else:
		var g := ProgramStore.find_group(group_id())
		var names := ProgramStore.launch_group_names()
		for it in g.get("items", []):
			out.append({"id": String(it.id), "name": String(it.name), "icon": String(it.get("icon", "")), "c2": String(it.path),
				"c3": MacDialogLogic.launch_group_cell(int(it.get("launchGroup", 0)), names)})
	return out


## True when the entries are already in name order (the order Clean Up produces). The list view has no
## sort of its own and shows the store order, so the Name column's sorted-column shading is drawn only when
## that order really is by name. Same comparator as MacDialogLogic.clean_up.
static func is_name_sorted(es: Array) -> bool:
	for i in range(1, es.size()):
		if String(es[i].name).naturalnocasecmp_to(String(es[i - 1].name)) < 0:
			return false
	return true


func _wrap_labels() -> bool:
	return String(ProgramStore.settings.get("labelDisplay", "wrap")) == "wrap"


func compute_layout() -> void:
	var st: Dictionary = win.state()
	var view := String(st.get("view", "large"))
	var es := entries()
	var vh := int(size.y)
	var w := int(size.x)
	_scroll_visible = false
	for pass_i in 2:
		var cw := w - (MacGeometry.SCROLL_W if _scroll_visible else 0)
		if view == "large":
			var specs := []
			for e in es:
				specs.append({"id": e.id, "lines": MacDraw.label_lines(String(e.name), MacGeometry.CELL_W - 12, _wrap_labels()).size()})
			_layout = MacGeometry.grid_layout(specs, cw)
		else:
			_layout = MacGeometry.details_layout(es, cw)
		_content_h = int(_layout.height)
		if _content_h > vh and not _scroll_visible:
			_scroll_visible = true
			continue
		break
	_layout["entries"] = es
	_layout["view"] = view


func scroll_offset() -> int:
	return clampi(int(win.state().get("scroll", 0)), 0, MacGeometry.max_scroll(int(size.y), _content_h))


func scrollbar_rect() -> Rect2:
	return Rect2(size.x - MacGeometry.SCROLL_W, 0, MacGeometry.SCROLL_W, size.y - MacGeometry.GRIP)


func _thumb() -> Rect2:
	var sb := scrollbar_rect()
	var track := int(sb.size.y) - MacGeometry.SCROLL_W * 2
	var t := MacGeometry.scroll_thumb(int(size.y), _content_h, scroll_offset(), track)
	return Rect2(sb.position.x, sb.position.y + MacGeometry.SCROLL_W + int(t.thumb_y), sb.size.x, int(t.thumb_h))


func grip_rect() -> Rect2:
	return Rect2(size.x - MacGeometry.GRIP - 0, size.y - MacGeometry.GRIP, MacGeometry.GRIP, MacGeometry.GRIP)


func _has_point(point: Vector2) -> bool:
	# the grow box belongs to the window (resize), not the content
	if grip_rect().has_point(point) and not win.state().get("shaded", false) and not win.state().get("zoomed", false):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if win == null or win.state().is_empty():
		return
	compute_layout()
	var st: Dictionary = win.state()
	var sel := String(st.get("sel", ""))
	var off := scroll_offset()
	draw_rect(Rect2(Vector2.ZERO, size), MacTheme.b("ffffff"))
	var es: Array = _layout.entries
	var active: bool = win.is_active()
	if _layout.view == "large":
		for i in _layout.cells.size():
			var cell: Dictionary = _layout.cells[i]
			var r: Rect2 = cell.rect
			if r.end.y - off < 0 or r.position.y - off > size.y:
				continue
			var e: Dictionary = es[i]
			var on: bool = e.id == sel
			MacDraw.icon(self, MacIconCatalog.texture(String(e.icon), "large"), cell.icon.position - Vector2(0, off), Vector2(32, 32), on)
			var lines := MacDraw.label_lines(String(e.name), MacGeometry.CELL_W - 12, _wrap_labels())
			var lr: Rect2 = cell.label
			MacDraw.icon_label(self, Rect2(lr.position - Vector2(0, off), lr.size), lines, on, MacTheme.b("ffffff"), MacTheme.t("000000"))
	else:
		_draw_details(es, sel, off)
	if _scroll_visible:
		_draw_scrollbar()
	MacDraw.grip(self, grip_rect(), true)


func _draw_details(es: Array, sel: String, off: int) -> void:
	var cols: Array = _layout.cols
	var h: Rect2 = _layout.header
	var by_name := is_name_sorted(es)
	for i in _layout.rows.size():
		var row: Rect2 = _layout.rows[i].rect
		var ry := row.position.y - off
		if ry + row.size.y < h.size.y or ry > size.y:
			continue
		var e: Dictionary = es[i]
		var on: bool = e.id == sel
		if on:
			draw_rect(Rect2(0, ry, row.size.x, row.size.y), MacTheme.b("ccccff"))
		elif by_name:
			draw_rect(Rect2(0, ry, cols[0].w, row.size.y), MacTheme.b("eeeeee"))
		Px.hline(self, 0, ry + row.size.y - 1, row.size.x, MacTheme.b("eeeeee"))
		draw_texture_rect(MacIconCatalog.texture(String(e.icon), "small"), Rect2(8, ry + 2, 16, 16), false)
		var fg := MacTheme.t("000000")
		MacDraw.text_centered_y(self, 30, ry, row.size.y - 1, String(e.name), fg, false, int(cols[0].w) - 36)
		MacDraw.text_centered_y(self, cols[1].x + 10, ry, row.size.y - 1, String(e.c2), fg, false, int(cols[1].w) - 14)
		MacDraw.text_centered_y(self, cols[2].x + 10, ry, row.size.y - 1, String(e.c3), fg, false, int(cols[2].w) - 14)
	# sticky header
	draw_rect(Rect2(0, 0, _layout.width, h.size.y), MacTheme.b("dddddd"))
	if by_name:
		draw_rect(Rect2(0, 0, cols[0].w, h.size.y), MacTheme.b("bbbbbb"))
	Px.hline(self, 0, h.size.y - 1, _layout.width, MacTheme.b("888888"))
	var names := ["Name", "Size" if is_computer() else "Command", "Type" if is_computer() else "Batch"]
	for i in 3:
		var cx: float = cols[i].x
		MacDraw.text_centered_y(self, cx + 10, 0, h.size.y - 1, names[i], MacTheme.t("000000"), false, int(cols[i].w) - 14)
		if i < 2:
			Px.vline(self, cx + cols[i].w - 1, 0, h.size.y - 1, MacTheme.b("888888"))
		Px.hline(self, cx, 0, cols[i].w - (1 if i < 2 else 0), MacTheme.s("cccccc") if i == 0 and by_name else MacTheme.s("ffffff"))


func _draw_scrollbar() -> void:
	var sb := scrollbar_rect()
	Px.checker(self, sb, MacTheme.b("ffffff"), MacTheme.b("cccccc"))
	Px.vline(self, sb.position.x, sb.position.y, sb.size.y, MacTheme.b("888888"))
	var up := Rect2(sb.position.x, sb.position.y, MacGeometry.SCROLL_W, MacGeometry.SCROLL_W)
	var down := Rect2(sb.position.x, sb.end.y - MacGeometry.SCROLL_W, MacGeometry.SCROLL_W, MacGeometry.SCROLL_W)
	for b in [up, down]:
		MacDraw.gradient_box(self, Rect2(b.position.x + 1, b.position.y, b.size.x - 1, b.size.y))
	MacDraw.mask(self, up.position + Vector2(5, 6), MacDraw.UP_ARROW_MASK, MacTheme.t("000000"))
	MacDraw.mask(self, down.position + Vector2(5, 6), MacDraw.DOWN_ARROW_MASK, MacTheme.t("000000"))
	var th := _thumb()
	MacDraw.gradient_box(self, Rect2(th.position.x + 1, th.position.y, th.size.x - 1, th.size.y))


# ------------------------------------------------------------------ hit testing

func entry_at(p: Vector2) -> String:
	if _layout.is_empty():
		return ""
	var q := p + Vector2(0, scroll_offset())
	if _layout.view == "large":
		for c in _layout.cells:
			var r: Rect2 = c.rect
			var hit := Rect2(c.icon.position.x - 4, r.position.y, 40, r.size.y)   # icon + label strip
			if hit.has_point(q) or Rect2(c.label).grow_individual(4, 0, 4, 0).has_point(q):
				return String(c.id)
		return ""
	if q.y < MacGeometry.DETAILS_HEADER_H:
		return ""
	for r in _layout.rows:
		if r.rect.has_point(q):
			return String(r.id)
	return ""


func _entry_rect(id: String) -> Rect2:
	if _layout.is_empty():
		return Rect2()
	var off := Vector2(0, scroll_offset())
	if _layout.view == "large":
		for c in _layout.cells:
			if c.id == id:
				return Rect2(c.rect.position - off, c.rect.size)
	else:
		for r in _layout.rows:
			if r.id == id:
				return Rect2(r.rect.position - off, r.rect.size)
	return Rect2()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll_by(-24)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_by(24)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				win.desk.activate_window(win.key)
				if _scroll_visible and scrollbar_rect().has_point(mb.position):
					_scrollbar_press(mb.position)
				else:
					var id := entry_at(mb.position)
					win.desk.store.set_selection(win.key, id)
					if id != "" and mb.double_click:
						win.desk.entry_activated(win.key, id)
			else:
				_drag_scroll = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			win.desk.activate_window(win.key)
			var id2 := entry_at(mb.position)
			win.desk.store.set_selection(win.key, id2)
			win.desk.entry_context(win.key, id2, mb.global_position)
		accept_event()
	elif event is InputEventMouseMotion and _drag_scroll:
		var mm := event as InputEventMouseMotion
		var track := int(scrollbar_rect().size.y) - MacGeometry.SCROLL_W * 2
		var th := _thumb()
		var travel := maxi(1, track - int(th.size.y))
		var max_off := MacGeometry.max_scroll(int(size.y), _content_h)
		var ty := mm.position.y - _drag_off - (scrollbar_rect().position.y + MacGeometry.SCROLL_W)
		win.desk.store.set_scroll(win.key, int(roundf(clampf(ty / travel, 0.0, 1.0) * max_off)))
		accept_event()


func _scrollbar_press(p: Vector2) -> void:
	var sb := scrollbar_rect()
	if p.y < sb.position.y + MacGeometry.SCROLL_W:
		_scroll_by(-16)
	elif p.y >= sb.end.y - MacGeometry.SCROLL_W:
		_scroll_by(16)
	else:
		var th := _thumb()
		if th.has_point(p):
			_drag_scroll = true
			_drag_off = int(p.y - th.position.y)
		elif p.y < th.position.y:
			_scroll_by(-int(size.y) + 16)
		else:
			_scroll_by(int(size.y) - 16)


func _scroll_by(delta: int) -> void:
	var maxs := MacGeometry.max_scroll(int(size.y), _content_h)
	win.desk.store.set_scroll(win.key, clampi(scroll_offset() + delta, 0, maxs))


## Keyboard: moves the selection (dir = Vector2i) through the entries in display order.
func move_selection(dir: Vector2i) -> void:
	var es: Array = entries()
	if es.is_empty():
		return
	var sel := String(win.state().get("sel", ""))
	var idx := -1
	for i in es.size():
		if es[i].id == sel:
			idx = i
	var per_row := 1
	if _layout.get("view", "large") == "large":
		per_row = maxi(1, (int(size.x) - (MacGeometry.SCROLL_W if _scroll_visible else 0) - MacGeometry.GRID_PAD * 2 + MacGeometry.CELL_GAP_X) / (MacGeometry.CELL_W + MacGeometry.CELL_GAP_X))
	var step := dir.x + dir.y * per_row
	var ni := 0 if idx < 0 else clampi(idx + step, 0, es.size() - 1)
	win.desk.store.set_selection(win.key, String(es[ni].id))
	_ensure_visible(String(es[ni].id))


func _ensure_visible(id: String) -> void:
	var r := _entry_rect(id)
	if r.size == Vector2.ZERO:
		return
	if r.position.y < 0:
		_scroll_by(int(r.position.y) - 4)
	elif r.end.y > size.y:
		_scroll_by(int(r.end.y - size.y) + 4)


## Automation: mac.window:<key>:item:<index|name>, mac.folder-item:<index|name> (active window), mac.folder-view.
func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree() or win == null or _layout.is_empty():
		return null
	var token := ""
	var p1 := "mac.window:%s:item:" % win.key
	if id.begins_with(p1):
		token = id.substr(p1.length())
	elif win.is_active() and id.begins_with("mac.folder-item:"):
		token = id.substr("mac.folder-item:".length())
	elif win.is_active() and id == "mac.folder-view":
		return Rect2(global_position, size)
	else:
		return null
	var es: Array = _layout.entries
	var target := ""
	if token.is_valid_int() and token.to_int() < es.size():
		target = String(es[token.to_int()].id)
	else:
		for e in es:
			if String(e.name) == token:
				target = String(e.id)
	if target == "":
		return null
	var r := _entry_rect(target)
	if r.size == Vector2.ZERO:
		return null
	if _layout.view == "large":
		for c in _layout.cells:
			if c.id == target:
				var ic: Rect2 = c.icon
				r = Rect2(ic.position - Vector2(0, scroll_offset()), Vector2(32, 32))
	return Rect2(r.position + global_position, r.size)
