class_name Win95SelectionState
extends RefCounted
## Pure list/desktop selection logic. Port of shells/win95/selectionState.ts.
## State: {selected: Array[String], focused: String ("" none), anchor: String ("" none)}.
## Spatial items: {id, x, y, width, height}. Marquee/rect: {x, y, width, height}.


static func empty() -> Dictionary:
	return {"selected": [], "focused": "", "anchor": ""}


## modifiers: {ctrl?: bool, shift?: bool}
static func select_item(state: Dictionary, id: String, ordered_ids: Array, modifiers: Dictionary = {}) -> Dictionary:
	var ctrl: bool = modifiers.get("ctrl", false)
	var shift: bool = modifiers.get("shift", false)
	if shift and String(state.anchor) != "":
		var from := ordered_ids.find(state.anchor)
		var to := ordered_ids.find(id)
		if from >= 0 and to >= 0:
			var range_ids: Array = ordered_ids.slice(mini(from, to), maxi(from, to) + 1)
			var selected: Array = range_ids
			if ctrl:
				selected = state.selected.duplicate()
				for r in range_ids:
					if not selected.has(r):
						selected.append(r)
			return {"selected": selected, "focused": id, "anchor": state.anchor}
	if ctrl:
		var sel: Array = state.selected.duplicate()
		if sel.has(id):
			sel.erase(id)
		else:
			sel.append(id)
		return {"selected": sel, "focused": id, "anchor": id}
	return {"selected": [id], "focused": id, "anchor": id}


static func select_all(ids: Array) -> Dictionary:
	var first: String = String(ids[0]) if ids.size() > 0 else ""
	return {"selected": ids.duplicate(), "focused": first, "anchor": first}


## direction: "left" | "right" | "up" | "down". Returns the neighbouring id ("" when empty).
static func find_directional_item(items: Array, current_id: String, direction: String) -> String:
	if items.is_empty():
		return ""
	var current: Dictionary = items[0]
	for it in items:
		if it.id == current_id:
			current = it
			break
	var cx: float = float(current.x) + float(current.width) / 2.0
	var cy: float = float(current.y) + float(current.height) / 2.0
	var horizontal := direction == "left" or direction == "right"
	var candidates: Array = []
	for it in items:
		if it.id == current.id:
			continue
		var x: float = float(it.x) + float(it.width) / 2.0
		var y: float = float(it.y) + float(it.height) / 2.0
		var ok := false
		match direction:
			"left":
				ok = x < cx
			"right":
				ok = x > cx
			"up":
				ok = y < cy
			_:
				ok = y > cy
		if ok:
			var primary := absf(x - cx) if horizontal else absf(y - cy)
			var secondary := absf(y - cy) if horizontal else absf(x - cx)
			candidates.append({"id": it.id, "score": primary + secondary * 2.0, "order": candidates.size()})
	if candidates.is_empty():
		return String(current.id)
	# stable sort by score (JS Array.sort is stable)
	var best: Dictionary = candidates[0]
	for c in candidates:
		if c.score < best.score:
			best = c
	return String(best.id)


static func normalize_marquee(start: Vector2, end: Vector2) -> Dictionary:
	return {
		"x": minf(start.x, end.x),
		"y": minf(start.y, end.y),
		"width": absf(end.x - start.x),
		"height": absf(end.y - start.y),
	}


static func items_in_marquee(items: Array, marquee: Dictionary) -> Array:
	var out: Array = []
	for it in items:
		if float(it.x) < float(marquee.x) + float(marquee.width) and float(it.x) + float(it.width) > float(marquee.x) \
				and float(it.y) < float(marquee.y) + float(marquee.height) and float(it.y) + float(it.height) > float(marquee.y):
			out.append(it.id)
	return out


## Snaps a position to the icon grid. position/cell/inset: Vector2 (cell = width,height).
static func snap_position(position: Vector2, cell: Vector2, inset: Vector2 = Vector2(4, 4)) -> Vector2:
	return Vector2(
		inset.x + _js_round((position.x - inset.x) / cell.x) * cell.x,
		inset.y + _js_round((position.y - inset.y) / cell.y) * cell.y)


static func _js_round(v: float) -> float:
	return floorf(v + 0.5)


## Type-to-select: first label (cyclic, after `after_id`) starting with prefix. labels: [{id, label}].
static func find_type_match(labels: Array, prefix: String, after_id: String) -> String:
	if prefix.is_empty() or labels.is_empty():
		return ""
	var lower := prefix.to_lower()
	var found := -1
	for i in labels.size():
		if labels[i].id == after_id:
			found = i
			break
	var start := maxi(0, found + 1)
	for offset in labels.size():
		var item: Dictionary = labels[(start + offset) % labels.size()]
		if String(item.label).to_lower().begins_with(lower):
			return String(item.id)
	return ""
