class_name BeIconBox
extends Control
## 32px smooth icon for dialogs; follows `icon` / `item_name` changes.

var icon := "default":
	set(v):
		icon = v
		queue_redraw()
var item_name := ""


func _init() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	BeDraw.icon(self, BeIconCatalog.texture(icon, item_name), Rect2(Vector2.ZERO, Vector2(32, 32)))
