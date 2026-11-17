class_name LaunchGroups
extends RefCounted
## Batch ("numbered group") launching. Port of src/renderer/src/utils/launchGroups.ts and the
## batch loop in launchHandlers.ts.

const MAX_BATCH_ITEMS := 200
const MAX_LAUNCH_DELAY_MS := 10000
## Launch group numbers the editors and the Launch Groups manager offer (1..MAX_GROUP).
const MAX_GROUP := 8
## Longest launch group name kept (settings.launchGroupNames values).
const MAX_NAME_LENGTH := 40


## "None", "Group 3" or, when `names` (settings.launchGroupNames) names it, "Group 3: Morning".
static func format_launch_group(value: int, names: Variant = null) -> String:
	if value <= 0:
		return "None"
	var n := name_of(names, value)
	return "Group %d" % value if n == "" else "Group %d: %s" % [value, n]


# ------------------------------------------------------------------ names

## The name stored for group `number` in `names` (settings.launchGroupNames: {"3": "Morning"}), or "".
static func name_of(names: Variant, number: int) -> String:
	if not Jsonx.is_obj(names):
		return ""
	var v: Variant = names.get(str(number))
	return String(v) if Jsonx.is_str(v) else ""


## The launchGroupNames dictionary from a settings dictionary ({} when missing or malformed).
static func names_from(settings: Variant) -> Dictionary:
	if Jsonx.is_obj(settings) and Jsonx.is_obj(settings.get("launchGroupNames")):
		return settings.launchGroupNames
	return {}


## A name as stored: one line, trimmed, at most MAX_NAME_LENGTH characters.
static func clean_name(text: String) -> String:
	var one_line := text.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	return one_line.substr(0, MAX_NAME_LENGTH).strip_edges()


## Launch label for a menu or button: "Launch Group 3 (2 items)" or "Launch Group 3: Morning (2 items)".
static func launch_label(number: int, count: int, names: Variant = null) -> String:
	return "Launch %s (%d %s)" % [format_launch_group(number, names), count, "item" if count == 1 else "items"]


# ------------------------------------------------------------- inspection

## Every launch group that exists: each number some item uses plus each named number, sorted.
## [{number, name, label, count}] where label is format_launch_group().
static func defined_groups(groups: Array, names: Variant = null) -> Array:
	var counts := {}
	for g in groups:
		for item in g.get("items", []):
			var n := int(item.get("launchGroup", 0))
			if n > 0:
				counts[n] = int(counts.get(n, 0)) + 1
	if Jsonx.is_obj(names):
		for k in names:
			var n := String(k).to_int()
			if n > 0 and name_of(names, n) != "" and not counts.has(n):
				counts[n] = 0
	var numbers := counts.keys()
	numbers.sort()
	var out := []
	for n in numbers:
		out.append({"number": n, "name": name_of(names, n), "label": format_launch_group(n, names), "count": counts[n]})
	return out


## Every program item, in group then item order, for a member checklist:
## [{key: "groupId:itemId", groupId, itemId, name, groupName, launchGroup}].
static func all_items(groups: Array) -> Array:
	var out := []
	for g in groups:
		for item in g.get("items", []):
			out.append({"key": "%s:%s" % [g.id, item.id], "groupId": g.id, "itemId": item.id,
				"name": String(item.get("name", "")), "groupName": String(g.get("name", "")),
				"launchGroup": int(item.get("launchGroup", 0))})
	return out


## The "groupId:itemId" keys of the items in launch group `number`.
static func member_keys(groups: Array, number: int) -> Array:
	var out := []
	for e in all_items(groups):
		if e.launchGroup == number:
			out.append(e.key)
	return out


## The lowest number in 1..MAX_GROUP no item uses and no name claims, or 0 when all are taken.
static func next_free_number(groups: Array, names: Variant = null) -> int:
	var taken := {}
	for d in defined_groups(groups, names):
		taken[int(d.number)] = true
	for n in range(1, MAX_GROUP + 1):
		if not taken.has(n):
			return n
	return 0


## [{groupNumber, items}] sorted by number; items keep group then item order.
static func collect_launch_groups(groups: Array) -> Array:
	var buckets := {}
	for g in groups:
		for item in g.items:
			var n := int(item.get("launchGroup", 0))
			if n <= 0:
				continue
			if not buckets.has(n):
				buckets[n] = []
			buckets[n].append(item)
	var numbers := buckets.keys()
	numbers.sort()
	var out := []
	for n in numbers:
		out.append({"groupNumber": n, "items": buckets[n]})
	return out


## Launches items sequentially with `delay_ms` between them. Coroutine: `await` it.
## Returns [{id, success, error?}].
static func launch_batch(host: Node, items: Array, delay_ms: Variant, launcher: Callable = Launcher.launch_program) -> Array:
	for item in items:
		if not Validators.is_launch_item(item):
			return [{"id": "unknown", "success": false, "error": "Invalid program batch payload"}]
	if items.size() > MAX_BATCH_ITEMS:
		return [{"id": "unknown", "success": false, "error": "Batch size exceeds %d items" % MAX_BATCH_ITEMS}]
	var clamped := 0
	if Jsonx.is_num(delay_ms):
		clamped = clampi(int(floorf(float(delay_ms))), 0, MAX_LAUNCH_DELAY_MS)
	var results := []
	for i in items.size():
		var result: Dictionary = launcher.call(items[i])
		var entry := {"id": items[i].id, "success": result.get("success", false)}
		if result.has("error"):
			entry["error"] = result.error
		results.append(entry)
		if i < items.size() - 1 and clamped > 0:
			await host.get_tree().create_timer(clamped / 1000.0).timeout
	return results


## `on_group_start(progress)` fires before each bucket launches. Coroutine.
static func launch_group_buckets(host: Node, buckets: Array, launch_delay: Variant, on_group_start: Callable = Callable(),
		batch_launcher: Callable = Callable()) -> Array:
	var results := []
	for index in buckets.size():
		var bucket: Dictionary = buckets[index]
		if on_group_start.is_valid():
			on_group_start.call({"groupNumber": bucket.groupNumber, "groupIndex": index,
				"totalGroups": buckets.size(), "items": bucket.items})
		var group_results: Array
		if batch_launcher.is_valid():
			group_results = await batch_launcher.call(bucket.items, launch_delay)
		else:
			group_results = await launch_batch(host, bucket.items, launch_delay)
		results.append_array(group_results)
	return results
