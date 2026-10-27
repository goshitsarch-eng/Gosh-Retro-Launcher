class_name Win31DialogLayer
extends Control
## Modal dialog host for the WfW shell. Watches UIState.dialog_changed and shows the dialog for
## UIState.active_dialog / dialog_data (port of components/Dialogs/DialogManager.tsx).
## PLACEHOLDER — replaced by the dialogs agent. Mounted full-rect above the shell by Win31Shell.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
