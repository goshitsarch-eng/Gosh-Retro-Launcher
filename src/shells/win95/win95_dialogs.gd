class_name Win95Dialogs
extends RefCounted
## Entry points the Win95 shell calls for dialogs and secondary windows. All are real implementations:
##   show_message(shell, title, text, icon = "information")    # OK box; icon: information|warning|critical|question
##   confirm(shell, title, message, on_confirm, on_cancel)       # Yes / No(default) box
##   open_run(shell)                  # Start > Run..., Win+R           (Win95DialogForms)
##   open_shutdown(shell)             # Start > Shut Down...            (Win95DialogForms)
##   open_find(shell)                 # single-instance Find primary window (Win95FindView)
##   open_wizard(shell, ctx)          # Create Shortcut wizard; ctx = {groupId?}
##   open_properties(shell, target)   # {kind: "item", groupId, item} | {kind: "group", group}  (Win95Properties)
##   open_new_folder(shell, ctx)      # ctx = {openItemAfterCreate?, openUrlAfterCreate?}
##   open_new_url(shell, ctx)         # ctx = {groupId?}
##   open_help(shell) / open_about(shell)
##   build_find_view(shell, window)   # the Find client Control hosted by Win95Window
## Building blocks for new dialogs: Win95Modal (frame, key routing), Win95Button/Checkbox/Radio/
## TextInput/Select/GroupBox/Label/IconBox/TabStrip/Rule. `shell` is the Win95Shell.

static func open_run(shell: Control) -> void:
	Win95DialogForms.open_run(shell)


static func open_shutdown(shell: Control) -> void:
	Win95DialogForms.open_shutdown(shell)


static func open_find(shell: Control) -> void:
	shell.windows.open_find()


static func open_wizard(shell: Control, ctx: Dictionary) -> void:
	Win95DialogForms.open_wizard(shell, ctx)


static func open_properties(shell: Control, target: Dictionary) -> void:
	if target.get("kind", "") == "group":
		Win95Properties.open_group(shell, target.get("group", {}))
	else:
		Win95Properties.open_item(shell, String(target.get("groupId", "")), target.get("item", {}))


static func open_new_folder(shell: Control, ctx: Dictionary) -> void:
	Win95DialogForms.open_new_folder(shell, ctx)


static func open_new_url(shell: Control, ctx: Dictionary) -> void:
	Win95DialogForms.open_new_url(shell, ctx)


static func open_help(shell: Control) -> void:
	Win95DialogForms.open_help(shell)


static func open_about(shell: Control) -> void:
	Win95DialogForms.open_about(shell)


static func build_find_view(shell: Control, window: Control) -> Control:
	var view := Win95FindView.new()
	view.setup(shell, window)
	return view


## OK message box (355x145 frame, 32px icon, wrapped text, default OK).
static func show_message(shell: Control, title: String, text: String, icon: String = "information") -> Win95Modal:
	var m := Win95Modal.open(shell, title, Vector2(355, 145))
	var y := _message_body(m, text, icon)
	var ok := Win95Button.new()
	ok.label = "OK"
	m.add(ok, Vector2(m.body.size.x - 9 - 75, y))
	m.set_default(ok)
	ok.pressed.connect(m.close)
	ok.grab_focus()
	return m


## Yes/No question box; No is the default (least destructive).
static func confirm(shell: Control, title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> Win95Modal:
	var m := Win95Modal.open(shell, title, Vector2(355, 145))
	var y := _message_body(m, message, "question")
	var yes := Win95Button.new()
	yes.label = "&Yes"
	var no := Win95Button.new()
	no.label = "&No"
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


## Icon + wrapped text row; returns the y of the button row (message margin collapses with 12px).
static func _message_body(m: Win95Modal, text: String, icon: String) -> float:
	var label := Win95Label.make(text, Vector2.ZERO, {"wrap": 275})
	m.add(Win95IconBox.make(icon, Vector2.ZERO), Vector2(9, 10))
	m.add(label, Vector2(51, 10))
	return 10.0 + maxf(32.0, label.size.y) + 12.0
