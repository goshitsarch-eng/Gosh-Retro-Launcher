class_name Win95Label
extends Control
## Static Win95 text (RTM bitmap-style) with optional wrapping, bold, colour and disabled look.
##   var l := Win95Label.make("&Open:", Vector2(9, 57))            # single line, access underline
##   var l := Win95Label.make("long text", pos, {"wrap": 265})     # wrapped to 265 px
## opts: wrap (max width, 0 = none), bold, color, disabled, show_access, max_width (clip).
## The control sizes itself to the text; mouse input passes through.

var text := "":
	set(v):
		text = v
		_fit()
var wrap_width := 0
var bold := false
var color := Win95Draw.TEXT
var disabled := false
var show_access := true
var max_width := 0


static func make(p_text: String, pos: Vector2, opts: Dictionary = {}) -> Win95Label:
	var l := Win95Label.new()
	l.wrap_width = int(opts.get("wrap", 0))
	l.bold = bool(opts.get("bold", false))
	l.color = opts.get("color", Win95Draw.TEXT)
	l.disabled = bool(opts.get("disabled", false))
	l.show_access = bool(opts.get("show_access", true))
	l.max_width = int(opts.get("max_width", 0))
	l.position = pos
	l.text = p_text
	return l


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func access_key() -> String:
	return String(RetroFont.parse_access(text).accessKey)


func _fit() -> void:
	var f := Win95Draw.font()
	if wrap_width > 0:
		var lines := f.wrap(text, wrap_width, bold)
		var w := 1
		for l in lines:
			w = maxi(w, f.measure(l, bold))
		size = Vector2(w, maxi(13, lines.size() * 13))
	else:
		var w2 := f.measure(text, bold)
		if max_width > 0:
			w2 = mini(w2, max_width)
		size = Vector2(maxi(1, w2), 13)
	queue_redraw()


func _draw() -> void:
	var opts := {"bold": bold, "disabled": disabled, "show_access": show_access}
	if wrap_width > 0:
		opts["wrap"] = true
		opts["max_width"] = wrap_width
	elif max_width > 0:
		opts["max_width"] = max_width
	Win95Draw.text(self, Vector2.ZERO, text, color, opts)
