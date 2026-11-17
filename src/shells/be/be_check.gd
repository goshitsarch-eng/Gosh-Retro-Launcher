class_name BeCheck
extends Control
## Check box (15px gradient square with a bold blue tick) plus label. Emits `toggled(on)`.

signal toggled(on: bool)

var label := ""
var checked := false:
	set(v):
		checked = v
		queue_redraw()


static func make(p_label: String, p_checked: bool, p_id: String = "") -> BeCheck:
	var c := BeCheck.new()
	c.label = p_label
	c.checked = p_checked
	c.custom_minimum_size = Vector2(15 + 8 + BeFont.width(p_label), 20)
	if p_id != "":
		BeUi.auto_id(c, p_id)
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		checked = not checked
		toggled.emit(checked)
		accept_event()


## The 15px box with its tick (also drawn by the "checks" lists in BeChoice).
static func draw_box(ci: CanvasItem, box: Rect2, on: bool) -> void:
	BeDraw.gradient_diag(ci, box.grow(-1), BeTheme.b("ffffff"), BeTheme.b("d8d8d8"))
	BeDraw.border(ci, box, BeTheme.b("6a6a6a"))
	if on:
		var c := BeTheme.t("1a3a8a")
		ci.draw_polyline(PackedVector2Array([box.position + Vector2(3.5, 7.5), box.position + Vector2(6, 10.5), box.position + Vector2(11.5, 3.5)]), c, 2.0, true)


func _draw() -> void:
	draw_box(self, Rect2(0, (size.y - 15) / 2.0, 15, 15), checked)
	BeFont.draw(self, Vector2(23, (size.y - BeGeometry.LINE) / 2.0), label, BeTheme.t("000000"))
