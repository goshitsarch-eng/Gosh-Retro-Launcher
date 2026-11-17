class_name MacListBox
extends Control
## Single-selection list (Help topics, Browse, Shut Down choices, Launch Groups) and, with `grid = true`, an icon
## grid (Change Icon). Rows: {id, label, sub?, icon?, checked?, auto?}. Selected row = #33339a with white text.
## Double-click emits `activated`. With `checks = true` every row carries a check box (the Launch Groups Members
## checklist): a click selects the row and flips its box (`toggled`). A classic scroll bar appears when the rows do
## not fit; `empty_text` is drawn when there are no rows.

signal selection_changed(id: String)
signal activated(id: String)
signal toggled(id: String, on: bool)

const ROW_H := 20
const CELL := Vector2(52, 48)

var rows: Array = []
var selected_id := ""
var grid := false
var checks := false
var empty_text := ""
var _scroll := 0
var _auto := ""
var _drag_thumb := false
var _drag_off := 0


func _init(p_auto_id: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_auto = p_auto_id
	add_to_group("pm_auto")
	if p_auto_id != "":
		set_meta("auto_id", p_auto_id)


func _content_h() -> int:
	if grid:
		var per := maxi(1, int((size.x - 12) / CELL.x))
		return 12 + int(ceil(float(rows.size()) / per)) * int(CELL.y + 4)
	return rows.size() * ROW_H


func _has_scrollbar() -> bool:
	return not grid and _content_h() > int(size.y)


func _row_w() -> float:
	return size.x - (MacGeometry.SCROLL_W if _has_scrollbar() else 0)


func _cell_rect(i: int) -> Rect2:
	if grid:
		var per := maxi(1, int((size.x - 12) / CELL.x))
		return Rect2(6 + (i % per) * CELL.x, 6 + (i / per) * (CELL.y + 4) - _scroll, CELL.x, CELL.y)
	return Rect2(0, i * ROW_H - _scroll, _row_w(), ROW_H)


func _max_scroll() -> int:
	return MacGeometry.max_scroll(int(size.y), _content_h())


func scrollbar_rect() -> Rect2:
	return Rect2(size.x - MacGeometry.SCROLL_W, 0, MacGeometry.SCROLL_W, size.y)


func _thumb() -> Rect2:
	var sb := scrollbar_rect()
	var track := int(sb.size.y) - MacGeometry.SCROLL_W * 2
	var t := MacGeometry.scroll_thumb(int(size.y), _content_h(), _scroll, track)
	return Rect2(sb.position.x, sb.position.y + MacGeometry.SCROLL_W + int(t.thumb_y), sb.size.x, int(t.thumb_h))


func _draw() -> void:
	_scroll = clampi(_scroll, 0, _max_scroll())
	draw_rect(Rect2(Vector2.ZERO, size), MacTheme.b("ffffff"))
	if rows.is_empty() and empty_text != "":
		var lines := MacDraw.font().wrap(MacDraw.glyph_safe(empty_text).replace("&", "&&"), int(size.x) - 24)
		for li in lines.size():
			MacDraw.text(self, Vector2(12, 10 + li * RetroFont.LABEL_LINE_HEIGHT), lines[li], MacTheme.t("888888"))
	for i in rows.size():
		var r := _cell_rect(i)
		if r.end.y < 0 or r.position.y > size.y:
			continue
		var row: Dictionary = rows[i]
		var on: bool = String(row.id) == selected_id
		if on:
			draw_rect(r, MacTheme.b("33339a"))
		if grid:
			draw_texture_rect(MacIconCatalog.texture(String(row.get("icon", "")), "large"), Rect2(r.position + Vector2(10, 8), Vector2(32, 32)), false)
			continue
		var fg := MacTheme.t("ffffff") if on else MacTheme.t("000000")
		var tx := r.position.x + 8
		if checks:
			MacDraw.checkbox(self, Rect2(tx, r.position.y + 3, 13, 13), row.get("checked", false))
			tx += 20
		if row.has("icon"):
			draw_texture_rect(MacIconCatalog.texture(String(row.icon), "small"), Rect2(tx, r.position.y + 2, 16, 16), false)
			tx += 24
		var sub := String(row.get("sub", ""))
		var sub_w := mini(MacDraw.measure(sub), int(r.size.x * 0.5)) if sub != "" else 0
		MacDraw.text_centered_y(self, tx, r.position.y, ROW_H, String(row.label), fg, false, int(r.size.x - tx - sub_w - 16))
		if sub != "":
			MacDraw.text_centered_y(self, r.size.x - 8 - sub_w, r.position.y, ROW_H, sub, fg if on else MacTheme.t("888888"), false, sub_w)
	if _has_scrollbar():
		_draw_scrollbar()
	Px.outline(self, Rect2(Vector2.ZERO, size), MacTheme.b("888888"))


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


func _index_at(p: Vector2) -> int:
	for i in rows.size():
		if _cell_rect(i).has_point(p):
			return i
	return -1


func index_of(id: String) -> int:
	for i in rows.size():
		if String(rows[i].id) == id:
			return i
	return -1


func select(id: String) -> void:
	selected_id = id
	ensure_visible(id)
	selection_changed.emit(selected_id)
	queue_redraw()


## Keyboard: moves the selection by `dir` rows (the first row when nothing is selected).
func step(dir: int) -> void:
	if rows.is_empty():
		return
	var i := index_of(selected_id)
	var ni := 0 if i < 0 else clampi(i + dir, 0, rows.size() - 1)
	select(String(rows[ni].id))


## Flips the check box of row `id` (checks mode).
func toggle(id: String) -> void:
	var i := index_of(id)
	if not checks or i < 0:
		return
	rows[i]["checked"] = not rows[i].get("checked", false)
	toggled.emit(id, rows[i].checked)
	queue_redraw()


func ensure_visible(id: String) -> void:
	var i := index_of(id)
	if i < 0 or grid:
		return
	var top := i * ROW_H
	if top < _scroll:
		_scroll = top
	elif top + ROW_H > _scroll + int(size.y):
		_scroll = top + ROW_H - int(size.y)
	_scroll = clampi(_scroll, 0, _max_scroll())
	queue_redraw()


func _scroll_by(delta: int) -> void:
	_scroll = clampi(_scroll + delta, 0, _max_scroll())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_thumb = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _has_scrollbar() and scrollbar_rect().has_point(mb.position):
			_scrollbar_press(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _index_at(mb.position)
			if i >= 0:
				selected_id = String(rows[i].id)
				selection_changed.emit(selected_id)
				if checks:
					toggle(selected_id)
				queue_redraw()
				if mb.double_click and not checks:
					activated.emit(selected_id)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll_by(-24 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 24)
		accept_event()
	elif event is InputEventMouseMotion and _drag_thumb:
		var mm := event as InputEventMouseMotion
		var track := int(scrollbar_rect().size.y) - MacGeometry.SCROLL_W * 2
		var travel := maxi(1, track - int(_thumb().size.y))
		var ty := mm.position.y - _drag_off - MacGeometry.SCROLL_W
		_scroll = int(roundf(clampf(ty / travel, 0.0, 1.0) * _max_scroll()))
		queue_redraw()
		accept_event()


func _scrollbar_press(p: Vector2) -> void:
	var sb := scrollbar_rect()
	if p.y < sb.position.y + MacGeometry.SCROLL_W:
		_scroll_by(-ROW_H)
	elif p.y >= sb.end.y - MacGeometry.SCROLL_W:
		_scroll_by(ROW_H)
	else:
		var th := _thumb()
		if th.has_point(p):
			_drag_thumb = true
			_drag_off = int(p.y - th.position.y)
		elif p.y < th.position.y:
			_scroll_by(-int(size.y) + ROW_H)
		else:
			_scroll_by(int(size.y) - ROW_H)


## Automation: <auto_id>:<row id | label | auto | index> (scrolled into view first).
func auto_lookup(id: String) -> Variant:
	if _auto == "" or not is_visible_in_tree() or not id.begins_with(_auto + ":"):
		return null
	var token := id.substr(_auto.length() + 1)
	for i in rows.size():
		if String(rows[i].id) == token or String(rows[i].label) == token or String(rows[i].get("auto", "")) == token or str(i) == token:
			ensure_visible(String(rows[i].id))
			var r := _cell_rect(i)
			return Rect2(global_position + r.position, r.size)
	return null
