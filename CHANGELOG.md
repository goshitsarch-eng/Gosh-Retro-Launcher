# Changelog

All notable changes to Gosh Retro Launcher are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
