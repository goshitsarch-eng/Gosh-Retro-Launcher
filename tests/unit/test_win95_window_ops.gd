extends TestCase
## Extra coverage for the minimize/restore/maximize/close/apply operations shared by the window
## chrome and the taskbar (Win95WindowStore), plus DOM key translation of the input controller.

const STORE_SCRIPT := preload("res://src/core/program_store.gd")


func _make() -> Array:
	var store: Node = STORE_SCRIPT.new()
	store.groups = [{
		"id": "g", "name": "g", "icon": "folder",
		"windowState": Types.default_window_state(),
		"shellWindowState": Types.create_shell_window_state(),
		"items": [],
	}]
	store.settings = Types.default_settings()
	store.settings["shell"] = "win95"
	store.settings["saveSettingsOnExit"] = false
	return [store, Win95WindowStore.new(store)]


func test_group_maximize_remembers_and_restores_the_normal_bounds() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_group("g")
	var e := w.find_entry("group:g")
	w.maximize_entry(e)
	expect(w.entry_is_maximized(e))
	var s := Types.get_group_window_state(store.find_group("g"), "win95")
	expect_eq(s.restoreWidth, 300)
	w.restore_entry(e)
	expect(not w.entry_is_maximized(e))
	expect_eq(w.entry_rect(e), {"x": 20, "y": 20, "width": 300, "height": 200})
	store.free()


func test_system_window_minimize_restore_and_taskbar_style_apply_rect() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_my_computer()
	var e := w.find_entry("my-computer")
	w.minimize_entry(e)
	expect(w.entry_is_minimized(e))
	expect_eq(w.active_window_id, "")
	w.restore_entry(e)
	expect(not w.entry_is_minimized(e))
	expect_eq(w.active_window_id, "my-computer")
	w.apply_rect(e, Win95Geometry.rect(18, 18, 400, 250))
	expect_eq(w.entry_rect(e), {"x": 18, "y": 18, "width": 400, "height": 250})
	w.maximize_entry(e)
	expect_eq(e.systemRestoreBounds, {"x": 18, "y": 18, "width": 400, "height": 250})
	w.maximize_entry(e)  # toggles back
	expect(not w.entry_is_maximized(e))
	store.free()


func test_close_entry_clears_minimized_flag_and_removes_the_window() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_group("g")
	var e := w.find_entry("group:g")
	w.minimize_entry(e)
	w.close_entry(e)
	expect_eq(w.windows.size(), 0)
	expect_eq(Types.get_group_window_state(store.find_group("g"), "win95").minimized, false)
	store.free()


func test_cycle_order_uses_z_order() -> void:
	var made := _make()
	var store: Node = made[0]
	var w: Win95WindowStore = made[1]
	w.open_my_computer()
	w.open_find()
	expect_eq(w.by_z().map(func(e): return e.id), ["my-computer", "find"])
	w.focus_window("my-computer")
	expect_eq(w.by_z().map(func(e): return e.id), ["find", "my-computer"])
	store.free()


func test_key_names_follow_dom_conventions() -> void:
	var cases := [[KEY_ESCAPE, "Escape"], [KEY_UP, "ArrowUp"], [KEY_MENU, "ContextMenu"], [KEY_F10, "F10"],
		[KEY_SPACE, " "], [KEY_ALT, "Alt"], [KEY_META, "Meta"], [KEY_PAGEDOWN, "PageDown"]]
	for c in cases:
		var ev := InputEventKey.new()
		ev.keycode = c[0]
		expect_eq(Win95InputController.key_name(ev), c[1], str(c[0]))
	var a := InputEventKey.new()
	a.keycode = KEY_A
	a.unicode = "a".unicode_at(0)
	a.ctrl_pressed = true
	var dom := Win95InputController.to_dom(a)
	expect_eq(dom.key, "a")
	expect_eq(dom.ctrlKey, true)
	expect_eq(Win95ShellInput.route_shortcut(dom), "")
