class_name Notes
extends RefCounted
## Sticky notes: the third kind of item next to programs and web sites. A note is an item with
## kind "note", an empty path and its text in `note`. Opening it (double-click, Enter, Quick Search,
## Find, a launch group) shows a sticky note window on the desktop instead of starting a program.
##
## Item fields: kind "note", note (text), noteColor (one of COLORS, default yellow),
## noteBounds {x, y, width, height} (window rect in shell logical pixels, kept per item, not per
## shell), noteOpen (true while its window is open, so open notes come back after a restart).

const KIND := "note"
const ICON := "note"
const MAX_TEXT := 20000
const DEFAULT_COLOR := "yellow"
## Paper colours, in the order the editors offer them (Stickies-like pastels).
const COLORS := {
	"yellow": Color8(255, 255, 153),
	"pink": Color8(255, 204, 229),
	"blue": Color8(204, 229, 255),
	"green": Color8(204, 255, 204),
	"purple": Color8(229, 204, 255),
	"gray": Color8(224, 224, 224),
}
const COLOR_LABELS := {"yellow": "Yellow", "pink": "Pink", "blue": "Blue", "green": "Green", "purple": "Purple", "gray": "Gray"}
const DEFAULT_SIZE := Vector2i(180, 140)
const MIN_SIZE := Vector2i(96, 56)


static func is_note(item: Variant) -> bool:
	return Jsonx.is_obj(item) and String(item.get("kind", "")) == KIND


## A new note item (without id; ProgramStore.add_item assigns one).
static func make_note(name: String, text: String = "", color: String = DEFAULT_COLOR) -> Dictionary:
	var n := name.strip_edges()
	return {
		"kind": KIND,
		"name": n if n != "" else "Note",
		"path": "",
		"icon": ICON,
		"win31Icon": ICON,
		"workingDir": "",
		"note": clean_text(text),
		"noteColor": color if COLORS.has(color) else DEFAULT_COLOR,
	}


static func clean_text(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "\n").substr(0, MAX_TEXT)


static func color_of(item: Dictionary) -> Color:
	return COLORS.get(String(item.get("noteColor", DEFAULT_COLOR)), COLORS[DEFAULT_COLOR])


## Ordered [{id, label}] of the paper colours for the editors' drop-downs.
static func color_choices() -> Array:
	var out := []
	for id in COLORS:
		out.append({"id": id, "label": COLOR_LABELS[id]})
	return out


## The first line of the text, trimmed and cut to `max_chars` (for tooltips, Find and list views).
static func preview(item: Dictionary, max_chars: int = 40) -> String:
	var t := String(item.get("note", "")).strip_edges()
	var first := t.split("\n", false, 1)
	var line := first[0].strip_edges() if first.size() > 0 else ""
	return line if line.length() <= max_chars else line.substr(0, max_chars - 1) + "…"


static func is_bounds(value: Variant) -> bool:
	return Jsonx.is_obj(value) and Jsonx.is_num(value.get("x")) and Jsonx.is_num(value.get("y")) \
		and Jsonx.is_num(value.get("width")) and Jsonx.is_num(value.get("height")) \
		and value.width > 0 and value.height > 0


## The window rect for `item` inside `area` (the shell's logical desktop): its stored bounds,
## or a cascaded default from `index`, moved and shrunk so the whole note stays reachable.
static func window_rect(item: Dictionary, area: Rect2i, index: int = 0) -> Rect2i:
	var r := Rect2i(area.position + Vector2i(48 + (index % 8) * 20, 40 + (index % 8) * 20), DEFAULT_SIZE)
	var b: Variant = item.get("noteBounds")
	if is_bounds(b):
		r = Rect2i(int(b.x), int(b.y), int(b.width), int(b.height))
	r.size.x = clampi(r.size.x, MIN_SIZE.x, maxi(MIN_SIZE.x, area.size.x))
	r.size.y = clampi(r.size.y, MIN_SIZE.y, maxi(MIN_SIZE.y, area.size.y))
	r.position.x = clampi(r.position.x, area.position.x, maxi(area.position.x, area.end.x - r.size.x))
	r.position.y = clampi(r.position.y, area.position.y, maxi(area.position.y, area.end.y - r.size.y))
	return r


static func bounds_dict(r: Rect2i) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
