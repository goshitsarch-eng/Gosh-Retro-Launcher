class_name BeField
extends Control
## Single-line text input: a flat LineEdit inside a 30px sunken field. Signals mirror LineEdit.

signal text_changed(text: String)
signal text_submitted(text: String)

var edit: LineEdit
var bold := false
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit:
			edit.text = v


static func make(p_text: String = "", p_id: String = "", p_bold: bool = false) -> BeField:
	var f := BeField.new()
	f.bold = p_bold
	f._build()
	f.text = p_text
	if p_id != "":
		BeUi.auto_id(f, p_id)
	return f


func _init() -> void:
	custom_minimum_size = Vector2(80, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build() -> void:
	if edit != null:
		return
	edit = LineEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	edit.add_theme_font_override("font", BeFont.font(bold))
	edit.add_theme_font_size_override("font_size", BeGeometry.FONT)
	edit.add_theme_color_override("font_color", BeTheme.t("000000"))
	edit.add_theme_color_override("font_selected_color", BeTheme.t("000000"))
	edit.add_theme_color_override("selection_color", BeTheme.b("a8a8a8"))
	edit.add_theme_color_override("caret_color", BeTheme.t("000000"))
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.text_changed.connect(func(t): text_changed.emit(t))
	edit.text_submitted.connect(func(t): text_submitted.emit(t))
	add_child(edit)
	resized.connect(_layout)
	_layout()


func _ready() -> void:
	_build()
	_layout()


func _layout() -> void:
	if edit:
		edit.position = Vector2(8, 3)
		edit.size = Vector2(maxf(1.0, size.x - 16), size.y - 6)


func grab_text_focus(select_all: bool = true) -> void:
	edit.grab_focus()
	if select_all:
		edit.select_all()


func _draw() -> void:
	BeDraw.field(self, Rect2(Vector2.ZERO, size))
