class_name W31SettingsDialog
extends W31Dialog
## Settings (General / Appearance / Batch Launch). Port of Dialogs/SettingsDialog.tsx; the
## Win95 title-bar slider is replaced by the Windows 95 scale selector (see USER_GUIDE).
## Writes through ProgramStore (persist-first transaction when the shell changes).

var form: Dictionary
var preview: W31ThemePreview
var slider_value: Control


func _init() -> void:
	super("Settings", 400)
	form = W31DialogLogic.settings_form(ProgramStore.settings)


func _cb(x: int, y: int, text: String, key: String, inverted: bool = false) -> W31Checkbox:
	var c := W31Checkbox.new(text, (form[key] == "dark") if key == "theme" else ((form[key] == "wrap") if key == "labelDisplay" else form[key]))
	c.toggled.connect(func(on: bool):
		if key == "theme":
			form.theme = "dark" if on else "light"
			if preview:
				preview.theme = form.theme
		elif key == "labelDisplay":
			form.labelDisplay = "wrap" if on else "ellipsis"
		else:
			form[key] = on)
	add_widget(c, x, y)
	return c


func _scale_combo(key: String) -> W31Combo:
	var c := W31Combo.new()
	c.set_items(["Auto", "1×", "2×", "3×", "4×"])
	c.selected = W31DialogLogic.scale_to_index(form[key])
	c.selection_changed.connect(func(i: int): form[key] = W31DialogLogic.scale_from_index(i))
	return c


func _build(cw: int) -> void:
	var inner_w := cw - 16
	# ---- General
	var g1 := W31GroupBox.new("General")
	add_widget(g1, 0, 10, Vector2(cw, 131))
	_cb(8, 22, "Auto Arrange icons", "autoArrange")
	_cb(8, 43, "Minimize on Use", "minimizeOnUse")
	_cb(8, 67, "Save Settings on Exit", "saveSettingsOnExit")
	_cb(8, 88, "Minimize to Tray on Close", "trayOnClose")
	var starter := make_button("Add Starter Groups", false, func(): ProgramStore.add_starter_workspace())
	add_widget(starter, 8, 111, starter.fit())
	# ---- Appearance
	var g2 := W31GroupBox.new("Appearance")
	add_widget(g2, 0, 151, Vector2(cw, 232))
	_cb(8, 163, "Dark Mode", "theme")
	_cb(8, 186, "Wrap item labels (show full names)", "labelDisplay")
	_cb(8, 207, "Sound Effects", "soundEnabled")
	var shell_combo := W31Combo.new()
	shell_combo.set_items(["Windows 3.1", "Windows 95"], ["win31", "win95"])
	shell_combo.select_value(form.shell)
	shell_combo.selection_changed.connect(func(_i):
		form.shell = shell_combo.value()
		_rebuild(scroll != null)
		var p := get_parent()
		if p is Control:
			place(p.size))
	add_form_row(228, "Desktop Shell:", shell_combo, inner_w - 111, 19, 8)
	preview = W31ThemePreview.new()
	preview.shell = form.shell
	preview.theme = form.theme
	preview.group_chrome_scale = float(form.groupChromeScale)
	add_widget(preview, 8, 255, Vector2(inner_w, 88))
	var scale_label := "Program Manager Scale:" if form.shell == "win31" else "Windows 95 Scale:"
	var lw := maxi(106, W31.text_w(scale_label, 12))
	var scale_key := "win31Scale" if form.shell == "win31" else "win95Scale"
	var scale_combo := _scale_combo(scale_key)
	add_label(8, 351 + 3, scale_label, lw)
	add_widget(scale_combo, 8 + lw + 5, 351, Vector2(inner_w - lw - 5, 19))
	# ---- Batch Launch
	var g3 := W31GroupBox.new("Batch Launch")
	add_widget(g3, 0, 393, Vector2(cw, 38))
	var dl := "Delay between launches:"
	var dlw := W31.text_w(dl, 12)
	add_text(8, 393 + 12 + 1, dl, 12)
	var value_w := 60
	var slider_w := inner_w - dlw - 7 - 7 - value_w
	var slider := W31Slider.new(100, 5000, 100)
	slider.value = form.launchDelay
	var value_label := W31ValueLabel.new("%dms" % form.launchDelay, value_w)
	slider.value_changed.connect(func(v: float):
		form.launchDelay = int(v)
		value_label.text = "%dms" % int(v))
	add_widget(slider, 8 + dlw + 7, 393 + 11, Vector2(slider_w, 18))
	add_widget(value_label, 8 + dlw + 7 + slider_w + 7, 393 + 12 + 1, Vector2(value_w, 13))
	# ---- buttons
	var ok := make_button("OK", true, _submit)
	add_button_row(438, [ok, make_button("Cancel", false, UIState.close_dialog)])
	_finish(438 + 4 + 22 + 8)


func _submit() -> void:
	var result := W31DialogLogic.apply_settings(ProgramStore, form)
	UIState.close_dialog()
	if not result.get("success", true):
		push_error("Failed to apply shell settings: %s" % result.get("error", "unknown"))


## Right-aligned 12px text (the "500ms" readout).
class W31ValueLabel extends Control:
	var text := "":
		set(v):
			text = v
			queue_redraw()

	func _init(p_text: String, w: int) -> void:
		text = p_text
		size = Vector2(w, 13)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tw := W31.text_w(text, 12)
		W31.text(self, size.x - tw, 0, text, W31.BLACK, 12)
