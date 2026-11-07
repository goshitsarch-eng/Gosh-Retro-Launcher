class_name Win95WindowStore
extends RefCounted
## Win95 primary-window manager state (z-order, active window, one-shot Move/Size requests).
## Port of shells/win95/windowStore.ts. Group geometry/minimized state lives in the ProgramStore
## (per-shell window state, "win95"); My Computer and Find keep theirs here ("system" fields).
##
## Entries are Dictionaries: {id, kind: "my-computer"|"group"|"find", groupId?, zIndex,
## systemBounds?, systemRestoreBounds?, systemMinimized?, systemMaximized?}.
## active_window_id is "" when the desktop is active. `changed` fires after every mutation.

signal changed

const MY_COMPUTER_DEFAULT := {"x": 42, "y": 34, "width": 430, "height": 300}
const FIND_DEFAULT := {"x": 96, "y": 58, "width": 439, "height": 237}

var windows: Array = []
var active_window_id: String = ""
var next_z_index := 1
## {id, command: "move"|"size", nonce} or {}
var requested_command: Dictionary = {}

## ProgramStore-like object (groups array + update_group_window_state). Injected for tests.
var store: Object


func _init(p_store: Object = null) -> void:
	store = p_store if p_store != null else Engine.get_main_loop().root.get_node("ProgramStore")


# ------------------------------------------------------------------ queries

func find_entry(id: String) -> Dictionary:
	for e in windows:
		if e.id == id:
			return e
	return {}


func find_group(group_id: String) -> Dictionary:
	for g in store.groups:
		if g.id == group_id:
			return g
	return {}


func group_state(group_id: String) -> Dictionary:
	var g := find_group(group_id)
	if g.is_empty():
		return {}
	return Types.get_group_window_state(g, "win95")


func entry_is_minimized(entry: Dictionary) -> bool:
	if entry.kind == "group" and entry.get("groupId", "") != "":
		var g := find_group(entry.groupId)
		if g.is_empty():
			return true
		return bool(Types.get_group_window_state(g, "win95").get("minimized", false))
	return bool(entry.get("systemMinimized", false))


func entry_is_maximized(entry: Dictionary) -> bool:
	if entry.kind == "group" and entry.get("groupId", "") != "":
		return bool(group_state(entry.groupId).get("maximized", false))
	return bool(entry.get("systemMaximized", false))


func _top_visible(excluded_id: String = "") -> String:
	var best: Dictionary = {}
	for e in windows:
		if e.id == excluded_id or entry_is_minimized(e):
			continue
		if best.is_empty() or e.zIndex > best.zIndex:
			best = e
	return String(best.id) if not best.is_empty() else ""


func _bring_to_front(id: String, z: int) -> void:
	for e in windows:
		if e.id == id:
			e["zIndex"] = z


# ---------------------------------------------------------------- mutations

func open_my_computer() -> void:
	var existing := find_entry("my-computer")
	if not existing.is_empty():
		existing["systemMinimized"] = false
		_bring_to_front("my-computer", next_z_index)
		active_window_id = "my-computer"
		next_z_index += 1
		changed.emit()
		return
	windows.append({
		"id": "my-computer", "kind": "my-computer", "zIndex": next_z_index,
		"systemBounds": MY_COMPUTER_DEFAULT.duplicate(), "systemMinimized": false, "systemMaximized": false,
	})
	active_window_id = "my-computer"
	next_z_index += 1
	changed.emit()


func open_find() -> void:
	var existing := find_entry("find")
	if not existing.is_empty():
		existing["systemMinimized"] = false
		_bring_to_front("find", next_z_index)
		active_window_id = "find"
		next_z_index += 1
		changed.emit()
		return
	windows.append({
		"id": "find", "kind": "find", "zIndex": next_z_index,
		"systemBounds": FIND_DEFAULT.duplicate(), "systemMinimized": false, "systemMaximized": false,
	})
	active_window_id = "find"
	next_z_index += 1
	changed.emit()


func open_group(group_id: String) -> void:
	store.update_group_window_state(group_id, {"minimized": false}, "win95")
	var id := "group:" + group_id
	if not find_entry(id).is_empty():
		_bring_to_front(id, next_z_index)
		active_window_id = id
		next_z_index += 1
		changed.emit()
		return
	windows.append({"id": id, "kind": "group", "groupId": group_id, "zIndex": next_z_index})
	active_window_id = id
	next_z_index += 1
	changed.emit()


func focus_window(id: String) -> void:
	var target := find_entry(id)
	if target.is_empty() or entry_is_minimized(target):
		return
	_bring_to_front(id, next_z_index)
	active_window_id = id
	next_z_index += 1
	changed.emit()


func close_window(id: String) -> void:
	windows = windows.filter(func(e): return e.id != id)
	if active_window_id == id:
		active_window_id = _top_visible()
	changed.emit()


func deactivate_window(id: String) -> void:
	if active_window_id == id:
		active_window_id = _top_visible(id)
	changed.emit()


func activate_desktop() -> void:
	active_window_id = ""
	changed.emit()


func update_system_window(id: String, updates: Dictionary) -> void:
	for e in windows:
		if e.id == id:
			for k in updates:
				e[k] = updates[k]
	changed.emit()


func request_window_command(id: String, command: String) -> void:
	requested_command = {"id": id, "command": command, "nonce": int(requested_command.get("nonce", 0)) + 1}
	changed.emit()


func clear_window_command(nonce: int) -> void:
	if int(requested_command.get("nonce", -1)) == nonce:
		requested_command = {}
		changed.emit()


func reset() -> void:
	windows = []
	active_window_id = ""
	next_z_index = 1
	requested_command = {}
	changed.emit()


# ------------------------------------------------------------------ window operations (chrome + taskbar)

static func _is_group_entry(entry: Dictionary) -> bool:
	return entry.kind == "group" and String(entry.get("groupId", "")) != ""


## Normalised state of an entry: {minimized, maximized, x, y, width, height, restoreX/Y/Width/Height (or absent)}.
func entry_state(entry: Dictionary) -> Dictionary:
	if _is_group_entry(entry):
		var s := group_state(entry.groupId)
		return s.duplicate() if not s.is_empty() else {"minimized": true, "maximized": false, "x": 0, "y": 0, "width": 300, "height": 200}
	var b: Dictionary = entry.get("systemBounds", MY_COMPUTER_DEFAULT)
	var out := {
		"minimized": bool(entry.get("systemMinimized", false)),
		"maximized": bool(entry.get("systemMaximized", false)),
		"x": b.x, "y": b.y, "width": b.width, "height": b.height,
	}
	var rb: Dictionary = entry.get("systemRestoreBounds", {})
	if not rb.is_empty():
		out["restoreX"] = rb.x
		out["restoreY"] = rb.y
		out["restoreWidth"] = rb.width
		out["restoreHeight"] = rb.height
	return out


## Persisted (unconstrained) restored rectangle {x,y,width,height}.
func entry_rect(entry: Dictionary) -> Dictionary:
	var s := entry_state(entry)
	return Win95Geometry.rect(s.x, s.y, s.width, s.height)


func minimize_entry(entry: Dictionary) -> void:
	set_minimized(entry, true)
	deactivate_window(entry.id)


func restore_entry(entry: Dictionary) -> void:
	var s := entry_state(entry)
	if _is_group_entry(entry):
		var updates := {"minimized": false}
		if s.maximized:
			updates = {
				"x": s.get("restoreX", s.x), "y": s.get("restoreY", s.y),
				"width": s.get("restoreWidth", s.width), "height": s.get("restoreHeight", s.height),
				"maximized": false, "minimized": false,
			}
		store.update_group_window_state(entry.groupId, updates, "win95")
		changed.emit()
	else:
		var updates := {"systemMinimized": false, "systemMaximized": false}
		if s.maximized and entry.has("systemRestoreBounds"):
			updates["systemBounds"] = entry.systemRestoreBounds
		update_system_window(entry.id, updates)
	focus_window(entry.id)


func maximize_entry(entry: Dictionary) -> void:
	var s := entry_state(entry)
	if s.maximized:
		restore_entry(entry)
		return
	if _is_group_entry(entry):
		store.update_group_window_state(entry.groupId, {
			"restoreX": s.x, "restoreY": s.y, "restoreWidth": s.width, "restoreHeight": s.height,
			"minimized": false, "maximized": true,
		}, "win95")
		changed.emit()
	else:
		update_system_window(entry.id, {
			"systemRestoreBounds": entry.get("systemBounds", MY_COMPUTER_DEFAULT).duplicate(),
			"systemMinimized": false, "systemMaximized": true,
		})
	focus_window(entry.id)


func close_entry(entry: Dictionary) -> void:
	if _is_group_entry(entry):
		store.update_group_window_state(entry.groupId, {"minimized": false}, "win95")
	close_window(entry.id)


## Persists a new restored rectangle without touching minimized/maximized.
func set_rect(entry: Dictionary, r: Dictionary) -> void:
	if _is_group_entry(entry):
		store.update_group_window_state(entry.groupId, {"x": r.x, "y": r.y, "width": r.width, "height": r.height}, "win95")
		changed.emit()
	else:
		update_system_window(entry.id, {"systemBounds": Win95Geometry.rect(r.x, r.y, r.width, r.height)})


## Persists a rectangle and un-minimizes/un-maximizes (Cascade/Tile).
func apply_rect(entry: Dictionary, r: Dictionary) -> void:
	if _is_group_entry(entry):
		store.update_group_window_state(entry.groupId, {"x": r.x, "y": r.y, "width": r.width, "height": r.height, "minimized": false, "maximized": false}, "win95")
		changed.emit()
	else:
		update_system_window(entry.id, {"systemBounds": Win95Geometry.rect(r.x, r.y, r.width, r.height), "systemMinimized": false, "systemMaximized": false})


# ------------------------------------------------------------------ helpers shared by chrome/taskbar

## Windows in ascending z-order (taskbar order is insertion order = `windows`).
func by_z() -> Array:
	var out := windows.duplicate()
	out.sort_custom(func(a, b): return a.zIndex < b.zIndex)
	return out


## Restores a minimized window (without focusing).
func unminimize(entry: Dictionary) -> void:
	if entry.kind == "group" and entry.get("groupId", "") != "":
		store.update_group_window_state(entry.groupId, {"minimized": false}, "win95")
	else:
		update_system_window(entry.id, {"systemMinimized": false})


func set_minimized(entry: Dictionary, minimized: bool) -> void:
	if entry.kind == "group" and entry.get("groupId", "") != "":
		store.update_group_window_state(entry.groupId, {"minimized": minimized}, "win95")
		changed.emit()
	else:
		update_system_window(entry.id, {"systemMinimized": minimized})
