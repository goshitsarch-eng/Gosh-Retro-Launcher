class_name W31MessageDialogs
extends RefCounted
## Small Win31 dialogs that are only text + buttons: About, Confirm, Unavailable, Welcome, Exit Windows.


class About extends W31Dialog:
	func _init() -> void:
		super("About Program Manager", 360)

	func _build(_cw: int) -> void:
		add_image(W31Icons.catalog_texture("program-manager"), 20, 17, Vector2(48, 48))
		add_text(86, 13, "Program Manager", 14, {"bold": true, "line_height": 13})
		add_text(86, 29, "Version %s" % Platform.version(), 12, {"line_height": 14})
		add_text(86, 46, "Copyright (c) 2025", 12, {"line_height": 14})
		add_op(func(ci: CanvasItem):
			Px.hline(ci, 86, 68, 240, W31.SHADOW)
			Px.hline(ci, 86, 69, 240, W31.WHITE))
		var h := add_paragraph(86, 78, "Windows 3.11 Program Manager-compatible launcher", 240, 14, 12)
		var y := 78 + h + 3 + 5
		add_op(func(ci: CanvasItem):
			Px.hline(ci, 86, y, 240, W31.SHADOW)
			Px.hline(ci, 86, y + 1, 240, W31.WHITE))
		y += 2 + 5 + 3
		add_text(86, y, "Running on %s" % W31DialogLogic.platform_display_name(Platform.os_name()), 12, {"line_height": 14})
		var grid_bottom := y + 14
		var ok := make_button("OK", true, UIState.close_dialog)
		initial_focus = ok
		var top := grid_bottom + 8
		add_button_row(top, [ok])
		_finish(top + 4 + 22 + 8)


class Confirm extends W31Dialog:
	var options: Dictionary

	func _init(p_options: Dictionary) -> void:
		options = p_options
		super(String(p_options.get("title", "Program Manager")), 350)
		cancel_callable = _on_no

	func _build(cw: int) -> void:
		add_image(W31Icons.catalog_texture("question"), 10, 12)
		var msg_h := add_paragraph(52, 12, String(options.get("message", "")), cw - 20 - 32 - 10, 15, 12)
		var block := maxi(32, msg_h) + 20
		var yes := make_button("Yes", true, _on_yes)
		var no := make_button("No", false, _on_no)
		initial_focus = yes
		add_button_row(block, [yes, no])
		_finish(block + 4 + 22 + 8)

	func _on_yes() -> void:
		var cb: Variant = options.get("onConfirm")
		if cb is Callable and cb.is_valid():
			cb.call()
		UIState.close_dialog()

	func _on_no() -> void:
		var cb: Variant = options.get("onCancel")
		if cb is Callable and cb.is_valid():
			cb.call()
		UIState.close_dialog()


## 'unavailable' (Win95 MessageDialog in the original; reachable only through UIState): OK-only message.
class Unavailable extends W31Dialog:
	var data: Dictionary

	func _init(p_data: Dictionary) -> void:
		data = p_data
		super(String(p_data.get("title", "Program Manager")), 350)

	func _build(cw: int) -> void:
		add_image(W31Icons.catalog_texture("warning"), 10, 12)
		var msg_h := add_paragraph(52, 12, String(data.get("message", "This feature is not available.")), cw - 20 - 32 - 10, 15, 12)
		var block := maxi(32, msg_h) + 20
		var ok := make_button("OK", true, UIState.close_dialog)
		initial_focus = ok
		add_button_row(block, [ok])
		_finish(block + 4 + 22 + 8)


class ExitWindows extends W31Dialog:
	func _init() -> void:
		super("Exit Windows", 330)

	func _build(_cw: int) -> void:
		add_image(W31Icons.catalog_texture("question"), 12, 12)
		add_text(57, 22, "This will end your Program Manager session.")
		var ok := make_button("OK", true, func(): Platform.quit_app())
		var cancel := make_button("Cancel", false, UIState.close_dialog)
		var help := make_button("Help", false, func(): UIState.open_dialog("help", {"helpTopic": "contents"}))
		add_button_row(58, [ok, cancel, help])
		_finish(58 + 4 + 22 + 8)


class Welcome extends W31Dialog:
	func _init() -> void:
		super("Welcome to Program Manager", 400)

	func _build(cw: int) -> void:
		var mod := W31DialogLogic.welcome_mod_key(Platform.os_name())
		var y := 4  # inner padding 8px 4px minus nothing: content already has 8px
		add_image(W31Icons.catalog_texture("program-manager"), 4, 8 + y - 4, Vector2(48, 48))
		add_text(64, 8 + y + 6, "Program Manager", 11, {"bold": true})
		add_text(64, 8 + y + 6 + 15, "A retro launcher for your modern desktop", 11)
		var ry := 8 + 48 + 12
		add_op(func(ci: CanvasItem):
			Px.hline(ci, 4, ry + 8, int((cw - 8) * 0.8), W31.SHADOW)
			Px.hline(ci, 4, ry + 9, int((cw - 8) * 0.8), W31.WHITE))
		var ty := ry + 8 + 2 + 8
		add_text(4, ty, "Getting started:", 12, {"bold": true, "line_height": 18})
		ty += 18 + 4
		for line in ["Drag files into a group window to add programs", "Use File -> New to create items or groups",
				"Double-click an item to launch it", "Right-click items for properties"]:
			_bullet(4 + 16, ty, line)
			ty += 18
		ty += 8
		add_text(4, ty, "Quick Search:", 12, {"bold": true, "line_height": 18})
		ty += 18 + 4
		add_text(4 + 4, ty, "Press %s+Shift+Space anywhere to quickly find and launch programs." % mod, 12, {"line_height": 18})
		ty += 18 + 8
		add_text(4, ty, "Keyboard shortcuts:", 12, {"bold": true, "line_height": 18})
		ty += 18 + 4
		for line in ["Alt+F/O/W/H - Open menus", "Enter - Launch selected item", "Delete - Remove selected item", "Shift+F4/F5 - Tile / Cascade windows"]:
			_bullet(4 + 16, ty, line)
			ty += 18
		ty += 8
		var ok := make_button("OK", true, UIState.close_dialog)
		initial_focus = ok
		add_button_row(ty, [ok])
		_finish(ty + 4 + 22 + 8)

	func _bullet(x: int, y: int, text: String) -> void:
		add_op(func(ci: CanvasItem):
			Px.fill(ci, x - 11, y + 7, 4, 4, W31.BLACK)
			Px.fill(ci, x - 12, y + 8, 6, 2, W31.BLACK)
			Px.fill(ci, x - 10, y + 6, 2, 6, W31.BLACK))
		add_text(x, y, text, 12, {"line_height": 18})
