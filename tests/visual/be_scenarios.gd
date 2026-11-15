class_name BeScenarios
extends RefCounted
## Capture-view drivers for the Be shell ("be" and "be-*" views). Drive the real shell through automation ids
## (documented in tests/visual/BE_AUTOMATION_IDS.md) with injected input events.
##   be, be-folder, be-details, be-mini, be-zoom, be-menu, be-context, be-bg-context, be-desk-context, be-deskbar,
##   be-deskbar-sub, be-getinfo, be-rename, be-trash, be-newfolder, be-find, be-find-results, be-about, be-launch,
##   be-two-windows, be-hidden, be-quicksearch, be-tools, be-switch, be-move, be-resize, be-close, be-trash-confirm, be-newfolder-ok, be-dark, be-dark-folder, be-scale3


static func run(view: String, a: Automation, host: Node) -> void:
	await a.move(Vector2(300, 460))
	await a.wait_ms(60)
	match view:
		"be":
			pass
		"be-folder", "be-scale3":
			await _open_group(a, "main")
		"be-details":
			await _open_group(a, "main")
			await _choose_view(a, "List View")
		"be-mini":
			await _open_group(a, "main")
			await _choose_view(a, "Mini Icon View")
		"be-zoom":
			await _open_group(a, "main")
			await a.click_id("be.window.active:zoom")
		"be-menu":
			await _open_group(a, "main")
			await a.click_id("be.window.active:menu:view")
			await a.wait_ms(80)
		"be-context":
			await _open_group(a, "main")
			await a.click_id("be.window.active:entry:0")
			await a.rclick_id("be.window.active:entry:0")
			await a.wait_ms(80)
		"be-bg-context":
			await _open_group(a, "main")
			await a.rclick(a.center("be.window.active:content") + Vector2(60, 90))
			await a.wait_ms(80)
		"be-desk-context":
			await a.rclick(Vector2(300, 440))
			await a.wait_ms(80)
		"be-deskbar":
			await a.click_id("be.deskbar.logo")
			await a.wait_ms(100)
		"be-deskbar-sub":
			await _open_group(a, "main")
			await a.click_id("be.deskbar.logo")
			await a.wait_ms(100)
			await a.hover_id("be.popup-item:Main")
			await a.wait_ms(120)
		"be-getinfo":
			await _open_group(a, "main")
			await a.rclick_id("be.window.active:entry:1")
			await a.click_id("be.popup-item:Get Info")
			await a.wait_ms(150)
		"be-rename":
			await _open_group(a, "main")
			await a.rclick_id("be.window.active:entry:2")
			await a.click_id("be.popup-item:Edit Name")
			await a.wait_ms(150)
		"be-trash":
			await _open_group(a, "main")
			await a.rclick_id("be.window.active:entry:3")
			await a.click_id("be.popup-item:Move to Trash")
			await a.wait_ms(150)
		"be-newfolder":
			await a.rclick(Vector2(300, 440))
			await a.click_id("be.popup-item:New Folder")
			await a.wait_ms(150)
		"be-find", "be-find-results":
			await a.rclick(Vector2(300, 440))
			await a.click_id("be.popup-item:Find…")
			await a.wait_ms(150)
			await _nudge_find_left(a)
			if view == "be-find-results":
				await a.click_id("be.find.run")
				await a.wait_ms(120)
				await a.click_id("be.find.result:1")
				await a.wait_ms(60)
		"be-about":
			await a.click_id("be.deskbar.logo")
			await a.click_id("be.popup-item:About Program Manager...")
			await a.wait_ms(150)
		"be-launch":
			ProgramStore.add_item("main", {"name": "Harmless", "path": "/usr/bin/true", "icon": "terminal", "workingDir": ""})
			await _open_group(a, "main")
			await a.wait_ms(100)
			await a.dblclick_id("be.window.active:entry:8")
			await a.wait_ms(20)
		"be-two-windows":
			await _open_group(a, "main")
			await _open_group(a, "accessories")
		"be-move":
			await _open_group(a, "main")
			var tab := a.center("be.window.active:tab")
			await a.drag(tab, tab + Vector2(-90, 40), 4, true)
			await a.wait_ms(60)
		"be-resize":
			await _open_group(a, "main")
			var grip := a.center("be.window.active:grip")
			await a.drag(grip, grip + Vector2(-60, -50), 4, true)
			await a.wait_ms(60)
		"be-close":
			await _open_group(a, "main")
			await a.click_id("be.window.active:close")
			await a.wait_ms(60)
		"be-trash-confirm":
			await _open_group(a, "main")
			await a.rclick_id("be.window.active:entry:3")
			await a.click_id("be.popup-item:Move to Trash")
			await a.wait_ms(100)
			await a.click_id("be.dialog.button:Yes")
			await a.wait_ms(100)
		"be-newfolder-ok":
			await a.rclick(Vector2(300, 440))
			await a.click_id("be.popup-item:New Folder")
			await a.wait_ms(120)
			await a.type_text("Zeta")
			await a.key(KEY_ENTER)
			await a.wait_ms(120)
		"be-quicksearch":
			Platform.trigger_quick_search()
			await a.wait_ms(150)
			await a.type_text("co")
			await a.key(KEY_ENTER)
			await a.wait_ms(120)
		"be-tools":
			await a.click_id("be.deskbar.tools")
			await a.wait_ms(200)
		"be-switch":
			await _switch_shell(host, "win95")
			await a.wait_ms(200)
			await _switch_shell(host, "be")
			await a.wait_ms(200)
			await _open_group(a, "main")
		"be-hidden":
			await _open_group(a, "main")
			await a.click_id("be.deskbar.task:g:main")
			await a.wait_ms(100)
		"be-dark", "be-dark-folder":
			await a.rclick(Vector2(300, 440))
			await a.click_id("be.popup-item:Backgrounds…")
			await a.wait_ms(120)
			await a.click_id("be.dialog.dark")
			await a.click_id("be.dialog.button:OK")
			await a.wait_ms(120)
			if view == "be-dark-folder":
				await _open_group(a, "main")
				await a.click_id("be.window.active:entry:0")
		_:
			pass


## At 640 px wide the default Find window runs under the Deskbar; drag it left like a user would.
static func _nudge_find_left(a: Automation) -> void:
	var tab := a.center("be.window.active:tab")
	await a.drag(tab, tab + Vector2(-110, 24), 4, true)
	await a.wait_ms(80)


## Switches shell through the settings transaction, as Launcher Tools > Apply does.
static func _switch_shell(host: Node, shell: String) -> void:
	var next: Dictionary = ProgramStore.settings.duplicate(true)
	next["shell"] = shell
	ProgramStore.apply_settings_transaction(next)
	await host.get_tree().process_frame


static func _open_group(a: Automation, gid: String) -> void:
	await a.dblclick_id("be.desktop-icon:g:" + gid)
	await a.wait_ms(120)


static func _choose_view(a: Automation, label: String) -> void:
	await a.click_id("be.window.active:menu:view")
	await a.wait_ms(60)
	await a.click_id("be.popup-item:" + label)
	await a.wait_ms(100)
