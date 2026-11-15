class_name BeWindowStore
extends RefCounted
## Be window manager state (z-order, hidden, zoomed, per-window view). Session-only: geometry is not persisted.
## Entries: {key, x, y, w, h, hidden, zoomed, view}; key is "computer", "g:<groupId>" or "find".
## Port of openWin/raise/closeWin/minWin and the zoom toggle from the design. `changed` fires after every mutation.

signal changed

const COMPUTER := "computer"
const FIND := "find"
const VIEWS := ["large", "small", "details"]

var entries: Dictionary = {}  ## key -> entry
var order: Array = []         ## opening order (Deskbar task list)
var z: Array = []             ## back-to-front
var view_size := Vector2(640, 480)


static func group_key(group_id: String) -> String:
	return "g:" + group_id


static func is_group_key(key: String) -> bool:
	return key.begins_with("g:")


static func group_id_of(key: String) -> String:
	return key.substr(2) if is_group_key(key) else ""


func has(key: String) -> bool:
	return entries.has(key)


func get_entry(key: String) -> Dictionary:
	return entries.get(key, {})


func rect_of(key: String) -> Rect2:
	var e: Dictionary = entries.get(key, {})
	if e.is_empty():
		return Rect2()
	if e.zoomed:
		return Rect2(0, 0, view_size.x, view_size.y)
	return Rect2(e.x, e.y, e.w, e.h)


func open(key: String) -> void:
	if not entries.has(key):
		var r := BeGeometry.default_rect(key, order.size(), view_size)
		entries[key] = {"key": key, "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y,
			"hidden": false, "zoomed": false, "view": "large"}
		order.append(key)
	entries[key].hidden = false
	z.erase(key)
	z.append(key)
	changed.emit()


func raise(key: String) -> void:
	if not entries.has(key):
		return
	if z.back() == key and not entries[key].hidden:
		return
	entries[key].hidden = false
	z.erase(key)
	z.append(key)
	changed.emit()


func close(key: String) -> void:
	if not entries.has(key):
		return
	entries.erase(key)
	order.erase(key)
	z.erase(key)
	changed.emit()


func hide(key: String) -> void:
	if entries.has(key):
		entries[key].hidden = true
		changed.emit()


func toggle_zoom(key: String) -> void:
	if entries.has(key):
		entries[key].zoomed = not entries[key].zoomed
		raise(key)
		changed.emit()


func move_to(key: String, pos: Vector2) -> void:
	var e: Dictionary = entries.get(key, {})
	if e.is_empty():
		return
	var p := BeGeometry.clamp_position(pos, Vector2(e.w, e.h), view_size)
	e.x = p.x
	e.y = p.y
	changed.emit()


func resize_to(key: String, size: Vector2) -> void:
	var e: Dictionary = entries.get(key, {})
	if e.is_empty():
		return
	var s := BeGeometry.clamp_size(key, size)
	e.w = s.x
	e.h = s.y
	changed.emit()


func set_view(key: String, view: String) -> void:
	if entries.has(key) and VIEWS.has(view):
		entries[key].view = view
		changed.emit()


func close_all() -> void:
	entries.clear()
	order.clear()
	z.clear()
	changed.emit()


## Topmost visible window key, "" when none (the design's active95).
func active() -> String:
	for i in range(z.size() - 1, -1, -1):
		if not entries[z[i]].hidden:
			return z[i]
	return ""


func z_index(key: String) -> int:
	return z.find(key)


## Drops group windows whose group no longer exists.
func sync_groups(valid_group_ids: Array) -> void:
	var gone := []
	for key in order:
		if is_group_key(key) and not valid_group_ids.has(group_id_of(key)):
			gone.append(key)
	for key in gone:
		entries.erase(key)
		order.erase(key)
		z.erase(key)
	if not gone.is_empty():
		changed.emit()


## Deskbar task click: the active window hides, anything else is raised.
func task_click(key: String) -> void:
	if active() == key:
		hide(key)
	else:
		raise(key)
