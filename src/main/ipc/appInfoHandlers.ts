import { ipcMain, app, nativeImage, shell, type NativeImage } from 'electron'
import { readFile } from 'fs/promises'
import { basename, dirname, extname, isAbsolute } from 'path'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { AppInfo } from '@shared/types'

const WFW_PALETTE = [
  [0, 0, 0], [128, 128, 128], [192, 192, 192], [255, 255, 255],
  [0, 0, 128], [0, 0, 255], [0, 128, 0], [0, 128, 128],
  [128, 0, 0], [128, 0, 128], [128, 128, 0], [255, 0, 0],
  [0, 255, 0], [255, 255, 0], [0, 255, 255], [255, 0, 255]
] as const

function paletteLimitedIcon(image: NativeImage): string | undefined {
  if (image.isEmpty()) return undefined
  const resized = image.resize({ width: 32, height: 32, quality: 'best' })
  const bitmap = Buffer.from(resized.toBitmap())
  for (let offset = 0; offset + 3 < bitmap.length; offset += 4) {
    if (bitmap[offset + 3] < 16) continue
    const blue = bitmap[offset]
    const green = bitmap[offset + 1]
    const red = bitmap[offset + 2]
    let best: readonly [number, number, number] = WFW_PALETTE[0]
    let distance = Number.POSITIVE_INFINITY
    for (const candidate of WFW_PALETTE) {
      const next = (red - candidate[0]) ** 2 + (green - candidate[1]) ** 2 + (blue - candidate[2]) ** 2
      if (next < distance) {
        best = candidate
        distance = next
      }
    }
    bitmap[offset] = best[2]
    bitmap[offset + 1] = best[1]
    bitmap[offset + 2] = best[0]
  }
  return nativeImage.createFromBitmap(bitmap, { width: 32, height: 32 }).toDataURL()
}

async function loadBestIcon(filePath: string): Promise<{ icon?: string; win31Icon?: string }> {
  try {
    const imageExtension = ['.png', '.jpg', '.jpeg', '.gif', '.ico', '.icns', '.webp', '.bmp'].includes(extname(filePath).toLowerCase())
    let image = imageExtension ? nativeImage.createFromPath(filePath) : await app.getFileIcon(filePath, { size: 'large' })
    if (image.isEmpty() && imageExtension) image = await app.getFileIcon(filePath, { size: 'large' })
    if (image.isEmpty()) return {}
    const fullSize = image.getSize()
    const full = fullSize.width === 128 && fullSize.height === 128
      ? image
      : image.resize({ width: 128, height: 128, quality: 'best' })
    return { icon: full.toDataURL(), win31Icon: paletteLimitedIcon(image) }
  } catch (error) {
    console.warn(`Failed to extract icon for ${filePath}:`, error)
    return {}
  }
}

async function getWindowsAppInfo(filePath: string): Promise<AppInfo> {
  const extension = extname(filePath).toLowerCase()
  if (extension === '.lnk') {
    try {
      const details = shell.readShortcutLink(filePath)
      const target = details.target || filePath
      return {
        name: basename(filePath, '.lnk'),
        path: target,
        ...(await loadBestIcon(target)),
        workingDir: details.cwd || dirname(target),
        ...(details.args ? { arguments: details.args } : {})
      }
    } catch (error) {
      console.warn('Failed to read Windows shortcut:', error)
    }
  }
  return {
    name: basename(filePath, extension),
    path: filePath,
    ...(await loadBestIcon(filePath)),
    workingDir: dirname(filePath)
  }
}

async function getDesktopEntry(filePath: string): Promise<AppInfo> {
  try {
    const lines = (await readFile(filePath, 'utf8')).split(/\r?\n/)
    let name = basename(filePath, '.desktop')
    let command = ''
    let iconPath = ''
    let inEntry = false
    for (const line of lines) {
      const value = line.trim()
      if (value === '[Desktop Entry]') { inEntry = true; continue }
      if (value.startsWith('[')) { inEntry = false; continue }
      if (!inEntry) continue
      if (value.startsWith('Name=')) name = value.slice(5)
      else if (value.startsWith('Exec=')) command = value.slice(5).replace(/%[fFuUdDnNickvm]/g, '').trim()
      else if (value.startsWith('Icon=')) iconPath = value.slice(5)
    }
    const first = command.startsWith('"')
      ? command.slice(1, command.indexOf('"', 1))
      : command.split(/\s+/)[0]
    const args = command.slice(command.startsWith('"') ? command.indexOf('"', 1) + 1 : first.length).trim()
    const iconTarget = iconPath && isAbsolute(iconPath) ? iconPath : filePath
    return {
      name,
      path: first || filePath,
      ...(await loadBestIcon(iconTarget)),
      ...(args ? { arguments: args } : {})
    }
  } catch {
    return { name: basename(filePath, '.desktop'), path: filePath, ...(await loadBestIcon(filePath)) }
  }
}

export async function getAppInfo(filePath: string): Promise<AppInfo> {
  const extension = extname(filePath).toLowerCase()
  try {
    if (process.platform === 'win32') return getWindowsAppInfo(filePath)
    if (process.platform === 'linux' && extension === '.desktop') return getDesktopEntry(filePath)
    return {
      name: basename(filePath, extension || undefined),
      path: filePath,
      ...(await loadBestIcon(filePath)),
      workingDir: extension ? dirname(filePath) : undefined
    }
  } catch (error) {
    console.error('Failed to get app info:', error)
    return { name: basename(filePath, extension || undefined), path: filePath }
  }
}

export function registerAppInfoHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.APP_GET_INFO, async (_, filePath: unknown) => {
    if (typeof filePath !== 'string' || !filePath) throw new Error('Invalid application path')
    return getAppInfo(filePath)
  })
}
