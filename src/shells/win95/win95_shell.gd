class_name Win95Shell
extends ShellBase
## The Windows 95 RTM shell (port of Win95Shell.tsx): desktop + windows, taskbar, Start menu,
## popup/menu layer and dialog layer, all laid out in 640x480-style logical pixels (the host owns the
## integer content scale). It hosts the single Win95 input model (Win95InputController): every key
## and mouse event passes through _input() first.
##
## Launch groups: launch_group_row(row_id) / launch_buckets(buckets) (Win95LaunchGroupLogic rows);
## a batch shows Win95LaunchProgress while it runs.
## Layers (back to front): desktop (windows inside) < notes_layer (sticky notes) < outline_layer
## (Move/Size outline) < taskbar < Start menu < dialog_layer < popup_layer. A sticky note's text owns
## the keyboard while it has focus (see note_has_focus and Win95InputController.on_key); clicking one
## makes it the active "window", and each open note has a taskbar button and an Alt+Tab stop.
## Public surface used by the Win95* components: windows (Win95WindowStore), input, desktop, taskbar,
## popup_layer, dialog_layer, logical_size, desktop_size(), host_focused, dragging, launch_item().

const M := Win95Tokens.M

var windows: Win95WindowStore
var input: Win95InputController
var desktop: Win95Desktop
var taskbar: Win95Taskbar
var start_menu: Win95StartMenu
var popup_layer: Control
var dialog_layer: Control
var notes_layer: Control
## Holds the window Move/Size outline (Win95Desktop.set_outline) above the notes; clips like the desktop.
var outline_layer: Control

var logical_size := Vector2(640, 480)
var host_focused := true
var dragging := false


func shell_id() -> String:
	return "win95"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var rf := RetroFont.instance(RetroFont.WIN95)
	rf.baseline_adjust = 1  # calibrated against the RTM reference renders
	rf.x_adjust = 1
	windows = Win95WindowStore.new(null)
	input = Win95InputController.new()
	input.shell = self
	add_child(input)
	desktop = Win95Desktop.new()
	add_child(desktop)
	notes_layer = _make_layer()
	notes_layer.name = "NotesLayer"
	add_child(notes_layer)
	outline_layer = _make_layer()
	outline_layer.name = "OutlineLayer"
	outline_layer.clip_contents = true
	add_child(outline_layer)
	taskbar = Win95Taskbar.new()
	add_child(taskbar)
	start_menu = Win95StartMenu.new()
	add_child(start_menu)
	popup_layer = _make_layer()
	dialog_layer = _make_layer()
	add_child(dialog_layer)  # popups (combo lists, menus opened from dialogs) draw above dialogs
	add_child(popup_layer)
	resized.connect(_layout)


func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	A11y.set_base(self)
	A11y.ensure_proxy(get_tree())
	if Engine.has_meta("pm_capture"):
		host_focused = true
	else:
		var win := get_window()
		if win != null:
			host_focused = win.has_focus() or true
			win.focus_entered.connect(func(): _set_host_focus(true))
			win.focus_exited.connect(func(): _set_host_focus(false))
	desktop.setup(self)
	taskbar.setup(self)
	windows.changed.connect(_on_windows_changed)
	start_menu.setup(self)
	_layout()


func _set_host_focus(focused: bool) -> void:
	host_focused = focused
	desktop.sync_windows()
	desktop.queue_redraw()
	taskbar.queue_redraw()


func on_host_state_changed(state: Dictionary) -> void:
	if state.has("focused") and not Engine.has_meta("pm_capture"):
		_set_host_focus(bool(state.focused))


func on_activate() -> void:
	_layout()


func on_scale_changed(_factor: int) -> void:
	_layout()


func _layout() -> void:
	logical_size = Vector2(ceilf(size.x), ceilf(size.y))
	if logical_size.x < 1 or logical_size.y < 1:
		return
	var h := logical_size.y - M.taskbarHeight
	desktop.position = Vector2.ZERO
	desktop.size = Vector2(logical_size.x, maxf(1.0, h))
	taskbar.position = Vector2(0, h)
	taskbar.size = Vector2(logical_size.x, M.taskbarHeight)
	for c in [notes_layer, outline_layer]:
		c.position = Vector2.ZERO
		c.size = desktop.size
	for c in [start_menu, popup_layer, dialog_layer]:
		c.position = Vector2.ZERO
		c.size = logical_size
	desktop.sync_windows()
	taskbar.queue_redraw()
	start_menu.queue_redraw()


func desktop_size() -> Vector2:
	return Vector2(logical_size.x, maxf(1.0, logical_size.y - M.taskbarHeight))


func set_dragging(on: bool) -> void:
	dragging = on


func _exit_tree() -> void:
	A11y.clear_base(self)


## Win95 keeps its own keyboard focus model: report the element it points at when no control holds
## Godot focus (open menus are overlays and win before this; see A11y).
func a11y_focus() -> RID:
	for i in range(dialog_layer.get_child_count() - 1, -1, -1):
		var m := dialog_layer.get_child(i)
		if m is Win95Modal and m.visible and not m.is_queued_for_deletion():
			return m.get_accessibility_element()
	var id: String = windows.active_window_id
	if id != "":
		var w := desktop.window_for(id)
		if w != null and is_instance_valid(w):
			return w.a11y_focus()
	return desktop.a11y_focus()


# ------------------------------------------------------------------- launching

func launch_item(item: Dictionary) -> void:
	if _is_note(item):
		open_note(String(item.get("id", "")))  # a note opens its window; Minimize on Use would hide it
		return
	var result: Dictionary = Platform.launch(item)
	if not result.get("success", false):
		Win95Dialogs.show_message(self, String(item.name), String(result.get("error", "Windows cannot find '%s'." % item.path)), "warning")
	elif ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()


var _launch_in_progress := false


func is_launching_groups() -> bool:
	return _launch_in_progress


## Start > Programs > Launch Groups rows ("launch-all" / "launch:<n>") and the manager's Launch button.
func launch_group_row(row_id: String) -> void:
	launch_buckets(Win95LaunchGroupLogic.buckets_for(ProgramStore.groups, row_id))


## The progress window of the batch that is running (null between batches).
var launch_progress: Win95LaunchProgress


## Starts launch-group buckets one item at a time, in the order and with the pauses of
## LaunchGroups.launch_group_buckets (settings.launchDelay between the items of a group), while the
## Win95LaunchProgress window shows each one; its Cancel skips the items not started yet. A second
## request while a run is in progress is ignored. Notes open their windows (behind the progress
## window, without taking the keyboard). Items that fail are listed in one warning box afterwards,
## the way a single failed launch is reported. Nothing here raises or focuses the launcher's own
## OS window, so the program that was just started keeps the focus it took.
func launch_buckets(buckets: Array) -> void:
	if _launch_in_progress or buckets.is_empty():
		return
	_launch_in_progress = true
	var names := ProgramStore.launch_group_names()
	var title := Win95LaunchGroupLogic.launch_title(buckets, names)
	var steps := Win95LaunchGroupLogic.batch_steps(buckets)
	var results: Array = Win95LaunchGroupLogic.batch_refusals(buckets)
	var delay := Win95LaunchGroupLogic.clamp_delay(ProgramStore.settings.get("launchDelay", 500))
	UIState.begin_launch_feedback(buckets.size(), steps.size())
	Input.set_default_cursor_shape(Input.CURSOR_BUSY)  # Win95's "working in background" pointer while programs start
	var progress: Win95LaunchProgress = null
	if not steps.is_empty():
		progress = Win95LaunchProgress.open(self, steps.size(), Win95LaunchGroupLogic.progress_title(int(steps[0].groupNumber), names))
	launch_progress = progress
	var started_program := false
	var bucket := -1
	for step in steps:
		if progress.cancelled or not is_inside_tree():
			break
		if int(step.bucket) != bucket:
			bucket = int(step.bucket)
			UIState.update_launch_feedback(int(step.groupNumber), bucket)
		progress.show_step(step, Win95LaunchGroupLogic.progress_title(int(step.groupNumber), names))
		await get_tree().process_frame  # paint "Starting <program>..." before the start blocks
		if progress.cancelled or not is_inside_tree():
			break
		var result := _launch_batch_item(step.item)
		var entry := {"id": step.item.get("id", "unknown"), "success": result.get("success", false)}
		if result.has("error"):
			entry["error"] = result.error
		results.append(entry)
		if entry.success and not _is_note(step.item):
			started_program = true
		progress.set_done(int(step.index) + 1)
		if step.pauseAfter and delay > 0:
			await _batch_pause(delay, progress)
	if progress != null and not progress.cancelled and is_inside_tree():
		await get_tree().process_frame  # let the full bar show for a moment
	if progress != null:
		progress.close()
	launch_progress = null
	var text := Win95LaunchGroupLogic.failure_message(results, buckets)
	UIState.finish_launch_feedback(results.filter(func(r): return not r.get("success", false)).size())
	_launch_in_progress = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not is_inside_tree():
		return
	if text != "":
		Win95Dialogs.show_message(self, Win95LaunchGroupLogic.escape(title), Win95LaunchGroupLogic.escape(text), "warning")
	elif started_program and ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()


## One item of a batch: a note opens its window without focus; anything else goes to Platform.launch.
func _launch_batch_item(item: Dictionary) -> Dictionary:
	if _is_note(item):
		var n := open_note(String(item.get("id", "")), false)
		return {"success": true} if n != null else {"success": false, "error": "The note no longer exists."}
	return Platform.launch(item)


## The pause between two items of a group, cut short by Cancel (checked every 50 ms).
func _batch_pause(ms: int, progress: Win95LaunchProgress) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until and not progress.cancelled and is_inside_tree():
		await get_tree().create_timer(minf(0.05, (until - Time.get_ticks_msec()) / 1000.0)).timeout


static func _is_note(item: Dictionary) -> bool:
	if Notes.is_note(item):
		return true
	var id: Variant = item.get("id")
	return id is String and Notes.is_note(ProgramStore.locate_item(String(id)).get("item", {}))


# ------------------------------------------------------------------ sticky notes

func note_layer() -> Control:
	return notes_layer


func note_style() -> Dictionary:
	return {"font": RetroFont.instance(RetroFont.WIN95).font, "font_size": 11, "text_color": Win95Draw.TEXT}


func open_note(item_id: String, focus: bool = true) -> StickyNote:
	var n := super.open_note(item_id, focus)
	if n != null and not n.closed.is_connected(_on_note_closed):
		n.closed.connect(_on_note_closed)
		n.activated.connect(_on_note_activated)
	if n != null and focus:
		input.close_start_menu()
		windows.activate_note(item_id)
	return n


func _on_note_activated(item_id: String) -> void:
	windows.activate_note(item_id)


## The active note closed: the task that was active before it takes over (another note gets the
## keyboard back; a window or the desktop is reactivated the usual way).
func _on_note_closed(item_id: String) -> void:
	if windows.active_note_id() != item_id:
		return
	var open_ids := task_stack().filter(func(t): return t != Win95TaskbarState.note_task_id(item_id))
	var next := Win95TaskbarState.next_active(_recent_tasks, open_ids)
	if Win95TaskbarState.is_note_task(next):
		open_note(Win95TaskbarState.note_item_id(next))
	else:
		windows.note_closed(item_id)


## Most recently active task ids first (window entry ids and Win95TaskbarState.note_task_id ids).
var _recent_tasks: Array = []


## A window (or the desktop) became active: the note text gives up the keyboard, and the active
## task moves to the front of the recently-active list.
func _on_windows_changed() -> void:
	if windows.active_window_id != Win95WindowStore.NOTE_ACTIVE and note_has_focus():
		get_viewport().gui_release_focus()
	_recent_tasks = Win95TaskbarState.touch_recent(_recent_tasks, active_task_id())


## Everything Alt+Tab switches between, bottom to top: the windows by z-order, then the open notes
## (which sit above every window) in their own stacking order.
func task_stack() -> Array:
	var out: Array = windows.by_z().map(func(e): return String(e.id))
	for n in open_notes():
		out.append(Win95TaskbarState.note_task_id(n.item_id))
	return out


## The task id of the active window or note ("" while the desktop is active).
func active_task_id() -> String:
	var nid := windows.active_note_id()
	return Win95TaskbarState.note_task_id(nid) if nid != "" else windows.active_window_id


## Brings a window (restoring it when minimized) or a note to the front and gives it the keyboard.
func activate_task(task_id: String) -> void:
	if Win95TaskbarState.is_note_task(task_id):
		open_note(Win95TaskbarState.note_item_id(task_id))
		return
	var entry := windows.find_entry(task_id)
	if not entry.is_empty():
		windows.unminimize(entry)
		windows.focus_window(task_id)


## True while the text of a sticky note has the keyboard focus.
func note_has_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return owner != null and notes_layer.is_ancestor_of(owner)


## The note window that has the keyboard focus, or null.
func focused_note() -> StickyNote:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	while owner != null and owner != notes_layer:
		if owner is StickyNote:
			return owner
		owner = owner.get_parent() as Control
	return null


## The topmost open note under `pos` (shell logical pixels), or null.
func note_at(pos: Vector2) -> StickyNote:
	var notes := open_notes()
	for i in range(notes.size() - 1, -1, -1):
		var n: StickyNote = notes[i]
		if n.visible and Rect2(n.position + notes_layer.position, n.size).has_point(pos):
			return n
	return null


## A press outside the notes (and off the taskbar, whose buttons decide for themselves) takes the
## keyboard back from a note's text (the windows and the desktop do not take Godot focus
## themselves). A left press on a note makes it the active window and goes on to the note. A
## right press brings the note to the front and opens show_note_menu here, as the note's own
## context_requested would: the note's text field takes right-clicks in its area before the note
## sees them. Returns true when the event was used here.
func _route_note_press(mb: InputEventMouseButton, pos: Vector2) -> bool:
	var hit := note_at(pos)
	if hit == null:
		if note_has_focus() and not Rect2(taskbar.position, taskbar.size).has_point(pos):
			get_viewport().gui_release_focus()
		return false
	windows.activate_note(hit.item_id)
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		hit.move_to_front()
		show_note_menu(hit.item_id, global_position + pos)
		return true
	# A press on the title strip, close box or grip activates the note with the keyboard too (its
	# caret stays where it was), so typing and Alt+F4 go to it as they would to a window.
	var edit := _note_text(hit)
	if edit != null and not edit.has_focus():
		edit.grab_focus()
	return false


func _note_text(n: StickyNote) -> TextEdit:
	for c in n.get_children():
		if c is TextEdit:
			return c
	return null


## Right-click on an open note (StickyNote.context_requested): its menu at the pointer.
func show_note_menu(item_id: String, global_pos: Vector2) -> void:
	open_note_menu(item_id, global_pos - global_position)


## The note menu (Close, Properties, Delete) at `at` (shell logical pixels); `opts` as Win95Menu.open.
## A right-click on the note or on its taskbar button and Shift+F10 / the Menu key in it open it.
func open_note_menu(item_id: String, at: Vector2, opts: Dictionary = {}) -> Win95Menu:
	return Win95Menu.open(self, note_menu_items(item_id), at, opts)


func note_menu_items(item_id: String) -> Array:
	return [
		{"id": "note-close", "label": "&Close", "defaultItem": true, "onSelect": func(): close_note(item_id)},
		{"id": "note-properties", "label": "P&roperties", "icon": "properties", "onSelect": func():
			var loc := ProgramStore.locate_item(item_id)
			if not loc.is_empty():
				Win95Dialogs.open_properties(self, {"kind": "item", "groupId": loc.groupId, "item": loc.item})},
		{"id": "sep", "separator": true},
		{"id": "note-delete", "label": "&Delete", "onSelect": func(): confirm_delete_note(item_id)},
	]


## Win95's delete question for note `item_id`: Yes deletes it (its window closes with it), No gives
## the note the keyboard back.
func confirm_delete_note(item_id: String) -> Win95Modal:
	var loc := ProgramStore.locate_item(item_id)
	if loc.is_empty():
		return null
	var gid := String(loc.groupId)
	var message := Win95TaskbarState.delete_note_message(String(loc.item.get("name", "Note")))
	return Win95Dialogs.confirm(self, "Confirm File Delete", message, func():
		ProgramStore.delete_item(gid, item_id), func():
		if note_window(item_id) != null:
			open_note(item_id))


## Shift+F10 / the Menu key while a note's text has the keyboard: the note menu inside its text.
func open_focused_note_menu() -> void:
	var n := focused_note()
	if n != null:
		open_note_menu(n.item_id, notes_layer.position + n.position + Vector2(8, n.title_h + 8))


# ------------------------------------------------------------------ host events

func toggle_quick_search() -> void:
	input.close_start_menu()
	Win95Dialogs.open_find(self)


func on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	var target := ""
	for e in windows.by_z():
		if e.kind != "group" or windows.entry_is_minimized(e):
			continue
		var w: Win95Window = desktop.window_for(e.id)
		if w != null and Rect2(w.position, w.size).has_point(logical_pos):
			target = String(e.groupId)
	if target == "":
		return
	for path in files:
		var info: Dictionary = Platform.get_app_info(path)
		ProgramStore.add_item(target, {
			"name": info.get("name", path.get_file().get_basename()),
			"path": info.get("path", path),
			"icon": info.get("icon", "application"),
			"workingDir": info.get("workingDir", ""),
		})


# --------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.ctrl_pressed and k.alt_pressed and k.keycode == KEY_T:
			request_show_launcher_tools.emit()
			get_viewport().set_input_as_handled()
			return
		if input.on_key(k):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var pos := mb.position - global_position
		if input.on_pointer("down" if mb.pressed else "up", mb, pos):
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT) \
				and not input.modal_active() and _route_note_press(mb, pos):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if input.on_pointer("move", mm, mm.position - global_position):
			get_viewport().set_input_as_handled()
