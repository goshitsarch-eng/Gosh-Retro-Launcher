class_name Win95Tokens
extends RefCounted
## Logical-pixel measurements from a clean Windows 95 RTM install at 640x480/96 DPI.
## Port of shells/win95/tokens.ts. Values are never multiplied in components; the shell root
## owns the single integer transform.

const REFERENCE_WIDTH := 640
const REFERENCE_HEIGHT := 480

const M := {
	"taskbarHeight": 28, "taskbarTopHighlight": 1, "taskbarInset": 2,
	"startButtonWidth": 54, "startButtonHeight": 22, "startButtonIcon": 16,
	"taskButtonHeight": 22, "taskButtonMaxWidth": 160,
	"trayHeight": 22, "trayWidth": 63, "trayMinWidth": 63,
	"desktopIcon": 32, "desktopCellWidth": 75, "desktopCellHeight": 74,
	"desktopInsetX": 4, "desktopInsetY": 4,
	"smallIcon": 16, "largeIcon": 32,
	"startTopIcon": 32, "startTopItemHeight": 32, "startSubIcon": 16, "startSubItemHeight": 22,
	"startStripWidth": 21, "startMenuWidth": 164, "startMenuHeight": 235, "startSeparatorHeight": 7,
	"menuBorder": 2, "menuHorizontalInset": 3, "menuSeparatorHeight": 6,
	"windowFrame": 3, "captionHeight": 18, "captionInset": 2, "captionButton": 16,
	"captionButtonWidth": 16, "captionButtonHeight": 14, "captionButtonGap": 2,
	"menuBarHeight": 20, "statusBarHeight": 20, "scrollbar": 16, "resizeBorder": 3,
	"dialogFrame": 3, "dialogCaptionHeight": 18,
	"buttonHeight": 23, "buttonMinWidth": 75, "inputHeight": 21,
	"runDialogWidth": 347, "runDialogHeight": 163,
	"shutdownDialogWidth": 347, "shutdownDialogHeight": 222,
	"findWindowWidth": 439, "findWindowHeight": 237,
	"labelLineHeight": 13, "systemFontPx": 11, "submenuDelayMs": 220, "doubleClickMs": 500,
}

static func m(key: String) -> int:
	return M[key]


static func resolve_auto_scale(width: float, height: float) -> int:
	return ShellScale.resolve_auto(width, height)
