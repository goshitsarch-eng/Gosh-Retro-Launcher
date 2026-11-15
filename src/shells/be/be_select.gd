class_name BeSelect
extends Control
## Drop-down select (30px, rounded gradient face with a caret). `options` = [[value, label], ...].
## The list opens as a BePopup in the shell's popup layer.

signal changed(value: String)

var options: Array = []
var value := ""
var min_width := 0.0


static func make(p_options: Array, p_value: String, p_id: String = "", p_min_width: float = 0.0) -> BeSelect:
	var s := BeSelect.new()
	s.options = p_options
	s.value = p_value
	s.min_width = p_min_width
	s.refresh_size()
	if p_id != "":
		BeUi.auto_id(s, p_id)
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func label_of(v: String) -> String:
	for o in options:
		if String(o[0]) == v:
			return String(o[1])
	return ""


func refresh_size() -> void:
	var w := min_width
	for o in options:
		w = maxf(w, BeFont.width(String(o[1])) + 8 + 26)
	custom_minimum_size = Vector2(w, 30)
	queue_redraw()


func set_value(v: String) -> void:
	value = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var rows := []
		for o in options:
			rows.append({"label": String(o[1]), "value": String(o[0]), "dot": String(o[0]) == value})
		var gr := get_global_rect()
		var p := BePopup.open(BeUi.popup_layer, rows, Vector2(gr.position.x, gr.end.y), {
			"min_w": gr.size.x, "pad_left": 26.0, "anchor": gr})
		p.picked.connect(func(row):
			value = String(row.value)
			queue_redraw()
			changed.emit(value))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	BeDraw.button_face(self, r, BeTheme.b("fafafa"), BeTheme.b("d4d4d4"), BeTheme.b("6a6a6a"))
	BeFont.draw(self, Vector2(8, (size.y - BeGeometry.LINE) / 2.0), BeFont.clip(label_of(value), size.x - 36), BeTheme.t("000000"))
	BeDraw.caret_down(self, size.x - 17, 13, BeTheme.b("000000"))
