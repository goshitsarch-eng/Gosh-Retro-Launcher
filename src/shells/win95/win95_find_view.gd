class_name Win95FindView
extends Control
## Client of the modeless Find window (port of Win95FindView.tsx): "Name & Location",
## "Date Modified" (visible, criteria disabled: launcher items have no dates) and "Advanced" pages,
## Find Now / Stop / New Search, and the results list (click, Ctrl/Shift, arrows, Home/End,
## PageUp/PageDown, Ctrl+A, double-click / Enter launches). Searches with ProgramSearch.find_programs.
## Plugs into Win95Window as its client (signals result_count_changed / selection_changed,
## methods open_selected() / select_all() / handle_key()).

signal result_count_changed(count: int)
signal selection_changed(id: String)

const RESULT_H := 53
const ROW_H := 19

var shell: Control
var window: Control

var tab := "name"
var named_edit: Win95TextInput
var look_in: Win95Select
var include_sub: Win95Checkbox
var type_select: Win95Select
var containing_edit: Win95TextInput
var path_edit: Win95TextInput
var btn_find: Win95Button
var btn_stop: Win95Button
var btn_new: Win95Button
var tabs: Win95TabStrip

var results: Array = []
var selection: Dictionary = Win95SelectionState.empty()
var scroll := 0
var running := false
var searched := false

var _page: Control
var _pages: Dictionary = {}
var _sb: Win95Scrollbar
var _sb_clip: Control
var _timer: Timer
var _last_click_ms := 0
var _last_click_row := -1


func setup(p_shell: Control, p_window: Control) -> void:
	shell = p_shell
	window = p_window
	mouse_filter = Control.MOUSE_FILTER_STOP
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_found)
	add_child(_timer)
	tabs = Win95TabStrip.new()
	tabs.configure([{"id": "name", "label": "&Name && Location"}, {"id": "date", "label": "&Date Modified"}, {"id": "advanced", "label": "&Advanced"}], "find", "name")
	tabs.position = Vector2.ZERO
	tabs.size = Vector2(427, 22)
	tabs.tab_selected.connect(_on_tab)
	add_child(tabs)
	_build_pages()
	_build_actions()
	_sb = Win95Scrollbar.new()
	_sb.vertical = true
	_sb.scrolled.connect(func(v): scroll = v; queue_redraw())
	_sb_clip = Control.new()
	_sb_clip.clip_contents = true
	_sb_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sb_clip)
	_sb_clip.add_child(_sb)
	_sb.hide()
	add_to_group("pm_auto")
	ProgramStore.groups_changed.connect(_on_groups_changed)
	shell.windows.changed.connect(_on_windows_changed)
	resized.connect(_layout)
	_layout()
	call_deferred("_initial_focus")


func _exit_tree() -> void:
	if ProgramStore.groups_changed.is_connected(_on_groups_changed):
		ProgramStore.groups_changed.disconnect(_on_groups_changed)
	if shell != null and is_instance_valid(shell) and shell.windows.changed.is_connected(_on_windows_changed):
		shell.windows.changed.disconnect(_on_windows_changed)


func _initial_focus() -> void:
	if is_inside_tree() and named_edit != null:
		named_edit.focus_edit()


func _layout() -> void:
	tabs.size = Vector2(size.x, 22)
	_page.position = Vector2(7, 28)
	# the scrollbar is as tall as RESULT_H + 18 but is clipped by the results area (as in the original)
	_sb_clip.position = Vector2(2, 98 + 18)
	_sb_clip.size = Vector2(size.x - 4, maxf(1.0, size.y - 98 - 18 - 2))
	_sb.position = Vector2(size.x - 4 - 16, 0)


func _field_x() -> float:
	return 74.0


func _field_w() -> float:
	return maxf(40.0, size.x - 2 - 12 - 82 - 74)


func _build_pages() -> void:
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	# Name & Location
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages["name"] = p
	named_edit = Win95TextInput.new()
	named_edit.text = "*"
	named_edit.position = Vector2(74, 0)
	named_edit.size = Vector2(257, 21)
	named_edit.text_submitted.connect(func(_t): find_now())
	look_in = Win95Select.new()
	look_in.shell = shell
	look_in.position = Vector2(74, 21)
	look_in.size = Vector2(257, 21)
	_refresh_groups()
	include_sub = Win95Checkbox.new()
	include_sub.label = "&Include subgroups"
	include_sub.checked = true
	include_sub.position = Vector2(74, 44)
	p.add_child(Win95Label.make("&Named:", Vector2(0, 4)))
	p.add_child(named_edit)
	p.add_child(Win95Label.make("&Look in:", Vector2(0, 25)))
	p.add_child(look_in)
	p.add_child(include_sub)
	# Date Modified (criteria unavailable)
	var d := Control.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages["date"] = d
	d.add_child(Win95Label.make("Date criteria are unavailable because launcher items do not store modified dates.", Vector2(0, 0), {"disabled": true, "wrap": 265}))
	var all := Win95Checkbox.new()
	all.label = "&All files"
	all.checked = true
	all.disabled = true
	all.position = Vector2(0, 31)
	d.add_child(all)
	# Advanced
	var a := Control.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages["advanced"] = a
	type_select = Win95Select.new()
	type_select.shell = shell
	type_select.options = ["All launcher items", "Application", "Internet Shortcut"]
	type_select.position = Vector2(74, 0)
	type_select.size = Vector2(257, 21)
	containing_edit = Win95TextInput.new()
	containing_edit.position = Vector2(74, 21)
	containing_edit.size = Vector2(257, 21)
	path_edit = Win95TextInput.new()
	path_edit.position = Vector2(74, 42)
	path_edit.size = Vector2(257, 21)
	a.add_child(Win95Label.make("Of &type:", Vector2(0, 4)))
	a.add_child(type_select)
	a.add_child(Win95Label.make("&Containing text:", Vector2(0, 25)))
	a.add_child(containing_edit)
	a.add_child(Win95Label.make("&Path contains:", Vector2(0, 46)))
	a.add_child(path_edit)
	for k in _pages:
		_page.add_child(_pages[k])
	_show_page()


func _build_actions() -> void:
	btn_find = _action("&Find Now", 0)
	btn_find.default_button = true
	btn_find.pressed.connect(find_now)
	btn_stop = _action("&Stop", 1)
	btn_stop.disabled = true
	btn_stop.pressed.connect(stop)
	btn_new = _action("&New Search", 2)
	btn_new.pressed.connect(new_search)


func _action(label: String, i: int) -> Win95Button:
	var b := Win95Button.new()
	b.label = label
	b.size = Vector2(75, 22)
	b.custom_minimum_size = b.size
	b.position = Vector2(344, 28 + i * 24)
	add_child(b)
	return b


func _show_page() -> void:
	for k in _pages:
		_pages[k].visible = k == tab


func _on_tab(id: String) -> void:
	tab = id
	_show_page()
	queue_redraw()


func _refresh_groups() -> void:
	var opts: Array = ["All launcher groups"]
	for g in ProgramStore.groups:
		opts.append(String(g.name))
	var keep := look_in.selected_index
	look_in.options = opts
	look_in.selected_index = keep if keep < opts.size() else 0


func _on_groups_changed() -> void:
	_refresh_groups()


func _on_windows_changed() -> void:
	# Typing must not leak into a hidden field once another window is active.
	if shell.windows.active_window_id != "find":
		var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if owner != null and is_ancestor_of(owner):
			owner.release_focus()


# ------------------------------------------------------------------ commands

func _group_id() -> String:
	if look_in.selected_index <= 0 or look_in.selected_index > ProgramStore.groups.size():
		return ""
	return String(ProgramStore.groups[look_in.selected_index - 1].id)


func _type() -> String:
	return ["all", "application", "internet"][clampi(type_select.selected_index, 0, 2)]


func stop() -> void:
	_timer.stop()
	_set_running(false)


func _set_running(r: bool) -> void:
	running = r
	btn_find.disabled = r
	btn_find.default_button = not r
	btn_stop.disabled = not r
	queue_redraw()


func find_now() -> void:
	stop()
	_set_running(true)
	searched = true
	selection = Win95SelectionState.empty()
	scroll = 0
	_emit_selection()
	_timer.start(0.18)
	queue_redraw()


func _on_found() -> void:
	var filters := Win95DialogLogic.find_filters(named_edit.text, _group_id(), include_sub.checked, _type(), containing_edit.text, path_edit.text)
	results = ProgramSearch.find_programs(ProgramStore.groups, filters)
	_set_running(false)
	result_count_changed.emit(results.size())
	_sync_scrollbar()
	queue_redraw()


func new_search() -> void:
	stop()
	named_edit.text = "*"
	look_in.selected_index = 0
	include_sub.checked = true
	type_select.selected_index = 0
	containing_edit.text = ""
	path_edit.text = ""
	results = []
	searched = false
	selection = Win95SelectionState.empty()
	scroll = 0
	tab = "name"
	tabs.select("name")
	_show_page()
	result_count_changed.emit(0)
	_emit_selection()
	_sync_scrollbar()
	named_edit.focus_edit()
	queue_redraw()


func _ids() -> Array:
	return Win95DialogLogic.find_result_ids(results)


func _focused_index() -> int:
	return maxi(0, _ids().find(selection.focused))


func _emit_selection() -> void:
	var f: String = selection.focused if selection.focused != "" else (String(selection.selected[0]) if selection.selected.size() > 0 else "")
	selection_changed.emit(f)


func select_all() -> void:
	var ids := _ids()
	selection = Win95SelectionState.select_all(ids)
	_emit_selection()
	queue_redraw()


func open_selected() -> void:
	if results.is_empty():
		return
	_launch(results[_focused_index()])


func _launch(r: Dictionary) -> void:
	shell.launch_item(r.item)


func _sync_scrollbar() -> void:
	var content := maxi(RESULT_H, results.size() * ROW_H)
	scroll = Win95ScrollbarState.clamp_scroll(scroll, content, RESULT_H)
	_sb.visible = content > RESULT_H
	if _sb.visible:
		_sb.configure(scroll, RESULT_H, content, RESULT_H + 18, ROW_H)


# ------------------------------------------------------------------- drawing

func _results_rect() -> Rect2:
	return Rect2(0, 96, size.x, size.y - 96)


func _draw() -> void:
	Win95Draw.fill(self, Rect2(Vector2.ZERO, size), Win95Draw.FACE)
	# criteria frame
	var cr := Rect2(0, 22, size.x, 74)
	Win95Draw.border(self, cr, 1, Win95Draw.LIGHT, Win95Draw.SHADOW, Win95Draw.SHADOW, Win95Draw.LIGHT)
	# results area
	var ra := _results_rect()
	Win95Draw.sunken(self, ra, Win95Draw.WINDOW)
	var inner := Rect2(ra.position + Vector2(2, 2), ra.size - Vector2(4, 4))
	var hx := inner.position.x + 1
	var hw := inner.size.x - 1
	var c2 := 120.0
	var c1 := hw - c2
	Win95Draw.fill(self, Rect2(hx, inner.position.y, hw, 18), Win95Draw.FACE)
	for col in [[hx, c1, "Name"], [hx + c1, c2, "In Folder"]]:
		var r := Rect2(col[0], inner.position.y, col[1], 18)
		Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.DARK, Win95Draw.LIGHT)
		Win95Draw.text(self, r.position + Vector2(5, 3), col[2], Win95Draw.TEXT)
	# rows, clipped to the area below the header
	var rows_top := inner.position.y + 18
	var clip_bottom := inner.end.y
	var selected := {}
	for s in selection.selected:
		selected[s] = true
	var ids := _ids()
	for i in results.size():
		var y := rows_top + i * ROW_H - scroll
		if y + ROW_H <= rows_top or y >= clip_bottom:
			continue
		var r2: Dictionary = results[i]
		var sel: bool = selected.has(ids[i])
		var fg := Win95Draw.SELECTED_TEXT if sel else Win95Draw.TEXT
		var clip_h := minf(ROW_H, clip_bottom - y)
		var row := Rect2(hx, y, hw - (16 if _sb.visible else 0), clip_h)
		if sel:
			Win95Draw.fill(self, row, Win95Draw.SELECTED)
		if clip_h >= ROW_H - 2:
			Win95Draw.icon(self, Win95IconCatalog.texture(String(r2.item.get("icon", "")), "small"), Vector2(hx + 4, y + 2))
		Win95Draw.text(self, Vector2(hx + 23, y + 3), r2.item.name, fg, {"max_width": int(c1) - 27})
		Win95Draw.text(self, Vector2(hx + c1 + 4, y + 3), r2.group.name, fg, {"max_width": int(c2) - 8})
	if results.is_empty():
		if running:
			Win95Draw.text(self, Vector2(hx + 5, rows_top + 5), "Searching...", Win95Draw.TEXT)
		elif searched:
			Win95Draw.text(self, Vector2(hx + 5, rows_top + 5), "No files found.", Win95Draw.TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ra := _results_rect()
		var rows_top := ra.position.y + 2 + 18
		var p: Vector2 = event.position
		if ra.has_point(p) and p.y >= rows_top:
			var idx := int((p.y - rows_top + scroll) / ROW_H)
			get_viewport().gui_release_focus()
			if idx >= 0 and idx < results.size() and p.x < size.x - (20 if _sb.visible else 2):
				var ids := _ids()
				selection = Win95SelectionState.select_item(selection, ids[idx], ids, {"ctrl": event.ctrl_pressed, "shift": event.shift_pressed})
				_emit_selection()
				queue_redraw()
				if event.double_click:
					_launch(results[idx])
		else:
			get_viewport().gui_release_focus()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and _sb.visible:
		scroll = Win95ScrollbarState.clamp_scroll(scroll + (48 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -48), results.size() * ROW_H, RESULT_H)
		_sb.configure(scroll, RESULT_H, results.size() * ROW_H, RESULT_H + 18, ROW_H)
		queue_redraw()
		accept_event()


# ------------------------------------------------------------------- keyboard

func _text_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit and is_ancestor_of(owner)


## Window-layer key hook. With a field focused the keys belong to the field (Enter in "Named" is
## handled by its text_submitted); otherwise the keys drive the results list.
func handle_key(event: Dictionary) -> bool:
	if _text_focus() or results.is_empty():
		return false
	var key: String = event.key
	var ctrl: bool = event.get("ctrlKey", false)
	var shift: bool = event.get("shiftKey", false)
	var ids := _ids()
	var index := _focused_index()
	if ctrl and key.to_lower() == "a":
		select_all()
		return true
	if key == "Enter":
		_launch(results[index])
		return true
	var nxt := Win95DialogLogic.find_next_index(index, key, results.size())
	if nxt < 0:
		return false
	selection = Win95SelectionState.select_item(selection, ids[nxt], ids, {"shift": shift, "ctrl": ctrl})
	scroll = Win95DialogLogic.find_reveal(scroll, nxt, ROW_H, RESULT_H)
	_sync_scrollbar()
	_emit_selection()
	queue_redraw()
	return true


# ----------------------------------------------------------------- automation

func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree() or shell.windows.active_window_id != "find":
		return null
	var origin := global_position
	if id.begins_with("w95.find-tab:"):
		var label := id.substr("w95.find-tab:".length())
		for i in tabs.tabs.size():
			if String(tabs.tabs[i].label).replace("&&", "\u0001").replace("&", "").replace("\u0001", "&") == label:
				var r := tabs.tab_rect(i)
				return Rect2(origin + tabs.position + r.position, r.size)
	if id.begins_with("w95.find-action:"):
		var label2 := id.substr("w95.find-action:".length())
		for b in [btn_find, btn_stop, btn_new]:
			if String(b.label).replace("&", "") == label2:
				return Rect2(b.global_position, b.size)
	return null
