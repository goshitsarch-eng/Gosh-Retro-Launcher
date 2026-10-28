class_name Win31PopupMenu
extends Control
## Drop-down / control-menu popup (Win31PopupMenu in Win31MenuBar.tsx + .wfw-popup-menu CSS).
## Pointer and key handling run from _input so a menu works even when the press that opened it
## never released (automation / press-drag gestures) and the Godot GUI focus mask is stale.

signal command_chosen(command: String)
signal dismissed

const BORDER_PAD := 3        ## 1px border + 2px padding
const ROW_H := 17
const SEP_H := 6
const CHECK_COL := 14
const ITEM_PAD_L := 2
const ITEM_PAD_R := 12

var items: Array = []
var min_width := 172
var highlighted := -1
## Group-window control menus close on Escape too; both share the TS key handler.
var key_handling := true

var _pressed := -1
var _born_frame := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # hit-testing is done in _input
	focus_mode = Control.FOCUS_NONE
	_born_frame = Engine.get_process_frames()


func set_items(new_items: Array, keep_highlight: bool = true) -> void:
	items = new_items
	var enabled := Win31Commands.enabled_indexes(items)
	if not keep_highlight or not enabled.has(highlighted):
		highlighted = enabled[0] if enabled.size() > 0 else -1
	size = compute_size()
	queue_redraw()


func compute_size() -> Vector2:
	var f := Win31Chrome.font()
	var widest := 0
	var h := BORDER_PAD * 2
	for it in items:
		if it.get("separator", false):
			h += SEP_H
		else:
			h += ROW_H
			widest = maxi(widest, f.measure(String(it.get("label", ""))))
	var w := maxi(min_width, BORDER_PAD * 2 + ITEM_PAD_L + CHECK_COL + widest + ITEM_PAD_R)
	return Vector2(w, h)


## Local rect of item `i`.
func item_rect(i: int) -> Rect2:
	var y := float(BORDER_PAD)
	for k in items.size():
		var is_sep: bool = items[k].get("separator", false)
		var hh := SEP_H if is_sep else ROW_H
		if k == i:
			return Rect2(BORDER_PAD, y, size.x - BORDER_PAD * 2, hh)
		y += hh
	return Rect2()


func item_at(local: Vector2) -> int:
	for i in items.size():
		if items[i].get("separator", false):
			continue
		if item_rect(i).has_point(local):
			return i
	return -1


func _draw() -> void:
	var f := Win31Chrome.font()
	Win31Chrome.popup_frame(self, Rect2(Vector2.ZERO, size))
	for i in items.size():
		var it: Dictionary = items[i]
		var r := item_rect(i)
		if it.get("separator", false):
			Win31Chrome.separator(self, r.position.x + 1 - 0, r.position.y + 2, r.size.x - 2 + 0)
			continue
		var disabled: bool = it.get("disabled", false)
		var hot := i == highlighted and not disabled
		if hot:
			Px.fill_rect(self, r, Pal.NAVY)
		var color := Pal.WHITE if hot else Pal.BLACK
		if it.get("checked", false):
			Win31Chrome.check_mark(self, Vector2(r.position.x + 3, r.position.y + 4), Pal.SHADOW if disabled else color)
		Win31Chrome.access_text(self, Vector2(r.position.x + ITEM_PAD_L + CHECK_COL, r.position.y + 1),
			String(it.get("label", "")), color, 14, disabled)


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		var local: Vector2 = event.position - get_global_rect().position
		if get_global_rect().has_point(event.position):
			var i := item_at(local)
			if i >= 0 and not items[i].get("disabled", false) and i != highlighted:
				highlighted = i
				queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_global_rect().has_point(event.position):
			_pressed = -1
			return
		var vp := get_viewport()
		var local: Vector2 = event.position - get_global_rect().position
		var i := item_at(local)
		if event.pressed:
			_pressed = i
		else:
			var was := _pressed
			_pressed = -1
			if i >= 0 and i == was and not items[i].get("disabled", false):
				var cmd: Variant = items[i].get("command")
				if cmd != null:
					command_chosen.emit(String(cmd))
		vp.set_input_as_handled()
	elif event is InputEventKey and event.pressed and key_handling:
		if Engine.get_process_frames() == _born_frame:
			return
		_key(event)


func _key(ev: InputEventKey) -> void:
	var key := Win31Commands.key_name(ev)
	var enabled := Win31Commands.enabled_indexes(items)
	if key == "escape":
		get_viewport().set_input_as_handled()
		dismissed.emit()
		return
	if key == "home" or key == "end":
		get_viewport().set_input_as_handled()
		highlighted = (enabled[0] if key == "home" else enabled[enabled.size() - 1]) if enabled.size() > 0 else -1
		queue_redraw()
		return
	if key == "down" or key == "up":
		get_viewport().set_input_as_handled()
		highlighted = Win31Commands.step_highlight(enabled, highlighted, 1 if key == "down" else -1)
		queue_redraw()
		return
	if (key == "enter" or key == " ") and highlighted >= 0:
		get_viewport().set_input_as_handled()
		var cmd: Variant = items[highlighted].get("command")
		if cmd != null:
			command_chosen.emit(String(cmd))
		return
	var m := Win31Commands.mnemonic_match(items, key)
	if m >= 0:
		get_viewport().set_input_as_handled()
		var cmd2: Variant = items[m].get("command")
		if cmd2 != null:
			command_chosen.emit(String(cmd2))


## Automation: rect (logical coordinates) of the row whose visible label contains `label`.
func auto_row(label: String) -> Variant:
	for i in items.size():
		if items[i].get("separator", false):
			continue
		var visible: String = RetroFont.parse_access(String(items[i].get("label", ""))).text
		if visible.contains(label):
			var r := item_rect(i)
			return Rect2(get_global_rect().position + r.position, r.size)
	return null
