class_name MacMenuBar
extends Control
## The Mac menu bar: launcher logo menu, File/Edit/View/Special/Help, clock, and the Program Manager
## application menu at the right end (Launcher Tools… + window list). Drop-downs are MacPopupMenu overlays
## added to `popup_host`; hovering another title while a menu is open switches to it.

signal command(id: String)

var ctx_provider: Callable          ## () -> Dictionary for MacMenuModel.menu_bar()
var app_items_provider: Callable    ## () -> Array of app-menu entries
var popup_host: Control
var clock_text := ""
var open_id := ""                   ## "" | menu id | "app"

var _menus: Array = []
var _hit: Array = []                ## [{id, rect}]
var _popup: MacPopupMenu
var _clock_rect := Rect2()
var _app_label := true
var _clock_timer: Timer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("pm_auto")
	_clock_timer = Timer.new()
	_clock_timer.wait_time = 15.0
	_clock_timer.autostart = true
	_clock_timer.timeout.connect(update_clock)
	add_child(_clock_timer)
	resized.connect(queue_redraw)


func _ready() -> void:
	update_clock()


func update_clock() -> void:
	if Engine.has_meta("pm_capture_clock"):
		clock_text = String(Engine.get_meta("pm_capture_clock"))  # deterministic visual captures
		queue_redraw()
		return
	var d := Time.get_datetime_dict_from_system()
	var h: int = d.hour % 12
	if h == 0:
		h = 12
	var t := "%d:%02d %s" % [h, d.minute, "PM" if d.hour >= 12 else "AM"]
	if t != clock_text:
		clock_text = t
		queue_redraw()


func _build_hits() -> void:
	_menus = MacMenuModel.menu_bar(ctx_provider.call() if ctx_provider.is_valid() else {})
	_hit.clear()
	var x := 12
	for m in _menus:
		var w := 10 + (16 if m.id == "logo" else MacDraw.measure(String(m.label), true)) + 10
		_hit.append({"id": m.id, "rect": Rect2(x, 0, w, size.y - 1)})
		x += w
	var app_w := 10 + 16 + 6 + MacDraw.measure("Program Manager", true) + 10
	var clock_w := MacDraw.measure(clock_text)
	_app_label = x + clock_w + 16 + app_w + 6 <= size.x
	if not _app_label:
		app_w = 36
	var app_x := int(size.x) - 6 - app_w
	_clock_rect = Rect2(app_x - clock_w - 10, 0, clock_w, size.y - 1)
	if _clock_rect.position.x < x:
		_clock_rect = Rect2()
	_hit.append({"id": "app", "rect": Rect2(app_x, 0, app_w, size.y - 1)})


func _draw() -> void:
	_build_hits()
	var h := int(size.y)
	var top := MacTheme.b("f6f6f6")
	var bot := MacTheme.b("dddddd")
	for y in h - 1:
		draw_rect(Rect2(0, y, size.x, 1), top.lerp(bot, float(y) / maxf(1.0, h - 2.0)))
	draw_rect(Rect2(0, h - 1, size.x, 1), MacTheme.b("444444"))
	_corner(0, false)
	_corner(int(size.x) - 8, true)
	var logo := MacIconCatalog.logo("small")
	for i in _hit.size():
		var hit: Dictionary = _hit[i]
		var rect: Rect2 = hit.rect
		var open: bool = open_id == hit.id
		if open:
			draw_rect(rect, MacTheme.b("33339a"))
		var fg := MacTheme.t("ffffff") if open else MacTheme.t("000000")
		if hit.id == "app":
			draw_rect(Rect2(rect.position.x, 0, 1, h - 1), MacTheme.b("999999"))
			draw_texture_rect(logo, Rect2(rect.position.x + 10, floorf((h - 16) / 2.0), 16, 16), false)
			if _app_label:
				MacDraw.text_centered_y(self, rect.position.x + 10 + 16 + 6, 0, h - 1, "Program Manager", fg, true)
		elif hit.id == "logo":
			draw_texture_rect(logo, Rect2(rect.position.x + 10, floorf((h - 16) / 2.0), 16, 16), false)
		else:
			MacDraw.text_centered_y(self, rect.position.x + 10, 0, h - 1, String(_menus[i].label), fg, true)
	if _clock_rect.has_area():
		MacDraw.text_centered_y(self, _clock_rect.position.x, 0, h - 1, clock_text, MacTheme.t("000000"))


## The black rounded screen corners (design: 8px radial-gradient cut-outs).
func _corner(x: int, right: bool) -> void:
	for y in 8:
		for cx in 8:
			var dx := (cx + 0.5) - (0.0 if right else 8.0)
			var dy := (y + 0.5) - 8.0
			if dx * dx + dy * dy > 7.5 * 7.5:
				draw_rect(Rect2(x + cx, y, 1, 1), Color.BLACK)


func auto_lookup(id: String) -> Variant:
	if not is_visible_in_tree():
		return null
	if id == "mac.clock":
		return Rect2(global_position + _clock_rect.position, _clock_rect.size)
	if not id.begins_with("mac.menu:"):
		return null
	var want := id.substr("mac.menu:".length())
	for i in _hit.size():
		var name: String = "app" if _hit[i].id == "app" else String(_menus[i].label if _menus[i].label != "" else "logo")
		if name.to_lower() == want.to_lower():
			return Rect2(global_position + _hit[i].rect.position, _hit[i].rect.size)
	return null


func _input(event: InputEvent) -> void:
	# hovering another title while a menu is open switches menus (motion may bypass the GUI pass)
	if event is InputEventMouseMotion and open_id != "":
		var id := _id_at((event as InputEventMouseMotion).position - global_position)
		if id != "" and id != open_id:
			open_menu(id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id := _id_at((event as InputEventMouseButton).position)
		if id == "":
			close_menu()
			return
		if open_id == id:
			close_menu()
		else:
			open_menu(id)
		accept_event()


func _id_at(p: Vector2) -> String:
	for h in _hit:
		if h.rect.has_point(p):
			return String(h.id)
	return ""


func open_menu(id: String) -> void:
	close_menu()
	_build_hits()
	var rect := Rect2()
	var items: Array = []
	var right := -1.0
	for i in _hit.size():
		if _hit[i].id == id:
			rect = _hit[i].rect
			if id == "app":
				items = app_items_provider.call() if app_items_provider.is_valid() else []
				right = rect.end.x
			else:
				items = _menus[i].items
	if items.is_empty() or popup_host == null:
		return
	open_id = id
	var at := Vector2(rect.position.x - 1, size.y)
	_popup = MacPopupMenu.open(popup_host, items, at, {"min_width": 240 if id == "app" else 220, "align_right": right})
	_popup.chosen.connect(func(cmd: String): command.emit(cmd))
	_popup.closed.connect(_on_popup_closed.bind(_popup))
	queue_redraw()


func _on_popup_closed(which: MacPopupMenu) -> void:
	if _popup == which:
		_popup = null
		open_id = ""
		queue_redraw()


func close_menu() -> void:
	if _popup != null and is_instance_valid(_popup):
		var p := _popup
		_popup = null
		p.close()
	open_id = ""
	queue_redraw()


func is_open() -> bool:
	return open_id != ""
