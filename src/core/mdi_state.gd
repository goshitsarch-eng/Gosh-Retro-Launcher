extends Node
## Autoload "MdiState". Port of src/renderer/src/store/mdiStore.ts (Win31 group windows).

signal windows_changed
signal cascade_requested
signal tile_requested
signal arrange_icons_requested

## [{id, groupId, zIndex}]
var windows: Array = []
var active_window_id: String = ""
var next_z_index := 1


func open_window(group_id: String) -> void:
	for w in windows:
		if w.groupId == group_id:
			focus_window(group_id)
			return
	windows.append({"id": group_id, "groupId": group_id, "zIndex": next_z_index})
	active_window_id = group_id
	next_z_index += 1
	windows_changed.emit()


func close_window(group_id: String) -> void:
	windows = windows.filter(func(w): return w.groupId != group_id)
	if active_window_id == group_id:
		active_window_id = windows[windows.size() - 1].groupId if windows.size() > 0 else ""
	windows_changed.emit()


func focus_window(group_id: String) -> void:
	for w in windows:
		if w.groupId == group_id:
			w["zIndex"] = next_z_index
	active_window_id = group_id
	next_z_index += 1
	windows_changed.emit()


func set_active_window(group_id: String) -> void:
	active_window_id = group_id
	windows_changed.emit()


func is_open(group_id: String) -> bool:
	for w in windows:
		if w.groupId == group_id:
			return true
	return false


func cascade_windows() -> void:
	cascade_requested.emit()


func tile_windows() -> void:
	tile_requested.emit()


func arrange_icons() -> void:
	arrange_icons_requested.emit()
