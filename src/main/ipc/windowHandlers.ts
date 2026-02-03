import { ipcMain, app } from 'electron'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  minimizeMainWindow,
  maximizeMainWindow,
  closeMainWindow,
  isMaximized
} from '../window'

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

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_PLATFORM, () => {
    return process.platform
  })

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_VERSION, () => {
    return app.getVersion()
  })
}
