class_name MacListBox
extends Control
## Single-selection list (Help topics, Browse, Shut Down choices) and, with `grid = true`, an icon grid
## (Change Icon). Rows: {id, label, sub?, icon?}. Selected row = #33339a with white text. Double-click emits `activated`.

signal selection_changed(id: String)
signal activated(id: String)

const ROW_H := 20
const CELL := Vector2(52, 48)

var rows: Array = []
var selected_id := ""
var grid := false
var _scroll := 0
var _auto := ""


func _init(p_auto_id: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_auto = p_auto_id
	add_to_group("pm_auto")
	if p_auto_id != "":
		set_meta("auto_id", p_auto_id)


func _content_h() -> int:
	if grid:
		var per := maxi(1, int((size.x - 12) / CELL.x))
		return 12 + int(ceil(float(rows.size()) / per)) * int(CELL.y + 4)
	return rows.size() * ROW_H


func _cell_rect(i: int) -> Rect2:
	if grid:
		var per := maxi(1, int((size.x - 12) / CELL.x))
		return Rect2(6 + (i % per) * CELL.x, 6 + (i / per) * (CELL.y + 4) - _scroll, CELL.x, CELL.y)
	return Rect2(0, i * ROW_H - _scroll, size.x, ROW_H)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), MacTheme.b("ffffff"))
	for i in rows.size():
		var r := _cell_rect(i)
		if r.end.y < 0 or r.position.y > size.y:
			continue
		var row: Dictionary = rows[i]
		var on: bool = String(row.id) == selected_id
		if on:
			draw_rect(r, MacTheme.b("33339a"))
		if grid:
			draw_texture_rect(MacIconCatalog.texture(String(row.get("icon", "")), "large"), Rect2(r.position + Vector2(10, 8), Vector2(32, 32)), false)
			continue
		var fg := MacTheme.t("ffffff") if on else MacTheme.t("000000")
		var tx := r.position.x + 8
		if row.has("icon"):
			draw_texture_rect(MacIconCatalog.texture(String(row.icon), "small"), Rect2(tx, r.position.y + 2, 16, 16), false)
			tx += 24
		var sub := String(row.get("sub", ""))
		var sub_w := mini(MacDraw.measure(sub), int(size.x * 0.5)) if sub != "" else 0
		MacDraw.text_centered_y(self, tx, r.position.y, ROW_H, String(row.label), fg, false, int(size.x - tx - sub_w - 16))
		if sub != "":
			MacDraw.text_centered_y(self, size.x - 8 - sub_w, r.position.y, ROW_H, sub, fg if on else MacTheme.t("888888"), false, sub_w)
	Px.outline(self, Rect2(Vector2.ZERO, size), MacTheme.b("888888"))


func _index_at(p: Vector2) -> int:
	for i in rows.size():
		if _cell_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _index_at(mb.position)
			if i >= 0:
				selected_id = String(rows[i].id)
				selection_changed.emit(selected_id)
				queue_redraw()
				if mb.double_click:
					activated.emit(selected_id)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_scroll = clampi(_scroll + (-24 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 24), 0, maxi(0, _content_h() - int(size.y)))
			queue_redraw()
		accept_event()


func auto_lookup(id: String) -> Variant:
	if _auto == "" or not is_visible_in_tree() or not id.begins_with(_auto + ":"):
		return null
	var token := id.substr(_auto.length() + 1)
	for i in rows.size():
		if String(rows[i].id) == token or String(rows[i].label) == token or str(i) == token:
			var r := _cell_rect(i)
			return Rect2(global_position + r.position, r.size)
	return null
