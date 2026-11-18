class_name MacFindWindow
extends MacWindow
## The Find window (design "Find items [in all groups] whose [name] contains [____]  [Find]" + results list).
## Results are ProgramSearch matches; double-click launches, right-click opens the item context menu. Searching
## "name (launch groups)" also matches launch group names, and the last column then shows each item's launch group.
## Sticky notes match by title and text ("name" and "name or text (notes)"); their last column is the note's first line.

const PAD := 12
const ROW_H := 20
const HEADER_H := 20

var where_sel: MacSelect
var type_sel: MacSelect
var query: MacTextField
var find_btn: MacButton
var results: Array = []     ## [{group, item}]
var ran := false
var ran_kind := ""          ## the type filter of the last search (its last column follows it)
var _sel_id := ""
var _scroll := 0


func _init() -> void:
	super._init()
	has_zoom = false
	where_sel = MacSelect.new("mac.find.where")
	type_sel = MacSelect.new("mac.find.type")
	type_sel.options = [{"id": "all", "label": "name"}, {"id": "app", "label": "name (programs)"},
		{"id": "url", "label": "name (URLs)"}, {"id": "note", "label": "name or text (notes)"},
		{"id": "batch", "label": "name (launch groups)"}]
	query = MacTextField.new("mac.find.query")
	find_btn = MacButton.new("Find", 70)
	find_btn.is_default = true
	find_btn.set_meta("auto_id", "mac.find.run")
	for c in [where_sel, type_sel, query, find_btn]:
		add_child(c)
	find_btn.pressed.connect(run_search)
	query.text_submitted.connect(func(_t): run_search())


func title_text() -> String:
	return "Find"


func setup() -> void:
	where_sel.host = desk.shell.select_layer
	type_sel.host = desk.shell.select_layer
	refresh_groups()


func refresh_groups() -> void:
	var opts := [{"id": "all", "label": "in all groups"}]
	for g in ProgramStore.groups:
		opts.append({"id": String(g.id), "label": "in “%s”" % String(g.name)})
	var keep := where_sel.current_id()
	where_sel.options = opts
	where_sel.selected_index = 0
	where_sel.select_id(keep)


func focus_query() -> void:
	query.focus_edit()


func run_search() -> void:
	results = MacDialogLogic.find_items(ProgramStore.groups, query.text, where_sel.current_id(), type_sel.current_id(),
		ProgramStore.launch_group_names())
	ran = true
	ran_kind = type_sel.current_id()
	_scroll = 0
	_sel_id = ""
	queue_redraw()


func _on_state_synced(st: Dictionary) -> void:
	for c in [where_sel, type_sel, query, find_btn]:
		c.visible = not st.shaded
	if st.shaded:
		return
	var b := MacGeometry.find_body(Rect2(Vector2.ZERO, size))
	var x := b.position.x + PAD
	var y1 := b.position.y + PAD
	var fw: float = MacDraw.measure("Find items")
	where_sel.position = Vector2(x + fw + 8, y1)
	where_sel.size = Vector2(clampf(b.size.x - PAD * 2 - fw - 8 - 48, 60.0, 170.0), 22)
	var y2 := y1 + 22 + 10
	type_sel.position = Vector2(x, y2)
	type_sel.size = Vector2(140, 22)
	var cx := x + 140 + 8 + MacDraw.measure("contains") + 8
	query.position = Vector2(cx, y2)
	query.size = Vector2(maxf(60.0, b.end.x - PAD - cx), 22)
	find_btn.position = Vector2(b.end.x - PAD - find_btn.size.x - 4, y2 + 22 + 14)


func _results_rect() -> Rect2:
	var b := MacGeometry.find_body(Rect2(Vector2.ZERO, size))
	var top := find_btn.position.y + find_btn.size.y + 14
	return Rect2(b.position.x + PAD, top, b.size.x - PAD * 2, maxf(0.0, b.end.y - 22 - top))


func _draw_body(c: Dictionary, _st: Dictionary) -> void:
	var b := MacGeometry.find_body(Rect2(Vector2.ZERO, size))
	var fg := MacTheme.t("000000")
	MacDraw.text(self, Vector2(b.position.x + PAD, where_sel.position.y + 4), "Find items", fg)
	MacDraw.text(self, Vector2(where_sel.position.x + where_sel.size.x + 8, where_sel.position.y + 4), "whose", fg)
	MacDraw.text(self, Vector2(type_sel.position.x + type_sel.size.x + 8, type_sel.position.y + 4), "contains", fg)
	if not ran:
		return
	var rr := _results_rect()
	if rr.size.y <= HEADER_H:
		return
	draw_rect(rr, MacTheme.b("ffffff"))
	var cols := [rr.size.x * 0.34, rr.size.x * 0.2]
	var c0 := int(cols[0])
	var c1 := int(cols[1])
	var view_h := int(rr.size.y) - HEADER_H
	var max_scroll := maxi(0, results.size() * ROW_H - view_h)
	var batch := ran_kind == "batch"
	var names := ProgramStore.launch_group_names()
	_scroll = clampi(_scroll, 0, max_scroll)
	for i in results.size():
		var ry := rr.position.y + HEADER_H + i * ROW_H - _scroll
		if ry < rr.position.y + HEADER_H - ROW_H + 1 or ry + ROW_H > rr.end.y + ROW_H - 1:
			continue
		if ry < rr.position.y + HEADER_H or ry + ROW_H > rr.end.y:
			continue
		var r: Dictionary = results[i]
		var on: bool = r.item.id == _sel_id
		if on:
			draw_rect(Rect2(rr.position.x, ry, rr.size.x, ROW_H), MacTheme.b("ccccff"))
		Px.hline(self, rr.position.x, ry + ROW_H - 1, rr.size.x, MacTheme.b("eeeeee"))
		draw_texture_rect(MacIconCatalog.texture(String(r.item.get("icon", "")), "small"), Rect2(rr.position.x + 8, ry + 2, 16, 16), false)
		MacDraw.text_centered_y(self, rr.position.x + 30, ry, ROW_H - 1, MacDraw.fit(String(r.item.name), c0 - 36), fg)
		MacDraw.text_centered_y(self, rr.position.x + c0 + 10, ry, ROW_H - 1, MacDraw.fit(String(r.group.name), c1 - 14), fg)
		var last := MacDialogLogic.find_detail(r.item, batch, names)
		MacDraw.text_centered_y(self, rr.position.x + c0 + c1 + 10, ry, ROW_H - 1, MacDraw.fit(last, int(rr.size.x) - c0 - c1 - 14), fg)
	draw_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, HEADER_H), MacTheme.b("dddddd"))
	# The Name header shading marks a sorted column. Results are ranked by relevance, so shade it only when they really
	# are in name order (the same rule as the folder list view).
	if MacFolderView.is_name_sorted(results.map(func(r): return r.item)):
		draw_rect(Rect2(rr.position.x, rr.position.y, c0, HEADER_H), MacTheme.b("bbbbbb"))
	Px.hline(self, rr.position.x, rr.position.y + HEADER_H - 1, rr.size.x, MacTheme.b("888888"))
	MacDraw.text_centered_y(self, rr.position.x + 10, rr.position.y, HEADER_H - 1, "Name", fg)
	MacDraw.text_centered_y(self, rr.position.x + c0 + 10, rr.position.y, HEADER_H - 1, "Group", fg)
	MacDraw.text_centered_y(self, rr.position.x + c0 + c1 + 10, rr.position.y, HEADER_H - 1, MacDialogLogic.find_detail_header(ran_kind), fg)
	Px.vline(self, rr.position.x + c0 - 1, rr.position.y, HEADER_H - 1, MacTheme.b("888888"))
	Px.vline(self, rr.position.x + c0 + c1 - 1, rr.position.y, HEADER_H - 1, MacTheme.b("888888"))
	Px.outline(self, rr, MacTheme.b("888888"))
	MacDraw.text(self, Vector2(rr.position.x, rr.end.y + 5), "%s found" % MacDialogLogic.plural(results.size(), "item"), fg)
	if not _st.shaded and not _st.zoomed:
		MacDraw.grip(self, c.grip, true)


func _row_at(p: Vector2) -> int:
	var rr := _results_rect()
	if not ran or not Rect2(rr.position.x, rr.position.y + HEADER_H, rr.size.x, rr.size.y - HEADER_H).has_point(p):
		return -1
	var i := int((p.y - rr.position.y - HEADER_H + _scroll) / ROW_H)
	return i if i >= 0 and i < results.size() else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var hit_row := _row_at(mb.position)
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and ran:
			_scroll += -24 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 24
			queue_redraw()
			accept_event()
			return
		if mb.pressed and part_at(mb.position) == Part.BODY and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			desk.activate_window(key)
			_sel_id = String(results[hit_row].item.id) if hit_row >= 0 else ""
			queue_redraw()
			if hit_row >= 0:
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
					desk.shell.launch_item(results[hit_row].item)
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					desk.shell.show_item_context(String(results[hit_row].group.id), String(results[hit_row].item.id), mb.global_position)
			accept_event()
			return
	super._gui_input(event)


func selected_result() -> Dictionary:
	for r in results:
		if r.item.id == _sel_id:
			return r
	return {}


func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return super.auto_lookup(id)
	if id.begins_with("mac.find.result:"):
		var i := id.substr("mac.find.result:".length()).to_int()
		if i >= 0 and i < results.size():
			var rr := _results_rect()
			return Rect2(global_position + Vector2(rr.position.x + 8, rr.position.y + HEADER_H + i * ROW_H - _scroll), Vector2(rr.size.x - 16, ROW_H))
		return null
	return super.auto_lookup(id)
