class_name Win31QuickSearch
extends Control
## Quick Search overlay (port of components/QuickSearch/QuickSearchOverlay.tsx). Visible while
## UIState.quick_search_open: a centred 400px "Search for Program Item" box with a text field and
## up to 10 ranked results. Up/Down move, Enter launches, Esc or a click outside closes.
## Mounted full-rect above the shell by Win31Shell.

var _dialog: _SearchDialog


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	UIState.quick_search_changed.connect(_sync)
	resized.connect(_place)
	_sync()


func _sync() -> void:
	var open: bool = UIState.quick_search_open
	if open and _dialog == null:
		_dialog = _SearchDialog.new()
		add_child(_dialog)
		_dialog.setup(int(size.y))
		_dialog.relaid_out.connect(_place)
		_place()
		_dialog.focus_field()
	elif not open and _dialog != null:
		var d := _dialog
		_dialog = null
		d.queue_free()
		remove_child(d)
	visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE


func _place() -> void:
	if _dialog:
		_dialog.place(size)


func _gui_input(event: InputEvent) -> void:
	# click on the backdrop (not on the dialog) closes
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dialog == null or not _dialog.get_rect().has_point(event.position):
			UIState.close_quick_search()
		accept_event()


func is_open() -> bool:
	return _dialog != null


## Test/automation access.
func dialog() -> Control:
	return _dialog


class _SearchDialog extends W31Dialog:
	signal relaid_out

	var field: W31TextField
	var results: _Results

	func _init() -> void:
		super("Search for Program Item", 400)
		draggable = false
		system_menu = false
		cancel_callable = UIState.close_quick_search
		set_auto_id("wfw.quick-search")

	func setup(shell_height: int) -> void:
		build(shell_height)
		max_height = 100000

	func focus_field() -> void:
		if field:
			field.focus_at_end()

	func _build(cw: int) -> void:
		field = W31TextField.new()
		field.set_field_size(cw, 19)
		field.placeholder_text = "Search programs... (Esc to close)"
		field.set_auto_id("wfw.quick-search.input")
		add_widget(field, 0, 0)
		results = _Results.new()
		results.position = Vector2(0, 27)
		results.size = Vector2(cw, 0)
		results.set_auto_id("wfw.quick-search.results")
		results.height_changed.connect(_on_height)
		body.add_child(results)
		field.text_changed.connect(func(t: String): results.set_query(t))
		_finish(27)
		results.set_query("")

	func _on_height(h: int) -> void:
		_finish(27 + h)
		_finish_layout(false)
		relaid_out.emit()

	## Key handling lives here (before the LineEdit sees Up/Down/Enter).
	func _input(event: InputEvent) -> void:
		if not (event is InputEventKey) or not event.pressed:
			return
		match event.keycode:
			KEY_DOWN:
				results.move(1)
			KEY_UP:
				results.move(-1)
			KEY_ENTER, KEY_KP_ENTER:
				results.launch_selected()
			KEY_ESCAPE:
				UIState.close_quick_search()
			_:
				return
		if is_inside_tree():
			get_viewport().set_input_as_handled()

	func tab_stops() -> Array:
		return []


class _Results extends W31Widget:
	signal height_changed(h: int)

	const ROW_H := 30
	const MAX_H := 300
	const NO_RESULTS_H := 45

	var query := ""
	var view: Dictionary = {}
	var selected := 0
	var scroll_y := 0.0
	var _last_len := -1
	var _sb: W31ScrollBar

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		_sb = W31ScrollBar.new()
		_sb.visible = false
		_sb.step = ROW_H
		_sb.scrolled.connect(func(v: float):
			scroll_y = v
			queue_redraw())
		add_child(_sb)

	func displayed() -> Array:
		return view.get("displayed", [])

	func set_query(q: String) -> void:
		query = q
		view = W31DialogLogic.quick_search_view(ProgramStore.groups, q)
		var n: int = displayed().size()
		if n != _last_len:
			selected = 0
			_last_len = n
		scroll_y = 0.0
		_relayout()

	func _content_h() -> int:
		var n: int = displayed().size()
		if n == 0:
			return 0
		return n * ROW_H + (23 if view.get("hasMore", false) else 0)

	func _relayout() -> void:
		var n: int = displayed().size()
		var h := 0
		if n > 0:
			var ch := _content_h() + 2
			h = mini(ch, MAX_H)
			size.y = h
			_sb.visible = ch > h
			if _sb.visible:
				_sb.position = Vector2(size.x - 1 - W31ScrollBar.WIDTH, 1)
				_sb.size = Vector2(W31ScrollBar.WIDTH, h - 2)
				_sb.total = _content_h()
				_sb.page = h - 2
		elif view.get("empty", false):
			h = NO_RESULTS_H
			size.y = h
			_sb.visible = false
		else:
			size.y = 0
			_sb.visible = false
		height_changed.emit(h)
		queue_redraw()

	func move(delta: int) -> void:
		selected = W31DialogLogic.quick_search_move(selected, delta, displayed().size())
		_ensure_visible()
		queue_redraw()

	func _ensure_visible() -> void:
		if not _sb.visible:
			return
		var top := selected * ROW_H
		if top < scroll_y:
			scroll_y = top
		elif top + ROW_H > scroll_y + size.y - 2:
			scroll_y = top + ROW_H - (size.y - 2)
		_sb.value = scroll_y
		scroll_y = _sb.value

	func launch_selected() -> void:
		var d := displayed()
		if selected >= 0 and selected < d.size():
			_launch(d[selected].item)

	func _launch(item: Dictionary) -> void:
		var result: Dictionary = await Platform.launch(item)
		if not result.get("success", false):
			push_warning("Failed to launch: %s" % result.get("error", ""))
		UIState.close_quick_search()
		if ProgramStore.settings.get("minimizeOnUse", false):
			Platform.minimize_window()

	func _row_at(p: Vector2) -> int:
		var i := int((p.y - 1 + scroll_y) / ROW_H)
		return i if i >= 0 and i < displayed().size() else -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var i := _row_at(event.position)
			if i >= 0 and i != selected and event.position.x < size.x - (W31ScrollBar.WIDTH if _sb.visible else 0):
				selected = i
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var i := _row_at(event.position)
				if i >= 0 and event.position.x < size.x - (W31ScrollBar.WIDTH if _sb.visible else 0):
					_launch(displayed()[i].item)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and _sb.visible:
				_sb.value -= ROW_H
				scroll_y = _sb.value
				queue_redraw()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _sb.visible:
				_sb.value += ROW_H
				scroll_y = _sb.value
				queue_redraw()
			accept_event()

	func auto_lookup(id: String) -> Variant:
		if id.begins_with("wfw.quick-search.result:"):
			var i := int(id.get_slice(":", 1))
			if i >= 0 and i < displayed().size():
				return Rect2(get_global_rect().position + Vector2(1, 1 + i * ROW_H - scroll_y), Vector2(size.x - 2, ROW_H))
		return null

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if size.y <= 0:
			return
		var d := displayed()
		if d.is_empty():
			if view.get("empty", false):
				var s := "No results found"
				W31.text(self, floorf((size.x - W31.text_w(s)) / 2.0), 16, s, W31.SHADOW)
			return
		Px.fill_rect(self, r, W31.WHITE)
		W31.border2(self, r, W31.SHADOW, W31.WHITE)
		var sb_w := W31ScrollBar.WIDTH if _sb.visible else 0
		var inner_w := size.x - 2 - sb_w
		var clip_top := 1.0
		var clip_bottom := size.y - 1
		for i in d.size():
			var y := 1 + i * ROW_H - scroll_y
			if y + ROW_H <= clip_top or y >= clip_bottom:
				continue
			var sel := i == selected
			var rr := Rect2(1, y, inner_w, ROW_H)
			if sel:
				_fill_clipped(rr, W31.NAVY, clip_top, clip_bottom)
			var fg := W31.WHITE if sel else W31.BLACK
			var sub := Color(1, 1, 1, 1).lerp(W31.NAVY, 0.2) if sel else W31.BLACK.lerp(W31.FACE, 0.2)
			var item: Dictionary = d[i].item
			var tex: Texture2D = IconRegistry.resolve(String(item.get("icon", "")))
			if tex == null:
				tex = W31Icons.texture(String(item.get("win31Icon", item.get("icon", ""))))
			if y + 7 >= clip_top and y + 7 + 16 <= clip_bottom:
				Px.tex(self, tex, Vector2(1 + 5, y + 7), Vector2(16, 16))
			if y + 2 >= clip_top and y + 28 <= clip_bottom:
				var f := W31.font()
				f.draw(self, Vector2(1 + 5 + 16 + 5, y + 2), f.clip(String(item.name), int(inner_w) - 5 - 16 - 5 - 5, true), fg, {"bold": true})
				W31.text(self, 1 + 5 + 16 + 5, y + 15, String(d[i].group.name), sub, 10, {"line_height": 13})
		if view.get("hasMore", false):
			var y2 := 1 + d.size() * ROW_H - scroll_y
			var s2: String = view.moreText
			if y2 + 23 > clip_top and y2 < clip_bottom and y2 + 16 <= clip_bottom:
				W31.text(self, 1 + floorf((inner_w - W31.text_w(s2, 10)) / 2.0), y2 + 5, s2, W31.SHADOW, 10, {"line_height": 13})

	func _fill_clipped(r: Rect2, c: Color, top: float, bottom: float) -> void:
		var y0 := maxf(r.position.y, top)
		var y1 := minf(r.end.y, bottom)
		if y1 > y0:
			Px.fill(self, r.position.x, y0, r.size.x, y1 - y0, c)
