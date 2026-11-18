class_name MacDialogs
extends RefCounted
## Entry points for every Mac dialog (all bind to ProgramStore through MacDialogLogic):
##   alert / confirm            untitled message boxes (icons: note | caution | stop)
##   about, help, run, find via shell, desktop_pictures, shutdown
##   new_folder, rename, new_program, new_website, new_note, get_info_item (get_info_note for a sticky note),
##   get_info_group, change_icon, browse_programs
##   (the Launch Groups manager is MacLaunchGroups)
## `shell` is the MacShell (dialog_layer, popup_layer, logical_size, launch_item, ...).

const LABEL_W := 92.0   ## right edge of the label column inside forms


# ------------------------------------------------------------------- alerts

## Untitled message box. lines: [String | {t, w: bold}].
static func alert(shell: Control, lines: Array, icon: String = "note", buttons: Array = [["OK", Callable()]]) -> MacDialog:
	var wrap_w := 252
	var labels := []
	var text_h := 0
	for ln in lines:
		var bold := false
		var t := ""
		if ln is Dictionary:
			t = String(ln.t)
			bold = int(ln.get("w", 400)) >= 700
		else:
			t = String(ln)
		var lbl := MacLabel.make(t, {"wrap": wrap_w, "bold": bold})
		labels.append(lbl)
		text_h += int(lbl.size.y) + (6 if labels.size() > 1 else 0)
	var content_h := maxi(32, text_h + 4)
	var pad := MacDialog.ALERT_PAD + MacDialog.ALERT_BORDER + 1
	var height := pad * 2 + 16 + content_h + 14 + 20 + 14
	var d := MacDialog.open(shell, "", Vector2(pad * 2 + 18 + 32 + 18 + wrap_w + 18, height), false)
	d.add(MacIconBox.make(MacIconCatalog.alert_icon(icon)), Vector2(18, 16))
	var y := 16.0 + 4.0
	for l in labels:
		d.add(l, Vector2(68, y))
		y += l.size.y + 6.0
	var btns := []
	for i in buttons.size():
		var b := MacButton.new(String(buttons[i][0]), 66)
		var cb: Callable = buttons[i][1]
		b.pressed.connect(func():
			d.close()
			if cb.is_valid():
				cb.call())
		btns.append(b)
	d.button_row(btns, 16.0 + content_h + 14.0, 18.0)
	d.set_default(btns[0])
	if buttons.size() > 1:
		d.on_cancel = func():
			d.close()
	return d


static func message(shell: Control, text: String, icon: String = "note") -> MacDialog:
	return alert(shell, [text], icon)


## Yes / No question; Yes (design order) is the default button.
static func confirm(shell: Control, text: String, on_yes: Callable, icon: String = "caution", yes_label: String = "Yes", no_label: String = "No") -> MacDialog:
	return alert(shell, [text], icon, [[yes_label, on_yes], [no_label, Callable()]])


static func about(shell: Control) -> MacDialog:
	return alert(shell, [{"t": "Program Manager", "w": 700}, "Version " + Platform.version(),
		"A retro desktop launcher inspired by Windows 3.1.", MacDialogLogic.stats_line(ProgramStore.groups, ProgramStore.launch_group_names())], "note")


static func about_computer(shell: Control) -> MacDialog:
	return alert(shell, [{"t": "Launcher HD", "w": 700}, MacDialogLogic.computer_line(ProgramStore.groups)], "note")


# --------------------------------------------------------------- form helpers

static func _titled(shell: Control, title: String, w: int, h: int) -> MacDialog:
	return MacDialog.open(shell, title, Vector2(w, h), true)


static func _field_row(d: MacDialog, label: String, y: float, field: Control, right_pad: float = 14.0) -> void:
	var l := MacLabel.make(label, {"bold": true})
	d.add(l, Vector2(LABEL_W - l.size.x, y + 4))
	d.add(field, Vector2(LABEL_W + 12, y))
	field.size = Vector2(d.body.size.x - LABEL_W - 12 - right_pad, 22)


static func _buttons(d: MacDialog, ok_label: String = "OK", extra: Array = []) -> Array:
	var ok := MacButton.new(ok_label, 66)
	var cancel := MacButton.new("Cancel", 66)
	cancel.pressed.connect(func(): d.cancel())
	var all := extra.duplicate()
	all.append_array([ok, cancel])
	d.button_row(all, d.body.size.y - 12 - 20, 18.0)
	d.set_default(ok)
	return [ok, cancel]


# --------------------------------------------------------------------- forms

static func new_folder(shell: Control) -> MacDialog:
	var d := _titled(shell, "New Folder", 340, 136)
	var f := MacTextField.new("mac.dialog.field:Name")
	f.text = MacDialogLogic.DEFAULT_FOLDER_NAME
	_field_row(d, "Name:", 16, f)
	var b := _buttons(d)
	b[0].pressed.connect(func():
		var id := MacDialogLogic.create_folder(ProgramStore, f.text)
		d.close()
		if id != "":
			shell.open_group_window(id))
	f.focus_edit()
	f.edit.select_all()
	return d


static func rename(shell: Control, group_id: String, item_id: String) -> MacDialog:
	var current := ""
	if item_id != "":
		current = String(ProgramStore.find_item(group_id, item_id).get("name", ""))
	else:
		current = String(ProgramStore.find_group(group_id).get("name", ""))
	var d := _titled(shell, "Rename", 360, 150)
	d.add(MacLabel.make("Rename “%s” to:" % current, {"wrap": 320}), Vector2(14, 14))
	var f := MacTextField.new("mac.dialog.field:Name")
	f.text = current
	_field_row(d, "Name:", 42, f)
	var b := _buttons(d)
	b[0].pressed.connect(func():
		MacDialogLogic.rename(ProgramStore, group_id, item_id, f.text)
		d.close())
	f.focus_edit()
	f.edit.select_all()
	return d


static func new_program(shell: Control, group_id: String) -> MacDialog:
	var d := _titled(shell, "New Program", 440, 218)
	d.add(MacLabel.make("Type the command line or web address of the program you want to add.", {"wrap": 400}), Vector2(14, 12))
	var cmd := MacTextField.new("mac.dialog.field:Command line")
	var name_f := MacTextField.new("mac.dialog.field:Name")
	var group_sel := MacSelect.new("mac.dialog.select:Group")
	group_sel.host = shell.select_layer
	for g in ProgramStore.groups:
		group_sel.options.append({"id": String(g.id), "label": String(g.name)})
	group_sel.select_id(group_id)
	_field_row(d, "Command line:", 44, cmd)
	_field_row(d, "Name:", 44 + 28, name_f)
	_field_row(d, "Group:", 44 + 56, group_sel)
	var browse := MacButton.new("Browse...", 66)
	var b := _buttons(d, "OK", [browse])
	browse.pressed.connect(func():
		var path: String = await Platform.select_executable()
		if path != "" and is_instance_valid(d):
			cmd.text = path
			if name_f.text.strip_edges() == "":
				name_f.text = path.replace("\\", "/").get_file().get_basename())
	b[0].pressed.connect(func():
		var gid := group_sel.current_id()
		var id := MacDialogLogic.add_program(ProgramStore, gid, name_f.text, cmd.text)
		d.close()
		if id != "":
			shell.open_group_window(gid))
	cmd.focus_edit()
	return d


static func new_website(shell: Control, group_id: String) -> MacDialog:
	var d := _titled(shell, "New Website", 440, 218)
	d.add(MacLabel.make("Type the web address of the site you want to add. The name is optional.", {"wrap": 400}), Vector2(14, 12))
	var url := MacTextField.new("mac.dialog.field:Web address")
	var name_f := MacTextField.new("mac.dialog.field:Name")
	var group_sel := MacSelect.new("mac.dialog.select:Group")
	group_sel.host = shell.select_layer
	for g in ProgramStore.groups:
		group_sel.options.append({"id": String(g.id), "label": String(g.name)})
	group_sel.select_id(group_id)
	_field_row(d, "Web address:", 44, url)
	_field_row(d, "Name:", 44 + 28, name_f)
	_field_row(d, "Group:", 44 + 56, group_sel)
	var b := _buttons(d, "OK", [])
	b[0].pressed.connect(func():
		var gid := group_sel.current_id()
		var id := Launcher.add_website(ProgramStore, gid, name_f.text, url.text)
		d.close()
		if id != "":
			shell.open_group_window(gid))
	url.focus_edit()
	return d


## File > New Note…: a sticky note (title, paper colour, folder, text) that opens on the desktop when OK is clicked.
static func new_note(shell: Control, group_id: String) -> MacDialog:
	var d := _titled(shell, "New Note", 440, 268)
	d.add(MacLabel.make("A sticky note stays in its folder and opens on the desktop. Type a title and, if you like, the text.",
		{"wrap": 400}), Vector2(14, 12))
	var title_f := MacTextField.new("mac.dialog.field:Title")
	title_f.text = MacDialogLogic.DEFAULT_NOTE_NAME
	_field_row(d, "Title:", 44, title_f)
	var color_sel := _color_row(d, shell, "Color:", 44 + 28, Notes.DEFAULT_COLOR)
	var group_sel := MacSelect.new("mac.dialog.select:Folder")
	group_sel.host = shell.select_layer
	for g in ProgramStore.groups:
		group_sel.options.append({"id": String(g.id), "label": String(g.name)})
	group_sel.select_id(group_id)
	_field_row(d, "Folder:", 44 + 56, group_sel)
	var text_l := MacLabel.make("Text:", {"bold": true})
	d.add(text_l, Vector2(LABEL_W - text_l.size.x, 44 + 84 + 4))
	var text_f := MacTextArea.new("mac.dialog.field:Text")
	d.add(text_f, Vector2(LABEL_W + 12, 44 + 84))
	text_f.size = Vector2(d.body.size.x - LABEL_W - 12 - 14, 62)
	var b := _buttons(d)
	b[0].pressed.connect(func():
		var id := MacDialogLogic.create_note(ProgramStore, group_sel.current_id(), title_f.text, text_f.text, color_sel.current_id())
		d.close()
		if id != "":
			shell.open_note(id))
	d.on_key = func(k: InputEventKey) -> bool:
		if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and text_f.has_text_focus():
			text_f.insert_newline()
			return true
		return false
	title_f.focus_edit()
	title_f.edit.select_all()
	return d


## A "Color:" row: the paper colour pop-up with a swatch of the paper after it. Returns the pop-up.
static func _color_row(d: MacDialog, shell: Control, label: String, y: float, current: String) -> MacSelect:
	var sel := MacSelect.new("mac.dialog.select:Color")
	sel.host = shell.select_layer
	sel.options = MacDialogLogic.note_color_options()
	sel.selected_index = MacDialogLogic.note_color_index(current)
	_field_row(d, label, y, sel)
	sel.size.x = 120
	var swatch := _PaperSwatch.new()
	swatch.color_id = sel.current_id()
	d.add(swatch, Vector2(sel.position.x + sel.size.x + 10, y + 1))
	sel.selected.connect(func(_i: int):
		swatch.color_id = sel.current_id()
		swatch.queue_redraw())
	return sel


## A small square of note paper (the colour the pop-up beside it picks), framed like a Stickies window.
class _PaperSwatch extends Control:
	var color_id := Notes.DEFAULT_COLOR

	func _init() -> void:
		size = Vector2(28, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		add_to_group("pm_auto")
		set_meta("auto_id", "mac.dialog.swatch:Color")

	func _draw() -> void:
		var paper: Color = Notes.COLORS.get(color_id, Notes.COLORS[Notes.DEFAULT_COLOR])
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, paper)
		draw_rect(Rect2(1, 1, size.x - 2, 4), paper.darkened(0.1))
		Px.hline(self, 1, 5, size.x - 2, paper.darkened(0.3))
		Px.outline(self, r, Color.BLACK)


static func run(shell: Control) -> MacDialog:
	var d := _titled(shell, "Run", 420, 152)
	d.add(MacLabel.make("Type the name of a program in your launcher groups, or a command to run.", {"wrap": 380}), Vector2(14, 12))
	var f := MacTextField.new("mac.dialog.field:Run")
	d.add(f, Vector2(14, 48))
	f.size = Vector2(d.body.size.x - 28, 22)
	var browse := MacButton.new("Browse...", 66)
	var b := _buttons(d, "OK", [browse])
	browse.pressed.connect(func(): browse_programs(shell, func(item: Dictionary): f.text = String(item.path)))
	b[0].pressed.connect(func():
		var item := MacDialogLogic.run_item(ProgramStore.groups, f.text)
		d.close()
		if not item.is_empty():
			shell.launch_item(item))
	f.focus_edit()
	return d


static func browse_programs(shell: Control, on_pick: Callable) -> MacDialog:
	var d := _titled(shell, "Browse", 420, 330)
	d.add(MacLabel.make("Programs in your launcher groups:", {}), Vector2(14, 12))
	var list := MacListBox.new("mac.browse")
	var rows := []
	for g in ProgramStore.groups:
		for it in g.items:
			if Notes.is_note(it):
				continue  # a note has no command line to put in Run
			rows.append({"id": String(it.id), "label": String(it.name), "sub": String(it.path), "icon": String(it.get("icon", ""))})
	list.rows = rows
	d.add(list, Vector2(14, 32))
	list.size = Vector2(d.body.size.x - 28, 220)
	var b := _buttons(d)
	var pick := func():
		for g in ProgramStore.groups:
			for it in g.items:
				if String(it.id) == list.selected_id:
					d.close()
					on_pick.call(it)
					return
		d.close()
	b[0].pressed.connect(pick)
	list.activated.connect(func(_id): pick.call())
	return d


static func help(shell: Control) -> MacDialog:
	var d := _titled(shell, "Program Manager Help", 420, 290)
	d.add(MacLabel.make("Click a topic, and then click Display.", {}), Vector2(14, 12))
	var list := MacListBox.new("mac.help")
	var rows := []
	var topics: Array = MacDialogLogic.HELP_TOPICS
	for i in topics.size():
		rows.append({"id": "t%d" % i, "label": String(topics[i][0]), "icon": "help"})
	list.rows = rows
	list.selected_id = "t0"
	d.add(list, Vector2(14, 32))
	list.size = Vector2(d.body.size.x - 28, 160)
	var display := MacButton.new("Display", 66)
	var cancel := MacButton.new("Cancel", 66)
	cancel.pressed.connect(func(): d.cancel())
	d.button_row([display, cancel], d.body.size.y - 12 - 20, 18.0)
	d.set_default(display)
	var show := func():
		var t: Array = topics[list.selected_id.substr(1).to_int()]
		d.close()
		alert(shell, [{"t": String(t[0]), "w": 700}, String(t[1])], "note")
	display.pressed.connect(show)
	list.activated.connect(func(_id): show.call())
	return d


static func desktop_pictures(shell: Control) -> MacDialog:
	var d := _titled(shell, "Desktop Pictures", 400, 214)
	d.add(MacLabel.make("Desktop color:", {}), Vector2(14, 12))
	var state := {"color": MacTheme.desk_override if MacTheme.desk_override != "" else MacTheme.DEFAULT_DESK, "dark": MacTheme.dark}
	var swatches := []
	for i in MacTheme.DESK_PALETTE.size():
		var s := _Swatch.new()
		s.color = Color(String(MacTheme.DESK_PALETTE[i][0]))
		s.hex = String(MacTheme.DESK_PALETTE[i][0])
		s.label = String(MacTheme.DESK_PALETTE[i][1])
		s.state = state
		s.siblings = swatches
		swatches.append(s)
		d.add(s, Vector2(18 + (i % 3) * 112, 34 + (i / 3) * 40))
	var dark := MacCheckBox.new("Dark mode", state.dark)
	dark.toggled.connect(func(on: bool): state.dark = on)
	d.add(dark, Vector2(18, 118))
	var b := _buttons(d)
	b[0].pressed.connect(func():
		MacTheme.desk_override = "" if String(state.color) == MacTheme.DEFAULT_DESK else String(state.color)
		d.close()
		ProgramStore.update_settings({"theme": "dark" if state.dark else "light"})
		shell.refresh_theme())
	return d


class _Swatch extends Control:
	var color := Color.WHITE
	var hex := ""
	var label := ""
	var state: Dictionary
	var siblings: Array

	func _init() -> void:
		size = Vector2(92, 28)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		add_to_group("pm_auto")

	func _ready() -> void:
		set_meta("auto_id", "mac.swatch:" + label)

	func _draw() -> void:
		if String(state.color).to_lower() == hex.to_lower():
			Px.outline(self, Rect2(Vector2.ZERO, size), MacTheme.b("ffffff"))
			Px.outline(self, Rect2(Vector2.ZERO, size).grow(1), MacTheme.b("444444"))
			Px.outline(self, Rect2(Vector2.ZERO, size).grow(2), MacTheme.b("444444"))
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(r, color)
		Px.outline(self, r, Color.BLACK)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			state.color = hex
			for s in siblings:
				s.queue_redraw()
			accept_event()


static func shutdown(shell: Control) -> MacDialog:
	var d := _titled(shell, "Shut Down", 380, 230)
	d.add(MacIconBox.make("stop"), Vector2(14, 14))
	d.add(MacLabel.make("What do you want Program Manager to do?", {"wrap": 280}), Vector2(60, 14))
	var list := MacListBox.new("mac.shutdown")
	list.rows = [{"id": "quit", "label": "Close Program Manager"}, {"id": "restart", "label": "Restart Program Manager"},
		{"id": "win95", "label": "Switch to the Windows 95 shell"}]
	list.selected_id = "quit"
	d.add(list, Vector2(60, 50))
	list.size = Vector2(d.body.size.x - 60 - 18, 62)
	var b := _buttons(d, "OK")
	b[0].pressed.connect(func():
		var choice := list.selected_id
		d.close()
		shell.do_shutdown(choice))
	return d


# --------------------------------------------------------------- change icon

static func change_icon(shell: Control, current: String, on_pick: Callable) -> MacDialog:
	var d := _titled(shell, "Change Icon", 380, 250)
	d.add(MacLabel.make("Select an icon from the list below:", {}), Vector2(14, 12))
	var grid := MacListBox.new("mac.icon-choice")
	grid.grid = true
	var rows := []
	for id in MacDialogLogic.ICON_CHOICES:
		rows.append({"id": id, "label": id, "icon": id})
	grid.rows = rows
	grid.selected_id = current if MacDialogLogic.ICON_CHOICES.has(current) else ""
	d.add(grid, Vector2(14, 32))
	grid.size = Vector2(d.body.size.x - 28, 120)
	var browse := MacButton.new("Browse...", 66)
	var b := _buttons(d, "OK", [browse])
	var pick := func():
		d.close()
		if grid.selected_id != "":
			on_pick.call(grid.selected_id)
	b[0].pressed.connect(pick)
	grid.activated.connect(func(_id): pick.call())
	browse.pressed.connect(func():
		var path: String = await Platform.select_icon()
		if path != "" and is_instance_valid(d):
			d.close()
			on_pick.call(path))
	return d


# ------------------------------------------------------------------ Get Info

static func get_info_group(shell: Control, group_id: String) -> MacDialog:
	var g := ProgramStore.find_group(group_id)
	if g.is_empty():
		return message(shell, "The folder no longer exists.", "caution")
	var d := _titled(shell, "%s Info" % g.name, 360, 230)
	d.add(MacIconBox.make("folder"), Vector2(14, 14))
	var name_f := MacTextField.new("mac.dialog.field:Name")
	d.add(name_f, Vector2(60, 19))
	name_f.size = Vector2(d.body.size.x - 60 - 14, 22)
	name_f.text = String(g.name)
	d.add(_Rule.new(d.body.size.x - 28), Vector2(14, 56))
	var in_batch := 0
	for it in g.items:
		if int(it.get("launchGroup", 0)) > 0:
			in_batch += 1
	_static_row(d, "Contains:", MacDialogLogic.plural(g.items.size(), "item"), 72)
	_static_row(d, "Launch groups:", "%d in launch groups" % in_batch, 98)
	var b := _buttons(d)
	b[0].pressed.connect(func():
		if MacDialogLogic.rename(ProgramStore, group_id, "", name_f.text):
			d.close()
		else:
			message(shell, "Enter a name for this folder.", "caution"))
	name_f.focus_edit()
	return d


static func get_info_item(shell: Control, group_id: String, item_id: String) -> MacDialog:
	var item := ProgramStore.find_item(group_id, item_id)
	if item.is_empty():
		return message(shell, "The item no longer exists.", "caution")
	if Notes.is_note(item):
		return get_info_note(shell, group_id, item_id)
	var state := {"icon": String(item.get("icon", "")), "group": group_id}
	var d := _titled(shell, "%s Info" % item.name, 420, 392)
	var icon_box := MacIconBox.make(state.icon)
	d.add(icon_box, Vector2(14, 12))
	var name_f := MacTextField.new("mac.dialog.field:Name")
	name_f.text = String(item.name)
	d.add(name_f, Vector2(60, 17))
	name_f.size = Vector2(d.body.size.x - 60 - 14, 22)
	d.add(_Rule.new(d.body.size.x - 28), Vector2(14, 54))
	var y := 66.0
	_static_row(d, "Kind:", MacDialogLogic.kind_of(item), y)
	y += 26
	var where := MacSelect.new("mac.dialog.select:Where")
	where.host = shell.select_layer
	for g in ProgramStore.groups:
		where.options.append({"id": String(g.id), "label": String(g.name)})
	where.select_id(group_id)
	_field_row(d, "Where:", y, where)
	y += 26
	var path_f := MacTextField.new("mac.dialog.field:Target")
	path_f.text = String(item.path)
	_field_row(d, "Target:", y, path_f)
	y += 26
	var dir_f := MacTextField.new("mac.dialog.field:Start in")
	dir_f.text = String(item.get("workingDir", ""))
	_field_row(d, "Start in:", y, dir_f)
	y += 26
	var args_f := MacTextField.new("mac.dialog.field:Arguments")
	args_f.text = String(item.get("arguments", ""))
	_field_row(d, "Arguments:", y, args_f)
	y += 26
	var env_f := MacTextField.new("mac.dialog.field:Environment")
	env_f.text = String(item.get("environment", ""))
	_field_row(d, "Environment:", y, env_f)
	y += 26
	var lg := MacSelect.new("mac.dialog.select:Launch group")
	lg.host = shell.select_layer
	lg.options = MacDialogLogic.launch_group_options(ProgramStore.launch_group_names(), int(item.get("launchGroup", 0)))
	lg.select_id(str(int(item.get("launchGroup", 0))))
	_field_row(d, "Launch group:", y, lg)
	y += 26
	var key_f := MacTextField.new("mac.dialog.field:Shortcut key")
	key_f.text = String(item.get("shortcutKey", ""))
	_field_row(d, "Shortcut key:", y, key_f)
	y += 26
	var run_sel := MacSelect.new("mac.dialog.select:Open as")
	run_sel.host = shell.select_layer
	for i in MacDialogLogic.RUN_MODES.size():
		run_sel.options.append({"id": MacDialogLogic.RUN_MODES[i], "label": MacDialogLogic.RUN_MODE_LABELS[i]})
	run_sel.select_id(String(item.get("runMode", "normal")))
	_field_row(d, "Open as:", y, run_sel)
	run_sel.size.x = minf(run_sel.size.x, 200)
	var change := MacButton.new("Change Icon...", 90)
	var b := _buttons(d, "OK", [change])
	change.pressed.connect(func():
		change_icon(shell, String(state.icon), func(id: String):
			state.icon = id
			icon_box.icon = id
			icon_box.queue_redraw()))
	b[0].pressed.connect(func():
		var result := MacDialogLogic.apply_item_info(ProgramStore, group_id, item_id, {
			"name": name_f.text, "path": path_f.text, "workingDir": dir_f.text, "arguments": args_f.text,
			"environment": env_f.text, "runMode": run_sel.current_id(), "launchGroup": lg.current_id(),
			"shortcutKey": key_f.text, "icon": state.icon, "groupId": where.current_id()})
		if result.ok:
			d.close()
		else:
			message(shell, String(result.error), "caution"))
	name_f.focus_edit()
	name_f.edit.select_all()
	return d


## Get Info for a sticky note: title, Kind, Where, paper Color, Launch group and Change Icon (a note has no target,
## start-in folder, arguments, environment, shortcut key or window mode).
static func get_info_note(shell: Control, group_id: String, item_id: String) -> MacDialog:
	var item := ProgramStore.find_item(group_id, item_id)
	if item.is_empty():
		return message(shell, "The item no longer exists.", "caution")
	var state := {"icon": String(item.get("icon", ""))}
	var d := _titled(shell, "%s Info" % item.name, 420, 262)
	var icon_box := MacIconBox.make(state.icon)
	d.add(icon_box, Vector2(14, 12))
	var name_f := MacTextField.new("mac.dialog.field:Name")
	name_f.text = String(item.name)
	d.add(name_f, Vector2(60, 17))
	name_f.size = Vector2(d.body.size.x - 60 - 14, 22)
	d.add(_Rule.new(d.body.size.x - 28), Vector2(14, 54))
	var y := 66.0
	_static_row(d, "Kind:", MacDialogLogic.kind_of(item), y)
	y += 26
	var where := MacSelect.new("mac.dialog.select:Where")
	where.host = shell.select_layer
	for g in ProgramStore.groups:
		where.options.append({"id": String(g.id), "label": String(g.name)})
	where.select_id(group_id)
	_field_row(d, "Where:", y, where)
	y += 26
	var color_sel := _color_row(d, shell, "Color:", y, String(item.get("noteColor", Notes.DEFAULT_COLOR)))
	y += 26
	var lg := MacSelect.new("mac.dialog.select:Launch group")
	lg.host = shell.select_layer
	lg.options = MacDialogLogic.launch_group_options(ProgramStore.launch_group_names(), int(item.get("launchGroup", 0)))
	lg.select_id(str(int(item.get("launchGroup", 0))))
	_field_row(d, "Launch group:", y, lg)
	var change := MacButton.new("Change Icon...", 90)
	var b := _buttons(d, "OK", [change])
	change.pressed.connect(func():
		change_icon(shell, String(state.icon), func(id: String):
			state.icon = id
			icon_box.icon = id
			icon_box.queue_redraw()))
	b[0].pressed.connect(func():
		var result := MacDialogLogic.apply_note_info(ProgramStore, group_id, item_id, {
			"name": name_f.text, "noteColor": color_sel.current_id(), "launchGroup": lg.current_id(),
			"icon": state.icon, "groupId": where.current_id()})
		if result.ok:
			d.close()
		else:
			message(shell, String(result.error), "caution"))
	name_f.focus_edit()
	name_f.edit.select_all()
	return d


static func _static_row(d: MacDialog, label: String, value: String, y: float) -> void:
	var l := MacLabel.make(label, {"bold": true})
	d.add(l, Vector2(LABEL_W - l.size.x, y + 4))
	d.add(MacLabel.make(value, {}), Vector2(LABEL_W + 12, y + 4))


class _Rule extends Control:
	func _init(w: float = 100) -> void:
		size = Vector2(w, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		MacDraw.separator(self, 0, 0, size.x)
