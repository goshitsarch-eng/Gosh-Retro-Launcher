class_name BeChoice
extends Control
## Selectable cells used by the dialogs: a "list" (icon + name + detail rows), a "checks" list (the same rows with a
## check box in front; a click toggles it), an "icons" grid (52x48 cells with a 32px icon) or "swatches" (46x32 colour
## chips). Lists taller than their box scroll (wheel, slim scrollbar). Signals: picked(id) on click, activated(id) on
## double-click, toggled(id, on) when a "checks" box changes. Automation: "<auto_id>:<cell id>" is a cell's rect.

signal picked(id: String)
signal activated(id: String)
signal toggled(id: String, on: bool)

const ROW_H := 24.0

var kind := "list"
var cells: Array = []     ## [{id, label, sub, tex: Texture2D, color: Color, checked?: bool}]
var selected := ""
var max_h := 240.0
var min_h := 120.0
var _rects: Array = []
var _content_h := 0.0
var _scroll := 0.0
var _width := 0.0


static func make(p_kind: String, p_cells: Array, p_selected: String, p_width: float, p_id: String = "") -> BeChoice:
	var c := BeChoice.new()
	c.kind = p_kind
	c.cells = p_cells
	c.selected = p_selected
	c.max_h = 220.0 if p_kind == "icons" else 240.0
	c._measure(p_width)
	if p_id != "":
		BeUi.auto_id(c, p_id)
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _is_rows() -> bool:
	return kind == "list" or kind == "checks"


func _measure(w: float) -> void:
	_width = w
	_rects.clear()
	if _is_rows():
		_content_h = 2.0 + cells.size() * ROW_H
		var box_h := clampf(_content_h, min_h, max_h)
		var row_w := w - 2 - (BeGeometry.SCROLLBAR if _content_h > box_h else 0.0)
		for i in cells.size():
			_rects.append(Rect2(1, 1 + i * ROW_H, row_w, ROW_H))
		custom_minimum_size = Vector2(w, box_h)
	elif kind == "icons":
		var per := maxi(1, int(floorf((w - 12 + 4) / 56.0)))
		for i in cells.size():
			_rects.append(Rect2(6 + (i % per) * 56, 6 + (i / per) * 52, 52, 48))
		_content_h = 12.0 + int(ceilf(float(cells.size()) / per)) * 52 - 4
		custom_minimum_size = Vector2(w, minf(_content_h, max_h))
	else:
		var per2 := maxi(1, int(floorf((w - 8 + 10) / 56.0)))
		for i in cells.size():
			_rects.append(Rect2(4 + (i % per2) * 56, 4 + (i / per2) * 42, 46, 32))
		_content_h = 8.0 + int(ceilf(float(cells.size()) / per2)) * 42 - 10
		custom_minimum_size = Vector2(w, _content_h)
	_scroll = clampf(_scroll, 0.0, _max_scroll())


## Fixes a "list" / "checks" box at `rows` rows high (a longer list scrolls).
func fixed_rows(rows: int) -> void:
	min_h = 2.0 + rows * ROW_H
	max_h = min_h
	_measure(_width)


## Replaces the cells (e.g. after the store changed), keeping the box size and, when it still exists, the selection.
func set_cells(p_cells: Array, p_selected: String) -> void:
	cells = p_cells
	selected = p_selected
	var keep := custom_minimum_size.y
	_measure(_width)
	if _is_rows():
		custom_minimum_size.y = keep  # the dialog was laid out for this height
		_measure_rows_in(keep)
	ensure_visible(selected)
	queue_redraw()


func _measure_rows_in(box_h: float) -> void:
	var row_w := _width - 2 - (BeGeometry.SCROLLBAR if _content_h > box_h else 0.0)
	for i in _rects.size():
		_rects[i] = Rect2(1, 1 + i * ROW_H, row_w, ROW_H)
	_scroll = clampf(_scroll, 0.0, _max_scroll())


func _view_h() -> float:
	return size.y if size.y > 0 else custom_minimum_size.y


func _max_scroll() -> float:
	return maxf(0.0, _content_h - _view_h())


func index_of(id: String) -> int:
	for i in cells.size():
		if String(cells[i].id) == id:
			return i
	return -1


func rect_of(id: String) -> Rect2:
	var i := index_of(id)
	if i < 0:
		return Rect2()
	var r: Rect2 = _rects[i]
	return Rect2(r.position - Vector2(0, _scroll), r.size)


func auto_lookup(id: String) -> Variant:
	var base := String(get_meta("auto_id", ""))
	if base == "" or not is_visible_in_tree():
		return null
	if id == base:
		return get_global_rect()
	if id.begins_with(base + ":"):
		var r := rect_of(id.substr(base.length() + 1))
		if r.size != Vector2.ZERO:
			return Rect2(get_global_rect().position + r.position, r.size)
	return null


## Scrolls so cell `id` is fully in view.
func ensure_visible(id: String) -> void:
	var i := index_of(id)
	if i < 0:
		return
	var r: Rect2 = _rects[i]
	var view_h := _view_h()
	if r.position.y - 1 < _scroll:
		_scroll = maxf(0.0, r.position.y - 1)
	elif r.end.y + 1 > _scroll + view_h:
		_scroll = r.end.y + 1 - view_h
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	queue_redraw()


## Keyboard: moves the selection `delta` rows (clamped); selects the first row when none is selected.
func move_selection(delta: int) -> void:
	if cells.is_empty():
		return
	var i := index_of(selected)
	i = 0 if i < 0 else clampi(i + delta, 0, cells.size() - 1)
	selected = String(cells[i].id)
	ensure_visible(selected)
	picked.emit(selected)


## "checks": flips the box of cell `id`.
func toggle(id: String) -> void:
	var i := index_of(id)
	if i < 0 or kind != "checks":
		return
	cells[i]["checked"] = not bool(cells[i].get("checked", false))
	queue_redraw()
	toggled.emit(id, bool(cells[i].checked))


func checked_ids() -> Array:
	var out := []
	for c in cells:
		if bool(c.get("checked", false)):
			out.append(String(c.id))
	return out


func _cell_at(p: Vector2) -> int:
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(p + Vector2(0, _scroll)):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _cell_at(mb.position)
			if i >= 0:
				selected = String(cells[i].id)
				queue_redraw()
				picked.emit(selected)
				if kind == "checks":
					toggle(selected)
				elif mb.double_click:
					activated.emit(selected)
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll = clampf(_scroll + (36.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -36.0), 0.0, _max_scroll())
			queue_redraw()
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if kind != "swatches":
		BeDraw.fill(self, r, BeTheme.b("ffffff"))
		BeDraw.border(self, r, BeTheme.b("989898"))
	for i in cells.size():
		var c: Dictionary = cells[i]
		var rr: Rect2 = Rect2((_rects[i] as Rect2).position - Vector2(0, _scroll), (_rects[i] as Rect2).size)
		if rr.end.y < 0 or rr.position.y > size.y:
			continue
		var on := String(c.id) == selected
		if _is_rows():
			if on:
				BeDraw.fill(self, rr, BeTheme.b("a8a8a8"))
			var x := rr.position.x + 8
			if kind == "checks":
				BeCheck.draw_box(self, Rect2(x, rr.position.y + 4, 15, 15), bool(c.get("checked", false)))
				x += 15 + 8
			BeDraw.icon(self, c.get("tex"), Rect2(x, rr.position.y + 4, 16, 16))
			x += 24
			var sub := String(c.get("sub", ""))
			var sub_w := minf(BeFont.width(sub, 14), rr.size.x * 0.55)
			BeFont.draw(self, Vector2(x, rr.position.y + 3), BeFont.clip(String(c.label), rr.end.x - x - 16 - sub_w - 8), BeTheme.t("000000"))
			if sub != "":
				BeFont.draw(self, Vector2(rr.end.x - 8 - sub_w, rr.position.y + 3), BeFont.clip(sub, sub_w, 14), BeTheme.t("444444"), 14)
		elif kind == "icons":
			if on:
				BeDraw.fill(self, rr, BeTheme.b("a8a8a8"))
			BeDraw.icon(self, c.get("tex"), Rect2(rr.position.x + 10, rr.position.y + 8, 32, 32))
		else:
			if on:
				BeDraw.border(self, rr.grow(2), BeTheme.s("ffffff"))
				BeDraw.border(self, rr.grow(3), BeTheme.s("ffffff"))
				BeDraw.border(self, rr.grow(4), BeTheme.t("000080"))
			BeDraw.fill(self, rr, c.color)
			BeDraw.border(self, rr, BeTheme.b("000000"))
	if _is_rows() and _content_h > size.y and size.y > 0:
		# slim scrollbar, drawn like the folder windows'
		var bar := Rect2(size.x - 1 - BeGeometry.SCROLLBAR, 1, BeGeometry.SCROLLBAR, size.y - 2)
		BeDraw.fill(self, bar, BeTheme.b("e8e8e8"))
		BeDraw.vline(self, bar.position.x, bar.position.y, bar.size.y, BeTheme.b("b8b8b8"))
		var t := BeGeometry.scroll_thumb(bar.size.y, size.y - 2, _content_h - 2, _scroll)
		BeDraw.button_face(self, Rect2(bar.position.x + 2, bar.position.y + t.x, bar.size.x - 4, t.y),
			BeTheme.b("fafafa"), BeTheme.b("d4d4d4"), BeTheme.b("6a6a6a"), 3.0)
