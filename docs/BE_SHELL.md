# Be shell (BeOS-style)

`BeShell` (`src/shells/be/`) is the shell selected by `settings.shell == "be"` (scale key `beScale`). It implements the
BeOS-flavoured design in `Program Manager.dc.html` (the `isBe` markup and its script logic): a blue desktop of folder
icons, yellow-tabbed folder windows, a Deskbar on the right edge, popup menus and square-cornered dialogs. Like the other
shells it is drawn in integer logical pixels (the host applies the integer content scale) and uses `ProgramStore`, `UIState` and `Platform` for most work, and calls `Launcher`, `LaunchGroups`, `Sounds` and a Windows 95 dialog helper directly (`be_dialogs.gd`, `be_shell.gd`).

## Mapping to the data model
* **Groups = folders.** Every group is a desktop icon and a folder window; the root window "Program Manager" lists all
  groups (List View columns Name / Size / Type). Items are application icons inside a folder window.
* **Persisted:** groups/items (add, rename, duplicate, move to another group, trash, sort via Clean Up) and
  `settings.theme` (`light`/`dark`, from the Backgrounds dialog). Item fields edited in Get Info: name, path
  (Target), workingDir, arguments, environment, runMode, launchGroup, shortcutKey, icon, group.
* **Session only:** window geometry/z-order/hidden/zoomed/view, selection, Find state and the desktop colour chosen in
  Backgrounds. No existing settings key fits per-shell window state, so nothing is written.

## Files
| File | Role |
|------|------|
| `be_shell.gd` | shell root: layers, command dispatch (`do_action`), launching + toast, selection, theme, file drops, Quick Search |
| `be_desktop.gd` / `be_window.gd` / `be_folder_view.gd` / `be_find_view.gd` | desktop icons, window chrome (tab, menu bar, status, grip), Icon / Mini Icon / List views, Find window |
| `be_deskbar.gd` / `be_popup.gd` / `be_toast.gd` | Deskbar (logo menu with group submenus, tools button, clock, running windows), popup menus, launch feedback |
| `be_dialog.gd` / `be_dialogs.gd` + `be_button/label/field/select/check/choice/icon_box.gd` | modal dialogs and their widgets |
| `be_window_store.gd`, `be_menu_state.gd`, `be_menu_model.gd`, `be_geometry.gd`, `be_dialog_logic.gd`, `be_icon_catalog.gd`, `be_theme.gd` | **pure logic** (no nodes/autoloads), covered by `tests/unit/test_be_*.gd` |
| `be_font.gd`, `be_draw.gd`, `be_ui.gd` | drawing helpers |

## Behaviour
* **Folder windows**: drag the tab to move, double-click the tab to hide (the Deskbar row stays; clicking it shows the
  window again), close box (left) and zoom box (right; zoom fills the desktop like the design), grip resizes (min
  320x220; Find min 460x280). Right-click: item menu (Open, Get Info, Edit Name, Duplicate, Move to Trash), folder menu,
  or the background menu (Add Program… / New Folder, view choice, Clean Up, Get Info, Close). Menu bar: File, Edit
  (disabled placeholders as in the design), View, Help. Hovering another title while a menu is open switches menus.
* **Desktop**: icon column wraps at the bottom margin; right-click = New Folder, Clean Up, Find…, Launcher Tools…,
  Backgrounds…, Help. Launcher Tools… emits `request_show_launcher_tools` (also the Deskbar tools button and
  Ctrl+Alt+T).
* **Launch Groups…** (Deskbar menu, `be_launch_groups.gd`) creates, renames, renumbers, deletes and launches launch groups and edits their members in a checklist. The Deskbar menu also has **Export All…** / **Import All…** (asks first). Menus taller than the shell scroll.
* **Deskbar**: logo menu (About, Find, Run, Launcher Tools, Backgrounds, Help, Restart, Shut Down) followed by a
  submenu per group listing its items; clock (`h:mm AM/PM`, fixed in captures); one row per open window (click shows /
  hides, right-click Show/Hide/Zoom/Close).
* **Launching**: double-click / Open / Enter calls `Platform.launch`; success shows the "Starting …" toast, failure an
  alert dialog. `UIState.launch_feedback` (batch launches from Launcher Tools) drives the same toast.
  `settings.minimizeOnUse` is honoured. Files dropped on a folder window are added to that group.
* **Quick Search** (`toggle_quick_search`): opens/focuses the Find window, closes it when it is already active. Find
  uses the design's filters (name contains, type, group) through `BeDialogLogic.find`.
* **Dialogs**: Edit Name, New Folder, folder/item Get Info (+ Change Icon), New Program (Add Program…, native Browse),
  Run, Move to Trash confirm, About, Help topics, Backgrounds (desktop colour + dark mode), Shut Down (Restart resets the
  session; Shut Down emits `request_quit`). Enter = default button, Esc = cancel.
* **Keyboard**: Ctrl+Alt+T, Ctrl+Shift+Space (Cmd+Shift+Space on macOS) for Quick Search, Esc/arrows/Enter inside menus and
  dialogs, Enter opens the selected entry, and Space or Enter activates a focused button.
* **Dark theme**: `BeTheme` carries the design's `DARK` tables (backgrounds, shadows, text); `BeTheme.dark` follows
  `settings.theme`. A desktop colour picked in Backgrounds is used verbatim (as in the design); the default colour
  darkens with the theme.

## Fonts and icons
No new font is bundled. The design's smooth Helvetica stack is approximated with a `SystemFont`
(`Helvetica Neue, Helvetica, Nimbus Sans, Liberation Sans, Arial, DejaVu Sans`, then Godot's default), laid out on fixed
18 px line boxes so layout does not depend on the font's metrics. The pixel fonts are not used by this shell.
The 64px icons in `assets/be/` are drawn at 32/16 logical px with the shell's linear texture filter (the host's nearest
filter only applies to the pixel shells' art); chrome stays crisp.

## Not implemented (deliberately)
* Arrange/Cascade/Tile (the design has none for Be), Select All / Edit menu actions (disabled in the design).
* Screen-reader proxy (`A11y`) integration - the other shells' accessibility tree is not wired for Be yet.
* Window geometry persistence (see above).
* `request_switch_shell`, tray hide and window maximise/minimise requests are not emitted: the design has no control
  for them; shells are switched from Launcher Tools like the other shells.

## Tests and captures
Unit tests: `tests/unit/test_be_*.gd`. Visual drivers: `tests/visual/be_scenarios.gd`
(`godot --path . -- --capture=be-folder --out=artifacts/be-folder.png`), ids in `tests/visual/BE_AUTOMATION_IDS.md`.

## Known gaps (2026-11-14 audit)

- Find: the Type and Group selectors store their values, but the search does not use them, and the path filter is always empty (BE-06).
- Launch All: the toast can show the wrong group numbers (BE-01). Failed items do not stop the batch.
- New Website, New Program, New Folder and Edit Name close without a message when the input is invalid (BE-03).
- Get Info stores a Shortcut key, but nothing in the BeOS shell starts an item from it (BE-07).
