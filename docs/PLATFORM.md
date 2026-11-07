# Platform integration (Godot build)

Everything the Electron main process / preload used to do lives in the `Platform` autoload
(`src/app/platform.gd`) and its helpers in `src/platform/`. Shells talk only to `Platform`,
`Sounds` and `IconRegistry`.

## Known gaps versus the Electron build

| Capability | Status | Why |
|------------|--------|-----|
| **Global Quick Search hotkey** (`globalShortcut` Ctrl/Cmd+Shift+Space while the app is in the background) | **Not possible.** The shortcut works while the window is focused; from the background use the tray menu's **Quick Search** item. | Godot has no API for OS-wide hotkeys (no `RegisterHotKey`, `CGEventTap` or portal GlobalShortcuts binding). A helper process or native plugin was ruled out. |
| Hiding the window to the tray removes the taskbar button | **Minimizes instead.** The taskbar/Dock entry stays; the tray icon (or taskbar) restores it. | Godot refuses to change the visibility of the main window (`Can't change visibility of main window`) and has no skip-taskbar flag. |
| macOS tray icon adapting to dark/light menu bars | Coloured icon instead of a template image. | `StatusIndicator` cannot mark an image as a template. |
| OS file icons for arbitrary files (`app.getFileIcon`) | Real extractors for `.exe/.dll` (PE resources), `.ico`, `.icns`, `.app` bundles, `.desktop` `Icon=` via freedesktop themes, PNG/JPG/WebP/BMP/SVG/TGA. Other files (documents, `.sh`, `.msi`, GIF, XPM, JPEG-2000 icns payloads, 16-bit NE executables) get **no icon**. | Godot cannot query shell icons. |
| Display add/remove events | `display_changed` fires on DPI change and when the window moves to another screen. | Godot has no hot-plug signal. |
| Window move events | Polled for ~1 s after a window-manager drag/resize started through `Platform`. | Godot has no move signal. |
| Native file dialogs on Linux without `xdg-desktop-portal` | Falls back to Godot's own `FileDialog`. | `DisplayServer.file_dialog_show` needs the portal. |
| Notarized macOS builds | Presets sign ad-hoc; set `codesign/identity` / `notarization/*` for releases. | Needs Apple credentials. |
| AppImage and RPM packages | Not produced (tar.gz, deb, NSIS installer + zip, dmg + zip are). | Out of scope for the Godot pipeline. |
| Launcher Tools as a separate OS window | `Platform.open_launcher_tools()` emits `launcher_tools_requested` (falls back to the Settings dialog). | Up to the shell's Launcher Tools implementation. |

## Behaviour notes

* **Single instance**: loopback TCP (`SingleInstance`), port derived from the user-data directory. The second instance
  quits and the first restores and focuses its window. No lock file, so a crash never leaves stale state; a foreign
  program on the port is detected by the handshake and the next candidate port is used. Disabled for `--capture`,
  `--no-single-instance`, `PM_NO_SINGLE_INSTANCE=1` and headless runs. A second instance briefly shows a window before
  exiting (Godot creates the window before any script runs).
* **Close**: `Platform.close_window()` honours `trayOnClose`; OS close requests are routed through it
  (`auto_accept_quit` is off). Quit paths call `ProgramStore.flush()`.
* **Window**: min size 400x300 DIP, initial size `min(work area, 640x480 x scale)` of the primary display, centred;
  Win31 is borderless, Win95 uses the OS frame; switching shells flips the frame and restores the outer bounds.
  Bounds in `Platform` are physical pixels (outer rect, frame included); `work_area()` / `get_display_work_area()` are DIPs.
* **Drag and drop**: `Platform.files_dropped(files, logical_pos)`; `main.gd` forwards it to `ShellBase.on_files_dropped`.
* **Shortcuts handled by `Platform`**: Ctrl/Cmd+Shift+Space (Quick Search) and Ctrl+Alt+T (Launcher Tools), via the
  window's `window_input` (before any shell sees the key).
* **Dialogs**: `Platform.dialog_provider` (a `Callable`) overrides every file chooser, for tests and automation.
* **Sounds**: effects are rendered once into `AudioStreamWAV`s; at most 6 pooled players, released after 5 s of silence.
* **Icons**: `IconRegistry.get_icon_src()` mirrors `getIconSrc()`; http(s) icons are never fetched (default icon).
  The four legacy PNG icons in `icons.ts` were corrupt, so `tools/make_builtin_pngs.py` redraws them.

## Packaging

Presets: `export_presets.cfg` (Windows x86_64/arm64, macOS universal, Linux x86_64/arm64; PCK embedded).
Pinned toolchain: Godot **4.6.3-stable** from
`https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/`
(`Godot_v4.6.3-stable_{linux.x86_64,linux.arm64,win64.exe,macos.universal}.zip`, `Godot_v4.6.3-stable_export_templates.tpz`).
Templates install to `~/.local/share/godot/export_templates/4.6.3.stable/` (Linux),
`%APPDATA%\Godot\export_templates\4.6.3.stable\` (Windows), `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` (macOS).
Windows icon/version resources need `rcedit` (the workflow downloads it and writes the editor setting).

Workflows (`.github/workflows/`): `test.yml`, `build-linux.yml`, `build-windows.yml`, `build-macos.yml`;
tagged `v*` builds attach artifacts to the release and check that the tag equals `application/config/version`.
The workflows have not been executed (no CI access from the development sandbox).
