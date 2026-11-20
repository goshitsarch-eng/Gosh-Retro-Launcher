class_name MacDialog
extends Control
## Modal dialog frame of the Mac shell. Two styles from the design:
##  * alert  - untitled: 3px frame with a 2px #888 inner border (messages, confirmations, About)
##  * titled - striped title bar with a close box (Get Info, Run, forms, lists), body padding 14/14/12
## A full-rect overlay swallows pointer input underneath. Enter presses the default button, Esc or Cmd-. cancels.
## `body` is positioned at the content origin; add widgets with add(widget, body-local position).

signal closed

var shell: Control
var title := ""
var titled := true
var frame_size := Vector2(360, 120)
var body: Control
var _scroll: ScrollContainer
var _visible_frame := Vector2.ZERO
var default_button: MacButton
var on_cancel: Callable = Callable()
## Optional key hook for the topmost dialog: (InputEventKey) -> bool handled. Runs before Return / Esc / Cmd-.
var on_key: Callable = Callable()
var auto_name := ""

var _frame_pos := Vector2.ZERO
var _closed := false
var _drag_from := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _dragging := false

const ALERT_PAD := 3
const ALERT_BORDER := 2


static func open(p_shell: Control, p_title: String, p_size: Vector2, p_titled: bool = true) -> MacDialog:
	var d := MacDialog.new()
	d.shell = p_shell
	d.title = p_title
	d.titled = p_titled
	d.frame_size = p_size
	for sibling in p_shell.dialog_layer.get_children():
		if sibling is Control:
			sibling.visible = false   # only the topmost dialog shows (the design swaps forms in place)
	p_shell.dialog_layer.add_child(d)
	d._build()
	return d


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("pm_auto")


func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	add_child(_scroll)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(body)
	resized.connect(_fit_frame)
	_fit_frame()
	queue_redraw()


func _fit_frame() -> void:
	var top := float(MacGeometry.MENU_H)
	_visible_frame = frame_size.min(Vector2(size.x, maxf(1, size.y - top)))
	_frame_pos = ((size - _visible_frame) / 2.0).round()
	_place_body()
	queue_redraw()


func _place_body() -> void:
	var top := float(MacGeometry.MENU_H)
	_frame_pos = _frame_pos.clamp(Vector2(0, top), (size - _visible_frame).max(Vector2(0, top)))
	var inset := Vector2(5, 1 + MacGeometry.TITLE_H) if titled else Vector2.ONE * (ALERT_PAD + ALERT_BORDER + 1)
	var chrome := Vector2(10, 6 + MacGeometry.TITLE_H) if titled else inset * 2
	_scroll.position = _frame_pos + inset
	_scroll.size = (_visible_frame - chrome).max(Vector2.ONE)
	body.custom_minimum_size = frame_size - chrome
	body.size = body.custom_minimum_size


func add(widget: Control, at: Vector2) -> Control:
	body.add_child(widget)
	widget.position = at
	return widget


func set_default(btn: MacButton) -> void:
	if default_button != null and is_instance_valid(default_button):
		default_button.is_default = false
	default_button = btn
	btn.is_default = true


func frame_rect() -> Rect2:
	return Rect2(_frame_pos, _visible_frame)


## Places buttons right-aligned in a row whose top is `y` (body coords); returns nothing.
func button_row(buttons: Array, y: float, right_pad: float = 14.0) -> void:
	var x := body.size.x - right_pad
	for i in range(buttons.size() - 1, -1, -1):
		var b: MacButton = buttons[i]
		x -= b.size.x
		add(b, Vector2(x, y))
		x -= 14.0


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()
	var layer := get_parent()
	if layer != null:
		var below: Node = null
		for c in layer.get_children():
			if c == self:
				break
			if not c.is_queued_for_deletion():
				below = c
		if below is Control:
			(below as Control).visible = true
	queue_free()


func cancel() -> void:
	if on_cancel.is_valid():
		on_cancel.call()
	else:
		close()


func _draw() -> void:
	var r := frame_rect()
	MacDraw.panel(self, r, 0.3, true)
	if titled:
		var close_box := Rect2(r.position.x + 1 + 2, r.position.y + 1 + 4, MacGeometry.BOX, MacGeometry.BOX)
		MacDraw.gradient_box(self, close_box)
		var cap_w := MacDraw.measure(title, true) + 12
		var sx0 := close_box.end.x + 5
		var sx1 := r.end.x - 1 - 2
		var avail := sx1 - sx0
		var each := maxf(0.0, floorf((avail - cap_w - 10) / 2.0))
		var sy := r.position.y + 1 + 5
		MacDraw.stripes(self, Rect2(sx0, sy, each, 11))
		MacDraw.text_centered_y(self, sx0 + each + 5 + 6, r.position.y + 1, MacGeometry.TITLE_H, title, MacTheme.t("000000"), true)
		MacDraw.stripes(self, Rect2(sx0 + each + 5 + cap_w + 5, sy, maxf(0.0, sx1 - (sx0 + each + 5 + cap_w + 5)), 11))
	else:
		var inner := r.grow(-ALERT_PAD)
		Px.outline(self, inner, MacTheme.b("888888"))
		Px.outline(self, inner.grow(-1), MacTheme.b("888888"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var r := frame_rect()
		if mb.pressed and titled:
			var close_box := Rect2(r.position.x + 3, r.position.y + 5, MacGeometry.BOX, MacGeometry.BOX)
			if close_box.has_point(mb.position):
				cancel()
			elif Rect2(r.position, Vector2(r.size.x, MacGeometry.TITLE_H + 1)).has_point(mb.position):
				_dragging = true
				_drag_from = mb.global_position
				_drag_origin = _frame_pos
		elif not mb.pressed:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			var d := (event as InputEventMouseMotion).global_position - _drag_from
			_frame_pos = (_drag_origin + d).floor()
			_place_body()
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()


func _input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if shell.dialog_layer.get_child(shell.dialog_layer.get_child_count() - 1) != self:
		return  # only the topmost dialog reacts
	var k := event as InputEventKey
	if shell.select_layer.get_child_count() > 0:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if k.keycode == KEY_TAB:
		var stops := body.find_children("*", "Control", true, false).filter(func(c: Control):
			return c.is_visible_in_tree() and c.focus_mode == Control.FOCUS_ALL and not c is ScrollBar)
		if not stops.is_empty():
			var i := stops.find(owner)
			var next := posmod(i - 1, stops.size()) if k.shift_pressed else (i + 1) % stops.size()
			if i < 0 and k.shift_pressed:
				next = stops.size() - 1
			stops[next].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if on_key.is_valid() and on_key.call(k):
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE or (k.keycode == KEY_PERIOD and (k.meta_pressed or k.ctrl_pressed)):
		cancel()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		if owner is MacButton or owner is MacSelect or owner is TextEdit:
			return
		if default_button != null and is_instance_valid(default_button) and not default_button.disabled:
			default_button.pressed.emit()
			get_viewport().set_input_as_handled()


func auto_lookup(id: String) -> Variant:
	if id == "mac.dialog" and is_visible_in_tree() and shell.dialog_layer.get_child(shell.dialog_layer.get_child_count() - 1) == self:
		return Rect2(global_position + _frame_pos, _visible_frame)
	return null
