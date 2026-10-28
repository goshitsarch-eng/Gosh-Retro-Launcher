class_name Win95TextInput
extends Control
## Win95 single-line text field (21px tall sunken field) wrapping a flat LineEdit that uses the
## pixel font. Static chrome is deterministic; caret/selection/IME stay native (as in the original).
## API: text (get/set), signals text_changed(text) / text_submitted(text), grab_focus().

signal text_changed(text: String)
signal text_submitted(text: String)

var edit: LineEdit
var text: String:
	get:
		return edit.text if edit else ""
	set(v):
		if edit:
			edit.text = v
var disabled := false:
	set(v):
		disabled = v
		if edit:
			edit.editable = not v
		queue_redraw()
var label := ""   ## &access label of the field's caption (for Alt+key focus)


func _init() -> void:
	size = Vector2(150, 21)
	custom_minimum_size = Vector2(0, 21)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	edit = LineEdit.new()
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(s, empty)
	var f := RetroFont.instance()
	edit.add_theme_font_override("font", f.font)
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_color_override("font_color", Win95Draw.TEXT)
	edit.add_theme_color_override("font_selected_color", Win95Draw.SELECTED_TEXT)
	edit.add_theme_color_override("selection_color", Win95Draw.SELECTED)
	edit.add_theme_color_override("caret_color", Win95Draw.TEXT)
	edit.add_theme_color_override("font_uneditable_color", Win95Draw.DISABLED)
	edit.caret_blink = false
	edit.context_menu_enabled = false
	edit.text_changed.connect(func(t): text_changed.emit(t))
	edit.text_submitted.connect(func(t): text_submitted.emit(t))
	edit.focus_entered.connect(queue_redraw)
	edit.focus_exited.connect(queue_redraw)
	add_child(edit)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	edit.position = Vector2(5, 3)
	edit.size = Vector2(maxf(1.0, size.x - 10), 15)


func focus_edit() -> void:
	edit.grab_focus()


func has_text_focus() -> bool:
	return edit.has_focus()


func _draw() -> void:
	Win95Draw.sunken(self, Rect2(Vector2.ZERO, size), Win95Draw.FACE if disabled else Win95Draw.WINDOW)
