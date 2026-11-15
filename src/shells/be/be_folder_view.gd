class_name BeFolderView
extends Control
## The white content area of a folder window: Icon / Mini Icon / List views with selection, wheel scrolling and a slim
## scrollbar. Entries come from BeDialogLogic.entries_for(); selection lives in the shell (one selected entry).

var shell: Control
var key := ""
var entries: Array = []
var view := "large"
var _cells: Array = []        ## per-entry Rect2 in content coordinates (before scroll)
var _lines: Array = []        ## large view: wrapped label lines per entry
var _content_h := 0.0
var _scroll := Vector2.ZERO
var _thumb_drag := false
var _thumb_off := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_NONE


func setup(p_shell: Control, p_key: String) -> void:
	shell = p_shell
	key = p_key


func inner() -> Rect2:
	return Rect2(1, 1, maxf(0.0, size.x - 2), maxf(0.0, size.y - 2))


func refresh(p_entries: Array, p_view: String) -> void:
	entries = p_entries
	view = p_view
	_layout()
	queue_redraw()


func _layout() -> void:
	var w := inner().size.x
	_cells.clear()
	_lines.clear()
	if view == "large":
		for e in entries:
			_lines.append(BeFont.wrap(String(e.name), 90.0))
		var lc := []
		for l in _lines:
			lc.append(l.size())
		var res := BeGeometry.large_cells(lc, w)
		_cells = res.rects
		_content_h = res.height
	elif view == "small":
		var res2 := BeGeometry.small_cells(entries.size(), w)
		_cells = res2.rects
		_content_h = res2.height
	else:
		for i in entries.size():
			_cells.append(Rect2(0, BeGeometry.DETAILS_HEAD_H + i * BeGeometry.DETAILS_ROW_H, maxf(w, BeGeometry.DETAILS_MIN_W), BeGeometry.DETAILS_ROW_H))
		_content_h = BeGeometry.DETAILS_HEAD_H + entries.size() * BeGeometry.DETAILS_ROW_H
	var max_y := maxf(0.0, _content_h - inner().size.y)
	_scroll.y = clampf(_scroll.y, 0.0, max_y)
	var max_x := maxf(0.0, (BeGeometry.DETAILS_MIN_W if view == "details" else 0.0) - w)
	_scroll.x = clampf(_scroll.x, 0.0, max_x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Rect (global logical coordinates) of entry `index`, scroll applied.
func entry_rect(index: int) -> Rect2:
	if index < 0 or index >= _cells.size():
		return Rect2()
	var c: Rect2 = _cells[index]
	return Rect2(get_global_rect().position + Vector2(1, 1) + c.position - _scroll, c.size)


func entry_index(id: String) -> int:
	for i in entries.size():
		if entries[i].id == id:
			return i
	return -1


func _index_at(p: Vector2) -> int:
	if view == "details" and p.y - 1 < BeGeometry.DETAILS_HEAD_H:
		return -1
	var q := p - Vector2(1, 1) + _scroll
	for i in range(_cells.size() - 1, -1, -1):
		if (_cells[i] as Rect2).has_point(q):
			if view == "details" and q.y < BeGeometry.DETAILS_HEAD_H:
				continue
			return i
	return -1


# ----------------------------------------------------------------- input

func _scroll_by(dy: float, dx: float = 0.0) -> void:
	var max_y := maxf(0.0, _content_h - inner().size.y)
	var max_x := maxf(0.0, (BeGeometry.DETAILS_MIN_W if view == "details" else 0.0) - inner().size.x)
	_scroll = Vector2(clampf(_scroll.x + dx, 0.0, max_x), clampf(_scroll.y + dy, 0.0, max_y))
	queue_redraw()


func _bar_rect() -> Rect2:
	var vh := inner().size.y
	if _content_h <= vh + 0.5:
		return Rect2()
	return Rect2(size.x - 1 - 12, 1, 12, vh)


func _thumb_rect() -> Rect2:
	var bar := _bar_rect()
	if bar.size == Vector2.ZERO:
		return Rect2()
	var vh := bar.size.y
	var th := maxf(24.0, vh * vh / _content_h)
	var max_y := _content_h - vh
	var ty := bar.position.y + (vh - th) * (_scroll.y / max_y if max_y > 0 else 0.0)
	return Rect2(bar.position.x + 2, ty, 8, th)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var p := mb.position
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var d := 36.0 * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
			if mb.shift_pressed:
				_scroll_by(0.0, d)
			else:
				_scroll_by(d)
			accept_event()
			return
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT):
			_scroll_by(0.0, 36.0 * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT else -1.0))
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var thumb := _thumb_rect()
				var bar := _bar_rect()
				if bar.size != Vector2.ZERO and bar.has_point(p):
					_thumb_drag = true
					_thumb_off = p.y - thumb.position.y if thumb.has_point(p) else thumb.size.y / 2.0
					_drag_thumb(p.y)
					accept_event()
					return
				shell.raise_window(key)
				var i := _index_at(p)
				if i >= 0:
					shell.select_entry(key, String(entries[i].id))
					if mb.double_click:
						shell.open_entry(key, String(entries[i].id))
				else:
					shell.clear_selection()
			else:
				_thumb_drag = false
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			shell.raise_window(key)
			var j := _index_at(p)
			if j >= 0:
				shell.select_entry(key, String(entries[j].id))
				shell.open_entry_menu(key, String(entries[j].id), get_global_rect().position + p)
			else:
				shell.clear_selection()
				shell.open_background_menu(key, get_global_rect().position + p)
			accept_event()
	elif event is InputEventMouseMotion and _thumb_drag:
		_drag_thumb((event as InputEventMouseMotion).position.y)
		accept_event()


func _drag_thumb(y: float) -> void:
	var bar := _bar_rect()
	if bar.size == Vector2.ZERO:
		return
	var th := maxf(24.0, bar.size.y * bar.size.y / _content_h)
	var f := clampf((y - _thumb_off - bar.position.y) / maxf(1.0, bar.size.y - th), 0.0, 1.0)
	_scroll.y = f * (_content_h - bar.size.y)
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	BeDraw.fill(self, r, BeTheme.b("ffffff"))
	var sel: String = shell.selected_id_in(key)
	var origin := Vector2(1, 1) - _scroll
	if view == "details":
		_draw_details(sel, origin)
	else:
		for i in entries.size():
			var rc := Rect2(origin + (_cells[i] as Rect2).position, (_cells[i] as Rect2).size)
			if rc.end.y < 0 or rc.position.y > size.y:
				continue
			_draw_entry(i, rc, entries[i].id == sel)
	_draw_bar()
	BeDraw.border(self, r, BeTheme.b("989898"))


func _draw_entry(i: int, rc: Rect2, on: bool) -> void:
	var e: Dictionary = entries[i]
	var tint := Color(BeTheme.FILTER_LARGE, BeTheme.FILTER_LARGE, BeTheme.FILTER_LARGE, 1.0) if on else Color.WHITE
	var fg := BeTheme.t("ffffff") if on else BeTheme.t("000000")
	var bg := BeTheme.b("000000")
	if view == "large":
		BeDraw.icon(self, BeIconCatalog.texture(String(e.icon), String(e.name)), Rect2(rc.position.x + (rc.size.x - 32) / 2.0, rc.position.y + 2, 32, 32), tint)
		var lines: PackedStringArray = _lines[i]
		var tw := 0.0
		for l in lines:
			tw = maxf(tw, BeFont.width(l))
		var box := Rect2(rc.position.x + (rc.size.x - tw - 10) / 2.0, rc.position.y + 2 + 32 + 4, tw + 10, lines.size() * BeGeometry.LINE + 2)
		if on:
			BeDraw.fill(self, box, bg)
		for n in lines.size():
			BeFont.draw_centered(self, rc.position.x + rc.size.x / 2.0, box.position.y + 1 + n * BeGeometry.LINE, lines[n], fg)
	else:
		BeDraw.icon(self, BeIconCatalog.texture(String(e.icon), String(e.name)), Rect2(rc.position.x + 2, rc.position.y + (rc.size.y - 16) / 2.0, 16, 16), tint)
		var label := BeFont.clip(String(e.name), rc.size.x - 2 - 16 - 6 - 10 - 2)
		var lw := BeFont.width(label)
		var box2 := Rect2(rc.position.x + 2 + 16 + 6, rc.position.y + 2, lw + 10, BeGeometry.LINE + 2)
		if on:
			BeDraw.fill(self, box2, bg)
		BeFont.draw(self, Vector2(box2.position.x + 5, box2.position.y + 1), label, fg)


func _draw_details(sel: String, origin: Vector2) -> void:
	var cols := BeGeometry.details_columns(inner().size.x)
	var tw: float = float(cols[4]) + float(cols[5])
	for i in entries.size():
		var rc := Rect2(origin.x, origin.y + BeGeometry.DETAILS_HEAD_H + i * BeGeometry.DETAILS_ROW_H, tw, BeGeometry.DETAILS_ROW_H)
		if rc.end.y < 0 or rc.position.y > size.y:
			continue
		var e: Dictionary = entries[i]
		if e.id == sel:
			BeDraw.fill(self, rc, BeTheme.b("c8c8c8"))
		BeDraw.icon(self, BeIconCatalog.texture(String(e.icon), String(e.name)), Rect2(rc.position.x + 8, rc.position.y + 4, 16, 16))
		var col := BeTheme.t("000000")
		BeFont.draw(self, Vector2(rc.position.x + 8 + 16 + 6, rc.position.y + 3), BeFont.clip(String(e.name), float(cols[1]) - 8 - 16 - 6 - 8), col)
		BeFont.draw(self, Vector2(rc.position.x + float(cols[2]) + 10, rc.position.y + 3), BeFont.clip(String(e.c2), float(cols[3]) - 20), col)
		BeFont.draw(self, Vector2(rc.position.x + float(cols[4]) + 10, rc.position.y + 3), BeFont.clip(String(e.c3), float(cols[5]) - 20), col)
	# sticky header
	var hr := Rect2(1 - _scroll.x, 1, tw, BeGeometry.DETAILS_HEAD_H)
	BeDraw.gradient_v(self, hr, BeTheme.b("f4f4f4"), BeTheme.b("d4d4d4"))
	BeDraw.hline(self, hr.position.x, hr.end.y - 1, hr.size.x, BeTheme.b("989898"))
	var labels := ["Name", "Size" if key == BeWindowStore.COMPUTER else "Command", "Type" if key == BeWindowStore.COMPUTER else "Batch"]
	for n in 3:
		var cx: float = hr.position.x + float(cols[n * 2])
		BeFont.draw(self, Vector2(cx + 10, hr.position.y + 4), labels[n], BeTheme.t("000000"), BeGeometry.FONT, true)
		if n < 2:
			BeDraw.vline(self, cx + float(cols[n * 2 + 1]) - 1, hr.position.y, hr.size.y - 1, BeTheme.b("b8b8b8"))


func _draw_bar() -> void:
	var bar := _bar_rect()
	if bar.size == Vector2.ZERO:
		return
	BeDraw.fill(self, bar, BeTheme.b("e8e8e8"))
	BeDraw.vline(self, bar.position.x, bar.position.y, bar.size.y, BeTheme.b("b8b8b8"))
	var th := _thumb_rect()
	BeDraw.button_face(self, th, BeTheme.b("fafafa"), BeTheme.b("d4d4d4"), BeTheme.b("6a6a6a"), 3.0)
