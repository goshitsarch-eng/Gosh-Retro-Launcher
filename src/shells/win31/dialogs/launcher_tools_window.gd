class_name LauncherToolsWindow
extends Window
## Separate native "Launcher Tools" window (port of components/LauncherTools/LauncherTools.tsx +
## styles/launcher-tools.css). A plain flat-gray form built from standard Godot controls:
## shell/scale/desktop-mode/sound/tray (persist-first shell switch), Export All / Import All, .GRP
## import/export, URL launcher, launch groups (launch, new, rename, renumber, delete), per-item
## launch profile, workspace profiles and backups.
## The shell calls LauncherToolsWindow.show_singleton(host).

static var _instance: LauncherToolsWindow

var status_label: Label
var _root: VBoxContainer
var _content: VBoxContainer

# state (mirrors the React component)
var _form: Dictionary
var _selected_group := ""
var _selected_profile := ""
var _selected_item_key := ""
var _profile_name := ""
var _rename_profile := ""
var _url_name := ""
var _url_value := "https://"
var _launching := false
var _backups: Array = []
var _building := false
var _ready_done := false
var _ui_scale := 1.0  # content scale applied to this native window (HiDPI)
var _pending_profile := ""  # profile id waiting for the Apply confirmation
var profile_confirm: ConfirmationDialog
var profile_store: Node  # store profile Apply and backup Restore act on; null means ProgramStore (tests pass a scratch store)
var _pending_restore := ""  # backup id waiting for the Restore confirmation
var restore_confirm: ConfirmationDialog
var import_confirm: ConfirmationDialog  # Import All replaces everything, so it asks first
var _import_pending := false
var group_delete_confirm: ConfirmationDialog
var _pending_group_delete := 0  # launch group number waiting for the Delete confirmation
var _new_group_name := ""
var _new_group_button: Button
var _group_names := {}  # launch group number -> name being typed in its row

# widgets that tests/automation reach
var shell_option: OptionButton
var scale_option: OptionButton
var desktop_check: CheckBox
var sound_check: CheckBox
var tray_check: CheckBox


## Shows (or focuses) the single Launcher Tools window as a child of `host`.
static func show_singleton(host: Node) -> LauncherToolsWindow:
	if _instance == null or not is_instance_valid(_instance):
		_instance = LauncherToolsWindow.new()
		host.add_child(_instance)
	_instance.show()
	_instance.grab_focus()
	return _instance


const BASE_SIZE := Vector2i(680, 720)
const BASE_MIN_SIZE := Vector2i(480, 360)
## Layout caps so the form fits BASE_SIZE.x and still works at BASE_MIN_SIZE.x with no horizontal
## clipping: drop-downs do not grow to their longest entry, fields start small and stretch, rows
## wrap (HFlowContainer) and long text wraps.
const FIELD_MIN_W := 120
const OPTION_MIN_W := 120
const COUNT_W := 76


func _init() -> void:
	title = "Launcher Tools"
	size = BASE_SIZE
	min_size = BASE_MIN_SIZE
	exclusive = false
	transient = false
	close_requested.connect(_on_close)


## Window sizes are physical pixels: scale them with the content so the form keeps its layout, and
## never exceed the usable screen area.
func _apply_scale() -> void:
	var before := _ui_scale
	_ui_scale = ShellScale.apply_dialog_scale(self)
	min_size = Vector2i(Vector2(BASE_MIN_SIZE) * _ui_scale)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(get_window_id()))
	var wanted := Vector2i(Vector2(size) * (_ui_scale / before)) if before > 0.0 and _ready_done else Vector2i(Vector2(BASE_SIZE) * _ui_scale)
	size = Vector2i(mini(wanted.x, usable.size.x), mini(wanted.y, usable.size.y)).max(min_size)


func _ready() -> void:
	_apply_scale()
	_ready_done = true
	dpi_changed.connect(_apply_scale)
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = Color("#d4d0c8")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	var footer := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("#d4d0c8")
	fs.border_color = Color("#777777")
	fs.border_width_top = 1
	fs.content_margin_left = 18
	fs.content_margin_right = 18
	fs.content_margin_top = 7
	fs.content_margin_bottom = 7
	footer.add_theme_stylebox_override("panel", fs)
	status_label = Label.new()
	status_label.text = "Ready."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.set("accessibility_live", 1)  # LIVE_POLITE; enum moved DisplayServer -> AccessibilityServer in 4.7. Old footer was role="status"
	status_label.set_meta("auto_id", "tools.status")
	footer.add_child(status_label)
	_root.add_child(footer)
	_form = LauncherToolsLogic.appearance_form(ProgramStore.settings)
	_selected_group = ProgramStore.groups[0].id if ProgramStore.groups.size() > 0 else ""
	if ProgramStore.workspace_profiles.size() > 0:
		_selected_profile = ProgramStore.workspace_profiles[0].id
		_rename_profile = ProgramStore.workspace_profiles[0].name
	_ensure_profile_confirm()
	_ensure_restore_confirm()
	_ensure_import_confirm()
	_ensure_group_delete_confirm()
	ProgramStore.settings_changed.connect(_on_settings)
	ProgramStore.groups_changed.connect(_rebuild)
	ProgramStore.profiles_changed.connect(_rebuild)
	ProgramStore.data_reloaded.connect(_on_settings)
	_refresh_backups()
	_rebuild()


func _on_close() -> void:
	hide()
	queue_free()
	_instance = null


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


# ------------------------------------------------------------------ theme

static func _box(bg: Color, border: Color, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	if shadow:
		s.border_width_right = 2
		s.border_width_bottom = 2
	return s


static func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13
	var ink := Color("#111111")
	for type_name in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", type_name, ink)
		t.set_color("font_hover_color", type_name, ink)
		t.set_color("font_pressed_color", type_name, ink)
		t.set_color("font_focus_color", type_name, ink)
		t.set_color("font_disabled_color", type_name, Color("#777777"))
	t.set_color("font_color", "Label", ink)
	for type_name in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type_name, _box(Color("#d4d0c8"), Color("#666666"), true))
		t.set_stylebox("hover", type_name, _box(Color("#dedbd2"), Color("#666666"), true))
		t.set_stylebox("pressed", type_name, _box(Color("#c4c0b8"), Color("#444444")))
		t.set_stylebox("disabled", type_name, _box(Color("#d4d0c8"), Color("#999999")))
		t.set_stylebox("focus", type_name, _box(Color(0, 0, 0, 0), Color("#000080")))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", _box(Color.WHITE, Color("#666666")))
	t.set_stylebox("focus", "LineEdit", _box(Color.WHITE, Color("#000080")))
	t.set_stylebox("read_only", "LineEdit", _box(Color("#eeeeee"), Color("#666666")))
	t.set_color("font_color", "LineEdit", ink)
	t.set_stylebox("normal", "TextEdit", _box(Color.WHITE, Color("#666666")))
	t.set_stylebox("focus", "TextEdit", _box(Color.WHITE, Color("#000080")))
	t.set_color("font_color", "TextEdit", ink)
	t.set_stylebox("panel", "PanelContainer", _box(Color("#ece9d8"), Color("#777777")))
	t.set_stylebox("panel", "PopupMenu", _box(Color.WHITE, Color("#666666")))
	t.set_color("font_color", "PopupMenu", ink)
	var dlg_panel := StyleBoxFlat.new()  # the Apply-profile confirmation (ConfirmationDialog)
	dlg_panel.bg_color = Color("#d4d0c8")
	dlg_panel.set_content_margin_all(8)
	t.set_stylebox("panel", "AcceptDialog", dlg_panel)
	return t


# ----------------------------------------------------------------- builders

func _section(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _padded(Color("#ece9d8"), 11))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var h := Label.new()
	h.text = title_text
	h.add_theme_font_size_override("font_size", 14)
	box.add_child(h)
	panel.add_child(box)
	_content.add_child(panel)
	return box


static func _padded(bg: Color, pad: int) -> StyleBoxFlat:
	var s := _box(bg, Color("#777777"))
	s.set_content_margin_all(pad)
	return s


## A row of controls that wraps onto more lines when the window is narrow.
func _row(parent: Control) -> HFlowContainer:
	var r := _flow(7)
	parent.add_child(r)
	return r


static func _flow(h_sep: int) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", h_sep)
	r.add_theme_constant_override("v_separation", 6)
	return r


## A label whose text wraps to the width it gets instead of widening the window.
static func _wrapped(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A drop-down that keeps a small minimum width and trims long entries (by default an OptionButton
## is as wide as its longest entry, so one long group or program name widened the whole window).
static func _fit_option(o: OptionButton, min_w: int = OPTION_MIN_W) -> OptionButton:
	o.fit_to_longest_item = false
	o.clip_text = true
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	o.custom_minimum_size.x = min_w
	return o


func _button(parent: Control, text: String, cb: Callable, disabled: bool = false, id: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	if id != "":
		b.set_meta("auto_id", "tools." + id)
	parent.add_child(b)
	return b


func _labeled(parent: Control, label: String, ctl: Control, expand: bool = true) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	if expand:
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x = maxf(ctl.custom_minimum_size.x, FIELD_MIN_W)
	var l := Label.new()
	l.text = label
	v.add_child(l)
	if ctl.accessibility_name == "":
		ctl.accessibility_name = label  # screen readers announce the field with its caption
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ctl)
	parent.add_child(v)
	return v


func _group_option(parent: Control, on_change: Callable) -> OptionButton:
	var o := _fit_option(OptionButton.new())
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for g in ProgramStore.groups:
		o.add_item(g.name)
		o.set_item_metadata(o.item_count - 1, g.id)
	for i in o.item_count:
		if o.get_item_metadata(i) == _selected_group:
			o.select(i)
	o.item_selected.connect(func(i: int):
		_selected_group = String(o.get_item_metadata(i))
		on_change.call())
	parent.add_child(o)
	return o


func _check(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _line(text: String, placeholder: String, cb: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size.x = FIELD_MIN_W
	e.text_changed.connect(cb)
	return e


func _scale_option(value: Variant, cb: Callable) -> OptionButton:
	var o := _fit_option(OptionButton.new())
	o.add_item("Auto")
	for v in Types.SCALE_FACTORS:
		o.add_item("%d×" % v)
	o.select(W31DialogLogic.scale_to_index(value))
	o.tooltip_text = "Auto adapts to your display (HiDPI / Retina / 4K) and window size, keeping text and icons crisp. Pick 1x-4x to force a size."
	o.item_selected.connect(func(i: int): cb.call(W31DialogLogic.scale_from_index(i)))
	return o


# -------------------------------------------------------------------- build

func _on_settings() -> void:
	_form = LauncherToolsLogic.appearance_form(ProgramStore.settings)
	_rebuild()


func _rebuild() -> void:
	if _content == null or _building:
		return
	_building = true
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var groups: Array = ProgramStore.groups
	if _selected_group == "" and groups.size() > 0:
		_selected_group = groups[0].id
	if _selected_group != "" and ProgramStore.find_group(_selected_group).is_empty():
		_selected_group = groups[0].id if groups.size() > 0 else ""
	if _selected_profile == "" and ProgramStore.workspace_profiles.size() > 0:
		_selected_profile = ProgramStore.workspace_profiles[0].id
		_rename_profile = ProgramStore.workspace_profiles[0].name
	_build_header()
	_build_appearance()
	_build_transfer()
	_build_groups()
	_build_url()
	_build_launch()
	_build_profile_editor()
	_build_workspaces()
	_build_backups()
	_building = false


func _build_header() -> void:
	var h := VBoxContainer.new()
	var t := Label.new()
	t.text = "Launcher Tools"
	t.add_theme_font_size_override("font_size", 22)
	h.add_child(t)
	var p := _wrapped("Modern launcher features are kept outside the Windows 3.11 Program Manager surface.")
	p.add_theme_color_override("font_color", Color("#444444"))
	h.add_child(p)
	_content.add_child(h)


func _build_appearance() -> void:
	var s := _section("Shell and appearance")
	s.add_child(_wrapped("Active shell: %s" % LauncherToolsLogic.shell_label(String(ProgramStore.settings.get("shell", "win31")))))
	var grid := _flow(9)
	s.add_child(grid)
	shell_option = _fit_option(OptionButton.new())
	for sh in Types.SHELLS:
		shell_option.add_item(LauncherToolsLogic.shell_label(sh))
	shell_option.select(maxi(0, Types.SHELLS.find(_form.shell)))
	shell_option.set_meta("auto_id", "tools.shell")
	shell_option.item_selected.connect(func(i: int):
		_form.shell = Types.SHELLS[i]
		_rebuild())
	_labeled(grid, "Shell", shell_option)
	var is31: bool = _form.shell == "win31"
	var skey := Types.scale_key(String(_form.shell))
	scale_option = _scale_option(_form[skey], func(v: Variant):
		_form[skey] = v)
	scale_option.set_meta("auto_id", "tools.scale")
	_labeled(grid, "WfW scale" if is31 else LauncherToolsLogic.shell_label(String(_form.shell)) + " scale", scale_option)
	var checks := _flow(12)
	s.add_child(checks)
	desktop_check = _check(checks, "WfW gray desktop mode", _form.win31DesktopMode, func(on: bool): _form.win31DesktopMode = on)
	sound_check = _check(checks, "Sound effects", _form.soundEnabled, func(on: bool): _form.soundEnabled = on)
	tray_check = _check(checks, "Minimize to tray on close", _form.trayOnClose, func(on: bool): _form.trayOnClose = on)
	var apply := _button(s, "Apply", _apply_appearance, false, "apply")
	apply.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _apply_appearance() -> void:
	var r := LauncherToolsLogic.apply_appearance(ProgramStore, _form)
	if not r.success:
		_form.shell = r.previousShell
	set_status(r.status)
	if not r.success:
		_rebuild()


func _build_groups() -> void:
	var s := _section("Windows 3.x groups")
	var row := _row(s)
	row.set_meta("auto_id", "tools.groups-row")
	_group_option(row, func(): pass)
	_button(row, "Import .GRP...", func(): _import_grp(), false, "import-grp")
	_button(row, "Export .GRP...", func(): _export_grp(), _selected_group == "", "export-grp")


func _build_transfer() -> void:
	var s := _section("Export and import everything")
	s.add_child(_wrapped("One file with all program groups, programs, launch groups, settings and workspace profiles."))
	var row := _row(s)
	_button(row, "Export All...", func(): _export_all(), false, "export-all")
	_button(row, "Import All...", _request_import_all, false, "import-all")


func _import_grp() -> void:
	var result: Dictionary = await Platform.import_grp()
	var info_fn := func(path: String) -> Dictionary: return Platform.get_app_info(path)
	# get_app_info may be a coroutine in the platform layer; resolve each item first.
	var prepared := result
	if result.get("success", false) and result.has("group"):
		var g: Dictionary = result.group.duplicate(true)
		var infos := {}
		for it in g.items:
			infos[String(it.path)] = await Platform.get_app_info(String(it.path))
		info_fn = func(path: String) -> Dictionary: return infos.get(path, {})
		prepared = {"success": true, "group": g}
	var r := LauncherToolsLogic.import_grp(ProgramStore, prepared, info_fn)
	if r.has("groupId"):
		_selected_group = r.groupId
		_rebuild()
	if r.status != "":
		set_status(r.status)


func _export_grp() -> void:
	var group := ProgramStore.find_group(_selected_group)
	if group.is_empty():
		return
	var result: Dictionary = await Platform.export_grp(group)
	var notes := (group.items as Array).filter(func(i): return Notes.is_note(i)).size()
	var st := LauncherToolsLogic.export_grp_status(String(group.name), result, notes)
	if st != "":
		set_status(st)


func _export_all() -> void:
	var result: Dictionary = await Platform.export_all()
	var st := LauncherToolsLogic.export_all_status(result)
	if st != "" and is_inside_tree():
		set_status(st)


## Import All replaces everything (after an automatic backup), so it asks first; only OK imports.
func _request_import_all() -> void:
	_ensure_import_confirm()
	_import_pending = true
	import_confirm.dialog_text = DataTransfer.IMPORT_CONFIRM
	if import_confirm.is_inside_tree():
		import_confirm.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		import_confirm.content_scale_factor = _ui_scale
		import_confirm.reset_size()
		import_confirm.popup_centered()


func _ensure_import_confirm() -> void:
	if import_confirm != null:
		return
	import_confirm = ConfirmationDialog.new()
	import_confirm.title = DataTransfer.IMPORT_TITLE
	import_confirm.ok_button_text = "OK"
	import_confirm.cancel_button_text = "Cancel"
	import_confirm.confirmed.connect(func(): _confirm_import_all())
	import_confirm.canceled.connect(func(): _import_pending = false)
	add_child(import_confirm)


func _confirm_import_all() -> void:
	if not _import_pending:
		return
	_import_pending = false
	var result: Dictionary = await Platform.import_data()
	var st := LauncherToolsLogic.import_all_status(result)
	if st != "" and is_inside_tree():
		set_status(st)


func _build_url() -> void:
	var s := _section("URL launcher")
	var grid := _flow(9)
	s.add_child(grid)
	var add_btn: Button
	var name_edit := _line(_url_name, "", func(t: String):
		_url_name = t
		add_btn.disabled = ProgramStore.groups.is_empty() or _url_name.strip_edges().is_empty())
	name_edit.set_meta("auto_id", "tools.url-name")
	_labeled(grid, "Name", name_edit)
	var url_edit := _line(_url_value, "", func(t: String): _url_value = t)
	url_edit.set_meta("auto_id", "tools.url-value")
	var lv := _labeled(grid, "URL", url_edit)
	lv.size_flags_stretch_ratio = 2.0
	var gv := VBoxContainer.new()
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gv.custom_minimum_size.x = OPTION_MIN_W
	var gl := Label.new()
	gl.text = "Group"
	gv.add_child(gl)
	_group_option(gv, func(): pass)
	grid.add_child(gv)
	add_btn = _button(s, "Add URL", func():
		var st := LauncherToolsLogic.add_url(ProgramStore, _selected_group, _url_name, _url_value)
		if st != "":
			_url_name = ""
			set_status(st)
			_rebuild(), ProgramStore.groups.is_empty() or _url_name.strip_edges().is_empty(), "add-url")
	add_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _build_launch() -> void:
	var s := _section("Launch groups")
	var names: Dictionary = ProgramStore.launch_group_names()
	var buckets := LaunchGroups.collect_launch_groups(ProgramStore.groups)
	var row := _row(s)
	var spin := SpinBox.new()
	spin.min_value = 100
	spin.max_value = 5000
	spin.step = 100
	spin.value = int(ProgramStore.settings.get("launchDelay", 500))
	spin.set_meta("auto_id", "tools.delay")
	spin.value_changed.connect(func(v: float): LauncherToolsLogic.set_delay(ProgramStore, v))
	_labeled(row, "Delay between items", spin, false)
	var all := _button(row, "Launching..." if _launching else "Launch All", func(): _launch(buckets), _launching or buckets.is_empty(), "launch-all")
	all.size_flags_vertical = Control.SIZE_SHRINK_END
	var rows := LauncherToolsLogic.launch_group_rows(ProgramStore.groups, names)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	s.add_child(list)
	for r in rows:
		_launch_group_row(list, r, buckets)
	if rows.is_empty():
		var l := _wrapped("No launch groups yet. Name one below, then pick its programs with Batch group in the next section.")
		l.add_theme_color_override("font_color", Color("#555555"))
		s.add_child(l)
	var add_row := _row(s)
	var name_edit := _line(_new_group_name, "New launch group name", func(t: String):
		_new_group_name = t
		if is_instance_valid(_new_group_button):
			_new_group_button.disabled = LaunchGroups.clean_name(t) == "")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.max_length = LaunchGroups.MAX_NAME_LENGTH
	name_edit.accessibility_name = "New launch group name"
	name_edit.set_meta("auto_id", "tools.launch-group-new-name")
	add_row.add_child(name_edit)
	_new_group_button = _button(add_row, "New launch group", func():
		var st := LauncherToolsLogic.new_launch_group(ProgramStore, _new_group_name)
		_new_group_name = ""
		set_status(st)
		_rebuild(), LaunchGroups.clean_name(_new_group_name) == "", "launch-group-new")


## One launch group: number (choosing a taken one swaps), name + Rename, size, Launch, Delete. Two
## blocks that sit side by side when there is room and stack when the window is narrow (the name
## field takes the spare width).
func _launch_group_row(list: VBoxContainer, r: Dictionary, buckets: Array) -> void:
	var n := int(r.number)
	var row := _flow(7)
	row.set_meta("auto_id", "tools.launch-group-row-%d" % n)
	list.add_child(row)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	var num := _fit_option(OptionButton.new(), 84)
	for v in range(1, LaunchGroups.MAX_GROUP + 1):
		num.add_item("Group %d" % v)
		num.set_item_metadata(num.item_count - 1, v)
	num.select(clampi(n - 1, 0, LaunchGroups.MAX_GROUP - 1))
	num.accessibility_name = "Number of group %d" % n
	num.tooltip_text = "Choosing a number another group has swaps the two."
	num.set_meta("auto_id", "tools.launch-group-number-%d" % n)
	num.item_selected.connect(func(i: int):
		set_status(LauncherToolsLogic.renumber_launch_group(ProgramStore, n, int(num.get_item_metadata(i))))
		_rebuild())
	grid.add_child(num)
	var typed := String(_group_names.get(n, r.name))
	var name_edit := _line(typed, "No name", func(t: String): _group_names[n] = t)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.max_length = LaunchGroups.MAX_NAME_LENGTH
	name_edit.accessibility_name = "Name of group %d" % n
	name_edit.set_meta("auto_id", "tools.launch-group-name-%d" % n)
	grid.add_child(name_edit)
	_button(grid, "Rename", func():
		set_status(LauncherToolsLogic.rename_launch_group(ProgramStore, n, String(_group_names.get(n, r.name))))
		_group_names.erase(n)
		_rebuild(), false, "launch-group-rename-%d" % n)
	var tail := HBoxContainer.new()
	tail.add_theme_constant_override("separation", 7)
	row.add_child(tail)
	var count := Label.new()
	count.text = String(r.right)
	count.custom_minimum_size.x = COUNT_W
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tail.add_child(count)
	var bucket := []
	for b in buckets:
		if int(b.groupNumber) == n:
			bucket = [b]
	_button(tail, "Launch", func(): _launch(bucket), _launching or bucket.is_empty(), "launch-group-%d" % n)
	_button(tail, "Delete", func(): _request_group_delete(n), false, "launch-group-delete-%d" % n)


func _request_group_delete(number: int) -> void:
	_ensure_group_delete_confirm()
	_pending_group_delete = number
	group_delete_confirm.dialog_text = LauncherToolsLogic.delete_launch_group_confirmation(
		ProgramStore.groups, ProgramStore.launch_group_names(), number)
	if group_delete_confirm.is_inside_tree():
		group_delete_confirm.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		group_delete_confirm.content_scale_factor = _ui_scale
		group_delete_confirm.reset_size()
		group_delete_confirm.popup_centered()


func _ensure_group_delete_confirm() -> void:
	if group_delete_confirm != null:
		return
	group_delete_confirm = ConfirmationDialog.new()
	group_delete_confirm.title = "Delete Launch Group"
	group_delete_confirm.ok_button_text = "Delete"
	group_delete_confirm.cancel_button_text = "Cancel"
	group_delete_confirm.confirmed.connect(_confirm_group_delete)
	group_delete_confirm.canceled.connect(func(): _pending_group_delete = 0)
	add_child(group_delete_confirm)


func _confirm_group_delete() -> void:
	var n := _pending_group_delete
	_pending_group_delete = 0
	if n > 0:
		set_status(LauncherToolsLogic.delete_launch_group(ProgramStore, n))
		_group_names.erase(n)
		_rebuild()


func _launch(buckets: Array) -> void:
	if _launching or buckets.is_empty():
		return
	_launching = true
	set_status(LauncherToolsLogic.launch_status_start(buckets, ProgramStore.launch_group_names()))
	_rebuild()
	var results: Array = await LaunchGroups.launch_group_buckets(self, buckets, ProgramStore.settings.get("launchDelay", 500),
		Callable(), func(items: Array, delay: Variant) -> Array: return await Platform.launch_batch(items, delay))
	_launching = false
	set_status(LauncherToolsLogic.launch_status_done(results))
	_rebuild()


func _build_profile_editor() -> void:
	var s := _section("Launch profile and batch metadata")
	var opt := _fit_option(OptionButton.new())
	opt.add_item("Select a program item...")
	opt.set_item_metadata(0, "")
	var choices := LauncherToolsLogic.item_choices(ProgramStore.groups)
	for c in choices:
		opt.add_item(c.label)
		opt.set_item_metadata(opt.item_count - 1, c.key)
		if c.key == _selected_item_key:
			opt.select(opt.item_count - 1)
	opt.set_meta("auto_id", "tools.item-select")
	opt.item_selected.connect(func(i: int):
		_selected_item_key = String(opt.get_item_metadata(i))
		_rebuild())
	s.add_child(opt)
	var parts := _selected_item_key.split(":")
	if parts.size() != 2:
		return
	var group := ProgramStore.find_group(parts[0])
	var item := ProgramStore.find_item(parts[0], parts[1])
	if group.is_empty() or item.is_empty():
		return
	var args := String(item.get("arguments", ""))
	var wd := String(item.get("workingDir", ""))
	var env := String(item.get("environment", ""))
	var mode := String(item.get("runMode", "normal"))
	var lg := int(item.get("launchGroup", 0))
	var box := _flow(8)
	box.add_theme_constant_override("v_separation", 8)
	s.add_child(box)
	var a_edit := _line(args, "", func(t: String): args = t)
	_labeled(box, "Arguments", a_edit)
	var w_edit := _line(wd, "", func(t: String): wd = t)
	_labeled(box, "Working directory", w_edit)
	var e_edit := TextEdit.new()
	e_edit.text = env
	e_edit.placeholder_text = "KEY=VALUE"
	e_edit.custom_minimum_size = Vector2(0, 60)
	e_edit.text_changed.connect(func(): env = e_edit.text)
	_labeled(box, "Environment", e_edit)
	var m_opt := _fit_option(OptionButton.new())
	for m in ["Normal", "Minimized", "Maximized"]:
		m_opt.add_item(m)
	m_opt.select(Types.RUN_MODES.find(mode))
	m_opt.item_selected.connect(func(i: int): mode = Types.RUN_MODES[i])
	_labeled(box, "Run mode", m_opt)
	var lg_opt := _fit_option(OptionButton.new())
	var stored_lg := lg
	for label in LauncherToolsLogic.batch_group_labels(ProgramStore.launch_group_names(), stored_lg):
		lg_opt.add_item(label)
	lg_opt.select(lg if lg <= LaunchGroups.MAX_GROUP else LaunchGroups.MAX_GROUP + 1)
	lg_opt.set_meta("auto_id", "tools.batch-group")
	lg_opt.item_selected.connect(func(i: int): lg = LauncherToolsLogic.batch_group_value(i, stored_lg))
	_labeled(box, "Batch group", lg_opt)
	var save := _button(s, "Save launch profile", func():
		var st := LauncherToolsLogic.save_launch_profile(ProgramStore, parts[0], parts[1],
			LauncherToolsLogic.launch_profile_updates(args, wd, env, mode, lg))
		set_status(st), false, "save-profile")
	save.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _build_workspaces() -> void:
	var s := _section("Workspace profiles")
	var profiles: Array = ProgramStore.workspace_profiles
	var r1 := _row(s)
	var name_edit := _line(_profile_name, "New profile name", func(t: String): _profile_name = t)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.set_meta("auto_id", "tools.profile-name")
	r1.add_child(name_edit)
	_button(r1, "Save current workspace", func():
		var r := LauncherToolsLogic.save_profile(ProgramStore, _profile_name)
		_profile_name = ""
		_selected_profile = r.id
		for p in ProgramStore.workspace_profiles:
			if p.id == r.id:
				_rename_profile = p.name
		set_status(r.status)
		_rebuild(), false, "save-workspace")
	var r2 := _row(s)
	var sel := _fit_option(OptionButton.new())
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel.add_item("Select a profile...")
	sel.set_item_metadata(0, "")
	for p in profiles:
		sel.add_item(p.name)
		sel.set_item_metadata(sel.item_count - 1, p.id)
		if p.id == _selected_profile:
			sel.select(sel.item_count - 1)
	sel.item_selected.connect(func(i: int):
		_selected_profile = String(sel.get_item_metadata(i))
		_rename_profile = ""
		for p in ProgramStore.workspace_profiles:
			if p.id == _selected_profile:
				_rename_profile = p.name
		_rebuild())
	sel.set_meta("auto_id", "tools.profile-select")
	var pick := HBoxContainer.new()  # [profile][Apply] and [name][Rename][Delete] stack when narrow
	pick.add_theme_constant_override("separation", 7)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(pick)
	pick.add_child(sel)
	var none := _selected_profile == ""
	_button(pick, "Apply", _request_apply_profile, none, "apply-profile")
	var edit_box := HBoxContainer.new()
	edit_box.add_theme_constant_override("separation", 7)
	edit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(edit_box)
	var ren_edit := _line(_rename_profile, "", func(t: String): _rename_profile = t)
	ren_edit.editable = not none
	ren_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_box.add_child(ren_edit)
	_button(edit_box, "Rename", func():
		LauncherToolsLogic.rename_profile(ProgramStore, _selected_profile, _rename_profile), none or _rename_profile.strip_edges().is_empty(), "rename-profile")
	_button(edit_box, "Delete", func():
		LauncherToolsLogic.delete_profile(ProgramStore, _selected_profile)
		_selected_profile = ""
		_rename_profile = ""
		_rebuild(), none, "delete-profile")
	for p in profiles:
		if p.id == _selected_profile:
			var small := _wrapped(LauncherToolsLogic.profile_summary(p))
			small.add_theme_font_size_override("font_size", 11)
			s.add_child(small)


## Apply replaces every group and item, so it asks first; only OK applies.
func _request_apply_profile() -> void:
	var c := LauncherToolsLogic.apply_profile_confirmation(_profile_store().workspace_profiles, _selected_profile)
	if not c.required:
		return
	_ensure_profile_confirm()
	_pending_profile = _selected_profile
	profile_confirm.dialog_text = c.message
	if profile_confirm.is_inside_tree():
		# A native child window: give it this window's HiDPI scale so it is not drawn at 1x.
		profile_confirm.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		profile_confirm.content_scale_factor = _ui_scale
		profile_confirm.reset_size()
		profile_confirm.popup_centered()


## Modal OK/Cancel box owned by this window (created once; _rebuild never frees it).
func _ensure_profile_confirm() -> void:
	if profile_confirm != null:
		return
	profile_confirm = ConfirmationDialog.new()
	profile_confirm.title = "Apply Workspace Profile"
	profile_confirm.ok_button_text = "OK"
	profile_confirm.cancel_button_text = "Cancel"
	profile_confirm.confirmed.connect(_confirm_apply_profile)
	profile_confirm.canceled.connect(func(): _pending_profile = "")
	add_child(profile_confirm)


func _confirm_apply_profile() -> void:
	var id := _pending_profile
	_pending_profile = ""
	if id != "":
		set_status(LauncherToolsLogic.apply_profile(_profile_store(), id))


func _profile_store() -> Node:
	return profile_store if profile_store != null else ProgramStore


func _refresh_backups() -> void:
	_backups = _profile_store().list_backups()


func _build_backups() -> void:
	var s := _section("Backup and recovery")
	var row := _row(s)
	_button(row, "Create restore point", func():
		set_status(LauncherToolsLogic.create_backup(ProgramStore))
		_refresh_backups()
		_rebuild(), false, "create-backup")
	_button(row, "Refresh", func():
		_refresh_backups()
		_rebuild(), false, "refresh-backups")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	s.add_child(list)
	for b in _backups:
		var r := HBoxContainer.new()
		r.add_child(_wrapped(LauncherToolsLogic.backup_label(b)))
		var id: String = b.id
		_button(r, "Restore", func(): _request_restore(id), false, "restore-backup")
		list.add_child(r)
	if _backups.is_empty():
		var l := Label.new()
		l.text = "No restore points yet."
		l.add_theme_color_override("font_color", Color("#555555"))
		list.add_child(l)


## Restore replaces all data, so it asks first (like profile Apply); only OK restores.
func _request_restore(id: String) -> void:
	var c := LauncherToolsLogic.restore_confirmation(_backups, id)
	if not c.required:
		return
	_ensure_restore_confirm()
	_pending_restore = id
	restore_confirm.dialog_text = c.message
	if restore_confirm.is_inside_tree():
		restore_confirm.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		restore_confirm.content_scale_factor = _ui_scale
		restore_confirm.reset_size()
		restore_confirm.popup_centered()


func _ensure_restore_confirm() -> void:
	if restore_confirm != null:
		return
	restore_confirm = ConfirmationDialog.new()
	restore_confirm.title = "Restore Backup"
	restore_confirm.ok_button_text = "OK"
	restore_confirm.cancel_button_text = "Cancel"
	restore_confirm.confirmed.connect(_confirm_restore)
	restore_confirm.canceled.connect(func(): _pending_restore = "")
	add_child(restore_confirm)


func _confirm_restore() -> void:
	var id := _pending_restore
	_pending_restore = ""
	if id == "":
		return
	set_status(LauncherToolsLogic.restore_backup(_profile_store(), id))
	_refresh_backups()
	_rebuild()
