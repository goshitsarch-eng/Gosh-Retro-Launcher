import { describe, it, expect } from 'vitest'
import { isValidItem, isValidGroup, isValidSettings } from '../storeHandlers'

describe('isValidItem', () => {
  const validItem = {
    id: '123',
    name: 'Test App',
    path: '/usr/bin/test',
    icon: 'default',
    workingDir: '/home/user'
  }

  it('accepts a valid item with all fields', () => {
    expect(isValidItem(validItem)).toBe(true)
  })

  it('rejects item missing id', () => {
    const { id, ...rest } = validItem
    expect(isValidItem(rest)).toBe(false)
  })

  it('rejects item missing name', () => {
    const { name, ...rest } = validItem
    expect(isValidItem(rest)).toBe(false)
  })

  it('rejects item missing path', () => {
    const { path, ...rest } = validItem
    expect(isValidItem(rest)).toBe(false)
  })

  it('rejects item missing icon', () => {
    const { icon, ...rest } = validItem
    expect(isValidItem(rest)).toBe(false)
  })

  it('rejects null', () => {
    expect(isValidItem(null)).toBe(false)
  })

  it('rejects non-object', () => {
    expect(isValidItem('string')).toBe(false)
    expect(isValidItem(42)).toBe(false)
    expect(isValidItem(undefined)).toBe(false)
  })

  it('accepts items with extra fields', () => {
    expect(isValidItem({ ...validItem, shortcutKey: 'Ctrl+A' })).toBe(true)
  })
})

describe('isValidGroup', () => {
  const validItem = {
    id: '123',
    name: 'Test App',
    path: '/usr/bin/test',
    icon: 'default',
    workingDir: '/home/user'
  }

  const validGroup = {
    id: 'group-1',
    name: 'Main',
    icon: 'folder',
    windowState: { x: 0, y: 0, width: 300, height: 200, minimized: false, maximized: false },
    items: [validItem]
  }

  it('accepts a valid group with items', () => {
    expect(isValidGroup(validGroup)).toBe(true)
  })

  it('accepts a group with empty items array', () => {
    expect(isValidGroup({ ...validGroup, items: [] })).toBe(true)
  })

  it('rejects group with an invalid item in array', () => {
    expect(isValidGroup({ ...validGroup, items: [{ bad: true }] })).toBe(false)
  })

  it('rejects group missing windowState', () => {
    const { windowState, ...rest } = validGroup
    expect(isValidGroup(rest)).toBe(false)
  })

  it('rejects group with null windowState', () => {
    expect(isValidGroup({ ...validGroup, windowState: null })).toBe(false)
  })

  it('rejects group missing items', () => {
    const { items, ...rest } = validGroup
    expect(isValidGroup(rest)).toBe(false)
  })
})

describe('isValidSettings', () => {
  const validSettings = {
    autoArrange: true,
    minimizeOnUse: false,
    saveSettingsOnExit: true,
    launchDelay: 500,
    trayOnClose: true,
    groupChromeScale: 1,
    theme: 'light',
    labelDisplay: 'wrap',
    shell: 'win31'
  }

  it('accepts valid settings', () => {
    expect(isValidSettings(validSettings)).toBe(true)
  })

  it('accepts dark theme', () => {
    expect(isValidSettings({ ...validSettings, theme: 'dark' })).toBe(true)
  })

  it('accepts ellipsis labelDisplay', () => {
    expect(isValidSettings({ ...validSettings, labelDisplay: 'ellipsis' })).toBe(true)
  })

  it('rejects invalid theme', () => {
    expect(isValidSettings({ ...validSettings, theme: 'blue' })).toBe(false)
  })

  it('rejects invalid labelDisplay', () => {
    expect(isValidSettings({ ...validSettings, labelDisplay: 'truncate' })).toBe(false)
  })

  it('rejects negative launchDelay', () => {
    expect(isValidSettings({ ...validSettings, launchDelay: -1 })).toBe(false)
  })

  it('rejects zero groupChromeScale', () => {
    expect(isValidSettings({ ...validSettings, groupChromeScale: 0 })).toBe(false)
  })

  it('rejects non-boolean autoArrange', () => {
    expect(isValidSettings({ ...validSettings, autoArrange: 'yes' })).toBe(false)
  })

  it('rejects null', () => {
    expect(isValidSettings(null)).toBe(false)
  })

  it('rejects non-object', () => {
    expect(isValidSettings('string')).toBe(false)
  })

  it('rejects missing fields', () => {
    const { theme, ...rest } = validSettings
    expect(isValidSettings(rest)).toBe(false)
  })

  it('accepts win95 shell', () => {
    expect(isValidSettings({ ...validSettings, shell: 'win95' })).toBe(true)
  })

  it('rejects invalid shell', () => {
    expect(isValidSettings({ ...validSettings, shell: 'win98' })).toBe(false)
  })

  it('accepts missing shell for backward compatibility', () => {
    const { shell, ...rest } = validSettings
    expect(isValidSettings(rest)).toBe(true)
  })
})
