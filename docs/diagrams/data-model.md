# Data Model Diagrams

Data types from `src/shared/types/index.ts`, Zustand store state shapes, and persistence format.

## Core Data Types (Entity Relationship)

```mermaid
erDiagram
    StoreData {
        ProgramGroup[] groups
        AppSettings settings
    }

    ProgramGroup {
        string id "UUID"
        string name
        string icon
        WindowState windowState
        ProgramItem[] items
    }

    ProgramItem {
        string id "UUID"
        string name
        string path "executable path or URL"
        string icon "icon ID or data URL"
        string workingDir
        number launchGroup "optional batch group"
    }

    WindowState {
        number x
        number y
        number width
        number height
        boolean minimized
        boolean maximized
    }

    AppSettings {
        boolean autoArrange
        boolean minimizeOnUse
        boolean saveSettingsOnExit
        number launchDelay "ms, >= 0"
        boolean trayOnClose
        number groupChromeScale "positive number"
        string theme "light or dark"
        string labelDisplay "wrap or ellipsis"
        string shell "win31 or win95"
        boolean soundEnabled
    }

    StoreData ||--o{ ProgramGroup : "contains"
    StoreData ||--|| AppSettings : "has"
    ProgramGroup ||--|| WindowState : "has"
    ProgramGroup ||--o{ ProgramItem : "contains"
```

## All Shared Type Definitions

```mermaid
classDiagram
    class ProgramItem {
        +string id
        +string name
        +string path
        +string icon
        +string workingDir
        +number launchGroup~optional~
    }

    class WindowState {
        +number x
        +number y
        +number width
        +number height
        +boolean minimized
        +boolean maximized
    }

    class ProgramGroup {
        +string id
        +string name
        +string icon
        +WindowState windowState
        +ProgramItem[] items
    }

    class AppSettings {
        +boolean autoArrange
        +boolean minimizeOnUse
        +boolean saveSettingsOnExit
        +number launchDelay
        +boolean trayOnClose
        +number groupChromeScale
        +string theme
        +string labelDisplay
        +ShellType shell
        +boolean soundEnabled
    }

    class StoreData {
        +ProgramGroup[] groups
        +AppSettings settings
    }

    class AppInfo {
        +string name
        +string path
        +string icon~optional~
        +string workingDir~optional~
    }

    class FileFilter {
        +string name
        +string[] extensions
    }

    ProgramGroup *-- WindowState
    ProgramGroup *-- ProgramItem
    StoreData *-- ProgramGroup
    StoreData *-- AppSettings
```

## Type Aliases and Constants

```mermaid
graph TB
    subgraph "Type Aliases"
        ShellType["ShellType = 'win31' | 'win95'"]
        Platform["Platform = 'win32' | 'darwin' | 'linux'"]
        Theme["theme: 'light' | 'dark'"]
        LabelDisplay["labelDisplay: 'wrap' | 'ellipsis'"]
    end

    subgraph "Default Constants"
        DS["DEFAULT_SETTINGS"]
        DWS["DEFAULT_WINDOW_STATE"]
    end

    DS --> DSVals["autoArrange: true<br/>minimizeOnUse: false<br/>saveSettingsOnExit: true<br/>launchDelay: 500<br/>trayOnClose: true<br/>groupChromeScale: 1<br/>theme: 'light'<br/>labelDisplay: 'wrap'<br/>shell: 'win31'<br/>soundEnabled: true"]

    DWS --> DWSVals["x: 20, y: 20<br/>width: 300, height: 200<br/>minimized: false<br/>maximized: false"]
```

## Zustand Store: programStore

```mermaid
classDiagram
    class ProgramState {
        +ProgramGroup[] groups
        +AppSettings settings
        +boolean isLoading
        +loadData() Promise~void~
        +saveGroups() Promise~void~
        +saveSettings() Promise~void~
        +addGroup(name) string
        +updateGroup(id, updates) void
        +deleteGroup(id) void
        +updateGroupWindowState(id, windowState) void
        +addItem(groupId, item) void
        +updateItem(groupId, itemId, updates) void
        +deleteItem(groupId, itemId) void
        +moveItem(fromGroupId, toGroupId, itemId) void
        +updateSettings(updates) void
    }

    note for ProgramState "All mutating actions trigger debounced IPC save (300ms).\nUUID generated via uuid.v4() for new groups and items.\nloadData() merges server data with DEFAULT_SETTINGS."
```

## Zustand Store: uiStore

```mermaid
classDiagram
    class UIState {
        +string|null activeMenu
        +DialogType|null activeDialog
        +DialogData dialogData
        +boolean quickSearchOpen
        +string|null selectedItemId
        +string|null selectedGroupId
        +setActiveMenu(menu) void
        +openDialog(type, data?) void
        +closeDialog() void
        +toggleQuickSearch() void
        +openQuickSearch() void
        +closeQuickSearch() void
        +setSelectedItem(itemId, groupId) void
        +clearSelection() void
    }

    class DialogType {
        <<enumeration>>
        newGroup
        renameGroup
        groupProperties
        newItem
        newUrl
        itemProperties
        settings
        about
        confirm
        welcome
        null
    }

    class DialogData {
        +string groupId~optional~
        +ProgramGroup group~optional~
        +ProgramItem item~optional~
        +ConfirmDialogOptions confirmOptions~optional~
        +boolean openItemAfterCreate~optional~
        +boolean openUrlAfterCreate~optional~
        +boolean showIconPicker~optional~
    }

    class ConfirmDialogOptions {
        +string title
        +string message
        +Function onConfirm
        +Function onCancel~optional~
    }

    UIState --> DialogType
    UIState --> DialogData
    DialogData --> ConfirmDialogOptions
```

## Zustand Store: mdiStore

```mermaid
classDiagram
    class MDIState {
        +MDIWindowState[] windows
        +string|null activeWindowId
        +number nextZIndex
        +openWindow(groupId) void
        +closeWindow(groupId) void
        +focusWindow(groupId) void
        +setActiveWindow(groupId) void
        +cascadeWindows() void
        +tileWindows() void
        +arrangeIcons() void
    }

    class MDIWindowState {
        +string id
        +string groupId
        +number zIndex
    }

    MDIState *-- MDIWindowState

    note for MDIState "openWindow: focuses existing or creates new with nextZIndex++\ncloseWindow: removes + focuses last remaining window\nfocusWindow: assigns nextZIndex++ to bring to front\ncascade/tile/arrangeIcons: dispatch CustomEvents handled by MDIContainer"
```

## Persistence Format

The data is stored as a JSON file by electron-store at the OS-specific config path.

```mermaid
graph TB
    subgraph "electron-store Configuration"
        StoreName["name: 'program-manager-data'"]
        StoreDefaults["defaults:<br/>groups: []<br/>settings: DEFAULT_SETTINGS"]
    end

    subgraph "File Location (per OS)"
        Win["Windows:<br/>%APPDATA%/program-manager/<br/>program-manager-data.json"]
        Mac["macOS:<br/>~/Library/Application Support/<br/>program-manager/<br/>program-manager-data.json"]
        Linux["Linux:<br/>~/.config/program-manager/<br/>program-manager-data.json"]
    end

    StoreName --> Win
    StoreName --> Mac
    StoreName --> Linux
```

Example JSON structure:

```mermaid
graph TD
    Root["program-manager-data.json"] --> Groups["groups: [...]"]
    Root --> Settings["settings: {...}"]

    Groups --> G1["Group 0"]
    G1 --> G1ID["id: 'uuid-1'"]
    G1 --> G1Name["name: 'Main'"]
    G1 --> G1Icon["icon: 'folder'"]
    G1 --> G1WS["windowState: {x, y, width, height, minimized, maximized}"]
    G1 --> G1Items["items: [...]"]
    G1Items --> I1["Item 0: {id, name, path, icon, workingDir, launchGroup?}"]
    G1Items --> I2["Item 1: {id, name, path, icon, workingDir, launchGroup?}"]

    Settings --> S1["autoArrange: true"]
    Settings --> S2["minimizeOnUse: false"]
    Settings --> S3["saveSettingsOnExit: true"]
    Settings --> S4["launchDelay: 500"]
    Settings --> S5["trayOnClose: true"]
    Settings --> S6["groupChromeScale: 1"]
    Settings --> S7["theme: 'light'"]
    Settings --> S8["labelDisplay: 'wrap'"]
    Settings --> S9["shell: 'win31'"]
    Settings --> S10["soundEnabled: true"]
```

## Validation Rules

Data validation functions in `storeHandlers.ts` enforce these constraints on import and IPC writes:

```mermaid
graph TB
    subgraph "isValidItem(item)"
        VI1["typeof id === 'string'"]
        VI2["typeof name === 'string'"]
        VI3["typeof path === 'string'"]
        VI4["typeof icon === 'string'"]
    end

    subgraph "isValidGroup(group)"
        VG1["typeof id === 'string'"]
        VG2["typeof name === 'string'"]
        VG3["typeof icon === 'string'"]
        VG4["typeof windowState === 'object' && !== null"]
        VG5["Array.isArray(items)"]
        VG6["items.every(isValidItem)"]
    end

    subgraph "isValidSettings(settings)"
        VS1["autoArrange: boolean"]
        VS2["minimizeOnUse: boolean"]
        VS3["saveSettingsOnExit: boolean"]
        VS4["launchDelay: number >= 0"]
        VS5["trayOnClose: boolean"]
        VS6["groupChromeScale: number > 0"]
        VS7["theme: 'light' | 'dark'"]
        VS8["labelDisplay: 'wrap' | 'ellipsis'"]
        VS9["shell: undefined | 'win31' | 'win95'"]
        VS10["soundEnabled: undefined | boolean"]
    end

    note1["Note: shell and soundEnabled are optional<br/>for backward compatibility with older exports"]
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `src/shared/types/index.ts` | All interfaces: ProgramItem (6 fields, launchGroup optional), WindowState (6 fields), ProgramGroup (5 fields), AppSettings (10 fields), StoreData, AppInfo, FileFilter. Type aliases: ShellType, Platform. Constants: DEFAULT_SETTINGS, DEFAULT_WINDOW_STATE |
| `src/main/store.ts` | electron-store config: name='program-manager-data', StoreSchema with groups+settings, defaults, getter/setter functions |
| `src/renderer/src/store/programStore.ts` | ProgramState interface: groups, settings, isLoading + 12 actions. Debounced saves (300ms timers). UUID via uuid.v4(). loadData merges with DEFAULT_SETTINGS. updateGroupWindowState conditionally saves based on saveSettingsOnExit |
| `src/renderer/src/store/uiStore.ts` | UIState interface: 10 DialogType values, DialogData shape with 7 optional fields, ConfirmDialogOptions, menu/selection/quickSearch state |
| `src/renderer/src/store/mdiStore.ts` | MDIState + MDIWindowState interfaces. z-index management: nextZIndex increments on open/focus. Window arrangement via CustomEvent dispatch |
| `src/main/ipc/storeHandlers.ts` | Validation functions: isValidItem (4 string checks), isValidGroup (6 checks including nested items validation), isValidSettings (10 checks with optional shell/soundEnabled for backward compat). VALID_THEMES, VALID_LABEL_DISPLAYS, VALID_SHELLS arrays |
