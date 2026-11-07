class_name Win31Shell
extends ShellBase
## Windows for Workgroups 3.11 Program Manager shell. Port of shells/Win31Shell.tsx: outer frame
## (OS window or movable desktop-mode window), command dispatch, global shortcuts, batch launch,
## host window state, minimized desktop icon, and the overlay stack
## (content, launch feedback, dialogs, Quick Search).

const MIN_W := 320
const MIN_H := 240

var pm: Win31ProgramManager
var desktop_icon: Win31DesktopIcon
var feedback: Win31LaunchFeedback
var dialogs: Win31DialogLayer
var quick: Win31QuickSearch

var host_state := {"focused": true, "maximized": false, "minimized": false, "bounds": Rect2i(0, 0, 800, 600)}
var desktop_bounds := {"x": 68, "y": 49, "width": 511, "height": 335}
var desktop_maximized := false

var _scale := 1
var _launch_in_progress := false
var _move_origin := {}
var _resize_origin := {}
var _kb_op := {}                 ## active outer keyboard Move/Size: {mode, kind, initial, bounds, born}
var _activated := false


func shell_id() -> String:
	return "win31"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	pm = Win31ProgramManager.new()
	add_child(pm)
	desktop_icon = Win31DesktopIcon.new()
	desktop_icon.visible = false
	desktop_icon.restore_requested.connect(func(): ProgramStore.update_settings({"win31ProgramManagerMinimized": false}))
	add_child(desktop_icon)
	feedback = Win31LaunchFeedback.new()
	add_child(feedback)
	dialogs = Win31DialogLayer.new()
	add_child(dialogs)
	quick = Win31QuickSearch.new()
	add_child(quick)
	pm.command_chosen.connect(run_command)
	pm.minimize_requested.connect(minimize_program_manager)
	pm.maximize_toggle_requested.connect(toggle_program_manager_maximize)
	pm.desktop_move.connect(_on_desktop_move)
	pm.desktop_resize.connect(_on_desktop_resize)
	pm.client.launch_requested.connect(_on_grid_launch)
	add_to_group("pm_auto")


func _ready() -> void:
	ProgramStore.groups_changed.connect(_on_groups_changed)
	ProgramStore.settings_changed.connect(_on_settings_changed)
	UIState.selection_changed.connect(_on_selection_changed)
	UIState.dialog_changed.connect(_update_menus)
	MdiState.windows_changed.connect(_update_menus)
	if Platform.has_signal("window_state_changed"):
		Platform.window_state_changed.connect(on_host_state_changed)


func _exit_tree() -> void:
	for pair in [[ProgramStore.groups_changed, _on_groups_changed], [ProgramStore.settings_changed, _on_settings_changed],
			[UIState.selection_changed, _on_selection_changed], [UIState.dialog_changed, _update_menus],
			[MdiState.windows_changed, _update_menus]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	if Platform.has_signal("window_state_changed") and Platform.window_state_changed.is_connected(on_host_state_changed):
		Platform.window_state_changed.disconnect(on_host_state_changed)


# --------------------------------------------------------------- lifecycle

func on_activate() -> void:
	_activated = true
	var b: Variant = ProgramStore.settings.get("win31ProgramManagerBounds")
	if b != null:
		desktop_bounds = b.duplicate()
	host_state.maximized = Platform.is_window_maximized()
	pm.client.refresh_all()
	_apply_settings()
	_update_menus()
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree() and ProgramStore.settings.get("shell", "win31") == "win31":
		Sounds.play("startup_chime")


func toggle_quick_search() -> void:
	UIState.toggle_quick_search()


func on_scale_changed(factor: int) -> void:
	_scale = maxi(1, factor)
	_layout()


func on_host_state_changed(state: Dictionary) -> void:
	for k in ["focused", "maximized", "minimized"]:
		if state.has(k):
			host_state[k] = state[k]
	if state.has("bounds"):
		host_state["bounds"] = state.bounds
	pm.set_active(bool(host_state.focused))
	_sync_maximized()
	queue_redraw()


func on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	pm.client.add_dropped_files(files, logical_pos)


# ----------------------------------------------------------------- layout

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and pm != null:
		_layout()


func _desktop_mode() -> bool:
	return bool(ProgramStore.settings.get("win31DesktopMode", false))


func _desktop_minimized() -> bool:
	return _desktop_mode() and bool(ProgramStore.settings.get("win31ProgramManagerMinimized", false))


func effective_maximized() -> bool:
	return desktop_maximized if _desktop_mode() else bool(host_state.maximized)


func _layout() -> void:
	var desktop := _desktop_mode()
	var minimized := _desktop_minimized()
	pm.visible = not minimized
	desktop_icon.visible = minimized
	pm.desktop_window = desktop
	if desktop:
		if desktop_maximized:
			pm.position = Vector2.ZERO
			pm.size = Vector2(maxf(MIN_W, size.x), maxf(MIN_H, size.y))
		else:
			pm.position = Vector2(float(desktop_bounds.x), float(desktop_bounds.y))
			pm.size = Vector2(maxf(MIN_W, float(desktop_bounds.width)), maxf(MIN_H, float(desktop_bounds.height)))
	else:
		pm.position = Vector2.ZERO
		pm.size = Vector2(maxf(MIN_W, size.x), maxf(MIN_H, size.y))
	pm.apply_layout()
	pm.client.apply_layout()
	desktop_icon.position = Vector2(1, maxf(8.0 / _scale, size.y - 70))
	_sync_maximized()
	pm.queue_redraw()
	queue_redraw()


func _sync_maximized() -> void:
	pm.set_maximized(effective_maximized())


func _draw() -> void:
	Px.fill(self, 0, 0, size.x, size.y, Pal.FACE)


# ------------------------------------------------------------ store events

func _on_groups_changed() -> void:
	pm.client.refresh_all()
	_update_menus()


func _on_settings_changed() -> void:
	if _move_origin.is_empty() and _resize_origin.is_empty():
		var b: Variant = ProgramStore.settings.get("win31ProgramManagerBounds")
		if b != null:
			desktop_bounds = b.duplicate()
	_apply_settings()
	pm.client.refresh_all()
	_update_menus()


func _apply_settings() -> void:
	if not _desktop_mode():
		desktop_maximized = false
	_layout()


func _on_selection_changed() -> void:
	for id in pm.client.windows:
		pm.client.windows[id].grid.queue_redraw()
		pm.client.windows[id].queue_redraw()
	for id in pm.client.icons:
		pm.client.icons[id].queue_redraw()
	_update_menus()


func _update_menus() -> void:
	if pm == null:
		return
	pm.menu_bar.disabled = UIState.active_dialog != ""
	pm.menu_bar.set_menus(Win31Commands.build_menus(ProgramStore.groups, MdiState.active_window_id,
		UIState.win31_selection, ProgramStore.settings))


func selected() -> Dictionary:
	return Win31Commands.selected_objects(ProgramStore.groups, UIState.win31_selection, MdiState.active_window_id)


# ------------------------------------------------------------ outer window

func toggle_program_manager_maximize() -> void:
	if _desktop_mode():
		desktop_maximized = not desktop_maximized
		_layout()
	else:
		Platform.toggle_maximize_window()
		await get_tree().create_timer(0.2).timeout
		if is_inside_tree():
			host_state.maximized = Platform.is_window_maximized()
			_sync_maximized()


func minimize_program_manager() -> void:
	if _desktop_mode():
		ProgramStore.update_settings({"win31ProgramManagerMinimized": true})
	else:
		Platform.minimize_window()


func persist_desktop_bounds(bounds: Dictionary) -> void:
	desktop_bounds = bounds.duplicate()
	ProgramStore.update_settings({"win31ProgramManagerBounds": bounds.duplicate()})
	_layout()


func _on_desktop_move(phase: String, delta: Vector2) -> void:
	if _move_origin.is_empty():
		_move_origin = desktop_bounds.duplicate()
	var b := Win31Commands.desktop_drag_bounds(_move_origin, delta.x, delta.y, size.x, size.y)
	if phase == "end":
		_move_origin = {}
		persist_desktop_bounds(b)
	else:
		desktop_bounds = b
		_layout()


func _on_desktop_resize(phase: String, direction: String, delta: Vector2) -> void:
	if _resize_origin.is_empty():
		_resize_origin = desktop_bounds.duplicate()
	var b := Win31Commands.desktop_resize_bounds(_resize_origin, direction, delta)
	if phase == "end":
		_resize_origin = {}
		persist_desktop_bounds(b)
	else:
		desktop_bounds = b
		_layout()


# ---------------------------------------------------------------- launching

func _on_grid_launch(item: Dictionary) -> void:
	var gid := ""
	for g in ProgramStore.groups:
		for it in g.items:
			if it.id == item.id:
				gid = g.id
	launch_item(item, gid)


## Launches one item. `group_id` is the window to minimize for Minimize on Use (the grid passes
## its own group; the Open command / shortcut keys use the selected group).
func launch_item(item: Dictionary, group_id: String = "") -> void:
	var result: Dictionary = Platform.launch(item)
	if not result.get("success", false):
		UIState.open_dialog("confirm", {"confirmOptions": {
			"title": "Program Manager",
			"message": String(result.get("error", "Cannot run %s." % item.get("name", ""))),
			"onConfirm": func() -> void: pass,
		}})
		return
	if ProgramStore.settings.get("minimizeOnUse", false):
		var gid := group_id if group_id != "" else String(selected().group.get("id", ""))
		if gid != "":
			pm.client.update_state(gid, {"minimized": true})


func launch_buckets(buckets: Array) -> void:
	if _launch_in_progress or buckets.is_empty():
		return
	# Let the menu close paint before starting sounds, progress updates, and platform work.
	await get_tree().process_frame
	await get_tree().process_frame
	if _launch_in_progress or not is_inside_tree():
		return
	_launch_in_progress = true
	Sounds.play("button_click")
	var total := 0
	for b in buckets:
		total += b.items.size()
	UIState.begin_launch_feedback(buckets.size(), total)
	var results: Array = await LaunchGroups.launch_group_buckets(self, buckets, ProgramStore.settings.get("launchDelay", 500),
		_on_group_start, Callable(Platform, "launch_batch"))
	var failures := results.filter(func(r): return not r.get("success", false))
	UIState.finish_launch_feedback(failures.size())
	if failures.size() > 0:
		push_error("Failed to launch some grouped items: %s" % str(failures))
	if ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()
	_launch_in_progress = false


func _on_group_start(progress: Dictionary) -> void:
	Sounds.play("menu_click")
	UIState.update_launch_feedback(progress.groupNumber, progress.groupIndex)


func restore_group(group: Dictionary) -> void:
	pm.client.restore_group(group.id)


# ----------------------------------------------------------------- commands

func run_command(command: String) -> void:
	pm.close_system_menu()
	var groups: Array = ProgramStore.groups
	if command.begins_with("group:"):
		var group := ProgramStore.find_group(command.substr(6))
		if not group.is_empty():
			restore_group(group)
		return
	if command.begins_with("launch-group:"):
		var number := int(command.substr("launch-group:".length()))
		for bucket in LaunchGroups.collect_launch_groups(groups):
			if bucket.groupNumber == number:
				launch_buckets([bucket])
				break
		return
	var sel := selected()
	var group: Dictionary = sel.group
	var item: Dictionary = sel.item
	var settings: Dictionary = ProgramStore.settings
	match command:
		"new":
			var data := {}
			if not group.is_empty():
				data["groupId"] = group.id
			UIState.open_dialog("newObject", data)
		"open":
			if not item.is_empty():
				launch_item(item)
			elif not group.is_empty():
				restore_group(group)
		"move", "copy":
			if not item.is_empty() and not group.is_empty():
				UIState.open_dialog("moveItem" if command == "move" else "copyItem", {
					"groupId": group.id, "item": item, "copyMode": command == "copy"})
		"delete":
			if not item.is_empty() and not group.is_empty():
				_confirm_delete_item(group, item, "Delete the program item “%s”?" % item.name)
			elif not group.is_empty():
				_confirm_delete_group(group, "Delete the program group “%s” and all its items?" % group.name)
		"properties":
			if not item.is_empty() and not group.is_empty():
				UIState.open_dialog("itemProperties", {"groupId": group.id, "item": item})
			elif not group.is_empty():
				UIState.open_dialog("groupProperties", {"group": group})
		"run":
			UIState.open_dialog("run")
		"launch-all":
			launch_buckets(LaunchGroups.collect_launch_groups(groups))
		"launcher-tools":
			LauncherToolsWindow.show_singleton(host if host != null else self)
		"exit":
			UIState.open_dialog("exitWindows")
		"auto-arrange":
			ProgramStore.update_settings({"autoArrange": not settings.get("autoArrange", true)})
		"minimize-on-use":
			ProgramStore.update_settings({"minimizeOnUse": not settings.get("minimizeOnUse", false)})
		"save-settings":
			ProgramStore.update_settings({"saveSettingsOnExit": not settings.get("saveSettingsOnExit", true)})
		"cascade":
			MdiState.cascade_windows()
		"tile":
			MdiState.tile_windows()
		"arrange-icons":
			MdiState.arrange_icons()
		"help-contents", "help-search", "help-using":
			UIState.open_dialog("help", {"helpTopic": "search" if command == "help-search" else ("using" if command == "help-using" else "contents")})
		"about":
			UIState.open_dialog("about")
		"outer-restore", "outer-maximize":
			toggle_program_manager_maximize()
		"outer-move", "outer-size":
			_begin_outer_keyboard_op("move" if command == "outer-move" else "size")
		"outer-minimize":
			minimize_program_manager()
		"outer-close":
			if _desktop_mode():
				UIState.open_dialog("exitWindows")
			else:
				Platform.close_window()


func _confirm_delete_item(group: Dictionary, item: Dictionary, message: String) -> void:
	var gid: String = group.id
	var iid: String = item.id
	UIState.open_dialog("confirm", {"confirmOptions": {
		"title": "Delete Program Item", "message": message,
		"onConfirm": func() -> void: ProgramStore.delete_item(gid, iid),
	}})


func _confirm_delete_group(group: Dictionary, message: String) -> void:
	var gid: String = group.id
	UIState.open_dialog("confirm", {"confirmOptions": {
		"title": "Delete Program Group", "message": message,
		"onConfirm": func() -> void: ProgramStore.delete_group(gid),
	}})


# ----------------------------------------------------------------- keyboard

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := Win31Commands.key_name(event)
	if event.ctrl_pressed and event.alt_pressed and key == "t":
		get_viewport().set_input_as_handled()
		request_show_launcher_tools.emit()
		return
	if not _kb_op.is_empty() and Engine.get_process_frames() != _kb_op.born:
		_outer_keyboard_op_key(event, key)
	if UIState.active_dialog != "":
		return
	if event.alt_pressed and key == " ":
		get_viewport().set_input_as_handled()
		pm.toggle_system_menu()
		return
	if event.alt_pressed and key == "-":
		get_viewport().set_input_as_handled()
		pm.client.open_active_system_menu()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	_shell_shortcuts(event, key)


func _shell_shortcuts(ev: InputEventKey, key: String) -> void:
	var groups: Array = ProgramStore.groups
	var sel := selected()
	var group: Dictionary = sel.group
	var item: Dictionary = sel.item
	var accepted := func() -> void: get_viewport().set_input_as_handled()
	if key == "f1" and not ev.ctrl_pressed and not ev.alt_pressed:
		accepted.call()
		UIState.open_dialog("help", {"helpTopic": "contents"})
		return
	if ev.alt_pressed and key == "f4":
		accepted.call()
		if _desktop_mode():
			UIState.open_dialog("exitWindows")
		else:
			Platform.close_window()
		return
	if ev.shift_pressed and not ev.ctrl_pressed and not ev.alt_pressed and key == "f4":
		accepted.call()
		MdiState.tile_windows()
		return
	if ev.shift_pressed and not ev.ctrl_pressed and not ev.alt_pressed and key == "f5":
		accepted.call()
		MdiState.cascade_windows()
		return
	if ev.ctrl_pressed and not ev.alt_pressed and key == "f6":
		var visible := Win31Commands.visible_groups(groups)
		if visible.size() > 0:
			accepted.call()
			var current := -1
			for i in visible.size():
				if visible[i].id == MdiState.active_window_id:
					current = i
			var n := visible.size()
			MdiState.focus_window(visible[((current + 1) % n + n) % n].id)
		return
	if ev.ctrl_pressed and not ev.alt_pressed and key == "f4" and not group.is_empty():
		accepted.call()
		pm.client.update_state(group.id, {"minimized": true})
		return
	if ev.alt_pressed and key == "enter" and not group.is_empty():
		accepted.call()
		if not item.is_empty():
			UIState.open_dialog("itemProperties", {"groupId": group.id, "item": item})
		else:
			UIState.open_dialog("groupProperties", {"group": group})
		return
	if key == "delete" and not group.is_empty():
		accepted.call()
		if not item.is_empty():
			_confirm_delete_item(group, item, "Delete the program item “%s”?" % item.name)
		else:
			_confirm_delete_group(group, "Delete the program group “%s”?" % group.name)
		return
	if Win31Commands.is_reserved_alt_key(key, ev.ctrl_pressed, ev.shift_pressed, ev.meta_pressed, ev.alt_pressed):
		return
	for g in groups:
		for it in g.items:
			if Win31Commands.shortcut_matches_event(String(it.get("shortcutKey", "")), ev):
				accepted.call()
				launch_item(it)
				return


# --------------------------------------- outer keyboard Move / Size (system menu)

func _begin_outer_keyboard_op(mode: String) -> void:
	if _desktop_mode():
		_kb_op = {"mode": mode, "kind": "desktop", "initial": desktop_bounds.duplicate(), "bounds": desktop_bounds.duplicate(),
			"born": Engine.get_process_frames()}
	else:
		var r: Rect2i = Platform.get_window_bounds()
		var b := {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
		_kb_op = {"mode": mode, "kind": "host", "initial": b.duplicate(), "bounds": b, "born": Engine.get_process_frames()}


func _outer_keyboard_op_key(ev: InputEventKey, key: String) -> void:
	var desktop: bool = _kb_op.kind == "desktop"
	if key == "escape" or key == "enter":
		get_viewport().set_input_as_handled()
		var initial: Dictionary = _kb_op.initial
		var final: Dictionary = _kb_op.bounds
		_kb_op = {}
		if desktop:
			persist_desktop_bounds(initial if key == "escape" else final)
		elif key == "escape":
			Platform.set_window_bounds(Rect2i(initial.x, initial.y, initial.width, initial.height))
		return
	var step: Dictionary
	if desktop:
		step = Win31Commands.desktop_key_step(_kb_op.mode, _kb_op.bounds, key, ev.shift_pressed)
	else:
		step = Win31Commands.host_key_step(_kb_op.mode, _kb_op.bounds, key, ev.shift_pressed)
	if step.is_empty():
		return
	get_viewport().set_input_as_handled()
	_kb_op.bounds = step
	if desktop:
		persist_desktop_bounds(step)  # commit each key so keyboard movement paints and persists
	else:
		Platform.set_window_bounds(Rect2i(step.x, step.y, step.width, step.height))
