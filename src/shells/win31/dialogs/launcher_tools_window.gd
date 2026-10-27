class_name LauncherToolsWindow
extends Window
## Separate native "Launcher Tools" window (port of components/LauncherTools/LauncherTools.tsx).
## PLACEHOLDER — replaced by the dialogs agent.

static var _instance: LauncherToolsWindow


## Shows (or focuses) the single Launcher Tools window as a child of `host`.
static func show_singleton(host: Node) -> LauncherToolsWindow:
	if _instance == null or not is_instance_valid(_instance):
		_instance = LauncherToolsWindow.new()
		_instance.title = "Launcher Tools"
		_instance.size = Vector2i(680, 720)
		host.add_child(_instance)
	_instance.show()
	_instance.grab_focus()
	return _instance
