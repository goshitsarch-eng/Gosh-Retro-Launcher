class_name Win31MenuBar
extends Control
## The File / Options / Window / Launcher / Help bar (Win31MenuBar in Win31MenuBar.tsx,
## .wfw-menu-bar CSS). Owns the open drop-down; keyboard: F10, Alt+<mnemonic>, Left/Right.

signal command_chosen(command: String)

const ROOT_WIDTHS := [40, 58, 60, 72, 45]
const ROOT_H := 19
const POPUP_TOP := 18
const BAR_H := 20

var menus: Array = []
var disabled := false
var active_menu := ""
## Full-rect overlay (above the MDI client) that hosts popups; assigned by the program manager.
var popup_layer: Control

var _popup: Win31PopupMenu
var _born_frame := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, BAR_H)
	add_to_group("pm_auto")


func set_menus(new_menus: Array) -> void:
	menus = new_menus
	if _popup != null:
		var m := _menu(active_menu)
		if m.is_empty():
			close_menu()
		else:
			_popup.set_items(m.items)
	queue_redraw()


func _menu(id: String) -> Dictionary:
	for m in menus:
		if m.id == id:
			return m
	return {}


func root_rect(index: int) -> Rect2:
	var x := 0
	for i in index:
		x += ROOT_WIDTHS[i]
	return Rect2(x, 0, ROOT_WIDTHS[index], ROOT_H)


func root_at(local: Vector2) -> int:
	for i in menus.size():
		if root_rect(i).has_point(local):
			return i
	return -1


func open_menu(id: String) -> void:
	if disabled and active_menu == "":
		return
	if id == active_menu and _popup != null:
		return
	close_menu(false)
	var idx := _index_of(id)
	if idx < 0 or popup_layer == null:
		return
	active_menu = id
	var m := _menu(id)
	_popup = Win31PopupMenu.new()
	_popup.min_width = 172
	_popup.command_chosen.connect(_on_command)
	_popup.dismissed.connect(close_menu)
	popup_layer.add_child(_popup)
	_popup.set_items(m.items, false)
	var root := root_rect(idx)
	var bar_pos := get_global_rect().position - popup_layer.get_global_rect().position
	var x := bar_pos.x + root.position.x
	if idx >= menus.size() - 2:  # .wfw-menu-root:nth-last-child(-n+2) > popup {right: 0}
		x = bar_pos.x + root.end.x - _popup.size.x
	_popup.position = Vector2(x, bar_pos.y + POPUP_TOP)
	_born_frame = Engine.get_process_frames()
	queue_redraw()


func close_menu(redraw: bool = true) -> void:
	active_menu = ""
	if _popup != null:
		if is_instance_valid(_popup):
			_popup.queue_free()
			if _popup.get_parent():
				_popup.get_parent().remove_child(_popup)
		_popup = null
	if redraw:
		queue_redraw()


func _index_of(id: String) -> int:
	for i in menus.size():
		if menus[i].id == id:
			return i
	return -1


func _on_command(command: String) -> void:
	close_menu()
	command_chosen.emit(command)


func is_open() -> bool:
	return active_menu != ""


func popup_rect() -> Rect2:
	return _popup.get_global_rect() if _popup != null else Rect2()


func _exit_tree() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()


func _draw() -> void:
	var f := Win31Chrome.font()
	Px.fill(self, 0, 0, size.x, size.y, Pal.WHITE)
	Px.hline(self, 0, size.y - 1, size.x, Pal.BLACK)
	for i in menus.size():
		var r := root_rect(i)
		var pressed: bool = menus[i].id == active_menu
		if pressed:
			Px.fill_rect(self, r, Pal.NAVY)
		Win31Chrome.access_text(self, Vector2(r.position.x + 8, r.position.y), menus[i].label,
			Pal.WHITE if pressed else Pal.BLACK, 18)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var grect := get_global_rect()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var inside := grect.has_point(event.position)
		if event.pressed:
			if inside:
				var i := root_at(event.position - grect.position)
				if i >= 0 and not disabled:
					if menus[i].id == active_menu:
						close_menu()
					else:
						open_menu(menus[i].id)
				get_viewport().set_input_as_handled()
			elif active_menu != "" and not popup_rect().has_point(event.position):
				close_menu()  # dismiss; the press continues to its target
		elif inside:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if active_menu != "" and grect.has_point(event.position):
			var i2 := root_at(event.position - grect.position)
			if i2 >= 0 and menus[i2].id != active_menu:
				open_menu(menus[i2].id)
	elif event is InputEventKey and event.pressed:
		if Engine.get_process_frames() == _born_frame:
			return
		_key(event)


func _key(ev: InputEventKey) -> void:
	if disabled:
		return
	var key := Win31Commands.key_name(ev)
	if key == "f10":
		get_viewport().set_input_as_handled()
		if active_menu != "":
			close_menu()
		elif menus.size() > 0:
			open_menu(menus[0].id)
		return
	if ev.alt_pressed and not ev.ctrl_pressed and not ev.meta_pressed:
		var id := Win31Commands.menu_for_accelerator(menus, key)
		if id != "":
			get_viewport().set_input_as_handled()
			open_menu(id)
			return
	if active_menu == "":
		return
	if key == "right" or key == "left":
		get_viewport().set_input_as_handled()
		var idx := _index_of(active_menu)
		var offset := 1 if key == "right" else -1
		open_menu(menus[(idx + offset + menus.size()) % menus.size()].id)


## Automation ids: wfw.menu:<index>.
func auto_lookup(id: String) -> Variant:
	if id.begins_with("wfw.menu:") and is_visible_in_tree():
		var i := int(id.substr(9))
		if i >= 0 and i < ROOT_WIDTHS.size():
			var r := root_rect(i)
			return Rect2(get_global_rect().position + r.position, r.size)
	elif id.begins_with("wfw.popup-item:") and _popup != null:
		return _popup.auto_row(id.substr(15))
	return null
