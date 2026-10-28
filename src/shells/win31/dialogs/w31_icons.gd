class_name W31Icons
extends RefCounted
## WfW icon catalog used by the Win31 dialogs. Port of shells/win31/iconCatalog.ts plus the
## icon-picker filter from ItemPropertiesDialog (WFW_ICON_IDS filter by substring).

const IDS := [
	"group", "default", "file-manager", "control-panel", "print-manager",
	"clipbook", "dos", "setup", "pif", "readme", "accessories", "network",
	"games", "startup", "program-manager", "terminal", "calculator", "clock",
	"paint", "cardfile", "warning", "information", "question",
]

const ALIASES := {
	"folder": "group", "wfw-group": "group", "wfw-file-manager": "file-manager",
	"wfw-control-panel": "control-panel", "wfw-print-manager": "print-manager",
	"wfw-clipbook": "clipbook", "wfw-dos": "dos", "wfw-setup": "setup", "wfw-pif": "pif",
	"wfw-readme": "readme", "drive": "file-manager", "network": "network", "trash": "default",
}


static func is_external(icon: String) -> bool:
	return icon.begins_with("data:") or icon.begins_with("file:") or icon.begins_with("http:") or icon.begins_with("https:")


## Catalog id for any icon string (unknown ids fall back to "default").
static func icon_id(icon: String) -> String:
	if IDS.has(icon):
		return icon
	return ALIASES.get(icon, "default")


## Picker filter: case-insensitive substring over the catalog ids (empty query = everything).
static func filter_ids(query: String) -> Array:
	var q := query.to_lower()
	var out := []
	for id in IDS:
		if q.is_empty() or String(id).to_lower().contains(q):
			out.append(id)
	return out


## Generic filter over {id, name} records (the Win95-style BUILTIN_ICONS list): matches on name.
static func filter_named(entries: Array, query: String) -> Array:
	var q := query.to_lower()
	var out := []
	for e in entries:
		if q.is_empty() or String(e.get("name", "")).to_lower().contains(q):
			out.append(e)
	return out


static func catalog_texture(id: String) -> Texture2D:
	var local := "res://assets/wfw-rtm-local/%s-32.png" % id
	var t: Texture2D = null
	if FileAccess.file_exists(local) or ResourceLoader.exists(local):
		t = Assets.tex(local)
	if t == null:
		t = Assets.tex("res://assets/wfw/%s-32.png" % id)
	if t == null:
		t = Assets.tex("res://assets/wfw/default-32.png")
	return t


## Texture for any icon string: catalog id/alias, data: URL or file path. Never null in a
## complete checkout (falls back to the default icon).
static func texture(icon: String) -> Texture2D:
	if is_external(icon):
		var t: Texture2D = null
		if icon.begins_with("data:"):
			t = Assets.from_data_url(icon)
		elif icon.begins_with("file:"):
			t = Assets.tex(icon.trim_prefix("file://"))
		if t != null:
			return t
		return catalog_texture("default")
	return catalog_texture(icon_id(icon))
