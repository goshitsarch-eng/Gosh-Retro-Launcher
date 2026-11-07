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
