import { afterEach, describe, expect, it, vi } from 'vitest'
import { collectLaunchGroups, launchGroupBuckets } from '../launchGroups'
import type { ProgramGroup, ProgramItem } from '@shared/types'

const item = (id: string, launchGroup: number): ProgramItem => ({
  id,
  name: id,
  path: `/apps/${id}`,
  icon: 'default',
  workingDir: '',
  launchGroup
})

const group = (id: string, items: ProgramItem[]): ProgramGroup => ({
  id,
  name: id,
  icon: 'folder',
  windowState: { x: 0, y: 0, width: 300, height: 200, minimized: false, maximized: false },
  items
})

describe('launch groups', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('collects assigned items in group and item order, sorted by launch number', () => {
    const groups = [
      group('one', [item('a', 2), item('ignored', 0), item('b', 1)]),
      group('two', [item('c', 2), item('d', 1)])
    ]
    expect(collectLaunchGroups(groups).map((bucket) => ({
      groupNumber: bucket.groupNumber,
      ids: bucket.items.map((entry) => entry.id)
    }))).toEqual([
      { groupNumber: 1, ids: ['b', 'd'] },
      { groupNumber: 2, ids: ['a', 'c'] }
    ])
  })

  it('launches every bucket exactly once in order and reports progress before IPC', async () => {
    const calls: string[] = []
    const launchBatch = vi.fn(async (items: ProgramItem[], delay: number) => {
      calls.push(`launch:${items.map((entry) => entry.id).join(',')}:${delay}`)
      return items.map((entry) => ({ id: entry.id, success: true }))
    })
    vi.stubGlobal('window', { electronAPI: { program: { launchBatch } } })
    const buckets = [
      { groupNumber: 1, items: [item('a', 1)] },
      { groupNumber: 3, items: [item('b', 3), item('c', 3)] }
    ]

    const results = await launchGroupBuckets(buckets, 250, (progress) => {
      calls.push(`progress:${progress.groupNumber}:${progress.groupIndex}`)
    })

    expect(calls).toEqual([
      'progress:1:0',
      'launch:a:250',
      'progress:3:1',
      'launch:b,c:250'
    ])
    expect(results).toHaveLength(3)
    expect(launchBatch).toHaveBeenCalledTimes(2)
  })
})
