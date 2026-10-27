class_name ShellBase
extends Control
## Contract between the app host and a desktop shell (Win31/WfW or Win95).
## A shell fills the window's *logical* area (the host applies the integer content scale),
## owns all of its dialogs/menus/windows, and talks to the model only through the
## ProgramStore / UIState / MdiState autoloads.

signal request_quit
signal request_hide_window      ## minimize-to-tray / hide
signal request_minimize_window
signal request_maximize_window
signal request_show_launcher_tools
signal request_switch_shell(shell: String)

var host: Node  ## the app host (src/app/main.gd); set before the shell enters the tree


func shell_id() -> String:
	return ""


## Called after the store has loaded and the shell is in the tree.
func on_activate() -> void:
	pass


## Global Quick Search / Win95 Find toggle (tray menu, in-app shortcut).
func toggle_quick_search() -> void:
	pass


## Files dragged from the OS file manager. `logical_pos` is in shell logical pixels.
func on_files_dropped(_files: PackedStringArray, _logical_pos: Vector2) -> void:
	pass


## Window geometry changed (focus/maximize/minimize/resize/display metrics).
func on_host_state_changed(_state: Dictionary) -> void:
	pass


## Whole-UI scale preference changed or the display changed. `factor` is the integer scale.
func on_scale_changed(_factor: int) -> void:
	pass
