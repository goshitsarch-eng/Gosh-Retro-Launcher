# Automation ids

The visual scenarios (`tests/visual/scenarios.gd`) and integration tests drive the real shells
with injected mouse/keyboard events at the on-screen position of an *automation id*.

A node publishes ids by joining group `pm_auto` and either

* setting meta `auto_id` (its global rect is the target), or
* implementing `func auto_lookup(id: String) -> Variant` returning a `Rect2` in **logical**
  coordinates (or `null`) — used for virtual, custom-drawn items (icons, list rows, menu rows).

Ids correspond to the DOM selectors the original Electron capture script used.

## Windows 95

| id | element |
|----|---------|
| `w95.start-button` | Start button |
| `w95.start-command:<Label>` | top-level Start menu row: `Programs`, `Documents`, `Settings`, `Find`, `Help`, `Run...`, `Shut Down...` |
| `w95.start-level:<n>:first-command` | first row of the n-th cascading submenu level (1 = first cascade) |
| `w95.desktop-icon:<key>` | `my-computer`, `network-neighborhood`, `recycle-bin`; `first` = first desktop icon |
| `w95.taskbar` | taskbar background |
| `w95.task-window:first` | first task button |
| `w95.folder-item:<i>` | i-th object in the *active* folder window |
| `w95.window.active:menu:<name>` | menu bar title of the active window (`file`, `edit`, `view`, `help`) |
| `w95.window.active:button:<Label>` | caption button: `Minimize`, `Maximize`, `Restore`, `Close` |
| `w95.window.active:caption-icon` | system-menu icon |
| `w95.popup-item:<Label>` | row of the open popup/context menu (visible label without `&`) |
| `w95.find-tab:<Label>` / `w95.find-action:<Label>` | Find window tabs / buttons |

## Windows 3.1 / WfW

| id | element |
|----|---------|
| `wfw.menu:<index>` | menu bar title (0 File, 1 Options, 2 Window, 3 Launcher, 4 Help) |
| `wfw.popup-item:<Label>` | open menu row (substring match on visible label) |
| `wfw.program-item:first` | first program icon in the first open group window |
| `wfw.minimized-group:first` | first minimized group icon |
| `wfw.child-window:button:<Label>` | child caption button (`Maximize`, `Minimize`, `Restore`) |
| `wfw.dialog.radio:<Label>` / `wfw.dialog.button:<Label>` | controls in the open dialog |

The `wfw-settings` scenario opens Options > Settings... with `wfw.menu:1` and `wfw.popup-item:Settings...`
(keep the ellipsis: the match is a substring, and `Settings` alone also matches "Save Settings on Exit").

### Windows 3.1 / WfW (additional ids published by the Win31 shell)

| id | element |
|----|---------|
| `wfw.menu-bar` / `wfw.outer-caption` / `wfw.program-manager` | menu bar, outer caption, outer frame |
| `wfw.system-button` | outer control-menu box (popup rows via `wfw.popup-item:<Label>`) |
| `wfw.caption-button:Minimize` / `:Maximize` / `:Restore` | outer caption buttons |
| `wfw.child-window:button:<Label>` | `Minimize`, `Maximize`/`Restore`, `System` of the active (else first visible) group window |
| `wfw.child-window:caption` / `wfw.window:<groupId>` | caption bar / frame of that window |
| `wfw.program-item:<itemId>` | a specific program item cell |
| `wfw.minimized-group:<groupId>` | a specific minimized group icon |
| `wfw.desktop-icon:program-manager` | minimized Program Manager icon (desktop mode) |

## Launch groups and Export All / Import All

### Windows for Workgroups

| Id | Element |
|----|---------|
| `wfw.dialog.launch-groups.list` | group list in the Launch Groups dialog |
| `wfw.dialog.launch-groups:<close\|new\|rename\|number\|delete\|members\|launch>` | its buttons |
| `wfw.dialog.launch-group-name` | name field (New / Rename) |
| `wfw.dialog.launch-group-number` | number drop-down (Number) |
| `wfw.dialog.launch-group-members.list` | Members checklist |

### Windows 95

| Id | Element |
|----|---------|
| `w95.start-item:<level>:<label>` | a Start menu row by cascade level and label |
| `w95.lg.list` | group list in the Launch Groups dialog |
| `w95.lg.button:<New\|Rename\|Number\|Delete\|Members\|Launch\|Close>` | its buttons |
| `w95.lg.name` / `w95.lg.number` | name field / number drop-down in the sub-dialogs |
| `w95.lg.members.list` | Members checklist |
| `w95.properties.select:launchGroup` / `w95.wizard.select:launchGroup` | Launch group drop-down in Properties / Create Shortcut |

### Launcher Tools

`tools.export-all`, `tools.import-all`, `tools.launch-group-number-<n>`, `tools.launch-group-name-<n>`,
`tools.launch-group-rename-<n>`, `tools.launch-group-delete-<n>`, `tools.launch-group-new-name`,
`tools.launch-group-new`, `tools.batch-group`. (`tools.import-json` and `tools.export-json` were removed.)

## Sticky notes (every shell)

A open note window (`StickyNote`) answers `note:<itemId>` (window), `note.title:<itemId>` (drag strip),
`note.close:<itemId>`, `note.grip:<itemId>` (resize) and `note.text:<itemId>` (text area).

Windows for Workgroups: `wfw.dialog.new-note`, `wfw.dialog.note-properties`, `wfw.dialog.note-group`, `wfw.dialog.note-title`,
`wfw.dialog.note-color`, `wfw.dialog.note-text`, `wfw.dialog.note-launch-group`; Launcher Tools `tools.launch-group-row-<n>`.

Windows 95: `w95.new-note.*`, `w95.note-props.*`, `w95.change-icon.*`, `w95.launch-progress.*` (batch progress window),
`w95.wizard.button:sticky-note` (see the class comments in `src/shells/win95/` for each control).
