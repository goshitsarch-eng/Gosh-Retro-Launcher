import { describe, expect, it } from 'vitest'
import { resolveWfwAutoScale } from '../tokens'

describe('WfW integer UI scale', () => {
  it.each([
    [640, 480, 1],
    [1366, 768, 1],
    [1920, 1080, 2],
    [2560, 1440, 3],
    [3840, 2160, 4],
    [7680, 4320, 4]
  ])('resolves %d x %d to %dx', (width, height, expected) => {
    expect(resolveWfwAutoScale(width, height)).toBe(expected)
  })

  it('clamps undersized work areas to 1x', () => {
    expect(resolveWfwAutoScale(400, 300)).toBe(1)
  })
})
