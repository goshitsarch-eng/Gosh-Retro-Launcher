extends Control
var font: FontFile
var bold: FontFile

func _ready() -> void:
	font = FontFile.new()
	font.load_dynamic_font("res://assets/fonts/win95/Win95Sans.woff2")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.force_autohinter = false
	bold = FontFile.new()
	bold.load_dynamic_font("res://assets/fonts/win95/Win95Sans-Bold.woff2")
	bold.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	bold.hinting = TextServer.HINTING_NONE
	bold.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var scale := 2
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scale = int(args[0])
	var win := get_window()
	win.size = Vector2i(640, 480) * scale
	win.content_scale_factor = float(scale)
	await get_tree().process_frame
	await get_tree().process_frame
	print("window size ", win.size, " visible rect ", get_viewport().get_visible_rect().size, " factor ", win.content_scale_factor, " mode ", win.content_scale_mode)
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	print("img ", img.get_size())
	img.save_png("/repo/exp/out_%d.png" % scale)
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 480), Color("#008080"))
	draw_rect(Rect2(10, 10, 100, 40), Color("#c0c0c0"))
	draw_rect(Rect2(10, 10, 100, 1), Color.WHITE)
	var x := 12.0
	for ch in "Programs Documents Settings 0123456789":
		draw_char(font, Vector2(x, 24), ch, 11, Color.BLACK)
		x += font.get_char_size(ch.unicode_at(0), 11).x
	x = 12.0
	for ch in "Programs Documents Bold":
		draw_char(bold, Vector2(x, 40), ch, 11, Color.BLACK)
		x += bold.get_char_size(ch.unicode_at(0), 11).x
	draw_string(font, Vector2(12, 70), "draw_string Programs", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
