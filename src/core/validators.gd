class_name Validators
extends RefCounted
## Strict payload validation. Port of the is* guards in src/main/ipc/storeHandlers.ts and launchHandlers.ts.


static func is_position(value: Variant) -> bool:
	return Jsonx.is_obj(value) and Jsonx.is_num(value.get("x")) and Jsonx.is_num(value.get("y"))


static func is_position_map(value: Variant) -> bool:
	if not Jsonx.is_obj(value):
		return false
	for k in value:
		if not is_position(value[k]):
			return false
	return true


static func is_window_state(value: Variant) -> bool:
	if not Jsonx.is_obj(value):
		return false
	return Jsonx.is_num(value.get("x")) and Jsonx.is_num(value.get("y")) \
		and Jsonx.is_num(value.get("width")) and value.width > 0 \
		and Jsonx.is_num(value.get("height")) and value.height > 0 \
		and Jsonx.is_bool(value.get("minimized")) and Jsonx.is_bool(value.get("maximized"))


static func _opt_str(o: Dictionary, k: String) -> bool:
	return not o.has(k) or Jsonx.is_str(o[k])


static func is_valid_item(item: Variant) -> bool:
	if not Jsonx.is_obj(item):
		return false
	var o: Dictionary = item
	if not (Jsonx.is_str(o.get("id")) and Jsonx.is_str(o.get("name")) and Jsonx.is_str(o.get("path")) and Jsonx.is_str(o.get("icon"))):
		return false
	if not (_opt_str(o, "win31Icon") and _opt_str(o, "workingDir") and _opt_str(o, "arguments") and _opt_str(o, "environment")):
		return false
	if o.has("runMode") and not (Jsonx.is_str(o.runMode) and Types.RUN_MODES.has(o.runMode)):
		return false
	if o.has("launchGroup") and not (Jsonx.is_integer(o.launchGroup) and o.launchGroup >= 0):
		return false
	if not _opt_str(o, "shortcutKey"):
		return false
	if o.has("runMinimized") and not Jsonx.is_bool(o.runMinimized):
		return false
	if o.has("win31Position") and not is_position(o.win31Position):
		return false
	if o.has("win95Position") and not is_position(o.win95Position):
		return false
	return true


## Item payload for launching (workingDir is mandatory there, unlike stored items).
static func is_launch_item(value: Variant) -> bool:
	if not Jsonx.is_obj(value):
		return false
	var o: Dictionary = value
	if not (Jsonx.is_str(o.get("id")) and Jsonx.is_str(o.get("name")) and Jsonx.is_str(o.get("path")) \
			and Jsonx.is_str(o.get("icon")) and Jsonx.is_str(o.get("workingDir"))):
		return false
	if not (_opt_str(o, "arguments") and _opt_str(o, "environment")):
		return false
	if o.has("runMode") and not (Jsonx.is_str(o.runMode) and Types.RUN_MODES.has(o.runMode)):
		return false
	if o.has("runMinimized") and not Jsonx.is_bool(o.runMinimized):
		return false
	if o.has("launchGroup") and not (Jsonx.is_integer(o.launchGroup) and o.launchGroup >= 0):
		return false
	return true


static func is_valid_group(group: Variant) -> bool:
	if not Jsonx.is_obj(group):
		return false
	var o: Dictionary = group
	var shell_state: Variant = o.get("shellWindowState")
	var has_legacy := is_window_state(o.get("windowState"))
	var has_shell := Jsonx.is_obj(shell_state) and is_window_state(shell_state.get("win31")) and is_window_state(shell_state.get("win95"))
	if not (Jsonx.is_str(o.get("id")) and Jsonx.is_str(o.get("name")) and Jsonx.is_str(o.get("icon")) and (has_legacy or has_shell)):
		return false
	if o.has("win31IconPosition") and not is_position(o.win31IconPosition):
		return false
	if not Jsonx.is_arr(o.get("items")):
		return false
	for item in o.items:
		if not is_valid_item(item):
			return false
	return true


static func is_valid_workspace_profile(value: Variant) -> bool:
	if not Jsonx.is_obj(value):
		return false
	var p: Dictionary = value
	if not (Jsonx.is_str(p.get("id")) and Jsonx.is_str(p.get("name")) and Jsonx.is_str(p.get("createdAt")) \
			and Jsonx.is_str(p.get("updatedAt")) and Jsonx.is_arr(p.get("groups"))):
		return false
	for g in p.groups:
		if not is_valid_group(g):
			return false
	return true


static func is_valid_settings(settings: Variant) -> bool:
	if not Jsonx.is_obj(settings):
		return false
	var o: Dictionary = settings
	if not (Jsonx.is_bool(o.get("autoArrange")) and Jsonx.is_bool(o.get("minimizeOnUse")) and Jsonx.is_bool(o.get("saveSettingsOnExit"))):
		return false
	if not (Jsonx.is_num_any(o.get("launchDelay")) and o.launchDelay >= 0):
		return false
	if not Jsonx.is_bool(o.get("trayOnClose")):
		return false
	if not (Jsonx.is_num_any(o.get("groupChromeScale")) and o.groupChromeScale > 0):
		return false
	if o.has("win31Scale") and not Types.is_scale_preference(o.win31Scale):
		return false
	if o.has("win95Scale") and not Types.is_scale_preference(o.win95Scale):
		return false
	if o.has("win95DesktopIconPositions") and not is_position_map(o.win95DesktopIconPositions):
		return false
	if o.has("win31DesktopMode") and not Jsonx.is_bool(o.win31DesktopMode):
		return false
	if o.has("win31ProgramManagerMinimized") and not Jsonx.is_bool(o.win31ProgramManagerMinimized):
		return false
	if o.has("win31ProgramManagerBounds"):
		var b: Variant = o.win31ProgramManagerBounds
		if not (Jsonx.is_obj(b) and is_position(b) and Jsonx.is_num(b.get("width")) and b.width >= 320 \
				and Jsonx.is_num(b.get("height")) and b.height >= 240):
			return false
	if not (Jsonx.is_str(o.get("theme")) and Types.THEMES.has(o.theme)):
		return false
	if not (Jsonx.is_str(o.get("labelDisplay")) and Types.LABEL_DISPLAYS.has(o.labelDisplay)):
		return false
	if o.has("shell") and not (Jsonx.is_str(o.shell) and Types.SHELLS.has(o.shell)):
		return false
	if o.has("soundEnabled") and not Jsonx.is_bool(o.soundEnabled):
		return false
	return true


static func is_valid_shell_frame_request(value: Variant) -> bool:
	return Jsonx.is_str(value) and (value == "win31" or value == "win95")


## win31 uses a custom-drawn frame; win95 a native OS frame.
static func uses_native_window_frame(shell: String) -> bool:
	return shell != "win31"
