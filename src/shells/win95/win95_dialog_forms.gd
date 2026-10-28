class_name Win95DialogForms
extends RefCounted
## The concrete Win95 dialogs (ports of Win95Dialogs.tsx): Run, Shut Down, Create Shortcut wizard,
## Create New Folder, New Internet Shortcut, Help, About. Everything is built on Win95Modal;
## positions are body coordinates derived from the original CSS (body padding 10px 9px 8px:
## content origin (9, 10), content width = body width - 18). Rules live in Win95DialogLogic.

const CX := 9.0
const CY := 10.0


static func _button(label: String, size_w: float = 75.0) -> Win95Button:
	var b := Win95Button.new()
	b.label = label
	b.size = Vector2(size_w, 23)
	b.custom_minimum_size = b.size
	return b


## Right-aligned button row (gap 6) ending 9px from the body's right edge, top at y.
static func _row(m: Win95Modal, buttons: Array, y: float) -> void:
	var x: float = m.body.size.x - 9.0
	for i in range(buttons.size() - 1, -1, -1):
		var b: Win95Button = buttons[i]
		x -= b.size.x
		m.add(b, Vector2(x, y))
		x -= 6.0


static func _form_row(m: Win95Modal, label: String, y: float, field: Control, field_x: float = CX + 111.0) -> void:
	var l := Win95Label.make(label, Vector2(0, 0))
	m.add(l, Vector2(CX + 105.0 - l.size.x, y + 4))
	m.add(field, Vector2(field_x, y))
	field.size = Vector2(m.body.size.x - 9 - field_x, 21)


static func _group_names() -> Array:
	return ProgramStore.groups.map(func(g): return String(g.name))


static func _group_index(group_id: String) -> int:
	for i in ProgramStore.groups.size():
		if ProgramStore.groups[i].id == group_id:
			return i
	return 0


# ------------------------------------------------------------------------ Run

static func open_run(shell: Control) -> void:
	var m := Win95Modal.open(shell, "Run", Vector2(347, 163), {
		"help": "Type a launcher command or path in Open. Browse selects an executable; successful commands are retained for this launcher session."})
	m.add(Win95IconBox.make("run", Vector2.ZERO), Vector2(CX, CY + 6))
	m.add(Win95Label.make("Type the name of a program, folder, document, or Internet resource, and Windows will open it for you.", Vector2.ZERO, {"wrap": 265}), Vector2(CX + 40, CY))
	var open_label := Win95Label.make("&Open:", Vector2.ZERO)
	m.add(open_label, Vector2(CX, CY + 43 + 4))
	var edit := Win95TextInput.new()
	m.add(edit, Vector2(CX + 41, CY + 43))
	edit.size = Vector2(m.body.size.x - 18 - 41, 21)
	var arrow := Win95ComboButton.new()
	m.add(arrow, Vector2(CX + 41 + edit.size.x - 18, CY + 43 + 2))
	var error := Win95Label.make("", Vector2.ZERO, {"color": Color("#800000"), "max_width": 315})
	m.add(error, Vector2(49, 78))
	var ok := _button("&OK")
	var cancel := _button("&Cancel")
	var browse := _button("&Browse...")
	_row(m, [ok, cancel, browse], m.body.size.y - 8 - 23)
	m.set_default(ok)
	edit.text_changed.connect(func(_t): error.text = "")
	cancel.pressed.connect(m.close)
	ok.pressed.connect(func():
		var item := Win95DialogLogic.run_item(edit.text)
		if item.is_empty():
			return
		var result: Dictionary = Platform.launch(item)
		if result.get("success", false):
			Win95DialogLogic.remember_run(edit.text)
			m.close()
		else:
			error.text = Win95DialogLogic.run_error(result, edit.text))
	browse.pressed.connect(func():
		var path: String = await Platform.select_executable()
		if path != "" and is_instance_valid(edit):
			edit.text = path
			error.text = "")
	arrow.pressed.connect(func():
		var items: Array = []
		for i in Win95DialogLogic.run_history.size():
			var entry: String = Win95DialogLogic.run_history[i]
			items.append({"id": "h%d" % i, "label": entry.replace("&", "&&"), "onSelect": func():
				edit.text = entry
				error.text = ""})
		if items.is_empty():
			items.append({"id": "empty", "label": "(Empty)", "disabled": true})
		Win95Menu.open(shell, items, edit.get_global_transform() * Vector2(0, 20), {}))
	edit.focus_edit()


# ------------------------------------------------------------------ Shut Down

static func open_shutdown(shell: Control) -> void:
	var m := Win95Modal.open(shell, "Shut Down Windows", Vector2(347, 222))
	m.add(Win95IconBox.make("shutdown", Vector2.ZERO), Vector2(CX, CY + 25))
	m.add(Win95Label.make("What do you want the computer to do?", Vector2.ZERO), Vector2(CX + 42, CY))
	var choices := [
		["quit", "&Shut down the launcher", false], ["restart", "&Restart the launcher", false],
		["win31", "Restart in Windows for &Workgroups 3.11", false], ["msdos", "Restart the computer in &MS-DOS mode", true]]
	var radios := {}
	for i in choices.size():
		var r := Win95Radio.new()
		r.label = choices[i][1]
		r.group = "shutdown"
		r.disabled = choices[i][2]
		r.checked = i == 0
		m.add(r, Vector2(CX + 42, CY + 18 + i * 18))
		radios[choices[i][0]] = r
	var yes := _button("&Yes")
	var no := _button("&No")
	var help := _button("&Help")
	_row(m, [yes, no, help], m.body.size.y - 8 - 23)
	m.set_default(yes)
	no.pressed.connect(m.close)
	help.pressed.connect(func(): Win95Dialogs.show_message(shell, "Shut Down Help", Win95DialogLogic.SHUTDOWN_HELP, "information"))
	yes.pressed.connect(func():
		var choice := "quit"
		for k in radios:
			if radios[k].checked:
				choice = k
		m.close()
		_do_shutdown(shell, choice))
	yes.grab_focus()


static func _do_shutdown(shell: Control, choice: String) -> void:
	match choice:
		"quit":
			shell.request_quit.emit()
		"restart":
			shell.windows.reset()
			Platform.recreate_for_shell(String(ProgramStore.settings.get("shell", "win95")))
		"win31":
			var next := Win95DialogLogic.shutdown_next_settings(ProgramStore.settings, "win31")
			var result: Dictionary = ProgramStore.apply_settings_transaction(next)
			if result.get("success", false):
				Platform.recreate_for_shell("win31")
			else:
				Win95Dialogs.show_message(shell, "Shut Down Windows", String(result.get("error", "The launcher could not switch shells.")), "warning")


# --------------------------------------------------------------------- Wizard

static func open_wizard(shell: Control, ctx: Dictionary) -> void:
	var m := Win95Modal.open(shell, "Create Shortcut", Vector2(430, 250), {
		"help": "The Create Shortcut wizard adds a launcher item without modifying the selected application."})
	var state := {"step": 0, "group_id": String(ctx.get("groupId", ProgramStore.groups[0].id if ProgramStore.groups.size() > 0 else "")),
		"icon": "new-shortcut", "working_dir": "", "name": "New Shortcut"}
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.body.add_child(page)
	var buttons_holder := Control.new()
	buttons_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.body.add_child(buttons_holder)
	var back := _button("< &Back")
	var next := _button("&Next >")
	var cancel := _button("&Cancel")
	var cw: float = m.body.size.x - 18
	m.body.add_child(Win95Rule.make(Vector2(CX, CY + 158), cw))
	_row(m, [back, next, cancel], CY + 158 + 1 + 8)
	cancel.pressed.connect(m.close)
	m.set_default(next)
	var command := Win95TextInput.new()
	var name_edit := Win95TextInput.new()
	var group_select := Win95Select.new()
	group_select.shell = shell
	var rebuild := func() -> void:
		for c in page.get_children():
			page.remove_child(c)
			if c != command and c != name_edit and c != group_select:
				c.free()
		var icon_id: String = "new-shortcut" if state.step == 0 else String(state.icon)
		page.add_child(Win95IconBox.make(icon_id, Vector2(CX + 5, CY + 5)))
		var col_x := CX + 5 + 36 + 10
		var col_w := cw - 10 - 46
		if state.step == 0:
			page.add_child(Win95Label.make("What item would you like to create a shortcut for?", Vector2(col_x, CY + 5), {"bold": true, "wrap": 315}))
			page.add_child(Win95Label.make("Type the location of the item, or click Browse.", Vector2(col_x, CY + 5 + 29 + 8), {"wrap": 315}))
			var y := CY + 5 + 29 + 8 + 13 + 14
			command.position = Vector2(col_x, y)
			command.size = Vector2(col_w - 81, 21)
			page.add_child(command)
			var br := _button("&Browse...")
			br.position = Vector2(col_x + col_w - 75, y - 1)
			page.add_child(br)
			br.pressed.connect(func():
				var path: String = await Platform.select_executable()
				if path == "" or not is_instance_valid(command):
					return
				command.text = path
				var info: Dictionary = Platform.get_app_info(path)
				var applied := Win95DialogLogic.wizard_apply_app_info(info, state.icon)
				state.name = applied.name
				state.working_dir = applied.workingDir
				state.icon = applied.icon)
			command.focus_edit()
		else:
			page.add_child(Win95Label.make("Select a title and program group", Vector2(col_x, CY + 5), {"bold": true}))
			var ry := CY + 5 + 29 + 8
			var l1 := Win95Label.make("&Name:", Vector2(0, 0))
			l1.position = Vector2(col_x + 105 - l1.size.x, ry + 4)
			page.add_child(l1)
			name_edit.position = Vector2(col_x + 111, ry)
			name_edit.size = Vector2(col_w - 111, 21)
			page.add_child(name_edit)
			var l2 := Win95Label.make("&Program group:", Vector2(0, 0))
			l2.position = Vector2(col_x + 105 - l2.size.x, ry + 26 + 4)
			page.add_child(l2)
			group_select.position = Vector2(col_x + 111, ry + 26)
			group_select.size = Vector2(col_w - 111, 21)
			page.add_child(group_select)
	var sync := func() -> void:
		back.disabled = state.step == 0
		if state.step == 0:
			next.label = "&Next >"
			next.disabled = not Win95DialogLogic.wizard_can_next(command.text)
		else:
			next.label = "&Finish"
			next.disabled = not Win95DialogLogic.wizard_can_finish(name_edit.text, state.group_id, command.text)
	command.text_changed.connect(func(_t): sync.call())
	name_edit.text_changed.connect(func(t): state.name = t; sync.call())
	group_select.item_selected.connect(func(i): state.group_id = String(ProgramStore.groups[i].id); sync.call())
	back.pressed.connect(func():
		state.step = 0
		rebuild.call()
		sync.call())
	next.pressed.connect(func():
		if state.step == 0:
			if not Win95DialogLogic.wizard_can_next(command.text):
				return
			state.step = 1
			name_edit.text = String(state.name)
			group_select.options = _group_names()
			group_select.selected_index = _group_index(state.group_id)
			rebuild.call()
			sync.call()
			name_edit.focus_edit()
		else:
			var id := Win95DialogLogic.wizard_finish(ProgramStore, state.group_id, name_edit.text, command.text, state.icon, state.working_dir)
			if id == "":
				return
			var gid: String = state.group_id
			m.close()
			shell.windows.open_group(gid))
	rebuild.call()
	sync.call()


# --------------------------------------------------------- New Folder / New URL

static func open_new_folder(shell: Control, ctx: Dictionary) -> void:
	var m := Win95Modal.open(shell, "Create New Folder", Vector2(340, 128))
	m.add(Win95Label.make("Type a name for the new folder:", Vector2.ZERO), Vector2(CX, CY))
	var edit := Win95TextInput.new()
	edit.text = "New Folder"
	m.add(edit, Vector2(CX, CY + 15))
	edit.size = Vector2(m.body.size.x - 18, 21)
	var ok := _button("&OK")
	var cancel := _button("&Cancel")
	_row(m, [ok, cancel], CY + 15 + 21 + 12)
	m.set_default(ok)
	cancel.pressed.connect(m.close)
	ok.pressed.connect(func():
		var id := Win95DialogLogic.create_folder(ProgramStore, edit.text)
		if id == "":
			return
		shell.windows.open_group(id)
		m.close()
		if ctx.get("openItemAfterCreate", false):
			Win95Dialogs.open_wizard(shell, {"groupId": id})
		elif ctx.get("openUrlAfterCreate", false):
			Win95Dialogs.open_new_url(shell, {"groupId": id}))
	edit.focus_edit()
	edit.edit.select_all()


static func open_new_url(shell: Control, ctx: Dictionary) -> void:
	var m := Win95Modal.open(shell, "New Internet Shortcut", Vector2(390, 185))
	var group_id := String(ctx.get("groupId", ProgramStore.groups[0].id if ProgramStore.groups.size() > 0 else ""))
	var name_edit := Win95TextInput.new()
	name_edit.text = "New Internet Shortcut"
	var url_edit := Win95TextInput.new()
	url_edit.text = "https://"
	var group_select := Win95Select.new()
	group_select.shell = shell
	group_select.options = _group_names()
	group_select.selected_index = _group_index(group_id)
	_form_row(m, "&Name:", CY + 5, name_edit)
	_form_row(m, "Internet &address:", CY + 5 + 26, url_edit)
	_form_row(m, "Program &group:", CY + 5 + 52, group_select)
	var ok := _button("&OK")
	var cancel := _button("&Cancel")
	_row(m, [ok, cancel], CY + 5 + 78 + 21 + 12 - 5)
	m.set_default(ok)
	cancel.pressed.connect(m.close)
	group_select.item_selected.connect(func(i): group_id = String(ProgramStore.groups[i].id))
	ok.pressed.connect(func():
		var id := Win95DialogLogic.create_url_item(ProgramStore, group_id, name_edit.text, url_edit.text)
		if id == "":
			return
		m.close()
		shell.windows.open_group(group_id))
	name_edit.focus_edit()


# ---------------------------------------------------------------- Help / About

static func open_help(shell: Control) -> void:
	var m := Win95Modal.open(shell, "Gosh 95 Help", Vector2(430, 245))
	m.body.add_child(_HelpPane.new())
	var ok := _button("OK")
	_row(m, [ok], m.body.size.y - 8 - 23)
	m.set_default(ok)
	ok.pressed.connect(m.close)
	ok.grab_focus()


static func open_about(shell: Control) -> void:
	var m := Win95Modal.open(shell, "About Gosh 95", Vector2(380, 205))
	m.add(Win95IconBox.make("windows-logo", Vector2.ZERO), Vector2(CX, CY))
	m.add(Win95Label.make("Gosh 95", Vector2.ZERO, {"bold": true}), Vector2(CX + 42, CY))
	m.add(Win95Label.make("Windows 95 RTM-style application launcher", Vector2.ZERO), Vector2(CX + 42, CY + 13))
	m.add(Win95Label.make("Version %s" % Platform.version(), Vector2.ZERO), Vector2(CX + 42, CY + 26))
	m.body.add_child(Win95Rule.make(Vector2(CX, CY + 32 + 9 + 4), m.body.size.x - 18))
	m.add(Win95Label.make("This launcher provides a period-style interface for starting saved applications. It does not emulate Microsoft Windows.", Vector2.ZERO, {"wrap": 330}), Vector2(CX, CY + 32 + 9 + 4 + 2 + 9))
	var ok := _button("OK")
	_row(m, [ok], m.body.size.y - 8 - 23)
	m.set_default(ok)
	ok.pressed.connect(m.close)
	ok.grab_focus()


## The two-pane help viewer (topic list + copy), drawn directly.
class _HelpPane extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2(9, 10)
		size = Vector2(404, 148)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Win95Draw.border(self, r, 2, Win95Draw.SHADOW, Win95Draw.LIGHT, Win95Draw.LIGHT, Win95Draw.SHADOW)
		Win95Draw.fill(self, Rect2(2, 2, 130, size.y - 4), Win95Draw.WINDOW)
		Win95Draw.fill(self, Rect2(2 + 130, 2, size.x - 134, size.y - 4), Win95Draw.WINDOW)
		Win95Draw.fill(self, Rect2(131, 2, 1, size.y - 4), Win95Draw.SHADOW)
		Win95Draw.text(self, Vector2(8, 8), "Contents", Win95Draw.TEXT, {"bold": true})
		var y := 8 + 13 + 3
		for t in ["Starting a program", "Organizing programs", "Using Find and Run"]:
			Win95Draw.text(self, Vector2(10, y + 2), t, Win95Draw.TEXT)
			y += 19
		Win95Draw.text(self, Vector2(142, 10), "Starting a program", Win95Draw.TEXT, {"bold": true})
		Win95Draw.text(self, Vector2(142, 10 + 14 + 6), "Click Start, point to Programs, point to a program group, and then click the program you want to start.", Win95Draw.TEXT, {"wrap": true, "max_width": 230})
		Win95Draw.text(self, Vector2(142, 10 + 14 + 6 + 52 + 13), "You can also open My Computer and double-click a saved application.", Win95Draw.TEXT, {"wrap": true, "max_width": 230})
