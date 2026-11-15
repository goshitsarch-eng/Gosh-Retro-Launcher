class_name MacTextField
extends Control
## Single-line text field: design frame (1px #444, inset #999) around a flat LineEdit using the pixel font.

signal text_changed(text: String)
signal text_submitted(text: String)

var edit: LineEdit
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit:
			edit.text = v
var bold := false


func _init(p_auto_id: String = "") -> void:
	size = Vector2(150, 22)
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	edit = LineEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	var f := RetroFont.instance()
	edit.add_theme_font_override("font", f.font)
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_color_override("font_color", MacTheme.t("000000"))
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("selection_color", MacTheme.b("33339a"))
	edit.add_theme_color_override("caret_color", MacTheme.t("000000"))
	edit.add_theme_color_override("font_uneditable_color", MacTheme.t("999999"))
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.text_changed.connect(func(t): text_changed.emit(t))
	edit.text_submitted.connect(func(t): text_submitted.emit(t))
	add_child(edit)
	resized.connect(_layout_edit)
	add_to_group("pm_auto")
	if p_auto_id != "":
		set_meta("auto_id", p_auto_id)
	_layout_edit()


func _layout_edit() -> void:
	edit.position = Vector2(5, 3)
	edit.size = Vector2(maxf(1.0, size.x - 10), 16)


func set_editable(on: bool) -> void:
	edit.editable = on
	queue_redraw()


func focus_edit() -> void:
	edit.grab_focus()


func _draw() -> void:
	MacDraw.field(self, Rect2(Vector2.ZERO, size))
