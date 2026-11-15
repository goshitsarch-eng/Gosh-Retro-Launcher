class_name BeShell
extends ShellBase
## The BeOS-style shell (design: isBe markup + script): a desktop of folder icons, tabbed yellow folder windows, a
## Deskbar on the right edge, menus and dialogs, all drawn in logical pixels (the host owns the integer scale).
##
## Layers (back to front): desktop (windows inside) < deskbar < menu_layer (menu-bar dropdowns, context and
## Deskbar menus) < dialog_layer < popup_layer (select lists) < toast.
## Window geometry and selection are session-only; folders, items and settings.theme live in the ProgramStore.

var windows: BeWindowStore
var desktop: BeDesktop
var deskbar: BeDeskbar
var menu_layer: Control
var dialog_layer: Control
var popup_layer: Control
var toast: BeToast

var find_state := {"q": "", "where": "all", "type": "all", "ran": false}
var selection := {"key": "", "id": ""}   ## selected entry inside a window ("find" for the Find window)
var desk_sel := ""                       ## selected desktop icon id ("computer" or "g:<groupId>")
var desktop_color := ""                  ## session-only Backgrounds choice ("" = themed default)


func shell_id() -> String:
	return "be"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth 64px art; the project default (nearest) is for the pixel shells
	add_to_group("be_shell")
	windows = BeWindowStore.new()
	desktop = BeDesktop.new()
	add_child(desktop)
	deskbar = BeDeskbar.new()
	add_child(deskbar)
	menu_layer = _make_layer()
	dialog_layer = _make_layer()
	popup_layer = _make_layer()
	toast = BeToast.new()
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)


func _make_layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _ready() -> void:
	BeUi.shell = self
	BeUi.popup_layer = popup_layer
	BeTheme.dark = BeTheme.is_dark(ProgramStore.settings)
	desktop.setup(self)
	deskbar.setup(self)
	windows.changed.connect(_on_windows_changed)
	ProgramStore.groups_changed.connect(_on_groups_changed)
	ProgramStore.settings_changed.connect(_on_settings_changed)
	UIState.launch_feedback_changed.connect(_on_launch_feedback)
	BeUi.auto_id(self, "be.shell")
	_layout()
	if windows.order.is_empty():
		windows.open(BeWindowStore.COMPUTER)  # the design opens Program Manager on first show


func _exit_tree() -> void:
	if BeUi.shell == self:
		BeUi.shell = null
		BeUi.popup_layer = null
	for pair in [[ProgramStore.groups_changed, _on_groups_changed], [ProgramStore.settings_changed, _on_settings_changed],
			[UIState.launch_feedback_changed, _on_launch_feedback]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func on_activate() -> void:
	_layout()


func on_scale_changed(_factor: int) -> void:
	_layout()


func _layout() -> void:
	desktop.position = Vector2.ZERO
	desktop.size = size
	windows.view_size = size
	deskbar.refresh()
	desktop.sync()


# --------------------------------------------------------------- store events

func _on_windows_changed() -> void:
	desktop.sync()
	deskbar.refresh()


func _on_groups_changed() -> void:
	var ids := []
	for g in ProgramStore.groups:
		ids.append(String(g.id))
	windows.sync_groups(ids)
	if selection.key != "":
		_validate_selection()
	if desk_sel.begins_with("g:") and not ids.has(desk_sel.substr(2)):
		desk_sel = ""
	desktop.sync()
	deskbar.refresh()


func _validate_selection() -> void:
	var still := false
	if selection.key == BeWindowStore.FIND:
		for g in ProgramStore.groups:
			for it in g.items:
				if it.id == selection.id:
					still = true
	else:
		for e in BeDialogLogic.entries_for(String(selection.key), ProgramStore.groups):
			if e.id == selection.id:
				still = true
	if not still:
		selection = {"key": "", "id": ""}


func _on_settings_changed() -> void:
	var dark := BeTheme.is_dark(ProgramStore.settings)
	if dark != BeTheme.dark:
		BeTheme.dark = dark
		_redraw_tree(self)


func _redraw_tree(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	if n is BeWindow:
		(n as BeWindow).refresh()
	for c in n.get_children():
		_redraw_tree(c)


func _on_launch_feedback() -> void:
	var text := BeDialogLogic.feedback_text(UIState.launch_feedback)
	if text == "":
		toast.hide_toast()
	else:
		toast.show_text(text, 4.0)


# ----------------------------------------------------------------- selection

func selected_id_in(key: String) -> String:
	return String(selection.id) if selection.key == key else ""


func select_entry(key: String, id: String) -> void:
	desk_sel = ""
	selection = {"key": key, "id": id}
	_refresh_windows()


func select_desktop_icon(id: String) -> void:
	selection = {"key": "", "id": ""}
	desk_sel = id
	_refresh_windows()
	desktop.queue_redraw()


func clear_selection() -> void:
	selection = {"key": "", "id": ""}
	desk_sel = ""
	_refresh_windows()
	desktop.queue_redraw()


func _refresh_windows() -> void:
	for key in windows.order:
		var w := desktop.window_for(key)
		if w != null:
			w.refresh()


# -------------------------------------------------------------------- windows

func raise_window(key: String) -> void:
	close_all_menus()
	windows.raise(key)


func close_window(key: String) -> void:
	if selection.key == key:
		selection = {"key": "", "id": ""}
	windows.close(key)


func open_group_window(gid: String) -> void:
	if ProgramStore.find_group(gid).is_empty():
		return
	close_all_menus()
	windows.open(BeWindowStore.group_key(gid))


func open_computer() -> void:
	close_all_menus()
	windows.open(BeWindowStore.COMPUTER)


func open_find() -> void:
	close_all_menus()
	windows.open(BeWindowStore.FIND)
	var w := desktop.window_for(BeWindowStore.FIND)
	if w != null and w.find_view != null:
		w.find_view.focus_query.call_deferred()


func toggle_quick_search() -> void:
	if windows.has(BeWindowStore.FIND) and windows.active() == BeWindowStore.FIND:
		close_window(BeWindowStore.FIND)
	else:
		open_find()


func close_all_menus() -> void:
	for layer in [menu_layer]:
		for c in layer.get_children():
			if c is BePopup:
				(c as BePopup).close()


func open_menu(rows: Array, at: Vector2, opts: Dictionary = {}) -> BePopup:
	close_all_menus()
	var o := {"min_w": 190.0, "item_h": BeGeometry.CTX_ITEM_H, "pad_left": 26.0}
	o.merge(opts, true)
	var p := BePopup.open(menu_layer, rows, at, o)
	p.picked.connect(func(row): do_action(String(row.action), row.args))
	return p


func open_desktop_icon(id: String) -> void:
	if id == "computer":
		open_computer()
	elif id.begins_with("g:"):
		open_group_window(id.substr(2))


## Double-click / Open on an entry of a window.
func open_entry(key: String, id: String) -> void:
	if key == BeWindowStore.COMPUTER:
		open_group_window(id)
		return
	var gid := BeWindowStore.group_id_of(key)
	var item: Dictionary = ProgramStore.find_item(gid, id)
	if not item.is_empty():
		launch_item(item)


func open_entry_menu(key: String, id: String, at: Vector2, find_group_id: String = "") -> void:
	if key == BeWindowStore.COMPUTER:
		open_menu(BeMenuModel.group_menu(id), at)
	else:
		var gid := find_group_id if key == BeWindowStore.FIND else BeWindowStore.group_id_of(key)
		open_menu(BeMenuModel.item_menu(gid, id), at)


func open_background_menu(key: String, at: Vector2) -> void:
	var e: Dictionary = windows.get_entry(key)
	open_menu(BeMenuModel.folder_background_menu(key, key == BeWindowStore.COMPUTER, String(e.get("view", "large"))), at)


# ------------------------------------------------------------------- commands

func do_action(action: String, args: Dictionary) -> void:
	close_all_menus()
	var gid := String(args.get("gid", ""))
	var iid := String(args.get("iid", ""))
	var key := String(args.get("key", ""))
	match action:
		"item.open":
			var it: Dictionary = ProgramStore.find_item(gid, iid)
			if not it.is_empty():
				launch_item(it)
		"item.info":
			BeDialogs.item_info(self, gid, iid)
		"item.rename":
			BeDialogs.rename(self, gid, iid)
		"item.duplicate":
			BeDialogLogic.duplicate_item(ProgramStore, gid, iid)
		"item.trash":
			BeDialogs.confirm_trash_item(self, gid, iid)
		"group.open":
			open_group_window(gid)
		"group.info":
			BeDialogs.group_info(self, gid)
		"group.rename":
			BeDialogs.rename(self, gid)
		"group.trash":
			BeDialogs.confirm_trash_group(self, gid)
		"window.show":
			windows.raise(key)
		"window.hide":
			windows.hide(key)
		"window.zoom":
			windows.toggle_zoom(key)
		"window.close":
			close_window(key)
		"window.view":
			windows.set_view(key, String(args.get("view", "large")))
		"window.cleanup":
			if key == BeWindowStore.COMPUTER:
				BeDialogLogic.sort_groups(ProgramStore)
			else:
				BeDialogLogic.sort_items(ProgramStore, BeWindowStore.group_id_of(key))
		"window.refresh":
			desktop.sync()
		"desktop.cleanup":
			desktop.sync()
		"folder.new":
			BeDialogs.new_folder(self)
		"program.new":
			BeDialogs.new_program(self, BeWindowStore.group_id_of(key))
		"website.new":
			BeDialogs.new_website(self, BeWindowStore.group_id_of(key))
		"find.open":
			open_find()
		"tools.open":
			request_show_launcher_tools.emit()
		"backgrounds.open":
			BeDialogs.backgrounds(self)
		"help.open":
			BeDialogs.help(self)
		"about.open":
			BeDialogs.about(self)
		"run.open":
			BeDialogs.run(self)
		"computer.open":
			open_computer()
		"session.restart":
			restart_session()
		"session.shutdown":
			BeDialogs.shutdown(self)


func set_desktop_color(color: String) -> void:
	desktop_color = color
	desktop.queue_redraw()


## Restart: closes every window and returns to the first-show state (Program Manager open).
func restart_session() -> void:
	for c in dialog_layer.get_children():
		if c is BeDialog:
			(c as BeDialog).close()
	close_all_menus()
	selection = {"key": "", "id": ""}
	desk_sel = ""
	windows.close_all()
	windows.open(BeWindowStore.COMPUTER)


func on_item_trashed(_gid: String, iid: String) -> void:
	if selection.id == iid:
		selection = {"key": "", "id": ""}


# ------------------------------------------------------------------ launching

func launch_item(item: Dictionary) -> void:
	close_all_menus()
	var result: Dictionary = Platform.launch(item)
	if not bool(result.get("success", false)):
		BeDialogs.message(self, [{"t": String(item.name), "w": 700}, BeDialogLogic.launch_error(result, item)], "warning")
		return
	toast.show_text("Starting %s…" % item.name)
	if bool(ProgramStore.settings.get("minimizeOnUse", false)):
		Platform.minimize_window()


# ------------------------------------------------------------------ host events

func on_files_dropped(files: PackedStringArray, logical_pos: Vector2) -> void:
	var target := ""
	for i in range(windows.z.size() - 1, -1, -1):
		var key: String = windows.z[i]
		if not BeWindowStore.is_group_key(key) or windows.entries[key].hidden:
			continue
		if windows.rect_of(key).has_point(logical_pos):
			target = BeWindowStore.group_id_of(key)
			break
	if target == "":
		return
	for path in files:
		var info: Dictionary = Platform.get_app_info(path)
		ProgramStore.add_item(target, {
			"name": info.get("name", path.get_file().get_basename()),
			"path": info.get("path", path),
			"icon": info.get("icon", "default"),
			"workingDir": info.get("workingDir", ""),
		})


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.alt_pressed and k.keycode == KEY_T:
		request_show_launcher_tools.emit()
		get_viewport().set_input_as_handled()
		return
	if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and dialog_layer.get_child_count() == 0 \
			and menu_layer.get_child_count() == 0 and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if selection.key != "":
			open_entry(String(selection.key), String(selection.id)) if selection.key != BeWindowStore.FIND else _open_find_selection()
			get_viewport().set_input_as_handled()
		elif desk_sel != "":
			open_desktop_icon(desk_sel)
			get_viewport().set_input_as_handled()


func _open_find_selection() -> void:
	for g in ProgramStore.groups:
		for it in g.items:
			if it.id == selection.id:
				launch_item(it)
				return
