import { describe, expect, it } from 'vitest'
import type { ProgramGroup } from '@shared/types'
import { createShellWindowState } from '@shared/types'
import { findPrograms } from '../../../utils/programSearch'
import { layoutWin95ListView, resizeWin95ReportColumn, win95PageSelectionIndex } from '../listViewState'
import {
  clampWin95Scroll,
  win95ScrollFromThumb,
  win95ScrollPage,
  win95ScrollStep,
  win95ThumbMetrics,
  win95ThumbOffset
} from '../scrollbarState'

const groups: ProgramGroup[] = [{
  id: 'tools', name: 'Tools', icon: 'folder',
  windowState: { x: 0, y: 0, width: 300, height: 200, minimized: false, maximized: false },
  shellWindowState: createShellWindowState(),
  items: [
    { id: 'paint', name: 'Paint', path: 'C:\\Tools\\paint.exe', icon: 'application', workingDir: '', arguments: '/safe' },
    { id: 'site', name: 'Project Site', path: 'https://example.com/project', icon: 'url', workingDir: '' }
  ]
}, {
  id: 'games', name: 'Games', icon: 'folder',
  windowState: { x: 0, y: 0, width: 300, height: 200, minimized: false, maximized: false },
  shellWindowState: createShellWindowState(),
  items: [{ id: 'cards', name: 'Card Game', path: 'C:\\Games\\cards.exe', icon: 'application', workingDir: '' }]
}]

describe('Win95 list-view layouts', () => {
  const ids = Array.from({ length: 12 }, (_, index) => `item-${index}`)
  it('keeps Icon, Small Icon, List, and Report layouts distinct', () => {
    const icon = layoutWin95ListView(ids, 'large', { width: 320, height: 180 })
    const small = layoutWin95ListView(ids, 'small', { width: 320, height: 180 })
    const list = layoutWin95ListView(ids, 'list', { width: 320, height: 180 })
    const report = layoutWin95ListView(ids, 'details', { width: 320, height: 180 })
    expect(icon.items[1].x).toBe(81)
    expect(small.items[1].x).toBe(154)
    expect(list.items[1].y).toBe(24)
    expect(list.items[9].x).toBe(154)
    expect(report.items[0].y).toBe(18)
    expect(report.items[1].y).toBe(37)
  })

  it('uses manual icon positions only when Auto Arrange is off', () => {
    const manual = { 'item-0': { x: 222, y: 111 } }
    expect(layoutWin95ListView(ids, 'large', { width: 320, height: 180 }, manual, false).items[0]).toMatchObject({ x: 222, y: 111 })
    expect(layoutWin95ListView(ids, 'large', { width: 320, height: 180 }, manual, true).items[0]).toMatchObject({ x: 5, y: 8 })
    expect(resizeWin95ReportColumn(60, -100)).toBe(40)
    expect(win95PageSelectionIndex(3, 1, 5, 12)).toBe(8)
  })
})

describe('Win95 scrollbar calculations', () => {
  it('calculates proportional thumbs and reversible drag positions', () => {
    const metrics = win95ThumbMetrics(100, 400, 168)
    expect(metrics.thumbLength).toBe(42)
    const offset = win95ThumbOffset(150, metrics)
    expect(offset).toBe(63)
    expect(win95ScrollFromThumb(offset, metrics)).toBe(150)
  })

  it('clamps line and shaft-page actions at both ends', () => {
    expect(clampWin95Scroll(-10, 300, 100)).toBe(0)
    expect(clampWin95Scroll(500, 300, 100)).toBe(200)
    expect(win95ScrollStep(195, 1, 16, 300, 100)).toBe(200)
    expect(win95ScrollPage(100, -1, 300, 100)).toBe(16)
  })
})

describe('Win95 Find filters', () => {
  it('maps Named wildcards and Look in filters to launcher groups', () => {
    expect(findPrograms(groups, { named: 'P*' }).map((result) => result.item.id)).toEqual(['paint', 'site'])
    expect(findPrograms(groups, { named: '*', groupId: 'games' }).map((result) => result.item.id)).toEqual(['cards'])
  })

  it('maps item type, path, and containing-text predicates without date fabrication', () => {
    expect(findPrograms(groups, { named: '*', type: 'internet' }).map((result) => result.item.id)).toEqual(['site'])
    expect(findPrograms(groups, { named: '*', type: 'application', path: 'games' }).map((result) => result.item.id)).toEqual(['cards'])
    expect(findPrograms(groups, { named: '*', containing: '/safe' }).map((result) => result.item.id)).toEqual(['paint'])
  })
})
