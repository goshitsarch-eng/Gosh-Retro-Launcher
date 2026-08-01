import type { WfwScaleFactor } from './tokens'

const iconModules = import.meta.glob('../../assets/wfw/*.png', {
  eager: true,
  query: '?url',
  import: 'default'
}) as Record<string, string>

// Optional, gitignored resource pack extracted from the user's own licensed
// Windows for Workgroups 3.11 media. Distributable builds fall back to the
// clean-room set.
const originalIconModules = import.meta.glob('../../assets/wfw-rtm-local/*.png', {
  eager: true,
  query: '?url',
  import: 'default'
}) as Record<string, string>

export const WFW_ICON_IDS = [
  'group', 'default', 'file-manager', 'control-panel', 'print-manager',
  'clipbook', 'dos', 'setup', 'pif', 'readme', 'accessories', 'network',
  'games', 'startup', 'program-manager', 'terminal', 'calculator', 'clock',
  'paint', 'cardfile', 'warning', 'information', 'question'
] as const

export type WfwIconId = (typeof WFW_ICON_IDS)[number]

const aliases: Record<string, WfwIconId> = {
  folder: 'group',
  'wfw-group': 'group',
  'wfw-file-manager': 'file-manager',
  'wfw-control-panel': 'control-panel',
  'wfw-print-manager': 'print-manager',
  'wfw-clipbook': 'clipbook',
  'wfw-dos': 'dos',
  'wfw-setup': 'setup',
  'wfw-pif': 'pif',
  'wfw-readme': 'readme',
  drive: 'file-manager',
  network: 'network',
  trash: 'default'
}

export function isExternalIcon(icon: string): boolean {
  return icon.startsWith('data:') || icon.startsWith('file:') || icon.startsWith('http:') || icon.startsWith('https:')
}

export function getWfwIconId(icon: string): WfwIconId {
  if ((WFW_ICON_IDS as readonly string[]).includes(icon)) return icon as WfwIconId
  return aliases[icon] ?? 'default'
}

export function getWfwIconSrc(
  icon: string,
  scale: WfwScaleFactor,
  devicePixelRatio = window.devicePixelRatio || 1
): string {
  if (isExternalIcon(icon)) return icon
  const id = getWfwIconId(icon)
  const variant = Math.max(1, Math.min(4, Math.ceil(scale * devicePixelRatio)))
  const suffix = variant * 32
  const path = `../../assets/wfw-rtm-local/${id}-${suffix}.png`
  return originalIconModules[path] ?? iconModules[`../../assets/wfw/${id}-${suffix}.png`] ?? iconModules[`../../assets/wfw/default-${suffix}.png`]
}
