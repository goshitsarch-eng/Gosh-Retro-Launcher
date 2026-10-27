# Electron -> Godot parity checklist

Every user-visible behavior of the 1.0.6 Electron build, and how it is verified in the Godot build.
Status legend: **T** = covered by a unit test, **V** = pixel-diffed against the committed Electron baseline,
**S** = inspected by screenshot, **M** = manual/platform-only (cannot run in CI here), **GAP** = known difference.
This table is filled in at the end of the port; open items are listed in the final report.

## Data & storage
| Feature | Verification |
|---|---|
| Same data file (`program-manager-data.json`) and location per OS; existing user data loads unchanged | T (test_persistence) |
| Schema migration (v1..v5), legacy single-shell geometry copied to both shells, invalid scale/positions normalized | T (test_migration) |
| Strict validation of groups/items/settings/profiles | T (test_validators) |
| 300 ms debounced saves (flushed on exit) | T |
| Versioned automatic backups (12 kept, 30 s throttle), manual restore points, restore | T |
| Corrupt store recovered from newest backup, corrupt file preserved | T |
| JSON export/import with validation + 10 MB cap | T |
| Workspace profiles (save/apply/rename/delete) with independent Win31/Win95 layouts | T |

## Launching
| Feature | Verification |
|---|---|
| Tokenizer, exec validation, environment parsing, arguments, working dir | T (test_launcher) |
| URLs (http/https only) open in default browser | T/M |
| Windows: .lnk target+args+cwd, exe/com run modes (min/max), bat/cmd via ComSpec | T (lnk parse) / M |
| macOS: .app via `open -a --args`; other executables | M |
| Linux: .desktop `Exec=` (field codes stripped, exec path validated) | T |
| Batch launch with delay 100..5000 ms, numbered groups 1..8, Launch All / Launch Group, exactly once, in order | T |
| Launch feedback toast; menu closes before launching | T/S |
| Minimize on Use | M |
| Single instance; second launch focuses the first | M |

## Shells
| Feature | Verification |
|---|---|
| Win95: desktop, taskbar, Start -> Programs -> group -> app, tray clock | V (win95-desktop/start/programs/program-items/settings) |
| Win95: windows (active/inactive, min/max/restore, system menu, outline move/size) | V |
| Win95: folder views Large/Small/List/Details, multi-select, marquee, type-to-select, Line Up/Auto Arrange | V/T |
| Win95: menu/input model (tracking, cascades, bare Alt, Win key, Alt+Tab, Shift+F10) | T |
| Win95: Find, Run, Shut Down, Create Shortcut wizard, property sheets, message boxes | V (win95-find*/run/shutdown/wizard/properties/message) |
| Win95: scale Auto/1x..4x, non-divisible remainder, DPR 1.25 | V |
| WfW: Program Manager chrome, menus + accelerators, MDI groups, minimized group icons | V (reference/desktop/desktop-minimized) / S |
| WfW: cascade/tile/arrange, drag/resize, item drag move/copy, label wrap/ellipsis, auto-arrange | T/S |
| WfW: desktop mode + minimize to desktop icon | V |
| WfW: all dialogs (properties, new, move/copy, run, exit, help, about, welcome, confirm, settings, icon picker) | S/T |
| WfW: Quick Search overlay | S/T |
| Shell switch persists settings first, rolls back on failure; per-shell group geometry | T |
| Independent Win31/Win95 scale (Auto/1x-4x) | T/V |
| Launcher Tools window (shell/scales/desktop mode/sound/tray, GRP import/export, URL items, launch groups, profiles, backups, JSON transfer) | T/S |
| Windows 3.x .GRP import/export (checksummed PMCC) | T |
| Sound effects (startup chime WfW only, window/menu/dialog/button tones), toggle | T |

## System integration
| Feature | Verification |
|---|---|
| Tray icon + menu (Show, Launcher Tools, group submenus, Exit); minimize to tray on close | M |
| Drag & drop files onto a group window (app info: name/path/workingDir/args/icon) | T/M |
| Icon extraction from exe/ico/icns/.app/.desktop; WfW 16-colour palette icon | T |
| Native open/save dialogs with per-OS filters | M |
| Window frame: native (Win95) vs custom (Win31), bounds kept on shell switch | M |
| Ctrl+Alt+T Launcher Tools from either shell | S/T |
| Global hotkey Ctrl/Cmd+Shift+Space while the app is in the background | **GAP** (no OS-wide hotkey API in Godot; in-app shortcut + tray item provided) |
| Packaging: Windows / macOS / Linux exports + CI | M |
