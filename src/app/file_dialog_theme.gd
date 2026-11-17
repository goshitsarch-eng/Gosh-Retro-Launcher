class_name FileDialogTheme
extends RefCounted
## Theme for Godot's own FileDialog, used when the system has no native file chooser (Linux without
## the desktop portal). Instead of Godot's dark editor look it uses the active desktop's font and a
## flat, light retro palette, so the chooser reads as part of the launcher. Platform shows the dialog
## embedded in the launcher window and sized to fit it.

## Win95-style grey, the default for every desktop (ShellBase.file_dialog_palette()).
const DEFAULT_PALETTE := {
	"face": Color8(192, 192, 192),
	"light": Color8(255, 255, 255),
	"shadow": Color8(128, 128, 128),
	"dark": Color8(0, 0, 0),
	"field": Color8(255, 255, 255),
	"text": Color8(0, 0, 0),
	"disabled": Color8(128, 128, 128),
	"select": Color8(0, 0, 128),
	"select_text": Color8(255, 255, 255),
	"title": Color8(0, 0, 128),
	"title_text": Color8(255, 255, 255),
}


## `style` is a shell's note_style() ({font, font_size}); `palette` overrides DEFAULT_PALETTE keys.
static func make(style: Dictionary = {}, palette: Dictionary = {}) -> Theme:
	var p := DEFAULT_PALETTE.duplicate()
	p.merge(palette, true)
	var t := Theme.new()
	var font: Font = style.get("font", RetroFont.instance(RetroFont.WIN95).font)
	var size := int(style.get("font_size", 11))
	t.default_font = font
	t.default_font_size = size

	var face := _flat(p.face, p.face, 0)
	var raised := _bevel(p.face, p.light, p.dark, 4, 2)
	var sunken := _bevel(p.field, p.shadow, p.light, 3, 2)
	var pressed := _bevel(p.face, p.dark, p.light, 4, 2)
	var focus := _flat(Color(0, 0, 0, 0), p.dark, 1, 0)
	focus.draw_center = false

	# Window frame (embedded): a plain title bar in the palette's caption colours.
	t.set_stylebox("embedded_border", "Window", _title_frame(p.title, p.dark))
	t.set_stylebox("embedded_unfocused_border", "Window", _title_frame(p.shadow, p.dark))
	t.set_color("title_color", "Window", p.title_text)
	t.set_color("title_outline_modulate", "Window", Color(0, 0, 0, 0))
	t.set_constant("title_height", "Window", 18)
	t.set_font_size("title_font_size", "Window", size)
	t.set_font("title_font", "Window", font)
	var close := _close_icon(p.title_text)
	t.set_icon("close", "Window", close)
	t.set_icon("close_pressed", "Window", close)
	t.set_constant("close_h_offset", "Window", 14)
	t.set_constant("close_v_offset", "Window", 13)
	t.set_stylebox("panel", "AcceptDialog", face)
	t.set_stylebox("panel", "FileDialog", face)
	t.set_stylebox("panel", "Panel", face)
	t.set_stylebox("panel", "PanelContainer", face)

	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, raised)
		t.set_stylebox("hover", type, raised)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, raised)
		t.set_stylebox("focus", type, focus)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, p.text)
		t.set_color("font_disabled_color", type, p.disabled)
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			t.set_color(c, type, p.text)
	for type in ["CheckBox", "CheckButton"]:
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(s, type, _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
		t.set_stylebox("focus", type, focus)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, p.text)

	t.set_stylebox("normal", "LineEdit", sunken)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", sunken)
	t.set_color("font_color", "LineEdit", p.text)
	t.set_color("font_uneditable_color", "LineEdit", p.disabled)
	t.set_color("font_placeholder_color", "LineEdit", p.disabled)
	t.set_color("caret_color", "LineEdit", p.text)
	t.set_color("selection_color", "LineEdit", p.select)
	t.set_color("font_selected_color", "LineEdit", p.select_text)
	t.set_color("clear_button_color", "LineEdit", p.text)

	for type in ["Tree", "ItemList"]:
		t.set_stylebox("panel", type, sunken)
		t.set_stylebox("focus", type, focus)
		var sel := _flat(p.select, p.select, 0, 0)
		t.set_stylebox("selected", type, sel)
		t.set_stylebox("selected_focus", type, sel)
		t.set_stylebox("cursor", type, focus)
		t.set_stylebox("cursor_unfocused", type, focus)
		t.set_stylebox("hovered", type, _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
		t.set_color("font_color", type, p.text)
		t.set_color("font_selected_color", type, p.select_text)
		t.set_color("font_hovered_color", type, p.text)
		t.set_color("guide_color", type, Color(0, 0, 0, 0))
		t.set_constant("v_separation", type, 1)
		t.set_constant("vseparation", type, 1)
	t.set_stylebox("title_button_normal", "Tree", raised)
	t.set_stylebox("title_button_hover", "Tree", raised)
	t.set_stylebox("title_button_pressed", "Tree", pressed)
	t.set_color("title_button_color", "Tree", p.text)

	for type in ["Label"]:
		t.set_color("font_color", type, p.text)
	t.set_stylebox("panel", "PopupMenu", _bevel(p.field, p.light, p.dark, 2, 2))
	t.set_stylebox("hover", "PopupMenu", _flat(p.select, p.select, 0, 0))
	t.set_color("font_color", "PopupMenu", p.text)
	t.set_color("font_hover_color", "PopupMenu", p.select_text)
	t.set_color("font_disabled_color", "PopupMenu", p.disabled)
	t.set_color("font_separator_color", "PopupMenu", p.text)

	var track := _flat(p.face.lightened(0.35), p.face.lightened(0.35), 0, 0)
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, raised)
		t.set_stylebox("grabber_highlight", type, raised)
		t.set_stylebox("grabber_pressed", type, pressed)
	t.set_stylebox("separator", "HSeparator", _flat(p.shadow, p.shadow, 0, 0))
	t.set_stylebox("separator", "VSeparator", _flat(p.shadow, p.shadow, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", _flat(Color8(255, 255, 225), p.dark, 1, 2))
	t.set_color("font_color", "TooltipLabel", p.text)
	return t


static func _flat(bg: Color, border: Color, width: int, margin: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


## A one-pixel bevel as a 9-slice texture: `tl` on the top and left edges, `br` on the bottom and
## right, `bg` inside (StyleBoxFlat has a single border colour, so it cannot draw a bevel).
static func _bevel(bg: Color, tl: Color, br: Color, margin_x: int, margin_y: int) -> StyleBox:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in 3:
		img.set_pixel(i, 0, tl)
		img.set_pixel(0, i, tl)
		img.set_pixel(i, 2, br)
		img.set_pixel(2, i, br)
	img.set_pixel(2, 0, br)
	img.set_pixel(0, 2, br)
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.texture_margin_left = 1
	s.texture_margin_top = 1
	s.texture_margin_right = 1
	s.texture_margin_bottom = 1
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	s.content_margin_top = margin_y
	s.content_margin_bottom = margin_y
	return s


## A 7x7 one-pixel X in the caption text colour (Godot's own is a large white glyph).
static func _close_icon(color: Color) -> Texture2D:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 7:
		img.set_pixel(i, i, color)
		img.set_pixel(6 - i, i, color)
	return ImageTexture.create_from_image(img)


static func _title_frame(caption: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = caption
	s.border_color = border
	s.set_border_width_all(1)
	s.expand_margin_top = 18
	s.expand_margin_left = 1
	s.expand_margin_right = 1
	s.expand_margin_bottom = 1
	s.anti_aliasing = false
	return s
