class_name W31ScrollBar
extends W31Widget
## 16px vertical WfW scrollbar: raised arrow buttons, dithered channel, raised thumb.
## Units are arbitrary (pixels or rows): `total` content, `page` visible, `value` offset.

signal scrolled(value: float)

const WIDTH := 16
const BUTTON := 16

var total := 0.0:
	set(v):
		total = v
		_value = clampf(_value, 0.0, max_value())
		queue_redraw()
var page := 0.0:
	set(v):
		page = v
		_value = clampf(_value, 0.0, max_value())
		queue_redraw()
var value := 0.0:
	get:
		return _value
	set(v):
		_value = clampf(v, 0.0, max_value())
		queue_redraw()
var step := 13.0

var _value := 0.0
var _drag := false
var _drag_origin := 0.0
var _drag_value := 0.0
var _hold := ""  ## "up" | "down" while an arrow is pressed


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


func max_value() -> float:
	return maxf(0.0, total - page)


func _track() -> Rect2:
	return Rect2(0, BUTTON, WIDTH, maxf(0.0, size.y - 2 * BUTTON))


func _thumb() -> Rect2:
	var t := _track()
	if total <= page or total <= 0.0:
		return Rect2(t.position, Vector2.ZERO)
	var len := maxf(BUTTON, floorf(t.size.y * page / total))
	var travel := t.size.y - len
	var y := t.position.y + (floorf(travel * value / max_value()) if max_value() > 0.0 else 0.0)
	return Rect2(0, y, WIDTH, len)


func _draw() -> void:
	var t := _track()
	Px.checker(self, t, W31.FACE, W31.WHITE)
	var up := Rect2(0, 0, WIDTH, BUTTON)
	var down := Rect2(0, size.y - BUTTON, WIDTH, BUTTON)
	W31.raised(self, up, _hold == "up")
	W31.raised(self, down, _hold == "down")
	W31.triangle(self, up.get_center() + Vector2(0, 0), 0, 4)
	W31.triangle(self, down.get_center() + Vector2(0, 0), 1, 4)
	var th := _thumb()
	if th.size.y > 0:
		W31.raised(self, th)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = event.position
			if p.y < BUTTON:
				_hold = "up"
				_set(value - step)
			elif p.y >= size.y - BUTTON:
				_hold = "down"
				_set(value + step)
			else:
				var th := _thumb()
				if th.size.y > 0 and th.has_point(p):
					_drag = true
					_drag_origin = p.y
					_drag_value = value
				elif p.y < th.position.y:
					_set(value - page)
				else:
					_set(value + page)
			queue_redraw()
		else:
			_drag = false
			_hold = ""
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		var t := _track()
		var th := _thumb()
		var travel := t.size.y - th.size.y
		if travel > 0.0:
			_set(_drag_value + (event.position.y - _drag_origin) * max_value() / travel)
		accept_event()


func _set(v: float) -> void:
	var old := value
	value = v
	if value != old:
		scrolled.emit(value)
