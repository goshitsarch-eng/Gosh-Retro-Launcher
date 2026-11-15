class_name BePopup
extends Control
## A popup menu: context menus, folder menu-bar dropdowns, select lists and the Deskbar menu with its group
## submenus. It covers the whole shell (so it can see motion and outside presses); a press outside closes it and is
## replayed to whatever lies below (the design closes menus on pointerdown and lets the click through).
## Rows: {label, bold?, disabled?, dot?, icon?: Texture2D, children?: Array, sep?}. Row picks emit `picked(row)`.

signal picked(row: Dictionary)
signal closed
signal sibling_hover(index: int)  ## pointer moved over one of `siblings` (menu-bar titles)

const PAD_Y := 3

var rows: Array = []
var at := Vector2.ZERO
var item_h := BeGeometry.MENU_ITEM_H
var min_w := 200.0
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


func auto_lookup(id: String) -> Variant:
	if id == "be.popup":
		return Rect2(_rect.position, _rect.size)
	if id.begins_with("be.popup-item:"):
		var label := id.substr("be.popup-item:".length())
		for i in rows.size():
			if String(rows[i].get("label", "")) == label and not rows[i].get("sep", false):
				return _row_rect(_rect, rows, i)
		if open_child >= 0:
			var kids: Array = rows[open_child].get("children", [])
			for i in kids.size():
				if String(kids[i].get("label", "")) == label:
					return _row_rect(_child_rect, kids, i)
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
		if r.has("children"):
			arrow = 18.0
	return BeGeometry.menu_size(list, widest, item_h, p_min_w, pad_left, 16.0 + arrow)


func _layout() -> void:
	var s := _measure(rows, min_w)
	var view := size if size.x > 0 else get_viewport_rect().size
	var origin := Vector2(at.x - s.x, at.y) if align_right else at
	_rect = Rect2(BeGeometry.fit_popup(origin, s, view), s)
	queue_redraw()


func _row_rect(frame: Rect2, list: Array, index: int) -> Rect2:
	var y := frame.position.y + 1 + PAD_Y
	for i in index:
		y += BeGeometry.MENU_SEP_H if list[i].get("sep", false) else item_h
	return Rect2(frame.position.x + 1, y, frame.size.x - 2, item_h)


func _row_at(frame: Rect2, list: Array, p: Vector2) -> int:
	if not frame.has_point(p):
		return -1
	for i in list.size():
		if list[i].get("sep", false):
			continue
		if _row_rect(frame, list, i).has_point(p):
			return i
	return -1


func _child_frame(index: int) -> Rect2:
	var kids: Array = rows[index].get("children", [])
	var list := kids if not kids.is_empty() else [{"label": "(empty)", "disabled": true}]
	var s := _measure(list, 220.0)
	var rr := _row_rect(_rect, rows, index)
	var x := rr.position.x - s.x - 2 + 1 if submenu_left else _rect.end.x + 2
	var view := size if size.x > 0 else get_viewport_rect().size
	var y := minf(rr.position.y - 4, view.y - s.y - 4.0)
	return Rect2(Vector2(maxf(0.0, x), maxf(0.0, y)), s)


func _kids(index: int) -> Array:
	var kids: Array = rows[index].get("children", [])
	return kids if not kids.is_empty() else [{"label": "(empty)", "disabled": true}]


func _draw_list(frame: Rect2, list: Array, hover_i: int) -> void:
	BeDraw.popup_frame(self, frame)
	var y := frame.position.y + 1 + PAD_Y
	for i in list.size():
		var r: Dictionary = list[i]
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
		y += item_h


func _draw() -> void:
	_draw_list(_rect, rows, hover if open_child < 0 else open_child)
	if open_child >= 0:
		var kids := _kids(open_child)
		_draw_list(_child_rect, kids, hover_child)


func _is_in_menus(p: Vector2) -> bool:
	return _rect.has_point(p) or (open_child >= 0 and _child_rect.has_point(p))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
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
	if open_child >= 0 and _child_rect.has_point(p):
		hover_child = _row_at(_child_rect, _kids(open_child), p)
		queue_redraw()
		return
	var i := _row_at(_rect, rows, p)
	if i >= 0:
		hover = i
		hover_child = -1
		if rows[i].has("children") and not rows[i].get("disabled", false):
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
		var j := _row_at(_child_rect, kids, p)
		if j >= 0 and not kids[j].get("disabled", false):
			_pick(kids[j])
		return
	var i := _row_at(_rect, rows, p)
	if i < 0 or rows[i].get("disabled", false):
		return
	if rows[i].has("children"):
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
			queue_redraw()
		KEY_RIGHT:
			if hover >= 0 and rows[hover].has("children"):
				_press(_row_rect(_rect, rows, hover).get_center())
			else:
				return
		KEY_ENTER, KEY_KP_ENTER:
			if hover >= 0:
				_press(_row_rect(_rect, rows, hover).get_center())
		_:
			return
	vp.set_input_as_handled()
