class_name MacWindowStore
extends RefCounted
## Pure state of the Mac shell's windows: z-order (last = front), active window, geometry, shade (collapse)
## and zoom. Keys: "computer" (Launcher HD), "g:<groupId>" (folder window) and "find". All state is session
## only (the persisted schema has no Mac window fields). `changed` fires after every mutation.

signal changed

var windows: Array = []   ## bottom -> top; Dictionaries {key, rect: Rect2, shaded, zoomed, restore: Rect2, view, scroll, sel}
var open_counter := 0


func find(key: String) -> Dictionary:
	for w in windows:
		if w.key == key:
			return w
	return {}


func has(key: String) -> bool:
	return not find(key).is_empty()


func active_key() -> String:
	return String(windows[windows.size() - 1].key) if windows.size() > 0 else ""


func is_active(key: String) -> bool:
	return key != "" and active_key() == key


## Opens (or raises) a window; `rect` is its frame when it is created.
func open(key: String, rect: Rect2) -> Dictionary:
	var w := find(key)
	if w.is_empty():
		w = {"key": key, "rect": rect, "shaded": false, "zoomed": false, "restore": Rect2(), "view": "large", "scroll": 0, "sel": ""}
		windows.append(w)
		open_counter += 1
		changed.emit()
	else:
		raise(key)
	return w


func raise(key: String) -> void:
	var w := find(key)
	if w.is_empty() or windows[windows.size() - 1] == w:
		return
	windows.erase(w)
	windows.append(w)
	changed.emit()


func close(key: String) -> void:
	var w := find(key)
	if w.is_empty():
		return
	windows.erase(w)
	changed.emit()


func close_where(pred: Callable) -> void:
	var before := windows.size()
	windows = windows.filter(func(w): return not pred.call(w))
	if windows.size() != before:
		changed.emit()


func reset() -> void:
	windows.clear()
	open_counter = 0
	changed.emit()


func move_to(key: String, pos: Vector2) -> void:
	var w := find(key)
	if w.is_empty():
		return
	w.rect = Rect2(pos.floor(), w.rect.size)
	changed.emit()


## Resizes a window's frame (grow box); an unzoom happens implicitly.
func resize_to(key: String, size: Vector2, max_size: Vector2 = Vector2(100000, 100000)) -> void:
	var w := find(key)
	if w.is_empty():
		return
	var s := Vector2(clampf(size.x, MacGeometry.MIN_W, max_size.x), clampf(size.y, MacGeometry.MIN_H, max_size.y)).floor()
	w.rect = Rect2(w.rect.position, s)
	w.zoomed = false
	changed.emit()


func toggle_shade(key: String) -> void:
	var w := find(key)
	if w.is_empty():
		return
	w.shaded = not w.shaded
	changed.emit()


## Zoom box: toggles between the user's frame and the full desktop.
func toggle_zoom(key: String, desk: Vector2) -> void:
	var w := find(key)
	if w.is_empty():
		return
	if w.zoomed:
		if w.restore.size.x > 0:
			w.rect = w.restore
		w.zoomed = false
	else:
		w.restore = w.rect
		w.rect = MacGeometry.zoom_rect(desk)
		w.zoomed = true
		w.shaded = false
	changed.emit()


func set_view(key: String, view: String) -> void:
	var w := find(key)
	if not w.is_empty() and ["large", "details"].has(view):
		w.view = view
		w.scroll = 0
		changed.emit()


func set_selection(key: String, id: String) -> void:
	var w := find(key)
	if not w.is_empty():
		w.sel = id
		changed.emit()


func set_scroll(key: String, offset: int) -> void:
	var w := find(key)
	if not w.is_empty():
		w.scroll = maxi(0, offset)
		changed.emit()


## Re-flows every window after the desktop resized (keeps title bars reachable, refits zoomed frames).
func fit(desk: Vector2) -> void:
	var dirty := false
	for w in windows:
		var r: Rect2 = w.rect
		if w.zoomed:
			r = MacGeometry.zoom_rect(desk)
		else:
			r = Rect2(MacGeometry.clamp_position(r.position, r.size, desk), r.size)
		if r != w.rect:
			w.rect = r
			dirty = true
	if dirty:
		changed.emit()


## Window keys of folder windows for a group id list that no longer exists.
func orphan_group_windows(group_ids: Array) -> Array:
	var out := []
	for w in windows:
		if String(w.key).begins_with("g:") and not group_ids.has(String(w.key).substr(2)):
			out.append(w.key)
	return out


## Arrange > Clean Up: stacks windows in a cascade.
func cascade(desk: Vector2) -> void:
	for i in windows.size():
		var w: Dictionary = windows[i]
		var r := MacGeometry.cascade_rect(i, desk, w.rect.size)
		w.rect = r
		w.zoomed = false
	changed.emit()
