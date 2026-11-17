class_name BeDeskbar
extends Control
## The Deskbar: a 200px panel on the right edge with the logo button (menu + group submenus), the Launcher Tools
## button, the clock and one row per open window (click raises / hides, right-click opens the window menu).
## Automation ids: be.deskbar.logo, be.deskbar.tools, be.deskbar.clock, be.deskbar.task:<index|key>.

var shell: Control
var _clock := ""
var _timer: Timer
var _start_popup: BePopup
var _parts := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(p_shell: Control) -> void:
	shell = p_shell
	add_to_group("pm_auto")
	_clock = _format_clock()
	_timer = Timer.new()
	_timer.wait_time = 15.0
	_timer.timeout.connect(func():
		var c := _format_clock()
		if c != _clock:
			_clock = c
			queue_redraw())
	add_child(_timer)
	_timer.start()
	shell.windows.changed.connect(refresh)
	refresh()


## "12:00 PM" in captures (Engine meta), else the local time.
func _format_clock() -> String:
	if Engine.has_meta("pm_capture_clock"):
		return String(Engine.get_meta("pm_capture_clock"))
	return BeDialogLogic.format_clock(Time.get_time_dict_from_system())


func refresh() -> void:
	if shell == null:
		return
	var view_w: float = shell.size.x
	_parts = BeGeometry.deskbar_parts(shell.windows.order.size(), view_w)
	var r: Rect2 = _parts.rect
	position = r.position
	size = r.size
	queue_redraw()


func start_open() -> bool:
	return _start_popup != null and is_instance_valid(_start_popup) and _start_popup.is_inside_tree()


func _local(r: Rect2) -> Rect2:
	return Rect2(r.position - position, r.size)


func auto_lookup(id: String) -> Variant:
	var origin := global_position
	match id:
		"be.deskbar.logo": return Rect2(origin + _local(_parts.logo).position, _parts.logo.size)
		"be.deskbar.tools": return Rect2(origin + _local(_parts.tools).position, _parts.tools.size)
		"be.deskbar.clock": return Rect2(origin + _local(_parts.clock).position, _parts.clock.size)
		"be.deskbar": return Rect2(origin, size)
	if id.begins_with("be.deskbar.task:"):
		var n := id.substr("be.deskbar.task:".length())
		var order: Array = shell.windows.order
		var idx := int(n) if n.is_valid_int() else order.find(n)
		if idx >= 0 and idx < _parts.tasks.size():
			var t: Rect2 = _parts.tasks[idx]
			return Rect2(origin + _local(t).position, t.size)
	return null


func _draw() -> void:
	if _parts.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var edge := BeTheme.b("6a6a6a")
	BeDraw.fill(self, r, BeTheme.b("d8d8d8"))
	BeDraw.vline(self, 0, 0, r.size.y, edge)
	BeDraw.hline(self, 0, r.size.y - 1, r.size.x, edge)
	BeDraw.hline(self, 1, 0, r.size.x - 1, BeTheme.s("ffffff"))
	BeDraw.vline(self, 1, 0, r.size.y - 1, BeTheme.s("ffffff"))
	# logo button
	var logo := _local(_parts.logo)
	BeDraw.fill(self, Rect2(logo.position.x + 1, logo.position.y, logo.size.x - 1, logo.size.y), BeTheme.b("bcbcbc") if start_open() else BeTheme.b("d8d8d8"))
	BeDraw.hline(self, 1, logo.end.y - 1, r.size.x - 1, BeTheme.b("989898"))
	BeDraw.icon(self, BeIconCatalog.texture("logo"), Rect2(logo.position.x + (logo.size.x - 36) / 2.0 + 0.5, logo.position.y + 5, 36, 36))
	# clock row
	var c := _local(_parts.clock)
	BeDraw.fill(self, c, BeTheme.b("e4e4e4"))
	BeDraw.border(self, c, BeTheme.b("989898"))
	BeDraw.hline(self, c.position.x + 1, c.position.y + 1, c.size.x - 2, BeTheme.s("b8b8b8"))
	BeDraw.vline(self, c.position.x + 1, c.position.y + 1, c.size.y - 2, BeTheme.s("b8b8b8"))
	var cw := BeFont.width(_clock, BeGeometry.FONT_CLOCK)
	var tx := c.end.x - 1 - 10 - cw
	BeFont.draw(self, Vector2(tx, c.position.y + 1), _clock, BeTheme.t("000000"), BeGeometry.FONT_CLOCK, false, BeGeometry.CLOCK_ROW_H - 2)
	BeDraw.icon(self, BeIconCatalog.texture("tools"), Rect2(tx - 10 - 16, c.position.y + 6, 16, 16))
	# tasks
	var active: String = shell.windows.active()
	for i in shell.windows.order.size():
		var key: String = shell.windows.order[i]
		var t := _local(_parts.tasks[i])
		var on := key == active
		if on:
			BeDraw.fill(self, Rect2(t.position.x + 1, t.position.y, t.size.x - 1, t.size.y), BeTheme.b("bcbcbc"))
		BeDraw.hline(self, t.position.x + 1, t.position.y, t.size.x - 1, BeTheme.b("f0f0f0"))
		BeDraw.hline(self, t.position.x + 1, t.end.y - 1, t.size.x - 1, BeTheme.b("b8b8b8"))
		var title := BeDialogLogic.window_title(key, ProgramStore.groups, String(shell.find_state.q))
		var icon := "my-computer" if key == BeWindowStore.COMPUTER else ("find" if key == BeWindowStore.FIND else "folder-open")
		BeDraw.icon(self, BeIconCatalog.texture(icon), Rect2(t.position.x + 10, t.position.y + 7, 16, 16))
		BeFont.draw(self, Vector2(t.position.x + 10 + 16 + 8, t.position.y + 6), BeFont.clip(title, t.size.x - 10 - 16 - 8 - 10, BeGeometry.FONT, on), BeTheme.t("000000"), BeGeometry.FONT, on)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	var p := mb.position + position
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if (_parts.logo as Rect2).has_point(p):
			toggle_start()
		elif (_parts.tools as Rect2).grow(4).has_point(p):
			shell.do_action("tools.open", {})
		else:
			var i := _task_at(p)
			if i >= 0:
				shell.close_all_menus()
				shell.windows.task_click(shell.windows.order[i])
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if (_parts.logo as Rect2).has_point(p):
			shell.open_menu(BeMenuModel.deskbar_context_menu(), mb.global_position)
		else:
			var j := _task_at(p)
			if j >= 0:
				shell.open_menu(BeMenuModel.window_menu(shell.windows.order[j]), mb.global_position)
		accept_event()


func _task_at(p: Vector2) -> int:
	for i in _parts.tasks.size():
		if (_parts.tasks[i] as Rect2).has_point(p):
			return i
	return -1


func toggle_start() -> void:
	if start_open():
		_start_popup.close()
		return
	shell.close_all_menus()
	var rows := []
	for r in BeMenuModel.deskbar_menu(LaunchGroups.collect_launch_groups(ProgramStore.groups), ProgramStore.launch_group_names()):
		var row: Dictionary = r.duplicate()
		if not row.get("sep", false):
			row.icon = BeIconCatalog.texture(String(row.icon))
		rows.append(row)
	rows.append(BeMenuModel.SEP)
	for g in ProgramStore.groups:
		var kids := []
		for it in g.items:
			kids.append({"label": String(it.name), "action": "item.open", "args": {"gid": String(g.id), "iid": String(it.id)},
				"icon": BeIconCatalog.texture(String(it.get("icon", "default")), String(it.name))})
		rows.append({"label": String(g.name), "icon": BeIconCatalog.texture("folder"), "children": kids, "action": "none", "args": {}})
	var logo := _parts.logo as Rect2
	_start_popup = BePopup.open(shell.menu_layer, rows, Vector2(logo.end.x - 4, logo.end.y), {
		"min_w": 240.0, "pad_left": 34.0, "icons": true, "submenu_left": true, "align_right": true, "anchor": Rect2(global_position + _local(logo).position, logo.size)})
	_start_popup.picked.connect(func(row): shell.do_action(String(row.action), row.args))
	_start_popup.closed.connect(func(): queue_redraw())
	queue_redraw()
