class_name MacIconCatalog
extends RefCounted
## Mac icon catalog: maps the launcher's catalog/legacy icon ids onto the twelve classic-Mac icons
## (MACMAP in the design). Built-in ids resolve to assets/mac/{large,small}/<id>.png; user icons (data: / file
## URLs / absolute or Windows paths) pass through to the shared external-icon loader like Win95IconCatalog.

const MAC_IDS := ["folder", "volume", "trash", "application", "doc", "url", "terminal", "find", "tools", "stop", "note", "caution"]

const MACMAP := {
	"folder": "folder", "folder-open": "folder", "programs": "folder", "group": "folder", "accessories": "folder",
	"games": "folder", "startup": "folder", "my-computer": "volume", "drive": "volume", "url": "url",
	"network": "url", "terminal": "terminal", "dos": "terminal", "run": "terminal", "readme": "doc",
	"documents": "doc", "clipbook": "doc", "find": "find", "settings": "tools", "control-panel": "tools",
	"setup": "tools", "information": "note", "help": "note", "question": "note", "warning": "caution",
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
