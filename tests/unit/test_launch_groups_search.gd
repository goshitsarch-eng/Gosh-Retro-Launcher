extends TestCase
## Ports of launchGroups.test.ts and programSearch.test.ts

func _item(id: String, lg: int) -> Dictionary:
	return {"id": id, "name": id, "path": "/apps/" + id, "icon": "default", "workingDir": "", "launchGroup": lg}


func _group(id: String, items: Array) -> Dictionary:
	var st := {"x": 0, "y": 0, "width": 300, "height": 200, "minimized": false, "maximized": false}
	return {"id": id, "name": id, "icon": "folder", "windowState": st, "shellWindowState": {"win31": st, "win95": st}, "items": items}


func test_collect_orders_by_number() -> void:
	var groups := [
		_group("one", [_item("a", 2), _item("ignored", 0), _item("b", 1)]),
		_group("two", [_item("c", 2), _item("d", 1)]),
	]
	var out := []
	for b in LaunchGroups.collect_launch_groups(groups):
		out.append({"groupNumber": b.groupNumber, "ids": b.items.map(func(i): return i.id)})
	expect_eq(out, [{"groupNumber": 1, "ids": ["b", "d"]}, {"groupNumber": 2, "ids": ["a", "c"]}])


func test_launch_buckets_reports_progress_before_launch() -> void:
	var calls := []
	var batch := func(items: Array, delay: Variant) -> Array:
		calls.append("launch:%s:%s" % [",".join(items.map(func(i): return i.id)), delay])
		return items.map(func(i): return {"id": i.id, "success": true})
	var buckets := [
		{"groupNumber": 1, "items": [_item("a", 1)]},
		{"groupNumber": 3, "items": [_item("b", 3), _item("c", 3)]},
	]
	var host := Node.new()
	var results: Array = await LaunchGroups.launch_group_buckets(host, buckets, 250,
		func(p): calls.append("progress:%d:%d" % [p.groupNumber, p.groupIndex]), batch)
	expect_eq(calls, ["progress:1:0", "launch:a:250", "progress:3:1", "launch:b,c:250"])
	expect_eq(results.size(), 3)
	host.free()


func test_batch_limits() -> void:
	var host := Node.new()
	var many := []
	for i in 201:
		many.append(_item("i%d" % i, 1))
	var r: Array = await LaunchGroups.launch_batch(host, many, 0)
	expect_eq(r[0].error, "Batch size exceeds 200 items")
	var bad: Array = await LaunchGroups.launch_batch(host, [{"id": 1}], 0)
	expect_eq(bad[0].error, "Invalid program batch payload")
	host.free()


func _search_groups() -> Array:
	return [_group("utilities", [
		{"id": "calc", "name": "Calculator", "path": "calc.exe", "icon": "calculator", "workingDir": ""},
		{"id": "calendar", "name": "Calendar", "path": "calendar.exe", "icon": "calendar", "workingDir": ""},
		{"id": "notes", "name": "Notes", "path": "/tools/calc-notes", "icon": "document", "workingDir": ""}])]


func test_search_ranking() -> void:
	expect_eq(ProgramSearch.search_programs(_search_groups(), "calc").map(func(r): return r.item.id), ["calc", "notes"])
	expect_eq(ProgramSearch.search_programs(_search_groups(), "utilities").size(), 3)
	expect_eq(ProgramSearch.search_programs(_search_groups(), "   "), [])


func test_find_programs_filters() -> void:
	var g := _search_groups()
	expect_eq(ProgramSearch.find_programs(g, {"named": "cal*"}).map(func(r): return r.item.id), ["calc", "calendar"])
	expect_eq(ProgramSearch.find_programs(g, {"named": "Notes"}).size(), 1)
	expect_eq(ProgramSearch.find_programs(g, {"named": "", "path": "tools"}).size(), 1)
	expect_eq(ProgramSearch.find_programs(g, {"named": "", "type": "internet"}).size(), 0)
