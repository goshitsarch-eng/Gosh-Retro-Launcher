import { describe, expect, it } from 'vitest'
import { isValidShellFrameRequest } from '../windowHandlers'
import { usesNativeWindowFrame } from '../../window'

describe('shell-aware window framing', () => {
  it('accepts only supported shell frame requests', () => {
    expect(isValidShellFrameRequest('win31')).toBe(true)
    expect(isValidShellFrameRequest('win95')).toBe(true)
    expect(isValidShellFrameRequest('win98')).toBe(false)
    expect(isValidShellFrameRequest({ shell: 'win31' })).toBe(false)
  })

  it('uses a custom frame only for Windows 3.1', () => {
    expect(usesNativeWindowFrame('win31')).toBe(false)
    expect(usesNativeWindowFrame('win95')).toBe(true)
  })
})
