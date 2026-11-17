class_name BePopup
extends Control
## A popup menu: context menus, folder menu-bar dropdowns, select lists and the Deskbar menu with its group
## submenus. It covers the whole shell (so it can see motion and outside presses); a press outside closes it and is
## replayed to whatever lies below (the design closes menus on pointerdown and lets the click through).
## Rows: {label, bold?, disabled?, dot?, icon?: Texture2D, swatch?: Color, children?: Array, sep?}. Row picks emit
## `picked(row)`. A swatch is a small colour sample at the right end of the row (the note menu's paper colours).
## A menu taller than the shell is cut to fit and scrolls: arrow strips at its top and bottom scroll while the pointer
## rests on them, and the wheel and the arrow keys scroll too.

signal picked(row: Dictionary)
signal closed
signal sibling_hover(index: int)  ## pointer moved over one of `siblings` (menu-bar titles)

const PAD_Y := 3
const ARROW_H := 16.0
const SCROLL_STEP := 6.0
const SWATCH_ROOM := 18.0   ## room right of the label for a submenu caret or a colour swatch
const SWATCH := Vector2(14, 10)

var rows: Array = []
var at := Vector2.ZERO
var item_h := BeGeometry.MENU_ITEM_H
var min_w := 200.0
var child_min_w := 220.0    ## minimum width of a submenu
var pad_left := 26.0        ## text x inset (dot / icon sits in the gutter)
var icons := false          ## rows carry 16px icons
var submenu_left := false   ## children open to the left (Deskbar menu)
var align_right := false    ## `at.x` is the popup's right edge
var anchor := Rect2()       ## pressing here closes without replay (the title that opened it)
var siblings: Array = []    ## Array[Rect2] of other menu titles
var hover := -1
var hover_child := -1
var open_child := -1        ## row index whose children are shown
var _rect := Rect2()
var _child_rect := Rect2()
var _closing := false
var _scroll_main := 0.0
var _scroll_child := 0.0
var _arrow := Vector2i.ZERO   ## (list: 0 main / 1 child, dir: -1 up / +1 down) while the pointer rests on an arrow strip
var _timer: Timer


static func open(layer: Control, p_rows: Array, p_at: Vector2, opts: Dictionary = {}) -> BePopup:
	var p := BePopup.new()
	for k in opts:
		p.set(k, opts[k])
	p.rows = p_rows
	p.at = p_at
	layer.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p._layout()
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("pm_auto")
	set_meta("auto_id", "be.popup")
	_timer = Timer.new()
	_timer.wait_time = 0.04
	_timer.timeout.connect(_on_arrow_tick)
	add_child(_timer)


func auto_lookup(id: String) -> Variant:
	if id == "be.popup":
		return Rect2(_rect.position, _rect.size)
	if id.begins_with("be.popup-item:"):
		var label := id.substr("be.popup-item:".length())
		for i in rows.size():
			if String(rows[i].get("label", "")) == label and not rows[i].get("sep", false):
				_scroll_main = _reveal(_rect, rows, i, _scroll_main)
				queue_redraw()
				return _row_rect(_rect, rows, i, _scroll_main)
		if open_child >= 0:
			var kids: Array = rows[open_child].get("children", [])
			for i in kids.size():
				if String(kids[i].get("label", "")) == label:
					_scroll_child = _reveal(_child_rect, kids, i, _scroll_child)
					queue_redraw()
					return _row_rect(_child_rect, kids, i, _scroll_child)
	return null


func _text_w(row: Dictionary) -> float:
	return BeFont.width(String(row.get("label", "")), BeGeometry.FONT, bool(row.get("bold", false)))


func _measure(list: Array, p_min_w: float) -> Vector2:
	var widest := 0.0
	var arrow := 0.0
	for r in list:
		if r.get("sep", false):
			continue
		widest = maxf(widest, _text_w(r))
		if r.has("children") or r.has("swatch"):
			arrow = SWATCH_ROOM
	return BeGeometry.menu_size(list, widest, item_h, p_min_w, pad_left, 16.0 + arrow)


func _layout() -> void:
	var s := _measure(rows, min_w)
	var view := size if size.x > 0 else get_viewport_rect().size
	s.y = minf(s.y, view.y - 4.0)  # taller menus scroll
	var origin := Vector2(at.x - s.x, at.y) if align_right else at
	_rect = Rect2(BeGeometry.fit_popup(origin, s, view), s)
	queue_redraw()


## True when `list` is taller than its (cut) `frame`.
func _overflows(frame: Rect2, list: Array) -> bool:
	return frame.size.y + 0.5 < _measure(list, 0.0).y


## The part of a scrolling frame between its arrow strips (the whole frame otherwise).
func _band(frame: Rect2, list: Array) -> Rect2:
	if not _overflows(frame, list):
		return frame
	return Rect2(frame.position.x + 1, frame.position.y + 1 + ARROW_H, frame.size.x - 2, frame.size.y - 2 - 2 * ARROW_H)


func _max_scroll(frame: Rect2, list: Array) -> float:
	if not _overflows(frame, list):
		return 0.0
	return maxf(0.0, _measure(list, 0.0).y - frame.size.y + 2 * ARROW_H)


## Scroll offset that shows row `index` whole.
func _reveal(frame: Rect2, list: Array, index: int, sc: float) -> float:
	var band := _band(frame, list)
	var rr := _row_rect(frame, list, index, sc)
	if rr.position.y < band.position.y:
		sc -= band.position.y - rr.position.y
	elif rr.end.y > band.end.y:
		sc += rr.end.y - band.end.y
	return clampf(sc, 0.0, _max_scroll(frame, list))


func _row_rect(frame: Rect2, list: Array, index: int, sc: float = 0.0) -> Rect2:
	var y := frame.position.y + 1 + PAD_Y + (ARROW_H if _overflows(frame, list) else 0.0) - sc
	for i in index:
		y += BeGeometry.MENU_SEP_H if list[i].get("sep", false) else item_h
	return Rect2(frame.position.x + 1, y, frame.size.x - 2, item_h)


func _row_at(frame: Rect2, list: Array, p: Vector2, sc: float = 0.0) -> int:
	if not frame.has_point(p) or not _band(frame, list).has_point(p):
		return -1
	for i in list.size():
		if list[i].get("sep", false):
			continue
		if _row_rect(frame, list, i, sc).has_point(p):
			return i
	return -1


## -1 / +1 when `p` is on the up / down arrow strip of a scrolling frame, else 0.
func _arrow_at(frame: Rect2, list: Array, p: Vector2) -> int:
	if not frame.has_point(p) or not _overflows(frame, list):
		return 0
	var band := _band(frame, list)
	if p.y < band.position.y:
		return -1
	if p.y >= band.end.y:
		return 1
	return 0


func _scroll_by(which: int, dy: float) -> void:
	if which == 0:
		var before := _scroll_main
		_scroll_main = clampf(_scroll_main + dy, 0.0, _max_scroll(_rect, rows))
		if _scroll_main != before:
			open_child = -1  # the submenu belonged to a row that moved
	elif open_child >= 0:
		_scroll_child = clampf(_scroll_child + dy, 0.0, _max_scroll(_child_rect, _kids(open_child)))
	queue_redraw()


func _on_arrow_tick() -> void:
	if _arrow.y == 0 or _closing:
		_timer.stop()
		return
	_scroll_by(_arrow.x, _arrow.y * SCROLL_STEP)


func _child_frame(index: int) -> Rect2:
	var kids: Array = rows[index].get("children", [])
	var list := kids if not kids.is_empty() else [{"label": "(empty)", "disabled": true}]
	var s := _measure(list, child_min_w)
	var rr := _row_rect(_rect, rows, index, _scroll_main)
	var x := rr.position.x - s.x - 2 + 1 if submenu_left else _rect.end.x + 2
	var view := size if size.x > 0 else get_viewport_rect().size
	s.y = minf(s.y, view.y - 4.0)
	var y := minf(rr.position.y - 4, view.y - s.y - 4.0)
	return Rect2(Vector2(maxf(0.0, x), maxf(0.0, y)), s)


func _kids(index: int) -> Array:
	var kids: Array = rows[index].get("children", [])
	return kids if not kids.is_empty() else [{"label": "(empty)", "disabled": true}]


func _draw_list(frame: Rect2, list: Array, hover_i: int, sc: float = 0.0) -> void:
	BeDraw.popup_frame(self, frame)
	var over := _overflows(frame, list)
	var band := _band(frame, list)
	var y := frame.position.y + 1 + PAD_Y + (ARROW_H if over else 0.0) - sc
	for i in list.size():
		var r: Dictionary = list[i]
		var h: float = BeGeometry.MENU_SEP_H if r.get("sep", false) else float(item_h)
		if over and (y + h <= band.position.y or y >= band.end.y):
			y += h
			continue
		if r.get("sep", false):
			BeDraw.separator(self, frame.position.x + 1, y, frame.size.x - 2)
			y += BeGeometry.MENU_SEP_H
			continue
		var rr := Rect2(frame.position.x + 1, y, frame.size.x - 2, item_h)
		var disabled := bool(r.get("disabled", false))
		if i == hover_i and not disabled:
			BeDraw.fill(self, rr, BeTheme.b("a8a8a8"))
		var col := BeTheme.t("808080") if disabled else BeTheme.t("000000")
		if bool(r.get("dot", false)):
			draw_circle(Vector2(rr.position.x + 12, rr.position.y + item_h / 2.0), 3.0, col)
		if icons and r.get("icon") != null:
			BeDraw.icon(self, r.icon, Rect2(rr.position.x + 10, rr.position.y + (item_h - 16) / 2.0, 16, 16))
		BeFont.draw(self, Vector2(rr.position.x + pad_left, rr.position.y + (item_h - BeGeometry.LINE) / 2.0),
			String(r.get("label", "")), col, BeGeometry.FONT, bool(r.get("bold", false)))
		if r.has("children"):
			BeDraw.caret_right(self, rr.end.x - 14, rr.position.y + (item_h - 8) / 2.0, BeTheme.b("000000"))
		elif r.get("swatch") is Color:
			var sw := Rect2(Vector2(rr.end.x - 10 - SWATCH.x, rr.position.y + floorf((item_h - SWATCH.y) / 2.0)), SWATCH)
			BeDraw.fill(self, sw, r.swatch)
			BeDraw.border(self, sw, BeTheme.t("808080"))
		y += item_h
	if over:
		_draw_arrows(frame, band, sc > 0.0, sc < _max_scroll(frame, list))


## The scroll strips of a cut menu, painted over any row that runs under them.
func _draw_arrows(frame: Rect2, band: Rect2, up: bool, down: bool) -> void:
	var w := frame.size.x - 2
	var cx := floorf(frame.position.x + frame.size.x / 2.0)
	var top := Rect2(frame.position.x + 1, frame.position.y + 1, w, ARROW_H)
	var bottom := Rect2(frame.position.x + 1, band.end.y, w, ARROW_H)
	for strip in [top, bottom]:
		BeDraw.fill(self, strip, BeTheme.b("e8e8e8"))
	BeDraw.hline(self, top.position.x, top.end.y - 1, w, BeTheme.b("c8c8c8"))
	BeDraw.hline(self, bottom.position.x, bottom.position.y, w, BeTheme.b("c8c8c8"))
	var on := BeTheme.t("000000")
	var off := BeTheme.t("a8a8a8")
	var ty := top.position.y + 5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, ty + 5), Vector2(cx + 4, ty + 5), Vector2(cx, ty)]), on if up else off)
	var by := bottom.position.y + 5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, by), Vector2(cx + 4, by), Vector2(cx, by + 5)]), on if down else off)


func _draw() -> void:
	_draw_list(_rect, rows, hover if open_child < 0 else open_child, _scroll_main)
	if open_child >= 0:
		var kids := _kids(open_child)
		_draw_list(_child_rect, kids, hover_child, _scroll_child)


func _is_in_menus(p: Vector2) -> bool:
	return _rect.has_point(p) or (open_child >= 0 and _child_rect.has_point(p))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var dy := float(item_h) * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
			if open_child >= 0 and _child_rect.has_point(mb.position):
				_scroll_by(1, dy)
			elif _rect.has_point(mb.position):
				_scroll_by(0, dy)
			accept_event()
			return
		var p := mb.position
		if _is_in_menus(p):
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_press(p)
			accept_event()
			return
		var replay := not anchor.has_point(p)
		close()
		if replay:
			_replay.call_deferred(mb.duplicate())
		accept_event()


func _replay(ev: InputEvent) -> void:
	if is_inside_tree():
		get_viewport().push_input(ev, true)


func _motion(p: Vector2) -> void:
	for i in siblings.size():
		if (siblings[i] as Rect2).has_point(p):
			sibling_hover.emit(i)
			return
	var arrow := Vector2i.ZERO
	if open_child >= 0 and _child_rect.has_point(p):
		arrow = Vector2i(1, _arrow_at(_child_rect, _kids(open_child), p))
	elif _rect.has_point(p):
		arrow = Vector2i(0, _arrow_at(_rect, rows, p))
	_arrow = arrow
	if _arrow.y != 0:
		if _timer.is_stopped():
			_timer.start()
		return
	if open_child >= 0 and _child_rect.has_point(p):
		hover_child = _row_at(_child_rect, _kids(open_child), p, _scroll_child)
		queue_redraw()
		return
	var i := _row_at(_rect, rows, p, _scroll_main)
	if i >= 0:
		hover = i
		hover_child = -1
		if rows[i].has("children") and not rows[i].get("disabled", false):
			if open_child != i:
				_scroll_child = 0.0
			open_child = i
			_child_rect = _child_frame(i)
		else:
			open_child = -1
	elif not _rect.has_point(p):
		hover = -1
	queue_redraw()


func _press(p: Vector2) -> void:
	if open_child >= 0 and _child_rect.has_point(p):
		var kids := _kids(open_child)
		var j := _row_at(_child_rect, kids, p, _scroll_child)
		if j >= 0 and not kids[j].get("disabled", false):
			_pick(kids[j])
		return
	var i := _row_at(_rect, rows, p, _scroll_main)
	if i < 0 or rows[i].get("disabled", false):
		return
	if rows[i].has("children"):
		if open_child != i:
			_scroll_child = 0.0
		open_child = i
		hover = i
		_child_rect = _child_frame(i)
		queue_redraw()
		return
	_pick(rows[i])


func _pick(row: Dictionary) -> void:
	var r := row.duplicate()
	close()
	picked.emit(r)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseMotion:
		# Hover is read here rather than through GUI dispatch so it also follows injected (automation) motion.
		_motion((event as InputEventMouseMotion).position - global_position)
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	var vp := get_viewport()  # the popup may remove itself below
	match k.keycode:
		KEY_ESCAPE:
			close()
		KEY_DOWN, KEY_UP:
			hover = BeMenuState.step(rows, hover if hover >= 0 else (rows.size() if k.keycode == KEY_DOWN else 0), 1 if k.keycode == KEY_DOWN else -1)
			if hover >= 0:
				var sc := _reveal(_rect, rows, hover, _scroll_main)
				if sc != _scroll_main:
					_scroll_by(0, sc - _scroll_main)
			queue_redraw()
		KEY_RIGHT:
			if hover >= 0 and rows[hover].has("children"):
				_press(_row_rect(_rect, rows, hover, _scroll_main).get_center())
			else:
				return
		KEY_ENTER, KEY_KP_ENTER:
			if hover >= 0:
				_press(_row_rect(_rect, rows, hover, _scroll_main).get_center())
		_:
			return
	vp.set_input_as_handled()
