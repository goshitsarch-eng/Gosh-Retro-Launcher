import { ipcMain, app } from 'electron'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  minimizeMainWindow,
  maximizeMainWindow,
  closeMainWindow,
  isMaximized,
  recreateWindowForShell,
  getMainWindow,
  getActiveDisplayWorkArea,
  createLauncherToolsWindow
} from '../window'
import { getSettings } from '../store'
import type { HostWindowBounds, ShellType } from '@shared/types'

function isHostWindowBounds(value: unknown): value is HostWindowBounds {
  if (typeof value !== 'object' || value === null) return false
  const bounds = value as Record<string, unknown>
  return ['x', 'y', 'width', 'height'].every((key) =>
    typeof bounds[key] === 'number' && Number.isFinite(bounds[key])) &&
    (bounds.width as number) >= 400 && (bounds.height as number) >= 300
}

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

  ipcMain.handle(IPC_CHANNELS.WINDOW_GET_BOUNDS, () => {
    return getMainWindow()?.getBounds() ?? { x: 0, y: 0, width: 800, height: 600 }
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_SET_BOUNDS, (_, requestedBounds: unknown) => {
    if (!isHostWindowBounds(requestedBounds)) throw new Error('Invalid window bounds')
    getMainWindow()?.setBounds(requestedBounds)
    return true
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_GET_DISPLAY_WORK_AREA, () => {
    return getActiveDisplayWorkArea()
  })

  ipcMain.handle(IPC_CHANNELS.APP_OPEN_LAUNCHER_TOOLS, () => {
    createLauncherToolsWindow()
    return true
  })

  ipcMain.handle(IPC_CHANNELS.WINDOW_RECREATE_FOR_SHELL, (_, requestedShell: unknown) => {
    if (!isValidShellFrameRequest(requestedShell)) {
      throw new Error('Invalid shell frame request')
    }
    const shellType = requestedShell
    if ((getSettings().shell ?? 'win31') !== shellType) {
      throw new Error('Shell setting must be saved before recreating the window')
    }
    // Reply to the invoking renderer before destroying its BrowserWindow.
    // Destroying synchronously can reject the invoke promise and make the
    // renderer's shell-switch transaction roll its saved setting back.
    setImmediate(() => recreateWindowForShell(shellType))
    return true
  })

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_PLATFORM, () => {
    return process.platform
  })

  ipcMain.handle(IPC_CHANNELS.SYSTEM_GET_VERSION, () => {
    return app.getVersion()
  })
}
