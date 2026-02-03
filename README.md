# Program Manager

A Windows 3.1 Program Manager clone built with Electron and React. Organize and launch applications, URLs, and scripts from a retro-styled MDI desktop — on Windows, macOS, and Linux.

![Windows 3.1 Style](https://img.shields.io/badge/Style-Windows%203.1-008080)
![Electron](https://img.shields.io/badge/Electron-40-47848F)
![React](https://img.shields.io/badge/React-19-61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6)

## Features

- **Windows 3.1 UI**: Beveled borders, teal desktop (`#008080`), classic bitmap-style W95FA font, MDI (Multiple Document Interface) windows with draggable and resizable group windows
- **Program Groups**: Create, rename, and delete groups. Each group opens as its own MDI window containing program items. Drag and drop files onto a group window to add them as items.
- **Cross-Platform Launch**: Executes programs based on platform — `.exe`/`.lnk`/`.bat` on Windows, `.app` bundles on macOS, `.desktop` files and executables on Linux. URLs open in the default browser.
- **System Tray**: Closing the window minimizes to tray (configurable). The tray menu lists all groups and their items for quick launch. Double-click the tray icon to restore on Windows/Linux.
- **Quick Search**: Global shortcut (`Ctrl+Shift+Space` / `Cmd+Shift+Space`) opens a search overlay to filter and launch any item across all groups. Keyboard navigable with arrow keys and Enter.
- **Batch Launch**: Launch all items in a group sequentially with a configurable delay (100ms–5000ms) between each.
- **Launch Groups**: Assign items to numbered launch groups (1–8) for batch launching subsets of items across groups.
- **Import/Export**: Back up and restore all groups and settings as JSON.
- **Dark Mode**: Toggle between light and dark themes from settings.
- **Scalable Title Bars**: Adjust the MDI window title bar size from 1x to 1.6x in settings.
- **Built-in Icon Picker**: Over 40 embedded Win 3.1–style icons (SVG and PNG data URLs) to assign to groups and items, with no external icon files required.
- **Single Instance**: Only one instance of the application runs at a time. Launching again focuses the existing window.

## Installation

```bash
# Clone the repository
git clone https://github.com/goshitsarch-eng/Gosh-Retro-Launcher.git
cd Gosh-Retro-Launcher

# Install dependencies
npm install

# Run in development mode
npm run dev

# Build for production
npm run build

# Package for your platform
npm run build:win    # Windows (NSIS installer)
npm run build:mac    # macOS (DMG + ZIP, universal)
npm run build:linux  # Linux (AppImage + Flatpak)
```

## Development

```bash
# Start development server with hot reload
npm run dev

# Type check all targets (main, preload, renderer)
npm run typecheck

# Build without packaging
npm run build
```

DevTools can be opened by setting the environment variable `ELECTRON_OPEN_DEVTOOLS=1` before running in dev mode.

## Architecture

```
src/
├── main/               # Electron main process
│   ├── index.ts        # App lifecycle, single instance lock, global shortcuts
│   ├── window.ts       # BrowserWindow creation and management
│   ├── tray.ts         # System tray with dynamic group/item menus
│   ├── store.ts        # electron-store persistence (program-manager-data.json)
│   └── ipc/            # IPC handlers
│       ├── index.ts        # Handler registration
│       ├── windowHandlers.ts   # Minimize, maximize, close, quit, platform
│       ├── fileHandlers.ts     # File/icon selection dialogs, file existence
│       ├── launchHandlers.ts   # Program launch, batch launch, .desktop parsing
│       └── storeHandlers.ts    # Get/set groups and settings, import/export
├── preload/            # Context bridge (contextIsolation: true)
│   └── index.ts        # Exposes electronAPI to renderer with typed interface
├── renderer/           # React application
│   └── src/
│       ├── App.tsx             # Root component — loads data, applies theme/scale
│       ├── main.tsx            # React entry point
│       ├── components/
│       │   ├── Common/         # Button, TextInput, Checkbox, Icon
│       │   ├── Menu/           # MenuBar, Menu, MenuItem, MenuSeparator
│       │   ├── MDI/            # MDIContainer, MDIWindow, MDIWindowControls
│       │   ├── Items/          # ItemGrid (with drag-drop), ProgramItem
│       │   ├── Dialogs/        # DialogManager + 9 dialog types
│       │   └── QuickSearch/    # QuickSearchOverlay
│       ├── hooks/
│       │   ├── useDraggable.ts     # Mouse-based window dragging
│       │   └── useResizable.ts     # 8-direction window resizing
│       ├── store/              # Zustand state stores
│       │   ├── programStore.ts     # Groups, items, settings, persistence
│       │   ├── mdiStore.ts         # Window z-order, open/close/focus
│       │   └── uiStore.ts         # Menus, dialogs, quick search, selection
│       ├── styles/             # Windows 3.1 CSS
│       │   ├── variables.css       # Color palette, sizing, dark mode overrides
│       │   ├── win31.css           # Base styles, bevels, buttons, inputs
│       │   ├── dialog.css          # Modal dialogs, forms, settings layout
│       │   ├── menu.css            # Menu bar and dropdowns
│       │   └── mdi.css             # MDI container, windows, item grid
│       ├── types/
│       │   └── electron.d.ts       # Window.electronAPI type declaration
│       └── utils/
│           ├── icons.ts            # 40+ built-in icon data URLs, getIconSrc()
│           └── launchGroups.ts     # Launch group options (0–8)
└── shared/             # Shared across all processes
    ├── types/index.ts      # ProgramItem, ProgramGroup, AppSettings, etc.
    └── constants/ipc.ts    # IPC channel name constants
```

## Data Model

Application state is persisted via `electron-store` in a file called `program-manager-data.json`. The structure:

- **groups**: Array of `ProgramGroup`, each containing a name, icon ID, window position/size state, and an array of `ProgramItem` entries.
- **settings**: `AppSettings` object with fields for `autoArrange`, `minimizeOnUse`, `saveSettingsOnExit`, `launchDelay` (ms), `trayOnClose`, `groupChromeScale`, and `theme` (`'light'` | `'dark'`).

Each `ProgramItem` stores a name, executable/URL path, icon reference, working directory, shortcut key, and optional launch group number.

## Tray Icons

The tray module looks for platform-specific icons under `assets/icons/`:

- `tray-macTemplate.png` (macOS — template image for dark/light mode)
- `tray-win.ico` (Windows)
- `tray-linux.png` (Linux)

If the icon file is missing or empty, a small fallback PNG is used instead.

## App Icons for Packaging

The `electron-builder.yml` expects platform-specific app icons in `resources/`:

- `icon.ico` — Windows
- `icon.icns` — macOS
- `icon.png` — Linux (recommended 512×512)

## Tech Stack

- **Electron 40** — Desktop framework
- **React 19** — UI (functional components, hooks only)
- **TypeScript 5.9** — Type safety across all three processes
- **Zustand 5** — Client-side state management
- **electron-store 8** — JSON-based persistence in the main process
- **electron-vite 5** — Build tooling with separate configs for main, preload, and renderer
- **electron-builder 26** — Cross-platform packaging (NSIS, DMG, AppImage, Flatpak)
- **Vite 7** — Renderer bundling with React plugin

## CI/CD

GitHub Actions workflows build platform-specific artifacts on manual dispatch or version tag pushes (`v*`):

| Workflow | Runner | Output |
|----------|--------|--------|
| `build-windows.yml` | `windows-latest` | `.exe` (x64, arm64) |
| `build-macos.yml` | `macos-latest` | `.dmg` (x64, arm64) — code-signed and notarized |
| `build-linux.yml` | `ubuntu-24.04` | AppImage, `.deb`, `.rpm` |
| `build-linux-arm64.yml` | `ubuntu-24.04` | `.deb`, `.rpm` (arm64) |
| `build-linux-flatpak.yml` | `ubuntu-24.04` | `.flatpak` bundle |

## Known Limitations

- The CI workflows reference `package:win`, `package:mac`, and `package:linux` npm scripts that are not defined in `package.json`. The actual scripts are `build:win`, `build:mac`, and `build:linux`. The workflows will fail unless the scripts are added or the workflow files are updated.
- Shortcut key bindings (`ProgramItem.shortcutKey`) are stored but not wired to any global or local shortcut registration at runtime.
- The `saveSettingsOnExit` flag only affects whether window position changes are persisted — all other settings are saved immediately.
- The tray menu is rebuilt when groups change, but not when individual items within groups are renamed or reordered without a full group save.

## License

MIT
