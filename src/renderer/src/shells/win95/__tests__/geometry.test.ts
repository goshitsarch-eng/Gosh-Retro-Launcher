import { describe, expect, it } from 'vitest'
import { constrainWin95Rect, dragWin95Rect, resizeWin95Rect } from '../geometry'

describe('Windows 95 logical window geometry', () => {
  const area = { width: 640, height: 452 }
  const rect = { x: 40, y: 30, width: 300, height: 200 }

  it('constrains restored windows to the logical desktop', () => {
    expect(constrainWin95Rect({ x: 600, y: 440, width: 300, height: 200 }, area))
      .toEqual({ x: 340, y: 252, width: 300, height: 200 })
  })

  it('uses logical deltas independent of renderer scale', () => {
    expect(dragWin95Rect(rect, 25, 15, area)).toEqual({ ...rect, x: 65, y: 45 })
    expect(resizeWin95Rect(rect, 'se', 40, 20, area)).toEqual({ ...rect, width: 340, height: 220 })
  })

  it('keeps all eight-edge resize paths within the work area', () => {
    expect(resizeWin95Rect(rect, 'nw', -100, -100, area)).toEqual({ x: 0, y: 0, width: 340, height: 230 })
    expect(resizeWin95Rect(rect, 'e', 1000, 0, area).width).toBe(600)
  })
})
