class_name BeFindView
extends Control
## Contents of the Find window: "Find [type] in [group]", "Name or text contains [____] (Find)", and the results list
## (Name / Group / Launch Group / Command). State lives in shell.find_state so reopening the window keeps the last search.

const TYPES := [["all", "All programs"], ["app", "Applications"], ["url", "URLs"], ["note", "Sticky notes"], ["batch", "In a launch group"]]
const HEADINGS := ["Name", "Group", BeDialogLogic.LAUNCH_GROUP_HEADING, "Command"]

var shell: Control
var window: Control
var type_sel: BeSelect
var where_sel: BeSelect
var query: BeField
var run_btn: BeButton
var results: Array = []
var _scroll := 0.0
var _rows: Array = []   ## Rect2 per result (local to the results box, unscrolled)
var _list: _Results


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false


func setup(p_shell: Control, p_window: Control) -> void:
	shell = p_shell
	window = p_window
	var st: Dictionary = shell.find_state
	type_sel = BeSelect.make(TYPES, String(st.type), "be.find.type", 120)
	type_sel.changed.connect(func(v): shell.find_state.type = v)
	where_sel = BeSelect.make(_where_options(), String(st.where), "be.find.where", 120)
	where_sel.changed.connect(func(v): shell.find_state.where = v)
	query = BeField.make(String(st.q), "be.find.query")
	query.text_changed.connect(func(t): shell.find_state.q = t)
	query.text_submitted.connect(func(_t): run())
	run_btn = BeButton.make("Find", true, "be.find.run")
	run_btn.min_width = 90
	run_btn.pressed.connect(run)
	_list = _Results.new()
	_list.view = self
	add_child(_list)
	for c in [type_sel, where_sel, query, run_btn]:
		add_child(c)
	resized.connect(_layout)
	_layout()


func _where_options() -> Array:
	var o := [["all", "All groups"]]
	for g in ProgramStore.groups:
		o.append([String(g.id), String(g.name)])
	return o


func focus_query() -> void:
	query.grab_text_focus()


func refresh() -> void:
	where_sel.options = _where_options()
	if where_sel.label_of(String(shell.find_state.where)) == "":
		shell.find_state.where = "all"
	where_sel.value = String(shell.find_state.where)
	where_sel.refresh_size()
	if bool(shell.find_state.ran):
		_compute()
	_layout()


func run() -> void:
	shell.find_state.ran = true
	shell.deskbar.queue_redraw()  # the task title follows the query
	_scroll = 0.0
	_compute()
	_layout()
	if window != null:
		window.refresh()


func _compute() -> void:
	var st: Dictionary = shell.find_state
	results = BeDialogLogic.find(ProgramStore.groups, String(st.q), String(st.where), String(st.type), "")


func title_text() -> String:
	return BeDialogLogic.find_title(String(shell.find_state.q))


func _layout() -> void:
	if size.x <= 0 or type_sel == null:
		return
	var y := 0.0
	if _list != null:
		var lr := _results_rect()
		_list.position = lr.position
		_list.size = lr.size
		_list.visible = bool(shell.find_state.ran)
		_list.queue_redraw()
	var x := 32.0 + 8.0 + BeFont.width("Find") + 8.0
	type_sel.position = Vector2(x, y + 1)
	type_sel.size = type_sel.custom_minimum_size
	x += type_sel.size.x + 8.0
	x += BeFont.width("in") + 8.0
	where_sel.position = Vector2(x, y + 1)
	where_sel.size = where_sel.custom_minimum_size
	var y2 := 32.0 + 12.0
	var lw := BeFont.width(BeDialogLogic.FIND_QUERY_LABEL) + 10.0
	run_btn.size = run_btn.custom_minimum_size
	run_btn.position = Vector2(size.x - run_btn.size.x, y2)
	query.position = Vector2(lw, y2)
	query.size = Vector2(maxf(40.0, run_btn.position.x - 10.0 - lw), 30)
	_rows.clear()
	for i in results.size():
		_rows.append(Rect2(0, 27 + i * 24, size.x, 24))
	queue_redraw()


func _results_rect() -> Rect2:
	var top := 32.0 + 12.0 + 30.0 + 12.0
	return Rect2(0, top, size.x, maxf(0.0, size.y - top - 12.0 - 16.0))


func entry_rect(index: int) -> Rect2:
	if index < 0 or index >= _rows.size():
		return Rect2()
	var rr := _results_rect()
	return Rect2(get_global_rect().position + rr.position + (_rows[index] as Rect2).position - Vector2(0, _scroll), (_rows[index] as Rect2).size)


func auto_lookup(id: String) -> Variant:
	if id.begins_with("be.find.result:"):
		var n := id.substr("be.find.result:".length())
		if n.is_valid_int():
			var r := entry_rect(int(n))
			return r if r.size != Vector2.ZERO else null
	return null


func _ready() -> void:
	add_to_group("pm_auto")


func _columns() -> Array:
	return BeGeometry.find_columns(size.x - 2)


func _row_at(p: Vector2) -> int:
	var rr := _results_rect()
	if not rr.has_point(p) or p.y - rr.position.y < 27:
		return -1
	var q := p - rr.position + Vector2(0, _scroll)
	for i in _rows.size():
		if (_rows[i] as Rect2).has_point(q):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var rr := _results_rect()
			var max_s := maxf(0.0, 27.0 + results.size() * 24 - rr.size.y)
			_scroll = clampf(_scroll + (36.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -36.0), 0.0, max_s)
			queue_redraw()
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			shell.raise_window(BeWindowStore.FIND)
			var i := _row_at(mb.position)
			if i >= 0:
				var res: Dictionary = results[i]
				shell.select_entry("find", String(res.item.id))
				if mb.button_index == MOUSE_BUTTON_RIGHT:
					shell.open_entry_menu("find", String(res.item.id), get_global_rect().position + mb.position, String(res.group.id))
				elif mb.double_click:
					shell.launch_item(res.item)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				shell.clear_selection()
			accept_event()


class _Results extends Control:
	var view: BeFindView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		view._draw_results(self)


func _draw() -> void:
	var col := BeTheme.t("000000")
	BeDraw.icon(self, BeIconCatalog.texture("find"), Rect2(0, 0, 32, 32))
	BeFont.draw(self, Vector2(40, 7), "Find", col)
	BeFont.draw(self, Vector2(type_sel.position.x + type_sel.size.x + 8, 7), "in", col)
	BeFont.draw(self, Vector2(0, 44 + 6), BeDialogLogic.FIND_QUERY_LABEL, col)
	if bool(shell.find_state.ran):
		var rr := _results_rect()
		BeFont.draw(self, Vector2(0, rr.end.y + 12 - 1), "%d file(s) found" % results.size(), col, BeGeometry.FONT_SMALL, false, 16)


func _draw_results(c: Control) -> void:
	var col := BeTheme.t("000000")
	var rr := Rect2(Vector2.ZERO, c.size)
	BeDraw.fill(c, rr, BeTheme.b("ffffff"))
	var cols := _columns()
	var sel: String = shell.selected_id_in(BeWindowStore.FIND)
	var names := ProgramStore.launch_group_names()
	for i in results.size():
		var r: Rect2 = _rows[i]
		var y := r.position.y - _scroll
		if y + 24 < 0 or y > rr.size.y:
			continue
		var res: Dictionary = results[i]
		if String(res.item.id) == sel:
			BeDraw.fill(c, Rect2(1, y, rr.size.x - 2, 24), BeTheme.b("c8c8c8"))
		BeDraw.icon(c, BeIconCatalog.texture(String(res.item.get("icon", "default")), String(res.item.name)), Rect2(8, y + 4, 16, 16))
		BeFont.draw(c, Vector2(8 + 16 + 6, y + 3), BeFont.clip(String(res.item.name), float(cols[1]) - 38), col)
		var cells := [String(res.group.name), BeDialogLogic.launch_group_cell(res.item, names), BeDialogLogic.command_text(res.item)]
		for n in 3:
			BeFont.draw(c, Vector2(float(cols[n * 2 + 2]) + 10, y + 3), BeFont.clip(cells[n], float(cols[n * 2 + 3]) - 20), col)
	var hr := Rect2(1, 1, rr.size.x - 2, 26)
	BeDraw.gradient_v(c, hr, BeTheme.b("f4f4f4"), BeTheme.b("d4d4d4"))
	BeDraw.hline(c, hr.position.x, hr.end.y - 1, hr.size.x, BeTheme.b("989898"))
	for n in HEADINGS.size():
		var cx: float = hr.position.x + float(cols[n * 2])
		BeFont.draw(c, Vector2(cx + 10, hr.position.y + 3), HEADINGS[n], col, BeGeometry.FONT, true)
		if n < HEADINGS.size() - 1:
			BeDraw.vline(c, cx + float(cols[n * 2 + 1]) - 1, hr.position.y, hr.size.y - 1, BeTheme.b("b8b8b8"))
	BeDraw.border(c, rr, BeTheme.b("989898"))
