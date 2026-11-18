class_name MacTextArea
extends Control
## Multi-line text box (the New Note… text): the design's field frame (1px #444, inset #999) around a flat,
## word-wrapping TextEdit in the pixel font. Return types a new line; the dialog's own Return handling is
## skipped while the box has focus (see MacDialogs.new_note).

var edit: TextEdit
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit:
			edit.text = v


func _init(p_auto_id: String = "") -> void:
	size = Vector2(150, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	edit = TextEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	edit.add_theme_font_override("font", RetroFont.instance().font)
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_constant_override("line_spacing", 1)
	edit.add_theme_color_override("font_color", MacTheme.t("000000"))
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("selection_color", MacTheme.b("33339a"))
	edit.add_theme_color_override("caret_color", MacTheme.t("000000"))
	edit.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.highlight_current_line = false
	edit.scroll_smooth = false
	# a plain grey thumb instead of Godot's own scroll bar look
	var bar := edit.get_v_scroll_bar()
	var grab := StyleBoxFlat.new()
	grab.bg_color = MacTheme.b("888888")
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(s, grab)
	add_child(edit)
	resized.connect(_layout_edit)
	add_to_group("pm_auto")
	if p_auto_id != "":
		set_meta("auto_id", p_auto_id)
	_layout_edit()


func _layout_edit() -> void:
	edit.position = Vector2(4, 3)
	edit.size = Vector2(maxf(1.0, size.x - 8), maxf(1.0, size.y - 6))


func focus_edit() -> void:
	edit.grab_focus()


func has_text_focus() -> bool:
	return edit.has_focus()


## Return inside the box: a new line at the caret (the dialog would otherwise press its default button).
func insert_newline() -> void:
	edit.insert_text_at_caret("\n")


func _draw() -> void:
	MacDraw.field(self, Rect2(Vector2.ZERO, size))
