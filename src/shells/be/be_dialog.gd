class_name BeDialog
extends Control
## Modal Be dialog. A full-shell blocker holding one framed panel: optional yellow title tab (Get Info, forms), optional
## 40px left strip with a 32px icon (message dialogs), a vertical stack of rows and a right-aligned button row.
## Rows are plain Controls (BeLabel, BeField, BeSelect, BeCheck, BeChoice, grids built with row_grid()).
## Enter presses the default button, Escape cancels. BeDialogs builds the concrete dialogs.

signal closed

const BORDER := 1
const GAP := 14

var title := ""
var tabbed := false
var text_mode := false
var panel_w := 480
var icon_tex: Texture2D
var cancel_cb := Callable()
## Optional key hook for the topmost dialog: func(k: InputEventKey) -> bool (true = handled). Runs before
## Escape / Enter, so a list dialog can take the arrow keys or Space.
var key_handler := Callable()
var content: VBoxContainer
var buttons: Array = []
var default_button: BeButton
var _frame := Rect2()
var _pad := Vector4(18, 16, 18, 14)  ## left, top, right, bottom
var _strip := 0
var _done := false


static func open(layer: Control, p_title: String, width: int, p_tabbed: bool, p_text: bool, auto_id: String = "be.dialog") -> BeDialog:
	var d := BeDialog.new()
	d.title = p_title
	d.panel_w = width
	d.tabbed = p_tabbed
	d.text_mode = p_text
	if p_text:
		d._strip = 40
		d._pad = Vector4(26, 18, 18, 14)
	BeUi.auto_id(d, auto_id)
	layer.add_child(d)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d._setup()
	return d


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _setup() -> void:
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", GAP)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)


func content_width() -> float:
	return panel_w - 2 * BORDER - _strip - _pad.x - _pad.z


func add_row(c: Control) -> Control:
	content.add_child(c)
	return c


## Rows laid out as a two-column grid (label column right-aligned or left, field column expanding).
func row_grid(pairs: Array, label_w: float, gap: Vector2 = Vector2(12, 10), right_labels: bool = false) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(gap.x))
	g.add_theme_constant_override("v_separation", int(gap.y))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in pairs:
		var l := BeLabel.make(String(p[0]), false, 0.0, "444444" if right_labels else "000000")
		l.align_right = right_labels
		l.custom_minimum_size.x = label_w
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(l)
		var f: Control = p[1]
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(f)
	content.add_child(g)
	return g


func set_buttons(specs: Array) -> void:
	## specs: [{label, id?, default?, cb: Callable (returns true to keep open)}]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 2)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	for s in specs:
		var b := BeButton.make(String(s.label), bool(s.get("default", false)), "be.dialog.button:" + String(s.label))
		var cb: Callable = s.get("cb", Callable())
		b.pressed.connect(func():
			var keep := false
			if cb.is_valid():
				keep = bool(cb.call())
			if not keep:
				close())
		row.add_child(b)
		buttons.append(b)
		if bool(s.get("default", false)):
			default_button = b
	content.add_child(pad)


## Positions everything once rows exist. Call after the last add_row/set_buttons.
func finish() -> void:
	relayout()
	if default_button != null:
		default_button.grab_focus.call_deferred()


## Re-measures and re-centres the panel after a row changed size (keeps the focus where it is).
func relayout() -> void:
	content.size = Vector2(content_width(), 0)
	var h := content.get_combined_minimum_size().y
	var ph := maxf(h + _pad.y + _pad.w + 2 * BORDER, 60.0 if text_mode else 0.0)
	var view := size if size.x > 0 else get_viewport_rect().size
	var total := ph + (BeGeometry.TAB_H if tabbed else 0)
	var x := floorf(maxf(0.0, (view.x - panel_w) / 2.0))
	var top := floorf(maxf(0.0, (view.y - total) / 2.0))
	_frame = Rect2(x, top + (BeGeometry.TAB_H if tabbed else 0), panel_w, ph)
	content.position = _frame.position + Vector2(BORDER + _strip + _pad.x, BORDER + _pad.y)
	content.size = Vector2(content_width(), h)
	if tabbed:
		var tw := BeGeometry.tab_width(BeFont.width(title, BeGeometry.FONT, true), panel_w, false)
		set_meta("tab_w", tw)
	queue_redraw()


func frame_rect() -> Rect2:
	return _frame


func close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()


func cancel() -> void:
	if cancel_cb.is_valid():
		cancel_cb.call()
	close()


func _draw() -> void:
	if _frame.size == Vector2.ZERO:
		return
	BeDraw.panel(self, _frame)
	# 3px 3px 0 rgba(0,0,0,.25) shadow, below the panel edge
	draw_rect(Rect2(_frame.position.x + 3, _frame.end.y, _frame.size.x, 3), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(_frame.end.x, _frame.position.y + 3, 3, _frame.size.y), Color(0, 0, 0, 0.25))
	if text_mode:
		var strip := Rect2(_frame.position.x + 1, _frame.position.y + 1, _strip, _frame.size.y - 2)
		BeDraw.fill(self, strip, BeTheme.b("bcbcbc"))
		BeDraw.vline(self, strip.end.x - 1, strip.position.y, strip.size.y, BeTheme.b("a8a8a8"))
		BeDraw.icon(self, icon_tex, Rect2(_frame.position.x + 16, _frame.position.y + 14, 32, 32))
	if tabbed:
		var tw: float = get_meta("tab_w", 120.0)
		var tab := Rect2(_frame.position.x, _frame.position.y - BeGeometry.TAB_H + 1, tw, BeGeometry.TAB_H)
		BeDraw.tab(self, tab, true, false)
		BeDraw.close_box(self, Rect2(tab.position.x + 7, tab.position.y + 5, 15, 15))
		BeFont.draw(self, Vector2(tab.position.x + 7 + 15 + 10, tab.position.y), BeFont.clip(title, tw - 7 - 15 - 10 - 10), BeTheme.t("000000"), BeGeometry.FONT, true, BeGeometry.TAB_H)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and tabbed:
			var tab_close := Rect2(_frame.position.x + 7, _frame.position.y - BeGeometry.TAB_H + 6, 15, 15)
			if tab_close.has_point(mb.position):
				cancel()
		accept_event()
	elif event is InputEventMouseMotion:
		accept_event()


func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or not event.pressed:
		return
	if BeUi.popup_layer != null and BeUi.popup_layer.get_child_count() > 0:
		return  # an open select list owns the keyboard
	if get_parent() != null and get_parent().get_child(get_parent().get_child_count() - 1) != self:
		return  # only the topmost dialog reacts
	var k := event as InputEventKey
	var vp := get_viewport()  # the dialog may remove itself below
	if key_handler.is_valid() and bool(key_handler.call(k)):
		vp.set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE:
		cancel()
		vp.set_input_as_handled()
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and default_button != null:
		var f := vp.gui_get_focus_owner()
		if (f is BeButton and f != default_button) or f is TextEdit:
			return  # a focused button activates itself; a text box types a new line
		default_button.pressed.emit()
		vp.set_input_as_handled()
