class_name ProgramSearch
extends RefCounted
## Quick Search / Win95 Find ranking. Port of src/renderer/src/utils/programSearch.ts.


static func _wildcard(value: String) -> RegEx:
	var escaped := ""
	for ch in value:
		if ".+^${}()|[]\\".contains(ch):
			escaped += "\\" + ch
		elif ch == "*":
			escaped += ".*"
		elif ch == "?":
			escaped += "."
		else:
			escaped += ch
	var re := RegEx.new()
	re.compile("(?is)^" + escaped + "$")
	return re


static func _cmp(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return String(a.item.name).naturalnocasecmp_to(String(b.item.name)) < 0


## filters: {named, groupId?, type?("all"|"application"|"internet"), containing?, path?}
static func find_programs(groups: Array, filters: Dictionary) -> Array:
	var named := String(filters.get("named", "")).strip_edges()
	if named.is_empty():
		named = "*"
	var pattern := _wildcard(named if (named.contains("*") or named.contains("?")) else "*" + named + "*")
	var containing := String(filters.get("containing", "")).strip_edges().to_lower()
	var path_filter := String(filters.get("path", "")).strip_edges().to_lower()
	var group_id := String(filters.get("groupId", ""))
	var type := String(filters.get("type", "all"))
	var named_l := named.to_lower()
	var url_re := RegEx.new()
	url_re.compile("(?i)^https?://")
	var results := []
	for group in groups:
		if group_id != "" and group.id != group_id:
			continue
		for item in group.items:
			var internet := url_re.search(item.path) != null
			if type == "internet" and not internet:
				continue
			if type == "application" and internet:
				continue
			if pattern.search(item.name) == null:
				continue
			var haystack := ("%s\n%s\n%s" % [item.name, item.path, item.get("arguments", "")]).to_lower()
			if containing != "" and not haystack.contains(containing):
				continue
			if path_filter != "" and not String(item.path).to_lower().contains(path_filter):
				continue
			var lname := String(item.name).to_lower()
			var score := 3 if lname == named_l else (2 if lname.begins_with(named_l) else 1)
			results.append({"group": group, "item": item, "score": score})
	results.sort_custom(_cmp)
	return results


static func search_programs(groups: Array, raw_query: String) -> Array:
	var query := raw_query.strip_edges().to_lower()
	if query.is_empty():
		return []
	var results := []
	for group in groups:
		var group_name := String(group.name).to_lower()
		for item in group.items:
			var name := String(item.name).to_lower()
			var path := String(item.path).to_lower()
			var score := 3 if name.begins_with(query) else (2 if name.contains(query) else (1 if (path.contains(query) or group_name.contains(query)) else 0))
			if score > 0:
				results.append({"group": group, "item": item, "score": score})
	results.sort_custom(_cmp)
	return results
