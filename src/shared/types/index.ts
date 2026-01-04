// Shared type definitions used across main, preload, and renderer

export interface ProgramItem {
  id: string
  name: string
  path: string
  icon: string
  workingDir: string
  shortcutKey: string
  launchGroup?: number
}

export interface WindowState {
  x: number
  y: number
  width: number
  height: number
  minimized: boolean
  maximized: boolean
}

export interface ProgramGroup {
  id: string
  name: string
  icon: string
  windowState: WindowState
  items: ProgramItem[]
}

export interface AppSettings {
  autoArrange: boolean
  minimizeOnUse: boolean
  saveSettingsOnExit: boolean
  launchDelay: number
  trayOnClose: boolean
  groupChromeScale: number
  theme: 'light' | 'dark'
}

export interface StoreData {
  groups: ProgramGroup[]
  settings: AppSettings
}

export const DEFAULT_SETTINGS: AppSettings = {
  autoArrange: true,
  minimizeOnUse: false,
  saveSettingsOnExit: true,
  launchDelay: 500,
  trayOnClose: true,
  groupChromeScale: 1,
  theme: 'light'
}

export const DEFAULT_WINDOW_STATE: WindowState = {
  x: 20,
  y: 20,
  width: 300,
  height: 200,
  minimized: false,
  maximized: false
}

// Platform type for cross-platform handling
export type Platform = 'win32' | 'darwin' | 'linux'

// File filter types for dialogs
export interface FileFilter {
  name: string
  extensions: string[]
}
