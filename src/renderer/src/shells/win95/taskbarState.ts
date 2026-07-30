export type TaskbarButtonState = 'active' | 'inactive' | 'minimized'

export function getTaskbarButtonState(
  windowId: string,
  activeWindowId: string | null,
  minimized: boolean
): TaskbarButtonState {
  if (minimized) return 'minimized'
  return windowId === activeWindowId ? 'active' : 'inactive'
}

export type TaskbarClickAction = 'minimize' | 'restore-focus' | 'focus'

export function getTaskbarClickAction(
  windowId: string,
  activeWindowId: string | null,
  minimized: boolean
): TaskbarClickAction {
  if (minimized) return 'restore-focus'
  return windowId === activeWindowId ? 'minimize' : 'focus'
}
