import { app, BrowserWindow, shell, type Rectangle } from 'electron'
import { join } from 'path'
import { getSettings } from './store'
import type { ShellType } from '@shared/types'

let mainWindow: BrowserWindow | null = null
let isQuitting = false

interface CreateWindowOptions {
  shell?: ShellType
  bounds?: Rectangle
  maximized?: boolean
}

export function usesNativeWindowFrame(shellType: ShellType): boolean {
  return shellType !== 'win31'
}

export function setQuitting(value: boolean): void {
  isQuitting = value
}

export function createWindow(options: CreateWindowOptions = {}): BrowserWindow {
  const shellType = options.shell ?? getSettings().shell ?? 'win31'
  const useNativeFrame = usesNativeWindowFrame(shellType)
  const bounds = options.bounds
  const browserWindow = new BrowserWindow({
    width: bounds?.width ?? 800,
    height: bounds?.height ?? 600,
    x: bounds?.x,
    y: bounds?.y,
    minWidth: 400,
    minHeight: 300,
    frame: useNativeFrame,
    backgroundColor: shellType === 'win31' ? '#c0c0c0' : '#008080',
    show: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  })
  mainWindow = browserWindow

  // Handle window ready-to-show
  browserWindow.once('ready-to-show', () => {
    if (browserWindow.isDestroyed()) return
    if (options.maximized) browserWindow.maximize()
    browserWindow.show()
  })

  // Handle close behavior - minimize to tray instead of quitting (unless actually quitting)
  browserWindow.on('close', (event) => {
    const settings = getSettings()
    if (!isQuitting && settings.trayOnClose !== false) {
      event.preventDefault()
      browserWindow.hide()
    }
  })

  browserWindow.on('closed', () => {
    if (mainWindow === browserWindow) mainWindow = null
  })

  // Open external links in browser (only allow http/https protocols)
  browserWindow.webContents.setWindowOpenHandler(({ url }) => {
    try {
      const parsed = new URL(url)
      if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
        void shell.openExternal(url)
      }
    } catch {
      // Invalid URL, ignore
    }
    return { action: 'deny' }
  })

  // Load the app
  const isDev = !app.isPackaged
  if (isDev && process.env['ELECTRON_RENDERER_URL']) {
    void browserWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    void browserWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }

  // Open DevTools only when explicitly requested
  if (isDev && process.env['ELECTRON_OPEN_DEVTOOLS'] === '1') {
    browserWindow.webContents.openDevTools()
  }

  return browserWindow
}

export function recreateWindowForShell(shellType: ShellType): BrowserWindow {
  const previousWindow = mainWindow
  const maximized = previousWindow?.isMaximized() ?? false
  const bounds = previousWindow && !previousWindow.isDestroyed()
    ? maximized ? previousWindow.getNormalBounds() : previousWindow.getBounds()
    : undefined

  if (previousWindow && !previousWindow.isDestroyed()) {
    // destroy() intentionally bypasses close-to-tray interception. The tray itself
    // remains alive and is reused by the replacement BrowserWindow.
    previousWindow.destroy()
  }

  return createWindow({ shell: shellType, bounds, maximized })
}

export function getMainWindow(): BrowserWindow | null {
  return mainWindow
}

export function showMainWindow(): void {
  if (mainWindow) {
    if (mainWindow.isMinimized()) {
      mainWindow.restore()
    }
    mainWindow.show()
    mainWindow.focus()
  }
}

export function hideMainWindow(): void {
  mainWindow?.hide()
}

export function minimizeMainWindow(): void {
  mainWindow?.minimize()
}

export function maximizeMainWindow(): void {
  if (mainWindow) {
    if (mainWindow.isMaximized()) {
      mainWindow.unmaximize()
    } else {
      mainWindow.maximize()
    }
  }
}

export function isMaximized(): boolean {
  return mainWindow?.isMaximized() ?? false
}

export function closeMainWindow(): void {
  mainWindow?.close()
}
