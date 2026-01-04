import { ipcMain, dialog } from 'electron'
import { writeFileSync, readFileSync } from 'fs'
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
import type { ProgramGroup, AppSettings, StoreData } from '@shared/types'

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
      case 'groups':
        setGroups(value as ProgramGroup[])
        break
      case 'settings':
        setSettings(value as AppSettings)
        break
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
      writeFileSync(result.filePath, JSON.stringify(data, null, 2), 'utf-8')
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
      const content = readFileSync(result.filePaths[0], 'utf-8')
      const data = JSON.parse(content) as StoreData

      // Validate structure
      if (!Array.isArray(data.groups) || typeof data.settings !== 'object') {
        return { success: false, error: 'Invalid file format' }
      }

      setAllData(data)
      return { success: true }
    } catch (error) {
      console.error('Failed to import settings:', error)
      return { success: false, error: 'Failed to read file' }
    }
  })
}
