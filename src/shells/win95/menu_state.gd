class_name Win95MenuState
extends RefCounted
## Pure keyboard-navigation reducer shared by Start and popup menus. Port of shells/win95/menuState.ts.
## State: {level: int, indices: Array}. Result adds `action`:
## "none" | "open-child" | "activate" | "close-level" | "close-all".


static func _wrap(value: int, length: int) -> int:
	if length <= 0:
		return -1
	return (value + length) % length


static func reduce_navigation(state: Dictionary, key: String, item_counts: Array, selected_has_child: bool = false) -> Dictionary:
	var indices: Array = state.indices.duplicate()
	var level := maxi(0, mini(int(state.level), item_counts.size() - 1))
	var count: int = int(item_counts[level]) if level < item_counts.size() else 0
	while indices.size() <= level:
		indices.append(null)
	var selected: int = int(indices[level]) if indices[level] != null else (0 if count > 0 else -1)
	match key:
		"ArrowDown":
			indices[level] = ((0 if count > 0 else -1) if selected < 0 else _wrap(selected + 1, count))
			return {"level": level, "indices": indices, "action": "none"}
		"ArrowUp":
			indices[level] = (((count - 1) if count > 0 else -1) if selected < 0 else _wrap(selected - 1, count))
			return {"level": level, "indices": indices, "action": "none"}
		"Home":
			indices[level] = 0 if count > 0 else -1
			return {"level": level, "indices": indices, "action": "none"}
		"End":
			indices[level] = (count - 1) if count > 0 else -1
			return {"level": level, "indices": indices, "action": "none"}
		"ArrowRight":
			if selected_has_child:
				var next_level := mini(level + 1, item_counts.size() - 1)
				while indices.size() <= next_level:
					indices.append(null)
				indices[next_level] = 0
				return {"level": next_level, "indices": indices, "action": "open-child"}
		"ArrowLeft", "Escape":
			if level == 0:
				return {"level": level, "indices": indices, "action": "close-all"}
			indices.resize(level)
			return {"level": level - 1, "indices": indices, "action": "close-level"}
		"Enter":
			return {"level": level, "indices": indices, "action": "open-child" if selected_has_child else "activate"}
	return {"level": level, "indices": indices, "action": "none"}


## Index of the first label whose access key (&x) matches `key`, or -1.
static func mnemonic_index(labels: Array, key: String) -> int:
	var lower := key.to_lower()
	for i in labels.size():
		var label := String(labels[i])
		var marker := label.find("&")
		if marker >= 0 and marker + 1 < label.length() and label[marker + 1].to_lower() == lower:
			return i
	return -1


static func display_mnemonic(label: String) -> Dictionary:
	var marker := label.find("&")
	if marker < 0 or marker == label.length() - 1:
		return {"before": label, "mnemonic": "", "after": ""}
	return {"before": label.substr(0, marker), "mnemonic": label[marker + 1], "after": label.substr(marker + 2)}
