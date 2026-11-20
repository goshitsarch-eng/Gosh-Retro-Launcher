extends SceneTree
## Exercises the real WfW system menu in a desktop session.
## godot --path . --script tests/visual/window_flow.gd

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This test needs a desktop session.")
		quit(2)
		return
	var profile := DirAccess.create_temp("program-manager-window-test")
	if profile == null:
		printerr("Could not create a temporary profile.")
		quit(2)
		return
	OS.set_environment("PM_USER_DATA", profile.get_current_dir())
	OS.set_environment("PM_NO_SINGLE_INSTANCE", "1")
	OS.set_environment("PM_FORCE_DPR", "1")
	change_scene_to_file("res://src/app/main.tscn")
	await scene_changed
	var platform := root.get_node("Platform")
	var input := Automation.new(self)
	await input.wait_ms(800)
	var work := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	for offset in [Vector2i(40, 40), Vector2i.ZERO]:
		root.position = work.position + offset
		root.size = Vector2i(640, 480)
		await input.wait_ms(200)
		var normal: Rect2i = platform.get_window_bounds()
		for cycle in 2:
			for maximize in [true, false]:
				var command := "Maximize" if maximize else "Restore"
				await input.click_id("wfw.system-button")
				await input.frames(2)
				await input.click_id("wfw.popup-item:" + command)
				await input.wait_ms(650)
				var bounds: Rect2i = platform.get_window_bounds()
				var enlarged := bounds.size != normal.size and bounds.size.x >= normal.size.x and bounds.size.y >= normal.size.y
				var correct_size: bool = enlarged if maximize else bounds == normal
				var passed: bool = platform.is_window_maximized() == maximize and correct_size
				print("%s %s (cycle %d, %s) %s" % ["PASS" if passed else "FAIL", command, cycle + 1, offset, bounds])
				if not passed:
					quit(1)
					return
	quit(0)
