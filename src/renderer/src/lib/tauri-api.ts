import { invoke } from '@tauri-apps/api/core'
import { listen, type UnlistenFn } from '@tauri-apps/api/event'
import type { ProgramItem, ProgramGroup, AppSettings, StoreData } from '@shared/types'

interface LaunchResult {
  success: boolean
  error?: string
}

interface BatchLaunchResult {
  id: string
  success: boolean
  error?: string
}

interface ImportResult {
  success: boolean
  error?: string
}

// Store active listeners for cleanup
const listenerMap = new Map<string, Map<(...args: unknown[]) => void, UnlistenFn>>()

export const tauriAPI = {
  // Window Controls
  window: {
    minimize: (): Promise<void> => invoke('minimize_window'),
    maximize: (): Promise<void> => invoke('maximize_window'),
    close: (): Promise<void> => invoke('close_window'),
    quit: (): Promise<void> => invoke('quit_app'),
    isMaximized: (): Promise<boolean> => invoke('is_maximized')
  },

  // File Operations
  file: {
    selectExecutable: (): Promise<string | null> => invoke('select_executable'),
    selectIcon: (): Promise<string | null> => invoke('select_icon'),
    exists: (path: string): Promise<boolean> => invoke('file_exists', { path })
  },

  // Program Management
  program: {
    launch: (item: ProgramItem): Promise<LaunchResult> =>
      invoke('launch_program', { item }),
    launchBatch: (items: ProgramItem[], delay: number): Promise<BatchLaunchResult[]> =>
      invoke('launch_batch', { items, delay })
  },

  // Store/Persistence
  store: {
    get: <T>(key: string): Promise<T> => invoke('store_get', { key }),
    set: <T>(key: string, value: T): Promise<void> => invoke('store_set', { key, value }),
    getAll: (): Promise<StoreData> => invoke('store_get_all'),
    exportData: (): Promise<boolean> => invoke('store_export'),
    importData: (): Promise<ImportResult> => invoke('store_import')
  },

  // System
  system: {
    getPlatform: (): Promise<'win32' | 'darwin' | 'linux'> => invoke('get_platform'),
    openExternal: (url: string): Promise<LaunchResult> => invoke('open_external', { url })
  },

  // Event Listeners
  on: async (channel: string, callback: (...args: unknown[]) => void): Promise<void> => {
    const validChannels = ['quick-search:toggle', 'tray-launch-item']

    if (!validChannels.includes(channel)) {
      console.warn(`Invalid event channel: ${channel}`)
      return
    }

    const channelListeners = listenerMap.get(channel) ?? new Map()

    // Avoid duplicate listeners
    if (channelListeners.has(callback)) {
      return
    }

    const unlisten = await listen(channel, (event) => {
      callback(event.payload)
    })

    channelListeners.set(callback, unlisten)
    listenerMap.set(channel, channelListeners)
  },

  off: (channel: string, callback: (...args: unknown[]) => void): void => {
    const channelListeners = listenerMap.get(channel)
    const unlisten = channelListeners?.get(callback)

    if (!unlisten) {
      return
    }

    unlisten()
    channelListeners?.delete(callback)

    if (channelListeners?.size === 0) {
      listenerMap.delete(channel)
    }
  }
}

// For backward compatibility, expose as electronAPI
export const electronAPI = tauriAPI

// Type for the API
export type TauriAPI = typeof tauriAPI
