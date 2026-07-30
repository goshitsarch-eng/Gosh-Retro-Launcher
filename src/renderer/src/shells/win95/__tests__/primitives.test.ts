import { describe, expect, it } from 'vitest'
import { WIN95_METRICS, WIN95_PALETTE } from '../tokens'
import { clipWin95Text, measureWin95Text, parseWin95AccessText, win95GlyphAdvance, wrapWin95Text } from '../bitmapText'
import { leastDestructiveDefault, resolveWin95DialogKey } from '../dialogState'
import { win95KeyboardResizeEdge } from '../geometry'

describe('Win95 visual primitives', () => {
  it('locks release-identifying token values', () => {
    expect(WIN95_PALETTE).toMatchObject({ desktop: '#008080', face: '#c0c0c0', highlight: '#dfdfdf', activeCaption: '#000080' })
    expect(WIN95_METRICS).toMatchObject({
      taskbarHeight: 28,
      startButtonWidth: 54,
      trayWidth: 63,
      startMenuWidth: 164,
      startMenuHeight: 235,
      startTopItemHeight: 32,
      captionHeight: 18,
      captionButtonWidth: 16,
      captionButtonHeight: 14,
      runDialogWidth: 347,
      runDialogHeight: 163,
      shutdownDialogWidth: 347,
      shutdownDialogHeight: 222
    })
  })

  it('measures, clips, wraps, and parses bitmap access text deterministically', () => {
    expect(parseWin95AccessText('&Name && Location')).toEqual({ text: 'Name & Location', accessIndex: 0, accessKey: 'n' })
    expect(measureWin95Text('Start')).toBe(22)
    expect(measureWin95Text('Start', true)).toBe(27)
    expect(win95GlyphAdvance('W')).toBeGreaterThan(win95GlyphAdvance('i'))
    expect(clipWin95Text('Programs', measureWin95Text('Prog'))).toBe('Prog')
    expect(wrapWin95Text('Network Neighborhood', 50)).toEqual(['Network', 'Neighborh', 'ood'])
  })

  it('routes default/cancel keys and selects least-destructive defaults', () => {
    expect(resolveWin95DialogKey({ key: 'Escape' }, true)).toBe('cancel')
    expect(resolveWin95DialogKey({ key: 'F4', altKey: true }, true)).toBe('cancel')
    expect(resolveWin95DialogKey({ key: 'Enter' }, true)).toBe('default')
    expect(resolveWin95DialogKey({ key: 'Tab', shiftKey: true }, true)).toBe('reverse-focus')
    expect(leastDestructiveDefault(['yes', 'no'])).toBe('no')
    expect(leastDestructiveDefault(['ok', 'cancel', 'apply'])).toBe('cancel')
  })

  it('chooses every keyboard sizing edge deterministically', () => {
    expect(win95KeyboardResizeEdge(undefined, 'ArrowLeft')).toBe('w')
    expect(win95KeyboardResizeEdge('w', 'ArrowUp')).toBe('nw')
    expect(win95KeyboardResizeEdge(undefined, 'ArrowRight')).toBe('e')
    expect(win95KeyboardResizeEdge('e', 'ArrowDown')).toBe('se')
  })
})
