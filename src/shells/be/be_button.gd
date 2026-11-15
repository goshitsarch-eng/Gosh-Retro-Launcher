class_name BeButton
extends Control
## Push button: 4px-radius gradient face, 1px border, optional default ring. Emits `pressed`.

signal pressed

var label := "":
	set(v):
		label = v
		_update()
var is_default := false:
	set(v):
		is_default = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var min_width := 86.0
var _down := false
var _hover := false


static func make(p_label: String, p_default: bool = false, p_id: String = "") -> BeButton:
	var b := BeButton.new()
	b.label = p_label
	b.is_default = p_default
	if p_id != "":
		BeUi.auto_id(b, p_id)
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _update() -> void:
	custom_minimum_size = Vector2(maxf(min_width, BeFont.width(label) + 28), 30)
	size = custom_minimum_size
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			grab_focus()
		else:
			var was := _down
			_down = false
			if was and Rect2(Vector2.ZERO, size).has_point(mb.position):
				pressed.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed and has_focus():
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			pressed.emit()
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var top := BeTheme.b("c4c4c4") if _down else BeTheme.b("fafafa")
	var bottom := BeTheme.b("e8e8e8") if _down else BeTheme.b("d4d4d4")
	if is_default:
		BeDraw.default_ring(self, r, BeTheme.s("d8d8d8"), BeTheme.s("6a6a6a"))
	BeDraw.button_face(self, r, top, bottom, BeTheme.b("6a6a6a"))
	var col := BeTheme.t("808080") if disabled else BeTheme.t("000000")
	BeFont.draw_centered(self, size.x / 2.0, (size.y - BeGeometry.LINE) / 2.0, label, col)
	if has_focus() and not _down and not is_default:
		Px.focus_rect(self, r.grow(-4), BeTheme.t("808080"))
