class_name Win31LaunchFeedback
extends Control
## Batch-launch progress toast (port of components/LaunchFeedback.tsx), driven by
## UIState.launch_feedback. PLACEHOLDER — replaced by the dialogs agent. Mounted by Win31Shell.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
