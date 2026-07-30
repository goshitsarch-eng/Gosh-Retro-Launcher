# Program Manager

Program Manager is a retro desktop launcher inspired by Windows 3.1. It lets you organize apps, URLs, scripts, and folders into classic program groups, then launch them from a nostalgic Electron app on Windows, macOS, and Linux.

Version 1.0.6 is shown in the app About dialog and comes from `package.json`.

## What It Does

1. Switch between an isolated WfW 3.11 Program Manager and a Windows 95 RTM-style launcher desktop.
2. Launch through the canonical Windows 95 path: **Start → Programs → group → app**, or open groups from My Computer.
3. Scale either shell crisply at independent Auto/1×/2×/3×/4× integer factors on modern displays.
4. Create program groups and fill them with apps, links, scripts, or files.
5. Drag files into a group window to add them quickly.
6. Launch items from the desktop, Find, Run, or the system tray.
7. Batch launch numbered groups from 1 to 8 with a delay you control.
8. Import and export original Windows 3.x `.GRP` files.
9. Save named workspace profiles with independent Win31 and Win95 layouts.
10. Configure arguments, environment variables, working directories, run modes, and shortcut keys.
11. Use the separate Launcher Tools window for URLs, batch metadata, profiles, shell switching, scale options, and JSON transfer.
12. Recover from automatic versioned backups or create manual restore points.
13. Optionally place Program Manager on a gray WfW desktop and minimize it to its classic desktop icon.
14. Use RTM-style multi-selection, marquee selection, all four folder views, deterministic scrollbars, task/system/context menus, and outline move/size in Windows 95.

## Install And Run

You need Node.js 22 or newer.

```bash
git clone https://github.com/goshitsarch-eng/Gosh-Retro-Launcher.git
cd Gosh-Retro-Launcher
npm install
npm run dev
```

## Build

```bash
npm run build
npm run build:win
npm run build:mac
npm run build:linux
```

`npm run build` compiles the app. The platform commands create installer packages for Windows, macOS, and Linux.

## Development

```bash
npm run dev
npm run typecheck
npm test
npm run test:watch
npm run test:visual
```

To open DevTools during development, run:

```bash
ELECTRON_OPEN_DEVTOOLS=1 npm run dev
```

## Project Shape

The Electron main process lives in `src/main`. It owns the app window, tray menu, storage, file dialogs, and launch behavior.

The preload script lives in `src/preload`. It exposes a typed, limited API to the renderer through Electron context isolation.

The React app lives in `src/renderer`. It renders the retro shells, dialogs, menus, quick search, program groups, icons, and settings. The Windows 95 implementation owns its input controller, primary-window store, bitmap text, list view, controls, and clean-room icon catalog; it does not import Win31 presentation primitives.

Shared types and IPC channel names live in `src/shared`.

## Documentation

1. [User Guide](docs/USER_GUIDE.md)
2. [Architecture](docs/ARCHITECTURE.md)
3. [API Reference](docs/API_REFERENCE.md)
4. [Windows 95 RTM source-cited audit](src/renderer/src/shells/win95/RTM_AUDIT.md)
5. [Changelog](CHANGELOG.md)
6. [System Architecture Diagram](docs/diagrams/system-architecture.md)
7. [User Flows](docs/diagrams/user-flows.md)
8. [Data Flow](docs/diagrams/data-flow.md)

## Notes

Settings are saved automatically. Window positions are saved when that option is enabled. Automatic restore points are retained under the app user-data directory, with the newest 12 backups kept.

Open **Launcher Tools...** from the tray or press **Ctrl+Alt+T** in either shell to switch shells and manage modern launcher features. Windows 95 also exposes it under **Start → Settings → Launcher Tools...**.

The Windows 95 target is original US-English retail RTM at a canonical 640×480/96-DPI logical grid—not OSR2, Plus!, an IE-integrated shell, or Windows 98. Built-in icons and fonts are independently recreated and project-owned. My Computer maps to launcher groups; Find searches launcher metadata; Shut Down affects only the launcher; networking, recycling, Control Panel, printers, date metadata, and operating-system actions are not fabricated.

## License

This project is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
