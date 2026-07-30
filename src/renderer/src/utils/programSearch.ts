import type { ProgramGroup, ProgramItem } from '@shared/types'

export interface ProgramSearchResult {
  group: ProgramGroup
  item: ProgramItem
  score: number
}

export interface Win95FindFilters {
  named: string
  groupId?: string
  includeSubgroups?: boolean
  type?: 'all' | 'application' | 'internet'
  containing?: string
  path?: string
}

function wildcardPattern(value: string): RegExp {
  const escaped = value.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.')
  return new RegExp(`^${escaped}$`, 'i')
}

export function findPrograms(groups: ProgramGroup[], filters: Win95FindFilters): ProgramSearchResult[] {
  const named = filters.named.trim() || '*'
  const pattern = wildcardPattern(named.includes('*') || named.includes('?') ? named : `*${named}*`)
  const containing = filters.containing?.trim().toLocaleLowerCase('en-US') ?? ''
  const pathFilter = filters.path?.trim().toLocaleLowerCase('en-US') ?? ''
  const results: ProgramSearchResult[] = []
  for (const group of groups) {
    if (filters.groupId && group.id !== filters.groupId) continue
    for (const item of group.items) {
      const internet = /^https?:\/\//i.test(item.path)
      if (filters.type === 'internet' && !internet) continue
      if (filters.type === 'application' && internet) continue
      if (!pattern.test(item.name)) continue
      const haystack = `${item.name}\n${item.path}\n${item.arguments ?? ''}`.toLocaleLowerCase('en-US')
      if (containing && !haystack.includes(containing)) continue
      if (pathFilter && !item.path.toLocaleLowerCase('en-US').includes(pathFilter)) continue
      const exact = item.name.toLocaleLowerCase('en-US') === named.toLocaleLowerCase('en-US')
      results.push({ group, item, score: exact ? 3 : item.name.toLocaleLowerCase('en-US').startsWith(named.toLocaleLowerCase('en-US')) ? 2 : 1 })
    }
  }
  return results.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name, 'en-US', { numeric: true, sensitivity: 'base' }))
}

export function searchPrograms(groups: ProgramGroup[], rawQuery: string): ProgramSearchResult[] {
  const query = rawQuery.trim().toLocaleLowerCase('en-US')
  if (!query) return []
  const results: ProgramSearchResult[] = []
  for (const group of groups) {
    const groupName = group.name.toLocaleLowerCase('en-US')
    for (const item of group.items) {
      const name = item.name.toLocaleLowerCase('en-US')
      const path = item.path.toLocaleLowerCase('en-US')
      const score = name.startsWith(query) ? 3
        : name.includes(query) ? 2
          : path.includes(query) || groupName.includes(query) ? 1 : 0
      if (score) results.push({ group, item, score })
    }
  }
  return results.sort((a, b) => b.score - a.score ||
    a.item.name.localeCompare(b.item.name, 'en-US', { numeric: true, sensitivity: 'base' }))
}
