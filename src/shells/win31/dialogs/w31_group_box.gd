class_name W31GroupBox
extends W31Widget
## `.win31-groupbox`: 1px etched frame (grey top/left, white bottom/right) with the 12px label
## cut into the top border. Children are positioned by the owner relative to the box; use
## INNER_X/INNER_Y for the content origin (1px border + 7px/11px padding).

const INNER_X := 8
const INNER_Y := 12
const PAD_BOTTOM := 8

var title := ""


func _init(p_title: String = "") -> void:
	title = p_title
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	W31.group_frame(self, Rect2(Vector2.ZERO, size))
	var w := W31.text_w(title, 12)
	# label box: left 7, padding 0 3px, 13px tall centred on the top border (top -7)
	Px.fill(self, 7, -7, w + 6, 13, W31.FACE)
	W31.text(self, 10, -7, title, W31.BLACK, 12)
