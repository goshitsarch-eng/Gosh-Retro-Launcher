import { contextBridge, ipcRenderer } from 'electron'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { ProgramItem, ProgramGroup, AppSettings, StoreData } from '@shared/types'

const ipcListenerMap = new Map<string, Map<(...args: unknown[]) => void, (...args: unknown[]) => void>>()

// Electron API exposed to renderer
const electronAPI = {
  // Window Controls
  window: {
    minimize: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_MINIMIZE),
    maximize: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_MAXIMIZE),
    close: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_CLOSE),
    quit: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_QUIT),
    isMaximized: () => ipcRenderer.invoke(IPC_CHANNELS.WINDOW_IS_MAXIMIZED) as Promise<boolean>
  },

  // File Operations
  file: {
    selectExecutable: () =>
      ipcRenderer.invoke(IPC_CHANNELS.FILE_SELECT_EXECUTABLE) as Promise<string | null>,
    selectIcon: () =>
      ipcRenderer.invoke(IPC_CHANNELS.FILE_SELECT_ICON) as Promise<string | null>,
    exists: (path: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.FILE_EXISTS, path) as Promise<boolean>
  },

  // Program Management
  program: {
    launch: (item: ProgramItem) =>
      ipcRenderer.invoke(IPC_CHANNELS.PROGRAM_LAUNCH, item) as Promise<{
        success: boolean
        error?: string
      }>,
    launchBatch: (items: ProgramItem[], delay: number) =>
      ipcRenderer.invoke(IPC_CHANNELS.PROGRAM_LAUNCH_BATCH, items, delay) as Promise<
        Array<{ id: string; success: boolean; error?: string }>
      >
  },

  // Store/Persistence
  store: {
    get: <T>(key: string) => ipcRenderer.invoke(IPC_CHANNELS.STORE_GET, key) as Promise<T>,
    set: <T>(key: string, value: T) => ipcRenderer.invoke(IPC_CHANNELS.STORE_SET, key, value),
    getAll: () => ipcRenderer.invoke(IPC_CHANNELS.STORE_GET_ALL) as Promise<StoreData>,
    exportData: () => ipcRenderer.invoke(IPC_CHANNELS.STORE_EXPORT) as Promise<boolean>,
    importData: () =>
      ipcRenderer.invoke(IPC_CHANNELS.STORE_IMPORT) as Promise<{
        success: boolean
        error?: string
      }>
  },

  // System
  system: {
    getPlatform: () =>
      ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_GET_PLATFORM) as Promise<
        'win32' | 'darwin' | 'linux'
      >,
    openExternal: (url: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.SYSTEM_OPEN_EXTERNAL, url) as Promise<{
        success: boolean
        error?: string
      }>
  },

  // Event Listeners
  on: (channel: string, callback: (...args: unknown[]) => void) => {
    const validChannels = [IPC_CHANNELS.QUICK_SEARCH_TOGGLE]
    if (validChannels.includes(channel as typeof IPC_CHANNELS.QUICK_SEARCH_TOGGLE)) {
      const channelListeners = ipcListenerMap.get(channel) ?? new Map()
      if (channelListeners.has(callback)) {
        return
      }
      const listener = (_: Electron.IpcRendererEvent, ...args: unknown[]) => callback(...args)
      channelListeners.set(callback, listener)
      ipcListenerMap.set(channel, channelListeners)
      ipcRenderer.on(channel, listener)
    }
  },

  off: (channel: string, callback: (...args: unknown[]) => void) => {
    const validChannels = [IPC_CHANNELS.QUICK_SEARCH_TOGGLE]
    if (validChannels.includes(channel as typeof IPC_CHANNELS.QUICK_SEARCH_TOGGLE)) {
      const channelListeners = ipcListenerMap.get(channel)
      const listener = channelListeners?.get(callback)
      if (!listener) {
        return
      }
      ipcRenderer.removeListener(channel, listener)
      channelListeners?.delete(callback)
      if (channelListeners?.size === 0) {
        ipcListenerMap.delete(channel)
      }
    }
  }
}

// Expose to renderer
contextBridge.exposeInMainWorld('electronAPI', electronAPI)

// Type export for renderer
export type ElectronAPI = typeof electronAPI
