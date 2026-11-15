class_name MacPopupMenu
extends Control
## Drop-down / context menu of the Mac shell (design: #ddd panel, 1px #444 border, 2px offset shadow,
## 22px-class rows, #33339a hover). The control is a full-rect overlay: a press outside the panel closes it
## (the menu bar sits above the overlay so title clicks still reach it). Items are MacMenuModel entries; an
## item may carry `icon` (Texture2D, drawn 16px) and `check`. Choose = release over an enabled row, Enter, or
## the accelerator-free keyboard (Up/Down/Home/End/Esc).

signal chosen(id: String)
signal closed

const ROW_H := 20
const SEP_H := 8
const PAD_Y := 2
const PAD_L := 22
const PAD_R := 22
const MIN_W := 170

var items: Array = []
var anchor := Vector2.ZERO          ## requested top-left of the panel
var min_width := MIN_W
var hover := -1
var panel_rect := Rect2()
var auto_prefix := "mac.popup-item:"
var align_right_to := -1.0          ## when >= 0 the panel's right edge is aligned to this x
var _rows: Array = []               ## [{rect, index}] for selectable rows
var _closing := false
var _armed := false                 ## a release only chooses once the pointer moved (or pressed) inside the menu


static func open(parent: Control, p_items: Array, at: Vector2, opts: Dictionary = {}) -> MacPopupMenu:
	var m := MacPopupMenu.new()
	m.items = p_items
	m.anchor = at
	m.min_width = int(opts.get("min_width", MIN_W))
	m.align_right_to = float(opts.get("align_right", -1.0))
	m.auto_prefix = String(opts.get("auto_prefix", "mac.popup-item:"))
	parent.add_child(m)
	m._layout()
	return m


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("pm_auto")


func _ready() -> void:
	set_process_input(true)
	_layout()


func _row_h(entry: Dictionary) -> int:
	return SEP_H if MacMenuModel.is_sep(entry) else ROW_H


func _layout() -> void:
	var vp := get_parent_area_size() if get_parent() is Control else size
	var w := min_width
	for e in items:
		if MacMenuModel.is_sep(e):
			continue
		var tw: int = PAD_L + MacDraw.measure(String(e.label)) + PAD_R
		if e.get("icon") != null:
			tw += 20
		if e.has("key"):
			tw += 24 + MacDraw.measure(MacMenuModel.accelerator_text(String(e.key), OS.get_name() == "macOS"))
		w = maxi(w, tw)
	var h := PAD_Y * 2 + 2
	for e in items:
		h += _row_h(e)
	var x := anchor.x
	if align_right_to >= 0.0:
		x = align_right_to - w
	if x + w + 2 > vp.x:
		x = maxf(0.0, vp.x - w - 2)
	var y := anchor.y
	if y + h + 2 > vp.y:
		y = maxf(0.0, vp.y - h - 2)
	panel_rect = Rect2(x, y, w, h)
	_rows.clear()
	var ry := y + 1 + PAD_Y
	for i in items.size():
		var rh := _row_h(items[i])
		if not MacMenuModel.is_sep(items[i]):
			_rows.append({"rect": Rect2(x + 1, ry, w - 2, rh), "index": i})
		ry += rh
	queue_redraw()


func _index_at(p: Vector2) -> int:
	for r in _rows:
		if r.rect.has_point(p):
			return int(r.index)
	return -1


func _draw() -> void:
	MacDraw.menu_panel(self, panel_rect)
	var y := panel_rect.position.y + 1 + PAD_Y
	var mac_os := OS.get_name() == "macOS"
	for i in items.size():
		var e: Dictionary = items[i]
		if MacMenuModel.is_sep(e):
			MacDraw.separator(self, panel_rect.position.x + 1, y + 3, panel_rect.size.x - 2)
			y += SEP_H
			continue
		var disabled: bool = e.get("disabled", false)
		var lit := i == hover and not disabled
		var row := Rect2(panel_rect.position.x + 1, y, panel_rect.size.x - 2, ROW_H)
		if lit:
			draw_rect(row, MacTheme.b("33339a"))
		var fg := MacTheme.t("ffffff") if lit else (MacTheme.t("999999") if disabled else MacTheme.t("000000"))
		if e.get("check", false):
			MacDraw.check(self, Vector2(row.position.x + 7, y + 6), fg)
		var tx := row.position.x + PAD_L
		if e.get("icon") != null:
			draw_texture_rect(e.icon, Rect2(tx, y + 2, 16, 16), false)
			tx += 20
		MacDraw.text_centered_y(self, tx, y, ROW_H, String(e.label), fg)
		if e.has("key"):
			var kt := MacMenuModel.accelerator_text(String(e.key), mac_os)
			var kfg := MacTheme.t("ffffff") if lit else MacTheme.t("999999")
			MacDraw.text_centered_y(self, row.end.x - PAD_R + 8 - MacDraw.measure(kt), y, ROW_H, kt, kfg)
		y += ROW_H


func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree() or not id.begins_with(auto_prefix):
		return null
	var label := id.substr(auto_prefix.length())
	for r in _rows:
		var e: Dictionary = items[r.index]
		if String(e.label) == label or String(e.id) == label:
			return Rect2(r.rect.position + global_position, r.rect.size)
	return null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _index_at((event as InputEventMouseMotion).position)
		if i != hover:
			hover = i
			queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var over := _index_at(mb.position)
		if mb.pressed:
			if not panel_rect.has_point(mb.position):
				close()
			else:
				_armed = true
		elif over >= 0 and _armed:
			_choose(over)
		accept_event()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseMotion:
		# injected/embedded pointer motion does not always reach the GUI pass; track hover here too
		var mp := (event as InputEventMouseMotion).position - global_position
		if mp != anchor:
			_armed = true
		var i := _index_at(mp)
		if i != hover:
			hover = i
			queue_redraw()
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_ESCAPE:
			close()
		KEY_DOWN:
			_step(1)
		KEY_UP:
			_step(-1)
		KEY_HOME:
			hover = -1
			_step(1)
		KEY_END:
			hover = items.size()
			_step(-1)
		KEY_ENTER, KEY_KP_ENTER:
			if hover >= 0:
				_choose(hover)
		_:
			return
	get_viewport().set_input_as_handled()


func _step(dir: int) -> void:
	var i := hover
	for _n in items.size():
		i += dir
		if i < 0 or i >= items.size():
			i = (i + items.size()) % items.size()
		if not MacMenuModel.is_sep(items[i]) and not items[i].get("disabled", false):
			hover = i
			break
	queue_redraw()


func _choose(index: int) -> void:
	var e: Dictionary = items[index]
	if e.get("disabled", false):
		return
	var id := String(e.id)
	close()
	chosen.emit(id)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
