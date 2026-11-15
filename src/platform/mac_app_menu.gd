class_name MacAppMenu
extends RefCounted
## macOS menu bar integration (no-op elsewhere): adds "Settings…" (Cmd+,) to the system application
## menu and "Launcher Tools…" / "Quick Search" to the Dock menu. The app name in the menu bar and the
## standard "About" panel (with the app icon) come from the exported bundle's Info.plist and
## icon.icns; Godot already provides About / Services / Hide / Quit there.

const SETTINGS_TAG := "pm.settings"
const TOOLS_TAG := "pm.tools"
const SEARCH_TAG := "pm.search"


## Index after the standard "About" entry and its separator (clamped to the menu size).
static func settings_index(item_count: int) -> int:
	return clampi(2, 0, maxi(0, item_count))


## Safe to call once per process; returns false when there is no native menu (other OS, headless).
static func install(on_settings: Callable, on_tools: Callable, on_search: Callable) -> bool:
	if OS.get_name() != "macOS" or DisplayServer.get_name() == "headless":
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_GLOBAL_MENU):
		return false
	var app := NativeMenu.get_system_menu(NativeMenu.APPLICATION_MENU_ID)
	if app.is_valid():
		var n := NativeMenu.get_item_count(app)
		NativeMenu.add_item(app, "Settings…", func(_tag: Variant) -> void: on_settings.call(), Callable(),
			SETTINGS_TAG, KEY_MASK_META | KEY_COMMA, settings_index(n))
		NativeMenu.add_separator(app, settings_index(n) + 1)
	var dock := NativeMenu.get_system_menu(NativeMenu.DOCK_MENU_ID)
	if dock.is_valid():
		NativeMenu.add_item(dock, "Launcher Tools…", func(_tag: Variant) -> void: on_tools.call(), Callable(), TOOLS_TAG)
		NativeMenu.add_item(dock, "Quick Search", func(_tag: Variant) -> void: on_search.call(), Callable(), SEARCH_TAG)
	return app.is_valid()
