class_name W31ThemePreview
extends Control
## Settings > Appearance thumbnail (port of Dialogs/ThemePreview.tsx + .theme-preview CSS).
## Tiny text is drawn with the 1-bit WfWSans strike at 7-8px (the original used W95FA).

const COLORS := {
	"win31": {
		"light": {"desktop": "#c0c0c0", "windowBg": "#ffffff", "chrome": "#c0c0c0", "bevelLight": "#ffffff",
			"bevelDark": "#808080", "bevelDarkest": "#000000", "titlebarActive": "#000080",
			"titlebarInactive": "#808080", "titlebarText": "#ffffff", "text": "#000000"},
		"dark": {"desktop": "#2b2b2b", "windowBg": "#1f1f1f", "chrome": "#2b2b2b", "bevelLight": "#4a4a4a",
			"bevelDark": "#101010", "bevelDarkest": "#000000", "titlebarActive": "#0b2a52",
			"titlebarInactive": "#3a3a3a", "titlebarText": "#e6e6e6", "text": "#e6e6e6"},
	},
	"win95": {
		"light": {"desktop": "#008080", "windowBg": "#ffffff", "chrome": "#c0c0c0", "bevelLight": "#ffffff",
			"bevelDark": "#808080", "bevelDarkest": "#000000", "titlebarActive": "#000080",
			"titlebarInactive": "#808080", "titlebarText": "#ffffff", "titlebarGradientEnd": "#1084d0",
			"text": "#000000", "accent": "#ff0000"},
		"dark": {"desktop": "#0f2f2f", "windowBg": "#1f1f1f", "chrome": "#2b2b2b", "bevelLight": "#4a4a4a",
			"bevelDark": "#101010", "bevelDarkest": "#000000", "titlebarActive": "#0b2a52",
			"titlebarInactive": "#3a3a3a", "titlebarText": "#e6e6e6", "titlebarGradientEnd": "#1a5a8c",
			"text": "#e6e6e6", "accent": "#b0b0b0"},
	},
}

var shell := "win31":
	set(v):
		shell = v
		queue_redraw()
var theme_name := "light":
	set(v):
		theme_name = v
		queue_redraw()
var group_chrome_scale := 1.0:
	set(v):
		group_chrome_scale = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func colors_for(p_shell: String, p_theme: String) -> Dictionary:
	var out := {}
	var src: Dictionary = COLORS.get(p_shell, COLORS.win31).get(p_theme, COLORS.win31.light)
	for k in src:
		out[k] = Color(src[k])
	return out


func _t(x: float, y: float, s: String, px: int, color: Color, bold: bool = false, shadow: bool = false) -> void:
	W31.text(self, x, y, s, color, px, {"bold": bold, "desktop_shadow": shadow, "line_height": px + 3})


func _draw() -> void:
	var c := colors_for(shell, theme_name)
	var r := Rect2(Vector2.ZERO, size)
	Px.fill_rect(self, r, c.desktop)
	if shell == "win95":
		_draw95(c)
	else:
		_draw31(c)
	Px.outline(self, r, W31.BLACK)


func _draw31(c: Dictionary) -> void:
	var w := size.x
	var title_h := int(roundf(17 * group_chrome_scale))
	Px.fill(self, 1, 1, w - 2, 14, c.chrome)
	Px.hline(self, 1, 14, w - 2, W31.BLACK)
	_t(5, 2, "Program Manager", 8, c.text, true)
	Px.fill(self, 1, 15, w - 2, 14, c.chrome)
	Px.hline(self, 1, 28, w - 2, Color(0, 0, 0, 0.45))
	var mx := 7.0
	for label in ["File", "Options", "Window", "Help"]:
		_t(mx, 17, label, 7, c.text)
		mx += W31.text_w(label, 7) + 12
	var win := Rect2(12, 32, floorf(w * 0.62), 54)
	Px.fill_rect(self, win, c.chrome)
	Px.outline(self, win, c.bevelDarkest)
	Px.hline(self, win.position.x + 1, win.position.y + 1, win.size.x - 2, c.bevelLight)
	Px.vline(self, win.position.x + 1, win.position.y + 1, win.size.y - 2, c.bevelLight)
	Px.hline(self, win.position.x + 1, win.end.y - 2, win.size.x - 2, c.bevelDark)
	Px.vline(self, win.end.x - 2, win.position.y + 1, win.size.y - 2, c.bevelDark)
	var tb := Rect2(win.position.x + 1, win.position.y + 1, win.size.x - 2, title_h)
	Px.fill_rect(self, tb, c.titlebarActive)
	_t(tb.position.x + 3, tb.position.y + (title_h - 11) / 2, "Main", 8, c.titlebarText, true)
	var gx := tb.end.x - 3 - 18
	var gy := tb.position.y + (title_h - 7) / 2
	Px.fill(self, gx + 7, gy, 2, 7, c.titlebarText)
	Px.fill(self, gx, gy + 3, 18, 2, c.titlebarText)
	var body := Rect2(win.position.x + 3, tb.end.y + 2, win.size.x - 6, win.end.y - 3 - tb.end.y - 2)
	Px.fill_rect(self, body, c.windowBg)
	var bx := body.position.x + floorf((body.size.x - (3 * 12 + 2 * 8)) / 2.0)
	var by := body.position.y + floorf((body.size.y - 16) / 2.0)
	for i in 3:
		var col: Color = [c.titlebarActive, c.titlebarInactive, c.bevelDark][i]
		Px.fill(self, bx + i * 20, by, 12, 16, col)
		Px.outline(self, Rect2(bx + i * 20, by, 12, 16), Color(0, 0, 0, 0.65))
	_t(12 + 54 / 2.0 - W31.text_w("Accessories", 7) / 2.0, size.y - 7 - 10, "Accessories", 7, c.titlebarText, false, true)


func _draw95(c: Dictionary) -> void:
	var title_h := int(roundf(18 * group_chrome_scale))
	# desktop icon
	Px.fill(self, 8 + 6, 8, 18, 18, c.chrome)
	Px.outline(self, Rect2(8 + 6, 8, 18, 18), W31.BLACK)
	_t(8, 8 + 18 + 2, "My Computer", 6, c.titlebarText, false, true)
	var win := Rect2(40, 9, floorf(size.x * 0.64), 68)
	Px.fill_rect(self, win, c.chrome)
	Px.edge(self, win, c.bevelLight, c.bevelDarkest)
	Px.edge(self, win.grow(-1), c.bevelLight, c.bevelDarkest)
	var tb := Rect2(win.position.x + 2, win.position.y + 2, win.size.x - 4, title_h)
	var grad_end: Color = c.get("titlebarGradientEnd", c.titlebarActive)
	var steps := int(tb.size.x)
	for i in steps:
		Px.fill(self, tb.position.x + i, tb.position.y, 1, title_h, c.titlebarActive.lerp(grad_end, float(i) / maxf(steps - 1, 1)))
	_t(tb.position.x + 3, tb.position.y + (title_h - 11) / 2, "Programs", 8, c.titlebarText, true)
	var ty := tb.end.y
	Px.fill(self, tb.position.x, ty, tb.size.x, 12, c.chrome)
	Px.hline(self, tb.position.x, ty + 11, tb.size.x, Color(0, 0, 0, 0.45))
	_t(tb.position.x + 4, ty + 1, "File Edit View", 7, c.text)
	var body := Rect2(tb.position.x + 2, ty + 12 + 2, tb.size.x - 4, win.end.y - 4 - ty - 12 - 2)
	Px.fill_rect(self, body, c.windowBg)
	var bx := body.position.x + floorf((body.size.x - 52) / 2.0)
	var by := body.position.y + floorf((body.size.y - 16) / 2.0)
	for i in 3:
		var col: Color = [c.titlebarActive, c.get("accent", c.bevelDark), c.bevelDark][i]
		Px.fill(self, bx + i * 20, by, 12, 16, col)
		Px.outline(self, Rect2(bx + i * 20, by, 12, 16), Color(0, 0, 0, 0.65))
	# taskbar
	var tbar := Rect2(0, size.y - 19, size.x, 19)
	Px.fill_rect(self, tbar, c.chrome)
	Px.hline(self, 0, tbar.position.y, size.x, c.bevelLight)
	var start := Rect2(3, tbar.position.y + 3, 14 + W31.text_w("Start", 7) + 4, 14)
	Px.edge(self, start, c.bevelLight, c.bevelDarkest)
	_t(start.position.x + 5, start.position.y + 2, "Start", 7, c.text, true)
	var tray_w := W31.text_w("3:11 PM", 7) + 8
	var tray := Rect2(size.x - 3 - tray_w, tbar.position.y + 3, tray_w, 14)
	Px.edge(self, tray, c.bevelDark, c.bevelLight)
	_t(tray.position.x + 4, tray.position.y + 2, "3:11 PM", 7, c.text)
