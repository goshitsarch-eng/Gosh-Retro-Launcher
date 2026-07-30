export interface MenuLevelState {
  level: number
  indices: number[]
}

export type MenuNavigationKey =
  | 'ArrowUp' | 'ArrowDown' | 'ArrowLeft' | 'ArrowRight'
  | 'Home' | 'End' | 'Enter' | 'Escape'

export interface MenuNavigationResult extends MenuLevelState {
  action: 'none' | 'open-child' | 'activate' | 'close-level' | 'close-all'
}

function wrap(value: number, length: number): number {
  if (length <= 0) return -1
  return (value + length) % length
}

/** Pure reducer shared by Start and popup-menu keyboard handling. */
export function reduceMenuNavigation(
  state: MenuLevelState,
  key: MenuNavigationKey,
  itemCounts: number[],
  selectedHasChild = false
): MenuNavigationResult {
  const indices = [...state.indices]
  const level = Math.max(0, Math.min(state.level, itemCounts.length - 1))
  const count = itemCounts[level] ?? 0
  const selected = indices[level] ?? (count > 0 ? 0 : -1)

  if (key === 'ArrowDown') {
    indices[level] = wrap(selected + 1, count)
    return { level, indices, action: 'none' }
  }
  if (key === 'ArrowUp') {
    indices[level] = wrap(selected - 1, count)
    return { level, indices, action: 'none' }
  }
  if (key === 'Home') {
    indices[level] = count ? 0 : -1
    return { level, indices, action: 'none' }
  }
  if (key === 'End') {
    indices[level] = count ? count - 1 : -1
    return { level, indices, action: 'none' }
  }
  if (key === 'ArrowRight' && selectedHasChild) {
    const nextLevel = Math.min(level + 1, itemCounts.length - 1)
    indices[nextLevel] = 0
    return { level: nextLevel, indices, action: 'open-child' }
  }
  if (key === 'ArrowLeft') {
    if (level === 0) return { level, indices, action: 'close-all' }
    indices.splice(level)
    return { level: level - 1, indices, action: 'close-level' }
  }
  if (key === 'Escape') {
    if (level === 0) return { level, indices, action: 'close-all' }
    indices.splice(level)
    return { level: level - 1, indices, action: 'close-level' }
  }
  if (key === 'Enter') {
    return { level, indices, action: selectedHasChild ? 'open-child' : 'activate' }
  }
  return { level, indices, action: 'none' }
}

export function mnemonicIndex(labels: string[], key: string): number {
  const lower = key.toLocaleLowerCase('en-US')
  return labels.findIndex((label) => {
    const marker = label.indexOf('&')
    return marker >= 0 && label[marker + 1]?.toLocaleLowerCase('en-US') === lower
  })
}

export function displayMnemonic(label: string): { before: string; mnemonic: string; after: string } {
  const marker = label.indexOf('&')
  if (marker < 0 || marker === label.length - 1) return { before: label, mnemonic: '', after: '' }
  return { before: label.slice(0, marker), mnemonic: label[marker + 1], after: label.slice(marker + 2) }
}
