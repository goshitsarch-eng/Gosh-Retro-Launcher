class_name BeLaunchGroups
extends RefCounted
## The Launch Groups manager (Deskbar > Launch Groups…): a tabbed Be panel listing every launch group (number, name,
## member count) with New…, Rename…, Number…, Members…, Delete and Launch beside the list, plus its sub-dialogs.
## Changes go through ProgramStore; the list follows the store while the panel is open. Wording and rows come from
## BeDialogLogic (pure, unit-tested).
## Keyboard: Up/Down pick a group, Delete deletes it, Enter = Done, Esc closes; in Members, Up/Down move and Space
## checks. Automation ids: be.dialog.launch-groups, be.dialog.launch-groups-list(:<number>), be.dialog.status,
## be.dialog.button:<label> (side buttons too), be.dialog.members, be.dialog.members-list(:<groupId:itemId>),
## be.dialog.launch-group-name, be.dialog.launch-group-number, be.dialog.select:number, be.dialog.field:name.

const AUTO_ID := "be.dialog.launch-groups"
const SIDE_W := 104.0
const LIST_ROWS := 8


static func _names() -> Dictionary:
	return ProgramStore.launch_group_names()


static func _list_cells(rows: Array) -> Array:
	var out := []
	for r in rows:
		out.append({"id": String(r.id), "label": String(r.label), "sub": String(r.sub), "tex": BeIconCatalog.texture("terminal")})
	return out


## The open manager, or null.
static func find_open(shell: Control) -> BeDialog:
	for c in shell.dialog_layer.get_children():
		if c is BeDialog and String(c.get_meta("auto_id", "")) == AUTO_ID and not c.is_queued_for_deletion():
			return c
	return null


static func open(shell: Control, select_number: int = 0) -> BeDialog:
	var existing := find_open(shell)
	if existing != null:
		return existing
	var d := BeDialog.open(shell.dialog_layer, "Launch Groups", 560, true, false, AUTO_ID)
	d.add_row(BeLabel.make(BeDialogLogic.LAUNCH_GROUPS_INTRO, false, d.content_width()))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := BeDialogLogic.manager_rows(ProgramStore.groups, _names())
	var first := str(select_number) if select_number > 0 else (String(rows[0].id) if not rows.is_empty() else "")
	var list := BeChoice.make("list", _list_cells(rows), first, d.content_width() - SIDE_W - 12, AUTO_ID + "-list")
	list.fixed_rows(LIST_ROWS)
	body.add_child(list)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.custom_minimum_size.x = SIDE_W
	body.add_child(side)
	d.add_row(body)
	var status := BeLabel.make("", false, d.content_width(), "444444")
	BeUi.auto_id(status, "be.dialog.status")
	d.add_row(_two_lines(status))
	var st := {"msg": ""}
	var btn := {}
	var selected := func() -> int:
		return int(list.selected) if list.selected != "" else 0
	var refresh := func() -> void:
		var names := _names()
		var now := BeDialogLogic.manager_rows(ProgramStore.groups, names)
		var keep := list.selected
		var found := false
		for r in now:
			if String(r.id) == keep:
				found = true
		if not found:
			keep = String(now[0].id) if not now.is_empty() else ""
		list.set_cells(_list_cells(now), keep)
		var n := int(keep) if keep != "" else 0
		for k in ["Rename…", "Number…", "Members…", "Delete"]:
			btn[k].disabled = n == 0
		btn["Launch"].disabled = n == 0 or LaunchGroups.member_keys(ProgramStore.groups, n).is_empty()
		status.text = String(st.msg) if String(st.msg) != "" else BeDialogLogic.manager_status(ProgramStore.groups, names)
		d.relayout()
	var said := func(msg: String, number: int) -> void:
		st.msg = msg
		if number > 0:
			list.selected = str(number)
		refresh.call()
	var actions := {
		"New…": func(): new_group(shell, said),
		"Rename…": func(): rename(shell, selected.call(), said),
		"Number…": func(): renumber(shell, selected.call(), said),
		"Members…": func(): members(shell, selected.call(), said),
		"Delete": func(): delete(shell, selected.call(), said),
		"Launch": func(): launch(shell, selected.call()),
	}
	for label in ["New…", "Rename…", "Number…", "Members…", "Delete", "", "Launch"]:
		if label == "":
			var gap := Control.new()
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			side.add_child(gap)
			continue
		var b := BeButton.make(label, false, "be.dialog.button:" + label)
		b.min_width = SIDE_W
		b.label = label  # re-measure at the side width
		var act: Callable = actions[label]
		b.pressed.connect(func():
			if not b.disabled:
				act.call())
		side.add_child(b)
		btn[label] = b
	list.picked.connect(func(_id):
		st.msg = ""
		refresh.call())
	list.activated.connect(func(_id): actions["Members…"].call())
	d.key_handler = func(k: InputEventKey) -> bool:
		match k.keycode:
			KEY_UP, KEY_DOWN:
				list.move_selection(-1 if k.keycode == KEY_UP else 1)
				return true
			KEY_DELETE:
				if selected.call() > 0:
					actions["Delete"].call()
				return true
		return false
	d.set_buttons([{"label": "Done", "default": true}])
	var on_store := func(): refresh.call()
	var sigs := [ProgramStore.groups_changed, ProgramStore.settings_changed, ProgramStore.data_reloaded]
	for s in sigs:
		(s as Signal).connect(on_store)
	# tree_exiting, not closed: the manager also goes when the whole shell is freed (a desktop switch)
	d.tree_exiting.connect(func():
		for s in sigs:
			if (s as Signal).is_connected(on_store):
				(s as Signal).disconnect(on_store))
	refresh.call()
	d.finish()
	return d


## A holder two text lines high, so a status line that wraps does not move the panel.
static func _two_lines(label: BeLabel) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size.y = 2 * BeGeometry.LINE
	box.add_child(label)
	return box


# ------------------------------------------------------------- sub-dialogs

## New…: asks for a name, makes the group on the lowest free number and opens its Members list.
static func new_group(shell: Control, said: Callable) -> void:
	var full := BeDialogLogic.new_group_error(ProgramStore.groups, _names(), "x")
	if full != "":
		BeDialogs.message(shell, [{"t": "No free launch group number", "w": 700}, full], "warning")
		return
	var d := BeDialog.open(shell.dialog_layer, "New Launch Group", 440, true, false, "be.dialog.launch-group-name")
	var number := LaunchGroups.next_free_number(ProgramStore.groups, _names())
	d.add_row(BeLabel.make("The new group gets number %d. You choose its programs next." % number, false, d.content_width()))
	var f := BeField.make("", "be.dialog.field:name")
	d.row_grid([["Name:", f]], 60)
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		var err := BeDialogLogic.new_group_error(ProgramStore.groups, _names(), f.text)
		if err != "":
			BeDialogs.message(shell, [err], "warning")
			return true
		var n: int = ProgramStore.create_launch_group(f.text)
		if n == 0:
			BeDialogs.message(shell, [BeDialogLogic.LAUNCH_GROUPS_FULL], "warning")
			return true
		said.call("Made %s." % BeDialogLogic.batch_text(n, _names()), n)
		(func(): members(shell, n, said)).call_deferred()
		return false}, {"label": "Cancel"}])
	d.finish()
	f.grab_text_focus.call_deferred()


static func rename(shell: Control, number: int, said: Callable) -> void:
	if number <= 0:
		return
	var current := LaunchGroups.name_of(_names(), number)
	var d := BeDialog.open(shell.dialog_layer, "Rename Launch Group", 460, true, false, "be.dialog.launch-group-name")
	var hint := "Leave the name blank to call it just “Group %d”." % number
	if LaunchGroups.member_keys(ProgramStore.groups, number).is_empty():
		hint = "This group has no programs, so with a blank name it is removed."
	d.add_row(BeLabel.make("Name for Group %d:" % number, false, d.content_width()))
	var f := BeField.make(current, "be.dialog.field:name")
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_row(f)
	d.add_row(BeLabel.make(hint, false, d.content_width(), "444444"))
	f.text_submitted.connect(func(_t): d.default_button.pressed.emit())
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		var cleaned := LaunchGroups.clean_name(f.text)
		ProgramStore.set_launch_group_name(number, f.text)
		if cleaned == "" and LaunchGroups.member_keys(ProgramStore.groups, number).is_empty():
			said.call("Removed Group %d: it had no name and no programs." % number, 0)
		elif cleaned == "":
			said.call("Group %d no longer has a name." % number, number)
		else:
			said.call("Renamed to %s." % BeDialogLogic.batch_text(number, _names()), number)
		return false}, {"label": "Cancel"}])
	d.finish()
	f.grab_text_focus.call_deferred()


## Number…: moves the group to another number; a taken number swaps (Launch All order changes).
static func renumber(shell: Control, number: int, said: Callable) -> void:
	if number <= 0:
		return
	var names := _names()
	var d := BeDialog.open(shell.dialog_layer, "Launch Group Number", 460, true, false, "be.dialog.launch-group-number")
	d.add_row(BeLabel.make("Move “%s” to number:" % BeDialogLogic.batch_text(number, names), false, d.content_width()))
	var sel := BeSelect.make(BeDialogLogic.number_options(ProgramStore.groups, names, number), str(number), "be.dialog.select:number", 160)
	sel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	d.add_row(sel)
	var note := BeLabel.make("", false, d.content_width(), "444444")
	d.add_row(_two_lines(note))
	var update := func(v: String) -> void:
		var t := BeDialogLogic.renumber_text(ProgramStore.groups, _names(), number, int(v))
		note.text = t if t != "" else "Launch All starts groups in number order."
		d.relayout()
	sel.changed.connect(update)
	update.call(str(number))
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		var to := int(sel.value)
		var text := BeDialogLogic.renumber_text(ProgramStore.groups, _names(), number, to)
		if ProgramStore.renumber_launch_group(number, to):
			said.call(text, to)
		return false}, {"label": "Cancel"}])
	d.finish()


static func delete(shell: Control, number: int, said: Callable) -> void:
	if number <= 0:
		return
	var label := BeDialogLogic.batch_text(number, _names())
	BeDialogs.confirm(shell, BeDialogLogic.delete_prompt(ProgramStore.groups, _names(), number), "question", "Delete", func():
		ProgramStore.delete_launch_group(number)
		said.call("Deleted %s. Its programs were kept." % label, 0), "be.dialog.launch-group-delete")


static func launch(shell: Control, number: int) -> void:
	for b in LaunchGroups.collect_launch_groups(ProgramStore.groups):
		if int(b.groupNumber) == number:
			shell.launch_buckets([b])


## Members…: a checklist of every program (folder shown on the right, other launch groups in brackets).
static func members(shell: Control, number: int, said: Callable = Callable()) -> void:
	if number <= 0:
		return
	var names := _names()
	var d := BeDialog.open(shell.dialog_layer, "%s members" % BeDialogLogic.batch_text(number, names), 520, true, false, "be.dialog.members")
	var rows := BeDialogLogic.member_rows(ProgramStore.groups, names, number)
	if rows.is_empty():
		d.add_row(BeLabel.make("There are no programs yet. Add programs to a folder first, then choose them here.", false, d.content_width()))
		d.set_buttons([{"label": "OK", "default": true}])
		d.finish()
		return
	d.add_row(BeLabel.make(BeDialogLogic.MEMBERS_HELP, false, d.content_width()))
	var cells := []
	for r in rows:
		cells.append({"id": String(r.id), "label": String(r.label), "sub": String(r.sub), "checked": bool(r.checked),
			"tex": BeIconCatalog.texture(String(r.icon), String(r.name))})
	var list := BeChoice.make("checks", cells, String(cells[0].id), d.content_width(), "be.dialog.members-list")
	d.add_row(list)
	d.key_handler = func(k: InputEventKey) -> bool:
		match k.keycode:
			KEY_UP, KEY_DOWN:
				list.move_selection(-1 if k.keycode == KEY_UP else 1)
				return true
			KEY_SPACE:
				if d.get_viewport().gui_get_focus_owner() is BeButton and d.get_viewport().gui_get_focus_owner() != d.default_button:
					return false
				list.toggle(list.selected)
				return true
		return false
	d.set_buttons([{"label": "OK", "default": true, "cb": func():
		var keys := list.checked_ids()
		var text := BeDialogLogic.members_result(ProgramStore.groups, _names(), number, keys)
		ProgramStore.set_launch_group_members(number, keys)
		if said.is_valid():
			said.call(text, number)
		return false}, {"label": "Cancel"}])
	d.finish()
