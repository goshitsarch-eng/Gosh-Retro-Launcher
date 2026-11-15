class_name MacLabel
extends Control
## Static (optionally wrapped) text for dialogs. MacLabel.make(text, {wrap: px, bold, color, align}).

var text := ""
var bold := false
var color_hex := "000000"
var lines := PackedStringArray()
var align_right := false


static func make(p_text: String, opts: Dictionary = {}) -> MacLabel:
	var l := MacLabel.new()
	l.text = p_text
	l.bold = opts.get("bold", false)
	l.color_hex = String(opts.get("color", "000000"))
	l.align_right = opts.get("align_right", false)
	var wrap_w := int(opts.get("wrap", 0))
	if wrap_w > 0:
		l.lines = MacDraw.font().wrap(MacDraw.glyph_safe(p_text).replace("&", "&&"), wrap_w, l.bold)
	else:
		l.lines = PackedStringArray([p_text])
	var w := 0
	for ln in l.lines:
		w = maxi(w, MacDraw.measure(ln, l.bold))
	l.size = Vector2(w, l.lines.size() * RetroFont.LABEL_LINE_HEIGHT)
	return l


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	for i in lines.size():
		var x := 0.0
		if align_right:
			x = size.x - MacDraw.measure(lines[i], bold)
		MacDraw.text(self, Vector2(x, i * RetroFont.LABEL_LINE_HEIGHT), lines[i], MacTheme.t(color_hex), bold)
