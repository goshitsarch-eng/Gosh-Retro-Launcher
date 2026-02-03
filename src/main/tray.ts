import { app, Tray, Menu, nativeImage } from 'electron'
import { join } from 'path'
import { showMainWindow } from './window'
import { getGroups } from './store'
import { launchProgram } from './ipc/launchHandlers'
import type { ProgramItem } from '@shared/types'

let tray: Tray | null = null

function getTrayIconPath(): string {
  const resourcesPath = app.isPackaged
    ? join(process.resourcesPath, 'assets', 'icons')
    : join(__dirname, '../../assets/icons')

  switch (process.platform) {
    case 'darwin':
      return join(resourcesPath, 'tray-macTemplate.png')
    case 'win32':
      return join(resourcesPath, 'tray-win.ico')
    default:
      return join(resourcesPath, 'tray-linux.png')
  }
}

function launchItem(item: ProgramItem): void {
  launchProgram(item).catch((err) => {
    console.error('Failed to launch item from tray:', err)
  })
}

function buildTrayMenu(): Menu {
  const groups = getGroups()

  const menuItems: Electron.MenuItemConstructorOptions[] = [
    {
      label: 'Show Program Manager',
      click: showMainWindow
    },
    { type: 'separator' }
  ]

  // Add groups as submenus
  if (groups.length > 0) {
    for (const group of groups) {
      if (group.items.length > 0) {
        menuItems.push({
          label: group.name,
          submenu: group.items.map((item) => ({
            label: item.name,
            click: () => launchItem(item)
          }))
        })
      } else {
        menuItems.push({
          label: group.name,
          enabled: false
        })
      }
    }
    menuItems.push({ type: 'separator' })
  }

  menuItems.push({
    label: 'Exit',
    click: () => app.quit()
  })

  return Menu.buildFromTemplate(menuItems)
}

export function createTray(): void {
  const iconPath = getTrayIconPath()
  let icon: Electron.NativeImage

  try {
    icon = nativeImage.createFromPath(iconPath)
    if (icon.isEmpty()) {
      // Create a simple fallback icon
      icon = nativeImage.createFromDataURL(
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAdgAAAHYBTnsmCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAABsSURBVDiNY2AYBaNgGAAGBgYGBgYmBnr6/0+GoAYDA8P/fwwM//8zMJChgYEB4gWYF8jRgOJiuBfI0YDhBXI0YHmBHA1YXiBHA44XyNGA5wVyNBB4gRwNRF4gRwORF8jRQOQFcjQQeQE5GgBz2DI0p5bf0QAAAABJRU5ErkJggg=='
      )
    }
  } catch {
    // Create fallback icon
    icon = nativeImage.createFromDataURL(
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAdgAAAHYBTnsmCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAABsSURBVDiNY2AYBaNgGAAGBgYGBgYmBnr6/0+GoAYDA8P/fwwM//8zMJChgYEB4gWYF8jRgOJiuBfI0YDhBXI0YHmBHA1YXiBHA44XyNGA5wVyNBB4gRwNRF4gRwORF8jRQOQFcjQQeQE5GgBz2DI0p5bf0QAAAABJRU5ErkJggg=='
    )
  }

  // On macOS, use template image for proper dark/light mode support
  if (process.platform === 'darwin') {
    icon.setTemplateImage(true)
  }

  tray = new Tray(icon)
  tray.setToolTip('Program Manager')
  tray.setContextMenu(buildTrayMenu())

  // Double-click to show window (Windows/Linux)
  if (process.platform !== 'darwin') {
    tray.on('double-click', showMainWindow)
  }
}

export function updateTrayMenu(): void {
  if (tray) {
    tray.setContextMenu(buildTrayMenu())
  }
}

export function destroyTray(): void {
  if (tray) {
    tray.destroy()
    tray = null
  }
}
