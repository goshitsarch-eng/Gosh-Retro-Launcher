class_name Win95InputController
extends Node
## The single Win95 input model (port of Win95InputController.tsx).
##
## Keyboard goes through four priority layers (modal -> menu -> window -> desktop); each key is
## consumed at most once. Bare Alt / Windows key are resolved on key-up (menu-bar mode / Start).
## Pointer handlers are "document level": they see every mouse event first (before the GUI
## controls) in reverse registration order and may consume it by returning true.
##
## Register with:
##   register_key("menu", "my-id", callable)       # callable(event: Dictionary) -> bool  (DOM-style key dict)
##   register_pointer("up", "my-id", callable)     # callable(event: InputEventMouse, pos: Vector2) -> bool
## and always unregister in _exit_tree (the helpers below are idempotent).

signal start_menu_changed(open: bool)

const LAYERS := ["modal", "menu", "window", "desktop"]

var shell: Control
var start_menu_open := false

var _key_handlers := {"modal": {}, "menu": {}, "window": {}, "desktop": {}}
var _pointer_handlers := {"down": {}, "move": {}, "up": {}}
var _menu_scopes := {}
var _modals := {}
var _modifier_pending := ""


# ------------------------------------------------------------------ start menu state

func open_start_menu() -> void:
	if not start_menu_open:
		start_menu_open = true
		start_menu_changed.emit(true)


func close_start_menu() -> void:
	if start_menu_open:
		start_menu_open = false
		start_menu_changed.emit(false)


func toggle_start_menu() -> void:
	if start_menu_open:
		close_start_menu()
	else:
		open_start_menu()


# ------------------------------------------------------------------ registration

func register_key(layer: String, id: String, cb: Callable) -> void:
	_key_handlers[layer][id] = cb


func unregister_key(layer: String, id: String) -> void:
	_key_handlers[layer].erase(id)


func register_pointer(phase: String, id: String, cb: Callable) -> void:
	_pointer_handlers[phase][id] = cb


func unregister_pointer(phase: String, id: String) -> void:
	_pointer_handlers[phase].erase(id)


func set_menu_scope(id: String, open: bool) -> void:
	if open:
		_menu_scopes[id] = true
	else:
		_menu_scopes.erase(id)


## Modal dialogs own the keyboard while any is registered.
func set_modal(id: String, open: bool) -> void:
	if open:
		_modals[id] = true
	else:
		_modals.erase(id)


func modal_active() -> bool:
	return not _modals.is_empty()


func menu_active() -> bool:
	return start_menu_open or not _menu_scopes.is_empty()


# ------------------------------------------------------------------ keyboard

static func key_name(event: InputEventKey) -> String:
	match event.keycode:
		KEY_ESCAPE: return "Escape"
		KEY_ENTER, KEY_KP_ENTER: return "Enter"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Backspace"
		KEY_DELETE: return "Delete"
		KEY_INSERT: return "Insert"
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_HOME: return "Home"
		KEY_END: return "End"
		KEY_PAGEUP: return "PageUp"
		KEY_PAGEDOWN: return "PageDown"
		KEY_MENU: return "ContextMenu"
		KEY_SPACE: return " "
		KEY_ALT: return "Alt"
		KEY_CTRL: return "Control"
		KEY_SHIFT: return "Shift"
		KEY_META: return "Meta"
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12:
			return "F%d" % (event.keycode - KEY_F1 + 1)
	if event.unicode > 31 and event.unicode != 127:
		return String.chr(event.unicode)
	var label := OS.get_keycode_string(event.keycode)
	if label.length() == 1:
		return label if event.shift_pressed else label.to_lower()
	return label


## DOM-style key description ({key, ctrlKey, altKey, shiftKey, metaKey, repeat}).
static func to_dom(event: InputEventKey) -> Dictionary:
	return {
		"key": key_name(event),
		"ctrlKey": event.ctrl_pressed,
		"altKey": event.alt_pressed,
		"shiftKey": event.shift_pressed,
		"metaKey": event.meta_pressed,
		"repeat": event.echo,
	}


func dispatch_layer(layer: String, event: Dictionary) -> bool:
	var handlers: Array = _key_handlers[layer].values()
	handlers.reverse()
	for h in handlers:
		if h.is_valid() and h.call(event):
			return true
	return false


func cycle_window(reverse: bool) -> void:
	var windows: Win95WindowStore = shell.windows
	var ordered := windows.by_z()
	if ordered.is_empty():
		return
	var active := -1
	for i in ordered.size():
		if ordered[i].id == windows.active_window_id:
			active = i
	var delta := -1 if reverse else 1
	var index: int
	if active < 0:
		index = (ordered.size() - 1) if reverse else 0
	else:
		index = (active + delta + ordered.size()) % ordered.size()
	var entry: Dictionary = ordered[index]
	windows.unminimize(entry)
	windows.focus_window(entry.id)


## Returns true when the event was consumed.
func on_key(event: InputEventKey) -> bool:
	var dom := to_dom(event)
	var name: String = dom.key
	if not event.pressed:
		return _key_up(event, dom)
	if name == "Alt" and not event.ctrl_pressed and not event.shift_pressed and not event.meta_pressed:
		_modifier_pending = "Alt"
	elif name == "Meta" and not event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
		_modifier_pending = "Meta"
	elif event.alt_pressed or event.meta_pressed:
		_modifier_pending = ""
	if name == "Alt" or name == "Meta" or name == "Control" or name == "Shift":
		return false
	if modal_active():
		return dispatch_layer("modal", dom)
	var command := Win95ShellInput.route_shortcut(dom)
	if command != "":
		var handled := true
		match command:
			"toggle-start": toggle_start_menu()
			"open-run":
				close_start_menu()
				Win95Dialogs.open_run(shell)
			"open-find":
				close_start_menu()
				Win95Dialogs.open_find(shell)
			"open-explorer":
				close_start_menu()
				shell.windows.open_my_computer()
			"cycle-window": cycle_window(false)
			"cycle-window-reverse": cycle_window(true)
			"system-menu", "close-window": handled = dispatch_layer("window", dom)
			"context-menu": handled = dispatch_layer("menu", dom) or dispatch_layer("window", dom) or dispatch_layer("desktop", dom)
			_: handled = false
		return handled
	var menu_is_open := menu_active()
	return (menu_is_open and dispatch_layer("menu", dom)) or dispatch_layer("window", dom) or dispatch_layer("desktop", dom)


func _key_up(event: InputEventKey, _dom: Dictionary) -> bool:
	if modal_active():
		return false
	var name := key_name(event)
	if name == "Meta" and _modifier_pending == "Meta":
		_modifier_pending = ""
		toggle_start_menu()
		return true
	if name == "Alt" and _modifier_pending == "Alt":
		_modifier_pending = ""
		close_start_menu()
		return dispatch_layer("window", {"key": "Alt", "altKey": false, "ctrlKey": false, "shiftKey": false, "metaKey": false})
	return false


# ------------------------------------------------------------------ pointer

## phase: "down" | "move" | "up". pos is in shell logical coordinates.
func on_pointer(phase: String, event: InputEventMouse, pos: Vector2) -> bool:
	var handlers: Array = _pointer_handlers[phase].values()
	handlers.reverse()
	for h in handlers:
		if h.is_valid() and h.call(event, pos):
			return true
	return false
