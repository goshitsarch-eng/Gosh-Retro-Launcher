class_name Win95TabStrip
extends Control
## Win95 property-sheet / Find tab row. Tabs: [{id, label ("&Name")}].
## style "find":  22px strip, tabs min 105 wide, 1px overlap, selected tab 22 tall / others 21 (bottom aligned).
## style "sheet": 23px strip, tabs min 68 wide, selected tab 23 tall / others 22 (top aligned).
## Signal tab_selected(id). Alt+<access key> handling is left to the owner (access_key_of()).

signal tab_selected(id: String)

var tabs: Array = []
var selected := ""
var style := "sheet"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func configure(p_tabs: Array, p_style: String, p_selected: String = "") -> void:
	tabs = p_tabs
	style = p_style
	selected = p_selected if p_selected != "" else String(p_tabs[0].id)
	size = Vector2(size.x, 22 if style == "find" else 23)
	queue_redraw()


func select(id: String) -> void:
	if id == selected:
		return
	selected = id
	queue_redraw()
	tab_selected.emit(id)


func access_key_of(id: String) -> String:
	for t in tabs:
		if t.id == id:
			return String(RetroFont.parse_access(t.label).accessKey)
	return ""


## Local rect of a tab.
func tab_rect(index: int) -> Rect2:
	var x := 5.0
	for i in tabs.size():
		var tw := Win95Draw.measure(tabs[i].label)
		var min_w := 105 if style == "find" else 68
		var pad := 14 if style == "find" else 16
		var w := float(maxi(min_w, tw + pad + 2))
		var sel: bool = tabs[i].id == selected
		var h: float
		var y := 0.0
		if style == "find":
			h = 22.0 if sel else 21.0
			y = 22.0 - h
		else:
			h = 23.0 if sel else 22.0
		if i == index:
			return Rect2(x, y, w, h)
		x += w - (1 if style == "find" else 0)
	return Rect2()


func _draw() -> void:
	# unselected first, selected on top
	for pass_selected in [false, true]:
		for i in tabs.size():
			var sel: bool = tabs[i].id == selected
			if sel != pass_selected:
				continue
			var r := tab_rect(i)
			Win95Draw.fill(self, r, Win95Draw.FACE)
			Win95Draw.border(self, r, 1, Win95Draw.LIGHT, Win95Draw.DARK, Win95Draw.FACE, Win95Draw.LIGHT)
			Win95Draw.inset_shadow(self, r.grow(-1), -1, 0, Win95Draw.SHADOW)
			var tw := Win95Draw.measure(tabs[i].label)
			var avail := int(r.size.x) - (16 if style == "find" else 18)
			Win95Draw.text(self, Vector2(r.position.x + 1 + 7 + (maxi(0, int((avail - tw) / 2.0)) if tw < avail else 0), r.position.y + 4), tabs[i].label, Win95Draw.TEXT, {"max_width": avail})
			if sel and has_focus():
				Win95Draw.dotted_rect(self, r.grow(-4), Win95Draw.TEXT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(tabs.size() - 1, -1, -1):
			if tab_rect(i).has_point(event.position):
				select(String(tabs[i].id))
				break
		accept_event()
