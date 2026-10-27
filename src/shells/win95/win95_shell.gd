class_name Win95Shell
extends ShellBase
## PLACEHOLDER — replaced by the full Win95 shell port.


func shell_id() -> String:
	return "win95"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.W95_DESKTOP)
