class_name MacLaunchGroups
extends Node
## The Launch Groups manager (Special > Launch Groups…): the defined launch groups (number, name, member count)
## with New…, Rename…, Members…, Delete…, Launch and a Number pop-up that renumbers (swapping with a group already
## on that number). It lives as a child of its MacDialog and rebuilds whenever the store changes. New, Rename,
## Members and the Delete confirmation open on top of it and hand back when they close. The wording and the store
## calls are in MacDialogLogic (unit-tested); ProgramStore does the work.

const W := 460
const H := 320
const LIST_RECT := Rect2(14, 46, 300, 162)   ## eight 20 px rows + frame

var shell: Control
var dialog: MacDialog
var list: MacListBox
var number_label: MacLabel
var number_sel: MacSelect
var status: MacLabel
var buttons := {}


static func open(p_shell: Control) -> MacDialog:
	var d := MacDialog.open(p_shell, "Launch Groups", Vector2(W, H), true)
	var m := MacLaunchGroups.new()
	m.shell = p_shell
	m.dialog = d
	d.add_child(m)
	m._build()
	return d


func _build() -> void:
	var d := dialog
	d.add(MacLabel.make("Programs in a launch group start together. Launch All starts the groups in number order.",
		{"wrap": 420}), Vector2(14, 12))
	list = MacListBox.new("mac.launch-groups")
	list.empty_text = "No launch groups yet. Click New to make one."
	d.add(list, LIST_RECT.position)
	list.size = LIST_RECT.size
	var bx := LIST_RECT.end.x + 14
	var bw := int(d.body.size.x - 14 - bx)
	var actions := [["new", "New…"], ["rename", "Rename…"], ["members", "Members…"], ["delete", "Delete…"]]
	for i in actions.size():
		var b := MacButton.new(String(actions[i][1]), bw)
		b.set_meta("auto_id", "mac.launch-groups." + String(actions[i][0]))
		d.add(b, Vector2(bx, LIST_RECT.position.y + i * 28))
		buttons[actions[i][0]] = b
	var launch := MacButton.new("Launch", bw)
	launch.set_meta("auto_id", "mac.launch-groups.launch")
	d.add(launch, Vector2(bx, LIST_RECT.end.y - 20))
	buttons["launch"] = launch
	number_label = MacLabel.make("Number:", {"bold": true})
	d.add(number_label, Vector2(14, LIST_RECT.end.y + 14))
	number_sel = MacSelect.new("mac.launch-groups.number")
	number_sel.host = shell.select_layer
	d.add(number_sel, Vector2(14 + number_label.size.x + 8, LIST_RECT.end.y + 10))
	number_sel.size = Vector2(LIST_RECT.end.x - number_sel.position.x, 22)
	var done := MacButton.new("Done", 66)
	done.set_meta("auto_id", "mac.launch-groups.done")
	d.button_row([done], d.body.size.y - 12 - 20, 18.0)
	d.set_default(done)
	done.pressed.connect(d.close)
	buttons["new"].pressed.connect(new_group)
	buttons["rename"].pressed.connect(rename_group)
	buttons["members"].pressed.connect(func(): edit_members(selected_number()))
	buttons["delete"].pressed.connect(delete_group)
	launch.pressed.connect(launch_group)
	number_sel.selected.connect(func(_i: int): renumber(number_sel.current_id().to_int()))
	list.selection_changed.connect(func(_id: String): _sync_controls())
	list.activated.connect(func(id: String): edit_members(id.to_int()))
	d.on_key = _on_key
	refresh()


func _ready() -> void:
	for sig in [ProgramStore.groups_changed, ProgramStore.settings_changed, ProgramStore.data_reloaded]:
		sig.connect(refresh)


func _exit_tree() -> void:
	for sig in [ProgramStore.groups_changed, ProgramStore.settings_changed, ProgramStore.data_reloaded]:
		if sig.is_connected(refresh):
			sig.disconnect(refresh)


func selected_number() -> int:
	return list.selected_id.to_int() if list.index_of(list.selected_id) >= 0 else 0


func _selected_row() -> Dictionary:
	var i := list.index_of(list.selected_id)
	return list.rows[i] if i >= 0 else {}


## Rebuilds the list from the store, keeping the selection when the group still exists.
func refresh() -> void:
	if list == null:
		return
	list.rows = MacDialogLogic.launch_group_rows(ProgramStore.groups, ProgramStore.launch_group_names())
	if list.index_of(list.selected_id) < 0:
		list.selected_id = String(list.rows[0].id) if not list.rows.is_empty() else ""
	list.ensure_visible(list.selected_id)
	list.queue_redraw()
	_sync_controls()


func _sync_controls() -> void:
	var n := selected_number()
	var row := _selected_row()
	for k in ["rename", "members", "delete"]:
		buttons[k].disabled = n == 0
	buttons["launch"].disabled = n == 0 or int(row.get("count", 0)) == 0
	number_label.visible = n > 0
	number_sel.visible = n > 0
	if n > 0:
		number_sel.options = MacDialogLogic.number_options(ProgramStore.groups, ProgramStore.launch_group_names(), n)
		number_sel.selected_index = 0
		number_sel.select_id(str(n))


func set_status(text: String) -> void:
	if status != null and is_instance_valid(status):
		status.queue_free()
	status = MacLabel.make(text, {"wrap": int(LIST_RECT.size.x)})
	dialog.add(status, Vector2(14, LIST_RECT.end.y + 40))


func _select(number: int) -> void:
	refresh()
	if list.index_of(str(number)) >= 0:
		list.select(str(number))


func _on_key(k: InputEventKey) -> bool:
	if k.ctrl_pressed or k.meta_pressed or k.alt_pressed:
		return false
	if k.keycode == KEY_UP or k.keycode == KEY_DOWN:
		list.step(-1 if k.keycode == KEY_UP else 1)
		return true
	return false


# ------------------------------------------------------------------ actions

func new_group() -> MacDialog:
	var names := ProgramStore.launch_group_names()
	if LaunchGroups.next_free_number(ProgramStore.groups, names) == 0:
		return MacDialogs.message(shell, MacDialogLogic.ALL_NUMBERS_IN_USE, "caution")
	var d := MacDialog.open(shell, "New Launch Group", Vector2(380, 160), true)
	d.add(MacLabel.make(MacDialogLogic.new_group_prompt(ProgramStore.groups, names), {"wrap": 340}), Vector2(14, 12))
	var f := MacTextField.new("mac.dialog.field:Name")
	MacDialogs._field_row(d, "Name:", 50, f)
	var b := MacDialogs._buttons(d)
	b[0].pressed.connect(func():
		var r := MacDialogLogic.new_launch_group(ProgramStore, f.text)
		if String(r.error) != "":
			MacDialogs.message(shell, String(r.error), "caution")
			return
		d.close()
		_select(int(r.number))
		set_status("Group %d was created." % int(r.number))
		edit_members(int(r.number)))
	f.focus_edit()
	return d


func rename_group() -> MacDialog:
	var n := selected_number()
	if n == 0:
		return null
	var d := MacDialog.open(shell, "Rename Group %d" % n, Vector2(380, 160), true)
	var f := MacTextField.new("mac.dialog.field:Name")
	f.text = LaunchGroups.name_of(ProgramStore.launch_group_names(), n)
	MacDialogs._field_row(d, "Name:", 14, f)
	d.add(MacLabel.make(MacDialogLogic.rename_hint(int(_selected_row().get("count", 0))), {"wrap": 340}), Vector2(14, 48))
	var b := MacDialogs._buttons(d)
	b[0].pressed.connect(func():
		var text := MacDialogLogic.rename_launch_group(ProgramStore, n, f.text)
		d.close()
		refresh()
		set_status(text))
	f.focus_edit()
	f.edit.select_all()
	return d


func edit_members(n: int) -> MacDialog:
	if n <= 0:
		return null
	var names := ProgramStore.launch_group_names()
	var d := MacDialog.open(shell, LaunchGroups.format_launch_group(n, names), Vector2(440, 340), true)
	d.add(MacLabel.make("Check the programs Group %d starts. A program is in one launch group at a time, so checking one marked with another group moves it here." % n,
		{"wrap": 400}), Vector2(14, 12))
	var checklist := MacListBox.new("mac.launch-group-members")
	checklist.checks = true
	checklist.empty_text = "There are no programs yet. Add some to a folder first."
	checklist.rows = MacDialogLogic.member_rows(ProgramStore.groups, n, names)
	if not checklist.rows.is_empty():
		checklist.selected_id = String(checklist.rows[0].id)
	d.add(checklist, Vector2(14, 52))
	checklist.size = Vector2(d.body.size.x - 28, 202)
	var summary := [MacLabel.make(MacDialogLogic.members_summary(checklist.rows), {})]
	d.add(summary[0], Vector2(14, d.body.size.y - 12 - 20 + 4))
	checklist.toggled.connect(func(_id: String, _on: bool):
		summary[0].queue_free()
		summary[0] = MacLabel.make(MacDialogLogic.members_summary(checklist.rows), {})
		d.add(summary[0], Vector2(14, d.body.size.y - 12 - 20 + 4)))
	var b := MacDialogs._buttons(d)
	b[0].pressed.connect(func():
		var keys := MacDialogLogic.checked_keys(checklist.rows)
		var had_name := LaunchGroups.name_of(ProgramStore.launch_group_names(), n) != ""
		ProgramStore.set_launch_group_members(n, keys)
		d.close()
		_select(n)
		set_status(MacDialogLogic.members_status(n, keys.size(), had_name)))
	d.on_key = func(k: InputEventKey) -> bool:
		if k.ctrl_pressed or k.meta_pressed or k.alt_pressed:
			return false
		if k.keycode == KEY_UP or k.keycode == KEY_DOWN:
			checklist.step(-1 if k.keycode == KEY_UP else 1)
			return true
		if k.keycode == KEY_SPACE:
			checklist.toggle(checklist.selected_id)
			return true
		return false
	return d


func delete_group() -> MacDialog:
	var n := selected_number()
	if n == 0:
		return null
	var names := ProgramStore.launch_group_names()
	var label := LaunchGroups.format_launch_group(n, names)
	return MacDialogs.confirm(shell, MacDialogLogic.delete_prompt(ProgramStore.groups, names, n), func():
		ProgramStore.delete_launch_group(n)
		refresh()
		set_status("%s was deleted. Its programs were kept." % label), "caution", "Delete", "Cancel")


func renumber(to: int) -> void:
	var n := selected_number()
	if n == 0 or to == n:
		return
	var r := MacDialogLogic.renumber_launch_group(ProgramStore, n, to)
	if r.ok:
		_select(to)
		set_status(String(r.status))


func launch_group() -> void:
	var n := selected_number()
	for bucket in LaunchGroups.collect_launch_groups(ProgramStore.groups):
		if int(bucket.groupNumber) == n:
			dialog.close()
			shell.launch_buckets([bucket])
			return
