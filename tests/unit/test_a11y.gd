extends TestCase
## Screen-reader descriptions (A11y specs) of the custom-drawn controls. The specs are pure data, so
## they are checked headless; applying them needs a live AccessKit client (see src/toolkit/a11y.gd).


func _option_names(specs: Array) -> Array:
	return specs.map(func(s): return String(s.get("name", "")))


# ------------------------------------------------------------------ helpers

func test_plain_and_access_shortcut() -> void:
	expect_eq(A11y.plain("&File"), "File")
	expect_eq(A11y.plain("Name && Location"), "Name & Location")
	expect_eq(A11y.plain("&Name && Location"), "Name & Location")
	expect_eq(A11y.access_shortcut("Sh&ut Down..."), "Alt+U")
	expect_eq(A11y.access_shortcut("Fish && Chips"), "")
	expect_eq(A11y.access_shortcut("OK"), "")
	expect_eq(A11y.clean_caption("&Open:"), "Open")


func test_spec_builders() -> void:
	var b := A11y.button("&OK", false, true)
	expect_eq(b.role, DisplayServer.ROLE_DEFAULT_BUTTON)
	expect_eq(b.name, "OK")
	expect_eq(b.shortcut, "Alt+O")
	expect_eq(A11y.button("Cancel").role, DisplayServer.ROLE_BUTTON)
	var c := A11y.check_box("Sound &Effects", true, true)
	expect_eq([c.role, c.name, c.checked, c.disabled], [DisplayServer.ROLE_CHECK_BOX, "Sound Effects", true, true])
	var cb := A11y.combo("Run:", "Normal Window", true)
	expect_eq([cb.value, cb.expanded, cb.popup], ["Normal Window", true, DisplayServer.POPUP_LIST])
	var m := A11y.menu_item("&Auto Arrange", Rect2(3, 3, 100, 17), false, "check", true)
	expect_eq([m.role, m.name, m.checked], [DisplayServer.ROLE_MENU_ITEM_CHECK_BOX, "Auto Arrange", true])
	var r := A11y.menu_item("Large Icons", Rect2(), false, "radio", false)
	expect_eq(r.role, DisplayServer.ROLE_MENU_ITEM_RADIO)
	var sub := A11y.menu_item("&Programs", Rect2(), false, "item", false, true)
	expect_eq([sub.popup, sub.expanded], [DisplayServer.POPUP_MENU, false])
	expect_eq(A11y.menu_item("", Rect2(), false, "separator").role, DisplayServer.ROLE_SPLITTER)
	var sb := A11y.scroll_bar("", 30, 200, 50, true)
	expect_eq([sb.num.value, sb.num.max, sb.vertical], [30.0, 200.0, true])


func test_caption_for_prefers_same_row_label() -> void:
	var field := Rect2(60, 20, 150, 21)
	var labels := [
		{"text": "&Open:", "rect": Rect2(10, 24, 30, 13)},
		{"text": "Type the name of a program", "rect": Rect2(10, 0, 200, 13)},
	]
	expect_eq(A11y.caption_for(field, labels), "Open")
	# nearest left label wins
	labels.append({"text": "&Named:", "rect": Rect2(20, 24, 36, 13)})
	expect_eq(A11y.caption_for(field, labels), "Named")


func test_caption_for_falls_back_to_label_above() -> void:
	var field := Rect2(0, 40, 200, 21)
	var labels := [{"text": "&Command line:", "rect": Rect2(0, 22, 80, 13)}, {"text": "far away", "rect": Rect2(0, 0, 60, 13)}]
	expect_eq(A11y.caption_for(field, labels), "Command line")
	expect_eq(A11y.caption_for(field, []), "")


func test_overlay_focus_stack() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var a := _FocusStub.new()
	var b := _FocusStub.new()
	tree.root.add_child(a)
	tree.root.add_child(b)
	a.rid = RID()
	expect(not A11y.overlay_focus().is_valid(), "no overlays")
	A11y.push_overlay(a)
	A11y.push_overlay(b)
	# b has no opinion (invalid RID): the resolver falls through to a, then to the control itself
	expect(not A11y.overlay_focus().is_valid())
	A11y.remove_overlay(a)
	A11y.remove_overlay(b)
	expect(A11y._overlays.is_empty(), "overlays removed")
	a.queue_free()
	b.queue_free()


class _FocusStub extends Node:
	var rid := RID()

	func a11y_focus() -> RID:
		return rid


# ------------------------------------------------------------------ Win31 widgets

func test_w31_widget_specs() -> void:
	var ok := W31Button.new("&OK", true)
	var s := ok.a11y_spec()
	expect_eq([s.role, s.name, s.disabled, s.shortcut], [DisplayServer.ROLE_DEFAULT_BUTTON, "OK", false, "Alt+O"])
	expect(s.click is Callable)
	ok.disabled = true
	expect_eq(ok.a11y_spec().disabled, true)
	var cb := W31Checkbox.new("Minimize on Use", true)
	expect_eq([cb.a11y_spec().role, cb.a11y_spec().checked], [DisplayServer.ROLE_CHECK_BOX, true])
	cb.toggle()
	expect_eq(cb.a11y_spec().checked, false)
	var r := W31Radio.new("&Normal")
	expect_eq([r.a11y_spec().role, r.a11y_spec().name, r.a11y_spec().checked], [DisplayServer.ROLE_RADIO_BUTTON, "Normal", false])
	var combo := W31Combo.new()
	combo.set_items(["Normal Window", "Minimized", "Maximized"])
	combo.selected = 2
	combo.set_a11y_label("&Run:")
	var cs := combo.a11y_spec()
	expect_eq([cs.name, cs.value, cs.expanded], ["Run", "Maximized", false])
	var slider := W31Slider.new(100, 5000, 100)
	slider.value = 700
	slider.set_a11y_label("Delay between launches:")
	var ss := slider.a11y_spec()
	expect_eq([ss.role, ss.name, ss.num.value, ss.num.min, ss.num.max, ss.num.step],
		[DisplayServer.ROLE_SLIDER, "Delay between launches", 700.0, 100.0, 5000.0, 100.0])
	var gb := W31GroupBox.new("General")
	expect_eq(gb.a11y_spec().name, "General")
	for n in [ok, cb, r, combo, slider, gb]:
		n.free()


func test_w31_text_field_label_names_the_editor() -> void:
	var tf := W31TextField.new()
	tf.set_a11y_label("&Description:")
	expect_eq(tf.edit.accessibility_name, "Description")
	tf.free()


func test_w31_icon_grid_options() -> void:
	var grid := W31IconGrid.new(4, 4)
	grid.size = Vector2(200, 0)
	grid.set_entries([{"id": "notepad", "name": "notepad"}, {"id": "my-computer", "name": "my-computer"}])
	grid.selected_id = "my-computer"
	var specs := grid.a11y_item_specs()
	expect_eq(_option_names(specs), ["notepad", "my computer"])
	expect_eq(specs.map(func(s): return s.selected), [false, true])
	expect_eq(specs[1].index, 1)
	expect_eq(specs[1].bounds, grid.cell_rect(1))
	expect_eq(grid.a11y_spec().role, DisplayServer.ROLE_LIST_BOX)
	grid.free()


func test_win31_popup_menu_items() -> void:
	var menu := Win31PopupMenu.new()
	menu.set_items([
		{"command": "auto-arrange", "label": "&Auto Arrange", "checked": true},
		{"separator": true},
		{"command": "delete", "label": "&Delete", "disabled": true},
		{"command": "exit", "label": "E&xit Windows..."},
	], false)
	var specs := menu.a11y_item_specs()
	expect_eq(specs.size(), 4)
	expect_eq([specs[0].role, specs[0].name, specs[0].checked], [DisplayServer.ROLE_MENU_ITEM_CHECK_BOX, "Auto Arrange", true])
	expect_eq(specs[1].role, DisplayServer.ROLE_SPLITTER)
	expect_eq([specs[2].role, specs[2].disabled], [DisplayServer.ROLE_MENU_ITEM, true])
	expect_eq([specs[3].name, specs[3].shortcut], ["Exit Windows...", "Alt+X"])
	expect_eq(specs[3].bounds, menu.item_rect(3))
	menu.free()


func test_win31_menu_bar_roots() -> void:
	var bar := Win31MenuBar.new()
	bar.set_menus([{"id": "file", "label": "&File", "items": []}, {"id": "options", "label": "&Options", "items": []}])
	bar.active_menu = "options"
	var specs := bar.a11y_item_specs()
	expect_eq(_option_names(specs), ["File", "Options"])
	expect_eq(specs.map(func(s): return s.expanded), [false, true])
	expect_eq(specs[0].popup, DisplayServer.POPUP_MENU)
	bar.free()


# ------------------------------------------------------------------ Win95 controls

func test_win95_control_specs() -> void:
	var b := Win95Button.new()
	b.label = "&Browse..."
	b.default_button = true
	expect_eq([b.a11y_spec().role, b.a11y_spec().name, b.a11y_spec().shortcut], [DisplayServer.ROLE_DEFAULT_BUTTON, "Browse...", "Alt+B"])
	var c := Win95Checkbox.new()
	c.label = "&Include subgroups"
	c.checked = true
	expect_eq([c.a11y_spec().role, c.a11y_spec().name, c.a11y_spec().checked], [DisplayServer.ROLE_CHECK_BOX, "Include subgroups", true])
	var r := Win95Radio.new()
	r.label = "&Shut down the computer?"
	expect_eq(r.a11y_spec().role, DisplayServer.ROLE_RADIO_BUTTON)
	var l := Win95Label.make("&Open:", Vector2.ZERO)
	expect_eq([l.a11y_spec().role, l.a11y_spec().name], [DisplayServer.ROLE_STATIC_TEXT, "Open:"])
	var sb := Win95Scrollbar.new()
	sb.configure(10, 50, 200, 100)
	expect_eq([sb.a11y_spec().role, sb.a11y_spec().num.value], [DisplayServer.ROLE_SCROLL_BAR, 10.0])
	for n in [b, c, r, l, sb]:
		n.free()


func test_win95_tab_strip_tabs() -> void:
	var t := Win95TabStrip.new()
	t.configure([{"id": "name", "label": "&Name && Location"}, {"id": "date", "label": "&Date Modified"}], "find", "date")
	var specs := t.a11y_tab_specs()
	expect_eq(_option_names(specs), ["Name & Location", "Date Modified"])
	expect_eq(specs.map(func(s): return s.selected), [false, true])
	expect_eq(specs.map(func(s): return s.role), [DisplayServer.ROLE_TAB, DisplayServer.ROLE_TAB])
	expect_eq(specs[0].shortcut, "Alt+N")
	expect_eq(specs[1].bounds, t.tab_rect(1))
	t.free()


func test_win95_field_caption_from_sibling_label() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var form := Control.new()
	tree.root.add_child(form)
	form.add_child(Win95Label.make("Type the name of a program.", Vector2(0, 0), {"wrap": 265}))
	form.add_child(Win95Label.make("&Open:", Vector2(9, 57)))
	var edit := Win95TextInput.new()
	edit.position = Vector2(50, 53)
	edit.size = Vector2(250, 21)
	form.add_child(edit)
	var sel := Win95Select.new()
	sel.options = ["Programs", "Accessories"]
	sel.position = Vector2(50, 90)
	form.add_child(sel)
	form.add_child(Win95Label.make("&Look in:", Vector2(0, 94)))
	expect_eq(Win95Label.caption_near(edit), "Open")
	expect_eq(sel.a11y_spec().name, "Look in")
	expect_eq(sel.a11y_spec().value, "Programs")
	await tree.process_frame  # the LineEdit is named once the form is assembled (deferred)
	expect_eq(edit.edit.accessibility_name, "Open")
	form.free()


func test_win95_menu_rows() -> void:
	var m := Win95Menu.new()
	m.items = [
		{"id": "large", "label": "Lar&ge Icons", "checked": true, "radio": true},
		{"id": "sep", "separator": true},
		{"id": "arrange", "label": "Arrange &Icons", "children": [{"id": "x", "label": "by &Name"}]},
		{"id": "close", "label": "&Close", "disabled": true},
	]
	m._layout()
	var specs := m.a11y_item_specs()
	expect_eq(specs.map(func(s): return s.role), [DisplayServer.ROLE_MENU_ITEM_RADIO, DisplayServer.ROLE_SPLITTER,
		DisplayServer.ROLE_MENU_ITEM, DisplayServer.ROLE_MENU_ITEM])
	expect_eq([specs[0].name, specs[0].checked], ["Large Icons", true])
	expect_eq([specs[2].popup, specs[2].expanded], [DisplayServer.POPUP_MENU, false])
	expect_eq(specs[3].disabled, true)
	expect_eq(specs[2].bounds, Rect2(4, m._rows[2].y, m.size.x - 8, 20))
	m.free()


# ------------------------------------------------------------------ store-backed views

const _GROUPS := [
	{"id": "g1", "name": "Accessories", "items": [
		{"id": "a", "name": "Notepad", "path": "/bin/notepad"},
		{"id": "b", "name": "Paintbrush", "path": "/bin/paint"},
	]},
]


func test_win31_item_grid_lists_program_items() -> void:
	var saved_groups: Array = ProgramStore.groups
	var saved_sel: Dictionary = UIState.win31_selection
	ProgramStore.groups = _GROUPS.duplicate(true)
	UIState.win31_selection = {"kind": "item", "groupId": "g1", "itemId": "b"}
	var grid := Win31ItemGrid.new()
	grid.group_id = "g1"
	grid.size = Vector2(300, 200)
	var spec := grid.a11y_spec()
	expect_eq([spec.role, spec.name, spec.count], [DisplayServer.ROLE_LIST_BOX, "Accessories", 2])
	var items := grid.a11y_item_specs()
	expect_eq(_option_names(items), ["Notepad", "Paintbrush"])
	expect_eq(items.map(func(s): return s.selected), [false, true])
	expect_eq(items[1].bounds, grid.cell_rect(1))
	grid.free()
	ProgramStore.groups = saved_groups
	UIState.win31_selection = saved_sel


func test_quick_search_live_status() -> void:
	var saved_groups: Array = ProgramStore.groups
	ProgramStore.groups = _GROUPS.duplicate(true)
	var results = Win31QuickSearch._Results.new()
	results.size = Vector2(380, 0)
	results.set_query("paint")
	expect_eq(results.a11y_status(), "Paintbrush, Accessories, 1 of 1")
	expect_eq(_option_names(results.a11y_row_specs()), ["Paintbrush, Accessories"])
	results.set_query("zzz-nothing")
	expect_eq(results.a11y_status(), "No results found")
	results.free()
	ProgramStore.groups = saved_groups
