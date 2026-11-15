class_name MacWindow
extends Control
## Base of the Mac shell's windows: striped title bar with close / zoom / collapse boxes, drag by the title,
## grow box, shadow. Geometry lives in MacWindowStore (this control mirrors it); subclasses fill the body
## (`_draw_body`, child controls) and reply to `body_visible_changed`.
##
## Press on the close/zoom/collapse box acts on release inside the box. Double-clicking the title bar collapses
## (window-shade) the window like the design's `onDoubleClick={shade}`.

var desk: Control          ## MacDesktop (owner; has .store, .shell)
var key := ""
var has_zoom := true

enum Part { NONE, CLOSE, ZOOM, SHADE, TITLE, GRIP, BODY }

var _press_part := Part.NONE
var _drag_from := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_mode := ""        ## "" | "move" | "size"
var _hot := Part.NONE       ## box currently held down (pressed look)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("pm_auto")


func state() -> Dictionary:
	return desk.store.find(key)


func is_active() -> bool:
	return desk.store.is_active(key)


func title_text() -> String:
	return MacDialogLogic.window_title(key, ProgramStore.groups)


## Synchronise geometry from the store. Called by the desktop.
func sync_from_store() -> void:
	var st := state()
	if st.is_empty():
		return
	var r: Rect2 = st.rect
	position = r.position
	size = Vector2(r.size.x, MacGeometry.SHADED_H if st.shaded else r.size.y)
	_on_state_synced(st)
	queue_redraw()


func _on_state_synced(_st: Dictionary) -> void:
	pass


func chrome() -> Dictionary:
	var st := state()
	var frame := Rect2(Vector2.ZERO, size)
	return MacGeometry.chrome(frame, bool(st.get("shaded", false)), has_zoom, MacDraw.measure(title_text(), true))


func _draw() -> void:
	var st := state()
	if st.is_empty():
		return
	var c := chrome()
	var frame: Rect2 = c.frame
	MacDraw.panel(self, frame, 0.3, true)
	var active := is_active()
	var tcol := MacTheme.t("000000") if active else MacTheme.t("888888")
	if active:
		MacDraw.stripes(self, c.stripe_l)
		MacDraw.stripes(self, c.stripe_r)
	MacDraw.gradient_box(self, c.close, _hot == Part.CLOSE)
	if has_zoom:
		MacDraw.gradient_box(self, c.zoom, _hot == Part.ZOOM)
		var z: Rect2 = c.zoom
		Px.outline(self, Rect2(z.position.x + 2, z.position.y + 2, 7, 7), MacTheme.b("444444"))
	MacDraw.gradient_box(self, c.shade, _hot == Part.SHADE)
	var s: Rect2 = c.shade
	var line := MacTheme.b("444444")
	Px.hline(self, s.position.x + 2, s.position.y + 4, s.size.x - 4, line)
	Px.hline(self, s.position.x + 2, s.position.y + 6, s.size.x - 4, line)
	var tr: Rect2 = c.title_text
	var cap := title_text()
	var cw := MacDraw.measure(cap, true)
	var avail := int(tr.size.x) - 12
	MacDraw.text_centered_y(self, tr.position.x + 6 + maxf(0.0, floorf((avail - cw) / 2.0)), tr.position.y, TITLE_H(), cap, tcol, true, maxi(avail, 0))
	if not st.shaded:
		_draw_body(c, st)


func TITLE_H() -> int:
	return MacGeometry.TITLE_H


func _draw_body(_c: Dictionary, _st: Dictionary) -> void:
	pass


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func part_at(p: Vector2) -> int:
	var c := chrome()
	if c.close.has_point(p):
		return Part.CLOSE
	if has_zoom and c.zoom.has_point(p):
		return Part.ZOOM
	if c.shade.has_point(p):
		return Part.SHADE
	if not state().get("shaded", false) and not state().get("zoomed", false) and c.grip.has_point(p):
		return Part.GRIP
	if (c.title as Rect2).has_point(p):
		return Part.TITLE
	return Part.BODY


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				desk.activate_window(key)
				_press_part = part_at(mb.position) as Part
				match _press_part:
					Part.CLOSE, Part.ZOOM, Part.SHADE:
						_hot = _press_part
						queue_redraw()
					Part.TITLE:
						if mb.double_click:
							desk.store.toggle_shade(key)
							_press_part = Part.NONE
						else:
							_begin_drag("move", mb)
					Part.GRIP:
						_begin_drag("size", mb)
			else:
				var released_on := part_at(mb.position)
				if _drag_mode != "":
					_drag_mode = ""
				elif _press_part != Part.NONE and released_on == _press_part:
					match _press_part:
						Part.CLOSE:
							desk.close_window(key)
						Part.ZOOM:
							desk.store.toggle_zoom(key, desk.desk_size())
						Part.SHADE:
							desk.store.toggle_shade(key)
				_press_part = Part.NONE
				_hot = Part.NONE
				queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			desk.activate_window(key)
			_body_context(mb)
			accept_event()
	elif event is InputEventMouseMotion and _drag_mode != "":
		var mm := event as InputEventMouseMotion
		var delta := mm.global_position - _drag_from
		if _drag_mode == "move":
			desk.store.move_to(key, MacGeometry.clamp_position(_drag_origin + delta, size, desk.desk_size()))
		else:
			desk.store.resize_to(key, _drag_origin + delta, desk.desk_size() * 2.0)
		accept_event()
	elif event is InputEventMouseMotion and _hot != Part.NONE:
		# boxes stay visually pressed only while the pointer is inside
		var inside := part_at((event as InputEventMouseMotion).position) == _press_part
		if (_hot != Part.NONE) != inside:
			_hot = _press_part if inside else Part.NONE
			queue_redraw()


func _begin_drag(mode: String, mb: InputEventMouseButton) -> void:
	_drag_mode = mode
	_drag_from = mb.global_position
	_drag_origin = state().rect.position if mode == "move" else state().rect.size


func _body_context(_mb: InputEventMouseButton) -> void:
	pass


## Automation: "mac.window:<key>:<part>" parts: close zoom shade title grip body.
func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return null
	var prefix := "mac.window:" + key + ":"
	if not id.begins_with(prefix):
		var active_prefix := "mac.window.active:"
		if is_active() and id.begins_with(active_prefix):
			return _part_rect(id.substr(active_prefix.length()))
		return null
	return _part_rect(id.substr(prefix.length()))


func _part_rect(part: String) -> Variant:
	var c := chrome()
	var r := Rect2()
	match part:
		"close": r = c.close
		"zoom": r = c.zoom
		"shade": r = c.shade
		"title": r = c.title_text
		"grip": r = c.grip
		"frame": r = c.frame
		_: return null
	if r.size == Vector2.ZERO:
		return null
	return Rect2(r.position + global_position, r.size)
