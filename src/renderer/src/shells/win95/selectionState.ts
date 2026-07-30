export interface Win95SelectionState {
  selected: string[]
  focused: string | null
  anchor: string | null
}

export interface SelectModifiers { ctrl?: boolean; shift?: boolean }

export function selectWin95Item(
  state: Win95SelectionState,
  id: string,
  orderedIds: string[],
  modifiers: SelectModifiers = {}
): Win95SelectionState {
  if (modifiers.shift && state.anchor) {
    const from = orderedIds.indexOf(state.anchor)
    const to = orderedIds.indexOf(id)
    if (from >= 0 && to >= 0) {
      const range = orderedIds.slice(Math.min(from, to), Math.max(from, to) + 1)
      const selected = modifiers.ctrl ? [...new Set([...state.selected, ...range])] : range
      return { selected, focused: id, anchor: state.anchor }
    }
  }
  if (modifiers.ctrl) {
    const selected = state.selected.includes(id)
      ? state.selected.filter((candidate) => candidate !== id)
      : [...state.selected, id]
    return { selected, focused: id, anchor: id }
  }
  return { selected: [id], focused: id, anchor: id }
}

export function selectWin95All(ids: string[]): Win95SelectionState {
  return { selected: [...ids], focused: ids[0] ?? null, anchor: ids[0] ?? null }
}

export interface Win95SpatialItem {
  id: string
  x: number
  y: number
  width: number
  height: number
}

export function findWin95DirectionalItem(
  items: Win95SpatialItem[],
  currentId: string | null,
  direction: 'left' | 'right' | 'up' | 'down'
): string | null {
  if (!items.length) return null
  const current = items.find((item) => item.id === currentId) ?? items[0]
  const cx = current.x + current.width / 2
  const cy = current.y + current.height / 2
  const candidates = items.filter((item) => {
    if (item.id === current.id) return false
    const x = item.x + item.width / 2
    const y = item.y + item.height / 2
    if (direction === 'left') return x < cx
    if (direction === 'right') return x > cx
    if (direction === 'up') return y < cy
    return y > cy
  })
  candidates.sort((a, b) => {
    const score = (item: Win95SpatialItem): number => {
      const x = item.x + item.width / 2
      const y = item.y + item.height / 2
      const primary = direction === 'left' || direction === 'right' ? Math.abs(x - cx) : Math.abs(y - cy)
      const secondary = direction === 'left' || direction === 'right' ? Math.abs(y - cy) : Math.abs(x - cx)
      return primary + secondary * 2
    }
    return score(a) - score(b)
  })
  return candidates[0]?.id ?? current.id
}

export interface Win95MarqueeRect { x: number; y: number; width: number; height: number }

export function normalizeWin95Marquee(start: { x: number; y: number }, end: { x: number; y: number }): Win95MarqueeRect {
  return {
    x: Math.min(start.x, end.x),
    y: Math.min(start.y, end.y),
    width: Math.abs(end.x - start.x),
    height: Math.abs(end.y - start.y)
  }
}

export function itemsInWin95Marquee(items: Win95SpatialItem[], marquee: Win95MarqueeRect): string[] {
  return items.filter((item) => item.x < marquee.x + marquee.width && item.x + item.width > marquee.x &&
    item.y < marquee.y + marquee.height && item.y + item.height > marquee.y).map((item) => item.id)
}

export function snapWin95Position(
  position: { x: number; y: number },
  cell: { width: number; height: number },
  inset = { x: 4, y: 4 }
): { x: number; y: number } {
  return {
    x: inset.x + Math.round((position.x - inset.x) / cell.width) * cell.width,
    y: inset.y + Math.round((position.y - inset.y) / cell.height) * cell.height
  }
}

export function findWin95TypeMatch(labels: Array<{ id: string; label: string }>, prefix: string, afterId: string | null): string | null {
  if (!prefix || !labels.length) return null
  const lower = prefix.toLocaleLowerCase('en-US')
  const start = Math.max(0, labels.findIndex((item) => item.id === afterId) + 1)
  for (let offset = 0; offset < labels.length; offset += 1) {
    const item = labels[(start + offset) % labels.length]
    if (item.label.toLocaleLowerCase('en-US').startsWith(lower)) return item.id
  }
  return null
}
