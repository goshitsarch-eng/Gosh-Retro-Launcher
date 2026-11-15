class_name BeToast
extends Control
## Launch feedback toast: logo + text in a small framed box at the bottom-right of the desktop (design: z 650).

var text := "":
	set(v):
		text = v
		visible = text != ""
		queue_redraw()
var _timer: Timer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 1.8
	_timer.timeout.connect(func(): text = "")
	add_child(_timer)
	add_to_group("pm_auto")


func show_text(t: String, seconds: float = 1.8) -> void:
	text = t
	_timer.start(seconds)


func hide_toast() -> void:
	_timer.stop()
	text = ""


func auto_lookup(id: String) -> Variant:
	if id == "be.toast" and visible:
		return _box()
	return null


func _box() -> Rect2:
	var w := 14.0 * 2 + 24 + 10 + BeFont.width(text) + 2
	var h := 8.0 * 2 + 24 + 2
	return Rect2(size.x - 12 - w, size.y - 12 - h, w, h)


func _draw() -> void:
	if text == "":
		return
	var b := _box()
	BeDraw.popup_frame(self, b)
	BeDraw.icon(self, BeIconCatalog.texture("logo"), Rect2(b.position.x + 15, b.position.y + 9, 24, 24))
	BeFont.draw(self, Vector2(b.position.x + 15 + 24 + 10, b.position.y + (b.size.y - BeGeometry.LINE) / 2.0), text, BeTheme.t("000000"))
