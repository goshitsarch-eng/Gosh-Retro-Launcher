class_name W31Widget
extends Control
## Base of the Win31 dialog controls: automation id registration and a few shared hooks.
## All widgets draw themselves in logical pixels (see W31) and live inside a W31Dialog.

var auto_id := ""
var access_key := ""  ## lower-case single letter activated by Alt+key in the owning dialog


func set_auto_id(id: String) -> void:
	auto_id = id
	set_meta("auto_id", id)
	if not is_in_group("pm_auto"):
		add_to_group("pm_auto")


## The Control that actually owns keyboard focus (wrappers such as text fields override this).
func focus_target() -> Control:
	return self


## Whether the widget wants Tab/focus traversal right now.
func is_tab_stop() -> bool:
	return is_visible_in_tree() and focus_mode != Control.FOCUS_NONE


## Escape closes an open drop-down instead of the dialog: return true to swallow Escape.
func consume_escape() -> bool:
	return false


## Alt+access key pressed.
func activate_access_key() -> void:
	grab_focus()
