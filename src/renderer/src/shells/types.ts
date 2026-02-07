import type { ShellType } from '@shared/types'

export interface ShellProps {
  platform: string
}

export interface ShellDefinition {
  id: ShellType
  name: string
  component: React.ComponentType<ShellProps>
}
