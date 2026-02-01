import { app, BrowserWindow, shell } from 'electron'
import { join } from 'path'
import { getSettings } from './store'

let mainWindow: BrowserWindow | null = null
let isQuitting = false

export function setQuitting(value: boolean): void {
  isQuitting = value
}

export function createWindow(): BrowserWindow {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    minWidth: 400,
    minHeight: 300,
    backgroundColor: '#008080', // Win 3.1 teal
    show: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  })

  // Handle window ready-to-show
  mainWindow.on('ready-to-show', () => {
    mainWindow?.show()
  })

  // Handle close behavior - minimize to tray instead of quitting (unless actually quitting)
  mainWindow.on('close', (event) => {
    const settings = getSettings()
    if (!isQuitting && settings.trayOnClose !== false) {
      event.preventDefault()
      mainWindow?.hide()
    }
  })

  // Open external links in browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  // Load the app
  const isDev = !app.isPackaged
  if (isDev && process.env['ELECTRON_RENDERER_URL']) {
    mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }

  // Open DevTools only when explicitly requested
  if (isDev && process.env['ELECTRON_OPEN_DEVTOOLS'] === '1') {
    mainWindow.webContents.openDevTools()
  }

  return mainWindow
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
