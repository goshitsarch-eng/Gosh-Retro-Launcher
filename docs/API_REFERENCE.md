# API Reference (IPC Bridge)

This document describes the complete inter-process communication (IPC) API between the Electron main process and the renderer process in Gosh Retro Launcher.

> All facts in this document were verified by reading source code on 2026-02-06. See the [Research Log](#research-log) at the end for the full audit trail.

## Overview

Gosh Retro Launcher uses Electron's `contextBridge` to expose a controlled API from the main process to the renderer. The renderer never has direct access to Node.js APIs.

**Security model** (verified in `src/main/window.ts:21-24`):

| Setting | Value |
|---|---|
| `contextIsolation` | `true` |
| `nodeIntegration` | `false` |
| `sandbox` | `true` |

The preload script (`src/preload/index.ts`) defines an `electronAPI` object and exposes it via `contextBridge.exposeInMainWorld('electronAPI', electronAPI)`. The renderer accesses it as `window.electronAPI`.

The TypeScript type `ElectronAPI` is exported from the preload module and declared globally in `src/renderer/src/types/electron.d.ts`.

For a visual overview of how IPC messages flow through the system, see [Sequence Diagrams](diagrams/sequence-diagrams.md) and [Data Flow](diagrams/data-flow.md).

---

## IPC Channel Constants

All channel names are defined in `src/shared/constants/ipc.ts` as the `IPC_CHANNELS` constant object. Both the main process handlers and the preload bridge import from this single source of truth.

| Constant | Channel String | Category |
|---|---|---|
| `WINDOW_MINIMIZE` | `window:minimize` | Window Management |
| `WINDOW_MAXIMIZE` | `window:maximize` | Window Management |
| `WINDOW_CLOSE` | `window:close` | Window Management |
| `WINDOW_QUIT` | `window:quit` | Window Management |
| `WINDOW_IS_MAXIMIZED` | `window:is-maximized` | Window Management |
| `FILE_SELECT_EXECUTABLE` | `file:select-executable` | File Operations |
| `FILE_SELECT_ICON` | `file:select-icon` | File Operations |
| `FILE_EXISTS` | `file:exists` | File Operations |
| `PROGRAM_LAUNCH` | `program:launch` | Program Management |
| `PROGRAM_LAUNCH_BATCH` | `program:launch-batch` | Program Management |
| `STORE_GET` | `store:get` | Store/Persistence |
| `STORE_SET` | `store:set` | Store/Persistence |
| `STORE_GET_ALL` | `store:get-all` | Store/Persistence |
| `STORE_IMPORT` | `store:import` | Store/Persistence |
| `STORE_EXPORT` | `store:export` | Store/Persistence |
| `SYSTEM_GET_PLATFORM` | `system:get-platform` | System |
| `SYSTEM_GET_VERSION` | `system:get-version` | System |
| `SYSTEM_OPEN_EXTERNAL` | `system:open-external` | System |
| `QUICK_SEARCH_TOGGLE` | `quick-search:toggle` | Quick Search |
| `APP_GET_INFO` | `app:get-info` | Application Info |

The type `IpcChannel` is a union of all channel string literals, derived from `IPC_CHANNELS`.

---

## Bridge API Surface

The preload bridge is organized into six namespaces plus an event listener system. Each namespace maps to one or more handler modules in `src/main/ipc/`.

### Handler Registration

All IPC handlers are registered via `registerIpcHandlers()` in `src/main/ipc/index.ts`, which calls five registration functions in order:

1. `registerWindowHandlers()` -- window management + system platform/version
2. `registerFileHandlers()` -- file selection dialogs + file existence checks
3. `registerStoreHandlers()` -- persistent data CRUD + import/export
4. `registerLaunchHandlers()` -- program launching + `system:open-external`
5. `registerAppInfoHandlers()` -- app metadata extraction

---

### `window` namespace

**Source**: `src/preload/index.ts:10-16`, handler in `src/main/ipc/windowHandlers.ts`

#### `window.minimize()`

Minimizes the main application window.

- **Parameters**: None
- **Returns**: `Promise<void>`
- **Channel**: `window:minimize`
- **Handler**: Calls `minimizeMainWindow()` from `src/main/window.ts`

#### `window.maximize()`

Toggles the main window between maximized and unmaximized states.

- **Parameters**: None
- **Returns**: `Promise<void>`
- **Channel**: `window:maximize`
- **Handler**: Calls `maximizeMainWindow()` which checks `isMaximized()` and calls either `unmaximize()` or `maximize()`

#### `window.close()`

Closes the main window. If `trayOnClose` is enabled in settings and the app is not quitting, the window is hidden to the system tray instead of actually closing.

- **Parameters**: None
- **Returns**: `Promise<void>`
- **Channel**: `window:close`
- **Handler**: Calls `closeMainWindow()` which triggers the window's `close` event. The event handler in `src/main/window.ts:34-39` checks `isQuitting` and `settings.trayOnClose` to decide whether to hide or close.

#### `window.quit()`

Fully quits the application (all windows, tray, and process).

- **Parameters**: None
- **Returns**: `Promise<void>`
- **Channel**: `window:quit`
- **Handler**: Calls `app.quit()` directly

#### `window.isMaximized()`

Returns whether the main window is currently maximized.

- **Parameters**: None
- **Returns**: `Promise<boolean>`
- **Channel**: `window:is-maximized`
- **Handler**: Returns `mainWindow?.isMaximized() ?? false`

---

### `file` namespace

**Source**: `src/preload/index.ts:19-26`, handler in `src/main/ipc/fileHandlers.ts`

#### `file.selectExecutable()`

Opens a native file dialog for selecting an executable or application file. File filters are platform-specific:

| Platform | Filters |
|---|---|
| Windows | Executables (`.exe`, `.bat`, `.cmd`, `.msi`), Shortcuts (`.lnk`), All Files |
| macOS | Applications (`.app`), All Files |
| Linux | Desktop Entries (`.desktop`), Shell Scripts (`.sh`), All Files |

- **Parameters**: None
- **Returns**: `Promise<string | null>` -- absolute file path, or `null` if canceled
- **Channel**: `file:select-executable`
- **Handler**: Opens `dialog.showOpenDialog` with platform-specific filters and `openFile` property

#### `file.selectIcon()`

Opens a native file dialog for selecting an image file to use as an icon.

Filters: Images (`.png`, `.jpg`, `.jpeg`, `.gif`, `.ico`, `.svg`), Icons (`.ico`, `.icns`), All Files.

- **Parameters**: None
- **Returns**: `Promise<string | null>` -- absolute file path, or `null` if canceled
- **Channel**: `file:select-icon`

#### `file.exists(path)`

Checks whether a file exists at the given path.

- **Parameters**: `path: string` -- absolute file path to check
- **Returns**: `Promise<boolean>` -- `true` if file exists, `false` otherwise (including on error)
- **Channel**: `file:exists`
- **Handler**: Uses `existsSync(filePath)` wrapped in try/catch

---

### `program` namespace

**Source**: `src/preload/index.ts:29-39`, handler in `src/main/ipc/launchHandlers.ts`

#### `program.launch(item)`

Launches a single program. Handles URLs, platform-specific executables, and `.desktop` files.

- **Parameters**: `item: ProgramItem` -- the program item to launch (see [Type Definitions](#type-definitions))
- **Returns**: `Promise<{ success: boolean; error?: string }>`
- **Channel**: `program:launch`

**Launch behavior by type**:

| Input | Behavior |
|---|---|
| URL (`http://` or `https://`) | Opens via `shell.openExternal()` |
| Windows `.lnk` | Resolves shortcut via `shell.readShortcutLink()`, spawns target with args |
| Windows other (`.exe`, etc.) | Opens via `shell.openPath()` |
| macOS `.app` | Spawns `open -a <path>` |
| macOS other | Spawns executable directly |
| Linux `.desktop` | Parses `[Desktop Entry]` section, extracts `Exec=` line, strips field codes (`%f`, `%u`, etc.), validates exec path, spawns |
| Linux other | Spawns executable directly |

All spawned processes are detached (`detached: true`, `stdio: 'ignore'`) and unref'd so they outlive the launcher.

**Security**: The `isValidExecPath()` function (exported for testing) rejects exec paths containing shell metacharacters: `` ; & | ` $ ( ) { } ``. This is applied to Linux `.desktop` file exec commands.

**Command tokenization**: The `tokenizeCommand()` function (exported for testing) splits command strings respecting single quotes, double quotes, and backslash escapes.

#### `program.launchBatch(items, delay)`

Launches multiple programs sequentially with a configurable delay between each.

- **Parameters**:
  - `items: ProgramItem[]` -- array of program items to launch
  - `delay: number` -- milliseconds to wait between launches
- **Returns**: `Promise<Array<{ id: string; success: boolean; error?: string }>>` -- result for each item, keyed by item `id`
- **Channel**: `program:launch-batch`
- **Handler**: Iterates items, calls `launchProgram()` for each, waits `delay` ms between launches (except after the last one)

---

### `store` namespace

**Source**: `src/preload/index.ts:42-52`, handler in `src/main/ipc/storeHandlers.ts`

The main process uses `electron-store` (file name: `program-manager-data`) for persistent JSON storage. The store schema has two top-level keys: `groups` and `settings`.

#### `store.get<T>(key)`

Retrieves a value from the persistent store.

- **Parameters**: `key: string` -- either `'groups'` or `'settings'`
- **Returns**: `Promise<T>` -- `ProgramGroup[]` for `'groups'`, `AppSettings` for `'settings'`, `null` for unknown keys
- **Channel**: `store:get`

#### `store.set<T>(key, value)`

Sets a value in the persistent store with validation.

- **Parameters**:
  - `key: string` -- either `'groups'` or `'settings'`
  - `value: T` -- the data to store
- **Returns**: `Promise<void>`
- **Channel**: `store:set`
- **Throws**: `Error('Invalid groups data')` if groups validation fails; `Error('Invalid settings data')` if settings validation fails
- **Side effects**: Setting `'groups'` triggers `updateTrayMenu()` to rebuild the system tray context menu

**Validation** (from `src/main/ipc/storeHandlers.ts:16-65`):

- `isValidItem(item)`: checks `id`, `name`, `path`, `icon` are all strings
- `isValidGroup(group)`: checks `id`, `name`, `icon` are strings, `windowState` is a non-null object, `items` is an array where every element passes `isValidItem`
- `isValidSettings(settings)`: checks all required boolean/number/string fields, validates `theme` is `'light'|'dark'`, `labelDisplay` is `'wrap'|'ellipsis'`, `shell` is optional and must be `'win31'|'win95'`, `soundEnabled` is optional boolean, `launchDelay >= 0`, `groupChromeScale > 0`

#### `store.getAll()`

Retrieves all store data (groups + settings) in one call.

- **Parameters**: None
- **Returns**: `Promise<StoreData>` -- `{ groups: ProgramGroup[], settings: AppSettings }`
- **Channel**: `store:get-all`

#### `store.exportData()`

Opens a native save dialog and exports all store data to a JSON file.

- **Parameters**: None
- **Returns**: `Promise<boolean>` -- `true` if saved successfully, `false` if canceled or failed
- **Channel**: `store:export`
- **Default filename**: `program-manager-backup.json`
- **Format**: Pretty-printed JSON (2-space indent)

#### `store.importData()`

Opens a native open dialog and imports store data from a JSON file with full validation.

- **Parameters**: None
- **Returns**: `Promise<{ success: boolean; error?: string }>`
- **Channel**: `store:import`
- **Validation**: Validates that `groups` is an array, every group passes `isValidGroup`, and settings pass `isValidSettings`
- **Side effects**: On success, replaces all store data via `setAllData()` and calls `updateTrayMenu()`
- **Error values**: `'No window'`, `'Canceled'`, `'Invalid file format'`, `'Invalid group or item data in file'`, `'Failed to read file'`

---

### `system` namespace

**Source**: `src/preload/index.ts:55-66`, handlers split across `src/main/ipc/windowHandlers.ts` (platform, version) and `src/main/ipc/launchHandlers.ts` (openExternal)

#### `system.getPlatform()`

Returns the current operating system platform.

- **Parameters**: None
- **Returns**: `Promise<'win32' | 'darwin' | 'linux'>`
- **Channel**: `system:get-platform`
- **Handler**: Returns `process.platform`

#### `system.getVersion()`

Returns the application version string.

- **Parameters**: None
- **Returns**: `Promise<string>` -- e.g., `"1.0.4"` (from `package.json` version field)
- **Channel**: `system:get-version`
- **Handler**: Returns `app.getVersion()`

#### `system.openExternal(url)`

Opens a URL in the user's default browser.

- **Parameters**: `url: string` -- the URL to open
- **Returns**: `Promise<{ success: boolean; error?: string }>`
- **Channel**: `system:open-external`
- **Security**: Validates URL via `new URL(url)` and rejects non-`http:`/`https:` protocols with error `'Only http and https URLs are allowed'`

---

### `app` namespace

**Source**: `src/preload/index.ts:70-72`, handler in `src/main/ipc/appInfoHandlers.ts`

#### `app.getInfo(filePath)`

Extracts application metadata from a file, including name, resolved path, icon (as data URL), and working directory. Behavior is platform-specific.

- **Parameters**: `filePath: string` -- path to the application file
- **Returns**: `Promise<AppInfo>` -- `{ name: string; path: string; icon?: string; workingDir?: string }`
- **Channel**: `app:get-info`

**Platform behavior**:

| Platform | File Type | Behavior |
|---|---|---|
| macOS | `.app` bundle | Extracts name from bundle name, icon via `app.getFileIcon()` |
| macOS | Other | Strips extension for name, attempts icon extraction |
| Windows | `.lnk` | Resolves via `shell.readShortcutLink()`, extracts target path, args, cwd, icon |
| Windows | `.exe`, `.bat`, `.cmd`, `.msi` | Extracts name, icon, sets `workingDir` to file's directory |
| Windows | Other | Strips extension for name, attempts icon extraction |
| Linux | `.desktop` | Parses `[Desktop Entry]` for `Name=`, `Exec=` (strips field codes), `Icon=` (loads if absolute path) |
| Linux | Other | Uses basename as name, attempts icon via `app.getFileIcon()`, sets `workingDir` |

Icons are returned as data URLs via `nativeImage.toDataURL()`. On failure, the function gracefully degrades to returning just `name` and `path`.

---

### Event Listener System

**Source**: `src/preload/index.ts:76-104`

The bridge provides `on()` and `off()` methods for subscribing to events pushed from the main process to the renderer. A whitelist controls which channels can be listened to.

#### `electronAPI.on(channel, callback)`

Registers a listener for a specific IPC channel.

- **Parameters**:
  - `channel: string` -- must be in the valid channels whitelist
  - `callback: (...args: unknown[]) => void`
- **Whitelisted channels**: `quick-search:toggle` (only channel currently allowed)
- **Deduplication**: If the same callback is already registered for the channel, the call is a no-op
- **Implementation**: Maintains an internal `Map<string, Map<callback, wrappedListener>>` to track registrations

#### `electronAPI.off(channel, callback)`

Removes a previously registered listener.

- **Parameters**:
  - `channel: string` -- must be in the valid channels whitelist
  - `callback: (...args: unknown[]) => void` -- the exact callback reference passed to `on()`
- **Behavior**: Removes the internal wrapper listener via `ipcRenderer.removeListener()` and cleans up tracking maps

#### Quick Search Toggle (Main-to-Renderer Event)

The main process sends the `quick-search:toggle` event via `mainWindow.webContents.send('quick-search:toggle')` when the global keyboard shortcut is pressed:

- **macOS**: `Cmd+Shift+Space`
- **Windows/Linux**: `Ctrl+Shift+Space`

This is registered in `src/main/index.ts:15-29`.

---

## Type Definitions

All shared types are defined in `src/shared/types/index.ts` and imported by main, preload, and renderer code.

### `ProgramItem`

```typescript
interface ProgramItem {
  id: string           // UUID v4, generated by programStore
  name: string         // Display name
  path: string         // Executable path or URL
  icon: string         // Icon identifier or data URL
  workingDir: string   // Working directory for launch
  launchGroup?: number // Optional launch group number
}
```

### `ProgramGroup`

```typescript
interface ProgramGroup {
  id: string             // UUID v4
  name: string           // Display name
  icon: string           // Icon identifier (default: 'folder')
  windowState: WindowState
  items: ProgramItem[]
}
```

### `WindowState`

```typescript
interface WindowState {
  x: number          // Window X position (default: 20)
  y: number          // Window Y position (default: 20)
  width: number      // Window width (default: 300)
  height: number     // Window height (default: 200)
  minimized: boolean // Whether minimized (default: false)
  maximized: boolean // Whether maximized (default: false)
}
```

### `AppSettings`

```typescript
interface AppSettings {
  autoArrange: boolean       // Auto-arrange items in grid (default: true)
  minimizeOnUse: boolean     // Minimize window after launching (default: false)
  saveSettingsOnExit: boolean // Persist window positions (default: true)
  launchDelay: number        // ms delay between batch launches (default: 500)
  trayOnClose: boolean       // Minimize to tray on close (default: true)
  groupChromeScale: number   // MDI window chrome scale factor (default: 1)
  theme: 'light' | 'dark'   // Color theme (default: 'light')
  labelDisplay: 'wrap' | 'ellipsis' // Item label overflow (default: 'wrap')
  shell: ShellType           // UI shell theme (default: 'win31')
  soundEnabled: boolean      // UI sound effects (default: true)
}
```

### `StoreData`

```typescript
interface StoreData {
  groups: ProgramGroup[]
  settings: AppSettings
}
```

### `AppInfo`

```typescript
interface AppInfo {
  name: string         // Extracted application name
  path: string         // Resolved executable path
  icon?: string        // Data URL of extracted icon
  workingDir?: string  // Resolved working directory
}
```

### `ShellType`

```typescript
type ShellType = 'win31' | 'win95'
```

### `Platform`

```typescript
type Platform = 'win32' | 'darwin' | 'linux'
```

### `FileFilter`

```typescript
interface FileFilter {
  name: string
  extensions: string[]
}
```

---

## Error Handling

### IPC Error Propagation

All IPC handlers use `ipcMain.handle()` (invoke/handle pattern). Errors propagate as follows:

1. **Handler throws**: The error is serialized and delivered as a rejected promise to the renderer's `ipcRenderer.invoke()` call.
2. **Structured errors**: Most handlers return result objects like `{ success: boolean; error?: string }` rather than throwing, allowing the renderer to handle failures gracefully.
3. **Validation errors**: `store:set` throws `Error('Invalid groups data')` or `Error('Invalid settings data')` on validation failure.

### Main Process Error Handlers

Registered in `src/main/index.ts:7-13`:

```
process.on('uncaughtException', (error) => { console.error(...) })
process.on('unhandledRejection', (reason) => { console.error(...) })
```

These prevent the process from crashing on unhandled errors but only log to console.

---

## Security Considerations

### Exec Path Validation

`isValidExecPath()` in `src/main/ipc/launchHandlers.ts:53-59` rejects command strings containing shell metacharacters (`` ; & | ` $ ( ) { } ``). This prevents shell injection when launching programs parsed from `.desktop` files.

### Command Tokenization

`tokenizeCommand()` in `src/main/ipc/launchHandlers.ts:8-50` safely tokenizes command strings by respecting single quotes, double quotes, and backslash escape sequences. Arguments are passed as an array to `spawn()`, never concatenated into a shell command.

### URL Protocol Validation

Both `system.openExternal()` (in `launchHandlers.ts:228-239`) and the window open handler (in `window.ts:43-53`) validate that URLs use only `http:` or `https:` protocols before passing them to `shell.openExternal()`.

### Preload Event Whitelist

The `on()`/`off()` event system in the preload bridge only allows listening to channels in an explicit whitelist (currently only `quick-search:toggle`). This prevents the renderer from subscribing to arbitrary IPC channels.

### Process Isolation

The BrowserWindow is created with `contextIsolation: true`, `nodeIntegration: false`, and `sandbox: true`, ensuring the renderer has zero direct access to Node.js or Electron internals.

---

## Related Documentation

- [Architecture](ARCHITECTURE.md) -- system design and component overview
- [System Architecture Diagram](diagrams/system-architecture.md)
- [Data Flow Diagram](diagrams/data-flow.md)
- [Sequence Diagrams](diagrams/sequence-diagrams.md)
- [Data Model Diagram](diagrams/data-model.md)

---

## Research Log

Every claim in this document was verified by reading actual source code. No information was taken from comments, READMEs, or external documentation without independent verification.

| File | Lines | What Was Verified |
|---|---|---|
| `src/shared/constants/ipc.ts` | 1-41 | All 20 IPC channel constants and their string values |
| `src/preload/index.ts` | 1-112 | Complete bridge API: 6 namespaces, all method signatures, return types, event listener system with whitelist |
| `src/main/ipc/index.ts` | 1-14 | Handler registration order: window, file, store, launch, appInfo |
| `src/main/ipc/windowHandlers.ts` | 1-38 | 7 handlers: minimize, maximize, close, quit, isMaximized, getPlatform, getVersion |
| `src/main/ipc/fileHandlers.ts` | 1-81 | 3 handlers: selectExecutable (platform-specific filters), selectIcon (image filters), exists (existsSync) |
| `src/main/ipc/storeHandlers.ts` | 1-162 | 5 handlers: get (switch on key), set (with validation + tray update), getAll, export (save dialog + JSON write), import (open dialog + full validation) |
| `src/main/ipc/launchHandlers.ts` | 1-240 | 3 handlers: launch (platform-specific), launchBatch (sequential with delay), openExternal (URL protocol validation). Plus tokenizeCommand and isValidExecPath security functions |
| `src/main/ipc/appInfoHandlers.ts` | 1-233 | 1 handler: getInfo with platform-specific extraction (macOS .app, Windows .lnk/.exe, Linux .desktop parsing) |
| `src/main/window.ts` | 1-110 | BrowserWindow config: 800x600, security settings (contextIsolation, sandbox), tray-on-close behavior, external link protocol validation |
| `src/main/index.ts` | 1-102 | Startup sequence, global shortcut registration (Ctrl/Cmd+Shift+Space), single instance lock, error handlers |
| `src/shared/types/index.ts` | 1-89 | All type definitions: ProgramItem (6 fields), ProgramGroup, WindowState, AppSettings (10 fields), StoreData, AppInfo, FileFilter, ShellType, Platform, defaults |
| `src/renderer/src/types/electron.d.ts` | 1-9 | Global Window.electronAPI type declaration importing ElectronAPI from preload |
