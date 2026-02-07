// Shared type definitions used across main, preload, and renderer

export interface ProgramItem {
  id: string
  name: string
  path: string
  icon: string
  workingDir: string
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
  labelDisplay: 'wrap' | 'ellipsis'
  shell: ShellType
  soundEnabled: boolean
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
  theme: 'light',
  labelDisplay: 'wrap',
  shell: 'win31',
  soundEnabled: true
}

export const DEFAULT_WINDOW_STATE: WindowState = {
  x: 20,
  y: 20,
  width: 300,
  height: 200,
  minimized: false,
  maximized: false
}

// Shell type for pluggable UI shells
export type ShellType = 'win31' | 'win95'

// Platform type for cross-platform handling
export type Platform = 'win32' | 'darwin' | 'linux'

// App info extracted from dropped/browsed files
export interface AppInfo {
  name: string
  path: string
  icon?: string // data URL or icon ID
  workingDir?: string
}

// File filter for dialog boxes
export interface FileFilter {
  name: string
  extensions: string[]
}

