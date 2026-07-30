import { resolveWin95RasterVariant, type Win95ScaleFactor } from './tokens'

const iconModules = import.meta.glob('../../assets/win95/{large,small}/*.png', {
  eager: true,
  query: '?url',
  import: 'default'
}) as Record<string, string>

// Optional, gitignored resource pack extracted from the user's own licensed
// Windows 95 RTM media. Distributable builds fall back to the clean-room set.
const originalIconModules = import.meta.glob('../../assets/win95-rtm-local/{large,small}/*.png', {
  eager: true,
  query: '?url',
  import: 'default'
}) as Record<string, string>

export const WIN95_ICON_IDS = [
  'my-computer', 'network-neighborhood', 'recycle-empty', 'recycle-full',
  'folder', 'folder-open', 'programs', 'documents', 'settings',
  'control-panel', 'find', 'help', 'run', 'shutdown', 'windows-logo',
  'application', 'url', 'drive', 'printers', 'taskbar', 'warning',
  'information', 'question', 'critical', 'new-shortcut', 'properties'
] as const

export type Win95IconId = (typeof WIN95_ICON_IDS)[number]
export type Win95IconSize = 'small' | 'large'

let runtimeScale: Win95ScaleFactor = 1
export function setWin95RuntimeScale(scale: Win95ScaleFactor): void { runtimeScale = scale }

const aliases: Record<string, Win95IconId> = {
  default: 'application',
  'default-item.png': 'application',
  folder: 'folder',
  group: 'folder',
  'folder.png': 'folder',
  'folder-open': 'folder-open',
  document: 'documents',
  book: 'documents',
  settings: 'settings',
  gear: 'settings',
  search: 'find',
  question: 'question',
  'question.png': 'question',
  information: 'information',
  warning: 'warning',
  error: 'critical',
  critical: 'critical',
  stop: 'critical',
  shortcut: 'new-shortcut',
  properties: 'properties',
  terminal: 'run',
  power: 'shutdown',
  flag: 'windows-logo',
  drive: 'drive',
  network: 'network-neighborhood',
  trash: 'recycle-empty',
  web: 'url',
  globe: 'url',
  link: 'url',
  'program-manager.png': 'application',
  'file-manager': 'drive',
  'control-panel': 'control-panel',
  'print-manager': 'printers',
  clipbook: 'documents',
  dos: 'run',
  setup: 'settings',
  pif: 'application',
  readme: 'documents',
  startup: 'programs',
  accessories: 'programs',
  games: 'programs',
  calculator: 'application',
  paint: 'application',
  clock: 'application'
}

export function isExternalWin95Icon(icon: string): boolean {
  return icon.startsWith('data:') || icon.startsWith('file:') ||
    icon.startsWith('http:') || icon.startsWith('https:') ||
    icon.startsWith('/') || /^[a-zA-Z]:[\\/]/.test(icon)
}

export function getWin95IconId(icon: string | undefined): Win95IconId {
  if (!icon) return 'application'
  if ((WIN95_ICON_IDS as readonly string[]).includes(icon)) return icon as Win95IconId
  return aliases[icon] ?? 'application'
}

export function getWin95IconSrc(
  icon: string | undefined,
  size: Win95IconSize,
  scale: Win95ScaleFactor = runtimeScale,
  devicePixelRatio = window.devicePixelRatio || 1
): string {
  if (icon && isExternalWin95Icon(icon)) {
    if (/^[a-zA-Z]:[\\/]/.test(icon)) return `file:///${icon.replace(/\\/g, '/')}`
    return icon
  }
  const id = getWin95IconId(icon)
  const base = size === 'large' ? 32 : 16
  const variant = resolveWin95RasterVariant(scale, devicePixelRatio)
  const pixels = base * variant
  const originalPath = `../../assets/win95-rtm-local/${size}/${id}-${pixels}.png`
  const modulePath = `../../assets/win95/${size}/${id}-${pixels}.png`
  return originalIconModules[originalPath] ?? iconModules[modulePath] ??
    iconModules[`../../assets/win95/${size}/application-${pixels}.png`]
}
