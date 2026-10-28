class_name Win95IconCatalog
extends RefCounted
## Win95 icon catalog: catalog ids, legacy-id aliases and texture lookup.
## Port of shells/win95/iconCatalog.ts. The 1x sources (large/<id>-32.png, small/<id>-16.png) are
## drawn at their logical size and scaled by the host's integer content scale (nearest filtering),
## so the pre-scaled -48/-64/-96/-128 variants are never used here.
##
## texture(icon, "small"|"large") accepts a catalog id, a legacy alias, or an external icon
## (data: URL, file: URL, absolute/Windows path) and never returns null.

const ICON_IDS := [
	"my-computer", "network-neighborhood", "recycle-empty", "recycle-full",
	"folder", "folder-open", "programs", "documents", "settings",
	"control-panel", "find", "help", "run", "shutdown", "windows-logo",
	"application", "url", "drive", "printers", "taskbar", "warning",
	"information", "question", "critical", "new-shortcut", "properties",
]

const ALIASES := {
	"default": "application",
	"default-item.png": "application",
	"folder": "folder",
	"group": "folder",
	"folder.png": "folder",
	"folder-open": "folder-open",
	"document": "documents",
	"book": "documents",
	"settings": "settings",
	"gear": "settings",
	"search": "find",
	"question": "question",
	"question.png": "question",
	"information": "information",
	"warning": "warning",
	"error": "critical",
	"critical": "critical",
	"stop": "critical",
	"shortcut": "new-shortcut",
	"properties": "properties",
	"terminal": "run",
	"power": "shutdown",
	"flag": "windows-logo",
	"drive": "drive",
	"network": "network-neighborhood",
	"trash": "recycle-empty",
	"web": "url",
	"globe": "url",
	"link": "url",
	"program-manager.png": "application",
	"file-manager": "drive",
	"control-panel": "control-panel",
	"print-manager": "printers",
	"clipbook": "documents",
	"dos": "run",
	"setup": "settings",
	"pif": "application",
	"readme": "documents",
	"startup": "programs",
	"accessories": "programs",
	"games": "programs",
	"calculator": "application",
	"paint": "application",
	"clock": "application",
}

const ROOT := "res://assets/win95"


static func is_external(icon: String) -> bool:
	if icon.begins_with("data:") or icon.begins_with("file:") or icon.begins_with("http:") or icon.begins_with("https:") or icon.begins_with("/"):
		return true
	return icon.length() >= 3 and icon[1] == ":" and (icon[2] == "\\" or icon[2] == "/") and \
		((icon[0] >= "a" and icon[0] <= "z") or (icon[0] >= "A" and icon[0] <= "Z"))


static func get_icon_id(icon: String) -> String:
	if icon.is_empty():
		return "application"
	if ICON_IDS.has(icon):
		return icon
	return String(ALIASES.get(icon, "application"))


## Path of the 1x source for a catalog id.
static func path_for(id: String, size: String) -> String:
	var base := 32 if size == "large" else 16
	return "%s/%s/%s-%d.png" % [ROOT, size, id, base]


static func _external_texture(icon: String) -> Texture2D:
	if icon.begins_with("data:"):
		return Assets.from_data_url(icon)
	if icon.begins_with("http:") or icon.begins_with("https:"):
		return null  # remote icons are not fetched; the caller falls back to the application icon
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


## Texture for an icon string at the given native size family ("small" 16px | "large" 32px).
static func texture(icon: String, size: String = "large") -> Texture2D:
	if is_external(icon):
		var ext := _external_texture(icon)
		if ext != null:
			return ext
		return Assets.tex(path_for("application", size))
	var id := get_icon_id(icon)
	var t := Assets.tex(path_for(id, size))
	return t if t != null else Assets.tex(path_for("application", size))


## Catalog texture by id (no alias/external handling).
static func by_id(id: String, size: String = "large") -> Texture2D:
	return texture(id, size)
