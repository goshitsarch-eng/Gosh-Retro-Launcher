# Reference

## Data model
The persisted document (`program-manager-data.json`) is unchanged from 1.x:

```
{ schemaVersion: 5, groups: [Group], settings: Settings, workspaceProfiles: [Profile] }
Group    { id, name, icon, windowState, shellWindowState:{win31,win95}, win31IconPosition?, items:[Item] }
Item     { id, name, path, icon, win31Icon?, workingDir, arguments?, environment?, runMode?,
           launchGroup?, shortcutKey?, runMinimized?, win31Position?, win95Position? }
Settings { autoArrange, minimizeOnUse, saveSettingsOnExit, launchDelay, trayOnClose, groupChromeScale,
           win31Scale, win95Scale, macScale, beScale, win95DesktopIconPositions, win31DesktopMode,
           win31ProgramManagerBounds, win31ProgramManagerMinimized, theme, labelDisplay, shell, soundEnabled,
           launchGroupNames }
```
`launchGroupNames` maps a launch group number, written as a string, to its name: `{"3": "Morning"}`. Names are one line,
at most 40 characters. A launch group exists while any item uses its number or it has a name, so a named group can be empty.
`src/core/types.gd` holds the defaults; `src/core/migration.gd` the normalization rules.

## Autoloads

### `ProgramStore`
State: `groups`, `settings`, `workspace_profiles`, `load_report`. Signals: `groups_changed`, `settings_changed`, `profiles_changed`,
`data_loaded`, `data_reloaded`, `data_normalized`, `save_failed`, `save_recovered` (see Store results below).
Groups/items: `add_group`, `import_group`, `replace_groups`, `add_starter_workspace`, `update_group`, `delete_group`,
`update_group_window_state(id, updates, shell)`, `update_group_icon_position`, `add_item`, `update_item`,
`update_item_position`, `update_win95_item_position`, `delete_item`, `move_item`, `copy_item`, `find_group`, `find_item`.
Profiles: `save_workspace_profile`, `apply_workspace_profile`, `delete_workspace_profile`, `rename_workspace_profile`.
Launch groups: `launch_group_names`, `create_launch_group(name, keys)` (lowest free number from 1 to 8, or 0 when all are
taken or the group would be empty and unnamed), `set_launch_group_name(n, name)` (blank removes the name),
`set_launch_group_members(n, keys)` (exactly these `"groupId:itemId"` items; they leave any other launch group),
`renumber_launch_group(from, to)` (swaps with `to` when it is taken, which changes the Launch All order) and
`delete_launch_group(n)` (members go back to None and the name is removed; the programs stay).
Settings: `update_settings`, `apply_settings_transaction`. Data: `export_to`, `import_from`, `list_backups`,
`create_backup`, `restore_backup`, `flush`.

### `UIState`
Dialogs (`open_dialog(type, data)`, `close_dialog`), menus, quick search, selection, and batch-launch feedback.

### `MdiState`
Win31 group window stacking: `open_window`, `close_window`, `focus_window`, `cascade_windows`, `tile_windows`, `arrange_icons`.

### `Platform`
Launching (`launch`, `launch_batch`, `open_external`), native dialogs (`select_executable`, `select_icon`, `import_grp`,
`export_grp`, `import_data`, `export_all`, `export_data`), `get_app_info`, window control, tray/shortcut signals
(`quick_search_requested`, `launcher_tools_requested`, `files_dropped`, `window_state_changed`).

### `LaunchGroups` and `DataTransfer` (static helpers)
`LaunchGroups`: `format_launch_group(n, names)` ("None", "Group 3", "Group 3: Morning"), `launch_label(n, count, names)`,
`defined_groups(groups, names)` (`[{number, name, label, count}]`), `all_items(groups)`, `member_keys(groups, n)`,
`next_free_number(groups, names)`, `clean_name(text)`, plus `collect_launch_groups` and `launch_group_buckets` for launching.
`DataTransfer`: the wording every desktop uses for Export All / Import All (`IMPORT_CONFIRM`, `export_status(result)`,
`import_status(result)`, `default_export_name()`). `Platform.export_all()` returns `{success, path}`, `{canceled}` or `{error}`.

### `Sounds`
`Sounds.play(name)` for `startup_chime`, `window_open`, `window_close`, `menu_click`, `dialog_open`, `error_beep`,
`button_click`; honors `settings.soundEnabled`.

## Command line
| Argument | Effect |
|----------|--------|
| `-- --capture=<view> --out=<png> [--baseline=<png>]` | Render a visual scenario and optionally diff it |
| `-- --no-single-instance` | Skip the single-instance lock |
| `PM_USER_DATA=<dir>` (env) | Use another data directory (tests, portable use) |

## Store results and notices (added with the 2026-11-14 fixes)

- `import_from(path)` returns `{"success": true}`. It adds counts (`normalized`, `shortcutsCleared`) only when something was repaired or cleared. A failed import, including one whose safety `store-replaced` backup cannot be written, returns `success: false` with an error and changes nothing.
- `import_group(group)` returns `{"success", "normalized", "shortcutsCleared"}`, or `success: false` when the group has no usable id or name. The imported group may be given a new id if its id is already in use.
- `apply_workspace_profile(id)` returns `{"success", "backup"?, "normalized"?, "error"?}`. It writes a forced `store-replaced` backup first and changes nothing if that backup cannot be written.
- `restore_backup(id)` returns `{"success", "backup"?, "error"?}` with the same safety rule: one forced `store-replaced` backup of the current data is written first (`set_all_data(d, false)` then skips its own), and the restore is refused if that backup fails.
- Signal `data_normalized(source, report)`: values were repaired. `source` is `load`, `import`, `grp-import`, `profile-apply` or `save`; `report` holds `normalized` and `shortcutsCleared` counts.
- Signal `save_failed(kind, message)`: data was invalid even after repair, the store file could not be written, or a safety backup could not be made. `kind` is `groups`, `settings`, `profiles` or `backup`. For `groups`, `settings` and `profiles` the change stays in memory, marked dirty, and is retried by the next flush of that kind and by `flush()` (called on exit and by `create_backup` and `export_to`). A pending `profiles` change is also retried by a flush of groups or settings. For `backup` the restore, profile apply or JSON import is refused and nothing is retried.
- Signal `save_recovered(kind)`: the first successful save of `kind` after `save_failed` reported it.
- `apply_settings_transaction(next)` writes synchronously and returns `{"success", "previous"?, "error"?}`. A refused write changes nothing and is not kept pending.
- `Persistence.set_groups`, `set_settings`, `set_workspace_profiles` and `set_all_data` return `bool`: whether the store file was written. On failure the in-memory data is put back as it was.
- The host (`src/app/main.gd`) shows both signals to the user. In capture runs they are shown only with `PM_CAPTURE_NOTICE=1`.
