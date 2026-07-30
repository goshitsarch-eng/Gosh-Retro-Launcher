export type Win95DialogKeyAction = 'cancel' | 'default' | 'advance-focus' | 'reverse-focus' | 'none'

export function resolveWin95DialogKey(event: {
  key: string
  altKey?: boolean
  shiftKey?: boolean
}, hasDefault: boolean, focusedButton = false, multiline = false): Win95DialogKeyAction {
  if (event.key === 'Escape' || (event.altKey && event.key === 'F4')) return 'cancel'
  if (event.key === 'Tab') return event.shiftKey ? 'reverse-focus' : 'advance-focus'
  if (event.key === 'Enter' && hasDefault && !focusedButton && !multiline) return 'default'
  return 'none'
}

export function leastDestructiveDefault<T extends string>(buttons: T[]): T | null {
  const preferred = ['cancel', 'no', 'close', 'ok']
  for (const id of preferred) {
    const match = buttons.find((button) => button.toLowerCase() === id)
    if (match) return match
  }
  return buttons[0] ?? null
}
