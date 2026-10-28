class_name Win95Properties
extends RefCounted
## Tabbed property sheets (ports of ItemPropertySheet / GroupPropertySheet in Win95Dialogs.tsx).
##   Win95Properties.open_item(shell, group_id, item)   # "<name> Properties": Shortcut + Program tabs
##   Win95Properties.open_group(shell, group)            # "<name> Properties": General tab
## OK = apply then close; Apply is enabled only while the sheet is dirty; invalid fields (blank
## name/command) are not applied (see Win95DialogLogic.apply_*). Desktop objects use a message box
## (Win95Dialogs.show_message), as in the original.

const CX := 9.0
const PAGE_TOP := 32.0   ## body y of the page frame (tab strip 23 px - 1 px overlap + 10 px content top)


## The sunken sheet page frame (1px light/shadow border).
class _Page extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Win95Draw.border(self, Rect2(Vector2.ZERO, size), 1, Win95Draw.LIGHT, Win95Draw.SHADOW, Win95Draw.SHADOW, Win95Draw.LIGHT)


static func _button(label: String) -> Win95Button:
	var b := Win95Button.new()
	b.label = label
	return b


static func _row(m: Win95Modal, parent: Control, label: String, y: float, field: Control, cw: float) -> void:
	var l := Win95Label.make(label, Vector2.ZERO)
	var ox := CX + 10.0
	parent.add_child(l)
	l.position = Vector2(ox + 105 - l.size.x, y + 4)
	parent.add_child(field)
	field.position = Vector2(ox + 111, y)
	field.size = Vector2(cw - 2 - 18 - 111, 21)


static func _buttons(m: Win95Modal, y: float) -> Array:
	var ok := _button("&OK")
	var cancel := _button("&Cancel")
	var apply := _button("&Apply")
	apply.disabled = true
	var x: float = m.body.size.x - 9.0
	for b in [apply, cancel, ok]:
		x -= b.size.x
		m.add(b, Vector2(x, y))
		x -= 6.0
	m.set_default(ok)
	cancel.pressed.connect(m.close)
	return [ok, cancel, apply]


static func open_group(shell: Control, group: Dictionary) -> void:
	if group.is_empty() or ProgramStore.find_group(String(group.get("id", ""))).is_empty():
		Win95Dialogs.show_message(shell, "Properties", "The folder no longer exists.", "warning")
		return
	var gid: String = group.id
	var live := ProgramStore.find_group(gid)
	var m := Win95Modal.open(shell, "%s Properties" % live.name, Vector2(365, 285))
	var cw: float = m.body.size.x - 18
	var page := _Page.new()
	page.position = Vector2(CX, PAGE_TOP)
	page.size = Vector2(cw, 154)
	m.body.add_child(page)
	var strip := Win95TabStrip.new()
	strip.position = Vector2(CX, 10)
	strip.size = Vector2(cw, 23)
	strip.configure([{"id": "general", "label": "&General"}], "sheet", "general")
	m.body.add_child(strip)
	var ox := CX + 10.0
	var oy := PAGE_TOP + 12.0
	m.add(Win95IconBox.make("folder", Vector2.ZERO), Vector2(ox, oy))
	m.add(Win95Label.make(String(live.name), Vector2.ZERO, {"bold": true}), Vector2(ox + 42, oy))
	var edit := Win95TextInput.new()
	edit.text = String(live.name)
	var label := Win95Label.make("&Name:", Vector2.ZERO)
	m.add(label, Vector2(ox + 105 - label.size.x, oy + 41 + 4))
	m.add(edit, Vector2(ox + 111, oy + 41))
	edit.size = Vector2(cw - 2 - 18 - 111, 21)
	var n: int = live.items.size()
	m.add(Win95Label.make("Contains %s." % Win95DialogLogic.plural_objects(n), Vector2.ZERO), Vector2(ox, oy + 41 + 21 + 5))
	var btns := _buttons(m, PAGE_TOP + 154 + 12)
	var ok: Win95Button = btns[0]
	var apply: Win95Button = btns[2]
	edit.text_changed.connect(func(_t): apply.disabled = false)
	apply.pressed.connect(func():
		if Win95DialogLogic.apply_group_properties(ProgramStore, gid, edit.text):
			apply.disabled = true)
	ok.pressed.connect(func():
		Win95DialogLogic.apply_group_properties(ProgramStore, gid, edit.text)
		m.close())
	edit.focus_edit()


static func open_item(shell: Control, group_id: String, item: Dictionary) -> void:
	var live := ProgramStore.find_item(group_id, String(item.get("id", ""))) if item.has("id") else {}
	if live.is_empty():
		var found := Win95DialogLogic.group_of_item(ProgramStore, String(item.get("id", "")))
		if found != "":
			group_id = found
			live = ProgramStore.find_item(group_id, String(item.id))
	if live.is_empty():
		Win95Dialogs.show_message(shell, "Properties", "The shortcut no longer exists.", "warning")
		return
	var item_id: String = live.id
	var state := {"group": group_id}
	var m := Win95Modal.open(shell, "%s Properties" % live.name, Vector2(420, 285))
	var cw: float = m.body.size.x - 18
	var page := _Page.new()
	page.position = Vector2(CX, PAGE_TOP)
	page.size = Vector2(cw, 161)
	m.body.add_child(page)
	var strip := Win95TabStrip.new()
	strip.position = Vector2(CX, 10)
	strip.size = Vector2(cw, 23)
	strip.configure([{"id": "shortcut", "label": "&Shortcut"}, {"id": "program", "label": "&Program"}], "sheet", "shortcut")
	m.body.add_child(strip)
	var ox := CX + 10.0
	var oy := PAGE_TOP + 12.0
	var shortcut_page := Control.new()
	shortcut_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var program_page := Control.new()
	program_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.body.add_child(shortcut_page)
	m.body.add_child(program_page)
	program_page.visible = false
	shortcut_page.add_child(Win95IconBox.make(String(live.get("icon", "")), Vector2(ox, oy)))
	shortcut_page.add_child(Win95Label.make(String(live.name), Vector2(ox + 42, oy), {"bold": true}))
	var name_edit := Win95TextInput.new()
	name_edit.text = String(live.name)
	var cmd_edit := Win95TextInput.new()
	cmd_edit.text = String(live.path)
	var dir_edit := Win95TextInput.new()
	dir_edit.text = String(live.get("workingDir", ""))
	var group_select := Win95Select.new()
	group_select.shell = shell
	group_select.options = ProgramStore.groups.map(func(g): return String(g.name))
	for i in ProgramStore.groups.size():
		if ProgramStore.groups[i].id == group_id:
			group_select.selected_index = i
	_row(m, shortcut_page, "&Description:", oy + 41, name_edit, cw)
	_row(m, shortcut_page, "&Command line:", oy + 41 + 26, cmd_edit, cw)
	_row(m, shortcut_page, "&Working directory:", oy + 41 + 52, dir_edit, cw)
	_row(m, shortcut_page, "Program &group:", oy + 41 + 78, group_select, cw)
	var args_edit := Win95TextInput.new()
	args_edit.text = String(live.get("arguments", ""))
	var run_select := Win95Select.new()
	run_select.shell = shell
	run_select.options = Win95DialogLogic.RUN_MODE_LABELS
	run_select.selected_index = maxi(0, Win95DialogLogic.RUN_MODES.find(String(live.get("runMode", "normal"))))
	_row(m, program_page, "&Arguments:", oy, args_edit, cw)
	_row(m, program_page, "&Run:", oy + 26, run_select, cw)
	var close_on_exit := Win95Checkbox.new()
	close_on_exit.label = "Close on e&xit"
	close_on_exit.checked = true
	close_on_exit.disabled = true
	program_page.add_child(close_on_exit)
	close_on_exit.position = Vector2(ox, oy + 52 + 4)
	strip.tab_selected.connect(func(id):
		shortcut_page.visible = id == "shortcut"
		program_page.visible = id == "program")
	var btns := _buttons(m, PAGE_TOP + 161 + 12)
	var ok: Win95Button = btns[0]
	var apply: Win95Button = btns[2]
	var dirty := func(_x = null): apply.disabled = false
	for e in [name_edit, cmd_edit, dir_edit, args_edit]:
		e.text_changed.connect(dirty)
	group_select.item_selected.connect(dirty)
	run_select.item_selected.connect(dirty)
	var do_apply := func() -> bool:
		var gi := clampi(group_select.selected_index, 0, maxi(0, ProgramStore.groups.size() - 1))
		var result := Win95DialogLogic.apply_item_properties(ProgramStore, state.group, item_id, {
			"name": name_edit.text, "command": cmd_edit.text, "workingDir": dir_edit.text, "arguments": args_edit.text,
			"runMode": Win95DialogLogic.RUN_MODES[clampi(run_select.selected_index, 0, 2)],
			"groupId": String(ProgramStore.groups[gi].id) if ProgramStore.groups.size() > 0 else ""})
		if result.ok:
			state.group = result.groupId
		return result.ok
	apply.pressed.connect(func():
		if do_apply.call():
			apply.disabled = true)
	ok.pressed.connect(func():
		do_apply.call()
		m.close())
	name_edit.focus_edit()
