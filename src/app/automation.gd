class_name Automation
extends RefCounted
## Test/automation driver: injects real input events (in shell *logical* coordinates) and
## resolves stable element ids. Any Node in group "pm_auto" may implement
##     func auto_lookup(id: String) -> Variant   # Rect2 in logical coords, or null
## Controls may also just carry meta "auto_id" (their global rect is used).
## The visual scenarios and integration tests are written against these ids.

var tree: SceneTree
var window: Window


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	window = p_tree.root


func scale_factor() -> float:
	return window.content_scale_factor


# ------------------------------------------------------------------ lookup

## Rect2 in logical coordinates, or an empty Rect2() when not found.
func find_rect(id: String) -> Rect2:
	for n in tree.get_nodes_in_group("pm_auto"):
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n.has_method("auto_lookup"):
			var r: Variant = n.auto_lookup(id)
			if r is Rect2:
				return r
		if n is Control and n.has_meta("auto_id") and n.get_meta("auto_id") == id and n.is_visible_in_tree():
			return n.get_global_rect()
	return Rect2()


func has(id: String) -> bool:
	return find_rect(id).size != Vector2.ZERO


func center(id: String) -> Vector2:
	var r := find_rect(id)
	assert(r.size != Vector2.ZERO, "automation id not found: " + id)
	return (r.position + r.size / 2.0).floor()


## Waits (up to timeout_ms) for an id to appear.
func wait_for(id: String, timeout_ms: int = 2000) -> bool:
	var t := Time.get_ticks_msec()
	while not has(id):
		if Time.get_ticks_msec() - t > timeout_ms:
			return false
		await tree.process_frame
	return true


# ------------------------------------------------------------------ events

func _push(ev: InputEvent) -> void:
	window.push_input(ev, true)


func _mods(ev: InputEventWithModifiers, mods: Dictionary) -> void:
	ev.ctrl_pressed = mods.get("ctrl", false)
	ev.shift_pressed = mods.get("shift", false)
	ev.alt_pressed = mods.get("alt", false)
	ev.meta_pressed = mods.get("meta", false)


var _mouse := Vector2.ZERO
var _buttons := 0


func move(p: Vector2, mods: Dictionary = {}) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.relative = p - _mouse
	ev.button_mask = _buttons
	_mods(ev, mods)
	_mouse = p
	_push(ev)
	await tree.process_frame


func down(p: Vector2, button: int = MOUSE_BUTTON_LEFT, mods: Dictionary = {}, double: bool = false) -> void:
	await move(p, mods)
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = button
	ev.pressed = true
	ev.double_click = double
	_buttons |= (1 << (button - 1))
	ev.button_mask = _buttons
	_mods(ev, mods)
	_push(ev)
	await tree.process_frame


func up(p: Vector2, button: int = MOUSE_BUTTON_LEFT, mods: Dictionary = {}) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = button
	ev.pressed = false
	_buttons &= ~(1 << (button - 1))
	ev.button_mask = _buttons
	_mods(ev, mods)
	_push(ev)
	await tree.process_frame


func click(p: Vector2, mods: Dictionary = {}) -> void:
	await down(p, MOUSE_BUTTON_LEFT, mods)
	await up(p, MOUSE_BUTTON_LEFT, mods)


func dblclick(p: Vector2, mods: Dictionary = {}) -> void:
	await down(p, MOUSE_BUTTON_LEFT, mods)
	await up(p, MOUSE_BUTTON_LEFT, mods)
	await down(p, MOUSE_BUTTON_LEFT, mods, true)
	await up(p, MOUSE_BUTTON_LEFT, mods)


func rclick(p: Vector2, mods: Dictionary = {}) -> void:
	await down(p, MOUSE_BUTTON_RIGHT, mods)
	await up(p, MOUSE_BUTTON_RIGHT, mods)


func drag(from: Vector2, to: Vector2, steps: int = 4, release: bool = false) -> void:
	await down(from)
	for i in range(1, steps + 1):
		await move(from.lerp(to, float(i) / steps))
	if release:
		await up(to)


func key(keycode: Key, mods: Dictionary = {}, text: String = "") -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.key_label = keycode
		ev.pressed = pressed
		if text != "":
			ev.unicode = text.unicode_at(0)
		_mods(ev, mods)
		_push(ev)
		await tree.process_frame


func type_text(text: String) -> void:
	for ch in text:
		await key(OS.find_keycode_from_string(ch.to_upper()) as Key, {}, ch)


# ------------------------------------------------------------- id helpers

func click_id(id: String, mods: Dictionary = {}) -> void:
	await click(center(id), mods)


func dblclick_id(id: String) -> void:
	await dblclick(center(id))


func rclick_id(id: String) -> void:
	await rclick(center(id))


func hover_id(id: String) -> void:
	await move(center(id))


func down_id(id: String, mods: Dictionary = {}) -> void:
	await down(center(id), MOUSE_BUTTON_LEFT, mods)


func frames(n: int = 2) -> void:
	for i in n:
		await tree.process_frame


func wait_ms(ms: int) -> void:
	await tree.create_timer(ms / 1000.0).timeout
