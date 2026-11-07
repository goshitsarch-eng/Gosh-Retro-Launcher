class_name W31Radio
extends W31Widget
## `.wfw-radio-group` radio: 12x12 round button, 6px gap, 11px label with an underlined access
## key. Radios sharing a `group` array behave as one set (arrow keys move within it).

signal selected

const ROUND := [
	"...######...",
	"..########..",
	".##########.",
	"############",
	"############",
	"############",
	"############",
	"############",
	"############",
	".##########.",
	"..########..",
	"...######...",
]
const DOT := [
	".####.",
	"######",
	"######",
	"######",
	"######",
	".####.",
]

var text := ""  ## with & access marker
var checked := false:
	set(v):
		checked = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		queue_redraw()
var group: Array = []  ## shared Array of W31Radio


func _init(p_text: String = "") -> void:
	text = p_text
	focus_mode = Control.FOCUS_ALL
	var parsed := RetroFont.parse_access(p_text)
	access_key = parsed.accessKey
	set_auto_id("wfw.dialog.radio:" + parsed.text)
	size = Vector2(12 + 6 + W31.text_w(p_text, 11), 13)


func is_tab_stop() -> bool:
	if not super.is_tab_stop():
		return false
	if group.size() < 2:
		return true
	var any_checked := false
	for r in group:
		if r.checked and not r.disabled:
			any_checked = true
	if any_checked:
		return checked
	for r in group:
		if not r.disabled:
			return r == self
	return false


func _is_outer(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and y < 12 and x < 12 and ROUND[y][x] == "#"


func _draw() -> void:
	var fill := W31.FACE if disabled else W31.WHITE
	var ring := W31.SHADOW if disabled else W31.BLACK
	for y in 12:
		for x in 12:
			if not _is_outer(x, y):
				continue
			var edge := not (_is_outer(x - 1, y) and _is_outer(x + 1, y) and _is_outer(x, y - 1) and _is_outer(x, y + 1))
			Px.fill(self, x, y, 1, 1, ring if edge else fill)
	if checked:
		for y in 6:
			for x in 6:
				if DOT[y][x] == "#":
					Px.fill(self, 3 + x, 3 + y, 1, 1, W31.SHADOW if disabled else W31.BLACK)
	var f := W31.font()
	f.draw(self, Vector2(18, 0), text, W31.BLACK, {"disabled": disabled})
	if has_focus():
		var w := f.measure(RetroFont.parse_access(text).text)
		Px.focus_rect(self, Rect2(16, -1, w + 4, 15))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		select()
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		var step := 0
		match event.keycode:
			KEY_DOWN, KEY_RIGHT:
				step = 1
			KEY_UP, KEY_LEFT:
				step = -1
			KEY_SPACE:
				select()
				accept_event()
				return
		if step != 0 and group.size() > 1:
			var i := group.find(self)
			for n in group.size():
				i = posmod(i + step, group.size())
				var other: W31Radio = group[i]
				if not other.disabled:
					other.grab_focus()
					other.select()
					break
			accept_event()


func select() -> void:
	if checked:
		return
	for r in group:
		if r != self:
			r.checked = false
	checked = true
	selected.emit()


func activate_access_key() -> void:
	if not disabled:
		grab_focus()
		select()
