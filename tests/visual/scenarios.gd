extends RefCounted
## Scenario drivers for every capture view. Port of the view branches in scripts/capture-wfw.cjs.
## They run against the *real* shells using injected input events and automation ids
## (see tests/visual/AUTOMATION_IDS.md), never private state.


## The original harness opened windows with bare `dblclick` events (no pointer press), which never selected the
## icon/item. Opening through the shell's window API reproduces that; the click path stays as a fallback.
static var _shell: Object = null


static func run(view: String, a: Automation, host: Node) -> void:
	_shell = host.get("shell") if host != null else null
	if view.begins_with("win95"):
		await _win95(view, a, host)
	elif view == "mac" or view.begins_with("mac-"):
		await MacScenarios.run(view, a, host)
	elif view == "be" or view.begins_with("be-"):
		await BeScenarios.run(view, a, host)
	else:
		await _wfw(view, a)


# ------------------------------------------------------------------ Win95

static func _open_my_computer(a: Automation) -> void:
	if _shell != null and _shell.get("windows") != null:
		_shell.windows.open_my_computer()
	else:
		await a.dblclick_id("w95.desktop-icon:my-computer")
	await a.wait_ms(120)


static func _open_first_folder_item(a: Automation) -> void:
	if _shell != null and _shell.get("windows") != null and ProgramStore.groups.size() > 0:
		_shell.windows.open_group(ProgramStore.groups[0].id)
	else:
		await a.dblclick_id("w95.folder-item:0")


static func _open_main_group(a: Automation) -> void:
	await _open_my_computer(a)
	await _open_first_folder_item(a)
	await a.wait_ms(120)


static func _open_start(a: Automation) -> void:
	await a.click_id("w95.start-button")
	await a.wait_ms(60)


static func _choose_view(a: Automation, label: String) -> void:
	await a.down_id("w95.window.active:menu:view")
	await a.wait_ms(60)
	await a.click_id("w95.popup-item:" + label)
	await a.wait_ms(100)


static func _open_find(a: Automation) -> void:
	await _open_start(a)
	await a.click_id("w95.start-command:Find")
	await a.wait_ms(80)
	await a.click_id("w95.start-level:1:first-command")
	await a.wait_ms(150)


static func _win95(view: String, a: Automation, host: Node = null) -> void:
	await a.move(Vector2(620, 3))
	await a.wait_ms(40)
	if view == "win95-selected":
		await a.down_id("w95.desktop-icon:first")
		await a.up(a.center("w95.desktop-icon:first"))
		await a.wait_ms(60)
	if view == "win95-keyboard-start":
		await a.key(KEY_ESCAPE, {"ctrl": true})
		await a.wait_ms(60)
		await a.key(KEY_DOWN)
		await a.wait_ms(60)
	if ["win95-start", "win95-programs", "win95-program-items", "win95-run", "win95-find", "win95-shutdown"].has(view):
		await _open_start(a)
	if view == "win95-programs" or view == "win95-program-items":
		await a.hover_id("w95.start-command:Programs")
		await a.wait_ms(300)
	if view == "win95-program-items":
		await a.hover_id("w95.start-level:1:first-command")
		await a.wait_ms(300)
	if view == "win95-run":
		await a.click_id("w95.start-command:Run...")
		await a.wait_ms(100)
	if view == "win95-find":
		await a.click_id("w95.start-command:Find")
		await a.wait_ms(60)
		await a.click_id("w95.start-level:1:first-command")
		await a.wait_ms(100)
	if view == "win95-shutdown":
		await a.click_id("w95.start-command:Shut Down...")
		await a.wait_ms(100)
	if view == "win95-my-computer" or view == "win95-group":
		await _open_my_computer(a)
	if view == "win95-group":
		await _open_first_folder_item(a)
		await a.wait_ms(100)
	if view == "win95-desktop-inactive":
		await a.down_id("w95.desktop-icon:my-computer")
		await a.up(a.center("w95.desktop-icon:my-computer"))
		await _open_my_computer(a)
	if view == "win95-desktop-marquee":
		await a.down(Vector2(1, 1))
		await a.move(Vector2(82, 226))
		await a.wait_ms(80)
	if view == "win95-settings":
		await _open_start(a)
		await a.hover_id("w95.start-command:Settings")
		await a.wait_ms(300)
	if view == "win95-taskbar-context":
		await a.rclick(Vector2(300, 470))
		await a.wait_ms(100)
	if view == "win95-task-context":
		await _open_my_computer(a)
		await a.rclick(Vector2(100, 470))  # the original harness dispatched contextmenu at clientX 100, clientY 470
		await a.wait_ms(100)
	if ["win95-folder-small", "win95-folder-list", "win95-folder-details", "win95-folder-multiselect"].has(view):
		await _open_main_group(a)
		if view == "win95-folder-small":
			await _choose_view(a, "Small Icons")
		if view == "win95-folder-list":
			await _choose_view(a, "List")
		if view == "win95-folder-details":
			await _choose_view(a, "Details")
		if view == "win95-folder-multiselect":
			for step in [[0, {}], [2, {"ctrl": true}], [4, {"shift": true}]]:
				var id := "w95.folder-item:%d" % step[0]
				await a.down(a.center(id), MOUSE_BUTTON_LEFT, step[1])
				await a.up(a.center(id), MOUSE_BUTTON_LEFT, step[1])
				await a.wait_ms(80)
	if view == "win95-window-inactive":
		await _open_my_computer(a)
		await _open_first_folder_item(a)
		await a.wait_ms(120)
	if view == "win95-window-maximized":
		await _open_my_computer(a)
		await a.click_id("w95.window.active:button:Maximize")
		await a.wait_ms(100)
	if view == "win95-window-minimized":
		await _open_my_computer(a)
		await a.click_id("w95.window.active:button:Minimize")
		await a.wait_ms(100)
	if view == "win95-menubar":
		await _open_my_computer(a)
		await a.down_id("w95.window.active:menu:file")
		await a.wait_ms(100)
	if ["win95-system-menu", "win95-move-outline", "win95-size-outline"].has(view):
		await _open_my_computer(a)
		await a.click_id("w95.window.active:caption-icon")
		await a.wait_ms(80)
		if view == "win95-move-outline" or view == "win95-size-outline":
			await a.click_id("w95.popup-item:" + ("Move" if view == "win95-move-outline" else "Size"))
			await a.key(KEY_RIGHT, {"shift": true})
			await a.key(KEY_DOWN, {"shift": true})
			await a.wait_ms(100)
	if view == "win95-folder-context":
		await _open_main_group(a)
		await a.rclick(Vector2(80, 100))
		await a.wait_ms(100)
	if ["win95-find-results", "win95-find-date", "win95-find-advanced"].has(view):
		await _open_find(a)
		if view == "win95-find-results":
			await a.click_id("w95.find-action:Find Now")
			await a.wait_ms(350)
		else:
			await a.click_id("w95.find-tab:" + ("Date Modified" if view == "win95-find-date" else "Advanced"))
			await a.wait_ms(100)
	if view == "win95-wizard":
		await a.rclick(Vector2(300, 250))
		await a.wait_ms(80)
		await a.click_id("w95.popup-item:New Shortcut")
		await a.wait_ms(120)
	if view == "win95-wizard-loop":
		# Leak probe: open and cancel the wizard repeatedly and report the live object count each time.
		for i in 6:
			await a.rclick(Vector2(300, 250))
			await a.wait_ms(80)
			await a.click_id("w95.popup-item:New Shortcut")
			await a.wait_ms(150)
			var can_cancel := a.has("w95.dialog.button:Cancel")
			await a.click_id("w95.dialog.button:Cancel")
			await a.wait_ms(150)
			print("WIZARD_LOOP iteration=%d cancel_found=%s objects=%d" % [i, can_cancel, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	if view == "win95-properties":
		await _open_my_computer(a)
		await a.rclick(Vector2(80, 100))
		await a.wait_ms(80)
		await a.click_id("w95.popup-item:Properties")
		await a.wait_ms(120)
	if view == "win95-message":
		# The original harness dispatched a bare `dblclick` event (no pointer press), so the icon stays unselected.
		if host != null and host.get("shell") != null:
			host.shell.desktop.open_icon("network-neighborhood")
		else:
			await a.dblclick_id("w95.desktop-icon:network-neighborhood")
		await a.wait_ms(120)
	if view == "win95-launch":
		ProgramStore.update_item("main", "main-0", {"path": "/usr/bin/touch", "arguments": _marker(view)})
		await _open_main_group(a)
		await a.dblclick_id("w95.folder-item:0")
		await a.wait_ms(800)
		_report_marker(view)
	if view == "win95-icon-context":
		await a.rclick(Vector2(40, 40))
		await a.wait_ms(120)
	await a.wait_ms(100)


# -------------------------------------------------------------------- WfW

static func _menu(a: Automation, index: int) -> void:
	await a.down_id("wfw.menu:%d" % index)
	await a.wait_ms(120)


static func _item(a: Automation, label: String) -> void:
	await a.click_id("wfw.popup-item:" + label)
	await a.wait_ms(300)


static func _select_first_item(a: Automation) -> void:
	await a.down_id("wfw.program-item:first")
	await a.up(a.center("wfw.program-item:first"))
	await a.wait_ms(150)


static func _wfw(view: String, a: Automation) -> void:
	if view == "menu-sweep-wfw":
		# Menu click-through: every item of the five WfW menus, each followed by Escape. Skipped on purpose:
		# "Exit Windows..." (quits the app) and "Launcher Tools..." (opens a separate OS window).
		# Setup: select the first program item, so the selection-dependent File items are enabled.
		await a.click_id("wfw.program-item:first")
		await a.wait_ms(60)
		# Delete goes last, so it cannot remove the selection the other items need.
		var sweep_items := ["New...", "Open", "Move...", "Copy...", "Properties...", "Delete", "Run...",
			"Auto Arrange", "Minimize on Use", "Save Settings on Exit", "Settings...", "Contents", "Search for Help On...",
			"How to Use Help", "About Program Manager...", "Cascade", "Tile", "Arrange Icons", "Launch All"]
		for menu_index in 5:
			for label in sweep_items:
				await a.click_id("wfw.menu:%d" % menu_index)
				await a.wait_ms(60)
				if not a.has("wfw.popup-item:" + label):
					print("SWEEP_SKIP wfw menu=%d item=%s (not in this menu)" % [menu_index, label])
					continue
				print("SWEEP wfw menu=%d item=%s" % [menu_index, label])
				await a.click_id("wfw.popup-item:" + label)
				await a.wait_ms(120)
				await a.key(KEY_ESCAPE)
				await a.wait_ms(60)
				await a.key(KEY_ESCAPE)
				await a.wait_ms(60)
		print("SWEEP_DONE wfw")
	if view == "launch-win31":
		ProgramStore.update_item("main", "main-0", {"path": "/usr/bin/touch", "arguments": _marker(view)})
		await a.wait_ms(200)
		await a.dblclick_id("wfw.program-item:first")
		await a.wait_ms(800)
		_report_marker(view)
		return
	# Runtime shell switching (settings change -> host flips frame/scale and remounts the shell).
	if view == "switch-to-win95" or view == "switch-roundtrip":
		ProgramStore.update_settings({"shell": "win95"})
		await a.wait_ms(600)
		if view == "switch-roundtrip":
			ProgramStore.update_settings({"shell": "win31"})
			await a.wait_ms(600)
			ProgramStore.update_settings({"shell": "win95"})
			await a.wait_ms(600)
			ProgramStore.update_settings({"shell": "win31"})
			await a.wait_ms(600)
		await a.wait_ms(100)
		return
	if view == "file" or view == "about":
		await _menu(a, 4 if view == "about" else 0)
	if view == "about":
		await _item(a, "About Program Manager")
		await a.wait_ms(200)
	if view == "options":
		await _menu(a, 1)
	if view == "window":
		await _menu(a, 2)
	if view == "help":
		await _menu(a, 4)
	if view == "new-dialog":
		await _menu(a, 0)
		await _item(a, "New...")
	if view == "run-dialog":
		await _menu(a, 0)
		await _item(a, "Run...")
	if view == "exit-confirm":
		await _menu(a, 0)
		await _item(a, "Exit Windows...")
	if view == "item-selected" or view == "item-properties":
		await _select_first_item(a)
		if view == "item-properties":
			await _menu(a, 0)
			await _item(a, "Properties...")
	if view == "group-maximized":
		await a.click_id("wfw.child-window:button:Maximize")
		await a.wait_ms(200)
	if view == "wfw-move-dialog" or view == "wfw-copy-dialog":
		await _select_first_item(a)
		await _menu(a, 0)
		await _item(a, "Move..." if view == "wfw-move-dialog" else "Copy...")
	if view == "wfw-group-properties":
		await a.down_id("wfw.minimized-group:first")
		await a.up(a.center("wfw.minimized-group:first"))
		await a.wait_ms(150)
		await _menu(a, 0)
		await _item(a, "Properties...")
	if view == "wfw-settings":
		# Options > Settings... ("Settings..." with the ellipsis: the id is a substring match and plain
		# "Settings" would hit "Save Settings on Exit").
		await _menu(a, 1)
		await _item(a, "Settings...")
	if view == "wfw-new-group":
		await _menu(a, 0)
		await _item(a, "New...")
		await a.click_id("wfw.dialog.radio:Program Group")
		await a.wait_ms(100)
		await a.click_id("wfw.dialog.button:OK")
		await a.wait_ms(300)
	await a.wait_ms(100)


# ---------------------------------------------------------- launch checks

static func _marker(view: String) -> String:
	var path := "%s/launched-%s.marker" % [OS.get_environment("PM_MARKER_DIR") if OS.get_environment("PM_MARKER_DIR") != "" else "/tmp", view]
	DirAccess.remove_absolute(path)
	return path


static func _report_marker(view: String) -> void:
	var dir := OS.get_environment("PM_MARKER_DIR") if OS.get_environment("PM_MARKER_DIR") != "" else "/tmp"
	var path := "%s/launched-%s.marker" % [dir, view]
	print("LAUNCH_RESULT %s %s" % [view, "OK" if FileAccess.file_exists(path) else "MISSING"])
