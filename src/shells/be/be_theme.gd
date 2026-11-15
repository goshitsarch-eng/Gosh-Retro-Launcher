class_name BeTheme
extends RefCounted
## Be shell colours. The design writes every colour as a hex literal and swaps them for dark mode through
## three lookup tables (backgrounds `b`, shadows/rings `s`, text `t`). The same tables live here:
## BeTheme.b("e8e8e8") is the light colour in light mode and the mapped colour in dark mode.
## `dark` mirrors ProgramStore.settings.theme == "dark" (set by BeShell).

const DESKTOP_DEFAULT := "336698"
const FILTER_LARGE := 0.55  ## selected icon brightness (design: filter brightness(.55 / .6))

const DARK_B := {
	"ffffff": "#1d1e21", "000000": "#050506", "c0c0c0": "#3a3b3f", "808080": "#2a2b2e", "dfdfdf": "#4a4b50",
	"000080": "#2c4f8c", "0a0a0a": "#000000", "008080": "#123a3a", "e0e0e0": "#46474c", "ffffe1": "#3b3824",
	"336698": "#1b2a3b", "d8d8d8": "#2e2f33", "e8e8e8": "#36373b", "e2e2e2": "#3a3b3f", "ffcb00": "#6e5a12",
	"a8a8a8": "#55575d", "bcbcbc": "#46474c", "e4e4e4": "#26272a", "f4f4f4": "#45464b", "d4d4d4": "#323337",
	"fafafa": "#47484d", "6a6a6a": "#0c0c0d", "989898": "#18191b", "b8b8b8": "#232427", "c8c8c8": "#46474c",
	"f0f0f0": "#45464b", "c4c4c4": "#2a2b2e", "8a8a8a": "#5a5b60", "cfcfcf": "#2a2b2e",
}
const DARK_S := {
	"ffffff": "#58595f", "dfdfdf": "#46474c", "808080": "#141517", "000000": "#000000", "0a0a0a": "#000000",
	"c0c0c0": "#3a3b3f", "999999": "#1c1d20", "888888": "#1c1d20", "a8a8a8": "#1c1d20", "6a6a6a": "#000000",
	"444444": "#000000", "c8c8c8": "#151618", "d8d8d8": "#2e2f33", "dddddd": "#323337", "b8b8b8": "#222326",
	"000080": "#6a90d8", "989898": "#1a1b1d", "e8e8e8": "#36373b", "cccccc": "#1c1d20",
}
const DARK_T := {
	"000000": "#e3e4e6", "ffffff": "#ffffff", "808080": "#8c8d92", "c0c0c0": "#9a9ba0", "444444": "#c8c9cc",
	"333333": "#cfd0d2", "888888": "#8c8d92", "8a8a8a": "#8c8d92", "999999": "#8c8d92", "1a3a8a": "#9ab8ff",
	"33339a": "#aab0ff", "000080": "#9ab8ff",
}

static var dark := false
static var _cache := {}


static func _pick(table: Dictionary, hex: String) -> Color:
	var key := "%s%s" % [hex, dark]
	var hit: Variant = _cache.get(_tid(table) + key)
	if hit != null:
		return hit
	var c := Color("#" + hex)
	if dark and table.has(hex):
		c = Color(String(table[hex]))
	_cache[_tid(table) + key] = c
	return c


static func _tid(table: Dictionary) -> String:
	return "b" if table == DARK_B else ("s" if table == DARK_S else "t")


## Background / border colour (design namespace `b`).
static func b(hex: String) -> Color:
	return _pick(DARK_B, hex)


## Shadow / highlight colour (namespace `s`).
static func s(hex: String) -> Color:
	return _pick(DARK_S, hex)


## Text colour (namespace `t`).
static func t(hex: String) -> Color:
	return _pick(DARK_T, hex)


## Desktop colour: a chosen colour is used verbatim (the design sets --desk-be directly), otherwise the themed default.
static func desktop(custom: String = "") -> Color:
	if custom != "":
		return Color(custom)
	return b(DESKTOP_DEFAULT)


static func is_dark(settings: Dictionary) -> bool:
	return String(settings.get("theme", "light")) == "dark"
