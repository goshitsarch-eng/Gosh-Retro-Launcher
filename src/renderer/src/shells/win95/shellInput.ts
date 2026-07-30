export type Win95InputLayer = 'modal' | 'menu' | 'window' | 'desktop'

export type Win95ShellCommand =
  | 'toggle-start' | 'open-run' | 'open-find' | 'open-explorer'
  | 'cycle-window' | 'cycle-window-reverse' | 'menu-bar-mode'
  | 'system-menu' | 'close-window' | 'context-menu'

export interface Win95ShortcutEvent {
  key: string
  code?: string
  ctrlKey?: boolean
  altKey?: boolean
  shiftKey?: boolean
  metaKey?: boolean
}

/** Pure shell accelerator routing. Bare Meta/Alt are resolved on key-up. */
export function routeWin95Shortcut(event: Win95ShortcutEvent): Win95ShellCommand | null {
  const key = event.key.toLowerCase()
  if (event.ctrlKey && !event.altKey && key === 'escape') return 'toggle-start'
  if (event.metaKey) {
    if (key === 'r') return 'open-run'
    if (key === 'f') return 'open-find'
    if (key === 'e') return 'open-explorer'
    if (key === 'tab') return event.shiftKey ? 'cycle-window-reverse' : 'cycle-window'
  }
  if (event.altKey) {
    if (key === 'tab') return event.shiftKey ? 'cycle-window-reverse' : 'cycle-window'
    if (key === ' ') return 'system-menu'
    if (key === 'f4') return 'close-window'
  }
  if (key === 'contextmenu' || (event.shiftKey && key === 'f10')) return 'context-menu'
  return null
}

export interface MenuRect { x: number; y: number; width: number; height: number }
export interface MenuViewport { width: number; height: number }

export function placeWin95Menu(
  anchor: MenuRect,
  menu: { width: number; height: number },
  viewport: MenuViewport,
  kind: 'below' | 'cascade' = 'cascade'
): { x: number; y: number; flippedX: boolean; flippedY: boolean } {
  let x = kind === 'below' ? anchor.x : anchor.x + anchor.width - 1
  let y = kind === 'below' ? anchor.y + anchor.height - 1 : anchor.y
  let flippedX = false
  let flippedY = false
  if (x + menu.width > viewport.width) {
    x = kind === 'below' ? Math.max(0, viewport.width - menu.width) : anchor.x - menu.width + 1
    flippedX = true
  }
  if (y + menu.height > viewport.height) {
    y = kind === 'below' ? anchor.y - menu.height + 1 : viewport.height - menu.height
    flippedY = true
  }
  return {
    x: Math.max(0, Math.round(x)),
    y: Math.max(0, Math.round(y)),
    flippedX,
    flippedY
  }
}

export function menuColumnLayout(rowHeights: number[], availableHeight: number): number[][] {
  const columns: number[][] = [[]]
  let used = 0
  for (let index = 0; index < rowHeights.length; index += 1) {
    const height = Math.max(1, rowHeights[index])
    if (columns[columns.length - 1].length && used + height > availableHeight) {
      columns.push([])
      used = 0
    }
    columns[columns.length - 1].push(index)
    used += height
  }
  return columns
}

function triangleArea(a: [number, number], b: [number, number], c: [number, number]): number {
  return Math.abs((a[0] * (b[1] - c[1]) + b[0] * (c[1] - a[1]) + c[0] * (a[1] - b[1])) / 2)
}

/** True when the pointer remains inside the parent-to-child submenu corridor. */
export function isPointInMenuCorridor(
  origin: { x: number; y: number },
  point: { x: number; y: number },
  childEdge: { x: number; top: number; bottom: number }
): boolean {
  const a: [number, number] = [origin.x, origin.y]
  const b: [number, number] = [childEdge.x, childEdge.top]
  const c: [number, number] = [childEdge.x, childEdge.bottom]
  const p: [number, number] = [point.x, point.y]
  const total = triangleArea(a, b, c)
  const parts = triangleArea(p, b, c) + triangleArea(a, p, c) + triangleArea(a, b, p)
  return Math.abs(total - parts) < 0.5
}

export interface Win95MenuTrackingState {
  open: boolean
  mode: 'closed' | 'tracking' | 'latched'
  path: number[]
}

export type Win95MenuTrackingAction =
  | { type: 'open'; index?: number; tracking?: boolean }
  | { type: 'hover'; level: number; index: number; hasChild: boolean }
  | { type: 'release'; hasChild: boolean }
  | { type: 'close-level' }
  | { type: 'close-all' }

export function reduceWin95MenuTracking(
  state: Win95MenuTrackingState,
  action: Win95MenuTrackingAction
): Win95MenuTrackingState {
  if (action.type === 'open') return {
    open: true,
    mode: action.tracking ? 'tracking' : 'latched',
    path: [action.index ?? 0]
  }
  if (action.type === 'hover') {
    const path = state.path.slice(0, action.level)
    path[action.level] = action.index
    return { ...state, path }
  }
  if (action.type === 'release') {
    if (action.hasChild) return { ...state, mode: 'latched' }
    return { open: false, mode: 'closed', path: [] }
  }
  if (action.type === 'close-level') {
    if (state.path.length <= 1) return { open: false, mode: 'closed', path: [] }
    return { ...state, mode: 'latched', path: state.path.slice(0, -1) }
  }
  return { open: false, mode: 'closed', path: [] }
}
