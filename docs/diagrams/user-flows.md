# User Flow Diagrams

Key task flows verified by tracing the actual UI components and store logic.

## First-Run Experience

```mermaid
flowchart TD
    A["App launches"] --> B["main/index.ts:<br/>requestSingleInstanceLock()"]
    B --> C["app.whenReady()"]
    C --> D["initStore()<br/>(defaults: empty groups, DEFAULT_SETTINGS)"]
    D --> E["registerIpcHandlers()"]
    E --> F["createWindow()<br/>(800x600, sandbox: true)"]
    F --> G["createTray()"]
    G --> H["registerGlobalShortcuts()<br/>(Ctrl/Cmd+Shift+Space)"]

    H --> I["Renderer loads"]
    I --> J["App.tsx: loadData()"]
    J --> K["programStore: store.getAll() via IPC"]
    K --> L["Set groups=[], settings=DEFAULT_SETTINGS"]
    L --> M["sounds.startupChime()<br/>(after 300ms delay)"]

    M --> N{"localStorage.getItem('hasLaunched')?"}
    N -->|"null (first run)"| O["Set 'hasLaunched' = 'true'<br/>openDialog('welcome')"]
    N -->|"exists"| P["Skip welcome"]

    O --> Q["WelcomeDialog renders<br/>with onboarding info"]
    Q --> R["User dismisses dialog"]

    P --> S["Shell renders (win31 default)"]
    R --> S

    S --> T["Empty state shown<br/>(theme-aware, menu path hint)"]
    T --> U["Shortcut hint shown:<br/>'Press Ctrl+Shift+Space for Quick Search'"]
```

## Adding a Program Item

```mermaid
flowchart TD
    A{"Entry point?"} -->|"Menu: File > New"| B["uiStore.openDialog('newItem',<br/>{groupId, openItemAfterCreate: true})"]
    A -->|"Right-click grid > New Item"| B
    A -->|"Right-click desktop > New Item"| B

    B --> C["DialogManager renders<br/>ItemPropertiesDialog"]

    C --> D["User fills Name field"]

    C --> E{"Browse for path?"}
    E -->|"Browse button"| F["window.electronAPI.file.selectExecutable()"]
    F --> G["Platform-specific file dialog:<br/>Win: .exe, .bat, .cmd, .msi, .lnk<br/>Mac: .app, *<br/>Linux: .desktop, .sh, *"]
    G --> H{"File selected?"}
    H -->|Yes| I["window.electronAPI.app.getInfo(path)"]
    I --> J["Auto-populate name, icon, workingDir<br/>from extracted AppInfo"]
    H -->|No| K["Keep current values"]
    E -->|"Type path manually"| K

    J --> L["User can edit icon<br/>(icon picker with search/filter)"]
    K --> L

    L --> M["User sets Working Directory<br/>(optional)"]
    M --> N["User clicks OK"]

    N --> O["programStore.addItem(groupId, {<br/>name, path, icon, workingDir, launchGroup<br/>})"]
    O --> P["UUID generated for new item"]
    P --> Q["Zustand state updated"]
    Q --> R["Debounced save (300ms):<br/>IPC store:set -> electron-store -> JSON file"]
    R --> S["Tray menu updated"]
    S --> T["Item appears in group window"]
```

## Adding a URL Item

```mermaid
flowchart TD
    A["Menu: File > New URL..."] --> B["uiStore.openDialog('newUrl',<br/>{groupId, openUrlAfterCreate: true})"]
    B --> C["NewUrlDialog renders"]
    C --> D["User enters Name and URL<br/>(http:// or https://)"]
    D --> E["User clicks OK"]
    E --> F["programStore.addItem(groupId, {<br/>name, path: url, icon: 'globe', workingDir: ''<br/>})"]
    F --> G["Same save flow as program items"]
```

## Organizing Groups

```mermaid
flowchart TD
    A{"Create group?"} -->|"File > New Group"| B["uiStore.openDialog('newGroup')"]
    A -->|"Right-click desktop ><br/>New Group"| B

    B --> C["NewGroupDialog renders"]
    C --> D["User enters group name"]
    D --> E["programStore.addGroup(name)"]
    E --> F["New ProgramGroup created:<br/>id: uuid, icon: 'folder',<br/>windowState: offset by group count * 30px"]
    F --> G["mdiStore.openWindow(groupId)"]
    G --> H["MDI window appears"]

    H --> I{"Arrange windows?"}
    I -->|"Window > Cascade<br/>(or Shift+F5)"| J["mdiStore.cascadeWindows()<br/>dispatches CustomEvent 'mdi-cascade'"]
    I -->|"Window > Tile<br/>(or Shift+F4)"| K["mdiStore.tileWindows()<br/>dispatches CustomEvent 'mdi-tile'"]
    I -->|"Window > Arrange Icons"| L["mdiStore.arrangeIcons()<br/>dispatches CustomEvent 'mdi-arrange-icons'"]
    I -->|"Manual drag/resize"| M["useDraggable / useResizable hooks<br/>(pointer events for touch support)"]

    M --> N["programStore.updateGroupWindowState(id, {x, y, width, height})"]
    N --> O{"settings.saveSettingsOnExit?"}
    O -->|Yes| P["Debounced save (300ms)"]
    O -->|No| Q["Position not persisted"]
```

## Renaming and Editing Groups

```mermaid
flowchart TD
    A{"Edit group?"} -->|"Right-click title bar ><br/>Rename"| B["uiStore.openDialog('renameGroup', {groupId})"]
    A -->|"Right-click title bar ><br/>Properties"| C["uiStore.openDialog('groupProperties', {groupId, group})"]

    B --> D["RenameGroupDialog"]
    D --> E["User enters new name"]
    E --> F["programStore.updateGroup(id, {name})"]

    C --> G["GroupPropertiesDialog"]
    G --> H["User edits name, icon"]
    H --> I["programStore.updateGroup(id, updates)"]

    F --> J["Debounced save -> IPC -> electron-store"]
    I --> J
```

## Deleting Items and Groups

```mermaid
flowchart TD
    A{"Delete what?"} -->|"Select item + Delete key"| B["uiStore.openDialog('confirm', {<br/>confirmOptions: {<br/>title, message, onConfirm<br/>}})"]
    A -->|"Right-click item ><br/>Delete"| B
    A -->|"Right-click group ><br/>Delete Group"| C["uiStore.openDialog('confirm', {<br/>confirmOptions for group delete})"]

    B --> D["ConfirmDialog renders"]
    D --> E{"User confirms?"}
    E -->|Yes| F["programStore.deleteItem(groupId, itemId)"]
    E -->|No| G["closeDialog()"]

    C --> H["ConfirmDialog renders"]
    H --> I{"User confirms?"}
    I -->|Yes| J["programStore.deleteGroup(groupId)<br/>mdiStore.closeWindow(groupId)"]
    I -->|No| K["closeDialog()"]

    F --> L["Debounced save + tray update"]
    J --> L
```

## Quick Search

```mermaid
flowchart TD
    A{"Trigger?"} -->|"Ctrl/Cmd+Shift+Space<br/>(global, works when minimized)"| B["Main process sends<br/>'quick-search:toggle' to renderer"]
    A -->|"Help menu > Quick Search"| C["Direct toggle"]

    B --> D["QuickSearchOverlay opens"]
    C --> D

    D --> E["Input auto-focused"]
    E --> F["User types query"]

    F --> G["Real-time scoring:<br/>3 = name starts with query<br/>2 = name contains query<br/>1 = path or group name contains query"]

    G --> H["Results sorted by score desc,<br/>then alphabetical"]
    H --> I["Top 10 displayed<br/>(+ 'N more not shown' if overflow)"]

    I --> J{"User action?"}
    J -->|"Arrow Up/Down"| K["Navigate selection"]
    J -->|"Enter"| L["Launch selected item"]
    J -->|"Click result"| L
    J -->|"Escape"| M["Close overlay"]
    J -->|"Click outside"| M

    K --> J
    L --> N["IPC program:launch"]
    N --> O{"settings.minimizeOnUse?"}
    O -->|Yes| P["Minimize window"]
    O -->|No| Q["Done"]
```

## Changing Theme and Shell

```mermaid
flowchart TD
    A["Options > Settings<br/>(or via menu)"] --> B["uiStore.openDialog('settings')"]
    B --> C["SettingsDialog renders"]

    C --> D["Appearance groupbox"]

    D --> E{"Change theme?"}
    E -->|"Select Light/Dark"| F["programStore.updateSettings({theme: 'light'|'dark'})"]
    F --> G["App.tsx useEffect:<br/>document.documentElement.classList.toggle('theme-dark')"]

    D --> H{"Change shell?"}
    H -->|"Select Windows 3.1 / Windows 95"| I["programStore.updateSettings({shell: 'win31'|'win95'})"]
    I --> J["App.tsx re-renders:<br/>getShell(settings.shell)<br/>ShellComponent swaps"]

    D --> K["ThemePreview component<br/>shows inline miniature preview<br/>of selected shell + theme"]

    D --> L{"Toggle sounds?"}
    L -->|"soundEnabled checkbox"| M["programStore.updateSettings({soundEnabled: bool})"]
    M --> N["useSounds hook reads setting<br/>to enable/disable audio"]

    J --> O["All settings debounce-saved (300ms)"]
    G --> O
    N --> O
    O --> P["IPC store:set -> electron-store -> JSON"]
```

## Launching from System Tray

```mermaid
flowchart TD
    A["User interacts with system tray"] --> B{"Action?"}

    B -->|"Double-click icon<br/>(Win/Linux only)"| C["showMainWindow():<br/>restore + show + focus"]

    B -->|"Right-click > Show Program Manager"| C

    B -->|"Right-click > Group > Item"| D["tray.ts: launchItem(item)"]
    D --> E["launchProgram(item)<br/>(same as renderer launch path)"]
    E --> F["Platform-specific spawn"]

    B -->|"Right-click > Exit"| G["app.quit()"]
```

## Window Close Behavior

```mermaid
flowchart TD
    A["User clicks window close (X)"] --> B{"isQuitting flag?"}
    B -->|"true (app.quit() called)"| C["Window actually closes"]
    B -->|"false"| D{"settings.trayOnClose?"}
    D -->|"true (default)"| E["event.preventDefault()<br/>mainWindow.hide()"]
    D -->|"false"| C

    E --> F["App continues in system tray"]
    C --> G{"process.platform?"}
    G -->|"darwin"| H["App stays active<br/>(macOS convention)"]
    G -->|"Other"| I["app.quit()"]
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `src/main/index.ts` | App startup sequence, single instance lock, global shortcut registration, quit/close lifecycle, activate handler for macOS |
| `src/main/window.ts` | BrowserWindow creation, tray-on-close behavior (event.preventDefault + hide), isQuitting flag, dev vs production URL loading |
| `src/main/tray.ts` | System tray: platform-specific icons, dynamic menu from groups, double-click handler (Win/Linux), direct program launch from tray submenu |
| `src/renderer/src/App.tsx` | First-run detection via localStorage('hasLaunched'), welcome dialog trigger, loadData + startup chime, shell resolution via getShell(), theme CSS class toggle, shared keyboard shortcuts (Enter/Delete), quick search IPC listener |
| `src/renderer/src/store/programStore.ts` | All CRUD actions (addGroup, addItem, updateItem, deleteItem, deleteGroup, moveItem, updateSettings), debounced saves, UUID generation, windowState offset calculation for new groups |
| `src/renderer/src/store/uiStore.ts` | 10 dialog types, openDialog/closeDialog, menu state, quick search state, selection state |
| `src/renderer/src/store/mdiStore.ts` | Window open/close/focus, z-index management, cascade/tile/arrangeIcons via CustomEvent dispatch |
| `src/renderer/src/shells/Win31Shell.tsx` | MenuBar + MDIContainer rendering, Alt+F/O/W/H menu shortcuts, Shift+F4 tile, Shift+F5 cascade, Escape close menu, chrome scale CSS vars, shortcut hint |
| `src/renderer/src/shells/win95/Win95Shell.tsx` | Desktop + Taskbar + StartMenu rendering, start menu toggle, Escape closes start menu, chrome scale CSS vars, shortcut hint |
| `src/renderer/src/components/Dialogs/DialogManager.tsx` | Switch-based dialog rendering for all 10 dialog types |
| `src/renderer/src/components/QuickSearch/QuickSearchOverlay.tsx` | Search scoring (prefix=3, substring=2, path/group=1), max 10 results, keyboard navigation (arrows, Enter, Escape), click handling, auto-focus |
| `src/main/ipc/storeHandlers.ts` | Import/export flows: dialog.showSaveDialog/showOpenDialog, file I/O, 3-stage validation, tray menu update |
| `src/main/ipc/fileHandlers.ts` | Platform-specific executable file filters (Win: exe/bat/cmd/msi/lnk, Mac: app, Linux: desktop/sh) |
| `src/main/ipc/appInfoHandlers.ts` | Auto-populate from file: name extraction, icon extraction via app.getFileIcon/nativeImage, .desktop file parsing, .lnk shortcut resolution |
