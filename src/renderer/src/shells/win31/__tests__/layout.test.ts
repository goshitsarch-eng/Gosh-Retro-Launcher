import { describe, expect, it } from 'vitest'
import { calculateWin31TileLayout } from '../layout'

describe('Win31 window tiling', () => {
  it('uses the full final row instead of leaving an empty tile', () => {
    expect(calculateWin31TileLayout(3, 600, 400)).toEqual([
      { x: 0, y: 0, width: 300, height: 200 },
      { x: 300, y: 0, width: 300, height: 200 },
      { x: 0, y: 200, width: 600, height: 200 }
    ])
  })

  it('covers the client exactly when dimensions do not divide evenly', () => {
    const bounds = calculateWin31TileLayout(5, 601, 401)
    const totalArea = bounds.reduce((area, rect) => area + rect.width * rect.height, 0)

    expect(bounds).toHaveLength(5)
    expect(totalArea).toBe(601 * 401)
  })

  it('returns no bounds when there are no windows', () => {
    expect(calculateWin31TileLayout(0, 600, 400)).toEqual([])
  })
})
