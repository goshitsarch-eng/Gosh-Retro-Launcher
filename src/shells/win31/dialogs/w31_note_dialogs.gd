class_name W31NoteDialogs
extends RefCounted
## Sticky notes in the WfW shell: the New Sticky Note dialog (File > New... > Sticky Note) and the
## note's Properties (title, paper colour, launch group, icon; the text is edited in the note).
## Rules live in W31DialogLogic (note_form / apply_new_note / apply_note_properties).


## The shell that hosts `from` (a dialog inside its dialog layer), or null outside a shell.
static func shell_of(from: Node) -> ShellBase:
	var n := from
	while n != null and not (n is ShellBase):
		n = n.get_parent()
	return n as ShellBase


## Opens note `id` in `shell` (or through Platform, which asks the host, when there is no shell).
static func open_note_in(shell: ShellBase, id: String) -> void:
	if id == "":
		return
	if shell != null and is_instance_valid(shell) and shell.is_inside_tree():
		shell.open_note(id)
	else:
		Platform.launch({"id": id})


class NewNote extends W31Dialog:
	var groups: Array
	var form: Dictionary
	var group_id := ""
	var group_combo: W31Combo
	var title_field: W31TextField
	var color_combo: W31Combo
	var text_field: W31TextField
	var ok: W31Button

	func _init(p_data: Dictionary, p_groups: Array) -> void:
		super("New Sticky Note", 400)
		set_auto_id("wfw.dialog.new-note")
		groups = p_groups
		form = W31DialogLogic.note_form()
		group_id = String(p_data.get("groupId", ""))
		if ProgramStore.find_group(group_id).is_empty() and groups.size() > 0:
			group_id = String(groups[0].id)

	func _build(cw: int) -> void:
		var fw := cw - 111
		var y := 0
		if groups.size() > 1:
			var names := []
			var ids := []
			for g in groups:
				names.append(String(g.name))
				ids.append(String(g.id))
			group_combo = W31Combo.new()
			group_combo.set_items(names, ids)
			group_combo.select_value(group_id)
			group_combo.set_auto_id("wfw.dialog.note-group")
			group_combo.selection_changed.connect(func(_i): group_id = String(group_combo.value()); _sync())
			add_form_row(y, "Program Group:", group_combo, fw)
			y += 24
		title_field = W31TextField.new()
		title_field.set_field_size(fw, 19)
		title_field.placeholder_text = "Note"
		title_field.text = String(form.name)
		title_field.set_auto_id("wfw.dialog.note-title")
		title_field.text_changed.connect(func(t: String): form.name = t)
		add_form_row(y, "Title:", title_field, fw)
		initial_focus = title_field
		y += 24
		color_combo = W31Combo.new()
		var colors := W31DialogLogic.note_color_choices()
		color_combo.set_items(colors.labels, colors.values)
		color_combo.select_value(String(form.noteColor))
		color_combo.set_auto_id("wfw.dialog.note-color")
		color_combo.selection_changed.connect(func(_i): form.noteColor = String(color_combo.value()))
		add_form_row(y, "Color:", color_combo, fw)
		y += 24
		text_field = W31TextField.new(true)
		text_field.set_field_size(fw, 69)
		text_field.placeholder_text = "Optional"
		text_field.text = String(form.text)
		text_field.set_auto_id("wfw.dialog.note-text")
		text_field.text_changed.connect(func(t: String): form.text = t)
		add_form_row(y, "Text:", text_field, fw, 69)
		y += 69 + 5
		ok = make_button("OK", true, _submit)
		add_button_row(y, [ok, make_button("Cancel", false, UIState.close_dialog), make_button("Help", false, W31FormDialogs.open_help)])
		_sync()
		_finish(y + 4 + 22 + 8)

	func _sync() -> void:
		if ok:
			ok.disabled = not W31DialogLogic.note_form_valid(group_id)

	func _submit() -> void:
		var shell := W31NoteDialogs.shell_of(self)
		var id := W31DialogLogic.apply_new_note(ProgramStore, group_id, form)
		if id == "":
			return
		UIState.close_dialog()
		W31NoteDialogs.open_note_in(shell, id)


class NoteProperties extends W31Dialog:
	var data: Dictionary
	var existing: Dictionary
	var group_id := ""
	var form: Dictionary
	var ok: W31Button

	func _init(p_data: Dictionary, groups: Array) -> void:
		super("Sticky Note Properties", 400)
		set_auto_id("wfw.dialog.note-properties")
		data = p_data
		existing = p_data.get("item", {})
		group_id = W31DialogLogic.resolve_item_group(groups, data)
		form = W31DialogLogic.note_form(existing)

	func _build(cw: int) -> void:
		var bw := W31PropertiesDialogs.BUTTON_COL_W
		var fw := cw - bw - 4 - W31PropertiesDialogs.COL_GAP
		var title := W31TextField.new()
		title.set_field_size(fw - 111, 19)
		title.text = String(form.name)
		title.set_auto_id("wfw.dialog.note-title")
		title.text_changed.connect(func(t: String): form.name = t)
		add_form_row(0, "Title:", title, fw - 111)
		initial_focus = title
		var color := W31Combo.new()
		var colors := W31DialogLogic.note_color_choices()
		color.set_items(colors.labels, colors.values)
		color.select_value(String(form.noteColor))
		color.set_auto_id("wfw.dialog.note-color")
		color.selection_changed.connect(func(_i): form.noteColor = String(color.value()))
		add_form_row(24, "Color:", color, fw - 111)
		var lg := W31Combo.new()
		var choices := W31DialogLogic.launch_group_choices(ProgramStore.launch_group_names(), int(form.launchGroup))
		lg.set_items(choices.labels, choices.values)
		lg.select_value(int(form.launchGroup))
		lg.set_auto_id("wfw.dialog.note-launch-group")
		lg.selection_changed.connect(func(_i): form.launchGroup = int(lg.value()))
		add_form_row(48, "Launch Group:", lg, fw - 111)
		add_label(0, 72, "Icon:")
		add_widget(W31IconWell.new(String(form.win31Icon)), 111, 72)
		ok = make_button("OK", true, _submit)
		var col_h := W31PropertiesDialogs._button_column(self, fw + W31PropertiesDialogs.COL_GAP, [
			ok, make_button("Cancel", false, UIState.close_dialog), make_button("Change Icon...", false, _change_icon),
			make_button("Help", false, W31FormDialogs.open_help)])
		_finish(maxi(72 + 42 + 5, col_h))

	## Change Icon returns here with a copy of the item, so what was typed so far goes with it.
	func _change_icon() -> void:
		var item: Dictionary = existing.duplicate(true)
		item["name"] = form.name
		item["noteColor"] = form.noteColor
		item["launchGroup"] = form.launchGroup
		item["win31Icon"] = form.win31Icon
		UIState.open_dialog("changeIcon", {"groupId": group_id, "item": item})

	func _submit() -> void:
		if W31DialogLogic.apply_note_properties(ProgramStore, group_id, String(existing.get("id", "")), form):
			UIState.close_dialog()
