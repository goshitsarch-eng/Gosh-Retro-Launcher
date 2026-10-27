class_name Win31QuickSearch
extends Control
## Quick Search overlay (port of components/QuickSearch/QuickSearchOverlay.tsx). Visible while
## UIState.quick_search_open. PLACEHOLDER — replaced by the dialogs agent. Mounted by Win31Shell.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
