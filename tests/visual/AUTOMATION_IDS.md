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
