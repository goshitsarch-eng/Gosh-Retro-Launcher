import { contextBridge, ipcRenderer } from 'electron'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type {
  ProgramItem,
  StoreData,
  AppInfo,
  ShellType,
  HostWindowBounds,
  DisplayWorkArea,
  BackupInfo,
  GrpImportResult,
  ProgramGroup
} from '@shared/types'

const ipcListenerMap = new Map<string, Map<(...args: unknown[]) => void, (...args: unknown[]) => void>>()
const validListenerChannels: string[] = [
  IPC_CHANNELS.QUICK_SEARCH_TOGGLE,
  IPC_CHANNELS.WINDOW_STATE_CHANGED,
  IPC_CHANNELS.WINDOW_DISPLAY_CHANGED,
  IPC_CHANNELS.APP_OPEN_LAUNCHER_TOOLS,
  IPC_CHANNELS.STORE_CHANGED
]

const electronAPI = {
  window: {
    minimize: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_MINIMIZE),
    maximize: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_MAXIMIZE),
    close: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_CLOSE),
    quit: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_QUIT),
    isMaximized: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_IS_MAXIMIZED) as Promise<boolean>,
    getBounds: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_GET_BOUNDS) as Promise<HostWindowBounds>,
    setBounds: (bounds: HostWindowBounds) =>
      ipcRenderer.invoke(IPC_CHANNELS.WINDOW_SET_BOUNDS, bounds) as Promise<boolean>,
    getDisplayWorkArea: () =>
      ipcRenderer.invoke(IPC_CHANNELS.WINDOW_GET_DISPLAY_WORK_AREA) as Promise<DisplayWorkArea>,
    recreateForShell: (shell: ShellType) =>
      ipcRenderer.invoke(IPC_CHANNELS.WINDOW_RECREATE_FOR_SHELL, shell) as Promise<boolean>
  },

  file: {
    selectExecutable: () =>
      ipcRenderer.invoke(IPC_CHANNELS.FILE_SELECT_EXECUTABLE) as Promise<string | null>,
    selectIcon: () => ipcRenderer.invoke(IPC_CHANNELS.FILE_SELECT_ICON) as Promise<string | null>,
    exists: (path: string) => ipcRenderer.invoke(IPC_CHANNELS.FILE_EXISTS, path) as Promise<boolean>,
    importGrp: () => ipcRenderer.invoke(IPC_CHANNELS.FILE_IMPORT_GRP) as Promise<GrpImportResult>,
    exportGrp: (group: ProgramGroup) =>
      ipcRenderer.invoke(IPC_CHANNELS.FILE_EXPORT_GRP, group) as Promise<{ success: boolean; error?: string }>
  },

  program: {
    launch: (item: ProgramItem) =>
      ipcRenderer.invoke(IPC_CHANNELS.PROGRAM_LAUNCH, item) as Promise<{ success: boolean; error?: string }>,
    launchBatch: (items: ProgramItem[], delay: number) =>
      ipcRenderer.invoke(IPC_CHANNELS.PROGRAM_LAUNCH_BATCH, items, delay) as Promise<
        Array<{ id: string; success: boolean; error?: string }>
      >
  },

  store: {
    get: <T>(key: string) => ipcRenderer.invoke(IPC_CHANNELS.STORE_GET, key) as Promise<T>,
    set: <T>(key: string, value: T) => ipcRenderer.invoke(IPC_CHANNELS.STORE_SET, key, value),
    getAll: () => ipcRenderer.invoke(IPC_CHANNELS.STORE_GET_ALL) as Promise<StoreData>,
    exportData: () => ipcRenderer.invoke(IPC_CHANNELS.STORE_EXPORT) as Promise<boolean>,
    importData: () => ipcRenderer.invoke(IPC_CHANNELS.STORE_IMPORT) as Promise<{ success: boolean; error?: string }>,
    listBackups: () => ipcRenderer.invoke(IPC_CHANNELS.BACKUP_LIST) as Promise<BackupInfo[]>,
    createBackup: (reason = 'manual') =>
      ipcRenderer.invoke(IPC_CHANNELS.BACKUP_CREATE, reason) as Promise<BackupInfo | null>,
    restoreBackup: (id: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.BACKUP_RESTORE, id) as Promise<{ success: boolean; error?: string }>
  },

  system: {
    getPlatform: () =>
      ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_GET_PLATFORM) as Promise<'win32' | 'darwin' | 'linux'>,
    getVersion: () => ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_GET_VERSION) as Promise<string>,
    openExternal: (url: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_OPEN_EXTERNAL, url) as Promise<{ success: boolean; error?: string }>
  },

  app: {
    getInfo: (filePath: string) => ipcRenderer.invoke(IPC_CHANNELS.APP_GET_INFO, filePath) as Promise<AppInfo>,
    openLauncherTools: () => ipcRenderer.invoke(IPC_CHANNELS.APP_OPEN_LAUNCHER_TOOLS) as Promise<boolean>
  },

  on: (channel: string, callback: (...args: unknown[]) => void) => {
    if (!validListenerChannels.includes(channel)) return
    const channelListeners = ipcListenerMap.get(channel) ?? new Map()
    if (channelListeners.has(callback)) return
    const listener = (_: Electron.IpcRendererEvent, ...args: unknown[]) => callback(...args)
    channelListeners.set(callback, listener)
    ipcListenerMap.set(channel, channelListeners)
    ipcRenderer.on(channel, listener)
  },

  off: (channel: string, callback: (...args: unknown[]) => void) => {
    if (!validListenerChannels.includes(channel)) return
    const channelListeners = ipcListenerMap.get(channel)
    const listener = channelListeners?.get(callback)
    if (!listener) return
    ipcRenderer.removeListener(channel, listener)
    channelListeners?.delete(callback)
    if (channelListeners?.size === 0) ipcListenerMap.delete(channel)
  }
}

contextBridge.exposeInMainWorld('electronAPI', electronAPI)

export type ElectronAPI = typeof electronAPI
