class_name Types
extends RefCounted
## Shared model constants/defaults. Port of src/shared/types/index.ts.
## Records are plain Dictionaries with the exact same keys the Electron build persisted.

const CURRENT_SCHEMA_VERSION := 5
const SCALE_FACTORS := [1, 2, 3, 4]
const SHELL_WIN31 := "win31"
const SHELL_WIN95 := "win95"
const RUN_MODES := ["normal", "minimized", "maximized"]
const THEMES := ["light", "dark"]
const LABEL_DISPLAYS := ["wrap", "ellipsis"]
const SHELLS := ["win31", "win95"]

static func default_settings() -> Dictionary:
	return {
		"autoArrange": true,
		"minimizeOnUse": false,
		"saveSettingsOnExit": true,
		"launchDelay": 500,
		"trayOnClose": true,
		"groupChromeScale": 1,
		"win31Scale": "auto",
		"win95Scale": "auto",
		"win95DesktopIconPositions": {},
		"win31DesktopMode": false,
		"win31ProgramManagerBounds": {"x": 68, "y": 49, "width": 511, "height": 335},
		"win31ProgramManagerMinimized": false,
		"theme": "light",
		"labelDisplay": "wrap",
		"shell": "win31",
		"soundEnabled": true,
	}


static func default_window_state() -> Dictionary:
	return {"x": 20, "y": 20, "width": 300, "height": 200, "minimized": false, "maximized": false}


static func clone_window_state(state: Dictionary = {}) -> Dictionary:
	return (state if not state.is_empty() else default_window_state()).duplicate(true)


static func create_shell_window_state(state: Dictionary = {}) -> Dictionary:
	return {"win31": clone_window_state(state), "win95": clone_window_state(state)}


static func get_group_window_state(group: Dictionary, shell: String) -> Dictionary:
	var shell_states: Variant = group.get("shellWindowState")
	if Jsonx.is_obj(shell_states) and shell_states.get(shell) != null:
		return shell_states[shell]
	var legacy: Variant = group.get("windowState")
	if Jsonx.is_obj(legacy):
		return legacy
	return default_window_state()


static func is_scale_factor(value: Variant) -> bool:
	return Jsonx.is_num(value) and SCALE_FACTORS.has(int(value)) and float(int(value)) == float(value)


static func is_scale_preference(value: Variant) -> bool:
	return (Jsonx.is_str(value) and str(value) == "auto") or is_scale_factor(value)


static func make_id() -> String:
	## UUID v4 (the Electron build used the `uuid` package).
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
