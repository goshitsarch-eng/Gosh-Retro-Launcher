class_name Win31DesktopIcon
extends Control
## Classic desktop icon of the minimized Program Manager in desktop mode
## (.wfw-desktop-program-manager-icon): 75x64 cell, 32px icon, two-line navy label.
## Double-click or Enter restores the window.

signal restore_requested

const CELL := Vector2(75, 64)
const ICON_X := 22
const LABEL_LINES := ["Program", "Manager"]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	size = CELL
	custom_minimum_size = CELL
	add_to_group("pm_auto")


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var f := Win31Chrome.font()
	var tex := WfwIcons.texture("program-manager")
	if tex != null:
		Px.tex(self, tex, Vector2(ICON_X, 0), Vector2(32, 32))
	var widest := 0
	for l in LABEL_LINES:
		widest = maxi(widest, f.measure(l))
	var box_w := widest + 4
	var box := Rect2(floorf((CELL.x - box_w + 1) / 2.0), 34, box_w, 24)
	Px.fill_rect(self, box, Pal.NAVY)
	for i in LABEL_LINES.size():
		var w := f.measure(LABEL_LINES[i])
		f.draw(self, Vector2(box.position.x + 2 + floorf((widest - w) / 2.0), box.position.y + i * 12), LABEL_LINES[i], Pal.WHITE,
			{"line_height": 12, "show_access": false})
	if has_focus():
		Px.focus_rect(self, box, Pal.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		if event.double_click:
			restore_requested.emit()
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus() and Win31Commands.key_name(event) == "enter":
		accept_event()
		restore_requested.emit()


func auto_lookup(id: String) -> Variant:
	if id == "wfw.desktop-icon:program-manager" and is_visible_in_tree():
		return get_global_rect()
	return null
