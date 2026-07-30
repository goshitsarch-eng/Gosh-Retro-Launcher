// Shared type definitions used across main, preload, and renderer

export type ShellType = 'win31' | 'win95'
export type Platform = 'win32' | 'darwin' | 'linux'
export type Win31ScalePreference = 'auto' | 1 | 2 | 3 | 4
export type Win95ScalePreference = 'auto' | 1 | 2 | 3 | 4
export const WIN31_SCALE_FACTORS = [1, 2, 3, 4] as const
export const WIN95_SCALE_FACTORS = [1, 2, 3, 4] as const

export function isWin31ScalePreference(value: unknown): value is Win31ScalePreference {
  return value === 'auto' || WIN31_SCALE_FACTORS.includes(value as 1 | 2 | 3 | 4)
}

export function isWin95ScalePreference(value: unknown): value is Win95ScalePreference {
  return value === 'auto' || WIN95_SCALE_FACTORS.includes(value as 1 | 2 | 3 | 4)
}

export interface LogicalPosition {
  x: number
  y: number
}

export interface LogicalRect extends LogicalPosition {
  width: number
  height: number
}

export type ProgramRunMode = 'normal' | 'minimized' | 'maximized'

export interface ProgramItem {
  id: string
  name: string
  path: string
  icon: string
  /** Palette-limited icon used only by the WfW shell. */
  win31Icon?: string
  workingDir: string
  arguments?: string
  /** Newline-delimited KEY=VALUE entries. */
  environment?: string
  runMode?: ProgramRunMode
  launchGroup?: number
  /** WfW-compatible metadata. Unsupported hosts retain it without acting on it. */
  shortcutKey?: string
  runMinimized?: boolean
  /** Unscaled WfW Program Manager coordinates used when Auto Arrange is off. */
  win31Position?: LogicalPosition
  /** Unscaled Win95 Icon/Small Icon view coordinates used when Auto Arrange is off. */
  win95Position?: LogicalPosition
}

export interface WindowState {
  x: number
  y: number
  width: number
  height: number
  minimized: boolean
  maximized: boolean
  restoreX?: number
  restoreY?: number
  restoreWidth?: number
  restoreHeight?: number
}

export interface ShellWindowState {
  win31: WindowState
  win95: WindowState
}

export interface ProgramGroup {
  id: string
  name: string
  icon: string
  /**
   * Legacy geometry retained in exports for one-way compatibility. Runtime
   * shell code must use shellWindowState instead.
   */
  windowState: WindowState
  shellWindowState: ShellWindowState
  win31IconPosition?: LogicalPosition
  items: ProgramItem[]
}

export interface WorkspaceProfile {
  id: string
  name: string
  groups: ProgramGroup[]
  createdAt: string
  updatedAt: string
}

export interface BackupInfo {
  id: string
  createdAt: string
  reason: string
  size: number
}

export interface AppSettings {
  autoArrange: boolean
  minimizeOnUse: boolean
  saveSettingsOnExit: boolean
  launchDelay: number
  trayOnClose: boolean
  /** Legacy fractional Win95 caption option retained for saved-data compatibility; RTM shell ignores it. */
  groupChromeScale: number
  /** WfW shell-owned whole-UI scale. */
  win31Scale: Win31ScalePreference
  /** Windows 95 shell-owned whole-UI scale. */
  win95Scale: Win95ScalePreference
  /** Unscaled manual positions for shell-owned Win95 desktop objects. */
  win95DesktopIconPositions: Record<string, LogicalPosition>
  /** Show the gray WfW desktop around an internal Program Manager window. */
  win31DesktopMode: boolean
  win31ProgramManagerBounds: LogicalRect
  win31ProgramManagerMinimized: boolean
  theme: 'light' | 'dark'
  labelDisplay: 'wrap' | 'ellipsis'
  shell: ShellType
  soundEnabled: boolean
}

export interface StoreData {
  schemaVersion: number
  groups: ProgramGroup[]
  settings: AppSettings
  workspaceProfiles: WorkspaceProfile[]
}

export const CURRENT_SCHEMA_VERSION = 5

export const DEFAULT_SETTINGS: AppSettings = {
  autoArrange: true,
  minimizeOnUse: false,
  saveSettingsOnExit: true,
  launchDelay: 500,
  trayOnClose: true,
  groupChromeScale: 1,
  win31Scale: 'auto',
  win95Scale: 'auto',
  win95DesktopIconPositions: {},
  win31DesktopMode: false,
  win31ProgramManagerBounds: { x: 68, y: 49, width: 511, height: 335 },
  win31ProgramManagerMinimized: false,
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

export function cloneWindowState(state: WindowState = DEFAULT_WINDOW_STATE): WindowState {
  return { ...state }
}

export function createShellWindowState(state: WindowState = DEFAULT_WINDOW_STATE): ShellWindowState {
  return {
    win31: cloneWindowState(state),
    win95: cloneWindowState(state)
  }
}

export function getGroupWindowState(group: ProgramGroup, shell: ShellType): WindowState {
  return group.shellWindowState?.[shell] ?? group.windowState ?? DEFAULT_WINDOW_STATE
}

// App info extracted from dropped/browsed files
export interface AppInfo {
  name: string
  path: string
  icon?: string // full-colour data URL or icon ID
  win31Icon?: string // palette-limited data URL
  workingDir?: string
  arguments?: string
}

export interface GrpImportResult {
  success: boolean
  group?: ProgramGroup
  error?: string
}

export interface DisplayWorkArea {
  id: number
  width: number
  height: number
  scaleFactor: number
}

export interface HostWindowBounds {
  x: number
  y: number
  width: number
  height: number
}

export interface HostWindowState {
  focused: boolean
  maximized: boolean
  minimized: boolean
  bounds: HostWindowBounds
}

// File filter for dialog boxes
export interface FileFilter {
  name: string
  extensions: string[]
}
