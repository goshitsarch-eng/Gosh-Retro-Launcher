class_name BeUi
extends RefCounted
## Shared handles the Be widgets need: the shell's popup layer (select lists and context menus above dialogs)
## and the automation-id helper. Set by BeShell while it is in the tree.

static var shell: Control
static var popup_layer: Control


## Registers `node` with the automation driver (group "pm_auto", meta "auto_id").
static func auto_id(node: Control, id: String) -> void:
	node.set_meta("auto_id", id)
	if not node.is_in_group("pm_auto"):
		node.add_to_group("pm_auto")
