import {
  CURRENT_SCHEMA_VERSION,
  DEFAULT_SETTINGS,
  DEFAULT_WINDOW_STATE,
  createShellWindowState,
  isWin31ScalePreference,
  isWin95ScalePreference,
  type AppSettings,
  type LogicalPosition,
  type ProgramGroup,
  type ProgramItem,
  type ProgramRunMode,
  type ShellWindowState,
  type StoreData,
  type WorkspaceProfile,
  type WindowState
} from './types'

function finite(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function normalizeWindowState(value: unknown): WindowState {
  const candidate = typeof value === 'object' && value !== null
    ? value as Partial<Record<keyof WindowState, unknown>>
    : {}
  return {
    x: finite(candidate.x, DEFAULT_WINDOW_STATE.x),
    y: finite(candidate.y, DEFAULT_WINDOW_STATE.y),
    width: Math.max(150, finite(candidate.width, DEFAULT_WINDOW_STATE.width)),
    height: Math.max(92, finite(candidate.height, DEFAULT_WINDOW_STATE.height)),
    minimized: typeof candidate.minimized === 'boolean' ? candidate.minimized : false,
    maximized: typeof candidate.maximized === 'boolean' ? candidate.maximized : false,
    ...(typeof candidate.restoreX === 'number' ? { restoreX: candidate.restoreX } : {}),
    ...(typeof candidate.restoreY === 'number' ? { restoreY: candidate.restoreY } : {}),
    ...(typeof candidate.restoreWidth === 'number' ? { restoreWidth: candidate.restoreWidth } : {}),
    ...(typeof candidate.restoreHeight === 'number' ? { restoreHeight: candidate.restoreHeight } : {})
  }
}

function normalizePosition(value: unknown): LogicalPosition | undefined {
  if (typeof value !== 'object' || value === null) return undefined
  const candidate = value as Record<string, unknown>
  if (typeof candidate.x !== 'number' || !Number.isFinite(candidate.x)) return undefined
  if (typeof candidate.y !== 'number' || !Number.isFinite(candidate.y)) return undefined
  return { x: candidate.x, y: candidate.y }
}

function normalizePositionMap(value: unknown): Record<string, LogicalPosition> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return {}
  return Object.fromEntries(Object.entries(value)
    .map(([key, position]) => [key, normalizePosition(position)] as const)
    .filter((entry): entry is [string, LogicalPosition] => entry[1] !== undefined))
}

function normalizeItem(value: unknown): ProgramItem | null {
  if (typeof value !== 'object' || value === null) return null
  const item = value as Record<string, unknown>
  if (typeof item.id !== 'string' || typeof item.name !== 'string' || typeof item.path !== 'string') {
    return null
  }
  return {
    id: item.id,
    name: item.name,
    path: item.path,
    icon: typeof item.icon === 'string' ? item.icon : 'default',
    ...(typeof item.win31Icon === 'string' ? { win31Icon: item.win31Icon } : {}),
    workingDir: typeof item.workingDir === 'string' ? item.workingDir : '',
    ...(typeof item.arguments === 'string' ? { arguments: item.arguments } : {}),
    ...(typeof item.environment === 'string' ? { environment: item.environment } : {}),
    ...(['normal', 'minimized', 'maximized'].includes(item.runMode as string)
      ? { runMode: item.runMode as ProgramRunMode }
      : {}),
    ...(typeof item.launchGroup === 'number' ? { launchGroup: item.launchGroup } : {}),
    ...(typeof item.shortcutKey === 'string' ? { shortcutKey: item.shortcutKey } : {}),
    ...(typeof item.runMinimized === 'boolean' ? { runMinimized: item.runMinimized } : {}),
    ...(normalizePosition(item.win31Position)
      ? { win31Position: normalizePosition(item.win31Position) }
      : {}),
    ...(normalizePosition(item.win95Position)
      ? { win95Position: normalizePosition(item.win95Position) }
      : {})
  }
}

function normalizeShellWindowState(value: unknown, legacy: WindowState): ShellWindowState {
  if (typeof value !== 'object' || value === null) return createShellWindowState(legacy)
  const states = value as Record<string, unknown>
  return {
    win31: normalizeWindowState(states.win31 ?? legacy),
    win95: normalizeWindowState(states.win95 ?? legacy)
  }
}

function normalizeGroup(value: unknown): ProgramGroup | null {
  if (typeof value !== 'object' || value === null) return null
  const group = value as Record<string, unknown>
  if (typeof group.id !== 'string' || typeof group.name !== 'string') return null
  const legacy = normalizeWindowState(group.windowState)
  const shellWindowState = normalizeShellWindowState(group.shellWindowState, legacy)
  const items = Array.isArray(group.items)
    ? group.items.map(normalizeItem).filter((item): item is ProgramItem => item !== null)
    : []
  const iconPosition = normalizePosition(group.win31IconPosition)
  return {
    id: group.id,
    name: group.name,
    icon: typeof group.icon === 'string' ? group.icon : 'folder',
    // Keep a deterministic legacy value without allowing either shell to read it.
    windowState: { ...shellWindowState.win31 },
    shellWindowState,
    ...(iconPosition ? { win31IconPosition: iconPosition } : {}),
    items
  }
}

function normalizeProfile(value: unknown): WorkspaceProfile | null {
  if (typeof value !== 'object' || value === null) return null
  const profile = value as Record<string, unknown>
  if (typeof profile.id !== 'string' || typeof profile.name !== 'string') return null
  const groups = Array.isArray(profile.groups)
    ? profile.groups.map(normalizeGroup).filter((group): group is ProgramGroup => group !== null)
    : []
  const now = new Date(0).toISOString()
  return {
    id: profile.id,
    name: profile.name,
    groups,
    createdAt: typeof profile.createdAt === 'string' ? profile.createdAt : now,
    updatedAt: typeof profile.updatedAt === 'string' ? profile.updatedAt : now
  }
}

export function migrateStoreData(value: unknown): StoreData {
  const data = typeof value === 'object' && value !== null
    ? value as Record<string, unknown>
    : {}
  const rawSettings = typeof data.settings === 'object' && data.settings !== null
    ? data.settings as Partial<AppSettings>
    : {}
  const settings: AppSettings = {
    ...DEFAULT_SETTINGS,
    ...rawSettings,
    win31Scale: isWin31ScalePreference(rawSettings.win31Scale)
      ? rawSettings.win31Scale
      : 'auto',
    win95Scale: isWin95ScalePreference(rawSettings.win95Scale)
      ? rawSettings.win95Scale
      : 'auto',
    win95DesktopIconPositions: normalizePositionMap(rawSettings.win95DesktopIconPositions),
    win31DesktopMode: typeof rawSettings.win31DesktopMode === 'boolean'
      ? rawSettings.win31DesktopMode
      : false,
    win31ProgramManagerBounds: {
      x: finite(rawSettings.win31ProgramManagerBounds?.x, DEFAULT_SETTINGS.win31ProgramManagerBounds.x),
      y: finite(rawSettings.win31ProgramManagerBounds?.y, DEFAULT_SETTINGS.win31ProgramManagerBounds.y),
      width: Math.max(320, finite(rawSettings.win31ProgramManagerBounds?.width, DEFAULT_SETTINGS.win31ProgramManagerBounds.width)),
      height: Math.max(240, finite(rawSettings.win31ProgramManagerBounds?.height, DEFAULT_SETTINGS.win31ProgramManagerBounds.height))
    },
    win31ProgramManagerMinimized: typeof rawSettings.win31ProgramManagerMinimized === 'boolean'
      ? rawSettings.win31ProgramManagerMinimized
      : false
  }
  const groups = Array.isArray(data.groups)
    ? data.groups.map(normalizeGroup).filter((group): group is ProgramGroup => group !== null)
    : []
  const workspaceProfiles = Array.isArray(data.workspaceProfiles)
    ? data.workspaceProfiles.map(normalizeProfile).filter((profile): profile is WorkspaceProfile => profile !== null)
    : []
  return {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    groups,
    settings,
    workspaceProfiles
  }
}
