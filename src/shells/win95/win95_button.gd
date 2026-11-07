class_name Win95Button
extends Control
## Win95 push button (port of Win95Button / .win95-control-button). Native Control: focusable,
## press-drag-release, keyboard "click()" from the modal key router.
##   var b := Win95Button.new(); b.label = "&OK"; b.default_button = true; b.size = Vector2(75, 23)
##   b.pressed.connect(...)
## Raised/pressed faces, default-button outline, dotted focus rect, disabled text, `set_state`
## (toggled dither look). `access_key` is the lower-case &-key (or "").

signal pressed

var label := "":
	set(v):
		label = v
		queue_redraw()
var default_button := false:
	set(v):
		default_button = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var set_state := false:
	set(v):
		set_state = v
		queue_redraw()
var _down := false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Win95Tokens.M.buttonMinWidth, Win95Tokens.M.buttonHeight)
	custom_minimum_size = size


func access_key() -> String:
	return String(RetroFont.parse_access(label).accessKey)


func click() -> void:
	if not disabled:
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var down := _down or set_state
	if default_button:
		Win95Draw.outline_rect(self, r.grow(2), Win95Draw.DARK)  # outline: 1px solid; outline-offset: 1px
	if down:
		Win95Draw.pressed(self, r)
		if set_state and not _down:
			Win95Draw.dither_checker(self, r.grow(-2), Vector2(2, 2), Win95Draw.LIGHT)
	else:
		Win95Draw.raised(self, r)
	var tw := Win95Draw.measure(label)
	var off := Vector2(1, 1) if down else Vector2.ZERO
	Win95Draw.text(self, Vector2(int((size.x - tw) / 2.0) + off.x, int((size.y - 13) / 2.0) + off.y), label, Win95Draw.TEXT, {"disabled": disabled})
	if has_focus() and not default_button:
		Win95Draw.dotted_rect(self, r.grow(-5), Win95Draw.TEXT)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			grab_focus()
			queue_redraw()
		else:
			var was := _down
			_down = false
			queue_redraw()
			if was and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
