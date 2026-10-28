class_name Win95DialogState
extends RefCounted
## Pure dialog key routing. Port of shells/win95/dialogState.ts.
## event: {key: String, altKey?: bool, shiftKey?: bool}  (DOM-style key names)


## "cancel" | "default" | "advance-focus" | "reverse-focus" | "none"
static func resolve_key(event: Dictionary, has_default: bool, focused_button: bool = false, multiline: bool = false) -> String:
	var key: String = event.get("key", "")
	if key == "Escape" or (event.get("altKey", false) and key == "F4"):
		return "cancel"
	if key == "Tab":
		return "reverse-focus" if event.get("shiftKey", false) else "advance-focus"
	if key == "Enter" and has_default and not focused_button and not multiline:
		return "default"
	return "none"


## Id of the least destructive button (cancel, no, close, ok, else first); "" when empty.
static func least_destructive_default(buttons: Array) -> String:
	for preferred in ["cancel", "no", "close", "ok"]:
		for b in buttons:
			if String(b).to_lower() == preferred:
				return String(b)
	return String(buttons[0]) if buttons.size() > 0 else ""
