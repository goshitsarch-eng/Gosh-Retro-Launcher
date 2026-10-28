class_name Win95Modal
extends Control
## Reusable Win95 modal dialog frame (port of the Win95Dialog wrapper in Win95Dialogs.tsx).
##
##   var m := Win95Modal.open(shell, "Run", Vector2(347, 163), {"help": "Context help text"})
##   m.body                      # Control at the client origin; add widgets in body coordinates
##                               # (body is (width-8) x (height-26); the CSS body padding is 10px 9px 8px)
##   m.add(widget, Vector2(x, y))
##   m.set_default(button)       # Enter activates it (unless a button has focus); also the "default" outline
##   m.on_cancel = callable      # Esc / Alt+F4 / caption Close; default just closes
##   m.close()                   # closes and emits `closed`
## A full-rect overlay blocks all pointer input beneath the dialog; while any modal is open the
## input controller routes keys ONLY to the "modal" layer: Esc/Alt+F4 cancel, Tab/Shift+Tab move focus,
## Enter = default/focused button, Alt+<letter> triggers the widget whose &access key matches.
## The caption can be dragged. Key/Default routing uses Win95DialogState.

signal closed

var shell: Control
var title := ""
var frame_size := Vector2(360, 120)
var context_help := ""
var body: Control
var default_button: Control
var on_cancel: Callable = Callable()

var _uid := ""
var _drag_start := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _dragging := false
var _frame_pos := Vector2.ZERO
var _closed := false
static var _counter := 0


static func open(p_shell: Control, p_title: String, p_size: Vector2, opts: Dictionary = {}) -> Win95Modal:
	var m := Win95Modal.new()
	m.shell = p_shell
	m.title = p_title
	m.frame_size = p_size
	m.context_help = String(opts.get("help", ""))
	m._uid = "modal-%d" % Win95Modal._counter
	Win95Modal._counter += 1
	p_shell.dialog_layer.add_child(m)
	m._build()
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _build() -> void:
	var vp: Vector2 = shell.logical_size
	_frame_pos = Vector2(Win95ShellInput.js_round((vp.x - frame_size.x) / 2.0), Win95ShellInput.js_round((vp.y - frame_size.y - 28) / 2.0))
	_frame_pos = Vector2(maxf(0, _frame_pos.x), maxf(0, _frame_pos.y))
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_place_body()
	shell.input.set_modal(_uid, true)
	shell.input.register_key("modal", _uid, _on_key)
	add_to_group("pm_auto")
	queue_redraw()


func _place_body() -> void:
	body.position = _frame_pos + Vector2(4, 22)
	body.size = Vector2(frame_size.x - 8, frame_size.y - 26)


func add(widget: Control, at: Vector2) -> Control:
	body.add_child(widget)
	widget.position = at
	return widget


func set_default(btn: Control) -> void:
	if default_button != null and is_instance_valid(default_button) and default_button is Win95Button:
		(default_button as Win95Button).default_button = false
	default_button = btn
	if btn is Win95Button:
		(btn as Win95Button).default_button = true


func frame_rect() -> Rect2:
	return Rect2(_frame_pos, frame_size)


func _exit_tree() -> void:
	if shell != null and is_instance_valid(shell) and shell.input != null:
		shell.input.set_modal(_uid, false)
		shell.input.unregister_key("modal", _uid)


func close() -> void:
	if _closed:
		return
	_closed = true
	shell.input.set_modal(_uid, false)
	shell.input.unregister_key("modal", _uid)
	closed.emit()
	queue_free()


func cancel() -> void:
	if on_cancel.is_valid():
		on_cancel.call()
	else:
		close()


# -------------------------------------------------------------------- drawing

func _caption_rect() -> Rect2:
	return Rect2(_frame_pos + Vector2(4, 4), Vector2(frame_size.x - 8, 18))


func _close_rect() -> Rect2:
	return Rect2(_frame_pos + Vector2(frame_size.x - 22, 6), Vector2(16, 14))


func _help_rect() -> Rect2:
	return Rect2(_frame_pos + Vector2(frame_size.x - 38, 6), Vector2(16, 14))


var _pressed_cap := ""


func _draw() -> void:
	var fr := frame_rect()
	Win95Draw.window_frame(self, fr)
	var cap := _caption_rect()
	Win95Draw.fill(self, cap, Win95Draw.CAPTION)
	Win95Draw.text(self, cap.position + Vector2(2, 3), title, Color.WHITE,
		{"bold": true, "max_width": maxi(1, int(frame_size.x) - (49 if context_help != "" else 31))})
	for part in ["close", "help"]:
		if part == "help" and context_help == "":
			continue
		var r := _close_rect() if part == "close" else _help_rect()
		if _pressed_cap == part:
			Win95Draw.pressed(self, r)
		else:
			Win95Draw.raised(self, r)
		Win95Draw.glyph(self, part, r.position + Vector2(2, 2) + (Vector2(1, 1) if _pressed_cap == part else Vector2.ZERO))


# ------------------------------------------------------------------- pointer

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			if _close_rect().has_point(p):
				_pressed_cap = "close"
			elif context_help != "" and _help_rect().has_point(p):
				_pressed_cap = "help"
			elif _caption_rect().has_point(p):
				_dragging = true
				_drag_start = p
				_drag_origin = _frame_pos
			queue_redraw()
		else:
			var part := _pressed_cap
			_pressed_cap = ""
			_dragging = false
			queue_redraw()
			if part == "close" and _close_rect().has_point(p):
				cancel()
			elif part == "help" and _help_rect().has_point(p):
				Win95Dialogs.show_message(shell, "Help", context_help, "information")
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_frame_pos = (_drag_origin + event.position - _drag_start).round()
		_place_body()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()


# ------------------------------------------------------------------ keyboard

func _focus_chain() -> Array:
	var out: Array = []
	_collect(body, out)
	return out


func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Win95TextInput:
			if not c.disabled:
				out.append(c)
		elif c is Control and c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not (c is LineEdit):
			if not ("disabled" in c and c.disabled):
				out.append(c)
		if c.get_child_count() > 0 and not (c is Win95TextInput):
			_collect(c, out)


func _focused_widget() -> Control:
	var owner := shell.get_viewport().gui_get_focus_owner()
	if owner == null:
		return null
	if owner is LineEdit and owner.get_parent() is Win95TextInput:
		return owner.get_parent()
	return owner


func _focus_widget(w: Control) -> void:
	if w is Win95TextInput:
		(w as Win95TextInput).focus_edit()
	else:
		w.grab_focus()


func _on_key(event: Dictionary) -> bool:
	var focused := _focused_widget()
	var has_default: bool = default_button != null and is_instance_valid(default_button) and not ("disabled" in default_button and default_button.disabled)
	var is_button := focused is Win95Button
	var action := Win95DialogState.resolve_key(event, has_default, is_button, false)
	match action:
		"cancel":
			cancel()
			return true
		"advance-focus", "reverse-focus":
			var chain := _focus_chain()
			if chain.is_empty():
				return true
			var idx := chain.find(focused)
			var next: int
			if action == "reverse-focus":
				next = chain.size() - 1 if idx <= 0 else idx - 1
			else:
				next = 0 if idx >= chain.size() - 1 else idx + 1
			_focus_widget(chain[next])
			return true
	var key: String = event.key
	if event.get("altKey", false) and key.length() == 1:
		var access := key.to_lower()
		var found: Control = null
		for w in _all_widgets(body):
			if w.has_method("access_key") and w.access_key() == access:
				found = w
		if found != null:
			if found.has_method("click"):
				found.click()
			if found is Win95Checkbox or found is Win95Radio or found is Win95Button:
				_focus_widget(found)
			return true
		return false
	if key == "Enter" and is_button:
		(focused as Win95Button).click()
		return true
	if key == " " and focused != null and focused.has_method("click") and not (focused is Win95TextInput):
		focused.click()
		return true
	if action == "default" and has_default:
		if default_button.has_method("click"):
			default_button.click()
		return true
	return false


func _all_widgets(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_widgets(c))
	return out


# ---------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if id.begins_with("w95.dialog.button:"):
		var label := id.substr("w95.dialog.button:".length())
		for w in _all_widgets(body):
			if w is Win95Button and String(w.label).replace("&", "") == label:
				return Rect2(w.global_position, w.size)
	return null
