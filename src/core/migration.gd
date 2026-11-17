class_name Migration
extends RefCounted
## Port of src/shared/storeMigration.ts. Normalizes any persisted payload to the current schema.
## The output always passes Validators.is_valid_group / is_valid_settings, so ProgramStore never
## holds data its save guard would refuse.
##
## Every normaliser takes an optional counter Dictionary `ctx`. When it holds the key "normalized",
## each value that had to be changed (reset to a default, coerced, clamped, dropped, or a record
## dropped) adds 1 to it. A required value that is missing (a group or item icon, a group with no
## window state at all) counts too. Valid data is never counted: filling in a key that is absent
## (workingDir, profile timestamps, a shell window state built from the legacy windowState, settings
## keys) and re-syncing windowState with shellWindowState.win31 are schema upkeep, not repairs.
## Callers that pass no counter are unaffected.


static func _bump(ctx: Dictionary) -> void:
	if ctx.has("normalized"):
		ctx["normalized"] = int(ctx["normalized"]) + 1


## Counts (in ctx) a present value that is not a window state object once, or else each field that is
## replaced, clamped or dropped. Pass no ctx when `value` is a fallback that was already counted.
static func _normalize_window_state(value: Variant, ctx: Dictionary = {}) -> Dictionary:
	var c: Dictionary = value if Jsonx.is_obj(value) else {}
	if value != null and not Jsonx.is_obj(value):
		_bump(ctx)
	elif Jsonx.is_obj(value):
		for key in ["x", "y"]:
			if not Jsonx.is_num(c.get(key)):
				_bump(ctx)
		if not Jsonx.is_num(c.get("width")) or float(c.width) < 150.0:
			_bump(ctx)
		if not Jsonx.is_num(c.get("height")) or float(c.height) < 92.0:
			_bump(ctx)
		for key in ["minimized", "maximized"]:
			if not Jsonx.is_bool(c.get(key)):
				_bump(ctx)
		for key in ["restoreX", "restoreY", "restoreWidth", "restoreHeight"]:
			if c.has(key) and not Jsonx.is_num_any(c[key]):
				_bump(ctx)
	var d := Types.default_window_state()
	var out := {
		"x": Jsonx.finite(c.get("x"), d.x),
		"y": Jsonx.finite(c.get("y"), d.y),
		"width": maxf(150.0, Jsonx.finite(c.get("width"), d.width)),
		"height": maxf(92.0, Jsonx.finite(c.get("height"), d.height)),
		"minimized": c.get("minimized") if Jsonx.is_bool(c.get("minimized")) else false,
		"maximized": c.get("maximized") if Jsonx.is_bool(c.get("maximized")) else false,
	}
	for key in ["restoreX", "restoreY", "restoreWidth", "restoreHeight"]:
		if Jsonx.is_num_any(c.get(key)):
			out[key] = c[key]
	return out


static func normalize_position(value: Variant) -> Variant:
	## Returns Dictionary or null.
	if not Jsonx.is_obj(value):
		return null
	if not Jsonx.is_num(value.get("x")) or not Jsonx.is_num(value.get("y")):
		return null
	return {"x": value.x, "y": value.y}


static func _normalize_position_map(value: Variant) -> Dictionary:
	if not Jsonx.is_obj(value):
		return {}
	var out := {}
	for key in value:
		var p: Variant = normalize_position(value[key])
		if p != null:
			out[str(key)] = p
	return out


static func _normalize_item(value: Variant, ctx: Dictionary = {}) -> Variant:
	if not Jsonx.is_obj(value):
		return null
	var item: Dictionary = value
	if not Jsonx.is_str(item.get("id")) or not Jsonx.is_str(item.get("name")) or not Jsonx.is_str(item.get("path")):
		return null
	var out := {
		"id": item.id,
		"name": item.name,
		"path": item.path,
		"icon": item.icon if Jsonx.is_str(item.get("icon")) else "default",
	}
	if not Jsonx.is_str(item.get("icon")):
		_bump(ctx)
	for key in ["win31Icon", "workingDir", "arguments", "environment", "shortcutKey"]:
		if item.has(key) and not Jsonx.is_str(item[key]):
			_bump(ctx)
	if item.has("runMinimized") and not Jsonx.is_bool(item.runMinimized):
		_bump(ctx)
	for key in ["win31Position", "win95Position"]:
		if item.has(key) and normalize_position(item[key]) == null:
			_bump(ctx)
	if Jsonx.is_str(item.get("win31Icon")):
		out["win31Icon"] = item.win31Icon
	out["workingDir"] = item.workingDir if Jsonx.is_str(item.get("workingDir")) else ""
	if Jsonx.is_str(item.get("arguments")):
		out["arguments"] = item.arguments
	if Jsonx.is_str(item.get("environment")):
		out["environment"] = item.environment
	if Jsonx.is_str(item.get("runMode")) and Types.RUN_MODES.has(item.runMode):
		out["runMode"] = item.runMode
	elif item.has("runMode"):
		_bump(ctx)
	if item.has("launchGroup"):
		# Any integer >= 0 is a batch number (9 stays 9); -1, 2.5 or a string become 0 ("None").
		if Validators.is_valid_launch_group(item.launchGroup):
			out["launchGroup"] = item.launchGroup
		else:
			out["launchGroup"] = 0
			_bump(ctx)
	if Jsonx.is_str(item.get("shortcutKey")):
		out["shortcutKey"] = item.shortcutKey
	if Jsonx.is_bool(item.get("runMinimized")):
		out["runMinimized"] = item.runMinimized
	var p31: Variant = normalize_position(item.get("win31Position"))
	if p31 != null:
		out["win31Position"] = p31
	var p95: Variant = normalize_position(item.get("win95Position"))
	if p95 != null:
		out["win95Position"] = p95
	return out


static func _normalize_shell_window_state(value: Variant, legacy: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	if not Jsonx.is_obj(value):
		if value != null:
			_bump(ctx)
		return Types.create_shell_window_state(legacy)
	var s: Dictionary = value
	# A shell that has no state of its own uses the (already counted) legacy one.
	return {
		"win31": _normalize_window_state(s.win31, ctx) if s.get("win31") != null else _normalize_window_state(legacy),
		"win95": _normalize_window_state(s.win95, ctx) if s.get("win95") != null else _normalize_window_state(legacy),
	}


static func normalize_group(value: Variant, ctx: Dictionary = {}) -> Variant:
	if not Jsonx.is_obj(value):
		return null
	var g: Dictionary = value
	if not Jsonx.is_str(g.get("id")) or not Jsonx.is_str(g.get("name")):
		return null
	var legacy := _normalize_window_state(g.get("windowState"), ctx)
	if g.get("windowState") == null and g.get("shellWindowState") == null:
		_bump(ctx)  # no window state at all: the default is used
	var shell_state := _normalize_shell_window_state(g.get("shellWindowState"), legacy, ctx)
	var items := []
	if Jsonx.is_arr(g.get("items")):
		for raw in g.items:
			var it: Variant = _normalize_item(raw, ctx)
			if it != null:
				items.append(it)
			else:
				_bump(ctx)
	else:
		_bump(ctx)  # items is required: missing or not a list becomes []
	var icon_pos: Variant = normalize_position(g.get("win31IconPosition"))
	if g.has("win31IconPosition") and icon_pos == null:
		_bump(ctx)
	if not Jsonx.is_str(g.get("icon")):
		_bump(ctx)
	var out := {
		"id": g.id,
		"name": g.name,
		"icon": g.icon if Jsonx.is_str(g.get("icon")) else "folder",
		"windowState": shell_state.win31.duplicate(true),
		"shellWindowState": shell_state,
	}
	if icon_pos != null:
		out["win31IconPosition"] = icon_pos
	out["items"] = items
	return out


## Normalised copies of `value`'s groups; records that cannot be repaired are dropped and counted.
static func normalize_groups(value: Variant, ctx: Dictionary = {}) -> Array:
	var groups := []
	if Jsonx.is_arr(value):
		for g in value:
			var ng: Variant = normalize_group(g, ctx)
			if ng != null:
				groups.append(ng)
			else:
				_bump(ctx)
	elif value != null:
		_bump(ctx)  # not a list: no groups (an absent list is simply empty)
	return groups


static func _normalize_profile(value: Variant, ctx: Dictionary = {}) -> Variant:
	if not Jsonx.is_obj(value):
		return null
	var p: Dictionary = value
	if not Jsonx.is_str(p.get("id")) or not Jsonx.is_str(p.get("name")):
		return null
	var groups := normalize_groups(p.get("groups"), ctx)
	var epoch := "1970-01-01T00:00:00.000Z"
	for key in ["createdAt", "updatedAt"]:  # a missing timestamp is filled in, not counted
		if p.get(key) != null and not Jsonx.is_str(p[key]):
			_bump(ctx)
	return {
		"id": p.id,
		"name": p.name,
		"groups": groups,
		"createdAt": p.createdAt if Jsonx.is_str(p.get("createdAt")) else epoch,
		"updatedAt": p.updatedAt if Jsonx.is_str(p.get("updatedAt")) else epoch,
	}


## Settings in the current schema. Every known key holds a value of the type and range of its
## default (rules in Validators.is_valid_setting_value); an invalid value falls back to the default.
## Unknown keys are kept untouched. Key order (defaults first, then unknown keys in stored order) is
## unchanged, so valid data keeps the same JSON layout.
static func normalize_settings(value: Variant, ctx: Dictionary = {}) -> Dictionary:
	var raw: Dictionary = value if Jsonx.is_obj(value) else {}
	if value != null and not Jsonx.is_obj(value):
		_bump(ctx)  # settings that are not an object: all defaults
	var defaults := Types.default_settings()
	var settings: Dictionary = defaults.duplicate(true)
	for k in raw:
		if defaults.has(k) and not Validators.is_valid_setting_value(str(k), raw[k]):
			_bump(ctx)  # keeps the default; the position and bounds lines below may salvage part of it
			continue
		settings[k] = Jsonx.clone(raw[k])
	settings["win31Scale"] = raw.win31Scale if Types.is_scale_preference(raw.get("win31Scale")) else "auto"
	settings["win95Scale"] = raw.win95Scale if Types.is_scale_preference(raw.get("win95Scale")) else "auto"
	settings["macScale"] = raw.macScale if Types.is_scale_preference(raw.get("macScale")) else "auto"
	settings["beScale"] = raw.beScale if Types.is_scale_preference(raw.get("beScale")) else "auto"
	settings["win95DesktopIconPositions"] = _normalize_position_map(raw.get("win95DesktopIconPositions"))
	settings["win31DesktopMode"] = raw.win31DesktopMode if Jsonx.is_bool(raw.get("win31DesktopMode")) else false
	var b: Dictionary = raw.get("win31ProgramManagerBounds") if Jsonx.is_obj(raw.get("win31ProgramManagerBounds")) else {}
	var db: Dictionary = defaults.win31ProgramManagerBounds
	settings["win31ProgramManagerBounds"] = {
		"x": Jsonx.finite(b.get("x"), db.x),
		"y": Jsonx.finite(b.get("y"), db.y),
		"width": maxf(320.0, Jsonx.finite(b.get("width"), db.width)),
		"height": maxf(240.0, Jsonx.finite(b.get("height"), db.height)),
	}
	settings["win31ProgramManagerMinimized"] = raw.win31ProgramManagerMinimized if Jsonx.is_bool(raw.get("win31ProgramManagerMinimized")) else false
	settings["launchGroupNames"] = _normalize_launch_group_names(raw.get("launchGroupNames"))
	return settings


## Keeps the valid entries of a launchGroupNames map (a whole-map default was already counted above
## when the map as a whole was invalid). Names are cleaned like the editors clean them.
static func _normalize_launch_group_names(value: Variant) -> Dictionary:
	var out := {}
	if not Jsonx.is_obj(value):
		return out
	for k in value:
		var key := str(k)
		if Jsonx.is_str(k) and Jsonx.is_str(value[k]):
			var cleaned := LaunchGroups.clean_name(String(value[k]))
			if Validators.is_launch_group_name_entry(key, cleaned):
				out[key] = cleaned
	return out


## Clears, in place, every item shortcutKey that has no modifier (Validators.is_safe_shortcut) and
## returns how many were cleared. Only for data arriving from outside (JSON, .GRP and profile
## import): migration of the user's own stored data never calls it, so their keys are kept.
static func clear_unsafe_shortcuts(groups: Array) -> int:
	var cleared := 0
	for g in groups:
		if not Jsonx.is_obj(g) or not Jsonx.is_arr(g.get("items")):
			continue
		for it in g.items:
			if Jsonx.is_obj(it) and Jsonx.is_str(it.get("shortcutKey")) and not Validators.is_safe_shortcut(String(it.shortcutKey)):
				it["shortcutKey"] = ""
				cleared += 1
	return cleared


static func migrate_store_data(value: Variant, ctx: Dictionary = {}) -> Dictionary:
	var data: Dictionary = value if Jsonx.is_obj(value) else {}
	var settings := normalize_settings(data.get("settings"), ctx)
	var groups := normalize_groups(data.get("groups"), ctx)
	var profiles := []
	if Jsonx.is_arr(data.get("workspaceProfiles")):
		for p in data.workspaceProfiles:
			var np: Variant = _normalize_profile(p, ctx)
			if np != null:
				profiles.append(np)
			else:
				_bump(ctx)
	elif data.get("workspaceProfiles") != null:
		_bump(ctx)
	return {
		"schemaVersion": Types.CURRENT_SCHEMA_VERSION,
		"groups": groups,
		"settings": settings,
		"workspaceProfiles": profiles,
	}
