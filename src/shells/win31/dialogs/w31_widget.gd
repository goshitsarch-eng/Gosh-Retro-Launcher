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


# ------------------------------------------------------------------ accessibility

## Screen-reader description of this widget (see A11y); {} keeps Godot's generic element.
func a11y_spec() -> Dictionary:
	return {}


## Sets the caption a screen reader announces for this widget (its form label).
func set_a11y_label(label: String) -> void:
	accessibility_name = A11y.plain(label.trim_suffix(":"))


## Caption the owning form gave this widget (form-row label), without access markers.
func a11y_label() -> String:
	return A11y.plain(accessibility_name)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		A11y.track(self)
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		var spec := a11y_spec()
		if not spec.is_empty():
			A11y.apply_node(self, spec)


func _get_focused_accessibility_element() -> RID:
	return A11y.resolve(get_accessibility_element())
