class_name Win95TextArea
extends Control
## Win95 multi-line edit field (a sunken white box like Win95TextInput, any height) wrapping a flat
## TextEdit in the pixel font, with the Win95 scroll bar look left to the TextEdit's own bar. Enter
## starts a new line (the dialog router leaves Enter to it, see Win95Modal); Tab still moves focus.
## API: text (get/set), signal text_changed(text), focus_edit().

signal text_changed(text: String)

var edit: TextEdit
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit and edit.text != v:
			edit.text = v
var label := ""   ## &access label of the field's caption (for screen readers)


func _init() -> void:
	size = Vector2(200, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	edit = TextEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	var f := RetroFont.instance()
	edit.add_theme_font_override("font", f.font)
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_constant_override("line_spacing", 0)
	edit.add_theme_color_override("font_color", Win95Draw.TEXT)
	edit.add_theme_color_override("font_selected_color", Win95Draw.SELECTED_TEXT)
	edit.add_theme_color_override("selection_color", Win95Draw.SELECTED)
	edit.add_theme_color_override("caret_color", Win95Draw.TEXT)
	edit.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.highlight_current_line = false
	edit.scroll_smooth = false
	edit.text_changed.connect(func(): text_changed.emit(edit.text))
	add_child(edit)
	resized.connect(_layout)
	A11y.track(self)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_layout.call_deferred()


func _ready() -> void:
	_layout()
	if label != "":
		edit.accessibility_name = A11y.clean_caption(label)


func _layout() -> void:
	if edit == null:
		return
	edit.position = Vector2(5, 4)  # the text sits where Win95TextInput's does
	edit.size = Vector2(maxf(1.0, size.x - 8), maxf(1.0, size.y - 6))


func focus_edit() -> void:
	edit.grab_focus()


func _draw() -> void:
	Win95Draw.sunken(self, Rect2(Vector2.ZERO, size), Win95Draw.WINDOW)
