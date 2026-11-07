# Electron → Godot parity

Every user-visible behavior of the 1.0.6 Electron build and how the Godot build was checked.
**T** unit-tested (headless, 257 tests) · **V** pixel-diffed against the Electron baseline · **S** inspected in a real render ·
**E** exercised end-to-end with injected input in the running app · **X** exported Linux build run · **M** platform-specific, *not run in this
environment* (code written and reviewed, parts unit-tested) · **GAP** known difference.

## Data & storage
| Feature | Status |
|---|---|
| Same `program-manager-data.json`, same per-OS location; 1.x files load unchanged (incl. tab-indented electron-store output) | T |
| Schema migration v1→v5, legacy geometry copied per shell, invalid scales/positions normalized | T |
| Strict validation of groups/items/settings/profiles/launch payloads | T |
| 300 ms debounced saves, now also flushed on exit (can't lose the last edit) | T |
| Versioned auto backups (12 kept, 30 s throttle), manual restore points, restore | T |
| Corrupt store recovered from newest backup, corrupt copy kept | T |
| JSON export/import with validation + 10 MB cap | T |
| Workspace profiles, independent Win31/Win95 layouts | T |

## Launching
| Feature | Status |
|---|---|
| Tokenizer, exec validation, env parsing, arguments, working dir | T |
| Launch from a real double-click in both shells (spawns the process, args honored) | E (Linux) |
| `.desktop` Exec parsing | T, E |
| `.lnk` target/args/cwd, exe/com run modes (min/max via PowerShell), bat/cmd | T (parser, payload); **M** (running) |
| macOS `.app` via `open -a … --args` | **M** |
| URLs (http/https only) | T; opening a browser **M** |
| Batch launch: delay clamp 0–10 s, ≤200 items, numbered groups, Launch All / Launch Group, order, progress-before-launch | T |
| Launch-feedback toast | S |
| Minimize on Use | **M** (no window manager under Xvfb) |
| Single instance (second launch focuses first) | T + two-process run on Linux; Windows/macOS **M** |

## Shells
| Feature | Status |
|---|---|
| Win95 desktop/taskbar/Start cascades/windows/folder views/Find/Run/Shut Down/wizard/properties/messages | V + S + E (layout, colours, bevels, positions match; see below) |
| Win95 menu/input model (tracking, cascades, bare Alt, Win key, Alt+Tab, Shift+F10, type-to-select, Ctrl+A) | T (state machines) + E |
| Win95 scale 1×–4×, non-divisible remainder, 125 % DPR | V |
| WfW chrome, menus/accelerators, MDI groups, minimized icons, cascade/tile/arrange, desktop mode | V (`desktop-minimized` 0.14 %) + S + T |
| WfW dialogs (properties, new, move/copy, run, exit, help, about, welcome, confirm, settings, icon picker) | S + E (22-check interaction run) + T |
| WfW Quick Search, launch feedback | S + E + T |
| Launcher Tools window (all sections) | T (logic) + S |
| Shell switch at runtime (persist-first, rollback), per-shell geometry | T + V (switch result identical to a cold start) + E round trip |
| Win31 `.GRP` import/export (checksummed PMCC) | T |
| Sound effects | T (synthesis); audible output **M** |
| Optional local RTM icon/font packs (both shells) | T (atlas), S |

## System integration
| Feature | Status |
|---|---|
| Tray icon + menu, group submenus, Exit, Show, Launcher Tools | **M** (model T) |
| Minimize to tray on close | **GAP** (minimizes; taskbar entry stays) |
| Drag & drop files onto a group window | T (routing/target resolution); OS drag **M** |
| Icon extraction exe/dll/ico/icns/.app/.desktop + WfW 16-colour quantization | T (synthetic binaries) |
| Native open/save dialogs with per-OS filters | T via test provider; native **M** |
| Window frame (native Win95 / custom Win31), bounds kept on switch | S (borderless flip); OS behavior **M** |
| Ctrl+Alt+T Launcher Tools, in-app Quick Search shortcut | T |
| Global hotkey Ctrl/Cmd+Shift+Space while backgrounded | **GAP** (no OS-wide hotkey API; tray "Quick Search" item instead) |
| Exported Linux build starts and renders both shells with fonts/icons | X |
| Windows/macOS exports, CI workflows, installers | **M** (never executed) |

## Pixel comparison against the Electron baselines
All 41 baselines were re-rendered and diffed (rule: ≤ 0.5 % of pixels differing by > 20/channel).
Only `desktop-minimized` (0.14 %) meets it; the rest are 0.6–7 %. The residual is accounted for by:
1. **Icon art.** The baselines were captured with the author's gitignored licensed icon pack
   (`assets/*-rtm-local`); the distributable build uses the clean-room set. Opaque icon pixels differ everywhere.
2. **Glyph shapes.** Baselines used Chromium rasterization (host fonts for WfW); Godot draws the bundled 1-bit fonts.
3. `win95-move-outline`/`size-outline`: the original harness fired the arrow keys in the same tick as the menu click,
   so its outline never moved; the Godot scenario moves it, as a correct implementation does.
Shift analysis on the desktop labels, taskbar, menu bar, status bar and folder rows shows zero offset. With the
local packs installed the build uses them (icons for both shells, the RTM bitmap-font atlas for Windows 95).

## Intentional differences
* WfW: item drag between group windows (Ctrl copies) and OS file drops onto group windows are implemented; in the TS they
  only existed in an unused generic grid. `labelDisplay: ellipsis` is honored. Desktop-mode window is mouse-resizable.
* WfW dialogs: `©` → "(c)", `×` → "x" (glyphs absent from the strike); combo/radio/checkbox are drawn, not native.
* Win95 popups draw above the taskbar; outside-click closes the whole cascade.
* Accessibility: no screen-reader tree (the old build had ARIA); everything is keyboard-reachable.
* No AppImage/RPM, notarization, or macOS template tray icon (see PLATFORM.md).
