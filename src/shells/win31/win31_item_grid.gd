class_name Win31ItemGrid
extends Control
## Program item area of a group window (Win31ItemGrid.tsx + .wfw-item-area/.wfw-program-item CSS):
## fixed 75x72 cells, 32px icons, wrapped labels, selection/focus, manual placement, arrow keys,
## double-click/Enter launch, cross-group drag, period scrollbars.

signal launch_requested(item: Dictionary)

const ICON_X := 22           ## (73px content - 32px icon) / 2 + 1px cell padding, snapped
const LABEL_Y := 35          ## icon 32 + 3px margin
const DRAG_THRESHOLD := 4

var group_id := ""
var scroll := Vector2i.ZERO
## The MDI client that resolves cross-group drops (Win31MdiClient); optional for tests.
var client: Control

var _drag := {}              ## {index, start: Vector2, origin: Vector2i, offset: Vector2i, moved: bool}
var _bar_drag := {}          ## {vertical: bool, grab: float, start_scroll: int}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	add_to_group("pm_auto")


func _group() -> Dictionary:
	return ProgramStore.find_group(group_id)


func _items() -> Array:
	return _group().get("items", [])


func _positions() -> Array:
	return Win31GridLogic.positions(_items(), bool(ProgramStore.settings.get("autoArrange", true)), size.x)


func _selected_index() -> int:
	var sel: Dictionary = UIState.win31_selection
	if sel.get("kind", "") == "item" and sel.get("groupId", "") == group_id:
		var items := _items()
		for i in items.size():
			if items[i].id == sel.get("itemId", ""):
				return i
	return -1


# --------------------------------------------------------------- geometry

func _bars() -> Dictionary:
	return Win31GridLogic.scrollbars(Win31GridLogic.content_size(_positions()), size.x, size.y)


func _viewport_size() -> Vector2:
	var b := _bars()
	return Vector2(size.x - (Win31GridLogic.SCROLLBAR if b.v else 0), size.y - (Win31GridLogic.SCROLLBAR if b.h else 0))


func _clamp_scroll() -> void:
	var content := Win31GridLogic.content_size(_positions())
	var vp := _viewport_size()
	scroll.x = clampi(scroll.x, 0, maxi(0, content.x - int(vp.x)))
	scroll.y = clampi(scroll.y, 0, maxi(0, content.y - int(vp.y)))


## Cell rectangle of item `i` in this control's local coordinates (scroll applied).
func cell_rect(i: int, positions: Array = []) -> Rect2:
	var pos: Array = positions if not positions.is_empty() else _positions()
	var p: Vector2i = pos[i]
	return Rect2(p.x - scroll.x, p.y - scroll.y, Win31GridLogic.CELL_W, Win31GridLogic.CELL_H)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clamp_scroll()
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	Px.fill(self, 0, 0, size.x, size.y, Pal.WHITE)
	var group := _group()
	if group.is_empty():
		return
	var items: Array = group.items
	var positions := _positions()
	var selected := _selected_index()
	var f := Win31Chrome.font()
	var mode := String(ProgramStore.settings.get("labelDisplay", "wrap"))
	for i in items.size():
		var item: Dictionary = items[i]
		var p := Vector2(positions[i]) - Vector2(scroll)
		if not _drag.is_empty() and _drag.index == i and _drag.moved and not bool(ProgramStore.settings.get("autoArrange", true)):
			p = Vector2(_drag.origin) + Vector2(_drag.offset) - Vector2(scroll)
		if p.x + Win31GridLogic.CELL_W < 0 or p.y + Win31GridLogic.CELL_H < 0 or p.x > size.x or p.y > size.y:
			continue
		draw_item(self, item, p, i == selected, i == selected and has_focus(), mode)
	_draw_scrollbars()


## Paints one program item cell with its top-left at `p` (shared with drag ghosts).
static func draw_item(ci: CanvasItem, item: Dictionary, p: Vector2, selected: bool, focused: bool, mode: String) -> void:
	var f := Win31Chrome.font()
	var tex := WfwIcons.item_texture(item)
	if tex != null:
		var s := tex.get_size()
		var k := minf(32.0 / s.x, 32.0 / s.y)
		var sz := (s * k).floor()
		Px.tex(ci, tex, Vector2(p.x + ICON_X + floorf((32.0 - sz.x) / 2.0), p.y + floorf((32.0 - sz.y) / 2.0)), sz)
	var layout := Win31GridLogic.label_layout(f, String(item.get("name", "")), mode)
	var lines: PackedStringArray = layout.lines
	var box_w: int = layout.box_w
	var box_x := p.x + 1 + floorf((73 - box_w + 1) / 2.0)
	var box := Rect2(box_x, p.y + LABEL_Y, box_w, maxi(1, lines.size()) * Win31GridLogic.LABEL_LINE)
	var color := Pal.WHITE if selected else Pal.BLACK
	if selected:
		Px.fill_rect(ci, box, Pal.NAVY)
	var content_w := box_w - Win31GridLogic.LABEL_PAD * 2
	for li in lines.size():
		var w := f.measure(Win31GridLogic.lit(lines[li]))
		var lx := box.position.x + Win31GridLogic.LABEL_PAD + floorf((content_w - w) / 2.0)
		f.draw(ci, Vector2(lx, box.position.y + li * Win31GridLogic.LABEL_LINE + Win31Chrome.LABEL_DY), Win31GridLogic.lit(lines[li]), color,
			{"line_height": Win31GridLogic.LABEL_LINE, "show_access": false})
	if focused:
		Px.focus_rect(ci, box, color)


func _draw_scrollbars() -> void:
	var b := _bars()
	var vp := _viewport_size()
	var content := Win31GridLogic.content_size(_positions())
	if b.v:
		var track := Rect2(size.x - 16, 0, 16, vp.y)
		_draw_bar(track, true, content.y, vp.y, scroll.y)
	if b.h:
		var track2 := Rect2(0, size.y - 16, vp.x, 16)
		_draw_bar(track2, false, content.x, vp.x, scroll.x)
	if b.v and b.h:
		Px.fill(self, size.x - 16, size.y - 16, 16, 16, Pal.WHITE)


func _bar_thumb(track: Rect2, vertical: bool, content: float, viewport: float, offset: float) -> Rect2:
	var inner := track.grow(-1)
	var length := inner.size.y if vertical else inner.size.x
	var thumb_len: float = clampf(round(length * viewport / content), 16.0, length) if content > 0 else length
	var max_off := maxf(1.0, content - viewport)
	var pos: float = round((length - thumb_len) * offset / max_off)
	if vertical:
		return Rect2(inner.position.x, inner.position.y + pos, inner.size.x, thumb_len)
	return Rect2(inner.position.x + pos, inner.position.y, thumb_len, inner.size.y)


func _draw_bar(track: Rect2, vertical: bool, content: float, viewport: float, offset: float) -> void:
	Px.fill_rect(self, track, Pal.WHITE)
	Px.checker(self, track.grow(-1), Pal.FACE, Pal.WHITE)
	Px.outline(self, track, Pal.BLACK)
	var t := _bar_thumb(track, vertical, content, viewport, offset)
	Px.fill_rect(self, t, Pal.FACE)
	Px.edge(self, t, Pal.WHITE, Pal.BLACK)
	Px.edge(self, t.grow(-1), Pal.FACE, Pal.SHADOW)


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		_mouse_motion(event)
	elif event is InputEventKey and event.pressed:
		_key(event)


func _mouse_button(ev: InputEventMouseButton) -> void:
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if ev.pressed:
			var dir := -1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			scroll.y += dir * 24
			_clamp_scroll()
			queue_redraw()
			accept_event()
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if ev.pressed:
		if _press_scrollbar(ev.position):
			accept_event()
			return
		var positions := _positions()
		var i := Win31GridLogic.item_at(positions, ev.position + Vector2(scroll))
		if i < 0:
			UIState.clear_selection()  # pointerdown on the item area itself; the window still activates
			grab_focus()
			queue_redraw()
			return
		var item: Dictionary = _items()[i]
		UIState.set_win31_selection({"kind": "item", "groupId": group_id, "itemId": item.id})
		UIState.set_selected_item(item.id, group_id)
		grab_focus()
		_drag = {"index": i, "start": ev.global_position, "origin": positions[i], "offset": Vector2i.ZERO, "moved": false}
		accept_event()
		queue_redraw()
		if ev.double_click:
			_drag = {}
			launch_requested.emit(item)
	else:
		_bar_drag = {}
		if not _drag.is_empty():
			_end_drag(ev)
			accept_event()


func _mouse_motion(ev: InputEventMouseMotion) -> void:
	if not _bar_drag.is_empty():
		_drag_bar(ev.position)
		accept_event()
		return
	if _drag.is_empty() or not (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	var delta: Vector2 = ev.global_position - _drag.start
	if not _drag.moved and delta.length() < 1.0:
		return
	var auto := bool(ProgramStore.settings.get("autoArrange", true))
	if auto and not _drag.moved and delta.length() < DRAG_THRESHOLD:
		return
	_drag.moved = true
	if not auto:
		_drag.offset = Win31GridLogic.drag_position(Vector2(_drag.origin), delta, size.x, size.y) - Vector2i(_drag.origin)
	if client != null and client.has_method("item_drag_update"):
		client.item_drag_update(group_id, _items()[_drag.index], ev.global_position)
	accept_event()
	queue_redraw()


func _end_drag(ev: InputEventMouseButton) -> void:
	var drag := _drag
	_drag = {}
	queue_redraw()
	if not drag.moved:
		return
	var item: Dictionary = _items()[drag.index] if drag.index < _items().size() else {}
	if item.is_empty():
		return
	if client != null and client.has_method("item_drag_end"):
		if client.item_drag_end(group_id, item, ev.global_position, ev.ctrl_pressed):
			return
	if not bool(ProgramStore.settings.get("autoArrange", true)):
		var delta: Vector2 = ev.global_position - drag.start
		var pos := Win31GridLogic.drag_position(Vector2(drag.origin), delta, size.x, size.y)
		ProgramStore.update_item_position(group_id, item.id, {"x": pos.x, "y": pos.y})


## True when the item is being dragged live inside this grid (manual arrangement).
func is_dragging() -> bool:
	return not _drag.is_empty() and _drag.moved


func _press_scrollbar(pos: Vector2) -> bool:
	var b := _bars()
	var vp := _viewport_size()
	var content := Win31GridLogic.content_size(_positions())
	if b.v and pos.x >= size.x - 16 and pos.y < vp.y:
		var track := Rect2(size.x - 16, 0, 16, vp.y)
		var t := _bar_thumb(track, true, content.y, vp.y, scroll.y)
		if t.has_point(pos):
			_bar_drag = {"vertical": true, "grab": pos.y - t.position.y, "start": scroll.y}
		else:
			scroll.y += int(vp.y) * (1 if pos.y > t.end.y else -1)
			_clamp_scroll()
		queue_redraw()
		return true
	if b.h and pos.y >= size.y - 16 and pos.x < vp.x:
		var track2 := Rect2(0, size.y - 16, vp.x, 16)
		var t2 := _bar_thumb(track2, false, content.x, vp.x, scroll.x)
		if t2.has_point(pos):
			_bar_drag = {"vertical": false, "grab": pos.x - t2.position.x, "start": scroll.x}
		else:
			scroll.x += int(vp.x) * (1 if pos.x > t2.end.x else -1)
			_clamp_scroll()
		queue_redraw()
		return true
	return false


func _drag_bar(pos: Vector2) -> void:
	var vp := _viewport_size()
	var content := Win31GridLogic.content_size(_positions())
	var vertical: bool = _bar_drag.vertical
	var track := Rect2(size.x - 16, 0, 16, vp.y) if vertical else Rect2(0, size.y - 16, vp.x, 16)
	var cont := float(content.y if vertical else content.x)
	var view := vp.y if vertical else vp.x
	var t := _bar_thumb(track, vertical, cont, view, 0)
	var length := (track.size.y if vertical else track.size.x) - 2.0
	var travel := maxf(1.0, length - (t.size.y if vertical else t.size.x))
	var p := (pos.y if vertical else pos.x) - float(_bar_drag.grab) - (track.position.y if vertical else track.position.x) - 1.0
	var off := int(round(clampf(p / travel, 0.0, 1.0) * maxf(0.0, cont - view)))
	if vertical:
		scroll.y = off
	else:
		scroll.x = off
	_clamp_scroll()
	queue_redraw()


func _key(ev: InputEventKey) -> void:
	if not has_focus():
		return
	var items := _items()
	if items.is_empty():
		return
	var key := Win31Commands.key_name(ev)
	var current := _selected_index()
	if key == "enter" and current >= 0:
		accept_event()
		launch_requested.emit(items[current])
		return
	var next := Win31GridLogic.navigate(key, current, items.size(), Win31GridLogic.columns(size.x))
	if next < 0:
		return
	accept_event()
	var item: Dictionary = items[next]
	UIState.set_win31_selection({"kind": "item", "groupId": group_id, "itemId": item.id})
	UIState.set_selected_item(item.id, group_id)
	_scroll_into_view(next)
	queue_redraw()


func _scroll_into_view(index: int) -> void:
	var positions := _positions()
	var r := cell_rect(index, positions)
	var vp := _viewport_size()
	if r.position.y < 0:
		scroll.y += int(r.position.y)
	elif r.end.y > vp.y:
		scroll.y += int(r.end.y - vp.y)
	if r.position.x < 0:
		scroll.x += int(r.position.x)
	elif r.end.x > vp.x:
		scroll.x += int(r.end.x - vp.x)
	_clamp_scroll()


func _focus_changed() -> void:
	queue_redraw()


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Global-coordinate rect of an item cell (automation).
func item_global_rect(index: int) -> Rect2:
	var items := _items()
	if index < 0 or index >= items.size():
		return Rect2()
	var r := cell_rect(index)
	return Rect2(get_global_rect().position + r.position, r.size)
