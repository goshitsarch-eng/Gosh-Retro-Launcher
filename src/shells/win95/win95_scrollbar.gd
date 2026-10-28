class_name Win95Scrollbar
extends Control
## Deterministic Win95 scrollbar (port of Win95Scrollbar.tsx): 16px line buttons, dithered
## shaft, proportional raised thumb, press-and-hold auto-repeat (350 ms delay, 55 ms interval),
## shaft paging and thumb dragging. Emits `scrolled(value)` with the new content offset.
##   var sb := Win95Scrollbar.new(); sb.vertical = true; sb.configure(value, viewport, content, length, line)
## The control is `length` long and 16 px thick.

signal scrolled(value: int)

const ARROW := 16
const REPEAT_DELAY := 0.35
const REPEAT_INTERVAL := 0.055

var vertical := true
var value := 0
var viewport_size := 0.0
var content_size := 0.0
var length := 0.0
var line_size := 16.0

var _metrics: Dictionary = {}
var _pressed_part := ""          ## "first" | "last" | "track" | "thumb" | ""
var _drag_start := 0.0
var _drag_thumb := 0.0
var _repeat: Timer
var _repeat_action: Callable = Callable()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_repeat = Timer.new()
	_repeat.one_shot = true
	_repeat.timeout.connect(_on_repeat)
	add_child(_repeat)


func configure(p_value: int, p_viewport: float, p_content: float, p_length: float, p_line: float = 16.0) -> void:
	value = p_value
	viewport_size = p_viewport
	content_size = p_content
	length = p_length
	line_size = p_line
	size = Vector2(ARROW, length) if vertical else Vector2(length, ARROW)
	_update_metrics()
	queue_redraw()


func _track_length() -> float:
	return maxf(0.0, length - ARROW * 2)


func _update_metrics() -> void:
	_metrics = Win95ScrollbarState.thumb_metrics(viewport_size, content_size, _track_length())
	_metrics["thumbOffset"] = Win95ScrollbarState.thumb_offset(value, _metrics)


func max_scroll() -> float:
	return float(_metrics.maxScroll)


# --------------------------------------------------------------------- drawing

func _arrow_rect(first: bool) -> Rect2:
	if vertical:
		return Rect2(0, 0 if first else length - ARROW, ARROW, ARROW)
	return Rect2(0 if first else length - ARROW, 0, ARROW, ARROW)


func _track_rect() -> Rect2:
	if vertical:
		return Rect2(0, ARROW, ARROW, _track_length())
	return Rect2(ARROW, 0, _track_length(), ARROW)


func _thumb_rect() -> Rect2:
	var t := _track_rect()
	var off := float(_metrics.thumbOffset)
	var len := float(_metrics.thumbLength)
	if vertical:
		return Rect2(t.position.x, t.position.y + off, ARROW, len)
	return Rect2(t.position.x + off, t.position.y, len, ARROW)


func _draw_arrow(first: bool) -> void:
	var r := _arrow_rect(first)
	var disabled := (value <= 0) if first else (float(value) >= float(_metrics.maxScroll))
	var down := _pressed_part == ("first" if first else "last") and not disabled
	Win95Draw.fill(self, r, Win95Draw.FACE)
	if down:
		Win95Draw.border(self, r, 1, Win95Draw.DARK, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.DARK)
		Win95Draw.inset_shadow(self, r.grow(-1), 1, 1, Win95Draw.SHADOW)
	else:
		Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
		Win95Draw.inset_shadow(self, r.grow(-1), -1, -1, Win95Draw.SHADOW)
	var name := ("scroll-up" if first else "scroll-down") if vertical else ("scroll-left" if first else "scroll-right")
	var origin := r.position + Vector2(1, 2) + (Vector2(1, 1) if down else Vector2.ZERO)
	var color := Win95Draw.FACE.lerp(Win95Draw.DARK, 0.35) if disabled else Win95Draw.DARK
	Win95Draw.glyph(self, name, origin, color)


func _draw() -> void:
	_update_metrics()
	_draw_arrow(true)
	_draw_arrow(false)
	var t := _track_rect()
	if t.size.x > 0 and t.size.y > 0:
		Win95Draw.fill(self, t, Win95Draw.LIGHT)
		Win95Draw.dither_checker(self, t, t.position, Win95Draw.FACE)
		var th := _thumb_rect()
		if float(_metrics.maxScroll) > 0:
			Win95Draw.fill(self, th, Win95Draw.FACE)
			Win95Draw.border(self, th, 2, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
			Win95Draw.inset_shadow(self, th.grow(-2), -1, -1, Win95Draw.SHADOW)
		else:
			Win95Draw.fill(self, th, Win95Draw.FACE)
			Win95Draw.border(self, th, 2, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
			Win95Draw.inset_shadow(self, th.grow(-2), -1, -1, Win95Draw.SHADOW)


# ----------------------------------------------------------------- interaction

func _axis(p: Vector2) -> float:
	return p.y if vertical else p.x


func _emit_value(v: int) -> void:
	value = v
	scrolled.emit(v)
	queue_redraw()


func _step(direction: int) -> void:
	_emit_value(Win95ScrollbarState.scroll_step(value, direction, line_size, content_size, viewport_size))


func _page(direction: int) -> void:
	_emit_value(Win95ScrollbarState.scroll_page(value, direction, content_size, viewport_size))


func _start_repeat(action: Callable) -> void:
	_repeat_action = action
	action.call()
	_repeat.start(REPEAT_DELAY)


func _on_repeat() -> void:
	if _repeat_action.is_valid() and _pressed_part != "":
		_repeat_action.call()
		_repeat.start(REPEAT_INTERVAL)


func _stop_repeat() -> void:
	_repeat.stop()
	_repeat_action = Callable()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_pressed_part = ""
			_stop_repeat()
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _pressed_part == "thumb":
		var offset := _drag_thumb + _axis(event.position) - _drag_start
		_emit_value(Win95ScrollbarState.scroll_from_thumb(offset, _metrics))
		accept_event()


func _press(p: Vector2) -> void:
	_update_metrics()
	var max_s := float(_metrics.maxScroll)
	if _arrow_rect(true).has_point(p):
		if value > 0:
			_pressed_part = "first"
			_start_repeat(func(): _step(-1))
		return
	if _arrow_rect(false).has_point(p):
		if float(value) < max_s:
			_pressed_part = "last"
			_start_repeat(func(): _step(1))
		return
	if max_s <= 0:
		return
	if _thumb_rect().has_point(p):
		_pressed_part = "thumb"
		_drag_start = _axis(p)
		_drag_thumb = float(_metrics.thumbOffset)
		queue_redraw()
		return
	if _track_rect().has_point(p):
		_pressed_part = "track"
		var coordinate := _axis(p) - ARROW
		var dir := -1 if coordinate < float(_metrics.thumbOffset) else 1
		_start_repeat(func(): _page(dir))


## Rect (local) of a sub-part for automation/tests: "first", "last", "thumb", "track".
func part_rect(part: String) -> Rect2:
	match part:
		"first": return _arrow_rect(true)
		"last": return _arrow_rect(false)
		"thumb": return _thumb_rect()
		_: return _track_rect()
