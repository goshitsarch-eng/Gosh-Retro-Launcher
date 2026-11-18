# Be shell automation ids

Ids resolve through `Automation` (`src/app/automation.gd`): nodes in group `pm_auto` either implement
`auto_lookup(id)` or carry meta `auto_id`. All rectangles are in shell logical pixels. `BeScenarios`
(`tests/visual/be_scenarios.gd`) drives the real shell with these ids and injected mouse/keyboard events.

| Id | Element |
|----|---------|
| `be.shell` | the whole shell |
| `be.desktop` | the desktop area |
| `be.desktop-icon:<n>` / `:<id>` / `:first` | desktop icon by index, by id (`computer`, `g:<groupId>`), or the first one |
| `be.window:<key>` | a window by key (`computer`, `g:<groupId>`, `find`) |
| `be.window:<key>:tab` / `:close` / `:zoom` / `:grip` / `:content` | title tab, close box, zoom box (folder windows), resize grip, white content area |
| `be.window:<key>:menu:<file\|edit\|view\|help>` | menu-bar title of a folder window |
| `be.window:<key>:entry:<index\|id>` | an icon / row inside a folder window (scroll applied) |
| `be.window.active[:part]` | the same parts for the topmost visible window |
| `be.deskbar` | the Deskbar panel |
| `be.deskbar.logo` | logo button (opens the Deskbar menu; right-click for About / Launcher Tools) |
| `be.deskbar.tools` | the Launcher Tools button next to the clock |
| `be.deskbar.clock` | the clock row |
| `be.deskbar.task:<index\|key>` | a running-window row |
| `be.popup` | the open popup menu (context menu, menu-bar dropdown, Deskbar menu, select list) |
| `be.popup-item:<label>` | a row of the open popup (or of its open submenu), by exact label, e.g. `be.popup-item:Get Info`, `be.popup-item:Find…` |
| `be.toast` | the launch feedback toast |
| `be.find.type` / `be.find.where` / `be.find.query` / `be.find.run` | Find window controls |
| `be.find.result:<index>` | a result row in the Find window |
| `be.dialog` family | `be.dialog.message`, `be.dialog.shutdown`, `be.dialog.rename`, `be.dialog.new-folder`, `be.dialog.group-info`, `be.dialog.item-info`, `be.dialog.new-program`, `be.dialog.run`, `be.dialog.help`, `be.dialog.backgrounds`, `be.dialog.change-icon` |
| `be.dialog.button:<label>` | a dialog button (`OK`, `Cancel`, `Yes`, `No`, `Apply`, `Change Icon...`, `Browse...`, `Display`, `Restart`, `Shut Down`) |
| `be.dialog.field:<name>` | text inputs: `name`, `path`, `command`, `workingDir`, `arguments`, `environment`, `shortcutKey` |
| `be.dialog.select:<name>` | selects: `group`, `launchGroup`, `runMode` |
| `be.dialog.dark` / `be.dialog.swatches` / `be.dialog.icon-grid` / `be.dialog.help-list` | Backgrounds check box and swatches, Change Icon grid, Help topic list |

## Capture views

`godot --path . -- --capture=<view> --out=artifacts/<view>.png` (window 640x480 logical; `be-scale3` renders at 3x).

`be`, `be-folder`, `be-details`, `be-mini`, `be-zoom`, `be-menu`, `be-context`, `be-bg-context`, `be-desk-context`,
`be-deskbar`, `be-deskbar-sub`, `be-getinfo`, `be-rename`, `be-trash`, `be-trash-confirm`, `be-newfolder`,
`be-newfolder-ok`, `be-find`, `be-find-results`, `be-quicksearch`, `be-about`, `be-launch`, `be-two-windows`,
`be-hidden`, `be-move`, `be-resize`, `be-close`, `be-tools`, `be-switch`, `be-dark`, `be-dark-folder`, `be-scale3`.

## Launch groups and Export All / Import All

| Id | Element |
|----|---------|
| `be.dialog.launch-groups` | the Launch Groups dialog |
| `be.dialog.launch-groups-list:<n>` | row for group `n` |
| `be.dialog.launch-group-name` / `be.dialog.select:number` | name field / number select in the sub-dialogs |
| `be.dialog.launch-group-number` / `be.dialog.launch-group-delete` | Number and Delete sub-dialogs |
| `be.dialog.members` / `be.dialog.members-list:<groupId:itemId>` | Members dialog / one checklist row |
| `be.dialog.select:launchGroup` | Launch group select in Get Info |
| `be.dialog.import-confirm` | Import All confirmation |

Deskbar menus taller than the shell scroll; looking up a menu row scrolls it into view first.

## Sticky notes

`be.dialog.new-note`, `be.dialog.select:noteColor`, `be.dialog.field:noteText`, the popup row "New Note…" and the Find type
"Sticky notes". Note windows use the shared `note:<itemId>` ids (see AUTOMATION_IDS.md).

Note menu: `be.popup-item:Close`, `Get Info`, `Color` (submenu `Yellow` ... `Gray`), `Move to Trash…`; the trash
confirmation is `be.dialog.note-trash` with `be.dialog.button:Delete` / `Cancel`. The logo menu adds
`be.popup-item:New Note…`, `Launch Groups…`, `Export All…`, `Import All…`.
