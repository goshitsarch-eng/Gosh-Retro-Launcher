import { describe, expect, it } from 'vitest'
import { CURRENT_SCHEMA_VERSION, DEFAULT_SETTINGS } from '../types'
import { migrateStoreData } from '../storeMigration'

const legacyWindow = {
  x: 42,
  y: 37,
  width: 410,
  height: 230,
  minimized: true,
  maximized: false
}

describe('store migration', () => {
  it('copies legacy group geometry into independent Win31 and Win95 records once', () => {
    const migrated = migrateStoreData({
      groups: [{
        id: 'main',
        name: 'Main',
        icon: 'folder',
        windowState: legacyWindow,
        items: [{ id: 'one', name: 'One', path: 'one.exe', icon: 'default', workingDir: '' }]
      }],
      settings: { ...DEFAULT_SETTINGS, win31Scale: 2 }
    })

    expect(migrated.schemaVersion).toBe(CURRENT_SCHEMA_VERSION)
    expect(migrated.groups[0].shellWindowState).toEqual({
      win31: legacyWindow,
      win95: legacyWindow
    })
    expect(migrated.groups[0].shellWindowState.win31).not.toBe(
      migrated.groups[0].shellWindowState.win95
    )
    expect(migrated.settings.win31Scale).toBe(2)
  })

  it('migrates workspace profiles and desktop geometry without sharing objects', () => {
    const migrated = migrateStoreData({
      groups: [],
      settings: {
        ...DEFAULT_SETTINGS,
        win31DesktopMode: true,
        win31ProgramManagerBounds: { x: 68, y: 49, width: 511, height: 335 }
      },
      workspaceProfiles: [{
        id: 'work', name: 'Work', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-02T00:00:00.000Z',
        groups: [{ id: 'main', name: 'Main', icon: 'group', windowState: legacyWindow, items: [] }]
      }]
    })
    expect(migrated.settings.win31DesktopMode).toBe(true)
    expect(migrated.settings.win31ProgramManagerBounds).toEqual({ x: 68, y: 49, width: 511, height: 335 })
    expect(migrated.workspaceProfiles[0].groups[0].shellWindowState.win31).toEqual(legacyWindow)
    expect(migrated.workspaceProfiles[0].groups).not.toBe(migrated.groups)
  })

  it('adds an independent Win95 scale without changing legacy Win31 scale', () => {
    const migrated = migrateStoreData({
      groups: [],
      settings: { ...DEFAULT_SETTINGS, win31Scale: 3, win95Scale: 2 }
    })
    expect(migrated.settings.win31Scale).toBe(3)
    expect(migrated.settings.win95Scale).toBe(2)

    const legacy = migrateStoreData({ groups: [], settings: { win31Scale: 4 } })
    expect(legacy.settings.win31Scale).toBe(4)
    expect(legacy.settings.win95Scale).toBe('auto')
  })

  it('retains valid Win95 desktop and item positions while rejecting malformed coordinates', () => {
    const migrated = migrateStoreData({
      groups: [{
        id: 'main', name: 'Main', icon: 'folder', windowState: legacyWindow,
        items: [
          { id: 'one', name: 'One', path: 'one.exe', icon: 'application', workingDir: '', win95Position: { x: 123, y: 45 } },
          { id: 'two', name: 'Two', path: 'two.exe', icon: 'application', workingDir: '', win95Position: { x: 'bad', y: 2 } }
        ]
      }],
      settings: {
        ...DEFAULT_SETTINGS,
        win95DesktopIconPositions: {
          'my-computer': { x: 7, y: 9 },
          broken: { x: Number.NaN, y: 3 }
        }
      }
    })
    expect(migrated.groups[0].items[0].win95Position).toEqual({ x: 123, y: 45 })
    expect(migrated.groups[0].items[1].win95Position).toBeUndefined()
    expect(migrated.settings.win95DesktopIconPositions).toEqual({ 'my-computer': { x: 7, y: 9 } })
  })

  it('normalizes invalid scale and malformed persisted objects', () => {
    const migrated = migrateStoreData({
      groups: [null, { id: 3 }, {
        id: 'valid',
        name: 'Valid',
        windowState: { width: -1, height: Number.NaN },
        items: [{ id: 'bad' }]
      }],
      settings: { win31Scale: 8 }
    })

    expect(migrated.settings.win31Scale).toBe('auto')
    expect(migrated.settings.win95Scale).toBe('auto')
    expect(migrated.groups).toHaveLength(1)
    expect(migrated.groups[0].items).toEqual([])
    expect(migrated.groups[0].shellWindowState.win31.width).toBeGreaterThanOrEqual(150)
    expect(migrated.groups[0].shellWindowState.win31.height).toBeGreaterThanOrEqual(92)
  })
})
