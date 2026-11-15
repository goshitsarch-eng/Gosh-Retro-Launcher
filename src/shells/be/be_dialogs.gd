class_name BeDialogs
extends RefCounted
## Entry points for every Be dialog (design: dialog markup + formDef + message()). `shell` is the BeShell; dialogs are
## added to shell.dialog_layer. Data changes go through ProgramStore via BeDialogLogic.

const SWATCHES := [["#336698", "Be Blue"], ["#2f4f6f", "Night"], ["#3f6f5f", "Moss"], ["#6f4f3a", "Clay"],
	["#5a5a6a", "Graphite"], ["#1e2e44", "Ink"]]
const TOPICS := [
	["Starting programs", "Double-click an icon in a folder window to start it. Use the Deskbar menu to open Find, Run and Launcher Tools."],
	["Creating folders and programs", "Right-click the desktop and choose New Folder, or open a folder and choose Add Program… from its File menu. You can also drag files into a folder window to add them quickly."],
	["Batch launching", "Give items a batch group number from 1 to 8 in Get Info or Launcher Tools. Then use Launch Group or Launch All to start them with the delay you set."],
	["Importing .GRP files", "Open Launcher Tools and choose Import .GRP to bring in an original Windows 3.x program group. Export .GRP writes one back out."],
	["Switching shells", "Press Ctrl+Alt+T to open Launcher Tools, pick a shell under Appearance, and click Apply."],
	["Backups and profiles", "Settings are saved automatically. The newest 12 automatic restore points are kept, and you can create manual restore points and named workspace profiles in Launcher Tools."],
]


static func _layer(shell: Control) -> Control:
	return shell.dialog_layer


# --------------------------------------------------------------- messages

## OK box (design `message()`): lines = [String | {t, w}], icon = catalog id ("information", "question", "warning", ...).
static func message(shell: Control, lines: Array, icon: String = "information", on_confirm: Callable = Callable()) -> BeDialog:
	var d := BeDialog.open(_layer(shell), "", 460, false, true, "be.dialog.message")
	d.icon_tex = BeIconCatalog.texture(icon)
	_text_lines(d, lines)
	if on_confirm.is_valid():
		d.set_buttons([{"label": "Yes", "default": true, "cb": on_confirm}, {"label": "No"}])
	else:
		d.set_buttons([{"label": "OK", "default": true}])
	d.finish()
	return d


static func _text_lines(d: BeDialog, lines: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in lines:
		var t := String(l) if l is String else String(l.t)
		var b: bool = (l is Dictionary and int(l.get("w", 400)) >= 700)
		box.add_child(BeLabel.make(t, b, d.content_width()))
	d.add_row(box)


static func about(shell: Control) -> BeDialog:
	return message(shell, [{"t": "Program Manager", "w": 700}, "Version %s" % Platform.version(),
		"A retro desktop launcher inspired by Windows 3.1."], "information")


static func confirm_trash_item(shell: Control, gid: String, iid: String) -> void:
	var it: Dictionary = ProgramStore.find_item(gid, iid)
	if it.is_empty():
		return
	message(shell, ["Remove “%s” from Program Manager?" % it.name], "question", func():
		BeDialogLogic.trash_item(ProgramStore, gid, iid)
		shell.on_item_trashed(gid, iid)
		return false)


static func confirm_trash_group(shell: Control, gid: String) -> void:
	var g: Dictionary = ProgramStore.find_group(gid)
	if g.is_empty():
		return
	message(shell, ["Remove the folder “%s” and its %d items from Program Manager?" % [g.name, g.items.size()]], "question", func():
		BeDialogLogic.trash_group(ProgramStore, gid)
		return false)


static func shutdown(shell: Control) -> void:
	var d := BeDialog.open(_layer(shell), "", 480, false, true, "be.dialog.shutdown")
	d.icon_tex = BeIconCatalog.texture("question")
	_text_lines(d, ["Are you sure you want to shut down Program Manager?"])
	d.set_buttons([
		{"label": "Restart", "cb": func(): shell.restart_session(); return false},
		{"label": "Cancel"},
		{"label": "Shut Down", "default": true, "cb": func(): shell.request_quit.emit(); return false}])
	d.finish()


# ------------------------------------------------------------------ forms

static func _form(shell: Control, title: String, width: int, auto_id: String) -> BeDialog:
	return BeDialog.open(_layer(shell), title, width, true, false, auto_id)


static func rename(shell: Control, gid: String, iid: String = "") -> void:
	var cur := ""
	if iid != "":
		cur = String(ProgramStore.find_item(gid, iid).get("name", ""))
	else:
		cur = String(ProgramStore.find_group(gid).get("name", ""))
	if cur == "" and iid == "":
		return
	var d := _form(shell, "Edit Name", 480, "be.dialog.rename")
	d.add_row(BeLabel.make("Rename “%s” to:" % cur, false, d.content_width()))
	var f := BeField.make(cur, "be.dialog.field:name")
	d.row_grid([["Name:", f]], 110)
	var ok := func():
		if iid != "":
			BeDialogLogic.rename_item(ProgramStore, gid, iid, f.text)
		else:
			BeDialogLogic.rename_group(ProgramStore, gid, f.text)
		return false
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": ok}, {"label": "Cancel"}])
	d.finish()
	f.grab_text_focus.call_deferred()


static func new_folder(shell: Control) -> void:
	var d := _form(shell, "New Folder", 480, "be.dialog.new-folder")
	var f := BeField.make("New Folder", "be.dialog.field:name")
	d.row_grid([["Name:", f]], 110)
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		var id := BeDialogLogic.create_folder(ProgramStore, f.text)
		if id != "":
			shell.open_group_window.call_deferred(id)
		return false}, {"label": "Cancel"}])
	d.finish()
	f.grab_text_focus.call_deferred()


static func group_info(shell: Control, gid: String) -> void:
	var g: Dictionary = ProgramStore.find_group(gid)
	if g.is_empty():
		return
	var stats := BeDialogLogic.group_stats(g)
	var d := _form(shell, "%s info" % g.name, 480, "be.dialog.group-info")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(BeLabel.make("Contains: %s" % BeDialogLogic.plural(stats.items, "item", "items"), false, d.content_width()))
	box.add_child(BeLabel.make("In launch groups: %d" % stats.batched, false, d.content_width()))
	d.add_row(box)
	var f := BeField.make(String(g.name), "be.dialog.field:name")
	d.row_grid([["Name:", f]], 110)
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		BeDialogLogic.rename_group(ProgramStore, gid, f.text)
		return false}, {"label": "Cancel"}])
	d.finish()


static func item_info(shell: Control, gid: String, iid: String) -> void:
	var item: Dictionary = ProgramStore.find_item(gid, iid)
	if item.is_empty():
		return
	var v := BeDialogLogic.info_fields(item, gid)
	var d := _form(shell, "%s info" % item.name, 480, "be.dialog.item-info")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_box := BeIconBox.new()
	icon_box.icon = String(v.icon)
	icon_box.item_name = String(v.name)
	head.add_child(icon_box)
	var name_f := BeField.make(String(v.name), "be.dialog.field:name", true)
	head.add_child(name_f)
	d.add_row(head)
	var fields := {
		"path": BeField.make(String(v.path), "be.dialog.field:path"),
		"workingDir": BeField.make(String(v.workingDir), "be.dialog.field:workingDir"),
		"arguments": BeField.make(String(v.arguments), "be.dialog.field:arguments"),
		"environment": BeField.make(String(v.environment), "be.dialog.field:environment"),
		"shortcutKey": BeField.make(String(v.shortcutKey), "be.dialog.field:shortcutKey"),
	}
	var batch_opts := [["0", "None"]]
	for n in range(1, BeDialogLogic.MAX_LAUNCH_GROUP + 1):
		batch_opts.append([str(n), "Group %d" % n])
	var batch := BeSelect.make(batch_opts, str(v.launchGroup), "be.dialog.select:launchGroup", 140)
	var run_opts := []
	for m in BeDialogLogic.RUN_MODE_LABELS:
		run_opts.append([m[0], m[1]])
	var run_mode := BeSelect.make(run_opts, String(v.runMode), "be.dialog.select:runMode", 160)
	var group_opts := []
	for g in ProgramStore.groups:
		group_opts.append([String(g.id), String(g.name)])
	var group_sel := BeSelect.make(group_opts, gid, "be.dialog.select:group", 160)
	var grid := d.row_grid([
		["Kind:", BeLabel.make(BeDialogLogic.kind_of(item))],
		["Group:", group_sel],
		["Target:", fields.path],
		["Start in:", fields.workingDir],
		["Arguments:", fields.arguments],
		["Environment:", fields.environment],
		["Shortcut key:", fields.shortcutKey],
		["Batch group:", batch],
		["Run:", run_mode]], 100, Vector2(12, 10), true)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in grid.get_children():
		if c is BeSelect:
			c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var state := {"icon": String(v.icon), "gid": gid}
	var apply := func() -> bool:
		var res := BeDialogLogic.apply_item_info(ProgramStore, String(state.gid), iid, {
			"name": name_f.text, "path": fields.path.text, "workingDir": fields.workingDir.text,
			"arguments": fields.arguments.text, "environment": fields.environment.text,
			"shortcutKey": fields.shortcutKey.text, "runMode": run_mode.value, "launchGroup": int(batch.value),
			"icon": state.icon, "groupId": group_sel.value})
		if res.ok:
			state.gid = res.groupId
		return bool(res.ok)
	d.set_buttons([
		{"label": "Change Icon...", "cb": func():
			change_icon(shell, String(state.icon), func(id: String):
				state.icon = id
				icon_box.icon = id)
			return true},
		{"label": "OK", "default": true, "cb": func(): return not apply.call()},
		{"label": "Cancel"},
		{"label": "Apply", "cb": func():
			apply.call()
			return true}])
	d.finish()


static func new_program(shell: Control, gid: String) -> void:
	if ProgramStore.groups.is_empty():
		return
	var d := _form(shell, "New Program", 520, "be.dialog.new-program")
	d.add_row(BeLabel.make("Type the command line or web address of the program you want to add.", false, d.content_width()))
	var cmd := BeField.make("", "be.dialog.field:path")
	var name_f := BeField.make("", "be.dialog.field:name")
	var opts := []
	for g in ProgramStore.groups:
		opts.append([String(g.id), String(g.name)])
	var sel := BeSelect.make(opts, gid if gid != "" else String(ProgramStore.groups[0].id), "be.dialog.select:group", 160)
	var g := d.row_grid([["Command line:", cmd], ["Name:", name_f], ["Group:", sel]], 110)
	for c in g.get_children():
		if c is BeSelect:
			c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cmd.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([
		{"label": "OK", "default": true, "cb": func():
			BeDialogLogic.new_program(ProgramStore, sel.value, name_f.text, cmd.text)
			return false},
		{"label": "Cancel"},
		{"label": "Browse...", "cb": func():
			browse_into(cmd, name_f)
			return true}])
	d.finish()
	cmd.grab_text_focus.call_deferred()


static func new_website(shell: Control, gid: String) -> void:
	if ProgramStore.groups.is_empty():
		return
	var d := _form(shell, "New Website", 520, "be.dialog.new-website")
	d.add_row(BeLabel.make("Type the web address of the site you want to add. The name is optional.", false, d.content_width()))
	var url := BeField.make("", "be.dialog.field:url")
	var name_f := BeField.make("", "be.dialog.field:name")
	var opts := []
	for g in ProgramStore.groups:
		opts.append([String(g.id), String(g.name)])
	var sel := BeSelect.make(opts, gid if gid != "" else String(ProgramStore.groups[0].id), "be.dialog.select:group", 160)
	var g := d.row_grid([["Web address:", url], ["Name:", name_f], ["Group:", sel]], 110)
	for c in g.get_children():
		if c is BeSelect:
			c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	url.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([
		{"label": "OK", "default": true, "cb": func():
			Launcher.add_website(ProgramStore, sel.value, name_f.text, url.text, "url")
			return false},
		{"label": "Cancel"}])
	d.finish()
	url.grab_text_focus.call_deferred()


## Native file picker; fills the command (and an empty name) from the chosen file.
static func browse_into(cmd: BeField, name_f: BeField = null) -> void:
	var path: String = await Platform.select_executable()
	if path == "":
		return
	var info: Dictionary = Platform.get_app_info(path)
	cmd.text = String(info.get("path", path))
	if name_f != null and name_f.text.strip_edges().is_empty():
		name_f.text = String(info.get("name", BeDialogLogic.basename_of(path)))


static func run(shell: Control) -> void:
	var d := _form(shell, "Run", 480, "be.dialog.run")
	d.add_row(BeLabel.make("Type the name of a program in your launcher groups, or a command to run.", false, d.content_width()))
	var f := BeField.make("", "be.dialog.field:command")
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_row(f)
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([
		{"label": "OK", "default": true, "cb": func():
			var item := BeDialogLogic.run_target(ProgramStore.groups, f.text)
			if not item.is_empty():
				shell.launch_item(item)
			return false},
		{"label": "Cancel"},
		{"label": "Browse...", "cb": func():
			browse_into(f)
			return true}])
	d.finish()
	f.grab_text_focus.call_deferred()


static func help(shell: Control) -> void:
	var d := _form(shell, "Program Manager Help", 520, "be.dialog.help")
	d.add_row(BeLabel.make("Click a topic, and then click Display.", false, d.content_width()))
	var cells := []
	for i in TOPICS.size():
		cells.append({"id": str(i), "label": TOPICS[i][0], "sub": "", "tex": BeIconCatalog.texture("question")})
	var list := BeChoice.make("list", cells, "0", d.content_width(), "be.dialog.help-list")
	d.add_row(list)
	var show := func():
		var t: Array = TOPICS[int(list.selected)]
		message(shell, [{"t": t[0], "w": 700}, t[1]], "information")
		return false
	list.activated.connect(func(_id): d.default_button.pressed.emit())
	d.set_buttons([{"label": "Display", "default": true, "cb": show}, {"label": "Cancel"}])
	d.finish()


static func backgrounds(shell: Control) -> void:
	var d := _form(shell, "Backgrounds", 470, "be.dialog.backgrounds")
	d.add_row(BeLabel.make("Desktop color:", false, d.content_width()))
	var cells := []
	for s in SWATCHES:
		cells.append({"id": s[0], "label": s[1], "color": Color(s[0])})
	var current: String = shell.desktop_color if shell.desktop_color != "" else SWATCHES[0][0]
	var sw := BeChoice.make("swatches", cells, current, d.content_width(), "be.dialog.swatches")
	d.add_row(sw)
	var dark := BeCheck.make("Dark mode", BeTheme.dark, "be.dialog.dark")
	d.add_row(dark)
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		# the default colour stays "themed" so dark mode can darken it; any other swatch is used verbatim
		shell.set_desktop_color("" if sw.selected == SWATCHES[0][0] else sw.selected)
		ProgramStore.update_settings({"theme": "dark" if dark.checked else "light"})
		return false}, {"label": "Cancel"}])
	d.finish()


static func change_icon(shell: Control, current: String, on_pick: Callable) -> void:
	var d := _form(shell, "Change Icon", 500, "be.dialog.change-icon")
	d.add_row(BeLabel.make("Select an icon from the list below:", false, d.content_width()))
	var cells := []
	for o in BeIconCatalog.picker_options():
		cells.append({"id": String(o.id), "label": String(o.id), "tex": BeIconCatalog.texture(String(o.id), String(o.id))})
	var grid := BeChoice.make("icons", cells, current if current != "" else "default", d.content_width(), "be.dialog.icon-grid")
	d.add_row(grid)
	grid.activated.connect(func(_id): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		on_pick.call(grid.selected)
		return false}, {"label": "Cancel"}])
	d.finish()
