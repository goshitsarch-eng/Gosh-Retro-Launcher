class_name Win95LaunchGroups
extends RefCounted
## The Launch Groups manager and its sub-dialogs, built on Win95Modal and the Win95 controls:
##   open_manager(shell)                      # Start > Settings > Launch Groups..., Programs > Launch Groups > Manage
##   open_members(shell, number, title, on_ok) # check list of every program; on_ok(keys)
##   open_name_prompt(shell, title, text, value, on_ok)   # one-line name box (New / Rename)
##   open_number(shell, number, on_done)       # pick 1..8 (swaps when taken)
## Rules and wording live in Win95LaunchGroupLogic; changes go through ProgramStore's launch-group API.
## Automation ids: w95.lg.list, w95.lg.button:<New|Rename|Number|Delete|Members|Launch|Close>,
## w95.lg.members.list, w95.lg.name, w95.lg.number.

const CX := 9.0
const CY := 10.0
const HELP := "A launch group starts several programs one after another. Launch All starts Group 1 first, then Group 2, and so on, waiting the launch delay between programs. Use Members to choose the programs in a group, and Number to change the order."

static var _open_manager: WeakRef = null


static func _button(label: String) -> Win95Button:
	var b := Win95Button.new()
	b.label = label
	b.size = Vector2(75, 23)
	b.custom_minimum_size = b.size
	return b


static func _auto(node: Control, id: String) -> void:
	node.set_meta("auto_id", id)
	node.add_to_group("pm_auto")


static func _names() -> Dictionary:
	return ProgramStore.launch_group_names()


## Right-aligned OK / Cancel row ending 9 px from the body's right edge.
static func _ok_cancel(m: Win95Modal, y: float, ok_label: String = "OK") -> Array:
	var ok := _button(ok_label)
	var cancel := _button("Cancel")
	m.add(ok, Vector2(m.body.size.x - 9 - 75 * 2 - 6, y))
	m.add(cancel, Vector2(m.body.size.x - 9 - 75, y))
	m.set_default(ok)
	cancel.pressed.connect(m.close)
	return [ok, cancel]


# ------------------------------------------------------------------- manager

static func open_manager(shell: Control) -> Win95Modal:
	var existing: Variant = _open_manager.get_ref() if _open_manager != null else null
	if existing is Win95Modal and is_instance_valid(existing) and existing.is_inside_tree() and not existing.is_queued_for_deletion():
		return existing
	var m := Win95Modal.open(shell, Win95LaunchGroupLogic.MANAGER_TITLE, Vector2(420, 290), {"help": HELP})
	var mgr := _Manager.new()
	m.body.add_child(mgr)
	mgr.build(shell, m)
	_open_manager = weakref(m)
	return m


## The manager's client: list + button column + status line. Lives inside the modal body so its
## store connections end when the dialog is freed.
class _Manager extends Control:
	var shell: Control
	var modal: Win95Modal
	var list: Win95ListBox
	var status: Win95Label
	var buttons := {}
	var rows: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func build(p_shell: Control, m: Win95Modal) -> void:
		shell = p_shell
		modal = m
		var bw: float = m.body.size.x
		m.add(Win95Label.make("Launch All starts Group 1 first, then Group 2, and so on. Select a group, then choose a command.", Vector2.ZERO, {"wrap": 310}), Vector2(Win95LaunchGroups.CX, Win95LaunchGroups.CY))
		m.add(Win95Label.make("Launch groups:", Vector2.ZERO), Vector2(Win95LaunchGroups.CX, Win95LaunchGroups.CY + 33))
		list = Win95ListBox.new()
		list.columns = [{"label": "Number", "width": 62}, {"label": "Name", "width": 170}, {"label": "Programs"}]
		list.empty_text = "There are no launch groups. Click New to create one."
		list.accessibility_name = "Launch groups"
		Win95LaunchGroups._auto(list, "w95.lg.list")
		m.add(list, Vector2(Win95LaunchGroups.CX, Win95LaunchGroups.CY + 49))
		var list_w := bw - Win95LaunchGroups.CX - 9 - 75 - 9
		list.size = Vector2(list_w, 163)
		var bx := Win95LaunchGroups.CX + list_w + 9
		var specs := [["new", "&New..."], ["rename", "&Rename..."], ["number", "N&umber..."], ["delete", "&Delete"],
			["members", "&Members..."], ["launch", "&Launch"]]
		for i in specs.size():
			var b := Win95LaunchGroups._button(specs[i][1])
			Win95LaunchGroups._auto(b, "w95.lg.button:" + String(specs[i][1]).replace("&", "").trim_suffix("..."))
			m.add(b, Vector2(bx, Win95LaunchGroups.CY + 49 + i * 28))
			buttons[specs[i][0]] = b
		var close := Win95LaunchGroups._button("Close")
		Win95LaunchGroups._auto(close, "w95.lg.button:Close")
		m.add(close, Vector2(bw - 9 - 75, m.body.size.y - 8 - 23))
		m.set_default(close)
		close.pressed.connect(m.close)
		status = Win95Label.make("", Vector2.ZERO, {"max_width": int(list_w), "show_access": false})
		m.add(status, Vector2(Win95LaunchGroups.CX, m.body.size.y - 8 - 23 + 5))
		buttons.new.pressed.connect(_on_new)
		buttons.rename.pressed.connect(_on_rename)
		buttons.number.pressed.connect(_on_number)
		buttons.delete.pressed.connect(_on_delete)
		buttons.members.pressed.connect(_on_members)
		buttons.launch.pressed.connect(_on_launch)
		list.selection_changed.connect(func(_i): _sync_buttons())
		list.row_activated.connect(func(_i): _on_members())
		list.command_key.connect(func(key):
			if key == "Delete":
				_on_delete()
			elif key == "F2":
				_on_rename())
		ProgramStore.groups_changed.connect(refresh)
		ProgramStore.settings_changed.connect(refresh)
		ProgramStore.data_reloaded.connect(refresh)
		refresh()
		list.grab_focus()

	func _exit_tree() -> void:
		for sig in [ProgramStore.groups_changed, ProgramStore.settings_changed, ProgramStore.data_reloaded]:
			if sig.is_connected(refresh):
				sig.disconnect(refresh)

	func selected_row() -> Dictionary:
		return rows[list.selected] if list.selected >= 0 and list.selected < rows.size() else {}

	func selected_number() -> int:
		return int(selected_row().get("number", 0))

	## Rebuilds the rows from the store, keeping the selected group (by number) selected.
	func refresh() -> void:
		if not is_inside_tree():
			return
		select_number(selected_number())

	func select_number(number: int) -> void:
		var previous := list.selected
		rows = Win95LaunchGroupLogic.manager_rows(ProgramStore.groups, Win95LaunchGroups._names())
		list.set_rows(rows, Win95LaunchGroupLogic.row_index(rows, number, maxi(0, previous)))
		_sync_buttons()

	func _sync_buttons() -> void:
		var state := Win95LaunchGroupLogic.manager_buttons(selected_row(), ProgramStore.groups, Win95LaunchGroups._names())
		for k in buttons:
			buttons[k].disabled = not bool(state.get(k, true))

	func say(text: String) -> void:
		status.text = Win95LaunchGroupLogic.escape(text)

	func _on_new() -> void:
		var number := LaunchGroups.next_free_number(ProgramStore.groups, Win95LaunchGroups._names())
		if number == 0:
			Win95Dialogs.show_message(shell, "New Launch Group", Win95LaunchGroupLogic.all_numbers_used_message(), "information")
			return
		Win95LaunchGroups.open_name_prompt(shell, "New Launch Group",
			"Type a name for the new launch group (Group %d). You choose its programs next." % number, "", func(text: String):
				if not is_inside_tree():
					return
				var name := LaunchGroups.clean_name(text)
				if name != "":
					var n: int = ProgramStore.create_launch_group(name)
					if n == 0:
						Win95Dialogs.show_message(shell, "New Launch Group", Win95LaunchGroupLogic.all_numbers_used_message(), "information")
						return
					select_number(n)
					say(Win95LaunchGroupLogic.created_status(n, Win95LaunchGroups._names()))
					_on_members()
					return
				# No name: the group only exists once it has programs, so create it from the check list.
				Win95LaunchGroups.open_members(shell, 0, "Group %d" % number, func(keys: Array):
					if not is_inside_tree():
						return
					if keys.is_empty():
						say("No launch group was created. Type a name or choose a program.")
						return
					var n2: int = ProgramStore.create_launch_group("", keys)
					if n2 == 0:
						Win95Dialogs.show_message(shell, "New Launch Group", Win95LaunchGroupLogic.all_numbers_used_message(), "information")
						return
					select_number(n2)
					say(Win95LaunchGroupLogic.created_status(n2, Win95LaunchGroups._names()))))

	func _on_rename() -> void:
		var number := selected_number()
		if number <= 0:
			return
		Win95LaunchGroups.open_name_prompt(shell, "Rename Launch Group",
			"Type a new name for Group %d. Leave it blank to remove the name." % number,
			LaunchGroups.name_of(Win95LaunchGroups._names(), number), func(text: String):
				if not is_inside_tree():
					return
				ProgramStore.set_launch_group_name(number, text)
				select_number(number)
				if selected_number() != number:
					say("Group %d had no programs and no name, so it was removed." % number)
				else:
					say(Win95LaunchGroupLogic.renamed_status(number, Win95LaunchGroups._names())))

	func _on_number() -> void:
		var number := selected_number()
		if number <= 0:
			return
		Win95LaunchGroups.open_number(shell, number, func(to: int, text: String):
			if not is_inside_tree():
				return
			select_number(to)
			say(text))

	func _on_delete() -> void:
		var row := selected_row()
		if row.is_empty():
			return
		var number := int(row.number)
		Win95Dialogs.confirm(shell, "Confirm Launch Group Delete",
			Win95LaunchGroupLogic.escape(Win95LaunchGroupLogic.delete_prompt(number, int(row.count), Win95LaunchGroups._names())), func():
				if not is_inside_tree():
					return
				var label := LaunchGroups.format_launch_group(number, Win95LaunchGroups._names())
				ProgramStore.delete_launch_group(number)
				select_number(-1)
				say("Deleted %s." % label))

	func _on_members() -> void:
		var number := selected_number()
		if number <= 0:
			return
		var label := LaunchGroups.format_launch_group(number, Win95LaunchGroups._names())
		Win95LaunchGroups.open_members(shell, number, label, func(keys: Array):
			ProgramStore.set_launch_group_members(number, keys)
			if is_inside_tree():
				select_number(number)
				if selected_number() != number:
					say("%s had no programs and no name, so it was removed." % label)
				else:
					say("%s now has %s." % [label, Win95LaunchGroupLogic.plural_programs(keys.size())]))

	func _on_launch() -> void:
		var number := selected_number()
		if number > 0:
			shell.launch_group_row("launch:%d" % number)


# ------------------------------------------------------------------- prompts

## One-line text prompt (Create New Folder layout). on_ok(text) runs after the box closes.
static func open_name_prompt(shell: Control, title: String, prompt: String, value: String, on_ok: Callable) -> Win95Modal:
	var label := Win95Label.make(prompt, Vector2.ZERO, {"wrap": 322})
	var m := Win95Modal.open(shell, title, Vector2(340, 26 + CY + label.size.y + 4 + 21 + 12 + 23 + 10))
	m.add(label, Vector2(CX, CY))
	var edit := Win95TextInput.new()
	edit.text = value
	edit.accessibility_name = "Name"
	_auto(edit, "w95.lg.name")
	m.add(edit, Vector2(CX, CY + label.size.y + 4))
	edit.size = Vector2(m.body.size.x - 18, 21)
	var btns := _ok_cancel(m, CY + label.size.y + 4 + 21 + 12)
	(btns[0] as Win95Button).pressed.connect(func():
		var text := edit.text
		m.close()
		on_ok.call(text))
	edit.focus_edit()
	edit.edit.select_all()
	return m


## Number picker for group `number`. on_done(to, status_text) runs after a successful renumber.
static func open_number(shell: Control, number: int, on_done: Callable) -> Win95Modal:
	var names := _names()
	var m := Win95Modal.open(shell, "Change Group Number", Vector2(340, 170))
	m.add(Win95Label.make("Launch All starts the lowest number first. Choose the number for %s:" % Win95LaunchGroupLogic.escape(LaunchGroups.format_launch_group(number, names)),
		Vector2.ZERO, {"wrap": 322}), Vector2(CX, CY))
	var choices := Win95LaunchGroupLogic.number_choices(ProgramStore.groups, names, number)
	var label := Win95Label.make("N&umber:", Vector2.ZERO)
	m.add(label, Vector2(CX, CY + 36 + 4))
	var select := Win95Select.new()
	select.shell = shell
	select.options = Win95LaunchGroupLogic.choice_labels(choices).map(func(t): return String(t))
	select.selected_index = Win95LaunchGroupLogic.choice_index(choices, number)
	_auto(select, "w95.lg.number")
	m.add(select, Vector2(CX + 60, CY + 36))
	select.size = Vector2(m.body.size.x - 18 - 60, 21)
	var note := Win95Label.make("", Vector2.ZERO, {"wrap": 322, "show_access": false})
	m.add(note, Vector2(CX, CY + 36 + 21 + 6))
	var btns := _ok_cancel(m, m.body.size.y - 8 - 23)
	var ok: Win95Button = btns[0]
	var sync := func(_i = null):
		var to := Win95LaunchGroupLogic.choice_value(choices, select.selected_index)
		note.text = Win95LaunchGroupLogic.escape(Win95LaunchGroupLogic.number_note(ProgramStore.groups, names, number, to))
	select.item_selected.connect(sync)
	sync.call()
	ok.pressed.connect(func():
		var to := Win95LaunchGroupLogic.choice_value(choices, select.selected_index)
		m.close()
		if to == number:
			return
		var before := _names().duplicate()
		var swapped := Win95LaunchGroupLogic.is_number_used(ProgramStore.groups, before, to)
		if ProgramStore.renumber_launch_group(number, to):
			on_done.call(to, Win95LaunchGroupLogic.renumbered_status(number, to, swapped, before)))
	select.grab_focus()
	return m


# ------------------------------------------------------------------- members

## Check list of every program; on_ok(keys) gets the checked "groupId:itemId" keys after the box
## closes. `number` 0 = a group that is not created yet (nothing checked).
static func open_members(shell: Control, number: int, group_label: String, on_ok: Callable) -> Win95Modal:
	var m := Win95Modal.open(shell, "%s Members" % Win95LaunchGroupLogic.escape(group_label), Vector2(420, 300))
	m.add(Win95Label.make("Check each program that belongs to %s. A program can be in only one launch group, so checking a program that is in another group moves it." % Win95LaunchGroupLogic.escape(group_label),
		Vector2.ZERO, {"wrap": 394}), Vector2(CX, CY))
	var rows := Win95LaunchGroupLogic.member_rows(ProgramStore.groups, number)
	var list := Win95ListBox.new()
	list.columns = [{"label": "Program", "width": 165}, {"label": "Program group", "width": 120}, {"label": "Launch group"}]
	list.checkboxes = true
	list.empty_text = "There are no programs yet."
	list.accessibility_name = "Programs"
	_auto(list, "w95.lg.members.list")
	m.add(list, Vector2(CX, CY + 33))
	list.size = Vector2(m.body.size.x - 18, 178)
	list.set_rows(rows, 0)
	var summary := Win95Label.make("", Vector2.ZERO, {"max_width": 230, "show_access": false})
	m.add(summary, Vector2(CX, m.body.size.y - 8 - 23 + 5))
	var update := func(_a = null, _b = null):
		summary.text = Win95LaunchGroupLogic.members_summary(list.rows, number)
	list.check_toggled.connect(update)
	update.call()
	var btns := _ok_cancel(m, m.body.size.y - 8 - 23)
	(btns[0] as Win95Button).pressed.connect(func():
		var keys := Win95LaunchGroupLogic.checked_keys(list.rows)
		m.close()
		on_ok.call(keys))
	list.grab_focus()
	return m
