class_name W31PropertiesDialogs
extends RefCounted
## Program Group Properties and Program Item Properties / New Program Item (Win31 layout:
## fields on the left, 78px button column on the right).

const BUTTON_COL_W := 78
const COL_GAP := 10


## Stacks the property buttons (78px wide, 7px apart); returns the bottom y.
static func _button_column(dlg: W31Dialog, x: int, buttons: Array) -> int:
	var y := 0
	for b in buttons:
		(b as W31Button).wrap_text = true
		var s: Vector2 = b.fit(BUTTON_COL_W)
		dlg.add_widget(b, x, y, s)
		y += int(s.y) + 7
	return y - 7


class GroupProperties extends W31Dialog:
	var group: Dictionary
	var name_text := ""
	var icon := "folder"
	var show_picker := false
	var name_field: W31TextField
	var file_field: W31TextField
	var ok: W31Button

	func _init(p_data: Dictionary) -> void:
		super("Program Group Properties", 390)
		group = p_data.get("group", {})
		name_text = String(group.get("name", ""))
		icon = String(group.get("icon", "")) if String(group.get("icon", "")) != "" else "folder"
		show_picker = p_data.get("showIconPicker", false)

	func _build(cw: int) -> void:
		var fw := cw - BUTTON_COL_W - 4 - COL_GAP
		name_field = W31TextField.new()
		name_field.set_field_size(fw - 111, 19)
		name_field.text = name_text
		name_field.text_changed.connect(_on_name)
		add_form_row(0, "Description:", name_field, fw - 111)
		initial_focus = name_field
		file_field = W31TextField.new()
		file_field.set_field_size(fw - 111, 19)
		file_field.read_only = true
		file_field.text = W31DialogLogic.group_file_name(name_text)
		add_form_row(24, "Group File:", file_field, fw - 111)
		add_label(0, 48, "Icon:")
		var well := W31IconWell.new(icon)
		add_widget(well, 111, 48)
		var fields_h := 95
		if show_picker:
			var grid := W31IconGrid.new(7, 4)
			grid.size = Vector2(fw, 0)
			var entries := []
			for id in W31Icons.IDS:
				entries.append({"id": id, "name": id})
			grid.set_entries(entries)
			grid.selected_id = icon
			grid.chosen.connect(func(id: String):
				icon = id
				well.icon = id
				grid.selected_id = id)
			add_widget(grid, 0, 95)
			fields_h = 95 + int(grid.size.y)
		ok = make_button("OK", true, _submit)
		var change := make_button("Hide Icons" if show_picker else "Change Icon...", false, _toggle_picker)
		var col_x := fw + COL_GAP
		var col_h := W31PropertiesDialogs._button_column(self, col_x, [
			ok, make_button("Cancel", false, UIState.close_dialog), change,
			make_button("Delete", false, _delete), make_button("Help", false, W31FormDialogs.open_help)])
		_sync()
		_finish(maxi(fields_h, col_h))

	func _refresh_icon() -> void:
		_rebuild(scroll != null)
		grab_initial_focus()
		var p := get_parent()
		if p is Control:
			place(p.size)

	func _on_name(t: String) -> void:
		name_text = t
		file_field.text = W31DialogLogic.group_file_name(t)
		_sync()

	func _sync() -> void:
		ok.disabled = not W31DialogLogic.group_name_valid(name_text)

	func _toggle_picker() -> void:
		show_picker = not show_picker
		_refresh_icon()

	func _submit() -> void:
		if W31DialogLogic.apply_group_properties(ProgramStore, String(group.get("id", "")), name_text, icon):
			UIState.close_dialog()

	func _delete() -> void:
		var gid := String(group.get("id", ""))
		UIState.open_dialog("confirm", {"confirmOptions": {
			"title": "Delete Group",
			"message": "Are you sure you want to delete \"%s\" and all its items?" % group.get("name", ""),
			"onConfirm": func():
				MdiState.close_window(gid)
				ProgramStore.delete_group(gid)}})


class ItemProperties extends W31Dialog:
	var data: Dictionary
	var existing: Dictionary
	var is_editing := false
	var resolved_group_id := ""
	var selected_group_id := ""
	var form: Dictionary
	var show_picker := false
	var icon_search := ""
	var ok: W31Button
	var _focus_filter := false
	var _fields := {}  ## key -> W31TextField

	func _init(p_data: Dictionary, groups: Array) -> void:
		data = p_data
		existing = p_data.get("item", {})
		is_editing = not existing.is_empty()
		super("Program Item Properties" if is_editing else "New Program Item", 470)
		resolved_group_id = W31DialogLogic.resolve_item_group(groups, data)
		selected_group_id = resolved_group_id
		form = W31DialogLogic.item_form(existing)

	func _text_row(y: int, label: String, key: String, fw: int, multiline: bool = false) -> void:
		var tf := W31TextField.new(multiline)
		var h := 43 if multiline else 19
		tf.set_field_size(fw - 111, h)
		tf.text = String(form[key])
		if multiline:
			tf.placeholder_text = "KEY=VALUE (one per line)"
		tf.text_changed.connect(func(t: String):
			form[key] = t
			_sync())
		add_form_row(y, label, tf, fw - 111, h)
		_fields[key] = tf

	func _build(cw: int) -> void:
		var fw := cw - BUTTON_COL_W - 4 - COL_GAP
		_fields.clear()
		_text_row(0, "Description:", "name", fw)
		initial_focus = _fields["name"]
		_text_row(24, "Command Line:", "path", fw)
		_text_row(48, "Working Directory:", "workingDir", fw)
		_text_row(72, "Arguments:", "arguments", fw)
		_text_row(96, "Environment:", "environment", fw, true)
		_text_row(144, "Shortcut Key:", "shortcutKey", fw)
		var run := W31Combo.new()
		run.set_items(["Normal Window", "Minimized", "Maximized"], ["normal", "minimized", "maximized"])
		run.select_value(form.runMode)
		run.selection_changed.connect(func(_i): form.runMode = run.value())
		add_form_row(168, "Run:", run, fw - 111)
		var lg := W31Combo.new()
		var labels := []
		for v in W31DialogLogic.LAUNCH_GROUP_OPTIONS:
			labels.append(W31DialogLogic.format_launch_group(v))
		lg.set_items(labels, W31DialogLogic.LAUNCH_GROUP_OPTIONS.duplicate())
		lg.select_value(int(form.launchGroup))
		lg.selection_changed.connect(func(_i): form.launchGroup = int(lg.value()))
		add_form_row(192, "Launch Group:", lg, fw - 111)
		add_label(0, 216, "Icon:")
		var well := W31IconWell.new(String(form.win31Icon))
		add_widget(well, 111, 216)
		var fields_h := 216 + 42 + 5
		if show_picker and not is_editing:
			var y := fields_h + 5
			var filter := W31TextField.new()
			filter.set_field_size(fw, 19)
			filter.placeholder_text = "Filter icons..."
			filter.text = icon_search
			filter.text_changed.connect(func(t: String):
				icon_search = t
				_focus_filter = true
				_refresh())
			add_widget(filter, 0, y)
			if _focus_filter:
				initial_focus = filter
			y += 19 + 4
			var grid := W31IconGrid.new(7, 4)
			grid.size = Vector2(fw, 0)
			var entries := []
			for id in W31Icons.filter_ids(icon_search):
				entries.append({"id": id, "name": id})
			grid.set_entries(entries)
			grid.selected_id = String(form.icon)
			grid.chosen.connect(func(id: String):
				form.win31Icon = id
				form.icon = id
				well.icon = id
				grid.selected_id = id)
			add_widget(grid, 0, y)
			fields_h = y + int(grid.size.y) + 5
		ok = make_button("OK", true, _submit)
		var browse := make_button("Browse...", false, func(): _browse())
		var change := make_button("Hide Icons" if show_picker else "Change Icon...", false, _change_icon)
		var col_h := W31PropertiesDialogs._button_column(self, fw + COL_GAP, [
			ok, make_button("Cancel", false, UIState.close_dialog), browse, change,
			make_button("Help", false, W31FormDialogs.open_help)])
		_sync()
		_finish(maxi(fields_h, col_h))

	func _refresh() -> void:
		_rebuild(scroll != null)
		grab_initial_focus()
		var p := get_parent()
		if p is Control:
			place(p.size)

	func _sync() -> void:
		if ok:
			ok.disabled = not W31DialogLogic.item_form_valid(form, selected_group_id)

	func _change_icon() -> void:
		if is_editing:
			var item: Dictionary = existing.duplicate(true)
			for k in ["name", "path", "workingDir", "arguments", "environment", "runMode", "shortcutKey", "icon", "win31Icon", "launchGroup"]:
				item[k] = form[k]
			UIState.open_dialog("changeIcon", {"groupId": resolved_group_id, "item": item})
		else:
			show_picker = not show_picker
			_focus_filter = false
			_refresh()

	func _browse() -> void:
		var selected: String = await Platform.select_executable()
		if selected == "":
			return
		var info: Dictionary = await Platform.get_app_info(selected)
		form = W31DialogLogic.apply_browse_result(form, selected, info)
		if not is_instance_valid(self):
			return
		for k in _fields:
			(_fields[k] as W31TextField).text = String(form[k])
		_sync()

	func _submit() -> void:
		if W31DialogLogic.apply_item_properties(ProgramStore, form, existing, resolved_group_id, selected_group_id) != "":
			UIState.close_dialog()
