# Gosh Retro Launcher

A Windows 3.1 Program Manager clone built with Tauri and Svelte. Cross-platform app launcher for Windows, macOS, and Linux.

![Windows 3.1 Style](https://img.shields.io/badge/Style-Windows%203.1-008080)
![Tauri](https://img.shields.io/badge/Tauri-2-24C8DB)
![Svelte](https://img.shields.io/badge/Svelte-5-FF3E00)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6)

## Features

- **Authentic Windows 3.1 Look**: Recreation of the classic UI
  - 3D beveled borders and buttons
  - Teal desktop background (#008080)
  - Classic bitmap-style fonts (W95FA)
  - MDI (Multiple Document Interface) windows

- **Program Groups**: Organize your apps into draggable, resizable group windows
  - Create, rename, and delete groups
  - Drag-and-drop files to add programs
  - Double-click to launch
  - Configurable title bar scaling

- **Cross-Platform**: Works on Windows, macOS, and Linux
  - Windows: Supports `.exe`, `.lnk`, `.bat`, `.cmd`, `.msi` files
  - macOS: Supports `.app` bundles and `.sh` scripts
  - Linux: Supports `.desktop` files, `.sh` scripts, and `.AppImage`

- **System Tray**: Minimize to tray for quick access
  - Quick launch programs from tray menu
  - Double-click to restore
  - Optional minimize to tray on window close

- **Quick Search**: Global shortcut to search all programs
  - `Ctrl+Shift+Space` (Windows/Linux)
  - `Cmd+Shift+Space` (macOS)

- **Batch Launch**: Launch items with configurable delay
  - Assign items to launch groups for startup sequences
  - File > Launch All to execute

- **Import/Export**: Backup and restore your program groups

- **Appearance Options**:
  - Light and dark themes
  - Adjustable group title bar size

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

# Build for specific platforms
npm run build:win        # Windows
npm run build:mac        # macOS (Universal)
npm run build:mac-arm    # macOS (Apple Silicon)
npm run build:mac-intel  # macOS (Intel)
npm run build:linux      # Linux
```

## Development

```bash
# Start development server with hot reload
npm run dev

# Start frontend only (Vite dev server on port 5173)
npm run dev:frontend

# Type check
npm run typecheck

# Build without packaging
npm run build:frontend
```

## Architecture

```
Gosh-Retro-Launcher/
├── src/
│   ├── renderer/                    # Svelte frontend
│   │   └── src/
│   │       ├── App.svelte           # Root component
│   │       ├── main.ts              # Entry point
│   │       ├── assets/fonts/        # W95FA fonts
│   │       ├── components/
│   │       │   ├── Common/          # Button, Checkbox, TextInput, Icon
│   │       │   ├── Dialogs/         # Modal dialogs
│   │       │   ├── Items/           # Program icons & grid
│   │       │   ├── MDI/             # Window management
│   │       │   ├── Menu/            # Menu bar system
│   │       │   └── QuickSearch/     # Search overlay
│   │       ├── lib/                 # Drag/resize utilities
│   │       ├── stores/              # Svelte state (runes)
│   │       ├── styles/              # Win 3.1 CSS
│   │       └── types/               # TypeScript declarations
│   └── shared/                      # Shared types & constants
│       └── types/
├── src-tauri/                       # Rust backend (Tauri)
│   ├── src/
│   │   ├── main.rs                  # Entry point
│   │   ├── lib.rs                   # App setup, plugins, shortcuts
│   │   ├── tray.rs                  # System tray
│   │   └── commands/                # IPC handlers
│   │       ├── launch.rs            # Program execution
│   │       ├── store.rs             # Persistence
│   │       ├── file.rs              # File dialogs
│   │       ├── window.rs            # Window controls
│   │       └── system.rs            # Platform info
│   ├── icons/                       # App icons (multi-resolution)
│   └── tauri.conf.json              # Tauri configuration
└── .github/workflows/               # CI/CD pipelines
```

## Tech Stack

- **Tauri 2** - Cross-platform desktop framework (Rust)
- **Svelte 5** - UI framework with runes
- **TypeScript 5.7** - Type safety
- **Vite 7** - Build tooling

### Tauri Plugins
- `tauri-plugin-shell` - Shell execution
- `tauri-plugin-dialog` - File dialogs
- `tauri-plugin-fs` - File system access
- `tauri-plugin-store` - Persistent storage
- `tauri-plugin-global-shortcut` - Global keyboard shortcuts
- `tauri-plugin-single-instance` - Single instance enforcement
- `tauri-plugin-process` - Process management
- `tauri-plugin-opener` - URL opening

### Platform-Specific Dependencies
- Windows: `lnk` crate for parsing `.lnk` shortcuts
- Linux: `freedesktop_entry_parser` for `.desktop` files

## Settings

The application stores data in `program-manager-data.json` with the following options:

| Setting | Description | Default |
|---------|-------------|---------|
| Auto Arrange | Automatically arrange icons in groups | true |
| Minimize on Use | Minimize window after launching a program | false |
| Save Settings on Exit | Persist window positions on exit | true |
| Minimize to Tray on Close | Hide to tray instead of quitting | true |
| Launch Delay | Milliseconds between batch launches | 500 |
| Group Chrome Scale | Title bar size multiplier (1.0 - 1.6) | 1.0 |
| Theme | `light` or `dark` | light |

## License

MIT
