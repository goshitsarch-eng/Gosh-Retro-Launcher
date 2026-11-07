class_name WfwIcons
extends RefCounted
## Port of shells/win31/iconCatalog.ts: WfW icon ids -> assets/wfw/<id>-32.png (logical size).
## An optional gitignored pack extracted from licensed media (assets/wfw-rtm-local/<id>-32.png)
## wins over the clean-room set, exactly like the TS build. External icons (data:/file:/http(s):)
## are decoded directly; unknown ids fall back to the `default` icon.

const IDS := [
	"group", "default", "file-manager", "control-panel", "print-manager",
	"clipbook", "dos", "setup", "pif", "readme", "accessories", "network",
	"games", "startup", "program-manager", "terminal", "calculator", "clock",
	"paint", "cardfile", "warning", "information", "question",
]

const ALIASES := {
	"folder": "group",
	"wfw-group": "group",
	"wfw-file-manager": "file-manager",
	"wfw-control-panel": "control-panel",
	"wfw-print-manager": "print-manager",
	"wfw-clipbook": "clipbook",
	"wfw-dos": "dos",
	"wfw-setup": "setup",
	"wfw-pif": "pif",
	"wfw-readme": "readme",
	"drive": "file-manager",
	"network": "network",
	"trash": "default",
}


static func is_external_icon(icon: String) -> bool:
	return icon.begins_with("data:") or icon.begins_with("file:") or icon.begins_with("http:") or icon.begins_with("https:")


static func icon_id(icon: String) -> String:
	if IDS.has(icon):
		return icon
	return String(ALIASES.get(icon, "default"))


## Resource path of the 32px (logical size) catalog image for an icon string.
static func catalog_path(icon: String) -> String:
	var id := icon_id(icon)
	var local := "res://assets/wfw-rtm-local/%s-32.png" % id
	if FileAccess.file_exists(local) or ResourceLoader.exists(local):
		return local
	return "res://assets/wfw/%s-32.png" % id


## Texture for an icon string (never null for catalog icons; external icons that fail to decode
## fall back to the catalog default).
static func texture(icon: String) -> Texture2D:
	if is_external_icon(icon):
		var t: Texture2D = null
		if icon.begins_with("data:"):
			t = Assets.from_data_url(icon)
		elif icon.begins_with("file:"):
			t = Assets.tex(_file_url_to_path(icon))
		else:
			t = IconRegistry.resolve(icon)
		if t != null:
			return t
		return Assets.tex("res://assets/wfw/default-32.png")
	return Assets.tex(catalog_path(icon))


## Texture shown for a program item: honors the palette-limited `win31Icon` over `icon`.
static func item_texture(item: Dictionary) -> Texture2D:
	return texture(item_icon_string(item))


static func item_icon_string(item: Dictionary) -> String:
	var w: Variant = item.get("win31Icon")
	if w is String and w != "":
		return w
	return String(item.get("icon", "default"))


## External (full-colour, smooth-scaled in the browser) icons are drawn without the 32px clamp.
static func is_external_item(item: Dictionary) -> bool:
	var w: Variant = item.get("win31Icon")
	return not (w is String and w != "") and is_external_icon(String(item.get("icon", "")))


static func _file_url_to_path(url: String) -> String:
	var p := url.trim_prefix("file://")
	if p.length() > 2 and p[0] == "/" and p[2] == ":":
		p = p.substr(1)  # file:///C:/x -> C:/x
	return p.uri_decode()
