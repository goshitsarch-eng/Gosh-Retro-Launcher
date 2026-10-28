class_name TrayController
extends Node
## System tray (port of src/main/tray.ts) on Godot's StatusIndicator + PopupMenu.
##
## Menu: Show Program Manager, Launcher Tools..., Quick Search, separator, one submenu per group
## (disabled entry when the group is empty) launching the item through Platform.launch, separator,
## Exit. Rebuilt whenever groups change. Tooltip "Program Manager".
## Restore gestures (user guide platform table): Windows double-click, Linux click/double-click,
## macOS click opens the menu (handled natively by the OS when a menu is attached).

signal show_requested
signal launcher_tools_requested
signal quick_search_requested
signal quit_requested

const TOOLTIP := "Program Manager"
const DOUBLE_CLICK_MS := 500
const ICON_BY_OS := {
	"win32": "res://assets/icons/tray-win.png",
	"darwin": "res://assets/icons/tray-mac.png",
	"linux": "res://assets/icons/tray-linux.png",
}
const FALLBACK_ICON := "res://resources/icon.png"

var available := false
var _indicator: StatusIndicator
var _menu: PopupMenu
var _submenus: Array[PopupMenu] = []
var _last_left_press_ms := -100000
var _actions := {}  ## menu item id -> action id for the top-level menu


# ---------------------------------------------------------------- model (pure, unit-tested)

## Menu description. Entries: {kind: "action", id, label} | {kind: "separator"} |
## {kind: "submenu", label, items: [{label, group_id, item_id}]} | {kind: "disabled", label}.
static func build_model(groups: Array) -> Array:
	var model := [
		{"kind": "action", "id": "show", "label": "Show Program Manager"},
		{"kind": "action", "id": "launcher_tools", "label": "Launcher Tools..."},
		{"kind": "action", "id": "quick_search", "label": "Quick Search"},
		{"kind": "separator"},
	]
	if groups.size() > 0:
		for g in groups:
			var items: Array = g.get("items", [])
			var name := String(g.get("name", ""))
			if items.size() > 0:
				var entries := []
				for it in items:
					entries.append({"label": String(it.get("name", "")), "group_id": String(g.get("id", "")), "item_id": String(it.get("id", ""))})
				model.append({"kind": "submenu", "label": name, "items": entries})
			else:
				model.append({"kind": "disabled", "label": name})
		model.append({"kind": "separator"})
	model.append({"kind": "action", "id": "exit", "label": "Exit"})
	return model


## Icon texture for this OS with the same fallback chain as the Electron build (platform icon ->
## app icon -> small generated glyph).
static func load_icon(os_name: String) -> Texture2D:
	var path: String = ICON_BY_OS.get(os_name, ICON_BY_OS.linux)
	var tex := Assets.tex(path)
	if tex == null:
		tex = Assets.tex(FALLBACK_ICON)
	if tex == null:
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color8(0x00, 0x00, 0x80))
		img.fill_rect(Rect2i(2, 2, 12, 12), Color8(0xc0, 0xc0, 0xc0))
		tex = ImageTexture.create_from_image(img)
	return tex


# ---------------------------------------------------------------- lifecycle

## Creates the indicator. Returns false (and stays inert) when the platform has no tray.
func setup() -> bool:
	if available:
		return true
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return false
	_menu = PopupMenu.new()
	_menu.name = "TrayMenu"
	add_child(_menu)
	_menu.id_pressed.connect(_on_top_pressed)
	_indicator = StatusIndicator.new()
	_indicator.name = "TrayIndicator"
	_indicator.icon = load_icon(Launcher.platform())
	_indicator.tooltip = TOOLTIP
	add_child(_indicator)
	_indicator.menu = _indicator.get_path_to(_menu)
	_indicator.pressed.connect(_on_indicator_pressed)
	available = true
	rebuild()
	if not ProgramStore.groups_changed.is_connected(rebuild):
		ProgramStore.groups_changed.connect(rebuild)
	if not ProgramStore.data_reloaded.is_connected(rebuild):
		ProgramStore.data_reloaded.connect(rebuild)
	return true


func teardown() -> void:
	if ProgramStore.groups_changed.is_connected(rebuild):
		ProgramStore.groups_changed.disconnect(rebuild)
	if ProgramStore.data_reloaded.is_connected(rebuild):
		ProgramStore.data_reloaded.disconnect(rebuild)
	if _indicator:
		_indicator.queue_free()
		_indicator = null
	if _menu:
		_menu.queue_free()
		_menu = null
	_submenus.clear()
	available = false


func rebuild() -> void:
	if _menu == null:
		return
	_apply_model(build_model(ProgramStore.groups))


func _apply_model(model: Array) -> void:
	_menu.clear()
	for sm in _submenus:
		if is_instance_valid(sm):
			_menu.remove_child(sm)
			sm.queue_free()
	_submenus.clear()
	_actions.clear()
	var next_id := 1
	for entry in model:
		match entry.kind:
			"action":
				_menu.add_item(entry.label, next_id)
				_actions[next_id] = entry.id
				next_id += 1
			"separator":
				_menu.add_separator()
			"disabled":
				_menu.add_item(entry.label, next_id)
				_menu.set_item_disabled(_menu.item_count - 1, true)
				next_id += 1
			"submenu":
				var sub := PopupMenu.new()
				sub.name = "Group%d" % _submenus.size()
				_menu.add_child(sub)
				_submenus.append(sub)
				for i in entry.items.size():
					var e: Dictionary = entry.items[i]
					sub.add_item(e.label, i)
					sub.set_item_metadata(i, [e.group_id, e.item_id])
				sub.id_pressed.connect(_on_item_pressed.bind(sub))
				_menu.add_submenu_node_item(entry.label, sub, next_id)
				next_id += 1


func _on_top_pressed(id: int) -> void:
	match String(_actions.get(id, "")):
		"show":
			show_requested.emit()
		"launcher_tools":
			launcher_tools_requested.emit()
		"quick_search":
			quick_search_requested.emit()
		"exit":
			quit_requested.emit()


func _on_item_pressed(id: int, sub: PopupMenu) -> void:
	var idx := sub.get_item_index(id)
	var meta: Variant = sub.get_item_metadata(idx)
	if not (meta is Array) or meta.size() != 2:
		return
	var item := ProgramStore.find_item(String(meta[0]), String(meta[1]))
	if item.is_empty():
		return
	# Like tray.ts, launch the stored item directly (no IPC payload validation).
	var result: Dictionary = Launcher.launch_program(item)
	if not result.get("success", false):
		push_warning("Failed to launch item from tray: %s" % result.get("error", "unknown error"))


func _on_indicator_pressed(mouse_button: int, _pos: Vector2i) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	if should_restore(Launcher.platform(), Time.get_ticks_msec(), _last_left_press_ms):
		_last_left_press_ms = -100000
		show_requested.emit()
	else:
		_last_left_press_ms = Time.get_ticks_msec()


## Click policy: Windows needs a double-click (two left presses within DOUBLE_CLICK_MS), Linux
## (StatusNotifier hosts rarely deliver double-clicks) restores on any left click, and macOS
## shows the attached menu natively so a stray "pressed" also restores.
static func should_restore(os_name: String, now_ms: int, last_press_ms: int) -> bool:
	if os_name == "win32":
		return now_ms - last_press_ms <= DOUBLE_CLICK_MS
	return true
