class_name BeTextBox
extends Control
## Multi-line text input: a flat TextEdit inside the same sunken frame as BeField (New Note… text).
## Enter types a new line here; BeDialog leaves Enter to it while it has the focus.

signal text_changed(text: String)

var edit: TextEdit
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit:
			edit.text = v


static func make(p_text: String = "", p_id: String = "", p_height: float = 84.0) -> BeTextBox:
	var b := BeTextBox.new()
	b.custom_minimum_size = Vector2(80, p_height)
	b._build()
	b.text = p_text
	if p_id != "":
		BeUi.auto_id(b, p_id)
	return b


func _init() -> void:
	custom_minimum_size = Vector2(80, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build() -> void:
	if edit != null:
		return
	edit = TextEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	edit.add_theme_font_override("font", BeFont.font())
	edit.add_theme_font_size_override("font_size", BeGeometry.FONT)
	edit.add_theme_color_override("font_color", BeTheme.t("000000"))
	edit.add_theme_color_override("font_selected_color", BeTheme.t("000000"))
	edit.add_theme_color_override("selection_color", BeTheme.b("a8a8a8"))
	edit.add_theme_color_override("caret_color", BeTheme.t("000000"))
	edit.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	edit.add_theme_constant_override("line_spacing", 1)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.highlight_current_line = false
	edit.scroll_smooth = false
	edit.text_changed.connect(func(): text_changed.emit(edit.text))
	add_child(edit)
	resized.connect(_layout)
	_layout()


func _ready() -> void:
	_build()
	_layout()


func _layout() -> void:
	if edit:
		edit.position = Vector2(4, 3)
		edit.size = Vector2(maxf(1.0, size.x - 8), maxf(1.0, size.y - 6))


func grab_text_focus() -> void:
	edit.grab_focus()


func _draw() -> void:
	BeDraw.field(self, Rect2(Vector2.ZERO, size))
