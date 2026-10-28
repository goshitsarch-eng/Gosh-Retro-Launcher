class_name LauncherToolsWindow
extends Window
## Separate native "Launcher Tools" window (port of components/LauncherTools/LauncherTools.tsx +
## styles/launcher-tools.css). A plain flat-gray form built from standard Godot controls:
## shell/scale/desktop-mode/sound/tray (persist-first shell switch), .GRP and JSON import/export,
## URL launcher, launch groups, per-item launch profile, workspace profiles and backups.
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


func _init() -> void:
	title = "Launcher Tools"
	size = Vector2i(680, 720)
	min_size = Vector2i(480, 360)
	exclusive = false
	transient = false
	close_requested.connect(_on_close)


func _ready() -> void:
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
	status_label.set_meta("auto_id", "tools.status")
	footer.add_child(status_label)
	_root.add_child(footer)
	_form = LauncherToolsLogic.appearance_form(ProgramStore.settings)
	_selected_group = ProgramStore.groups[0].id if ProgramStore.groups.size() > 0 else ""
	if ProgramStore.workspace_profiles.size() > 0:
		_selected_profile = ProgramStore.workspace_profiles[0].id
		_rename_profile = ProgramStore.workspace_profiles[0].name
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


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 7)
	parent.add_child(r)
	return r


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
	var l := Label.new()
	l.text = label
	v.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ctl)
	parent.add_child(v)
	return v


func _group_option(parent: Control, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
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
	e.text_changed.connect(cb)
	return e


func _scale_option(value: Variant, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.add_item("Auto")
	for v in Types.SCALE_FACTORS:
		o.add_item("%d×" % v)
	o.select(W31DialogLogic.scale_to_index(value))
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
	var p := Label.new()
	p.text = "Modern launcher features are kept outside the Windows 3.11 Program Manager surface."
	p.add_theme_color_override("font_color", Color("#444444"))
	h.add_child(p)
	_content.add_child(h)


func _build_appearance() -> void:
	var s := _section("Shell and appearance")
	var active := Label.new()
	active.text = "Active shell: %s" % LauncherToolsLogic.shell_label(String(ProgramStore.settings.get("shell", "win31")))
	s.add_child(active)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 9)
	s.add_child(grid)
	shell_option = OptionButton.new()
	shell_option.add_item(LauncherToolsLogic.shell_label("win31"))
	shell_option.add_item(LauncherToolsLogic.shell_label("win95"))
	shell_option.select(0 if _form.shell == "win31" else 1)
	shell_option.set_meta("auto_id", "tools.shell")
	shell_option.item_selected.connect(func(i: int):
		_form.shell = "win31" if i == 0 else "win95"
		_rebuild())
	_labeled(grid, "Shell", shell_option)
	var is31: bool = _form.shell == "win31"
	scale_option = _scale_option(_form["win31Scale" if is31 else "win95Scale"], func(v: Variant):
		_form["win31Scale" if is31 else "win95Scale"] = v)
	scale_option.set_meta("auto_id", "tools.scale")
	_labeled(grid, "WfW scale" if is31 else "Windows 95 scale", scale_option)
	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", 12)
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
	_button(row, "Import JSON...", func(): _import_json(), false, "import-json")
	_button(row, "Export JSON...", func(): _export_json(), false, "export-json")


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
	var st := LauncherToolsLogic.export_grp_status(String(group.name), result)
	if st != "":
		set_status(st)


func _import_json() -> void:
	var result: Dictionary = await Platform.import_data()
	var st := LauncherToolsLogic.import_json_status(result)
	if st != "":
		set_status(st)


func _export_json() -> void:
	var saved: bool = await Platform.export_data()
	if saved:
		set_status("Launcher backup exported.")


func _build_url() -> void:
	var s := _section("URL launcher")
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 9)
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
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 7)
	flow.add_theme_constant_override("v_separation", 7)
	s.add_child(flow)
	for b in buckets:
		var bucket: Dictionary = b
		_button(flow, LauncherToolsLogic.launch_group_label(bucket), func(): _launch([bucket]), _launching, "launch-group-%d" % int(bucket.groupNumber))
	if buckets.is_empty():
		var l := Label.new()
		l.text = "No launch groups are assigned. Assign one to a program below."
		l.add_theme_color_override("font_color", Color("#555555"))
		s.add_child(l)


func _launch(buckets: Array) -> void:
	if _launching or buckets.is_empty():
		return
	_launching = true
	set_status(LauncherToolsLogic.launch_status_start(buckets))
	_rebuild()
	var results: Array = await LaunchGroups.launch_group_buckets(self, buckets, ProgramStore.settings.get("launchDelay", 500),
		Callable(), func(items: Array, delay: Variant) -> Array: return await Platform.launch_batch(items, delay))
	_launching = false
	set_status(LauncherToolsLogic.launch_status_done(results))
	_rebuild()


func _build_profile_editor() -> void:
	var s := _section("Launch profile and batch metadata")
	var opt := OptionButton.new()
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
	var box := GridContainer.new()
	box.columns = 2
	box.add_theme_constant_override("h_separation", 8)
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
	var ev := _labeled(box, "Environment", e_edit)
	box.add_child(Control.new())
	var m_opt := OptionButton.new()
	for m in ["Normal", "Minimized", "Maximized"]:
		m_opt.add_item(m)
	m_opt.select(Types.RUN_MODES.find(mode))
	m_opt.item_selected.connect(func(i: int): mode = Types.RUN_MODES[i])
	_labeled(box, "Run mode", m_opt)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 8
	spin.step = 1
	spin.value = lg
	spin.value_changed.connect(func(v: float): lg = int(v))
	_labeled(box, "Batch group", spin)
	ev = ev
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
	var sel := OptionButton.new()
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
	r2.add_child(sel)
	var none := _selected_profile == ""
	_button(r2, "Apply", func(): set_status(LauncherToolsLogic.apply_profile(ProgramStore, _selected_profile)), none, "apply-profile")
	var ren_edit := _line(_rename_profile, "", func(t: String): _rename_profile = t)
	ren_edit.editable = not none
	ren_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(ren_edit)
	_button(r2, "Rename", func():
		LauncherToolsLogic.rename_profile(ProgramStore, _selected_profile, _rename_profile), none or _rename_profile.strip_edges().is_empty(), "rename-profile")
	_button(r2, "Delete", func():
		LauncherToolsLogic.delete_profile(ProgramStore, _selected_profile)
		_selected_profile = ""
		_rename_profile = ""
		_rebuild(), none, "delete-profile")
	for p in profiles:
		if p.id == _selected_profile:
			var small := Label.new()
			small.text = LauncherToolsLogic.profile_summary(p)
			small.add_theme_font_size_override("font_size", 11)
			s.add_child(small)


func _refresh_backups() -> void:
	_backups = ProgramStore.list_backups()


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
		var l := Label.new()
		l.text = LauncherToolsLogic.backup_label(b)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var id: String = b.id
		_button(r, "Restore", func():
			set_status(LauncherToolsLogic.restore_backup(ProgramStore, id))
			_refresh_backups()
			_rebuild(), false, "restore-backup")
		list.add_child(r)
	if _backups.is_empty():
		var l := Label.new()
		l.text = "No restore points yet."
		l.add_theme_color_override("font_color", Color("#555555"))
		list.add_child(l)
