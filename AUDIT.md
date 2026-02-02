# Documentation Audit Report

## Summary

- Source files analyzed: 38
- Documentation files reviewed: 1 (README.md)
- Discrepancies found: 10
- Gaps identified: 8

## Discrepancy Log

| Location | Type | Description | Resolution |
|----------|------|-------------|------------|
| README.md badge | OUTDATED | Claims Electron 28+; actual version is ^40.0.0 (`package.json:34`) | Updated badge to Electron 40 |
| README.md badge | OUTDATED | Claims React 18; actual version is ^19.2.4 (`package.json:37`) | Updated badge to React 19 |
| README.md badge | OUTDATED | Claims TypeScript 5.3; actual version is ^5.9.3 (`package.json:39`) | Updated badge to TypeScript 5.9 |
| README.md:44 | INCORRECT | Clone URL `yourusername/ElectronAppLauncher.git` is a placeholder | Updated to `goshitsarch-eng/Gosh-Retro-Launcher.git` |
| README.md:79–88 | OUTDATED | Instructs users to download fonts and icon PNGs into `assets/fonts/` and `assets/icons/`; fonts are bundled at `src/renderer/src/assets/fonts/` and icons are embedded as data URLs in `src/renderer/src/utils/icons.ts` | Removed section; replaced with accurate tray icon and packaging icon notes |
| README.md:122–128 | OUTDATED | Tech stack versions all outdated (Electron 28+, React 18, TypeScript 5, Zustand unversioned) | Updated all to match `package.json` versions |
| README.md:97–117 | MISLEADING | Architecture tree omits Common/, hooks/, utils/, types/, QuickSearch/ directories | Replaced with complete tree matching actual file structure |
| README.md features | MISSING | No mention of dark mode, theme support, scalable title bars, built-in icon picker (40+ icons), launch groups, single-instance enforcement | Added all to features list |
| README.md | MISSING | No mention of CI/CD workflows (5 GitHub Actions files exist) | Added CI/CD table |
| README.md | MISSING | No mention of data model, store file name, or settings structure | Added Data Model section |

## New Documentation Created

- `AUDIT.md` — this file

## Documentation Updated

- `README.md` — full rewrite based on code analysis

## Remaining Uncertainties

### Cannot Determine from Code

| Item | What is Unclear | What Would Resolve It |
|------|-----------------|----------------------|
| CI workflow scripts | Workflows reference `package:win`/`package:mac`/`package:linux` which don't exist in `package.json` | Running the workflows or asking the author if scripts were renamed |
| `autoArrange` setting | Stored and toggled in UI but unclear if it affects item layout in `ItemGrid` beyond being a flag | Runtime testing with the setting toggled |
| `shortcutKey` field | Present in `ProgramItem` type and editable in the dialog, but no code registers these as keyboard shortcuts | Author input on whether this is planned or vestigial |
| Tray `launch-item` channel | `tray.ts:28` sends a `launch-item` event to the renderer, but no listener for this channel was found in the preload valid channels list | Runtime testing to confirm if tray item launches work |

### Requires Runtime Verification

| Behavior | Why Static Analysis is Insufficient |
|----------|-------------------------------------|
| .desktop file parsing on Linux | The parser handles field codes but actual .desktop files vary widely |
| macOS code signing and notarization | Requires Apple credentials and CI environment to verify |
| Flatpak build pipeline | Generates a manifest at build time; correctness depends on runtime SDK availability |
| Drag-and-drop file addition | `ItemGrid` handles `drop` events but actual behavior depends on browser file API |

### Needs Author Input

| Question | Context |
|----------|---------|
| Are the `package:*` npm scripts intentionally different from `build:*`? | CI workflows will fail without them |
| Is `ProgramItem.shortcutKey` a planned feature or deprecated? | The field is stored and editable but has no runtime effect |
| Should the `launch-item` tray IPC channel be added to the preload allowlist? | Currently not in `validChannels` array (`src/preload/index.ts:69`) |

## Recommendations

1. **Fix CI scripts**: Either add `package:win`, `package:mac`, `package:linux` scripts to `package.json` or update the workflow YAML files to use `build:win`, `build:mac`, `build:linux`.
2. **Wire up or remove `shortcutKey`**: The field exists in the data model and UI but does nothing. Either register shortcuts via `globalShortcut` or remove the field to avoid confusion.
3. **Add `launch-item` to preload valid channels**: The tray sends this event but the preload bridge may block it since it's not in the allowlist. Verify and fix.
4. **Add tray icon assets**: The `assets/icons/` directory contains only a `.gitkeep`. Platform-specific tray icons should be added or the fallback behavior should be documented as intentional.
5. **Add `resources/` icon assets**: The `resources/` directory contains only a `.gitkeep`. Packaging will produce apps without proper icons.
