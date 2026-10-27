class_name LaunchGroups
extends RefCounted
## Batch ("numbered group") launching. Port of src/renderer/src/utils/launchGroups.ts and the
## batch loop in launchHandlers.ts.

const MAX_BATCH_ITEMS := 200
const MAX_LAUNCH_DELAY_MS := 10000


static func format_launch_group(value: int) -> String:
	return "None" if value <= 0 else "Group %d" % value


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
