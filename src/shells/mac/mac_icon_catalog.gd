class_name MacIconCatalog
extends RefCounted
## Mac icon catalog: maps the launcher's catalog/legacy icon ids onto the classic-Mac icons (MACMAP in the
## design). "note" is the sticky note (Notes.ICON, a Stickies-style pad); the alert "note" icon of message boxes
## is "info" (see alert_icon()). Built-in ids resolve to assets/mac/{large,small}/<id>.png; user icons (data: / file
## URLs / absolute or Windows paths) pass through to the shared external-icon loader like Win95IconCatalog.

const MAC_IDS := ["folder", "volume", "trash", "application", "doc", "url", "terminal", "find", "tools", "stop", "info", "caution", "note"]

const MACMAP := {
	"folder": "folder", "folder-open": "folder", "programs": "folder", "group": "folder", "accessories": "folder",
	"games": "folder", "startup": "folder", "my-computer": "volume", "drive": "volume", "url": "url",
	"network": "url", "terminal": "terminal", "dos": "terminal", "run": "terminal", "readme": "doc",
	"documents": "doc", "clipbook": "doc", "find": "find", "settings": "tools", "control-panel": "tools",
	"setup": "tools", "information": "info", "help": "info", "question": "info", "warning": "caution",
	"critical": "stop", "recycle-empty": "trash",
}

const ROOT := "res://assets/mac"
const LOGO_SMALL := "res://assets/win95/small/launcher-logo-16.png"
const LOGO_LARGE := "res://assets/win95/large/launcher-logo-32.png"


static func is_external(icon: String) -> bool:
	return Win95IconCatalog.is_external(icon)


## Catalog id (one of MAC_IDS) for an icon string; "application" for anything unknown or external.
static func get_icon_id(icon: String) -> String:
	if MAC_IDS.has(icon):
		return icon
	return String(MACMAP.get(icon, "application"))


## Icon id for a message-box kind: the classic alert kinds are note | caution | stop, and the alert "note" (a
## speech balloon) is the "info" icon, because "note" itself is the sticky-note icon.
static func alert_icon(kind: String) -> String:
	return "info" if kind == "note" else kind


static func path_for(id: String, size: String) -> String:
	return "%s/%s/%s.png" % [ROOT, size, id]


## Texture for an icon string; size is "small" (16px) or "large" (32px). Never returns null.
static func texture(icon: String, size: String = "large") -> Texture2D:
	if is_external(icon):
		var ext := _external_texture(icon)
		if ext != null:
			return ext
	var t := Assets.tex(path_for(get_icon_id(icon), size))
	return t if t != null else Assets.tex(path_for("application", size))


static func _external_texture(icon: String) -> Texture2D:
	if icon.begins_with("data:"):
		return Assets.from_data_url(icon)
	if icon.begins_with("http:") or icon.begins_with("https:"):
		return null  # remote icons are never fetched
	var path := icon
	if path.begins_with("file:///"):
		path = path.substr(7)
		if path.length() > 2 and path[2] == ":":
			path = path.substr(1)
	elif path.begins_with("file:"):
		path = path.substr(5)
	if path.length() >= 3 and path[1] == ":":
		path = path.replace("\\", "/")
	return Assets.tex(path)


static func logo(size: String = "small") -> Texture2D:
	return Assets.tex(LOGO_SMALL if size == "small" else LOGO_LARGE)
