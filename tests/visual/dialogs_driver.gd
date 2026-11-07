extends Control
## Stand-alone visual driver for the Win31 dialogs (the real WfW shell is built elsewhere).
## Mounts Win31DialogLayer / Win31QuickSearch / Win31LaunchFeedback over a grey background,
## opens a dialog through UIState and saves a screenshot.
##   godot --path . res://tests/visual/dialogs_driver.tscn -- --view=about --out=artifacts/dlg-about.png
## Views: about new-dialog run-dialog exit-confirm item-properties wfw-move-dialog wfw-copy-dialog
## wfw-group-properties wfw-new-group new-item confirm change-icon help help-search settings new-url
## welcome quick-search quick-search-empty launch-feedback

const FIXTURES := preload("res://tests/visual/fixtures.gd")

var layer: Win31DialogLayer
var qs: Win31QuickSearch
var feedback: Win31LaunchFeedback
var shot_override: Image


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var view: String = args.get("view", "about")
	var flow_mode: bool = args.has("flow")
	var out: String = args.get("out", "artifacts/dlg-%s.png" % view)
	var profile := "%s/pm-dlg-%d" % [OS.get_environment("TMPDIR") if OS.get_environment("TMPDIR") != "" else "/tmp", OS.get_process_id()]
	DirAccess.make_dir_recursive_absolute(profile)
	var f := FileAccess.open(profile.path_join("program-manager-data.json"), FileAccess.WRITE)
	f.store_string(Jsonx.stringify(FIXTURES.data_for("workspace"), "  "))
	f.close()
	ProgramStore.init_store(profile)
	Engine.set_meta("pm_capture", true)
	get_window().size = Vector2i(640, 480)
	ShellScale.apply(get_window(), 1.0)
	var bg := ColorRect.new()
	bg.color = Pal.FACE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	layer = Win31DialogLayer.new()
	qs = Win31QuickSearch.new()
	feedback = Win31LaunchFeedback.new()
	add_child(feedback)
	add_child(qs)
	add_child(layer)
	await get_tree().process_frame
	await get_tree().process_frame
	if flow_mode:
		await _flows()
		get_tree().quit()
		return
	await _open(view)
	for i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if args.has("dump"):
		_dump(layer, 0)
	var img := shot_override if shot_override else get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print(out)
	get_tree().quit()


func _open(view: String) -> void:
	var groups: Array = ProgramStore.groups
	var main: Dictionary = groups[0]
	var item: Dictionary = main.items[0]
	match view:
		"about": UIState.open_dialog("about")
		"new-dialog": UIState.open_dialog("newObject", {"groupId": main.id})
		"run-dialog": UIState.open_dialog("run")
		"exit-confirm": UIState.open_dialog("exitWindows")
		"item-properties": UIState.open_dialog("itemProperties", {"groupId": main.id, "item": item})
		"new-item": UIState.open_dialog("newItem", {"groupId": main.id})
		"wfw-move-dialog": UIState.open_dialog("moveItem", {"groupId": main.id, "item": item})
		"wfw-copy-dialog": UIState.open_dialog("copyItem", {"groupId": main.id, "item": item})
		"wfw-group-properties": UIState.open_dialog("groupProperties", {"group": groups[1]})
		"wfw-new-group": UIState.open_dialog("newGroup")
		"confirm": UIState.open_dialog("confirm", {"confirmOptions": {"title": "Delete Program Item",
			"message": "Delete the program item “%s”?" % item.name, "onConfirm": func(): pass}})
		"change-icon": UIState.open_dialog("changeIcon", {"groupId": main.id, "item": item})
		"help": UIState.open_dialog("help", {"helpTopic": "contents"})
		"help-search": UIState.open_dialog("help", {"helpTopic": "search"})
		"settings": UIState.open_dialog("settings")
		"new-url": UIState.open_dialog("newUrl", {"groupId": main.id})
		"welcome": UIState.open_dialog("welcome")
		"quick-search":
			UIState.open_quick_search()
			await get_tree().process_frame
			qs.dialog().field.text = "m"
			qs.dialog().results.set_query("m")
		"quick-search-empty":
			UIState.open_quick_search()
			await get_tree().process_frame
			qs.dialog().field.text = "zzz"
			qs.dialog().results.set_query("zzz")
		"tools":
			var w := LauncherToolsWindow.show_singleton(self)
			w.position = Vector2i(0, 0)
			await get_tree().create_timer(0.6).timeout
			shot_override = w.get_texture().get_image()
		"launch-feedback": UIState.begin_launch_feedback(3, 5); UIState.update_launch_feedback(2, 1)


func _dump(n: Node, depth: int) -> void:
	if n is W31TextField:
		print("TF ", n.position, n.size, " edit ", n.edit.position, n.edit.size, " min ", n.edit.get_combined_minimum_size(), n.edit.get_minimum_size(), " fh ", n.edit.get_theme_font("font").get_height(11), n.edit.get_theme_font_size("font_size"), n.edit.get_theme_stylebox("normal").get_minimum_size(), n.edit.get_theme_font_size("font_size"))
	for c in n.get_children():
		_dump(c, depth + 1)


var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _flows() -> void:
	var a := Automation.new(get_tree())
	# 1. New Program Object -> Program Group -> OK -> New Program Group -> type -> Enter
	var n0 := ProgramStore.groups.size()
	UIState.open_dialog("newObject", {"groupId": "main"})
	await a.frames(3)
	_check(a.has("wfw.dialog.radio:Program Group"), "radio automation id present")
	await a.click_id("wfw.dialog.radio:Program Group")
	await a.click_id("wfw.dialog.button:OK")
	await a.frames(3)
	_check(UIState.active_dialog == "newGroup", "OK on Program Group opens newGroup (got %s)" % UIState.active_dialog)
	var ok_btn: W31Button = layer.current_dialog().default_button
	_check(ok_btn.disabled, "New Program Group OK disabled while blank")
	await a.key(KEY_ENTER)
	_check(UIState.active_dialog == "newGroup", "Enter on disabled default does nothing")
	print("FOCUS ", get_viewport().gui_get_focus_owner(), " field=", layer.current_dialog().field.edit)
	await a.type_text("zed")
	await a.frames(2)
	print("TEXT '", layer.current_dialog().field.text, "'")
	_check(not ok_btn.disabled, "OK enabled after typing")
	await a.key(KEY_ENTER)
	await a.frames(3)
	_check(UIState.active_dialog == "" and ProgramStore.groups.size() == n0 + 1 and ProgramStore.groups[n0].name == "zed",
		"Enter submits default button and creates group (%d groups)" % ProgramStore.groups.size())
	# 2. Escape cancels
	UIState.open_dialog("run")
	await a.frames(3)
	await a.key(KEY_ESCAPE)
	await a.frames(2)
	_check(UIState.active_dialog == "", "Esc closes Run")
	# 3. Tab traversal wraps and keeps focus in the dialog
	UIState.open_dialog("newObject", {"groupId": "main"})
	await a.frames(3)
	var seen := {}
	for i in 8:
		await a.key(KEY_TAB)
		var fo := get_viewport().gui_get_focus_owner()
		seen[str(fo.get_instance_id()) if fo else "none"] = true
	_check(seen.size() == 4 and not seen.has("none"), "Tab cycles through 4 stops (%d distinct)" % seen.size())
	await a.key(KEY_ESCAPE)
	# 4. Alt+access key selects radio
	UIState.open_dialog("newObject", {"groupId": "main"})
	await a.frames(3)
	await a.key(KEY_G, {"alt": true})
	await a.frames(1)
	await a.key(KEY_ENTER)
	await a.frames(3)
	_check(UIState.active_dialog == "newGroup", "Alt+G then Enter -> newGroup")
	await a.key(KEY_ESCAPE)
	# 5. Item properties edit via keyboard
	var item: Dictionary = ProgramStore.groups[0].items[0]
	UIState.open_dialog("itemProperties", {"groupId": "main", "item": item})
	await a.frames(3)
	await a.key(KEY_TAB)  # command line
	await a.type_text("/bin/ls")
	await a.key(KEY_ENTER)
	await a.frames(3)
	_check(UIState.active_dialog == "" and ProgramStore.find_item("main", item.id).path == "/bin/ls", "item properties Enter saves path")
	# 6. drag the dialog by its title bar
	UIState.open_dialog("about")
	await a.frames(3)
	var d := layer.current_dialog()
	var p0 := d.position
	await a.drag(p0 + Vector2(100, 9), p0 + Vector2(140, 29), 4, true)
	await a.frames(2)
	_check(d.position == p0 + Vector2(40, 20), "title bar drag moves dialog by (40,20): %s" % str(d.position - p0))
	await a.key(KEY_ESCAPE)
	# 7. modal: clicks on the backdrop do nothing
	UIState.open_dialog("about")
	await a.frames(3)
	await a.click(Vector2(5, 5))
	_check(UIState.active_dialog == "about", "backdrop click does not dismiss")
	await a.click_id("wfw.dialog.button:OK")
	await a.frames(2)
	_check(UIState.active_dialog == "", "OK closes About")
	# 8. Confirm Yes/No callbacks
	var hit := []
	UIState.open_dialog("confirm", {"confirmOptions": {"title": "T", "message": "Sure?", "onConfirm": func(): hit.append("yes"), "onCancel": func(): hit.append("no")}})
	await a.frames(3)
	await a.key(KEY_ENTER)
	await a.frames(2)
	_check(hit == ["yes"] and UIState.active_dialog == "", "Confirm: Enter = Yes")
	UIState.open_dialog("confirm", {"confirmOptions": {"title": "T", "message": "Sure?", "onConfirm": func(): hit.append("yes"), "onCancel": func(): hit.append("no")}})
	await a.frames(3)
	await a.key(KEY_ESCAPE)
	await a.frames(2)
	_check(hit == ["yes", "no"], "Confirm: Esc = No/cancel")
	# 9. Move dialog
	var g_before: int = ProgramStore.find_group("accessories").items.size()
	UIState.open_dialog("moveItem", {"groupId": "main", "item": ProgramStore.groups[0].items[1]})
	await a.frames(3)
	await a.key(KEY_ENTER)
	await a.frames(3)
	_check(ProgramStore.find_group("accessories").items.size() == g_before + 1, "Move OK moves item to first destination group")
	# 10. Quick search
	UIState.open_quick_search()
	await a.frames(3)
	await a.type_text("fi")
	await a.frames(2)
	_check(qs.dialog().results.displayed().size() > 0, "quick search shows results for 'fi'")
	await a.key(KEY_DOWN)
	await a.key(KEY_UP)
	await a.key(KEY_ESCAPE)
	await a.frames(2)
	_check(not UIState.quick_search_open and not qs.is_open(), "Esc closes quick search")
	UIState.open_quick_search()
	await a.frames(3)
	await a.click(Vector2(3, 3))
	await a.frames(2)
	_check(not UIState.quick_search_open, "click on backdrop closes quick search")
	# 11. launch feedback state
	UIState.begin_launch_feedback(2, 4)
	await a.frames(2)
	_check(feedback.visible, "feedback visible while launching")
	UIState.finish_launch_feedback(0)
	await a.frames(2)
	_check(feedback.layout().title == "Launched 4 items", "feedback title after finish")
	UIState.hide_launch_feedback()
	await a.frames(1)
	_check(not feedback.visible, "feedback hidden")
	print("FLOW DONE fails=%d" % _fails)
