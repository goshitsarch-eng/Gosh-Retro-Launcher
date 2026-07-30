import { describe, expect, it, vi } from 'vitest'
import { DEFAULT_SETTINGS } from '@shared/types'
import { applyShellSettingsTransaction } from '../shellSwitch'

describe('shell-switch persistence transaction', () => {
  it('persists the complete payload before recreating once', async () => {
    const order: string[] = []
    const previous = { ...DEFAULT_SETTINGS, shell: 'win31' as const }
    const next = { ...previous, shell: 'win95' as const, win95Scale: 3 as const }
    const result = await applyShellSettingsTransaction(previous, next, {
      persist: async (value) => { order.push(`persist:${value.shell}:${value.win95Scale}`) },
      updateRenderer: (value) => { order.push(`renderer:${value.shell}`) },
      recreate: async (shell) => { order.push(`recreate:${shell}`) }
    })
    expect(result.success).toBe(true)
    expect(order).toEqual(['persist:win95:3', 'renderer:win95', 'recreate:win95'])
  })

  it('rolls disk and renderer back if recreation fails', async () => {
    const previous = { ...DEFAULT_SETTINGS, shell: 'win95' as const }
    const next = { ...previous, shell: 'win31' as const }
    const persisted: string[] = []
    const rendered: string[] = []
    const recreate = vi.fn(async () => { throw new Error('frame failure') })
    const result = await applyShellSettingsTransaction(previous, next, {
      persist: async (value) => { persisted.push(value.shell) },
      updateRenderer: (value) => { rendered.push(value.shell) },
      recreate
    })
    expect(result).toEqual({ success: false, error: 'frame failure' })
    expect(persisted).toEqual(['win31', 'win95'])
    expect(rendered).toEqual(['win31', 'win95'])
    expect(recreate).toHaveBeenCalledTimes(1)
  })
})
