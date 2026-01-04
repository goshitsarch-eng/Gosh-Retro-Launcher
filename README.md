# Program Manager

A pixel-perfect Windows 3.1 Program Manager clone built with Electron and React. Cross-platform app/link launcher for Windows, macOS, and Linux.

![Windows 3.1 Style](https://img.shields.io/badge/Style-Windows%203.1-008080)
![Electron](https://img.shields.io/badge/Electron-28+-47848F)
![React](https://img.shields.io/badge/React-18-61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-3178C6)

## Features

- **Authentic Windows 3.1 Look**: Pixel-perfect recreation of the classic UI
  - 3D beveled borders and buttons
  - Teal desktop background (#008080)
  - Classic bitmap-style fonts
  - MDI (Multiple Document Interface) windows

- **Program Groups**: Organize your apps into draggable, resizable group windows
  - Create, rename, and delete groups
  - Drag-and-drop files to add programs
  - Double-click to launch

- **Cross-Platform**: Works on Windows, macOS, and Linux
  - Windows: Supports .exe, .lnk, .bat files
  - macOS: Supports .app bundles and executables
  - Linux: Supports .desktop files and shell scripts

- **System Tray**: Minimize to tray for quick access
  - Quick launch from tray menu
  - Double-click to restore

- **Quick Search**: Global shortcut to search all programs
  - `Ctrl+Shift+Space` (Windows/Linux)
  - `Cmd+Shift+Space` (macOS)

- **Batch Launch**: Launch all items in a group with configurable delay

- **Import/Export**: Backup and restore your program groups

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ElectronAppLauncher.git
cd ElectronAppLauncher

# Install dependencies
npm install

# Run in development mode
npm run dev

# Build for production
npm run build

# Package for your platform
npm run build:win    # Windows
npm run build:mac    # macOS
npm run build:linux  # Linux
```

## Development

```bash
# Start development server with hot reload
npm run dev

# Type check
npm run typecheck

# Build without packaging
npm run build
```

## Adding Icons

For the authentic Windows 3.1 look, you'll need to add:

1. **Fonts** (`assets/fonts/`):
   - Download [W95FA](https://github.com/alexpolt/W95Font) font
   - Add `W95FA.woff2` and `W95FA.woff`

2. **Icons** (`assets/icons/`):
   - `program-manager.png` - 32x32 app icon
   - `folder.png` - 32x32 group folder icon
   - `default-item.png` - 32x32 default program icon
   - `question.png` - 32x32 dialog icon
   - Tray icons for each platform

3. **App Icons** (`resources/`):
   - `icon.ico` - Windows (multi-resolution)
   - `icon.icns` - macOS
   - `icon.png` - Linux (512x512)

## Architecture

```
src/
├── main/           # Electron main process
│   ├── index.ts    # App lifecycle, window creation
│   ├── window.ts   # BrowserWindow management
│   ├── tray.ts     # System tray
│   ├── store.ts    # electron-store persistence
│   └── ipc/        # IPC handlers
├── preload/        # Context bridge
│   └── index.ts    # Secure API exposure
├── renderer/       # React application
│   └── src/
│       ├── components/
│       │   ├── Menu/       # In-app menu bar
│       │   ├── MDI/        # Window management
│       │   ├── Items/      # Program icons
│       │   ├── Dialogs/    # Modal dialogs
│       │   └── QuickSearch/
│       ├── store/          # Zustand state
│       └── styles/         # Win 3.1 CSS
└── shared/         # Shared types & constants
```

## Tech Stack

- **Electron 28+** - Cross-platform desktop framework
- **React 18** - UI library (hooks only)
- **TypeScript 5** - Type safety
- **Zustand** - State management
- **electron-store** - Persistent storage
- **electron-vite** - Build tooling
- **electron-builder** - Packaging

## License

MIT
