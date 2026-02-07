import type { ShellType } from '@shared/types'
import type { ShellDefinition } from './types'
import { Win31Shell } from './Win31Shell'
import { Win95Shell } from './win95'

const shells = new Map<ShellType, ShellDefinition>()

export function registerShell(shell: ShellDefinition): void {
  shells.set(shell.id, shell)
}

export function getShell(id: ShellType): ShellDefinition | undefined {
  return shells.get(id)
}

export function getAllShells(): ShellDefinition[] {
  return Array.from(shells.values())
}

// Register built-in shells
registerShell({
  id: 'win31',
  name: 'Windows 3.1',
  component: Win31Shell
})

registerShell({
  id: 'win95',
  name: 'Windows 95',
  component: Win95Shell
})
