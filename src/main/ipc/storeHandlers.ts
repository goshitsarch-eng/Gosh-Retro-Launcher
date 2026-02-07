import { ipcMain, dialog } from 'electron'
import { writeFile, readFile } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  getGroups,
  setGroups,
  getSettings,
  setSettings,
  getAllData,
  setAllData
} from '../store'
import { getMainWindow } from '../window'
import { updateTrayMenu } from '../tray'
import type { ProgramGroup, ProgramItem, AppSettings, StoreData } from '@shared/types'

export function isValidItem(item: unknown): item is ProgramItem {
  if (typeof item !== 'object' || item === null) return false
  const obj = item as Record<string, unknown>
  return (
    typeof obj.id === 'string' &&
    typeof obj.name === 'string' &&
    typeof obj.path === 'string' &&
    typeof obj.icon === 'string'
  )
}

export function isValidGroup(group: unknown): group is ProgramGroup {
  if (typeof group !== 'object' || group === null) return false
  const obj = group as Record<string, unknown>
  return (
    typeof obj.id === 'string' &&
    typeof obj.name === 'string' &&
    typeof obj.icon === 'string' &&
    typeof obj.windowState === 'object' &&
    obj.windowState !== null &&
    Array.isArray(obj.items) &&
    obj.items.every(isValidItem)
  )
}

const VALID_THEMES = ['light', 'dark']
const VALID_LABEL_DISPLAYS = ['wrap', 'ellipsis']
const VALID_SHELLS = ['win31', 'win95']

export function isValidSettings(settings: unknown): settings is AppSettings {
  if (typeof settings !== 'object' || settings === null) return false
  const obj = settings as Record<string, unknown>
  return (
    typeof obj.autoArrange === 'boolean' &&
    typeof obj.minimizeOnUse === 'boolean' &&
    typeof obj.saveSettingsOnExit === 'boolean' &&
    typeof obj.launchDelay === 'number' &&
    obj.launchDelay >= 0 &&
    typeof obj.trayOnClose === 'boolean' &&
    typeof obj.groupChromeScale === 'number' &&
    obj.groupChromeScale > 0 &&
    typeof obj.theme === 'string' &&
    VALID_THEMES.includes(obj.theme) &&
    typeof obj.labelDisplay === 'string' &&
    VALID_LABEL_DISPLAYS.includes(obj.labelDisplay) &&
    (obj.shell === undefined ||
      (typeof obj.shell === 'string' && VALID_SHELLS.includes(obj.shell))) &&
    (obj.soundEnabled === undefined || typeof obj.soundEnabled === 'boolean')
  )
}

export function registerStoreHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.STORE_GET, async (_, key: string) => {
    switch (key) {
      case 'groups':
        return getGroups()
      case 'settings':
        return getSettings()
      default:
        return null
    }
  })

  ipcMain.handle(IPC_CHANNELS.STORE_SET, async (_, key: string, value: unknown) => {
    switch (key) {
      case 'groups': {
        if (!Array.isArray(value) || !value.every(isValidGroup)) {
          throw new Error('Invalid groups data')
        }
        setGroups(value)
        updateTrayMenu()
        break
      }
      case 'settings': {
        if (!isValidSettings(value)) {
          throw new Error('Invalid settings data')
        }
        setSettings(value)
        break
      }
    }
  })

  ipcMain.handle(IPC_CHANNELS.STORE_GET_ALL, async () => {
    return getAllData()
  })

  ipcMain.handle(IPC_CHANNELS.STORE_EXPORT, async () => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return false

    const result = await dialog.showSaveDialog(mainWindow, {
      title: 'Export Settings',
      defaultPath: 'program-manager-backup.json',
      filters: [{ name: 'JSON Files', extensions: ['json'] }]
    })

    if (result.canceled || !result.filePath) {
      return false
    }

    try {
      const data = getAllData()
      await writeFile(result.filePath, JSON.stringify(data, null, 2), 'utf-8')
      return true
    } catch (error) {
      console.error('Failed to export settings:', error)
      return false
    }
  })

  ipcMain.handle(IPC_CHANNELS.STORE_IMPORT, async () => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return { success: false, error: 'No window' }

    const result = await dialog.showOpenDialog(mainWindow, {
      title: 'Import Settings',
      filters: [{ name: 'JSON Files', extensions: ['json'] }],
      properties: ['openFile']
    })

    if (result.canceled || result.filePaths.length === 0) {
      return { success: false, error: 'Canceled' }
    }

    try {
      const content = await readFile(result.filePaths[0], 'utf-8')
      const data = JSON.parse(content) as StoreData

      // Validate structure
      if (!Array.isArray(data.groups) || !isValidSettings(data.settings)) {
        return { success: false, error: 'Invalid file format' }
      }

      if (!data.groups.every(isValidGroup)) {
        return { success: false, error: 'Invalid group or item data in file' }
      }

      setAllData(data)
      updateTrayMenu()
      return { success: true }
    } catch (error) {
      console.error('Failed to import settings:', error)
      return { success: false, error: 'Failed to read file' }
    }
  })
}
