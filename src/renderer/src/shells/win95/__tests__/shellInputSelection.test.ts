import { describe, expect, it } from 'vitest'
import {
  isPointInMenuCorridor,
  menuColumnLayout,
  placeWin95Menu,
  reduceWin95MenuTracking,
  routeWin95Shortcut
} from '../shellInput'
import {
  findWin95DirectionalItem,
  findWin95TypeMatch,
  itemsInWin95Marquee,
  normalizeWin95Marquee,
  selectWin95All,
  selectWin95Item,
  snapWin95Position
} from '../selectionState'

describe('Win95 shell input routing', () => {
  it('routes required shell accelerators', () => {
    expect(routeWin95Shortcut({ key: 'Escape', ctrlKey: true })).toBe('toggle-start')
    expect(routeWin95Shortcut({ key: 'r', metaKey: true })).toBe('open-run')
    expect(routeWin95Shortcut({ key: 'f', metaKey: true })).toBe('open-find')
    expect(routeWin95Shortcut({ key: 'e', metaKey: true })).toBe('open-explorer')
    expect(routeWin95Shortcut({ key: 'Tab', altKey: true })).toBe('cycle-window')
    expect(routeWin95Shortcut({ key: 'Tab', altKey: true, shiftKey: true })).toBe('cycle-window-reverse')
    expect(routeWin95Shortcut({ key: ' ', altKey: true })).toBe('system-menu')
    expect(routeWin95Shortcut({ key: 'F4', altKey: true })).toBe('close-window')
    expect(routeWin95Shortcut({ key: 'F10', shiftKey: true })).toBe('context-menu')
  })

  it('tracks latched and press-drag-release menu modes by level', () => {
    let state = reduceWin95MenuTracking({ open: false, mode: 'closed', path: [] }, { type: 'open', index: 1, tracking: true })
    expect(state).toEqual({ open: true, mode: 'tracking', path: [1] })
    state = reduceWin95MenuTracking(state, { type: 'hover', level: 1, index: 3, hasChild: true })
    expect(state.path).toEqual([1, 3])
    state = reduceWin95MenuTracking(state, { type: 'release', hasChild: true })
    expect(state.mode).toBe('latched')
    expect(reduceWin95MenuTracking(state, { type: 'close-level' }).path).toEqual([1])
    expect(reduceWin95MenuTracking(state, { type: 'close-all' }).open).toBe(false)
  })

  it('places cascades at edges, builds overflow columns, and preserves submenu corridors', () => {
    expect(placeWin95Menu({ x: 600, y: 430, width: 35, height: 20 }, { width: 170, height: 100 }, { width: 640, height: 452 }))
      .toEqual({ x: 431, y: 352, flippedX: true, flippedY: true })
    expect(menuColumnLayout([20, 20, 20, 20, 20], 60)).toEqual([[0, 1, 2], [3, 4]])
    expect(isPointInMenuCorridor({ x: 100, y: 30 }, { x: 150, y: 35 }, { x: 200, top: 10, bottom: 70 })).toBe(true)
    expect(isPointInMenuCorridor({ x: 100, y: 30 }, { x: 80, y: 100 }, { x: 200, top: 10, bottom: 70 })).toBe(false)
  })
})

describe('Win95 list selection', () => {
  const ids = ['a', 'b', 'c', 'd']
  it('supports anchor ranges, disjoint toggles, and select all', () => {
    let state = selectWin95Item({ selected: [], focused: null, anchor: null }, 'b', ids)
    state = selectWin95Item(state, 'd', ids, { shift: true })
    expect(state.selected).toEqual(['b', 'c', 'd'])
    state = selectWin95Item(state, 'a', ids, { ctrl: true })
    expect(state.selected).toEqual(['b', 'c', 'd', 'a'])
    state = selectWin95Item(state, 'c', ids, { ctrl: true })
    expect(state.selected).toEqual(['b', 'd', 'a'])
    expect(selectWin95All(ids).selected).toEqual(ids)
  })

  it('supports spatial navigation, type matching, marquee intersection, and grid snap', () => {
    const items = [
      { id: 'a', x: 0, y: 0, width: 20, height: 20 },
      { id: 'b', x: 50, y: 0, width: 20, height: 20 },
      { id: 'c', x: 0, y: 50, width: 20, height: 20 }
    ]
    expect(findWin95DirectionalItem(items, 'a', 'right')).toBe('b')
    expect(findWin95DirectionalItem(items, 'a', 'down')).toBe('c')
    const marquee = normalizeWin95Marquee({ x: 55, y: 55 }, { x: -1, y: -1 })
    expect(itemsInWin95Marquee(items, marquee)).toEqual(['a', 'b', 'c'])
    expect(findWin95TypeMatch([{ id: 'a', label: 'Accessories' }, { id: 'b', label: 'Applications' }], 'app', 'a')).toBe('b')
    expect(snapWin95Position({ x: 78, y: 77 }, { width: 75, height: 74 })).toEqual({ x: 79, y: 78 })
  })
})
