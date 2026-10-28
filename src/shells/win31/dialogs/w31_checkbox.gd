class_name W31Checkbox
extends W31Widget
## `.win31-checkbox` (13x13 sunken box, 5px gap, 12px label). Port of Common/Checkbox.tsx.

signal toggled(checked: bool)

const BOX := 13
const GAP := 5
const CHECK := [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]

var text := ""
var checked := false:
	set(v):
		checked = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
		queue_redraw()


func _init(p_text: String = "", p_checked: bool = false) -> void:
	text = p_text
	checked = p_checked
	focus_mode = Control.FOCUS_ALL
	set_auto_id("wfw.dialog.checkbox:" + RetroFont.parse_access(p_text).text)
	custom_minimum_size = natural_size()
	size = custom_minimum_size


func natural_size() -> Vector2:
	return Vector2(BOX + GAP + W31.text_w(text, 11), 13)


func _draw() -> void:
	# box: y centred in the 13px row
	var box := Rect2(0, 0, BOX, BOX)
	Px.fill_rect(self, box, W31.FACE if disabled else W31.WHITE)
	W31.border2(self, box, W31.SHADOW, W31.WHITE, W31.WHITE)
	if checked:
		var col := W31.SHADOW if disabled else W31.BLACK
		for y in CHECK.size():
			for x in CHECK[y].length():
				if CHECK[y][x] == "#":
					Px.fill(self, 3 + x, 4 + y, 1, 1, col)
	var tx := BOX + GAP
	W31.text(self, tx, 0, text, W31.BLACK, 11, {"disabled": disabled})
	if has_focus():
		var w := W31.text_w(text, 11)
		Px.focus_rect(self, Rect2(tx - 2, -1, w + 4, 15))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		toggle()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and has_focus():
		toggle()
		accept_event()


func toggle() -> void:
	checked = not checked
	toggled.emit(checked)


func activate_access_key() -> void:
	if not disabled:
		grab_focus()
		toggle()
