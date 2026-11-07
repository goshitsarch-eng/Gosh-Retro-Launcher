class_name Win95DifferenceLayer
extends Control
## Draws white dotted rectangles with `mix-blend-mode: difference` (marquee selection, Move/Size
## outline). Godot has no difference blend, so the layer uses a canvas shader that inverts the
## already-rendered backdrop under every drawn pixel.
##   layer.set_rects([{"rect": Rect2, "thickness": 1}])   # in this layer's local coordinates

static var _shader: Shader

var rects: Array = []


static func difference_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_nearest;\nvoid fragment() {\n\tvec3 backdrop = texture(screen_tex, SCREEN_UV).rgb;\n\tCOLOR = vec4(abs(backdrop - COLOR.rgb), COLOR.a);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	material = difference_material()
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_rects(p_rects: Array) -> void:
	rects = p_rects
	queue_redraw()


func _draw() -> void:
	for entry in rects:
		var r: Rect2 = entry.rect
		var t: int = entry.get("thickness", 1)
		_dotted(r, t)


## Dotted border: `t`-pixel dots with `t`-pixel gaps starting at each side's origin corner.
func _dotted(r: Rect2, t: int) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	if w < 1 or h < 1:
		return
	var step := t * 2
	var x := 0.0
	while x < w:
		var run := minf(t, w - x)
		draw_rect(Rect2(x0 + x, y0, run, t), Color.WHITE)
		draw_rect(Rect2(x0 + x, y0 + h - t, run, t), Color.WHITE)
		x += step
	var y := float(t + 1)
	while y < h:
		var run := minf(t, h - y)
		draw_rect(Rect2(x0, y0 + y, t, run), Color.WHITE)
		draw_rect(Rect2(x0 + w - t, y0 + y, t, run), Color.WHITE)
		y += step
