import { describe, expect, it } from 'vitest'
import { WIN95_ICON_IDS, getWin95IconId, isExternalWin95Icon } from '../iconCatalog'

describe('Windows 95 icon aliases', () => {
  it('maps stored legacy ids to Win95-owned silhouettes', () => {
    expect(getWin95IconId('default')).toBe('application')
    expect(getWin95IconId('file-manager')).toBe('drive')
    expect(getWin95IconId('control-panel')).toBe('control-panel')
    expect(getWin95IconId('trash')).toBe('recycle-empty')
    expect(getWin95IconId('web')).toBe('url')
    expect(getWin95IconId('error')).toBe('critical')
    expect(getWin95IconId('shortcut')).toBe('new-shortcut')
    expect(getWin95IconId('properties')).toBe('properties')
    expect(getWin95IconId('unknown-old-id')).toBe('application')
  })

  it('contains the native-size families needed by shell surfaces', () => {
    expect(WIN95_ICON_IDS).toEqual(expect.arrayContaining([
      'my-computer', 'network-neighborhood', 'recycle-empty', 'folder',
      'programs', 'run', 'find', 'shutdown', 'taskbar', 'warning',
      'information', 'question', 'critical', 'application', 'url'
    ]))
  })

  it('does not replace extracted application icons', () => {
    expect(isExternalWin95Icon('data:image/png;base64,abc')).toBe(true)
    expect(isExternalWin95Icon('C:\\Apps\\app.exe')).toBe(true)
    expect(isExternalWin95Icon('file:///tmp/app.png')).toBe(true)
  })
})
