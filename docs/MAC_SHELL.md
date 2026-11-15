# Classic Mac OS shell

`MacShell` (`src/shells/mac`, shell id `mac`, scale key `macScale`) is a pixel-drawn Classic Mac OS desktop built from the
design prototype's Mac block. Groups are folders, items are application icons.

## Layout
* Menu bar (22 px): launcher-logo menu (About, Launcher Tools..., Desktop Pictures..., Find..., folder list), File, Edit,
  View, Special, Help, clock, and the Program Manager application menu (Launcher Tools... + window list).
* Desktop (`#6c6ca8`, or the dark mapping): Launcher HD and Trash icons in the right column. Launcher HD opens a window
  listing the groups as folders; double-clicking a folder opens a window with its items (as Icons / as List).
* Windows: striped title bar, close box, zoom box, collapse (window shade; also double-click the title), drag by the title,
  grow box, wheel/scroll bar. The Find window has name/type/group filters (ProgramSearch).
* Dialogs: alert / confirm (Move To Trash), About, Help, Run, Browse, New Folder, New Program, Rename, Get Info (all item
  fields: name, kind, group, target, start in, arguments, environment, launch group, shortcut key, open as, icon), Change
  Icon, Desktop Pictures (colour + dark mode), Shut Down (quit / restart / switch to Windows 95).

## Behaviour notes
* Persistence only goes through `ProgramStore` (add/update/delete group & item, move_item, replace_groups for Clean Up,
  `update_settings({theme})` for dark mode). Window geometry, view mode, selection and the desktop colour are session-only:
  the schema has no Mac fields and none were added.
* Dark theme follows `settings.theme`: `MacTheme.b/t/s(hex)` map the design's literals (DARK.b/t/s tables).
* Launching shows a toast ("Starting X..."), failures an alert; Launch All / Launch Group use `LaunchGroups` with the
  shared `UIState` launch feedback. "Launcher Tools..." emits `request_show_launcher_tools`; Ctrl+Alt+T also does.
* Shell switch (Shut Down > Switch to Windows 95) uses `apply_settings_transaction` + `Platform.recreate_for_shell`, like
  Win95's Shut Down. Quick Search (`toggle_quick_search`) opens the Find window with the query focused.
* Keyboard (Cmd on macOS, Ctrl elsewhere): N New Folder, O Open, W Close Window, I Get Info, D Duplicate, T / Backspace
  Move To Trash, F Find, R Run; arrows move the selection, Return opens, Delete trashes.
* The bundled pixel font lacks the ellipsis, curly quotes and em dash; `MacDraw.glyph_safe` substitutes ASCII.

## Code map
Pure/unit-tested: `MacTheme`, `MacIconCatalog`, `MacGeometry`, `MacWindowStore`, `MacMenuModel`, `MacDialogLogic`.
Controls: `MacShell`, `MacDesktop`, `MacWindow` > `MacFolderWindow` (+`MacFolderView`) / `MacFindWindow`, `MacMenuBar`,
`MacPopupMenu`, `MacDialog` + `MacDialogs`, widgets `MacButton`, `MacTextField`, `MacSelect`, `MacCheckBox`, `MacListBox`,
`MacLabel`, `MacIconBox`, `MacToast`. Drawing helpers: `MacDraw`.

Omitted on purpose: drag-and-drop of icons between folders / onto the Trash, icon positions on the desktop, an
accessibility (AccessKit) layer, a working Trash window (as in the design it reports "not available").
Visual views: `tests/visual/MAC_AUTOMATION_IDS.md`.
