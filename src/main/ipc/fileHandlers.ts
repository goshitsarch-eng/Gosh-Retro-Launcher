import { ipcMain, dialog } from 'electron'
import { access } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import { getMainWindow } from '../window'
import type { FileFilter } from '@shared/types'

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

  ipcMain.handle(IPC_CHANNELS.FILE_EXISTS, async (_, filePath: string) => {
    try {
      await access(filePath)
      return true
    } catch {
      return false
    }
  })
}
