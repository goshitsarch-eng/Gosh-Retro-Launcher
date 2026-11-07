class_name W31IconWell
extends Control
## 42x42 sunken preview well with a 32px icon (`.win31-icon-preview-well`).

var icon := "default":
	set(v):
		icon = v
		queue_redraw()


func _init(p_icon: String = "default") -> void:
	icon = p_icon
	size = Vector2(42, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Px.fill(self, 0, 0, 42, 42, W31.WHITE)
	Px.outline(self, Rect2(0, 0, 42, 42), W31.SHADOW)
	Px.hline(self, 1, 1, 41, W31.BLACK)
	Px.vline(self, 1, 2, 40, W31.BLACK)
	Px.tex(self, W31Icons.texture(icon), Vector2(5, 5))
