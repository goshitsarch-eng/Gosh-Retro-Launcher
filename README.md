# Program Manager

Program Manager is a retro desktop launcher inspired by Windows 3.1. It lets you organize apps, URLs, scripts, and folders into classic program groups, then launch them from a nostalgic app on Windows, macOS, and Linux.

Version 2.0.0 is a ground-up rewrite in **Godot 4** (GDScript). It reads the same data file as 1.x, so your groups, items, settings and backups carry over.

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

## Run

You need [Godot 4.6](https://godotengine.org/download) (the standard build; .NET is not required).

```bash
git clone https://github.com/goshitsarch-eng/Gosh-Retro-Launcher.git
cd Gosh-Retro-Launcher
godot --path .
```

You can also open `project.godot` in the Godot editor and press F5.

## Build

Export presets for Windows, macOS, and Linux are in `export_presets.cfg`. With the matching export templates installed:

```bash
godot --headless --path . --export-release "Linux x86_64" build/program-manager.x86_64
godot --headless --path . --export-release "Windows x86_64" build/program-manager.exe
godot --headless --path . --export-release "macOS" build/program-manager.zip
```

`tools/package_linux.sh` wraps the Linux export into `.tar.gz` and `.deb` packages. See [Platform integration](docs/PLATFORM.md) for CI, signing, and the pinned Godot version.

## Development

```bash
# unit tests (headless)
godot --headless --path . --script tests/run_tests.gd

# render a scenario with the real app and diff it against a committed baseline
godot --path . -- --capture=win95-start --out=artifacts/win95-start.png
python3 tests/visual/compare.py artifacts/win95-start.png tests/visual/baselines/win95-start.png
```

## Project Shape

| Path | Contents |
|------|----------|
| `src/core` | Data model, migration, store, backups, launcher, `.GRP` codec, search, UI/MDI state (autoloads `ProgramStore`, `UIState`, `MdiState`) |
| `src/toolkit` | Pixel-exact drawing: bitmap text, bevels, palette, scaling, icon registry |
| `src/shells/win31` | Windows for Workgroups shell, MDI windows, dialogs, Quick Search, Launcher Tools |
| `src/shells/win95` | Windows 95 shell: desktop, taskbar, Start, windows, folder views, Find, dialogs |
| `src/platform`, `src/app` | Tray, single instance, native dialogs, icon extraction, sounds, window management (autoload `Platform`) |
| `tests` | Unit tests and the visual regression harness |

## Documentation

1. [User Guide](docs/USER_GUIDE.md)
2. [Architecture](docs/ARCHITECTURE.md)
3. [Platform integration and known differences](docs/PLATFORM.md)
4. [Electron → Godot parity checklist](docs/PARITY.md)
5. [Windows 95 RTM source-cited audit](docs/RTM_AUDIT.md)
6. [Changelog](CHANGELOG.md)
