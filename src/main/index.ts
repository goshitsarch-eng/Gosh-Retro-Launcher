import { app, BrowserWindow, Menu, globalShortcut } from 'electron'
import { createWindow, getMainWindow, setQuitting } from './window'
import { registerIpcHandlers } from './ipc'
import { createTray } from './tray'
import { initStore } from './store'

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error)
})

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason)
})

function registerGlobalShortcuts(): void {
  // Register Quick Search shortcut
  const accelerator = process.platform === 'darwin'
    ? 'Cmd+Shift+Space'
    : 'Ctrl+Shift+Space'

  globalShortcut.register(accelerator, () => {
    const mainWindow = getMainWindow()
    if (mainWindow) {
      if (!mainWindow.isVisible()) {
        mainWindow.show()
      }
      mainWindow.webContents.send('quick-search:toggle')
    }
  })
}

app.whenReady().then(() => {
  // Disable native menu bar on all platforms
  Menu.setApplicationMenu(null)

  // Initialize store
  try {
    initStore()
  } catch (error) {
    console.error('Failed to initialize store, using defaults:', error)
  }

  // Register IPC handlers
  registerIpcHandlers()

  // Create main window
  createWindow()

  // Create system tray
  createTray()

  // Register global shortcuts
  registerGlobalShortcuts()

  app.on('activate', () => {
    // On macOS, re-create window when dock icon is clicked and no windows are open
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    } else {
      const mainWindow = getMainWindow()
      if (mainWindow) {
        mainWindow.show()
      }
    }
  })
})

app.on('window-all-closed', () => {
  // On macOS, apps typically stay active until explicitly quit
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('before-quit', () => {
  // Set quitting flag so window close handler allows actual close
  setQuitting(true)
})

app.on('will-quit', () => {
  // Unregister all shortcuts (only if app was ready)
  if (app.isReady()) {
    globalShortcut.unregisterAll()
  }
})

// Prevent multiple instances
const gotTheLock = app.requestSingleInstanceLock()
if (!gotTheLock) {
  app.quit()
} else {
  app.on('second-instance', () => {
    const mainWindow = getMainWindow()
    if (mainWindow) {
      if (mainWindow.isMinimized()) {
        mainWindow.restore()
      }
      mainWindow.show()
      mainWindow.focus()
    }
  })
}
