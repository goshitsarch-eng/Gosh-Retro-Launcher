class_name MacToast
extends Control
## Launch feedback toast ("Starting <name>..."): panel with the launcher logo at top-centre, auto-hides.

const HIDE_SECONDS := 1.8

var text := ""
var _timer: Timer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HIDE_SECONDS
	_timer.timeout.connect(func():
		visible = false)
	add_child(_timer)
	add_to_group("pm_auto")


func show_text(t: String) -> void:
	text = t
	visible = true
	queue_redraw()
	_timer.start()


func _draw() -> void:
	if text == "":
		return
	var w := 16 + 16 + 10 + MacDraw.measure(text) + 16
	var r := Rect2(floorf((size.x - w) / 2.0), 40, w, 34)
	MacDraw.panel(self, r, 0.3, true)
	draw_texture_rect(MacIconCatalog.logo("small"), Rect2(r.position.x + 16, r.position.y + 9, 16, 16), false)
	MacDraw.text_centered_y(self, r.position.x + 16 + 16 + 10, r.position.y, r.size.y, text, MacTheme.t("000000"))


func auto_lookup(id: String) -> Variant:
	if id == "mac.toast" and visible:
		var w := 16 + 16 + 10 + MacDraw.measure(text) + 16
		return Rect2(global_position + Vector2(floorf((size.x - w) / 2.0), 40), Vector2(w, 34))
	return null
