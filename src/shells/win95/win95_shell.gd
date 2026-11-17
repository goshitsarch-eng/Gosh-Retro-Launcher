class_name Win95Shell
extends ShellBase
## The Windows 95 RTM shell (port of Win95Shell.tsx): desktop + windows, taskbar, Start menu,
## popup/menu layer and dialog layer, all laid out in 640x480-style logical pixels (the host owns the
## integer content scale). It hosts the single Win95 input model (Win95InputController): every key
## and mouse event passes through _input() first.
##
## Launch groups: launch_group_row(row_id) / launch_buckets(buckets) (Win95LaunchGroupLogic rows);
## a batch shows Win95LaunchProgress while it runs.
## Layers (back to front): desktop (windows inside) < notes_layer (sticky notes) < taskbar < Start menu
## < dialog_layer < popup_layer. A sticky note's text owns the keyboard while it has focus (see
## note_has_focus and Win95InputController.on_key); clicking one makes it the active "window".
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
	notes_layer.position = Vector2.ZERO
	notes_layer.size = desktop.size
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
	if n != null and focus:
		input.close_start_menu()
		windows.activate_note()
	return n


func _on_note_closed(_id: String) -> void:
	windows.note_closed()


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


## A press outside the notes takes the keyboard back from a note's text (the windows and the
## desktop do not take Godot focus themselves); a press on a note makes it the active window.
## Right-click on a note opens its small menu. Returns true when the event was used here.
func _route_note_press(mb: InputEventMouseButton, pos: Vector2) -> bool:
	var hit := note_at(pos)
	if hit == null:
		if note_has_focus():
			get_viewport().gui_release_focus()
		return false
	windows.activate_note()
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_note_menu(hit, pos)
		return true
	return false


func _open_note_menu(n: StickyNote, at: Vector2) -> void:
	var id := n.item_id
	Win95Menu.open(self, [
		{"id": "note-close", "label": "&Close", "defaultItem": true, "onSelect": func():
			if is_instance_valid(n):
				n.close()},
		{"id": "sep", "separator": true},
		{"id": "note-properties", "label": "P&roperties", "icon": "properties", "onSelect": func():
			var loc := ProgramStore.locate_item(id)
			if not loc.is_empty():
				Win95Dialogs.open_properties(self, {"kind": "item", "groupId": loc.groupId, "item": loc.item})},
	], at)


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
