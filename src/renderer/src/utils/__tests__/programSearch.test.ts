import { describe, expect, it } from 'vitest'
import type { ProgramGroup } from '@shared/types'
import { searchPrograms } from '../programSearch'

const state = { x: 0, y: 0, width: 300, height: 200, minimized: false, maximized: false }
const groups: ProgramGroup[] = [{
  id: 'utilities', name: 'Utilities', icon: 'folder', windowState: state,
  shellWindowState: { win31: state, win95: state }, items: [
    { id: 'calc', name: 'Calculator', path: 'calc.exe', icon: 'calculator', workingDir: '' },
    { id: 'calendar', name: 'Calendar', path: 'calendar.exe', icon: 'calendar', workingDir: '' },
    { id: 'notes', name: 'Notes', path: '/tools/calc-notes', icon: 'document', workingDir: '' }
  ]
}]

describe('launcher Find ranking', () => {
  it('ranks name prefixes before substrings and paths', () => {
    expect(searchPrograms(groups, 'calc').map((result) => result.item.id)).toEqual(['calc', 'notes'])
  })

  it('returns group-name matches and ignores blank queries', () => {
    expect(searchPrograms(groups, 'utilities')).toHaveLength(3)
    expect(searchPrograms(groups, '   ')).toEqual([])
  })
})
