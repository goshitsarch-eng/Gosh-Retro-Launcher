import { describe, expect, it } from 'vitest'
import {
  logicalViewportSize,
  resolveWin95AutoScale,
  toWin95LogicalDelta,
  toWin95LogicalPoint,
  resolveWin95RasterVariant
} from '../tokens'

describe('Windows 95 integer scale', () => {
  it('uses the largest integer 640×480 canvas that fits', () => {
    expect(resolveWin95AutoScale(639, 479)).toBe(1)
    expect(resolveWin95AutoScale(640, 480)).toBe(1)
    expect(resolveWin95AutoScale(1279, 959)).toBe(1)
    expect(resolveWin95AutoScale(1280, 960)).toBe(2)
    expect(resolveWin95AutoScale(1920, 1080)).toBe(2)
    expect(resolveWin95AutoScale(2560, 1440)).toBe(3)
    expect(resolveWin95AutoScale(3840, 2160)).toBe(4)
    expect(resolveWin95AutoScale(10000, 10000)).toBe(4)
  })

  it('returns a logical viewport without fractional layout pixels', () => {
    expect(logicalViewportSize(1920, 1080, 2)).toEqual({ width: 960, height: 540 })
    expect(logicalViewportSize(2561, 1441, 3)).toEqual({ width: 854, height: 481 })
  })

  it('selects deterministic DPR-aware source variants without exceeding the atlas', () => {
    expect(resolveWin95RasterVariant(1, 1)).toBe(1)
    expect(resolveWin95RasterVariant(2, 1.25)).toBe(3)
    expect(resolveWin95RasterVariant(3, 1.5)).toBe(4)
    expect(resolveWin95RasterVariant(4, 2)).toBe(4)
  })

  it('converts physical pointer points and deltas at one shell boundary', () => {
    expect(toWin95LogicalDelta(96, 3)).toBe(32)
    expect(toWin95LogicalPoint(330, 180, 3, { left: 30, top: 30 })).toEqual({ x: 100, y: 50 })
  })
})
