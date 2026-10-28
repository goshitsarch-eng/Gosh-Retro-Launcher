# Reference

## Data model
The persisted document (`program-manager-data.json`) is unchanged from 1.x:

```
{ schemaVersion: 5, groups: [Group], settings: Settings, workspaceProfiles: [Profile] }
Group    { id, name, icon, windowState, shellWindowState:{win31,win95}, win31IconPosition?, items:[Item] }
Item     { id, name, path, icon, win31Icon?, workingDir, arguments?, environment?, runMode?,
           launchGroup?, shortcutKey?, runMinimized?, win31Position?, win95Position? }
Settings { autoArrange, minimizeOnUse, saveSettingsOnExit, launchDelay, trayOnClose, groupChromeScale,
           win31Scale, win95Scale, win95DesktopIconPositions, win31DesktopMode,
           win31ProgramManagerBounds, win31ProgramManagerMinimized, theme, labelDisplay, shell, soundEnabled }
```
`src/core/types.gd` holds the defaults; `src/core/migration.gd` the normalization rules.

## Autoloads

### `ProgramStore`
State: `groups`, `settings`, `workspace_profiles`. Signals: `groups_changed`, `settings_changed`, `profiles_changed`,
`data_loaded`, `data_reloaded`.
Groups/items: `add_group`, `import_group`, `replace_groups`, `add_starter_workspace`, `update_group`, `delete_group`,
`update_group_window_state(id, updates, shell)`, `update_group_icon_position`, `add_item`, `update_item`,
`update_item_position`, `update_win95_item_position`, `delete_item`, `move_item`, `copy_item`, `find_group`, `find_item`.
Profiles: `save_workspace_profile`, `apply_workspace_profile`, `delete_workspace_profile`, `rename_workspace_profile`.
Settings: `update_settings`, `apply_settings_transaction`. Data: `export_to`, `import_from`, `list_backups`,
`create_backup`, `restore_backup`, `flush`.

### `UIState`
Dialogs (`open_dialog(type, data)`, `close_dialog`), menus, quick search, selection, and batch-launch feedback.

### `MdiState`
Win31 group window stacking: `open_window`, `close_window`, `focus_window`, `cascade_windows`, `tile_windows`, `arrange_icons`.

### `Platform`
Launching (`launch`, `launch_batch`, `open_external`), native dialogs (`select_executable`, `select_icon`, `import_grp`,
`export_grp`, `import_data`, `export_data`), `get_app_info`, window control, tray/shortcut signals
(`quick_search_requested`, `launcher_tools_requested`, `files_dropped`, `window_state_changed`).

### `Sounds`
`Sounds.play(name)` for `startup_chime`, `window_open`, `window_close`, `menu_click`, `dialog_open`, `error_beep`,
`button_click`; honors `settings.soundEnabled`.

## Command line
| Argument | Effect |
|----------|--------|
| `-- --capture=<view> --out=<png> [--baseline=<png>]` | Render a visual scenario and optionally diff it |
| `-- --no-single-instance` | Skip the single-instance lock |
| `PM_USER_DATA=<dir>` (env) | Use another data directory (tests, portable use) |
