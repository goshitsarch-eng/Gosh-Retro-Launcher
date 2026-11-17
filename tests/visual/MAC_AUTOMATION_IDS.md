# Mac shell automation ids

Ids are resolved by `Automation` (`src/app/automation.gd`) from controls in group `pm_auto` (an `auto_lookup(id)` method or
meta `auto_id`). Rects are in shell logical pixels. `<label>` matches an item's label (or command id) exactly.

| Id | Element |
|----|---------|
| `mac.menu:logo` / `File` / `Edit` / `View` / `Special` / `Help` / `app` | Menu bar titles (`app` = "Program Manager" menu) |
| `mac.clock` | Clock text in the menu bar |
| `mac.popup-item:<label>` | Row of the open menu / context menu |
| `mac.select-item:<label>` | Row of an open pop-up (select) list |
| `mac.desktop-icon:computer` / `trash` (or the label) | Desktop icons (32px icon rect) |
| `mac.window:<key>:close` / `zoom` / `shade` / `title` / `grip` / `frame` | Window chrome; key = `computer`, `g:<groupId>`, `find` |
| `mac.window.active:<part>` | Same, for the frontmost window |
| `mac.window:<key>:item:<index or name>` | Icon of an entry in a folder window |
| `mac.folder-item:<index or name>` | Same, in the frontmost folder window |
| `mac.folder-view` | Content area of the frontmost folder window |
| `mac.find.where`, `mac.find.type`, `mac.find.query`, `mac.find.run` | Find window controls |
| `mac.find.result:<index>` | Row of the Find results |
| `mac.dialog` | Frame of the topmost dialog |
| `mac.dialog.button:<label>` | Dialog push button (`OK`, `Cancel`, `Yes`, `No`, `Change Icon...`, `Browse...`, `Display`) |
| `mac.dialog.field:<label>` | Text field (`Name`, `Target`, `Start in`, `Arguments`, `Environment`, `Shortcut key`, `Command line`, `Run`) |
| `mac.dialog.select:<label>` | Pop-up (`Where`, `Launch group`, `Open as`, `Group`) |
| `mac.dialog.check:<label>` | Check box (`Dark mode`) |
| `mac.swatch:<name>` | Desktop Pictures colour swatch |
| `mac.help:<index or label>`, `mac.browse:<...>`, `mac.shutdown:<id or label>`, `mac.icon-choice:<id>` | List rows in dialogs |
| `mac.toast` | Launch feedback toast |

## Capture views (`tests/visual/mac_scenarios.gd`)

`mac`, `mac-menu`, `mac-menu-logo`, `mac-menu-special`, `mac-app-menu`, `mac-folder`, `mac-folder-list`,
`mac-folder-selected`, `mac-getinfo`, `mac-getinfo-done`, `mac-context`, `mac-desk-context`, `mac-folder-context`,
`mac-trash` (confirm box), `mac-trash-done`, `mac-find`, `mac-quick-search`, `mac-rename`, `mac-rename-done`,
`mac-new-folder`, `mac-new-folder-done`, `mac-about`, `mac-help`, `mac-run`, `mac-desktop-pictures`, `mac-shade`,
`mac-zoom`, `mac-drag`, `mac-resize`, `mac-close`, `mac-launch`, `mac-shortcuts`, `mac-shutdown`, `mac-switch`,
`mac-dark`, `mac-dark-folder`, `mac-scale2`, `mac-scale3`.

Do not run two captures at once (or alongside another shell's capture): concurrent Godot instances give
unreliable injected input and stale PNGs.

## Launch groups

| Id | Element |
|----|---------|
| `mac.launch-groups:<n>` | row for group `n` in the Launch Groups dialog |
| `mac.launch-groups.new` / `.rename` / `.members` / `.delete` / `.launch` / `.done` | its buttons |
| `mac.launch-groups.number` | Number pop-up |
| `mac.launch-group-members:<program name \| groupId:itemId \| index>` | a Members checklist row |

Export All… and Import All… are File menu rows (`mac.popup-item:Export All…`). Every mac dialog now also cancels on
Cmd/Ctrl-period.

## Sticky notes

New Note dialog: `mac.dialog.field:Title`, `mac.dialog.field:Text`, `mac.dialog.select:Color`, `mac.dialog.select:Folder`,
`mac.dialog.swatch:Color`. The notes layer is `mac.notes-layer`; note windows use the shared `note:<itemId>` ids
(see AUTOMATION_IDS.md).

Note menu rows (right-click or Control-click a note): `mac.popup-item:Close`, `Get Info`, `Yellow` ... `Gray`,
`Move To Trash…`; their commands are `note-close`, `note-info`, `note-color:<id>`, `note-trash`.
