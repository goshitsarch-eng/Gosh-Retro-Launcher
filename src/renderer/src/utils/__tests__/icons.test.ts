import { describe, it, expect } from 'vitest'
import { getIconSrc, DEFAULT_ITEM_ICON, BUILTIN_ICONS } from '../icons'

describe('getIconSrc', () => {
  it('returns the data URL for a builtin icon ID', () => {
    const webIcon = BUILTIN_ICONS.find((i) => i.id === 'web')
    expect(webIcon).toBeDefined()
    expect(getIconSrc('web')).toBe(webIcon!.icon)
  })

  it('returns DEFAULT_ITEM_ICON for undefined', () => {
    expect(getIconSrc(undefined)).toBe(DEFAULT_ITEM_ICON)
  })

  it('returns DEFAULT_ITEM_ICON for legacy name "default-item.png"', () => {
    expect(getIconSrc('default-item.png')).toBe(DEFAULT_ITEM_ICON)
  })

  it('passes through data URLs', () => {
    const dataUrl = 'data:image/png;base64,abc123'
    expect(getIconSrc(dataUrl)).toBe(dataUrl)
  })

  it('passes through HTTP URLs', () => {
    const httpUrl = 'https://example.com/icon.png'
    expect(getIconSrc(httpUrl)).toBe(httpUrl)
  })

  it('converts Windows paths to file URLs', () => {
    expect(getIconSrc('C:\\icons\\test.png')).toBe('file:///C:/icons/test.png')
  })

  it('returns Unix paths as-is', () => {
    expect(getIconSrc('/usr/share/icon.png')).toBe('/usr/share/icon.png')
  })

  it('returns DEFAULT_ITEM_ICON for unknown strings', () => {
    expect(getIconSrc('some-random-string')).toBe(DEFAULT_ITEM_ICON)
  })
})
