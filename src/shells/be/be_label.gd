class_name BeLabel
extends Control
## Static text. With `wrap_w` > 0 the text wraps to that width; the control reports its natural size as minimum size.

var text := "":
	set(v):
		text = v
		_update()
var bold := false:
	set(v):
		bold = v
		_update()
var tone := "000000"       ## text-namespace hex of the colour
var font_size := BeGeometry.FONT
var wrap_w := 0.0:
	set(v):
		wrap_w = v
		_update()
var align_right := false
var _lines := PackedStringArray()


static func make(p_text: String, p_bold: bool = false, p_wrap: float = 0.0, p_tone: String = "000000") -> BeLabel:
	var l := BeLabel.new()
	l.tone = p_tone
	l.bold = p_bold
	l.wrap_w = p_wrap
	l.text = p_text
	return l


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update() -> void:
	if wrap_w > 0.0:
		_lines = BeFont.wrap(text, wrap_w, font_size, bold)
	else:
		_lines = PackedStringArray([text])
	var w := 0.0
	for l in _lines:
		w = maxf(w, BeFont.width(l, font_size, bold))
	custom_minimum_size = Vector2(w, _lines.size() * BeGeometry.LINE)
	queue_redraw()


func _draw() -> void:
	var col := BeTheme.t(tone)
	for i in _lines.size():
		var w := BeFont.width(_lines[i], font_size, bold)
		var x := size.x - w if align_right else 0.0
		BeFont.draw(self, Vector2(x, i * BeGeometry.LINE), _lines[i], col, font_size, bold)
