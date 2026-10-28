class_name W31Button
extends W31Widget
## `.win31-button`: 1px white/grey bevel, 1px black outline (2px when default), centred label,
## dotted focus ring, pressed state with the text nudged by (1,1). Port of Common/Button.tsx
## + the .shell-win31 rules in dialog.css/wfw.css.

signal pressed

const MIN_WIDTH := 68
const MIN_HEIGHT := 22
const PAD_X := 8
const PAD_Y := 2
const LINE := 13

var text := "":
	set(v):
		text = v
		queue_redraw()
var is_default := false:
	set(v):
		is_default = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		queue_redraw()
var wrap_text := false  ## properties column: fixed width, label wraps ("Change Icon...")

var _down := false


func _init(p_text: String = "", p_default: bool = false) -> void:
	text = p_text
	is_default = p_default
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_auto_id("wfw.dialog.button:" + RetroFont.parse_access(p_text).text)


## Natural size: min 68x22, label + 16px padding + 2px border (wraps when `wrap_text`).
func fit(width: int = 0) -> Vector2:
	var f := W31.font()
	var label: String = RetroFont.parse_access(text).text
	if wrap_text and width > 0:
		var lines := f.wrap(label, width - 2 - 2 * PAD_X)
		return Vector2(width, maxi(MIN_HEIGHT, lines.size() * LINE + 2 * PAD_Y + 2))
	var w := maxi(MIN_WIDTH, f.measure(label) + 2 * PAD_X + 2)
	if width > 0:
		w = width
	return Vector2(w, MIN_HEIGHT)


func _label_lines(label: String) -> PackedStringArray:
	if wrap_text:
		return W31.font().wrap(label, int(size.x) - 2 - 2 * PAD_X)
	return PackedStringArray([label])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# outline outside the border box: 1px, 2px for the default button
	var ring := 2 if is_default else 1
	Px.fill_rect(self, r.grow(ring), W31.BLACK)
	Px.fill_rect(self, r, W31.FACE)
	var down := _down and not disabled
	if down:
		W31.border2(self, r, W31.SHADOW, W31.WHITE)
	else:
		W31.border2(self, r, W31.WHITE, W31.SHADOW)
	var label: String = RetroFont.parse_access(text).text
	var f := W31.font()
	var lines := _label_lines(label)
	var off := Vector2(1, 1) if down else Vector2.ZERO
	var total_h := lines.size() * LINE
	var top := floorf((size.y - total_h) / 2.0) + off.y
	for i in lines.size():
		var w := f.measure(lines[i])
		var x := floorf((size.x - w) / 2.0) + off.x
		f.draw(self, Vector2(x, top + i * LINE), lines[i], W31.BLACK, {"disabled": disabled, "show_access": false})
	if has_focus() and not disabled:
		Px.focus_rect(self, Rect2(4 + off.x, 4 + off.y, size.x - 8, size.y - 8))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			grab_focus()
			queue_redraw()
			accept_event()
		elif _down:
			_down = false
			queue_redraw()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			accept_event()
	elif event is InputEventKey and has_focus():
		if event.keycode == KEY_SPACE:
			_down = event.pressed
			queue_redraw()
			if not event.pressed:
				pressed.emit()
			accept_event()
		elif event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			pressed.emit()
			accept_event()


func activate_access_key() -> void:
	click()


## Programmatic click (tests, default-button activation).
func click() -> void:
	if not disabled:
		pressed.emit()
