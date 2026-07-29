# Program Manager

Program Manager is a retro desktop launcher inspired by Windows 3.1. It lets you organize apps, URLs, scripts, and folders into classic program groups, then launch them from a nostalgic Electron app on Windows, macOS, and Linux.

Version 1.0.6 is shown in the app About dialog and comes from `package.json`.

## What It Does

1. Switch between Windows 3.1 and Windows 95 style desktops.
2. Create program groups and fill them with apps, links, scripts, or files.
3. Drag files into a group window to add them quickly.
4. Launch items from the desktop, quick search, or the system tray.
5. Batch launch numbered groups from 1 to 8 with a delay you control.
6. Import and export original Windows 3.x `.GRP` files.
7. Save named workspace profiles with independent Win31 and Win95 layouts.
8. Configure PIF-style arguments, environment variables, working directories, run modes, and shortcut keys.
9. Use the separate Launcher Tools window for URLs, batch metadata, profiles, shell options, and JSON transfer.
10. Recover from automatic versioned backups or create manual restore points.
11. Optionally place Program Manager on a gray WfW desktop and minimize it to its classic desktop icon.

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

The React app lives in `src/renderer`. It renders the retro shells, dialogs, menus, quick search, program groups, icons, and settings.

Shared types and IPC channel names live in `src/shared`.

## Documentation

1. [User Guide](docs/USER_GUIDE.md)
2. [Architecture](docs/ARCHITECTURE.md)
3. [API Reference](docs/API_REFERENCE.md)
4. [Changelog](CHANGELOG.md)
5. [System Architecture Diagram](docs/diagrams/system-architecture.md)
6. [User Flows](docs/diagrams/user-flows.md)
7. [Data Flow](docs/diagrams/data-flow.md)

## Notes

Settings are saved automatically. Window positions are saved when that option is enabled. Automatic restore points are retained under the app user-data directory, with the newest 12 backups kept.

Use **Launcher Tools...** from the tray for modern management features. The canonical WfW Program Manager menus intentionally contain only period-appropriate commands.

## License

This project is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
