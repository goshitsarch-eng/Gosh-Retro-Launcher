import type { LogicalPosition } from '@shared/types'
import type { Win95ViewMode } from './Win95FolderView'

export interface Win95ListLayoutItem extends LogicalPosition {
  id: string
  width: number
  height: number
}
export interface Win95ListLayout {
  items: Win95ListLayoutItem[]
  contentWidth: number
  contentHeight: number
  columns: number
  rowsPerPage: number
}

export function layoutWin95ListView(
  ids: string[],
  mode: Win95ViewMode,
  viewport: { width: number; height: number },
  manualPositions: Record<string, LogicalPosition | undefined> = {},
  autoArrange = true,
  reportWidths = { name: 220, type: 110, location: 180 }
): Win95ListLayout {
  const width = Math.max(1, viewport.width)
  const height = Math.max(1, viewport.height)
  if (mode === 'details') {
    const rowHeight = 19
    const header = 18
    const totalWidth = reportWidths.name + reportWidths.type + reportWidths.location
    return {
      items: ids.map((id, index) => ({ id, x: 0, y: header + index * rowHeight, width: totalWidth, height: rowHeight })),
      contentWidth: Math.max(width, totalWidth),
      contentHeight: Math.max(height, header + ids.length * rowHeight),
      columns: 1,
      rowsPerPage: Math.max(1, Math.floor((height - header) / rowHeight))
    }
  }
  if (mode === 'list') {
    const cellWidth = 150
    const cellHeight = 20
    const rows = Math.max(1, Math.floor((height - 8) / cellHeight))
    const columns = Math.max(1, Math.ceil(ids.length / rows))
    return {
      items: ids.map((id, index) => ({ id, x: 4 + Math.floor(index / rows) * cellWidth, y: 4 + (index % rows) * cellHeight, width: cellWidth, height: cellHeight })),
      contentWidth: Math.max(width, 8 + columns * cellWidth),
      contentHeight: height,
      columns,
      rowsPerPage: rows
    }
  }
  const large = mode === 'large'
  const cellWidth = large ? 76 : 150
  const cellHeight = large ? 68 : 20
  const insetX = large ? 5 : 4
  const insetY = large ? 8 : 4
  const columns = Math.max(1, Math.floor((width - insetX * 2) / cellWidth))
  const items = ids.map((id, index) => {
    const automatic = { x: insetX + (index % columns) * cellWidth, y: insetY + Math.floor(index / columns) * cellHeight }
    const point = autoArrange || !manualPositions[id] ? automatic : manualPositions[id]!
    return { id, x: point.x, y: point.y, width: cellWidth, height: cellHeight }
  })
  const contentWidth = Math.max(width, ...items.map((item) => item.x + item.width + insetX))
  const contentHeight = Math.max(height, ...items.map((item) => item.y + item.height + insetY))
  return {
    items,
    contentWidth,
    contentHeight,
    columns,
    rowsPerPage: Math.max(1, Math.floor((height - insetY * 2) / cellHeight))
  }
}

export function resizeWin95ReportColumn(width: number, delta: number, minimum = 40): number {
  return Math.max(minimum, Math.round(width + delta))
}

export function win95PageSelectionIndex(index: number, direction: -1 | 1, rowsPerPage: number, count: number): number {
  if (!count) return -1
  return Math.max(0, Math.min(count - 1, index + direction * Math.max(1, rowsPerPage)))
}
