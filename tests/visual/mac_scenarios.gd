class_name MacScenarios
extends RefCounted
## Capture-view drivers for the Mac shell ("mac" and "mac-*" views). They drive the real shell through
## injected input addressed by automation ids (tests/visual/MAC_AUTOMATION_IDS.md), never private state.
##   mac, mac-menu, mac-menu-logo, mac-menu-special, mac-app-menu, mac-folder, mac-folder-list, mac-folder-selected,
##   mac-getinfo, mac-getinfo-group, mac-context, mac-desk-context, mac-folder-context, mac-trash, mac-find,
##   mac-rename, mac-new-folder, mac-about, mac-help, mac-run, mac-desktop-pictures, mac-shade, mac-zoom,
##   mac-drag, mac-resize, mac-launch, mac-dark, mac-dark-folder, mac-scale2, mac-scale3,
##   mac-close, mac-trash-done, mac-rename-done, mac-new-folder-done, mac-getinfo-done, mac-shortcuts, mac-quick-search,
##   mac-shutdown, mac-switch (Shut Down > Switch to the Windows 95 shell)


static func _open_main(a: Automation) -> void:
	await a.dblclick_id("mac.folder-item:Main")
	await a.wait_ms(120)


static func _menu(a: Automation, name: String) -> void:
	await a.click_id("mac.menu:" + name)
	await a.wait_ms(80)


static func _pick(a: Automation, label: String) -> void:
	await a.click_id("mac.popup-item:" + label)
	await a.wait_ms(120)


static func run(view: String, a: Automation, _host: Node) -> void:
	if view == "mac-menu-sweep":
		# Menu click-through: every static item of the Mac menu bar, each followed by Escape. Skipped on purpose:
		# "Restart" (restarts the app), "Launcher Tools…" (separate OS window), and the per-group Launch entries.
		# Setup: open Main and select its first item, so the View and selection-dependent File items are enabled.
		await _open_main(a)
		await a.click_id("mac.folder-item:1")
		await a.wait_ms(60)
		# Order matters: View needs the folder window, Close Window ends it, Move To Trash removes the selection.
		var sweep := {
			"logo": ["About Program Manager…", "Desktop Pictures…", "Find…"],
			"View": ["as Icons", "as List"],
			"Edit": ["Undo", "Cut", "Copy", "Paste", "Clear", "Select All"],
			"File": ["New Folder", "Open", "Get Info", "Duplicate", "Find…", "Move To Trash", "Close Window"],
			"Special": ["Launch All", "Run…", "Shut Down"],
			"Help": ["Program Manager Help", "Show Balloons"],
		}
		for title in sweep:
			for label in sweep[title]:
				await a.click_id("mac.menu:" + title)
				await a.wait_ms(60)
				if not a.has("mac.popup-item:" + label):
					print("SWEEP_SKIP mac menu=%s item=%s" % [title, label])
					continue
				print("SWEEP mac menu=%s item=%s" % [title, label])
				await a.click_id("mac.popup-item:" + label)
				await a.wait_ms(120)
				await a.key(KEY_ESCAPE)
				await a.wait_ms(60)
				await a.key(KEY_ESCAPE)
				await a.wait_ms(60)
		print("SWEEP_DONE mac")
		return
	await a.move(Vector2(600, 300))
	await a.wait_ms(40)
	var folder_views := ["mac-folder", "mac-folder-list", "mac-folder-selected", "mac-getinfo", "mac-context", "mac-trash",
		"mac-shade", "mac-zoom", "mac-drag", "mac-resize", "mac-launch", "mac-dark-folder", "mac-folder-context", "mac-rename",
		"mac-close", "mac-trash-done", "mac-rename-done", "mac-getinfo-done"]
	if folder_views.has(view):
		await _open_main(a)
	match view:
		"mac-menu":
			await _menu(a, "File")
		"mac-menu-logo":
			await _menu(a, "logo")
		"mac-menu-special":
			await _menu(a, "Special")
		"mac-app-menu":
			await _menu(a, "app")
		"mac-folder-list":
			await _menu(a, "View")
			await _pick(a, "as List")
		"mac-folder-selected", "mac-getinfo", "mac-context", "mac-trash", "mac-rename", "mac-launch", "mac-trash-done", "mac-rename-done", "mac-getinfo-done":
			await a.click_id("mac.folder-item:1")
			await a.wait_ms(60)
		"mac-shade":
			await a.click_id("mac.window.active:shade")
		"mac-zoom":
			await a.click_id("mac.window.active:zoom")
		"mac-drag":
			await a.drag(a.center("mac.window.active:title") - Vector2(60, 0), Vector2(250, 250), 5, true)
		"mac-resize":
			await a.drag(a.center("mac.window.active:grip"), Vector2(560, 440), 5, true)
		"mac-desk-context":
			await a.rclick(Vector2(250, 340))
		"mac-folder-context":
			await a.rclick(a.center("mac.folder-view") + Vector2(80, 80))
		"mac-about":
			await _menu(a, "logo")
			await _pick(a, "About Program Manager…")
		"mac-help":
			await _menu(a, "Help")
			await _pick(a, "Program Manager Help")
		"mac-run":
			await _menu(a, "Special")
			await _pick(a, "Run…")
		"mac-desktop-pictures":
			await _menu(a, "logo")
			await _pick(a, "Desktop Pictures…")
		"mac-new-folder":
			await _menu(a, "File")
			await _pick(a, "New Folder")
		"mac-find":
			await _menu(a, "File")
			await _pick(a, "Find…")
			await a.type_text("co")
			await a.click_id("mac.find.run")
			await a.wait_ms(100)
		"mac-close":
			await a.click_id("mac.window.active:close")
		"mac-new-folder-done":
			await _menu(a, "File")
			await _pick(a, "New Folder")
			await a.type_text("x")
			await a.key(KEY_ENTER)
			await a.wait_ms(120)
		"mac-shortcuts":
			await a.key(KEY_N, {"ctrl": true})
		"mac-quick-search":
			_host.shell.toggle_quick_search()
			await a.wait_ms(100)
			await a.type_text("m")
			await a.key(KEY_ENTER)
		"mac-shutdown":
			await _menu(a, "Special")
			await _pick(a, "Shut Down")
		"mac-switch":
			await _menu(a, "Special")
			await _pick(a, "Shut Down")
			await a.click_id("mac.shutdown:win95")
			await a.click_id("mac.dialog.button:OK")
			await a.wait_ms(300)
	match view:
		"mac-getinfo":
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
			await _pick(a, "Get Info")
		"mac-context":
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
		"mac-trash":
			await _menu(a, "File")
			await _pick(a, "Move To Trash")
		"mac-rename":
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
			await _pick(a, "Rename")
		"mac-launch":
			await a.dblclick_id("mac.folder-item:1")
			await a.wait_ms(100)
		"mac-trash-done":
			await _menu(a, "File")
			await _pick(a, "Move To Trash")
			await a.click_id("mac.dialog.button:Yes")
			await a.wait_ms(100)
		"mac-rename-done":
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
			await _pick(a, "Rename")
			await a.type_text("Ctl")
			await a.key(KEY_ENTER)
			await a.wait_ms(100)
		"mac-getinfo-done":
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
			await _pick(a, "Get Info")
			await a.click_id("mac.dialog.field:Target")
			await a.type_text("ab")
			await a.click_id("mac.dialog.select:Launch group")
			await a.click_id("mac.select-item:Group 2")
			await a.click_id("mac.dialog.button:OK")
			await a.wait_ms(100)
			await a.rclick_id("mac.folder-item:1")
			await a.wait_ms(80)
			await _pick(a, "Get Info")
	await a.wait_ms(60)
