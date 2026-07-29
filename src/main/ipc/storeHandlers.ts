import { BrowserWindow, ipcMain, dialog, type WebContents } from 'electron'
import { writeFile, readFile, stat } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  getGroups,
  setGroups,
  getSettings,
  setSettings,
  getAllData,
  setAllData,
  getWorkspaceProfiles,
  setWorkspaceProfiles
} from '../store'
import { getMainWindow } from '../window'
import { updateTrayMenu } from '../tray'
import type { ProgramGroup, ProgramItem, AppSettings, StoreData, WindowState, WorkspaceProfile } from '@shared/types'
import { isWin31ScalePreference } from '@shared/types'
import { migrateStoreData } from '@shared/storeMigration'
import { createBackup, listBackups, readBackup } from '../backups'

const MAX_IMPORT_BYTES = 10 * 1024 * 1024 // 10MB

function notifyStoreChanged(sender?: WebContents): void {
  for (const window of BrowserWindow.getAllWindows()) {
    if (!window.isDestroyed() && window.webContents !== sender && !window.webContents.isDestroyed()) {
      window.webContents.send(IPC_CHANNELS.STORE_CHANGED)
    }
  }
}

function isPosition(value: unknown): boolean {
  if (typeof value !== 'object' || value === null) return false
  const position = value as Record<string, unknown>
  return typeof position.x === 'number' && Number.isFinite(position.x) &&
    typeof position.y === 'number' && Number.isFinite(position.y)
}

function isWindowState(value: unknown): value is WindowState {
  if (typeof value !== 'object' || value === null) return false
  const state = value as Record<string, unknown>
  return typeof state.x === 'number' && Number.isFinite(state.x) &&
    typeof state.y === 'number' && Number.isFinite(state.y) &&
    typeof state.width === 'number' && Number.isFinite(state.width) && state.width > 0 &&
    typeof state.height === 'number' && Number.isFinite(state.height) && state.height > 0 &&
    typeof state.minimized === 'boolean' && typeof state.maximized === 'boolean'
}

export function isValidItem(item: unknown): item is ProgramItem {
  if (typeof item !== 'object' || item === null) return false
  const obj = item as Record<string, unknown>
  return (
    typeof obj.id === 'string' &&
    typeof obj.name === 'string' &&
    typeof obj.path === 'string' &&
    typeof obj.icon === 'string' &&
    (obj.win31Icon === undefined || typeof obj.win31Icon === 'string') &&
    (obj.workingDir === undefined || typeof obj.workingDir === 'string') &&
    (obj.arguments === undefined || typeof obj.arguments === 'string') &&
    (obj.environment === undefined || typeof obj.environment === 'string') &&
    (obj.runMode === undefined || ['normal', 'minimized', 'maximized'].includes(obj.runMode as string)) &&
    (obj.launchGroup === undefined ||
      (typeof obj.launchGroup === 'number' && Number.isInteger(obj.launchGroup) && obj.launchGroup >= 0)) &&
    (obj.shortcutKey === undefined || typeof obj.shortcutKey === 'string') &&
    (obj.runMinimized === undefined || typeof obj.runMinimized === 'boolean') &&
    (obj.win31Position === undefined || isPosition(obj.win31Position))
  )
}

export function isValidGroup(group: unknown): group is ProgramGroup {
  if (typeof group !== 'object' || group === null) return false
  const obj = group as Record<string, unknown>
  const shellState = obj.shellWindowState as Record<string, unknown> | undefined
  const hasLegacyState = isWindowState(obj.windowState)
  const hasShellState = typeof shellState === 'object' && shellState !== null &&
    isWindowState(shellState.win31) && isWindowState(shellState.win95)
  return (
    typeof obj.id === 'string' &&
    typeof obj.name === 'string' &&
    typeof obj.icon === 'string' &&
    (hasLegacyState || hasShellState) &&
    (obj.win31IconPosition === undefined || isPosition(obj.win31IconPosition)) &&
    Array.isArray(obj.items) &&
    obj.items.every(isValidItem)
  )
}

const VALID_THEMES = ['light', 'dark']
const VALID_LABEL_DISPLAYS = ['wrap', 'ellipsis']
const VALID_SHELLS = ['win31', 'win95']

function isValidWorkspaceProfile(value: unknown): value is WorkspaceProfile {
  if (typeof value !== 'object' || value === null) return false
  const profile = value as Record<string, unknown>
  return typeof profile.id === 'string' && typeof profile.name === 'string' &&
    typeof profile.createdAt === 'string' && typeof profile.updatedAt === 'string' &&
    Array.isArray(profile.groups) && profile.groups.every(isValidGroup)
}

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
    (obj.win31Scale === undefined || isWin31ScalePreference(obj.win31Scale)) &&
    (obj.win31DesktopMode === undefined || typeof obj.win31DesktopMode === 'boolean') &&
    (obj.win31ProgramManagerMinimized === undefined || typeof obj.win31ProgramManagerMinimized === 'boolean') &&
    (obj.win31ProgramManagerBounds === undefined || (
      typeof obj.win31ProgramManagerBounds === 'object' && obj.win31ProgramManagerBounds !== null &&
      isPosition(obj.win31ProgramManagerBounds) &&
      typeof (obj.win31ProgramManagerBounds as Record<string, unknown>).width === 'number' &&
      Number.isFinite((obj.win31ProgramManagerBounds as Record<string, unknown>).width) &&
      ((obj.win31ProgramManagerBounds as Record<string, unknown>).width as number) >= 320 &&
      typeof (obj.win31ProgramManagerBounds as Record<string, unknown>).height === 'number' &&
      Number.isFinite((obj.win31ProgramManagerBounds as Record<string, unknown>).height) &&
      ((obj.win31ProgramManagerBounds as Record<string, unknown>).height as number) >= 240
    )) &&
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
      case 'workspaceProfiles':
        return getWorkspaceProfiles()
      default:
        return null
    }
  })

  ipcMain.handle(IPC_CHANNELS.STORE_SET, async (event, key: string, value: unknown) => {
    switch (key) {
      case 'groups': {
        if (!Array.isArray(value) || !value.every(isValidGroup)) {
          throw new Error('Invalid groups data')
        }
        setGroups(value)
        updateTrayMenu()
        notifyStoreChanged(event.sender)
        break
      }
      case 'settings': {
        if (!isValidSettings(value)) {
          throw new Error('Invalid settings data')
        }
        setSettings(value)
        notifyStoreChanged(event.sender)
        break
      }
      case 'workspaceProfiles': {
        if (!Array.isArray(value) || !value.every(isValidWorkspaceProfile)) {
          throw new Error('Invalid workspace profiles data')
        }
        setWorkspaceProfiles(value)
        notifyStoreChanged(event.sender)
        break
      }
    }
  })

  ipcMain.handle(IPC_CHANNELS.STORE_GET_ALL, async () => {
    return getAllData()
  })

  ipcMain.handle(IPC_CHANNELS.BACKUP_LIST, () => listBackups())

  ipcMain.handle(IPC_CHANNELS.BACKUP_CREATE, async (_, reason: unknown) => {
    const label = typeof reason === 'string' ? reason : 'manual'
    return createBackup(getAllData(), label, true)
  })

  ipcMain.handle(IPC_CHANNELS.BACKUP_RESTORE, async (event, id: unknown) => {
    if (typeof id !== 'string') return { success: false, error: 'Invalid backup identifier' }
    try {
      setAllData(await readBackup(id))
      updateTrayMenu()
      notifyStoreChanged(event.sender)
      return { success: true }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
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

  ipcMain.handle(IPC_CHANNELS.STORE_IMPORT, async (event) => {
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
      const importPath = result.filePaths[0]
      const fileStats = await stat(importPath)
      if (fileStats.size > MAX_IMPORT_BYTES) {
        return {
          success: false,
          error: `Import file is too large (max ${Math.round(MAX_IMPORT_BYTES / (1024 * 1024))}MB)`
        }
      }

      const content = await readFile(importPath, 'utf-8')
      const data = JSON.parse(content) as Partial<StoreData>

      // Validate before migration so malformed imports are not silently repaired.
      if (!Array.isArray(data.groups) || !isValidSettings(data.settings)) {
        return { success: false, error: 'Invalid file format' }
      }

      if (!data.groups.every(isValidGroup)) {
        return { success: false, error: 'Invalid group or item data in file' }
      }

      setAllData(migrateStoreData(data))
      updateTrayMenu()
      notifyStoreChanged(event.sender)
      return { success: true }
    } catch (error) {
      console.error('Failed to import settings:', error)
      return { success: false, error: 'Failed to read file' }
    }
  })
}
