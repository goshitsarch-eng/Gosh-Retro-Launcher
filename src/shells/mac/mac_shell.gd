class_name MacShell
extends ShellBase
## The classic Mac OS-style shell. Layers (back to front): desktop (icons + folder/Find windows) < sticky notes
## (below the menu bar strip) < popup layer (menus) < menu bar < toast < dialog layer < popup overlay for selects
## opened inside dialogs.
## Groups are folders ("Launcher HD" lists them, a folder window lists its items). Everything is drawn in
## integer logical pixels; the host applies the integer content scale.
##
## Public surface used by the Mac* components: desktop, popup_layer, dialog_layer, logical_size,
## launch_item(), open_group_window(), show_menu(), show_item_context(), do_shutdown(), refresh_theme().

var desktop: MacDesktop
var notes_layer: Control    ## StickyNote windows (ShellBase.open_note); covers the desktop under the menu bar
var menu_bar: MacMenuBar
var popup_layer: Control
var dialog_layer: Control
var select_layer: Control
var toast_ctl: MacToast
var logical_size := Vector2(640, 480)

var _launch_in_progress := false
var _restart_overlay: ColorRect


func shell_id() -> String:
	return "mac"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var rf := RetroFont.instance(RetroFont.WIN95)
	rf.baseline_adjust = 1  # same calibration as the Win95 shell (they share the Win95Sans instance)
	rf.x_adjust = 1
	desktop = MacDesktop.new()
	add_child(desktop)
	notes_layer = _make_layer()
	notes_layer.set_meta("auto_id", "mac.notes-layer")
	notes_layer.add_to_group("pm_auto")
	add_child(notes_layer)
	popup_layer = _make_layer()
	add_child(popup_layer)
	menu_bar = MacMenuBar.new()
	add_child(menu_bar)
	toast_ctl = MacToast.new()
	add_child(toast_ctl)
	dialog_layer = _make_layer()
	add_child(dialog_layer)
	select_layer = _make_layer()
	add_child(select_layer)
	resized.connect(_layout)


func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.focus_mode = Control.FOCUS_NONE
	return c


func _ready() -> void:
	MacTheme.refresh_from_settings()
	desktop.setup(self)
	menu_bar.popup_host = popup_layer
	menu_bar.ctx_provider = _menu_context
	menu_bar.app_items_provider = _app_menu_items
	menu_bar.command.connect(func(id: String): run_command(id, {}))
	ProgramStore.groups_changed.connect(_on_groups_changed)
	ProgramStore.settings_changed.connect(_on_settings_changed)
	UIState.launch_feedback_changed.connect(_on_launch_feedback)
	desktop.store.changed.connect(menu_bar.queue_redraw)
	_layout()


func _exit_tree() -> void:
	for pair in [[ProgramStore.groups_changed, _on_groups_changed], [ProgramStore.settings_changed, _on_settings_changed],
			[UIState.launch_feedback_changed, _on_launch_feedback]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func on_activate() -> void:
	_layout()
	if desktop.store.windows.is_empty():
		desktop.open_window("computer")


func on_scale_changed(_factor: int) -> void:
	_layout()


func _layout() -> void:
	logical_size = Vector2(ceilf(size.x), ceilf(size.y))
	if logical_size.x < 1 or logical_size.y < 1:
		return
	desktop.position = Vector2.ZERO
	desktop.size = logical_size
	menu_bar.position = Vector2.ZERO
	menu_bar.size = Vector2(logical_size.x, MacGeometry.MENU_H)
	notes_layer.position = Vector2(0, MacGeometry.MENU_H)
	notes_layer.size = Vector2(logical_size.x, maxf(1.0, logical_size.y - MacGeometry.MENU_H))
	for c in [popup_layer, dialog_layer, select_layer]:
		c.position = Vector2.ZERO
		c.size = logical_size
	toast_ctl.position = Vector2.ZERO
	toast_ctl.size = logical_size


func _on_groups_changed() -> void:
	desktop.refresh()
	menu_bar.queue_redraw()


func _on_settings_changed() -> void:
	refresh_theme()


func refresh_theme() -> void:
	MacTheme.refresh_from_settings()
	for lay in [desktop, menu_bar, toast_ctl]:
		lay.queue_redraw()
	desktop.refresh()
	for d in dialog_layer.get_children():
		d.queue_redraw()
		for c in d.find_children("*", "Control", true, false):
			c.queue_redraw()


func has_dialog() -> bool:
	return dialog_layer.get_child_count() > 0 or _any_popup() or select_layer.get_child_count() > 0


func _any_popup() -> bool:
	return popup_layer.get_child_count() > 0


# ---------------------------------------------------------------- sticky notes

## Notes float above the desktop and its folder windows, below the menu bar, menus, toasts and dialogs.
func note_layer() -> Control:
	return notes_layer


## The shell's pixel font. The paper stays light in the dark theme, so the text stays black.
func note_style() -> Dictionary:
	return {"font": MacDraw.font().font, "font_size": 11, "text_color": Color.BLACK}


## Platinum grey with a light title bar and the lavender highlight, for the fallback file chooser.
func file_dialog_palette() -> Dictionary:
	return {"face": Color8(221, 221, 221), "shadow": Color8(136, 136, 136), "select": Color8(204, 204, 255),
		"select_text": Color.BLACK, "title": Color8(221, 221, 221), "title_text": Color.BLACK}


## The StickyNote that holds `node` (the note's text box, for instance), or null.
func _note_of(node: Node) -> StickyNote:
	var n := node
	while n != null and n != notes_layer:
		if n is StickyNote:
			return n
		n = n.get_parent()
	return null


# ------------------------------------------------------------------ host events

func toggle_quick_search() -> void:
	open_find()


func open_find() -> void:
	desktop.open_window("find")
	var w := desktop.window_for("find")
	if w is MacFindWindow:
		(w as MacFindWindow).focus_query()


func on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	var target := ""
	for i in range(desktop.store.windows.size() - 1, -1, -1):
		var st: Dictionary = desktop.store.windows[i]
		var r := Rect2(st.rect.position, Vector2(st.rect.size.x, MacGeometry.SHADED_H if st.shaded else st.rect.size.y))
		if String(st.key).begins_with("g:") and r.has_point(logical_pos):
			target = String(st.key).substr(2)
			break
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


# ------------------------------------------------------------------- launching

func launch_item(item: Dictionary) -> void:
	if Notes.is_note(item):
		open_note_item(item)
		return
	toast("Starting %s…" % String(item.get("name", "")))
	var result: Dictionary = Platform.launch(MacDialogLogic.launch_payload(item))
	if not result.get("success", false):
		MacDialogs.alert(self, [{"t": String(item.get("name", "")), "w": 700}, String(result.get("error", "Cannot find '%s'." % item.get("path", "")))], "stop")
	elif ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()


## Opens a sticky note the way any item opens: through Platform.launch (the host answers note_open_requested
## with open_note). If nothing answered (no host, as in tests), the shell opens it itself. No toast, and
## "minimize on use" does not apply: the note opens on this desktop.
func open_note_item(item: Dictionary) -> StickyNote:
	var id := String(item.get("id", ""))
	Platform.launch(MacDialogLogic.launch_payload(item))
	for n in open_notes():
		if n.item_id == id:
			return n
	return open_note(id)


func toast(text: String) -> void:
	toast_ctl.show_text(text)


func _on_launch_feedback() -> void:
	var fb: Dictionary = UIState.launch_feedback
	if not fb.get("visible", false):
		return
	var text := MacDialogLogic.launch_feedback_text(fb, ProgramStore.launch_group_names())
	if text != "":
		toast(text)


func launch_buckets(buckets: Array) -> void:
	if _launch_in_progress or buckets.is_empty():
		return
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
		func(progress: Dictionary): UIState.update_launch_feedback(progress.groupNumber, progress.groupIndex),
		Callable(Platform, "launch_batch"))
	var failures := results.filter(func(r): return not r.get("success", false))
	UIState.finish_launch_feedback(failures.size())
	if ProgramStore.settings.get("minimizeOnUse", false):
		Platform.minimize_window()
	_launch_in_progress = false


# --------------------------------------------------------------- menu plumbing

func _target() -> Dictionary:
	var key := desktop.store.active_key()
	var st := desktop.store.find(key)
	if st.is_empty():
		return {}
	var sel := String(st.get("sel", ""))
	if key == "computer" and sel != "":
		return {"kind": "group", "groupId": sel, "win": key}
	if key.begins_with("g:") and sel != "":
		return {"kind": "item", "groupId": key.substr(2), "itemId": sel, "win": key}
	if key == "find":
		var w := desktop.window_for("find")
		if w is MacFindWindow:
			var r: Dictionary = (w as MacFindWindow).selected_result()
			if not r.is_empty():
				return {"kind": "item", "groupId": String(r.group.id), "itemId": String(r.item.id), "win": key}
	return {}


func _menu_context() -> Dictionary:
	var key := desktop.store.active_key()
	var st := desktop.store.find(key)
	var t := _target()
	return {
		"groups": ProgramStore.groups, "active_key": key, "view": String(st.get("view", "")),
		"selected": {"kind": String(t.get("kind", "")), "groupId": String(t.get("groupId", "")), "itemId": String(t.get("itemId", ""))},
		"buckets": LaunchGroups.collect_launch_groups(ProgramStore.groups),
		"launch_names": ProgramStore.launch_group_names(),
	}


func _app_menu_items() -> Array:
	var wins := []
	var titles := {}
	for i in range(desktop.store.windows.size() - 1, -1, -1):
		var w: Dictionary = desktop.store.windows[i]
		wins.append({"key": w.key, "icon": MacIconCatalog.texture("find" if w.key == "find" else ("volume" if w.key == "computer" else "folder"), "small")})
		titles[w.key] = MacDialogLogic.window_title(w.key, ProgramStore.groups)
	return MacMenuModel.app_menu(wins, desktop.store.active_key(), titles)


## Opens a context menu at `pos` (logical coords). `ctx` is handed back to run_command().
func show_menu(items: Array, pos: Vector2, ctx: Dictionary) -> void:
	menu_bar.close_menu()
	_close_popups()
	var m := MacPopupMenu.open(popup_layer, items, pos, {"min_width": 170})
	m.chosen.connect(func(id: String): run_command(id, ctx))


func show_item_context(group_id: String, item_id: String, pos: Vector2) -> void:
	show_menu(MacMenuModel.item_menu(), pos, {"kind": "item", "groupId": group_id, "itemId": item_id, "win": desktop.store.active_key()})


func _close_popups() -> void:
	for c in popup_layer.get_children():
		if c is MacPopupMenu:
			(c as MacPopupMenu).close()


func open_group_window(group_id: String) -> void:
	if ProgramStore.find_group(group_id).is_empty():
		return
	desktop.open_window("g:" + group_id)


func open_desktop_icon(id: String) -> void:
	if id == "computer":
		desktop.open_window("computer")
	else:
		MacDialogs.message(self, "The Trash is not available in the application launcher.", "note")


# -------------------------------------------------------------------- commands

func run_command(id: String, ctx: Dictionary) -> void:
	var t: Dictionary = ctx
	if not t.has("kind") or t.kind in ["background", "desktop"]:
		var active := _target()
		if t.get("kind", "") == "" or (t.get("kind", "") == "background" and id in ["get-info"]):
			t = active if not active.is_empty() else t
	if id.begins_with("open-group:"):
		open_group_window(id.substr(11))
	elif id.begins_with("launch-group:"):
		var n := id.substr(13).to_int()
		for b in LaunchGroups.collect_launch_groups(ProgramStore.groups):
			if b.groupNumber == n:
				launch_buckets([b])
	elif id.begins_with("view:"):
		var key := String(t.get("win", desktop.store.active_key()))
		desktop.store.set_view(key, id.substr(5))
	elif id.begins_with("raise:"):
		var k := id.substr(6)
		desktop.open_window(k)
	else:
		_run_simple(id, t)


func _run_simple(id: String, t: Dictionary) -> void:
	var kind := String(t.get("kind", ""))
	var gid := String(t.get("groupId", ""))
	var iid := String(t.get("itemId", ""))
	match id:
		"about":
			MacDialogs.about(self)
		"tools":
			request_show_launcher_tools.emit()
		"desktop-pictures":
			MacDialogs.desktop_pictures(self)
		"find":
			open_find()
		"help":
			MacDialogs.help(self)
		"new-folder":
			MacDialogs.new_folder(self)
		"new-program":
			var win := String(t.get("win", desktop.store.active_key()))
			if win.begins_with("g:"):
				MacDialogs.new_program(self, win.substr(2))
		"new-website":
			var wwin := String(t.get("win", desktop.store.active_key()))
			if wwin.begins_with("g:"):
				MacDialogs.new_website(self, wwin.substr(2))
		"new-note":
			var gid_n := MacDialogLogic.note_group(ProgramStore.groups, String(t.get("win", desktop.store.active_key())))
			if gid_n == "":
				MacDialogs.message(self, "Make a folder first: a sticky note is kept in a folder.", "caution")
			else:
				MacDialogs.new_note(self, gid_n)
		"run":
			MacDialogs.run(self)
		"open":
			match kind:
				"item":
					launch_item(ProgramStore.find_item(gid, iid))
				"group":
					open_group_window(gid)
				"desk":
					open_desktop_icon(String(t.id))
		"get-info":
			match kind:
				"item":
					MacDialogs.get_info_item(self, gid, iid)
				"group":
					MacDialogs.get_info_group(self, gid)
				"desk":
					MacDialogs.about_computer(self) if t.id == "computer" else open_desktop_icon("trash")
				"background":
					var win2 := String(t.get("win", ""))
					if win2.begins_with("g:"):
						MacDialogs.get_info_group(self, win2.substr(2))
					else:
						MacDialogs.about_computer(self)
		"rename":
			if kind == "item" or kind == "group":
				MacDialogs.rename(self, gid, iid)
		"duplicate":
			if kind == "item":
				MacDialogLogic.duplicate_item(ProgramStore, gid, iid, "copy")
		"alias":
			if kind == "item":
				MacDialogLogic.duplicate_item(ProgramStore, gid, iid, "alias")
		"trash":
			_confirm_trash(kind, gid, iid)
		"close-window":
			var k := String(t.get("win", desktop.store.active_key()))
			if k != "":
				desktop.close_window(k)
		"clean-up":
			var k2 := String(t.get("win", desktop.store.active_key()))
			MacDialogLogic.clean_up(ProgramStore, k2.substr(2) if k2.begins_with("g:") else "")
		"launch-all":
			launch_buckets(LaunchGroups.collect_launch_groups(ProgramStore.groups))
		"launch-groups":
			MacLaunchGroups.open(self)
		"export-all":
			export_all()
		"import-all":
			import_all()
		"restart":
			restart()
		"shutdown":
			MacDialogs.shutdown(self)


# ------------------------------------------------------------ export / import

## File > Export All…: the whole launcher to one JSON file (Platform picks the file).
func export_all() -> void:
	var result: Dictionary = await Platform.export_all()
	_show_transfer("export", result)


## File > Import All…: confirm, pick the file, replace everything (Platform backs up the current setup first).
## The host shows the result (Platform.import_finished), because an import that switches the desktop frees
## this shell before it could.
func import_all() -> MacDialog:
	return MacDialogs.confirm(self, DataTransfer.IMPORT_CONFIRM, func(): Platform.import_data(), "caution", "OK", "Cancel")


func _show_transfer(kind: String, result: Dictionary) -> void:
	if not is_inside_tree():
		return
	var msg := MacDialogLogic.transfer_message(kind, result)
	if String(msg.text) != "":
		MacDialogs.message(self, String(msg.text), String(msg.icon))


func _confirm_trash(kind: String, gid: String, iid: String) -> void:
	if kind == "item":
		var item := ProgramStore.find_item(gid, iid)
		if item.is_empty():
			return
		MacDialogs.confirm(self, "Remove “%s” from Program Manager?" % item.name, func(): MacDialogLogic.trash_item(ProgramStore, gid, iid))
	elif kind == "group":
		var g := ProgramStore.find_group(gid)
		if g.is_empty():
			return
		MacDialogs.confirm(self, "Remove the folder “%s” and its %s from Program Manager?" % [g.name, MacDialogLogic.plural(g.items.size(), "item")],
			func(): MacDialogLogic.trash_folder(ProgramStore, gid))


# ------------------------------------------------------------- restart / quit

func do_shutdown(choice: String) -> void:
	match choice:
		"quit":
			request_quit.emit()
		"restart":
			restart()
		"win95":
			var next := ProgramStore.settings.duplicate(true)
			next["shell"] = "win95"
			var result: Dictionary = ProgramStore.apply_settings_transaction(next)
			if result.get("success", false):
				Platform.recreate_for_shell("win95")
			else:
				MacDialogs.message(self, String(result.get("error", "The launcher could not switch shells.")), "stop")


func restart() -> void:
	desktop.store.reset()
	_restart_overlay = ColorRect.new()
	_restart_overlay.color = Color.BLACK
	_restart_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_restart_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_restart_overlay)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(_restart_overlay):
		_restart_overlay.queue_free()
		_restart_overlay = null
	if is_inside_tree():
		desktop.open_window("computer")


# ------------------------------------------------------------------ keyboard

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_release_note_focus_outside()
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.alt_pressed and k.keycode == KEY_T:
		request_show_launcher_tools.emit()
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var in_note := _note_of(focus) if focus != null else null
	if has_dialog() or _restart_overlay != null:
		if in_note != null:
			focus.release_focus()  # a modal dialog is up: keys must not type into the note behind it
		return
	var in_text := focus is LineEdit or focus is TextEdit
	if in_note != null and (k.ctrl_pressed or k.meta_pressed) and not k.alt_pressed and k.keycode == KEY_W:
		in_note.close()   # Close Window acts on the note being typed in, as in Stickies
		get_viewport().set_input_as_handled()
		return
	if (k.ctrl_pressed or k.meta_pressed) and not k.alt_pressed:
		if k.keycode == KEY_BACKSPACE or k.keycode == KEY_DELETE:
			if not in_text:
				_run_target_command("trash")
				get_viewport().set_input_as_handled()
			return
		var cmd := MacMenuModel.accelerator(k.keycode)
		if cmd != "" and not (in_text and cmd in ["find", "run", "new-folder", "open", "close-window", "get-info", "duplicate", "trash"] and false):
			_run_target_command(cmd)
			get_viewport().set_input_as_handled()
		return
	if in_text:
		return
	var view := _active_view()
	match k.keycode:
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if view != null:
				view.move_selection(Vector2i(int(k.keycode == KEY_RIGHT) - int(k.keycode == KEY_LEFT), int(k.keycode == KEY_DOWN) - int(k.keycode == KEY_UP)))
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_run_target_command("open")
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			_run_target_command("trash")
			get_viewport().set_input_as_handled()


## A press outside the note whose text has the keyboard gives the keyboard back to the desktop (arrow keys, Return
## and Delete then work on the folder windows again). The press itself is not consumed.
func _release_note_focus_outside() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var note := _note_of(focus) if focus != null else null
	if note != null and not note.get_global_rect().has_point(note.get_global_mouse_position()):
		focus.release_focus()


func _run_target_command(cmd: String) -> void:
	run_command(cmd, _target())


func _active_view() -> MacFolderView:
	var w := desktop.window_for(desktop.store.active_key())
	return (w as MacFolderWindow).view if w is MacFolderWindow else null
