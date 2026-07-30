import { app, BrowserWindow, shell, screen, type Rectangle } from 'electron'
import { join } from 'path'
import { getSettings } from './store'
import type { DisplayWorkArea, HostWindowState, ShellType } from '@shared/types'
import { IPC_CHANNELS } from '@shared/constants/ipc'

let mainWindow: BrowserWindow | null = null
let launcherToolsWindow: BrowserWindow | null = null
let isQuitting = false
let displayListenersRegistered = false

function getHostWindowState(window: BrowserWindow): HostWindowState {
  return {
    focused: window.isFocused(),
    maximized: window.isMaximized(),
    minimized: window.isMinimized(),
    bounds: window.getBounds()
  }
}

function sendWindowState(window: BrowserWindow): void {
  if (window.isDestroyed() || window.webContents.isDestroyed()) return
  window.webContents.send(IPC_CHANNELS.WINDOW_STATE_CHANGED, getHostWindowState(window))
}

export function getActiveDisplayWorkArea(): DisplayWorkArea {
  const bounds = mainWindow && !mainWindow.isDestroyed()
    ? mainWindow.getBounds()
    : screen.getPrimaryDisplay().bounds
  const display = screen.getDisplayMatching(bounds)
  return {
    id: display.id,
    width: display.workAreaSize.width,
    height: display.workAreaSize.height,
    scaleFactor: display.scaleFactor
  }
}

function sendDisplayState(): void {
  if (!mainWindow || mainWindow.isDestroyed() || mainWindow.webContents.isDestroyed()) return
  mainWindow.webContents.send(IPC_CHANNELS.WINDOW_DISPLAY_CHANGED, getActiveDisplayWorkArea())
}

function ensureDisplayListeners(): void {
  if (displayListenersRegistered) return
  displayListenersRegistered = true
  screen.on('display-added', sendDisplayState)
  screen.on('display-removed', sendDisplayState)
  screen.on('display-metrics-changed', sendDisplayState)
}

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
  const settings = getSettings()
  const shellType = options.shell ?? settings.shell ?? 'win31'
  const useNativeFrame = usesNativeWindowFrame(shellType)
  const bounds = options.bounds
  let defaultWidth = 800
  let defaultHeight = 600
  if (!bounds && (shellType === 'win31' || shellType === 'win95')) {
    const workArea = screen.getPrimaryDisplay().workAreaSize
    const autoScale = Math.max(1, Math.min(4, Math.floor(Math.min(
      workArea.width / 640,
      workArea.height / 480
    ))))
    const preference = shellType === 'win31' ? settings.win31Scale : settings.win95Scale
    const scale = preference === 'auto' ? autoScale : preference
    defaultWidth = Math.min(workArea.width, 640 * scale)
    defaultHeight = Math.min(workArea.height, 480 * scale)
  }
  const browserWindow = new BrowserWindow({
    width: bounds?.width ?? defaultWidth,
    height: bounds?.height ?? defaultHeight,
    x: bounds?.x,
    y: bounds?.y,
    minWidth: 400,
    minHeight: 300,
    frame: useNativeFrame,
    // New Win95 windows size their emulated desktop by content pixels; saved
    // switch bounds remain outer-window bounds so recreation is lossless.
    useContentSize: shellType === 'win95' && !bounds,
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
  ensureDisplayListeners()

  // Handle window ready-to-show
  browserWindow.once('ready-to-show', () => {
    if (browserWindow.isDestroyed()) return
    if (options.maximized) browserWindow.maximize()
    browserWindow.show()
    sendWindowState(browserWindow)
    sendDisplayState()
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

  const notifyWindowState = (): void => sendWindowState(browserWindow)
  browserWindow.on('focus', notifyWindowState)
  browserWindow.on('blur', notifyWindowState)
  browserWindow.on('maximize', notifyWindowState)
  browserWindow.on('unmaximize', notifyWindowState)
  browserWindow.on('minimize', notifyWindowState)
  browserWindow.on('restore', notifyWindowState)
  browserWindow.on('resize', notifyWindowState)
  browserWindow.on('move', () => {
    sendWindowState(browserWindow)
    sendDisplayState()
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

export function createLauncherToolsWindow(): BrowserWindow {
  if (launcherToolsWindow && !launcherToolsWindow.isDestroyed()) {
    launcherToolsWindow.show()
    launcherToolsWindow.focus()
    return launcherToolsWindow
  }
  launcherToolsWindow = new BrowserWindow({
    width: 680,
    height: 720,
    minWidth: 560,
    minHeight: 520,
    title: 'Launcher Tools',
    frame: true,
    backgroundColor: '#c0c0c0',
    show: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  })
  const tools = launcherToolsWindow
  tools.once('ready-to-show', () => tools.show())
  tools.on('closed', () => { if (launcherToolsWindow === tools) launcherToolsWindow = null })
  tools.webContents.setWindowOpenHandler(({ url }) => {
    try {
      const parsed = new URL(url)
      if (parsed.protocol === 'http:' || parsed.protocol === 'https:') void shell.openExternal(url)
    } catch { /* Ignore malformed links. */ }
    return { action: 'deny' }
  })
  const isDev = !app.isPackaged
  if (isDev && process.env['ELECTRON_RENDERER_URL']) {
    const url = new URL(process.env['ELECTRON_RENDERER_URL'])
    url.searchParams.set('launcherTools', '1')
    void tools.loadURL(url.toString())
  } else {
    void tools.loadFile(join(__dirname, '../renderer/index.html'), { query: { launcherTools: '1' } })
  }
  return tools
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
