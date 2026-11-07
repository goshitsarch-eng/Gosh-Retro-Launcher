class_name Win31DialogLayer
extends Control
## Modal dialog host for the WfW shell. Watches UIState.dialog_changed and shows the dialog for
## UIState.active_dialog / dialog_data (port of components/Dialogs/DialogManager.tsx).
## Mounted full-rect above the shell by Win31Shell. While a dialog is open the layer swallows
## all mouse input (the backdrop is not dismissible in the WfW shell).

var _dialog: W31Dialog
var _pending: W31Dialog
var _prev_focus: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	UIState.dialog_changed.connect(_on_changed)
	resized.connect(_on_resized)
	_on_changed()


func current_dialog() -> W31Dialog:
	return _dialog


static func create_dialog(type: String, data: Dictionary) -> W31Dialog:
	var groups: Array = ProgramStore.groups
	match type:
		"newGroup":
			return W31FormDialogs.NewGroup.new(data)
		"renameGroup":
			if data.get("group", {}).is_empty():
				return null
			return W31FormDialogs.RenameGroup.new(data.group)
		"groupProperties":
			if data.get("group", {}).is_empty():
				return null
			return W31PropertiesDialogs.GroupProperties.new(data)
		"newItem", "itemProperties":
			return W31PropertiesDialogs.ItemProperties.new(data, groups)
		"newUrl":
			return W31FormDialogs.NewUrl.new(data, groups)
		"settings":
			return W31SettingsDialog.new()
		"about":
			return W31MessageDialogs.About.new()
		"confirm":
			var opts: Dictionary = data.get("confirmOptions", {})
			if opts.is_empty():
				return null
			return W31MessageDialogs.Confirm.new(opts)
		"welcome":
			return W31MessageDialogs.Welcome.new()
		"newObject":
			return W31FormDialogs.NewObject.new(data, groups)
		"moveItem", "copyItem":
			if String(data.get("groupId", "")) == "" or data.get("item", {}).is_empty():
				return null
			return W31FormDialogs.MoveCopy.new(type == "copyItem", data, groups)
		"run":
			return W31FormDialogs.Run.new()
		"help":
			return W31FormDialogs.Help.new(data)
		"changeIcon":
			if String(data.get("groupId", "")) == "" or data.get("item", {}).is_empty():
				return null
			return W31FormDialogs.ChangeIcon.new(data)
		"exitWindows":
			return W31MessageDialogs.ExitWindows.new()
		"unavailable":
			return W31MessageDialogs.Unavailable.new(data)
	return null


func _on_changed() -> void:
	var had_dialog := _dialog != null or _pending != null
	_remove_current()
	var type: String = UIState.active_dialog
	if type == "":
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if had_dialog and _prev_focus and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
			_prev_focus.grab_focus()
		_prev_focus = null
		return
	if not had_dialog:
		_prev_focus = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dlg := create_dialog(type, UIState.dialog_data)
	if dlg == null:
		return
	Sounds.play("dialog_open")
	if size.y > 0:
		_mount(dlg)
	else:
		_pending = dlg


func _remove_current() -> void:
	for d in [_dialog, _pending]:
		if d != null and is_instance_valid(d):
			if d.get_parent() == self:
				remove_child(d)
			d.queue_free()
	_dialog = null
	_pending = null


func _mount(dlg: W31Dialog) -> void:
	_dialog = dlg
	_pending = null
	add_child(dlg)
	dlg.build(int(size.y))
	dlg.place(size)
	dlg.grab_initial_focus()


func _on_resized() -> void:
	if _pending and size.y > 0:
		_mount(_pending)
	elif _dialog:
		_dialog.place(size)
