class_name Win95Radio
extends Control
## Win95 radio button (12x12 ring + label). Radios sharing a `group` name (and the same parent) are
## mutually exclusive. Signal selected().

signal selected

var label := "":
	set(v):
		label = v
		_fit()
var checked := false:
	set(v):
		checked = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var group := ""

# 12x12 circle: [start_x, end_x] (inclusive) per row.
const SPANS := [[4, 7], [2, 9], [1, 10], [1, 10], [0, 11], [0, 11], [0, 11], [0, 11], [1, 10], [1, 10], [2, 9], [4, 7]]


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _fit() -> void:
	size = Vector2(12 + 4 + Win95Draw.measure(label), 13)
	custom_minimum_size = size
	queue_redraw()


func access_key() -> String:
	return String(RetroFont.parse_access(label).accessKey)


func click() -> void:
	if disabled or checked:
		return
	if group != "" and get_parent() != null:
		for sib in get_parent().get_children():
			if sib is Win95Radio and sib != self and sib.group == group:
				sib.checked = false
	checked = true
	selected.emit()


func _draw() -> void:
	var bg := Win95Draw.FACE if disabled else Win95Draw.WINDOW
	for y in 12:
		var s: Array = SPANS[y]
		for x in range(s[0], s[1] + 1):
			var edge: bool = x == s[0] or x == s[1] or y == 0 or y == 11
			var c := bg
			if edge:
				c = Win95Draw.DARK
			elif y <= 1 or x <= 1 or (x == s[0] + 1) and y < 6:
				c = Win95Draw.SHADOW
			draw_rect(Rect2(x, y, 1, 1), c)
	# light bottom-right highlight outside the ring
	for y in range(3, 12):
		var s2: Array = SPANS[y]
		draw_rect(Rect2(s2[1] + 1, y + 1 if y < 11 else y, 1, 1), Win95Draw.LIGHT)
	if checked:
		draw_rect(Rect2(3, 3, 6, 6), Win95Draw.DISABLED if disabled else Win95Draw.TEXT)
		for c in [Vector2(3, 3), Vector2(8, 3), Vector2(3, 8), Vector2(8, 8)]:
			draw_rect(Rect2(c, Vector2.ONE), bg)
	Win95Draw.text(self, Vector2(16, 0), label, Win95Draw.TEXT, {"disabled": disabled})
	if has_focus():
		Win95Draw.dotted_rect(self, Rect2(14, -1, size.x - 14 + 2, 15), Win95Draw.TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
		elif Rect2(Vector2.ZERO, size).has_point(event.position):
			click()
		accept_event()
