class_name A11y
extends RefCounted
## Screen-reader support on Godot's AccessKit layer (the Electron build exposed the same tree through
## ARIA roles and native HTML controls).
##
## Every control here is custom-drawn, so each one describes itself with a *spec* Dictionary built by
## a pure function (`a11y_spec()` / `a11y_item_specs()`, unit-tested headless) and applies it from
## NOTIFICATION_ACCESSIBILITY_UPDATE with `A11y.apply()`. Godot only sends that notification while a
## screen reader (AccessKit client) is attached, so none of this runs otherwise; controls just call
## `queue_accessibility_update()` from `_draw()` (redraws already follow every visible state change),
## which costs one set insertion.
##
## Spec keys (all optional):
##   role: int (DisplayServer.ROLE_*), name, value, description, placeholder, tooltip: String,
##   checked: bool, selected: bool, expanded: bool, disabled, readonly, modal, multiselect,
##   hidden: bool, live: int (DisplayServer.LIVE_*), bounds: Rect2 (element-local), popup: int,
##   index / count: int (list position), level: int, num: {value, min, max, step},
##   vertical: bool (list/scrollbar orientation), shortcut: String,
##   click / focus / expand / collapse: Callable(data) for screen-reader actions.
##
## Focus: Win31 controls own Godot focus; Win95 keeps its own focus model, and both draw their menus
## without taking Godot focus. Open menus register as *overlays* (`push_overlay`) and the active shell
## as the *base* provider (`set_base`); focusable controls return `A11y.resolve(own)` from
## `_get_focused_accessibility_element()`, and a hidden proxy node at the root's first slot (the node
## SceneTree asks when no control has Godot focus) returns `A11y.proxy_focus()`.

const PROXY_NAME := "A11yFocusProxy"

static var _overlays: Array = []  ## WeakRef stack of objects with a11y_focus() -> RID
static var _base: WeakRef = null
static var _proxy: WeakRef = null
static var _supported := -1


## True on display servers that can host a screen reader (false headless).
static func supported() -> bool:
	if _supported < 0:
		_supported = 1 if DisplayServer.has_feature(DisplayServer.FEATURE_ACCESSIBILITY_SCREEN_READER) else 0
	return _supported == 1


## Refreshes `ci`'s accessibility element whenever it redraws (every visible state change of these
## custom-drawn controls goes through queue_redraw()). No-op without screen-reader support.
static func track(ci: CanvasItem) -> void:
	if supported() and not ci.draw.is_connected(ci.queue_accessibility_update):
		ci.draw.connect(ci.queue_accessibility_update)


# ------------------------------------------------------------------ specs

## Strips the `&` access-key markers of a menu/button label ("&File" -> "File", "&&" -> "&").
static func plain(label: String) -> String:
	return label.replace("&&", "\u0001").replace("&", "").replace("\u0001", "&").strip_edges()


## The access key of an `&`-marked label as a shortcut string ("Alt+F"), or "".
static func access_shortcut(label: String) -> String:
	var i := label.replace("&&", "__").find("&")
	if i < 0 or i + 1 >= label.length():
		return ""
	return "Alt+" + label[i + 1].to_upper()


static func button(name: String, disabled: bool = false, is_default: bool = false) -> Dictionary:
	return {"role": DisplayServer.ROLE_DEFAULT_BUTTON if is_default else DisplayServer.ROLE_BUTTON,
		"name": plain(name), "disabled": disabled, "shortcut": access_shortcut(name)}


static func check_box(name: String, checked: bool, disabled: bool = false) -> Dictionary:
	return {"role": DisplayServer.ROLE_CHECK_BOX, "name": plain(name), "checked": checked, "disabled": disabled,
		"shortcut": access_shortcut(name)}


static func radio(name: String, checked: bool, disabled: bool = false) -> Dictionary:
	return {"role": DisplayServer.ROLE_RADIO_BUTTON, "name": plain(name), "checked": checked, "disabled": disabled,
		"shortcut": access_shortcut(name)}


## Collapsed drop-down list: AccessKit's combo box is a button that pops up a list.
static func combo(name: String, value: String, expanded: bool, disabled: bool = false) -> Dictionary:
	return {"role": DisplayServer.ROLE_BUTTON, "name": plain(name), "value": value, "expanded": expanded,
		"popup": DisplayServer.POPUP_LIST, "disabled": disabled}


static func option(name: String, selected: bool, index: int, count: int, bounds: Rect2) -> Dictionary:
	return {"role": DisplayServer.ROLE_LIST_BOX_OPTION, "name": name, "selected": selected,
		"index": index, "count": count, "bounds": bounds}


## A menu row: `kind` is "item" | "check" | "radio" | "separator"; `submenu` marks cascades.
static func menu_item(label: String, bounds: Rect2, disabled: bool = false, kind: String = "item",
		checked: bool = false, submenu: bool = false, shortcut: String = "") -> Dictionary:
	var role := DisplayServer.ROLE_MENU_ITEM
	match kind:
		"check": role = DisplayServer.ROLE_MENU_ITEM_CHECK_BOX
		"radio": role = DisplayServer.ROLE_MENU_ITEM_RADIO
		"separator": return {"role": DisplayServer.ROLE_SPLITTER, "name": "", "bounds": bounds}
	var spec := {"role": role, "name": plain(label), "disabled": disabled, "bounds": bounds,
		"shortcut": shortcut if shortcut != "" else access_shortcut(label)}
	if kind == "check" or kind == "radio":
		spec["checked"] = checked
	if submenu:
		spec["popup"] = DisplayServer.POPUP_MENU
		spec["expanded"] = false
	return spec


static func dialog(title: String, modal: bool = true) -> Dictionary:
	return {"role": DisplayServer.ROLE_DIALOG, "name": title, "modal": modal}


static func window(title: String) -> Dictionary:
	return {"role": DisplayServer.ROLE_WINDOW, "name": title}


static func static_text(text: String, bounds: Rect2 = Rect2()) -> Dictionary:
	var spec := {"role": DisplayServer.ROLE_STATIC_TEXT, "name": text}
	if bounds.size != Vector2.ZERO:
		spec["bounds"] = bounds
	return spec


## Caption of a form field drawn as a separate label: the label left of the field on the same row
## (nearest first), else the one just above it. `labels` = [{text, rect}] in the field's space.
static func caption_for(field: Rect2, labels: Array) -> String:
	var best := ""
	var best_d := INF
	var cy := field.get_center().y
	for l in labels:
		var r: Rect2 = l.rect
		if r.end.x <= field.position.x + 2 and absf(r.get_center().y - cy) <= 8 and field.position.x - r.end.x < 120:
			var d := field.position.x - r.end.x
			if d < best_d:
				best_d = d
				best = String(l.text)
	if best != "":
		return clean_caption(best)
	for l in labels:
		var r: Rect2 = l.rect
		var gap := field.position.y - r.end.y
		if gap >= -2 and gap <= 12 and r.position.x < field.end.x and r.end.x > field.position.x - 2:
			if gap < best_d:
				best_d = gap
				best = String(l.text)
	return clean_caption(best)


## "&Name:" -> "Name".
static func clean_caption(label: String) -> String:
	return plain(label).trim_suffix(":").strip_edges()


static func scroll_bar(name: String, value: float, max_value: float, page: float, vertical: bool) -> Dictionary:
	return {"role": DisplayServer.ROLE_SCROLL_BAR, "name": name, "vertical": vertical,
		"num": {"value": value, "min": 0.0, "max": maxf(0.0, max_value), "step": maxf(1.0, page)}}


# ------------------------------------------------------------------ applying

## Applies `spec` to element `id`. Only valid inside NOTIFICATION_ACCESSIBILITY_UPDATE.
static func apply(id: RID, spec: Dictionary) -> void:
	if not id.is_valid():
		return
	if spec.has("role"):
		DisplayServer.accessibility_update_set_role(id, spec.role)
	if spec.has("name"):
		DisplayServer.accessibility_update_set_name(id, String(spec.name))
	if spec.has("value"):
		DisplayServer.accessibility_update_set_value(id, String(spec.value))
	if spec.has("description"):
		DisplayServer.accessibility_update_set_description(id, String(spec.description))
	if spec.has("placeholder"):
		DisplayServer.accessibility_update_set_placeholder(id, String(spec.placeholder))
	if spec.has("tooltip"):
		DisplayServer.accessibility_update_set_tooltip(id, String(spec.tooltip))
	if spec.has("shortcut") and String(spec.shortcut) != "":
		DisplayServer.accessibility_update_set_shortcut(id, String(spec.shortcut))
	if spec.has("checked"):
		DisplayServer.accessibility_update_set_checked(id, bool(spec.checked))
	if spec.has("selected"):
		DisplayServer.accessibility_update_set_list_item_selected(id, bool(spec.selected))
	if spec.has("expanded"):
		DisplayServer.accessibility_update_set_list_item_expanded(id, bool(spec.expanded))
	if spec.has("index"):
		DisplayServer.accessibility_update_set_list_item_index(id, int(spec.index))
	if spec.has("count"):
		DisplayServer.accessibility_update_set_list_item_count(id, int(spec.count))
	if spec.has("level"):
		DisplayServer.accessibility_update_set_list_item_level(id, int(spec.level))
	if spec.has("vertical"):
		DisplayServer.accessibility_update_set_list_orientation(id, bool(spec.vertical))
	if spec.has("popup"):
		DisplayServer.accessibility_update_set_popup_type(id, int(spec.popup))
	if spec.has("live"):
		DisplayServer.accessibility_update_set_live(id, int(spec.live))
	if spec.has("bounds"):
		DisplayServer.accessibility_update_set_bounds(id, spec.bounds)
	if spec.has("num"):
		var n: Dictionary = spec.num
		DisplayServer.accessibility_update_set_num_range(id, float(n.get("min", 0.0)), float(n.get("max", 0.0)))
		DisplayServer.accessibility_update_set_num_value(id, float(n.get("value", 0.0)))
		if n.has("step"):
			DisplayServer.accessibility_update_set_num_step(id, float(n.step))
	for key in ["hidden", "disabled", "readonly", "modal", "multiselect"]:
		if spec.has(key):
			DisplayServer.accessibility_update_set_flag(id, _flag(key), bool(spec[key]))
	for key in ["click", "focus", "expand", "collapse"]:
		if spec.has(key) and spec[key] is Callable and (spec[key] as Callable).is_valid():
			DisplayServer.accessibility_update_add_action(id, _action(key), spec[key])


static func _flag(key: String) -> int:
	match key:
		"hidden": return DisplayServer.FLAG_HIDDEN
		"disabled": return DisplayServer.FLAG_DISABLED
		"readonly": return DisplayServer.FLAG_READONLY
		"modal": return DisplayServer.FLAG_MODAL
	return DisplayServer.FLAG_MULTISELECTABLE


static func _action(key: String) -> int:
	match key:
		"click": return DisplayServer.ACTION_CLICK
		"focus": return DisplayServer.ACTION_FOCUS
		"expand": return DisplayServer.ACTION_EXPAND
	return DisplayServer.ACTION_COLLAPSE


## Applies `spec` to `node`'s own element (convenience for the update notification).
static func apply_node(node: Node, spec: Dictionary) -> void:
	apply(node.get_accessibility_element(), spec)


## Keeps the sub-elements in `rids` (an Array owned by the caller) in step with `specs`: creates the
## missing ones under `parent`, applies every spec and hides the surplus (elements cannot be freed
## inside the update notification; they are released with the parent element). Returns `rids`.
static func sync_children(parent: RID, rids: Array, specs: Array) -> Array:
	if not parent.is_valid():
		return rids
	for i in specs.size():
		var spec: Dictionary = specs[i]
		if i >= rids.size() or not DisplayServer.accessibility_has_element(rids[i]):
			var rid := DisplayServer.accessibility_create_sub_element(parent, int(spec.get("role", DisplayServer.ROLE_CONTAINER)))
			if i < rids.size():
				rids[i] = rid
			else:
				rids.append(rid)
		apply(rids[i], spec)
		DisplayServer.accessibility_update_set_flag(rids[i], DisplayServer.FLAG_HIDDEN, bool(spec.get("hidden", false)))
	for i in range(specs.size(), rids.size()):
		if DisplayServer.accessibility_has_element(rids[i]):
			DisplayServer.accessibility_update_set_flag(rids[i], DisplayServer.FLAG_HIDDEN, true)
	return rids


## Sub-element `i` of `rids` if it exists, else `fallback`.
static func child_or(rids: Array, i: int, fallback: RID) -> RID:
	if i >= 0 and i < rids.size() and DisplayServer.accessibility_has_element(rids[i]):
		return rids[i]
	return fallback


# ------------------------------------------------------------------ focus

## Registers an open menu (any object with `a11y_focus() -> RID`); the newest overlay wins.
static func push_overlay(owner: Object) -> void:
	remove_overlay(owner)
	_overlays.append(weakref(owner))


static func remove_overlay(owner: Object) -> void:
	for i in range(_overlays.size() - 1, -1, -1):
		var o: Variant = _overlays[i].get_ref()
		if o == null or o == owner:
			_overlays.remove_at(i)


## The shell's own focus model (object with `a11y_focus() -> RID`), consulted when no control
## has Godot focus.
static func set_base(owner: Object) -> void:
	_base = weakref(owner) if owner != null else null


static func clear_base(owner: Object) -> void:
	if _base != null and _base.get_ref() == owner:
		_base = null


## Focused element of the topmost open overlay, or an invalid RID.
static func overlay_focus() -> RID:
	for i in range(_overlays.size() - 1, -1, -1):
		var o: Variant = _overlays[i].get_ref()
		if o == null or not (o is Node) or not (o as Node).is_inside_tree():
			continue
		var r: RID = o.a11y_focus()
		if r.is_valid():
			return r
	return RID()


## What a control with Godot focus reports: an open menu wins over the control itself.
static func resolve(own: RID) -> RID:
	var o := overlay_focus()
	return o if o.is_valid() else own


## What the root proxy reports when no control has Godot focus.
static func proxy_focus() -> RID:
	var o := overlay_focus()
	if o.is_valid():
		return o
	var b: Variant = _base.get_ref() if _base != null else null
	if b != null and b is Node and (b as Node).is_inside_tree():
		return b.a11y_focus()
	return RID()


## Adds the focus proxy as the root's first child (SceneTree asks `root.get_child(0)` for the focus
## when no control has Godot focus). Only on display servers with screen-reader support.
static func ensure_proxy(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	if not supported():
		return
	if _proxy != null and _proxy.get_ref() != null and not (_proxy.get_ref() as Node).is_queued_for_deletion():
		return
	var p := FocusProxy.new()
	_proxy = weakref(p)
	p.name = PROXY_NAME
	tree.root.add_child.call_deferred(p)
	tree.root.move_child.call_deferred(p, 0)


class FocusProxy extends Node:
	func _get_focused_accessibility_element() -> RID:
		return A11y.proxy_focus()  # invalid -> the window itself

	func _notification(what: int) -> void:
		if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
			var ae := get_accessibility_element()
			DisplayServer.accessibility_update_set_role(ae, DisplayServer.ROLE_CONTAINER)
			DisplayServer.accessibility_update_set_name(ae, "")
			DisplayServer.accessibility_update_set_flag(ae, DisplayServer.FLAG_HIDDEN, true)
