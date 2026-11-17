class_name W31LaunchGroupDialogs
extends RefCounted
## Launcher > Launch Groups...: the manager (list of launch groups with a 78px button column, like
## the WfW Fonts / Drivers boxes) and the dialogs it opens in the single WfW dialog slot: New /
## Rename (name), Number, Members (checklist of every program). Each sub-dialog goes back to the
## manager when it closes, with the group selected and a line saying what changed.
## The rules live in W31DialogLogic; `store` is ProgramStore unless a test passes a scratch store.

const BUTTON_COL_W := 78
const COL_GAP := 10


## Shows the manager with launch group `selected` highlighted and `status` under the list.
static func open_manager(selected: int = 0, status: String = "") -> void:
	UIState.open_dialog("launchGroups", {"selected": selected, "status": status})


## Same, after the current dialog has finished closing (Confirm closes itself after its callback).
static func open_manager_later(selected: int = 0, status: String = "") -> void:
	(func() -> void: open_manager(selected, status)).call_deferred()


static func _names(store: Node) -> Dictionary:
	return store.launch_group_names()


## Base of the four dialogs: store access and a deferred rebuild when the store changes.
class _Base extends W31Dialog:
	var store: Node
	var _refresh_queued := false

	func _init(p_title: String, p_width: int, p_store: Node) -> void:
		super(p_title, p_width)
		store = p_store if p_store != null else ProgramStore

	func _enter_tree() -> void:
		for sig in ["groups_changed", "settings_changed"]:
			if store.has_signal(sig) and not store.is_connected(sig, _queue_refresh):
				store.connect(sig, _queue_refresh)

	func _exit_tree() -> void:
		for sig in ["groups_changed", "settings_changed"]:
			if store.has_signal(sig) and store.is_connected(sig, _queue_refresh):
				store.disconnect(sig, _queue_refresh)

	func _queue_refresh() -> void:
		if _refresh_queued or _closing:
			return
		_refresh_queued = true
		refresh.call_deferred()

	## Rebuilds from the store's current data (an import, another window or the store itself
	## changed it), keeping the dialog where it is.
	func refresh() -> void:
		_refresh_queued = false
		if _closing or not is_instance_valid(self):
			return
		_before_refresh()
		_rebuild(scroll != null)
		grab_initial_focus()
		var p := get_parent()
		if p is Control:
			place(p.size)

	func _before_refresh() -> void:
		pass

	## Static text whose content changes without a rebuild: drawn from `getter` each frame, wrapped
	## to `width`, at most `max_lines` lines of 14px. Returns the reserved height.
	func add_live_paragraph(x: int, y: int, width: int, max_lines: int, getter: Callable) -> int:
		var entry := {"text": "", "rect": Rect2(x, y, width, max_lines * 14)}
		body.texts.append(entry)
		add_op(func(ci: CanvasItem):
			var s := String(getter.call())
			entry.text = s
			var lines := W31.font().wrap(s, width)
			for i in mini(lines.size(), max_lines):
				W31.text(ci, x, y + i * 14, lines[i], W31.BLACK, 11, {"line_height": 14, "show_access": false}))
		return max_lines * 14


# --------------------------------------------------------------------- manager

class Manager extends _Base:
	var selected_number := 0
	var status := ""
	var rows: Array = []
	var list: W31ListBox
	var buttons := {}

	func _init(p_data: Dictionary = {}, p_store: Node = null) -> void:
		super("Launch Groups", 440, p_store)
		selected_number = int(p_data.get("selected", 0))
		status = String(p_data.get("status", ""))

	func _build(cw: int) -> void:
		var lw := cw - BUTTON_COL_W - COL_GAP
		var names := W31LaunchGroupDialogs._names(store)
		rows = W31DialogLogic.launch_group_rows(store.groups, names)
		add_text(0, 0, "&Groups:")
		list = W31ListBox.new(9)
		list.access_key = "g"
		list.set_a11y_label("Launch groups")
		list.set_auto_id("wfw.dialog.launch-groups.list")
		add_widget(list, 0, 16, Vector2(lw, list.fit_height()))
		list.set_rows(rows, W31DialogLogic.launch_group_row_index(rows, selected_number))
		list.selection_changed.connect(func(_i: int):
			selected_number = _current_number()
			status = ""
			_sync()
			body.queue_redraw())
		list.activated.connect(func(_i: int): _members())
		selected_number = _current_number()
		initial_focus = list
		var y := 16 + list.fit_height() + 8
		y += add_live_paragraph(0, y, lw, 4, _detail_text)
		var specs := [
			["close", "Close", true, func(): UIState.close_dialog()],
			["new", "&New...", false, _new],
			["rename", "&Rename...", false, _rename],
			["number", "N&umber...", false, _number],
			["delete", "&Delete", false, _delete],
			["members", "&Members...", false, _members],
			["launch", "&Launch", false, _launch],
		]
		buttons.clear()
		var column := []
		for s in specs:
			var b := make_button(s[1], s[2], s[3])
			b.set_auto_id("wfw.dialog.launch-groups:" + String(s[0]))
			buttons[s[0]] = b
			column.append(b)
		var col_h := W31PropertiesDialogs._button_column(self, lw + COL_GAP, column)
		_sync()
		_finish(maxi(y, col_h))

	func _current_number() -> int:
		if list == null or list.current < 0 or list.current >= rows.size():
			return 0
		return int(rows[list.current].number)

	func _detail_text() -> String:
		var detail := W31DialogLogic.launch_group_detail(store.groups, W31LaunchGroupDialogs._names(store), selected_number)
		return status + "\n" + detail if status != "" else detail

	func _sync() -> void:
		var actions := W31DialogLogic.launch_group_actions(rows, list.current if list else -1)
		for k in buttons:
			if actions.has(k):
				(buttons[k] as W31Button).disabled = not actions[k]

	func _before_refresh() -> void:
		selected_number = _current_number() if selected_number == 0 else selected_number

	func _new() -> void:
		var n := W31DialogLogic.new_launch_group_number(store.groups, W31LaunchGroupDialogs._names(store))
		var back := selected_number
		if n == 0:
			UIState.open_dialog("unavailable", {"title": "Launch Groups", "icon": "information",
				"message": W31DialogLogic.ALL_LAUNCH_GROUPS_IN_USE,
				"onClose": func(): W31LaunchGroupDialogs.open_manager(back)})
			return
		UIState.open_dialog("launchGroupName", {"mode": "new", "number": n, "back": back})

	func _rename() -> void:
		if selected_number > 0:
			UIState.open_dialog("launchGroupName", {"mode": "rename", "number": selected_number, "back": selected_number})

	func _number() -> void:
		if selected_number > 0:
			UIState.open_dialog("launchGroupNumber", {"number": selected_number})

	func _members() -> void:
		if selected_number > 0:
			UIState.open_dialog("launchGroupMembers", {"number": selected_number})

	func _delete() -> void:
		var n := selected_number
		if n <= 0:
			return
		var st: Node = store
		UIState.open_dialog("confirm", {"confirmOptions": {
			"title": "Delete Launch Group", "width": 380,
			"message": W31DialogLogic.delete_launch_group_message(store.groups, W31LaunchGroupDialogs._names(store), n),
			"onConfirm": func():
				var line := W31DialogLogic.apply_delete_launch_group(st, n)
				W31LaunchGroupDialogs.open_manager_later(0, line),
			"onCancel": func(): W31LaunchGroupDialogs.open_manager_later(n),
		}})

	func _launch() -> void:
		var buckets := W31DialogLogic.launch_group_bucket(store.groups, selected_number)
		if buckets.is_empty():
			return
		var shell := _shell()
		UIState.close_dialog()
		if shell != null:
			shell.launch_buckets(buckets)

	## The shell that owns the dialog layer (it runs batch launches with feedback and sounds).
	func _shell() -> Node:
		var n: Node = get_parent()
		while n != null:
			if n.has_method("launch_buckets"):
				return n
			n = n.get_parent()
		return null


# ----------------------------------------------------------------- new / rename

class NameDialog extends _Base:
	var mode := "new"
	var number := 0
	var back := 0
	var field: W31TextField
	var ok: W31Button

	func _init(p_data: Dictionary = {}, p_store: Node = null) -> void:
		mode = "rename" if String(p_data.get("mode", "new")) == "rename" else "new"
		super("New Launch Group" if mode == "new" else "Rename Launch Group", 370, p_store)
		number = int(p_data.get("number", 0))
		back = int(p_data.get("back", number))
		cancel_callable = func(): W31LaunchGroupDialogs.open_manager(back)

	func _build(cw: int) -> void:
		var names := W31LaunchGroupDialogs._names(store)
		var intro := "The new launch group will be Group %d." % number if mode == "new" \
			else "Rename %s." % W31DialogLogic.format_launch_group(number, names)
		add_text(0, 0, intro.replace("&", "&&"))
		var y := 21
		var prev := field.text if field else ("" if mode == "new" else LaunchGroups.name_of(names, number))
		field = W31TextField.new()
		field.set_field_size(cw - 111, 19)
		(field.edit as LineEdit).max_length = LaunchGroups.MAX_NAME_LENGTH
		field.text = prev
		field.access_key = "n"
		field.set_auto_id("wfw.dialog.launch-group-name")
		field.text_changed.connect(func(_t): _sync())
		add_form_row(y, "&Name:", field, cw - 111)
		initial_focus = field
		y += 24
		if mode == "rename":
			add_text(111, y, "Leave it blank to remove the name.", 11)
			y += 19
		ok = make_button("OK", true, _submit)
		add_button_row(y, [ok, make_button("Cancel", false, func(): cancel())])
		_sync()
		_finish(y + 4 + 22 + 8)

	func _sync() -> void:
		ok.disabled = not W31DialogLogic.launch_group_name_ok(mode, field.text)

	func _submit() -> void:
		if not W31DialogLogic.launch_group_name_ok(mode, field.text):
			return
		if mode == "new":
			var r := W31DialogLogic.apply_new_launch_group(store, field.text)
			if int(r.number) > 0:
				UIState.open_dialog("launchGroupMembers", {"number": int(r.number), "status": r.status})
			else:
				W31LaunchGroupDialogs.open_manager(back, r.status)
		else:
			W31LaunchGroupDialogs.open_manager(number, W31DialogLogic.apply_rename_launch_group(store, number, field.text))


# ---------------------------------------------------------------------- number

class NumberDialog extends _Base:
	var number := 0
	var target := 0
	var combo: W31Combo

	func _init(p_data: Dictionary = {}, p_store: Node = null) -> void:
		super("Launch Group Number", 400, p_store)
		number = int(p_data.get("number", 0))
		target = number
		cancel_callable = func(): W31LaunchGroupDialogs.open_manager(number)

	func _build(cw: int) -> void:
		var names := W31LaunchGroupDialogs._names(store)
		add_text(0, 0, ("Give %s another number." % W31DialogLogic.format_launch_group(number, names)).replace("&", "&&"))
		var labels := []
		var values := []
		for c in W31DialogLogic.launch_group_number_choices(store.groups, names, number):
			labels.append(c.label)
			values.append(c.value)
		combo = W31Combo.new()
		combo.set_items(labels, values)
		combo.select_value(target)
		combo.access_key = "n"
		combo.set_auto_id("wfw.dialog.launch-group-number")
		combo.selection_changed.connect(func(_i: int):
			target = int(combo.value())
			body.queue_redraw())
		add_form_row(21, "&Number:", combo, cw - 111)
		initial_focus = combo
		var y := 21 + 24
		y += add_live_paragraph(111, y, cw - 111, 3, func() -> String:
			return W31DialogLogic.renumber_note(store.groups, W31LaunchGroupDialogs._names(store), number, target))
		var ok := make_button("OK", true, _submit)
		add_button_row(y, [ok, make_button("Cancel", false, func(): cancel())])
		_finish(y + 4 + 22 + 8)

	func _submit() -> void:
		var r := W31DialogLogic.apply_renumber_launch_group(store, number, target)
		W31LaunchGroupDialogs.open_manager(int(r.number), String(r.status))


# --------------------------------------------------------------------- members

class Members extends _Base:
	var number := 0
	var status := ""
	var checked := {}
	var list: W31ListBox

	func _init(p_data: Dictionary = {}, p_store: Node = null) -> void:
		super("Launch Group Members", 420, p_store)
		number = int(p_data.get("number", 0))
		status = String(p_data.get("status", ""))
		checked = W31DialogLogic.member_check_set(store.groups, number)
		cancel_callable = func(): W31LaunchGroupDialogs.open_manager(number, status)

	func _build(cw: int) -> void:
		var names := W31LaunchGroupDialogs._names(store)
		add_text(0, 0, "&Programs in %s:" % W31DialogLogic.format_launch_group(number, names).replace("&", "&&"))
		var prev_cursor := list.current if list else -1
		list = W31ListBox.new(12, true)
		list.access_key = "p"
		list.set_a11y_label("Programs")
		list.set_auto_id("wfw.dialog.launch-group-members.list")
		add_widget(list, 0, 16, Vector2(cw, list.fit_height()))
		list.set_rows(W31DialogLogic.member_rows(store.groups, names, number, checked), prev_cursor)
		list.toggled.connect(func(i: int, on: bool):
			if on:
				checked[String(list.rows[i].key)] = true
			else:
				checked.erase(String(list.rows[i].key)))
		initial_focus = list
		var y := 16 + list.fit_height() + 6
		var note := W31DialogLogic.MEMBERS_MOVE_NOTE if list.rows.size() > 0 else "There are no programs yet. Add programs to a program group first."
		y += add_paragraph(0, y, note, cw, 14) + 3
		var ok := make_button("OK", true, _submit)
		var all := make_button("Select &All", false, func(): _set_all(true))
		var none := make_button("C&lear All", false, func(): _set_all(false))
		all.disabled = list.rows.is_empty()
		none.disabled = list.rows.is_empty()
		add_button_row(y, [ok, make_button("Cancel", false, func(): cancel()), all, none])
		_finish(y + 4 + 22 + 8)

	func _set_all(on: bool) -> void:
		list.set_all_checked(on)
		checked.clear()
		if on:
			for k in W31DialogLogic.checked_member_keys(list.rows):
				checked[k] = true

	func _before_refresh() -> void:
		var known := {}
		for e in LaunchGroups.all_items(store.groups):
			known[String(e.key)] = true
		for k in checked.keys():
			if not known.has(k):
				checked.erase(k)

	func _submit() -> void:
		var line := W31DialogLogic.apply_launch_group_members(store, number, W31DialogLogic.checked_member_keys(list.rows))
		W31LaunchGroupDialogs.open_manager(number, (status + " " + line) if status != "" else line)
