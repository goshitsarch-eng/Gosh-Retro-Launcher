# Data Flow Diagrams

Request/response flows for key operations, traced through actual code paths.

## Program Launch Flow

When a user launches a program (double-click, Enter key, quick search, or tray menu):

```mermaid
flowchart TD
    A["User Action<br/>(double-click / Enter / QuickSearch / Tray)"] --> B{Source?}

    B -->|"Renderer"| C["window.electronAPI.program.launch(item)"]
    B -->|"Tray"| D["tray.ts: launchItem() -> launchProgram(item)"]

    C --> E["preload: ipcRenderer.invoke('program:launch', item)"]
    E --> F["launchHandlers.ts: launchProgram(item)"]
    D --> F

    F --> G{"item.path starts with<br/>http:// or https://?"}
    G -->|Yes| H["shell.openExternal(url)"]
    G -->|No| I{"process.platform?"}

    I -->|"win32"| J{".lnk file?"}
    J -->|Yes| K["shell.readShortcutLink()<br/>tokenizeCommand(args)<br/>spawnDetached(target, args)"]
    J -->|No| L["shell.openPath(programPath)"]

    I -->|"darwin"| M{".app bundle?"}
    M -->|Yes| N["spawnDetached('open', ['-a', path])"]
    M -->|No| O["spawnDetached(path, [])"]

    I -->|"linux"| P{".desktop file?"}
    P -->|Yes| Q["parseDesktopFile(path)<br/>tokenizeCommand(exec)<br/>isValidExecPath(cmd)"]
    Q --> R{"Valid exec?"}
    R -->|Yes| S["spawnDetached(cmd, args)"]
    R -->|No| T["Return error"]
    P -->|No| U["spawnDetached(path, [])"]

    H --> V["Return {success, error?}"]
    K --> V
    L --> V
    N --> V
    O --> V
    S --> V
    T --> V
    U --> V

    V --> W{"Renderer: settings.minimizeOnUse?"}
    W -->|Yes| X["window.electronAPI.window.minimize()"]
    W -->|No| Y["Done"]
    X --> Y
```

## Batch Launch Flow

When launching a group of items with delay:

```mermaid
flowchart TD
    A["User triggers batch launch"] --> B["window.electronAPI.program.launchBatch(items, delay)"]
    B --> C["preload: ipcRenderer.invoke('program:launch-batch', items, delay)"]
    C --> D["launchHandlers: iterate items"]

    D --> E["For each item i = 0..n"]
    E --> F["launchProgram(items[i])"]
    F --> G["Collect result: {id, success, error?}"]
    G --> H{"i < items.length - 1<br/>AND delay > 0?"}
    H -->|Yes| I["await setTimeout(delay)"]
    I --> E
    H -->|No| J["Return all results array"]
```

## Add / Edit Item Flow

When creating or editing a program item via the ItemPropertiesDialog:

```mermaid
flowchart TD
    A["User opens dialog<br/>(File > New or Properties)"] --> B["uiStore.openDialog('newItem' | 'itemProperties',<br/>{groupId, item?})"]
    B --> C["DialogManager renders<br/>ItemPropertiesDialog"]

    C --> D{"Browse for executable?"}
    D -->|Yes| E["window.electronAPI.file.selectExecutable()"]
    E --> F["fileHandlers: dialog.showOpenDialog()<br/>with platform-specific filters"]
    F --> G["Return selected path or null"]
    G --> H["App info extraction:<br/>window.electronAPI.app.getInfo(path)"]
    H --> I["appInfoHandlers: platform-specific extraction<br/>(icon, name, workingDir)"]

    D -->|No| J["User fills form manually"]

    I --> J
    J --> K["User clicks OK"]

    K --> L{"New item or edit?"}
    L -->|"New"| M["programStore.addItem(groupId, itemData)"]
    L -->|"Edit"| N["programStore.updateItem(groupId, itemId, updates)"]

    M --> O["Generate uuid for new item<br/>Update groups in Zustand state"]
    N --> P["Merge updates into existing item<br/>Update groups in Zustand state"]

    O --> Q["debouncedSaveGroups (300ms)"]
    P --> Q

    Q --> R["window.electronAPI.store.set('groups', groups)"]
    R --> S["preload: ipcRenderer.invoke('store:set', 'groups', value)"]
    S --> T["storeHandlers: validate with isValidGroup()"]
    T --> U["store.set('groups', groups)"]
    U --> V["electron-store writes to<br/>program-manager-data.json"]
    T --> W["updateTrayMenu()"]
```

## Import / Export Flow

### Export

```mermaid
flowchart TD
    A["User: File > Export Settings"] --> B["window.electronAPI.store.exportData()"]
    B --> C["preload: ipcRenderer.invoke('store:export')"]
    C --> D["storeHandlers: dialog.showSaveDialog()<br/>defaultPath: 'program-manager-backup.json'<br/>filter: JSON files"]
    D --> E{"User canceled?"}
    E -->|Yes| F["Return false"]
    E -->|No| G["getAllData() from electron-store"]
    G --> H["JSON.stringify(data, null, 2)"]
    H --> I["writeFile(filePath, json, 'utf-8')"]
    I --> J["Return true"]
```

### Import

```mermaid
flowchart TD
    A["User: File > Import Settings"] --> B["window.electronAPI.store.importData()"]
    B --> C["preload: ipcRenderer.invoke('store:import')"]
    C --> D["storeHandlers: dialog.showOpenDialog()<br/>filter: JSON files, openFile"]
    D --> E{"User canceled?"}
    E -->|Yes| F["Return {success:false, error:'Canceled'}"]
    E -->|No| G["readFile(filePath, 'utf-8')"]
    G --> H["JSON.parse(content)"]

    H --> I{"Validate structure"}
    I --> J{"Array.isArray(data.groups)?"}
    J -->|No| K["Return {success:false, error:'Invalid file format'}"]
    J -->|Yes| L{"isValidSettings(data.settings)?"}
    L -->|No| K
    L -->|Yes| M{"data.groups.every(isValidGroup)?"}
    M -->|No| N["Return {success:false, error:'Invalid group or item data'}"]
    M -->|Yes| O["setAllData(data)<br/>store.set('groups', ...) + store.set('settings', ...)"]
    O --> P["updateTrayMenu()"]
    P --> Q["Return {success:true}"]
```

## Quick Search Flow

```mermaid
flowchart TD
    A{"Trigger source?"} -->|"Global shortcut<br/>Ctrl/Cmd+Shift+Space"| B["main/index.ts: globalShortcut handler"]
    A -->|"Help menu entry"| C["uiStore.toggleQuickSearch()"]

    B --> D["mainWindow.webContents.send('quick-search:toggle')"]
    D --> E["preload: ipcRenderer.on('quick-search:toggle')"]
    E --> F["App.tsx: toggleQuickSearch()"]

    C --> G["uiStore: quickSearchOpen = !quickSearchOpen"]
    F --> G

    G --> H["App.tsx renders QuickSearchOverlay"]
    H --> I["User types query"]

    I --> J["Relevance scoring against all items:<br/>Name prefix match = 3<br/>Name substring match = 2<br/>Path/Group name match = 1"]

    J --> K["Sort by score desc, then alphabetical"]
    K --> L["Display top 10 results"]

    L --> M{"User action?"}
    M -->|"Arrow keys"| N["Navigate selectedIndex"]
    M -->|"Enter"| O["Launch selected item<br/>via window.electronAPI.program.launch()"]
    M -->|"Escape"| P["closeQuickSearch()"]
    M -->|"Click result"| O

    O --> Q["Close overlay"]
    Q --> R{"settings.minimizeOnUse?"}
    R -->|Yes| S["window.electronAPI.window.minimize()"]
    R -->|No| T["Done"]
```

## Store Persistence Flow (Debounced)

```mermaid
flowchart TD
    A["Zustand action<br/>(addItem, updateGroup,<br/>updateSettings, etc.)"] --> B["set() updates local state"]
    B --> C["debouncedSaveGroups or<br/>debouncedSaveSettings (300ms)"]

    C --> D{"Timer already pending?"}
    D -->|Yes| E["clearTimeout(existing)"]
    D -->|No| F["Set new timer"]
    E --> F

    F --> G["After 300ms: saveGroups() or saveSettings()"]
    G --> H["window.electronAPI.store.set(key, value)"]
    H --> I["preload: ipcRenderer.invoke('store:set', key, value)"]
    I --> J["storeHandlers: validate data"]

    J --> K{"key = 'groups'?"}
    K -->|Yes| L["isValidGroup() for each group<br/>(checks id, name, icon, windowState, items)"]
    K -->|No| M["isValidSettings()<br/>(checks all boolean/number/enum fields)"]

    L --> N{"Valid?"}
    M --> N

    N -->|Yes| O["store.set(key, value)<br/>electron-store writes JSON"]
    N -->|No| P["throw Error('Invalid data')"]

    O --> Q{"key = 'groups'?"}
    Q -->|Yes| R["updateTrayMenu()"]
    Q -->|No| S["Done"]
    R --> S
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `src/main/ipc/launchHandlers.ts` | Full platform dispatch logic for program launch (win32 .lnk handling, darwin .app bundles, linux .desktop parsing), tokenizeCommand, isValidExecPath, spawnDetached, batch launch with delay, URL handling via shell.openExternal, system:open-external handler |
| `src/main/ipc/storeHandlers.ts` | store:get/set/get-all/export/import handlers, validation functions (isValidItem, isValidGroup, isValidSettings), export uses dialog.showSaveDialog + writeFile, import uses showOpenDialog + readFile + parse + 3-stage validation + setAllData, tray menu updates on group changes |
| `src/main/ipc/fileHandlers.ts` | File dialog handlers with platform-specific filters for executables and icons |
| `src/main/ipc/appInfoHandlers.ts` | Per-platform app info extraction: macOS (.app icon), Windows (.lnk resolution, .exe icon), Linux (.desktop parsing with Exec/Name/Icon fields) |
| `src/main/store.ts` | electron-store wrapper: file name `program-manager-data`, defaults, getAllData/setAllData functions |
| `src/main/index.ts` | Global shortcut registration (Ctrl/Cmd+Shift+Space) -> webContents.send('quick-search:toggle') |
| `src/preload/index.ts` | contextBridge: 6 API namespaces (window, file, program, store, system, app) + event listener with whitelist |
| `src/renderer/src/store/programStore.ts` | All Zustand actions with debounced saves (300ms), uuid generation for new items/groups, IPC calls to store:set |
| `src/renderer/src/store/uiStore.ts` | Quick search state management (toggleQuickSearch, openQuickSearch, closeQuickSearch) |
| `src/renderer/src/App.tsx` | Quick search IPC listener, launch helper with minimizeOnUse, welcome dialog on first run |
| `src/renderer/src/components/QuickSearch/QuickSearchOverlay.tsx` | Search scoring algorithm (prefix=3, substring=2, path/group=1), max 10 results, keyboard navigation, launch on Enter |
