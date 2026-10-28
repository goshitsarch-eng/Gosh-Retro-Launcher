class_name W31TextField
extends W31Widget
## `.win31-input`: black 1px frame + grey inset line, white fill, 3px side padding. Editing is
## delegated to a flat, transparent LineEdit/TextEdit that uses the 1-bit WfWSans strike.
## `multiline` gives the Environment textarea (13px rows).

signal text_changed(text: String)
signal text_submitted(text: String)

var multiline := false
var edit: Control  ## LineEdit or TextEdit
var read_only := false:
	set(v):
		read_only = v
		edit.editable = not v
var text: String:
	get:
		return edit.text
	set(v):
		edit.text = v
		if edit is LineEdit:
			edit.caret_column = v.length()
var placeholder_text: String:
	get:
		return edit.placeholder_text
	set(v):
		edit.placeholder_text = v


func _init(p_multiline: bool = false) -> void:
	multiline = p_multiline
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	var font := W31.font().font
	var empty := StyleBoxEmpty.new()
	if multiline:
		var te := TextEdit.new()
		edit = te
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.scroll_smooth = false
		te.context_menu_enabled = false
		te.highlight_current_line = false
		te.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
		te.add_theme_color_override("background_color", Color(0, 0, 0, 0))
		var fh := int(roundf(font.get_height(11)))
		te.add_theme_constant_override("line_spacing", 13 - fh)
		te.text_changed.connect(func(): text_changed.emit(te.text))
	else:
		var le := LineEdit.new()
		edit = le
		le.context_menu_enabled = false
		le.caret_blink = not Engine.has_meta("pm_capture")
		le.select_all_on_focus = false
		le.text_changed.connect(func(t: String): text_changed.emit(t))
		le.text_submitted.connect(func(t: String): text_submitted.emit(t))
		le.add_theme_color_override("font_uneditable_color", W31.BLACK)
		le.add_theme_color_override("font_placeholder_color", W31.SHADOW)
		le.add_theme_color_override("clear_button_color", W31.BLACK)
	for sb in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(sb, empty)
	edit.add_theme_font_override("font", font)
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_color_override("font_color", W31.BLACK)
	edit.add_theme_color_override("font_selected_color", W31.WHITE)
	edit.add_theme_color_override("selection_color", W31.NAVY)
	edit.add_theme_color_override("caret_color", W31.BLACK)
	edit.add_theme_color_override("font_placeholder_color", W31.SHADOW)
	edit.add_theme_constant_override("caret_width", 1)
	edit.focus_mode = Control.FOCUS_ALL
	add_child(edit)


func set_field_size(w: int, h: int) -> void:
	size = Vector2(w, h)
	custom_minimum_size = size
	if multiline:
		edit.position = Vector2(4, 2)
		edit.size = Vector2(w - 8, h - 4)
	else:
		edit.position = Vector2(4, 2)
		edit.size = Vector2(w - 8, h - 4)


func focus_target() -> Control:
	return edit


func is_tab_stop() -> bool:
	return is_visible_in_tree() and edit.focus_mode != Control.FOCUS_NONE


func activate_access_key() -> void:
	edit.grab_focus()


## Browser behaviour: focus via Tab selects the whole value.
func focus_select_all() -> void:
	edit.grab_focus()
	if edit is LineEdit:
		edit.select_all()
	elif edit is TextEdit:
		edit.select_all()


func focus_at_end() -> void:
	edit.grab_focus()
	if edit is LineEdit:
		edit.caret_column = edit.text.length()
	elif edit is TextEdit:
		edit.set_caret_line(edit.get_line_count() - 1)
		edit.set_caret_column(edit.get_line(edit.get_line_count() - 1).length())


func _draw() -> void:
	W31.sunken_field(self, Rect2(Vector2.ZERO, size))
