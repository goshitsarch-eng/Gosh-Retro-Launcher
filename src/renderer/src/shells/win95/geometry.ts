import type { LogicalRect } from '@shared/types'

export interface LogicalSize { width: number; height: number }
export type ResizeEdge = 'n' | 's' | 'e' | 'w' | 'ne' | 'nw' | 'se' | 'sw'

export function constrainWin95Rect(
  rect: LogicalRect,
  area: LogicalSize,
  min: LogicalSize = { width: 160, height: 100 }
): LogicalRect {
  const minimumWidth = Math.min(min.width, Math.max(1, area.width))
  const minimumHeight = Math.min(min.height, Math.max(1, area.height))
  const width = Math.max(minimumWidth, Math.min(rect.width, Math.max(minimumWidth, area.width)))
  const height = Math.max(minimumHeight, Math.min(rect.height, Math.max(minimumHeight, area.height)))
  const x = Math.max(0, Math.min(rect.x, Math.max(0, area.width - width)))
  const y = Math.max(0, Math.min(rect.y, Math.max(0, area.height - height)))
  return { x, y, width, height }
}

export function dragWin95Rect(
  start: LogicalRect,
  dx: number,
  dy: number,
  area: LogicalSize
): LogicalRect {
  return constrainWin95Rect({ ...start, x: start.x + dx, y: start.y + dy }, area, {
    width: Math.min(start.width, area.width),
    height: Math.min(start.height, area.height)
  })
}

export function win95KeyboardResizeEdge(
  current: ResizeEdge | undefined,
  key: 'ArrowLeft' | 'ArrowRight' | 'ArrowUp' | 'ArrowDown'
): ResizeEdge {
  const horizontal = key === 'ArrowLeft' ? 'w' : key === 'ArrowRight' ? 'e' : current?.includes('w') ? 'w' : current?.includes('e') ? 'e' : ''
  const vertical = key === 'ArrowUp' ? 'n' : key === 'ArrowDown' ? 's' : current?.includes('n') ? 'n' : current?.includes('s') ? 's' : ''
  return `${vertical}${horizontal}` as ResizeEdge
}

export function resizeWin95Rect(
  start: LogicalRect,
  edge: ResizeEdge,
  dx: number,
  dy: number,
  area: LogicalSize,
  min: LogicalSize = { width: 160, height: 100 }
): LogicalRect {
  let { x, y, width, height } = start
  if (edge.includes('e')) width += dx
  if (edge.includes('s')) height += dy
  if (edge.includes('w')) { x += dx; width -= dx }
  if (edge.includes('n')) { y += dy; height -= dy }
  const minimumWidth = Math.min(min.width, Math.max(1, area.width))
  const minimumHeight = Math.min(min.height, Math.max(1, area.height))
  if (width < minimumWidth) { if (edge.includes('w')) x -= minimumWidth - width; width = minimumWidth }
  if (height < minimumHeight) { if (edge.includes('n')) y -= minimumHeight - height; height = minimumHeight }
  if (x < 0) { width += x; x = 0 }
  if (y < 0) { height += y; y = 0 }
  width = Math.min(width, area.width - x)
  height = Math.min(height, area.height - y)
  return { x, y, width: Math.max(minimumWidth, width), height: Math.max(minimumHeight, height) }
}
