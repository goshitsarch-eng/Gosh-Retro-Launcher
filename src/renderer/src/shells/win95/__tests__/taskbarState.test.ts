import { describe, expect, it } from 'vitest'
import { getTaskbarButtonState, getTaskbarClickAction } from '../taskbarState'

describe('Windows 95 taskbar state', () => {
  it('presses only the active visible window', () => {
    expect(getTaskbarButtonState('one', 'one', false)).toBe('active')
    expect(getTaskbarButtonState('two', 'one', false)).toBe('inactive')
    expect(getTaskbarButtonState('one', 'one', true)).toBe('minimized')
  })

  it('maps button clicks to minimize, focus, or restore', () => {
    expect(getTaskbarClickAction('one', 'one', false)).toBe('minimize')
    expect(getTaskbarClickAction('two', 'one', false)).toBe('focus')
    expect(getTaskbarClickAction('one', 'one', true)).toBe('restore-focus')
  })
})
