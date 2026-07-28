import { ipcMain, app } from 'electron'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  minimizeMainWindow,
  maximizeMainWindow,
  closeMainWindow,
  isMaximized,
  recreateWindowForShell
} from '../window'
import { getSettings } from '../store'
import type { ShellType } from '@shared/types'

export function isValidShellFrameRequest(value: unknown): value is ShellType {
  return value === 'win31' || value === 'win95'
}

export function registerWindowHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.WINDOW_MINIMIZE, () => {
    minimizeMainWindow()
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_MAXIMIZE, () => {
    maximizeMainWindow()
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_CLOSE, () => {
    closeMainWindow()
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_QUIT, () => {
    app.quit()
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_IS_MAXIMIZED, () => {
    return isMaximized()
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_RECREATE_FOR_SHELL, (_, requestedShell: unknown) => {
    if (!isValidShellFrameRequest(requestedShell)) {
      throw new Error('Invalid shell frame request')
    }
    const shellType = requestedShell
    if ((getSettings().shell ?? 'win31') !== shellType) {
      throw new Error('Shell setting must be saved before recreating the window')
    }
    recreateWindowForShell(shellType)
    return true
  })

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_PLATFORM, () => {
    return process.platform
  })

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_VERSION, () => {
    return app.getVersion()
  })
}
