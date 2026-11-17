class_name BeWindow
extends Control
## One Be window: the yellow title tab (close box, bold title, zoom box) over a panel. Folder windows ("computer", "g:<id>")
## add a menu bar, the content view and a status row with the resize grip; the Find window hosts BeFindView.
## Dragging the tab moves the window, double-clicking it hides it, the grip resizes.

var shell: Control
var key := ""
var is_find := false
var view: BeFolderView
var find_view: BeFindView
var _title := ""
var _status := ""
var _status2 := ""
var _menus: Array = []      ## [{id, label, items}]
var _menu_rects: Array = [] ## local Rect2 per title
var _open_menu := ""
var _popup: BePopup
var _press := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false


func setup(p_shell: Control, p_key: String) -> void:
	shell = p_shell
	key = p_key
	is_find = key == BeWindowStore.FIND
	if is_find:
		find_view = BeFindView.new()
		add_child(find_view)
		find_view.setup(shell, self)
	else:
		view = BeFolderView.new()
		add_child(view)
		view.setup(shell, key)
	add_to_group("pm_auto")
	resized.connect(_relayout)


func _exit_tree() -> void:
	close_menus()


func _has_point(point: Vector2) -> bool:
	if point.y < BeGeometry.TAB_H and not _parts().tab.has_point(point):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


func _parts() -> Dictionary:
	var r := Rect2(Vector2.ZERO, size)
	var tw := BeFont.width(_title, BeGeometry.FONT, true)
	return BeGeometry.find_parts(r, tw) if is_find else BeGeometry.folder_parts(r, tw)


func is_active() -> bool:
	return shell.windows.active() == key


## Re-reads the store and repopulates the view.
func refresh() -> void:
	var groups: Array = ProgramStore.groups
	_title = "Find" if is_find else BeDialogLogic.window_title(key, groups)
	if not is_find:
		var ents := BeDialogLogic.entries_for(key, groups, ProgramStore.launch_group_names())
		var e: Dictionary = shell.windows.get_entry(key)
		view.refresh(ents, String(e.get("view", "large")))
		_status = BeDialogLogic.status_count(ents.size())
		_status2 = ""
		var sel: String = shell.selected_id_in(key)
		for en in ents:
			if en.id == sel:
				_status2 = String(en.c2) if not en.is_group else ""
		_menus = BeMenuModel.menu_bar(key, key == BeWindowStore.COMPUTER, String(e.get("view", "large")), sel)
	else:
		find_view.refresh()
	_relayout()
	queue_redraw()


func _relayout() -> void:
	if size.x <= 0:
		return
	var p := _parts()
	if is_find:
		find_view.position = p.inner.position
		find_view.size = p.inner.size
	else:
		view.position = p.content.position
		view.size = p.content.size
		_menu_rects.clear()
		var x: float = p.menu.position.x + 3
		for m in _menus:
			var w := BeFont.width(String(m.label)) + 20
			_menu_rects.append(Rect2(x, p.menu.position.y + 1, w, p.menu.size.y - 2))
			x += w
	queue_redraw()


func _global(r: Rect2) -> Rect2:
	return Rect2(get_global_rect().position + r.position, r.size)


## Automation ids: "be.window:<key>[:part]" for a specific window, "be.window.active[:part]" for the topmost one.
## Parts: tab, close, zoom, grip, content, menu:<id>, entry:<index|id>.
func auto_lookup(id: String) -> Variant:
	var rest := ""
	if id == "be.window:" + key:
		rest = ""
	elif id.begins_with("be.window:" + key + ":"):
		rest = id.substr(("be.window:" + key + ":").length())
	elif id == "be.window.active" and is_active():
		rest = ""
	elif id.begins_with("be.window.active:") and is_active():
		rest = id.substr("be.window.active:".length())
	else:
		return null
	var p := _parts()
	if rest == "":
		return get_global_rect()
	if rest.begins_with("menu:"):
		var mid := rest.substr(5)
		for i in _menus.size():
			if _menus[i].id == mid and i < _menu_rects.size():
				return _global(_menu_rects[i])
		return null
	if rest.begins_with("entry:") and not is_find:
		var n := rest.substr(6)
		var idx := int(n) if n.is_valid_int() else view.entry_index(n)
		if idx >= 0 and idx < view.entries.size():
			return view.entry_rect(idx)
		return null
	if p.has(rest):
		return _global(p[rest])
	return null


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if size.x <= 0:
		return
	var p := _parts()
	var active := is_active()
	if is_find:
		_draw_find(p, active)
	else:
		_draw_folder(p, active)
	_draw_tab(p, active)


func _draw_tab(p: Dictionary, active: bool) -> void:
	var tab: Rect2 = p.tab
	BeDraw.tab(self, tab, active, not is_find)
	BeDraw.close_box(self, p.close)
	var title_x: float = p.close.end.x + 10
	var limit: float = (p.zoom.position.x - 10) if p.has("zoom") else (tab.end.x - 11)
	BeFont.draw(self, Vector2(title_x, tab.position.y), BeFont.clip(_title, maxf(0.0, limit - title_x), BeGeometry.FONT, true),
		BeTheme.t("000000"), BeGeometry.FONT, true, BeGeometry.TAB_H)
	if p.has("zoom"):
		BeDraw.zoom_box(self, p.zoom)


func _draw_folder(p: Dictionary, _active: bool) -> void:
	BeDraw.panel(self, p.body)
	var m: Rect2 = p.menu
	BeDraw.fill(self, m, BeTheme.b("e8e8e8"))
	BeDraw.border(self, m, BeTheme.b("989898"))
	BeDraw.hline(self, m.position.x, m.end.y - 1, m.size.x, BeTheme.b("6a6a6a"))
	for i in _menus.size():
		var rr: Rect2 = _menu_rects[i]
		if _open_menu == _menus[i].id:
			BeDraw.fill(self, rr, BeTheme.b("a8a8a8"))
		BeFont.draw(self, Vector2(rr.position.x + 10, rr.position.y + (rr.size.y - BeGeometry.LINE) / 2.0), String(_menus[i].label), BeTheme.t("000000"))
	var s: Rect2 = p.status
	var sw := BeFont.width(_status, BeGeometry.FONT_SMALL) + 16
	var chip := Rect2(s.position.x, s.position.y + 1, sw + 2, 18)
	BeDraw.fill(self, chip, BeTheme.b("e8e8e8"))
	BeDraw.border(self, chip, BeTheme.b("989898"))
	BeFont.draw(self, Vector2(chip.position.x + 9, chip.position.y), _status, BeTheme.t("000000"), BeGeometry.FONT_SMALL, false, 18)
	if _status2 != "":
		BeFont.draw(self, Vector2(chip.end.x + 6, s.position.y + 1), BeFont.clip(_status2, p.grip.position.x - chip.end.x - 12, BeGeometry.FONT_SMALL), BeTheme.t("333333"), BeGeometry.FONT_SMALL, false, 18)
	BeDraw.grip(self, p.grip)


func _draw_find(p: Dictionary, _active: bool) -> void:
	BeDraw.panel(self, p.body)
	BeDraw.grip(self, p.grip)


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb)
			else:
				_on_release(mb)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			shell.raise_window(key)
			accept_event()
	elif event is InputEventMouseMotion and not _press.is_empty():
		_on_drag(event as InputEventMouseMotion)
		accept_event()


func _on_press(mb: InputEventMouseButton) -> void:
	shell.raise_window(key)
	var p := _parts()
	var pos := mb.position
	_press = {}
	if p.close.has_point(pos):
		_press = {"part": "close"}
	elif not is_find and p.zoom.has_point(pos):
		_press = {"part": "zoom"}
	elif p.tab.has_point(pos):
		if mb.double_click:
			shell.windows.hide(key)
			return
		_press = {"part": "move", "from": mb.global_position, "pos": position}
	elif p.grip.has_point(pos):
		_press = {"part": "size", "from": mb.global_position, "size": size}
	elif not is_find:
		for i in _menu_rects.size():
			if (_menu_rects[i] as Rect2).has_point(pos):
				_toggle_menu(i)
				return


func _on_release(mb: InputEventMouseButton) -> void:
	var part: String = _press.get("part", "")
	_press = {}
	var p := _parts()
	if part == "close" and p.close.has_point(mb.position):
		shell.close_window(key)
	elif part == "zoom" and p.zoom.has_point(mb.position):
		shell.windows.toggle_zoom(key)


func _on_drag(mm: InputEventMouseMotion) -> void:
	var part: String = _press.part
	var e: Dictionary = shell.windows.get_entry(key)
	if e.is_empty() or e.zoomed:
		return
	if part == "move":
		shell.windows.move_to(key, _press.pos + (mm.global_position - _press.from))
	elif part == "size":
		shell.windows.resize_to(key, _press.size + (mm.global_position - _press.from))


# --------------------------------------------------------------------- menus

func close_menus() -> void:
	if _popup != null and is_instance_valid(_popup) and _popup.is_inside_tree():
		var p := _popup
		_popup = null
		p.close()
	_popup = null
	_open_menu = ""
	queue_redraw()


func _toggle_menu(i: int) -> void:
	var id := String(_menus[i].id)
	var was := _open_menu == id
	close_menus()
	if not was:
		_open_menu_at(i)


func _open_menu_at(i: int) -> void:
	close_menus()
	var rr: Rect2 = _menu_rects[i]
	var origin := get_global_rect().position
	var sibs := []
	for j in _menu_rects.size():
		sibs.append(Rect2(origin + (_menu_rects[j] as Rect2).position, (_menu_rects[j] as Rect2).size) if j != i else Rect2())
	_open_menu = String(_menus[i].id)
	_popup = BePopup.open(shell.menu_layer, _menus[i].items, origin + Vector2(rr.position.x - 1, rr.end.y + 1), {
		"min_w": 200.0, "pad_left": 26.0, "anchor": Rect2(origin + rr.position, rr.size), "siblings": sibs})
	_popup.picked.connect(func(row): shell.do_action(String(row.action), row.args))
	_popup.closed.connect(func():
		_open_menu = ""
		queue_redraw())
	_popup.sibling_hover.connect(func(j: int): _open_menu_at(j))
	queue_redraw()
