class_name BeIconCatalog
extends RefCounted
## Be icon catalog (port of BEK / BEMAP / BE() in the design; "note" is the sticky note, see Notes). Catalog icon ids map onto the 64px smooth icons in
## assets/be; any other id gets one of six generic application icons chosen by a string hash of the item name.
## data: URLs and file paths pass through like Win95IconCatalog.

const ROOT := "res://assets/be"
const KEYS := ["folder", "volume", "logo", "url", "terminal", "doc", "find", "tools", "info", "question", "critical", "warning", "note"]
const APP_VARIANTS := 6
const MAP := {
	"folder": "folder", "folder-open": "folder", "programs": "folder", "group": "folder", "accessories": "folder",
	"games": "folder", "startup": "folder", "my-computer": "volume", "drive": "volume", "url": "url", "network": "url",
	"terminal": "terminal", "dos": "terminal", "run": "terminal", "readme": "doc", "documents": "doc",
	"clipbook": "doc", "find": "find", "settings": "tools", "control-panel": "tools", "setup": "tools",
	"information": "info", "help": "question", "warning": "warning", "critical": "critical",
	"launcher-logo": "logo", "windows-logo": "logo", "program-manager": "logo", "sticky-note": "note",
}


## JavaScript-style hash over code points (h = h * 31 + c, kept as an unsigned 32-bit value).
static func name_hash(text: String) -> int:
	var h := 0
	for i in text.length():
		h = (h * 31 + text.unicode_at(i)) & 0xFFFFFFFF
	return h


## Catalog key ("folder", "app-3", ...) for an icon id; `name` seeds the generic application icon.
static func key_for(icon: String, name: String = "") -> String:
	if KEYS.has(icon):
		return icon
	if MAP.has(icon):
		return String(MAP[icon])
	var seed_text := name if name != "" else icon
	return "app-%d" % (name_hash(seed_text) % APP_VARIANTS)


static func path_for(key: String) -> String:
	return "%s/%s.png" % [ROOT, key]


static func is_external(icon: String) -> bool:
	return Win95IconCatalog.is_external(icon)


## Texture for an icon string; never null for catalog ids. External icons that cannot be read fall back to the
## generic application icon for `name`.
static func texture(icon: String, name: String = "") -> Texture2D:
	if icon != "" and is_external(icon):
		var ext: Texture2D = null
		if icon.begins_with("data:"):
			ext = Assets.from_data_url(icon)
		elif not (icon.begins_with("http:") or icon.begins_with("https:")):
			var path := icon
			if path.begins_with("file:///"):
				path = path.substr(7)
				if path.length() > 2 and path[2] == ":":
					path = path.substr(1)
			elif path.begins_with("file:"):
				path = path.substr(5)
			if path.length() >= 3 and path[1] == ":":
				path = path.replace("\\", "/")
			ext = Assets.tex(path)
		if ext != null:
			return ext
		return Assets.tex(path_for(key_for("default", name)))
	return Assets.tex(path_for(key_for(icon, name)))


## Icon ids offered by the Change Icon dialog: the distinct catalog images for the design's icon list.
const PICKER_IDS := ["default", "file-manager", "control-panel", "print-manager", "clipbook", "dos", "setup", "pif",
	"readme", "terminal", "calculator", "clock", "paint", "cardfile", "network", "accessories", "games", "startup",
	"program-manager", "note"]


static func picker_options() -> Array:
	var seen := {}
	var out := []
	for id in PICKER_IDS:
		var key := key_for(String(id), String(id))
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"id": id, "key": key})
	return out
