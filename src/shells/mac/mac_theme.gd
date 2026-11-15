class_name MacTheme
extends RefCounted
## Mac shell colour tokens. The design styles every colour as a hex literal and re-maps those literals for the
## dark theme (DARK.b = backgrounds/borders, DARK.t = text, DARK.s = shadows). Components ask for a colour by its
## light-theme hex, e.g. MacTheme.b("dddddd"), and get the themed Color for the current ProgramStore theme.
## `desk_override` is the user-picked desktop colour (Desktop Pictures dialog; session only).

const DARK_B := {
	"ffffff": "#1d1e21", "000000": "#050506", "dddddd": "#323337", "eeeeee": "#2a2b2f", "bbbbbb": "#4a4b50",
	"cccccc": "#3a3b3f", "999999": "#4a4b50", "444444": "#0a0a0b", "888888": "#1c1d20", "33339a": "#4a4ab8",
	"ccccff": "#3b3b70", "f6f6f6": "#45464b", "aaaaaa": "#2a2b2e", "6c6ca8": "#2b2b46", "6a6a6a": "#0c0c0d",
}
const DARK_T := {
	"000000": "#e3e4e6", "ffffff": "#ffffff", "999999": "#8c9092", "444444": "#c8c9cc", "888888": "#8c8d92",
	"808080": "#8c8d92", "33339a": "#aab0ff",
}
const DARK_S := {
	"ffffff": "#58595f", "999999": "#1c1d20", "888888": "#1c1d20", "444444": "#000000", "000000": "#000000",
	"dddddd": "#323337",
}

const DESK_PALETTE := [
	["#6c6ca8", "Periwinkle"], ["#3a6a8a", "Ocean"], ["#5a8a5a", "Fern"],
	["#8a5a7a", "Plum"], ["#9a9aa0", "Platinum"], ["#404060", "Indigo"],
]
const DEFAULT_DESK := "#6c6ca8"

static var dark := false
static var desk_override := ""


static func refresh_from_settings() -> void:
	dark = String(ProgramStore.settings.get("theme", "light")) == "dark"


static func _pick(map: Dictionary, hex: String) -> Color:
	if dark and map.has(hex):
		return Color(String(map[hex]))
	return Color("#" + hex)


## Background / border colour (light hex without '#').
static func b(hex: String) -> Color:
	return _pick(DARK_B, hex)


## Text colour.
static func t(hex: String) -> Color:
	return _pick(DARK_T, hex)


## Shadow / highlight colour.
static func s(hex: String) -> Color:
	return _pick(DARK_S, hex)


static func desktop() -> Color:
	if desk_override != "":
		return Color(desk_override)
	return b("6c6ca8")


## Drop shadow of windows / menus (rgba(0,0,0,.3) / .45).
static func shadow(alpha: float) -> Color:
	return Color(0, 0, 0, alpha)
