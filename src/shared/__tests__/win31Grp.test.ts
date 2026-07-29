import { describe, expect, it } from 'vitest'
import { createShellWindowState, type ProgramGroup } from '../types'
import { GrpFormatError, parseWin31Grp, serializeWin31Grp, splitLegacyCommand } from '../win31Grp'

const state = { x: 12, y: 18, width: 416, height: 201, minimized: false, maximized: false }
const group: ProgramGroup = {
  id: 'main',
  name: 'Main',
  icon: 'group',
  windowState: state,
  shellWindowState: createShellWindowState(state),
  items: [{
    id: 'editor',
    name: 'Text Editor',
    path: 'C:\\Program Files\\Editor\\editor.exe',
    arguments: '--new "sample file.txt"',
    icon: 'default',
    workingDir: 'C:\\Program Files\\Editor',
    win31Position: { x: 75, y: 72 }
  }]
}

describe('Windows 3.x .GRP codec', () => {
  it('round-trips group names, commands, geometry, and manual icon positions', () => {
    let id = 0
    const serialized = serializeWin31Grp(group)
    const checksumView = new DataView(serialized.buffer, serialized.byteOffset, serialized.byteLength)
    let checksum = 0
    for (let offset = 0; offset < serialized.length; offset += 2) {
      checksum = (checksum + checksumView.getUint16(offset, true)) & 0xffff
    }
    expect(checksum).toBe(0)
    const parsed = parseWin31Grp(serialized, () => `id-${id++}`)
    expect(parsed.name).toBe('Main')
    expect(parsed.shellWindowState.win31).toMatchObject(state)
    expect(parsed.items).toHaveLength(1)
    expect(parsed.items[0]).toMatchObject({
      name: 'Text Editor',
      path: 'C:\\Program Files\\Editor\\editor.exe',
      arguments: '--new "sample file.txt"',
      win31Position: { x: 75, y: 72 }
    })
  })

  it('splits quoted and classic executable commands', () => {
    expect(splitLegacyCommand('"C:\\Long Path\\app.exe" /x')).toEqual({
      path: 'C:\\Long Path\\app.exe', arguments: '/x'
    })
    expect(splitLegacyCommand('C:\\DOS\\EDIT.COM README.TXT')).toEqual({
      path: 'C:\\DOS\\EDIT.COM', arguments: 'README.TXT'
    })
  })

  it('rejects non-PMCC files', () => {
    expect(() => parseWin31Grp(new Uint8Array(64))).toThrow(GrpFormatError)
  })
})
