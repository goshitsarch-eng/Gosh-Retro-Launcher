import { ipcMain, dialog } from 'electron'
import { access, readFile, writeFile } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import { getMainWindow } from '../window'
import type { FileFilter, ProgramGroup } from '@shared/types'
import { parseWin31Grp, serializeWin31Grp } from '@shared/win31Grp'

function getExecutableFilters(): FileFilter[] {
  switch (process.platform) {
    case 'win32':
      return [
        { name: 'Executables', extensions: ['exe', 'bat', 'cmd', 'msi'] },
        { name: 'Shortcuts', extensions: ['lnk'] },
        { name: 'All Files', extensions: ['*'] }
      ]
    case 'darwin':
      return [
        { name: 'Applications', extensions: ['app'] },
        { name: 'All Files', extensions: ['*'] }
      ]
    case 'linux':
      return [
        { name: 'Desktop Entries', extensions: ['desktop'] },
        { name: 'Shell Scripts', extensions: ['sh'] },
        { name: 'All Files', extensions: ['*'] }
      ]
    default:
      return [{ name: 'All Files', extensions: ['*'] }]
  }
}

function getImageFilters(): FileFilter[] {
  return [
    { name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'ico', 'svg'] },
    { name: 'Icons', extensions: ['ico', 'icns'] },
    { name: 'All Files', extensions: ['*'] }
  ]
}

export function registerFileHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.FILE_SELECT_EXECUTABLE, async () => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return null

    const result = await dialog.showOpenDialog(mainWindow, {
      title: 'Select Program',
      filters: getExecutableFilters(),
      properties: ['openFile']
    })

    if (result.canceled || result.filePaths.length === 0) {
      return null
    }

    return result.filePaths[0]
  })

  ipcMain.handle(IPC_CHANNELS.FILE_SELECT_ICON, async () => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return null

    const result = await dialog.showOpenDialog(mainWindow, {
      title: 'Select Icon',
      filters: getImageFilters(),
      properties: ['openFile']
    })

    if (result.canceled || result.filePaths.length === 0) {
      return null
    }

    return result.filePaths[0]
  })

  ipcMain.handle(IPC_CHANNELS.FILE_IMPORT_GRP, async () => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return { success: false, error: 'No Program Manager window is available.' }
    const result = await dialog.showOpenDialog(mainWindow, {
      title: 'Import Program Manager Group',
      filters: [
        { name: 'Program Manager Groups', extensions: ['grp'] },
        { name: 'All Files', extensions: ['*'] }
      ],
      properties: ['openFile']
    })
    if (result.canceled || !result.filePaths[0]) return { success: false, error: 'Canceled' }
    try {
      const bytes = await readFile(result.filePaths[0])
      if (bytes.byteLength > 10 * 1024 * 1024) return { success: false, error: 'The .GRP file is too large.' }
      return { success: true, group: parseWin31Grp(bytes) }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  ipcMain.handle(IPC_CHANNELS.FILE_EXPORT_GRP, async (_, value: unknown) => {
    const mainWindow = getMainWindow()
    if (!mainWindow) return { success: false, error: 'No Program Manager window is available.' }
    if (typeof value !== 'object' || value === null || typeof (value as ProgramGroup).name !== 'string' ||
      !Array.isArray((value as ProgramGroup).items)) {
      return { success: false, error: 'Invalid program group.' }
    }
    const group = value as ProgramGroup
    const safeName = group.name.replace(/[<>:"/\\|?*]+/g, '-').trim() || 'program-group'
    const result = await dialog.showSaveDialog(mainWindow, {
      title: 'Export Program Manager Group',
      defaultPath: `${safeName}.grp`,
      filters: [{ name: 'Program Manager Groups', extensions: ['grp'] }]
    })
    if (result.canceled || !result.filePath) return { success: false, error: 'Canceled' }
    try {
      await writeFile(result.filePath, serializeWin31Grp(group))
      return { success: true }
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  ipcMain.handle(IPC_CHANNELS.FILE_EXISTS, async (_, filePath: string) => {
    try {
      await access(filePath)
      return true
    } catch {
      return false
    }
  })
}
