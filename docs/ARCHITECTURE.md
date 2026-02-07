# Architecture

This document describes the system architecture of Gosh Retro Launcher -- a cross-platform desktop application that recreates the Windows 3.1 Program Manager experience using modern web technologies inside Electron.

> All facts in this document were verified by reading source code on 2026-02-06. See the [Research Log](#research-log) at the end for the full audit trail.

## High-Level Overview

Gosh Retro Launcher is an Electron application with three process layers:

1. **Main Process** -- Node.js runtime managing window lifecycle, system tray, persistent storage, file dialogs, and program launching
2. **Preload Script** -- Security boundary that selectively exposes main-process capabilities to the renderer via `contextBridge`
3. **Renderer Process** -- React 19 application with Zustand state management and a pluggable shell/theme system

The renderer never has direct access to Node.js APIs. All cross-boundary communication uses Electron's IPC invoke/handle pattern through explicitly defined channels.

For a visual representation, see [System Architecture Diagram](diagrams/system-architecture.md).

---

## Project Structure

```
src/
  main/                          # Main process (Node.js)
    index.ts                     # Entry point: app lifecycle, global shortcuts, single-instance lock
    window.ts                    # BrowserWindow creation and management
    store.ts                     # Persistent storage via electron-store
    tray.ts                      # System tray icon and context menu
    ipc/                         # IPC handler modules
      index.ts                   # Handler registration orchestrator
      appInfoHandlers.ts         # App metadata extraction (platform-specific)
      fileHandlers.ts            # File selection dialogs
      launchHandlers.ts          # Program launching with security validation
      storeHandlers.ts           # Store CRUD with data validation
      windowHandlers.ts          # Window controls + system info
      __tests__/                 # Main process unit tests
        launchHandlers.test.ts   # 17 tests: tokenization, path validation
        storeHandlers.test.ts    # 32 tests: item/group/settings validation

  preload/
    index.ts                     # contextBridge API definition (security boundary)

  renderer/
    index.html                   # HTML entry point
    src/
      main.tsx                   # React entry point
      App.tsx                    # Root component: shell resolution, shared shortcuts, dialogs
      components/
        Common/                  # Reusable UI primitives (Button, Checkbox, TextInput, Icon)
        Dialogs/                 # Modal dialogs (Settings, Properties, About, Welcome, etc.)
        Items/                   # ItemGrid, ProgramItem components
        MDI/                     # MDI window system (Container, Window, WindowControls)
        Menu/                    # MenuBar, Menu, MenuItem, MenuSeparator
        QuickSearch/             # Quick search overlay
        ErrorBoundary.tsx        # React error boundary
      hooks/
        useAnimatedUnmount.ts    # Delayed unmount for exit animations
        useDraggable.ts          # Pointer-event-based drag handling
        useResizable.ts          # Pointer-event-based resize handling
        useSounds.ts             # Web Audio sound effect hook
      shells/                    # Pluggable UI shell system
        types.ts                 # ShellProps, ShellDefinition interfaces
        registry.ts              # Shell registration and lookup
        index.ts                 # Re-exports
        Win31Shell.tsx           # Windows 3.1 shell implementation
        win95/                   # Windows 95 shell implementation
          Win95Shell.tsx         # Shell entry point
          Win95Desktop.tsx       # Desktop area
          Win95Taskbar.tsx       # Taskbar with Start button
          Win95StartMenu.tsx     # Start menu
          Win95Window.tsx        # Win95-styled MDI window
      store/
        index.ts                 # Re-exports
        programStore.ts          # Zustand: groups, items, settings (with debounced persistence)
        uiStore.ts               # Zustand: dialogs, menus, selection, quick search
        mdiStore.ts              # Zustand: MDI window state and arrangement
      styles/                    # CSS
        variables.css            # CSS custom properties
        win31.css                # Windows 3.1 theme styles
        win95.css                # Windows 95 theme styles
        mdi.css                  # MDI window system styles
        menu.css                 # Menu system styles
        dialog.css               # Dialog styles
        animations.css           # CSS animations with prefers-reduced-motion
      types/
        electron.d.ts            # Global Window.electronAPI type declaration
      utils/
        icons.ts                 # Icon definitions and lookup
        launchGroups.ts          # Launch group utilities
        sounds.ts                # Web Audio oscillator-based sound effects
        __tests__/
          icons.test.ts          # 8 tests: icon utilities

  shared/                        # Code shared across all three processes
    constants/
      ipc.ts                     # IPC channel name constants (single source of truth)
    types/
      index.ts                   # All shared TypeScript interfaces and defaults
```

---

## Process Architecture

### Main Process

**Entry point**: `src/main/index.ts`

The main process initializes in this exact order (verified from `app.whenReady()` callback at line 32):

1. Disable native menu bar (`Menu.setApplicationMenu(null)`)
2. Initialize persistent store (`initStore()`)
3. Register all IPC handlers (`registerIpcHandlers()`)
4. Create the BrowserWindow (`createWindow()`)
5. Create system tray (`createTray()`)
6. Register global keyboard shortcuts (`registerGlobalShortcuts()`)

**Single instance enforcement**: Uses `app.requestSingleInstanceLock()`. If a second instance starts, it is immediately quit. The first instance receives a `second-instance` event and brings its window to the foreground.

**Global shortcuts**: Registers `Ctrl+Shift+Space` (or `Cmd+Shift+Space` on macOS) to toggle the Quick Search overlay. The shortcut sends the `quick-search:toggle` event to the renderer via `mainWindow.webContents.send()`.

**Lifecycle events**:
- `activate` (macOS): Re-creates window if none exist, otherwise shows existing window
- `window-all-closed`: Quits on Windows/Linux, stays alive on macOS
- `before-quit`: Sets the `isQuitting` flag so the close handler allows actual window destruction
- `will-quit`: Unregisters all global shortcuts

**Error handlers**: `process.on('uncaughtException')` and `process.on('unhandledRejection')` log errors to console to prevent process crashes.

#### Window Management (`src/main/window.ts`)

The BrowserWindow is created with:
- **Default size**: 800x600, **minimum**: 400x300
- **Background**: `#008080` (Windows 3.1 teal)
- **Show**: `false` (shown on `ready-to-show` to prevent flash)
- **Security**: `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`

Close behavior: When the user closes the window, if `settings.trayOnClose` is `true` and the app is not actually quitting, the window is hidden instead of closed (minimize-to-tray pattern).

External link handling: The `setWindowOpenHandler` intercepts all attempts to open new windows, validates http/https protocol, and opens valid URLs in the system default browser.

Dev mode: Loads from `ELECTRON_RENDERER_URL` environment variable. DevTools open only when `ELECTRON_OPEN_DEVTOOLS=1`.

#### Persistent Store (`src/main/store.ts`)

Uses the `electron-store` package (v8.1.0) with file name `program-manager-data`. The store file is a JSON document managed by electron-store in the OS-standard app data directory.

Schema:
```
{
  groups: ProgramGroup[]   // default: []
  settings: AppSettings    // default: DEFAULT_SETTINGS
}
```

Exposes eight functions: `initStore`, `getGroups`, `setGroups`, `getSettings`, `setSettings`, `getAllData`, `setAllData`, `clearStore`.

#### System Tray (`src/main/tray.ts`)

Creates a system tray icon with platform-specific icons:
- macOS: template image (`tray-macTemplate.png`) for dark/light mode
- Windows: `.ico` format
- Linux: `.png` format
- Fallback: embedded base64 PNG if asset files are missing

The tray context menu structure:
1. "Show Program Manager" -- brings window to foreground
2. Separator
3. One submenu per group (items launch programs directly from tray)
4. Separator
5. "Exit" -- calls `app.quit()`

The tray menu is rebuilt whenever groups are updated via the `updateTrayMenu()` function, called from the `store:set` handler.

Double-click on the tray icon shows the main window (Windows/Linux only; macOS uses single-click convention).

### Preload Script (`src/preload/index.ts`)

The preload script defines the complete API surface between main and renderer processes. It exposes `window.electronAPI` with six namespaces (`window`, `file`, `program`, `store`, `system`, `app`) plus an event listener system (`on`/`off`).

All IPC calls use the invoke/handle pattern (`ipcRenderer.invoke` / `ipcMain.handle`). The event listener system uses `ipcRenderer.on`/`removeListener` with an explicit whitelist (currently only `quick-search:toggle`).

The preload maintains an internal `Map<string, Map<callback, wrappedListener>>` to track event registrations and support proper cleanup.

See [API Reference](API_REFERENCE.md) for the complete API documentation.

### Renderer Process

**Entry point**: `src/renderer/src/main.tsx` renders `<App />` into the DOM.

**Root component** (`src/renderer/src/App.tsx`): Resolves the active shell component from settings, manages shared keyboard shortcuts (Enter to launch, Delete to remove), quick search toggle, theme application, and renders the dialog manager.

---

## State Management

The renderer uses three Zustand stores, each managing a distinct concern. For a visual representation of data relationships, see [Data Model Diagram](diagrams/data-model.md) and [Data Flow Diagram](diagrams/data-flow.md).

### Program Store (`src/renderer/src/store/programStore.ts`)

**State**: `groups: ProgramGroup[]`, `settings: AppSettings`, `isLoading: boolean`

**Persistence**: All mutations trigger debounced saves (300ms) to the main process via `window.electronAPI.store.set()`. Two independent timers exist -- one for groups, one for settings -- so rapid group changes don't delay settings saves and vice versa.

**Data loading**: `loadData()` calls `store.getAll()` on startup, merges received settings with `DEFAULT_SETTINGS` to handle forward-compatible settings (new fields get defaults).

**Group actions**:
- `addGroup(name)` -- creates group with UUID, `'folder'` icon, cascaded window position (offset by 30px per existing group)
- `updateGroup(id, updates)` -- partial update via spread
- `deleteGroup(id)` -- filter by ID
- `updateGroupWindowState(id, windowState)` -- partial window state update, only persists if `saveSettingsOnExit` is enabled

**Item actions**:
- `addItem(groupId, item)` -- accepts `Omit<ProgramItem, 'id'>`, generates UUID
- `updateItem(groupId, itemId, updates)` -- partial update
- `deleteItem(groupId, itemId)` -- filter by ID
- `moveItem(fromGroupId, toGroupId, itemId)` -- removes from source, appends to target

**Settings actions**:
- `updateSettings(updates)` -- partial update via spread

### UI Store (`src/renderer/src/store/uiStore.ts`)

**State**: Transient UI state that is not persisted to disk.

- `activeMenu: string | null` -- currently open menu bar dropdown
- `activeDialog: DialogType | null` -- which modal dialog is showing
- `dialogData: { groupId?, group?, item?, confirmOptions?, openItemAfterCreate?, openUrlAfterCreate?, showIconPicker? }` -- context data for the active dialog
- `quickSearchOpen: boolean` -- whether the quick search overlay is visible
- `selectedItemId: string | null` + `selectedGroupId: string | null` -- currently selected program item

**Dialog types** (from the `DialogType` union): `newGroup`, `renameGroup`, `groupProperties`, `newItem`, `newUrl`, `itemProperties`, `settings`, `about`, `confirm`, `welcome`.

### MDI Store (`src/renderer/src/store/mdiStore.ts`)

**State**: Manages the Multiple Document Interface (MDI) window system.

- `windows: MDIWindowState[]` -- open windows, each with `{ id, groupId, zIndex }`
- `activeWindowId: string | null` -- currently focused window
- `nextZIndex: number` -- monotonically increasing z-index counter

**Actions**:
- `openWindow(groupId)` -- opens new window or focuses existing one
- `closeWindow(groupId)` -- closes and selects next-most-recent window
- `focusWindow(groupId)` -- brings to front by assigning next z-index
- `setActiveWindow(groupId | null)` -- sets active without z-index change
- `cascadeWindows()` -- dispatches `CustomEvent('mdi-cascade')` for the MDI container to handle
- `tileWindows()` -- dispatches `CustomEvent('mdi-tile')`
- `arrangeIcons()` -- dispatches `CustomEvent('mdi-arrange-icons')`

Window arrangement is delegated to the MDI container component via custom DOM events, keeping layout logic in the component that owns the DOM rather than in the store.

---

## Shell/Theme System

The application supports pluggable UI shells that control the entire visual presentation. For a visual diagram, see [System Architecture Diagram](diagrams/system-architecture.md).

### Architecture

**Interface** (`src/renderer/src/shells/types.ts`):
```typescript
interface ShellDefinition {
  id: ShellType          // 'win31' | 'win95'
  name: string           // Display name for settings UI
  component: React.ComponentType<ShellProps>
}

interface ShellProps {
  platform: string       // Current OS platform
}
```

**Registry** (`src/renderer/src/shells/registry.ts`): A `Map<ShellType, ShellDefinition>` with three functions:
- `registerShell(shell)` -- adds a shell to the registry
- `getShell(id)` -- retrieves by ID
- `getAllShells()` -- returns all registered shells (used by settings dialog)

Built-in shells are registered at module load time.

### Shell Implementations

**Windows 3.1** (`Win31Shell.tsx`): The default shell. Provides a classic Program Manager look with a MenuBar, MDI container, keyboard shortcuts (Alt+F/O/W/H, Shift+F4/F5, Escape), and a shortcut hint display.

**Windows 95** (`win95/Win95Shell.tsx`): An alternative shell with a Start menu, taskbar, desktop area, and Windows 95-styled MDI windows. Split into sub-components: `Win95Desktop`, `Win95Taskbar`, `Win95StartMenu`, `Win95Window`.

### Adding a New Shell

1. Create a React component implementing `ShellProps`
2. Call `registerShell({ id, name, component })` in `src/renderer/src/shells/registry.ts`
3. Add the new shell ID to the `ShellType` union in `src/shared/types/index.ts`
4. Add the ID to the `VALID_SHELLS` array in `src/main/ipc/storeHandlers.ts` for validation

### Theme and Styling

CSS is organized into separate files per concern:
- `variables.css` -- CSS custom properties for theming
- `win31.css` / `win95.css` -- Shell-specific styles
- `mdi.css` -- MDI window system
- `menu.css` -- Menu system
- `dialog.css` -- Modal dialogs
- `animations.css` -- CSS transitions and keyframe animations

All animations respect `@media (prefers-reduced-motion: reduce)` by disabling transitions and keyframes.

---

## Build System

### electron-vite (`electron.vite.config.ts`)

The project uses [electron-vite](https://electron-vite.org/) (v5.0.0) which provides a unified Vite-based build for all three Electron targets:

| Target | Entry Point | Plugins | Path Aliases |
|---|---|---|---|
| `main` | `src/main/index.ts` | `externalizeDepsPlugin()` | `@shared` -> `src/shared` |
| `preload` | `src/preload/index.ts` | `externalizeDepsPlugin()` | `@shared` -> `src/shared` |
| `renderer` | `src/renderer/index.html` | `@vitejs/plugin-react` | `@` -> `src/renderer/src`, `@shared` -> `src/shared` |

The `externalizeDepsPlugin()` ensures Node.js dependencies are not bundled into the main/preload builds (they're available at runtime).

Build output goes to `out/` directory.

### TypeScript Configuration

The project uses TypeScript project references with three config files:

**`tsconfig.json`** -- Root config, references both sub-configs.

**`tsconfig.node.json`** -- For main process, preload, and shared code:
- Target: ESNext, Module: ESNext, Resolution: bundler
- Strict mode enabled
- Includes: `src/main/**/*`, `src/preload/**/*`, `src/shared/**/*`, `electron.vite.config.ts`

**`tsconfig.web.json`** -- For renderer and shared code:
- Target: ESNext, Libs: ESNext + DOM + DOM.Iterable
- JSX: react-jsx
- `noEmit: true` (type-checking only; Vite handles compilation)
- Includes: `src/renderer/**/*`, `src/shared/**/*`

Both sub-configs define the `@shared` alias. The web config additionally defines `@` -> `src/renderer/src`.

### NPM Scripts

| Script | Command | Purpose |
|---|---|---|
| `dev` | `electron-vite dev` | Development mode with HMR |
| `build` | `electron-vite build` | Production build to `out/` |
| `preview` | `electron-vite preview` | Preview production build |
| `build:unpack` | build + `electron-builder --dir` | Build unpacked app |
| `build:win` | build + `electron-builder --win` | Package for Windows |
| `build:mac` | build + `electron-builder --mac` | Package for macOS |
| `build:linux` | build + `electron-builder --linux` | Package for Linux |
| `typecheck` | Three sequential `tsc --noEmit` runs | Type-check all three targets |
| `test` | `vitest run` | Run test suite once |
| `test:watch` | `vitest` | Run tests in watch mode |

---

## Packaging and Distribution

### electron-builder Configuration (`electron-builder.yml`)

| Field | Value |
|---|---|
| App ID | `com.programmanager.app` |
| Product Name | `Program Manager` |
| Output Directory | `dist/` |
| Build Resources | `resources/` |
| Extra Resources | `assets/` (copied to app bundle) |

**Windows (NSIS installer)**:
- Architectures: x64, arm64
- Installer: Not one-click, allows directory change, creates desktop and Start Menu shortcuts
- Artifact naming: `${productName}-${version}-${platform}-${arch}.${ext}`

**macOS (DMG + ZIP)**:
- Architecture: universal (x64 + arm64)
- Category: `public.app-category.utilities`
- Hardened runtime enabled
- Code signing with identity and notarization enabled

**Linux (deb + rpm + tar.gz)**:
- Executable name: `program-manager`
- Category: Utility

---

## CI/CD

Two GitHub Actions workflows in `.github/workflows/`. For a visual representation, see [Deployment Diagram](diagrams/deployment.md).

### Linux Build (`.github/workflows/build-linux.yml`)

**Triggers**: `workflow_dispatch` (manual) and push to `v*` tags.

**Matrix strategy**:
| Architecture | Runner |
|---|---|
| x64 | `ubuntu-24.04` |
| arm64 | `ubuntu-24.04-arm` |

**Steps**:
1. Checkout code
2. Install system dependencies (`libappindicator3-dev`, `rpm`)
3. Setup Node.js 22
4. `npm ci`
5. `npm run typecheck`
6. `npm test`
7. Build + package (deb, rpm, tar.gz)
8. Upload artifacts (30-day retention)
9. Upload to GitHub Release (on tag pushes only)

### Windows Build (`.github/workflows/build-windows.yml`)

**Triggers**: Same as Linux (`workflow_dispatch` + `v*` tags).

**Runner**: `windows-latest`

**Steps**:
1. Checkout code
2. Setup Node.js 22
3. `npm ci`
4. `npm run typecheck`
5. `npm test`
6. Build + package (NSIS installer, x64 + arm64)
7. Upload artifacts
8. Upload to GitHub Release (on tag pushes only)

Both workflows include typecheck and test steps as quality gates before packaging.

---

## Testing

### Framework

[Vitest](https://vitest.dev/) v4.0.18, configured in `vitest.config.ts`:
- `globals: true` -- global test functions (no imports needed)
- Path alias: `@shared` -> `src/shared`

### Test Suite

**57 tests across 3 test files**, all passing (verified by running `npm test`):

| Test File | Tests | Coverage Area |
|---|---|---|
| `src/main/ipc/__tests__/launchHandlers.test.ts` | 17 | `tokenizeCommand()`: basic tokenization, quoted strings, escapes, edge cases. `isValidExecPath()`: valid paths, shell metacharacter rejection |
| `src/main/ipc/__tests__/storeHandlers.test.ts` | 32 | `isValidItem()`: valid/invalid items, missing fields. `isValidGroup()`: valid/invalid groups, nested item validation. `isValidSettings()`: all fields, enum values, optional fields, boundary values |
| `src/renderer/src/utils/__tests__/icons.test.ts` | 8 | Icon utility functions |

### Running Tests

```bash
npm test          # Single run
npm run test:watch  # Watch mode
```

### Exported Test Functions

The following functions are exported specifically for testing:
- `tokenizeCommand` and `isValidExecPath` from `src/main/ipc/launchHandlers.ts`
- `isValidItem`, `isValidGroup`, and `isValidSettings` from `src/main/ipc/storeHandlers.ts`

---

## Dependencies

### Production Dependencies (from `package.json`)

| Package | Version | Purpose |
|---|---|---|
| `electron-store` | ^8.1.0 | Persistent JSON storage in OS app data directory |
| `uuid` | ^11.0.0 | UUID v4 generation for group and item IDs |
| `zustand` | ^5.0.10 | Lightweight state management for React renderer |

### Key Development Dependencies

| Package | Version | Purpose |
|---|---|---|
| `electron` | ^40.0.0 | Desktop application framework |
| `electron-builder` | ^26.4.0 | Packaging and distribution |
| `electron-vite` | ^5.0.0 | Unified Vite build for Electron |
| `react` | ^19.2.4 | UI library |
| `react-dom` | ^19.2.4 | React DOM renderer |
| `typescript` | ^5.9.3 | Type system |
| `vite` | ^7.3.1 | Build tool and dev server |
| `vitest` | ^4.0.18 | Test framework |
| `@vitejs/plugin-react` | ^5.1.2 | React support for Vite (JSX, Fast Refresh) |

---

## Related Documentation

- [API Reference](API_REFERENCE.md) -- complete IPC bridge documentation
- [System Architecture Diagram](diagrams/system-architecture.md)
- [Data Flow Diagram](diagrams/data-flow.md)
- [Sequence Diagrams](diagrams/sequence-diagrams.md)
- [Data Model Diagram](diagrams/data-model.md)
- [Deployment Diagram](diagrams/deployment.md)

---

## Research Log

Every claim in this document was verified by reading actual source code. No information was taken from comments, READMEs, or external documentation without independent verification.

| File | Lines | What Was Verified |
|---|---|---|
| `src/main/index.ts` | 1-102 | Startup sequence order (6 steps), single instance lock, global shortcut (Ctrl/Cmd+Shift+Space), lifecycle events (activate, window-all-closed, before-quit, will-quit), error handlers |
| `src/main/window.ts` | 1-110 | BrowserWindow config (800x600, 400x300 min, teal background), security settings (contextIsolation, nodeIntegration, sandbox), tray-on-close behavior, external link protocol validation, dev mode loading |
| `src/main/store.ts` | 1-64 | electron-store usage, file name `program-manager-data`, schema (groups + settings), all 8 exported functions |
| `src/main/tray.ts` | 1-117 | Platform-specific icons (mac template, win ico, linux png), fallback base64 icon, context menu structure, double-click behavior, updateTrayMenu/destroyTray |
| `src/main/ipc/index.ts` | 1-14 | Handler registration order: window, file, store, launch, appInfo |
| `src/main/ipc/windowHandlers.ts` | 1-38 | 7 handlers including system:get-platform and system:get-version |
| `src/main/ipc/fileHandlers.ts` | 1-81 | Platform-specific file filters, dialog properties |
| `src/main/ipc/storeHandlers.ts` | 1-162 | Validation functions (isValidItem, isValidGroup, isValidSettings), VALID_THEMES/VALID_SHELLS/VALID_LABEL_DISPLAYS arrays, import/export flow |
| `src/main/ipc/launchHandlers.ts` | 1-240 | tokenizeCommand algorithm, isValidExecPath metacharacter check, platform-specific launch behavior, URL protocol validation, batch launch with delay |
| `src/main/ipc/appInfoHandlers.ts` | 1-233 | Platform-specific app info extraction (macOS .app, Windows .lnk, Linux .desktop parsing) |
| `src/preload/index.ts` | 1-112 | Complete bridge API, event listener whitelist, deduplication, type export |
| `src/shared/types/index.ts` | 1-89 | All interfaces (ProgramItem 6 fields, ProgramGroup, WindowState, AppSettings 10 fields, StoreData, AppInfo, FileFilter), ShellType, Platform, DEFAULT_SETTINGS, DEFAULT_WINDOW_STATE |
| `src/shared/constants/ipc.ts` | 1-41 | 20 IPC channel constants |
| `src/renderer/src/store/programStore.ts` | 1-196 | ProgramState interface, debounced save (300ms, two independent timers), all group/item/settings actions, UUID generation, cascaded window positioning |
| `src/renderer/src/store/uiStore.ts` | 1-81 | UIState interface, DialogType union (10 types), dialog data shape, quick search state, selection state |
| `src/renderer/src/store/mdiStore.ts` | 1-94 | MDIState interface, z-index management, custom DOM events for arrangement |
| `src/renderer/src/shells/types.ts` | 1-11 | ShellProps and ShellDefinition interfaces |
| `src/renderer/src/shells/registry.ts` | 1-31 | Map-based registry, registerShell/getShell/getAllShells, two built-in registrations |
| `src/renderer/src/types/electron.d.ts` | 1-9 | Global Window.electronAPI declaration |
| `package.json` | 1-44 | Version 1.0.5, all scripts, 3 production deps, 11 dev deps with versions |
| `electron-builder.yml` | 1-77 | App ID, all platform configs (Windows NSIS, macOS DMG+ZIP, Linux deb+rpm+tar.gz), signing config |
| `electron.vite.config.ts` | 1-53 | Three build targets (main, preload, renderer), plugins, path aliases |
| `tsconfig.json` | 1-7 | Project references to node and web configs |
| `tsconfig.node.json` | 1-27 | ESNext target, bundler resolution, strict, @shared alias, includes main+preload+shared |
| `tsconfig.web.json` | 1-28 | ESNext target, DOM libs, react-jsx, noEmit, @shared and @ aliases, includes renderer+shared |
| `vitest.config.ts` | 1-13 | Globals true, @shared alias |
| `.github/workflows/build-linux.yml` | full | Matrix (x64 ubuntu-24.04, arm64 ubuntu-24.04-arm), steps (checkout, deps, node 22, ci, typecheck, test, build, upload, release) |
| `.github/workflows/build-windows.yml` | full | Runner windows-latest, steps (checkout, node 22, ci, typecheck, test, build x64+arm64, upload, release) |
| Test run output | -- | 57 tests, 3 files, all passing (verified via `npm test`) |
