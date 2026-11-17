class_name StickyNote
extends Control
## A sticky note window for a note item (see Notes): a square of coloured paper with a title strip,
## a close box at the top left, the editable text, and a resize grip at the bottom right. Drag the
## strip to move it. Typing, moving and resizing are saved to the item quietly; closing it clears
## noteOpen. Every shell hosts these through ShellBase.open_note (in the layer note_layer() returns)
## and passes its own font through note_style().

signal closed(item_id: String)
## Right-click on the note: the hosting shell shows its own menu (ShellBase.show_note_menu).
signal context_requested(item_id: String, global_pos: Vector2)
## The note came to the front (clicked or focused), for taskbars and window lists.
signal activated(item_id: String)

## Smallest title strip; a larger font makes it taller (see title_h).
const TITLE_H := 13
const CLOSE := 7
const GRIP := 9
const SAVE_DELAY := 0.4

var item_id := ""
var font: Font
var font_size := 11
var text_color := Color.BLACK
var paper := Notes.COLORS[Notes.DEFAULT_COLOR]
var title := ""
## Height of the title strip for this note's font.
var title_h := TITLE_H

var _edit: TextEdit
var _save_timer: Timer
var _drag := ""  ## "", "move", "resize" or "close"
var _press_at := Vector2.ZERO
var _start := Rect2()
var _close_down := false


## `style`: {font: Font, font_size: int, text_color: Color} from the shell (all optional).
func _init(id: String = "", style: Dictionary = {}) -> void:
	item_id = id
	font = style.get("font", RetroFont.instance(RetroFont.WIN95).font)
	font_size = int(style.get("font_size", 11))
	text_color = style.get("text_color", Color.BLACK)
	title_h = maxi(TITLE_H, int(ceilf(font.get_height(font_size))) + 3)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("pm_auto")
	_edit = TextEdit.new()
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.caret_blink = false
	_edit.context_menu_enabled = false
	_edit.highlight_current_line = false
	_edit.scroll_smooth = false
	_edit.set_meta("auto_id", "note.text:" + id)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		_edit.add_theme_stylebox_override(s, empty)
	_edit.add_theme_font_override("font", font)
	_edit.add_theme_font_size_override("font_size", font_size)
	_edit.add_theme_constant_override("line_spacing", 1)
	_edit.text_changed.connect(_on_text_changed)
	_edit.focus_entered.connect(func():
		move_to_front()
		activated.emit(item_id))
	add_child(_edit)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(_save_text)
	add_child(_save_timer)
	resized.connect(_layout)


func _ready() -> void:
	ProgramStore.groups_changed.connect(_sync_from_store)
	ProgramStore.data_reloaded.connect(_sync_from_store)
	_sync_from_store(true)
	_layout()


func _exit_tree() -> void:
	if not _save_timer.is_stopped():
		_save_text()


## Puts the window at `r` (shell logical pixels, in the parent's space).
func place(r: Rect2i) -> void:
	position = Vector2(r.position)
	size = Vector2(r.size)


## Brings the note to the front and puts the caret after its text, so typing adds to the note.
func focus_text() -> void:
	move_to_front()
	activated.emit(item_id)
	_edit.grab_focus()
	var last := _edit.get_line_count() - 1
	_edit.set_caret_line(last)
	_edit.set_caret_column(_edit.get_line(last).length())


func text() -> String:
	return _edit.text


func set_text_for_test(t: String) -> void:
	_edit.text = t
	_on_text_changed()


## Saves anything typed and closes the window; the note's noteOpen becomes false.
func close() -> void:
	if not _save_timer.is_stopped():
		_save_text()
	ProgramStore.update_note_quietly(item_id, {"noteOpen": false})
	closed.emit(item_id)
	queue_free()


# ------------------------------------------------------------------ store

func _sync_from_store(first: bool = false) -> void:
	var loc := ProgramStore.locate_item(item_id)
	if loc.is_empty() or not Notes.is_note(loc.item):
		closed.emit(item_id)
		queue_free()  # the note was deleted (or the data was replaced)
		return
	var item: Dictionary = loc.item
	title = String(item.get("name", "Note"))
	paper = Notes.color_of(item)
	var stored := String(item.get("note", ""))
	if (first or not _edit.has_focus()) and _edit.text != stored:
		_edit.text = stored
	_apply_colors()
	queue_redraw()


func _on_text_changed() -> void:
	_save_timer.start()


func _save_text() -> void:
	_save_timer.stop()
	ProgramStore.update_note_quietly(item_id, {"note": Notes.clean_text(_edit.text)})


func _save_bounds() -> void:
	ProgramStore.update_note_quietly(item_id, {"noteBounds": Notes.bounds_dict(Rect2i(Rect2(position, size)))})


# ----------------------------------------------------------------- layout

func _apply_colors() -> void:
	_edit.add_theme_color_override("font_color", text_color)
	_edit.add_theme_color_override("font_readonly_color", text_color)
	_edit.add_theme_color_override("caret_color", text_color)
	_edit.add_theme_color_override("selection_color", paper.darkened(0.25))
	_edit.add_theme_color_override("font_selected_color", text_color)
	_edit.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	var bar := _edit.get_v_scroll_bar()
	var grab := StyleBoxFlat.new()
	grab.bg_color = paper.darkened(0.3)
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(s, grab)


func _layout() -> void:
	_edit.position = Vector2(3, title_h + 2)
	_edit.size = Vector2(maxf(8, size.x - 6), maxf(8, size.y - title_h - 3 - GRIP))


func _close_rect() -> Rect2:
	return Rect2(4, 3, CLOSE, CLOSE)


func _grip_rect() -> Rect2:
	return Rect2(size.x - GRIP - 1, size.y - GRIP - 1, GRIP, GRIP)


func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	var edge := paper.darkened(0.55)
	var strip := paper.darkened(0.1)
	Px.fill(self, 0, 0, w, h, paper)
	Px.fill(self, 0, 0, w, title_h, strip)
	Px.hline(self, 0, title_h, w, paper.darkened(0.3))
	Px.outline(self, Rect2(0, 0, w, h), edge)
	var cr := _close_rect()
	if _close_down:
		Px.fill_rect(self, cr, edge)
	Px.outline(self, cr, edge)
	var room := w - (cr.end.x + 6) * 2
	if room > 8 and font:
		var t := title
		while t.length() > 1 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			t = t.substr(0, t.length() - 2) + "…"
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var asc := font.get_ascent(font_size)
		draw_string(font, Vector2(floorf((w - tw) / 2.0), floorf((title_h - font.get_height(font_size)) / 2.0 + asc)),
			t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	var g := _grip_rect()
	for i in 3:
		var o := 2 + i * 3
		for k in g.size.x - o:
			Px.fill(self, g.end.x - 1 - k, g.position.y + o + k, 1, 1, edge)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		move_to_front()
		activated.emit(item_id)
		context_requested.emit(item_id, event.global_position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if event.pressed:
			move_to_front()
			activated.emit(item_id)
			_press_at = event.global_position
			_start = Rect2(position, size)
			if _close_rect().grow(2).has_point(p):
				_drag = "close"
				_close_down = true
			elif _grip_rect().grow(1).has_point(p):
				_drag = "resize"
			elif p.y <= title_h:
				_drag = "move"
			else:
				_edit.grab_focus()
			queue_redraw()
			accept_event()
		else:
			var was := _drag
			_drag = ""
			if was == "close":
				_close_down = false
				queue_redraw()
				if _close_rect().grow(2).has_point(p):
					close()
			elif was == "move" or was == "resize":
				_save_bounds()
			accept_event()
	elif event is InputEventMouseMotion and _drag != "":
		var d: Vector2 = (event.global_position - _press_at) / _global_scale()
		var area := _area()
		if _drag == "move":
			var np := (_start.position + d).round()
			np.x = clampf(np.x, area.position.x - size.x + 24, area.end.x - 24)
			np.y = clampf(np.y, area.position.y, area.end.y - title_h)
			position = np
		elif _drag == "resize":
			var ns := (_start.size + d).round()
			ns.x = clampf(ns.x, Notes.MIN_SIZE.x, maxf(Notes.MIN_SIZE.x, area.end.x - position.x))
			ns.y = clampf(ns.y, Notes.MIN_SIZE.y, maxf(Notes.MIN_SIZE.y, area.end.y - position.y))
			size = ns
		elif _drag == "close":
			var inside := _close_rect().grow(2).has_point(event.position)
			if inside != _close_down:
				_close_down = inside
				queue_redraw()
		accept_event()


func _global_scale() -> float:
	var s := get_global_transform().get_scale().x
	return s if s > 0 else 1.0


func _area() -> Rect2:
	var p := get_parent() as Control
	return Rect2(Vector2.ZERO, p.size) if p else Rect2(Vector2.ZERO, size)


## Automation: note:<id> (window), note.title:<id>, note.close:<id>, note.grip:<id>, note.text:<id>.
func auto_lookup(id: String) -> Variant:
	var gp := global_position
	if id == "note.text:" + item_id:
		return Rect2(gp + _edit.position, _edit.size)
	if id == "note:" + item_id:
		return Rect2(gp, size)
	if id == "note.title:" + item_id:
		return Rect2(gp + Vector2(_close_rect().end.x + 4, 1), Vector2(maxf(4, size.x - _close_rect().end.x - 8), title_h - 2))
	if id == "note.close:" + item_id:
		return Rect2(gp + _close_rect().position, _close_rect().size)
	if id == "note.grip:" + item_id:
		return Rect2(gp + _grip_rect().position, _grip_rect().size)
	return null
