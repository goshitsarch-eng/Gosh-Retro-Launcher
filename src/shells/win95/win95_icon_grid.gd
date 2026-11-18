class_name Win95IconGrid
extends Control
## The icon list of the Win95 Change Icon box: a sunken white field of 32px icons in ROWS rows,
## filled column by column (a multi-column list box). The selected icon sits on a navy cell, with
## the dotted focus rectangle while the list has the focus. Click selects, double-click emits
## `activated`; Up/Down/Left/Right/Home/End move the selection. Cell maths: cell_rect / index_at.

signal selection_changed(id: String)
signal activated(id: String)

const CELL := Vector2(40, 38)
const ROWS := 3

var icons: Array = []:
	set(v):
		icons = v
		selected = clampi(selected, -1, icons.size() - 1)
		queue_redraw()
var selected := 0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(320, CELL.y * ROWS + 4)
	A11y.track(self)


func select_icon(id: String) -> void:
	var i := icons.find(id)
	selected = i if i >= 0 else 0
	queue_redraw()


func selected_icon() -> String:
	return String(icons[selected]) if selected >= 0 and selected < icons.size() else ""


## Cell `index` in the field (column-major: index / ROWS = column).
static func cell_rect(index: int) -> Rect2:
	return Rect2(Vector2(2 + (index / ROWS) * CELL.x, 2 + (index % ROWS) * CELL.y), CELL)


## The icon index under `p` (field coordinates), or -1.
static func index_at(p: Vector2, count: int) -> int:
	if p.x < 2 or p.y < 2:
		return -1
	var col := int((p.x - 2) / CELL.x)
	var row := int((p.y - 2) / CELL.y)
	if row >= ROWS:
		return -1
	var i := col * ROWS + row
	return i if i < count else -1


## The index a navigation key moves to from `index` (Up/Down: one row, Left/Right: one column).
static func next_index(index: int, key: String, count: int) -> int:
	if count <= 0:
		return -1
	match key:
		"ArrowUp": return maxi(0, index - 1)
		"ArrowDown": return mini(count - 1, index + 1)
		"ArrowLeft": return index - ROWS if index - ROWS >= 0 else index
		"ArrowRight": return index + ROWS if index + ROWS < count else index
		"Home": return 0
		"End": return count - 1
	return index


func _draw() -> void:
	Win95Draw.sunken(self, Rect2(Vector2.ZERO, size), Win95Draw.WINDOW)
	for i in icons.size():
		var c := cell_rect(i)
		if c.position.x + 4 > size.x - 2:
			break
		var ipos := c.position + ((CELL - Vector2(32, 32)) / 2.0).floor()
		var tex := Win95IconCatalog.texture(String(icons[i]), "large")
		if i == selected:
			Win95Draw.fill(self, Rect2(ipos - Vector2(2, 2), Vector2(36, 36)), Win95Draw.SELECTED)
		Win95Draw.icon(self, tex, ipos)
		if i == selected and has_focus():
			Win95Draw.dotted_rect(self, Rect2(ipos - Vector2(2, 2), Vector2(36, 36)), Win95Draw.LIGHT)


func _select(i: int) -> void:
	if i < 0 or i == selected:
		return
	selected = i
	selection_changed.emit(selected_icon())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		var i := index_at(event.position, icons.size())
		if i >= 0:
			_select(i)
			if event.double_click:
				activated.emit(selected_icon())
		accept_event()
	elif event is InputEventKey and event.pressed:
		var key := Win95InputController.key_name(event)
		if key in ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Home", "End"]:
			_select(next_index(selected, key, icons.size()))
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		A11y.apply_node(self, {"role": DisplayServer.ROLE_LIST, "name": "Current icon: " + selected_icon().replace("-", " ")})


## Automation: w95.change-icon.item:<icon id>.
func auto_lookup(id: String) -> Variant:
	if id.begins_with("w95.change-icon.item:"):
		var i := icons.find(id.substr("w95.change-icon.item:".length()))
		if i >= 0:
			return Rect2(global_position + cell_rect(i).position, CELL)
	return null
