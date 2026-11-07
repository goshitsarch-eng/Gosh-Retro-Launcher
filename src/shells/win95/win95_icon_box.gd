class_name Win95IconBox
extends Control
## A fixed Win95 icon (catalog id, alias or external icon string) drawn at its native size.
##   Win95IconBox.make("warning", Vector2(9, 10))          # 32x32
##   Win95IconBox.make("folder", pos, "small")              # 16x16

var icon := "":
	set(v):
		icon = v
		queue_redraw()
var family := "large"


static func make(p_icon: String, pos: Vector2, p_family: String = "large") -> Win95IconBox:
	var b := Win95IconBox.new()
	b.family = p_family
	b.size = Vector2(32, 32) if p_family == "large" else Vector2(16, 16)
	b.position = pos
	b.icon = p_icon
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	Win95Draw.icon(self, Win95IconCatalog.texture(icon, family), Vector2.ZERO)
