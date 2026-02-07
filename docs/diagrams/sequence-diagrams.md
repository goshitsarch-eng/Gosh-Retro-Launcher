# Sequence Diagrams

Critical interactions traced through actual code paths, showing the exact function calls and IPC channels used.

## App Startup Sequence

```mermaid
sequenceDiagram
    participant OS as Operating System
    participant Main as Main Process<br/>(index.ts)
    participant Store as electron-store<br/>(store.ts)
    participant Win as BrowserWindow<br/>(window.ts)
    participant Tray as System Tray<br/>(tray.ts)
    participant Preload as Preload Script
    participant Renderer as Renderer<br/>(App.tsx)
    participant ZStore as Zustand Stores

    Main->>Main: requestSingleInstanceLock()
    alt Lock not acquired
        Main->>OS: app.quit()
    end

    Main->>Main: process.on('uncaughtException')
    Main->>Main: process.on('unhandledRejection')

    OS->>Main: app.whenReady()
    Main->>Main: Menu.setApplicationMenu(null)

    Main->>Store: initStore()
    Store->>Store: new Store({name: 'program-manager-data',<br/>defaults: {groups: [], settings: DEFAULT_SETTINGS}})
    Store-->>Main: Store instance ready

    Main->>Main: registerIpcHandlers()
    Note over Main: Registers 5 handler modules:<br/>window, file, store, launch, appInfo

    Main->>Win: createWindow()
    Win->>Win: new BrowserWindow({800x600,<br/>contextIsolation:true,<br/>nodeIntegration:false, sandbox:true})
    Win->>Win: on('close') -> hide if trayOnClose
    Win->>Win: webContents.setWindowOpenHandler (http/https only)

    alt Development
        Win->>Win: loadURL(ELECTRON_RENDERER_URL)
    else Production
        Win->>Win: loadFile('../renderer/index.html')
    end

    Main->>Tray: createTray()
    Tray->>Tray: Platform-specific icon selection
    Tray->>Store: getGroups()
    Tray->>Tray: Build menu with group submenus

    Main->>Main: registerGlobalShortcuts()
    Note over Main: Ctrl/Cmd+Shift+Space -> quick-search:toggle

    Win-->>Preload: Window loads preload script
    Preload->>Preload: contextBridge.exposeInMainWorld('electronAPI', ...)

    Win->>Win: ready-to-show -> show()

    Preload-->>Renderer: window.electronAPI available
    Renderer->>ZStore: loadData()
    ZStore->>Preload: window.electronAPI.store.getAll()
    Preload->>Main: ipcRenderer.invoke('store:get-all')
    Main->>Store: getAllData()
    Store-->>Main: {groups, settings}
    Main-->>Preload: StoreData
    Preload-->>ZStore: {groups, settings}
    ZStore->>ZStore: set({groups, settings: {...DEFAULT_SETTINGS, ...data.settings}, isLoading: false})

    Renderer->>Renderer: setTimeout(300ms)
    Renderer->>Renderer: sounds.startupChime()

    Renderer->>Preload: window.electronAPI.system.getPlatform()
    Preload->>Main: ipcRenderer.invoke('system:get-platform')
    Main-->>Renderer: 'linux' | 'darwin' | 'win32'

    alt First run (no localStorage 'hasLaunched')
        Renderer->>Renderer: localStorage.setItem('hasLaunched', 'true')
        Renderer->>ZStore: openDialog('welcome')
    end

    Renderer->>Renderer: getShell(settings.shell)<br/>Render ShellComponent
```

## IPC Communication Pattern

All renderer-to-main communication uses the invoke/handle pattern through the preload bridge.

```mermaid
sequenceDiagram
    participant RC as Renderer Component
    participant API as window.electronAPI<br/>(preload bridge)
    participant IPC as ipcRenderer
    participant Main as ipcMain.handle()
    participant Handler as Handler Function

    RC->>API: electronAPI.namespace.method(args)
    API->>IPC: ipcRenderer.invoke(channel, ...args)
    IPC->>Main: IPC message via channel
    Main->>Handler: Handler receives (event, ...args)
    Handler->>Handler: Process request
    Handler-->>Main: Return value
    Main-->>IPC: Response
    IPC-->>API: Promise resolves
    API-->>RC: Typed result
```

The one exception is the main-to-renderer push for quick search:

```mermaid
sequenceDiagram
    participant GS as globalShortcut<br/>(main process)
    participant WC as mainWindow.webContents
    participant IPC as ipcRenderer
    participant PL as Preload (on/off)
    participant App as App.tsx

    GS->>GS: Ctrl/Cmd+Shift+Space pressed
    GS->>WC: webContents.send('quick-search:toggle')
    WC->>IPC: IPC message
    IPC->>PL: ipcRenderer.on('quick-search:toggle')
    PL->>App: callback()
    App->>App: toggleQuickSearch()
```

## Program Launch Flow (Full Sequence)

```mermaid
sequenceDiagram
    participant User
    participant UI as Renderer UI
    participant PS as programStore
    participant API as window.electronAPI
    participant PL as Preload
    participant LH as launchHandlers.ts
    participant OS as Operating System

    User->>UI: Double-click item / Enter key
    UI->>PS: Find item by selectedItemId + selectedGroupId
    PS-->>UI: ProgramItem {id, name, path, icon, workingDir}

    UI->>API: electronAPI.program.launch(item)
    API->>PL: ipcRenderer.invoke('program:launch', item)
    PL->>LH: launchProgram(item)

    alt URL (http/https)
        LH->>OS: shell.openExternal(url)
        OS-->>LH: success
    else Windows + .lnk
        LH->>OS: shell.readShortcutLink(path)
        OS-->>LH: {target, args, cwd}
        LH->>LH: tokenizeCommand(args)
        LH->>OS: spawn(target, args, {cwd, detached:true})
    else Windows + other
        LH->>OS: shell.openPath(path)
    else macOS + .app
        LH->>OS: spawn('open', ['-a', path], {detached:true})
    else macOS + other
        LH->>OS: spawn(path, [], {cwd, detached:true})
    else Linux + .desktop
        LH->>LH: parseDesktopFile(path)
        LH->>LH: tokenizeCommand(exec)
        LH->>LH: isValidExecPath(cmd)
        alt Valid
            LH->>OS: spawn(cmd, args, {cwd, detached:true})
        else Invalid
            LH-->>PL: {success:false, error:'Invalid Exec'}
        end
    else Linux + other
        LH->>OS: spawn(path, [], {cwd, detached:true})
    end

    LH-->>PL: {success: boolean, error?: string}
    PL-->>API: Result
    API-->>UI: Result

    alt success && settings.minimizeOnUse
        UI->>API: electronAPI.window.minimize()
    end
```

## Store Persistence Sequence (Debounced Write)

```mermaid
sequenceDiagram
    participant Action as Store Action<br/>(e.g. addItem)
    participant Zustand as Zustand State
    participant Debounce as Debounce Timer<br/>(300ms)
    participant API as window.electronAPI
    participant PL as Preload
    participant SH as storeHandlers.ts
    participant Store as electron-store
    participant Disk as JSON File
    participant Tray as Tray Menu

    Action->>Zustand: set({groups: [...groups, newItem]})
    Note over Zustand: UI updates immediately

    Action->>Debounce: debouncedSaveGroups()

    alt Timer already pending
        Debounce->>Debounce: clearTimeout(existing)
    end

    Debounce->>Debounce: setTimeout(300ms)
    Note over Debounce: Batches rapid changes

    Debounce->>Zustand: get().groups (after 300ms)
    Zustand-->>Debounce: Current groups array

    Debounce->>API: electronAPI.store.set('groups', groups)
    API->>PL: ipcRenderer.invoke('store:set', 'groups', groups)
    PL->>SH: handle('store:set')

    SH->>SH: Validate: Array.isArray(value)
    SH->>SH: Validate: value.every(isValidGroup)

    alt Valid
        SH->>Store: setGroups(value)
        Store->>Disk: Write program-manager-data.json
        SH->>Tray: updateTrayMenu()
        Tray->>Store: getGroups()
        Tray->>Tray: Rebuild context menu
    else Invalid
        SH-->>PL: throw Error('Invalid groups data')
    end
```

## Settings Sync Sequence

```mermaid
sequenceDiagram
    participant User
    participant Dialog as SettingsDialog
    participant PS as programStore
    participant Debounce as Debounce Timer
    participant API as window.electronAPI
    participant SH as storeHandlers.ts
    participant Store as electron-store
    participant App as App.tsx
    participant Shell as Shell Component

    User->>Dialog: Change setting (e.g. theme: 'dark')
    Dialog->>PS: updateSettings({theme: 'dark'})
    PS->>PS: set({settings: {...settings, theme: 'dark'}})
    Note over PS: State updates immediately

    PS->>Debounce: debouncedSaveSettings()
    Debounce->>Debounce: setTimeout(300ms)

    par UI reacts to state change
        App->>App: useEffect: document.documentElement<br/>.classList.toggle('theme-dark', true)
    and Settings persist after debounce
        Debounce->>API: electronAPI.store.set('settings', settings)
        API->>SH: invoke('store:set', 'settings', value)
        SH->>SH: isValidSettings(value)
        SH->>Store: setSettings(value)
    end

    User->>Dialog: Change shell to 'win95'
    Dialog->>PS: updateSettings({shell: 'win95'})
    PS->>PS: set({settings: {...settings, shell: 'win95'}})

    App->>App: getShell('win95')
    App->>Shell: Render Win95Shell instead of Win31Shell
    Note over Shell: Complete UI swap:<br/>Desktop + Taskbar + StartMenu
```

## Import Data Sequence

```mermaid
sequenceDiagram
    participant User
    participant Menu as Menu (File > Import)
    participant API as window.electronAPI
    participant PL as Preload
    participant SH as storeHandlers.ts
    participant Dialog as Electron dialog
    participant FS as File System
    participant Store as electron-store
    participant Tray as Tray
    participant PS as programStore

    User->>Menu: File > Import Settings
    Menu->>API: electronAPI.store.importData()
    API->>PL: ipcRenderer.invoke('store:import')
    PL->>SH: handle('store:import')

    SH->>Dialog: dialog.showOpenDialog({<br/>filter: JSON, openFile})
    Dialog-->>User: File picker
    User->>Dialog: Select file
    Dialog-->>SH: filePath

    SH->>FS: readFile(filePath, 'utf-8')
    FS-->>SH: JSON string

    SH->>SH: JSON.parse(content)

    SH->>SH: Validate: Array.isArray(data.groups)
    SH->>SH: Validate: isValidSettings(data.settings)
    SH->>SH: Validate: data.groups.every(isValidGroup)

    alt All valid
        SH->>Store: setAllData(data)
        Store->>Store: set('groups', data.groups)
        Store->>Store: set('settings', data.settings)
        SH->>Tray: updateTrayMenu()
        SH-->>PL: {success: true}
        PL-->>API: {success: true}
        API-->>Menu: Success
        Note over PS: Renderer must call loadData()<br/>to pick up imported data
    else Validation fails
        SH-->>PL: {success: false, error: 'reason'}
        PL-->>API: Error result
    end
```

## Second Instance Handling

```mermaid
sequenceDiagram
    participant User as User (launches 2nd instance)
    participant New as New Instance
    participant Lock as Single Instance Lock
    participant Existing as Existing Instance
    participant Win as Main Window

    User->>New: Launch app
    New->>Lock: requestSingleInstanceLock()
    Lock-->>New: false (lock held)
    New->>New: app.quit()

    Lock->>Existing: 'second-instance' event
    Existing->>Win: getMainWindow()

    alt Window minimized
        Existing->>Win: mainWindow.restore()
    end

    Existing->>Win: mainWindow.show()
    Existing->>Win: mainWindow.focus()
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `src/main/index.ts` | Full startup sequence: requestSingleInstanceLock -> uncaughtException/unhandledRejection handlers -> app.whenReady (setApplicationMenu(null), initStore, registerIpcHandlers, createWindow, createTray, registerGlobalShortcuts) -> activate handler -> window-all-closed -> before-quit -> will-quit -> second-instance handler |
| `src/main/store.ts` | electron-store initialization: name='program-manager-data', defaults, getAllData returns {groups, settings} |
| `src/main/window.ts` | BrowserWindow creation: 800x600, security flags, close handler (trayOnClose check), dev/prod URL loading, ready-to-show -> show(), window open handler (http/https only) |
| `src/main/tray.ts` | Tray creation: platform icon selection, buildTrayMenu from getGroups(), double-click handler, updateTrayMenu called from storeHandlers |
| `src/main/ipc/index.ts` | 5 handler modules registered in order |
| `src/main/ipc/windowHandlers.ts` | invoke handlers for window:minimize/maximize/close/quit/is-maximized + system:get-platform + system:get-version |
| `src/main/ipc/launchHandlers.ts` | launchProgram: URL check -> platform switch (win32 .lnk/other, darwin .app/other, linux .desktop/other), tokenizeCommand, isValidExecPath, parseDesktopFile, spawnDetached({detached:true, stdio:'ignore'}), batch launch with delay loop, system:open-external with URL protocol validation |
| `src/main/ipc/storeHandlers.ts` | store:get (switch on key), store:set (validate then persist + updateTrayMenu for groups), store:get-all (getAllData), store:export (showSaveDialog + writeFile), store:import (showOpenDialog + readFile + parse + 3-stage validation + setAllData + updateTrayMenu) |
| `src/preload/index.ts` | contextBridge with 6 namespaces, invoke pattern for all channels, on/off with whitelist [quick-search:toggle], ipcListenerMap for cleanup |
| `src/renderer/src/App.tsx` | loadData on mount -> startupChime after 300ms, getPlatform, first-run localStorage check, quick-search:toggle IPC listener, shared keyboard shortcuts, shell resolution via getShell, theme CSS class toggle |
| `src/renderer/src/store/programStore.ts` | All actions: debounced save functions (300ms clearTimeout+setTimeout pattern), loadData merges with DEFAULT_SETTINGS, addGroup calculates window offset, addItem generates UUID, all mutations call debouncedSaveGroups/debouncedSaveSettings |
| `src/renderer/src/store/uiStore.ts` | Quick search toggle, dialog open/close, menu state, selection state |
| `src/renderer/src/store/mdiStore.ts` | Window z-index management with nextZIndex++, CustomEvent dispatch for cascade/tile/arrange |
