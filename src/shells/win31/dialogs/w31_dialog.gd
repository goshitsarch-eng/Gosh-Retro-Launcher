class_name W31Dialog
extends Control
## Modal Win31 dialog frame (port of Dialogs/Dialog.tsx + the .shell-win31 dialog rules):
## 1px black frame with white/grey inset, 18px navy title bar with system button/menu
## (Move/Close), draggable title, scrollable 8px-padded content, keyboard model
## (Enter = default button, Esc = cancel, Tab/Shift+Tab trap, Alt+access keys, keyboard Move).
##
## Subclasses override `_build(cw)` and describe their content with the add_* helpers in
## *body* coordinates (origin = content box inside the 8px padding), then call `_finish(inner_h)`.

signal closed

const BORDER := 1
const FRAME := 3  ## border + 2px padding
const TITLE_H := 18
const PAD := 8
const MENU_W := 110

var title := ""
var dialog_width := 400
var default_button: W31Button
var initial_focus: Control
var draggable := true
var system_menu := true  ## false: the system button only reacts to a double click (Quick Search)
var drag_offset := Vector2.ZERO
var cancel_callable: Callable = Callable()

var body: W31Body
var viewport: Control
var scroll: W31ScrollBar
var max_height := 432  ## 90% of the shell height

var half_pixel := false  ## centred on a .5 position (see W31Button._text_dy)
var _inner_h := 0
var _content_w := 0
var _built := false
var _drag := false
var _drag_start := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _kb_move := false
var _kb_orig := Vector2.ZERO
var _menu: Control
var _closing := false


func _init(p_title: String = "", p_width: int = 400) -> void:
	title = p_title
	dialog_width = p_width
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_auto_id("wfw.dialog")


func set_auto_id(id: String) -> void:
	set_meta("auto_id", id)
	if not is_in_group("pm_auto"):
		add_to_group("pm_auto")


## Height available to the whole dialog (set by the layer before building).
func build(shell_height: int) -> void:
	max_height = int(shell_height * 0.9)
	_rebuild(false)


func _rebuild(with_scroll: bool) -> void:
	if viewport:
		viewport.queue_free()
		remove_child(viewport)
	default_button = null
	initial_focus = null
	viewport = Control.new()
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(viewport)
	body = W31Body.new()
	viewport.add_child(body)
	scroll = null
	_content_w = dialog_width - 2 * FRAME - 2 * PAD - (W31ScrollBar.WIDTH if with_scroll else 0)
	body.size.x = _content_w
	_inner_h = 0
	_build(_content_w)
	_finish_layout(with_scroll)
	_built = true


## Subclass hook: add widgets/text to `body`, set `default_button`, `initial_focus`, and call `_finish(inner_h)`.
func _build(_cw: int) -> void:
	pass


func _finish(inner_h: int) -> void:
	_inner_h = inner_h


func _finish_layout(with_scroll: bool) -> void:
	var content_h := _inner_h + 2 * PAD
	var chrome := 2 * FRAME + TITLE_H
	var overflow := chrome + content_h > max_height
	if overflow and not with_scroll:
		_rebuild(true)
		return
	var vh := mini(content_h, max_height - chrome)
	viewport.position = Vector2(FRAME, FRAME + TITLE_H)
	viewport.size = Vector2(dialog_width - 2 * FRAME, vh)
	body.position = Vector2(PAD, PAD)
	body.size = Vector2(_content_w, _inner_h)
	size = Vector2(dialog_width, chrome + vh)
	custom_minimum_size = size
	if with_scroll:
		scroll = W31ScrollBar.new()
		scroll.position = Vector2(viewport.size.x - W31ScrollBar.WIDTH, 0)
		scroll.size = Vector2(W31ScrollBar.WIDTH, vh)
		scroll.total = content_h
		scroll.page = vh
		scroll.step = 13
		scroll.scrolled.connect(func(v: float):
			body.position.y = PAD - v)
		viewport.add_child(scroll)
		viewport.gui_input.connect(_viewport_wheel)
	queue_redraw()


func _viewport_wheel(event: InputEvent) -> void:
	if scroll and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.value -= 39
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll.value += 39
		else:
			return
		body.position.y = PAD - scroll.value


# ---------------------------------------------------------------- content helpers

func add_widget(w: Control, x: int, y: int, sz: Vector2 = Vector2.ZERO) -> Control:
	w.position = Vector2(x, y)
	if sz != Vector2.ZERO:
		w.size = sz
	body.add_child(w)
	return w


func add_text(x: int, y: int, s: String, px: int = 11, opts: Dictionary = {}) -> void:
	body.ops.append(func(ci: CanvasItem): W31.text(ci, x, y, s, opts.get("color", W31.BLACK), px, opts))


## Wrapped paragraph; returns its height.
func add_paragraph(x: int, y: int, s: String, width: int, line_h: int, px: int = 11, opts: Dictionary = {}) -> int:
	var lines := W31.font(px).wrap(s, width)
	var o := opts.duplicate()
	o["line_height"] = line_h
	for i in lines.size():
		var line := lines[i]
		var yy := y + i * line_h
		body.ops.append(func(ci: CanvasItem): W31.text(ci, x, yy, line, o.get("color", W31.BLACK), px, o))
	return lines.size() * line_h


func add_image(tex: Texture2D, x: int, y: int, sz: Vector2 = Vector2.ZERO) -> void:
	body.ops.append(func(ci: CanvasItem): Px.tex(ci, tex, Vector2(x, y), sz))


func add_op(op: Callable, first: bool = false) -> void:
	if first:
		body.ops.insert(0, op)
	else:
		body.ops.append(op)


## Right-aligned 12px field label: `.win31-form-row label` (106px wide column, text right aligned).
func add_label(x: int, y: int, s: String, width: int = 106) -> void:
	var w := W31.text_w(s, 11)
	add_text(x + width - w, y, s, 11)


## One `.win31-form-row`: label + control, returns the row height (19 + 5 margin = 24 flow).
func add_form_row(y: int, label: String, ctl: Control, ctl_w: int, ctl_h: int = 19, label_x: int = 0) -> void:
	add_label(label_x, y + (ctl_h - 13) / 2 if ctl_h <= 19 else y, label)
	add_widget(ctl, label_x + 106 + 5, y, Vector2(ctl_w, ctl_h))


func add_text_field(x: int, y: int, w: int, value: String = "", h: int = 19, multiline: bool = false) -> W31TextField:
	var tf := W31TextField.new(multiline)
	tf.set_field_size(w, h)
	tf.text = value
	add_widget(tf, x, y)
	return tf


func add_combo(x: int, y: int, w: int, items: Array, selected: int = 0, values: Array = []) -> W31Combo:
	var c := W31Combo.new()
	c.set_items(items, values)
	c.selected = selected
	add_widget(c, x, y, Vector2(w, W31Combo.HEIGHT))
	return c


## `.win31-dialog-buttons`: centred row (7px gap) inside [x0, x0+width]; first button is the
## default. Returns the buttons; sets `default_button`. `top` = y of the row's padding box.
func add_button_row(top: int, buttons: Array, x0: int = 8, width: int = -1) -> void:
	if width < 0:
		width = _content_w - 16
	var total := 0
	var sizes := []
	for b in buttons:
		var s: Vector2 = b.fit()
		sizes.append(s)
		total += int(s.x)
	total += 7 * (buttons.size() - 1)
	var x := float(x0) + (width - total) / 2.0
	for i in buttons.size():
		var b: W31Button = buttons[i]
		add_widget(b, int(floorf(x + 0.5)), top + 4, sizes[i])
		x += sizes[i].x + 7
	if buttons.size() > 0 and default_button == null and (buttons[0] as W31Button).is_default:
		default_button = buttons[0]


func make_button(text: String, is_default: bool = false, on_press: Callable = Callable()) -> W31Button:
	var b := W31Button.new(text, is_default)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	if is_default:
		default_button = b
	return b


# ---------------------------------------------------------------- placement / drawing

## Centres the dialog (Chromium rounds .5 up) plus the drag offset inside a shell of `shell_size`.
func place(shell_size: Vector2) -> void:
	var cx := floorf((shell_size.x - size.x) / 2.0 + 0.5)
	var cy := floorf((shell_size.y - size.y) / 2.0 + 0.5)
	half_pixel = int(shell_size.y - size.y) % 2 != 0
	position = Vector2(cx, cy) + drag_offset
	queue_redraw()


func _title_rect() -> Rect2:
	return Rect2(FRAME, FRAME, dialog_width - 2 * FRAME, TITLE_H)


func _sysbtn_rect() -> Rect2:
	return Rect2(FRAME + 2, FRAME + 2, 13, 13)


func _draw() -> void:
	W31.dialog_frame(self, Rect2(Vector2.ZERO, size))
	var tr := _title_rect()
	Px.fill_rect(self, tr, W31.NAVY)
	# system button: face, white top/left, black bottom/right, double bar glyph
	var sb := _sysbtn_rect()
	Px.fill_rect(self, sb, W31.FACE)
	Px.edge(self, sb, W31.WHITE, W31.BLACK)
	Px.fill(self, sb.end.x - 1, sb.position.y, 1, 1, W31.SHADOW)
	Px.fill(self, sb.position.x, sb.end.y - 1, 1, 1, W31.SHADOW)
	Px.fill(self, sb.position.x + 4, sb.position.y + 7, 5, 2, W31.BLACK)
	var avail := int(tr.size.x) - 44
	var f := W31.font()
	var clipped := f.clip(title, avail, true)
	var tw := f.measure(clipped, true)
	f.draw(self, Vector2(tr.position.x + 22 + floorf((avail - tw) / 2.0), tr.position.y + (0 if half_pixel else 1)), clipped, W31.WHITE, {"bold": true, "line_height": TITLE_H, "show_access": false})


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _sysbtn_rect().has_point(event.position):
				if event.double_click:
					_close_menu()
					cancel()
				elif _menu:
					_close_menu()
				elif system_menu:
					_open_menu()
				accept_event()
			elif _title_rect().has_point(event.position) and draggable:
				_close_menu()
				_drag = true
				_drag_start = event.global_position
				_drag_origin = drag_offset
				accept_event()
			else:
				_close_menu()
		else:
			_drag = false
	elif event is InputEventMouseMotion and _drag:
		drag_offset = (_drag_origin + (event.global_position - _drag_start)).round()
		var parent_size := (get_parent() as Control).size if get_parent() is Control else Vector2(640, 480)
		place(parent_size)
		accept_event()


func _open_menu() -> void:
	_menu = _SysMenu.new(self)
	_menu.position = Vector2(FRAME, FRAME + 17)
	_menu.z_index = 50
	add_child(_menu)


func _close_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null


func begin_keyboard_move() -> void:
	_close_menu()
	_kb_move = true
	_kb_orig = drag_offset


func tab_stops() -> Array:
	var out := []
	_collect_stops(self, out)
	return out


func _collect_stops(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is W31Widget and c.is_tab_stop():
			out.append(c)
		_collect_stops(c, out)


func _widget_for_focus(owner: Control) -> W31Widget:
	var n: Node = owner
	while n and n != self:
		if n is W31Widget:
			return n
		n = n.get_parent()
	return null


func _all_widgets(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is W31Widget:
			out.append(c)
		out.append_array(_all_widgets(c))
	return out


func focus_next(reverse: bool = false) -> void:
	var stops := tab_stops()
	if stops.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var idx := -1
	for i in stops.size():
		if stops[i].focus_target() == owner:
			idx = i
	var next := 0 if idx < 0 and not reverse else (stops.size() - 1 if idx < 0 else posmod(idx + (-1 if reverse else 1), stops.size()))
	var w: W31Widget = stops[next]
	if w is W31TextField:
		w.focus_select_all()
	else:
		w.focus_target().grab_focus()


func grab_initial_focus() -> void:
	if initial_focus and is_instance_valid(initial_focus):
		if initial_focus is W31TextField:
			initial_focus.focus_at_end()
		elif initial_focus is W31Widget:
			initial_focus.focus_target().grab_focus()
		else:
			initial_focus.grab_focus()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or _closing:
		return
	if _kb_move:
		var step := 8 if event.shift_pressed else 1
		match event.keycode:
			KEY_ESCAPE:
				drag_offset = _kb_orig
				_kb_move = false
			KEY_ENTER, KEY_KP_ENTER:
				_kb_move = false
			KEY_LEFT:
				drag_offset.x -= step
			KEY_RIGHT:
				drag_offset.x += step
			KEY_UP:
				drag_offset.y -= step
			KEY_DOWN:
				drag_offset.y += step
			_:
				return
		place((get_parent() as Control).size)
		get_viewport().set_input_as_handled()
		return
	var owner := get_viewport().gui_get_focus_owner()
	var fw := _widget_for_focus(owner) if owner else null
	if event.keycode == KEY_ESCAPE:
		if fw and fw.consume_escape():
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		cancel()
	elif event.keycode == KEY_TAB:
		focus_next(event.shift_pressed)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if fw is W31Button:
			return  # the focused button handles Enter itself
		if owner is TextEdit:
			return
		if default_button and not default_button.disabled:
			get_viewport().set_input_as_handled()
			default_button.click()
	elif event.alt_pressed and not event.ctrl_pressed and event.keycode != KEY_ALT:
		var key := OS.get_keycode_string(event.keycode).to_lower()
		for w in _all_widgets(self):
			if (w as W31Widget).access_key != "" and (w as W31Widget).access_key == key:
				(w as W31Widget).activate_access_key()
				get_viewport().set_input_as_handled()
				return


## Esc / system-menu Close / Cancel buttons.
func cancel() -> void:
	if _closing:
		return
	_closing = true
	if cancel_callable.is_valid():
		cancel_callable.call()
	else:
		UIState.close_dialog()


# ---------------------------------------------------------------- content surface

class W31Body extends Control:
	var ops: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		for op in ops:
			op.call(self)


class _SysMenu extends Control:
	var dialog: W31Dialog
	var hover := -1
	const ITEMS := ["Move", "-", "Close"]

	func _init(p_dialog: W31Dialog) -> void:
		dialog = p_dialog
		size = Vector2(MENU_W, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _item_rect(i: int) -> Rect2:
		return Rect2(3, 3, MENU_W - 6, 17) if i == 0 else Rect2(3, 3 + 17 + 6, MENU_W - 6, 17)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Px.fill_rect(self, r, W31.FACE)
		Px.outline(self, r, W31.BLACK)
		Px.hline(self, 1, 1, size.x - 2, W31.WHITE)
		Px.vline(self, 1, 1, size.y - 2, W31.WHITE)
		Px.hline(self, 1, size.y - 2, size.x - 2, W31.SHADOW)
		Px.vline(self, size.x - 2, 1, size.y - 2, W31.SHADOW)
		for i in [0, 2]:
			var ir := _item_rect(0 if i == 0 else 1)
			var sel: bool = hover == i
			if sel:
				Px.fill_rect(self, ir, W31.NAVY)
			W31.font().draw(self, Vector2(ir.position.x + 16, ir.position.y + 2), "Move" if i == 0 else "Close", W31.WHITE if sel else W31.BLACK)
		# separator: 2px high, grey over white, 1px inset margins
		Px.hline(self, 4, 3 + 17 + 2, size.x - 8, W31.SHADOW)
		Px.hline(self, 4, 3 + 17 + 3, size.x - 8, W31.WHITE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var h := -1
			if _item_rect(0).has_point(event.position):
				h = 0
			elif _item_rect(1).has_point(event.position):
				h = 2
			if h != hover:
				hover = h
				queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _item_rect(0).has_point(event.position):
				dialog.begin_keyboard_move()
			elif _item_rect(1).has_point(event.position):
				dialog._close_menu()
				dialog.cancel()
			accept_event()
