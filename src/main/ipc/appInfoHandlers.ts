import { ipcMain, app, nativeImage, shell } from 'electron'
import { readFile } from 'fs/promises'
import { basename, dirname, extname } from 'path'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { AppInfo } from '@shared/types'

/**
 * Extract app info from a macOS .app bundle
 */
async function getMacAppInfo(appPath: string): Promise<AppInfo> {
  const name = basename(appPath, '.app')
  let icon: string | undefined

  try {
    // Get app icon using Electron's app.getFileIcon
    const image = await app.getFileIcon(appPath, { size: 'normal' })
    if (image && !image.isEmpty()) {
      icon = image.toDataURL()
    }
  } catch (e) {
    console.warn('Failed to extract macOS app icon:', e)
  }

  return { name, path: appPath, icon }
}

/**
 * Extract app info from Windows executables and shortcuts
 */
async function getWindowsAppInfo(filePath: string): Promise<AppInfo> {
  const ext = extname(filePath).toLowerCase()

  if (ext === '.lnk') {
    try {
      // Use Electron's shell.readShortcutLink to resolve Windows shortcuts
      const details = shell.readShortcutLink(filePath)
      const name = basename(filePath, '.lnk')

      let icon: string | undefined
      try {
        const targetPath = details.target || filePath
        const image = await app.getFileIcon(targetPath, { size: 'normal' })
        if (image && !image.isEmpty()) {
          icon = image.toDataURL()
        }
      } catch (e) {
        console.warn('Failed to extract Windows shortcut icon:', e)
      }

      return {
        name,
        path: details.target || filePath,
        icon,
        workingDir: details.cwd || dirname(details.target || filePath)
      }
    } catch (e) {
      console.warn('Failed to read Windows shortcut:', e)
      // Fall through to default handling
    }
  }

  // For .exe, .bat, .cmd, .msi files
  const name = basename(filePath, ext)
  let icon: string | undefined

  try {
    const image = await app.getFileIcon(filePath, { size: 'normal' })
    if (image && !image.isEmpty()) {
      icon = image.toDataURL()
    }
  } catch (e) {
    console.warn('Failed to extract executable icon:', e)
  }

  return { name, path: filePath, icon, workingDir: dirname(filePath) }
}

/**
 * Extract app info from Linux .desktop files or executables
 */
async function getLinuxAppInfo(filePath: string): Promise<AppInfo> {
  if (!filePath.endsWith('.desktop')) {
    // For regular executables
    const name = basename(filePath)
    let icon: string | undefined

    try {
      const image = await app.getFileIcon(filePath, { size: 'normal' })
      if (image && !image.isEmpty()) {
        icon = image.toDataURL()
      }
    } catch (e) {
      console.warn('Failed to extract Linux executable icon:', e)
    }

    return { name, path: filePath, icon, workingDir: dirname(filePath) }
  }

  // Parse .desktop file
  try {
    const content = await readFile(filePath, 'utf-8')
    const lines = content.split('\n')

    let name = basename(filePath, '.desktop')
    let exec = ''
    let iconPath = ''
    let inDesktopEntry = false

    for (const line of lines) {
      const trimmed = line.trim()

      if (trimmed === '[Desktop Entry]') {
        inDesktopEntry = true
        continue
      }
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        inDesktopEntry = false
        continue
      }
      if (!inDesktopEntry) continue

      if (trimmed.startsWith('Name=')) {
        name = trimmed.substring(5)
      } else if (trimmed.startsWith('Exec=')) {
        // Remove field codes like %f, %F, %u, %U, etc.
        exec = trimmed
          .substring(5)
          .replace(/%[fFuUdDnNickvm]/g, '')
          .trim()
      } else if (trimmed.startsWith('Icon=')) {
        iconPath = trimmed.substring(5)
      }
    }

    let icon: string | undefined
    if (iconPath) {
      try {
        // Try to load icon if it's an absolute path
        if (iconPath.startsWith('/')) {
          const image = nativeImage.createFromPath(iconPath)
          if (!image.isEmpty()) {
            icon = image.toDataURL()
          }
        }
        // For icon names without paths, we'd need to search icon themes
        // which is complex, so we skip that for now
      } catch (e) {
        console.warn('Failed to load Linux desktop icon:', e)
      }
    }

    return { name, path: exec || filePath, icon }
  } catch (e) {
    console.warn('Failed to parse .desktop file:', e)
    return {
      name: basename(filePath, '.desktop'),
      path: filePath
    }
  }
}

/**
 * Get app info based on platform
 */
async function getAppInfo(filePath: string): Promise<AppInfo> {
  try {
    switch (process.platform) {
      case 'darwin': {
        if (filePath.endsWith('.app')) {
          return await getMacAppInfo(filePath)
        }
        // For other files on macOS, try to get icon
        const name = basename(filePath).replace(/\.[^/.]+$/, '')
        let icon: string | undefined
        try {
          const image = await app.getFileIcon(filePath, { size: 'normal' })
          if (image && !image.isEmpty()) {
            icon = image.toDataURL()
          }
        } catch (e) {
          // Ignore
        }
        return { name, path: filePath, icon }
      }

      case 'win32': {
        const ext = extname(filePath).toLowerCase()
        if (['.lnk', '.exe', '.bat', '.cmd', '.msi'].includes(ext)) {
          return await getWindowsAppInfo(filePath)
        }
        // For other files on Windows
        const name = basename(filePath).replace(/\.[^/.]+$/, '')
        let icon: string | undefined
        try {
          const image = await app.getFileIcon(filePath, { size: 'normal' })
          if (image && !image.isEmpty()) {
            icon = image.toDataURL()
          }
        } catch (e) {
          // Ignore
        }
        return { name, path: filePath, icon }
      }

      case 'linux': {
        return await getLinuxAppInfo(filePath)
      }

      default: {
        // Default fallback for unknown platforms
        return {
          name: basename(filePath).replace(/\.[^/.]+$/, ''),
          path: filePath
        }
      }
    }
  } catch (error) {
    console.error('Failed to get app info:', error)
    return {
      name: basename(filePath).replace(/\.[^/.]+$/, ''),
      path: filePath
    }
  }
}

/**
 * Register IPC handlers for app info extraction
 */
export function registerAppInfoHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.APP_GET_INFO, async (_, filePath: string) => {
    return await getAppInfo(filePath)
  })
}
