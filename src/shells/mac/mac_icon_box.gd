class_name MacIconBox
extends Control
## A 32x32 (or 16x16) catalog icon for dialogs.

var icon := "application"
var small := false


static func make(p_icon: String, p_small: bool = false) -> MacIconBox:
	var b := MacIconBox.new()
	b.icon = p_icon
	b.small = p_small
	b.size = Vector2(16, 16) if p_small else Vector2(32, 32)
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	draw_texture_rect(MacIconCatalog.texture(icon, "small" if small else "large"), Rect2(Vector2.ZERO, size), false)
