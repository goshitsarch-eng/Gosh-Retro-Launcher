# System Architecture

High-level component diagram showing the Electron process architecture, store layer, shell system, and IPC communication channels.

## Process Architecture

```mermaid
graph TB
    subgraph "Main Process (src/main/)"
        MainEntry["index.ts<br/>App Lifecycle"]
        Store["store.ts<br/>electron-store"]
        Window["window.ts<br/>BrowserWindow"]
        Tray["tray.ts<br/>System Tray"]

        subgraph "IPC Handlers (src/main/ipc/)"
            IpcIndex["index.ts<br/>registerIpcHandlers()"]
            WindowH["windowHandlers.ts"]
            FileH["fileHandlers.ts"]
            StoreH["storeHandlers.ts"]
            LaunchH["launchHandlers.ts"]
            AppInfoH["appInfoHandlers.ts"]
        end

        MainEntry --> Store
        MainEntry --> IpcIndex
        MainEntry --> Window
        MainEntry --> Tray
        IpcIndex --> WindowH
        IpcIndex --> FileH
        IpcIndex --> StoreH
        IpcIndex --> LaunchH
        IpcIndex --> AppInfoH

        StoreH --> Store
        LaunchH -->|"spawn / shell.openPath"| OS["OS Process"]
        Tray -->|"launchProgram()"| LaunchH
        Tray -->|"getGroups()"| Store
        WindowH --> Window
    end

    subgraph "Preload (src/preload/)"
        Preload["index.ts<br/>contextBridge.exposeInMainWorld()"]
    end

    subgraph "Renderer Process (src/renderer/src/)"
        App["App.tsx"]

        subgraph "Shell System (shells/)"
            Registry["registry.ts<br/>Map&lt;ShellType, ShellDefinition&gt;"]
            Win31["Win31Shell.tsx<br/>MenuBar + MDIContainer"]
            Win95["Win95Shell.tsx<br/>Desktop + Taskbar + StartMenu"]
            Registry --> Win31
            Registry --> Win95
        end

        subgraph "Zustand Stores (store/)"
            ProgramStore["programStore.ts<br/>groups, settings, isLoading"]
            UIStore["uiStore.ts<br/>dialogs, menus, selection, quickSearch"]
            MDIStore["mdiStore.ts<br/>windows, activeWindowId, zIndex"]
        end

        subgraph "Components"
            MDI["MDI/<br/>MDIContainer, MDIWindow, MDIWindowControls"]
            Menu["Menu/<br/>MenuBar, Menu, MenuItem, MenuSeparator"]
            Dialogs["Dialogs/<br/>DialogManager + 10 dialog components"]
            QuickSearch["QuickSearch/<br/>QuickSearchOverlay"]
            Items["Items/<br/>ItemGrid, ProgramItem"]
            Common["Common/<br/>Button, Checkbox, Icon, TextInput"]
        end

        subgraph "Hooks"
            UseDraggable["useDraggable"]
            UseResizable["useResizable"]
            UseSounds["useSounds"]
            UseAnimatedUnmount["useAnimatedUnmount"]
        end

        App --> Registry
        App --> ProgramStore
        App --> UIStore
        App --> Dialogs
        App --> QuickSearch
        Win31 --> Menu
        Win31 --> MDI
        Win95 -->|"Win95Desktop"| MDI
        MDI --> Items
        Items --> Common
    end

    subgraph "Shared (src/shared/)"
        Types["types/index.ts<br/>ProgramItem, ProgramGroup,<br/>AppSettings, StoreData, etc."]
        IpcConst["constants/ipc.ts<br/>IPC_CHANNELS (20 channels)"]
    end

    Preload -->|"ipcRenderer.invoke()"| MainEntry
    App -->|"window.electronAPI.*"| Preload
    ProgramStore -->|"window.electronAPI.store.*"| Preload
    MainEntry -->|"webContents.send()"| Preload

    Types -.->|"imported by"| MainEntry
    Types -.->|"imported by"| Preload
    Types -.->|"imported by"| App
    IpcConst -.->|"imported by"| MainEntry
    IpcConst -.->|"imported by"| Preload

    Store -->|"JSON file"| Disk["program-manager-data.json"]
```

## IPC Channel Map

All IPC communication flows through the preload bridge. The renderer never has direct access to Node.js APIs.

```mermaid
graph LR
    subgraph "Renderer (window.electronAPI)"
        W["window.*"]
        F["file.*"]
        P["program.*"]
        S["store.*"]
        SYS["system.*"]
        AI["app.*"]
        EV["on/off events"]
    end

    subgraph "IPC Channels"
        WC["window:minimize<br/>window:maximize<br/>window:close<br/>window:quit<br/>window:is-maximized"]
        FC["file:select-executable<br/>file:select-icon<br/>file:exists"]
        PC["program:launch<br/>program:launch-batch"]
        SC["store:get<br/>store:set<br/>store:get-all<br/>store:export<br/>store:import"]
        SYSC["system:get-platform<br/>system:get-version<br/>system:open-external"]
        AIC["app:get-info"]
        QSC["quick-search:toggle"]
    end

    subgraph "Main Process Handlers"
        WH["windowHandlers.ts"]
        FH["fileHandlers.ts"]
        LH["launchHandlers.ts"]
        SH["storeHandlers.ts"]
        AIH["appInfoHandlers.ts"]
        GS["globalShortcut<br/>(index.ts)"]
    end

    W -->|"invoke"| WC --> WH
    F -->|"invoke"| FC --> FH
    P -->|"invoke"| PC --> LH
    S -->|"invoke"| SC --> SH
    SYS -->|"invoke"| SYSC
    SYSC -->|"get-platform<br/>get-version"| WH
    SYSC -->|"open-external"| LH
    AI -->|"invoke"| AIC --> AIH
    GS -->|"webContents.send()"| QSC --> EV
```

Note: `system:get-platform` and `system:get-version` are registered in `windowHandlers.ts`, while `system:open-external` is registered in `launchHandlers.ts`.

## Shell System

The pluggable shell system allows switching between UI themes at runtime.

```mermaid
graph TB
    subgraph "Shell Infrastructure"
        ShellType["ShellType = 'win31' | 'win95'"]
        ShellDef["ShellDefinition<br/>{id, name, component}"]
        Reg["registry.ts<br/>Map&lt;ShellType, ShellDefinition&gt;"]
        ShellType --> ShellDef
        ShellDef --> Reg
    end

    subgraph "Win31Shell"
        W31["Win31Shell.tsx"]
        W31MB["MenuBar"]
        W31MDI["MDIContainer"]
        W31 --> W31MB
        W31 --> W31MDI
    end

    subgraph "Win95Shell"
        W95["Win95Shell.tsx"]
        W95D["Win95Desktop"]
        W95TB["Win95Taskbar"]
        W95SM["Win95StartMenu"]
        W95 --> W95D
        W95 --> W95TB
        W95 --> W95SM
    end

    Reg -->|"getShell('win31')"| W31
    Reg -->|"getShell('win95')"| W95

    AppTsx["App.tsx"] -->|"settings.shell"| Reg
    AppTsx -->|"renders ShellComponent"| W31
    AppTsx -->|"renders ShellComponent"| W95
```

## Security Boundaries

```mermaid
graph TB
    subgraph "Renderer Process (Sandboxed)"
        R["React App<br/>contextIsolation: true<br/>nodeIntegration: false<br/>sandbox: true"]
    end

    subgraph "Preload Script"
        PL["contextBridge<br/>Allowlisted API surface only<br/>Event listener whitelist:<br/>quick-search:toggle only"]
    end

    subgraph "Main Process (Full Node.js)"
        M["IPC Handlers<br/>Input validation<br/>isValidItem / isValidGroup / isValidSettings<br/>isValidExecPath / tokenizeCommand<br/>URL protocol check (http/https only)"]
    end

    R -->|"window.electronAPI only"| PL
    PL -->|"ipcRenderer.invoke"| M
    M -->|"Validated spawn/openPath"| OS["Operating System"]
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `src/main/index.ts` | App lifecycle: single instance lock, startup sequence (initStore -> registerIpcHandlers -> createWindow -> createTray -> registerGlobalShortcuts), error handlers, global shortcut registration |
| `src/main/store.ts` | electron-store initialization with StoreSchema, file name `program-manager-data`, default values, getter/setter functions |
| `src/main/window.ts` | BrowserWindow config (800x600, contextIsolation:true, nodeIntegration:false, sandbox:true), tray-on-close behavior, dev vs production loading |
| `src/main/tray.ts` | System tray with dynamic group/item menu, platform-specific icons, direct program launch capability |
| `src/main/ipc/index.ts` | 5 handler registration modules |
| `src/main/ipc/windowHandlers.ts` | Handles window:* channels + system:get-platform + system:get-version |
| `src/main/ipc/fileHandlers.ts` | Handles file:* channels with platform-specific filters |
| `src/main/ipc/storeHandlers.ts` | Handles store:* channels with validation functions |
| `src/main/ipc/launchHandlers.ts` | Handles program:* channels + system:open-external, platform dispatch logic |
| `src/main/ipc/appInfoHandlers.ts` | Handles app:get-info with per-platform extraction |
| `src/preload/index.ts` | contextBridge exposes electronAPI with 6 namespaces + on/off listeners (whitelist: quick-search:toggle) |
| `src/shared/constants/ipc.ts` | 17 IPC channel constants in 7 groups |
| `src/shared/types/index.ts` | All shared interfaces and type definitions |
| `src/renderer/src/App.tsx` | Root component: shell resolution, theme toggling, shared shortcuts, welcome dialog |
| `src/renderer/src/shells/registry.ts` | Shell Map with registerShell/getShell, two built-in shells |
| `src/renderer/src/shells/types.ts` | ShellProps, ShellDefinition interfaces |
| `src/renderer/src/shells/Win31Shell.tsx` | MenuBar + MDIContainer composition, Win31-specific keyboard shortcuts |
| `src/renderer/src/shells/win95/Win95Shell.tsx` | Desktop + Taskbar + StartMenu composition, start menu toggle |
| `src/renderer/src/store/programStore.ts` | Zustand store: groups, settings, isLoading + all CRUD actions with debounced saves |
| `src/renderer/src/store/uiStore.ts` | Zustand store: dialogs (10 types), menus, selection, quick search |
| `src/renderer/src/store/mdiStore.ts` | Zustand store: MDI windows with z-index management, arrangement via CustomEvents |
| `src/renderer/src/components/Dialogs/DialogManager.tsx` | Switch-based dialog rendering for 10 dialog types |
| `electron.vite.config.ts` | 3-target build: main, preload, renderer with path aliases |
