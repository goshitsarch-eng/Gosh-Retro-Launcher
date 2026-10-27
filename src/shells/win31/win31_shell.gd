class_name Win31Shell
extends ShellBase
## PLACEHOLDER — replaced by the full WfW shell port.


func shell_id() -> String:
	return "win31"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.FACE)
