class_name BeChoice
extends Control
## Selectable cells used by the dialogs: a "list" (icon + name + detail rows), an "icons" grid (52x48 cells with a
## 32px icon) or "swatches" (46x32 colour chips). Signals: picked(id) on click, activated(id) on double-click.

signal picked(id: String)
signal activated(id: String)

var kind := "list"
var cells: Array = []     ## [{id, label, sub, tex: Texture2D, color: Color}]
var selected := ""
var max_h := 240.0
var _rects: Array = []
var _content_h := 0.0
var _scroll := 0.0


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


func _measure(w: float) -> void:
	_rects.clear()
	if kind == "list":
		for i in cells.size():
			_rects.append(Rect2(1, 1 + i * 24, w - 2, 24))
		_content_h = 2.0 + cells.size() * 24
		custom_minimum_size = Vector2(w, clampf(_content_h, 120.0, max_h))
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


func rect_of(id: String) -> Rect2:
	for i in cells.size():
		if String(cells[i].id) == id:
			var r: Rect2 = _rects[i]
			return Rect2(r.position - Vector2(0, _scroll), r.size)
	return Rect2()


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
				if mb.double_click:
					activated.emit(selected)
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll = clampf(_scroll + (36.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -36.0), 0.0, maxf(0.0, _content_h - size.y))
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
		if kind == "list":
			if on:
				BeDraw.fill(self, rr, BeTheme.b("a8a8a8"))
			BeDraw.icon(self, c.get("tex"), Rect2(rr.position.x + 8, rr.position.y + 4, 16, 16))
			var sub := String(c.get("sub", ""))
			var sub_w := minf(BeFont.width(sub, 14), rr.size.x * 0.55)
			BeFont.draw(self, Vector2(rr.position.x + 32, rr.position.y + 3), BeFont.clip(String(c.label), rr.size.x - 32 - 16 - sub_w - 8), BeTheme.t("000000"))
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
