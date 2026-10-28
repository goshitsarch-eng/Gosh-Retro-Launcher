class_name W31FormDialogs
extends RefCounted
## Win31 dialogs built from rows of fields + the bottom button row: New Program Object,
## Move/Copy Program Item, Run, Help, Change Icon, New/Rename Program Group, Add URL.


static func open_help() -> void:
	UIState.open_dialog("help", {"helpTopic": "contents"})


class NewObject extends W31Dialog:
	var kind := "item"
	var groups: Array
	var preferred_group_id := ""

	func _init(p_data: Dictionary, p_groups: Array) -> void:
		super("New Program Object", 286)
		groups = p_groups
		preferred_group_id = String(p_data.get("groupId", ""))
		kind = W31DialogLogic.new_object_default_kind(groups)

	func _build(cw: int) -> void:
		add_text(2, 2, "What type of object do you want to create?")
		var box_w := cw - 10
		add_op(func(ci: CanvasItem): W31.group_frame(ci, Rect2(5, 24, box_w, 55)))
		var group := []
		var rg := W31Radio.new("Program &Group")
		var ri := W31Radio.new("Program &Item")
		rg.group = group
		ri.group = group
		group.append(rg)
		group.append(ri)
		ri.disabled = groups.is_empty()
		rg.checked = kind == "group"
		ri.checked = kind == "item"
		rg.selected.connect(func(): kind = "group")
		ri.selected.connect(func(): kind = "item")
		add_widget(rg, 5 + 1 + 12, 24 + 1 + 10)
		add_widget(ri, 5 + 1 + 12, 24 + 1 + 10 + 20)
		var ok := make_button("OK", true, _submit)
		add_button_row(91, [ok, make_button("Cancel", false, UIState.close_dialog), make_button("Help", false, W31FormDialogs.open_help)])
		_finish(91 + 4 + 22 + 8)

	func _submit() -> void:
		var next := W31DialogLogic.new_object_next(kind, preferred_group_id, groups)
		UIState.open_dialog(next.type, next.data)


class MoveCopy extends W31Dialog:
	var copy := false
	var data: Dictionary
	var item: Dictionary
	var source_group_id := ""
	var available: Array
	var combo: W31Combo

	func _init(p_copy: bool, p_data: Dictionary, groups: Array) -> void:
		super("%s Program Item" % ("Copy" if p_copy else "Move"), 330)
		copy = p_copy
		data = p_data
		item = p_data.get("item", {})
		source_group_id = String(p_data.get("groupId", ""))
		available = W31DialogLogic.move_copy_groups(groups, copy, source_group_id)

	func _build(_cw: int) -> void:
		add_text(2, 2, "%s “%s” to:" % ["Copy" if copy else "Move", item.get("name", "")])
		var names := []
		var ids := []
		for g in available:
			names.append(g.name)
			ids.append(g.id)
		var prev := combo.selected if combo else 0
		combo = W31Combo.new()
		combo.set_items(names, ids)
		combo.selected = prev
		add_form_row(24, "Program Group:", combo, _cw - 111)
		initial_focus = combo
		var ok := make_button("OK", true, _submit)
		ok.disabled = available.is_empty()
		add_button_row(48, [ok, make_button("Cancel", false, UIState.close_dialog), make_button("Help", false, W31FormDialogs.open_help)])
		_finish(48 + 4 + 22 + 8)

	func _submit() -> void:
		var dest: String = String(combo.value()) if combo.value() != null else ""
		if W31DialogLogic.apply_move_copy(ProgramStore, copy, source_group_id, dest, String(item.get("id", ""))):
			UIState.close_dialog()


class Run extends W31Dialog:
	var field: W31TextField
	var ok: W31Button
	var _busy := false

	func _init() -> void:
		super("Run", 392)

	func _build(cw: int) -> void:
		var h := add_paragraph(2, 2, "Type the name of a program, folder, document, or network resource, and Program Manager will open it for you.", cw - 4, 14)
		var y := 2 + h + 9
		var prev := field.text if field else ""
		field = W31TextField.new()
		field.set_field_size(cw - 111, 19)
		field.text = prev
		field.text_changed.connect(func(_t): _sync())
		add_form_row(y, "Command Line:", field, cw - 111)
		initial_focus = field
		ok = make_button("OK", true, func(): _submit())
		var browse := make_button("Browse...", false, func(): _browse())
		var top := y + 24
		add_button_row(top, [ok, make_button("Cancel", false, UIState.close_dialog), browse, make_button("Help", false, W31FormDialogs.open_help)])
		_sync()
		_finish(top + 4 + 22 + 8)

	func _sync() -> void:
		if ok:
			ok.disabled = field.text.strip_edges().is_empty()

	func _browse() -> void:
		var path: String = await Platform.select_executable()
		if path != "" and is_instance_valid(field):
			field.text = path
			_sync()

	func _submit() -> void:
		if _busy:
			return
		var item := W31DialogLogic.run_item(field.text)
		if item.is_empty():
			return
		_busy = true
		var result: Dictionary = await Platform.launch(item)
		_busy = false
		if result.get("success", false):
			UIState.close_dialog()
		else:
			UIState.open_dialog("confirm", {"confirmOptions": {
				"title": "Program Manager", "message": W31DialogLogic.run_error_message(result, String(item.path)),
				"onConfirm": func(): pass}})


class Help extends W31Dialog:
	var topic := "contents"
	var query := ""
	var search: W31TextField

	func _init(p_data: Dictionary) -> void:
		super("Program Manager Help", 390)
		topic = String(p_data.get("helpTopic", "contents"))

	func _build(cw: int) -> void:
		add_text(2, 2, W31DialogLogic.help_heading(topic), 11, {"bold": true})
		var well_y := 24
		var inner := 0
		if topic == "search":
			search = W31TextField.new()
			search.set_field_size(cw - 16, 19)
			search.placeholder_text = "Type a subject..."
			search.text = query
			search.text_changed.connect(_on_query)
			add_widget(search, 8, well_y + 8)
			initial_focus = search
			var topics := W31DialogLogic.help_topics(query)
			var ly := well_y + 8 + 19 + 7
			for t in topics:
				var yy := ly
				add_op(func(ci: CanvasItem): Px.fill(ci, 8 + 18 - 12 + 4, yy + 5, 4, 4, W31.BLACK))
				add_text(8 + 18, ly, t, 11, {"line_height": 14})
				ly += 14
			inner = 19 + (7 + 14 * topics.size() if not topics.is_empty() else 0)
		else:
			var body_text := W31DialogLogic.HELP_BODY_USING if topic == "using" else W31DialogLogic.HELP_BODY_CONTENTS
			inner = add_paragraph(8, well_y + 8, body_text, cw - 2 - 14, 14)
		var well_h := maxi(92, 16 + inner)
		add_op(func(ci: CanvasItem):
			Px.fill(ci, 0, well_y, cw, well_h, W31.WHITE)
			Px.outline(ci, Rect2(0, well_y, cw, well_h), W31.BLACK)
			Px.hline(ci, 1, well_y + 1, cw - 2, W31.SHADOW)
			Px.vline(ci, 1, well_y + 2, well_h - 3, W31.SHADOW), true)
		var top := well_y + well_h + 9
		var ok := make_button("OK", true, UIState.close_dialog)
		add_button_row(top, [ok])
		_finish(top + 4 + 22 + 8)

	func _on_query(t: String) -> void:
		query = t
		var caret: int = search.edit.caret_column
		_rebuild(scroll != null)
		grab_initial_focus()
		search.edit.caret_column = mini(caret, t.length())
		var p := get_parent()
		if p is Control:
			place(p.size)


class ChangeIcon extends W31Dialog:
	var data: Dictionary
	var item: Dictionary
	var group_id := ""
	var icon := "default"
	var grid: W31IconGrid

	func _init(p_data: Dictionary) -> void:
		super("Change Icon", 360)
		data = p_data
		item = p_data.get("item", {})
		group_id = String(p_data.get("groupId", ""))
		var start: Variant = item.get("win31Icon")
		if start == null:
			start = item.get("icon")
		icon = String(start) if start != null else "default"
		cancel_callable = func(): _return_to_properties(_original_icon())

	func _original_icon() -> String:
		var o: Variant = item.get("win31Icon")
		if o == null:
			o = item.get("icon")
		return String(o) if o != null else "default"

	func _build(cw: int) -> void:
		add_text(0, 0, "Select an icon for this program item:")
		grid = W31IconGrid.new(8, 5)
		grid.max_height = 150
		grid.size = Vector2(cw, 0)
		var entries := []
		for id in W31Icons.IDS:
			entries.append({"id": id, "name": id})
		grid.set_entries(entries)
		grid.selected_id = icon
		grid.chosen.connect(func(id: String): icon = id; grid.selected_id = id)
		add_widget(grid, 0, 20)
		var top := 20 + int(grid.size.y) + 9
		var ok := make_button("OK", true, _submit)
		var cancel := make_button("Cancel", false, func(): cancel())
		var browse := make_button("Browse...", false, func(): _browse())
		add_button_row(top, [ok, cancel, browse, make_button("Help", false, W31FormDialogs.open_help)])
		_finish(top + 4 + 22 + 8)

	func _browse() -> void:
		var selected: String = await Platform.select_icon()
		if selected == "":
			return
		var info: Dictionary = await Platform.get_app_info(selected)
		icon = W31DialogLogic.browse_icon_choice(info, icon)
		if is_instance_valid(grid):
			grid.selected_id = icon

	func _return_to_properties(next_icon: String) -> void:
		var copy: Dictionary = item.duplicate(true)
		copy["win31Icon"] = next_icon
		UIState.open_dialog("itemProperties", {"groupId": group_id, "item": copy})

	func _submit() -> void:
		W31DialogLogic.apply_change_icon(ProgramStore, group_id, String(item.get("id", "")), icon)
		_return_to_properties(icon)


class NewGroup extends W31Dialog:
	var data: Dictionary
	var field: W31TextField
	var ok: W31Button

	func _init(p_data: Dictionary) -> void:
		super("New Program Group", 350)
		data = p_data

	func _build(cw: int) -> void:
		var y := 0
		if data.get("openItemAfterCreate", false):
			add_text(0, y, "Create a group to add your new program item.", 12)
			y += 21
		elif data.get("openUrlAfterCreate", false):
			add_text(0, y, "Create a group to add your URL.", 12)
			y += 21
		var prev := field.text if field else ""
		field = W31TextField.new()
		field.set_field_size(cw - 111, 19)
		field.placeholder_text = "Enter group name"
		field.text = prev
		field.text_changed.connect(func(_t): _sync())
		add_form_row(y, "Description:", field, cw - 111)
		initial_focus = field
		ok = make_button("OK", true, _submit)
		add_button_row(y + 24, [ok, make_button("Cancel", false, UIState.close_dialog)])
		_sync()
		_finish(y + 24 + 4 + 22 + 8)

	func _sync() -> void:
		ok.disabled = not W31DialogLogic.group_name_valid(field.text)

	func _submit() -> void:
		var id := W31DialogLogic.apply_new_group(ProgramStore, field.text)
		if id == "":
			return
		var follow := W31DialogLogic.new_group_followup(data)
		if follow != "":
			UIState.open_dialog(follow, {"groupId": id})
		else:
			UIState.close_dialog()


class RenameGroup extends W31Dialog:
	var group: Dictionary
	var field: W31TextField
	var ok: W31Button

	func _init(p_group: Dictionary) -> void:
		super("Rename Program Group", 350)
		group = p_group

	func _build(cw: int) -> void:
		var prev := field.text if field else String(group.get("name", ""))
		field = W31TextField.new()
		field.set_field_size(cw - 111, 19)
		field.text = prev
		field.text_changed.connect(func(_t): _sync())
		add_form_row(0, "Description:", field, cw - 111)
		initial_focus = field
		ok = make_button("OK", true, _submit)
		add_button_row(24, [ok, make_button("Cancel", false, UIState.close_dialog)])
		_sync()
		_finish(24 + 4 + 22 + 8)

	func _sync() -> void:
		ok.disabled = not W31DialogLogic.group_name_valid(field.text)

	func _submit() -> void:
		if W31DialogLogic.apply_rename_group(ProgramStore, String(group.get("id", "")), field.text):
			UIState.close_dialog()


class NewUrl extends W31Dialog:
	var data: Dictionary
	var groups: Array
	var group_combo: W31Combo
	var url_field: W31TextField
	var name_field: W31TextField
	var launch_combo: W31Combo
	var ok: W31Button
	var _selected_group := ""

	func _init(p_data: Dictionary, p_groups: Array) -> void:
		super("Add URL", 420)
		data = p_data
		groups = p_groups
		_selected_group = String(p_data.get("groupId", ""))
		if _selected_group == "" and groups.size() > 0:
			_selected_group = groups[0].id

	func _build(cw: int) -> void:
		var y := 0
		var prev_url := url_field.text if url_field else ""
		var prev_name := name_field.text if name_field else ""
		var prev_launch := launch_combo.selected if launch_combo else 0
		if groups.size() > 1:
			var names := []
			var ids := []
			for g in groups:
				names.append(g.name)
				ids.append(g.id)
			group_combo = W31Combo.new()
			group_combo.set_items(names, ids)
			group_combo.select_value(_selected_group)
			group_combo.selection_changed.connect(func(_i): _selected_group = String(group_combo.value()); _sync())
			add_form_row(y, "Program Group:", group_combo, cw - 111)
			y += 24
		url_field = W31TextField.new()
		url_field.set_field_size(cw - 111, 19)
		url_field.placeholder_text = "https://example.com"
		url_field.text = prev_url
		url_field.text_changed.connect(func(_t): _sync())
		add_form_row(y, "URL:", url_field, cw - 111)
		initial_focus = url_field
		y += 24
		name_field = W31TextField.new()
		name_field.set_field_size(cw - 111, 19)
		name_field.placeholder_text = "Optional (defaults to host)"
		name_field.text = prev_name
		add_form_row(y, "Name:", name_field, cw - 111)
		y += 24
		launch_combo = W31Combo.new()
		var labels := []
		for v in W31DialogLogic.LAUNCH_GROUP_OPTIONS:
			labels.append(W31DialogLogic.format_launch_group(v))
		launch_combo.set_items(labels, W31DialogLogic.LAUNCH_GROUP_OPTIONS.duplicate())
		launch_combo.selected = prev_launch
		add_form_row(y, "Launch Group:", launch_combo, cw - 111)
		y += 24
		ok = make_button("OK", true, _submit)
		add_button_row(y, [ok, make_button("Cancel", false, UIState.close_dialog)])
		_sync()
		_finish(y + 4 + 22 + 8)

	func _sync() -> void:
		ok.disabled = not W31DialogLogic.url_form_valid(url_field.text, _selected_group)

	func _submit() -> void:
		var item := W31DialogLogic.url_item(url_field.text, name_field.text, int(launch_combo.value()), _selected_group)
		if item.is_empty():
			return
		ProgramStore.add_item(_selected_group, item)
		UIState.close_dialog()
