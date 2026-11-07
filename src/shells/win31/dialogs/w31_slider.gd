class_name W31Slider
extends W31Widget
## `input[type=range]` as styled by dialog.css: 4px sunken channel, 9x16 raised thumb.

signal value_changed(value: float)

const THUMB_W := 9
const THUMB_H := 16
const HEIGHT := 18

var min_value := 0.0
var max_value := 100.0
var step := 1.0
var value := 0.0:
	set(v):
		value = _snap(v)
		queue_redraw()

var _drag := false


func _init(p_min: float = 0.0, p_max: float = 100.0, p_step: float = 1.0) -> void:
	min_value = p_min
	max_value = p_max
	step = p_step
	focus_mode = Control.FOCUS_ALL
	set_auto_id("wfw.dialog.slider")


func _snap(v: float) -> float:
	var s := roundf((v - min_value) / step) * step + min_value
	return clampf(s, min_value, max_value)


func _thumb_x() -> float:
	var frac := (value - min_value) / maxf(max_value - min_value, 0.0001)
	return floorf((size.x - THUMB_W) * frac + 0.5)


func _draw() -> void:
	var ty := floorf((size.y - 4) / 2.0)
	var track := Rect2(0, ty, size.x, 4)
	Px.fill_rect(self, track, W31.FACE)
	W31.border2(self, track, W31.SHADOW, W31.WHITE)
	var th := Rect2(_thumb_x(), floorf((size.y - THUMB_H) / 2.0), THUMB_W, THUMB_H)
	Px.fill_rect(self, th, W31.FACE)
	W31.border2(self, th, W31.WHITE, W31.BLACK, W31.SHADOW)
	if has_focus():
		Px.focus_rect(self, th.grow(-2))


func _set_from_x(x: float) -> void:
	var frac := clampf((x - THUMB_W / 2.0) / maxf(size.x - THUMB_W, 1.0), 0.0, 1.0)
	_commit(min_value + frac * (max_value - min_value))


func _commit(v: float) -> void:
	var old := value
	value = v
	if value != old:
		value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if event.pressed:
			grab_focus()
			_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		match event.keycode:
			KEY_LEFT, KEY_DOWN:
				_commit(value - step)
			KEY_RIGHT, KEY_UP:
				_commit(value + step)
			KEY_PAGEDOWN:
				_commit(value - step * 10)
			KEY_PAGEUP:
				_commit(value + step * 10)
			KEY_HOME:
				_commit(min_value)
			KEY_END:
				_commit(max_value)
			_:
				return
		accept_event()
