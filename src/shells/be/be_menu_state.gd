class_name BeMenuState
extends RefCounted
## Pure state for the folder-window menu bars, popups and keyboard navigation (design: state.menu / cm / start).
## `bar` = "<windowKey>:<menuId>" or "" ; `popup_hover` is the highlighted row index of the open popup.

var bar := ""
var popup_hover := -1


func is_open() -> bool:
	return bar != ""


func toggle(window_key: String, menu_id: String) -> void:
	var id := window_key + ":" + menu_id
	bar = "" if bar == id else id
	popup_hover = -1


## Hovering another title while one is open switches to it (design onMouseEnter).
func enter(window_key: String, menu_id: String) -> void:
	if bar != "" and bar.begins_with(window_key + ":") and bar != window_key + ":" + menu_id:
		bar = window_key + ":" + menu_id
		popup_hover = -1


func close() -> void:
	bar = ""
	popup_hover = -1


func open_menu_id() -> String:
	var i := bar.rfind(":")
	return bar.substr(i + 1) if i >= 0 else ""


func open_window_key() -> String:
	var i := bar.rfind(":")
	return bar.substr(0, i) if i >= 0 else ""


## Next enabled row from `from` going in `dir` (+1/-1), wrapping; -1 when every row is disabled.
static func step(items: Array, from: int, dir: int) -> int:
	var n := items.size()
	if n == 0:
		return -1
	var i := from
	for _k in n:
		i = posmod(i + dir, n)
		var it: Dictionary = items[i]
		if not bool(it.get("sep", false)) and not bool(it.get("disabled", false)):
			return i
	return -1


## Next/previous menu title index with wrap.
static func step_menu(count: int, from: int, dir: int) -> int:
	return posmod(from + dir, count) if count > 0 else 0
