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


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var view: String = args.get("view", "about")
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
	_open(view)
	for i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if args.has("dump"):
		_dump(layer, 0)
	var img := get_viewport().get_texture().get_image()
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
		"launch-feedback": UIState.begin_launch_feedback(3, 5); UIState.update_launch_feedback(2, 1)


func _dump(n: Node, depth: int) -> void:
	if n is W31TextField:
		print("TF ", n.position, n.size, " edit ", n.edit.position, n.edit.size, " min ", n.edit.get_combined_minimum_size(), n.edit.get_minimum_size(), " fh ", n.edit.get_theme_font("font").get_height(11), n.edit.get_theme_font_size("font_size"), n.edit.get_theme_stylebox("normal").get_minimum_size(), n.edit.get_theme_font_size("font_size"))
	for c in n.get_children():
		_dump(c, depth + 1)
