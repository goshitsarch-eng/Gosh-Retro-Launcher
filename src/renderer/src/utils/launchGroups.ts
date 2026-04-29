import type { ProgramGroup, ProgramItem } from '@shared/types'

export const LAUNCH_GROUP_OPTIONS = Array.from({ length: 9 }, (_, index) => index)

export function formatLaunchGroup(value: number): string {
  if (value <= 0) {
    return 'None'
  }
  return `Group ${value}`
}

export interface LaunchGroupBucket {
  groupNumber: number
  items: ProgramItem[]
}

export interface LaunchGroupProgress {
  groupNumber: number
  groupIndex: number
  totalGroups: number
  items: ProgramItem[]
}

export function collectLaunchGroups(groups: ProgramGroup[]): LaunchGroupBucket[] {
  const launchGroups = new Map<number, ProgramItem[]>()

  for (const group of groups) {
    for (const item of group.items) {
      const launchGroup = item.launchGroup ?? 0
      if (launchGroup <= 0) continue
      const bucket = launchGroups.get(launchGroup) ?? []
      bucket.push(item)
      launchGroups.set(launchGroup, bucket)
    }
  }

  return Array.from(launchGroups.entries())
    .sort(([a], [b]) => a - b)
    .map(([groupNumber, items]) => ({ groupNumber, items }))
}

export async function launchGroupBuckets(
  buckets: LaunchGroupBucket[],
  launchDelay: number,
  onGroupStart?: (progress: LaunchGroupProgress) => void
): Promise<Array<{ success: boolean; error?: string }>> {
  const results: Array<{ success: boolean; error?: string }> = []

  for (const [index, bucket] of buckets.entries()) {
    onGroupStart?.({
      groupNumber: bucket.groupNumber,
      groupIndex: index,
      totalGroups: buckets.length,
      items: bucket.items
    })
    const groupResults = await window.electronAPI.program.launchBatch(
      bucket.items,
      launchDelay
    )
    results.push(...groupResults)
  }

  return results
}
