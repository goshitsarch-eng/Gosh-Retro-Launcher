import { describe, expect, it } from 'vitest'
import { displayMnemonic, mnemonicIndex, reduceMenuNavigation } from '../menuState'

describe('Windows 95 menu navigation reducer', () => {
  it('wraps vertical selection and handles Home/End', () => {
    expect(reduceMenuNavigation({ level: 0, indices: [0] }, 'ArrowUp', [7]).indices[0]).toBe(6)
    expect(reduceMenuNavigation({ level: 0, indices: [6] }, 'ArrowDown', [7]).indices[0]).toBe(0)
    expect(reduceMenuNavigation({ level: 0, indices: [3] }, 'Home', [7]).indices[0]).toBe(0)
    expect(reduceMenuNavigation({ level: 0, indices: [3] }, 'End', [7]).indices[0]).toBe(6)
    expect(reduceMenuNavigation({ level: 0, indices: [-1] }, 'ArrowDown', [7]).indices[0]).toBe(0)
    expect(reduceMenuNavigation({ level: 0, indices: [-1] }, 'ArrowUp', [7]).indices[0]).toBe(6)
  })

  it('opens and closes nested levels without losing the parent index', () => {
    const opened = reduceMenuNavigation({ level: 0, indices: [2] }, 'ArrowRight', [7, 4], true)
    expect(opened).toEqual({ level: 1, indices: [2, 0], action: 'open-child' })
    const closed = reduceMenuNavigation(opened, 'Escape', [7, 4])
    expect(closed).toEqual({ level: 0, indices: [2], action: 'close-level' })
    expect(reduceMenuNavigation(closed, 'Escape', [7, 4]).action).toBe('close-all')
  })

  it('finds and displays ampersand mnemonics', () => {
    expect(mnemonicIndex(['&Programs', 'Sh&ut Down...'], 'u')).toBe(1)
    expect(displayMnemonic('Sh&ut Down...')).toEqual({ before: 'Sh', mnemonic: 'u', after: 't Down...' })
  })
})
