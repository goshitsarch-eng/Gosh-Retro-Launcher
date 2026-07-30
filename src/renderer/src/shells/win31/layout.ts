import type { LogicalRect } from '@shared/types'

/**
 * Fill the complete MDI client while keeping rows and columns as balanced as
 * possible. A short final row expands instead of leaving an empty tile slot.
 */
export function calculateWin31TileLayout(
  count: number,
  width: number,
  height: number
): LogicalRect[] {
  if (count <= 0) return []

  const rows = Math.max(1, Math.round(Math.sqrt(count)))
  const baseItemsPerRow = Math.floor(count / rows)
  const fullerRows = count % rows
  const bounds: LogicalRect[] = []

  for (let row = 0; row < rows; row += 1) {
    const itemsInRow = baseItemsPerRow + (row < fullerRows ? 1 : 0)
    const top = Math.floor(row * height / rows)
    const bottom = Math.floor((row + 1) * height / rows)
    for (let column = 0; column < itemsInRow; column += 1) {
      const left = Math.floor(column * width / itemsInRow)
      const right = Math.floor((column + 1) * width / itemsInRow)
      bounds.push({ x: left, y: top, width: right - left, height: bottom - top })
    }
  }

  return bounds
}
