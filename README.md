# Program Manager

A nostalgic recreation of the classic Windows Program Manager, built with Electron and React. Organize and launch applications, URLs, and scripts from a retro-styled desktop -- with switchable Windows 3.1 and Windows 95 shells -- on Windows, macOS, and Linux.

![Retro Style](https://img.shields.io/badge/Style-Retro%20Desktop-008080)
![Electron](https://img.shields.io/badge/Electron-40-47848F)
![React](https://img.shields.io/badge/React-19-61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6)
![License](https://img.shields.io/badge/License-AGPL--3.0-blue)

<!-- TODO: Add screenshot of the application here -->

## Features

- **Two Desktop Shells**: Switch between a Windows 3.1 MDI desktop (menu bar, beveled borders, teal background) and a Windows 95 shell (taskbar, Start menu, desktop windows). Selectable in Settings.
- **Program Groups**: Create, rename, and delete groups. Each group opens as its own window containing program items. Drag and drop files onto a group window to add them.
- **Cross-Platform Launch**: Platform-aware program execution -- `.exe`/`.lnk`/`.bat` on Windows, `.app` bundles on macOS, `.desktop` files and executables on Linux. URLs open in the default browser.
- **System Tray**: Closing the window minimizes to tray (configurable). The tray context menu lists all groups and their items for quick launch. Double-click the tray icon to restore on Windows and Linux.
- **Quick Search**: Global shortcut (`Ctrl+Shift+Space` / `Cmd+Shift+Space`) opens a search overlay to find and launch any item across all groups. Results are ranked by relevance (name prefix > name substring > path/group match). Keyboard navigable with arrow keys and Enter.
- **Batch Launch**: Assign items to numbered launch groups (1--8) and launch them sequentially via File > Launch All, with a configurable delay between each (100ms--5000ms).
- **Import/Export**: Back up and restore all groups and settings as a JSON file.
- **Dark Mode**: Toggle between light and dark themes.
- **Scalable Title Bars**: Adjust the MDI window title bar size from 100% to 160%.
- **80+ Built-in Icons**: Embedded SVG and PNG icons in a searchable icon picker -- no external icon files needed. Custom icon paths (file URLs, data URLs) are also supported.
- **Sound Effects**: Retro sound effects (startup chime, window open/close, menu click, dialog open, error beep) generated with the Web Audio API. Toggleable in Settings.
- **CSS Animations**: Window open/close/minimize, dialog transitions, menu fade-in, and Start menu slide. Automatically disabled when the OS-level `prefers-reduced-motion` setting is active.
- **Keyboard Accessible**: Full keyboard navigation with ARIA roles, arrow keys in the item grid, and menu shortcuts (Alt+F/O/W/H in the Win31 shell).
- **Single Instance**: Only one instance of the application runs at a time. Launching again focuses the existing window.
- **First-Run Welcome**: A welcome dialog on first launch explains how to get started.

## Installation

**Prerequisites**: [Node.js](https://nodejs.org/) 22+ and npm.

```bash
# Clone the repository
git clone https://github.com/goshitsarch-eng/Gosh-Retro-Launcher.git
cd Gosh-Retro-Launcher

# Install dependencies
npm install

# Run in development mode
npm run dev

# Build for production (compile only, no packaging)
npm run build

# Package for your platform
npm run build:win    # Windows -- NSIS installer (x64 + arm64)
npm run build:mac    # macOS -- DMG + ZIP (universal)
npm run build:linux  # Linux -- .deb, .rpm, .tar.gz
```

## Development

```bash
# Start development server with hot reload
npm run dev

# Type check all targets (main, preload, renderer)
npm run typecheck

# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Build without packaging (outputs to out/)
npm run build

# Build unpacked directory (for testing packaging)
npm run build:unpack
```

DevTools can be opened by setting the environment variable `ELECTRON_OPEN_DEVTOOLS=1` before running in dev mode:

```bash
ELECTRON_OPEN_DEVTOOLS=1 npm run dev
```

## Architecture

For a visual overview, see the [System Architecture Diagram](docs/diagrams/system-architecture.md).

```
src/
+-- main/                  # Electron main process
|   +-- index.ts           # App lifecycle, single instance lock, global shortcuts
|   +-- window.ts          # BrowserWindow creation and management
|   +-- tray.ts            # System tray with dynamic group/item menus
|   +-- store.ts           # electron-store persistence (program-manager-data.json)
|   +-- ipc/               # IPC handlers
|       +-- index.ts           # Handler registration
|       +-- windowHandlers.ts  # Minimize, maximize, close, quit, isMaximized
|       +-- fileHandlers.ts    # File/icon selection dialogs, file existence check
|       +-- launchHandlers.ts  # Program launch, batch launch, .desktop parsing
|       +-- storeHandlers.ts   # Get/set groups and settings, import/export, validation
|       +-- appInfoHandlers.ts # Extract app info from dropped files
|       +-- __tests__/         # Unit tests for launch and store handlers
+-- preload/               # Context bridge (contextIsolation: true, sandbox: true)
|   +-- index.ts           # Exposes typed electronAPI to renderer
+-- renderer/              # React application
|   +-- src/
|       +-- App.tsx                # Root component -- shell resolution, theme, shortcuts
|       +-- main.tsx               # React entry point
|       +-- components/
|       |   +-- Common/            # Button, TextInput, Checkbox, Icon
|       |   +-- Menu/              # MenuBar, Menu, MenuItem, MenuSeparator
|       |   +-- MDI/               # MDIContainer, MDIWindow, MDIWindowControls
|       |   +-- Items/             # ItemGrid (with drag-drop), ProgramItem
|       |   +-- Dialogs/           # DialogManager + 10 dialog types (incl. ThemePreview)
|       |   +-- QuickSearch/       # QuickSearchOverlay
|       |   +-- ErrorBoundary.tsx  # React error boundary
|       +-- hooks/
|       |   +-- useDraggable.ts        # Pointer-event-based window dragging
|       |   +-- useResizable.ts        # 8-direction pointer-event window resizing
|       |   +-- useSounds.ts           # Sound player hook (wraps sounds.ts)
|       |   +-- useAnimatedUnmount.ts  # Delayed unmount for CSS exit animations
|       +-- shells/                # Pluggable desktop shell system
|       |   +-- types.ts               # ShellProps, ShellDefinition interfaces
|       |   +-- registry.ts            # Shell registration (win31, win95)
|       |   +-- index.ts               # Re-exports getShell, getAllShells
|       |   +-- Win31Shell.tsx         # Windows 3.1 shell (MenuBar + MDI)
|       |   +-- win95/                 # Windows 95 shell
|       |       +-- index.ts
|       |       +-- Win95Shell.tsx     # Shell root (desktop + taskbar + start menu)
|       |       +-- Win95Desktop.tsx   # Desktop with program group windows
|       |       +-- Win95Taskbar.tsx   # Bottom taskbar with Start button
|       |       +-- Win95StartMenu.tsx # Start menu overlay
|       |       +-- Win95Window.tsx    # Win95-styled group window chrome
|       +-- store/                 # Zustand state stores
|       |   +-- programStore.ts        # Groups, items, settings, debounced persistence
|       |   +-- mdiStore.ts            # Window z-order, open/close/focus/tile/cascade
|       |   +-- uiStore.ts            # Menus, dialogs, quick search, selection
|       +-- utils/
|       |   +-- icons.ts               # 80 built-in icon data URLs, getIconSrc()
|       |   +-- launchGroups.ts        # Launch group options (0--8)
|       |   +-- sounds.ts             # Web Audio oscillator sound effects
|       |   +-- __tests__/            # Unit tests for icons utility
|       +-- types/
|           +-- electron.d.ts          # Window.electronAPI type declaration
+-- shared/                # Shared across all processes
    +-- types/index.ts         # ProgramItem, ProgramGroup, AppSettings, StoreData, etc.
    +-- constants/ipc.ts       # IPC channel name constants (20 channels)
```

## Data Model

Application state is persisted via `electron-store` in a file called `program-manager-data.json`. See the [Data Flow Diagram](docs/diagrams/data-flow.md) for a visual representation.

### ProgramGroup

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | UUID |
| `name` | `string` | Display name |
| `icon` | `string` | Icon ID or data URL |
| `windowState` | `WindowState` | Position, size, minimized/maximized |
| `items` | `ProgramItem[]` | Items in this group |

### ProgramItem

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | UUID |
| `name` | `string` | Display name |
| `path` | `string` | Executable path or URL |
| `icon` | `string` | Icon ID or data URL |
| `workingDir` | `string` | Working directory for launch |
| `launchGroup` | `number?` | Launch group number (1--8), optional |

### AppSettings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `autoArrange` | `boolean` | `true` | Auto-arrange icons in group windows |
| `minimizeOnUse` | `boolean` | `false` | Minimize app after launching a program |
| `saveSettingsOnExit` | `boolean` | `true` | Persist window positions on exit |
| `launchDelay` | `number` | `500` | Delay (ms) between batch launches |
| `trayOnClose` | `boolean` | `true` | Minimize to tray instead of quitting |
| `groupChromeScale` | `number` | `1` | Title bar scale factor (1--1.6) |
| `theme` | `'light' \| 'dark'` | `'light'` | Color theme |
| `labelDisplay` | `'wrap' \| 'ellipsis'` | `'wrap'` | How item labels handle overflow |
| `shell` | `'win31' \| 'win95'` | `'win31'` | Active desktop shell |
| `soundEnabled` | `boolean` | `true` | Enable retro sound effects |

## Tray Icons

The tray module looks for platform-specific icons under `assets/icons/`:

- `tray-macTemplate.png` -- macOS template image for automatic dark/light mode adaptation
- `tray-win.ico` -- Windows
- `tray-linux.png` -- Linux

If the icon file is missing or empty, a small fallback PNG is generated at runtime.

## App Icons for Packaging

The `electron-builder.yml` expects platform-specific app icons in `resources/`:

- `icon.ico` -- Windows
- `icon.icns` -- macOS
- `icon.png` -- Linux (recommended 512x512)

## Tech Stack

| Technology | Version | Role |
|------------|---------|------|
| Electron | 40 | Desktop framework |
| React | 19 | UI (functional components, hooks only) |
| TypeScript | 5.9 | Type safety across main, preload, and renderer |
| Zustand | 5 | Client-side state management |
| electron-store | 8 | JSON file persistence in the main process |
| electron-vite | 5 | Build tooling with separate main/preload/renderer configs |
| electron-builder | 26 | Cross-platform packaging (NSIS, DMG, deb, rpm, tar.gz) |
| Vite | 7 | Renderer bundling with React plugin |
| Vitest | 4 | Unit testing framework |
| uuid | 11 | UUID generation for groups and items |

## CI/CD

GitHub Actions workflows build platform-specific artifacts on manual dispatch (`workflow_dispatch`) or version tag pushes (`v*`). Both workflows run typecheck and tests before building.

| Workflow | Runner | Architectures | Output |
|----------|--------|---------------|--------|
| `build-windows.yml` | `windows-latest` | x64, arm64 | `.exe` NSIS installer |
| `build-linux.yml` | `ubuntu-24.04` / `ubuntu-24.04-arm` | x64, arm64 | `.deb`, `.rpm`, `.tar.gz` |

Tagged releases (`v*`) automatically upload artifacts to GitHub Releases.

> **Note**: The `electron-builder.yml` configuration file includes macOS build settings (DMG, code signing, notarization), but no CI workflow for macOS currently exists. macOS builds can be run locally with `npm run build:mac`.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes and ensure they pass:
   ```bash
   npm run typecheck
   npm test
   ```
4. Commit your changes and push to your fork
5. Open a Pull Request

## Documentation

- [User Guide](docs/USER_GUIDE.md) -- End-user documentation
- [Architecture](docs/ARCHITECTURE.md) -- Technical architecture details
- [API Reference](docs/API_REFERENCE.md) -- IPC API and store interfaces
- [Changelog](CHANGELOG.md) -- Version history

### Diagrams

- [System Architecture](docs/diagrams/system-architecture.md)
- [User Flows](docs/diagrams/user-flows.md)
- [Data Flow](docs/diagrams/data-flow.md)

## Known Limitations

- The `saveSettingsOnExit` flag controls whether window position changes are persisted on close. All other settings (theme, shell, sound, etc.) are saved immediately when changed.
- The tray menu is rebuilt when the group list changes via IPC, but not when individual items within groups are renamed without triggering a full groups save.

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE).

---

## Research Log

This README was verified against the following source files on 2026-02-06:

| File | Verified |
|------|----------|
| `package.json` | Name, version (1.0.5), all scripts, dependencies, devDependencies |
| `LICENSE` | AGPL-3.0-only (matches package.json `license` field) |
| `electron-builder.yml` | appId, productName, all platform targets and output formats |
| `electron.vite.config.ts` | Build configuration, path aliases (@shared, @) |
| `vitest.config.ts` | Test configuration |
| `src/shared/types/index.ts` | All interfaces, defaults, type unions |
| `src/shared/constants/ipc.ts` | All 20 IPC channel names |
| `src/main/index.ts` | Lifecycle, single instance, global shortcuts, error handlers |
| `src/main/window.ts` | BrowserWindow config (800x600, sandbox, contextIsolation) |
| `src/main/store.ts` | electron-store name, schema, all accessors |
| `src/main/tray.ts` | Icon paths, context menu structure, double-click behavior |
| `src/main/ipc/launchHandlers.ts` | Platform switch, .desktop parsing, URL handling, tokenizer |
| `src/main/ipc/storeHandlers.ts` | Validation functions, import/export, tray update |
| `src/preload/index.ts` | Full electronAPI shape, all method signatures |
| `src/renderer/src/App.tsx` | Shell resolution, theme, quick search IPC, welcome dialog |
| `src/renderer/src/shells/registry.ts` | Two registered shells (win31, win95) |
| `src/renderer/src/shells/Win31Shell.tsx` | Menu bar, MDI, keyboard shortcuts |
| `src/renderer/src/shells/win95/Win95Shell.tsx` | Taskbar, Start menu, desktop |
| `src/renderer/src/components/Menu/MenuBar.tsx` | File/Options/Window/Help menus, all actions |
| `src/renderer/src/components/QuickSearch/QuickSearchOverlay.tsx` | Relevance ranking, max 10 results |
| `src/renderer/src/components/Dialogs/SettingsDialog.tsx` | All 10 settings fields verified |
| `src/renderer/src/components/Dialogs/WelcomeDialog.tsx` | First-run onboarding content |
| `src/renderer/src/store/programStore.ts` | All actions, debounced save (300ms) |
| `src/renderer/src/store/uiStore.ts` | 10 dialog types, menu/selection/quicksearch state |
| `src/renderer/src/utils/icons.ts` | 80 entries in BUILTIN_ICONS array, getIconSrc resolver |
| `src/renderer/src/utils/sounds.ts` | 7 sound functions, Web Audio oscillator-based |
| `src/renderer/src/utils/launchGroups.ts` | Options 0--8 |
| `.github/workflows/build-linux.yml` | x64+arm64, ubuntu-24.04, deb/rpm/tar.gz |
| `.github/workflows/build-windows.yml` | x64+arm64, windows-latest, NSIS .exe |
