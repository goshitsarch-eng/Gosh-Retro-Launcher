# Changelog

All notable changes to Gosh Retro Launcher are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-11-20

### Fixed
- The macOS app launches and quits cleanly. A second Windows instance hands off to the running app. The Windows for Workgroups system menu restores the previous window size and position.
- Launcher Tools saves edited launch settings and adds websites to the selected destination. Dialogs remain usable at small window sizes, and Classic Mac dialog controls support keyboard navigation.
- The [desktop audit](docs/qa-2026-11-19/README.md) records all 27 corrections, their regression checks and the remaining platform coverage limits.
- macOS export: ETC2 ASTC import is enabled, so the universal macOS export succeeds (RT-01).
- Stored values that are out of range or of the wrong type are repaired on load and on import. Every repaired value is counted in the report, including a missing or wrong-type list or settings object (CORE-01).
- A stored or imported `launchGroup` above 8 is kept and launched in order. Only a negative number, a fraction or a string becomes 0, and that counts as a repair.
- Every item editor keeps a launch group above 8 when the item is saved; the WfW Properties dialog and Launcher Tools used to save it as 8.
- The BeOS launch message no longer shows the group number as its position in the batch (BE-01).
- An Import All that switches to another desktop now shows its result; the host reports it after the new desktop is up. A successful import shows an information icon in Windows for Workgroups, not a warning.
- Windows for Workgroups drop-downs show "&" in launch group names instead of dropping it.
- Launcher Tools fits its window: rows wrap and long names are clipped, so nothing runs off the right edge.
- Windows 95 New Internet Shortcut uses the program group chosen in it, not always the first one.
- The fallback file chooser (systems without a native one) opens inside the launcher window, fits it, and uses the desktop's font and colours (Mac: also dark mode) instead of Godot's dark editor look. Clicking a file and then Open works; Godot left Open greyed out.
- Classic Mac OS: while you type in a note or the Find field, item commands such as Cmd-T (Move To Trash) no longer act on the selected icon. Pop-up menus open over their button with the current item under the pointer.
- Windows for Workgroups text draws the punctuation its faces lack (bold apostrophe, question mark and others; regular < > | `), so "Plumber's" no longer reads "Plumbers"; typographic quotes, dashes and the ellipsis are spelled out.
- The host tells each desktop whether a notice is a problem, so a successful import shows an information icon in Windows for Workgroups.
- The launch group column is headed "Launch Group" instead of "Batch" on Mac and BeOS, and BeOS Find counts items, not files.
- Windows 95: the window move and size outline draws above sticky notes. BeOS sticky notes use the normal 15 px text.
- Saves no longer skip silently. A failed groups, settings or workspace-profile write shows a notice, logs an error and stays pending. Groups and settings are retried by the next save of the same kind, profiles by the next save of any kind, and all of them on exit (CORE-01).
- Restoring a backup writes one safety backup, not two.
- A JSON import is refused, and nothing is replaced, when its safety backup cannot be written.
- Imported shortcut keys without Ctrl, Alt, Shift, Meta or Win are cleared on import. Navigation keys never act as item shortcuts (CORE-02).
- A Windows program with a working folder starts in that folder. A missing program or folder is reported before anything starts, except in the fallback below (CORE-03).
- Windows: when the working folder is missing or the PowerShell launcher cannot run or is blocked, a `.exe` or `.com` with no arguments is started with ShellExecute, without its working folder. A failure of `Process.Start` itself is reported.
- Capture runs no longer read the real data file when `PM_USER_DATA` is not set (CORE-14).
- Options > Settings... opens the WfW settings dialog. Its changes are saved through the validated transaction, and a refused change shows "The settings could not be applied... Nothing was changed." (W31-001).
- Applying a workspace profile or restoring a backup asks first, and backs up the current data first. Either is refused if the backup cannot be written (W31-002).
- Import results, repaired values and save problems are reported to the user.

### Added
- Launch groups can be managed in every desktop. A Launch Groups window (WfW Launcher menu, Windows 95 Start menu, Mac Special menu, BeOS Deskbar) creates, renames, renumbers, deletes and launches groups and picks their programs from a checklist. Launcher Tools has the same controls.
- Launch groups have optional names (`settings.launchGroupNames`), shown everywhere a group appears, for example "Launch Group 3: Morning (2 items)". A named group can be empty. Moving a group to a number that is taken swaps the two.
- Windows 95 supports launch groups: a Launch group field in Properties and the Create Shortcut wizard, a Launch Groups cascade in Start > Programs, and an "In a launch group" Find filter.
- Export All... and Import All... in every desktop (WfW File menu, Windows 95 Start > Settings, Mac File menu, BeOS Deskbar, Launcher Tools) save or load the whole launcher in one file. Import asks first and backs up the current data. In Launcher Tools they replace Import JSON... and Export JSON....
- BeOS menus taller than the screen scroll, so the longer Deskbar menu fits at 640x480.
- Sticky notes, a third kind of item next to programs and web sites, in every desktop. A note has a title, a paper colour and text, opens as a sticky note on the desktop that saves as you type, and reopens after a restart if it was left open. Find and Quick Search search note text, and a note in a launch group opens when the group runs. Export All includes notes; .GRP export leaves them out and says so.
- Windows 95 shows a progress window while a launch group runs, with a Cancel button that stops the remaining items.
- End-to-end tests for Export All / Import All in every desktop, driven through the real menus and confirmation dialog, plus one that clicks and types through the fallback file chooser itself.
- Right-click (Mac: also Control-click) on a sticky note opens a menu in every desktop: Close, Properties / Get Info, Delete or Move to Trash, and on Mac and BeOS the paper colour. The note that has the keyboard has a stronger title strip.
- Windows 95 lists open sticky notes on the taskbar and in Alt+Tab.
- Windows for Workgroups File > New... offers Web Site next to Program Group, Program Item and Sticky Note, with its own Web Site Properties and a web icon.
- BeOS: Launch Groups, Export All, Import All and New Note in the logo's right-click menu; Find searches "Name or text" and shows each program's launch group.
- Screenshots of the four desktops in `docs/screenshots/`, shown in the README.
- `tools/capture_screenshots.sh`, which regenerates the screenshots from the running app with a temporary data folder.
- `PM_CAPTURE_NOTICE=1` (opt-in, capture runs only) shows store notices. Every capture run with it set then posts one sample save-failure notice, so the shell's message box can be checked. The `wfw-settings` view captures the settings dialog.
- An offline handbook at `docs/handbook/index.html`: user manual, architecture, development, build and release, troubleshooting, audit findings and coverage.

### Changed
- Godot 4.7.2, the latest stable release, replaces 4.6 in the CI workflows, the export preset header, the project feature tag, the README and the documentation.
- `docs/USER_GUIDE.md` is now a short guide that points to the handbook.
- Documentation corrected against the source: menus, settings, data locations, the Windows 95 desktop, the test suite, and the baseline and scenario counts.

### Known issues
- The Windows executable icon has one 256 px image, so the export warns about the other sizes.
- The Windows launch changes (CORE-03 and the ShellExecute fallback) have not been run on Windows.
- The item editors offer launch groups 0-8 only. For a stored 9, the WfW and BeOS editors and Launcher Tools save 8 on OK, and the Classic Mac OS Get Info dialog saves None.
- The item editor accepts a shortcut key without a modifier, such as F5, and that key then starts the item on the WfW desktop. Only import clears bare keys.
- Open audit findings are listed in the handbook's Audit findings chapter.

### Fixed

- macOS: Browse… for a program can now pick `.app` bundles (the chooser runs in "open any" mode starting in /Applications; bundles are folders and a plain file chooser greyed them out).
- Websites are now consistent across all four shells: Mac and BeOS gain a dedicated **New Website…** / **Add Website…** dialog (address, optional name, group; "github.com" becomes `https://github.com`, named after its host, with the web icon), matching the Windows 3.1 and 95 URL dialogs.
- Adding a website: a pasted web address now gets a sensible default name (its host, e.g. `github.com`) in the Mac and BeOS New Program dialogs, and `.app` names drop the suffix.

### Added

- **BeOS:** Launch All and Launch Group N in the Deskbar menu (same batch launch, delay and feedback toast as the Classic Mac OS Special menu); Add Website… in the File menu beside Add Program…. **Classic Mac OS:** New Program… and New Website… in the File menu, not just the right-click menu.
- **macOS menu bar:** the application menu gains **Settings…** (⌘,) opening Launcher Tools, and the Dock menu gains Launcher Tools… and Quick Search (`src/platform/mac_app_menu.gd`). The menu-bar app name and the standard About panel icon come from the exported bundle.
- **Classic Mac OS and BeOS shells** (`src/shells/mac`, `src/shells/be`), selectable from Launcher Tools and the WfW Settings dialog, with independent `macScale` / `beScale` scale settings, light and dark themes, Find / Quick Search, Get Info, rename, Move to Trash, New Folder and the shared launch feedback. Window and icon positions are session-only. See `docs/MAC_SHELL.md` and `docs/BE_SHELL.md`.
- Icon provenance notes: `assets/mac/PROVENANCE.md`, `assets/be/PROVENANCE.md`.
- Capture views `mac-*` and `be-*` with automation ids (`tests/visual/MAC_AUTOMATION_IDS.md`, `BE_AUTOMATION_IDS.md`) and a shell-registry unit test.

### Changed

- HiDPI: the native Launcher Tools window now scales its content and size to the display (OS scale on macOS/Wayland, inferred from screen height on Windows/X11), so text and controls stay crisp and legible on Retina and 4K panels and follow the window across monitors.
- Godot "creating applications" best practices: native `.ico`/`.icns` project icons and the Dummy 2D/3D physics engines (no physics is used), trimming startup cost.
- Windows 95 icons replaced by the Claude Design `icons95` set (`tools/import_design_icons.py`); the Win95 shell shows Windows for Workgroups artwork for WfW application ids; new `launcher-logo` icon.
- Visual harness: `click_id` waits for the element, and captures render every frame (`low_processor_mode` is off during captures) with a forced draw before the grab, which removes stale-frame captures.

### Fixed

- The single-instance lock is claimed on macOS. A free loopback port was misread as a foreign listener, so the app ran without the lock and a second launch did not hand off to the first.
- Built-in SVG icons are decoded from their raw bytes, so every icon load no longer logs "will not work on export".
- Launching an item with no target now says "No program is set for this item." instead of "Program not found: " with nothing after the colon.
- The BeOS Find window no longer opens under the Deskbar at 640×480. It is placed below the Deskbar's real height for the open windows, and at four open windows it is slightly shorter than its minimum height. The Deskbar logo menu uses "…" like the other BeOS menus.
- The BeOS details view shows a horizontal scrollbar when its columns are wider than the window, with the vertical scrollbar placed alongside it.
- The Win95 Create Shortcut wizard frees its text fields and labels when it closes. Each open used to leave objects alive.
- The Win95 Find dialog's Named field shows its text and caret vertically centred, instead of clipped at the bottom edge.
- The Mac list view and Find results shade the Name column header only when the rows really are in name order. Rows keep their store order.

## [2.0.0] - Godot rewrite

### Changed

- **Rewrote the entire application in Godot 4.6 (GDScript).** Electron, React, Node.js and the npm toolchain are gone; the app is a single Godot project (`project.godot`) with unit tests run headless by Godot itself.
- The data file (`program-manager-data.json`), its location on each OS, the schema (v5), automatic backups, and `.GRP` import/export are unchanged, so 1.x data and backups load as-is.
- Both shells are redrawn with a pixel-exact toolkit (1-bit bitmap text with the RTM advance table, bevel/dither primitives, integer 1x-4x whole-shell scaling) instead of DOM/CSS.
- Packaging moved to Godot exports (Windows NSIS + zip, macOS dmg + zip, Linux tar.gz + deb) with new GitHub Actions workflows.

### Added

- Visual regression harness that drives the real app with injected input and diffs against the Electron-era baselines; ports of the vitest suites plus tests for every new module.
- Runtime shell switching without recreating the process; a Quick Search item in the tray menu.
- `program-manager --quick-search` opens Quick Search in the running instance (or starts with it open), so macOS and Linux users can bind Cmd/Ctrl+Shift+Space in their system keyboard settings.
- Dropping files onto a WfW group window adds items; dragging an item between WfW group windows moves it (Ctrl copies).
- Optional local RTM icon/font packs are honored for both shells (`assets/win95-rtm-local`, `assets/wfw-rtm-local`).

### Security

- POSIX launches no longer route through `env(1)`: environment names starting with `-` were parsed as `env` options and a program path containing `=` as an assignment, so the process that ran could differ from the item's path. Environment additions are now applied around the fork, and the `cd` wrapper takes only positional operands.
- Windows: launch arguments are quoted with the MSVC/`CommandLineToArgvW` rules (a trailing `\` inside quotes no longer swallows the closing quote and merges arguments; empty arguments are kept), matching Node's `spawn`.
- Windows: item paths with a URI scheme other than http(s) (`ms-msdt:`, `search-ms:`, `file:` ...) are refused instead of being handed to `ShellExecute`, as the http/https-only URL policy intends.
- Store and backup files are created owner-only (`0600`) on macOS/Linux; items can carry environment variables such as tokens.
- Hostile icon files can no longer exhaust memory or CPU: PE resource extraction keeps spans instead of copies and caps resource size and decode attempts; binary plists have an object budget (shared references allowed exponential expansion); PNG/JPEG/WebP/BMP/SVG headers are size-checked before decoding, including the data-URL icons decoded from the store at every start.
- The single-instance listener caps concurrent loopback connections; the capture harness no longer uses a predictable `/tmp` directory.

### Fixed

- Performance: dragging a WfW group window, or Program Manager in desktop mode, moves the window instead of re-laying out and repainting every group on each mouse event; unchanged active-window/focus updates no longer rebuild menus or resync the Win95 desktop and taskbar; selected Win95 icons draw a cached dither mask instead of a per-pixel loop (marquee drags redraw per mouse move); icon pack lookups and icon-path regexes are no longer repeated on every draw; throttled auto-backups skip snapshotting the whole store.
- The POSIX launch unit test no longer assumes `/bin/true` exists (it does not on macOS).
- Parity: "Minimize to Tray on Close" hides the window again instead of minimizing it: on Windows through a small background helper (`ShowWindow`, no taskbar button; only when a tray icon exists), on macOS by hiding the app (the Dock icon brings it back). Linux still minimizes.
- Parity: Ctrl+Shift+Space opens Quick Search system-wide on Windows again (`RegisterHotKey` in the same helper), including while the window is hidden.
- Regression: on macOS/Linux a relative Command Line such as `./start.sh` is resolved against the item's working directory, and a bare program name is looked up on the PATH from the item's Environment field, as Electron's `spawn` did; both were reported as "Program not found".
- Regression: the WfW startup chime played twice on top of itself at launch.
- Regression: Win95 desktop right-click **New Folder...** creates "New Folder" and opens its property sheet again, instead of the name prompt used by folder windows.
- Parity: screen readers see the interface again (the 1.x build had ARIA). Both shells expose roles, names, states and keyboard focus through Godot's AccessKit layer, and launch feedback and search status are announced.
- Regression: the tray's **Launcher Tools...** restored and raised the hidden main window; it now only opens the tools window, like 1.x.

### Known differences from 1.x

- On macOS and Linux, Cmd/Ctrl+Shift+Space works from the background only after binding `program-manager --quick-search` in the system settings (Godot has no hotkey API; Windows uses a helper).
- On Linux, "Minimize to tray on close" minimizes (the taskbar entry stays): Linux desktops offer no portable way to hide a window.
- macOS tray icon is coloured instead of a template image; AppImage and RPM packages are no longer produced.
- File icons are extracted for exe/dll, ico, icns, .app, .desktop and common image formats; other file types get the default icon.
- See [docs/PLATFORM.md](docs/PLATFORM.md) for the full list.

## [Unreleased]

### Added

- Rebuilt the Windows 95 shell against the RTM retail layout with clean-room bitmap icons/font assets, canonical desktop/taskbar/Start hierarchy, Explorer-style launcher windows, and Win95-owned launcher dialogs.
- Added the primary **Start → Programs → group → app** launch path, My Computer group browsing, launcher Find/Run, complete task buttons, system menus, and keyboard navigation.
- Added independent Windows 95 Auto/1×/2×/3×/4× whole-shell scaling with logical geometry and explicit bitmap variants for modern high-resolution displays.
- Added `Launcher Tools...` under Windows 95 Start → Settings while retaining tray and Ctrl+Alt+T access from both shells.
- Added 39 deterministic Win95 visual states and pure tests for RTM tokens/bitmap text, independent icon families, shell shortcuts, nested menus, extended selection, list layouts, scrollbars, Find filters, dialog defaults, z-order/restore, persisted positions, and remainder/DPI geometry.
- Added a centralized Win95 menu/input controller with classic tracking/cascades, bare-Alt mode, Windows-key accelerators, menu-bar/system/context behavior, and priority routing across modal, menu, window, and desktop surfaces.
- Added multi-selection, marquee/type selection, active/inactive `ILD_BLEND50`-style icon masks, drag images, Auto Arrange/Line Up, manual position persistence, all four list views, report headers, and deterministic captured scrollbars.
- Added a single-instance modeless RTM-style Find primary window, exact 347×163 Run and 347×222 Shut Down frames, tabbed property sheets, and a Create Shortcut wizard.
- Restored visible Win31 launcher controls for launching all numbered groups, launching one group, and opening Launcher Tools.
- Restored the Launch Group field in Win31 program item properties and added runnable group controls to Launcher Tools.

### Changed

- Isolated Win95 dialogs, item views, menus, controls, bitmap text, icons, scaling, input routing, persisted positions, and open-window state from Win31 presentation primitives and the shared MDI store.
- Replaced mechanically shared icon geometry with separately authored 16×16 and 32×32 clean-room designs plus strict nearest-neighbor 2×–4× variants.
- Replaced browser-rasterized static Win95 chrome text with monochrome normal/bold bitmap output while retaining semantic text and ARIA.
- Removed post-RTM Win95 caption gradients, address bar composition, dark/fractional chrome, animations, synthetic interaction tones, onboarding hint, batch Start entry, and modern empty-state text.

### Fixed

- Made shell switching persist the complete settings payload before recreating the host window and roll back both disk and renderer state on errors.
- Corrected RTM frame/bevel edge order, taskbar top rows, Start/tray/menu dimensions, set-state checker patterns, caption controls, and dialog focus/default/cancel order.
- Covered non-divisible viewport remainders, selected DPR-aware raster variants, and rounded saved logical geometry without changing the canonical 1× grid.
- Improved program-item label wrapping, keyboard grid navigation, and Window > Tile geometry.
- Removed the conflicting scrollbars from the Win31 group icon picker.
- Made the full Launcher Tools window vertically scrollable with a visible status footer.

## [1.0.6] - 2026-04-29

### Changed

- Bumped the app version to 1.0.6. The About dialog shows this version from `package.json`.
- Simplified the README so it reads more like a human guide.
- Replaced dash heavy wording in the main documentation with cleaner sentences and ranges.

## [1.0.5] - 2026-02-06

### Added

- Pluggable desktop shell architecture with shell registry (`getShell`, `getAllShells`, `registerShell`) and shell type system (`a22f256`)
- Win95 shell with desktop, taskbar, start menu, and window chrome components (`a22f256`)
- Shell selector dropdown in Settings dialog under Appearance section (`a22f256`)
- Sound effects system using Web Audio API oscillator synthesis (`ea99bf6`)
- `useSounds` hook and `SoundPlayer` utility wired into windows, dialogs, start menu, and menu interactions (`ea99bf6`)
- `soundEnabled` boolean setting in AppSettings with Sound Effects checkbox in Settings dialog (`ea99bf6`)
- CSS animations for window open/close/minimize, dialog open/close, start menu, and menu fade-in (`ea99bf6`)
- `useAnimatedUnmount` hook for delayed unmount with exit animations (`ea99bf6`)
- ThemePreview component showing inline-styled miniature of Win31/Win95 shells in Settings dialog (`ea99bf6`)
- `@media (prefers-reduced-motion: reduce)` support to disable all animations (`ea99bf6`)
- Win95 chrome polish: CSS glyph buttons, status bar with item count, resize grip dots (`ea99bf6`)
- Vitest testing framework with 50+ unit tests for security-critical and utility functions (`105e11a`)
- Unit tests for `tokenizeCommand`, `isValidExecPath`, `isValidItem`, `isValidGroup`, `isValidSettings`, and icon utilities (`105e11a`)
- Global keyboard shortcuts: Alt+F/O/W/H for menu toggles, Shift+F4/F5 for window tiling/cascading, Escape to close, Enter to launch, Delete to remove (`105e11a`)
- Keyboard-accessible program items with tabIndex, ARIA roles, and arrow key navigation in grid (`105e11a`)
- First-run welcome dialog with onboarding information (`105e11a`)
- Quick search shortcut hint displayed in UI (`105e11a`)
- Right-click context menus on item grid background and MDI desktop (`105e11a`)
- Icon picker search/filter in ItemPropertiesDialog (`105e11a`)
- `isValidSettings()` validator with full StoreData import validation (`105e11a`)
- Typecheck and test steps added to CI workflows (`105e11a`)
- Text wrapping mode for item labels via `labelDisplay` setting (`wrap` or `ellipsis`) in AppSettings (`95ae107`)
- Platform-specific drag-and-drop app info extraction: macOS `.app` bundles, Windows `.lnk` shortcuts, Linux `.desktop` files (`95ae107`)
- 36 new SVG icons: Globe, Money, Heart, Lightning, Coffee, Home, Airplane, Car, Rocket, Robot, Puzzle, Compass, Map, Headphones, Microphone, Battery, Wifi, Bluetooth, Gear, Lightbulb, Bell, Flag, Pin, Eye, Hand, Pencil, Clipboard Check, Favorite Folder, Bookmark, Tag, Upload, Link, Power, Refresh, Sun, Moon (`95ae107`)

### Changed

- App.tsx refactored to resolve and render the active shell component via registry instead of embedding Win31-specific menu/MDI logic (`a22f256`)
- Drag and resize hooks switched from mouse events to pointer events for touch device support (`105e11a`)
- Quick search enhanced with path and group name matching plus relevance-based result ranking (`105e11a`)
- Store save operations debounced at 300ms for both groups and settings (`105e11a`)
- Icon picker grid expanded from 8 to 10 columns with taller scroll area (`95ae107`)

### Removed

- `shortcutKey` field removed from `ProgramItem` interface and all related UI (`105e11a`)

### Security

- Added `process.on('unhandledRejection')` and `process.on('uncaughtException')` handlers in main process (`105e11a`)
- Strong validation for IPC store data imports via `isValidItem`, `isValidGroup`, and `isValidSettings` (`105e11a`)

## [1.0.4] - 2026-02-02

### Added

- Initial release of Gosh Retro Launcher, a Windows 3.1 Program Manager clone built with Electron and React (`47893a2`)
- Windows 3.1-styled desktop with MDI (Multiple Document Interface) window management (`47893a2`)
- Program group management: create, rename, delete, view properties (`47893a2`)
- Program item management: create, edit, delete, launch executables (`47893a2`)
- URL shortcut support via dedicated New URL dialog (`47893a2`)
- Quick search overlay toggled via Ctrl+K / Cmd+K (`47893a2`)
- Draggable and resizable MDI windows with minimize/maximize/restore (`47893a2`)
- Menu bar with File, Options, Window, and Help menus (`47893a2`)
- Settings dialog with theme and appearance options (`47893a2`)
- Import/export of program data as JSON (`47893a2`)
- About dialog (`47893a2`)
- Confirmation dialog for destructive actions (`47893a2`)
- Error boundary component for crash resilience (`47893a2`)
- Zustand state management with programStore, uiStore, and mdiStore (`47893a2`)
- IPC bridge via preload script exposing `window.electronAPI` (`47893a2`)
- Electron-vite build system with separate tsconfig targets for main, preload, and renderer (`47893a2`)
- GitHub Actions CI workflows for Linux (AppImage, deb, rpm) and Windows (NSIS) builds (`47893a2`)

### Fixed

- macOS notarize config updated for electron-builder v26. The notarize option is a boolean, and teamId is read from `APPLE_TEAM_ID` (`af838e8`)
- CI: added `--publish never` to prevent electron-builder auto-publish during CI builds (`d72fc77`)
- Linux CI: dropped ARM64 RPM target and added `fail-fast: false` to build matrix (`d7f5779`)
- ARM64 RPM build: added `executableName` to electron-builder config to avoid spaces in install path (`99215c9`)

### Removed

- macOS CI workflow removed in favor of local builds (`ad6584f`)
