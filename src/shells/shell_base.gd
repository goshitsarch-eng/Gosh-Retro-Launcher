class_name ShellBase
extends Control
## Contract between the app host and a desktop shell (Win31/WfW or Win95).
## A shell fills the window's *logical* area (the host applies the integer content scale),
## owns all of its dialogs/menus/windows, and talks to the model only through the
## ProgramStore / UIState / MdiState autoloads.

signal request_quit
signal request_hide_window      ## minimize-to-tray / hide
signal request_minimize_window
signal request_maximize_window
signal request_show_launcher_tools
signal request_switch_shell(shell: String)
## A sticky note window was opened or closed (taskbars and window lists refresh).
signal notes_changed

var host: Node  ## the app host (src/app/main.gd); set before the shell enters the tree


func shell_id() -> String:
	return ""


## Called after the store has loaded and the shell is in the tree.
func on_activate() -> void:
	pass


## Global Quick Search / Win95 Find toggle (tray menu, in-app shortcut).
func toggle_quick_search() -> void:
	pass


## Files dragged from the OS file manager. `logical_pos` is in shell logical pixels.
func on_files_dropped(_files: PackedStringArray, _logical_pos: Vector2) -> void:
	pass


## Window geometry changed (focus/maximize/minimize/resize/display metrics).
func on_host_state_changed(_state: Dictionary) -> void:
	pass


## Whole-UI scale preference changed or the display changed. `factor` is the integer scale.
func on_scale_changed(_factor: int) -> void:
	pass


# ------------------------------------------------------------- sticky notes
# Notes (see Notes) open as StickyNote windows. A shell overrides note_layer() to put them in the
# right layer (above its windows, below its menus and dialogs) and note_style() to use its font.

## Colours for Godot's own file chooser (the fallback when the system has none), drawn with this
## shell's note_style() font. Keys as FileDialogTheme.DEFAULT_PALETTE; {} keeps the Win95 grey.
func file_dialog_palette() -> Dictionary:
	return {}


## The Control the note windows go in; it should cover the desktop area.
func note_layer() -> Control:
	return self


## {font: Font, font_size: int, text_color: Color} for the note windows.
func note_style() -> Dictionary:
	return {}


func open_notes() -> Array:
	var out := []
	var layer := note_layer()
	if layer:
		for c in layer.get_children():
			if c is StickyNote and not c.is_queued_for_deletion():
				out.append(c)
	return out


## Shows note `item_id` (or brings its open window to the front) and returns the window, or null
## when there is no such note. `focus` puts the caret in it.
func open_note(item_id: String, focus: bool = true) -> StickyNote:
	for n in open_notes():
		if n.item_id == item_id:
			if focus:
				n.focus_text()
			return n
	var loc := ProgramStore.locate_item(item_id)
	var layer := note_layer()
	if loc.is_empty() or not Notes.is_note(loc.item) or layer == null:
		return null
	var index := open_notes().size()
	var n := StickyNote.new(item_id, note_style())
	n.context_requested.connect(show_note_menu)
	n.closed.connect(func(_id): notes_changed.emit.call_deferred())
	layer.add_child(n)
	n.place(Notes.window_rect(loc.item, Rect2i(Vector2i.ZERO, Vector2i(layer.size)), index))
	ProgramStore.update_note_quietly(item_id, {"noteOpen": true})
	notes_changed.emit()
	if focus:
		n.focus_text.call_deferred()
	return n


## The open window of note `item_id`, or null.
func note_window(item_id: String) -> StickyNote:
	for n in open_notes():
		if n.item_id == item_id:
			return n
	return null


## Closes note `item_id`'s window if it is open (its text is saved first).
func close_note(item_id: String) -> void:
	var n := note_window(item_id)
	if n:
		n.close()


## Right-click on an open note. Shells show their own menu here (Close, Properties, Delete...);
## `global_pos` is where the click was.
func show_note_menu(_item_id: String, _global_pos: Vector2) -> void:
	pass


## Reopens every note that was open when the program last ran (the host calls this after mounting).
func restore_open_notes() -> void:
	for g in ProgramStore.groups:
		for it in g.items:
			if Notes.is_note(it) and it.get("noteOpen", false):
				open_note(String(it.id), false)
