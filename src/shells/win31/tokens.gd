class_name WfwTokens
extends RefCounted
## Measurements from the supplied WfW 3.11 captures. Port of shells/win31/tokens.ts.

const REFERENCE_WIDTH := 640
const REFERENCE_HEIGHT := 480

const M := {
	"outerFrame": 3, "captionHeight": 18, "menuHeight": 20, "menuLeftInset": 6, "menuGap": 17,
	"childFrame": 3, "childCaptionHeight": 18, "captionButton": 16, "scrollbar": 16,
	"programIcon": 32, "programCellWidth": 75, "programCellHeight": 72,
	"programGridInsetX": 0, "programGridInsetY": 0,
	"groupIconWidth": 32, "groupIconHeight": 25, "groupCellWidth": 75, "groupCellHeight": 58,
	"labelLineHeight": 13, "dialogControlHeight": 22,
}


static func m(key: String) -> int:
	return M[key]


static func resolve_auto_scale(width: float, height: float) -> int:
	return ShellScale.resolve_auto(width, height)
