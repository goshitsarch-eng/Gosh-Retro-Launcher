class_name Win95Dialogs
extends RefCounted
## Entry points the Win95 shell calls for dialogs and secondary windows.
##
## IMPLEMENTED here (basic Win95 message-box look, built on Win95Modal):
##   show_message(shell, title, text, icon = "information")      # OK box; icon: information|warning|critical|question
##   confirm(shell, title, message, on_confirm, on_cancel = Callable())   # Yes / No(default) box
##   open_find(shell)                                            # opens/activates the Find primary window
## STUBS (do nothing yet; a later agent fills them using Win95Modal + Win95Button/Checkbox/Radio/
## Win95TextInput/Win95Select/Win95GroupBox, or Win95Window chrome for window-like surfaces):
##   open_run(shell)                  # Start > Run..., Win+R
##   open_shutdown(shell)             # Start > Shut Down...  (quit / restart / switch via shell.request_*)
##   open_wizard(shell, ctx)          # Create Shortcut wizard; ctx = {groupId?}
##   open_properties(shell, target)   # target = {kind: "item", groupId, item} | {kind: "group", group}
##   open_new_folder(shell, ctx)      # ctx = {openItemAfterCreate?, openUrlAfterCreate?}
##   open_new_url(shell, ctx)         # ctx = {groupId?}
##   open_help(shell) / open_about(shell)
##   build_find_view(shell, window)   # return the Find client Control (or null); see Win95Window
## `shell` is the Win95Shell: shell.windows (Win95WindowStore), shell.input, shell.dialog_layer,
## shell.logical_size, shell.request_* signals.

static func open_run(_shell: Control) -> void:
	pass


static func open_shutdown(_shell: Control) -> void:
	pass


static func open_find(shell: Control) -> void:
	shell.windows.open_find()


static func open_wizard(_shell: Control, _ctx: Dictionary) -> void:
	pass


static func open_properties(_shell: Control, _target: Dictionary) -> void:
	pass


static func open_new_folder(_shell: Control, _ctx: Dictionary) -> void:
	pass


static func open_new_url(_shell: Control, _ctx: Dictionary) -> void:
	pass


static func open_help(_shell: Control) -> void:
	pass


static func open_about(_shell: Control) -> void:
	pass


static func build_find_view(_shell: Control, _window: Control) -> Control:
	return null


## OK message box (355x145 frame, 32px icon, wrapped text, default OK).
static func show_message(shell: Control, title: String, text: String, icon: String = "information") -> Win95Modal:
	var m := Win95Modal.open(shell, title, Vector2(355, 145))
	_message_body(m, text, icon)
	var ok := Win95Button.new()
	ok.label = "OK"
	m.add(ok, Vector2(m.body.size.x - 9 - 75, m.body.size.y - 8 - 23 - 0))
	m.set_default(ok)
	ok.pressed.connect(m.close)
	ok.grab_focus()
	return m


## Yes/No question box; No is the default (least destructive).
static func confirm(shell: Control, title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> Win95Modal:
	var m := Win95Modal.open(shell, title, Vector2(355, 145))
	_message_body(m, message, "question")
	var yes := Win95Button.new()
	yes.label = "&Yes"
	var no := Win95Button.new()
	no.label = "&No"
	var y: float = m.body.size.y - 8 - 23
	m.add(yes, Vector2(m.body.size.x - 9 - 75 * 2 - 6, y))
	m.add(no, Vector2(m.body.size.x - 9 - 75, y))
	m.set_default(no)
	var cancel := func():
		m.close()
		if on_cancel.is_valid():
			on_cancel.call()
	m.on_cancel = cancel
	yes.pressed.connect(func():
		m.close()
		on_confirm.call())
	no.pressed.connect(cancel)
	no.grab_focus()
	return m


static func _message_body(m: Win95Modal, text: String, icon: String) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = m.body.size
	var tex := Win95IconCatalog.texture(icon, "large")
	var lines := Win95Draw.font().wrap(text, 275)
	var draw_cb := func():
		Win95Draw.icon(holder, tex, Vector2(9, 10))
		Win95Draw.text(holder, Vector2(51, 10), text, Win95Draw.TEXT, {"wrap": true, "max_width": 275})
	holder.draw.connect(draw_cb)
	m.body.add_child(holder)
	holder.queue_redraw()
	if lines.is_empty():
		return
