class_name Win95TaskbarState
extends RefCounted
## Pure taskbar button state/click mapping. Port of shells/win95/taskbarState.ts.


## "active" | "inactive" | "minimized"
static func button_state(window_id: String, active_window_id: String, minimized: bool) -> String:
	if minimized:
		return "minimized"
	return "active" if window_id == active_window_id else "inactive"


## "minimize" | "restore-focus" | "focus"
static func click_action(window_id: String, active_window_id: String, minimized: bool) -> String:
	if minimized:
		return "restore-focus"
	return "minimize" if window_id == active_window_id else "focus"


# ------------------------------------------------------------- windows and sticky notes
# The taskbar shows one button per primary window and one per open sticky note. Task ids are the
# window entry ids ("group:<id>", "my-computer", "find") and NOTE_PREFIX + <note item id>.

const NOTE_PREFIX := "note:"


static func note_task_id(item_id: String) -> String:
	return NOTE_PREFIX + item_id


static func is_note_task(task_id: String) -> bool:
	return task_id.begins_with(NOTE_PREFIX)


static func note_item_id(task_id: String) -> String:
	return task_id.substr(NOTE_PREFIX.length()) if is_note_task(task_id) else ""


## Taskbar order: the ids of `previous` that are still in `current` keep their places (a button
## never jumps when another one is activated), and new ids go at the end in `current`'s order,
## the way Win95 adds a button for each window as it opens.
static func merge_order(previous: Array, current: Array) -> Array:
	var present := {}
	for id in current:
		present[id] = true
	var out: Array = []
	var seen := {}
	for id in previous:
		if present.has(id) and not seen.has(id):
			out.append(id)
			seen[id] = true
	for id in current:
		if not seen.has(id):
			out.append(id)
			seen[id] = true
	return out


## The taskbar buttons in `order` (see merge_order):
## [{id, kind: "window"|"note", key (window entry id or note item id), state}].
## `windows`: [{id, minimized}] in the window store's order; `note_ids`: the open notes' item ids.
## `active_note_id` is the note that is the active window ("" when a window or the desktop is).
## Only the active window or note is "active"; a note is never "minimized".
static func task_list(windows: Array, note_ids: Array, order: Array, active_window_id: String, active_note_id: String) -> Array:
	var by_id := {}
	var current: Array = []
	for w in windows:
		var id := String(w.id)
		var active_id := "" if active_note_id != "" else active_window_id
		by_id[id] = {"id": id, "kind": "window", "key": id, "state": button_state(id, active_id, bool(w.get("minimized", false)))}
		current.append(id)
	for nid in note_ids:
		var id := note_task_id(String(nid))
		by_id[id] = {"id": id, "kind": "note", "key": String(nid), "state": "active" if String(nid) == active_note_id else "inactive"}
		current.append(id)
	var out: Array = []
	for id in merge_order(order, current):
		out.append(by_id[id])
	return out


## What a click on a note's button does: "focus" brings it to the front with the keyboard;
## "keep" (it is already the active window) leaves it as it is. A note cannot be minimized, so
## this is what Win95 does for the active button of a window that has no Minimize box.
static func note_click_action(active: bool) -> String:
	return "keep" if active else "focus"


## Alt+Tab: the task after (or with `reverse` before) `active_id` in `stack`, the bottom-to-top
## z-order of everything that can be switched to (the windows, then the notes, which sit above
## every window). With nothing active it starts at the bottom (the top for reverse).
static func cycle_target(stack: Array, active_id: String, reverse: bool) -> String:
	if stack.is_empty():
		return ""
	var active := stack.find(active_id)
	if active < 0:
		return String(stack[stack.size() - 1 if reverse else 0])
	var delta := -1 if reverse else 1
	return String(stack[(active + delta + stack.size()) % stack.size()])


## The recently-active list with `task_id` moved to the front ("" leaves it as it is). Kept short.
static func touch_recent(recent: Array, task_id: String) -> Array:
	if task_id == "" or (not recent.is_empty() and recent[0] == task_id):
		return recent
	var out: Array = [task_id]
	for id in recent:
		if id != task_id and out.size() < 32:
			out.append(id)
	return out


## The task that takes over when the active one closes: the most recently active one that is
## still open (in `open_ids`), or "" (then the window store picks the topmost window).
static func next_active(recent: Array, open_ids: Array) -> String:
	for id in recent:
		if open_ids.has(id):
			return String(id)
	return ""


## The text of the Delete question for a note (its name with "&" kept literal).
static func delete_note_message(name: String) -> String:
	return "Are you sure you want to delete '%s'?" % name.replace("&", "&&")


## `text` cut to `max_width` pixels with "..." the way Win95 shortens task button and caption
## text; `measure` is Callable(String) -> int. Text that fits comes back unchanged.
static func ellipsize(text: String, max_width: int, measure: Callable) -> String:
	if int(measure.call(text)) <= max_width:
		return text
	const DOTS := "..."
	var cut := text
	while cut.length() > 0:
		cut = cut.substr(0, cut.length() - 1).strip_edges(false, true)
		if int(measure.call(cut + DOTS)) <= max_width:
			return cut + DOTS
	return DOTS if int(measure.call(DOTS)) <= max_width else ""
