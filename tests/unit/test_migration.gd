extends TestCase
## Port of src/shared/__tests__/storeMigration.test.ts

const LEGACY := {"x": 42, "y": 37, "width": 410, "height": 230, "minimized": true, "maximized": false}


func _settings(extra: Dictionary) -> Dictionary:
	var s := Types.default_settings()
	s.merge(extra, true)
	return s


func test_copies_legacy_group_geometry_into_independent_shell_records() -> void:
	var m := Migration.migrate_store_data({
		"groups": [{"id": "main", "name": "Main", "icon": "folder", "windowState": LEGACY,
			"items": [{"id": "one", "name": "One", "path": "one.exe", "icon": "default", "workingDir": ""}]}],
		"settings": _settings({"win31Scale": 2}),
	})
	expect_eq(m.schemaVersion, Types.CURRENT_SCHEMA_VERSION)
	expect_eq(m.groups[0].shellWindowState, {"win31": LEGACY, "win95": LEGACY})
	expect(not is_same(m.groups[0].shellWindowState.win31, m.groups[0].shellWindowState.win95), "independent objects")
	expect_eq(m.settings.win31Scale, 2)


func test_migrates_profiles_and_desktop_geometry() -> void:
	var m := Migration.migrate_store_data({
		"groups": [],
		"settings": _settings({"win31DesktopMode": true, "win31ProgramManagerBounds": {"x": 68, "y": 49, "width": 511, "height": 335}}),
		"workspaceProfiles": [{"id": "work", "name": "Work", "createdAt": "2026-01-01T00:00:00.000Z",
			"updatedAt": "2026-01-02T00:00:00.000Z",
			"groups": [{"id": "main", "name": "Main", "icon": "group", "windowState": LEGACY, "items": []}]}],
	})
	expect_eq(m.settings.win31DesktopMode, true)
	expect_eq(m.settings.win31ProgramManagerBounds, {"x": 68, "y": 49, "width": 511, "height": 335})
	expect_eq(m.workspaceProfiles[0].groups[0].shellWindowState.win31, LEGACY)


func test_independent_win95_scale() -> void:
	var m := Migration.migrate_store_data({"groups": [], "settings": _settings({"win31Scale": 3, "win95Scale": 2})})
	expect_eq(m.settings.win31Scale, 3)
	expect_eq(m.settings.win95Scale, 2)
	var legacy := Migration.migrate_store_data({"groups": [], "settings": {"win31Scale": 4}})
	expect_eq(legacy.settings.win31Scale, 4)
	expect_eq(legacy.settings.win95Scale, "auto")


func test_retains_valid_positions_rejects_malformed() -> void:
	var m := Migration.migrate_store_data({
		"groups": [{"id": "main", "name": "Main", "icon": "folder", "windowState": LEGACY, "items": [
			{"id": "one", "name": "One", "path": "one.exe", "icon": "application", "workingDir": "", "win95Position": {"x": 123, "y": 45}},
			{"id": "two", "name": "Two", "path": "two.exe", "icon": "application", "workingDir": "", "win95Position": {"x": "bad", "y": 2}}]}],
		"settings": _settings({"win95DesktopIconPositions": {"my-computer": {"x": 7, "y": 9}, "broken": {"x": NAN, "y": 3}}}),
	})
	expect_eq(m.groups[0].items[0].win95Position, {"x": 123, "y": 45})
	expect(not m.groups[0].items[1].has("win95Position"), "bad position dropped")
	expect_eq(m.settings.win95DesktopIconPositions, {"my-computer": {"x": 7, "y": 9}})


func test_normalizes_invalid_scale_and_malformed_objects() -> void:
	var m := Migration.migrate_store_data({
		"groups": [null, {"id": 3}, {"id": "valid", "name": "Valid", "windowState": {"width": -1, "height": NAN}, "items": [{"id": "bad"}]}],
		"settings": {"win31Scale": 8},
	})
	expect_eq(m.settings.win31Scale, "auto")
	expect_eq(m.settings.win95Scale, "auto")
	expect_eq(m.groups.size(), 1)
	expect_eq(m.groups[0].items, [])
	expect(m.groups[0].shellWindowState.win31.width >= 150)
	expect(m.groups[0].shellWindowState.win31.height >= 92)
