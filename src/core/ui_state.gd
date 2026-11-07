extends Node
## Autoload "UIState". Port of src/renderer/src/store/uiStore.ts: menus, dialogs, quick search,
## selection, and batch-launch feedback. Dialog payloads are Dictionaries; callbacks are Callables.

signal active_menu_changed
signal dialog_changed
signal quick_search_changed
signal selection_changed
signal launch_feedback_changed

const LAUNCH_FEEDBACK_HIDE_SECONDS := 1.8

var active_menu: String = ""
var active_dialog: String = ""  ## "" = none. See DIALOG_TYPES.
var dialog_data: Dictionary = {}
var quick_search_open := false
var selected_item_id: String = ""
var selected_group_id: String = ""
## {"kind": "item", groupId, itemId} | {"kind": "groupIcon", groupId} | {}
var win31_selection: Dictionary = {}
var launch_feedback: Dictionary = {}

var _hide_timer: Timer

const DIALOG_TYPES := [
	"newGroup", "renameGroup", "groupProperties", "newItem", "newUrl", "itemProperties", "settings",
	"about", "confirm", "welcome", "newObject", "moveItem", "copyItem", "run", "changeIcon", "help",
	"exitWindows", "unavailable",
]


func _init() -> void:
	_reset_feedback()
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = LAUNCH_FEEDBACK_HIDE_SECONDS
	_hide_timer.timeout.connect(_on_hide_timeout)
	add_child(_hide_timer)


func _reset_feedback() -> void:
	launch_feedback = {
		"visible": false, "totalGroups": 0, "totalItems": 0, "currentGroup": null,
		"completedGroups": 0, "failures": 0, "status": "idle",
	}


# ------------------------------------------------------------------ menus

func set_active_menu(menu: String) -> void:
	active_menu = menu
	active_menu_changed.emit()


# ---------------------------------------------------------------- dialogs

func open_dialog(type: String, data: Dictionary = {}) -> void:
	active_dialog = type
	dialog_data = data
	dialog_changed.emit()


func close_dialog() -> void:
	active_dialog = ""
	dialog_data = {}
	dialog_changed.emit()


# ----------------------------------------------------------- quick search

func toggle_quick_search() -> void:
	quick_search_open = not quick_search_open
	quick_search_changed.emit()


func open_quick_search() -> void:
	quick_search_open = true
	quick_search_changed.emit()


func close_quick_search() -> void:
	quick_search_open = false
	quick_search_changed.emit()


# -------------------------------------------------------------- selection

func set_selected_item(item_id: String, group_id: String) -> void:
	selected_item_id = item_id
	selected_group_id = group_id
	selection_changed.emit()


func clear_selection() -> void:
	selected_item_id = ""
	selected_group_id = ""
	win31_selection = {}
	selection_changed.emit()


func set_win31_selection(selection: Dictionary) -> void:
	win31_selection = selection
	selection_changed.emit()


# ------------------------------------------------------- launch feedback

func begin_launch_feedback(total_groups: int, total_items: int) -> void:
	_hide_timer.stop()
	launch_feedback = {
		"visible": true, "totalGroups": total_groups, "totalItems": total_items, "currentGroup": null,
		"completedGroups": 0, "failures": 0, "status": "launching",
	}
	launch_feedback_changed.emit()


func update_launch_feedback(current_group: int, completed_groups: int) -> void:
	launch_feedback["visible"] = true
	launch_feedback["currentGroup"] = current_group
	launch_feedback["completedGroups"] = completed_groups
	launch_feedback["status"] = "launching"
	launch_feedback_changed.emit()


func finish_launch_feedback(failures: int) -> void:
	launch_feedback["visible"] = true
	launch_feedback["currentGroup"] = null
	launch_feedback["completedGroups"] = launch_feedback.totalGroups
	launch_feedback["failures"] = failures
	launch_feedback["status"] = "error" if failures > 0 else "complete"
	launch_feedback_changed.emit()
	if is_inside_tree():
		_hide_timer.start()


func hide_launch_feedback() -> void:
	launch_feedback["visible"] = false
	launch_feedback["status"] = "idle"
	launch_feedback_changed.emit()


func _on_hide_timeout() -> void:
	hide_launch_feedback()
