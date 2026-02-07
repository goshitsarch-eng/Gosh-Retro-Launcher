# Changelog

All notable changes to Gosh Retro Launcher are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- macOS notarize config updated for electron-builder v26 -- notarize option set to boolean, teamId read from `APPLE_TEAM_ID` env var (`af838e8`)
- CI: added `--publish never` to prevent electron-builder auto-publish during CI builds (`d72fc77`)
- Linux CI: dropped ARM64 RPM target and added `fail-fast: false` to build matrix (`d7f5779`)
- ARM64 RPM build: added `executableName` to electron-builder config to avoid spaces in install path (`99215c9`)

### Removed

- macOS CI workflow removed in favor of local builds (`ad6584f`)

---

## Research Log

### Method
- Ran `git log --oneline --all` to enumerate all 11 commits on `main`
- Ran `git tag -l` to find release tags (found one: `v1.0.4`)
- Ran `git show --stat` on each commit to identify files changed
- Ran `git log --format="%B"` to read full commit messages for feature details
- Ran `git log v1.0.4..HEAD` to identify unreleased commits (5 found)
- Ran `git log v1.0.4` to identify tagged commits (6 found)
- Cross-referenced commit messages against `--stat` output to verify claims

### Findings
- **Tag v1.0.4** points to commit `99215c9` (2026-02-02), the last CI fix
- **package.json version** bumped to `1.0.5` for the 2026-02-06 release
- **Two tags**: `v1.0.4` (initial release) and `v1.0.5` (feature release)
- **11 total commits**: 6 in v1.0.4 (initial + 5 CI/build fixes), 5 in v1.0.5 (4 feature commits + 1 merge commit)
- **PR #8** (`e203023`) is a merge commit for `95ae107`; changes attributed to the feature commit, not the merge
- **Commit authorship**: initial + CI fixes by Goshitsarch/Vaughan; PR #8 feature commit by Claude (Anthropic); remaining 3 feature commits by Goshitsarch

### Commit-to-section mapping
| Commit | Section | Category |
|--------|---------|----------|
| `47893a2` Initial commit | 1.0.4 | Added |
| `af838e8` Fix mac notarize | 1.0.4 | Fixed |
| `ad6584f` Remove macOS CI | 1.0.4 | Removed |
| `d72fc77` Fix --publish never | 1.0.4 | Fixed |
| `d7f5779` Fix Linux CI | 1.0.4 | Fixed |
| `99215c9` Fix ARM64 RPM | 1.0.4 | Fixed |
| `95ae107` UI enhancements | Unreleased | Added/Changed |
| `e203023` Merge PR #8 | (skip -- merge commit) | -- |
| `105e11a` Vitest + UI/IPC | Unreleased | Added/Changed/Removed/Security |
| `a22f256` Shell system | Unreleased | Added/Changed |
| `ea99bf6` Sounds/animations | Unreleased | Added |
